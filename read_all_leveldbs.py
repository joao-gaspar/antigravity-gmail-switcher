import os, glob, re

appdata = os.environ.get('APPDATA', '')
localappdata = os.environ.get('LOCALAPPDATA', '')

paths = [
    os.path.join(appdata, 'Antigravity IDE'),
    os.path.join(localappdata, 'Antigravity IDE'),
    os.path.join(appdata, 'Code'),
    os.path.join(appdata, 'Antigravity')
]

emails_found = set()

for p in paths:
    if os.path.exists(p):
        for root, dirs, files in os.walk(p):
            for f in files:
                if f.endswith('.ldb') or f.endswith('.log') or f.endswith('.vscdb') or f == 'storage.json':
                    fp = os.path.join(root, f)
                    try:
                        with open(fp, 'rb') as file:
                            data = file.read()
                            matches = re.findall(rb'[\w\.-]+@[\w\.-]+\.\w+', data)
                            for m in matches:
                                email_str = m.decode('utf-8', errors='ignore')
                                if 'tilab.com' in email_str or 'totalcad.com' in email_str or 'gmail.com' in email_str or 'joaogaspar.com' in email_str:
                                    emails_found.add((email_str, fp))
                    except Exception:
                        pass

print(f"Total emails found: {len(emails_found)}")
for em, fp in sorted(emails_found):
    print(f"{em}  -->  {fp}")
