from datetime import date, datetime, timedelta, time
from sqlalchemy import select

from app.core.database import Base, engine, SessionLocal
from app.models.organization import Hospital, Department
from app.models.clinical import (
    Patient,
    Doctor,
    DoctorAvailability,
    Appointment,
    Encounter,
    Vital,
)
from app.models.records import Prescription, LabResult
from app.models.medication import PatientMedication
from app.models.operations import PharmacyItem, InventoryBatch, Ward, Room, Bed, Invoice
from app.models.advanced import EmergencyProfile, TrustedContact, MedicationSchedule, SymptomEntry, InsurancePolicy, LabOrder, ConsentRecord
import app.models


def get_or_create_department(db, hospital_id: str, name: str) -> Department:
    row = db.scalar(
        select(Department).where(
            Department.hospital_id == hospital_id,
            Department.name == name,
        )
    )
    if row:
        return row
    row = Department(hospital_id=hospital_id, name=name)
    db.add(row)
    db.flush()
    return row


def get_or_create_doctor(db, hospital_id: str, department: Department, data: dict) -> Doctor:
    row = db.scalar(
        select(Doctor).where(
            Doctor.hospital_id == hospital_id,
            Doctor.full_name == data["full_name"],
        )
    )
    if not row:
        row = Doctor(
            hospital_id=hospital_id,
            department_id=department.id,
            full_name=data["full_name"],
            specialty=data["specialty"],
            qualifications=data["qualifications"],
            languages=data["languages"],
            biography=data["biography"],
            consultation_minutes=data.get("consultation_minutes", 20),
        )
        db.add(row)
        db.flush()

    if not db.scalar(select(DoctorAvailability).where(DoctorAvailability.doctor_id == row.id)):
        for weekday, start_time, end_time in data["availability"]:
            db.add(
                DoctorAvailability(
                    doctor_id=row.id,
                    weekday=weekday,
                    start_time=start_time,
                    end_time=end_time,
                    slot_minutes=data.get("consultation_minutes", 20),
                )
            )
    return row


def get_or_create_patient(db, hospital_id: str, data: dict) -> Patient:
    row = db.scalar(select(Patient).where(Patient.patient_code == data["patient_code"]))
    if row:
        return row
    row = Patient(hospital_id=hospital_id, **data)
    db.add(row)
    db.flush()
    return row


def ensure_vital(db, patient: Patient, values: dict) -> None:
    if db.scalar(select(Vital).where(Vital.patient_id == patient.id)):
        return
    db.add(Vital(patient_id=patient.id, source="fictional_demo", **values))


def ensure_encounter(db, hospital_id: str, patient: Patient, doctor: Doctor, complaint: str, assessment: str, plan: str) -> Encounter:
    row = db.scalar(
        select(Encounter).where(
            Encounter.patient_id == patient.id,
            Encounter.chief_complaint == complaint,
        )
    )
    if row:
        return row
    row = Encounter(
        hospital_id=hospital_id,
        patient_id=patient.id,
        doctor_id=doctor.id,
        chief_complaint=complaint,
        history="Fictional demo history for UI testing only.",
        examination="Fictional demo examination entry.",
        assessment=assessment,
        plan=plan,
        follow_up="Demo follow-up entry; not medical advice.",
    )
    db.add(row)
    db.flush()
    return row


def ensure_prescription(db, patient: Patient, doctor: Doctor, encounter: Encounter, data: dict) -> None:
    existing = db.scalar(
        select(Prescription).where(
            Prescription.patient_id == patient.id,
            Prescription.medication_name == data["medication_name"],
        )
    )
    if existing:
        if not db.scalar(select(PatientMedication).where(PatientMedication.source_type == "electronic_prescription", PatientMedication.source_id == existing.id)):
            db.add(PatientMedication(
                patient_id=patient.id,
                source_type="electronic_prescription",
                source_id=existing.id,
                medication_name=existing.medication_name,
                strength=existing.strength,
                form=existing.form,
                frequency=existing.frequency,
                duration=existing.duration,
                instructions=existing.instructions,
                prescribing_doctor_text=doctor.full_name,
                status="active",
                verified=True,
            ))
        return
    prescription = Prescription(
        patient_id=patient.id,
        doctor_id=doctor.id,
        encounter_id=encounter.id,
        status="demo",
        instructions="Fictional demo record only — not for real-world treatment.",
        **data,
    )
    db.add(prescription)
    db.flush()
    db.add(PatientMedication(
        patient_id=patient.id,
        source_type="electronic_prescription",
        source_id=prescription.id,
        medication_name=prescription.medication_name,
        strength=prescription.strength,
        form=prescription.form,
        frequency=prescription.frequency,
        duration=prescription.duration,
        instructions=prescription.instructions,
        prescribing_doctor_text=doctor.full_name,
        status="active",
        verified=True,
    ))


def ensure_lab(db, patient: Patient, data: dict) -> None:
    existing = db.scalar(
        select(LabResult).where(
            LabResult.patient_id == patient.id,
            LabResult.test_name == data["test_name"],
        )
    )
    if existing:
        return
    db.add(
        LabResult(
            patient_id=patient.id,
            laboratory="Clinexa Fictional Demo Lab",
            verified=True,
            collected_at=datetime.now() - timedelta(days=2),
            **data,
        )
    )


def ensure_appointment(db, hospital_id: str, patient: Patient, doctor: Doctor, when: datetime, status: str, reason: str, queue_token: str | None = None) -> None:
    existing = db.scalar(
        select(Appointment).where(
            Appointment.patient_id == patient.id,
            Appointment.doctor_id == doctor.id,
            Appointment.reason == reason,
        )
    )
    if existing:
        return
    db.add(
        Appointment(
            hospital_id=hospital_id,
            patient_id=patient.id,
            doctor_id=doctor.id,
            start_at=when,
            appointment_type="in_person",
            reason=reason,
            status=status,
            queue_token=queue_token,
        )
    )


def main():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        hospital = db.scalar(select(Hospital).where(Hospital.code == "CLINEXA"))
        if not hospital:
            hospital = Hospital(
                name="Clinexa Hospital",
                code="CLINEXA",
                address="Fictional development hospital",
            )
            db.add(hospital)
            db.flush()

        departments = {
            name: get_or_create_department(db, hospital.id, name)
            for name in [
                "General Medicine",
                "Cardiology",
                "Pediatrics",
                "Orthopedics",
                "Neurology",
                "Dermatology",
            ]
        }

        doctor_specs = [
            {
                "full_name": "Dr. Aanya Rao",
                "department": "General Medicine",
                "specialty": "Internal Medicine",
                "qualifications": "Fictional demo credential",
                "languages": "English, Tamil",
                "biography": "Fictional Clinexa clinician profile for development and UI testing.",
                "consultation_minutes": 20,
                "availability": [(0, "09:00", "13:00"), (2, "09:00", "13:00"), (4, "09:00", "13:00")],
            },
            {
                "full_name": "Dr. Kiran Mehta",
                "department": "Cardiology",
                "specialty": "Cardiology",
                "qualifications": "Fictional demo credential",
                "languages": "English, Hindi",
                "biography": "Fictional Clinexa clinician profile for development and UI testing.",
                "consultation_minutes": 30,
                "availability": [(1, "10:00", "14:00"), (3, "10:00", "14:00")],
            },
            {
                "full_name": "Dr. Meera Iyer",
                "department": "Pediatrics",
                "specialty": "Pediatrics",
                "qualifications": "Fictional demo credential",
                "languages": "English, Tamil",
                "biography": "Fictional Clinexa clinician profile for development and UI testing.",
                "consultation_minutes": 20,
                "availability": [(0, "14:00", "18:00"), (2, "14:00", "18:00"), (5, "09:00", "12:00")],
            },
            {
                "full_name": "Dr. Dev Malhotra",
                "department": "Orthopedics",
                "specialty": "Orthopedics",
                "qualifications": "Fictional demo credential",
                "languages": "English, Hindi",
                "biography": "Fictional Clinexa clinician profile for development and UI testing.",
                "consultation_minutes": 20,
                "availability": [(1, "09:00", "12:00"), (4, "14:00", "18:00")],
            },
            {
                "full_name": "Dr. Nila Sen",
                "department": "Neurology",
                "specialty": "Neurology",
                "qualifications": "Fictional demo credential",
                "languages": "English, Bengali, Hindi",
                "biography": "Fictional Clinexa clinician profile for development and UI testing.",
                "consultation_minutes": 30,
                "availability": [(2, "10:00", "15:00"), (5, "10:00", "13:00")],
            },
            {
                "full_name": "Dr. Arjun Nair",
                "department": "Dermatology",
                "specialty": "Dermatology",
                "qualifications": "Fictional demo credential",
                "languages": "English, Malayalam",
                "biography": "Fictional Clinexa clinician profile for development and UI testing.",
                "consultation_minutes": 20,
                "availability": [(0, "10:00", "14:00"), (3, "14:00", "18:00")],
            },
        ]

        doctors = []
        for spec in doctor_specs:
            doctors.append(
                get_or_create_doctor(
                    db,
                    hospital.id,
                    departments[spec["department"]],
                    spec,
                )
            )

        patient_specs = [
            {
                "patient_code": "PT-DEMO101",
                "full_name": "Aarav Demo",
                "date_of_birth": date(1992, 4, 18),
                "sex": "Male",
                "phone": "9000000101",
                "email": "aarav.demo@example.invalid",
                "address": "Fictional address — Chennai",
                "blood_group": "O+",
                "emergency_contact": "Demo Contact • 9000010101",
                "allergies": "Demo: no allergies recorded",
                "conditions": "Fictional demo record",
                "current_medications": "Demo medication record",
            },
            {
                "patient_code": "PT-DEMO102",
                "full_name": "Diya Demo",
                "date_of_birth": date(1988, 11, 3),
                "sex": "Female",
                "phone": "9000000102",
                "email": "diya.demo@example.invalid",
                "address": "Fictional address — Bengaluru",
                "blood_group": "A+",
                "emergency_contact": "Demo Contact • 9000010102",
                "allergies": "Demo: seasonal sensitivity entry",
                "conditions": "Fictional demo record",
                "current_medications": "Demo medication record",
            },
            {
                "patient_code": "PT-DEMO103",
                "full_name": "Kabir Demo",
                "date_of_birth": date(2001, 7, 22),
                "sex": "Male",
                "phone": "9000000103",
                "email": "kabir.demo@example.invalid",
                "address": "Fictional address — Chennai",
                "blood_group": "B+",
                "emergency_contact": "Demo Contact • 9000010103",
                "allergies": "Demo: none documented",
                "conditions": "Fictional demo record",
                "current_medications": "None in demo profile",
            },
            {
                "patient_code": "PT-DEMO104",
                "full_name": "Mira Demo",
                "date_of_birth": date(1997, 2, 14),
                "sex": "Female",
                "phone": "9000000104",
                "email": "mira.demo@example.invalid",
                "address": "Fictional address — Coimbatore",
                "blood_group": "AB+",
                "emergency_contact": "Demo Contact • 9000010104",
                "allergies": "Demo: fictional allergy entry",
                "conditions": "Fictional demo record",
                "current_medications": "Demo medication record",
            },
            {
                "patient_code": "PT-DEMO105",
                "full_name": "Rohan Demo",
                "date_of_birth": date(1979, 9, 9),
                "sex": "Male",
                "phone": "9000000105",
                "email": "rohan.demo@example.invalid",
                "address": "Fictional address — Chennai",
                "blood_group": "O-",
                "emergency_contact": "Demo Contact • 9000010105",
                "allergies": "Demo: none documented",
                "conditions": "Fictional demo record",
                "current_medications": "Demo medication record",
            },
            {
                "patient_code": "PT-DEMO106",
                "full_name": "Sara Demo",
                "date_of_birth": date(2005, 5, 30),
                "sex": "Female",
                "phone": "9000000106",
                "email": "sara.demo@example.invalid",
                "address": "Fictional address — Chennai",
                "blood_group": "A-",
                "emergency_contact": "Demo Contact • 9000010106",
                "allergies": "Demo: none documented",
                "conditions": "Fictional demo record",
                "current_medications": "None in demo profile",
            },
            {
                "patient_code": "PT-DEMO107",
                "full_name": "Vikram Demo",
                "date_of_birth": date(1968, 12, 6),
                "sex": "Male",
                "phone": "9000000107",
                "email": "vikram.demo@example.invalid",
                "address": "Fictional address — Bengaluru",
                "blood_group": "B-",
                "emergency_contact": "Demo Contact • 9000010107",
                "allergies": "Demo: fictional medication sensitivity",
                "conditions": "Fictional demo record",
                "current_medications": "Demo medication record",
            },
            {
                "patient_code": "PT-DEMO108",
                "full_name": "Zoya Demo",
                "date_of_birth": date(2012, 8, 19),
                "sex": "Female",
                "phone": "9000000108",
                "email": "zoya.demo@example.invalid",
                "address": "Fictional address — Chennai",
                "blood_group": "O+",
                "emergency_contact": "Demo Parent • 9000010108",
                "allergies": "Demo: none documented",
                "conditions": "Fictional demo record",
                "current_medications": "None in demo profile",
            },
        ]

        patients = [get_or_create_patient(db, hospital.id, spec) for spec in patient_specs]

        vitals = [
            dict(systolic=118, diastolic=76, heart_rate=72, temperature_c=36.7, spo2=99, weight_kg=72, height_cm=176),
            dict(systolic=124, diastolic=80, heart_rate=78, temperature_c=36.8, spo2=98, weight_kg=64, height_cm=165),
            dict(systolic=116, diastolic=74, heart_rate=70, temperature_c=36.6, spo2=99, weight_kg=69, height_cm=174),
            dict(systolic=110, diastolic=72, heart_rate=76, temperature_c=36.9, spo2=98, weight_kg=58, height_cm=162),
            dict(systolic=132, diastolic=84, heart_rate=74, temperature_c=36.7, spo2=97, weight_kg=81, height_cm=178),
            dict(systolic=112, diastolic=70, heart_rate=82, temperature_c=36.8, spo2=99, weight_kg=55, height_cm=160),
            dict(systolic=128, diastolic=82, heart_rate=71, temperature_c=36.6, spo2=98, weight_kg=77, height_cm=171),
            dict(systolic=108, diastolic=68, heart_rate=84, temperature_c=36.7, spo2=99, weight_kg=42, height_cm=148),
        ]

        for patient, values in zip(patients, vitals):
            ensure_vital(db, patient, values)

        encounter_specs = [
            (0, 0, "Routine wellness review (demo)", "Demo assessment: stable for UI testing", "Demo plan: routine follow-up"),
            (1, 1, "Cardiology review (demo)", "Demo assessment for cardiology workflow", "Demo plan: monitoring workflow"),
            (2, 3, "Musculoskeletal review (demo)", "Demo orthopedic assessment", "Demo plan: follow-up workflow"),
            (3, 5, "Skin review (demo)", "Demo dermatology assessment", "Demo plan: observation workflow"),
            (4, 1, "Cardiology follow-up (demo)", "Demo follow-up assessment", "Demo plan: continue monitoring"),
            (5, 0, "General consultation (demo)", "Demo general assessment", "Demo plan: routine follow-up"),
            (6, 4, "Neurology review (demo)", "Demo neurological assessment", "Demo plan: review workflow"),
            (7, 2, "Pediatric review (demo)", "Demo pediatric assessment", "Demo plan: routine follow-up"),
        ]

        encounters = []
        for patient_index, doctor_index, complaint, assessment, plan in encounter_specs:
            encounters.append(
                ensure_encounter(
                    db,
                    hospital.id,
                    patients[patient_index],
                    doctors[doctor_index],
                    complaint,
                    assessment,
                    plan,
                )
            )

        prescription_specs = [
            dict(medication_name="Demo Medication A", strength="Demo strength", form="Tablet", frequency="Demo schedule", duration="Demo duration"),
            dict(medication_name="Demo Medication B", strength="Demo strength", form="Tablet", frequency="Demo schedule", duration="Demo duration"),
            dict(medication_name="Demo Medication C", strength="Demo strength", form="Gel", frequency="Demo schedule", duration="Demo duration"),
            dict(medication_name="Demo Medication D", strength="Demo strength", form="Cream", frequency="Demo schedule", duration="Demo duration"),
            dict(medication_name="Demo Medication E", strength="Demo strength", form="Tablet", frequency="Demo schedule", duration="Demo duration"),
            dict(medication_name="Demo Medication F", strength="Demo strength", form="Tablet", frequency="Demo schedule", duration="Demo duration"),
            dict(medication_name="Demo Medication G", strength="Demo strength", form="Tablet", frequency="Demo schedule", duration="Demo duration"),
            dict(medication_name="Demo Medication H", strength="Demo strength", form="Syrup", frequency="Demo schedule", duration="Demo duration"),
        ]

        lab_specs = [
            dict(test_name="Demo CBC", result_value="Demo normal", unit="", reference_range="Demo reference"),
            dict(test_name="Demo Lipid Panel", result_value="Demo value", unit="", reference_range="Demo reference"),
            dict(test_name="Demo Vitamin Panel", result_value="Demo value", unit="", reference_range="Demo reference"),
            dict(test_name="Demo Skin Panel", result_value="Demo value", unit="", reference_range="Demo reference"),
            dict(test_name="Demo Metabolic Panel", result_value="Demo value", unit="", reference_range="Demo reference"),
            dict(test_name="Demo CBC", result_value="Demo normal", unit="", reference_range="Demo reference"),
            dict(test_name="Demo Neurology Panel", result_value="Demo value", unit="", reference_range="Demo reference"),
            dict(test_name="Demo Pediatric CBC", result_value="Demo normal", unit="", reference_range="Demo reference"),
        ]

        for i, patient in enumerate(patients):
            doctor = doctors[encounter_specs[i][1]]
            ensure_prescription(db, patient, doctor, encounters[i], prescription_specs[i])
            ensure_lab(db, patient, lab_specs[i])

        today = date.today()
        base = datetime.combine(today, time(9, 0))
        appointment_specs = [
            (0, 0, base + timedelta(minutes=20), "waiting", "Demo queue appointment A", "Q-A101"),
            (1, 1, base + timedelta(minutes=40), "checked_in", "Demo queue appointment B", "Q-B102"),
            (2, 3, base + timedelta(minutes=60), "in_consultation", "Demo queue appointment C", "Q-C103"),
            (3, 5, base + timedelta(hours=2), "confirmed", "Demo appointment D", None),
            (4, 1, base + timedelta(days=1, hours=1), "confirmed", "Demo follow-up E", None),
            (5, 0, base + timedelta(days=1, hours=2), "confirmed", "Demo follow-up F", None),
            (6, 4, base - timedelta(days=1), "completed", "Demo completed appointment G", None),
            (7, 2, base + timedelta(days=2, hours=1), "confirmed", "Demo pediatric appointment H", None),
        ]

        for p_idx, d_idx, when, status, reason, queue_token in appointment_specs:
            ensure_appointment(
                db,
                hospital.id,
                patients[p_idx],
                doctors[d_idx],
                when,
                status,
                reason,
                queue_token,
            )

        item = db.scalar(
            select(PharmacyItem).where(
                PharmacyItem.hospital_id == hospital.id,
                PharmacyItem.name == "Clinexa Demo Supply",
            )
        )
        if not item:
            item = PharmacyItem(hospital_id=hospital.id, name="Clinexa Demo Supply", reorder_level=10)
            db.add(item)
            db.flush()
            db.add(InventoryBatch(pharmacy_item_id=item.id, batch_number="DEMO-BATCH-01", quantity=25))

        ward = db.scalar(
            select(Ward).where(
                Ward.hospital_id == hospital.id,
                Ward.name == "Demo General Ward",
            )
        )
        if not ward:
            ward = Ward(hospital_id=hospital.id, name="Demo General Ward")
            db.add(ward)
            db.flush()
            room = Room(ward_id=ward.id, name="D101")
            db.add(room)
            db.flush()
            db.add_all([Bed(room_id=room.id, label="D101-A"), Bed(room_id=room.id, label="D101-B")])

        for idx, patient in enumerate(patients[:4]):
            description = f"Fictional demo invoice {idx + 1}"
            invoice = db.scalar(
                select(Invoice).where(
                    Invoice.patient_id == patient.id,
                    Invoice.description == description,
                )
            )
            if not invoice:
                db.add(
                    Invoice(
                        hospital_id=hospital.id,
                        patient_id=patient.id,
                        description=description,
                        total_amount=500 + (idx * 250),
                        status="paid" if idx < 2 else "unpaid",
                    )
                )

        # Advanced V4 demo data: fictional only.
        for idx, patient in enumerate(patients[:4]):
            if not db.scalar(select(EmergencyProfile).where(EmergencyProfile.patient_id == patient.id)):
                db.add(EmergencyProfile(
                    patient_id=patient.id,
                    public_name=patient.full_name,
                    blood_group=patient.blood_group,
                    allergies=patient.allergies,
                    critical_conditions="Fictional demo emergency note",
                    emergency_notes="Demo profile for NFC/QR workflow testing only.",
                    enabled=True,
                ))
            if not db.scalar(select(TrustedContact).where(TrustedContact.patient_id == patient.id)):
                db.add(TrustedContact(patient_id=patient.id, name=f"Demo Contact {idx+1}", relation="Family", phone=f"90000900{idx+1:02d}", priority=1))
            if not db.scalar(select(MedicationSchedule).where(MedicationSchedule.patient_id == patient.id)):
                db.add(MedicationSchedule(patient_id=patient.id, medication_name=f"Demo Schedule {idx+1}", dose_label="Demo dose", times_csv="09:00,21:00", instructions="Fictional schedule only", active=True))
            if not db.scalar(select(SymptomEntry).where(SymptomEntry.patient_id == patient.id)):
                db.add(SymptomEntry(patient_id=patient.id, symptom="Demo symptom log", severity=(idx % 4) + 1, note="Fictional symptom entry"))
            if not db.scalar(select(InsurancePolicy).where(InsurancePolicy.patient_id == patient.id)):
                db.add(InsurancePolicy(patient_id=patient.id, provider="Clinexa Demo Insurance", policy_number=f"DEMO-POL-{idx+1:04d}", plan_name="Demo Plan", status="active"))
            if not db.scalar(select(ConsentRecord).where(ConsentRecord.patient_id == patient.id, ConsentRecord.consent_type == "teleconsultation")):
                db.add(ConsentRecord(patient_id=patient.id, consent_type="teleconsultation", granted=True, note="Fictional demo consent"))
            if not db.scalar(select(LabOrder).where(LabOrder.patient_id == patient.id, LabOrder.test_name == "Demo Advanced Panel")):
                db.add(LabOrder(hospital_id=hospital.id, patient_id=patient.id, doctor_id=doctors[idx % len(doctors)].id, test_name="Demo Advanced Panel", priority="routine", status="ordered", specimen="Demo specimen"))

        db.commit()
        print("Clinexa fictional demo data seeded successfully.")
        print(f"Doctors available: {len(doctors)}")
        print(f"Patients available: {len(patients)}")
        print("Sample encounters, vitals, prescriptions, labs, appointments, queue entries and invoices are ready.")
        print("All seeded clinical content is fictional and for development/demo use only.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
