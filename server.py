import http.server
import socketserver
import json
import os
import re
import ssl
import subprocess
import threading
import time
import urllib.parse
import urllib.request
import datetime

PORT = 8000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))
SWITCHER_DIR = r"C:\Users\JoaoGaspar\.gemini\config\skills\gmail-switcher"
WATCH_FILE   = os.path.join(SWITCHER_DIR, "watch_state.json")
ACCOUNTS_FILE = os.path.join(SWITCHER_DIR, "accounts.json")

SSL_CTX = ssl._create_unverified_context()

# ---- Background probe cache ----
_cache_lock = threading.Lock()
_cached_result = None
_cache_ts = 0
CACHE_TTL = 10  # seconds between real probes

def probe_language_server():
    """Directly queries the active language_server_windows_x64 process for real-time status."""
    ps_cmd = "Get-CimInstance Win32_Process -Filter \"name='language_server_windows_x64.exe'\" | Select-Object ProcessId, CommandLine | ConvertTo-Json -Compress"
    try:
        out = subprocess.check_output(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
            stderr=subprocess.DEVNULL,
            timeout=4
        ).decode('utf-8', errors='ignore').strip()
        if not out:
            return None, None, None
        procs = json.loads(out)
        if isinstance(procs, dict):
            procs = [procs]
    except Exception:
        return None, None, None

    try:
        netstat = subprocess.check_output(
            ["netstat", "-ano"],
            stderr=subprocess.DEVNULL,
            timeout=4
        ).decode('utf-8', errors='ignore')
    except Exception:
        return None, None, None

    for p in procs:
        cl = p.get('CommandLine', '')
        pid = p.get('ProcessId')
        if '--enable_lsp' in cl:
            continue # Agent language server does not have --enable_lsp
        m_csrf = re.search(r'--csrf_token\s+([\w-]+)', cl)
        if not m_csrf:
            continue
        csrf = m_csrf.group(1)

        ports = []
        for nline in netstat.splitlines():
            if 'LISTENING' in nline and nline.strip().endswith(str(pid)):
                pm = re.search(r'127\.0\.0\.1:(\d+)', nline)
                if pm:
                    ports.append(int(pm.group(1)))

        for port in ports:
            try:
                req = urllib.request.Request(
                    f'https://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/GetUserStatus',
                    data=b'{}',
                    headers={'x-codeium-csrf-token': csrf, 'Content-Type': 'application/json'}
                )
                res = urllib.request.urlopen(req, context=SSL_CTX, timeout=2)
                data = json.loads(res.read().decode('utf-8'))
                if 'userStatus' in data:
                    return data['userStatus'], port, pid
            except Exception:
                pass
    return None, None, None

def auto_register_account_if_new(email, name):
    """Automatically adds any newly detected account to accounts.json."""
    if not email or not os.path.exists(ACCOUNTS_FILE):
        return
    try:
        with open(ACCOUNTS_FILE, 'r', encoding='utf-8-sig') as f:
            data = json.load(f)
        accounts = data.get('accounts', [])
        exists = any(a.get('email', '').lower() == email.lower() for a in accounts)
        if not exists:
            label = name if name else email.split('@')[0].capitalize()
            group = 'alunos' if 'aluno' in email.lower() else 'geral'
            accounts.append({
                "email": email,
                "aliases": [email.split('@')[0]],
                "group": group,
                "label": label,
                "status": "active",
                "last_used": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "last_seen": datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
                "rate_limited_at": None,
                "reset_at": None,
                "auto_reset_at": None,
                "exhausted_models": [],
                "last_quota_snapshot": None
            })
            data['accounts'] = accounts
            with open(ACCOUNTS_FILE, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4, ensure_ascii=False)
            print(f"[auto-register] New account registered: {email}")
    except Exception as e:
        print(f"[auto-register] Error: {e}")

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_OPTIONS(self):
        """Handle CORS preflight requests from Vercel-hosted frontend."""
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-requested-with')
        self.send_header('Access-Control-Max-Age', '86400')
        self.send_header('Content-Length', '0')
        self.end_headers()

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        if parsed_url.path == '/api/live':
            self.handle_api_live()
        elif parsed_url.path == '/api/status':
            self._json_response({"status": "ok", "version": "2.0"})
        else:
            super().do_GET()

    def _json_response(self, data):
        body = json.dumps(data).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        self.wfile.write(body)


    def handle_api_live(self):
        """Serve from background probe cache — always fast, never blocks."""
        with _cache_lock:
            result = _cached_result
        if result is None:
            # Cache not ready yet (first 10s after startup)
            result = {
                "agent": None,
                "modelQuotas": {},
                "pool": [],
                "suggestEmail": None,
                "lastCheck": datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
                "status": "initializing"
            }
        self._json_response(result)

    def log_message(self, format, *args):
        pass

def _background_probe():
    """Continuously probes the Language Server and updates the cache."""
    global _cached_result, _cache_ts
    while True:
        try:
            user_status, port, pid = probe_language_server()
            now_iso = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
            result = build_result(user_status, port, pid, now_iso)
            with _cache_lock:
                _cached_result = result
                _cache_ts = time.time()
        except Exception as e:
            print(f"[probe error] {e}")
        time.sleep(CACHE_TTL)


def build_result(user_status, port, pid, now_iso):
    result = {
        "agent": None,
        "modelQuotas": {},
        "pool": [],
        "suggestEmail": None,
        "lastCheck": now_iso
    }
    if user_status:
        email = user_status.get('email')
        name  = user_status.get('name')
        result["agent"] = {"email": email, "name": name, "pid": pid, "port": port}
        auto_register_account_if_new(email, name)
        configs = user_status.get('cascadeModelConfigData', {}).get('clientModelConfigs', [])
        for c in configs:
            lbl = c.get('label') or c.get('modelOrAlias', {}).get('model')
            q = c.get('quotaInfo')
            if q:
                rem = q.get('remainingFraction')
                result["modelQuotas"][lbl] = {
                    "remaining": 0.0 if rem is None else float(rem),
                    "resetTime": q.get('resetTime')
                }
        try:
            with open(WATCH_FILE, 'w', encoding='utf-8') as f:
                json.dump({"last_check": now_iso, "agent_email": email,
                           "agent_name": name, "agent_pid": pid,
                           "agent_port": port, "model_quotas": result["modelQuotas"]}, f, indent=4)
        except Exception:
            pass
    else:
        try:
            if os.path.exists(WATCH_FILE):
                with open(WATCH_FILE, 'r', encoding='utf-8-sig') as f:
                    ws = json.load(f)
                result["lastCheck"]    = ws.get("last_check")
                result["agent"]        = {"email": ws.get("agent_email"), "name": ws.get("agent_name"),
                                          "pid": ws.get("agent_pid"),    "port": ws.get("agent_port")}
                result["modelQuotas"] = ws.get("model_quotas", {})
        except Exception:
            pass
    try:
        if os.path.exists(ACCOUNTS_FILE):
            with open(ACCOUNTS_FILE, 'r', encoding='utf-8-sig') as f:
                accs = json.load(f)
            pool = accs.get("accounts", [])
            result["pool"] = pool
            agent_email = result["agent"]["email"] if result["agent"] else None
            for acc in pool:
                if acc.get("status", "active") == "active" and acc.get("email") != agent_email:
                    result["suggestEmail"] = acc.get("email")
                    break
    except Exception:
        pass
    return result


if __name__ == '__main__':
    os.chdir(DIRECTORY)
    # Start background probe thread
    t = threading.Thread(target=_background_probe, daemon=True)
    t.start()
    print("[server] Background probe started.")
    # Use threading server to handle multiple concurrent requests
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("", PORT), CustomHandler) as httpd:
        print(f"[server] Serving at http://localhost:{PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
