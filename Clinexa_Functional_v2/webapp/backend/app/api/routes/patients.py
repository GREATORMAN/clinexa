from uuid import uuid4
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, or_
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.core.audit import log_action
from app.models.user import User
from app.models.clinical import Patient, Vital, Encounter
from app.models.records import Prescription, LabResult
from app.schemas.domain import PatientCreate, VitalCreate
router = APIRouter(prefix="/patients", tags=["Patients"])

@router.get("")
def list_patients(q: str | None = Query(default=None), db: Session = Depends(get_db),
                  user: User = Depends(require_permission("patient.demographics.read"))):
    stmt = select(Patient).where(Patient.hospital_id == tenant_id(user)).order_by(Patient.created_at.desc())
    if q:
        like=f"%{q}%"; stmt=stmt.where(or_(Patient.full_name.ilike(like), Patient.patient_code.ilike(like), Patient.phone.ilike(like)))
    return db.scalars(stmt.limit(200)).all()

@router.post("", status_code=201)
def create_patient(payload: PatientCreate, db: Session = Depends(get_db),
                   user: User = Depends(require_permission("patient.demographics.write"))):
    row = Patient(hospital_id=tenant_id(user), patient_code=f"PT-{uuid4().hex[:8].upper()}", **payload.model_dump())
    db.add(row); db.flush(); log_action(db,user.id,"patient.create","patient",row.id); db.commit(); db.refresh(row); return row

@router.get("/{patient_id}")
def patient_detail(patient_id: str, db: Session = Depends(get_db),
                   user: User = Depends(require_permission("patient.demographics.read"))):
    row=db.scalar(select(Patient).where(Patient.id==patient_id,Patient.hospital_id==tenant_id(user)))
    if not row: raise HTTPException(status_code=404,detail="Patient not found")
    log_action(db,user.id,"patient.view","patient",row.id); db.commit(); return row

@router.get("/{patient_id}/timeline")
def timeline(patient_id: str, db: Session = Depends(get_db),
             user: User = Depends(require_permission("patient.clinical.read"))):
    if not db.scalar(select(Patient).where(Patient.id==patient_id,Patient.hospital_id==tenant_id(user))):
        raise HTTPException(status_code=404,detail="Patient not found")
    events=[]
    for x in db.scalars(select(Encounter).where(Encounter.patient_id==patient_id)).all(): events.append({"type":"encounter","at":x.created_at,"summary":x.chief_complaint})
    for x in db.scalars(select(Prescription).where(Prescription.patient_id==patient_id)).all(): events.append({"type":"prescription","at":x.created_at,"summary":x.medication_name})
    for x in db.scalars(select(LabResult).where(LabResult.patient_id==patient_id)).all(): events.append({"type":"lab","at":x.created_at,"summary":f"{x.test_name}: {x.result_value}"})
    for x in db.scalars(select(Vital).where(Vital.patient_id==patient_id)).all(): events.append({"type":"vital","at":x.observed_at,"summary":"Vitals recorded"})
    events.sort(key=lambda e:e["at"], reverse=True); return events

@router.post("/{patient_id}/vitals",status_code=201)
def add_vital(patient_id: str,payload: VitalCreate,db: Session=Depends(get_db),
              user: User=Depends(require_permission("patient.clinical.write"))):
    if not db.scalar(select(Patient).where(Patient.id==patient_id,Patient.hospital_id==tenant_id(user))):
        raise HTTPException(status_code=404,detail="Patient not found")
    row=Vital(patient_id=patient_id,**payload.model_dump());db.add(row);db.commit();db.refresh(row);return row

@router.get("/{patient_id}/vitals")
def vitals(patient_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.read"))):
    if not db.scalar(select(Patient).where(Patient.id == patient_id, Patient.hospital_id == tenant_id(user))):
        raise HTTPException(status_code=404, detail="Patient not found")
    return db.scalars(select(Vital).where(Vital.patient_id == patient_id).order_by(Vital.observed_at.desc()).limit(100)).all()
