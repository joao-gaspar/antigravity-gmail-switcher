"""
database.py — SQLite data layer for Antigravity Quota Monitor
Tracks: machines, per-machine account pools, quota snapshots, suggestions.
"""
import sqlite3
import os
import socket
import platform
import uuid
import datetime

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "quota_monitor.db")
MACHINE_ID_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "machine_id.txt")

def get_machine_id():
    if os.path.exists(MACHINE_ID_FILE):
        try:
            with open(MACHINE_ID_FILE, "r", encoding="utf-8") as f:
                mid = f.read().strip()
                if mid:
                    return mid
        except Exception:
            pass
    mid = str(uuid.uuid4())
    with open(MACHINE_ID_FILE, "w", encoding="utf-8") as f:
        f.write(mid)
    return mid

def _get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def get_machine_info():
    hostname = os.environ.get("COMPUTERNAME") or socket.gethostname()
    return {
        "machine_id": get_machine_id(),
        "hostname": hostname,
        "ip": _get_local_ip(),
        "os": platform.platform()
    }

def init_db():
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.executescript("""
        CREATE TABLE IF NOT EXISTS machines (
            machine_id  TEXT PRIMARY KEY,
            hostname    TEXT,
            ip          TEXT,
            os          TEXT,
            first_seen  TEXT,
            last_seen   TEXT
        );
        CREATE TABLE IF NOT EXISTS machine_accounts (
            machine_id    TEXT,
            email         TEXT,
            name          TEXT,
            category      TEXT,
            avatar_url    TEXT,
            theme         TEXT,
            notes         TEXT,
            is_active     INTEGER DEFAULT 0,
            carousel_pos  INTEGER DEFAULT 999,
            status        TEXT DEFAULT "available",
            reset_at      TEXT,
            PRIMARY KEY (machine_id, email)
        );
        CREATE TABLE IF NOT EXISTS quota_snapshots (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            machine_id   TEXT,
            email        TEXT,
            ts           TEXT,
            gemini_pct   REAL,
            claude_pct   REAL,
            gpt_pct      REAL,
            reset_at     TEXT
        );
        CREATE TABLE IF NOT EXISTS suggestions (
            machine_id       TEXT PRIMARY KEY,
            suggested_email  TEXT,
            reason           TEXT,
            ts               TEXT
        );
    """)
    con.commit()
    con.close()

def _now():
    return datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")

def upsert_machine(machine_id, hostname, ip, os_str):
    now = _now()
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("""
        INSERT INTO machines (machine_id, hostname, ip, os, first_seen, last_seen)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(machine_id) DO UPDATE SET
            hostname=excluded.hostname, ip=excluded.ip, last_seen=excluded.last_seen
    """, (machine_id, hostname, ip, os_str, now, now))
    con.commit()
    con.close()

def list_machines():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    cur = con.cursor()
    cur.execute("SELECT * FROM machines ORDER BY last_seen DESC")
    machines = [dict(r) for r in cur.fetchall()]
    
    # Attach per-machine accounts
    for m in machines:
        cur.execute("""
            SELECT * FROM machine_accounts
            WHERE machine_id = ?
            ORDER BY carousel_pos ASC
        """, (m['machine_id'],))
        m['accounts'] = [dict(a) for a in cur.fetchall()]
    con.close()
    return machines

def get_all_machine_accounts():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    cur = con.cursor()
    cur.execute("SELECT * FROM machine_accounts ORDER BY machine_id, carousel_pos ASC")
    rows = [dict(r) for r in cur.fetchall()]
    con.close()
    return rows

def upsert_account(machine_id, email, is_active, carousel_pos=999, status="available", reset_at=None, name=None, category=None, avatar_url=None, theme=None, notes=None):
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    
    # Safely migration check for missing columns if DB exists
    for col in ['name', 'category', 'avatar_url', 'theme', 'notes']:
        try:
            cur.execute(f"ALTER TABLE machine_accounts ADD COLUMN {col} TEXT")
        except Exception:
            pass

    cur.execute("""
        INSERT INTO machine_accounts (machine_id, email, name, category, avatar_url, theme, notes, is_active, carousel_pos, status, reset_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(machine_id, email) DO UPDATE SET
            name=COALESCE(excluded.name, machine_accounts.name),
            category=COALESCE(excluded.category, machine_accounts.category),
            avatar_url=COALESCE(excluded.avatar_url, machine_accounts.avatar_url),
            theme=COALESCE(excluded.theme, machine_accounts.theme),
            notes=COALESCE(excluded.notes, machine_accounts.notes),
            is_active=excluded.is_active,
            carousel_pos=excluded.carousel_pos,
            status=excluded.status,
            reset_at=excluded.reset_at
    """, (machine_id, email, name, category, avatar_url, theme, notes, 1 if is_active else 0, carousel_pos, status, reset_at))
    con.commit()
    con.close()

def save_snapshot(machine_id, email, gemini_pct, claude_pct, gpt_pct, reset_at=None):
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("""
        INSERT INTO quota_snapshots (machine_id, email, ts, gemini_pct, claude_pct, gpt_pct, reset_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (machine_id, email, _now(), gemini_pct, claude_pct, gpt_pct, reset_at))
    con.commit()
    con.close()

def get_all_latest_snapshots():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    cur = con.cursor()
    cur.execute("""
        SELECT q.* FROM quota_snapshots q
        INNER JOIN (
            SELECT machine_id, email, MAX(ts) as max_ts
            FROM quota_snapshots GROUP BY machine_id, email
        ) latest ON q.machine_id=latest.machine_id AND q.email=latest.email AND q.ts=latest.max_ts
        ORDER BY q.machine_id, q.gemini_pct DESC
    """)
    rows = [dict(r) for r in cur.fetchall()]
    con.close()
    return rows

def _account_capacity_score(acc):
    """Lower score = more tokens consumed = less capacity.
    We invert: higher return value = more remaining capacity.
    tokenGemini/Claude/Gpt represent usage (0-100 scale); lower = less used = more free."""
    used = (acc.get("tokenGemini") or 0) + (acc.get("tokenClaude") or 0) + (acc.get("tokenGpt") or 0)
    return -used  # negate so sort ascending = best first


def compute_and_save_suggestion(machine_id, active_email, account_pool):
    candidates = [a for a in account_pool if a.get("email") != active_email]

    available = [c for c in candidates if c.get("status", "available") == "available"]
    blocked   = [c for c in candidates if c.get("status", "available") != "available"]

    # Available: sort by most remaining capacity (least consumed first)
    available_sorted = sorted(available, key=_account_capacity_score, reverse=True)

    # Blocked: sort by earliest reset_at (soonest back online first)
    def _reset_key(x):
        r = x.get("reset_at")
        return r if r else "9999-99-99"
    blocked_sorted = sorted(blocked, key=_reset_key)

    if available_sorted:
        best = available_sorted[0]
        used_pct = (
            (best.get("tokenGemini") or 0)
            + (best.get("tokenClaude") or 0)
            + (best.get("tokenGpt") or 0)
        ) // 3
        remaining = max(0, 100 - used_pct)
        suggestion = best.get("email")
        reason = f"Maior capacidade restante (~{remaining}% livre)"
    elif blocked_sorted:
        best = blocked_sorted[0]
        suggestion = best.get("email")
        reason = f"Menor prazo de retorno - renova em {best.get('reset_at', '?')}"
    else:
        suggestion = None
        reason = "Nenhuma conta alternativa disponivel"

    now = _now()
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("""
        INSERT INTO suggestions (machine_id, suggested_email, reason, ts)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(machine_id) DO UPDATE SET
            suggested_email=excluded.suggested_email, reason=excluded.reason, ts=excluded.ts
    """, (machine_id, suggestion, reason, now))
    con.commit()
    con.close()
    return {"email": suggestion, "reason": reason, "ts": now}

init_db()
print("database.py OK — DB at:", DB_PATH)
