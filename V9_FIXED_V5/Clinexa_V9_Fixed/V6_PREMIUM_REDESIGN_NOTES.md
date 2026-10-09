# Clinexa V6 — Premium Experience + Connected Pharmacy/OCR

This release is an incremental upgrade over Clinexa V5. It preserves the existing backend database and local environment while replacing the main application experience with a new role-aware design system and deeper connected workflows.

## Major experience changes

- New Clinexa visual system: typography hierarchy, surfaces, semantic colors, premium cards, responsive grids, skeleton loading, consistent empty/error states, animated page transitions, compact mobile navigation and grouped desktop navigation.
- Redesigned admin, doctor, nurse, reception, lab, billing, pharmacy and patient experiences around actionable work rather than dashboard tile clutter.
- New patient portal with Home, Medicines, Appointments, Records and Pharmacy destinations.
- Redesigned Patient 360, patient directory, doctor directory, appointments, doctor home, medicine centre, documents/OCR and pharmacy workspace.
- New role home for reception, nursing, laboratory and billing users.

## Prescription OCR + medicine workflow

- Keeps OCR output as a draft until human confirmation.
- OCR medicine rows receive local formulary suggestions using conservative fuzzy matching.
- The review UI can display likely catalog matches without silently replacing OCR text.
- Users must explicitly choose/verify medicine information before saving.
- Confirmed medicines continue to feed the patient-linked Medicine Centre.
- Original source text remains visible for verification.

## Medication catalog

- Adds a local hospital medication catalog seeded with 58 common development/formulary entries across common categories and forms.
- Catalog cards include a custom medicine visual, generic/display name, strength, form, category and description.
- Catalog data is for OCR matching and hospital workflow demonstration, not treatment recommendation.

## Pharmacy request safety + workflow

- Patient pharmacy requests can only contain catalog items that Clinexa can link to an ACTIVE, VERIFIED medication already present in that patient's record.
- Browsing a catalog item does not create a medication, dosage or prescription.
- Requests are fulfillment requests to the hospital pharmacy; they do not create or modify prescriptions.
- Pharmacy staff receive a dedicated request queue with submitted/reviewing/ready/fulfilled/declined lifecycle states.
- Pharmacy workspace also shows formulary cards and inventory low-stock signals.

## Backend additions

- medication_catalog_items
- pharmacy_requests
- pharmacy_request_items
- medication catalog matching service
- patient portal pharmacy endpoints
- staff pharmacy request endpoints
- medication catalog API for clinical/OCR workflows
- new V6 additive upgrade command

## Install over V5

1. Back up `backend/.env` and `backend/clinexa_dev.db`.
2. Copy the V6 overlay into the existing `Clinexa_Functional_v2` root using normal overwrite/merge semantics. Do NOT use `/MIR`.
3. Run `scripts\UPGRADE_CLINEXA_V6.bat`.
4. Run `scripts\START_CLINEXA_V6.bat`.

The upgrade script intentionally preserves the existing local `.env` and database.

## Validation performed in the build environment

- Python source compilation passes with `python -m compileall -q app`.
- Dart source files were checked for balanced braces/brackets/parentheses.
- Full backend pytest execution could not complete in the artifact build container because the container does not have the project's `python-jose` dependency installed. Run the test suite inside the project's Windows `.venv` after applying the overlay.
- Android/Flutter compilation must be verified on the target Windows/Flutter environment.
