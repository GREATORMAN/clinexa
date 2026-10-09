import hashlib,json,secrets
from datetime import datetime,timedelta
from fastapi import APIRouter,Depends,HTTPException
from pydantic import BaseModel,EmailStr,Field
from sqlalchemy import select,update
from sqlalchemy.orm import Session
from app.core.config import get_settings
from app.core.database import get_db
from app.core.security import hash_password
from app.core.audit import log_action
from app.models.user import User
from app.models.workspace import RecoveryTicket,Job,DeviceSession
from app.models.session import RefreshToken
from app.services.mfa import cipher
router=APIRouter(prefix='/auth',tags=['Password recovery'])
class Forgot(BaseModel):email:EmailStr
class Reset(BaseModel):
    token:str=Field(min_length=30,max_length=200)
    password:str=Field(min_length=10,max_length=128)
@router.post('/forgot-password',status_code=202)
def forgot(payload:Forgot,db:Session=Depends(get_db)):
    user=db.scalar(select(User).where(User.email==payload.email.lower(),User.is_active==True))
    if user:
        db.execute(update(RecoveryTicket).where(RecoveryTicket.user_id==user.id,RecoveryTicket.used==False).values(used=True))
        token=secrets.token_urlsafe(48)
        db.add(RecoveryTicket(user_id=user.id,token_hash=hashlib.sha256(token.encode()).hexdigest(),expires_at=datetime.utcnow()+timedelta(minutes=30)))
        encrypted=cipher().encrypt(json.dumps({'email':user.email,'token':token}).encode()).decode()
        db.add(Job(kind='password_reset_email',payload=encrypted))
        log_action(db,user.id,'password_reset.request','user',user.id);db.commit()
    return {'message':'If this account exists, a reset email has been queued. Delivery requires the configured mail service.'}
@router.post('/reset-password')
def reset(payload:Reset,db:Session=Depends(get_db)):
    hashed=hashlib.sha256(payload.token.encode()).hexdigest()
    ticket=db.scalar(select(RecoveryTicket).where(RecoveryTicket.token_hash==hashed))
    if not ticket or ticket.used or ticket.expires_at<=datetime.utcnow():raise HTTPException(422,'Invalid or expired reset token')
    changed=db.execute(update(RecoveryTicket).where(RecoveryTicket.id==ticket.id,RecoveryTicket.used==False,RecoveryTicket.expires_at>datetime.utcnow()).values(used=True))
    if changed.rowcount!=1:db.rollback();raise HTTPException(422,'Reset token already used')
    user=db.get(User,ticket.user_id)
    if not user or not user.is_active:db.rollback();raise HTTPException(422,'Account unavailable')
    user.password_hash=hash_password(payload.password)
    db.execute(update(DeviceSession).where(DeviceSession.user_id==user.id).values(revoked=True))
    db.execute(update(RefreshToken).where(RefreshToken.user_id==user.id).values(revoked=True))
    log_action(db,user.id,'password_reset.complete','user',user.id);db.commit()
    return {'message':'Password updated. Sign in again. MFA remains enabled if previously configured.'}
