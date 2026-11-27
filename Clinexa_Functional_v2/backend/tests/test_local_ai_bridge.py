import asyncio
from datetime import datetime, timedelta
import pytest
from sqlalchemy import select
from tests.test_v8_workflows import env
from app.models.local_ai import LocalAIRequest, LocalAIWorker
from app.services import local_ai_bridge as bridge


@pytest.fixture
def setup(env, monkeypatch):
    c, headers, ids, sessions, tokens = env
    monkeypatch.setattr(bridge, "SessionLocal", sessions)
    return env


def pair(setup, account="admin"):
    c, headers, ids, sessions, tokens = setup
    response = c.post("/api/v1/ai/bridge/configure", headers=headers(account),
        json={"name": "Test PC", "model": "qwen3:1.7b"})
    assert response.status_code == 200, response.text
    return {"Authorization": "Bearer " + response.json()["credential"]}


def poll(c, key, **extra):
    return c.post("/api/v1/ai/bridge/poll", headers=key,
        json={"models": ["qwen3:1.7b"], "ready": True, **extra})


def test_pairing_requires_admin_and_worker_cannot_use_user_api(setup):
    c, headers, ids, sessions, tokens = setup
    for account in ("patient", "desk"):
        assert c.post("/api/v1/ai/bridge/configure", headers=headers(account),
            json={"name": "No"}).status_code == 403
    key = pair(setup)
    assert c.get("/api/v1/admin/users", headers=key).status_code == 401
    assert poll(c, headers()).status_code == 401
    assert c.post("/api/v1/ai/bridge/poll", json={}).status_code == 401


def test_model_heartbeat_stale_detection_and_bounded_encrypted_queue(setup):
    c, headers, ids, sessions, tokens = setup
    key = pair(setup)
    with sessions() as db:
        hospital_id = db.get(LocalAIWorker, key["Authorization"].split()[1].split(".")[0]).hospital_id
    assert bridge.enqueue(hospital_id, [{"role": "user", "content": "Private record"}]) is None
    assert poll(c, key).status_code == 200
    assert bridge.status(hospital_id)["online"]
    for _ in range(4):
        assert bridge.enqueue(hospital_id, [{"role": "user", "content": "Private record"}])
    assert bridge.enqueue(hospital_id, []) is None
    with sessions() as db:
        assert all("Private record" not in row.payload for row in db.scalars(select(LocalAIRequest)))
        worker = db.scalar(select(LocalAIWorker))
        worker.last_seen = datetime.utcnow() - timedelta(minutes=2)
        db.commit()
    assert not bridge.status(hospital_id)["online"]


def test_claim_completion_lease_and_tenant_isolation(setup):
    c, headers, ids, sessions, tokens = setup
    key = pair(setup)
    other = pair(setup, "other")
    poll(c, key)
    with sessions() as db:
        hospital_id = db.get(LocalAIWorker, key["Authorization"].split()[1].split(".")[0]).hospital_id
    job_id = bridge.enqueue(hospital_id, [{"role": "user", "content": "Summarize authorized facts"}])
    assert poll(c, other).json()["job"] is None
    job = poll(c, key).json()["job"]
    assert job["id"] == job_id
    assert poll(c, key).json()["job"] is None
    url = f"/api/v1/ai/bridge/requests/{job_id}/result"
    result = {"lease": job["lease"], "answer": "Draft summary"}
    assert c.post(url, headers=other, json=result).status_code == 409
    assert c.post(url, headers=key, json={**result, "lease": "wrong" * 8}).status_code == 409
    assert c.post(url, headers=key, json=result).status_code == 200
    assert c.post(url, headers=key, json=result).status_code == 409
    with sessions() as db:
        row = db.get(LocalAIRequest, job_id)
        assert row.payload == "" and "Draft summary" not in row.result
    assert bridge.collect(job_id) == ("done", {"answer": "Draft summary"})
    with sessions() as db:
        assert db.get(LocalAIRequest, job_id) is None


def test_expiry_repair_and_revocation_clear_requests(setup):
    c, headers, ids, sessions, tokens = setup
    key = pair(setup)
    poll(c, key)
    with sessions() as db:
        hospital_id = db.scalar(select(LocalAIWorker)).hospital_id
    job_id = bridge.enqueue(hospital_id, [])
    job = poll(c, key).json()["job"]
    with sessions() as db:
        db.get(LocalAIRequest, job_id).expires_at = datetime.utcnow() - timedelta(seconds=1)
        db.commit()
    assert c.post(f"/api/v1/ai/bridge/requests/{job_id}/result", headers=key,
        json={"lease": job["lease"], "answer": "Late"}).status_code == 409
    assert bridge.collect(job_id) == ("expired", None)
    new_key = pair(setup)
    assert poll(c, key).status_code == 401
    poll(c, new_key)
    assert bridge.enqueue(hospital_id, [])
    assert c.delete("/api/v1/ai/bridge/configure", headers=headers()).status_code == 200
    assert poll(c, new_key).status_code == 401
    with sessions() as db:
        assert db.scalar(select(LocalAIRequest)) is None


def test_cloud_chat_receives_real_pc_response_and_offline_is_explicit(setup):
    c, headers, ids, sessions, tokens = setup
    key = pair(setup)
    poll(c, key)
    with sessions() as db:
        hospital_id = db.scalar(select(LocalAIWorker)).hospital_id

    async def exchange():
        task = asyncio.create_task(bridge.chat(hospital_id, [{"role": "user", "content": "Hello"}]))
        job = None
        for _ in range(30):
            await asyncio.sleep(0.05)
            response = await asyncio.to_thread(poll, c, key)
            job = response.json()["job"]
            if job:
                break
        assert job
        response = await asyncio.to_thread(c.post, f"/api/v1/ai/bridge/requests/{job['id']}/result",
            headers=key, json={"lease": job["lease"], "answer": "Hello from the local model"})
        assert response.status_code == 200
        result = await asyncio.wait_for(task, 4)
        assert result["online"] and result["answer"] == "Hello from the local model"
    asyncio.run(exchange())
    c.post("/api/v1/ai/bridge/poll", headers=key, json={"models": [], "ready": False})
    response = c.post("/api/v1/ai/chat", headers=headers(), json={"message": "Write a welcome message"})
    assert response.status_code == 200
    assert not response.json()["online"]
    assert response.json()["provider"] == "unavailable"
    assert not c.get("/api/v1/ai/status", headers=headers()).json()["engine_online"]
