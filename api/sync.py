from http.server import BaseHTTPRequestHandler
import json
import base64
import urllib.request

# Persistent global cloud store backed by keyvalue.immanuel.co
_machines_store = {}
_accounts_store = {}
_known_keys = ["mac_joaogaspar_pc", "mac_laptop_21i6oq39", "mac_ebbim", "mac_joaogaspar"]

def _sync_from_global_kv():
    for k in _known_keys:
        try:
            url = f"https://keyvalue.immanuel.co/api/KeyVal/GetValue/ags_sync_v1/{k}"
            req = urllib.request.Request(url, headers={"User-Agent": "AGS-Sync/1.0"})
            with urllib.request.urlopen(req, timeout=2) as resp:
                raw = resp.read().decode('utf-8').strip('"').strip()
                if raw and raw != "Not Found" and len(raw) > 5:
                    raw_b64 = raw.replace('-', '+').replace('_', '/')
                    padding = len(raw_b64) % 4
                    if padding:
                        raw_b64 += '=' * (4 - padding)
                    decoded = base64.b64decode(raw_b64).decode('utf-8')
                    m_data = json.loads(decoded)
                    mid = m_data.get("machine_id")
                    if mid:
                        _machines_store[mid] = m_data
        except Exception:
            pass

class handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_POST(self):
        try:
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length)
            data = json.loads(body.decode('utf-8'))

            mid = data.get('machine_id')
            if mid:
                _machines_store[mid] = {
                    "machine_id":     mid,
                    "hostname":       data.get("hostname", "PC"),
                    "username":       data.get("username", ""),
                    "ip":             data.get("ip", ""),
                    "os":             data.get("os", ""),
                    "active_email":   data.get("active_email"),
                    "suggest_email":  data.get("suggest_email"),
                    "suggest_reason": data.get("suggest_reason"),
                    "model_quotas":   data.get("model_quotas", {}),
                    "last_seen":      data.get("last_seen"),
                }
                k = "mac_" + mid.replace("mac-", "").replace('-', '_').replace('.', '_')
                if k not in _known_keys:
                    _known_keys.append(k)

            for acc in data.get("accounts", []):
                email = acc.get("email", "").strip().lower()
                if not email:
                    continue
                existing = _accounts_store.get(email, {})
                _accounts_store[email] = {
                    "email":       acc.get("email", email),
                    "tokenGemini": acc.get("tokenGemini", existing.get("tokenGemini", 0)),
                    "tokenClaude": acc.get("tokenClaude", existing.get("tokenClaude", 0)),
                    "tokenGpt":    acc.get("tokenGpt",    existing.get("tokenGpt",    0)),
                    "status":      acc.get("status",      existing.get("status", "available")),
                    "reset_at":    acc.get("reset_at",    existing.get("reset_at")),
                    "updated_at":  data.get("last_seen", ""),
                }

            _sync_from_global_kv()

            resp = {
                "status":   "ok",
                "machines": list(_machines_store.values()),
                "accounts": list(_accounts_store.values())
            }
            self._send_json(200, resp)
        except Exception as e:
            self._send_json(500, {"error": str(e)})

    def do_GET(self):
        _sync_from_global_kv()
        resp = {
            "status":   "ok",
            "machines": list(_machines_store.values()),
            "accounts": list(_accounts_store.values())
        }
        self._send_json(200, resp)

    def _send_json(self, code, obj):
        body = json.dumps(obj).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
