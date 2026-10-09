from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.rbac import Permission, Role

ROLE_PERMISSIONS: dict[str, set[str]] = {
    "Hospital Administrator": {
        "admin.dashboard", "audit.read", "users.manage", "patient.demographics.read", "patient.demographics.write",
        "patient.clinical.read", "patient.clinical.write", "doctors.read", "doctors.manage", "appointments.read",
        "appointments.create", "appointments.modify", "prescriptions.read", "prescriptions.create", "lab_results.upload",
        "documents.read", "documents.upload", "documents.ocr", "messages.read", "messages.send", "pharmacy.read",
        "pharmacy.manage", "billing.manage", "admissions.read", "admissions.manage",
    },
    "Doctor": {
        "patient.demographics.read", "patient.clinical.read", "patient.clinical.write", "doctors.read", "appointments.read",
        "appointments.create", "appointments.modify", "prescriptions.read", "prescriptions.create", "lab_results.upload",
        "documents.read", "documents.upload", "documents.ocr", "messages.read", "messages.send",
    },
    "Nurse": {
        "patient.demographics.read", "patient.demographics.write", "patient.clinical.read", "patient.clinical.write",
        "doctors.read", "appointments.read", "documents.read", "documents.upload", "documents.ocr", "messages.read", "messages.send",
    },
    "Receptionist": {
        "patient.demographics.read", "patient.demographics.write", "doctors.read", "appointments.read", "appointments.create",
        "appointments.modify", "messages.read", "messages.send", "admissions.read",
    },
    "Lab Technician": {
        "patient.demographics.read", "lab_results.upload", "documents.read", "documents.upload", "documents.ocr", "messages.read", "messages.send",
    },
    "Pharmacist": {
        "patient.demographics.read", "prescriptions.read", "pharmacy.read", "pharmacy.manage", "messages.read", "messages.send",
    },
    "Billing Staff": {"patient.demographics.read", "billing.manage"},
    "Support Staff": set(),
    # Patient/Caregiver permissions stay deliberately minimal until self-scope
    # object authorization is implemented. This is safer than tenant-wide read.
    "Patient": set(),
    "Caregiver": set(),
}

ACCOUNT_TYPE_TO_ROLE = {
    "doctor": "Doctor",
    "nurse": "Nurse",
    "receptionist": "Receptionist",
    "lab_technician": "Lab Technician",
    "pharmacist": "Pharmacist",
    "hospital_administrator": "Hospital Administrator",
    "billing_staff": "Billing Staff",
    "support_staff": "Support Staff",
    "patient": "Patient",
    "caregiver": "Caregiver",
}

STAFF_ACCOUNT_TYPES = {
    "doctor", "nurse", "receptionist", "lab_technician", "pharmacist",
    "hospital_administrator", "billing_staff", "support_staff",
}


def ensure_role(db: Session, role_name: str) -> Role:
    role = db.scalar(select(Role).where(Role.name == role_name))
    if not role:
        role = Role(name=role_name, description=f"Clinexa {role_name} role")
        db.add(role)
        db.flush()
    permission_codes = ROLE_PERMISSIONS.get(role_name, set())
    permissions = []
    for code in sorted(permission_codes):
        permission = db.scalar(select(Permission).where(Permission.code == code))
        if not permission:
            permission = Permission(code=code, description=code)
            db.add(permission)
            db.flush()
        permissions.append(permission)
    role.permissions = permissions
    return role


def ensure_standard_roles(db: Session) -> None:
    for role_name in ROLE_PERMISSIONS:
        ensure_role(db, role_name)
