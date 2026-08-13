import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint, Uuid, func, true, false
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Profile(Base):
    __tablename__ = "profiles"
    __table_args__ = (UniqueConstraint("user_id", name="uq_profiles_user_id"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    display_name: Mapped[str] = mapped_column(String(40), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(80), nullable=False, default="")
    dark_theme: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
    )
    reduce_motion: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default=false()
    )
    haptic_feedback: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
    )
    use_metric_units: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
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
