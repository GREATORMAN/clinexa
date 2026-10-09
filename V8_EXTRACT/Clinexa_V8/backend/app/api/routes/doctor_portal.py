from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.account import UserAccountProfile
from app.models.user import User
from app.models.clinical import Doctor, Patient, Appointment, Encounter
from app.models.advanced import LabOrder

router = APIRouter(prefix="/doctor", tags=["Doctor Workspace"])


def _doctor_profile(db: Session, user: User) -> tuple[UserAccountProfile, Doctor]:
    profile = db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id == user.id))
    if not profile or profile.account_type != "doctor" or profile.approval_status != "approved" or not profile.doctor_id:
        raise HTTPException(status_code=403, detail="Approved doctor profile required")
    doctor = db.get(Doctor, profile.doctor_id)
    if not doctor or doctor.hospital_id != user.hospital_id:
        raise HTTPException(status_code=403, detail="Doctor profile unavailable")
    return profile, doctor


def _appointment_view(db: Session, appointment: Appointment) -> dict:
    patient = db.get(Patient, appointment.patient_id)
    return {
        "id": appointment.id,
        "patient_id": appointment.patient_id,
        "patient_name": patient.full_name if patient else "Patient",
        "patient_code": patient.patient_code if patient else "",
        "start_at": appointment.start_at,
        "appointment_type": appointment.appointment_type,
        "reason": appointment.reason,
        "status": appointment.status,
        "queue_token": appointment.queue_token,
    }


@router.get("/workspace")
def workspace(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, doctor = _doctor_profile(db, user)
    now = datetime.utcnow()
    start_day = datetime(now.year, now.month, now.day)
    end_day = start_day + timedelta(days=1)
    upcoming_end = now + timedelta(days=14)

    today_rows = db.scalars(
        select(Appointment)
        .where(Appointment.doctor_id == doctor.id, Appointment.start_at >= start_day, Appointment.start_at < end_day)
        .order_by(Appointment.start_at)
    ).all()
    upcoming_rows = db.scalars(
        select(Appointment)
        .where(
            Appointment.doctor_id == doctor.id,
            Appointment.start_at >= now,
            Appointment.start_at <= upcoming_end,
            Appointment.status.notin_(["cancelled", "completed", "no_show"]),
        )
        .order_by(Appointment.start_at)
        .limit(30)
    ).all()
    waiting_rows = [x for x in today_rows if x.status in {"checked_in", "waiting", "in_consultation"}]
    pending_labs = db.scalars(
        select(LabOrder)
        .where(LabOrder.doctor_id == doctor.id, LabOrder.status.in_(["ordered", "collected", "processing", "completed"]))
        .order_by(LabOrder.ordered_at.desc())
        .limit(25)
    ).all()
    encounters = db.scalars(
        select(Encounter)
        .where(Encounter.doctor_id == doctor.id)
        .order_by(Encounter.created_at.desc())
        .limit(30)
    ).all()

    recent_patients = []
    seen: set[str] = set()
    for encounter in encounters:
        if encounter.patient_id in seen:
            continue
        patient = db.get(Patient, encounter.patient_id)
        if patient:
            recent_patients.append({"id": patient.id, "full_name": patient.full_name, "patient_code": patient.patient_code, "last_seen": encounter.created_at})
            seen.add(patient.id)
        if len(recent_patients) >= 8:
            break

    return {
        "doctor": doctor,
        "today": [_appointment_view(db, x) for x in today_rows],
        "waiting": [_appointment_view(db, x) for x in waiting_rows],
        "upcoming": [_appointment_view(db, x) for x in upcoming_rows],
        "pending_labs": pending_labs,
        "recent_patients": recent_patients,
        "counts": {
            "today": len(today_rows),
            "waiting": len(waiting_rows),
            "upcoming": len(upcoming_rows),
            "pending_labs": len(pending_labs),
        },
    }
