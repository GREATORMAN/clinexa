import pytest
from tests.test_v8_workflows import env
from app.core.security import hash_password, verify_password, create_access_token, decode_token

def test_password_hashing():
    password = "SecurePassword123!"
    hashed = hash_password(password)
    assert hashed != password
    assert verify_password(password, hashed)
    assert not verify_password("bad", hashed)

def test_pyjwt_token_flow():
    token = create_access_token("user-test-123", session_id="sess-456")
    payload = decode_token(token)
    assert payload["sub"] == "user-test-123"
    assert payload["sid"] == "sess-456"
    assert payload["type"] == "access"

def test_cross_tenant_vitals_isolation_security(env):
    c, h, ids, _, _ = env
    # ids['p'] is in Hospital A, ids['q'] is in Hospital B
    # Clinician from Hospital A querying vitals of patient in Hospital B must receive 404
    resp = c.get(f"/api/v1/patients/{ids['q']}/vitals", headers=h("admin"))
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Patient not found"

def test_ai_chat_clinical_read_permission_security(env):
    c, h, ids, _, _ = env
    # 'desk' has Receptionist role (lacks patient.clinical.read)
    # Querying AI chat with a patient_id must return 403 Forbidden
    payload = {
        "message": "Summarize patient medical chart",
        "patient_id": ids["p"]
    }
    resp = c.post("/api/v1/ai/chat", headers=h("desk"), json=payload)
    assert resp.status_code == 403
    assert "patient.clinical.read" in resp.json()["detail"]

def test_security_headers_and_csp(env):
    c, _, _, _, _ = env
    resp = c.get("/health")
    assert resp.status_code == 200
    headers = resp.headers
    assert headers.get("X-Content-Type-Options") == "nosniff"
    assert headers.get("X-Frame-Options") == "DENY"
    assert "default-src 'self'" in headers.get("Content-Security-Policy", "")
    assert headers.get("Cache-Control") == "no-store, no-cache, must-revalidate"

def test_public_emergency_rate_limiting(env):
    c, _, _, _, _ = env
    # Rapid requests to public emergency card should eventually trigger 429
    url = "/api/v1/advanced/emergency/public/fake-token-probe"
    # Execute 32 rapid requests
    responses = [c.get(url).status_code for _ in range(32)]
    # First 30 will be 404 (token invalid), 31st and 32nd must trigger 429
    assert 429 in responses

def test_analytics_low_stock_optimization(env):
    c, h, _, _, _ = env
    resp = c.get("/api/v1/advanced/analytics/overview", headers=h("admin"))
    assert resp.status_code == 200
    data = resp.json()
    assert "low_stock_items" in data
    assert isinstance(data["low_stock_items"], int)
