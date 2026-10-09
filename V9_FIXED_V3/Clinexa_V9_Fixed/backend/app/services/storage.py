from pathlib import Path
from uuid import uuid4
from fastapi import UploadFile, HTTPException
from app.core.config import get_settings

settings = get_settings()

EXT_MIME = {
    ".pdf": "application/pdf",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
}

def _magic_ok(data: bytes, ext: str) -> bool:
    if ext == ".pdf":
        return data.startswith(b"%PDF-")
    if ext == ".png":
        return data.startswith(b"\x89PNG\r\n\x1a\n")
    if ext in {".jpg", ".jpeg"}:
        return data.startswith(b"\xff\xd8\xff")
    if ext == ".webp":
        return len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP"
    return False

async def save_upload(file: UploadFile) -> tuple[str, int, str]:
    original = file.filename or ""
    ext = Path(original).suffix.lower()
    if ext not in EXT_MIME:
        raise HTTPException(status_code=400, detail="Unsupported file extension")

    data = await file.read(settings.MAX_UPLOAD_SIZE + 1)
    if len(data) > settings.MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail="File is too large")
    if not data or not _magic_ok(data, ext):
        raise HTTPException(status_code=400, detail="File content does not match an allowed PDF/image format")

    expected_mime = EXT_MIME[ext]
    supplied = (file.content_type or "").lower()
    if supplied not in {expected_mime, "application/octet-stream", ""}:
        raise HTTPException(status_code=400, detail="File MIME type does not match its extension")

    storage = Path(settings.STORAGE_PATH)
    storage.mkdir(parents=True, exist_ok=True)
    stored_name = f"{uuid4()}{ext}"
    (storage / stored_name).write_bytes(data)
    return stored_name, len(data), expected_mime

def path_for(stored_name: str) -> Path:
    safe_name = Path(stored_name).name
    return Path(settings.STORAGE_PATH) / safe_name
