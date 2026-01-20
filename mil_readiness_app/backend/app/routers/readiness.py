from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, desc
from .. import schemas, models, auth
from ..database import get_db
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from ..config import settings
from .auth import router as auth_router

router = APIRouter(
    prefix="/api/v1/readiness",
    tags=["readiness"]
)

# Reusable dependency for token verification
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def get_current_user_id(token: str = Depends(oauth2_scheme)):
    try:
        print(f"🔎 Validating Token: {token[:10]}...")
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        user_id: int = payload.get("user_id")
        role: str = payload.get("role")
        print(f"✅ Token Valid. User: {user_id}, Role: {role}")
        
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        return user_id, role
    except JWTError as e:
        print(f"❌ JWT Validation Failed: {e}")
        raise HTTPException(status_code=401, detail="Could not validate credentials")

@router.get("/users")
def get_dashboard_summary(
    db: Session = Depends(get_db),
    auth_info: tuple = Depends(get_current_user_id)
):
    # Returns list of users with their LATEST score
    # Used by dashboard.js
    
    # Logic: Get unique users from ReadinessScores, or all users?
    # Better: Get all users who have scores, + their latest score.
    
    subquery = db.query(
        models.ReadinessScore.user_id,
        func.max(models.ReadinessScore.timestamp).label("max_ts")
    ).group_by(models.ReadinessScore.user_id).subquery()
    
    latest_scores = db.query(models.ReadinessScore).join(
        subquery,
        (models.ReadinessScore.user_id == subquery.c.user_id) & 
        (models.ReadinessScore.timestamp == subquery.c.max_ts)
    ).all()
    
    results = []
    for score in latest_scores:
        user = db.query(models.User).filter(models.User.id == score.user_id).first()
        email = user.email if user else "Unknown"
        
        results.append({
            "user_id": email, # Dashboard expects email as ID string
            "latest_score": score.overall_score,
            "latest_submission": score.timestamp
        })
        
    return {"users": results}

@router.get("/{user_id}/latest", response_model=schemas.ReadinessScoreOut)
def get_latest_user_score(
    user_id: str,
    db: Session = Depends(get_db),
    auth_info: tuple = Depends(get_current_user_id)
):
    # Resolve email to ID
    user = db.query(models.User).filter(models.User.email == user_id).first()
    if not user:
        if user_id.isdigit():
             user = db.query(models.User).filter(models.User.id == int(user_id)).first()
    
    target_id = user.id if user else None
    
    if not target_id:
         raise HTTPException(status_code=404, detail="User not found")
         
    score = db.query(models.ReadinessScore)\
        .filter(models.ReadinessScore.user_id == target_id)\
        .order_by(desc(models.ReadinessScore.timestamp))\
        .first()
        
    if not score:
        raise HTTPException(status_code=404, detail="No scores found for this user")
        
    return score

@router.post("", response_model=schemas.ReadinessScoreOut, status_code=201)
def submit_readiness(
    score_data: schemas.ReadinessScoreCreate, 
    db: Session = Depends(get_db),
    auth_info: tuple = Depends(get_current_user_id)
):
    user_id, role = auth_info
    
    # Enforce role permissions: Only "device" (or admin) can submit
    # "DEVICE token can only: POST /api/v1/readiness"
    if role not in ["device", "admin", "soldier"]:
         raise HTTPException(status_code=403, detail="Unauthorized role")

    # "Add raw-data detection (denylist)"
    # We check the 'scores' dict for forbidden keys
    forbidden_keys = ["samples", "series", "ecg", "raw_oxygen"]
    for key in score_data.scores.keys():
        if any(bad in key.lower() for bad in forbidden_keys):
             print(f"SECURITY ALERT: Raw data rejected: {key}")
             raise HTTPException(status_code=403, detail="Raw data submission rejected")

    # Save to DB
    new_score = models.ReadinessScore(
        user_id=user_id,
        timestamp=score_data.timestamp,
        overall_score=score_data.overall_score,
        confidence=score_data.confidence,
        data=score_data.scores
    )
    db.add(new_score)
    db.commit()
    db.refresh(new_score)
    
    return new_score

@router.get("/history", response_model=list[schemas.ReadinessScoreOut])
def get_history(
    user_id_param: str = None, 
    db: Session = Depends(get_db),
    auth_info: tuple = Depends(get_current_user_id)
):
    current_user_id, role = auth_info
    
    # "DEVICE token cannot read history"
    if role == "device":
        raise HTTPException(status_code=403, detail="Devices cannot read history")
        
    # If admin, can read anyone (if user_id_param provided)
    target_id = current_user_id
    if role == "admin" and user_id_param:
        # TODO: Lookup user ID from string param if needed
        pass 
        
    scores = db.query(models.ReadinessScore).filter(models.ReadinessScore.user_id == target_id).all()
    return scores
