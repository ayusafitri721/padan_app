"""satukan dua head migrasi (no-op merge)

Revision ID: eb55c1fbb774
Revises: 4f1a2b3c4d5e, cb2a4248c778
Create Date: 2026-09-09 17:19:29.574931

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'eb55c1fbb774'
down_revision: Union[str, None] = ('4f1a2b3c4d5e', 'cb2a4248c778')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
