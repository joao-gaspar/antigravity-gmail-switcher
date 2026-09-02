import os, sqlite3

vscdb = os.path.join(os.environ.get('APPDATA', ''), 'Antigravity IDE', 'User', 'globalStorage', 'state.vscdb')

print(f"Opening SQLite database {vscdb}...")

try:
    # Open in URI read-only mode so it works even if Antigravity IDE is open
    conn = sqlite3.connect(f"file:{vscdb}?mode=ro", uri=True)
    cursor = conn.cursor()
    cursor.execute("SELECT key, value FROM ItemTable")
    rows = cursor.fetchall()
    print(f"Total keys in ItemTable: {len(rows)}")
    for key, value in rows:
        if any(x in key.lower() for x in ['auth', 'user', 'account', 'email', 'codeium', 'gemini', 'state', 'login', 'token', 'profile']):
            val_str = str(value)[:200]
            print(f"KEY: {key}")
            print(f"  VAL: {val_str}\n")
    conn.close()
except Exception as e:
    print("Error querying state.vscdb:", e)
