"""Add the outbound local Ollama bridge. Existing clinical tables are preserved."""
from alembic import op
import sqlalchemy as sa

revision = "0003_local_ai"
down_revision = "0002_v9"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("local_ai_workers",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("hospital_id", sa.String(36), sa.ForeignKey("hospitals.id"), nullable=False, unique=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("model", sa.String(120), nullable=False),
        sa.Column("secret_hash", sa.String(64), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("ready", sa.Boolean(), nullable=False),
        sa.Column("last_seen", sa.DateTime(), nullable=True),
        sa.Column("created_by", sa.String(36), sa.ForeignKey("users.id"), nullable=False))
    op.create_table("local_ai_requests",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("worker_id", sa.String(36), sa.ForeignKey("local_ai_workers.id"), nullable=False),
        sa.Column("state", sa.String(16), nullable=False),
        sa.Column("payload", sa.Text(), nullable=False),
        sa.Column("result", sa.Text(), nullable=True),
        sa.Column("lease_hash", sa.String(64), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False))
    for column in ("worker_id", "state", "expires_at"):
        op.create_index(f"ix_local_ai_requests_{column}", "local_ai_requests", [column])


def downgrade():
    op.drop_table("local_ai_requests")
    op.drop_table("local_ai_workers")
