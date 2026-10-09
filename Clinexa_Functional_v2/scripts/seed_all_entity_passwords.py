import sys
import sqlite3
from pathlib import Path
from uuid import uuid4
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "backend"))
from app.core.security import hash_password

TARGET_PASSWORD = "Default@9876543"
hashed_target = hash_password(TARGET_PASSWORD)

db_paths = [
    Path("backend/clinexa_dev.db").resolve(),
    Path("webapp/backend/clinexa_dev.db").resolve(),
]

DOCTOR_ACCOUNTS = [
    {"name": "sam j", "email": "sam.j@clinexa.com", "specialty": "Cardiology"},
    {"name": "Dr. Aanya Rao", "email": "aanya.rao@clinexa.com", "specialty": "Internal Medicine"},
    {"name": "Dr. Kiran Mehta", "email": "kiran.mehta@clinexa.com", "specialty": "Cardiology"},
    {"name": "Dr. Meera Iyer", "email": "meera.iyer@clinexa.com", "specialty": "Pediatrics"},
    {"name": "Dr. Dev Malhotra", "email": "dev.malhotra@clinexa.com", "specialty": "Orthopedics"},
    {"name": "Dr. Nila Sen", "email": "nila.sen@clinexa.com", "specialty": "Neurology"},
    {"name": "Dr. Arjun Nair", "email": "arjun.nair@clinexa.com", "specialty": "Dermatology"},
]

STAFF_ACCOUNTS = [
    {"name": "Nurse Sarah Jenkins", "email": "nurse@clinexa.com", "role": "Nurse", "account_type": "nurse"},
    {"name": "Alex Vance", "email": "lab.tech@clinexa.com", "role": "Lab Technician", "account_type": "lab_technician"},
    {"name": "Elena Rostova", "email": "pharmacist@clinexa.com", "role": "Pharmacist", "account_type": "pharmacist"},
    {"name": "David Miller", "email": "receptionist@clinexa.com", "role": "Receptionist", "account_type": "receptionist"},
    {"name": "Rachel Zane", "email": "billing@clinexa.com", "role": "Billing Staff", "account_type": "billing_staff"},
]

for db_path in db_paths:
    if not db_path.exists():
        print(f"Skipping non-existent DB: {db_path}")
        continue

    print(f"\nProcessing database: {db_path}")
    con = sqlite3.connect(db_path)
    cur = con.cursor()

    # Get hospital id
    cur.execute("SELECT id FROM hospitals LIMIT 1")
    row = cur.fetchone()
    hospital_id = row[0] if row else str(uuid4())

    # Get roles mapping: name -> id
    cur.execute("SELECT name, id FROM roles")
    roles = {r[0]: r[1] for r in cur.fetchall()}

    # Update any existing users (except vishal and kani)
    cur.execute(
        "UPDATE users SET password_hash = ? WHERE lower(email) NOT IN ('vishal@gmail.com', 'kani@gmail.com')",
        (hashed_target,)
    )
    print(f"Updated existing non-vishal/kani users in {db_path.name}")

    now_str = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")

    # 1. Setup Doctor Users and link to Doctor records
    cur.execute("SELECT id, full_name, specialty FROM doctors")
    db_doctors = cur.fetchall()

    for doc_id, doc_name, doc_spec in db_doctors:
        # Match configured email or generate one
        matching = next((d for d in DOCTOR_ACCOUNTS if d["name"].lower() in doc_name.lower() or doc_name.lower() in d["name"].lower()), None)
        if matching:
            doc_email = matching["email"]
        else:
            clean_name = doc_name.lower().replace("dr.", "").strip().replace(" ", ".")
            doc_email = f"{clean_name}@clinexa.com"

        # Check if user exists
        cur.execute("SELECT id FROM users WHERE lower(email) = ?", (doc_email.lower(),))
        user_row = cur.fetchone()
        if user_row:
            u_id = user_row[0]
            cur.execute("UPDATE users SET password_hash = ?, is_active = 1, is_verified = 1, is_staff = 1 WHERE id = ?", (hashed_target, u_id))
        else:
            u_id = str(uuid4())
            cur.execute(
                "INSERT INTO users (id, email, full_name, password_hash, hospital_id, is_active, is_verified, is_staff, created_at) "
                "VALUES (?, ?, ?, ?, ?, 1, 1, 1, ?)",
                (u_id, doc_email.lower(), doc_name, hashed_target, hospital_id, now_str)
            )

        # Assign Doctor role
        if "Doctor" in roles:
            cur.execute("DELETE FROM user_roles WHERE user_id = ? AND role_id = ?", (u_id, roles["Doctor"]))
            cur.execute("INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)", (u_id, roles["Doctor"]))

        # Link in user_account_profiles
        cur.execute("SELECT id FROM user_account_profiles WHERE user_id = ?", (u_id,))
        prof_row = cur.fetchone()
        if prof_row:
            cur.execute(
                "UPDATE user_account_profiles SET account_type = 'doctor', approval_status = 'approved', doctor_id = ?, specialty = ?, approved_at = ? WHERE user_id = ?",
                (doc_id, doc_spec, now_str, u_id)
            )
        else:
            cur.execute(
                "INSERT INTO user_account_profiles (id, user_id, account_type, approval_status, specialty, doctor_id, requested_at, approved_at) "
                "VALUES (?, ?, 'doctor', 'approved', ?, ?, ?, ?)",
                (str(uuid4()), u_id, doc_spec, doc_id, now_str, now_str)
            )
        print(f"Doctor configured: {doc_name} -> {doc_email}")

    # 2. Setup Patient Users for existing demo patients
    cur.execute("SELECT id, full_name, email FROM patients WHERE lower(email) != 'kani@gmail.com'")
    patients = cur.fetchall()

    for p_id, p_name, p_email in patients:
        valid_email = p_email
        if "@example.invalid" in p_email or "@example.com" in p_email:
            valid_email = f"{p_name.lower().replace(' ', '.')}@clinexa.com"
            cur.execute("UPDATE patients SET email = ? WHERE id = ?", (valid_email, p_id))

        cur.execute("SELECT id FROM users WHERE lower(email) = ?", (valid_email.lower(),))
        user_row = cur.fetchone()
        if user_row:
            u_id = user_row[0]
            cur.execute("UPDATE users SET password_hash = ?, is_active = 1, is_verified = 1 WHERE id = ?", (hashed_target, u_id))
        else:
            u_id = str(uuid4())
            cur.execute(
                "INSERT INTO users (id, email, full_name, password_hash, hospital_id, is_active, is_verified, is_staff, created_at) "
                "VALUES (?, ?, ?, ?, ?, 1, 1, 0, ?)",
                (u_id, valid_email.lower(), p_name, hashed_target, hospital_id, now_str)
            )

        if "Patient" in roles:
            cur.execute("DELETE FROM user_roles WHERE user_id = ? AND role_id = ?", (u_id, roles["Patient"]))
            cur.execute("INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)", (u_id, roles["Patient"]))

        cur.execute("SELECT id FROM user_account_profiles WHERE user_id = ?", (u_id,))
        prof_row = cur.fetchone()
        if prof_row:
            cur.execute(
                "UPDATE user_account_profiles SET account_type = 'patient', approval_status = 'approved', patient_id = ?, approved_at = ? WHERE user_id = ?",
                (p_id, now_str, u_id)
            )
        else:
            cur.execute(
                "INSERT INTO user_account_profiles (id, user_id, account_type, approval_status, patient_id, requested_at, approved_at) "
                "VALUES (?, ?, 'patient', 'approved', ?, ?, ?)",
                (str(uuid4()), u_id, p_id, now_str, now_str)
            )

    # 3. Setup Hospital Staff (Nurse, Lab, Pharmacist, Receptionist, Billing)
    for staff in STAFF_ACCOUNTS:
        s_email = staff["email"]
        s_name = staff["name"]
        s_role = staff["role"]
        s_type = staff["account_type"]

        cur.execute("SELECT id FROM users WHERE lower(email) = ?", (s_email.lower(),))
        user_row = cur.fetchone()
        if user_row:
            u_id = user_row[0]
            cur.execute("UPDATE users SET password_hash = ?, is_active = 1, is_verified = 1, is_staff = 1 WHERE id = ?", (hashed_target, u_id))
        else:
            u_id = str(uuid4())
            cur.execute(
                "INSERT INTO users (id, email, full_name, password_hash, hospital_id, is_active, is_verified, is_staff, created_at) "
                "VALUES (?, ?, ?, ?, ?, 1, 1, 1, ?)",
                (u_id, s_email.lower(), s_name, hashed_target, hospital_id, now_str)
            )

        if s_role in roles:
            cur.execute("DELETE FROM user_roles WHERE user_id = ? AND role_id = ?", (u_id, roles[s_role]))
            cur.execute("INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)", (u_id, roles[s_role]))

        cur.execute("SELECT id FROM user_account_profiles WHERE user_id = ?", (u_id,))
        prof_row = cur.fetchone()
        if prof_row:
            cur.execute(
                "UPDATE user_account_profiles SET account_type = ?, approval_status = 'approved', approved_at = ? WHERE user_id = ?",
                (s_type, now_str, u_id)
            )
        else:
            cur.execute(
                "INSERT INTO user_account_profiles (id, user_id, account_type, approval_status, requested_at, approved_at) "
                "VALUES (?, ?, ?, 'approved', ?, ?)",
                (str(uuid4()), u_id, s_type, now_str, now_str)
            )
        print(f"Staff configured: {s_name} ({s_role}) -> {s_email}")

    con.commit()
    con.close()
    print(f"Database {db_path.name} updated successfully with password: {TARGET_PASSWORD}")
