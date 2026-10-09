from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.routes.appointments import check_slot
from app.core.audit import log_action
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.account import UserAccountProfile
from app.models.user import User
from app.models.clinical import Patient, Doctor, Appointment
from app.models.records import LabResult, MedicalDocument
from app.models.medication import PatientMedication, PrescriptionOcrDraft
from app.models.catalog import MedicationCatalogItem, PharmacyRequest, PharmacyRequestItem
from app.models.advanced import MedicationSchedule, MedicationDoseLog
from app.schemas.domain import MedicationDoseLogCreate, PortalAppointmentCreate, PortalAppointmentReschedule, PharmacyRequestCreate
from app.services.storage import path_for
from app.services.medication_catalog import best_verified_medication_match

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
    check_slot(db, doctor, payload.start_at)
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
    if row.status in {"completed", "cancelled", "no_show", "in_consultation"}:
        raise HTTPException(409, "This appointment can no longer be rescheduled")
    doctor = db.get(Doctor, row.doctor_id)
    if not doctor or not doctor.is_active:
        raise HTTPException(409, "Doctor is unavailable")
    check_slot(db, doctor, payload.start_at, row.id)
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
    import hashlib
    from datetime import timezone
    from sqlalchemy.exc import IntegrityError
    from app.models.workspace import DoseReceipt
    key=hashlib.sha256((user.id+":"+schedule_id+":"+payload.idempotency_key).encode()).hexdigest() if payload.idempotency_key else None
    if key:
        receipt=db.get(DoseReceipt,key)
        if receipt:
            prior=db.get(MedicationDoseLog,receipt.dose_id)
            if prior.status!=payload.status:raise HTTPException(409,"This dose action was already recorded with a different status")
            return prior
    values=payload.model_dump(exclude={"idempotency_key"})
    if values['scheduled_for'].tzinfo:values['scheduled_for']=values['scheduled_for'].astimezone(timezone.utc).replace(tzinfo=None)
    row = MedicationDoseLog(schedule_id=schedule.id, **values)
    db.add(row);db.flush()
    if key:
        db.add(DoseReceipt(id=key,dose_id=row.id))
        try:db.flush()
        except IntegrityError:
            db.rollback();receipt=db.get(DoseReceipt,key)
            if not receipt:raise
            prior=db.get(MedicationDoseLog,receipt.dose_id)
            if prior.status!=payload.status:raise HTTPException(409,"Dose already recorded differently")
            return prior
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


@router.get("/pharmacy/catalog")
def pharmacy_catalog(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    meds = db.scalars(
        select(PatientMedication).where(
            PatientMedication.patient_id == patient.id,
            PatientMedication.verified == True,
            PatientMedication.status == "active",
        )
    ).all()
    rows = db.scalars(
        select(MedicationCatalogItem).where(
            MedicationCatalogItem.hospital_id == patient.hospital_id,
            MedicationCatalogItem.active == True,
        ).order_by(MedicationCatalogItem.category, MedicationCatalogItem.display_name)
    ).all()
    payload = []
    for item in rows:
        matched, score = best_verified_medication_match(meds, item)
        payload.append({
            "id": item.id,
            "generic_name": item.generic_name,
            "display_name": item.display_name,
            "category": item.category,
            "description": item.description,
            "form": item.form,
            "strength": item.strength,
            "image_key": item.image_key,
            "prescription_required": item.prescription_required,
            "request_eligible": matched is not None,
            "matched_patient_medication_id": matched.id if matched else None,
            "match_score": round(score, 3),
            "eligibility_note": "Linked to an active verified medicine in your record" if matched else "Requires an active verified medicine in your Clinexa record",
        })
    return payload


@router.get("/pharmacy/requests")
def patient_pharmacy_requests(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    requests = db.scalars(
        select(PharmacyRequest).where(PharmacyRequest.patient_id == patient.id).order_by(PharmacyRequest.created_at.desc()).limit(50)
    ).all()
    catalog = {x.id: x for x in db.scalars(select(MedicationCatalogItem).where(MedicationCatalogItem.hospital_id == patient.hospital_id)).all()}
    out = []
    for request in requests:
        items = db.scalars(select(PharmacyRequestItem).where(PharmacyRequestItem.request_id == request.id)).all()
        out.append({
            "id": request.id,
            "status": request.status,
            "note": request.note,
            "created_at": request.created_at,
            "items": [
                {
                    "id": item.id,
                    "catalog_item_id": item.catalog_item_id,
                    "display_name": catalog.get(item.catalog_item_id).display_name if catalog.get(item.catalog_item_id) else "Medicine",
                    "quantity": item.quantity,
                }
                for item in items
            ],
        })
    return out


@router.post("/pharmacy/requests", status_code=201)
def create_pharmacy_request(payload: PharmacyRequestCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    _, patient = _patient_profile(db, user)
    if not payload.items:
        raise HTTPException(400, "Add at least one medicine")
    verified_meds = {
        m.id: m
        for m in db.scalars(select(PatientMedication).where(
            PatientMedication.patient_id == patient.id,
            PatientMedication.verified == True,
            PatientMedication.status == "active",
        )).all()
    }
    validated = []
    for requested in payload.items:
        catalog_item = db.scalar(select(MedicationCatalogItem).where(
            MedicationCatalogItem.id == requested.catalog_item_id,
            MedicationCatalogItem.hospital_id == patient.hospital_id,
            MedicationCatalogItem.active == True,
        ))
        med = verified_meds.get(requested.patient_medication_id)
        if not catalog_item or not med:
            raise HTTPException(400, "Every pharmacy request item must link to an active verified medicine")
        matched, _ = best_verified_medication_match([med], catalog_item)
        if not matched:
            raise HTTPException(400, f"{catalog_item.display_name} does not match the selected verified medicine")
        validated.append((requested, catalog_item, med))

    row = PharmacyRequest(
        hospital_id=patient.hospital_id,
        patient_id=patient.id,
        requested_by_user_id=user.id,
        status="submitted",
        note=payload.note,
    )
    db.add(row)
    db.flush()
    for requested, _, med in validated:
        db.add(PharmacyRequestItem(
            request_id=row.id,
            catalog_item_id=requested.catalog_item_id,
            patient_medication_id=med.id,
            quantity=requested.quantity,
        ))
    log_action(db, user.id, "portal.pharmacy.request", "pharmacy_request", row.id, metadata={"item_count": len(validated)})
    db.commit()
    db.refresh(row)
    return {"id": row.id, "status": row.status, "item_count": len(validated), "created_at": row.created_at}
