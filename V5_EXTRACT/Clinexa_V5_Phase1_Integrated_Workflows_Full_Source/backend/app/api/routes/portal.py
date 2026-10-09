from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.audit import log_action
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.account import UserAccountProfile
from app.models.user import User
from app.models.clinical import Patient, Doctor, Appointment
from app.models.records import LabResult, MedicalDocument
from app.models.medication import PatientMedication, PrescriptionOcrDraft
from app.models.advanced import MedicationSchedule, MedicationDoseLog
from app.schemas.domain import MedicationDoseLogCreate, PortalAppointmentCreate, PortalAppointmentReschedule
from app.services.storage import path_for

router = APIRouter(prefix="/portal", tags=["Patient Portal"])


def _patient_profile(db: Session, user: User) -> tuple[UserAccountProfile, Patient]:
    profile = db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id == user.id))
    if not profile or profile.account_type != "patient" or not profile.patient_id:
        raise HTTPException(status_code=403, detail="Patient portal is not linked to this account")
    patient = db.get(Patient, profile.patient_id)
    if not patient or patient.hospital_id != user.hospital_id:
        raise HTTPException(status_code=403, detail="Patient profile unavailable")
    return profile, patient


@router.get("/home")
def home(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    appointments = db.scalars(
        select(Appointment).where(Appointment.patient_id == patient.id).order_by(Appointment.start_at.desc()).limit(50)
    ).all()
    medications = db.scalars(
        select(PatientMedication).where(PatientMedication.patient_id == patient.id).order_by(PatientMedication.created_at.desc()).limit(100)
    ).all()
    schedules = db.scalars(
        select(MedicationSchedule).where(MedicationSchedule.patient_id == patient.id).order_by(MedicationSchedule.created_at.desc()).limit(100)
    ).all()
    labs = db.scalars(
        select(LabResult).where(LabResult.patient_id == patient.id).order_by(LabResult.created_at.desc()).limit(30)
    ).all()
    documents = db.scalars(
        select(MedicalDocument).where(MedicalDocument.patient_id == patient.id).order_by(MedicalDocument.created_at.desc()).limit(30)
    ).all()
    ocr_imports = db.scalars(
        select(PrescriptionOcrDraft).where(PrescriptionOcrDraft.patient_id == patient.id).order_by(PrescriptionOcrDraft.created_at.desc()).limit(30)
    ).all()
    return {
        "patient": patient,
        "appointments": appointments,
        "medications": medications,
        "medication_schedules": schedules,
        "labs": labs,
        "documents": documents,
        "ocr_imports": ocr_imports,
    }


@router.get("/doctors")
def doctors(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    return db.scalars(
        select(Doctor).where(Doctor.hospital_id == patient.hospital_id, Doctor.is_active == True).order_by(Doctor.full_name)
    ).all()


@router.post("/appointments", status_code=201)
def create_appointment(payload: PortalAppointmentCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    doctor = db.scalar(select(Doctor).where(Doctor.id == payload.doctor_id, Doctor.hospital_id == patient.hospital_id, Doctor.is_active == True))
    if not doctor:
        raise HTTPException(400, "Invalid doctor")
    row = Appointment(
        hospital_id=patient.hospital_id,
        patient_id=patient.id,
        doctor_id=payload.doctor_id,
        start_at=payload.start_at,
        appointment_type=payload.appointment_type,
        reason=payload.reason,
        status="requested",
        created_by_user_id=user.id,
    )
    db.add(row)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "That doctor already has an appointment at this time")
    log_action(db, user.id, "portal.appointment.request", "appointment", row.id)
    db.commit(); db.refresh(row)
    return row


@router.patch("/appointments/{appointment_id}/reschedule")
def reschedule(appointment_id: str, payload: PortalAppointmentReschedule, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    row = db.scalar(select(Appointment).where(Appointment.id == appointment_id, Appointment.patient_id == patient.id))
    if not row:
        raise HTTPException(404, "Appointment not found")
    if row.status in {"completed", "cancelled", "no_show"}:
        raise HTTPException(409, "This appointment can no longer be rescheduled")
    conflict = db.scalar(select(Appointment).where(Appointment.doctor_id == row.doctor_id, Appointment.start_at == payload.start_at, Appointment.id != row.id))
    if conflict:
        raise HTTPException(409, "That doctor already has an appointment at this time")
    row.start_at = payload.start_at
    row.status = "requested"
    log_action(db, user.id, "portal.appointment.reschedule", "appointment", row.id, metadata={"start_at": payload.start_at})
    db.commit(); db.refresh(row)
    return row


@router.post("/appointments/{appointment_id}/cancel")
def cancel(appointment_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    row = db.scalar(select(Appointment).where(Appointment.id == appointment_id, Appointment.patient_id == patient.id))
    if not row:
        raise HTTPException(404, "Appointment not found")
    if row.status == "completed":
        raise HTTPException(409, "Completed appointments cannot be cancelled")
    row.status = "cancelled"
    log_action(db, user.id, "portal.appointment.cancel", "appointment", row.id)
    db.commit(); db.refresh(row)
    return row


@router.post("/medications/{schedule_id}/dose-logs", status_code=201)
def dose_log(schedule_id: str, payload: MedicationDoseLogCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    schedule = db.scalar(select(MedicationSchedule).where(MedicationSchedule.id == schedule_id, MedicationSchedule.patient_id == patient.id))
    if not schedule:
        raise HTTPException(404, "Medication schedule not found")
    row = MedicationDoseLog(schedule_id=schedule.id, **payload.model_dump())
    db.add(row)
    log_action(db, user.id, "portal.medication.log", "medication_schedule", schedule.id, metadata={"status": payload.status})
    db.commit(); db.refresh(row)
    return row


@router.get("/documents/{document_id}/download")
def download_document(document_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    doc = db.scalar(select(MedicalDocument).where(MedicalDocument.id == document_id, MedicalDocument.patient_id == patient.id))
    if not doc:
        raise HTTPException(404, "Document not found")
    p = path_for(doc.stored_name)
    if not p.exists():
        raise HTTPException(404, "Stored file is missing")
    log_action(db, user.id, "portal.document.read", "medical_document", doc.id)
    db.commit()
    return FileResponse(p, media_type=doc.mime_type, filename=doc.original_name)
