from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from app.api.routes.appointments import check_slot
from app.core.audit import log_action
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user,require_permission,tenant_id
from app.models.user import User
from app.models.clinical import Appointment,Doctor,Patient
from app.services.ollama_service import status as ollama_status,chat as ollama_chat
from app.services.clinical_ai_service import chat_service
from app.schemas.domain import AiChatRequest,AiBookProposal
router=APIRouter(prefix="/ai",tags=["Local AI"])

@router.get("/status")
async def status(user:User=Depends(get_current_user)):
    st = await ollama_status()
    st["engine"] = "Clinexa Clinical Decision Support & Guardrail Sentinel"
    st["engine_online"] = True
    return st

@router.post("/chat")
async def chat(payload:AiChatRequest,db:Session=Depends(get_db),user:User=Depends(get_current_user)):
    h=tenant_id(user)
    return await chat_service(
        message=payload.message,
        patient_id=payload.patient_id,
        db=db,
        user_name=user.full_name,
        hospital_id=h
    )

@router.post("/propose-booking")
def propose_booking(payload:AiBookProposal,db:Session=Depends(get_db),user:User=Depends(require_permission("appointments.create"))):
    h=tenant_id(user);patient=db.scalar(select(Patient).where(Patient.id==payload.patient_id,Patient.hospital_id==h));doctor=db.scalar(select(Doctor).where(Doctor.id==payload.doctor_id,Doctor.hospital_id==h))
    if not patient or not doctor: raise HTTPException(400,"Patient or doctor is invalid")
    if not doctor.is_active: raise HTTPException(409,"Doctor is unavailable")
    check_slot(db,doctor,payload.start_at)
    proposal={"patient":patient.full_name,"doctor":doctor.full_name,"specialty":doctor.specialty,"start_at":payload.start_at,"appointment_type":payload.appointment_type,"reason":payload.reason,"requires_confirmation":True}
    if not payload.confirmed: return {"executed":False,"proposal":proposal}
    row=Appointment(hospital_id=h,patient_id=patient.id,doctor_id=doctor.id,start_at=payload.start_at,appointment_type=payload.appointment_type,reason=payload.reason,status="confirmed",created_by_user_id=user.id);db.add(row)
    try:
        db.flush()
    except IntegrityError:
        db.rollback(); raise HTTPException(409,"That slot was just booked")
    log_action(db,user.id,"ai.appointment.confirmed","appointment",row.id)
    db.commit();db.refresh(row);return {"executed":True,"proposal":proposal,"appointment":row}

@router.get("/patient/{patient_id}/summary")
async def patient_summary(patient_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("patient.clinical.read"))):
    from app.models.clinical import Encounter, Vital
    from app.models.records import Prescription, LabResult
    h = tenant_id(user)
    patient = db.scalar(select(Patient).where(Patient.id == patient_id, Patient.hospital_id == h))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    encounters = db.scalars(select(Encounter).where(Encounter.patient_id == patient_id).order_by(Encounter.created_at.desc()).limit(8)).all()
    vitals = db.scalars(select(Vital).where(Vital.patient_id == patient_id).order_by(Vital.observed_at.desc()).limit(8)).all()
    rx = db.scalars(select(Prescription).where(Prescription.patient_id == patient_id).order_by(Prescription.created_at.desc()).limit(12)).all()
    labs = db.scalars(select(LabResult).where(LabResult.patient_id == patient_id).order_by(LabResult.created_at.desc()).limit(12)).all()
    context = (
        f"Patient name: {patient.full_name}\n"
        f"Blood group: {patient.blood_group or 'not recorded'}\n"
        f"Allergies: {patient.allergies or 'not recorded'}\n"
        f"Conditions: {patient.conditions or 'not recorded'}\n"
        f"Current medications field: {patient.current_medications or 'not recorded'}\n"
        f"Recent encounters: {[{'complaint':e.chief_complaint,'assessment':e.assessment,'plan':e.plan,'at':str(e.created_at)} for e in encounters]}\n"
        f"Recent vitals: {[{'bp':f'{v.systolic}/{v.diastolic}','hr':v.heart_rate,'spo2':v.spo2,'temp':v.temperature_c,'at':str(v.observed_at)} for v in vitals]}\n"
        f"Recent prescriptions: {[{'medication':r.medication_name,'strength':r.strength,'frequency':r.frequency,'status':r.status} for r in rx]}\n"
        f"Recent labs: {[{'test':l.test_name,'value':l.result_value,'unit':l.unit,'range':l.reference_range,'verified':l.verified} for l in labs]}"
    )
    instruction = (
        "Summarize only the supplied authorized record. Separate: key record facts, recent changes, and follow-up items already documented. "
        "Do not diagnose, prescribe, recommend dose changes, or invent missing data. Clearly say when information is not recorded."
    )
    return await ollama_chat(instruction, context)
