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
import database  # local SQLite layer

PORT = 8000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))
USER_HOME = os.path.expanduser("~")
SWITCHER_DIR = os.path.join(USER_HOME, ".gemini", "config", "skills", "gmail-switcher")
WATCH_FILE    = os.path.join(SWITCHER_DIR, "watch_state.json")
ACCOUNTS_FILE = os.path.join(SWITCHER_DIR, "accounts.json")

SSL_CTX = ssl._create_unverified_context()

# ---- Machine identity (set once at startup) ----
_MACHINE = database.get_machine_info()
database.upsert_machine(_MACHINE['machine_id'], _MACHINE['hostname'],
                        _MACHINE['ip'], _MACHINE['os'])

# ---- Background probe cache ----
_cache_lock = threading.Lock()
_cached_result = None
_cache_ts = 0
CACHE_TTL = 10  # seconds between real probes

def probe_language_server():
    """Directly queries the active language_server_windows_x64 process for real-time status."""
    # Hide subprocess console windows completely on Windows when running under pythonw.exe
    startupinfo = None
    if os.name == 'nt':
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 0  # SW_HIDE

    ps_cmd = "Get-CimInstance Win32_Process -Filter \"name LIKE 'language_server%'\" | Select-Object ProcessId, CommandLine | ConvertTo-Json -Compress"
    try:
        out = subprocess.check_output(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
            stderr=subprocess.DEVNULL,
            startupinfo=startupinfo,
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
            startupinfo=startupinfo,
            timeout=4
        ).decode('utf-8', errors='ignore')
    except Exception:
        return None, None, None

    for p in procs:
        cl = p.get('CommandLine', '')
        pid = p.get('ProcessId')
        if '--enable_lsp' in cl:
            continue # Agent language server does not have --enable_lsp
        m_csrf = re.search(r'--csrf_token[=\s]+([\w-]+)', cl)
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

def update_account_status_if_exhausted(email, model_quotas):
    """
    Checks if active account model quotas are exhausted (<= 1%) and updates accounts.json status.
    If exhausted, marks status = 'rate_limited' with reset_at timestamp.
    If recovered, resets status = 'active'.
    """
    if not email or not os.path.exists(ACCOUNTS_FILE):
        return
    try:
        is_exhausted = False
        reset_time_str = None
        
        for lbl, info in model_quotas.items():
            if 'gemini' in lbl.lower() or 'claude' in lbl.lower() or 'gpt' in lbl.lower():
                rem = info.get('remaining', 1.0)
                if rem <= 0.01:
                    is_exhausted = True
                    r_time = info.get('resetTime')
                    if r_time:
                        # Convert "2026-09-07T04:37:19Z" -> "2026-09-07 04:37:19"
                        reset_time_str = r_time.replace('T', ' ').replace('Z', '').strip()
                        break
        
        with open(ACCOUNTS_FILE, 'r', encoding='utf-8-sig') as f:
            data = json.load(f)
            
        accounts = data.get('accounts', [])
        updated = False
        
        for acc in accounts:
            if acc.get('email', '').lower() == email.lower():
                current_status = acc.get('status')
                if is_exhausted:
                    # Mark as rate_limited
                    target_reset = reset_time_str or (datetime.datetime.now() + datetime.timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S")
                    if current_status != 'rate_limited' or acc.get('reset_at') != target_reset:
                        acc['status'] = 'rate_limited'
                        acc['rate_limited_at'] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        acc['reset_at'] = target_reset
                        updated = True
                        print(f"[status-update] Marked {email} as rate_limited. Resets at {acc['reset_at']}")
                else:
                    # Recover to active
                    if current_status == 'rate_limited':
                        acc['status'] = 'active'
                        acc['rate_limited_at'] = None
                        acc['reset_at'] = None
                        updated = True
                        print(f"[status-update] Restored {email} to active status.")
                        
        if updated:
            with open(ACCOUNTS_FILE, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4, ensure_ascii=False)
    except Exception as e:
        print(f"[status-update] Error: {e}")

def sync_accounts_json_with_sqlite():
    """
    Retroactively sync accounts.json status with the latest SQLite snapshots.
    If the latest snapshot for an account shows it is exhausted (<= 1.0%), marks it rate_limited.
    """
    if not os.path.exists(ACCOUNTS_FILE):
        return
    try:
        snapshots = database.get_all_latest_snapshots()
        if not snapshots:
            return
            
        with open(ACCOUNTS_FILE, 'r', encoding='utf-8-sig') as f:
            data = json.load(f)
        
        accounts = data.get('accounts', [])
        updated = False
        
        for acc in accounts:
            email = acc.get('email', '').lower()
            snap = next((s for s in snapshots if s['email'].lower() == email), None)
            if snap:
                g_exh = (snap.get('gemini_pct', 100.0) <= 1.0)
                c_exh = (snap.get('claude_pct', 100.0) <= 1.0)
                is_exhausted = g_exh or c_exh  # rate limit if either main model is out
                current_status = acc.get('status')
                
                if is_exhausted:
                    if current_status != 'rate_limited':
                        acc['status'] = 'rate_limited'
                        acc['rate_limited_at'] = snap.get('ts', '').replace('T', ' ')
                        r_at = snap.get('reset_at') or ''
                        acc['reset_at'] = r_at.replace('T', ' ').replace('Z', '').strip()
                        if not acc['reset_at']:
                            acc['reset_at'] = (datetime.datetime.now() + datetime.timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S")
                        updated = True
                        print(f"[sync-db] Marked {email} as rate_limited based on SQLite snapshot.")
                else:
                    if current_status == 'rate_limited':
                        acc['status'] = 'active'
                        acc['rate_limited_at'] = None
                        acc['reset_at'] = None
                        updated = True
                        print(f"[sync-db] Restored {email} to active based on SQLite snapshot.")
                        
        if updated:
            with open(ACCOUNTS_FILE, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4, ensure_ascii=False)
    except Exception as e:
        print(f"[sync-db] Error syncing: {e}")


class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_OPTIONS(self):
        """Handle CORS preflight requests from Vercel-hosted frontend."""
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-requested-with')
        self.send_header('Access-Control-Allow-Private-Network', 'true')
        self.send_header('Access-Control-Max-Age', '86400')
        self.send_header('Content-Length', '0')
        self.end_headers()

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        if parsed_url.path == '/api/live':
            self.handle_api_live()
        elif parsed_url.path == '/api/status':
            self._json_response({"status": "ok", "version": "2.0",
                                  "machine": _MACHINE})
        elif parsed_url.path == '/api/machines':
            self._json_response(database.list_machines())
        elif parsed_url.path == '/api/snapshots':
            self._json_response(database.get_all_latest_snapshots())
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
        self.send_header('Access-Control-Allow-Private-Network', 'true')
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
    mid = _MACHINE['machine_id']
    result = {
        "agent": None,
        "modelQuotas": {},
        "pool": [],
        "suggestEmail": None,
        "suggestReason": None,
        "lastCheck": now_iso,
        "machine": _MACHINE
    }
    if user_status:
        email = user_status.get('email')
        name  = user_status.get('name')
        result["agent"] = {"email": email, "name": name, "pid": pid, "port": port}
        auto_register_account_if_new(email, name)
        configs = user_status.get('cascadeModelConfigData', {}).get('clientModelConfigs', [])
        gemini_vals, claude_vals, gpt_vals = [], [], []
        first_reset = None
        for c in configs:
            lbl = c.get('label') or c.get('modelOrAlias', {}).get('model')
            q = c.get('quotaInfo')
            if q:
                rem = q.get('remainingFraction')
                rem_val = 0.0 if rem is None else float(rem)
                reset_t = q.get('resetTime')
                if not first_reset and reset_t:
                    first_reset = reset_t
                result["modelQuotas"][lbl] = {"remaining": rem_val, "resetTime": reset_t}
                if lbl and 'gemini' in lbl.lower():
                    gemini_vals.append(rem_val)
                elif lbl and 'claude' in lbl.lower():
                    claude_vals.append(rem_val)
                elif lbl and ('gpt' in lbl.lower() or 'openai' in lbl.lower()):
                    gpt_vals.append(rem_val)
        # Persist snapshot
        g_pct = max(gemini_vals) * 100 if gemini_vals else 0.0
        c_pct = max(claude_vals) * 100 if claude_vals else 0.0
        p_pct = max(gpt_vals)    * 100 if gpt_vals    else 0.0
        database.save_snapshot(mid, email, g_pct, c_pct, p_pct, first_reset)
        database.upsert_account(mid, email, is_active=True)
        
        # Check and update accounts.json rate-limited status dynamically
        update_account_status_if_exhausted(email, result["modelQuotas"])
        
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
                result["lastCheck"]   = ws.get("last_check")
                result["agent"]       = {"email": ws.get("agent_email"), "name": ws.get("agent_name"),
                                         "pid": ws.get("agent_pid"),    "port": ws.get("agent_port")}
                result["modelQuotas"] = ws.get("model_quotas", {})
        except Exception:
            pass
    # Sincronizar status do JSON com banco SQLite antes de carregar o pool
    sync_accounts_json_with_sqlite()

    # Pool from accounts.json
    pool = []
    try:
        if os.path.exists(ACCOUNTS_FILE):
            with open(ACCOUNTS_FILE, 'r', encoding='utf-8-sig') as f:
                accs = json.load(f)
            pool = accs.get("accounts", [])
            result["pool"] = pool
            # Persist each account in DB for this machine
            agent_email = result["agent"]["email"] if result["agent"] else None
            for i, acc in enumerate(pool):
                database.upsert_account(mid, acc.get('email',''),
                                        is_active=(acc.get('email') == agent_email),
                                        carousel_pos=i,
                                        status=acc.get('status','available'),
                                        reset_at=acc.get('reset_at'),
                                        name=acc.get('name'),
                                        category=acc.get('category'),
                                        avatar_url=acc.get('avatarUrl'),
                                        theme=acc.get('theme'),
                                        notes=acc.get('notes'))
    except Exception:
        pass
    # Compute and persist suggestion
    agent_email = result["agent"]["email"] if result["agent"] else None
    sug = database.compute_and_save_suggestion(mid, agent_email, pool)
    result["suggestEmail"]  = sug.get("email")
    result["suggestReason"] = sug.get("reason")
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
