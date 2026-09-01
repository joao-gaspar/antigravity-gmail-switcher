from http.server import BaseHTTPRequestHandler
import json
import os

TMP_FILE = "/tmp/ags_sync_store.json"

def _load_store():
    try:
        if os.path.exists(TMP_FILE):
            with open(TMP_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {"machines": {}, "accounts": {}}

def _save_store(data):
    try:
        with open(TMP_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f)
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
            data = json.loads(body.decode('utf-8')) if body else {}

            store = _load_store()
            m_store = store.get("machines", {})
            a_store = store.get("accounts", {})

            # Seed machines from client cache if server cold-started
            for seed_m in data.get("seed_machines", []):
                smid = seed_m.get("machine_id")
                if smid and smid not in m_store:
                    m_store[smid] = seed_m

            mid = data.get('machine_id')
            if mid:
                m_store[mid] = {
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

            for acc in data.get("accounts", []):
                email = acc.get("email", "").strip().lower()
                if not email:
                    continue
                existing = a_store.get(email, {})
                a_store[email] = {
                    "email":       acc.get("email", email),
                    "tokenGemini": acc.get("tokenGemini", existing.get("tokenGemini", 0)),
                    "tokenClaude": acc.get("tokenClaude", existing.get("tokenClaude", 0)),
                    "tokenGpt":    acc.get("tokenGpt",    existing.get("tokenGpt",    0)),
                    "status":      acc.get("status",      existing.get("status", "available")),
                    "reset_at":    acc.get("reset_at",    existing.get("reset_at")),
                    "updated_at":  data.get("last_seen", ""),
                }

            _save_store({"machines": m_store, "accounts": a_store})

            resp = {
                "status":   "ok",
                "machines": list(m_store.values()),
                "accounts": list(a_store.values())
            }
            self._send_json(200, resp)
        except Exception as e:
            self._send_json(500, {"error": str(e)})

    def do_GET(self):
        store = _load_store()
        resp = {
            "status":   "ok",
            "machines": list(store.get("machines", {}).values()),
            "accounts": list(store.get("accounts", {}).values())
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
