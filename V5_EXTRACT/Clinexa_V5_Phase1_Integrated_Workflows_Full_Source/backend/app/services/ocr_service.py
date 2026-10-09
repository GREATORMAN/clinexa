from __future__ import annotations

import re
from pathlib import Path
from statistics import mean
from typing import Any

from app.core.config import get_settings

settings = get_settings()

_STRENGTH_RE = re.compile(r"\b\d+(?:\.\d+)?\s?(?:mcg|mg|g|ml|mL|iu|IU|units?|%)\b")
_DURATION_RE = re.compile(r"\b(?:for\s*)?\d+\s*(?:day|days|week|weeks|month|months)\b|\bx\s*\d+\s*(?:day|days|week|weeks|month|months)\b", re.I)
_FREQUENCY_RE = re.compile(
    r"\b\d\s*[-–]\s*\d\s*[-–]\s*\d(?:\s*[-–]\s*\d)?\b|"
    r"\b(?:OD|BD|BID|TDS|TID|QID|HS|SOS|PRN)\b|"
    r"\b(?:once|twice|three times|four times)\s+(?:a\s+)?day\b|"
    r"\bevery\s+\d+\s*(?:h|hr|hrs|hour|hours)\b",
    re.I,
)
_ROUTE_RE = re.compile(r"\b(?:oral|PO|IV|IM|SC|subcutaneous|topical|inhaled|nasal|ophthalmic|otic)\b", re.I)
_FORM_RE = re.compile(
    r"\b(?:tab(?:let)?s?|cap(?:sule)?s?|syrup|susp(?:ension)?|inj(?:ection)?|cream|ointment|drops?|inhaler|powder|gel|lotion|patch)\b",
    re.I,
)
_SKIP_LINE_RE = re.compile(
    r"\b(?:patient|doctor|hospital|clinic|address|phone|mobile|email|date|age|sex|diagnosis|signature|registration)\b",
    re.I,
)


def _configure_tesseract():
    import pytesseract

    if settings.TESSERACT_CMD:
        pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_CMD
    return pytesseract


def _prepare_image(image):
    """Conservative preprocessing: preserve handwriting while improving contrast."""
    from PIL import ImageFilter, ImageOps

    image = ImageOps.exif_transpose(image).convert("RGB")
    if min(image.size) < 1400:
        scale = min(2.0, 1400 / max(1, min(image.size)))
        image = image.resize((int(image.width * scale), int(image.height * scale)))
    gray = ImageOps.grayscale(image)
    gray = ImageOps.autocontrast(gray, cutoff=1)
    return gray.filter(ImageFilter.MedianFilter(size=3))


def _ocr_pil_image(image, page_number: int = 1) -> dict[str, Any]:
    pytesseract = _configure_tesseract()
    output = pytesseract.Output.DICT

    # Compare original-ish grayscale and enhanced image, then keep the run with
    # the stronger average word confidence instead of blindly overprocessing.
    from PIL import ImageOps

    candidates = [ImageOps.exif_transpose(image).convert("L"), _prepare_image(image)]
    best: dict[str, Any] | None = None
    for candidate in candidates:
        data = pytesseract.image_to_data(candidate, output_type=output, config="--psm 6")
        line_map: dict[tuple[int, int, int, int], dict[str, Any]] = {}
        confidences: list[float] = []
        words: list[str] = []
        for idx, text in enumerate(data.get("text", [])):
            text = (text or "").strip()
            try:
                conf = float(data.get("conf", [])[idx])
            except Exception:
                conf = -1.0
            if not text:
                continue
            key = (
                int(data.get("block_num", [0])[idx] or 0),
                int(data.get("par_num", [0])[idx] or 0),
                int(data.get("line_num", [0])[idx] or 0),
                page_number,
            )
            entry = line_map.setdefault(key, {"words": [], "conf": [], "page": page_number})
            entry["words"].append(text)
            if conf >= 0:
                entry["conf"].append(conf)
                confidences.append(conf)
            words.append(text)

        lines = []
        for entry in line_map.values():
            line_text = " ".join(entry["words"]).strip()
            if line_text:
                lines.append(
                    {
                        "text": line_text,
                        "confidence": mean(entry["conf"]) if entry["conf"] else None,
                        "page": entry["page"],
                    }
                )
        result = {
            "raw_text": "\n".join(line["text"] for line in lines),
            "confidence": mean(confidences) if confidences else None,
            "lines": lines,
            "word_count": len(words),
        }
        score = (result["confidence"] or 0.0) + min(result["word_count"], 200) * 0.01
        if best is None or score > best["_score"]:
            result["_score"] = score
            best = result

    assert best is not None
    best.pop("_score", None)
    return best


def _read_pages(path: str):
    from PIL import Image

    suffix = Path(path).suffix.lower()
    if suffix == ".pdf":
        try:
            import pypdfium2 as pdfium
        except ImportError as exc:
            raise RuntimeError("PDF OCR requires pypdfium2. Run: python -m pip install pypdfium2") from exc
        pdf = pdfium.PdfDocument(path)
        if len(pdf) == 0:
            raise RuntimeError("PDF has no pages")
        for index in range(min(len(pdf), 8)):
            page = pdf[index]
            bitmap = page.render(scale=2.0)
            yield bitmap.to_pil(), index + 1
        return

    image = Image.open(path)
    frames = getattr(image, "n_frames", 1)
    for index in range(min(frames, 8)):
        try:
            image.seek(index)
        except EOFError:
            break
        yield image.copy(), index + 1


def run_ocr(path: str) -> dict[str, Any]:
    if settings.OCR_ENGINE.lower() != "tesseract":
        return {
            "available": False,
            "raw_text": "",
            "confidence": None,
            "lines": [],
            "message": f"OCR engine {settings.OCR_ENGINE!r} is not configured in this build.",
        }
    try:
        page_results = [_ocr_pil_image(image, page_number) for image, page_number in _read_pages(path)]
        lines = [line for result in page_results for line in result["lines"]]
        confidences = [result["confidence"] for result in page_results if result["confidence"] is not None]
        return {
            "available": True,
            "raw_text": "\n".join(result["raw_text"] for result in page_results if result["raw_text"]),
            "confidence": mean(confidences) if confidences else None,
            "lines": lines,
            "page_count": len(page_results),
            "message": "OCR extracted text — verify every field against the original document before saving.",
        }
    except Exception as exc:
        return {
            "available": False,
            "raw_text": "",
            "confidence": None,
            "lines": [],
            "message": f"OCR unavailable: {exc}",
        }


def _first_match(regex: re.Pattern[str], text: str) -> str | None:
    match = regex.search(text)
    return match.group(0).strip() if match else None


def _extract_labeled_value(lines: list[dict[str, Any]], labels: tuple[str, ...]) -> str | None:
    label_expr = "|".join(re.escape(label) for label in sorted(labels, key=len, reverse=True))
    pattern = re.compile(rf"\b(?:{label_expr})\b\s*[:\-]?\s*(.+)$", re.I)
    for line in lines:
        match = pattern.search(line["text"])
        if match:
            value = match.group(1).strip(" .:-")
            if value:
                return value[:200]
    return None


def _medicine_name_from_line(text: str, strength: str | None, frequency: str | None, duration: str | None, route: str | None) -> tuple[str | None, str | None]:
    cleaned = re.sub(r"^\s*(?:rx\s*[:.-]?|\d+[.)-]?|[-•*])\s*", "", text, flags=re.I).strip()
    form_match = _FORM_RE.search(cleaned)
    form = form_match.group(0) if form_match else None
    if form_match and form_match.start() <= 3:
        cleaned = cleaned[form_match.end():].strip(" .:-")

    cut_positions = []
    for value in (strength, frequency, duration, route):
        if value:
            pos = cleaned.lower().find(value.lower())
            if pos > 0:
                cut_positions.append(pos)
    if cut_positions:
        cleaned = cleaned[: min(cut_positions)]

    # Strip common instruction words only when they are trailing the candidate.
    cleaned = re.split(r"\b(?:take|apply|use|after food|before food|with food)\b", cleaned, maxsplit=1, flags=re.I)[0]
    cleaned = cleaned.strip(" ,;:-.")
    cleaned = re.sub(r"\s{2,}", " ", cleaned)
    if len(cleaned) < 2 or len(cleaned) > 200:
        return None, form
    if _SKIP_LINE_RE.search(cleaned) and not (strength or frequency or form):
        return None, form
    return cleaned, form


def _line_signals(text: str) -> tuple[str | None, str | None, str | None, str | None, str | None]:
    return (
        _first_match(_STRENGTH_RE, text),
        _first_match(_FREQUENCY_RE, text),
        _first_match(_DURATION_RE, text),
        _first_match(_ROUTE_RE, text),
        _first_match(_FORM_RE, text),
    )


def _name_like_line(text: str) -> bool:
    """Return True only for a short, non-metadata line that could be a medicine name.

    This does not decide that the text *is* a medicine. It is used only to join
    an adjacent dosage line, after which the combined text is still shown for
    human verification.
    """
    text = text.strip(" .,:;-")
    if not (2 <= len(text) <= 100) or _SKIP_LINE_RE.search(text):
        return False
    return bool(re.search(r"[A-Za-z]{2,}", text))


def parse_prescription_ocr(lines: list[dict[str, Any]]) -> dict[str, Any]:
    """Conservatively structure prescription OCR without correcting or inventing text.

    Printed prescriptions commonly wrap one medicine across two OCR lines
    (e.g. ``Tab Paracetamol`` then ``500 mg 1-0-1 for 5 days``). We join only
    adjacent lines when there is a clear dosage/form signal. The original OCR
    text remains the source of truth and every field stays a reviewable draft.
    """
    patient_name = _extract_labeled_value(lines, ("patient name", "patient"))
    doctor_name = _extract_labeled_value(lines, ("doctor", "dr", "physician"))
    prescription_date = _extract_labeled_value(lines, ("date", "prescription date"))

    normalized: list[dict[str, Any]] = []
    for line in lines:
        text = re.sub(r"\s+", " ", line.get("text", "")).strip()
        if text:
            normalized.append({"text": text, "confidence": line.get("confidence"), "page": line.get("page")})

    items: list[dict[str, Any]] = []
    seen: set[tuple[str, str | None, str | None]] = set()
    consumed: set[int] = set()

    for index, line in enumerate(normalized):
        if index in consumed:
            continue
        text = line["text"]
        confidence_values = [line.get("confidence")]
        strength, frequency, duration, route, form_signal = _line_signals(text)

        # A form/name line followed immediately by dosage details is treated as
        # one candidate instead of two disconnected medicines.
        if (
            form_signal
            and not any((strength, frequency, duration))
            and index + 1 < len(normalized)
            and index + 1 not in consumed
        ):
            next_text = normalized[index + 1]["text"]
            n_strength, n_frequency, n_duration, n_route, _ = _line_signals(next_text)
            if any((n_strength, n_frequency, n_duration, n_route)) and not _SKIP_LINE_RE.search(next_text):
                text = f"{text} {next_text}"
                consumed.add(index + 1)
                confidence_values.append(normalized[index + 1].get("confidence"))
                strength, frequency, duration, route, form_signal = _line_signals(text)

        # A dosage-only line can borrow only the immediately preceding short
        # name-like OCR line. This is deliberately narrow to avoid inventing a
        # drug from distant text on the page.
        medication_name, form = _medicine_name_from_line(text, strength, frequency, duration, route)
        starts_with_dose = bool(
            (strength and text.lower().find(strength.lower()) <= 3)
            or (frequency and text.lower().find(frequency.lower()) <= 3)
        )
        dosage_only_name = (
            starts_with_dose
            or medication_name is None
            or not re.search(r"[A-Za-z]{2,}", medication_name)
            or bool(re.fullmatch(r"[\d\s.%-]+", medication_name or ""))
        )
        if dosage_only_name and any((strength, frequency, duration)) and index > 0:
            previous = normalized[index - 1]
            previous_text = previous["text"]
            if _name_like_line(previous_text) and index - 1 not in consumed:
                text = f"{previous_text} {text}"
                confidence_values.append(previous.get("confidence"))
                strength, frequency, duration, route, form_signal = _line_signals(text)
                medication_name, form = _medicine_name_from_line(text, strength, frequency, duration, route)
                starts_with_dose = bool(
                    (strength and text.lower().find(strength.lower()) <= 3)
                    or (frequency and text.lower().find(frequency.lower()) <= 3)
                )

        # If the line still begins with dosage data after the narrowly scoped
        # adjacent-line join, it has no verified medicine name. Keep it out of
        # structured medicines rather than creating a fake name such as "mg".
        if starts_with_dose and not form_signal:
            continue

        # A candidate must look medication-like. This intentionally prefers
        # missing unreadable handwriting to guessing a medicine.
        if not any((strength, frequency, duration, form_signal)):
            continue
        if _SKIP_LINE_RE.search(text) and not any((strength, frequency, form_signal)):
            continue
        if not medication_name:
            medication_name, form = _medicine_name_from_line(text, strength, frequency, duration, route)
        if not medication_name or not re.search(r"[A-Za-z]{2,}", medication_name):
            continue

        key = (
            medication_name.lower(),
            strength.lower() if strength else None,
            frequency.lower() if frequency else None,
        )
        if key in seen:
            continue
        seen.add(key)

        raw_confidences = [float(x) for x in confidence_values if x is not None]
        conf = mean(raw_confidences) if raw_confidences else None
        normalized_conf = round(conf / 100.0, 3) if conf is not None else None
        uncertain = normalized_conf is None or normalized_conf < 0.72
        items.append(
            {
                "source_line": text,
                "medication_name": medication_name,
                "strength": strength,
                "form": form,
                "frequency": frequency,
                "route": route,
                "duration": duration,
                "instructions": text,
                "confidence": normalized_conf,
                "uncertain": uncertain,
            }
        )

    return {
        "patient_name": patient_name,
        "doctor_name": doctor_name,
        "prescription_date": prescription_date,
        "items": items,
    }
