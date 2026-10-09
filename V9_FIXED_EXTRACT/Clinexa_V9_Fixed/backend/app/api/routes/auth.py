from datetime import datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from sqlalchemy import select, update

from app.core.audit import log_action
from app.core.config import get_settings
from app.core.database import get_db
from app.core.dependencies import get_current_user, permission_codes
from app.core.rbac_seed import ACCOUNT_TYPE_TO_ROLE, STAFF_ACCOUNT_TYPES, ensure_role
from app.core.security import hash_password, verify_password, create_access_token, create_refresh_token, decode_token
from app.models.account import UserAccountProfile
from app.models.organization import Hospital
from app.models.clinical import Patient
from app.models.user import User
from app.models.session import RefreshToken
from app.models.workspace import DeviceSession, MfaFactor
from app.services.mfa import cipher, verify as verify_mfa
from app.schemas.auth import ACCOUNT_TYPES, RegisterRequest, LoginRequest, RefreshRequest, TokenPair, UserView

router = APIRouter(prefix="/auth", tags=["Authentication"])
settings = get_settings()


def view(db: Session, user: User) -> UserView:
    profile = db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id == user.id))
    return UserView(
        id=user.id,
        full_name=user.full_name,
        email=user.email,
        is_staff=user.is_staff,
        hospital_id=user.hospital_id,
        roles=[r.name for r in user.roles],
        permissions=sorted(permission_codes(user)),
        account_type=profile.account_type if profile else None,
        approval_status=profile.approval_status if profile else None,
    )


@router.post("/register", response_model=UserView, status_code=201)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    email = payload.email.lower()
    account_type = payload.account_type.strip().lower()
    if account_type not in ACCOUNT_TYPES:
        raise HTTPException(status_code=422, detail="Unsupported account type")
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status_code=409, detail="Account already exists")

    hospital = db.scalar(select(Hospital).where(Hospital.code == "CLINEXA"))
    if not hospital:
        hospital = Hospital(name="Clinexa Hospital", code="CLINEXA", address="Development hospital")
        db.add(hospital)
        db.flush()

    staff = account_type in STAFF_ACCOUNT_TYPES
    requires_approval = staff or account_type == "caregiver"
    approval_status = "pending" if requires_approval else "approved"
    user = User(
        full_name=payload.full_name.strip(),
        email=email,
        password_hash=hash_password(payload.password),
        hospital_id=hospital.id,
        is_staff=staff,
        is_verified=not staff,
    )
    db.add(user)
    db.flush()
    patient_id = None
    if account_type == "patient":
        patient = Patient(
            hospital_id=hospital.id,
            patient_code=f"PT-{uuid4().hex[:8].upper()}",
            full_name=user.full_name,
            email=email,
        )
        db.add(patient)
        db.flush()
        patient_id = patient.id

    profile = UserAccountProfile(
        user_id=user.id,
        account_type=account_type,
        approval_status=approval_status,
        patient_id=patient_id,
        specialty=(payload.specialty.strip() if payload.specialty else None),
    )
    db.add(profile)

    if not requires_approval:
        role_name = ACCOUNT_TYPE_TO_ROLE[account_type]
        user.roles.append(ensure_role(db, role_name))

    log_action(
        db,
        user.id,
        "auth.register",
        "user",
        user.id,
        metadata={"account_type": account_type, "approval_status": approval_status},
    )
    db.commit()
    db.refresh(user)
    return view(db, user)


@router.post("/login", response_model=TokenPair)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if not user or not user.is_active or not verify_password(payload.password, user.password_hash):
        log_action(db, None, "auth.login.failed", "user", result="failure")
        db.commit()
        raise HTTPException(status_code=401, detail="Invalid credentials")
    factor = db.get(MfaFactor, user.id)
    if factor and factor.enabled:
        counter = verify_mfa(cipher().decrypt(factor.encrypted_secret.encode()).decode(), payload.mfa_code or "", factor.last_counter)
        if counter is None: raise HTTPException(401, "Authenticator code required or invalid")
        changed = db.execute(update(MfaFactor).where(MfaFactor.user_id == user.id, MfaFactor.last_counter == factor.last_counter).values(last_counter=counter))
        if changed.rowcount != 1:
            db.rollback(); raise HTTPException(401, "Authenticator code already used")
    if payload.account_type:
        expected = payload.account_type.strip().lower()
        if expected not in ACCOUNT_TYPES:
            raise HTTPException(status_code=422, detail="Unsupported account type")
        profile = db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id == user.id))
        if profile and profile.account_type != expected:
            display = profile.account_type.replace("_", " ").title()
            raise HTTPException(status_code=403, detail=f"This account belongs to the {display} workspace")
    token_id = str(uuid4())
    db.add(
        RefreshToken(
            token_id=token_id,
            user_id=user.id,
            expires_at=datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
    )
    session = DeviceSession(user_id=user.id, token_id=token_id, label=request.headers.get("user-agent", "Clinexa")[:200])
    db.add(session); db.flush()
    log_action(db, user.id, "auth.login", "user", user.id)
    db.commit()
    return TokenPair(access_token=create_access_token(user.id, session.id), refresh_token=create_refresh_token(user.id, token_id))


@router.post("/refresh", response_model=TokenPair)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)):
    try:
        decoded = decode_token(payload.refresh_token)
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
    if decoded.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid token type")
    old = db.scalar(select(RefreshToken).where(RefreshToken.token_id == decoded.get("jti")))
    if not old or old.revoked or old.expires_at <= datetime.utcnow():
        raise HTTPException(status_code=401, detail="Refresh token unavailable")
    user = db.get(User, decoded.get("sub"))
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Account unavailable")
    session = db.scalar(select(DeviceSession).where(DeviceSession.token_id == old.token_id, DeviceSession.user_id == user.id))
    if session and session.revoked:
        raise HTTPException(401, "Session revoked")
    claimed = db.execute(update(RefreshToken).where(RefreshToken.id == old.id, RefreshToken.revoked == False).values(revoked=True))
    if claimed.rowcount != 1:
        db.rollback(); raise HTTPException(401, "Refresh token already used")
    new_id = str(uuid4())
    db.add(
        RefreshToken(
            token_id=new_id,
            user_id=user.id,
            expires_at=datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
    )
    if session: session.token_id = new_id
    else:
        session = DeviceSession(user_id=user.id, token_id=new_id, label="Migrated session"); db.add(session); db.flush()
    db.commit()
    return TokenPair(access_token=create_access_token(user.id, session.id), refresh_token=create_refresh_token(user.id, new_id))


@router.get("/me", response_model=UserView)
def me(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return view(db, user)
