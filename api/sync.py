from http.server import BaseHTTPRequestHandler
import json

# In-memory cloud stores — reset on cold start, replenished by frequent polls
_machines_store = {}   # machine_id -> machine snapshot
_accounts_store = {}   # email (lower) -> { email, tokenGemini, tokenClaude, tokenGpt, status, reset_at }

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

            resp = {
                "status":   "ok",
                "machines": list(_machines_store.values()),
                "accounts": list(_accounts_store.values())
            }
            self._send_json(200, resp)
        except Exception as e:
            self._send_json(500, {"error": str(e)})

    def do_GET(self):
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
