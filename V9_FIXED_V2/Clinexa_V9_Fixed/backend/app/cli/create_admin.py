from getpass import getpass
from sqlalchemy import select
from app.core.database import Base,engine,SessionLocal
from app.core.security import hash_password
from app.models.organization import Hospital
from app.models.rbac import Role,Permission
from app.models.user import User
from app.models.account import UserAccountProfile
import app.models
PERMISSIONS=["*","admin.dashboard","audit.read","users.manage","patient.demographics.read","patient.demographics.write","patient.clinical.read","patient.clinical.write","doctors.read","doctors.manage","appointments.read","appointments.create","appointments.modify","prescriptions.read","prescriptions.create","lab_results.upload","documents.read","documents.upload","documents.ocr","messages.read","messages.send","pharmacy.read","pharmacy.manage","billing.manage","admissions.read","admissions.manage"]
def main():
    Base.metadata.create_all(bind=engine);db=SessionLocal()
    try:
        print("Create the first Clinexa administrator.");name=input("Full name: ").strip();email=input("Email: ").strip().lower();password=getpass("Password (minimum 10 characters): ");confirm=getpass("Confirm password: ")
        if len(password)<10: raise SystemExit("Password must be at least 10 characters.")
        if password!=confirm: raise SystemExit("Passwords do not match.")
        if db.scalar(select(User).where(User.email==email)): raise SystemExit("Email already exists.")
        hospital=db.scalar(select(Hospital).where(Hospital.code=="CLINEXA"))
        if not hospital: hospital=Hospital(name="Clinexa Hospital",code="CLINEXA",address="Development hospital");db.add(hospital);db.flush()
        role=db.scalar(select(Role).where(Role.name=="Super Administrator"))
        if not role: role=Role(name="Super Administrator",description="Full Clinexa administrator");db.add(role);db.flush()
        perms=[]
        for code in PERMISSIONS:
            p=db.scalar(select(Permission).where(Permission.code==code))
            if not p: p=Permission(code=code,description=code);db.add(p);db.flush()
            perms.append(p)
        role.permissions=perms
        user=User(email=email,full_name=name,password_hash=hash_password(password),hospital_id=hospital.id,is_active=True,is_verified=True,is_staff=True);user.roles.append(role);db.add(user);db.flush();db.add(UserAccountProfile(user_id=user.id,account_type="hospital_administrator",approval_status="approved",approved_by_user_id=user.id));db.commit();print("Administrator created successfully.")
    finally: db.close()
if __name__=="__main__": main()
