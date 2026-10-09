import time
import pytest
from sqlalchemy import select
from tests.test_v8_workflows import env
from app.models.workspace import ClinicalRevision,MfaFactor
from app.models.records import LabResult
from app.services.mfa import code
from app.core.rate_limit import limiter,RateLimit
@pytest.fixture(autouse=True)
def reset_limits():
    limiter.events.clear()
    yield
    limiter.events.clear()
def note(env):
    c,h,i,_,_=env;r=c.post('/api/v1/clinical-notes',headers=h(),json={'patient_id':i['p'],'title':'Review','content':'Initial history'});assert r.status_code==201,r.text;return r.json()
def test_note_draft_final_amend_history(env):
    n=note(env);c,h,_,_,_=env;url='/api/v1/clinical-notes/'+n['id']
    assert c.patch(url,headers=h(),json={'version':1,'title':'Review','content':'Updated'}).json()['version']==2
    r=c.patch(url,headers=h(),json={'version':2,'title':'Review','content':'Final','action':'finalize'});assert r.status_code==200 and r.json()['status']=='final'
    assert c.patch(url,headers=h(),json={'version':3,'title':'Review','content':'Overwrite'}).status_code==409
    assert c.patch(url,headers=h(),json={'version':3,'title':'Review','content':'Correction','action':'amend'}).status_code==422
    assert c.patch(url,headers=h(),json={'version':3,'title':'Review','content':'Correction','action':'amend','reason':'Transcription correction'}).status_code==200
    history=c.get(url+'/history',headers=h()).json();assert len(history)==4 and history[-1]['snapshot']['content']=='Initial history'
def test_note_stale_tenant_and_role(env):
    n=note(env);c,h,i,_,_=env;url='/api/v1/clinical-notes/'+n['id'];data={'version':1,'title':'Review','content':'Saved'}
    assert c.patch(url,headers=h(),json=data).status_code==200
    assert c.patch(url,headers=h(),json=data).status_code==409
    assert c.patch(url,headers=h('other'),json=data).status_code==404
    assert c.get(url+'/history',headers=h('other')).status_code==404
    assert c.get('/api/v1/clinical-notes',headers=h('patient')).status_code==403
    assert c.post('/api/v1/clinical-notes',headers=h(),json={'patient_id':i['q'],'title':'Bad'}).status_code==404
    assert c.post('/api/v1/clinical-notes',headers=h(),json={'patient_id':i['p'],'title':'   '}).status_code==422
def test_revision_append_only_orm(env):
    n=note(env);_,_,_,sessions,_=env
    with sessions() as db:
        r=db.scalar(select(ClinicalRevision).where(ClinicalRevision.resource_id==n['id']));r.reason='tampered'
        with pytest.raises(ValueError):db.commit()
def specimen(env):
    c,h,i,_,_=env;r=c.post('/api/v1/lab-workspace/specimens',headers=h(),json={'patient_id':i['p'],'test_name':'CBC','specimen':'Blood'});assert r.status_code==201,r.text;return r.json()
def move(c,h,r,state):
    result=c.patch('/api/v1/lab-workspace/specimens/'+r['id']+'/stage',headers=h(),json={'version':r['version'],'state':state});assert result.status_code==200,result.text;return result.json()
def test_specimen_release_no_duplicate(env):
    r=specimen(env);c,h,i,sessions,_=env
    for state in ['collected','received','processing']:r=move(c,h,r,state)
    url='/api/v1/lab-workspace/specimens/'+r['id']
    assert c.patch(url+'/stage',headers=h(),json={'version':r['version'],'state':'released'}).status_code==409
    assert c.patch(url+'/stage',headers=h(),json={'version':r['version'],'state':'technician_verified'}).status_code==409
    data={'version':r['version'],'confirmed':True,'fields':[{'test_name':'Hemoglobin','result_value':'13.4','unit':'g/dL','reference_range':'12-16'}]}
    result=c.post(url+'/verify',headers=h(),json=data);assert result.status_code==200,result.text;r=result.json()
    assert c.post(url+'/verify',headers=h(),json=data).status_code==409
    with sessions() as db:assert db.scalars(select(LabResult)).all()==[]
    for state in ['technician_verified','doctor_reviewed','released']:r=move(c,h,r,state)
    with sessions() as db:
        rows=db.scalars(select(LabResult)).all();assert len(rows)==1 and rows[0].verified
    assert c.patch(url+'/stage',headers=h(),json={'version':r['version'],'state':'released'}).status_code==409
def test_specimen_tenant_and_rejection(env):
    r=specimen(env);c,h,i,_,_=env;url='/api/v1/lab-workspace/specimens/'+r['id']
    assert c.get('/api/v1/lab-workspace/specimens',headers=h('other')).json()==[]
    assert c.patch(url+'/stage',headers=h('other'),json={'version':1,'state':'collected'}).status_code==404
    assert c.patch(url+'/stage',headers=h('patient'),json={'version':1,'state':'collected'}).status_code==403
    r=move(c,h,r,'collected');assert c.patch(url+'/stage',headers=h(),json={'version':r['version'],'state':'rejected'}).status_code==422
def test_parser_requires_verification(env):
    c,h,_,_,_=env;r=c.post('/api/v1/lab-workspace/parse',headers=h(),json={'text':'Hemoglobin  13.4 g/dL 12-16\nUnrecognized line'});assert r.status_code==200,r.text
    assert r.json()['fields'][0]['requires_verification'] and r.json()['fields'][0]['reference_range']=='12-16'
    assert len(r.json()['unparsed_lines'])==1
def test_session_revocation(env):
    c,h,_,_,tokens=env;rows=c.get('/api/v1/account/sessions',headers=h()).json();assert len(rows)==1 and rows[0]['current']
    assert c.delete('/api/v1/account/sessions/'+rows[0]['id'],headers=h('other')).status_code==404
    assert c.delete('/api/v1/account/sessions/'+rows[0]['id'],headers=h()).status_code==200
    assert c.get('/api/v1/auth/me',headers=h()).status_code==401
    assert c.post('/api/v1/auth/refresh',json={'refresh_token':tokens['admin']['refresh_token']}).status_code==401
def test_mfa_enrollment_login_replay(env):
    c,h,i,sessions,_=env;r=c.post('/api/v1/account/mfa/setup',headers=h(),json={'password':'StrongPassword123!'});assert r.status_code==200,r.text
    secret=r.json()['secret'];counter=int(time.time()//30);otp=code(secret,counter)
    assert c.post('/api/v1/account/mfa/confirm',headers=h(),json={'code':otp}).status_code==200
    assert c.get('/api/v1/auth/me',headers=h()).status_code==401
    data={'email':'admin@example.com','password':'StrongPassword123!'}
    assert c.post('/api/v1/auth/login',json=data).status_code==401
    assert c.post('/api/v1/auth/login',json={**data,'mfa_code':otp}).status_code==401
    with sessions() as db:assert secret not in db.get(MfaFactor,i['admin']).encrypted_secret
    value=code(secret,counter+1)
    assert c.post('/api/v1/auth/login',json={**data,'mfa_code':value}).status_code==200
    assert c.post('/api/v1/auth/login',json={**data,'mfa_code':value}).status_code==401
def test_message_threads_participants_and_receipts(env):
    c,h,i,_,_=env;contacts=c.get('/api/v1/message-contacts',headers=h()).json();assert i['other'] not in {u['id'] for u in contacts}
    assert c.post('/api/v1/messages',headers=h(),json={'recipient_user_id':i['desk'],'body':'Care handoff'}).status_code==201
    assert c.get('/api/v1/messages/thread/'+i['desk'],headers=h('other')).status_code==404
    assert c.post('/api/v1/messages/thread/'+i['admin']+'/read',headers=h('desk')).json()['updated']==1
    assert c.get('/api/v1/messages/thread/'+i['desk'],headers=h()).json()[0]['is_read']
    assert c.get('/api/v1/messages',headers=h('patient')).status_code==403
def test_rate_limit():
    r=RateLimit()
    for _ in range(3):assert r.allow('a',3,60)
    assert not r.allow('a',3,60) and r.allow('b',3,60)
def test_password_reset_single_use_no_email_disclosure(env):
    import json
    from app.models.workspace import Job,RecoveryTicket
    from app.services.mfa import cipher
    c,h,i,sessions,tokens=env
    existing=c.post('/api/v1/auth/forgot-password',json={'email':'admin@example.com'})
    missing=c.post('/api/v1/auth/forgot-password',json={'email':'missing@example.com'})
    assert existing.status_code==202 and existing.json()==missing.json()
    with sessions() as db:
        job=db.scalar(select(Job));payload=json.loads(cipher().decrypt(job.payload.encode()));token=payload['token']
        ticket=db.scalar(select(RecoveryTicket));assert token!=ticket.token_hash and token not in job.payload
    data={'token':token,'password':'NewStrongPassword123!'}
    assert c.post('/api/v1/auth/reset-password',json=data).status_code==200
    assert c.post('/api/v1/auth/reset-password',json=data).status_code==422
    assert c.get('/api/v1/auth/me',headers=h()).status_code==401
    assert c.post('/api/v1/auth/login',json={'email':'admin@example.com','password':'NewStrongPassword123!'}).status_code==200
def test_caregiver_scope_approval_and_revocation(env):
    from app.models.user import User
    from app.models.account import UserAccountProfile
    from app.core.security import hash_password
    from app.core.rbac_seed import ensure_role
    c,h,i,sessions,_=env
    with sessions() as db:
        patient_user=db.get(User,i['patient']);u=User(hospital_id=patient_user.hospital_id,email='care@example.com',full_name='Caregiver',password_hash=hash_password('StrongPassword123!'))
        db.add(u);db.flush();uid=u.id;db.add(UserAccountProfile(user_id=uid,account_type='caregiver',approval_status='pending'));db.commit()
    data={'email':'care@example.com','scopes':['appointments'],'document_ids':[]}
    r=c.post('/api/v1/privacy/grants',headers=h('patient'),json=data);assert r.status_code==200,r.text;gid=r.json()['id']
    r=c.post('/api/v1/auth/login',json={'email':'care@example.com','password':'StrongPassword123!'});care={'Authorization':'Bearer '+r.json()['access_token']}
    assert c.get('/api/v1/caregiver/grants',headers=care).status_code==403
    assert c.post('/api/v1/admin/users/'+uid+'/approve',headers=h()).status_code==200
    assert len(c.get('/api/v1/caregiver/grants',headers=care).json())==1
    assert c.get('/api/v1/caregiver/grants/'+gid+'/appointments',headers=care).status_code==200
    assert c.get('/api/v1/caregiver/grants/'+gid+'/reminders',headers=care).status_code==403
    assert c.delete('/api/v1/privacy/grants/'+gid,headers=h()).status_code==403
    assert c.delete('/api/v1/privacy/grants/'+gid,headers=h('patient')).status_code==200
    assert c.get('/api/v1/caregiver/grants/'+gid+'/appointments',headers=care).status_code==404
    assert c.get('/api/v1/caregiver/grants',headers=care).json()==[]
def test_audit_tenant_filter(env):
    c,h,i,_,_=env;note(env)
    other=c.get('/api/v1/admin/audit',headers=h('other')).json()
    assert all(r['actor_user_id']==i['other'] for r in other)
    own=c.get('/api/v1/admin/audit',headers=h(),params={'action':'note.create','resource':'clinical_note'}).json()
    assert len(own)==1 and own[0]['actor_user_id']==i['admin']
def test_notification_dose_retry_idempotent(env):
    from app.models.advanced import MedicationSchedule,MedicationDoseLog
    c,h,i,sessions,_=env
    with sessions() as db:
        schedule=MedicationSchedule(patient_id=i['p'],medication_name='Test medication');db.add(schedule);db.flush();id=schedule.id;db.commit()
    data={'scheduled_for':'2026-10-02T09:00:00+05:30','status':'taken','idempotency_key':'one-dose'}
    url='/api/v1/portal/medications/'+id+'/dose-logs'
    a=c.post(url,headers=h('patient'),json=data);b=c.post(url,headers=h('patient'),json=data)
    assert a.status_code==201 and b.status_code==201 and a.json()['id']==b.json()['id']
    assert a.json()['scheduled_for']=='2026-10-02T03:30:00'
    assert c.post(url,headers=h('patient'),json={**data,'status':'skipped'}).status_code==409
    with sessions() as db:assert len(db.scalars(select(MedicationDoseLog)).all())==1
def test_privacy_export_and_scan_history_self_scope(env):
    c,h,i,_,_=env
    r=c.get('/api/v1/privacy/export',headers=h('patient'));assert r.status_code==200 and r.json()['patient']['id']==i['p']
    assert c.get('/api/v1/privacy/export',headers=h()).status_code==403
    assert c.get('/api/v1/privacy/emergency-access',headers=h('patient')).json()==[]
def test_revision_sql_tamper_rejected(env):
    from sqlalchemy import update
    from sqlalchemy.exc import IntegrityError
    n=note(env);_,_,_,sessions,_=env
    with sessions() as db:
        with pytest.raises(IntegrityError):db.execute(update(ClinicalRevision).where(ClinicalRevision.resource_id==n['id']).values(reason='tampered'))
