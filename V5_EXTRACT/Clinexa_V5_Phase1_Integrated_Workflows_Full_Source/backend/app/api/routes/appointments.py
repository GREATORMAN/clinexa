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

@router.get("")
def list_appointments(db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.read"))):
    return db.scalars(select(Appointment).where(Appointment.hospital_id == tenant_id(user)).order_by(Appointment.start_at.desc()).limit(300)).all()

@router.post("", status_code=201)
def create_appointment(payload: AppointmentCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.create"))):
    h = tenant_id(user)
    if not db.scalar(select(Patient).where(Patient.id == payload.patient_id, Patient.hospital_id == h)):
        raise HTTPException(status_code=400, detail="Invalid patient")
    if not db.scalar(select(Doctor).where(Doctor.id == payload.doctor_id, Doctor.hospital_id == h)):
        raise HTTPException(status_code=400, detail="Invalid doctor")
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
    conflict = db.scalar(select(Appointment).where(Appointment.doctor_id == row.doctor_id, Appointment.start_at == payload.start_at, Appointment.id != row.id))
    if conflict:
        raise HTTPException(status_code=409, detail="That doctor already has an appointment at this time")
    row.start_at = payload.start_at; row.status = "rescheduled"
    log_action(db, user.id, "appointment.reschedule", "appointment", row.id, metadata={"start_at": payload.start_at})
    db.commit(); db.refresh(row); return row

@router.get("/queue/active")
def queue(db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.read"))):
    return db.scalars(select(Appointment).where(Appointment.hospital_id == tenant_id(user), Appointment.status.in_(["checked_in", "waiting", "in_consultation"])).order_by(Appointment.start_at)).all()
