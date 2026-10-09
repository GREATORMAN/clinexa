from __future__ import annotations

import re
from difflib import SequenceMatcher
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.catalog import MedicationCatalogItem
from app.models.medication import PatientMedication

_STOP = {
    "tablet", "tablets", "tab", "capsule", "capsules", "cap", "syrup", "suspension",
    "cream", "ointment", "drops", "inhaler", "injection", "mg", "mcg", "g", "ml", "iu",
}


def normalize_medication_name(value: str | None) -> str:
    value = (value or "").lower().replace("®", " ")
    value = re.sub(r"\b\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml|iu|units?|%)\b", " ", value, flags=re.I)
    tokens = [t for t in re.findall(r"[a-z]+", value) if t not in _STOP]
    return " ".join(tokens).strip()


def match_score(a: str | None, b: str | None) -> float:
    na, nb = normalize_medication_name(a), normalize_medication_name(b)
    if not na or not nb:
        return 0.0
    if na == nb:
        return 1.0
    if na in nb or nb in na:
        return 0.92
    ta, tb = set(na.split()), set(nb.split())
    token_score = len(ta & tb) / max(1, len(ta | tb))
    seq_score = SequenceMatcher(None, na, nb).ratio()
    return max(seq_score, token_score * 0.95)


def catalog_suggestions(db: Session, hospital_id: str, query: str | None, limit: int = 3) -> list[dict]:
    if not query or len(normalize_medication_name(query)) < 2:
        return []
    rows = db.scalars(
        select(MedicationCatalogItem).where(
            MedicationCatalogItem.hospital_id == hospital_id,
            MedicationCatalogItem.active == True,
        )
    ).all()
    ranked = []
    for item in rows:
        score = max(match_score(query, item.generic_name), match_score(query, item.display_name))
        if score >= 0.58:
            ranked.append((score, item))
    ranked.sort(key=lambda x: x[0], reverse=True)
    return [
        {
            "id": item.id,
            "generic_name": item.generic_name,
            "display_name": item.display_name,
            "strength": item.strength,
            "form": item.form,
            "category": item.category,
            "description": item.description,
            "image_key": item.image_key,
            "prescription_required": item.prescription_required,
            "match_score": round(score, 3),
        }
        for score, item in ranked[:limit]
    ]


def best_verified_medication_match(patient_medications: list[PatientMedication], catalog_item: MedicationCatalogItem) -> tuple[PatientMedication | None, float]:
    best = None
    best_score = 0.0
    for med in patient_medications:
        if not med.verified or med.status != "active":
            continue
        score = max(match_score(med.medication_name, catalog_item.generic_name), match_score(med.medication_name, catalog_item.display_name))
        if score > best_score:
            best = med
            best_score = score
    if best_score < 0.72:
        return None, best_score
    return best, best_score
