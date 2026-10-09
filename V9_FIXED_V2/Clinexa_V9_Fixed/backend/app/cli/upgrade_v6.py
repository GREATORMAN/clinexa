from sqlalchemy import select

from app.core.database import Base, engine, SessionLocal
from app.models.organization import Hospital
from app.models.catalog import MedicationCatalogItem
import app.models  # noqa: F401

CATALOG = [
    ("Paracetamol", "Paracetamol", "Pain & fever", "Common generic pain/fever medicine. Fulfillment in Clinexa is linked to a verified patient medication record.", "tablet", "500 mg", "tablet", False),
    ("Ibuprofen", "Ibuprofen", "Pain & inflammation", "Common anti-inflammatory medicine. Clinexa does not recommend it; pharmacy requests require a verified medication record.", "tablet", "400 mg", "tablet", True),
    ("Cetirizine", "Cetirizine", "Allergy", "Common antihistamine medicine listed for formulary matching and pharmacy workflow.", "tablet", "10 mg", "tablet", False),
    ("Loratadine", "Loratadine", "Allergy", "Common antihistamine medicine listed for formulary matching and pharmacy workflow.", "tablet", "10 mg", "tablet", False),
    ("Omeprazole", "Omeprazole", "Gastrointestinal", "Acid-suppression medicine listed in the local formulary for record matching.", "capsule", "20 mg", "capsule", True),
    ("Pantoprazole", "Pantoprazole", "Gastrointestinal", "Acid-suppression medicine listed in the local formulary for record matching.", "tablet", "40 mg", "tablet", True),
    ("Ondansetron", "Ondansetron", "Nausea", "Antiemetic medicine listed for clinician/pharmacy workflow and OCR matching.", "tablet", "4 mg", "tablet", True),
    ("Amoxicillin", "Amoxicillin", "Antibiotic", "Antibiotic formulary item. Pharmacy request requires an active verified medication record.", "capsule", "500 mg", "capsule", True),
    ("Azithromycin", "Azithromycin", "Antibiotic", "Antibiotic formulary item. Pharmacy request requires an active verified medication record.", "tablet", "500 mg", "tablet", True),
    ("Cefixime", "Cefixime", "Antibiotic", "Antibiotic formulary item. Pharmacy request requires an active verified medication record.", "tablet", "200 mg", "tablet", True),
    ("Doxycycline", "Doxycycline", "Antibiotic", "Antibiotic formulary item. Pharmacy request requires an active verified medication record.", "capsule", "100 mg", "capsule", True),
    ("Metformin", "Metformin", "Metabolic", "Common long-term medicine listed for verified medication matching.", "tablet", "500 mg", "tablet", True),
    ("Amlodipine", "Amlodipine", "Cardiovascular", "Common cardiovascular medicine listed for verified medication matching.", "tablet", "5 mg", "tablet", True),
    ("Losartan", "Losartan", "Cardiovascular", "Common cardiovascular medicine listed for verified medication matching.", "tablet", "50 mg", "tablet", True),
    ("Atorvastatin", "Atorvastatin", "Cardiovascular", "Lipid-lowering medicine listed for verified medication matching.", "tablet", "10 mg", "tablet", True),
    ("Salbutamol", "Salbutamol inhaler", "Respiratory", "Bronchodilator inhaler listed for verified medication matching and pharmacy workflow.", "inhaler", "100 mcg", "inhaler", True),
    ("Budesonide", "Budesonide inhaler", "Respiratory", "Inhaled medicine listed for verified medication matching and pharmacy workflow.", "inhaler", "200 mcg", "inhaler", True),
    ("Clotrimazole", "Clotrimazole cream", "Dermatology", "Topical antifungal formulary item for record matching.", "cream", "1%", "cream", False),
    ("Diclofenac", "Diclofenac gel", "Pain & inflammation", "Topical anti-inflammatory formulary item for record matching.", "gel", "1%", "cream", False),
    ("Oral rehydration salts", "Oral rehydration salts", "Hydration", "Oral rehydration product listed in the hospital formulary.", "sachet", None, "sachet", False),
    ("Iron folic acid", "Iron + folic acid", "Supplements", "Hospital formulary supplement item; use only according to an existing care plan or medication record.", "tablet", None, "tablet", False),
    ("Calcium vitamin D3", "Calcium + vitamin D3", "Supplements", "Hospital formulary supplement item; use only according to an existing care plan or medication record.", "tablet", None, "tablet", False),
    ("Levothyroxine", "Levothyroxine", "Endocrine", "Thyroid medicine listed for verified medication matching.", "tablet", "50 mcg", "tablet", True),
    ("Montelukast", "Montelukast", "Respiratory & allergy", "Medicine listed for verified medication matching and pharmacy workflow.", "tablet", "10 mg", "tablet", True),
    ("Levocetirizine", "Levocetirizine", "Allergy", "Local formulary entry used for OCR matching and verified fulfillment.", "tablet", "5 mg", "tablet", False),
    ("Fexofenadine", "Fexofenadine", "Allergy", "Local formulary entry used for OCR matching and verified fulfillment.", "tablet", "120 mg", "tablet", False),
    ("Esomeprazole", "Esomeprazole", "Gastrointestinal", "Local formulary entry used for record matching and verified pharmacy workflow.", "capsule", "40 mg", "capsule", True),
    ("Famotidine", "Famotidine", "Gastrointestinal", "Local formulary entry used for record matching and verified pharmacy workflow.", "tablet", "20 mg", "tablet", True),
    ("Loperamide", "Loperamide", "Gastrointestinal", "Local formulary entry used for record matching. Clinexa does not recommend or create a treatment plan.", "capsule", "2 mg", "capsule", False),
    ("Metronidazole", "Metronidazole", "Antimicrobial", "Antimicrobial formulary item. Fulfillment requires an active verified medicine record.", "tablet", "400 mg", "tablet", True),
    ("Amoxicillin clavulanate", "Amoxicillin + clavulanate", "Antibiotic", "Antibiotic formulary item for OCR matching and verified pharmacy workflow.", "tablet", "625 mg", "tablet", True),
    ("Cefuroxime", "Cefuroxime", "Antibiotic", "Antibiotic formulary item for OCR matching and verified pharmacy workflow.", "tablet", "500 mg", "tablet", True),
    ("Ciprofloxacin", "Ciprofloxacin", "Antibiotic", "Antibiotic formulary item for OCR matching and verified pharmacy workflow.", "tablet", "500 mg", "tablet", True),
    ("Fluconazole", "Fluconazole", "Antifungal", "Antifungal formulary item used for record matching and verified pharmacy workflow.", "capsule", "150 mg", "capsule", True),
    ("Mupirocin", "Mupirocin ointment", "Dermatology", "Topical formulary item used for record matching and verified fulfillment.", "ointment", "2%", "cream", True),
    ("Ketoconazole", "Ketoconazole cream", "Dermatology", "Topical formulary item used for record matching and verified fulfillment.", "cream", "2%", "cream", True),
    ("Adapalene", "Adapalene gel", "Dermatology", "Topical formulary item used for record matching and verified fulfillment.", "gel", "0.1%", "gel", True),
    ("Telmisartan", "Telmisartan", "Cardiovascular", "Cardiovascular formulary item used for verified medication matching.", "tablet", "40 mg", "tablet", True),
    ("Bisoprolol", "Bisoprolol", "Cardiovascular", "Cardiovascular formulary item used for verified medication matching.", "tablet", "5 mg", "tablet", True),
    ("Hydrochlorothiazide", "Hydrochlorothiazide", "Cardiovascular", "Cardiovascular formulary item used for verified medication matching.", "tablet", "12.5 mg", "tablet", True),
    ("Rosuvastatin", "Rosuvastatin", "Cardiovascular", "Lipid-management formulary item used for verified medication matching.", "tablet", "10 mg", "tablet", True),
    ("Sitagliptin", "Sitagliptin", "Metabolic", "Metabolic formulary item used for verified medication matching and pharmacy workflow.", "tablet", "100 mg", "tablet", True),
    ("Glimepiride", "Glimepiride", "Metabolic", "Metabolic formulary item used for verified medication matching and pharmacy workflow.", "tablet", "1 mg", "tablet", True),
    ("Fluticasone", "Fluticasone inhaler", "Respiratory", "Respiratory formulary item used for verified medication matching and pharmacy workflow.", "inhaler", "125 mcg", "inhaler", True),
    ("Ipratropium", "Ipratropium inhaler", "Respiratory", "Respiratory formulary item used for verified medication matching and pharmacy workflow.", "inhaler", "20 mcg", "inhaler", True),
    ("Acetylcysteine", "Acetylcysteine", "Respiratory", "Local formulary item used for record matching and verified fulfillment.", "sachet", "600 mg", "sachet", True),
    ("Artificial tears", "Lubricating eye drops", "Eye care", "Eye-care formulary entry used for record matching and verified fulfillment.", "drops", None, "drops", False),
    ("Olopatadine", "Olopatadine eye drops", "Eye care", "Eye-care formulary entry used for record matching and verified fulfillment.", "drops", "0.1%", "drops", True),
    ("Chlorhexidine", "Chlorhexidine mouthwash", "Oral care", "Oral-care formulary entry used for record matching and verified fulfillment.", "liquid", "0.2%", "liquid", False),
    ("Folic acid", "Folic acid", "Supplements", "Hospital formulary supplement entry; fulfillment remains linked to an existing verified record.", "tablet", "5 mg", "tablet", False),
    ("Cyanocobalamin", "Vitamin B12", "Supplements", "Hospital formulary supplement entry; fulfillment remains linked to an existing verified record.", "tablet", "500 mcg", "tablet", False),
    ("Zinc sulfate", "Zinc", "Supplements", "Hospital formulary supplement entry; Clinexa does not create dosing instructions.", "tablet", "20 mg", "tablet", False),
    ("Magnesium", "Magnesium", "Supplements", "Hospital formulary supplement entry; Clinexa does not create dosing instructions.", "tablet", None, "tablet", False),
    ("Lactulose", "Lactulose solution", "Gastrointestinal", "Local formulary entry used for record matching and verified fulfillment.", "syrup", None, "liquid", True),
    ("Antacid suspension", "Antacid suspension", "Gastrointestinal", "Local formulary entry used for record matching and verified fulfillment.", "suspension", None, "liquid", False),
    ("Povidone iodine", "Povidone iodine solution", "First aid", "Topical hospital formulary entry used for record matching and verified fulfillment.", "solution", "10%", "liquid", False),
    ("Paracetamol", "Paracetamol oral suspension", "Pain & fever", "Pediatric-form formulary entry used only for matching to an existing verified medication record.", "suspension", "250 mg/5 ml", "liquid", True),
    ("Amoxicillin", "Amoxicillin oral suspension", "Antibiotic", "Pediatric-form antibiotic formulary entry. Fulfillment requires an active verified medication record.", "suspension", "250 mg/5 ml", "liquid", True),
]


def main() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        hospitals = db.scalars(select(Hospital)).all()
        created = 0
        for hospital in hospitals:
            for generic_name, display_name, category, description, form, strength, image_key, rx_required in CATALOG:
                existing = db.scalar(select(MedicationCatalogItem).where(
                    MedicationCatalogItem.hospital_id == hospital.id,
                    MedicationCatalogItem.generic_name == generic_name,
                    MedicationCatalogItem.strength == strength,
                    MedicationCatalogItem.form == form,
                ))
                if existing:
                    continue
                db.add(MedicationCatalogItem(
                    hospital_id=hospital.id,
                    generic_name=generic_name,
                    display_name=display_name,
                    category=category,
                    description=description,
                    form=form,
                    strength=strength,
                    image_key=image_key,
                    prescription_required=rx_required,
                    active=True,
                ))
                created += 1
        db.commit()
        print("Clinexa V6 experience upgrade complete.")
        print(f"Medication catalog items created: {created}")
        print("Pharmacy request workflow tables are ready.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
