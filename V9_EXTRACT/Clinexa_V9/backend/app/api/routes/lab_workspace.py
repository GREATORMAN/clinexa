import json
from datetime import datetime
from typing import Literal
from fastapi import APIRouter,Depends,HTTPException
from pydantic import BaseModel,Field
from sqlalchemy import select,update
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import require_permission,tenant_id,permission_codes
from app.core.audit import log_action
from app.models.user import User
from app.models.clinical import Patient
from app.models.records import LabResult,OcrResult,MedicalDocument
from app.models.workspace import WorkspaceRecord,ClinicalRevision
from app.services.lab_parser import parse_lab
router=APIRouter(prefix='/lab-workspace',tags=['Lab verification and specimens'])
STAGES={'ordered':['collected','cancelled'],'collected':['received','rejected'],'received':['processing','rejected'],'processing':['technician_verified','rejected'],'technician_verified':['doctor_reviewed'],'doctor_reviewed':['released'],'released':[],'cancelled':[],'rejected':[]}
class SpecimenCreate(BaseModel):
    patient_id:str
    test_name:str=Field(min_length=1,max_length=200)
    specimen:str=Field(min_length=1,max_length=100)
class SpecimenUpdate(BaseModel):
    version:int=Field(ge=1)
    state:Literal['collected','received','processing','technician_verified','doctor_reviewed','released','cancelled','rejected']
    note:str=Field(default='',max_length=1000)
class TextInput(BaseModel):
    text:str=Field(max_length=100000)
class VerifiedField(BaseModel):
    test_name:str=Field(min_length=1,max_length=200)
    result_value:str=Field(min_length=1,max_length=120)
    unit:str=Field(default='',max_length=80)
    reference_range:str=Field(default='',max_length=120)
class VerifyInput(BaseModel):
    fields:list[VerifiedField]=Field(min_length=1,max_length=200)
    confirmed:bool
    version:int=Field(ge=1)

def patient(db,id,user):
    p=db.scalar(select(Patient).where(Patient.id==id,Patient.hospital_id==tenant_id(user)))
    if not p:raise HTTPException(404,'Patient not found')
    return p

def find(db,id,user):
    r=db.scalar(select(WorkspaceRecord).where(WorkspaceRecord.id==id,WorkspaceRecord.hospital_id==tenant_id(user),WorkspaceRecord.kind=='specimen'))
    if not r:raise HTTPException(404,'Specimen not found')
    return r

def view(r,name):return {'id':r.id,'patient_id':r.patient_id,'patient_name':name,'state':r.state,'version':r.version,'updated_at':r.updated_at,**json.loads(r.payload)}
def snapshot(db,r,user,reason):
    db.add(ClinicalRevision(hospital_id=r.hospital_id,resource_type='specimen',resource_id=r.id,version=r.version,snapshot=json.dumps({'state':r.state,'payload':json.loads(r.payload)}),actor_id=user.id,reason=reason))

@router.post('/parse')
def parse(payload:TextInput,user:User=Depends(require_permission('lab.orders.read'))):return parse_lab(payload.text)

@router.get('/documents/{id}/parse')
def parse_document(id:str,db:Session=Depends(get_db),user:User=Depends(require_permission('lab.orders.read'))):
    document=db.get(MedicalDocument,id)
    if not document:raise HTTPException(404,'Document not found')
    patient(db,document.patient_id,user)
    ocr=db.scalar(select(OcrResult).where(OcrResult.document_id==id).order_by(OcrResult.created_at.desc()))
    if not ocr:raise HTTPException(409,'Run document OCR first')
    return {'source_text':ocr.raw_text,**parse_lab(ocr.raw_text)}

@router.get('/specimens')
def list_specimens(db:Session=Depends(get_db),user:User=Depends(require_permission('lab.orders.read'))):
    rows=db.execute(select(WorkspaceRecord,Patient.full_name).join(Patient,Patient.id==WorkspaceRecord.patient_id).where(WorkspaceRecord.hospital_id==tenant_id(user),WorkspaceRecord.kind=='specimen').order_by(WorkspaceRecord.created_at.desc()).limit(500))
    return [view(r,n) for r,n in rows]

@router.post('/specimens',status_code=201)
def create(payload:SpecimenCreate,db:Session=Depends(get_db),user:User=Depends(require_permission('lab.orders.manage'))):
    p=patient(db,payload.patient_id,user)
    if not payload.test_name.strip() or not payload.specimen.strip():raise HTTPException(422,'Test and specimen are required')
    r=WorkspaceRecord(hospital_id=tenant_id(user),patient_id=p.id,kind='specimen',state='ordered',author_id=user.id,payload='{}');db.add(r);db.flush()
    r.payload=json.dumps({'test_name':payload.test_name.strip(),'specimen':payload.specimen.strip(),'accession_number':'CX-'+r.id.replace('-','').upper(),'fields':[],'timeline':[{'state':'ordered','at':datetime.utcnow().isoformat(),'actor_id':user.id,'note':''}]})
    snapshot(db,r,user,'Order created');log_action(db,user.id,'specimen.create','specimen',r.id);db.commit()
    return view(r,p.full_name)

@router.patch('/specimens/{id}/stage')
def stage(id:str,payload:SpecimenUpdate,db:Session=Depends(get_db),user:User=Depends(require_permission('lab.orders.manage'))):
    r=find(db,id,user);data=json.loads(r.payload)
    if payload.state not in STAGES[r.state]:raise HTTPException(409,'Invalid specimen transition')
    if payload.state=='technician_verified' and not ({'*','lab_results.upload'} & permission_codes(user)):raise HTTPException(403,'Result verification permission required')
    if payload.state in ('doctor_reviewed','released'):
        roles={x.name.lower() for x in user.roles}
        if not roles.intersection({'doctor','hospital administrator','super administrator'}):raise HTTPException(403,'Doctor review permission required')
    if payload.state=='technician_verified' and not data.get('fields'):raise HTTPException(409,'Verify the result fields first')
    if payload.state=='rejected' and not payload.note.strip():raise HTTPException(422,'A rejection reason is required')
    data['timeline'].append({'state':payload.state,'at':datetime.utcnow().isoformat(),'actor_id':user.id,'note':payload.note})
    changed=db.execute(update(WorkspaceRecord).where(WorkspaceRecord.id==id,WorkspaceRecord.version==payload.version,WorkspaceRecord.state==r.state).values(state=payload.state,payload=json.dumps(data),version=payload.version+1,updated_at=datetime.utcnow()))
    if changed.rowcount!=1:db.rollback();raise HTTPException(409,'Specimen changed. Reload before updating.')
    db.refresh(r)
    if r.state=='released':
        for field in data['fields']:db.add(LabResult(patient_id=r.patient_id,**field,verified=True,laboratory=data['accession_number']))
    snapshot(db,r,user,payload.note or payload.state);log_action(db,user.id,'specimen.'+r.state,'specimen',id);db.commit()
    return view(r,db.get(Patient,r.patient_id).full_name)

@router.post('/specimens/{id}/verify')
def verify(id:str,payload:VerifyInput,db:Session=Depends(get_db),user:User=Depends(require_permission('lab_results.upload'))):
    r=find(db,id,user)
    if r.state!='processing':raise HTTPException(409,'Only specimens in processing can accept verified fields')
    if not payload.confirmed:raise HTTPException(422,'Explicit verification is required')
    if any(not f.test_name.strip() or not f.result_value.strip() for f in payload.fields):raise HTTPException(422,'Test names and values cannot be blank')
    data=json.loads(r.payload);data['fields']=[f.model_dump() for f in payload.fields];data['verified_by']=user.id
    changed=db.execute(update(WorkspaceRecord).where(WorkspaceRecord.id==id,WorkspaceRecord.version==payload.version,WorkspaceRecord.state=='processing').values(payload=json.dumps(data),version=payload.version+1,updated_at=datetime.utcnow()))
    if changed.rowcount!=1:db.rollback();raise HTTPException(409,'Specimen changed. Reload before updating.')
    db.refresh(r);snapshot(db,r,user,'Fields manually verified');log_action(db,user.id,'specimen.verify','specimen',id);db.commit()
    return view(r,db.get(Patient,r.patient_id).full_name)
