from uuid import uuid4
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


class UserAccountProfile(Base):
    __tablename__ = "user_account_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True)
    account_type: Mapped[str] = mapped_column(String(60), default="patient", index=True)
    approval_status: Mapped[str] = mapped_column(String(40), default="pending", index=True)
    specialty: Mapped[str | None] = mapped_column(String(160))
    patient_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("patients.id", ondelete="SET NULL"), index=True)
    doctor_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("doctors.id", ondelete="SET NULL"), index=True)
    requested_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime)
    approved_by_user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id", ondelete="SET NULL"))
