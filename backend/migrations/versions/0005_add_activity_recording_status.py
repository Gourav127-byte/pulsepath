"""Add honest day-level Activity recording status.

Revision ID: 0005_activity_recording_status
Revises: 0004_domain_user_fks

Existing rows cannot be classified reliably, so they remain explicitly
legacy_unknown. New lazy rows and confirmed writes use unrecorded/recorded.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "0005_activity_recording_status"
down_revision: str | Sequence[str] | None = "0004_domain_user_fks"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "activities",
        sa.Column(
            "recording_status",
            sa.String(length=16),
            nullable=False,
            server_default="legacy_unknown",
        ),
    )
    op.create_check_constraint(
        "ck_activities_recording_status",
        "activities",
        "recording_status IN ('unrecorded', 'recorded', 'legacy_unknown')",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_activities_recording_status", "activities", type_="check"
    )
    op.drop_column("activities", "recording_status")
