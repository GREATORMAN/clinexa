from datetime import date, datetime, timedelta, time
import random
from sqlalchemy import select, delete

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
from app.models.operations import PharmacyItem, InventoryBatch
from app.models.advanced import (
    EmergencyProfile,
    TrustedContact,
    MedicationSchedule,
    MedicationDoseLog,
    SymptomEntry,
    InsurancePolicy,
    LabOrder,
)
from app.models.catalog import MedicationCatalogItem
import app.models


def seed_rich_dataset():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        hospital = db.scalar(select(Hospital).where(Hospital.code == "CLINEXA"))
        if not hospital:
            hospital = Hospital(
                name="Clinexa Hospital",
                code="CLINEXA",
                address="75 Healthcare Avenue, Chennai, TN",
            )
            db.add(hospital)
            db.flush()

        # Ensure doctors
        doctors = db.scalars(select(Doctor).where(Doctor.hospital_id == hospital.id)).all()
        patients = db.scalars(select(Patient).where(Patient.hospital_id == hospital.id)).all()
        if not patients:
            print("No patients found. Run seed_demo.py first.")
            return

        doc_by_name = {d.full_name: d for d in doctors}
        default_doc = doctors[0] if doctors else None

        # Clean out old "Demo Medication" and "Demo Schedule" dummy entries
        db.query(PatientMedication).filter(PatientMedication.medication_name.like("Demo Medication%")).delete(synchronize_session=False)
        db.query(Prescription).filter(Prescription.medication_name.like("Demo Medication%")).delete(synchronize_session=False)
        db.query(MedicationSchedule).filter(MedicationSchedule.medication_name.like("Demo Schedule%")).delete(synchronize_session=False)
        db.query(LabResult).filter(LabResult.test_name.like("Demo %")).delete(synchronize_session=False)
        db.flush()

        # -------------------------------------------------------------
        # 1. REALISTIC MEDICATIONS PER PATIENT
        # -------------------------------------------------------------
        PATIENT_MED_PLANS = {
            "PT-DEMO101": [  # Aarav - Hypertension & Cardio
                {
                    "name": "Telmisartan",
                    "strength": "40 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Morning)",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take with water every morning after breakfast.",
                    "doctor": "Dr. Kiran Mehta",
                    "schedule_time": "08:00",
                    "status": "active",
                },
                {
                    "name": "Amlodipine",
                    "strength": "5 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Bedtime)",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take at night before sleeping.",
                    "doctor": "Dr. Kiran Mehta",
                    "schedule_time": "21:30",
                    "status": "active",
                },
                {
                    "name": "Rosuvastatin",
                    "strength": "10 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Night)",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take after dinner with water.",
                    "doctor": "Dr. Kiran Mehta",
                    "schedule_time": "21:00",
                    "status": "active",
                },
                {
                    "name": "Multivitamin + Zinc",
                    "strength": "Standard",
                    "form": "Tablet",
                    "frequency": "Once daily",
                    "route": "Oral",
                    "duration": "15 days",
                    "instructions": "Take 1 tablet daily after breakfast.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": "08:30",
                    "status": "active",
                },
            ],
            "PT-DEMO102": [  # Diya - Asthma & Allergy
                {
                    "name": "Budesonide Inhaler",
                    "strength": "200 mcg",
                    "form": "Inhaler",
                    "frequency": "2 puffs BID",
                    "route": "Inhaled",
                    "duration": "60 days",
                    "instructions": "Rinse mouth thoroughly with water after inhalation.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": "08:00,20:00",
                    "status": "active",
                },
                {
                    "name": "Montelukast",
                    "strength": "10 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Night)",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take 1 tablet at bedtime.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": "21:00",
                    "status": "active",
                },
                {
                    "name": "Levocetirizine",
                    "strength": "5 mg",
                    "form": "Tablet",
                    "frequency": "Once daily SOS",
                    "route": "Oral",
                    "duration": "15 days",
                    "instructions": "Take when experiencing allergic symptoms or sneezing.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": "22:00",
                    "status": "active",
                },
                {
                    "name": "Salbutamol Inhaler",
                    "strength": "100 mcg",
                    "form": "Inhaler",
                    "frequency": "SOS / As needed",
                    "route": "Inhaled",
                    "duration": "30 days",
                    "instructions": "Take 1-2 puffs during acute wheezing or breathlessness.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": None,
                    "status": "active",
                },
            ],
            "PT-DEMO103": [  # Kabir - Orthopedic & Pain
                {
                    "name": "Paracetamol",
                    "strength": "650 mg",
                    "form": "Tablet",
                    "frequency": "1 tablet TID",
                    "route": "Oral",
                    "duration": "5 days",
                    "instructions": "Take after meals for joint and muscle soreness.",
                    "doctor": "Dr. Rajesh Kumar",
                    "schedule_time": "09:00,14:00,20:00",
                    "status": "active",
                },
                {
                    "name": "Diclofenac Gel",
                    "strength": "1%",
                    "form": "Gel",
                    "frequency": "Apply BID",
                    "route": "Topical",
                    "duration": "7 days",
                    "instructions": "Gently massage over the painful joint twice a day.",
                    "doctor": "Dr. Rajesh Kumar",
                    "schedule_time": "09:00,21:00",
                    "status": "active",
                },
                {
                    "name": "Pantoprazole",
                    "strength": "40 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Morning)",
                    "route": "Oral",
                    "duration": "7 days",
                    "instructions": "Take 30 minutes before breakfast.",
                    "doctor": "Dr. Rajesh Kumar",
                    "schedule_time": "07:30",
                    "status": "active",
                },
                {
                    "name": "Calcium + Vitamin D3",
                    "strength": "500 mg / 400 IU",
                    "form": "Tablet",
                    "frequency": "Once daily",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take after lunch daily.",
                    "doctor": "Dr. Rajesh Kumar",
                    "schedule_time": "13:30",
                    "status": "active",
                },
            ],
            "PT-DEMO104": [  # Mira - Dermatology & Antibiotic
                {
                    "name": "Amoxicillin + Clavulanate",
                    "strength": "625 mg",
                    "form": "Tablet",
                    "frequency": "1 tablet BID",
                    "route": "Oral",
                    "duration": "7 days",
                    "instructions": "Complete the full 7-day antibiotic course with food.",
                    "doctor": "Dr. Sneha Patel",
                    "schedule_time": "09:00,21:00",
                    "status": "active",
                },
                {
                    "name": "Cetirizine",
                    "strength": "10 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Night)",
                    "route": "Oral",
                    "duration": "10 days",
                    "instructions": "Take before bedtime for skin rash relief.",
                    "doctor": "Dr. Sneha Patel",
                    "schedule_time": "21:30",
                    "status": "active",
                },
                {
                    "name": "Clotrimazole Cream",
                    "strength": "1%",
                    "form": "Cream",
                    "frequency": "Apply BID",
                    "route": "Topical",
                    "duration": "14 days",
                    "instructions": "Apply thin layer to affected skin twice daily.",
                    "doctor": "Dr. Sneha Patel",
                    "schedule_time": "08:30,20:30",
                    "status": "active",
                },
            ],
            "PT-DEMO105": [  # Rohan - Diabetes & Lipid Management
                {
                    "name": "Metformin",
                    "strength": "500 mg",
                    "form": "Tablet",
                    "frequency": "1 tablet BID",
                    "route": "Oral",
                    "duration": "60 days",
                    "instructions": "Take with breakfast and dinner.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": "08:30,20:30",
                    "status": "active",
                },
                {
                    "name": "Glimepiride",
                    "strength": "1 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Morning)",
                    "route": "Oral",
                    "duration": "60 days",
                    "instructions": "Take 15 minutes before breakfast.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": "08:00",
                    "status": "active",
                },
                {
                    "name": "Atorvastatin",
                    "strength": "20 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Night)",
                    "route": "Oral",
                    "duration": "60 days",
                    "instructions": "Take 1 tablet after dinner.",
                    "doctor": "Dr. Kiran Mehta",
                    "schedule_time": "21:30",
                    "status": "active",
                },
                {
                    "name": "Pantoprazole",
                    "strength": "40 mg",
                    "form": "Tablet",
                    "frequency": "Once daily",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take before breakfast.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": "07:30",
                    "status": "active",
                },
            ],
            "PT-DEMO106": [  # Sara - Acid Peptic & Nausea
                {
                    "name": "Esomeprazole",
                    "strength": "40 mg",
                    "form": "Capsule",
                    "frequency": "Once daily (Morning)",
                    "route": "Oral",
                    "duration": "14 days",
                    "instructions": "Take on empty stomach before breakfast.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": "07:30",
                    "status": "active",
                },
                {
                    "name": "Ondansetron",
                    "strength": "4 mg",
                    "form": "Tablet",
                    "frequency": "SOS for nausea",
                    "route": "Oral",
                    "duration": "5 days",
                    "instructions": "Take 1 tablet if experiencing acute nausea.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": None,
                    "status": "active",
                },
                {
                    "name": "Oral Rehydration Salts",
                    "strength": "Standard",
                    "form": "Sachet",
                    "frequency": "1 sachet in 1L water",
                    "route": "Oral",
                    "duration": "3 days",
                    "instructions": "Drink throughout the day to stay hydrated.",
                    "doctor": "Dr. Aanya Rao",
                    "schedule_time": "10:00",
                    "status": "active",
                },
            ],
            "PT-DEMO107": [  # Vikram - Cardiology & Heart Support
                {
                    "name": "Bisoprolol",
                    "strength": "5 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Morning)",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take every morning with water.",
                    "doctor": "Dr. Kiran Mehta",
                    "schedule_time": "08:00",
                    "status": "active",
                },
                {
                    "name": "Losartan",
                    "strength": "50 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Morning)",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take in morning after breakfast.",
                    "doctor": "Dr. Kiran Mehta",
                    "schedule_time": "08:30",
                    "status": "active",
                },
                {
                    "name": "Hydrochlorothiazide",
                    "strength": "12.5 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Morning)",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take in morning to prevent nighttime urination.",
                    "doctor": "Dr. Kiran Mehta",
                    "schedule_time": "09:00",
                    "status": "active",
                },
                {
                    "name": "Atorvastatin",
                    "strength": "10 mg",
                    "form": "Tablet",
                    "frequency": "Once daily (Night)",
                    "route": "Oral",
                    "duration": "30 days",
                    "instructions": "Take at bedtime.",
                    "doctor": "Dr. Kiran Mehta",
                    "schedule_time": "21:30",
                    "status": "active",
                },
            ],
            "PT-DEMO108": [  # Zoya - Pediatric Care
                {
                    "name": "Paracetamol Oral Suspension",
                    "strength": "250 mg/5 ml",
                    "form": "Suspension",
                    "frequency": "5 ml SOS for fever",
                    "route": "Oral",
                    "duration": "3 days",
                    "instructions": "Administer 5 ml if body temperature exceeds 100°F. Max 4 doses/day.",
                    "doctor": "Dr. Priya Nair",
                    "schedule_time": None,
                    "status": "active",
                },
                {
                    "name": "Cetirizine Syrup",
                    "strength": "5 mg/5 ml",
                    "form": "Syrup",
                    "frequency": "2.5 ml once daily (Night)",
                    "route": "Oral",
                    "duration": "5 days",
                    "instructions": "Give 2.5 ml at bedtime for allergic cough.",
                    "doctor": "Dr. Priya Nair",
                    "schedule_time": "20:00",
                    "status": "active",
                },
            ],
        }

        med_count = 0
        schedule_count = 0
        rx_count = 0

        for patient in patients:
            plan = PATIENT_MED_PLANS.get(patient.patient_code, [])
            for item in plan:
                doc = doc_by_name.get(item["doctor"], default_doc)

                # 1. Prescription
                rx = Prescription(
                    patient_id=patient.id,
                    doctor_id=doc.id if doc else None,
                    medication_name=item["name"],
                    strength=item["strength"],
                    form=item["form"],
                    frequency=item["frequency"],
                    duration=item["duration"],
                    instructions=item["instructions"],
                    status="active",
                    created_at=datetime.utcnow() - timedelta(days=random.randint(1, 10)),
                )
                db.add(rx)
                db.flush()
                rx_count += 1

                # 2. PatientMedication record
                pmed = PatientMedication(
                    patient_id=patient.id,
                    source_type="electronic_prescription",
                    source_id=rx.id,
                    medication_name=item["name"],
                    strength=item["strength"],
                    form=item["form"],
                    frequency=item["frequency"],
                    route=item["route"],
                    duration=item["duration"],
                    instructions=item["instructions"],
                    prescribing_doctor_text=doc.full_name if doc else "Dr. Aanya Rao",
                    start_date=date.today() - timedelta(days=random.randint(1, 7)),
                    status=item["status"],
                    verified=True,
                )
                db.add(pmed)
                db.flush()
                med_count += 1

                # 3. Schedule & Dose Logs
                if item["schedule_time"]:
                    sch = MedicationSchedule(
                        patient_id=patient.id,
                        prescription_id=rx.id,
                        medication_name=item["name"],
                        dose_label=f"{item['strength']} {item['form']}".strip(),
                        times_csv=item["schedule_time"],
                        start_date=date.today() - timedelta(days=7),
                        instructions=item["instructions"],
                        active=True,
                    )
                    db.add(sch)
                    db.flush()
                    schedule_count += 1

                    # Seed 2 realistic dose logs (taken today & taken yesterday)
                    for day_offset in [0, 1]:
                        db.add(
                            MedicationDoseLog(
                                schedule_id=sch.id,
                                scheduled_for=datetime.utcnow() - timedelta(days=day_offset, hours=2),
                                status="taken",
                                logged_at=datetime.utcnow() - timedelta(days=day_offset, hours=2),
                                note="Confirmed by patient",
                            )
                        )

        # -------------------------------------------------------------
        # 2. RICH LAB RESULTS (Standard clinical ranges & real test panels)
        # -------------------------------------------------------------
        LAB_PANELS = [
            # CBC
            ("Hemoglobin", "14.2", "g/dL", "13.0 - 17.0"),
            ("Total Leukocyte Count (WBC)", "6,800", "/mcL", "4,000 - 11,000"),
            ("Platelet Count", "245,000", "/mcL", "150,000 - 450,000"),
            ("Packed Cell Volume (PCV)", "42.5", "%", "38.0 - 50.0"),
            # Metabolic & Renal
            ("Fasting Blood Sugar", "96", "mg/dL", "70 - 100"),
            ("HbA1c (Glycated Hemoglobin)", "5.6", "%", "< 5.7"),
            ("Serum Creatinine", "0.92", "mg/dL", "0.70 - 1.20"),
            ("Blood Urea Nitrogen", "14", "mg/dL", "7 - 20"),
            # Lipid Profile
            ("Total Cholesterol", "178", "mg/dL", "< 200"),
            ("HDL Cholesterol", "52", "mg/dL", "> 40"),
            ("LDL Cholesterol", "104", "mg/dL", "< 100"),
            ("Serum Triglycerides", "125", "mg/dL", "< 150"),
            # Liver Profile
            ("SGPT / ALT", "26", "U/L", "< 45"),
            ("SGOT / AST", "22", "U/L", "< 40"),
            ("Serum Bilirubin Total", "0.8", "mg/dL", "0.2 - 1.2"),
            # Thyroid & Vitamins
            ("Serum TSH", "2.35", "uIU/mL", "0.40 - 4.20"),
            ("Vitamin D3 (25-OH)", "34.5", "ng/mL", "30 - 100"),
            ("Vitamin B12", "440", "pg/mL", "200 - 900"),
        ]

        lab_count = 0
        for patient in patients:
            # Pick 4-6 realistic tests per patient
            selected_tests = random.sample(LAB_PANELS, k=min(6, len(LAB_PANELS)))
            for test_name, val, unit, ref in selected_tests:
                db.add(
                    LabResult(
                        patient_id=patient.id,
                        test_name=test_name,
                        result_value=val,
                        unit=unit,
                        reference_range=ref,
                        laboratory="Clinexa Diagnostics Central",
                        verified=True,
                        collected_at=datetime.utcnow() - timedelta(days=random.randint(1, 14)),
                    )
                )
                lab_count += 1

        # -------------------------------------------------------------
        # 3. RICH PHARMACY INVENTORY ITEMS
        # -------------------------------------------------------------
        PHARMACY_STOCK = [
            ("Paracetamol", "Tablet", "500 mg", 150, 20),
            ("Paracetamol", "Tablet", "650 mg", 120, 25),
            ("Ibuprofen", "Tablet", "400 mg", 80, 15),
            ("Amoxicillin", "Capsule", "500 mg", 65, 10),
            ("Amoxicillin + Clavulanate", "Tablet", "625 mg", 95, 15),
            ("Azithromycin", "Tablet", "500 mg", 50, 10),
            ("Cefixime", "Tablet", "200 mg", 45, 10),
            ("Metformin", "Tablet", "500 mg", 200, 30),
            ("Glimepiride", "Tablet", "1 mg", 110, 20),
            ("Telmisartan", "Tablet", "40 mg", 140, 20),
            ("Amlodipine", "Tablet", "5 mg", 160, 25),
            ("Atorvastatin", "Tablet", "10 mg", 90, 15),
            ("Rosuvastatin", "Tablet", "10 mg", 85, 15),
            ("Pantoprazole", "Tablet", "40 mg", 180, 25),
            ("Omeprazole", "Capsule", "20 mg", 130, 20),
            ("Cetirizine", "Tablet", "10 mg", 175, 25),
            ("Levocetirizine", "Tablet", "5 mg", 110, 15),
            ("Montelukast", "Tablet", "10 mg", 70, 15),
            ("Budesonide Inhaler", "Inhaler", "200 mcg", 35, 8),
            ("Salbutamol Inhaler", "Inhaler", "100 mcg", 40, 10),
            ("Clotrimazole Cream", "Cream", "1%", 55, 10),
            ("Diclofenac Gel", "Gel", "1%", 60, 12),
            ("Oral Rehydration Salts", "Sachet", "Standard", 250, 40),
            ("Calcium + Vitamin D3", "Tablet", "500 mg", 130, 20),
            ("Iron + Folic Acid", "Tablet", "Standard", 100, 15),
            ("Ondansetron", "Tablet", "4 mg", 85, 15),
            ("Povidone Iodine Solution", "Liquid", "10%", 40, 8),
            ("Chlorhexidine Mouthwash", "Liquid", "0.2%", 45, 10),
            ("Lubricating Eye Drops", "Drops", "0.5%", 50, 10),
        ]

        pharmacy_count = 0
        for name, form, strength, qty, reorder in PHARMACY_STOCK:
            existing = db.scalar(
                select(PharmacyItem).where(
                    PharmacyItem.hospital_id == hospital.id,
                    PharmacyItem.name == name,
                    PharmacyItem.strength == strength,
                )
            )
            if not existing:
                item = PharmacyItem(
                    hospital_id=hospital.id,
                    name=name,
                    form=form,
                    strength=strength,
                    reorder_level=reorder,
                )
                db.add(item)
                db.flush()
                db.add(
                    InventoryBatch(
                        pharmacy_item_id=item.id,
                        batch_number=f"BAT-2026-{random.randint(100, 999)}",
                        quantity=qty,
                        expiry_date=date(2027, random.randint(1, 12), 28),
                    )
                )
                pharmacy_count += 1

        # -------------------------------------------------------------
        # 4. EMERGENCY PROFILES (Realistic data & organ donation flags)
        # -------------------------------------------------------------
        EMERGENCY_DATA = {
            "PT-DEMO101": ("O+", "Penicillin (Mild rash)", "Essential Hypertension", "Carries Telmisartan 40mg. Contact spouse in emergency.", True),
            "PT-DEMO102": ("A+", "Dust mite sensitivity", "Bronchial Asthma", "Requires Salbutamol inhaler for acute shortness of breath.", True),
            "PT-DEMO103": ("B+", "None documented", "Right knee ligament sprain", "Active sports rehabilitation.", False),
            "PT-DEMO104": ("AB+", "Sulfa drugs", "Mild atopic dermatitis", "Topical creams only.", True),
            "PT-DEMO105": ("O-", "None known", "Type 2 Diabetes Mellitus", "Monitor blood glucose if altered consciousness.", True),
            "PT-DEMO106": ("A-", "Aspirin (Gastric irritation)", "GERD / Acid reflux", "Avoid NSAIDs.", False),
            "PT-DEMO107": ("B-", "Codeine", "Hypertension & Coronary monitoring", "Cardiac patient under Dr. Kiran Mehta.", True),
            "PT-DEMO108": ("O+", "None documented", "Pediatric wellness", "Parental consent required for any urgent procedure.", False),
        }

        for patient in patients:
            data = EMERGENCY_DATA.get(patient.patient_code)
            if data:
                blood, allergies, cond, notes, organ = data
                profile = db.scalar(select(EmergencyProfile).where(EmergencyProfile.patient_id == patient.id))
                if profile:
                    profile.blood_group = blood
                    profile.allergies = allergies
                    profile.critical_conditions = cond
                    profile.emergency_notes = notes
                    profile.organ_donor = organ
                    profile.enabled = True
                else:
                    db.add(
                        EmergencyProfile(
                            patient_id=patient.id,
                            public_name=patient.full_name,
                            blood_group=blood,
                            allergies=allergies,
                            critical_conditions=cond,
                            emergency_notes=notes,
                            organ_donor=organ,
                            enabled=True,
                        )
                    )

        db.commit()
        print(f"==================================================")
        print(f"CLINEXA RICH DATA SEEDING COMPLETE")
        print(f"==================================================")
        print(f"- Verified Patient Medications added: {med_count}")
        print(f"- Electronic Prescriptions created: {rx_count}")
        print(f"- Medication Reminder Schedules created: {schedule_count}")
        print(f"- Diagnostic Lab Results populated: {lab_count}")
        print(f"- Pharmacy Inventory Items stocked: {pharmacy_count}")
        print(f"- Emergency Profiles updated with organ donor status.")
        print(f"==================================================")
    finally:
        db.close()


if __name__ == "__main__":
    seed_rich_dataset()
