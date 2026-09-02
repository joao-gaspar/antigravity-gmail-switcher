import os, json, glob, re

appdata = os.environ.get('APPDATA', '')
target_dir = os.path.join(appdata, 'Antigravity IDE', 'User', 'globalStorage')

print(f"Scanning {target_dir}...")

for root, dirs, files in os.walk(target_dir):
    for f in files:
        fp = os.path.join(root, f)
        if f.endswith('.json') or f == 'storage.json':
            try:
                with open(fp, 'r', encoding='utf-8', errors='ignore') as file:
                    data = json.load(file)
                    print(f"\n=== {os.path.basename(fp)} ===")
                    if isinstance(data, dict):
                        for k, v in data.items():
                            if any(x in k.lower() for x in ['user', 'account', 'email', 'auth', 'gemini', 'codeium', 'token', 'profile']):
                                v_str = str(v)[:150]
                                print(f"  {k} => {v_str}")
            except Exception:
                pass
