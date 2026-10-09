from datetime import datetime

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.core.audit import log_action
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.core.rbac_seed import ACCOUNT_TYPE_TO_ROLE, ensure_role
from app.models.account import UserAccountProfile
from app.models.user import User
from app.models.audit import AuditLog
from app.models.clinical import Patient, Doctor, Appointment
from app.models.operations import Invoice
from app.models.organization import Department
from app.schemas.domain import DepartmentCreate

router = APIRouter(prefix="/admin", tags=["Administration"])


@router.get("/dashboard")
def dashboard(db: Session = Depends(get_db), user: User = Depends(require_permission("admin.dashboard"))):
    h = tenant_id(user)
    return {
        "patients": db.scalar(select(func.count()).select_from(Patient).where(Patient.hospital_id == h)) or 0,
        "doctors": db.scalar(select(func.count()).select_from(Doctor).where(Doctor.hospital_id == h)) or 0,
        "appointments": db.scalar(select(func.count()).select_from(Appointment).where(Appointment.hospital_id == h)) or 0,
        "paid_invoice_total": float(db.scalar(select(func.coalesce(func.sum(Invoice.total_amount), 0)).where(Invoice.hospital_id == h, Invoice.status == "paid")) or 0),
        "pending_staff": db.scalar(
            select(func.count())
            .select_from(UserAccountProfile)
            .join(User, UserAccountProfile.user_id == User.id)
            .where(User.hospital_id == h, UserAccountProfile.approval_status == "pending")
        ) or 0,
    }


@router.get("/audit")
def audit(limit: int = Query(100, ge=1, le=500), actor_id:str|None=None, action:str|None=None, resource:str|None=None, since:datetime|None=None, until:datetime|None=None, db: Session = Depends(get_db), user: User = Depends(require_permission("audit.read"))):
    query=select(AuditLog,User.full_name).join(User,User.id==AuditLog.actor_user_id).where(User.hospital_id==tenant_id(user))
    if actor_id:query=query.where(AuditLog.actor_user_id==actor_id)
    if action:query=query.where(AuditLog.action.contains(action))
    if resource:query=query.where(AuditLog.resource==resource)
    if since:query=query.where(AuditLog.created_at>=since)
    if until:query=query.where(AuditLog.created_at<=until)
    return [{**{c.name:getattr(row,c.name) for c in row.__table__.columns},'actor_name':name} for row,name in db.execute(query.order_by(AuditLog.created_at.desc()).limit(limit))]



@router.get("/users")
def users(db: Session = Depends(get_db), user: User = Depends(require_permission("users.manage"))):
    h = tenant_id(user)
    rows = db.scalars(select(User).where(User.hospital_id == h, User.is_active == True).order_by(User.full_name)).all()
    profiles = {
        p.user_id: p
        for p in db.scalars(
            select(UserAccountProfile).join(User, UserAccountProfile.user_id == User.id).where(User.hospital_id == h)
        ).all()
    }
    return [
        {
            "id": row.id,
            "full_name": row.full_name,
            "email": row.email,
            "is_staff": row.is_staff,
            "roles": [role.name for role in row.roles],
            "account_type": profiles[row.id].account_type if row.id in profiles else None,
            "approval_status": profiles[row.id].approval_status if row.id in profiles else None,
        }
        for row in rows
    ]


@router.post("/users/{user_id}/approve")
def approve_user(user_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("users.manage"))):
    target = db.scalar(select(User).where(User.id == user_id, User.hospital_id == tenant_id(user)))
    if not target:
        raise HTTPException(404, "User not found")
    profile = db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id == target.id))
    if not profile:
        raise HTTPException(409, "User does not have a role request")
    role_name = ACCOUNT_TYPE_TO_ROLE.get(profile.account_type)
    if not role_name:
        raise HTTPException(422, "Unsupported account type")
    if profile.account_type == "caregiver" and not profile.patient_id:
        raise HTTPException(409, "Caregiver access must be linked to a specific patient before approval")
    role = ensure_role(db, role_name)
    if role not in target.roles:
        target.roles.append(role)
    if profile.account_type == "doctor" and not profile.doctor_id:
        doctor = db.scalar(select(Doctor).where(Doctor.hospital_id == target.hospital_id, Doctor.full_name == target.full_name))
        if not doctor:
            doctor = Doctor(
                hospital_id=target.hospital_id,
                full_name=target.full_name,
                specialty=profile.specialty or "Not specified",
                qualifications=None,
                languages=None,
                biography="Clinexa staff profile linked to an approved doctor account.",
            )
            db.add(doctor)
            db.flush()
        profile.doctor_id = doctor.id
    profile.approval_status = "approved"
    profile.approved_at = datetime.utcnow()
    profile.approved_by_user_id = user.id
    target.is_verified = True
    log_action(db, user.id, "user.approve", "user", target.id, metadata={"role": role_name})
    db.commit()
    return {"status": "approved", "user_id": target.id, "role": role_name}


@router.post("/users/{user_id}/reject")
def reject_user(user_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("users.manage"))):
    target = db.scalar(select(User).where(User.id == user_id, User.hospital_id == tenant_id(user)))
    if not target:
        raise HTTPException(404, "User not found")
    profile = db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id == target.id))
    if not profile:
        raise HTTPException(409, "User does not have a role request")
    profile.approval_status = "rejected"
    profile.approved_at = datetime.utcnow()
    profile.approved_by_user_id = user.id
    target.roles.clear()
    log_action(db, user.id, "user.reject", "user", target.id, metadata={"account_type": profile.account_type})
    db.commit()
    return {"status": "rejected", "user_id": target.id}


@router.get("/departments")
def departments(db: Session = Depends(get_db), user: User = Depends(require_permission("doctors.read"))):
    return db.scalars(select(Department).where(Department.hospital_id == tenant_id(user), Department.is_active == True).order_by(Department.name)).all()


@router.post("/departments", status_code=201)
def create_department(payload: DepartmentCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("doctors.manage"))):
    h = tenant_id(user)
    existing = db.scalar(select(Department).where(Department.hospital_id == h, Department.name == payload.name.strip()))
    if existing:
        raise HTTPException(status_code=409, detail="Department already exists")
    row = Department(hospital_id=h, name=payload.name.strip())
    db.add(row)
    db.commit()
    db.refresh(row)
    return row
