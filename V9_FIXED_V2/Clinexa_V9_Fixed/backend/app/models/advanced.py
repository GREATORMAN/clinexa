from uuid import uuid4
from datetime import datetime, date
from sqlalchemy import String, Date, DateTime, Text, Float, Integer, ForeignKey, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


class EmergencyProfile(Base):
    __tablename__ = "emergency_profiles"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), unique=True, index=True)
    public_name: Mapped[str | None] = mapped_column(String(200))
    blood_group: Mapped[str | None] = mapped_column(String(20))
    allergies: Mapped[str | None] = mapped_column(Text)
    critical_conditions: Mapped[str | None] = mapped_column(Text)
    emergency_notes: Mapped[str | None] = mapped_column(Text)
    organ_donor: Mapped[bool] = mapped_column(Boolean, default=False)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class TrustedContact(Base):
    __tablename__ = "trusted_contacts"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    relation: Mapped[str | None] = mapped_column(String(80))
    phone: Mapped[str] = mapped_column(String(50))
    priority: Mapped[int] = mapped_column(Integer, default=1)
    can_receive_location: Mapped[bool] = mapped_column(Boolean, default=False)


class NfcBand(Base):
    __tablename__ = "nfc_bands"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(String(96), unique=True, index=True)
    label: Mapped[str] = mapped_column(String(120), default="Emergency band")
    tag_uid: Mapped[str | None] = mapped_column(String(200))
    active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    issued_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime)


class EmergencyAccessLog(Base):
    __tablename__ = "emergency_access_logs"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    band_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("nfc_bands.id", ondelete="SET NULL"), index=True)
    access_type: Mapped[str] = mapped_column(String(50), default="token_scan")
    source: Mapped[str | None] = mapped_column(String(120))
    accessed_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class MedicationSchedule(Base):
    __tablename__ = "medication_schedules"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    prescription_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("prescriptions.id", ondelete="SET NULL"), index=True)
    medication_name: Mapped[str] = mapped_column(String(200))
    dose_label: Mapped[str | None] = mapped_column(String(120))
    times_csv: Mapped[str] = mapped_column(String(200), default="09:00")
    start_date: Mapped[date | None] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date)
    instructions: Mapped[str | None] = mapped_column(Text)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class MedicationDoseLog(Base):
    __tablename__ = "medication_dose_logs"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    schedule_id: Mapped[str] = mapped_column(String(36), ForeignKey("medication_schedules.id", ondelete="CASCADE"), index=True)
    scheduled_for: Mapped[datetime] = mapped_column(DateTime, index=True)
    status: Mapped[str] = mapped_column(String(40), default="taken")
    logged_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    note: Mapped[str | None] = mapped_column(String(300))


class SymptomEntry(Base):
    __tablename__ = "symptom_entries"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    symptom: Mapped[str] = mapped_column(String(200), index=True)
    severity: Mapped[int] = mapped_column(Integer, default=1)
    note: Mapped[str | None] = mapped_column(Text)
    recorded_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class InsurancePolicy(Base):
    __tablename__ = "insurance_policies"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(200))
    policy_number: Mapped[str] = mapped_column(String(120))
    plan_name: Mapped[str | None] = mapped_column(String(160))
    valid_from: Mapped[date | None] = mapped_column(Date)
    valid_to: Mapped[date | None] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(40), default="active")


class LabOrder(Base):
    __tablename__ = "lab_orders"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    hospital_id: Mapped[str] = mapped_column(String(36), ForeignKey("hospitals.id", ondelete="CASCADE"), index=True)
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    doctor_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("doctors.id", ondelete="SET NULL"), index=True)
    test_name: Mapped[str] = mapped_column(String(200))
    priority: Mapped[str] = mapped_column(String(40), default="routine")
    status: Mapped[str] = mapped_column(String(40), default="ordered", index=True)
    specimen: Mapped[str | None] = mapped_column(String(120))
    ordered_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    collected_at: Mapped[datetime | None] = mapped_column(DateTime)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime)


class TeleconsultationSession(Base):
    __tablename__ = "teleconsultation_sessions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    appointment_id: Mapped[str] = mapped_column(String(36), ForeignKey("appointments.id", ondelete="CASCADE"), unique=True, index=True)
    room_code: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    status: Mapped[str] = mapped_column(String(40), default="waiting")
    consent_recorded: Mapped[bool] = mapped_column(Boolean, default=False)
    started_at: Mapped[datetime | None] = mapped_column(DateTime)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime)


class StaffShift(Base):
    __tablename__ = "staff_shifts"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    hospital_id: Mapped[str] = mapped_column(String(36), ForeignKey("hospitals.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    department_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("departments.id", ondelete="SET NULL"), index=True)
    starts_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    ends_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    shift_type: Mapped[str] = mapped_column(String(50), default="day")
    status: Mapped[str] = mapped_column(String(40), default="scheduled")


class ConsentRecord(Base):
    __tablename__ = "consent_records"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    consent_type: Mapped[str] = mapped_column(String(120), index=True)
    granted: Mapped[bool] = mapped_column(Boolean, default=False)
    note: Mapped[str | None] = mapped_column(String(500))
    recorded_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
