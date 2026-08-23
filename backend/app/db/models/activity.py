import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, DateTime, Float, ForeignKey, String, UniqueConstraint, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Activity(Base):
    __tablename__ = "activities"
    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_activities_user_date"),
        CheckConstraint(
            "recording_status IN ('unrecorded', 'recorded', 'legacy_unknown')",
            name="ck_activities_recording_status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date: Mapped[date] = mapped_column(Date, nullable=False)
    steps: Mapped[float] = mapped_column(Float, nullable=False)
    steps_manual: Mapped[float | None] = mapped_column(Float, nullable=True)
    steps_health_connect: Mapped[float | None] = mapped_column(Float, nullable=True)
    steps_downward_offset: Mapped[float] = mapped_column(Float, nullable=False, default=0.0, server_default="0.0")
    steps_provenance: Mapped[str] = mapped_column(String(32), nullable=False, default="system", server_default="'system'")
    steps_pending_reduction_value: Mapped[float | None] = mapped_column(Float, nullable=True)
    steps_pending_reduction_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    
    active_minutes: Mapped[float] = mapped_column(Float, nullable=False)
    active_minutes_manual: Mapped[float | None] = mapped_column(Float, nullable=True)
    active_minutes_health_connect: Mapped[float | None] = mapped_column(Float, nullable=True)
    # Active minutes untouched per HC spec rules
    @property
    def active_minutes_provenance(self) -> str:
        return "manual" if self.active_minutes_manual is not None else "system"
    
    distance: Mapped[float] = mapped_column(Float, nullable=False)
    distance_manual: Mapped[float | None] = mapped_column(Float, nullable=True)
    distance_health_connect: Mapped[float | None] = mapped_column(Float, nullable=True)
    distance_downward_offset: Mapped[float] = mapped_column(Float, nullable=False, default=0.0, server_default="0.0")
    distance_provenance: Mapped[str] = mapped_column(String(32), nullable=False, default="system", server_default="'system'")
    distance_pending_reduction_value: Mapped[float | None] = mapped_column(Float, nullable=True)
    distance_pending_reduction_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    
    calories: Mapped[float] = mapped_column(Float, nullable=False)
    calories_manual: Mapped[float | None] = mapped_column(Float, nullable=True)
    calories_health_connect: Mapped[float | None] = mapped_column(Float, nullable=True)
    calories_downward_offset: Mapped[float] = mapped_column(Float, nullable=False, default=0.0, server_default="0.0")
    calories_provenance: Mapped[str] = mapped_column(String(32), nullable=False, default="system", server_default="'system'")
    calories_pending_reduction_value: Mapped[float | None] = mapped_column(Float, nullable=True)
    calories_pending_reduction_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    daily_score: Mapped[float] = mapped_column(Float, nullable=False)
    score_version: Mapped[str] = mapped_column(String(16), nullable=False)
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    recording_status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="legacy_unknown"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
