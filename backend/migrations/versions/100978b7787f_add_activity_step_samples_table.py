"""add_activity_step_samples_table

Revision ID: 100978b7787f
Revises: f91a3b8210cd
Create Date: 2026-08-26 10:58:00.106170
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = '100978b7787f'
down_revision: str | Sequence[str] | None = 'f91a3b8210cd'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table('activity_step_samples',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('date', sa.Date(), nullable=False),
    sa.Column('start_time', sa.DateTime(timezone=True), nullable=False),
    sa.Column('end_time', sa.DateTime(timezone=True), nullable=False),
    sa.Column('steps', sa.Integer(), nullable=False),
    sa.Column('source_origin', sa.String(length=64), server_default='health_connect', nullable=False),
    sa.Column('sample_id', sa.String(length=128), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.CheckConstraint('end_time >= start_time', name='ck_step_samples_time_range'),
    sa.CheckConstraint('steps >= 0', name='ck_step_samples_steps_positive'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'sample_id', name='uq_step_samples_user_sample')
    )
    op.create_index(op.f('ix_activity_step_samples_date'), 'activity_step_samples', ['date'], unique=False)
    op.create_index(op.f('ix_activity_step_samples_start_time'), 'activity_step_samples', ['start_time'], unique=False)
    op.create_index(op.f('ix_activity_step_samples_user_id'), 'activity_step_samples', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_activity_step_samples_user_id'), table_name='activity_step_samples')
    op.drop_index(op.f('ix_activity_step_samples_start_time'), table_name='activity_step_samples')
    op.drop_index(op.f('ix_activity_step_samples_date'), table_name='activity_step_samples')
    op.drop_table('activity_step_samples')
