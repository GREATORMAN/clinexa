# Requested upgrade coverage

**Tested backend** means automated API/database tests passed here. **Flutter source** means implemented and grammar-checked, with compilation/rendering/device verification still required. **Configuration** means files are supplied, not deployed services. V8 functionality is retained unless noted; rows marked pending have not been silently converted into mock buttons.

| Requested area | V9 result and remaining work |
|---|---|
| Teleconsultation | Existing session records retained. Real WebRTC/video/audio, waiting room, reconnect and call summaries remain pending. |
| Medication reminders | Flutter native scheduling/actions and secure dose retry queue added; idempotent dose backend tested. Seven-day/60-notification window. Device and iOS setup/testing remain. Automatic missed-dose derivation and continuous background refresh remain pending. |
| Push notifications | Existing inbox retained. FCM/APNs device push remains pending. Local medication notifications are separate. |
| Doctor notes | Tested drafts, autosave API, author ownership, final locking, reasoned amendments, version history and stale-write protection. Dedicated Flutter editor added; existing encounter editor remains separate. |
| Prescription history | Existing prescriptions retained. Signed/versioned amendments and previous-version viewer remain pending. |
| Lab OCR | Dedicated conservative text parser with per-field parsing confidence, unmatched lines and explicit verification added. Flutter side-by-side source/field editor and existing OCR-text endpoint added. Not a validated parser for arbitrary report formats. |
| Lab operations | Tested specimen collection/receipt/processing/verification/review/release workflow, accession QR and timeline added. Uses a new specimen workspace, separate from legacy LabOrder rows. No 1D barcode printer integration. |
| Appointments | V8 overlap protection retained. Leave/holiday/resource calendar, slot locking across distributed workers, waitlist, recurrence and complete timezone engine remain pending. |
| AI Copilot | Existing chat/record summary/confirmed booking proposal retained. General permission-aware multi-tool WRITE previews remain pending. |
| AI contextual UX | Existing Patient 360 AI summary retained. New contextual integrations across consultation/labs/scheduling remain pending. |
| NFC emergency | Existing token/profile/tag source retained. Real tag/device testing, pairing/offline emergency card remain pending. |
| Caregiver accounts | Tested patient-granted read-only appointments/reminders/emergency/selected-document scopes, hospital approval, patient revocation and API checks on every request. Flutter patient/caregiver screens added. Editing/booking/delegated dose actions remain pending. |
| Offline mode | Secure native token/profile storage and a medication-action retry queue added. General encrypted clinical cache, conflict resolution and offline sync remain pending. |
| Secure messaging | Tested participant-scoped two-person threads/read receipts plus staff contact endpoint. Flutter threaded UI/polling added. Attachments, groups, websocket delivery and E2E encryption remain pending. |
| Notification controls | Existing read/read-all inbox retained; medication reminders can be enabled/disabled. General category preferences, mute/deep links/deduplication remain pending. |
| Patient privacy | Tested sharing/revocation, portal-data JSON export and emergency scan-history APIs; Flutter UI added. Export excludes document bytes and some clinical entities. Complete consent enforcement and all-record access history remain pending. |
| MFA | Tested encrypted-secret TOTP enrollment, confirmation, disable and replay protection. Flutter enrollment/login source added. Passkeys, email OTP and recovery codes remain pending. |
| Password recovery | Tested hashed, expiring, single-use reset tokens, encrypted email job payload and session revocation. Flutter recovery screen added. Real email needs SMTP/worker configuration; verification email remains pending. |
| Device/session management | Tested device listing, naming API, individual/all revocation, server logout and access/refresh invalidation. Flutter session UI added. Suspicious-login detection remains pending. |
| Security rate limiting | Auth/MFA/reset per-process limits, security/no-store headers, guarded production settings and V8 upload validation. Distributed gateway limits, lockouts and full production security review remain pending. |
| Clinical record history | Append-only note/specimen revisions with author/time/reason; SQLite SQL triggers tested through migration setup. PostgreSQL trigger source included. Other clinical entities remain pending. |
| Discharge workflow | Existing admission/discharge preserved. Full discharge summaries, discharge medicines/follow-up/final billing remain pending. |
| Inpatient workflow | Existing ward/bed lifecycle preserved. Transfers, nursing observations/rounds/cleaning-task timelines remain pending. |
| Medication administration | Full nursing MAR remains pending. Patient reminder logging is not a MAR. |
| Pharmacy stock | Existing batches/dispensing retained. Supplier/PO/reorder/adjustment/transfer/return workflows remain pending. |
| Pharmacy workflow | Existing request/dispensing retained. Partial fill, verification notes and pickup handoff remain pending. |
| Billing | Existing invoices/payments retained. Itemized services/refunds/receipts/tax/insurance integration remain pending. |
| Insurance | Existing policy records retained; eligibility/claim lifecycle remains pending. |
| Staff management | Existing shifts retained; leave/rota/workload/duty assignment remain pending. |
| Referrals | Existing model retained; receiving-provider workflow/closure remains pending. |
| Vaccination | Pending. |
| Care plans | Existing plans and V8 patient tasks retained; full goals/progress/acknowledgement remain pending. |
| Vitals | Existing records retained; richer trends/device provenance remain pending. |
| Symptoms | Existing logging retained; new trend/history integration remains pending. |
| Documents | Existing upload/OCR/download retained; caregiver-selected private download added. Preview/version/secure-sharing lifecycle remain pending. |
| Global search | Existing search/command navigation retained; improved ranking/recent/keyboard search remain pending. |
| Analytics | Existing role dashboard retained; expanded interactive operational charts remain pending. |
| Audit centre | Tenant isolation fixed and tested; actor/action/resource/date filters, details and CSV-export Flutter source added. Actorless failures are excluded from hospital views; separate operator security reporting remains pending. |
| Dark mode | Shared surfaces, typography, fields, navigation and existing feature colors updated; persistent switch and dark default. Full visual/contrast audit remains unverified without Flutter rendering. |
| Accessibility | Responsive shared components, semantic dock/labels retained; reduced-motion control added. Enlarged-text light/dark widget checks included but not run here. Screen-reader/contrast audit remains pending. |
| Localization | Pending. |
| Background jobs | Encrypted password-reset email queue and bounded SMTP worker added. General reminder/OCR/export distributed worker, scheduling and stuck-job recovery remain pending. |
| WebSockets/realtime | Message polling added; websocket infrastructure remains pending. |
| Database migrations | Frozen Alembic V8 baseline/V9 upgrade, schema-adoption validation and preservation tests added. Future upgrades should use tracked migrations. |
| Production DB | PostgreSQL driver and Compose configuration; no hosted/live PostgreSQL verification. |
| File storage | Existing validated local private storage retained. Private cloud object storage/signed URLs remain pending. |
| Observability | Existing health and audit retained; no-store/HTTPS security headers added. Structured metrics/tracing/crash reporting remain pending. |
| CI/CD | Backend/Flutter analyze/test/web-build GitHub Actions source added. Pipeline has not run on GitHub; deployment automation remains pending. |
| Release Android | Debug build verification script and native reminder setup added. Release signing/icon/splash/store package setup remain pending. |
| Backup/restore | Source backup, SQLite online backup and native pre-edit copies included. Migration preserves a seeded record in tests. Automated PostgreSQL/file backups and full restore drill remain pending. |
| Cloud deployment | Container/PostgreSQL Compose/Firebase Hosting starter configs. Cloud Run/SQL/object storage/secured AI provisioning and actual deployment remain pending. |

## Verification record

44 backend tests passed on Python 3.12, FastAPI 0.142.2, SQLAlchemy 2.1.2 and Alembic 1.20.0. Python compilation passed. 43 Dart files parsed without grammar errors. Flutter compilation/rendering and hardware/cloud integration were not performed. Run the included verification script before replacing a working app build.
