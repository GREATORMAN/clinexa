import sqlite3
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
db_path = root / "backend" / "clinexa_dev.db"

con = sqlite3.connect(db_path)
cur = con.cursor()

query = """
SELECT 
    u.id,
    u.email,
    u.full_name,
    u.is_active,
    u.is_staff,
    COALESCE(p.account_type, 'None') as account_type,
    COALESCE(p.approval_status, 'None') as approval_status,
    COALESCE(p.specialty, d.specialty, '') as specialty,
    u.created_at
FROM users u
LEFT JOIN user_account_profiles p ON u.id = p.user_id
LEFT JOIN doctors d ON p.doctor_id = d.id
ORDER BY u.created_at ASC
"""

cur.execute(query)
rows = cur.fetchall()

data = []
md_lines = [
    "# Clinexa Registered Users in Database (`clinexa_dev.db`)",
    "",
    f"Total Users Found: **{len(rows)}**",
    "",
    "| # | Name | Email | Account Type | Role Status | Specialty |",
    "| :--- | :--- | :--- | :--- | :--- | :--- |",
]

for i, r in enumerate(rows, 1):
    u_id, email, name, is_active, is_staff, acc_type, approval, specialty, created_at = r
    data.append({
        "id": u_id,
        "name": name,
        "email": email,
        "account_type": acc_type,
        "approval_status": approval,
        "specialty": specialty,
        "is_staff": bool(is_staff),
        "is_active": bool(is_active),
        "created_at": created_at,
    })
    md_lines.append(f"| {i} | **{name}** | `{email}` | {acc_type} | {approval} | {specialty or '—'} |")

md_content = "\n".join(md_lines) + "\n"
json_content = json.dumps(data, indent=2)

# Write to root and backend and webapp
(root / "DATABASE_USERS.md").write_text(md_content, encoding="utf-8")
(root / "backend" / "users_export.json").write_text(json_content, encoding="utf-8")
(root / "webapp" / "backend" / "users_export.json").write_text(json_content, encoding="utf-8")
(root / "webapp" / "DATABASE_USERS.md").write_text(md_content, encoding="utf-8")

print(f"Exported {len(rows)} users to DATABASE_USERS.md and users_export.json")
