from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import require_permission, tenant_id
from app.models.user import User
from app.models.operations import PharmacyItem, InventoryBatch, Invoice, Payment, Ward, Room, Bed, Admission, DispensingRecord
from app.models.records import Prescription
from app.schemas.domain import PharmacyItemCreate, InventoryBatchCreate, InvoiceCreate, PaymentCreate, AdmissionCreate, DispenseCreate, WardCreate, RoomCreate, BedCreate

router = APIRouter(tags=["Hospital Operations"])

@router.get("/pharmacy/items")
def pharmacy_items(db: Session = Depends(get_db), user: User = Depends(require_permission("pharmacy.read"))):
    items = db.scalars(select(PharmacyItem).where(PharmacyItem.hospital_id == tenant_id(user)).order_by(PharmacyItem.name)).all()
    out = []
    for item in items:
        qty = db.scalar(select(func.coalesce(func.sum(InventoryBatch.quantity), 0)).where(InventoryBatch.pharmacy_item_id == item.id)) or 0
        out.append({"id": item.id, "name": item.name, "form": item.form, "strength": item.strength, "reorder_level": item.reorder_level, "quantity": int(qty), "low_stock": int(qty) <= item.reorder_level})
    return out

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
    prescription = db.get(Prescription, payload.prescription_id)
    item = db.scalar(select(PharmacyItem).where(PharmacyItem.id == payload.pharmacy_item_id, PharmacyItem.hospital_id == tenant_id(user)))
    if not prescription or not item:
        raise HTTPException(status_code=404, detail="Prescription or pharmacy item not found")
    batch = db.scalar(select(InventoryBatch).where(InventoryBatch.pharmacy_item_id == item.id, InventoryBatch.quantity >= payload.quantity).order_by(InventoryBatch.expiry_date))
    if not batch:
        raise HTTPException(status_code=409, detail="Insufficient stock")
    batch.quantity -= payload.quantity
    row = DispensingRecord(prescription_id=prescription.id, pharmacy_item_id=item.id, quantity=payload.quantity, pharmacist_user_id=user.id)
    db.add(row); db.commit(); db.refresh(row); return row

@router.get("/billing/invoices")
def invoices(db: Session = Depends(get_db), user: User = Depends(require_permission("billing.manage"))):
    return db.scalars(select(Invoice).where(Invoice.hospital_id == tenant_id(user)).order_by(Invoice.created_at.desc())).all()

@router.post("/billing/invoices", status_code=201)
def create_invoice(payload: InvoiceCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("billing.manage"))):
    row = Invoice(hospital_id=tenant_id(user), **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row

@router.post("/billing/invoices/{invoice_id}/payments", status_code=201)
def pay(invoice_id: str, payload: PaymentCreate, db: Session = Depends(get_db), user: User = Depends(require_permission("billing.manage"))):
    inv = db.scalar(select(Invoice).where(Invoice.id == invoice_id, Invoice.hospital_id == tenant_id(user)))
    if not inv:
        raise HTTPException(status_code=404, detail="Invoice not found")
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
    if payload.bed_id:
        bed = db.get(Bed, payload.bed_id)
        if not bed or bed.status != "available":
            raise HTTPException(status_code=409, detail="Bed is not available")
        bed.status = "occupied"
    row = Admission(hospital_id=tenant_id(user), **payload.model_dump()); db.add(row); db.commit(); db.refresh(row); return row

@router.post("/admissions/{admission_id}/discharge")
def discharge(admission_id: str, db: Session = Depends(get_db), user: User = Depends(require_permission("admissions.manage"))):
    row = db.scalar(select(Admission).where(Admission.id == admission_id, Admission.hospital_id == tenant_id(user)))
    if not row:
        raise HTTPException(status_code=404, detail="Admission not found")
    row.status = "discharged"; row.discharged_at = datetime.utcnow()
    if row.bed_id:
        bed = db.get(Bed, row.bed_id)
        if bed:
            bed.status = "cleaning"
    db.commit(); db.refresh(row); return row
