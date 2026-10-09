from __future__ import annotations

import secrets
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user, require_permission, tenant_id
from app.core.audit import log_action
from app.models.user import User
from app.models.organization import Department
from app.models.clinical import Patient, Doctor, Appointment, Encounter, Vital
from app.models.records import Prescription, LabResult, MedicalDocument
from app.models.catalog import MedicationCatalogItem
from app.models.medication import PatientMedication, PrescriptionOcrDraft
from app.models.operations import CarePlan, Invoice, Admission, Bed, Room, Ward, PharmacyItem, InventoryBatch
from app.models.advanced import (
    EmergencyProfile, TrustedContact, NfcBand, EmergencyAccessLog,
    MedicationSchedule, MedicationDoseLog, SymptomEntry, InsurancePolicy,
    LabOrder, TeleconsultationSession, StaffShift, ConsentRecord,
)
from app.schemas.domain import (
    EmergencyProfileUpsert, TrustedContactCreate, NfcBandCreate,
    MedicationScheduleCreate, MedicationDoseLogCreate, SymptomCreate,
    InsurancePolicyCreate, LabOrderCreate, LabOrderStatusUpdate,
    TeleconsultationCreate, TeleconsultationStatusUpdate, StaffShiftCreate,
    ConsentCreate, PatientMedicationCreate,
)

router = APIRouter(prefix="/advanced", tags=["Clinexa Advanced"])


def _patient(db: Session, hospital_id: str, patient_id: str) -> Patient:
    row = db.scalar(select(Patient).where(Patient.id == patient_id, Patient.hospital_id == hospital_id))
    if not row:
        raise HTTPException(status_code=404, detail="Patient not found")
    return row


@router.get("/patients/{patient_id}/360")
def patient_360(
    patient_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("patient.clinical.read")),
):
    h = tenant_id(user)
    patient = _patient(db, h, patient_id)
    vitals = db.scalars(select(Vital).where(Vital.patient_id == patient_id).order_by(Vital.observed_at.desc()).limit(30)).all()
    encounters = db.scalars(select(Encounter).where(Encounter.patient_id == patient_id).order_by(Encounter.created_at.desc()).limit(30)).all()
    prescriptions = db.scalars(select(Prescription).where(Prescription.patient_id == patient_id).order_by(Prescription.created_at.desc()).limit(50)).all()
    labs = db.scalars(select(LabResult).where(LabResult.patient_id == patient_id).order_by(LabResult.created_at.desc()).limit(50)).all()
    documents = db.scalars(select(MedicalDocument).where(MedicalDocument.patient_id == patient_id).order_by(MedicalDocument.created_at.desc()).limit(50)).all()
    appointments = db.scalars(select(Appointment).where(Appointment.patient_id == patient_id, Appointment.hospital_id == h).order_by(Appointment.start_at.desc()).limit(50)).all()
    care_plans = db.scalars(select(CarePlan).where(CarePlan.patient_id == patient_id).order_by(CarePlan.created_at.desc()).limit(30)).all()
    medications = db.scalars(select(MedicationSchedule).where(MedicationSchedule.patient_id == patient_id).order_by(MedicationSchedule.created_at.desc())).all()
    patient_medications = db.scalars(select(PatientMedication).where(PatientMedication.patient_id == patient_id).order_by(PatientMedication.created_at.desc())).all()
    ocr_prescriptions = db.scalars(select(PrescriptionOcrDraft).where(PrescriptionOcrDraft.patient_id == patient_id).order_by(PrescriptionOcrDraft.created_at.desc()).limit(30)).all()
    symptoms = db.scalars(select(SymptomEntry).where(SymptomEntry.patient_id == patient_id).order_by(SymptomEntry.recorded_at.desc()).limit(30)).all()
    insurance = db.scalars(select(InsurancePolicy).where(InsurancePolicy.patient_id == patient_id).order_by(InsurancePolicy.id.desc())).all()
    emergency = db.scalar(select(EmergencyProfile).where(EmergencyProfile.patient_id == patient_id))
    contacts = db.scalars(select(TrustedContact).where(TrustedContact.patient_id == patient_id).order_by(TrustedContact.priority)).all()
    bands = db.scalars(select(NfcBand).where(NfcBand.patient_id == patient_id).order_by(NfcBand.issued_at.desc())).all()
    consents = db.scalars(select(ConsentRecord).where(ConsentRecord.patient_id == patient_id).order_by(ConsentRecord.recorded_at.desc())).all()
    return {
        "patient": patient,
        "vitals": vitals,
        "encounters": encounters,
        "prescriptions": prescriptions,
        "labs": labs,
        "documents": documents,
        "appointments": appointments,
        "care_plans": care_plans,
        "medication_schedules": medications,
        "patient_medications": patient_medications,
        "ocr_prescriptions": ocr_prescriptions,
        "symptoms": symptoms,
        "insurance": insurance,
        "emergency_profile": emergency,
        "trusted_contacts": contacts,
        "nfc_bands": bands,
        "consents": consents,
    }


@router.get("/search")
def global_search(
    q: str = Query(min_length=2, max_length=120),
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("patient.demographics.read")),
):
    h = tenant_id(user)
    like = f"%{q}%"
    patients = db.scalars(select(Patient).where(Patient.hospital_id == h, or_(Patient.full_name.ilike(like), Patient.patient_code.ilike(like), Patient.phone.ilike(like))).limit(12)).all()
    doctors = db.scalars(select(Doctor).where(Doctor.hospital_id == h, or_(Doctor.full_name.ilike(like), Doctor.specialty.ilike(like))).limit(12)).all()
    appointments = db.scalars(select(Appointment).where(Appointment.hospital_id == h, Appointment.reason.ilike(like)).limit(12)).all()
    documents = db.scalars(select(MedicalDocument).join(Patient, MedicalDocument.patient_id == Patient.id).where(Patient.hospital_id == h, or_(MedicalDocument.original_name.ilike(like), MedicalDocument.description.ilike(like))).limit(12)).all()
    return {
        "patients": [{"id": x.id, "label": x.full_name, "meta": x.patient_code} for x in patients],
        "doctors": [{"id": x.id, "label": x.full_name, "meta": x.specialty} for x in doctors],
        "appointments": [{"id": x.id, "label": x.reason or "Appointment", "meta": x.status} for x in appointments],
        "documents": [{"id": x.id, "label": x.original_name, "meta": x.category} for x in documents],
    }


@router.get("/analytics/overview")
def analytics_overview(db: Session = Depends(get_db), user: User = Depends(require_permission("admin.dashboard"))):
    h = tenant_id(user)
    now = datetime.utcnow()
    week_ago = now - timedelta(days=7)
    patient_count = db.scalar(select(func.count()).select_from(Patient).where(Patient.hospital_id == h)) or 0
    doctor_count = db.scalar(select(func.count()).select_from(Doctor).where(Doctor.hospital_id == h, Doctor.is_active == True)) or 0
    appointments_week = db.scalar(select(func.count()).select_from(Appointment).where(Appointment.hospital_id == h, Appointment.start_at >= week_ago)) or 0
    active_admissions = db.scalar(select(func.count()).select_from(Admission).where(Admission.hospital_id == h, Admission.status == "admitted")) or 0
    total_beds = db.scalar(select(func.count()).select_from(Bed).join(Room).join(Ward).where(Ward.hospital_id == h)) or 0
    occupied_beds = db.scalar(select(func.count()).select_from(Bed).join(Room).join(Ward).where(Ward.hospital_id == h, Bed.status == "occupied")) or 0
    pending_labs = db.scalar(select(func.count()).select_from(LabOrder).where(LabOrder.hospital_id == h, LabOrder.status.in_(["ordered", "collected", "processing"]))) or 0
    unpaid_total = db.scalar(select(func.coalesce(func.sum(Invoice.total_amount), 0)).where(Invoice.hospital_id == h, Invoice.status != "paid")) or 0
    low_stock = 0
    for item in db.scalars(select(PharmacyItem).where(PharmacyItem.hospital_id == h)).all():
        qty = db.scalar(select(func.coalesce(func.sum(InventoryBatch.quantity), 0)).where(InventoryBatch.pharmacy_item_id == item.id)) or 0
        if int(qty) <= item.reorder_level:
            low_stock += 1
    return {
        "patients": int(patient_count),
        "active_doctors": int(doctor_count),
        "appointments_last_7_days": int(appointments_week),
        "active_admissions": int(active_admissions),
        "bed_occupancy": {"occupied": int(occupied_beds), "total": int(total_beds)},
        "pending_lab_orders": int(pending_labs),
        "unpaid_invoice_total": float(unpaid_total),
        "low_stock_items": int(low_stock),
    }


@router.get("/emergency/profiles/{patient_id}")
def get_emergency_profile(patient_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.read"))):
    _patient(db, tenant_id(user), patient_id)
    profile = db.scalar(select(EmergencyProfile).where(EmergencyProfile.patient_id == patient_id))
    contacts = db.scalars(select(TrustedContact).where(TrustedContact.patient_id == patient_id).order_by(TrustedContact.priority)).all()
    bands = db.scalars(select(NfcBand).where(NfcBand.patient_id == patient_id).order_by(NfcBand.issued_at.desc())).all()
    logs = db.scalars(select(EmergencyAccessLog).where(EmergencyAccessLog.patient_id == patient_id).order_by(EmergencyAccessLog.accessed_at.desc()).limit(50)).all()
    return {"profile": profile, "contacts": contacts, "bands": bands, "access_logs": logs}


@router.put("/emergency/profiles/{patient_id}")
def upsert_emergency_profile(patient_id: str, payload: EmergencyProfileUpsert, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    patient = _patient(db, tenant_id(user), patient_id)
    row = db.scalar(select(EmergencyProfile).where(EmergencyProfile.patient_id == patient_id))
    values = payload.model_dump()
    if not values.get("public_name"):
        values["public_name"] = patient.full_name
    if not values.get("blood_group"):
        values["blood_group"] = patient.blood_group
    if row:
        for k, v in values.items():
            setattr(row, k, v)
        row.updated_at = datetime.utcnow()
    else:
        row = EmergencyProfile(patient_id=patient_id, **values)
        db.add(row)
    log_action(db, user.id, "emergency_profile.upsert", "patient", patient_id)
    db.commit(); db.refresh(row)
    return row


@router.post("/emergency/profiles/{patient_id}/contacts", status_code=201)
def add_trusted_contact(patient_id: str, payload: TrustedContactCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    _patient(db, tenant_id(user), patient_id)
    row = TrustedContact(patient_id=patient_id, **payload.model_dump())
    db.add(row); db.commit(); db.refresh(row); return row


@router.post("/emergency/bands", status_code=201)
def issue_band(payload: NfcBandCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    _patient(db, tenant_id(user), payload.patient_id)
    row = NfcBand(patient_id=payload.patient_id, token=secrets.token_urlsafe(32), label=payload.label, tag_uid=payload.tag_uid)
    db.add(row); db.flush(); log_action(db, user.id, "nfc_band.issue", "nfc_band", row.id); db.commit(); db.refresh(row)
    return {"id": row.id, "patient_id": row.patient_id, "label": row.label, "token": row.token, "uri": f"clinexa://emergency/{row.token}", "active": row.active}


@router.post("/emergency/bands/{band_id}/revoke")
def revoke_band(band_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    h = tenant_id(user)
    row = db.scalar(select(NfcBand).join(Patient, NfcBand.patient_id == Patient.id).where(NfcBand.id == band_id, Patient.hospital_id == h))
    if not row:
        raise HTTPException(status_code=404, detail="Band not found")
    row.active = False; row.revoked_at = datetime.utcnow(); log_action(db, user.id, "nfc_band.revoke", "nfc_band", row.id); db.commit(); db.refresh(row); return row


@router.get("/emergency/public/{token}")
def public_emergency_card(token: str, source: str | None = None, db: Session = Depends(get_db)):
    band = db.scalar(select(NfcBand).where(NfcBand.token == token, NfcBand.active == True))
    if not band:
        raise HTTPException(status_code=404, detail="Emergency token is invalid or revoked")
    profile = db.scalar(select(EmergencyProfile).where(EmergencyProfile.patient_id == band.patient_id, EmergencyProfile.enabled == True))
    patient = db.get(Patient, band.patient_id)
    if not profile or not patient:
        raise HTTPException(status_code=404, detail="Emergency profile unavailable")
    contacts = db.scalars(select(TrustedContact).where(TrustedContact.patient_id == patient.id).order_by(TrustedContact.priority).limit(3)).all()
    db.add(EmergencyAccessLog(patient_id=patient.id, band_id=band.id, access_type="public_scan", source=(source or "nfc")[:120]))
    db.commit()
    return {
        "name": profile.public_name or patient.full_name,
        "blood_group": profile.blood_group or patient.blood_group,
        "allergies": profile.allergies,
        "critical_conditions": profile.critical_conditions,
        "emergency_notes": profile.emergency_notes,
        "organ_donor": profile.organ_donor,
        "contacts": [{"name": c.name, "relation": c.relation, "phone": c.phone} for c in contacts],
        "band_label": band.label,
    }


@router.get("/medication-centre/{patient_id}")
def medication_centre(patient_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.read"))):
    _patient(db, tenant_id(user), patient_id)
    medications = db.scalars(select(PatientMedication).where(PatientMedication.patient_id == patient_id).order_by(PatientMedication.created_at.desc())).all()
    schedules = db.scalars(select(MedicationSchedule).where(MedicationSchedule.patient_id == patient_id).order_by(MedicationSchedule.created_at.desc())).all()
    prescriptions = db.scalars(select(Prescription).where(Prescription.patient_id == patient_id).order_by(Prescription.created_at.desc())).all()
    imports = db.scalars(select(PrescriptionOcrDraft).where(PrescriptionOcrDraft.patient_id == patient_id).order_by(PrescriptionOcrDraft.created_at.desc())).all()
    active = [m for m in medications if m.status == "active"]
    previous = [m for m in medications if m.status != "active"]
    return {
        "current": active,
        "previous": previous,
        "all": medications,
        "schedules": schedules,
        "electronic_prescriptions": prescriptions,
        "ocr_imports": imports,
    }


@router.post("/medication-centre", status_code=201)
def create_patient_medication(payload: PatientMedicationCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    _patient(db, tenant_id(user), payload.patient_id)
    values = payload.model_dump(exclude={"reminder_times"})
    row = PatientMedication(source_type="manual_verified", verified=True, verified_by_user_id=user.id, **values)
    db.add(row); db.flush()
    schedule = None
    if payload.reminder_times and payload.reminder_times.strip():
        schedule = MedicationSchedule(
            patient_id=payload.patient_id,
            medication_name=payload.medication_name,
            dose_label=" ".join(x for x in [payload.strength, payload.form] if x) or None,
            times_csv=payload.reminder_times.strip(),
            start_date=payload.start_date,
            end_date=payload.end_date,
            instructions=payload.instructions,
            active=payload.status == "active",
        )
        db.add(schedule); db.flush()
    log_action(db, user.id, "patient_medication.create", "patient_medication", row.id, metadata={"patient_id": payload.patient_id})
    db.commit(); db.refresh(row)
    return {"medication": row, "schedule": schedule}


@router.get("/medications/{patient_id}")
def medication_schedules(patient_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.read"))):
    _patient(db, tenant_id(user), patient_id)
    return db.scalars(select(MedicationSchedule).where(MedicationSchedule.patient_id == patient_id).order_by(MedicationSchedule.created_at.desc())).all()


@router.post("/medications", status_code=201)
def create_medication_schedule(payload: MedicationScheduleCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    _patient(db, tenant_id(user), payload.patient_id)
    row = MedicationSchedule(**payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row


@router.post("/medications/{schedule_id}/dose-logs", status_code=201)
def log_medication_dose(schedule_id: str, payload: MedicationDoseLogCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    h = tenant_id(user)
    schedule = db.scalar(select(MedicationSchedule).join(Patient, MedicationSchedule.patient_id == Patient.id).where(MedicationSchedule.id == schedule_id, Patient.hospital_id == h))
    if not schedule:
        raise HTTPException(status_code=404, detail="Medication schedule not found")
    row = MedicationDoseLog(schedule_id=schedule_id, **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row


@router.get("/symptoms/{patient_id}")
def symptoms(patient_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.read"))):
    _patient(db, tenant_id(user), patient_id)
    return db.scalars(select(SymptomEntry).where(SymptomEntry.patient_id == patient_id).order_by(SymptomEntry.recorded_at.desc()).limit(100)).all()


@router.post("/symptoms/{patient_id}", status_code=201)
def add_symptom(patient_id: str, payload: SymptomCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    _patient(db, tenant_id(user), patient_id)
    row = SymptomEntry(patient_id=patient_id, **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row


@router.get("/insurance/{patient_id}")
def insurance(patient_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.demographics.read"))):
    _patient(db, tenant_id(user), patient_id)
    return db.scalars(select(InsurancePolicy).where(InsurancePolicy.patient_id == patient_id)).all()


@router.post("/insurance/{patient_id}", status_code=201)
def add_insurance(patient_id: str, payload: InsurancePolicyCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.demographics.write"))):
    _patient(db, tenant_id(user), patient_id)
    row = InsurancePolicy(patient_id=patient_id, **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row


@router.get("/lab-orders")
def lab_orders(patient_id: str | None = None, db: Session = Depends(get_db), user: User = Depends(require_permission("lab.orders.read"))):
    stmt = select(LabOrder).where(LabOrder.hospital_id == tenant_id(user)).order_by(LabOrder.ordered_at.desc())
    if patient_id:
        stmt = stmt.where(LabOrder.patient_id == patient_id)
    return db.scalars(stmt.limit(200)).all()


@router.post("/lab-orders", status_code=201)
def create_lab_order(payload: LabOrderCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("lab.orders.manage"))):
    h = tenant_id(user); _patient(db, h, payload.patient_id)
    row = LabOrder(hospital_id=h, **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row


@router.patch("/lab-orders/{order_id}/status")
def update_lab_order(order_id: str, payload: LabOrderStatusUpdate, db: Session = Depends(get_db), user: User = Depends(require_permission("lab.orders.manage"))):
    row = db.scalar(select(LabOrder).where(LabOrder.id == order_id, LabOrder.hospital_id == tenant_id(user)))
    if not row:
        raise HTTPException(status_code=404, detail="Lab order not found")
    row.status = payload.status
    if payload.status == "collected": row.collected_at = datetime.utcnow()
    if payload.status == "completed": row.completed_at = datetime.utcnow()
    db.commit(); db.refresh(row); return row


@router.get("/teleconsultations")
def teleconsultations(db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.read"))):
    h = tenant_id(user)
    return db.scalars(select(TeleconsultationSession).join(Appointment, TeleconsultationSession.appointment_id == Appointment.id).where(Appointment.hospital_id == h).order_by(Appointment.start_at.desc()).limit(100)).all()


@router.post("/teleconsultations", status_code=201)
def create_teleconsultation(payload: TeleconsultationCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.modify"))):
    appt = db.scalar(select(Appointment).where(Appointment.id == payload.appointment_id, Appointment.hospital_id == tenant_id(user)))
    if not appt:
        raise HTTPException(status_code=404, detail="Appointment not found")
    existing = db.scalar(select(TeleconsultationSession).where(TeleconsultationSession.appointment_id == appt.id))
    if existing:
        return existing
    row = TeleconsultationSession(appointment_id=appt.id, room_code=f"CX-{secrets.token_hex(5).upper()}", consent_recorded=payload.consent_recorded)
    db.add(row); db.commit(); db.refresh(row); return row


@router.patch("/teleconsultations/{session_id}")
def update_teleconsultation(session_id: str, payload: TeleconsultationStatusUpdate, db: Session = Depends(get_db), user: User = Depends(require_permission("appointments.modify"))):
    h = tenant_id(user)
    row = db.scalar(select(TeleconsultationSession).join(Appointment, TeleconsultationSession.appointment_id == Appointment.id).where(TeleconsultationSession.id == session_id, Appointment.hospital_id == h))
    if not row:
        raise HTTPException(status_code=404, detail="Teleconsultation not found")
    row.status = payload.status
    if payload.status == "live" and row.started_at is None: row.started_at = datetime.utcnow()
    if payload.status == "ended": row.ended_at = datetime.utcnow()
    db.commit(); db.refresh(row); return row


@router.get("/staff/shifts")
def shifts(db: Session = Depends(get_db), user: User = Depends(require_permission("users.manage"))):
    return db.scalars(select(StaffShift).where(StaffShift.hospital_id == tenant_id(user)).order_by(StaffShift.starts_at.desc()).limit(200)).all()


@router.post("/staff/shifts", status_code=201)
def create_shift(payload: StaffShiftCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("users.manage"))):
    if payload.ends_at <= payload.starts_at:
        raise HTTPException(status_code=400, detail="Shift end must be after start")
    row = StaffShift(hospital_id=tenant_id(user), **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row


@router.get("/consents/{patient_id}")
def consents(patient_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.read"))):
    _patient(db, tenant_id(user), patient_id)
    return db.scalars(select(ConsentRecord).where(ConsentRecord.patient_id == patient_id).order_by(ConsentRecord.recorded_at.desc())).all()


@router.post("/consents/{patient_id}", status_code=201)
def add_consent(patient_id: str, payload: ConsentCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    _patient(db, tenant_id(user), patient_id)
    row = ConsentRecord(patient_id=patient_id, **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row


@router.get("/bed-board")
def bed_board(db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.read"))):
    h = tenant_id(user)
    rows = db.execute(select(Bed, Room, Ward).join(Room, Bed.room_id == Room.id).join(Ward, Room.ward_id == Ward.id).where(Ward.hospital_id == h).order_by(Ward.name, Room.name, Bed.label)).all()
    active_admissions = db.scalars(select(Admission).where(Admission.hospital_id == h, Admission.status == "admitted")).all()
    by_bed = {a.bed_id: a for a in active_admissions if a.bed_id}
    patients = {p.id: p for p in db.scalars(select(Patient).where(Patient.hospital_id == h)).all()}
    out = []
    for bed, room, ward in rows:
        adm = by_bed.get(bed.id)
        patient = patients.get(adm.patient_id) if adm else None
        out.append({
            "bed_id": bed.id, "bed": bed.label, "status": bed.status,
            "room": room.name, "ward": ward.name,
            "patient_id": patient.id if patient else None,
            "patient_name": patient.full_name if patient else None,
            "admission_id": adm.id if adm else None,
        })
    return out


@router.get("/medication-catalog")
def medication_catalog(db: Session = Depends(get_db), user: User = Depends(require_permission("medication.catalog.read"))):
    return db.scalars(
        select(MedicationCatalogItem).where(
            MedicationCatalogItem.hospital_id == tenant_id(user),
            MedicationCatalogItem.active == True,
        ).order_by(MedicationCatalogItem.category, MedicationCatalogItem.display_name)
    ).all()
