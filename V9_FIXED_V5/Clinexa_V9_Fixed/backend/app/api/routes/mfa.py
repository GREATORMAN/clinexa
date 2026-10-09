from urllib.parse import quote
from fastapi import APIRouter,Depends,HTTPException
from pydantic import BaseModel,Field
from sqlalchemy import update
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.security import verify_password
from app.core.audit import log_action
from app.models.workspace import MfaFactor,DeviceSession
from app.models.session import RefreshToken
from app.models.user import User
from app.services.mfa import cipher,new_secret,verify
router=APIRouter(prefix='/account/mfa',tags=['Authenticator MFA'])
class Setup(BaseModel):
    password:str
class Code(BaseModel):
    code:str=Field(pattern=r'^\d{6}$')
class Disable(Code):
    password:str
@router.get('')
def status(db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    factor=db.get(MfaFactor,user.id);return {'enabled':bool(factor and factor.enabled)}
@router.post('/setup')
def setup(payload:Setup,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    if not verify_password(payload.password,user.password_hash):raise HTTPException(401,'Invalid password')
    factor=db.get(MfaFactor,user.id)
    if factor and factor.enabled:raise HTTPException(409,'MFA is already enabled')
    secret=new_secret()
    if not factor:factor=MfaFactor(user_id=user.id);db.add(factor)
    factor.encrypted_secret=cipher().encrypt(secret.encode()).decode();factor.last_counter=-1;factor.enabled=False;db.commit()
    return {'secret':secret,'otpauth_url':f'otpauth://totp/Clinexa:{quote(user.email)}?secret={secret}&issuer=Clinexa&algorithm=SHA1&digits=6&period=30'}
@router.post('/confirm')
def confirm(payload:Code,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    factor=db.get(MfaFactor,user.id)
    if not factor or factor.enabled:raise HTTPException(409,'Start enrollment first')
    counter=verify(cipher().decrypt(factor.encrypted_secret.encode()).decode(),payload.code)
    if counter is None:raise HTTPException(422,'Invalid authenticator code')
    factor.enabled=True;factor.last_counter=counter
    # Existing sessions must reauthenticate with the second factor.
    db.execute(update(DeviceSession).where(DeviceSession.user_id==user.id).values(revoked=True))
    db.execute(update(RefreshToken).where(RefreshToken.user_id==user.id).values(revoked=True))
    log_action(db,user.id,'mfa.enable','user',user.id);db.commit();return {'enabled':True,'reauthenticate':True}
@router.post('/disable')
def disable(payload:Disable,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    factor=db.get(MfaFactor,user.id)
    if not factor or not factor.enabled:raise HTTPException(409,'MFA is not enabled')
    counter=verify(cipher().decrypt(factor.encrypted_secret.encode()).decode(),payload.code,factor.last_counter)
    if not verify_password(payload.password,user.password_hash) or counter is None:raise HTTPException(401,'Invalid credentials')
    changed=db.execute(update(MfaFactor).where(MfaFactor.user_id==user.id,MfaFactor.last_counter==factor.last_counter).values(enabled=False,last_counter=counter))
    if changed.rowcount!=1:db.rollback();raise HTTPException(409,'Retry with a fresh code')
    log_action(db,user.id,'mfa.disable','user',user.id);db.commit();return {'enabled':False}
