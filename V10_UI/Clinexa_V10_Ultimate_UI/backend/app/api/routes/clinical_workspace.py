"""Versioned clinical notes. Updates use database compare-and-swap, never last-write-wins."""
import json
from datetime import datetime
from typing import Literal
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select, update
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.core.audit import log_action
from app.models.user import User
from app.models.clinical import Patient
from app.models.workspace import ClinicalDraft, ClinicalRevision

router=APIRouter(prefix='/clinical-notes',tags=['Versioned clinical notes'])

class NoteCreate(BaseModel):
    patient_id: str
    title: str=Field(min_length=1,max_length=200)
    content: str=Field(default='',max_length=50000)
    @field_validator('title')
    @classmethod
    def title_present(cls,v):
        if not v.strip(): raise ValueError('Enter a title')
        return v.strip()

class NoteUpdate(BaseModel):
    version: int=Field(ge=1)
    content: str=Field(max_length=50000)
    title: str=Field(min_length=1,max_length=200)
    action: Literal['save','finalize','amend']='save'
    reason: str=Field(default='',max_length=500)
    @field_validator('title')
    @classmethod
    def title_present(cls,v):
        if not v.strip(): raise ValueError('Enter a title')
        return v.strip()

def view(note): return {c.name:getattr(note,c.name) for c in note.__table__.columns}
def revision(db,note,user,reason):
    db.add(ClinicalRevision(hospital_id=note.hospital_id,resource_type='note',resource_id=note.id,
        version=note.version,snapshot=json.dumps(view(note),default=str),actor_id=user.id,reason=reason))

def find(db,id,user):
    note=db.scalar(select(ClinicalDraft).where(ClinicalDraft.id==id,ClinicalDraft.hospital_id==tenant_id(user)))
    if not note: raise HTTPException(404,'Note not found')
    return note

@router.get('')
def list_notes(patient_id:str|None=None,db:Session=Depends(get_db),user:User=Depends(require_permission('patient.clinical.read'))):
    query=select(ClinicalDraft,Patient.full_name).join(Patient,Patient.id==ClinicalDraft.patient_id).where(ClinicalDraft.hospital_id==tenant_id(user))
    if patient_id: query=query.where(ClinicalDraft.patient_id==patient_id)
    return [{**view(n),'patient_name':name} for n,name in db.execute(query.order_by(ClinicalDraft.updated_at.desc()).limit(500))]

@router.post('',status_code=201)
def create(payload:NoteCreate,db:Session=Depends(get_db),user:User=Depends(require_permission('patient.clinical.write'))):
    patient=db.scalar(select(Patient).where(Patient.id==payload.patient_id,Patient.hospital_id==tenant_id(user)))
    if not patient: raise HTTPException(404,'Patient not found')
    note=ClinicalDraft(**payload.model_dump(),hospital_id=tenant_id(user),author_id=user.id)
    db.add(note);db.flush();revision(db,note,user,'Created draft')
    log_action(db,user.id,'note.create','clinical_note',note.id);db.commit()
    return {**view(note),'patient_name':patient.full_name}

@router.patch('/{id}')
def save(id:str,payload:NoteUpdate,db:Session=Depends(get_db),user:User=Depends(require_permission('patient.clinical.write'))):
    note=find(db,id,user)
    if note.author_id!=user.id: raise HTTPException(403,'Only the author may edit or finalize this note')
    if note.status=='final' and payload.action!='amend': raise HTTPException(409,'Final notes are locked. Use an amendment with a reason.')
    if payload.action=='amend' and (note.status!='final' or not payload.reason.strip()): raise HTTPException(422,'Amendments require a final note and a reason')
    if payload.action in ('finalize','amend') and not payload.content.strip(): raise HTTPException(422,'A final note cannot be empty')
    status='final' if payload.action in ('finalize','amend') else 'draft'
    values=dict(content=payload.content,title=payload.title,status=status,version=payload.version+1,updated_at=datetime.utcnow())
    changed=db.execute(update(ClinicalDraft).where(ClinicalDraft.id==id,ClinicalDraft.version==payload.version,ClinicalDraft.status==note.status).values(**values))
    if changed.rowcount!=1:
        db.rollback();raise HTTPException(409,'This note changed elsewhere. Your text has not been overwritten. Reload and compare before saving.')
    db.flush();db.refresh(note);revision(db,note,user,payload.reason.strip() or ('Finalized' if status=='final' else 'Draft saved'))
    log_action(db,user.id,'note.'+payload.action,'clinical_note',id,metadata={'version':note.version});db.commit()
    return {**view(note),'patient_name':db.get(Patient,note.patient_id).full_name}

@router.get('/{id}/history')
def history(id:str,db:Session=Depends(get_db),user:User=Depends(require_permission('patient.clinical.read'))):
    find(db,id,user)
    rows=db.execute(select(ClinicalRevision,User.full_name).join(User,User.id==ClinicalRevision.actor_id).where(ClinicalRevision.resource_type=='note',ClinicalRevision.resource_id==id).order_by(ClinicalRevision.version.desc()))
    return [{'version':r.version,'snapshot':json.loads(r.snapshot),'author':name,'reason':r.reason,'created_at':r.created_at} for r,name in rows]
