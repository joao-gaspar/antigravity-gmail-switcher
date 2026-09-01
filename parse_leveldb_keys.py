import os, glob, re

leveldb_dir = os.path.join(os.environ.get('APPDATA', ''), 'Antigravity IDE', 'Local Storage', 'leveldb')

log_files = glob.glob(os.path.join(leveldb_dir, '*.log')) + glob.glob(os.path.join(leveldb_dir, '*.ldb'))

print(f"Scanning {len(log_files)} files in leveldb...")

key_matches = []
for f in log_files:
    try:
        with open(f, 'rb') as file:
            content = file.read()
            # Search for JSON or text snippets near emails
            for m in re.finditer(rb'\{[^{}]*"(?:email|user|active|token|status)"[^{}]*\}', content):
                snippet = m.group(0).decode('utf-8', errors='ignore')
                key_matches.append((f, snippet))
    except Exception as e:
        print("Error reading:", f, e)

print(f"Found {len(key_matches)} JSON snippets in leveldb:")
for f, snip in key_matches[:20]:
    print(f"[{os.path.basename(f)}] {snip}")
