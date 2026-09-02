import os, sqlite3, re, base64

vscdb = os.path.join(os.environ.get('APPDATA', ''), 'Antigravity IDE', 'User', 'globalStorage', 'state.vscdb')

conn = sqlite3.connect(f"file:{vscdb}?mode=ro", uri=True)
cursor = conn.cursor()
cursor.execute("SELECT key, value FROM ItemTable WHERE key LIKE '%userStatus%' OR key LIKE '%oauthToken%'")
rows = cursor.fetchall()
conn.close()

for key, value in rows:
    print(f"\n=================== KEY: {key} ===================")
    val_bytes = value if isinstance(value, bytes) else str(value).encode('utf-8')
    print("RAW BYTES/STRING:")
    print(val_bytes[:300])
    
    # Search for emails in the raw bytes
    emails = re.findall(rb'[\w\.-]+@[\w\.-]+\.\w+', val_bytes)
    if emails:
        print("\nEmails found:", [e.decode('utf-8', errors='ignore') for e in set(emails)])
    
    # Try decoding JSON inside base64 or protobuf strings
    matches = re.findall(rb'\{[^{}]*"(?:email|user|name|token|state|emailAddress|account)"[^{}]*\}', val_bytes)
    for m in matches:
        print("FOUND JSON:", m.decode('utf-8', errors='ignore'))
