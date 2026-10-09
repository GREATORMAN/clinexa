from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.core.audit import log_action
from app.models.user import User
from app.models.clinical import Appointment, Patient, Doctor
from app.schemas.domain import AppointmentCreate, AppointmentStatusUpdate, AppointmentReschedule

router = APIRouter(prefix="/appointments", tags=["Appointments"])
ALLOWED = {"requested", "confirmed", "checked_in", "waiting", "in_consultation", "completed", "cancelled", "no_show", "rescheduled"}

TRANSITIONS = {
    "requested": {"confirmed", "cancelled"},
    "confirmed": {"checked_in", "no_show", "cancelled"},
    "rescheduled": {"checked_in", "no_show", "cancelled"},
    "checked_in": {"waiting", "in_consultation", "cancelled"},
    "waiting": {"in_consultation", "no_show", "cancelled"},
    "in_consultation": {"completed", "cancelled"},
    "completed": set(), "cancelled": set(), "no_show": set(),
}


def check_slot(db, doctor, start_at, exclude=None):
    # Existing appointment timestamps are hospital-local, without timezone.
    if start_at.tzinfo is not None:
        raise HTTPException(422, "Use hospital-local appointment time without timezone")
    if start_at < datetime.now():
        raise HTTPException(422, "Choose a future appointment time")
    duration = timedelta(minutes=max(1, doctor.consultation_minutes))
    query = select(Appointment).where(Appointment.doctor_id == doctor.id,
        Appointment.start_at > start_at - duration, Appointment.start_at < start_at + duration)
    if exclude:
        query = query.where(Appointment.id != exclude)
    for other in db.scalars(query):
        if other.status not in {"cancelled", "no_show"} or other.start_at == start_at:
            raise HTTPException(409, "This time overlaps an existing appointment. Choose another slot.")

@router.get("")
def list_appointments(db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.read"))):
    return db.scalars(select(Appointment).where(Appointment.hospital_id == tenant_id(user)).order_by(Appointment.start_at.desc()).limit(300)).all()

@router.post("", status_code=201)
def create_appointment(payload: AppointmentCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.create"))):
    h = tenant_id(user)
    if not db.scalar(select(Patient).where(Patient.id == payload.patient_id, Patient.hospital_id == h)):
        raise HTTPException(status_code=400, detail="Invalid patient")
    doctor = db.scalar(select(Doctor).where(Doctor.id == payload.doctor_id, Doctor.hospital_id == h, Doctor.is_active == True))
    if not doctor:
        raise HTTPException(status_code=400, detail="Invalid doctor")
    check_slot(db, doctor, payload.start_at)
    row = Appointment(hospital_id=h, created_by_user_id=user.id, status="confirmed", **payload.model_dump())
    db.add(row)
    try:
        db.flush()
    except IntegrityError:
        db.rollback(); raise HTTPException(status_code=409, detail="That doctor already has an appointment at this time")
    log_action(db, user.id, "appointment.create", "appointment", row.id)
    db.commit(); db.refresh(row); return row

@router.patch("/{appointment_id}/status")
def set_status(appointment_id: str, payload: AppointmentStatusUpdate, db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.modify"))):
    if payload.status not in ALLOWED:
        raise HTTPException(status_code=400, detail="Invalid appointment status")
    row = db.scalar(select(Appointment).where(Appointment.id == appointment_id, Appointment.hospital_id == tenant_id(user)))
    if not row:
        raise HTTPException(status_code=404, detail="Appointment not found")
    if payload.status != row.status and payload.status not in TRANSITIONS.get(row.status, set()):
        raise HTTPException(409, f"Cannot move {row.status} to {payload.status}")
    row.status = payload.status
    if payload.status in {"checked_in", "waiting"} and not row.queue_token:
        row.queue_token = f"Q-{row.id[:5].upper()}"
    log_action(db, user.id, "appointment.status", "appointment", row.id, metadata={"status": payload.status})
    db.commit(); db.refresh(row); return row

@router.patch("/{appointment_id}/reschedule")
def reschedule(appointment_id: str, payload: AppointmentReschedule, db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.modify"))):
    row = db.scalar(select(Appointment).where(Appointment.id == appointment_id, Appointment.hospital_id == tenant_id(user)))
    if not row:
        raise HTTPException(status_code=404, detail="Appointment not found")
    if row.status in {"completed", "cancelled", "no_show", "in_consultation"}:
        raise HTTPException(409, "This visit cannot be rescheduled")
    doctor = db.get(Doctor, row.doctor_id)
    if not doctor or not doctor.is_active:
        raise HTTPException(409, "Doctor is unavailable")
    check_slot(db, doctor, payload.start_at, row.id)
    row.start_at = payload.start_at; row.status = "rescheduled"
    log_action(db, user.id, "appointment.reschedule", "appointment", row.id, metadata={"start_at": payload.start_at})
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "That time was just booked. Choose another slot.")
    db.refresh(row); return row

@router.get("/queue/active")
def queue(db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.read"))):
    return db.scalars(select(Appointment).where(Appointment.hospital_id == tenant_id(user), Appointment.status.in_(["checked_in", "waiting", "in_consultation"])).order_by(Appointment.start_at)).all()
