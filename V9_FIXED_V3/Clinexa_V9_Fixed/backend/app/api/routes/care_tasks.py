from datetime import datetime, timezone
from typing import Literal
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select, update
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.core.audit import log_action
from app.models.user import User
from app.models.clinical import Patient
from app.models.care_task import CareTask

router = APIRouter(prefix="/care-tasks", tags=["Care tasks"])


class TaskCreate(BaseModel):
    patient_id: str
    title: str = Field(min_length=1, max_length=200)
    notes: str | None = Field(default=None, max_length=4000)
    priority: Literal["normal", "high", "urgent"] = "normal"
    due_at: datetime | None = None

    @field_validator("title")
    @classmethod
    def nonblank(cls, value):
        if not value.strip():
            raise ValueError("Enter a task title")
        return value.strip()

    @field_validator("due_at")
    @classmethod
    def utc_date(cls, value):
        if value and value.tzinfo:
            return value.astimezone(timezone.utc).replace(tzinfo=None)
        return value


class TaskUpdate(BaseModel):
    status: Literal["open", "in_progress", "completed", "cancelled"]
    version: int = Field(ge=1)


def view(task, patient):
    return {**{c.name: getattr(task, c.name) for c in task.__table__.columns},
            "patient_name": patient.full_name, "patient_code": patient.patient_code}


@router.get("")
def list_tasks(db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.read"))):
    rows = db.execute(select(CareTask, Patient).join(Patient, Patient.id == CareTask.patient_id)
                      .where(CareTask.hospital_id == tenant_id(user))
                      .order_by(CareTask.created_at.desc()).limit(500)).all()
    return [view(task, patient) for task, patient in rows]


@router.post("", status_code=201)
def create_task(payload: TaskCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    patient = db.scalar(select(Patient).where(Patient.id == payload.patient_id, Patient.hospital_id == tenant_id(user)))
    if not patient:
        raise HTTPException(404, "Patient not found")
    task = CareTask(**payload.model_dump(), hospital_id=tenant_id(user), created_by=user.id)
    db.add(task); db.flush()
    log_action(db, user.id, "care_task.create", "care_task", task.id)
    db.commit(); db.refresh(task)
    return view(task, patient)


@router.patch("/{task_id}")
def update_task(task_id: str, payload: TaskUpdate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    h = tenant_id(user)
    task = db.scalar(select(CareTask).where(CareTask.id == task_id, CareTask.hospital_id == h))
    if not task:
        raise HTTPException(404, "Task not found")
    result = db.execute(update(CareTask).where(CareTask.id == task_id, CareTask.hospital_id == h,
                                              CareTask.version == payload.version)
                        .values(status=payload.status, version=payload.version + 1,
                                completed_at=datetime.utcnow() if payload.status == "completed" else None))
    if result.rowcount != 1:
        db.rollback()
        raise HTTPException(409, "This task changed. Refresh before updating it.")
    log_action(db, user.id, "care_task.status", "care_task", task_id, metadata={"status": payload.status})
    db.commit(); db.refresh(task)
    return view(task, db.get(Patient, task.patient_id))
