"""
Centralized Test Data Management for Clinexa E2E Automation.
Defines credentials, boundary payloads, role matrices, and clinical record fixtures.
"""

ROLES_USERS = {
    "admin": {
        "username": "admin@clinexa.com",
        "password": "AdminSecurePassword123!",
        "role": "SYSTEM_ADMINISTRATOR",
        "permissions": ["READ", "WRITE", "DELETE", "AUDIT", "MANAGE_USERS"]
    },
    "doctor": {
        "username": "doctor.smith@clinexa.com",
        "password": "DoctorSecurePassword123!",
        "role": "CLINICAL_DOCTOR",
        "permissions": ["READ", "WRITE", "DIAGNOSE", "PRESCRIBE"]
    },
    "nurse": {
        "username": "nurse.sarah@clinexa.com",
        "password": "NurseSecurePassword123!",
        "role": "CLINICAL_NURSE",
        "permissions": ["READ", "UPDATE_VITALS", "ADMINISTER_MEDS"]
    },
    "patient": {
        "username": "patient.doe@clinexa.com",
        "password": "PatientSecurePassword123!",
        "role": "PATIENT_PORTAL",
        "permissions": ["READ_OWN_RECORDS", "BOOK_APPOINTMENT"]
    },
    "pharmacist": {
        "username": "pharma.mike@clinexa.com",
        "password": "PharmaSecurePassword123!",
        "role": "PHARMACY_SPECIALIST",
        "permissions": ["READ_PRESCRIPTIONS", "DISPENSE_DRUGS"]
    }
}

BOUNDARY_PAYLOADS = {
    "sql_injection": [
        "' OR '1'='1",
        "admin' --",
        "'; DROP TABLE users; --",
        "\" OR \"\"=\""
    ],
    "xss_vectors": [
        "<script>alert('XSS')</script>",
        "<img src=x onerror=alert(1)>",
        "<svg onload=alert(document.domain)>",
        "javascript:alert(1)"
    ],
    "overflow_strings": [
        "A" * 256,
        "A" * 1024,
        "B" * 5000
    ],
    "unicode_strings": [
        "こんにちは世界",
        "مرحبا بالعالم",
        "Привет мир",
        "🚀🔥💻✨🛡️"
    ]
}

VIEWPORT_CONFIGS = [
    {"name": "Desktop 4K", "width": 3840, "height": 2160},
    {"name": "Desktop FHD", "width": 1920, "height": 1080},
    {"name": "Laptop WXGA", "width": 1366, "height": 768},
    {"name": "Tablet iPad Pro", "width": 1024, "height": 1366},
    {"name": "Tablet Portrait", "width": 768, "height": 1024},
    {"name": "Mobile Large", "width": 414, "height": 896},
    {"name": "Mobile Standard", "width": 375, "height": 667},
    {"name": "Mobile Small", "width": 320, "height": 568}
]

CLINICAL_FIXTURES = {
    "sample_patient": {
        "first_name": "Eleanor",
        "last_name": "Vance",
        "dob": "1988-04-12",
        "gender": "Female",
        "blood_group": "O+",
        "allergies": "Penicillin",
        "phone": "+1-555-0199"
    },
    "sample_appointment": {
        "doctor": "Dr. Sarah Connor",
        "department": "Cardiology",
        "date": "2026-10-15",
        "time": "10:30 AM",
        "reason": "Routine Cardiovascular Followup"
    },
    "sample_medication": {
        "name": "Atorvastatin Calcium",
        "dosage": "20mg",
        "category": "Cardiovascular",
        "stock": 450,
        "unit_price": 12.50
    }
}
