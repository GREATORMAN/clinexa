# Clinexa V8 — care workspace upgrade

This upgrades the recovered **Clinexa V7 Showcase Full Source**. It preserves the Flutter + FastAPI architecture and existing local Ollama, OCR, medication, pharmacy, hospital, and patient workflows. It was built from the saved source archive, not from a live copy of your Windows folder.

## Install into your existing project (recommended)

1. Stop the old backend with **Ctrl+C in its terminal**. Close the running Flutter session.
2. Extract this ZIP. Find the `Clinexa_V8` folder that contains `backend`, `frontend`, and `scripts`.
3. Open CMD inside that folder and run:

```bat
scripts\INSTALL_INTO_EXISTING.bat "C:\Users\VISHAL\Documents\pdd\Clinexa_Full_v2\Clinexa_Functional_v2"
```

The installer backs up the old source, then copies updated application source, tests, dependency manifest and scripts. It preserves your `.env`, database, uploaded documents, Android/iOS platform folders, signing setup and local SDK configuration. SQLite receives an online database backup before additive migrations. Backup failures stop the upgrade. A PostgreSQL installation must be backed up separately and upgraded manually; this installer deliberately stops rather than skipping that backup.

4. In CMD, open the existing project:

```bat
cd /d "C:\Users\VISHAL\Documents\pdd\Clinexa_Full_v2\Clinexa_Functional_v2"
scripts\VERIFY_CLINEXA_V8.bat
scripts\START_CLINEXA_V8.bat
```

The verifier runs backend tests, Flutter analysis, widget tests and a debug APK build. Existing Flutter warnings are reported but do not fail the analyzer; compiler errors do fail it. The Android launcher defaults to your Moto device `ZD2224F6K4`. To use a different phone:

```bat
scripts\START_CLINEXA_V8.bat YOUR_ADB_DEVICE_ID
```

Do not run the commands from System32 unless you use their full paths. CMD uses `cd /d`; PowerShell uses `Set-Location`.

## Start only the backend

```bat
cd /d "C:\Users\VISHAL\Documents\pdd\Clinexa_Full_v2\Clinexa_Functional_v2\backend"
.venv\Scripts\activate.bat
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

`http://127.0.0.1:8000/` should identify Clinexa **8.0.0**. If it identifies 6.0.0, an old backend is still running. The new launcher never kills that process automatically. For the phone, the launcher creates a device-specific ADB reverse bridge.

For Chrome, keep the backend running and run `scripts\START_CLINEXA_WEB_V8.bat` from the project root. It fixes the web port at 8080 to match the existing CORS configuration.

## New installation

Run `scripts\UPGRADE_CLINEXA_V8.bat` from the extracted project. It creates a virtual environment if needed and creates a unique local signing key only when no `.env` exists. Then create your administrator interactively:

```bat
cd backend
.venv\Scripts\python.exe -m app.cli.create_admin
```

You can populate fictional records with `python -m app.cli.seed_demo` after activating the virtual environment. Run `python -m app.cli.upgrade_v6` again afterward if the hospital did not exist during the initial catalog migration. Existing installations already have their hospital/catalog. No accounts or passwords are bundled in the ZIP.

## What changed

### Visual and navigation experience

- A warmer, restrained green visual system, lighter desktop sidebar, cleaner page headers, reduced banner clutter, simpler surfaces and readable controls.
- Rebuilt administrator overview with real patient counts, today's schedule, waiting room, task totals, seven-day appointment activity and functional shortcuts.
- Role home shortcuts for scheduling, care tasks, laboratory work and billing. Decorative security/live metric cards were removed from nurse and billing homes.
- Searchable workspace command palette: **Ctrl+K** on Windows and **Command+K** on macOS; Enter opens the first matching workspace.
- Scrollable mobile More menu, constrained dropdowns and content-driven cards. Login switches to a scrolling layout on short desktop windows.
- Shared typography uses the platform font and no longer downloads Google Fonts at runtime.
- Notifications are reachable from both the staff shell and patient portal.

### Persistent workflows

- Patient-linked care tasks: title, handoff notes, normal/high/urgent priority, due date, overdue filter, search, start, complete, reopen and cancel.
- Tasks use hospital authorization, audit entries, UTC due dates and a version check to reject stale updates.
- Patient 360 shows the patient's care tasks and opens a board filtered to that patient.
- Notification inbox: all/unread filters, individual read and mark-all-read. Reads are scoped to the signed-in account.
- Appointments: patient/doctor/context search, today/upcoming filters, chronological ordering, allowed status actions and double-submission protection on the booking action.
- Scheduling rejects overlapping visits using the doctor's consultation duration, including patient portal and confirmed AI bookings. Terminal/in-consultation visits cannot be rescheduled.
- Bed workflow: admission → occupied → discharge → cleaning → mark ready → available. Occupied beds cannot be released using the status endpoint.

### Reliability and access controls

- Frontend refreshes expired access tokens with one shared refresh request. Retried uploads clone their multipart data.
- Profile permissions drive relevant UI controls. Operations and care dashboards only fetch authorized modules, so an unrelated 403 does not break the whole page.
- Pharmacists are no longer directed to a clinical medication screen they cannot read.
- Search omits doctor, appointment and document groups the caller is not authorized to read.
- Added patient/hospital checks for billing, admission and prescription dispensing.
- Dispensing rejects expired batches and guards stock updates. Negative batch quantities are rejected. Payments above the outstanding invoice balance are rejected.
- AI booking still requires explicit confirmation; it now uses the shared slot validation and writes an audit entry.
- Unsupported device authentication no longer silently bypasses an enabled device lock.

## Verification performed here

- **19 backend tests passed** with real FastAPI requests and isolated SQLite databases; these include the original OCR parser/password tests and the new workflow tests.
- All backend Python source compiled.
- **34 Dart files** (33 application files and one test file) parsed without syntax errors using a Dart grammar. This is not Flutter type checking.
- Tesseract successfully extracted a clean, fictional prescription image in this environment. This does not establish handwriting accuracy or your Windows Tesseract setup.
- The SQLite backup command completed successfully.

## Remaining verification and limits

**A Flutter SDK and Android runtime were unavailable here. Flutter analysis, widget tests, APK compilation and visual rendering have not been run here.** The included Windows verifier runs these checks using your existing Flutter installation. The ZIP contains source, not a prebuilt APK. Windows batch scripts have not been executed on Windows here.

The package includes responsive widget tests at 320, 390, 768 and 1440 pixels with enlarged text. Inspect your phone at default and enlarged font settings after the verifier passes; syntax checks cannot establish overflow-free rendering.

Local Ollama chat needs your running Ollama service and installed `qwen3:1.7b`. The real model was not available for inference tests here. NFC, camera, QR scanning and biometrics require physical-device checks. OCR-extracted medicine fields still require human review before confirmation.

Virtual visit records track consent and status; they do **not** provide video calls. Medication schedule/adherence records do **not** establish background operating-system reminder delivery. Both need additional native implementation and device verification before being represented as those features.

The existing appointment timestamps use hospital-local naive times; care-task due dates use UTC. Multi-timezone scheduling, concurrent overlapping bookings at different timestamps, simultaneous invoice payments, release signing, offline synchronization, production secret management and a full security audit are not solved by this upgrade. Database uniqueness protects an exact doctor/start collision, but there is no database exclusion constraint for all overlap cases. This is a tested development-source upgrade, not a claim of production readiness or that every inherited screen has been tested end to end.

## Acceptance checks on your machine

1. Sign in as an administrator; open each workspace and confirm the V8 overview/navigation.
2. Check the Moto at narrow width, enlarged font, keyboard open, and the More menu.
3. Create a patient and doctor; book, search and filter a visit. Reject a second overlapping booking.
4. Move a visit through check-in, waiting, consultation and completion.
5. Create a patient task; find it in Patient 360, complete it, reopen it and verify it after restart.
6. Mark a notification read; verify another account's inbox is unaffected.
7. Test nurse, receptionist, lab technician, pharmacist and billing accounts independently.
8. Upload a fictional prescription; verify extracted fields, save, and confirm the medication and pharmacy workflow.
9. Admit, discharge and mark a cleaned bed ready; confirm occupancy cannot be bypassed.
10. Record a partial/full invoice payment and reject overpayment.
11. Keep a session open beyond access-token expiry and confirm the next authorized request refreshes it.
12. Test Ollama, NFC and device authentication on the actual installed services/device.

Source rollback: restore `backend\app`, `backend\tests`, `frontend\lib`, `frontend\test`, scripts and saved manifests from the installer source backup. Stop the backend before restoring a database snapshot. Keep uploaded documents alongside their matching database. The installer does not delete old files or provide an automatic rollback.
