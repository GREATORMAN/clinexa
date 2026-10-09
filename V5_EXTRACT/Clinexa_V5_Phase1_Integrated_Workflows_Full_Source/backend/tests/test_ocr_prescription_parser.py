from app.services.ocr_service import parse_prescription_ocr


def test_structures_clear_printed_prescription_line_without_inventing_fields():
    result = parse_prescription_ocr([
        {"text": "Patient: Test Patient", "confidence": 96.0, "page": 1},
        {"text": "Dr. Test", "confidence": 95.0, "page": 1},
        {"text": "Tab Paracetamol 500 mg 1-0-1 for 5 days", "confidence": 91.0, "page": 1},
    ])
    assert result["patient_name"] == "Test Patient"
    assert result["doctor_name"] == "Test"
    assert len(result["items"]) == 1
    item = result["items"][0]
    assert item["medication_name"] == "Paracetamol"
    assert item["strength"].replace(" ", "") == "500mg"
    assert item["frequency"] == "1-0-1"
    assert "5 day" in item["duration"].lower()
    assert item["uncertain"] is False


def test_does_not_guess_plain_unreadable_or_non_medication_text():
    result = parse_prescription_ocr([
        {"text": "Patient: Example", "confidence": 80.0, "page": 1},
        {"text": "illegible scribble", "confidence": 25.0, "page": 1},
        {"text": "Follow up next week", "confidence": 88.0, "page": 1},
    ])
    assert result["items"] == []


def test_joins_wrapped_medicine_name_and_dosage_line_for_review():
    result = parse_prescription_ocr([
        {"text": "Tab Amoxicillin", "confidence": 89.0, "page": 1},
        {"text": "500 mg TDS for 5 days", "confidence": 92.0, "page": 1},
    ])
    assert len(result["items"]) == 1
    item = result["items"][0]
    assert item["medication_name"] == "Amoxicillin"
    assert item["strength"].replace(" ", "") == "500mg"
    assert item["frequency"].upper() == "TDS"
    assert item["source_line"] == "Tab Amoxicillin 500 mg TDS for 5 days"


def test_dosage_only_line_does_not_become_numeric_medicine():
    result = parse_prescription_ocr([
        {"text": "500 mg 1-0-1 for 5 days", "confidence": 90.0, "page": 1},
    ])
    assert result["items"] == []
