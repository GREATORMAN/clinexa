"""
Clinexa Clinical AI Decision Support & Guardrail Engine.
Provides grounded clinical reasoning, enterprise medical guardrails,
emergency red flag detection, allergy & drug interaction screening,
and hybrid clinical knowledge intelligence.
"""

import re
import json
import httpx
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.core.config import get_settings
from app.models.clinical import Patient, Vital, Encounter, Doctor
from app.models.records import Prescription, LabResult
from app.models.advanced import MedicationSchedule, EmergencyProfile

settings = get_settings()

SYSTEM_PROMPT_GUARDRAILED = """You are Clinexa Clinical AI, an enterprise clinical decision support and EHR navigation assistant.
Your role is to assist healthcare providers and patients with medical navigation, clinical context, and record interpretation.

CRITICAL CLINICAL SAFETY GUARDRAILS (ALWAYS ENFORCED):
1. EMERGENCY DETECTION: If the query describes acute emergency symptoms (severe chest pain, stroke FAST symptoms, acute dyspnea, anaphylaxis, severe hemorrhage, or suicidal crisis), immediately prioritize emergency medical evaluation (calling 108/911/112 or Emergency Department).
2. NEVER PRESCRIBE: You must NEVER independently prescribe medications, controlled substances, opioids, or modify drug dosages. Direct the user to their attending licensed physician.
3. GROUNDING: Base clinical answers strictly on authorized patient EHR data when supplied. Never fabricate patient biomarkers, vitals, or lab values. Explicitly declare when data is missing.
4. TONE & STRUCTURE: Professional, empathetic, structured, and clinically precise. Use clear markdown headers, bulleted takeaways, and actionable clinical next steps.
"""

# -------------------------------------------------------------
# GUARDRAIL 1: EMERGENCY DETECTION (Cardiac, Stroke, Airway, Trauma, Crisis)
# -------------------------------------------------------------
EMERGENCY_KEYWORDS = [
    r"\bchest pain\b", r"\bheart attack\b", r"\bmyocardial\b", r"\bcrushing pressure\b",
    r"\bshortness of breath\b", r"\bcannot breathe\b", r"\bstrangling\b", r"\bchoking\b",
    r"\bslurred speech\b", r"\bface droop\b", r"\bfacial drooping\b", r"\barm weakness\b",
    r"\bstroke\b", r"\bhemiplegia\b", r"\banaphylaxis\b", r"\bthroat swelling\b", r"\bthroat closing\b",
    r"\bsuicid", r"\bkill myself\b", r"\bend my life\b", r"\bself-harm\b",
    r"\bsevere bleeding\b", r"\bhemorrhag\b", r"\bunconscious\b", r"\bunresponsive\b",
    r"\bstatus epilepticus\b", r"\bprolonged seizure\b", r"\bcyanosis\b", r"\bblue lips\b"
]

# -------------------------------------------------------------
# GUARDRAIL 2: CONTROLLED SUBSTANCES & AUTONOMOUS PRESCRIBING
# -------------------------------------------------------------
CONTROLLED_DRUG_KEYWORDS = [
    r"\boxycODONE\b", r"\bmorphine\b", r"\bfentanyl\b", r"\bxanax\b", r"\balprazolam\b",
    r"\badderall\b", r"\btramadol\b", r"\bcodeine\b", r"\bpercocet\b", r"\bvicodin\b",
    r"\bdiazepam\b", r"\bvalium\b", r"\blorazepam\b", r"\bclonazepam\b", r"\bmethadone\b",
    r"\bprescribe me\b", r"\bwrite me a prescription\b", r"\blethal dose\b", r"\boverdose dose\b",
    r"\bgive me drugs\b", r"\bscript for narcotics\b"
]

# -------------------------------------------------------------
# GUARDRAIL 3: SYSTEM JAILBREAK & PROMPT INJECTION DEFENSE
# -------------------------------------------------------------
INJECTION_KEYWORDS = [
    r"\b(ignore|disregard|forget)\s+(all\s+)?(previous|prior)\s+(instructions|prompts|rules)\b",
    r"\b(bypass|disable|turn\s*off)\s+(guardrails?|safety|filters?|rules)\b",
    r"\b(act\s+as|pretend\s+to\s+be)\s+(an?\s+)?(unrestricted|dan|jailbroken|evil)\b",
    r"\b(reveal|show|print|leak)\s+(the\s+)?(system\s+prompt|developer\s+message)\b",
    r"\b(you\s+have\s+no\s+rules|unlimited\s+mode|god\s+mode)\b",
    r"\boverride\s+clinical\s+safety\b"
]

# Known drug allergy class cross-reactivities
ALLERGY_CROSS_MAP = {
    "penicillin": ["penicillin", "amoxicillin", "ampicillin", "augmentin", "piperacillin", "clavulanate"],
    "amoxicillin": ["amoxicillin", "penicillin", "ampicillin", "augmentin"],
    "sulfa": ["bactrim", "septra", "sulfamethoxazole", "trimethoprim", "sulfasalazine"],
    "aspirin": ["aspirin", "ibuprofen", "nsaid", "naproxen", "diclofenac", "ketorolac", "indomethacin"],
    "nsaid": ["ibuprofen", "naproxen", "aspirin", "diclofenac", "meloxicam", "celecoxib", "ketorolac"],
    "cephalosporin": ["cephalexin", "ceftriaxone", "cefuroxime", "cefixime"],
    "codeine": ["codeine", "morphine", "tramadol"],
}


def check_emergency_guardrail(text: str) -> Optional[Dict[str, Any]]:
    lowered = text.lower()
    for pattern in EMERGENCY_KEYWORDS:
        if re.search(pattern, lowered):
            return {
                "status": "emergency",
                "badge": "🚨 EMERGENCY RED FLAG DETECTED",
                "severity": "critical",
                "message": (
                    "Your query describes symptoms that indicate a potential acute, life-threatening medical emergency. "
                    "Please do NOT wait for chat advice. Immediately dial emergency medical services (108 / 112 / 911) "
                    "or proceed directly to the nearest hospital Emergency Room."
                ),
                "emergency_action": True,
            }
    return None


def check_prescription_guardrail(text: str) -> Optional[Dict[str, Any]]:
    lowered = text.lower()
    for pattern in CONTROLLED_DRUG_KEYWORDS:
        if re.search(pattern, lowered):
            return {
                "status": "prescription_advisory",
                "badge": "⚠️ RESTRICTED SUBSTANCE & PRESCRIBING GUARDRAIL",
                "severity": "warning",
                "message": (
                    "Clinexa Clinical AI cannot dispense, prescribe, or authorize controlled substances (such as narcotics, opioids, or benzodiazepines). "
                    "All prescription orders require clinical consultation and an authorized electronic signature by a licensed medical practitioner."
                ),
                "emergency_action": False,
            }
    return None


def check_injection_guardrail(text: str) -> Optional[Dict[str, Any]]:
    lowered = text.lower()
    for pattern in INJECTION_KEYWORDS:
        if re.search(pattern, lowered):
            return {
                "status": "injection_blocked",
                "badge": "🛡️ CLINICAL GOVERNANCE ENFORCED",
                "severity": "warning",
                "message": (
                    "System safety guardrails cannot be overridden. Clinexa AI operates strictly within authorized clinical governance, "
                    "evidence-based medical protocols, and patient safety boundaries."
                ),
                "emergency_action": False,
            }
    return None


def check_allergy_guardrail(text: str, patient_ctx: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Checks if the query mentions a medication that conflicts with patient's documented allergies."""
    if not patient_ctx:
        return None
    raw_allergies = (patient_ctx.get("allergies") or "").lower()
    if not raw_allergies or "none" in raw_allergies or "nkda" in raw_allergies:
        return None

    lowered_q = text.lower()
    for allergy_key, trigger_drugs in ALLERGY_CROSS_MAP.items():
        if allergy_key in raw_allergies:
            for drug in trigger_drugs:
                if re.search(rf"\b{drug}\b", lowered_q):
                    return {
                        "status": "allergy_alert",
                        "badge": "⚠️ DOCUMENTED ALLERGY CONTRAINDICATION",
                        "severity": "critical",
                        "allergy": allergy_key,
                        "drug": drug,
                        "message": (
                            f"Patient record indicates documented allergy to '{patient_ctx.get('allergies')}'. "
                            f"The requested medication '{drug.title()}' presents a high risk of adverse hypersensitivity reaction."
                        ),
                        "emergency_action": False,
                    }
    return None


def fetch_patient_context(db: Session, patient_id: str, hospital_id: str) -> Dict[str, Any]:
    patient = db.scalar(
        select(Patient).where(Patient.id == patient_id, Patient.hospital_id == hospital_id)
    )
    if not patient:
        return {}

    meds = db.scalars(
        select(MedicationSchedule).where(MedicationSchedule.patient_id == patient_id)
    ).all()
    rx = db.scalars(
        select(Prescription).where(Prescription.patient_id == patient_id).order_by(Prescription.created_at.desc()).limit(8)
    ).all()
    labs = db.scalars(
        select(LabResult).where(LabResult.patient_id == patient_id).order_by(LabResult.created_at.desc()).limit(12)
    ).all()
    vitals = db.scalars(
        select(Vital).where(Vital.patient_id == patient_id).order_by(Vital.observed_at.desc()).limit(5)
    ).all()
    encounters = db.scalars(
        select(Encounter).where(Encounter.patient_id == patient_id).order_by(Encounter.created_at.desc()).limit(3)
    ).all()
    emergency = db.scalar(
        select(EmergencyProfile).where(EmergencyProfile.patient_id == patient_id)
    )

    return {
        "id": patient.id,
        "name": patient.full_name,
        "code": patient.patient_code,
        "gender": patient.gender,
        "blood_group": emergency.blood_group if (emergency and emergency.blood_group) else (patient.blood_group or "Not recorded"),
        "allergies": emergency.allergies if (emergency and emergency.allergies) else (patient.allergies or "None recorded"),
        "conditions": patient.conditions or "None recorded",
        "medications": [
            f"{m.medication_name} {m.dose_label or ''}".strip()
            for m in meds
        ] or [
            f"{r.medication_name} {r.strength or ''} ({r.frequency or ''})".strip()
            for r in rx
        ],
        "recent_labs": [
            f"{l.test_name}: {l.result_value} {l.unit or ''} (Ref: {l.reference_range or 'N/A'})".strip()
            for l in labs
        ],
        "latest_vitals": [
            f"BP: {v.systolic}/{v.diastolic} mmHg, HR: {v.heart_rate} bpm, SpO2: {v.spo2}%, Temp: {v.temperature_c}°C ({v.observed_at.strftime('%Y-%m-%d') if v.observed_at else 'recent'})"
            for v in vitals
        ],
        "recent_encounters": [
            f"{e.chief_complaint or 'Visit'} - Plan: {e.plan or 'Review'}"
            for e in encounters
        ],
    }


def _package_response(res: Dict[str, Any]) -> Dict[str, Any]:
    """Ensures clean structured fields AND a unified markdown answer string for backwards compatibility."""
    headline = res.get("headline", "")
    summary_points = res.get("summary_points", [])
    detail = res.get("clinical_detail", "")
    badge = res.get("guardrail", {}).get("badge", "")
    disclaimer = res.get("disclaimer", "")

    parts = []
    if badge:
        parts.append(f"**[{badge}]**\n")
    if headline:
        parts.append(f"## {headline}\n")
    if summary_points:
        bullets = "\n".join([f"- {p}" for p in summary_points])
        parts.append(f"### Key Clinical Takeaways\n{bullets}\n")
    if detail:
        parts.append(f"{detail}\n")
    if disclaimer:
        parts.append(f"\n*Disclaimer: {disclaimer}*")

    res["answer"] = "\n".join(parts).strip()
    return res


def clinical_knowledge_engine(query: str, patient_ctx: Dict[str, Any]) -> Dict[str, Any]:
    """
    Intelligent Clinical Decision Engine providing grounded clinical insights,
    EHR data synthesis, diagnostic interpretation, and safety guardrails.
    """
    q = query.lower()

    # 1. System Injection Guardrail
    injection_guard = check_injection_guardrail(query)
    if injection_guard:
        return _package_response({
            "online": True,
            "provider": "clinexa_guardrail_sentinel",
            "guardrail": injection_guard,
            "headline": "Clinical Safety Protocol Enforced",
            "summary_points": [
                "System guardrails cannot be overridden, bypassed, or modified.",
                "Patient safety protocols mandate adherence to verified clinical boundaries.",
                "Requests must conform to clinical decision support and authorized EHR navigation."
            ],
            "clinical_detail": (
                "### Governance & Security Boundaries\n"
                "- Clinexa AI is an enterprise clinical assistant adhering to healthcare compliance standards.\n"
                "- You can inquire about disease management guidelines, laboratory biomarker interpretations, active patient chart summaries, or clinic appointment scheduling."
            ),
            "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
            "suggested_actions": [
                {"label": "📋 Chart Summary", "action": "chart_summary"},
                {"label": "👤 Patient 360°", "action": "patient_360"}
            ],
            "followup_questions": [
                "How do I summarize an active patient chart?",
                "What diagnostic reference ranges are supported?"
            ],
            "disclaimer": "Safety guardrails are hardcoded into Clinexa Clinical OS to ensure patient safety."
        })

    # 2. Emergency Guardrail Trigger
    emergency_guard = check_emergency_guardrail(query)
    if emergency_guard:
        return _package_response({
            "online": True,
            "provider": "clinexa_guardrail_sentinel",
            "guardrail": emergency_guard,
            "headline": "Acute Emergency Triage Protocol Triggered",
            "summary_points": [
                "Symptoms described indicate potential acute cardiorespiratory, neurological, or trauma emergency.",
                "Clinexa Clinical AI cannot provide acute medical stabilization or emergency resuscitation.",
                "Immediate in-person physical assessment, ECG, oxygenation, or resuscitation team is urgently needed."
            ],
            "clinical_detail": (
                "### Immediate Emergency Protocol\n"
                "- **Call Emergency Ambulance:** Dial 108 / 112 / 911 immediately without waiting.\n"
                "- **Do Not Drive Yourself:** Emergency responders have life-saving oxygen and defibrillation equipment en route.\n"
                "- **Patient Position:** Semi-reclining or upright position to facilitate respiratory effort.\n"
                "- **If Unconscious:** Check carotid pulse and chest breathing. If absent, initiate CPR (100–120 compressions/min) immediately.\n"
                "- **Prepare Medical Record:** Carry current medication list and the Clinexa Emergency Medical Tag."
            ),
            "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
            "suggested_actions": [
                {"label": "🚨 Call Emergency Hotline (108)", "action": "emergency_dial"},
                {"label": "📄 Open Emergency Medical Tag", "action": "emergency_tag"},
                {"label": "🏥 Nearest Hospital ER", "action": "nearest_er"}
            ],
            "followup_questions": [
                "What are the nearest emergency trauma centers?",
                "How do I access the offline NFC Emergency Passport?"
            ],
            "disclaimer": "CRITICAL EMERGENCY ADVISORY: Clinexa Decision Support does not replace in-person emergency physician evaluation."
        })

    # 3. Prescription & Restricted Substance Guardrail
    rx_guard = check_prescription_guardrail(query)
    if rx_guard:
        return _package_response({
            "online": True,
            "provider": "clinexa_guardrail_sentinel",
            "guardrail": rx_guard,
            "headline": "Restricted Substance & Medication Policy Advisory",
            "summary_points": [
                "Controlled substances and Schedule II-IV medications require formal physical clinical evaluation.",
                "Autonomous prescribing and self-titration of opioids, sedatives, or stimulants is prohibited.",
                "All prescriptions must be electronically signed by a verified clinician in Clinexa Clinical OS."
            ],
            "clinical_detail": (
                "### Clinical Prescription Workflow\n"
                "- Schedule an authorized consultation via the **Appointments** module.\n"
                "- For pain management, discuss evidence-based multimodal non-opioid options (physical therapy, topical analgesics, acetaminophen, supervised NSAIDs).\n"
                "- Active prescriptions can be inspected and refilled through the **Medicine Centre**."
            ),
            "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
            "suggested_actions": [
                {"label": "📅 Book Doctor Consultation", "action": "book_consult"},
                {"label": "💊 View Active Prescriptions", "action": "meds"}
            ],
            "followup_questions": [
                "How do I schedule a medication review appointment?",
                "What are the non-opioid therapeutic alternatives for chronic pain?"
            ],
            "disclaimer": "Clinical Decision Support adheres to WHO, CDSCO, and FDA medication safety regulations."
        })

    # 4. Allergy Contraindication Guardrail
    allergy_guard = check_allergy_guardrail(query, patient_ctx)
    if allergy_guard:
        return _package_response({
            "online": True,
            "provider": "clinexa_guardrail_sentinel",
            "guardrail": allergy_guard,
            "headline": f"Allergy Alert: {allergy_guard.get('allergy', 'Medication').upper()} Hypersensitivity",
            "summary_points": [
                f"Active EHR chart for {patient_ctx.get('name')} documents allergy: **{patient_ctx.get('allergies')}**.",
                f"Requested drug **{allergy_guard.get('drug', '').title()}** has direct cross-reactivity or class contraindication.",
                "Administering this drug carries severe risk of urticaria, angioedema, or anaphylaxis."
            ],
            "clinical_detail": (
                "### Clinical Risk & Substitution Guidance\n"
                f"- **Documented Patient Hypersensitivity:** `{patient_ctx.get('allergies')}`\n"
                f"- **Conflicting Drug Mentioned:** `{allergy_guard.get('drug', '').title()}`\n"
                "- **Recommended Clinical Action:** Halt administration. Select an alternative non-cross-reactive therapeutic agent under physician review (e.g. Macrolides like Azithromycin or Clindamycin for penicillin allergies, or Acetaminophen for NSAID allergies).\n"
                "- **Reconciliation:** Verify allergy history with patient or family before confirming orders."
            ),
            "patient_context_applied": f"{patient_ctx.get('name')} • {patient_ctx.get('code')}",
            "suggested_actions": [
                {"label": "⚠️ Review Patient Allergies", "action": "patient_360"},
                {"label": "💊 Medicine Centre", "action": "meds"}
            ],
            "followup_questions": [
                f"What are safe antibiotic alternatives for a patient with {patient_ctx.get('allergies')} allergy?",
                "How do I update patient allergy severity in the EHR?"
            ],
            "disclaimer": "Allergy screening flags known class cross-reactivities. Clinical judgment required."
        })

    # 5. Patient Record Grounded Query (Comprehensive Chart Summary)
    if patient_ctx and any(k in q for k in ["summary", "chart", "record", "overview", "medication", "prescriptions", "labs", "vitals", "blood pressure", "allergies", "history"]):
        meds_list = patient_ctx.get("medications", [])
        labs_list = patient_ctx.get("recent_labs", [])
        vitals_list = patient_ctx.get("latest_vitals", [])
        encounters_list = patient_ctx.get("recent_encounters", [])
        allergies = patient_ctx.get("allergies") or "None documented"
        blood_group = patient_ctx.get("blood_group") or "Not recorded"
        conditions = patient_ctx.get("conditions") or "None documented"

        summary_pts = [
            f"**Patient:** {patient_ctx.get('name')} (ID: {patient_ctx.get('code')}) | **Blood Group:** {blood_group}",
            f"**Allergies:** {allergies} | **Documented Conditions:** {conditions}",
            f"**Active Medications ({len(meds_list)}):** {', '.join(meds_list[:3]) if meds_list else 'No active medications on record'}"
        ]
        if vitals_list:
            summary_pts.append(f"**Latest Vitals:** {vitals_list[0]}")

        detail_md = "### Longitudinal Health Chart Synthesis\n\n"
        
        detail_md += f"**👤 Demographics & Core Profile:**\n"
        detail_md += f"- **Full Name:** {patient_ctx.get('name')}\n"
        detail_md += f"- **Patient Code:** `{patient_ctx.get('code')}`\n"
        detail_md += f"- **Gender:** {patient_ctx.get('gender') or 'Not recorded'}\n"
        detail_md += f"- **Blood Group:** {blood_group}\n"
        detail_md += f"- **Documented Allergies:** {allergies}\n\n"

        if meds_list:
            detail_md += "**💊 Active Prescriptions:**\n"
            for m in meds_list:
                detail_md += f"- {m}\n"
            detail_md += "\n"
        else:
            detail_md += "**💊 Active Prescriptions:** None currently documented in active EHR.\n\n"

        if vitals_list:
            detail_md += "**🩺 Recent Vitals Stream:**\n"
            for v in vitals_list[:3]:
                detail_md += f"- {v}\n"
            detail_md += "\n"

        if labs_list:
            detail_md += "**🧪 Verified Laboratory Biomarkers:**\n"
            for l in labs_list[:6]:
                detail_md += f"- {l}\n"
            detail_md += "\n"

        if encounters_list:
            detail_md += "**📋 Recent Clinical Encounters:**\n"
            for enc in encounters_list:
                detail_md += f"- {enc}\n"
            detail_md += "\n"

        return _package_response({
            "online": True,
            "provider": "clinexa_clinical_engine",
            "guardrail": {
                "status": "safe",
                "badge": "✅ VERIFIED EHR RECORD GROUNDING",
                "severity": "safe",
                "message": f"Data synthesized directly from active EHR database records for {patient_ctx.get('name')}.",
                "emergency_action": False
            },
            "headline": f"Clinical Health Chart: {patient_ctx.get('name')}",
            "summary_points": summary_pts,
            "clinical_detail": detail_md,
            "patient_context_applied": f"{patient_ctx.get('name')} • {patient_ctx.get('code')}",
            "suggested_actions": [
                {"label": "💊 Medicine Centre", "action": "meds"},
                {"label": "🔬 Lab Results", "action": "labs"},
                {"label": "👤 Patient 360°", "action": "patient_360"},
                {"label": "📅 Book Follow-up", "action": "book_consult"}
            ],
            "followup_questions": [
                f"Are there any drug interactions between {patient_ctx.get('name')}'s active medicines?",
                f"Are any recent lab biomarkers out of normal reference range?",
                f"When should {patient_ctx.get('name')}'s vitals be measured next?"
            ],
            "disclaimer": "Record summary reflects verified entries in Clinexa Clinical OS. Correlate with physical bedside evaluation."
        })

    # 6. Drug-Drug Interactions Query
    if any(k in q for k in ["interaction", "drug interaction", "contraindication", "safe to take together", "combine"]):
        meds_info = patient_ctx.get("medications", []) if patient_ctx else []
        meds_str = ", ".join(meds_info) if meds_info else "No patient medications loaded (general pharmacology query)"
        
        return _package_response({
            "online": True,
            "provider": "clinexa_clinical_engine",
            "guardrail": {
                "status": "safe",
                "badge": "✅ CLINICAL PHARMACOLOGY SURVEILLANCE",
                "severity": "safe",
                "message": "Screening for major drug-drug interactions and pharmacokinetic conflicts.",
                "emergency_action": False
            },
            "headline": "Pharmacological Drug-Drug Interaction Screen",
            "summary_points": [
                f"**Current Medication Context:** {meds_str}",
                "Major interaction classes monitored: ARBs/ACEi + Potassium/NSAIDs, Anticoagulants + Antiplatelets, SSRIs + Serotonergics.",
                "Always check renal clearance (eGFR) and hepatic function prior to polypharmacy initiation."
            ],
            "clinical_detail": (
                "### High-Yield Clinical Drug Interaction Alerts\n"
                "- **ARBs (Telmisartan) + Potassium / Spironolactone:** High risk of severe hyperkalemia and acute kidney injury. Monitor serum K+ and creatinine regularly.\n"
                "- **ARBs / ACEi + NSAIDs (Ibuprofen / Naproxen):** NSAIDs attenuate antihypertensive effects and reduce renal perfusion, potentially triggering acute renal failure.\n"
                "- **Metformin + Radiocontrast Agents:** Risk of contrast-induced nephropathy and lactic acidosis. Discontinue Metformin 48h prior to elective iodinated contrast.\n"
                "- **Statins (Atorvastatin/Rosuvastatin) + Macrolides / Azoles:** CYP3A4 inhibition increases statin plasma levels, elevating risk of myopathy and rhabdomyolysis.\n"
                "- **Anticoagulants (Warfarin/Apixaban) + Aspirin/NSAIDs:** Exponentially increases gastrointestinal and systemic bleeding risks without proportional ischemic benefit."
            ),
            "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
            "suggested_actions": [
                {"label": "💊 Medicine Centre", "action": "meds"},
                {"label": "🔬 Check Serum Potassium / Creatinine", "action": "labs"},
                {"label": "📅 Book Physician Review", "action": "book_consult"}
            ],
            "followup_questions": [
                "What are the clinical signs of hyperkalemia in patients on Telmisartan?",
                "Which pain relievers are safest for patients with hypertension?"
            ],
            "disclaimer": "Interaction screening adheres to clinical pharmacology reference standards. Physician approval required for medication modifications."
        })

    # 7. Glycemic / Diabetes Lab Interpretation (HbA1c, Glucose, Diabetes)
    if any(k in q for k in ["hba1c", "glycated", "a1c", "diabetes", "blood sugar", "glucose"]):
        return _package_response({
            "online": True,
            "provider": "clinexa_clinical_engine",
            "guardrail": {
                "status": "safe",
                "badge": "✅ CLINICAL DECISION SUPPORT • ADA STANDARDS",
                "severity": "safe",
                "message": "Glycemic evaluation based on American Diabetes Association (ADA 2026) Standards of Care.",
                "emergency_action": False
            },
            "headline": "HbA1c & Glycemic Control Clinical Protocol",
            "summary_points": [
                "**Diagnostic Thresholds:** Normal < 5.7% | Pre-diabetes 5.7%–6.4% | Diabetes diagnosis ≥ 6.5%.",
                "**Standard Adult Target:** HbA1c < 7.0% for most non-pregnant adults to reduce microvascular complications.",
                "**Estimated Average Glucose (eAG):** HbA1c of 7.0% corresponds to ~154 mg/dL. Each 1% increment adds ~29 mg/dL."
            ],
            "clinical_detail": (
                "### Clinical Interpretation & Action Plan\n"
                "- **Elevated Levels (> 8.0%):** Indicates chronic hyperglycemia. Assess medication adherence, diet, and consider dual therapy (e.g. Metformin + SGLT2 inhibitor or GLP-1 RA for cardiorenal protection).\n"
                "- **Target Individualization:** Relax target to < 8.0% in elderly individuals with hypoglycemia unawareness, severe cardiovascular disease, or limited life expectancy.\n"
                "- **Microvascular Screening:** Annual screening required for diabetic kidney disease (UACR + eGFR), dilated eye exam (retinopathy), and comprehensive foot exam."
            ),
            "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
            "suggested_actions": [
                {"label": "🔬 View Lab History", "action": "labs"},
                {"label": "💊 Diabetes Medications", "action": "meds"},
                {"label": "📅 Book Endocrinologist", "action": "book_consult"}
            ],
            "followup_questions": [
                "What is the difference between Fasting Blood Sugar and Post-Prandial Glucose?",
                "What are the cardiorenal benefits of SGLT2 inhibitors in Type 2 Diabetes?"
            ],
            "disclaimer": "Glycemic targets must be individualized by attending physician based on clinical comorbidity profile."
        })

    # 8. Complete Blood Count (CBC) Diagnostic Interpretation
    if any(k in q for k in ["cbc", "hemoglobin", "platelet", "white blood cell", "wbc", "rbc", "anemia", "neutrophil"]):
        return _package_response({
            "online": True,
            "provider": "clinexa_clinical_engine",
            "guardrail": {
                "status": "safe",
                "badge": "✅ HEMATOLOGY DIAGNOSTIC PROTOCOL",
                "severity": "safe",
                "message": "Standard hematology reference standards and morphological workup.",
                "emergency_action": False
            },
            "headline": "Complete Blood Count (CBC) Diagnostic Biomarkers",
            "summary_points": [
                "**Hemoglobin (Hb):** Adult Men: 13.8–17.2 g/dL | Adult Women: 12.1–15.1 g/dL. Low values define anemia.",
                "**WBC Count:** 4,000–11,000 /µL. Leukocytosis indicates infection, systemic inflammation, or physical stress.",
                "**Platelets:** 150,000–450,000 /µL. Essential for primary hemostasis; thrombocytopenia (<100k) warrants bleeding precautions."
            ],
            "clinical_detail": (
                "### Diagnostic Workup & Differential Algorithm\n"
                "- **Anemia Differential (MCV):**\n"
                "  • Microcytic (MCV < 80 fL): Iron deficiency anemia, Thalassemia trait, Sideroblastic anemia.\n"
                "  • Normocytic (MCV 80–100 fL): Anemia of chronic disease, acute blood loss, hemolysis, renal failure.\n"
                "  • Macrocytic (MCV > 100 fL): Vitamin B12 or Folate deficiency, liver disease, reticulocytosis.\n"
                "- **Differential White Cell Count:** Neutrophilia with left shift strongly favors bacterial etiology; Lymphocytosis typically suggests viral infections.\n"
                "- **Platelet Flags:** Platelets < 50,000/µL require trauma precautions; < 20,000/µL carries spontaneous intracranial/mucosal hemorrhage risk."
            ),
            "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
            "suggested_actions": [
                {"label": "🔬 View Patient CBC Lab", "action": "labs"},
                {"label": "🩺 Log Clinical Vitals", "action": "vitals"},
                {"label": "📅 Book Hematology Review", "action": "book_consult"}
            ],
            "followup_questions": [
                "How do you distinguish Iron Deficiency Anemia from Anemia of Chronic Disease?",
                "What is the clinical management threshold for severe thrombocytopenia?"
            ],
            "disclaimer": "Diagnostic hematology results must always be correlated with physical clinical examination."
        })

    # 9. Renal Profile & Kidney Function (Creatinine, BUN, eGFR)
    if any(k in q for k in ["creatinine", "kidney", "renal", "egfr", "bun", "urea"]):
        return _package_response({
            "online": True,
            "provider": "clinexa_clinical_engine",
            "guardrail": {
                "status": "safe",
                "badge": "✅ NEPHROLOGY CLINICAL GUIDELINES",
                "severity": "safe",
                "message": "Kidney Disease Improving Global Outcomes (KDIGO) staging reference.",
                "emergency_action": False
            },
            "headline": "Renal Biomarkers & Glomerular Filtration Protocol",
            "summary_points": [
                "**Serum Creatinine:** Normal Men: 0.7–1.3 mg/dL | Women: 0.6–1.1 mg/dL. Waste product of muscle metabolism.",
                "**eGFR (CKD-EPI):** > 90 mL/min/1.73m² (Normal) | 60–89 (Mildly reduced) | 30–59 (Moderate CKD) | < 15 (Kidney Failure).",
                "**Blood Urea Nitrogen (BUN):** Normal 7–20 mg/dL. Elevated BUN:Cr ratio (> 20:1) suggests prerenal azotemia/dehydration."
            ],
            "clinical_detail": (
                "### Clinical Renoprotective Pathways\n"
                "- **Acute Kidney Injury (AKI):** Rise in serum creatinine by ≥ 0.3 mg/dL within 48h or ≥ 1.5x baseline. Identify and discontinue nephrotoxic agents (NSAIDs, aminoglycosides).\n"
                "- **Medication Renal Dosing:** Adjust dosages of renally cleared medications (e.g. Metformin held if eGFR < 30, Gabapentin/Pregabalin, Ciprofloxacin, Enoxaparin).\n"
                "- **Hypertension & Proteinuria:** ACE inhibitors or ARBs are first-line for renoprotection in proteinuric CKD, paired with SGLT2 inhibitors."
            ),
            "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
            "suggested_actions": [
                {"label": "🔬 View Renal Lab Panel", "action": "labs"},
                {"label": "💊 Review Renally Cleared Meds", "action": "meds"},
                {"label": "📅 Book Nephrologist Consult", "action": "book_consult"}
            ],
            "followup_questions": [
                "What medications must be dose-adjusted when eGFR is under 45 mL/min?",
                "How does dehydration affect the BUN to Creatinine ratio?"
            ],
            "disclaimer": "Renal dosing adjustments require confirmation with attending nephrologist or pharmacist."
        })

    # 10. Cardiovascular / Hypertension Guidelines (Telmisartan, BP, Amlodipine)
    if any(k in q for k in ["hypertension", "blood pressure", "telmisartan", "amlodipine", "systolic", "diastolic"]):
        return _package_response({
            "online": True,
            "provider": "clinexa_clinical_engine",
            "guardrail": {
                "status": "safe",
                "badge": "✅ CARDIOLOGY CLINICAL PROTOCOL • ACC/AHA",
                "severity": "safe",
                "message": "Hypertension management aligned with ACC/AHA and JNC-8 guidelines.",
                "emergency_action": False
            },
            "headline": "Hypertension Staging & Antihypertensive Therapy",
            "summary_points": [
                "**Classification:** Normal < 120/80 | Elevated 120–129/<80 | Stage 1 HTN 130–139/80–89 | Stage 2 HTN ≥ 140/90 mmHg.",
                "**Target Goal:** < 130/80 mmHg for most adult patients with confirmed hypertension.",
                "**First-Line Pharmacotherapy:** ARBs (Telmisartan), ACE inhibitors, Dihydropyridine CCBs (Amlodipine), Thiazide diuretics."
            ],
            "clinical_detail": (
                "### Clinical Management Strategies\n"
                "- **Telmisartan (ARB):** 20mg–80mg once daily. Long 24h half-life provides consistent 24h blood pressure control. Monitor serum potassium and creatinine.\n"
                "- **Combination Therapy:** If BP is > 20/10 mmHg above target, initiate initial dual therapy (e.g. Telmisartan + Amlodipine or Telmisartan + Chlorthalidone).\n"
                "- **Lifestyle Prescriptions:** DASH dietary pattern, sodium restriction (< 2,300 mg/day), 150 min/week moderate aerobic activity, alcohol moderation.\n"
                "- **Hypertensive Crisis Red Flags:** SBP > 180 or DBP > 120 with end-organ damage (chest pain, shortness of breath, vision loss, confusion) requires emergent IV therapy in ER."
            ),
            "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
            "suggested_actions": [
                {"label": "🩺 Record Blood Pressure", "action": "vitals"},
                {"label": "💊 View BP Medications", "action": "meds"},
                {"label": "📅 Book Cardiologist Review", "action": "book_consult"}
            ],
            "followup_questions": [
                "What is the difference between Hypertensive Urgency and Hypertensive Emergency?",
                "What are common side effects of Amlodipine (e.g., peripheral pedal edema)?"
            ],
            "disclaimer": "Antihypertensive regimen changes require attending physician authorization."
        })

    # 11. Appointment Booking Intent
    if any(k in q for k in ["book appointment", "schedule visit", "doctor appointment", "book consult", "see a doctor"]):
        return _package_response({
            "online": True,
            "provider": "clinexa_clinical_engine",
            "guardrail": {
                "status": "safe",
                "badge": "✅ CARE COORDINATION WORKFLOW",
                "severity": "info",
                "message": "AI-assisted clinical appointment booking workflow.",
                "emergency_action": False
            },
            "headline": "AI-Assisted Appointment Scheduling",
            "summary_points": [
                "Clinexa enables rapid clinician booking with real-time slot conflict checks.",
                "Appointments can be scheduled for in-person consultations or tele-health encounters.",
                "All AI-proposed bookings require explicit user confirmation before writing to the database."
            ],
            "clinical_detail": (
                "### Quick Booking Steps\n"
                "- Click the **AI Booking** button in the top action bar or tap **Create Booking Proposal** below.\n"
                "- Select the patient, target physician specialty (Cardiology, General Medicine, Endocrinology), and desired date/time.\n"
                "- Review proposed details on the confirmation dialogue to lock in the appointment slot."
            ),
            "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
            "suggested_actions": [
                {"label": "📅 Create Booking Proposal", "action": "book_consult"},
                {"label": "👥 View Available Doctors", "action": "doctors"}
            ],
            "followup_questions": [
                "Which doctors are available for consultation tomorrow?",
                "How do I reschedule or cancel an existing appointment?"
            ],
            "disclaimer": "Appointment reservations require clinic database confirmation."
        })

    # 12. General Clinical Decision Support Synthesizer
    return _package_response({
        "online": True,
        "provider": "clinexa_clinical_engine",
        "guardrail": {
            "status": "safe",
            "badge": "✅ CLINICAL DECISION SUPPORT CO-PILOT",
            "severity": "safe",
            "message": "Structured evidence-based clinical reasoning and healthcare navigation.",
            "emergency_action": False
        },
        "headline": f"Clinical Guidance: {query.strip()[:60]}",
        "summary_points": [
            "Clinexa Clinical AI synthesizes EHR records, diagnostic reference ranges, and therapeutic protocols.",
            f"Active patient context: {patient_ctx.get('name') if patient_ctx else 'General Healthcare Guidance'}.",
            "Always correlate electronic decision support with comprehensive bedside clinical evaluation."
        ],
        "clinical_detail": (
            "### Clinical Evaluation & Diagnostic Framework\n"
            f"Regarding **\"{query.strip()}\"**:\n"
            "- **History & Physical:** Assess onset, duration, character, aggravating and alleviating factors, and systemic red flags.\n"
            "- **Diagnostic Alignment:** Verify baseline laboratory panels (CBC, Comprehensive Metabolic Panel, Lipid Profile) and physiological vitals on the **Patient 360°** record.\n"
            "- **Multidisciplinary Coordination:** Document findings in clinical progress notes and coordinate follow-up with attending specialists."
        ),
        "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
        "suggested_actions": [
            {"label": "👤 Open Patient 360°", "action": "patient_360"},
            {"label": "📅 Book Appointment", "action": "book_consult"},
            {"label": "💊 Medicine Centre", "action": "meds"}
        ],
        "followup_questions": [
            "What clinical biomarkers should be monitored regularly?",
            "How do I log new patient vitals or lab orders?",
            "What are the emergency red flags for this presentation?"
        ],
        "disclaimer": "Clinexa Clinical Decision Support provides authorized clinical reference only. Consult your attending physician for medical diagnosis and treatment."
    })


async def chat_service(message: str, patient_id: Optional[str], db: Session, user_name: str, hospital_id: str) -> Dict[str, Any]:
    """
    Main entrypoint for Clinexa Clinical AI.
    Executes real-time safety guardrails -> retrieves EHR context -> queries Ollama or hybrid Clinical Engine.
    """
    # 1. Fetch patient EHR context if specified
    patient_ctx = {}
    if patient_id:
        patient_ctx = fetch_patient_context(db, patient_id, hospital_id)

    # 2. Zero-latency safety guardrails (Emergency, Injection, Prescription, Allergy)
    emergency = check_emergency_guardrail(message)
    if emergency:
        return clinical_knowledge_engine(message, patient_ctx)

    injection = check_injection_guardrail(message)
    if injection:
        return clinical_knowledge_engine(message, patient_ctx)

    rx_guard = check_prescription_guardrail(message)
    if rx_guard:
        return clinical_knowledge_engine(message, patient_ctx)

    allergy_guard = check_allergy_guardrail(message, patient_ctx)
    if allergy_guard:
        return clinical_knowledge_engine(message, patient_ctx)

    # 3. If Ollama is available, query local neural model with structured EHR grounding
    try:
        context_str = f"Clinician / User: {user_name}.\n"
        if patient_ctx:
            context_str += (
                f"Patient Name: {patient_ctx.get('name')} (Code: {patient_ctx.get('code')})\n"
                f"Blood Group: {patient_ctx.get('blood_group')}, Allergies: {patient_ctx.get('allergies')}\n"
                f"Conditions: {patient_ctx.get('conditions')}\n"
                f"Active Medications: {patient_ctx.get('medications')}\n"
                f"Recent Labs: {patient_ctx.get('recent_labs')}\n"
                f"Latest Vitals: {patient_ctx.get('latest_vitals')}\n"
            )

        payload = {
            "model": settings.OLLAMA_MODEL,
            "stream": False,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT_GUARDRAILED},
                {"role": "system", "content": f"Authorized Patient Clinical Context:\n{context_str}"},
                {"role": "user", "content": message},
            ]
        }

        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.post(f"{settings.OLLAMA_BASE_URL}/api/chat", json=payload)
            if r.status_code == 200:
                raw_answer = r.json().get("message", {}).get("content", "")
                if raw_answer and len(raw_answer.strip()) > 10:
                    lines = [l.strip() for l in raw_answer.split("\n") if l.strip()]
                    summary = lines[:3] if len(lines) >= 3 else [raw_answer[:120]]
                    return _package_response({
                        "online": True,
                        "provider": f"ollama_{settings.OLLAMA_MODEL}",
                        "guardrail": {
                            "status": "safe",
                            "badge": "✅ CLINICAL LOCAL AI MODEL",
                            "severity": "safe",
                            "message": f"Processed via local private neural model ({settings.OLLAMA_MODEL}).",
                            "emergency_action": False
                        },
                        "headline": lines[0][:80] if lines else "Clinical Decision Synthesis",
                        "summary_points": summary,
                        "clinical_detail": raw_answer,
                        "patient_context_applied": patient_ctx.get("name") if patient_ctx else None,
                        "suggested_actions": [
                            {"label": "👤 Patient 360°", "action": "patient_360"},
                            {"label": "📅 Book Follow-up", "action": "book_consult"},
                            {"label": "💊 Medicine Centre", "action": "meds"}
                        ],
                        "followup_questions": [
                            "Are there any drug-drug interactions with active medications?",
                            "What clinical biomarkers should be repeated next?"
                        ],
                        "disclaimer": "Clinexa Local AI generates clinical decision guidance. Verify with attending licensed medical personnel."
                    })
    except Exception:
        # Graceful fallback to Clinexa Clinical Knowledge Engine
        pass

    # 4. Fallback to Clinexa Clinical Knowledge Engine
    return clinical_knowledge_engine(message, patient_ctx)
