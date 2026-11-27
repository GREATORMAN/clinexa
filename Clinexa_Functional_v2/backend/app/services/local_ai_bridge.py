"""Encrypted database queue; the PC initiates every connection over HTTPS."""
import asyncio
import base64
import hashlib
import json
import secrets
from datetime import datetime, timedelta
from time import monotonic
from cryptography.fernet import Fernet
from sqlalchemy import delete, func, select, update
from app.core.config import get_settings
from app.core.database import SessionLocal
from app.models.local_ai import LocalAIRequest, LocalAIWorker

STALE_SECONDS = 60
REQUEST_SECONDS = 100


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def cipher():
    settings = get_settings()
    key = hashlib.sha256(((settings.ENCRYPTION_KEY or settings.SECRET_KEY) + ":local-ai-requests").encode()).digest()
    return Fernet(base64.urlsafe_b64encode(key))


def seal(value):
    return cipher().encrypt(json.dumps(value).encode()).decode()


def unseal(value):
    return json.loads(cipher().decrypt(value.encode()))


def online(worker) -> bool:
    return bool(worker and worker.enabled and worker.ready and worker.last_seen
        and worker.last_seen > datetime.utcnow() - timedelta(seconds=STALE_SECONDS))


def status(hospital_id):
    with SessionLocal.begin() as db:
        cleanup(db)
        worker = db.scalar(select(LocalAIWorker).where(LocalAIWorker.hospital_id == hospital_id))
        return {"configured": bool(worker and worker.enabled), "online": online(worker),
            "model": worker.model if worker else get_settings().OLLAMA_MODEL,
            "provider": "local_pc_bridge", "connection": "outbound_https",
            "last_seen": worker.last_seen.isoformat() + "Z" if worker and worker.last_seen else None}


def cleanup(db):
    # Normal operation retains neither prompts nor answers after delivery/expiry.
    db.execute(delete(LocalAIRequest).where(LocalAIRequest.expires_at < datetime.utcnow()))


def enqueue(hospital_id, messages):
    with SessionLocal.begin() as db:
        cleanup(db)
        worker = db.scalar(select(LocalAIWorker).where(LocalAIWorker.hospital_id == hospital_id).with_for_update())
        if not online(worker):
            return None
        # Serialize per-PC queue admission, including across Cloud Run instances.
        db.execute(update(LocalAIWorker).where(LocalAIWorker.id == worker.id).values(ready=worker.ready))
        count = db.scalar(select(func.count()).select_from(LocalAIRequest).where(
            LocalAIRequest.worker_id == worker.id, LocalAIRequest.state.in_(["queued", "running"])))
        if count >= 4:
            return None
        content = {"model": worker.model, "messages": messages}
        if len(json.dumps(content).encode()) > 128000:
            return None
        job = LocalAIRequest(worker_id=worker.id, payload=seal(content),
            expires_at=datetime.utcnow() + timedelta(seconds=REQUEST_SECONDS))
        db.add(job)
        db.flush()
        return job.id


def collect(job_id):
    with SessionLocal.begin() as db:
        job = db.get(LocalAIRequest, job_id)
        if not job or job.expires_at <= datetime.utcnow():
            if job:
                db.delete(job)
            return "expired", None
        if job.state in {"done", "failed"}:
            result = unseal(job.result) if job.result else None
            state = job.state
            db.delete(job)
            return state, result
        return job.state, None


def discard(job_id):
    with SessionLocal.begin() as db:
        db.execute(delete(LocalAIRequest).where(LocalAIRequest.id == job_id))


async def chat(hospital_id, messages):
    job_id = await asyncio.to_thread(enqueue, hospital_id, messages)
    unavailable = {"online": False, "answer": "Local AI is unavailable or busy. Keep the paired PC awake, connected to the internet, and running START_LOCAL_AI.bat. The rest of Clinexa remains available.", "provider": "local_pc_bridge"}
    if not job_id:
        return unavailable
    try:
        deadline = monotonic() + REQUEST_SECONDS
        while monotonic() < deadline:
            state, result = await asyncio.to_thread(collect, job_id)
            if state == "done" and result:
                return {"online": True, "answer": result["answer"], "provider": "local_pc_bridge"}
            if state in {"failed", "expired"}:
                return unavailable
            await asyncio.sleep(0.6)
        return unavailable
    finally:
        await asyncio.to_thread(discard, job_id)
