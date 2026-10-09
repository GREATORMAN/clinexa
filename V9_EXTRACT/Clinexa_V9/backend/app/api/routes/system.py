from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.database import get_db
from app.core.config import get_settings
router = APIRouter(tags=["System"])
settings = get_settings()
@router.get("/health")
def health(): return {"status": "ok", "service": settings.APP_NAME}
@router.get("/ready")
def ready(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1")); return {"status": "ready", "database": "ok"}
