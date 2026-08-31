from http.server import BaseHTTPRequestHandler
import json
import time

# Cloud store for all reporting machines
_machines_store = {}

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
                    "machine_id": mid,
                    "hostname": data.get("hostname", "PC"),
                    "username": data.get("username", ""),
                    "ip": data.get("ip", ""),
                    "os": data.get("os", ""),
                    "active_email": data.get("active_email"),
                    "suggest_email": data.get("suggest_email"),
                    "suggest_reason": data.get("suggest_reason"),
                    "model_quotas": data.get("model_quotas", {}),
                    "last_seen": data.get("last_seen"),
                    "accounts": data.get("accounts", [])
                }
            
            resp = {
                "status": "ok",
                "machines": list(_machines_store.values())
            }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode('utf-8'))
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode('utf-8'))

    def do_GET(self):
        resp = {
            "status": "ok",
            "machines": list(_machines_store.values())
        }
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(resp).encode('utf-8'))
