from typing import Optional, Any, Dict
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime

# --- Token Schemas ---
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None
    role: Optional[str] = None

# --- User Schemas ---
class UserBase(BaseModel):
    email: EmailStr

class UserCreate(UserBase):
    password: str
    full_name: Optional[str] = None
    role: str = "soldier"

class UserOut(UserBase):
    id: int
    full_name: Optional[str] = None
    role: str
    is_active: bool
    created_at: datetime

    class Config:
        orm_mode = True

# --- Device Auth Schemas ---
class DeviceLoginRequest(BaseModel):
    device_id: str
    email: Optional[str] = None # Optional for linking first time?
    full_name: Optional[str] = None # Name from phone settings/profile

# --- Readiness Data Schema (Computed Only Contract) ---
class ReadinessScoreCreate(BaseModel):
    # Enforce exactly computed keys, reject raw
    timestamp: datetime
    overall_score: float
    confidence: str
    scores: Dict[str, Any] # Detailed breakdown matches JSON structure
    
    # "reject if payload contains banned keys" - logical check will be in router

class ReadinessScoreOut(ReadinessScoreCreate):
    id: int
    created_at: datetime
    user_id: int
    
    # Map 'data' from DB to 'scores' in JSON
    # This overrides the 'scores' field from ReadinessScoreCreate
    scores: Dict[str, Any] = Field(..., validation_alias="data", alias="scores")

    class Config:
        orm_mode = True
        populate_by_name = True
