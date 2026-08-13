"""Add ownership foreign keys for domain data.

Revision ID: 0004_domain_user_fks
Revises: 0003_add_password_reset_tokens

Domain rows are owned by a user and are deleted with that user. Existing rows
whose owner no longer exists are removed before constraints are introduced;
rows belonging to legitimate users are left untouched.
"""

from collections.abc import Sequence

from alembic import op


revision: str = "0004_domain_user_fks"
down_revision: str | Sequence[str] | None = "0003_add_password_reset_tokens"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    for table_name in ("profiles", "goals", "activities"):
        op.execute(
            f"DELETE FROM {table_name} "
            "WHERE NOT EXISTS ("
            f"SELECT 1 FROM users WHERE users.id = {table_name}.user_id"
            ")"
        )

    op.create_foreign_key(
        "fk_profiles_user_id_users",
        "profiles",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_goals_user_id_users",
        "goals",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_activities_user_id_users",
        "activities",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_activities_user_id_users", "activities", type_="foreignkey"
    )
    op.drop_constraint("fk_goals_user_id_users", "goals", type_="foreignkey")
    op.drop_constraint("fk_profiles_user_id_users", "profiles", type_="foreignkey")
