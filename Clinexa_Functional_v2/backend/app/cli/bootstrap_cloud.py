"""Create the first cloud owner once. Never reset or elevate existing accounts."""
import os
from pathlib import Path

from dotenv import dotenv_values
from pydantic import EmailStr, TypeAdapter
from sqlalchemy import select

from app.cli.create_admin import PERMISSIONS
from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models.account import UserAccountProfile
from app.models.organization import Hospital
from app.models.rbac import Permission, Role
from app.models.user import User


def bootstrap_admin():
    values = dotenv_values(Path.cwd() / ".env")

    def setting(key, default=""):
        return os.environ.get(key, values.get(key) or default)

    with SessionLocal.begin() as db:
        owner = db.scalar(
            select(User.id).join(User.roles).where(Role.name == "Super Administrator").limit(1)
        )
        if owner:
            print("Cloud owner already exists; credentials were not changed.")
            return

        email = str(TypeAdapter(EmailStr).validate_python(setting("BOOTSTRAP_ADMIN_EMAIL"))).lower()
        password = setting("BOOTSTRAP_ADMIN_PASSWORD")
        name = setting("BOOTSTRAP_ADMIN_NAME", "Clinexa Owner").strip()
        if len(password) < 16 or not name:
            raise RuntimeError("Initial cloud owner requires a name and a strong password of at least 16 characters.")
        if db.scalar(select(User.id).where(User.email == email)):
            raise RuntimeError("Bootstrap email belongs to an existing account; automatic promotion is refused.")

        hospital = db.scalar(select(Hospital).where(Hospital.code == "CLINEXA"))
        if hospital is None:
            hospital = Hospital(name="Clinexa Hospital", code="CLINEXA")
            db.add(hospital)
            db.flush()
        role = db.scalar(select(Role).where(Role.name == "Super Administrator"))
        if role is None:
            role = Role(name="Super Administrator", description="Clinexa cloud owner")
            db.add(role)
            db.flush()
        permissions = []
        for code in PERMISSIONS:
            permission = db.scalar(select(Permission).where(Permission.code == code))
            if permission is None:
                permission = Permission(code=code, description=code)
                db.add(permission)
                db.flush()
            permissions.append(permission)
        role.permissions = permissions
        user = User(
            email=email, full_name=name, password_hash=hash_password(password),
            hospital_id=hospital.id, is_active=True, is_verified=True, is_staff=True,
        )
        user.roles.append(role)
        db.add(user)
        db.flush()
        db.add(UserAccountProfile(
            user_id=user.id, account_type="hospital_administrator",
            approval_status="approved", approved_by_user_id=user.id,
        ))
    print("Initial cloud owner created. No demo accounts or patient records were imported.")


if __name__ == "__main__":
    bootstrap_admin()
