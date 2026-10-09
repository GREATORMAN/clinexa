import json
from fastapi import APIRouter,Depends,HTTPException
from pydantic import BaseModel,EmailStr,Field
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user,tenant_id
from app.core.audit import log_action
from app.models.user import User
from app.models.account import UserAccountProfile
from app.models.workspace import CaregiverGrant
from app.models.records import MedicalDocument
from app.models.advanced import MedicationSchedule,EmergencyProfile,EmergencyAccessLog
from app.models.clinical import Patient,Appointment
from app.api.routes.portal import _patient_profile,home
router=APIRouter(tags=['Patient privacy and caregiver access'])
SCOPES={'appointments','reminders','emergency','selected_documents'}
class GrantInput(BaseModel):
    email:EmailStr
    scopes:list[str]=Field(min_length=1,max_length=4)
    document_ids:list[str]=Field(default_factory=list,max_length=50)
def view(db,g):
    user=db.get(User,g.caregiver_id);profile=db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id==g.caregiver_id))
    return {'id':g.id,'caregiver_name':user.full_name,'email':user.email,'approval_status':profile.approval_status if profile else 'unavailable','revoked':g.revoked,**json.loads(g.scopes),'created_at':g.created_at}
@router.get('/privacy/grants')
def grants(db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    _,patient=_patient_profile(db,user)
    return [view(db,g) for g in db.scalars(select(CaregiverGrant).where(CaregiverGrant.patient_id==patient.id))]
@router.post('/privacy/grants')
def grant(payload:GrantInput,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    _,patient=_patient_profile(db,user)
    if set(payload.scopes)-SCOPES:raise HTTPException(422,'Unknown sharing scope')
    caregiver=db.scalar(select(User).where(User.email==payload.email.lower(),User.hospital_id==patient.hospital_id,User.is_active==True))
    profile=db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id==caregiver.id)) if caregiver else None
    if not profile or profile.account_type!='caregiver':raise HTTPException(404,'No caregiver account is available with that email')
    if profile.approval_status=='rejected':raise HTTPException(403,'This caregiver account was rejected by the hospital')
    ids=set(payload.document_ids)
    available=set(db.scalars(select(MedicalDocument.id).where(MedicalDocument.patient_id==patient.id,MedicalDocument.id.in_(ids))))
    if ids!=available:raise HTTPException(404,'Selected document unavailable')
    if ids and 'selected_documents' not in payload.scopes:raise HTTPException(422,'Selected-document access must be enabled')
    g=db.scalar(select(CaregiverGrant).where(CaregiverGrant.patient_id==patient.id,CaregiverGrant.caregiver_id==caregiver.id))
    if not g:g=CaregiverGrant(patient_id=patient.id,caregiver_id=caregiver.id,granted_by=user.id,scopes='{}');db.add(g)
    g.scopes=json.dumps({'scopes':sorted(set(payload.scopes)),'document_ids':sorted(ids)});g.revoked=False
    if not profile.patient_id:profile.patient_id=patient.id
    db.flush();log_action(db,user.id,'caregiver.grant','caregiver_grant',g.id,metadata={'scopes':sorted(set(payload.scopes))});db.commit();return view(db,g)
@router.delete('/privacy/grants/{id}')
def revoke(id:str,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    _,patient=_patient_profile(db,user)
    g=db.scalar(select(CaregiverGrant).where(CaregiverGrant.id==id,CaregiverGrant.patient_id==patient.id))
    if not g:raise HTTPException(404,'Grant not found')
    g.revoked=True;log_action(db,user.id,'caregiver.revoke','caregiver_grant',id);db.commit();return {'revoked':True}
@router.get('/privacy/export')
def export(db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    result=home(db,user)
    log_action(db,user.id,'patient.export','patient',result['patient'].id);db.commit();return result
@router.get('/privacy/emergency-access')
def accesses(db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    _,patient=_patient_profile(db,user)
    return db.scalars(select(EmergencyAccessLog).where(EmergencyAccessLog.patient_id==patient.id).order_by(EmergencyAccessLog.accessed_at.desc()).limit(200)).all()
def allowed(db,id,user,scope=None):
    profile=db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id==user.id,UserAccountProfile.account_type=='caregiver',UserAccountProfile.approval_status=='approved'))
    if not profile:raise HTTPException(403,'An approved caregiver account is required')
    g=db.scalar(select(CaregiverGrant).join(Patient,Patient.id==CaregiverGrant.patient_id).where(CaregiverGrant.id==id,CaregiverGrant.caregiver_id==user.id,CaregiverGrant.revoked==False,Patient.hospital_id==tenant_id(user)))
    if not g:raise HTTPException(404,'Sharing grant unavailable')
    data=json.loads(g.scopes)
    if scope and scope not in data['scopes']:raise HTTPException(403,'The patient has not shared this category')
    return g,data
@router.get('/caregiver/grants')
def caregiver_grants(db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    profile=db.scalar(select(UserAccountProfile).where(UserAccountProfile.user_id==user.id,UserAccountProfile.account_type=='caregiver',UserAccountProfile.approval_status=='approved'))
    if not profile:raise HTTPException(403,'Approved caregiver account required')
    rows=db.execute(select(CaregiverGrant,Patient).join(Patient,Patient.id==CaregiverGrant.patient_id).where(CaregiverGrant.caregiver_id==user.id,CaregiverGrant.revoked==False,Patient.hospital_id==tenant_id(user)))
    return [{'id':g.id,'patient_name':p.full_name,**json.loads(g.scopes)} for g,p in rows]
@router.get('/caregiver/grants/{id}/{scope}')
def shared(id:str,scope:str,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    if scope not in SCOPES:raise HTTPException(404,'Unknown sharing category')
    g,data=allowed(db,id,user,scope)
    if scope=='appointments':result=db.scalars(select(Appointment).where(Appointment.patient_id==g.patient_id).order_by(Appointment.start_at.desc()).limit(100)).all()
    elif scope=='reminders':result=db.scalars(select(MedicationSchedule).where(MedicationSchedule.patient_id==g.patient_id,MedicationSchedule.active==True)).all()
    elif scope=='emergency':result=db.scalar(select(EmergencyProfile).where(EmergencyProfile.patient_id==g.patient_id,EmergencyProfile.enabled==True))
    else:
        result=[{'id':d.id,'name':d.original_name,'category':d.category,'description':d.description} for d in db.scalars(select(MedicalDocument).where(MedicalDocument.patient_id==g.patient_id,MedicalDocument.id.in_(data['document_ids'])))]
    log_action(db,user.id,'caregiver.read','caregiver_grant',id,metadata={'scope':scope});db.commit();return result
@router.get('/caregiver/grants/{id}/documents/{document_id}/download')
def download(id:str,document_id:str,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    from fastapi.responses import FileResponse
    from app.services.storage import path_for
    g,data=allowed(db,id,user,'selected_documents')
    document=db.scalar(select(MedicalDocument).where(MedicalDocument.id==document_id,MedicalDocument.patient_id==g.patient_id))
    if not document or document_id not in data['document_ids']:raise HTTPException(404,'Document unavailable')
    path=path_for(document.stored_name)
    if not path.exists():raise HTTPException(404,'File unavailable')
    log_action(db,user.id,'caregiver.download','document',document.id);db.commit();return FileResponse(path,media_type=document.mime_type,filename=document.original_name)
