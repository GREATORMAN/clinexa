"""Adopt verified legacy schemas, then apply tracked migrations. Never drops data."""
from pathlib import Path
from alembic import command
from alembic.config import Config
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy import inspect,MetaData,text
from app.core.database import engine,Base
import app.models
NEW_TABLES={'clinical_drafts','clinical_revisions','workspace_records','device_sessions','mfa_factors','recovery_tickets','notification_preferences','caregiver_grants','background_jobs','dose_receipts'}
def revision_guards(connection):
    """Ensure protection also exists on verified schemas adopted without DDL."""
    if connection.dialect.name=='sqlite':
        for action in ['UPDATE','DELETE']:
            connection.execute(text(f"CREATE TRIGGER IF NOT EXISTS clinical_revision_no_{action.lower()} BEFORE {action} ON clinical_revisions BEGIN SELECT RAISE(ABORT, 'Clinical revisions are append-only'); END"))
    elif connection.dialect.name=='postgresql':
        connection.execute(text("CREATE OR REPLACE FUNCTION clinexa_revision_immutable() RETURNS trigger AS $$ BEGIN RAISE EXCEPTION 'Clinical revisions are append-only'; END; $$ LANGUAGE plpgsql"))
        exists=connection.scalar(text("SELECT 1 FROM pg_trigger WHERE tgname='clinical_revision_immutable' AND tgrelid='clinical_revisions'::regclass"))
        if not exists:connection.execute(text("CREATE TRIGGER clinical_revision_immutable BEFORE UPDATE OR DELETE ON clinical_revisions FOR EACH ROW EXECUTE FUNCTION clinexa_revision_immutable()"))

def migrate():
    config=Config(str(Path(__file__).resolve().parents[2]/'alembic.ini'))
    config.set_main_option('sqlalchemy.url',str(engine.url.render_as_string(hide_password=False)).replace('%','%%'))
    with engine.connect() as connection:
        tables=set(inspect(connection).get_table_names())
        if tables and 'alembic_version' not in tables:
            metadata=Base.metadata
            if not tables.intersection(NEW_TABLES):
                metadata=MetaData()
                for t in Base.metadata.sorted_tables:
                    if t.name not in NEW_TABLES:t.to_metadata(metadata)
                version='0001_v8'
            elif NEW_TABLES.issubset(tables):version='0002_v9'
            else:raise RuntimeError('Partial V9 schema detected. Keep the backup and resolve schema differences before migration.')
            differences=compare_metadata(MigrationContext.configure(connection),metadata)
            if differences:raise RuntimeError('Legacy database differs from the expected schema. Run the backed-up legacy upgrades, then retry. No version was stamped.')
            command.stamp(config,version)
    command.upgrade(config,'head')
    with engine.begin() as connection:revision_guards(connection)
    print('Alembic schema version is current. Existing clinical data preserved.')
if __name__=='__main__':migrate()
