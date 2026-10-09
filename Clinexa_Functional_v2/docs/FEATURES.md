# Clinexa feature map

## Working application modules

Authentication, RBAC, patient registry, doctor directory, appointments, queue states,
clinical encounters, vitals, prescriptions, labs, documents, OCR review, local Ollama,
messaging, referrals, care plans, pharmacy stock, billing, admissions/beds, audit and
admin dashboard metrics are represented by real database entities and API workflows.

## External integrations kept modular

SMS, email delivery, push notification infrastructure, payment-provider settlement,
insurance APIs, teleconsultation video providers and hospital hardware integrations are
left behind adapters/interfaces rather than being represented by fake success buttons.
