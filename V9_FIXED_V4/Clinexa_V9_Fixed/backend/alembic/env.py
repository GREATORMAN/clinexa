from alembic import context
from sqlalchemy import engine_from_config, pool

from app.core.database import Base
from app.core.config import get_settings

import app.models


config = context.config

database_url = (
    config.get_main_option("sqlalchemy.url")
    or get_settings().DATABASE_URL
)

# Alembic uses ConfigParser internally. Windows SQLite URLs can contain
# percent-encoded characters such as %3A and %5C, so percent signs must be
# escaped before assigning the URL as an Alembic config option.
config.set_main_option(
    "sqlalchemy.url",
    database_url.replace("%", "%%"),
)


if context.is_offline_mode():
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=Base.metadata,
        literal_binds=True,
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()
else:
    engine = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with engine.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=Base.metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()
