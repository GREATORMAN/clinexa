from datetime import datetime
from uuid import uuid4
from sqlalchemy import String, Text, DateTime, ForeignKey, Boolean, UniqueConstraint, event
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

def utcnow(): return datetime.utcnow()
def uuid(): return str(uuid4())

class ClinicalDraft(Base):
    __tablename__='clinical_drafts'
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uuid)
    hospital_id: Mapped[str]=mapped_column(ForeignKey('hospitals.id'),index=True)
    patient_id: Mapped[str]=mapped_column(ForeignKey('patients.id'),index=True)
    author_id: Mapped[str]=mapped_column(ForeignKey('users.id'))
    title: Mapped[str]=mapped_column(String(200))
    content: Mapped[str]=mapped_column(Text,default='')
    status: Mapped[str]=mapped_column(String(20),default='draft')
    version: Mapped[int]=mapped_column(default=1)
    updated_at: Mapped[datetime]=mapped_column(DateTime,default=utcnow)

class ClinicalRevision(Base):
    __tablename__='clinical_revisions'
    __table_args__=(UniqueConstraint('resource_type','resource_id','version'),)
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uuid)
    hospital_id: Mapped[str]=mapped_column(ForeignKey('hospitals.id'),index=True)
    resource_type: Mapped[str]=mapped_column(String(50))
    resource_id: Mapped[str]=mapped_column(String(36),index=True)
    version: Mapped[int]=mapped_column()
    snapshot: Mapped[str]=mapped_column(Text)
    actor_id: Mapped[str]=mapped_column(ForeignKey('users.id'))
    reason: Mapped[str]=mapped_column(String(500))
    created_at: Mapped[datetime]=mapped_column(DateTime,default=utcnow)

@event.listens_for(ClinicalRevision,'before_update')
@event.listens_for(ClinicalRevision,'before_delete')
def immutable_revision(*args): raise ValueError('Clinical revisions are append-only')

class WorkspaceRecord(Base):
    __tablename__='workspace_records'
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uuid)
    hospital_id: Mapped[str]=mapped_column(ForeignKey('hospitals.id'),index=True)
    patient_id: Mapped[str | None]=mapped_column(ForeignKey('patients.id'),index=True)
    kind: Mapped[str]=mapped_column(String(50),index=True)
    state: Mapped[str]=mapped_column(String(30),default='open')
    payload: Mapped[str]=mapped_column(Text)
    author_id: Mapped[str]=mapped_column(ForeignKey('users.id'))
    version: Mapped[int]=mapped_column(default=1)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=utcnow)
    updated_at: Mapped[datetime]=mapped_column(DateTime,default=utcnow)

class DeviceSession(Base):
    __tablename__='device_sessions'
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uuid)
    user_id: Mapped[str]=mapped_column(ForeignKey('users.id'),index=True)
    token_id: Mapped[str]=mapped_column(String(36),unique=True)
    label: Mapped[str]=mapped_column(String(200))
    revoked: Mapped[bool]=mapped_column(Boolean,default=False)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=utcnow)

class MfaFactor(Base):
    __tablename__='mfa_factors'
    user_id: Mapped[str]=mapped_column(ForeignKey('users.id'),primary_key=True)
    encrypted_secret: Mapped[str]=mapped_column(Text)
    enabled: Mapped[bool]=mapped_column(Boolean,default=False)
    last_counter: Mapped[int]=mapped_column(default=-1)

class RecoveryTicket(Base):
    __tablename__='recovery_tickets'
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uuid)
    user_id: Mapped[str]=mapped_column(ForeignKey('users.id'))
    token_hash: Mapped[str]=mapped_column(String(64),unique=True)
    expires_at: Mapped[datetime]=mapped_column(DateTime)
    used: Mapped[bool]=mapped_column(Boolean,default=False)

class NotificationPreference(Base):
    __tablename__='notification_preferences'
    user_id: Mapped[str]=mapped_column(ForeignKey('users.id'),primary_key=True)
    enabled_categories: Mapped[str]=mapped_column(Text,default='["appointments","labs","pharmacy","tasks","messages","security"]')
    muted_until: Mapped[datetime | None]=mapped_column(DateTime)

class CaregiverGrant(Base):
    __tablename__='caregiver_grants'
    __table_args__=(UniqueConstraint('patient_id','caregiver_id'),)
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uuid)
    patient_id: Mapped[str]=mapped_column(ForeignKey('patients.id'),index=True)
    caregiver_id: Mapped[str]=mapped_column(ForeignKey('users.id'))
    granted_by: Mapped[str]=mapped_column(ForeignKey('users.id'))
    scopes: Mapped[str]=mapped_column(Text)
    revoked: Mapped[bool]=mapped_column(Boolean,default=False)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=utcnow)

class Job(Base):
    __tablename__='background_jobs'
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uuid)
    kind: Mapped[str]=mapped_column(String(30))
    payload: Mapped[str]=mapped_column(Text)
    state: Mapped[str]=mapped_column(String(20),default='queued',index=True)
    attempts: Mapped[int]=mapped_column(default=0)
    error_code: Mapped[str | None]=mapped_column(String(100))
    created_at: Mapped[datetime]=mapped_column(DateTime,default=utcnow)

class DoseReceipt(Base):
    __tablename__='dose_receipts'
    id: Mapped[str]=mapped_column(String(64),primary_key=True)
    dose_id: Mapped[str]=mapped_column(ForeignKey('medication_dose_logs.id'),unique=True)

# Reject ordinary SQL UPDATE/DELETE as well as ORM mutation of revision rows.
from sqlalchemy import DDL
event.listen(ClinicalRevision.__table__,'after_create',DDL("CREATE TRIGGER clinical_revision_no_update BEFORE UPDATE ON clinical_revisions BEGIN SELECT RAISE(ABORT, 'Clinical revisions are append-only'); END").execute_if(dialect='sqlite'))
event.listen(ClinicalRevision.__table__,'after_create',DDL("CREATE TRIGGER clinical_revision_no_delete BEFORE DELETE ON clinical_revisions BEGIN SELECT RAISE(ABORT, 'Clinical revisions are append-only'); END").execute_if(dialect='sqlite'))
