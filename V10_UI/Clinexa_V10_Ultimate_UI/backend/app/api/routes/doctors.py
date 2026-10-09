from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import select, or_
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.models.user import User
from app.models.clinical import Doctor, DoctorAvailability
from app.schemas.domain import DoctorCreate, DoctorAvailabilityCreate

router = APIRouter(prefix="/doctors", tags=["Doctors"])

@router.get("")
def list_doctors(q: str | None = Query(default=None), specialty: str | None = None, db: Session = Depends(get_db), user: User = Depends(require_permission("doctors.read"))):
    stmt = select(Doctor).where(Doctor.hospital_id == tenant_id(user), Doctor.is_active == True)
    if specialty:
        stmt = stmt.where(Doctor.specialty.ilike(f"%{specialty}%"))
    if q:
        stmt = stmt.where(or_(Doctor.full_name.ilike(f"%{q}%"), Doctor.specialty.ilike(f"%{q}%")))
    return db.scalars(stmt.order_by(Doctor.full_name)).all()

@router.post("", status_code=201)
def create_doctor(payload: DoctorCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("doctors.manage"))):
    row = Doctor(hospital_id=tenant_id(user), **payload.model_dump())
    db.add(row); db.commit(); db.refresh(row)
    return row

@router.get("/{doctor_id}/availability")
def availability(doctor_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("doctors.read"))):
    doctor = db.scalar(select(Doctor).where(Doctor.id == doctor_id, Doctor.hospital_id == tenant_id(user)))
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")
    return db.scalars(select(DoctorAvailability).where(DoctorAvailability.doctor_id == doctor_id).order_by(DoctorAvailability.weekday)).all()

@router.post("/{doctor_id}/availability", status_code=201)
def add_availability(doctor_id: str, payload: DoctorAvailabilityCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("doctors.manage"))):
    doctor = db.scalar(select(Doctor).where(Doctor.id == doctor_id, Doctor.hospital_id == tenant_id(user)))
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")
    row = DoctorAvailability(doctor_id=doctor_id, **payload.model_dump())
    db.add(row); db.commit(); db.refresh(row)
    return row
