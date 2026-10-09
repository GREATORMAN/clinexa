"""
Mobile Test Data Management for Clinexa Android Appium Automation.
Defines credentials, roles, device configurations, search fixtures, and boundary payloads.
"""

MOBILE_USERS = {
    "admin": {
        "email": "mobile.admin@clinexa.com",
        "password": "AdminSecurePassword123!",
        "role": "SYSTEM_ADMIN",
        "mfa_secret": "JBSWY3DPEHPK3PXP"
    },
    "doctor": {
        "email": "mobile.doctor@clinexa.com",
        "password": "DoctorSecurePassword123!",
        "role": "DOCTOR",
        "mfa_secret": "JBSWY3DPEHPK3PXP"
    },
    "patient": {
        "email": "mobile.patient@clinexa.com",
        "password": "PatientSecurePassword123!",
        "role": "PATIENT",
        "mfa_secret": "JBSWY3DPEHPK3PXP"
    },
    "nurse": {
        "email": "mobile.nurse@clinexa.com",
        "password": "NurseSecurePassword123!",
        "role": "NURSE",
        "mfa_secret": "JBSWY3DPEHPK3PXP"
    }
}

MOBILE_SEARCH_QUERIES = [
    "John Doe", "Hypertension", "Cardiology", "Prescription Refill",
    "ECG Report", "Dr. Sarah", "Emergency Admission", "Metformin"
]

MOBILE_FORM_FIXTURES = {
    "valid_patient": {
        "first_name": "Alexander",
        "last_name": "Hamilton",
        "phone": "+1-555-0188",
        "dob": "1985-01-11",
        "blood_group": "A+"
    },
    "invalid_patient": {
        "first_name": "",
        "last_name": "123456",
        "phone": "invalid-phone",
        "dob": "future-date"
    }
}

DEVICE_ORIENTATIONS = ["PORTRAIT", "LANDSCAPE"]
NETWORK_STATES = ["WIFI_CONNECTED", "AIRPLANE_MODE", "MOBILE_DATA_ONLY", "OFFLINE"]
