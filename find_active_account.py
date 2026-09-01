import os, json, glob, re

appdata = os.environ.get('APPDATA', '')
localappdata = os.environ.get('LOCALAPPDATA', '')
userprofile = os.environ.get('USERPROFILE', '')

targets = [
    os.path.join(appdata, 'Antigravity IDE', 'User', 'globalStorage'),
    os.path.join(appdata, 'Antigravity IDE', 'User'),
    os.path.join(userprofile, '.gemini'),
    os.path.join(userprofile, '.codeium'),
    os.path.join(localappdata, 'Programs', 'Antigravity IDE')
]

found = []
for t in targets:
    if os.path.exists(t):
        for root, dirs, files in os.walk(t):
            for f in files:
                if f.endswith('.json') or f.endswith('.log') or f.endswith('.txt') or f == 'state.vscdb':
                    fp = os.path.join(root, f)
                    try:
                        with open(fp, 'r', encoding='utf-8', errors='ignore') as file:
                            content = file.read()
                            if 'totalcad.com.br' in content or 'joao.gaspar' in content or 'aluno21' in content:
                                found.append((fp, content[:500]))
                    except Exception:
                        pass

print(f"Found {len(found)} matching files:")
for fp, snippet in found[:10]:
    print(f"--- {fp} ---")
