from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.audit import log_action
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.models.user import User
from app.models.clinical import Patient
from app.models.records import MedicalDocument, OcrResult
from app.models.advanced import MedicationSchedule
from app.models.medication import PatientMedication, PrescriptionOcrDraft, PrescriptionOcrItem
from app.services.storage import save_upload, path_for
from app.services.ocr_service import run_ocr, parse_prescription_ocr
from app.services.medication_catalog import catalog_suggestions
from app.schemas.domain import OcrVerifyRequest, OcrPrescriptionConfirmRequest

router = APIRouter(prefix="/documents", tags=["Documents"])


def _patient_for_user(db: Session, user: User, patient_id: str) -> Patient:
    patient = db.scalar(select(Patient).where(Patient.id == patient_id, Patient.hospital_id == tenant_id(user)))
    if not patient:
        raise HTTPException(404, "Patient not found")
    return patient


def _document_for_user(db: Session, user: User, document_id: str) -> MedicalDocument:
    doc = db.get(MedicalDocument, document_id)
    if not doc:
        raise HTTPException(404, "Document not found")
    _patient_for_user(db, user, doc.patient_id)
    return doc


def _draft_payload(db: Session, draft: PrescriptionOcrDraft) -> dict:
    items = db.scalars(
        select(PrescriptionOcrItem)
        .where(PrescriptionOcrItem.draft_id == draft.id)
        .order_by(PrescriptionOcrItem.created_at.asc())
    ).all()
    patient = db.get(Patient, draft.patient_id)
    hospital_id = patient.hospital_id if patient else ""
    item_payloads = []
    for item in items:
        item_payloads.append({
            "id": item.id,
            "source_line": item.source_line,
            "medication_name": item.medication_name,
            "strength": item.strength,
            "form": item.form,
            "frequency": item.frequency,
            "route": item.route,
            "duration": item.duration,
            "instructions": item.instructions,
            "confidence": item.confidence,
            "uncertain": item.uncertain,
            "include": item.include,
            "confirmed": item.confirmed,
            "catalog_matches": catalog_suggestions(db, hospital_id, item.medication_name, limit=3) if hospital_id else [],
        })
    return {
        "id": draft.id,
        "ocr_result_id": draft.ocr_result_id,
        "patient_id": draft.patient_id,
        "document_id": draft.document_id,
        "patient_name": draft.patient_name_text,
        "doctor_name": draft.doctor_name_text,
        "prescription_date": draft.prescription_date_text,
        "status": draft.status,
        "confirmed_at": draft.confirmed_at,
        "items": item_payloads,
    }


@router.post("/upload", status_code=201)
async def upload(
    patient_id: str = Form(...),
    category: str = Form("other"),
    description: str = Form(""),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("documents.upload")),
):
    _patient_for_user(db, user, patient_id)
    stored, _, detected_mime = await save_upload(file)
    row = MedicalDocument(
        patient_id=patient_id,
        category=category.strip().lower() or "other",
        original_name=file.filename or "upload",
        stored_name=stored,
        mime_type=detected_mime,
        description=description or None,
        uploaded_by_user_id=user.id,
    )
    db.add(row)
    db.flush()
    log_action(db, user.id, "document.upload", "medical_document", row.id, metadata={"category": row.category})
    db.commit()
    db.refresh(row)
    return row


@router.get("/patient/{patient_id}")
def list_docs(
    patient_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("documents.read")),
):
    _patient_for_user(db, user, patient_id)
    return db.scalars(
        select(MedicalDocument)
        .where(MedicalDocument.patient_id == patient_id)
        .order_by(MedicalDocument.created_at.desc())
    ).all()


@router.get("/{document_id}/download")
def download(
    document_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("documents.read")),
):
    doc = _document_for_user(db, user, document_id)
    p = path_for(doc.stored_name)
    if not p.exists():
        raise HTTPException(404, "Stored file is missing")
    log_action(db, user.id, "document.read", "medical_document", doc.id)
    db.commit()
    return FileResponse(p, media_type=doc.mime_type, filename=doc.original_name)


@router.post("/{document_id}/ocr")
def ocr(
    document_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("documents.ocr")),
):
    doc = _document_for_user(db, user, document_id)
    result = run_ocr(str(path_for(doc.stored_name)))
    if not result.get("available"):
        raise HTTPException(status_code=422, detail=result.get("message") or "OCR unavailable")

    is_prescription = doc.category.lower() in {"prescription", "rx", "medicine", "medication"}
    row = OcrResult(
        document_id=doc.id,
        raw_text=result.get("raw_text") or "",
        confidence=result.get("confidence"),
        status="needs_structured_review" if is_prescription else "needs_review",
    )
    db.add(row)
    db.flush()

    draft_payload = None
    if is_prescription:
        structured = parse_prescription_ocr(result.get("lines") or [])
        draft = PrescriptionOcrDraft(
            ocr_result_id=row.id,
            patient_id=doc.patient_id,
            document_id=doc.id,
            patient_name_text=structured.get("patient_name"),
            doctor_name_text=structured.get("doctor_name"),
            prescription_date_text=structured.get("prescription_date"),
            status="needs_review",
        )
        db.add(draft)
        db.flush()
        for item in structured.get("items") or []:
            db.add(PrescriptionOcrItem(draft_id=draft.id, **item))
        db.flush()
        draft_payload = _draft_payload(db, draft)

    log_action(
        db,
        user.id,
        "document.ocr",
        "medical_document",
        doc.id,
        metadata={"ocr_result_id": row.id, "structured_prescription": is_prescription},
    )
    db.commit()
    db.refresh(row)
    return {"ocr": row, "engine": result, "prescription_draft": draft_payload}


@router.get("/ocr/{ocr_id}")
def ocr_review(
    ocr_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("documents.ocr")),
):
    row = db.get(OcrResult, ocr_id)
    if not row:
        raise HTTPException(404, "OCR result not found")
    doc = _document_for_user(db, user, row.document_id)
    draft = db.scalar(select(PrescriptionOcrDraft).where(PrescriptionOcrDraft.ocr_result_id == row.id))
    return {
        "ocr": row,
        "document": doc,
        "prescription_draft": _draft_payload(db, draft) if draft else None,
    }


@router.post("/ocr/{ocr_id}/verify")
def verify(
    ocr_id: str,
    payload: OcrVerifyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("documents.ocr")),
):
    row = db.get(OcrResult, ocr_id)
    if not row:
        raise HTTPException(404, "OCR result not found")
    _document_for_user(db, user, row.document_id)
    if payload.confirmed_text is not None:
        row.raw_text = payload.confirmed_text
    row.status = "verified"
    row.verified_by_user_id = user.id
    log_action(db, user.id, "ocr.verify", "ocr_result", row.id)
    db.commit()
    db.refresh(row)
    return row


@router.post("/ocr/{ocr_id}/confirm-prescription")
def confirm_prescription(
    ocr_id: str,
    payload: OcrPrescriptionConfirmRequest,
    db: Session = Depends(get_db),
    user: User = Depends(require_permission("patient.clinical.write")),
):
    ocr_row = db.get(OcrResult, ocr_id)
    if not ocr_row:
        raise HTTPException(404, "OCR result not found")
    doc = _document_for_user(db, user, ocr_row.document_id)
    draft = db.scalar(select(PrescriptionOcrDraft).where(PrescriptionOcrDraft.ocr_result_id == ocr_id))
    if not draft:
        raise HTTPException(409, "This OCR result is not a prescription draft")
    if draft.status == "confirmed":
        raise HTTPException(409, "Prescription OCR has already been confirmed")

    draft.doctor_name_text = payload.doctor_name or draft.doctor_name_text
    draft.prescription_date_text = payload.prescription_date or draft.prescription_date_text

    draft_items = {
        item.id: item
        for item in db.scalars(select(PrescriptionOcrItem).where(PrescriptionOcrItem.draft_id == draft.id)).all()
    }
    created_medications = []
    created_schedules = []

    for submitted in payload.items:
        if not submitted.include:
            if submitted.item_id and submitted.item_id in draft_items:
                draft_items[submitted.item_id].include = False
            continue

        source_item = draft_items.get(submitted.item_id or "")
        if submitted.item_id and not source_item:
            raise HTTPException(400, f"OCR item {submitted.item_id} does not belong to this prescription")
        if source_item is None:
            source_item = PrescriptionOcrItem(
                draft_id=draft.id,
                source_line="Manually added during OCR review",
                confidence=1.0,
                uncertain=False,
                include=True,
            )
            db.add(source_item)
            db.flush()
            draft_items[source_item.id] = source_item

        # The human-confirmed values replace draft suggestions. We do not infer
        # dosage, route, duration or reminder times here.
        source_item.medication_name = submitted.medication_name.strip()
        source_item.strength = submitted.strength
        source_item.form = submitted.form
        source_item.frequency = submitted.frequency
        source_item.route = submitted.route
        source_item.duration = submitted.duration
        source_item.instructions = submitted.instructions
        source_item.include = True
        source_item.confirmed = True
        source_item.uncertain = False

        existing = db.scalar(
            select(PatientMedication).where(
                PatientMedication.source_type == "ocr_prescription",
                PatientMedication.source_id == source_item.id,
            )
        )
        if existing:
            medication = existing
        else:
            medication = PatientMedication(
                patient_id=doc.patient_id,
                source_type="ocr_prescription",
                source_id=source_item.id,
                source_document_id=doc.id,
                medication_name=submitted.medication_name.strip(),
                strength=submitted.strength,
                form=submitted.form,
                frequency=submitted.frequency,
                route=submitted.route,
                duration=submitted.duration,
                instructions=submitted.instructions,
                prescribing_doctor_text=draft.doctor_name_text,
                start_date=submitted.start_date,
                end_date=submitted.end_date,
                status=submitted.status,
                verified=True,
                verified_by_user_id=user.id,
            )
            db.add(medication)
            db.flush()
        created_medications.append(medication)

        # Reminders are created only when the reviewer explicitly enters exact
        # times; Clinexa never turns a frequency string into a schedule itself.
        reminder_times = (submitted.reminder_times or "").strip()
        if reminder_times:
            schedule = MedicationSchedule(
                patient_id=doc.patient_id,
                medication_name=submitted.medication_name.strip(),
                dose_label=" ".join(x for x in [submitted.strength, submitted.form] if x) or None,
                times_csv=reminder_times,
                start_date=submitted.start_date,
                end_date=submitted.end_date,
                instructions=submitted.instructions,
                active=submitted.status == "active",
            )
            db.add(schedule)
            db.flush()
            created_schedules.append(schedule)

    if not created_medications:
        raise HTTPException(400, "Confirm at least one medicine before saving")

    ocr_row.status = "verified"
    ocr_row.verified_by_user_id = user.id
    draft.status = "confirmed"
    draft.confirmed_by_user_id = user.id
    draft.confirmed_at = datetime.utcnow()
    log_action(
        db,
        user.id,
        "ocr.prescription.confirm",
        "prescription_ocr_draft",
        draft.id,
        metadata={"patient_id": doc.patient_id, "medicine_count": len(created_medications)},
    )
    db.commit()

    return {
        "status": "confirmed",
        "patient_id": doc.patient_id,
        "medicine_count": len(created_medications),
        "medications": created_medications,
        "reminder_count": len(created_schedules),
        "schedules": created_schedules,
        "draft": _draft_payload(db, draft),
    }
