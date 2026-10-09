from datetime import datetime, date
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func, update, or_
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.audit import log_action
from pydantic import BaseModel
from typing import Literal
from app.core.dependencies import require_permission, tenant_id
from app.models.user import User
from app.models.operations import PharmacyItem, InventoryBatch, Invoice, Payment, Ward, Room, Bed, Admission, DispensingRecord
from app.models.catalog import MedicationCatalogItem, PharmacyRequest, PharmacyRequestItem
from app.models.clinical import Patient
from app.models.records import Prescription
from app.schemas.domain import PharmacyItemCreate, InventoryBatchCreate, InvoiceCreate, PaymentCreate, AdmissionCreate, DispenseCreate, WardCreate, RoomCreate, BedCreate, PharmacyRequestStatusUpdate

router = APIRouter(tags=["Hospital Operations"])

@router.get("/pharmacy/items")
def pharmacy_items(db: Session = Depends(get_db), user: User = Depends(require_permission("pharmacy.read"))):
    h = tenant_id(user)
    stmt = (
        select(
            PharmacyItem,
            func.coalesce(func.sum(InventoryBatch.quantity), 0).label("quantity")
        )
        .outerjoin(InventoryBatch, PharmacyItem.id == InventoryBatch.pharmacy_item_id)
        .where(PharmacyItem.hospital_id == h)
        .group_by(PharmacyItem.id)
        .order_by(PharmacyItem.name)
    )
    results = db.execute(stmt).all()
    return [
        {
            "id": item.id,
            "name": item.name,
            "form": item.form,
            "strength": item.strength,
            "reorder_level": item.reorder_level,
            "quantity": int(qty),
            "low_stock": int(qty) <= item.reorder_level
        }
        for item, qty in results
    ]

@router.post("/pharmacy/items", status_code=201)
def add_item(payload: PharmacyItemCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("pharmacy.manage"))):
    row = PharmacyItem(hospital_id=tenant_id(user), **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row

@router.get("/pharmacy/batches")
def batches(db: Session = Depends(get_db), user: User = Depends(require_permission("pharmacy.read"))):
    ids = select(PharmacyItem.id).where(PharmacyItem.hospital_id == tenant_id(user))
    return db.scalars(select(InventoryBatch).where(InventoryBatch.pharmacy_item_id.in_(ids)).order_by(InventoryBatch.expiry_date)).all()

@router.post("/pharmacy/batches", status_code=201)
def add_batch(payload: InventoryBatchCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("pharmacy.manage"))):
    item = db.scalar(select(PharmacyItem).where(PharmacyItem.id == payload.pharmacy_item_id, PharmacyItem.hospital_id == tenant_id(user)))
    if not item:
        raise HTTPException(status_code=404, detail="Pharmacy item not found")
    row = InventoryBatch(**payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row

@router.post("/pharmacy/dispense", status_code=201)
def dispense(payload: DispenseCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("pharmacy.manage"))):
    prescription = db.scalar(select(Prescription).join(Patient, Prescription.patient_id == Patient.id)
                             .where(Prescription.id == payload.prescription_id, Patient.hospital_id == tenant_id(user)))
    item = db.scalar(select(PharmacyItem).where(PharmacyItem.id == payload.pharmacy_item_id, PharmacyItem.hospital_id == tenant_id(user)))
    if not prescription or not item:
        raise HTTPException(status_code=404, detail="Prescription or pharmacy item not found")
    batch = db.scalar(select(InventoryBatch).where(InventoryBatch.pharmacy_item_id == item.id, InventoryBatch.quantity >= payload.quantity, or_(InventoryBatch.expiry_date == None, InventoryBatch.expiry_date >= date.today())).order_by(InventoryBatch.expiry_date))
    if not batch:
        raise HTTPException(status_code=409, detail="Insufficient stock")
    changed = db.execute(update(InventoryBatch).where(InventoryBatch.id == batch.id, InventoryBatch.quantity >= payload.quantity)
                         .values(quantity=InventoryBatch.quantity - payload.quantity))
    if changed.rowcount != 1:
        db.rollback()
        raise HTTPException(409, "Stock changed. Refresh before dispensing.")
    row = DispensingRecord(prescription_id=prescription.id, pharmacy_item_id=item.id, quantity=payload.quantity, pharmacist_user_id=user.id)
    db.add(row); db.commit(); db.refresh(row); return row

@router.get("/billing/invoices")
def invoices(db: Session = Depends(get_db), user: User = Depends(require_permission("billing.manage"))):
    return db.scalars(select(Invoice).where(Invoice.hospital_id == tenant_id(user)).order_by(Invoice.created_at.desc())).all()

@router.post("/billing/invoices", status_code=201)
def create_invoice(payload: InvoiceCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("billing.manage"))):
    if not db.scalar(select(Patient).where(Patient.id == payload.patient_id, Patient.hospital_id == tenant_id(user))):
        raise HTTPException(404, "Patient not found")
    row = Invoice(hospital_id=tenant_id(user), **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row

@router.post("/billing/invoices/{invoice_id}/payments", status_code=201)
def pay(invoice_id: str, payload: PaymentCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("billing.manage"))):
    inv = db.scalar(select(Invoice).where(Invoice.id == invoice_id, Invoice.hospital_id == tenant_id(user)))
    if not inv:
        raise HTTPException(status_code=404, detail="Invoice not found")
    existing_paid = db.scalar(select(func.coalesce(func.sum(Payment.amount), 0)).where(Payment.invoice_id == inv.id)) or 0
    if float(existing_paid) + payload.amount > inv.total_amount + 0.001:
        raise HTTPException(409, "Payment exceeds the outstanding balance")
    row = Payment(invoice_id=inv.id, **payload.model_dump()); db.add(row); db.flush()
    paid = db.scalar(select(func.coalesce(func.sum(Payment.amount), 0)).where(Payment.invoice_id == inv.id)) or 0
    if float(paid) >= inv.total_amount:
        inv.status = "paid"
    db.commit(); db.refresh(row); return row


@router.get("/wards")
def wards(db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.read"))):
    return db.scalars(select(Ward).where(Ward.hospital_id == tenant_id(user)).order_by(Ward.name)).all()

@router.post("/wards", status_code=201)
def create_ward(payload: WardCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.manage"))):
    row = Ward(hospital_id=tenant_id(user), name=payload.name.strip()); db.add(row); db.commit(); db.refresh(row); return row

@router.get("/rooms")
def rooms(db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.read"))):
    ward_ids = select(Ward.id).where(Ward.hospital_id == tenant_id(user))
    return db.scalars(select(Room).where(Room.ward_id.in_(ward_ids)).order_by(Room.name)).all()

@router.post("/rooms", status_code=201)
def create_room(payload: RoomCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.manage"))):
    ward = db.scalar(select(Ward).where(Ward.id == payload.ward_id, Ward.hospital_id == tenant_id(user)))
    if not ward: raise HTTPException(status_code=404, detail="Ward not found")
    row = Room(ward_id=ward.id, name=payload.name.strip()); db.add(row); db.commit(); db.refresh(row); return row

@router.post("/beds", status_code=201)
def create_bed(payload: BedCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.manage"))):
    room = db.get(Room, payload.room_id)
    if not room: raise HTTPException(status_code=404, detail="Room not found")
    ward = db.scalar(select(Ward).where(Ward.id == room.ward_id, Ward.hospital_id == tenant_id(user)))
    if not ward: raise HTTPException(status_code=403, detail="Access denied")
    row = Bed(room_id=room.id, label=payload.label.strip(), status="available"); db.add(row); db.commit(); db.refresh(row); return row

@router.get("/beds")
def beds(db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.read"))):
    rows = db.execute(select(Bed, Room, Ward).join(Room, Bed.room_id == Room.id).join(Ward, Room.ward_id == Ward.id).where(Ward.hospital_id == tenant_id(user))).all()
    return [{"bed_id": b.id, "label": b.label, "status": b.status, "room": r.name, "ward": w.name} for b, r, w in rows]

@router.get("/admissions")
def admissions(db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.read"))):
    return db.scalars(select(Admission).where(Admission.hospital_id == tenant_id(user)).order_by(Admission.admitted_at.desc())).all()

@router.post("/admissions", status_code=201)
def admit(payload: AdmissionCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.manage"))):
    if not db.scalar(select(Patient).where(Patient.id == payload.patient_id, Patient.hospital_id == tenant_id(user))):
        raise HTTPException(404, "Patient not found")
    if payload.bed_id:
        bed = db.get(Bed, payload.bed_id)
        if not bed or bed.status != "available":
            raise HTTPException(status_code=409, detail="Bed is not available")
        room = db.get(Room, bed.room_id)
        ward = db.get(Ward, room.ward_id) if room else None
        if not ward or ward.hospital_id != tenant_id(user):
            raise HTTPException(404, "Bed not found")
        changed = db.execute(update(Bed).where(Bed.id == bed.id, Bed.status == "available").values(status="occupied"))
        if changed.rowcount != 1:
            db.rollback()
            raise HTTPException(409, "Bed was just allocated. Refresh the bed board.")
    row = Admission(hospital_id=tenant_id(user), **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row

@router.post("/admissions/{admission_id}/discharge")
def discharge(admission_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.manage"))):
    row = db.scalar(select(Admission).where(Admission.id == admission_id, Admission.hospital_id == tenant_id(user)))
    if not row:
        raise HTTPException(status_code=404, detail="Admission not found")
    if row.status != "admitted":
        raise HTTPException(409, "Patient is already discharged")
    row.status = "discharged"; row.discharged_at = datetime.utcnow()
    if row.bed_id:
        bed = db.get(Bed, row.bed_id)
        if bed:
            bed.status = "cleaning"
    db.commit(); db.refresh(row); return row


@router.get("/pharmacy/catalog")
def medication_catalog(db: Session = Depends(get_db), user: User = Depends(require_permission("pharmacy.read"))):
    return db.scalars(
        select(MedicationCatalogItem).where(
            MedicationCatalogItem.hospital_id == tenant_id(user),
            MedicationCatalogItem.active == True,
        ).order_by(MedicationCatalogItem.category, MedicationCatalogItem.display_name)
    ).all()


@router.get("/pharmacy/requests")
def pharmacy_requests(db: Session = Depends(get_db), user: User = Depends(require_permission("pharmacy.read"))):
    h = tenant_id(user)
    requests = db.scalars(select(PharmacyRequest).where(PharmacyRequest.hospital_id == h).order_by(PharmacyRequest.created_at.desc()).limit(200)).all()
    patients = {p.id: p for p in db.scalars(select(Patient).where(Patient.hospital_id == h)).all()}
    catalog = {c.id: c for c in db.scalars(select(MedicationCatalogItem).where(MedicationCatalogItem.hospital_id == h)).all()}
    out = []
    for request in requests:
        items = db.scalars(select(PharmacyRequestItem).where(PharmacyRequestItem.request_id == request.id)).all()
        patient = patients.get(request.patient_id)
        out.append({
            "id": request.id,
            "patient_id": request.patient_id,
            "patient_name": patient.full_name if patient else "Patient",
            "patient_code": patient.patient_code if patient else None,
            "status": request.status,
            "note": request.note,
            "created_at": request.created_at,
            "items": [
                {
                    "id": x.id,
                    "catalog_item_id": x.catalog_item_id,
                    "display_name": catalog.get(x.catalog_item_id).display_name if catalog.get(x.catalog_item_id) else "Medicine",
                    "strength": catalog.get(x.catalog_item_id).strength if catalog.get(x.catalog_item_id) else None,
                    "form": catalog.get(x.catalog_item_id).form if catalog.get(x.catalog_item_id) else None,
                    "quantity": x.quantity,
                }
                for x in items
            ],
        })
    return out


@router.patch("/pharmacy/requests/{request_id}/status")
def update_pharmacy_request(request_id: str, payload: PharmacyRequestStatusUpdate, db: Session = Depends(get_db), user: User = Depends(require_permission("pharmacy.manage"))):
    row = db.scalar(select(PharmacyRequest).where(PharmacyRequest.id == request_id, PharmacyRequest.hospital_id == tenant_id(user)))
    if not row:
        raise HTTPException(404, "Pharmacy request not found")
    row.status = payload.status
    row.processed_by_user_id = user.id
    db.commit()
    db.refresh(row)
    return row

class BedStatusUpdate(BaseModel):
    status: Literal["available", "cleaning", "maintenance"]


@router.patch("/beds/{bed_id}/status")
def bed_status(bed_id: str, payload: BedStatusUpdate, db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.manage"))):
    bed = db.scalar(select(Bed).join(Room, Bed.room_id == Room.id).join(Ward, Room.ward_id == Ward.id)
                    .where(Bed.id == bed_id, Ward.hospital_id == tenant_id(user)))
    if not bed:
        raise HTTPException(404, "Bed not found")
    if bed.status == "occupied":
        raise HTTPException(409, "Discharge the patient before changing this bed")
    changed = db.execute(update(Bed).where(Bed.id == bed.id, Bed.status != "occupied").values(status=payload.status))
    if changed.rowcount != 1:
        db.rollback()
        raise HTTPException(409, "Bed occupancy changed. Refresh the bed board.")
    log_action(db, user.id, "bed.status", "bed", bed.id, metadata={"status": payload.status})
    db.commit(); db.refresh(bed)
    return bed
