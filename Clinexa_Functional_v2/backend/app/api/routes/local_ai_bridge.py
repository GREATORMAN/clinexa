"""Admin pairing and narrowly scoped, revocable PC worker credentials."""
import hmac
import secrets
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session
from app.core.audit import log_action
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.models.local_ai import LocalAIRequest, LocalAIWorker
from app.models.user import User
from app.services.local_ai_bridge import cleanup, digest, seal, unseal

router = APIRouter(prefix="/ai/bridge", tags=["Local AI bridge"])
bearer = HTTPBearer(auto_error=False)


class PairInput(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    model: str = Field(default="qwen3:1.7b", min_length=1, max_length=120, pattern=r"^[A-Za-z0-9][A-Za-z0-9._:/-]*$")


class PollInput(BaseModel):
    models: list[str] = Field(default_factory=list, max_length=100)
    ready: bool = False
    accept_jobs: bool = True


class ResultInput(BaseModel):
    lease: str = Field(min_length=20, max_length=100)
    answer: str = Field(default="", max_length=32000)
    error: bool = False


def worker_auth(credentials: HTTPAuthorizationCredentials | None = Depends(bearer), db: Session = Depends(get_db)):
    value = credentials.credentials if credentials else ""
    parts = value.split(".", 1)
    worker = db.scalar(select(LocalAIWorker).where(LocalAIWorker.id == parts[0]).with_for_update()) if len(parts) == 2 and len(value) <= 160 else None
    if not worker or not worker.enabled or not hmac.compare_digest(worker.secret_hash, digest(parts[1])):
        raise HTTPException(401, "Bridge credential is invalid or revoked")
    return worker


@router.post("/configure")
def configure(payload: PairInput, db: Session = Depends(get_db), user: User = Depends(require_permission("users.manage"))):
    hospital_id = tenant_id(user)
    worker = db.scalar(select(LocalAIWorker).where(LocalAIWorker.hospital_id == hospital_id).with_for_update())
    if worker:
        # Re-pairing invalidates the old PC and its outstanding responses immediately.
        db.execute(delete(LocalAIRequest).where(LocalAIRequest.worker_id == worker.id))
    else:
        worker = LocalAIWorker(hospital_id=hospital_id, created_by=user.id)
        db.add(worker)
    secret = secrets.token_urlsafe(32)
    worker.name = payload.name.strip() or "Clinexa PC"
    worker.model = payload.model
    worker.secret_hash = digest(secret)
    worker.enabled = True
    worker.ready = False
    worker.last_seen = None
    db.flush()
    log_action(db, user.id, "ai.bridge.pair", "local_ai_worker", worker.id)
    credential = f"{worker.id}.{secret}"
    db.commit()
    return {"credential": credential, "model": worker.model, "name": worker.name}


@router.delete("/configure")
def revoke(db: Session = Depends(get_db), user: User = Depends(require_permission("users.manage"))):
    worker = db.scalar(select(LocalAIWorker).where(LocalAIWorker.hospital_id == tenant_id(user)).with_for_update())
    if worker:
        worker.enabled = False
        worker.ready = False
        db.execute(delete(LocalAIRequest).where(LocalAIRequest.worker_id == worker.id))
        log_action(db, user.id, "ai.bridge.revoke", "local_ai_worker", worker.id)
    db.commit()
    return {"revoked": True}


@router.post("/poll")
def poll(payload: PollInput, worker: LocalAIWorker = Depends(worker_auth), db: Session = Depends(get_db)):
    # Row lock synchronizes claim, re-pairing, and revocation.
    worker = db.scalar(select(LocalAIWorker).where(LocalAIWorker.id == worker.id).with_for_update().execution_options(populate_existing=True))
    if not worker.enabled:
        raise HTTPException(401, "Bridge credential was revoked")
    cleanup(db)
    worker.last_seen = datetime.utcnow()
    worker.ready = payload.ready and worker.model in payload.models
    result = {"job": None, "model": worker.model}
    if worker.ready and payload.accept_jobs:
        active = db.scalar(select(LocalAIRequest.id).where(LocalAIRequest.worker_id == worker.id, LocalAIRequest.state == "running"))
        if not active:
            job = db.scalar(select(LocalAIRequest).where(LocalAIRequest.worker_id == worker.id,
                LocalAIRequest.state == "queued").order_by(LocalAIRequest.created_at).limit(1).with_for_update())
            if job:
                lease = secrets.token_urlsafe(24)
                claimed = db.execute(update(LocalAIRequest).where(LocalAIRequest.id == job.id,
                    LocalAIRequest.state == "queued").values(state="running", lease_hash=digest(lease)))
                if claimed.rowcount == 1:
                    result["job"] = {"id": job.id, "lease": lease, **unseal(job.payload)}
    db.commit()
    return result


@router.post("/requests/{job_id}/result")
def complete(job_id: str, payload: ResultInput, worker: LocalAIWorker = Depends(worker_auth), db: Session = Depends(get_db)):
    worker = db.scalar(select(LocalAIWorker).where(LocalAIWorker.id == worker.id).with_for_update().execution_options(populate_existing=True))
    if not worker.enabled:
        raise HTTPException(401, "Bridge credential was revoked")
    job = db.scalar(select(LocalAIRequest).where(LocalAIRequest.id == job_id,
        LocalAIRequest.worker_id == worker.id, LocalAIRequest.expires_at > datetime.utcnow()).with_for_update())
    if not job or job.state != "running" or not hmac.compare_digest(job.lease_hash or "", digest(payload.lease)):
        raise HTTPException(409, "Request expired, already completed, or lease is invalid")
    job.state = "failed" if payload.error or not payload.answer.strip() else "done"
    job.payload = ""  # Wipe the encrypted prompt as soon as inference finishes.
    job.result = seal({"answer": payload.answer}) if job.state == "done" else None
    job.lease_hash = None
    db.commit()
    return {"accepted": True}
