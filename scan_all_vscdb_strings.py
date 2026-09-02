import os, sqlite3, re

vscdb = os.path.join(os.environ.get('APPDATA', ''), 'Antigravity IDE', 'User', 'globalStorage', 'state.vscdb')

conn = sqlite3.connect(f"file:{vscdb}?mode=ro", uri=True)
cursor = conn.cursor()
cursor.execute("SELECT key, value FROM ItemTable")
rows = cursor.fetchall()
conn.close()

print(f"Scanning {len(rows)} entries in state.vscdb...")

for key, value in rows:
    val_bytes = str(value).encode('utf-8') if not isinstance(value, bytes) else value
    emails = re.findall(rb'[\w\.-]+@[\w\.-]+\.\w+', val_bytes)
    if emails:
        print(f"\n[KEY] {key}")
        print(f"  Emails: {[e.decode('utf-8', errors='ignore') for e in set(emails)]}")
        printable = re.sub(rb'[^\x20-\x7E]', b' ', val_bytes).decode('utf-8', errors='ignore')
        print(f"  Snippet: {printable[:250]}")
