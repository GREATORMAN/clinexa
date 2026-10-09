from fastapi import APIRouter,Depends,HTTPException,Request
from pydantic import BaseModel,Field
from sqlalchemy import select,update
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.audit import log_action
from app.models.user import User
from app.models.workspace import DeviceSession
from app.models.session import RefreshToken
router=APIRouter(prefix='/account',tags=['Device sessions'])
class Label(BaseModel):
    label:str=Field(min_length=1,max_length=200)
def revoke(db,row,user):
    row.revoked=True
    db.execute(update(RefreshToken).where(RefreshToken.user_id==user.id,RefreshToken.token_id==row.token_id).values(revoked=True))
    log_action(db,user.id,'session.revoke','device_session',row.id)
@router.get('/sessions')
def sessions(request:Request,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    return [{'id':r.id,'label':r.label,'created_at':r.created_at,'revoked':r.revoked,'current':r.id==getattr(request.state,'session_id',None)} for r in db.scalars(select(DeviceSession).where(DeviceSession.user_id==user.id).order_by(DeviceSession.created_at.desc()).limit(100))]
@router.patch('/sessions/{id}')
def label(id:str,payload:Label,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    row=db.scalar(select(DeviceSession).where(DeviceSession.id==id,DeviceSession.user_id==user.id))
    if not row:raise HTTPException(404,'Session not found')
    if not payload.label.strip():raise HTTPException(422,'Enter a device name')
    row.label=payload.label.strip();db.commit();return {'updated':True}
@router.delete('/sessions/{id}')
def revoke_session(id:str,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    row=db.scalar(select(DeviceSession).where(DeviceSession.id==id,DeviceSession.user_id==user.id))
    if not row:raise HTTPException(404,'Session not found')
    revoke(db,row,user);db.commit();return {'revoked':True}
@router.post('/sessions/revoke-all')
def revoke_all(db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    for row in db.scalars(select(DeviceSession).where(DeviceSession.user_id==user.id,DeviceSession.revoked==False)):revoke(db,row,user)
    db.execute(update(RefreshToken).where(RefreshToken.user_id==user.id).values(revoked=True));db.commit();return {'revoked':True}
@router.post('/logout')
def logout(request:Request,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    id=getattr(request.state,'session_id',None)
    if id:
        row=db.get(DeviceSession,id)
        if row:revoke(db,row,user)
    db.commit();return {'revoked':True}
