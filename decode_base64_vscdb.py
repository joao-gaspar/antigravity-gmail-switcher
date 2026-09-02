import os, sqlite3, base64, re

vscdb = os.path.join(os.environ.get('APPDATA', ''), 'Antigravity IDE', 'User', 'globalStorage', 'state.vscdb')

conn = sqlite3.connect(f"file:{vscdb}?mode=ro", uri=True)
cursor = conn.cursor()
cursor.execute("SELECT key, value FROM ItemTable WHERE key LIKE '%userStatus%' OR key LIKE '%oauthToken%'")
rows = cursor.fetchall()
conn.close()

for key, value in rows:
    print(f"\n=================== KEY: {key} ===================")
    val_str = str(value)
    # Extract base64 chunks
    b64_matches = re.findall(r'[A-Za-z0-9+/=]{20,}', val_str)
    for b64 in b64_matches:
        try:
            decoded = base64.b64decode(b64)
            emails = re.findall(rb'[\w\.-]+@[\w\.-]+\.\w+', decoded)
            if emails:
                print("FOUND EMAILS IN BASE64:", [e.decode('utf-8') for e in set(emails)])
            printable = re.sub(rb'[^\x20-\x7E]', b' ', decoded)
            printable_str = printable.decode('utf-8', errors='ignore')
            for chunk in printable_str.split('  '):
                if any(x in chunk.lower() for x in ['email', 'user', 'name', 'account', 'gmail', 'tilab', 'totalcad', '@']):
                    if len(chunk.strip()) > 3:
                        print("  CHUNK:", chunk.strip())
        except Exception:
            pass
