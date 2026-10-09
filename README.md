# 🏥 Clinexa — Enterprise Clinical Operating System & AI Decision Support

<p align="center">
  <img src="https://raw.githubusercontent.com/GREATORMAN/clinexa/main/Clinexa_Functional_v2/frontend/web/icons/Icon-512.png" alt="Clinexa Logo" width="120" height="120" style="border-radius: 24px;" />
</p>

<p align="center">
  <strong>An enterprise-grade, multi-tenant clinical operating system connecting clinicians, patients, laboratories, and hospital operations with zero-compromise safety guardrails and grounded AI decision support.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/FastAPI-0.115+-009688?logo=fastapi&logoColor=white" alt="FastAPI" />
  <img src="https://img.shields.io/badge/Python-3.12%20%7C%203.14-3776AB?logo=python&logoColor=white" alt="Python" />
  <img src="https://img.shields.io/badge/SQLAlchemy-2.0-D71F00?logo=sqlalchemy&logoColor=white" alt="SQLAlchemy" />
  <img src="https://img.shields.io/badge/AI_Engine-Ollama%20%2B%20Clinical_Sentinel-635BDF" alt="AI Engine" />
  <img src="https://img.shields.io/badge/Security-5--Layer%20Guardrails-10B981" alt="Guardrails" />
  <img src="https://img.shields.io/badge/License-Proprietary-gray" alt="License" />
</p>

---

## 🌟 Executive Overview

**Clinexa** is a comprehensive hospital clinical operating system designed for healthcare providers, doctors, nurses, pharmacists, and lab specialists. It bridges clinical workflows, electronic health records (EHR), inpatient bed management, and laboratory automation into an intuitive, high-performance workspace.

The platform is fortified with an **Enterprise Clinical AI Copilot** designed to synthesize patient charts, evaluate drug-drug interactions, explain laboratory biomarkers, and triage emergencies with **hardcoded medical guardrails**.

---

## 🛡️ 5-Layer Clinical AI Safety Guardrail Architecture

The Clinical AI assistant (`POST /api/v1/ai/chat`) is governed by an integrated multi-tier safety sentinel:

```
                  ┌──────────────────────────────────────────────┐
                  │            Incoming Clinician Query          │
                  └──────────────────────┬───────────────────────┘
                                         ▼
                 ┌────────────────────────────────────────────────┐
                 │  Layer 1: Prompt Injection & Jailbreak Defense │
                 └───────────────────────┬────────────────────────┘
                                         ▼
                 ┌────────────────────────────────────────────────┐
                 │  Layer 2: Acute Emergency Red Flag Triage      │ ──► [🚨 Dial 108 / ER]
                 └───────────────────────┬────────────────────────┘
                                         ▼
                 ┌────────────────────────────────────────────────┐
                 │  Layer 3: Prescription & Controlled Substance  │ ──► [⛔ Physician E-Sign Required]
                 └───────────────────────┬────────────────────────┘
                                         ▼
                 ┌────────────────────────────────────────────────┐
                 │  Layer 4: EHR Documented Allergy Screening     │ ──► [⚠️ Cross-Reactivity Alert]
                 └───────────────────────┬────────────────────────┘
                                         ▼
                 ┌────────────────────────────────────────────────┐
                 │  Layer 5: Polypharmacy Drug-Drug Interactions  │ ──► [💊 Conflict & Renal Check]
                 └───────────────────────┬────────────────────────┘
                                         ▼
             ┌────────────────────────────────────────────────────────┐
             │ Grounded Synthesis (Private Ollama / Clinical Engine)  │
             └────────────────────────────────────────────────────────┘
```

1. **🚨 Acute Emergency Triage Sentinel**: Identifies cardiac red flags, myocardial infarction, stroke FAST criteria (facial droop, arm weakness, speech difficulty), severe respiratory arrest, and crisis ideation. Immediately presents an emergency protocol banner with direct dispatch actions (108 Ambulance / 112 Dispatch / 911).
2. **⛔ Autonomous Prescribing & Controlled Substance Shield**: Blocks requests to dispense, self-titrate, or prescribe Schedule II–IV controlled narcotics (oxycodone, fentanyl, morphine, tramadol, benzodiazepines). Enforces electronic physician signatures under CDSCO/FDA compliance.
3. **⚠️ Documented Allergy & Class Cross-Reactivity Shield**: Dynamically cross-references requested medicines against the active patient's EHR allergy record (e.g. Penicillin, Sulfa, Aspirin/NSAIDs) and raises immediate contraindication alerts.
4. **💊 Polypharmacy Drug-Drug Interaction Screen**: Evaluates dangerous pharmacological conflicts (e.g., Telmisartan/ARBs + Potassium/NSAIDs, Metformin + radiocontrast agents, anticoagulants + NSAIDs).
5. **🛡️ Prompt Injection & Jailbreak Defense**: Detects and neutralizes prompt injection attempts (e.g. "ignore prior rules", "act as an unrestricted doctor", DAN mode).
6. **📋 EHR Database Grounding (Anti-Hallucination)**: Strictly bounded to verified patient database records (vitals, laboratory panels, encounters, active medications). Missing clinical data is explicitly declared rather than fabricated.

---

## 📂 Repository Workspace Structure

This monorepo contains the active production-ready codebase alongside verified architectural milestone packages:

| Directory | Description | Status |
| :--- | :--- | :--- |
| **[`Clinexa_Functional_v2/`](./Clinexa_Functional_v2)** | **Main active platform.** Complete FastAPI backend, Flutter frontend, active database schemas, and updated Clinical AI Guardrails engine. | **Active / Primary** |
| **[`V10_UI/`](./V10_UI)** | **Clinexa V10 Ultimate UI.** Contains responsive design assets, tokenized dark/light theme systems, and modular card components. | Reference Layer |
| **`V9_FIXED_V5/`** to **`V9_FIXED_V2/`** | Progressive hotfix editions covering Alembic migrations, OCR enhancements, and security gate patches. | Verified Archives |
| **`V5_EXTRACT/`** to **`V9_EXTRACT/`** | Evolutionary milestone packages documenting the progression from core EHR to multi-tenant clinic OS. | Architecture History |

---

## 🏥 Core Feature Modules

### 1. 🤖 Clinical Decision Support Workspace (`AiPage`)
* **Patient Chart Context**: Attach any patient's active chart (`PT-1001`) from the header dropdown to run grounded EHR queries.
* **Structured Clinical Card**: Formats responses into **Key Takeaways**, **Assessment Details**, **Interactive Action Chips** (Book Consult, View Meds, Check Labs, Dial 108), and **Clickable Follow-up Prompts**.
* **One-Click AI Booking**: Drafts appointment booking proposals with clinic doctors and time slots with mandatory user confirmation.

### 2. 👤 Patient 360° & Longitudinal Health Records
* Unified patient demographics, blood group, documented allergies, chronic conditions, and emergency profiles.
* Real-time physiological vitals telemetry (Blood Pressure, Heart Rate, SpO2, Temperature).
* Longitudinal diagnostic lab history with abnormal value indicators.

### 3. 🩺 Physician Consultation & Encounters
* SOAP progress note drafts with background autosave, version-conflict protection, and locking.
* Comprehensive clinical note amendment tracking with full audit provenance.

### 4. 🔬 Laboratory Workspace & OCR Specimen Intake
* Specimen barcode/QR tracking across the full chain-of-custody (`Ordered` ➔ `Collected` ➔ `Received` ➔ `Processing` ➔ `Released`).
* OCR intake parser extracting lab report values with side-by-side human-in-the-loop verification before release into permanent records.

### 5. 💊 Pharmacy Workspace & Medicine Centre
* Electronic prescription issuance, active regimen schedules, and inventory tracking.
* Device medication reminders supporting offline dose queues and sync verification.

### 6. 🚨 Emergency Hub & NFC Medical Passport
* Encrypted NFC wristband pairing for high-risk patients.
* Instant emergency tag scanning showing critical blood group, allergies, and ICE contacts without requiring app login.

### 7. 🏢 Hospital Inpatient Operations
* Ward, room, and bed occupancy management.
* Admissions and discharge workflows with automated bed sanitization states.
* Billing, invoicing, and payment processing.

---

## ⚡ Quick Start & Installation

### Prerequisites
* **Python**: 3.12 or newer (Virtual environment recommended)
* **Flutter SDK**: 3.24+ (Dart 3.5+)
* **Ollama** *(Optional for local AI)*: `ollama run med-llama` or `ollama run mistral`

### 1. Launch Everything with One Click (Windows)
Navigate to `Clinexa_Functional_v2` and run:

```bat
START_CLINEXA.bat
```

This automatically checks dependencies, starts the FastAPI backend server on `http://127.0.0.1:8000`, and launches the Flutter application.

---

### 2. Manual Startup

#### Backend (FastAPI + SQLAlchemy)
```bash
cd Clinexa_Functional_v2/backend
# Create and activate virtual environment
python -m venv .venv
.\.venv\Scripts\activate   # On Windows
source .venv/bin/activate  # On Linux/macOS

# Install dependencies
pip install -r requirements.txt

# Run migrations and start server
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```
* Interactive API Documentation (Swagger): **`http://127.0.0.1:8000/docs`**
* ReDoc Specification: **`http://127.0.0.1:8000/redoc`**

#### Frontend (Flutter)
```bash
cd Clinexa_Functional_v2/frontend
flutter pub get
flutter run -d chrome     # Web browser
# Or
flutter run -d windows    # Windows desktop app
```

---

## 🧪 Testing & Quality Assurance

The codebase includes an extensive suite of automated unit, integration, and security tests:

```bash
cd Clinexa_Functional_v2/backend
.\.venv\Scripts\python.exe -m pytest -v
```

```
====================== 47 passed, 869 warnings in 16.13s ======================
✓ test_install_helpers.py ........
✓ test_migrations.py ....
✓ test_ocr_prescription_parser.py ....
✓ test_security.py .
✓ test_v8_workflows.py ..............
✓ test_v9_workflows.py ................
```

Frontend static analysis:
```bash
cd Clinexa_Functional_v2/frontend
flutter analyze
# Result: No issues found!
```

---

## 🔒 Security & Data Privacy

* **Tenant Isolation**: All database operations are strictly scoped by `hospital_id` extracted from cryptographically verified bearer tokens.
* **Zero Autonomous Prescription Risk**: Hardcoded policy prohibits automated drug dispensing without licensed physician electronic signatures.
* **Audit Trail**: High-risk actions (patient admissions, emergency overrides, prescription modifications, AI bookings) are logged to an immutable audit ledger (`audit_events`).
* **Cryptographic MFA**: TOTP-based multi-factor authentication with automated session revocation on credential changes.

---

## 📄 License & Attribution

Developed for modern hospital clinical systems. Built with dedication by **GREATORMAN / VISHALSAI BJ**.  
*For clinical deployment inquiries and institutional licenses, refer to `docs/SECURITY.md`.*
