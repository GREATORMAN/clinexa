# Clinexa V9 · reference-inspired interface and safer clinical workflows

This update builds on V8. The reference's dark surfaces, rounded cards, soft pink/violet gradients and floating dock now guide the shared Flutter UI. Dark mode is the default; the top-bar switch and Appearance & account screen persist the chosen theme. See COVERAGE_V9.md for every requested area and the remaining work.

## Install into Vishal's Windows project

1. Stop the old backend terminal with Ctrl+C and stop the running Flutter app.
2. Extract the ZIP. Open the extracted **Clinexa_V9** folder in Explorer.
3. Double-click **INSTALL_V9.bat**. Its default target is:
   `C:\Users\VISHAL\Documents\pdd\Clinexa_Full_v2\Clinexa_Functional_v2`
4. After installation, open the target folder in Explorer, type **cmd** into its address bar and press Enter. Run:

   ```bat
   scripts\VERIFY_CLINEXA_V9.bat
   scripts\START_CLINEXA_V9.bat ZD2224F6K4
   ```

For another target, open CMD from the extracted Clinexa_V9 folder and run:

```bat
INSTALL_V9.bat "C:\path\to\existing\Clinexa_Functional_v2"
```

The earlier `C:\Users\VISHAL>scripts\INSTALL_INTO_EXISTING.bat ...` error occurs because CMD searches for the scripts folder under the current directory. The root installer resolves its own script location automatically.

Before changing source, the installer checks Python, Flutter, robocopy, package completeness and the existing target/native files. These checks are read-only. The installer backs up the replaced source and makes an online SQLite database backup. It preserves existing environment, patient database, storage, native package name and signing setup. Android notification setup edits the manifest/Gradle file and creates `.pre_v9` copies first. A failed verification is a reason to stop before launching; it is not reported as a successful build.

## Features to try

- **Clinical notes:** select a patient, create a draft, edit and observe autosave. Finalize to lock it. Amend a final note with a reason; inspect its previous versions. Stale writes return a conflict and keep the text on screen. Only the author may edit. Navigation waits for pending changes to save.
- **Lab workspace:** create a specimen, track its accession QR and timeline, then collect → receive → process. Paste report/OCR text into the side-by-side verifier; correct every field. Explicit human verification is required. A doctor/admin reviews and releases results into the existing patient labs. The parser is conservative and does not interpret clinical findings.
- **Messages:** choose a hospital contact, send a private two-person message, see sent/read states. Each thread refreshes every ten seconds. There are no attachments or group conversations yet.
- **Appearance & account:** toggle light/dark appearance and reduced motion; enroll an authenticator; list and revoke devices or sign out all sessions. Enabling MFA revokes existing sessions. The login screen accepts the six-digit authenticator code.
- **Password recovery:** request an email, then paste its token and choose a new password. Tokens expire after 30 minutes, are stored as hashes, and are single-use. Reset revokes sessions and preserves enabled MFA.
- **Patient Privacy & sharing:** the account menu opens granular, read-only caregiver sharing, selected-document access, immediate revocation, portal JSON export and emergency scan history. A pending caregiver still needs hospital approval. An approved caregiver's home shows only active grants.
- **Audit centre:** filter hospital-scoped actor/action/object/date events, inspect details and export the matching set (up to 500 rows).
- **Device medication reminders:** the patient's medicine page has Enable / refresh reminders, Turn off and Retry dose sync. Android/iOS source schedules the next seven days, capped at 60 upcoming notifications. Taken/Skip/Snooze actions open the app. Dose actions queue in platform secure storage and retry when Clinexa is opened online. Backend idempotency prevents duplicate actions.

## Device reminder setup and limitations

Android permissions, boot receivers and desugaring are configured by `scripts/configure_native_v9.py`. Build with a recent Flutter SDK and Android SDK 35 or newer. Grant notification permission on the device. Scheduling uses inexact alarms; delivery timing follows OS and battery policy. This is not a substitute for a clinical medication-administration system. Refresh the seven-day window by opening the patient portal.

For iOS, generate the iOS platform folder on a Mac if absent, configure the notification delegate in AppDelegate using the flutter_local_notifications 18.0.1 setup, and test launch actions, permissions and keychain access on a real device. No iOS build has been performed here.

Native credential and dose-queue storage uses flutter_secure_storage. Web storage has different security properties; this update does not implement encrypted web clinical caching. The dose queue is not a general offline sync system.

## Mail worker

Configure SMTP_HOST, SMTP_PORT (587), SMTP_FROM, SMTP_USER and SMTP_PASSWORD in backend environment. STARTTLS is required. Run or schedule:

```bat
cd backend
.venv\Scripts\python.exe -m app.cli.worker
```

Without SMTP settings, the worker reports unavailable and leaves queued jobs intact. It sends no fake email. Mail payloads are encrypted, and successful jobs clear them. Retries are bounded to five attempts. A worker terminated during a running job needs operator review. Keep SECRET_KEY stable; in production use a separate ENCRYPTION_KEY. Changing the encryption key without migrating factor/job secrets prevents their decryption. MFA recovery codes/passkeys and email verification are still pending.

## Database and verification

Alembic includes a frozen V8 baseline and additive V9 migration. Fresh databases can use `python -m app.cli.migrate`; verified legacy schemas can be adopted and stamped. The Windows upgrade first runs the existing additive upgrades, then validates/stamps their resulting schema. Downgrades are intentionally disabled; restore a verified backup instead. SQLite revision tables reject SQL update/delete; PostgreSQL triggers are included in the migration but have not been tested against a live PostgreSQL server here.

Backend verification in this environment: **44 automated tests pass**; Python compilation passes. Dart grammar parsing passes for **43 files**. **Flutter analyze, widget tests, APK build, visual rendering, device notifications, NFC and iOS were not executable here because there is no Flutter SDK or device.** The supplied Windows verification script runs analyze, tests and a debug APK build on your machine. Grammar parsing is not compilation.

Container, PostgreSQL Compose, CI and Firebase Hosting starter configurations are included. Read deploy/README.md before hosting. Cloud Run/private object storage, FCM push and WebRTC/TURN are not implemented or deployed by this release. It is not a completed production certification or the entire requested backlog.

## Continued installation checks

The updated package adds read-only preflight checks and Python-launcher fallback, backs up root configuration files as well as source, and handles partially configured Android notification receivers/desugaring settings. Native transformations are validated before any native file is changed. Schema adoption now ensures revision-table protection even when the new tables already exist.

44 tests pass, including these portable installer transformations and legacy/repeated migrations. The Windows batch execution, live PostgreSQL server, Flutter build and real devices remain unverified in this Linux environment.
