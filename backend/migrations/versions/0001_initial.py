"""Create activities, goals, and profiles.

Revision ID: 0001_initial
Revises:
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0001_initial"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "activities",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("steps", sa.Float(), nullable=False),
        sa.Column("active_minutes", sa.Float(), nullable=False),
        sa.Column("distance", sa.Float(), nullable=False),
        sa.Column("calories", sa.Float(), nullable=False),
        sa.Column("daily_score", sa.Float(), nullable=False),
        sa.Column("score_version", sa.String(length=16), nullable=False),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "date", name="uq_activities_user_date"),
    )
    op.create_index("ix_activities_user_id", "activities", ["user_id"])

    op.create_table(
        "goals",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("type", sa.String(length=32), nullable=False),
        sa.Column("target_value", sa.Float(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "type IN ('steps', 'active_minutes', 'calories', 'distance')",
            name="ck_goals_type",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "type", name="uq_goals_user_type"),
    )
    op.create_index("ix_goals_user_id", "goals", ["user_id"])

    op.create_table(
        "profiles",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("display_name", sa.String(length=40), nullable=False),
        sa.Column("subtitle", sa.String(length=80), nullable=False),
        sa.Column("dark_theme", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("reduce_motion", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("haptic_feedback", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("use_metric_units", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", name="uq_profiles_user_id"),
    )
    op.create_index("ix_profiles_user_id", "profiles", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_profiles_user_id", table_name="profiles")
    op.drop_table("profiles")
    op.drop_index("ix_goals_user_id", table_name="goals")
    op.drop_table("goals")
    op.drop_index("ix_activities_user_id", table_name="activities")
    op.drop_table("activities")
