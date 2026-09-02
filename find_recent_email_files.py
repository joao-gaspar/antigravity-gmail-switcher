import os, time, re

home = os.path.expanduser("~")
appdata = os.environ.get('APPDATA', '')
localappdata = os.environ.get('LOCALAPPDATA', '')

directories = [
    os.path.join(home, '.gemini'),
    os.path.join(appdata, 'Antigravity IDE'),
    os.path.join(localappdata, 'Antigravity IDE'),
    os.path.join(localappdata, 'Google')
]

now = time.time()
cutoff = now - (48 * 3600) # last 48 hours

print(f"Scanning files modified in the last 48 hours...")

found = []
for d in directories:
    if os.path.exists(d):
        for root, dirs, files in os.walk(d):
            # Skip brain logs and node_modules to avoid noise
            if '.system_generated' in root or 'brain' in root or 'node_modules' in root:
                continue
            for f in files:
                fp = os.path.join(root, f)
                try:
                    mtime = os.path.getmtime(fp)
                    if mtime >= cutoff:
                        size = os.path.getsize(fp)
                        if 0 < size < 10000000: # < 10MB
                            with open(fp, 'rb') as file:
                                content = file.read()
                                matches = re.findall(rb'[\w\.-]+@[\w\.-]+\.\w+', content)
                                if matches:
                                    emails = set([m.decode('utf-8', errors='ignore') for m in matches])
                                    # Filter out placeholder emails
                                    valid_emails = [e for e in emails if not any(x in e for x in ['example.com', 'schema.org', 'institution.edu', 'w3.org'])]
                                    if valid_emails:
                                        found.append((mtime, fp, valid_emails, content[:300]))
                except Exception:
                    pass

found.sort(key=lambda x: x[0], reverse=True)
print(f"Found {len(found)} recently modified files with valid emails:")
for mtime, fp, emails, snippet in found[:25]:
    mtime_str = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(mtime))
    print(f"\n[{mtime_str}] {fp}")
    print(f"  EMAILS: {emails}")
