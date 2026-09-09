"""menu image url

Revision ID: 4f1a2b3c4d5e
Revises: 0c334c525870
Create Date: 2026-09-09

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4f1a2b3c4d5e'
down_revision: Union[str, None] = '0c334c525870'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('menus', sa.Column('image_url', sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column('menus', 'image_url')
