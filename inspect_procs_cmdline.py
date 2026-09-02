import subprocess, json

ps_cmd = 'Get-CimInstance Win32_Process | Where-Object { $_.Name -like "language_server*" } | Select-Object ProcessId, ParentProcessId, CreationDate, CommandLine | ConvertTo-Json'
res = subprocess.check_output(['powershell', '-Command', ps_cmd]).decode('utf-8', errors='ignore')

procs = json.loads(res)
if isinstance(procs, dict):
    procs = [procs]

print(f"Total language_server processes: {len(procs)}")
for p in procs:
    print(f"\n--- PID {p.get('ProcessId')} (Parent: {p.get('ParentProcessId')}, Created: {p.get('CreationDate')}) ---")
    print("  CMD:", p.get('CommandLine'))
