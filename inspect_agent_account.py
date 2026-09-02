import os, json, glob, re

home = os.path.expanduser("~")
appdata = os.environ.get('APPDATA', '')
localappdata = os.environ.get('LOCALAPPDATA', '')

paths_to_check = [
    os.path.join(home, '.gemini'),
    os.path.join(appdata, 'Antigravity IDE'),
    os.path.join(appdata, 'Antigravity'),
    os.path.join(localappdata, 'Antigravity IDE')
]

print("=== SEARCHING ALL GEMINI / ANTIGRAVITY CONFIG AND CREDENTIAL FILES ===")

found_files = []
for p in paths_to_check:
    if os.path.exists(p):
        for root, dirs, files in os.walk(p):
            for f in files:
                fp = os.path.join(root, f)
                # Skip large log directories or brain logs to focus on config/state/json/db
                if '.system_generated' in fp or 'brain' in fp:
                    continue
                if f.endswith('.json') or f.endswith('.txt') or f.endswith('.cfg') or f.endswith('.plist') or 'account' in f.lower() or 'auth' in f.lower() or 'state' in f.lower() or 'user' in f.lower():
                    found_files.append(fp)

print(f"Found {len(found_files)} potential config/auth files.")

for fp in found_files[:40]:
    try:
        size = os.path.getsize(fp)
        if size < 500000: # < 500KB
            with open(fp, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read()
                emails = re.findall(r'[\w\.-]+@[\w\.-]+\.\w+', content)
                if emails:
                    print(f"\n--- FILE: {fp} (Size: {size} bytes) ---")
                    print(f"Emails found: {set(emails)}")
                    for line in content.splitlines():
                        if any(term in line.lower() for term in ['email', 'active', 'user', 'account', 'auth']):
                            if len(line.strip()) < 200:
                                print(f"  > {line.strip()}")
    except Exception:
        pass
