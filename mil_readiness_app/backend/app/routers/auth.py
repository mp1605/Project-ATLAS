from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from .. import schemas, models, auth
from ..database import get_db

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["authentication"]
)

@router.post("/login", response_model=schemas.Token)
def login_for_access_token(user_data: schemas.UserCreate, db: Session = Depends(get_db)):
    # This is "Admin/User Login"
    # In a real app we'd use OAuth2FormRequest, but JSON is requested by user plan
    user = db.query(models.User).filter(models.User.email == user_data.email).first()
    if not user:
        # Check if this is the FIRST user ever (Bootstrap Admin)
        count = db.query(models.User).count()
        if count == 0:
            print(f"⚠️ Bootstrapping First Admin: {user_data.email}")
            user = models.User(
                email=user_data.email,
                hashed_password=auth.get_password_hash(user_data.password),
                full_name="System Admin",
                role="admin"
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            raise HTTPException(status_code=401, detail="Incorrect email or password")
    elif not auth.verify_password(user_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    
    access_token = auth.create_access_token(
        data={"sub": user.email, "role": user.role, "user_id": user.id}
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/register", response_model=schemas.Token)
def register_admin(user_data: schemas.UserCreate, db: Session = Depends(get_db)):
    # Dashboard "Sign Up" flow
    # Check if exists
    user = db.query(models.User).filter(models.User.email == user_data.email).first()
    if user:
         raise HTTPException(status_code=400, detail="Email already registered")
    
    # Create new Admin/User
    # Note: For prototype, we allow self-registration as ADMIN
    new_user = models.User(
        email=user_data.email,
        hashed_password=auth.get_password_hash(user_data.password),
        full_name=user_data.full_name or "New Admin",
        role="admin" # Force admin for dashboard users
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    access_token = auth.create_access_token(
        data={"sub": new_user.email, "role": new_user.role, "user_id": new_user.id}
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/device-login", response_model=schemas.Token)
def device_login(device_req: schemas.DeviceLoginRequest, db: Session = Depends(get_db)):
    # "Device Login" flow
    # 1. Check if device exists
    # 2. If valid, return long-lived token
    
    # Note: Logic depends on how strict we want to be.
    # Plan says: "input: { email, deviceId } ... output: DEVICE JWT"
    
    # Check if we know this user
    user = None
    if device_req.email:
        user = db.query(models.User).filter(models.User.email == device_req.email).first()
        
    if not user:
        # Auto-create an "Anonymous Device User" if not found
        # This ensures the device login always succeeds for the prototype
        print(f"⚠️ User {device_req.email} not found. Creating anonymous user.")
        user = models.User(
            email=device_req.email or f"device_{device_req.device_id[:8]}@atlas.local",
            full_name=device_req.full_name or "Anonymous Device",
            role="soldier"
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        # Update existing user name if provided and not set
        if device_req.full_name and (user.full_name == "Anonymous Device" or not user.full_name):
            user.full_name = device_req.full_name
            db.commit()

    # Check/Register Device
    device = db.query(models.Device).filter(models.Device.device_id == device_req.device_id).first()
    if not device:
        # Register new device
        device = models.Device(
            device_id=device_req.device_id,
            user_id=user.id,
            label="Mobile Device"
        )
        db.add(device)
        db.commit()
        db.refresh(device)
    
    if not device.is_approved:
        raise HTTPException(status_code=403, detail="Device not approved")

    # Create token
    token = auth.create_device_token(device.device_id, user.id)
    return {"access_token": token, "token_type": "bearer"}
