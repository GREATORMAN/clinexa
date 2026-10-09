# Clinexa V4 Advanced Feature Matrix

Clinexa V4 is a development/demo build. Use fictional patient data only until the deployment, security, privacy and compliance work is completed.

## Implemented in this source

- Premium responsive Clinexa V3/V4 design system, desktop sidebar and mobile navigation
- Authentication, RBAC-backed API permissions and audit log foundation
- Patient directory plus Patient 360° longitudinal workspace
- Doctors, departments and availability
- Appointment booking, rescheduling, check-in, queue and completion states
- Encounters, vitals, prescriptions and lab results
- Lab order lifecycle: ordered → collected → processing → completed/cancelled
- Document upload, OCR and human verification workflow
- Local Ollama AI chat and patient-record summary endpoint
- AI appointment proposal/confirmation safety flow
- Internal messages and notifications
- Care plans
- Medication schedules and dose-log API
- Symptom tracker
- Insurance policy records
- Emergency profile
- Trusted emergency contacts
- Real Android NFC NDEF tag write/read flow
- Revocable NFC emergency tokens
- QR emergency backup generation and QR scanning
- Minimal public emergency-card endpoint and emergency access audit logs
- NFC band revoke flow
- Pharmacy inventory, batches and dispensing
- Billing invoices and payment recording
- Wards, rooms, beds, admissions and discharge
- Visual bed board
- Teleconsultation room/session lifecycle and consent state
- Staff-shift API and view
- Consent records
- Global command search
- Hospital analytics overview
- Device/biometric app-lock option
- Enhanced fictional seed data: 6 doctors, 8 patients and advanced sample records

## Integration-ready, but requires an external/native service before production use

These are intentionally not faked as "working" because they need infrastructure outside this repository:

- Actual teleconsultation audio/video media transport and signaling (the room/session workflow is implemented)
- SMS/email/push delivery providers
- Production payment gateway and insurance-claim clearinghouse integrations
- Hospital LIS/HIS/EHR interoperability adapters
- Production object storage, backups and disaster recovery
- Production PostgreSQL/Redis deployment and background job workers
- Public internet hosting required for NFC/QR emergency access from a different phone
- Apple iOS NFC entitlements/signing configuration
- Production compliance certification and clinical governance review

## NFC security model

The physical tag stores only `CLINEXA:<high-entropy token>`. It does not store the patient's chart, prescription history, password or access token. A token can be revoked and every emergency-card lookup is logged.
