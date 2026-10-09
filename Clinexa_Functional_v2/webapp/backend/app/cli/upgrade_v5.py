from sqlalchemy import select

from app.core.database import Base, engine, SessionLocal
from app.core.rbac_seed import ensure_standard_roles
from app.models.account import UserAccountProfile
from app.models.clinical import Doctor
from app.models.medication import PatientMedication
from app.models.records import Prescription
from app.models.user import User
import app.models  # noqa: F401


def infer_account_type(user: User) -> str:
    names = {r.name.lower() for r in user.roles}
    if "super administrator" in names or "hospital administrator" in names:
        return "hospital_administrator"
    mapping = {
        "doctor": "doctor",
        "nurse": "nurse",
        "receptionist": "receptionist",
        "lab technician": "lab_technician",
        "pharmacist": "pharmacist",
        "billing staff": "billing_staff",
        "support staff": "support_staff",
        "patient": "patient",
        "caregiver": "caregiver",
    }
    for role_name, account_type in mapping.items():
        if role_name in names:
            return account_type
    return "hospital_administrator" if user.is_staff else "patient"


def main() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        ensure_standard_roles(db)
        profile_count = 0
        medication_count = 0

        for user in db.scalars(select(User)).all():
            profile = db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id == user.id))
            if not profile:
                db.add(
                    UserAccountProfile(
                        user_id=user.id,
                        account_type=infer_account_type(user),
                        approval_status="approved" if user.roles else "pending",
                    )
                )
                profile_count += 1

        for rx in db.scalars(select(Prescription)).all():
            existing = db.scalar(
                select(PatientMedication).where(
                    PatientMedication.source_type == "electronic_prescription",
                    PatientMedication.source_id == rx.id,
                )
            )
            if existing:
                continue
            doctor = db.get(Doctor, rx.doctor_id) if rx.doctor_id else None
            db.add(
                PatientMedication(
                    patient_id=rx.patient_id,
                    source_type="electronic_prescription",
                    source_id=rx.id,
                    medication_name=rx.medication_name,
                    strength=rx.strength,
                    form=rx.form,
                    frequency=rx.frequency,
                    duration=rx.duration,
                    instructions=rx.instructions,
                    prescribing_doctor_text=doctor.full_name if doctor else None,
                    status="active" if rx.status in {"active", "demo"} else rx.status,
                    verified=True,
                )
            )
            medication_count += 1

        db.commit()
        print("Clinexa V5 upgrade complete.")
        print(f"New account profiles: {profile_count}")
        print(f"Backfilled patient medicines: {medication_count}")
        print("New OCR prescription and medication-centre tables are ready.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
