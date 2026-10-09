from uuid import uuid4
from datetime import datetime, date
from sqlalchemy import String, Date, DateTime, Text, Float, ForeignKey, Boolean, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


class PatientMedication(Base):
    """Verified longitudinal medication record.

    This is intentionally separate from reminder schedules and electronic
    prescriptions so imported/legacy prescriptions can feed one patient-linked
    medicine centre without pretending that OCR output is itself a prescription.
    """

    __tablename__ = "patient_medications"
    __table_args__ = (
        UniqueConstraint("source_type", "source_id", "medication_name", name="uq_patient_medication_source"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    source_type: Mapped[str] = mapped_column(String(40), default="manual", index=True)
    source_id: Mapped[str | None] = mapped_column(String(36), index=True)
    source_document_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("medical_documents.id", ondelete="SET NULL"), index=True)
    medication_name: Mapped[str] = mapped_column(String(200), index=True)
    strength: Mapped[str | None] = mapped_column(String(100))
    form: Mapped[str | None] = mapped_column(String(100))
    frequency: Mapped[str | None] = mapped_column(String(120))
    route: Mapped[str | None] = mapped_column(String(100))
    duration: Mapped[str | None] = mapped_column(String(120))
    instructions: Mapped[str | None] = mapped_column(Text)
    prescribing_doctor_text: Mapped[str | None] = mapped_column(String(200))
    start_date: Mapped[date | None] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(40), default="active", index=True)
    verified: Mapped[bool] = mapped_column(Boolean, default=True)
    verified_by_user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class PrescriptionOcrDraft(Base):
    __tablename__ = "prescription_ocr_drafts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    ocr_result_id: Mapped[str] = mapped_column(String(36), ForeignKey("ocr_results.id", ondelete="CASCADE"), unique=True, index=True)
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), index=True)
    document_id: Mapped[str] = mapped_column(String(36), ForeignKey("medical_documents.id", ondelete="CASCADE"), index=True)
    patient_name_text: Mapped[str | None] = mapped_column(String(200))
    doctor_name_text: Mapped[str | None] = mapped_column(String(200))
    prescription_date_text: Mapped[str | None] = mapped_column(String(100))
    status: Mapped[str] = mapped_column(String(40), default="needs_review", index=True)
    confirmed_by_user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime)


class PrescriptionOcrItem(Base):
    __tablename__ = "prescription_ocr_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    draft_id: Mapped[str] = mapped_column(String(36), ForeignKey("prescription_ocr_drafts.id", ondelete="CASCADE"), index=True)
    source_line: Mapped[str] = mapped_column(Text)
    medication_name: Mapped[str | None] = mapped_column(String(200))
    strength: Mapped[str | None] = mapped_column(String(100))
    form: Mapped[str | None] = mapped_column(String(100))
    frequency: Mapped[str | None] = mapped_column(String(120))
    route: Mapped[str | None] = mapped_column(String(100))
    duration: Mapped[str | None] = mapped_column(String(120))
    instructions: Mapped[str | None] = mapped_column(Text)
    confidence: Mapped[float | None] = mapped_column(Float)
    uncertain: Mapped[bool] = mapped_column(Boolean, default=True)
    include: Mapped[bool] = mapped_column(Boolean, default=True)
    confirmed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
