from datetime import date, datetime
from pydantic import BaseModel, Field, EmailStr

class PatientCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=200)
    date_of_birth: date | None = None
    sex: str | None = None
    phone: str | None = None
    email: EmailStr | None = None
    address: str | None = None
    blood_group: str | None = None
    emergency_contact: str | None = None
    allergies: str | None = None
    conditions: str | None = None
    current_medications: str | None = None

class DoctorCreate(BaseModel):
    full_name: str
    specialty: str
    department_id: str | None = None
    qualifications: str | None = None
    languages: str | None = None
    biography: str | None = None
    consultation_minutes: int = 20

class AppointmentCreate(BaseModel):
    patient_id: str
    doctor_id: str
    start_at: datetime
    appointment_type: str = "in_person"
    reason: str | None = None

class AppointmentStatusUpdate(BaseModel):
    status: str

class EncounterCreate(BaseModel):
    patient_id: str
    doctor_id: str | None = None
    appointment_id: str | None = None
    chief_complaint: str | None = None
    history: str | None = None
    examination: str | None = None
    assessment: str | None = None
    plan: str | None = None
    follow_up: str | None = None

class PrescriptionCreate(BaseModel):
    patient_id: str
    doctor_id: str
    encounter_id: str | None = None
    medication_name: str
    strength: str | None = None
    form: str | None = None
    frequency: str | None = None
    duration: str | None = None
    instructions: str | None = None

class LabResultCreate(BaseModel):
    patient_id: str
    test_name: str
    result_value: str
    unit: str | None = None
    reference_range: str | None = None
    laboratory: str | None = None
    collected_at: datetime | None = None
    verified: bool = False

class VitalCreate(BaseModel):
    systolic: float | None = None
    diastolic: float | None = None
    heart_rate: float | None = None
    temperature_c: float | None = None
    spo2: float | None = None
    weight_kg: float | None = None
    height_cm: float | None = None
    source: str = "clinician_entered"

class MessageCreate(BaseModel):
    recipient_user_id: str
    body: str = Field(min_length=1, max_length=5000)

class CarePlanCreate(BaseModel):
    patient_id: str
    title: str
    goals: str | None = None
    tasks: str | None = None
    start_date: date | None = None
    end_date: date | None = None

class PharmacyItemCreate(BaseModel):
    name: str
    form: str | None = None
    strength: str | None = None
    reorder_level: int = 10

class InventoryBatchCreate(BaseModel):
    pharmacy_item_id: str
    batch_number: str
    expiry_date: date | None = None
    quantity: int = 0

class InvoiceCreate(BaseModel):
    patient_id: str
    description: str
    total_amount: float = Field(ge=0)

class PaymentCreate(BaseModel):
    amount: float = Field(gt=0)
    provider: str = "manual"
    reference: str | None = None

class AdmissionCreate(BaseModel):
    patient_id: str
    doctor_id: str | None = None
    bed_id: str | None = None
    reason: str | None = None

class OcrVerifyRequest(BaseModel):
    confirmed_text: str | None = None

class AiChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)

class AiBookProposal(BaseModel):
    patient_id: str
    doctor_id: str
    start_at: datetime
    appointment_type: str = "in_person"
    reason: str | None = None
    confirmed: bool = False


class DepartmentCreate(BaseModel):
    name: str = Field(min_length=2, max_length=160)

class DoctorAvailabilityCreate(BaseModel):
    weekday: int = Field(ge=0, le=6)
    start_time: str = Field(pattern=r"^\d{2}:\d{2}$")
    end_time: str = Field(pattern=r"^\d{2}:\d{2}$")
    slot_minutes: int = Field(default=20, ge=5, le=180)

class AppointmentReschedule(BaseModel):
    start_at: datetime

class DispenseCreate(BaseModel):
    prescription_id: str
    pharmacy_item_id: str
    quantity: int = Field(gt=0)


class WardCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)

class RoomCreate(BaseModel):
    ward_id: str
    name: str = Field(min_length=1, max_length=100)

class BedCreate(BaseModel):
    room_id: str
    label: str = Field(min_length=1, max_length=100)

class EmergencyProfileUpsert(BaseModel):
    public_name: str | None = None
    blood_group: str | None = None
    allergies: str | None = None
    critical_conditions: str | None = None
    emergency_notes: str | None = None
    organ_donor: bool = False
    enabled: bool = True

class TrustedContactCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    relation: str | None = None
    phone: str = Field(min_length=5, max_length=50)
    priority: int = Field(default=1, ge=1, le=10)
    can_receive_location: bool = False

class NfcBandCreate(BaseModel):
    patient_id: str
    label: str = Field(default="Emergency band", min_length=1, max_length=120)
    tag_uid: str | None = None

class MedicationScheduleCreate(BaseModel):
    patient_id: str
    prescription_id: str | None = None
    medication_name: str = Field(min_length=1, max_length=200)
    dose_label: str | None = None
    times_csv: str = "09:00"
    start_date: date | None = None
    end_date: date | None = None
    instructions: str | None = None

class MedicationDoseLogCreate(BaseModel):
    scheduled_for: datetime
    status: str = Field(default="taken", pattern=r"^(taken|missed|skipped)$")
    note: str | None = None

class SymptomCreate(BaseModel):
    symptom: str = Field(min_length=1, max_length=200)
    severity: int = Field(default=1, ge=1, le=10)
    note: str | None = None

class InsurancePolicyCreate(BaseModel):
    provider: str = Field(min_length=1, max_length=200)
    policy_number: str = Field(min_length=1, max_length=120)
    plan_name: str | None = None
    valid_from: date | None = None
    valid_to: date | None = None
    status: str = "active"

class LabOrderCreate(BaseModel):
    patient_id: str
    doctor_id: str | None = None
    test_name: str = Field(min_length=1, max_length=200)
    priority: str = "routine"
    specimen: str | None = None

class LabOrderStatusUpdate(BaseModel):
    status: str = Field(pattern=r"^(ordered|collected|processing|completed|cancelled)$")

class TeleconsultationCreate(BaseModel):
    appointment_id: str
    consent_recorded: bool = False

class TeleconsultationStatusUpdate(BaseModel):
    status: str = Field(pattern=r"^(waiting|live|ended|cancelled)$")

class StaffShiftCreate(BaseModel):
    user_id: str
    department_id: str | None = None
    starts_at: datetime
    ends_at: datetime
    shift_type: str = "day"

class ConsentCreate(BaseModel):
    consent_type: str = Field(min_length=1, max_length=120)
    granted: bool
    note: str | None = None

class OcrMedicationItemConfirm(BaseModel):
    item_id: str | None = None
    include: bool = True
    medication_name: str = Field(min_length=1, max_length=200)
    strength: str | None = None
    form: str | None = None
    frequency: str | None = None
    route: str | None = None
    duration: str | None = None
    instructions: str | None = None
    reminder_times: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    status: str = "active"

class OcrPrescriptionConfirmRequest(BaseModel):
    doctor_name: str | None = None
    prescription_date: str | None = None
    items: list[OcrMedicationItemConfirm]

class PatientMedicationCreate(BaseModel):
    patient_id: str
    medication_name: str = Field(min_length=1, max_length=200)
    strength: str | None = None
    form: str | None = None
    frequency: str | None = None
    route: str | None = None
    duration: str | None = None
    instructions: str | None = None
    prescribing_doctor_text: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    status: str = "active"
    reminder_times: str | None = None

class PortalAppointmentCreate(BaseModel):
    doctor_id: str
    start_at: datetime
    appointment_type: str = "in_person"
    reason: str | None = None

class PortalAppointmentReschedule(BaseModel):
    start_at: datetime

class PharmacyRequestItemCreate(BaseModel):
    catalog_item_id: str
    patient_medication_id: str
    quantity: int = Field(default=1, ge=1, le=30)

class PharmacyRequestCreate(BaseModel):
    items: list[PharmacyRequestItemCreate] = Field(min_length=1, max_length=20)
    note: str | None = Field(default=None, max_length=1000)

class PharmacyRequestStatusUpdate(BaseModel):
    status: str = Field(pattern=r"^(submitted|reviewing|ready|fulfilled|declined|cancelled)$")
