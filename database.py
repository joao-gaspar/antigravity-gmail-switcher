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
    return {
        "machine_id": get_machine_id(),
        "hostname": socket.gethostname(),
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
    rows = [dict(r) for r in cur.fetchall()]
    con.close()
    return rows

def upsert_account(machine_id, email, is_active, carousel_pos=999, status="available", reset_at=None):
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("""
        INSERT INTO machine_accounts (machine_id, email, is_active, carousel_pos, status, reset_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(machine_id, email) DO UPDATE SET
            is_active=excluded.is_active, carousel_pos=excluded.carousel_pos,
            status=excluded.status, reset_at=excluded.reset_at
    """, (machine_id, email, 1 if is_active else 0, carousel_pos, status, reset_at))
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

def compute_and_save_suggestion(machine_id, active_email, account_pool):
    candidates = [a for a in account_pool if a.get("email") != active_email]
    available = [c for c in candidates if c.get("status","available") == "available"]
    blocked   = sorted([c for c in candidates if c.get("status","available") != "available"],
                        key=lambda x: x.get("reset_at") or "9999")
    if available:
        suggestion = available[0].get("email")
        reason = "Conta disponivel sem limitacao de quota"
    elif blocked:
        suggestion = blocked[0].get("email")
        reason = f"Todas limitadas - renova em {blocked[0].get('reset_at','?')}"
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
