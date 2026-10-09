"""Use SQLite online backup so a running local database is copied consistently."""
from datetime import datetime
from pathlib import Path
import sqlite3
from sqlalchemy.engine import make_url
from app.core.config import get_settings


def main():
    url = make_url(get_settings().DATABASE_URL)
    if url.get_backend_name() != 'sqlite':
        raise SystemExit('This launcher backs up SQLite only. Back up your PostgreSQL database before running upgrade modules manually.')
    if not url.database or url.database == ':memory:':
        print('No persistent database to back up.'); return
    source = Path(url.database)
    if not source.exists():
        print('No existing database. A new one will be initialized.'); return
    target_dir = Path('backups'); target_dir.mkdir(exist_ok=True)
    target = target_dir / ('clinexa_pre_v9_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f') + '.db')
    with sqlite3.connect(source) as src, sqlite3.connect(target) as dest:
        src.backup(dest)
    print('Database backup created: ' + str(target.resolve()))

if __name__ == '__main__': main()
