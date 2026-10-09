from pydantic import BaseModel, EmailStr, Field

ACCOUNT_TYPES = {
    "patient", "doctor", "nurse", "receptionist", "lab_technician",
    "pharmacist", "hospital_administrator", "billing_staff", "support_staff", "caregiver",
}


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=200)
    email: EmailStr
    password: str = Field(min_length=10, max_length=128)
    account_type: str = "patient"
    specialty: str | None = Field(default=None, max_length=160)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    account_type: str | None = None


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserView(BaseModel):
    id: str
    full_name: str
    email: EmailStr
    is_staff: bool
    hospital_id: str | None
    permissions: list[str] = []
    roles: list[str]
    account_type: str | None = None
    approval_status: str | None = None
