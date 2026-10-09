from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session, selectinload
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import decode_token
from app.models.user import User
from app.models.rbac import Role
from app.models.workspace import DeviceSession

bearer = HTTPBearer(auto_error=False)

def get_current_user(request: Request, credentials: HTTPAuthorizationCredentials | None = Depends(bearer), db: Session = Depends(get_db)) -> User:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Authentication required")
    try:
        payload = decode_token(credentials.credentials)
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    if payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid token type")
    user = db.scalar(select(User).options(selectinload(User.roles).selectinload(Role.permissions)).where(User.id == payload.get("sub")))
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="Account unavailable")
    sid = payload.get("sid")
    if not sid:
        raise HTTPException(401, "Refresh your session to continue")
    if sid:
        session = db.scalar(select(DeviceSession).where(DeviceSession.id == sid, DeviceSession.user_id == user.id))
        if not session or session.revoked:
            raise HTTPException(401, "Session revoked")
    request.state.session_id = sid
    return user

def permission_codes(user: User) -> set[str]:
    return {p.code for role in user.roles for p in role.permissions}

def require_permission(code: str):
    def checker(user: User = Depends(get_current_user)) -> User:
        permissions = permission_codes(user)
        if "*" not in permissions and code not in permissions:
            raise HTTPException(status_code=403, detail="Permission denied")
        return user
    return checker

def tenant_id(user: User) -> str:
    if not user.hospital_id:
        raise HTTPException(status_code=403, detail="User is not assigned to a hospital")
    return user.hospital_id
