from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.audit import log_action
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.models.user import User
from app.models.clinical import Patient, Encounter, Doctor
from app.models.records import Prescription, LabResult
from app.models.medication import PatientMedication
from app.schemas.domain import EncounterCreate, PrescriptionCreate, LabResultCreate

router = APIRouter(tags=["Clinical Records"])


def ensure(db: Session, hospital_id: str, patient_id: str) -> Patient:
    patient = db.scalar(select(Patient).where(Patient.id == patient_id, Patient.hospital_id == hospital_id))
    if not patient:
        raise HTTPException(404, "Patient not found")
    return patient


@router.post("/encounters", status_code=201)
def create_encounter(
    payload: EncounterCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("patient.clinical.write")),
):
    ensure(db, tenant_id(user), payload.patient_id)
    row = Encounter(hospital_id=tenant_id(user), author_user_id=user.id, **payload.model_dump())
    db.add(row)
    db.flush()
    log_action(db, user.id, "encounter.create", "encounter", row.id, metadata={"patient_id": payload.patient_id})
    db.commit()
    db.refresh(row)
    return row


@router.get("/patients/{patient_id}/encounters")
def encounters(
    patient_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("patient.clinical.read")),
):
    ensure(db, tenant_id(user), patient_id)
    return db.scalars(
        select(Encounter).where(Encounter.patient_id == patient_id).order_by(Encounter.created_at.desc())
    ).all()


@router.post("/prescriptions", status_code=201)
def create_prescription(
    payload: PrescriptionCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("prescriptions.create")),
):
    ensure(db, tenant_id(user), payload.patient_id)
    doctor = db.scalar(select(Doctor).where(Doctor.id == payload.doctor_id, Doctor.hospital_id == tenant_id(user)))
    if not doctor:
        raise HTTPException(404, "Doctor not found")

    row = Prescription(**payload.model_dump())
    db.add(row)
    db.flush()

    medication = PatientMedication(
        patient_id=payload.patient_id,
        source_type="electronic_prescription",
        source_id=row.id,
        medication_name=payload.medication_name,
        strength=payload.strength,
        form=payload.form,
        frequency=payload.frequency,
        duration=payload.duration,
        instructions=payload.instructions,
        prescribing_doctor_text=doctor.full_name,
        status="active",
        verified=True,
        verified_by_user_id=user.id,
    )
    db.add(medication)
    log_action(
        db,
        user.id,
        "prescription.create",
        "prescription",
        row.id,
        metadata={"patient_id": payload.patient_id},
    )
    db.commit()
    db.refresh(row)
    return row


@router.get("/patients/{patient_id}/prescriptions")
def prescriptions(
    patient_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("prescriptions.read")),
):
    ensure(db, tenant_id(user), patient_id)
    return db.scalars(
        select(Prescription).where(Prescription.patient_id == patient_id).order_by(Prescription.created_at.desc())
    ).all()


@router.post("/labs", status_code=201)
def create_lab(
    payload: LabResultCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("lab_results.upload")),
):
    ensure(db, tenant_id(user), payload.patient_id)
    row = LabResult(**payload.model_dump())
    db.add(row)
    db.flush()
    log_action(db, user.id, "lab_result.create", "lab_result", row.id, metadata={"patient_id": payload.patient_id})
    db.commit()
    db.refresh(row)
    return row


@router.get("/patients/{patient_id}/labs")
def labs(
    patient_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("patient.clinical.read")),
):
    ensure(db, tenant_id(user), patient_id)
    return db.scalars(
        select(LabResult).where(LabResult.patient_id == patient_id).order_by(LabResult.created_at.desc())
    ).all()
