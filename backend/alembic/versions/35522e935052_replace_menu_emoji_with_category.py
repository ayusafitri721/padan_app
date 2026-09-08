"""replace menu emoji with category

Revision ID: 35522e935052
Revises: 0691b188fbbe
Create Date: 2026-09-08 20:06:25.414982

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '35522e935052'
down_revision: Union[str, None] = '0691b188fbbe'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'menus',
        sa.Column('category', sa.String(length=50), nullable=False, server_default='Makanan Utama'),
    )

    # Petakan emoji lama ke kategori agar data tidak hilang
    op.execute(
        "UPDATE menus SET category = 'Mie & Bakso' WHERE emoji = '🍜'"
    )
    op.execute(
        "UPDATE menus SET category = 'Minuman' WHERE emoji IN ('🧋', '☕')"
    )
    op.execute(
        "UPDATE menus SET category = 'Makanan Utama' WHERE emoji IN ('🍛', '🍗', '🍢', '🥘', '🍲', '🥗', '🍔', '🍟', '🍕', '🍤', '🥟', '🍚')"
    )

    op.alter_column('menus', 'category', server_default=None)
    op.drop_column('menus', 'emoji')
    # ### end Alembic commands ###


def downgrade() -> None:
    op.add_column('menus', sa.Column('emoji', mysql.VARCHAR(length=10), nullable=False, server_default='🍽️'))
    op.alter_column('menus', 'emoji', server_default=None)
    op.drop_column('menus', 'category')
    # ### end Alembic commands ###
