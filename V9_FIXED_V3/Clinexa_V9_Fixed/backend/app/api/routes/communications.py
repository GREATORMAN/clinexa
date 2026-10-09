from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, or_, update
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import require_permission, get_current_user, tenant_id
from app.models.user import User
from app.models.operations import Message, Notification, CarePlan
from app.models.clinical import Patient
from app.schemas.domain import MessageCreate, CarePlanCreate

router = APIRouter(tags=["Communications and Care"])

@router.post("/messages", status_code=201)
def send_message(payload: MessageCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("messages.send"))):
    recipient = db.get(User, payload.recipient_user_id)
    if not recipient or recipient.hospital_id != tenant_id(user):
        raise HTTPException(status_code=400, detail="Recipient unavailable")
    row = Message(hospital_id=tenant_id(user), sender_user_id=user.id, recipient_user_id=recipient.id, body=payload.body)
    db.add(row); db.commit(); db.refresh(row); return row

@router.get("/messages")
def messages(db: Session = Depends(get_db), user: User = Depends(require_permission("messages.read"))):
    return db.scalars(select(Message).where(Message.hospital_id == tenant_id(user), or_(Message.sender_user_id == user.id, Message.recipient_user_id == user.id)).order_by(Message.created_at.desc()).limit(200)).all()

@router.get("/notifications")
def notifications(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return db.scalars(select(Notification).where(Notification.user_id == user.id).order_by(Notification.created_at.desc()).limit(200)).all()

@router.patch("/notifications/{notification_id}/read")
def notification_read(notification_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    row = db.scalar(select(Notification).where(Notification.id == notification_id, Notification.user_id == user.id))
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    row.is_read = True; db.commit(); db.refresh(row); return row

@router.post("/care-plans", status_code=201)
def care_plan(payload: CarePlanCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.write"))):
    if not db.scalar(select(Patient).where(Patient.id == payload.patient_id, Patient.hospital_id == tenant_id(user))):
        raise HTTPException(status_code=404, detail="Patient not found")
    row = CarePlan(**payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row

@router.post("/notifications/read-all")
def read_all(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    result = db.execute(update(Notification).where(Notification.user_id == user.id, Notification.is_read == False).values(is_read=True))
    db.commit()
    return {"updated": result.rowcount}

@router.get('/message-contacts')
def contacts(db:Session=Depends(get_db),user:User=Depends(require_permission('messages.read'))):
    return [{'id':u.id,'full_name':u.full_name} for u in db.scalars(select(User).where(User.hospital_id==tenant_id(user),User.is_active==True,User.id!=user.id).order_by(User.full_name))]

@router.get('/messages/thread/{contact_id}')
def thread(contact_id:str,db:Session=Depends(get_db),user:User=Depends(require_permission('messages.read'))):
    contact=db.scalar(select(User).where(User.id==contact_id,User.hospital_id==tenant_id(user),User.is_active==True))
    if not contact:raise HTTPException(404,'Contact unavailable')
    from sqlalchemy import and_
    return db.scalars(select(Message).where(Message.hospital_id==tenant_id(user),or_(and_(Message.sender_user_id==user.id,Message.recipient_user_id==contact_id),and_(Message.sender_user_id==contact_id,Message.recipient_user_id==user.id))).order_by(Message.created_at).limit(500)).all()

@router.post('/messages/thread/{contact_id}/read')
def read_thread(contact_id:str,db:Session=Depends(get_db),user:User=Depends(require_permission('messages.read'))):
    result=db.execute(update(Message).where(Message.hospital_id==tenant_id(user),Message.sender_user_id==contact_id,Message.recipient_user_id==user.id,Message.is_read==False).values(is_read=True));db.commit();return {'updated':result.rowcount}
