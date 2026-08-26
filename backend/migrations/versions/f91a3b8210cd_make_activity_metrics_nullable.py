"""Make activity metrics nullable

Revision ID: f91a3b8210cd
Revises: e89f2a019b88
Create Date: 2026-08-25 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f91a3b8210cd'
down_revision: Union[str, None] = 'e89f2a019b88'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column('activities', 'steps', existing_type=sa.Float(), nullable=True)
    op.alter_column('activities', 'active_minutes', existing_type=sa.Float(), nullable=True)
    op.alter_column('activities', 'distance', existing_type=sa.Float(), nullable=True)
    op.alter_column('activities', 'calories', existing_type=sa.Float(), nullable=True)
    op.alter_column('activities', 'daily_score', existing_type=sa.Float(), nullable=True)


def downgrade() -> None:
    op.alter_column('activities', 'steps', existing_type=sa.Float(), nullable=False)
    op.alter_column('activities', 'active_minutes', existing_type=sa.Float(), nullable=False)
    op.alter_column('activities', 'distance', existing_type=sa.Float(), nullable=False)
    op.alter_column('activities', 'calories', existing_type=sa.Float(), nullable=False)
    op.alter_column('activities', 'daily_score', existing_type=sa.Float(), nullable=False)
