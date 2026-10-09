from pathlib import Path
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine,inspect,text
from app.core.database import Base
from app.cli.migrate import NEW_TABLES

def config(path):
    cfg=Config(str(Path(__file__).resolve().parents[1]/'alembic.ini'));cfg.set_main_option('sqlalchemy.url','sqlite:///'+str(path));return cfg

def test_fresh_migrations_match_schema(tmp_path):
    path=tmp_path/'fresh.db';command.upgrade(config(path),'head');engine=create_engine('sqlite:///'+str(path))
    with engine.connect() as c:
        assert set(Base.metadata.tables).issubset(set(inspect(c).get_table_names()))
        assert c.scalar(text('select version_num from alembic_version'))=='0002_v9'
        assert c.scalar(text("select count(*) from sqlite_master where type='trigger' and name like 'clinical_revision_%'"))==2
    engine.dispose()
def test_v8_to_v9_preserves_existing_rows(tmp_path):
    path=tmp_path/'existing.db';cfg=config(path);command.upgrade(cfg,'0001_v8');engine=create_engine('sqlite:///'+str(path))
    with engine.begin() as c:
        from app.models.organization import Hospital
        c.execute(Hospital.__table__.insert().values(id='h',name='Existing hospital',code='EX'))
    command.upgrade(cfg,'head')
    with engine.connect() as c:
        assert c.scalar(text("select name from hospitals where id='h'"))=='Existing hospital'
        assert NEW_TABLES.issubset(set(inspect(c).get_table_names()))
    engine.dispose()

def test_adopted_current_schema_installs_missing_revision_guards(tmp_path,monkeypatch):
    from app.cli import migrate as module
    path=tmp_path/'adopted.db';engine=create_engine('sqlite:///'+str(path));Base.metadata.create_all(engine)
    with engine.begin() as c:
        c.execute(text('DROP TRIGGER clinical_revision_no_update'))
        c.execute(text('DROP TRIGGER clinical_revision_no_delete'))
    monkeypatch.setattr(module,'engine',engine)
    module.migrate();module.migrate()
    with engine.connect() as c:
        assert c.scalar(text('select version_num from alembic_version'))=='0002_v9'
        assert c.scalar(text("select count(*) from sqlite_master where type='trigger' and name like 'clinical_revision_%'"))==2
    engine.dispose()

def test_legacy_adoption_preserves_data(tmp_path,monkeypatch):
    from app.cli import migrate as module
    from app.models.organization import Hospital
    path=tmp_path/'legacy.db';cfg=config(path);command.upgrade(cfg,'0001_v8');engine=create_engine('sqlite:///'+str(path))
    with engine.begin() as c:
        c.execute(Hospital.__table__.insert().values(id='h',name='Preserved hospital',code='LEGACY'))
        c.execute(text('DROP TABLE alembic_version'))
    monkeypatch.setattr(module,'engine',engine);module.migrate()
    with engine.connect() as c:
        assert c.scalar(text("select name from hospitals where id='h'"))=='Preserved hospital'
        assert c.scalar(text('select version_num from alembic_version'))=='0002_v9'
    engine.dispose()
