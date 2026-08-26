import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Integer, String, UniqueConstraint, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class StepSample(Base):
    __tablename__ = "activity_step_samples"
    __table_args__ = (
        UniqueConstraint("user_id", "sample_id", name="uq_step_samples_user_sample"),
        CheckConstraint("end_time >= start_time", name="ck_step_samples_time_range"),
        CheckConstraint("steps >= 0", name="ck_step_samples_steps_positive"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    steps: Mapped[int] = mapped_column(Integer, nullable=False)
    source_origin: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        default="health_connect",
        server_default="'health_connect'",
    )
    sample_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
