"""Read-only installation checks. Run before replacing any project source."""
from pathlib import Path
import shutil,sys,subprocess

def check(source:Path,target:Path,find=shutil.which):
    errors=[]
    if sys.version_info<(3,10):errors.append('Python 3.10 or newer is required; Python 3.12 was used for verification.')
    for relative in ['backend/app/main.py','frontend/pubspec.yaml']:
        if not (target/relative).is_file():errors.append('Target is missing '+relative)
    for relative in ['backend/requirements.txt','backend/constraints-tested.txt','backend/alembic.ini','backend/alembic/versions/0002_v9.py','scripts/UPGRADE_CLINEXA_V9.bat','scripts/configure_native_v9.py','README_V9.md']:
        if not (source/relative).is_file():errors.append('Upgrade package is missing '+relative+'. Extract the complete ZIP first.')
    if find('flutter') is None:errors.append('Flutter is not on PATH. Open a terminal where flutter --version works, then retry.')
    if find('robocopy') is None:errors.append('Windows robocopy is not available on PATH.')
    native=target/'frontend/android'
    if native.is_dir():
        if not (native/'app/src/main/AndroidManifest.xml').is_file():errors.append('Existing Android project is missing its main manifest.')
        if not any((native/'app'/name).is_file() for name in ['build.gradle.kts','build.gradle']):errors.append('Existing Android project is missing its app Gradle file.')
    return errors

def main():
    if len(sys.argv)!=2:print('Usage: preflight_install.py EXISTING_PROJECT');return 2
    source=Path(__file__).resolve().parent.parent;target=Path(sys.argv[1]).resolve()
    errors=check(source,target)
    interpreter=target/'backend/.venv/Scripts/python.exe'
    if interpreter.exists():
        try:
            result=subprocess.run([str(interpreter),'-c','import sys;sys.exit(0 if sys.version_info >= (3,10) else 1)'],capture_output=True,timeout=15)
            if result.returncode:errors.append('The existing backend virtual environment needs Python 3.10 or newer. Recreate it before retrying.')
        except (OSError,subprocess.TimeoutExpired):errors.append('The existing backend virtual environment cannot run. Repair it before retrying.')
    if errors:
        for error in errors:print('ERROR: '+error)
        print('Preflight failed. No project source or database was changed.');return 1
    print('Preflight passed. Backups and installation can proceed.');return 0
if __name__=='__main__':raise SystemExit(main())
