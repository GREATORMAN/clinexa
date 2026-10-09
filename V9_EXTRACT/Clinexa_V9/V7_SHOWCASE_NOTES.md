# Clinexa V7 — Showcase UI / Responsive Reliability Pass

V7 is a frontend-first presentation and usability rebuild on top of the working V6 backend/workflows. It intentionally does not create a new database schema or overwrite local `.env` / SQLite data.

## What changed

- Rebuilt global visual language: Inter typography, calmer clinical palette, stronger information hierarchy, premium surfaces, consistent radius/elevation, and reusable teal/navy accent system.
- Rebuilt desktop/tablet/mobile application shell with a dark role-aware workspace rail, premium top bar, animated page switching, and floating mobile dock.
- Removed the fixed-aspect-ratio feature grids that caused `BOTTOM OVERFLOWED BY ... PIXELS` on compact Android devices. Primary dashboards and cards now use `CxAdaptiveGrid`, a content-height `Wrap` layout.
- Made section headers, page actions, filters, and cards adapt to narrow widths instead of forcing desktop rows onto phones.
- Rebuilt login experience for mobile and desktop with a much more visible Clinexa identity.
- Rebuilt dashboard / role home / doctor home presentation around spotlight heroes, action-first metrics, and real queues.
- Rebuilt Patient 360, Patients, Doctors, Appointments, Medicine Centre, Pharmacy, Documents/OCR and Care Operations presentation.
- Rebuilt Documents & OCR into a visible 3-step pipeline: Capture -> Extract -> Verify & Save, with the existing human-verification workflow preserved.
- Medicine Centre and Patient Portal keep the V6 formulary search, category filters, illustrated medicine cards, verified medicine history, reminders, OCR provenance and pharmacy request workflow.
- Patient pharmacy request flow remains constrained to verified medication records; catalog browsing does not create prescriptions or infer doses.
- Upgraded older feature pages through the shared `SectionPage` so AI, records, messages, emergency, operations, search and settings inherit the new presentation rather than looking like a different app.
- Replaced deprecated `withOpacity` calls touched by the redesign and modernized legacy dropdown initial values where practical.

## Overflow strategy

V7 removes all feature-level `GridView` / `childAspectRatio` layouts from the Flutter feature code. Cards grow with their content instead of being forced into a fixed height. Mobile page headers and section actions stack or wrap on smaller widths.

## Safety

- OCR remains a draft until explicit human confirmation.
- Unreadable prescription text is not guessed.
- Medicine catalog matching is a suggestion layer, not a prescription generator.
- Pharmacy requests must map to an active verified medication in the patient's record.
- No catalog item automatically creates a dose, frequency, duration, or reminder schedule.

## Validation performed in build environment

- Python backend source compilation: PASS.
- Static Dart delimiter/structure scan across all Flutter source files: PASS.
- Remaining feature-level fixed GridView / childAspectRatio layouts: NONE.
- Known invalid icons previously encountered (`clinical_notes_outlined`, `calendar_add_on_rounded`, etc.): NONE.
- Invalid FontWeight values previously encountered (`w750`, `w650`): NONE.

Flutter/Android SDK is not installed in the artifact build environment, so the first real `flutter analyze` and Android compile must run on the Windows/Flutter installation used for Clinexa.
