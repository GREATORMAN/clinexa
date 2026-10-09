import os
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent.parent
webapp_dir = root / "webapp"
backend_src = root / "backend"
frontend_web_src = root / "frontend" / "build" / "web"

print(f"Root: {root}")
print(f"Creating clean webapp in: {webapp_dir}")

# Ensure webapp directory exists
webapp_dir.mkdir(parents=True, exist_ok=True)
webapp_backend = webapp_dir / "backend"
webapp_frontend = webapp_dir / "frontend"

def copy_tree_clean(src: Path, dst: Path, ignore_patterns=None):
    if ignore_patterns is None:
        ignore_patterns = shutil.ignore_patterns("__pycache__", "*.pyc", "*.pyo", ".pytest_cache", ".venv")
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=ignore_patterns)

# 1. Copy backend app
print("Copying app...")
copy_tree_clean(backend_src / "app", webapp_backend / "app")

# 2. Copy alembic
print("Copying alembic...")
copy_tree_clean(backend_src / "alembic", webapp_backend / "alembic")

# 3. Copy backend files
for fname in ["alembic.ini", "requirements.txt", ".env", ".env.example", "clinexa_dev.db"]:
    src_file = backend_src / fname
    if src_file.is_file():
        shutil.copy2(src_file, webapp_backend / fname)
        print(f"Copied {fname}")

(webapp_backend / "storage").mkdir(parents=True, exist_ok=True)

# 4. Copy frontend web build
print("Copying frontend web build...")
copy_tree_clean(frontend_web_src, webapp_frontend, ignore_patterns=shutil.ignore_patterns("*.tmp"))

# 5. Update webapp/backend/app/main.py to recognize webapp/frontend
main_py_path = webapp_backend / "app" / "main.py"
content = main_py_path.read_text(encoding="utf-8")

replacement = """from pathlib import Path
from fastapi.staticfiles import StaticFiles

# Candidate directories for web frontend:
candidate_dirs = [
    Path(__file__).resolve().parent.parent.parent / "frontend",
    Path(__file__).resolve().parent.parent / "frontend",
    Path(__file__).resolve().parent.parent.parent / "frontend" / "build" / "web",
]
web_dir = next((d for d in candidate_dirs if d.is_dir() and (d / "index.html").is_file()), None)

if web_dir:
    app.mount("/", StaticFiles(directory=str(web_dir), html=True), name="frontend")
else:
    @app.get("/")
    def root(): return {"name": "Clinexa", "version": "9.0.0", "docs": "/docs"}
"""

if 'web_dir = Path(__file__).resolve().parent.parent.parent / "frontend" / "build" / "web"' in content:
    # Replace from "from pathlib import Path" to the end
    idx = content.find("from pathlib import Path")
    content = content[:idx] + replacement
    main_py_path.write_text(content, encoding="utf-8")
    print("Updated webapp/backend/app/main.py static mounting.")

print("Clean webapp folder populated successfully!")
