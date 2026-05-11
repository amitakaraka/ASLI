"""Initial migration - create schema from SQLAlchemy metadata.

Revision ID: 001_initial
Revises:
Create Date: 2026-03-18
"""

from alembic import op
from database.models import db

revision = "001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    db.metadata.create_all(bind=bind)


def downgrade() -> None:
    bind = op.get_bind()
    db.metadata.drop_all(bind=bind)
