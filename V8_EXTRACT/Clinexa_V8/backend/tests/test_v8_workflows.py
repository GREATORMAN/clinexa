from datetime import datetime, timedelta
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.main import app
from app.core.database import Base, get_db
from app.core.security import hash_password
from app.core.rbac_seed import ensure_role
from app.models.organization import Hospital
from app.models.user import User
from app.models.clinical import Patient, Doctor
from app.models.account import UserAccountProfile
from app.models.operations import Notification

@pytest.fixture
def env():
    engine = create_engine('sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine, expire_on_commit=False)
    with sessions() as db:
        a=Hospital(name='A',code='A');b=Hospital(name='B',code='B');db.add_all([a,b]);db.flush()
        p=Patient(hospital_id=a.id,patient_code='A1',full_name='Alice');q=Patient(hospital_id=b.id,patient_code='B1',full_name='Bob')
        d=Doctor(hospital_id=a.id,full_name='Doctor',specialty='General',consultation_minutes=20)
        db.add_all([p,q,d]);db.flush();ids={'p':p.id,'q':q.id,'d':d.id}
        for key,hospital,role in [('admin',a,'Hospital Administrator'),('other',b,'Hospital Administrator'),('desk',a,'Receptionist'),('patient',a,'Patient')]:
            u=User(hospital_id=hospital.id,email=key+'@example.com',full_name=key,password_hash=hash_password('StrongPassword123!'))
            u.roles.append(ensure_role(db,role));db.add(u);db.flush();ids[key]=u.id
            if key=='patient':db.add(UserAccountProfile(user_id=u.id,account_type='patient',approval_status='approved',patient_id=p.id))
        db.commit()
    def test_db():
        with sessions() as db:yield db
    app.dependency_overrides[get_db]=test_db
    with TestClient(app) as c:
        tokens={}
        for key in ['admin','other','desk','patient']:
            r=c.post('/api/v1/auth/login',json={'email':key+'@example.com','password':'StrongPassword123!'})
            assert r.status_code==200,r.text
            tokens[key]=r.json()
        def h(key='admin'):return {'Authorization':'Bearer '+tokens[key]['access_token']}
        yield c,h,ids,sessions,tokens
    app.dependency_overrides.clear();engine.dispose()

def task(env):
    c,h,i,_,_=env
    r=c.post('/api/v1/care-tasks',headers=h(),json={'patient_id':i['p'],'title':'Review results','priority':'high'})
    assert r.status_code==201,r.text
    return r.json()

def test_task_persistence(env):
    t=task(env);c,h,_,_,_=env
    rows=c.get('/api/v1/care-tasks',headers=h()).json()
    assert rows[0]['id']==t['id'] and rows[0]['patient_name']=='Alice'

def test_task_tenant_and_role_authorization(env):
    t=task(env);c,h,i,_,_=env
    assert c.get('/api/v1/care-tasks',headers=h('other')).json()==[]
    assert c.patch('/api/v1/care-tasks/'+t['id'],headers=h('other'),json={'status':'completed','version':1}).status_code==404
    assert c.post('/api/v1/care-tasks',headers=h(),json={'patient_id':i['q'],'title':'Task'}).status_code==404
    assert c.get('/api/v1/care-tasks',headers=h('desk')).status_code==403
    assert c.get('/api/v1/care-tasks',headers=h('patient')).status_code==403

def test_task_version_conflict_and_reopen(env):
    t=task(env);c,h,_,_,_=env;url='/api/v1/care-tasks/'+t['id']
    r=c.patch(url,headers=h(),json={'status':'completed','version':1})
    assert r.status_code==200 and r.json()['completed_at'] and r.json()['version']==2
    assert c.patch(url,headers=h(),json={'status':'open','version':1}).status_code==409
    r=c.patch(url,headers=h(),json={'status':'open','version':2})
    assert r.json()['completed_at'] is None and r.json()['version']==3

def test_task_validation_and_utc(env):
    c,h,i,_,_=env
    assert c.post('/api/v1/care-tasks',headers=h(),json={'patient_id':i['p'],'title':'   '}).status_code==422
    r=c.post('/api/v1/care-tasks',headers=h(),json={'patient_id':i['p'],'title':'Review','due_at':'2027-01-01T17:00:00+05:30'})
    assert r.status_code==201 and r.json()['due_at']=='2027-01-01T11:30:00'

def test_notifications_self_scope(env):
    c,h,i,sessions,_=env
    with sessions() as db:
        a=Notification(user_id=i['admin'],category='test',title='A',body='A');b=Notification(user_id=i['other'],category='test',title='B',body='B')
        db.add_all([a,b]);db.commit();bid=b.id
    assert c.patch('/api/v1/notifications/'+bid+'/read',headers=h()).status_code==404
    assert c.post('/api/v1/notifications/read-all',headers=h()).json()['updated']==1
    assert c.get('/api/v1/notifications',headers=h()).json()[0]['is_read'] is True
    assert c.get('/api/v1/notifications',headers=h('other')).json()[0]['is_read'] is False

def book(env):
    c,h,i,_,_=env;at=(datetime.now()+timedelta(days=2)).replace(hour=10,minute=0,second=0,microsecond=0)
    r=c.post('/api/v1/appointments',headers=h(),json={'patient_id':i['p'],'doctor_id':i['d'],'start_at':at.isoformat()})
    assert r.status_code==201,r.text
    return r.json(),at

def test_appointment_overlap_and_adjacent_slot(env):
    _,at=book(env);c,h,i,_,_=env
    data={'patient_id':i['p'],'doctor_id':i['d'],'start_at':(at+timedelta(minutes=10)).isoformat()}
    assert c.post('/api/v1/appointments',headers=h(),json=data).status_code==409
    data['start_at']=(at+timedelta(minutes=20)).isoformat()
    assert c.post('/api/v1/appointments',headers=h(),json=data).status_code==201

def test_visit_status_lifecycle(env):
    a,_=book(env);c,h,_,_,_=env;url='/api/v1/appointments/'+a['id']
    assert c.patch(url+'/status',headers=h(),json={'status':'completed'}).status_code==409
    for state in ['checked_in','waiting','in_consultation','completed']:
        assert c.patch(url+'/status',headers=h(),json={'status':state}).status_code==200
    assert c.patch(url+'/status',headers=h(),json={'status':'waiting'}).status_code==409
    assert c.patch(url+'/reschedule',headers=h(),json={'start_at':(datetime.now()+timedelta(days=3)).isoformat()}).status_code==409

def test_patient_request_overlap(env):
    _,at=book(env);c,h,i,_,_=env
    assert c.post('/api/v1/portal/appointments',headers=h('patient'),json={'doctor_id':i['d'],'start_at':(at+timedelta(minutes=5)).isoformat()}).status_code==409

def test_profile_and_refresh_rotation(env):
    c,h,_,_,tokens=env
    assert 'patient.clinical.write' in c.get('/api/v1/auth/me',headers=h()).json()['permissions']
    old=tokens['admin']['refresh_token'];r=c.post('/api/v1/auth/refresh',json={'refresh_token':old})
    assert r.status_code==200 and r.json()['refresh_token']!=old
    assert c.post('/api/v1/auth/refresh',json={'refresh_token':old}).status_code==401

def test_cross_tenant_operations_denied(env):
    c,h,i,_,_=env
    assert c.post('/api/v1/billing/invoices',headers=h(),json={'patient_id':i['q'],'description':'Visit','total_amount':100}).status_code==404
    assert c.post('/api/v1/admissions',headers=h(),json={'patient_id':i['q'],'reason':'Test'}).status_code==404

def test_bed_lifecycle(env):
    c,h,i,_,_=env
    ward=c.post('/api/v1/wards',headers=h(),json={'name':'Ward'}).json()
    room=c.post('/api/v1/rooms',headers=h(),json={'name':'Room','ward_id':ward['id']}).json()
    bed=c.post('/api/v1/beds',headers=h(),json={'label':'01','room_id':room['id']}).json()
    r=c.post('/api/v1/admissions',headers=h(),json={'patient_id':i['p'],'bed_id':bed['id']})
    assert r.status_code==201,r.text
    admission=r.json();url='/api/v1/beds/'+bed['id']+'/status'
    assert c.patch(url,headers=h(),json={'status':'available'}).status_code==409
    assert c.post('/api/v1/admissions/'+admission['id']+'/discharge',headers=h()).status_code==200
    assert c.patch(url,headers=h(),json={'status':'available'}).status_code==200
    assert c.get('/api/v1/beds',headers=h()).json()[0]['status']=='available'

def test_payment_and_stock_validation(env):
    c,h,i,_,_=env
    inv=c.post('/api/v1/billing/invoices',headers=h(),json={'patient_id':i['p'],'description':'Visit','total_amount':100}).json()
    url='/api/v1/billing/invoices/'+inv['id']+'/payments'
    assert c.post(url,headers=h(),json={'amount':101}).status_code==409
    assert c.post(url,headers=h(),json={'amount':100}).status_code==201
    assert c.post(url,headers=h(),json={'amount':100}).status_code==409
    item=c.post('/api/v1/pharmacy/items',headers=h(),json={'name':'Demo medicine'}).json()
    assert c.post('/api/v1/pharmacy/batches',headers=h(),json={'pharmacy_item_id':item['id'],'batch_number':'X','quantity':-1}).status_code==422

def test_task_is_visible_in_patient360(env):
    t=task(env);c,h,i,_,_=env
    r=c.get('/api/v1/advanced/patients/'+i['p']+'/360',headers=h())
    assert r.status_code==200 and r.json()['care_tasks'][0]['id']==t['id']

def test_ai_booking_requires_confirmation(env):
    c,h,i,_,_=env
    data={'patient_id':i['p'],'doctor_id':i['d'],'start_at':(datetime.now()+timedelta(days=4)).isoformat(),'confirmed':False}
    r=c.post('/api/v1/ai/propose-booking',headers=h(),json=data)
    assert r.status_code==200 and r.json()['executed'] is False
    assert c.get('/api/v1/appointments',headers=h()).json()==[]
    data['confirmed']=True
    r=c.post('/api/v1/ai/propose-booking',headers=h(),json=data)
    assert r.status_code==200 and r.json()['executed'] is True
    assert len(c.get('/api/v1/appointments',headers=h()).json())==1
    assert c.post('/api/v1/ai/propose-booking',headers=h(),json=data).status_code==409
