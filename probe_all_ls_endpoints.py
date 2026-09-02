import urllib.request, ssl, json, re, subprocess

# Get process list via powershell
ps_cmd = 'Get-CimInstance Win32_Process | Where-Object { $_.Name -like "language_server*" } | Select-Object ProcessId, CreationDate, CommandLine | ConvertTo-Json'
res = subprocess.check_output(['powershell', '-Command', ps_cmd]).decode('utf-8', errors='ignore')

procs_data = json.loads(res)
if isinstance(procs_data, dict):
    procs_data = [procs_data]

print(f"Found {len(procs_data)} language_server processes.")

# Get netstat output
netstat_out = subprocess.check_output(['netstat', '-ano']).decode('utf-8', errors='ignore')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

methods = [
    "GetUserStatus",
    "GetAuthState",
    "GetAgentStatus",
    "GetAccountInfo",
    "GetActiveUser",
    "GetConfig",
    "GetClientModelConfigs",
    "GetCascadeModelConfigs",
    "GetState",
    "GetUserInfo"
]

for p in procs_data:
    pid = p.get('ProcessId')
    cmd = p.get('CommandLine') or ''
    match = re.search(r'--csrf_token[=\s]+([\w-]+)', cmd)
    if not match:
        continue
    csrf = match.group(1)

    ports = []
    for line in netstat_out.splitlines():
        if 'LISTENING' in line and line.strip().endswith(str(pid)):
            pm = re.search(r'127\.0\.0\.1:(\d+)', line)
            if pm:
                ports.append(int(pm.group(1)))

    print(f"\n--- PID {pid} (CSRF: {csrf}) Ports: {ports} ---")
    for port in ports:
        for m in methods:
            url = f"https://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/{m}"
            req = urllib.request.Request(
                url,
                data=b"{}",
                headers={
                    "x-codeium-csrf-token": csrf,
                    "Content-Type": "application/json"
                },
                method="POST"
            )
            try:
                with urllib.request.urlopen(req, context=ctx, timeout=2) as resp:
                    data = resp.read().decode('utf-8', errors='ignore')
                    print(f"  [Port {port}] {m} SUCCESS => {data[:250]}")
            except Exception:
                pass
