# Clinexa V5 — Phase 1 Integrated Workflow Upgrade

This release deliberately focuses on replacing disconnected feature-shaped screens with persistent, permission-aware workflows. It does **not** claim that the entire Clinexa master specification is finished.

## Implemented in this phase

- Genuine account types for Patient, Doctor, Nurse, Receptionist, Lab Technician, Pharmacist, Hospital Administrator, Billing Staff, Support Staff and Caregiver request flow.
- Account-aware login: the selected workspace is validated against the account profile rather than acting as a visual role switch.
- Staff approval workflow with backend role/permission assignment. Doctor approval creates/links the doctor profile.
- Pending/rejected staff accounts cannot enter clinical workspaces.
- Self-scoped Patient Portal: a patient account reads only its linked patient record and can manage its own appointment requests, medication adherence logs and document downloads.
- Role-aware staff navigation. Doctors now enter a real doctor workspace rather than the administrator dashboard.
- Doctor work queue derived from the logged-in doctor's actual appointments, waiting patients, lab orders and encounter history.
- Integrated consultation workspace: patient context, timeline, verified medicines, prescription history, labs/documents, encounter recording, clinician-entered prescription creation and lab ordering.
- Patient 360° now includes the unified verified medication record and prescription OCR history.
- New persistent Patient Medication domain model so electronic prescriptions and reviewed OCR imports feed one Medicine Centre.
- Prescription OCR rebuilt around a draft/review/confirm workflow. Tesseract output is structured conservatively into medicine candidates, supports wrapped medicine/dose lines, preserves source text and confidence, and refuses dosage-only text as a medicine name.
- Prescription review UI shows the original image when supported, editable structured fields, confidence/uncertainty state, manual row addition and a **Confirm & Save Medicines** action.
- OCR never silently creates a medication record. Only explicitly confirmed rows enter the patient's Medicine Centre.
- Reminder schedules are created only when a person explicitly enters exact reminder times; frequency text is not converted into a schedule automatically.
- Electronic clinician prescriptions now also populate the Medicine Centre.
- Global PHI search now requires an explicit demographics permission instead of mere authentication.
- Existing NFC/Ollama implementations were preserved rather than replaced.
- Upgrade command safely creates the new tables and backfills existing electronic prescriptions into Patient Medication records.

## Validation performed in this build environment

- `python -m compileall -q app` — passed.
- Prescription OCR parser tests — 4 passed.
- Fresh SQLite schema creation — 48 tables, including all four new V5 account/medication/OCR tables.
- Upgrade script tested against a copy of the uploaded Clinexa development database — completed successfully; it created the account profile and backfilled 8 existing prescriptions into the Medicine Centre.
- Flutter source received structural delimiter checks across all Dart files with no detected bracket/brace mismatch.

Flutter/Dart executables are not installed in the build container, so `flutter analyze` and the Android device build must be run on the user's Windows/Flutter environment. The included upgrade/start scripts do this next-stage dependency/device startup work without overwriting `.env` or the existing database.

## Important work still not represented as complete

- Lab-report OCR still needs the same structured review depth as prescription OCR.
- Clinical note autosave/version history and immutable revision reasons are not yet complete.
- Appointment availability still needs richer slot rules, leave/blocking and waiting-list automation.
- Pharmacy inventory/dispensing, billing/insurance claims and admission/bed lifecycles need deeper end-to-end integration.
- Teleconsultation has session lifecycle records but not production video infrastructure.
- OS-level background notifications/reminders and full offline synchronization remain incomplete.
- Alembic-style versioned migrations are not yet present; this phase uses a safe additive V5 upgrade command.
- Full end-to-end, authorization, file-security and device/NFC test suites still need expansion.
- Caregiver access remains pending until it is explicitly linked to a patient; Clinexa does not grant a caregiver tenant-wide access.

## Apply to the current Windows project

1. Extract the overlay into the root containing `backend` and `frontend` and allow source files to be replaced.
2. Keep the existing `backend/.env`; the overlay intentionally does not contain it.
3. Run `scripts\UPGRADE_CLINEXA_V5.bat` once.
4. Run `scripts\START_CLINEXA_V5.bat` to start/reuse FastAPI, create the Android reverse tunnel and launch Flutter on the configured device.

If the device ID changes, set `CLINEXA_DEVICE` before starting, or edit the default in the launcher.
