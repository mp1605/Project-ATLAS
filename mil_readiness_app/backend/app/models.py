from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text, JSON, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=True) # Nullable for device-only users if needed
    full_name = Column(String, nullable=True)
    role = Column(String, default="soldier") # soldier, admin, commander
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    scores = relationship("ReadinessScore", back_populates="user")
    devices = relationship("Device", back_populates="user")
    audit_logs = relationship("AuditLog", back_populates="actor")

class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, unique=True, index=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"))
    label = Column(String, nullable=True) # e.g. "iPhone 13"
    last_seen_at = Column(DateTime(timezone=True), server_default=func.now())
    is_approved = Column(Boolean, default=True)

    user = relationship("User", back_populates="devices")

class ReadinessScore(Base):
    __tablename__ = "readiness_scores"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    
    # Core stored as JSONB for flexibility, with specific columns for query speed if needed
    # Plan: "Use JSONB for scores bundle"
    data = Column(JSON, nullable=False) 
    
    # Metadata for quick filtering
    overall_score = Column(Float, nullable=True)
    confidence = Column(String, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="scores")

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    actor_id = Column(Integer, ForeignKey("users.id"), nullable=True) # User who performed action
    action = Column(String, nullable=False) # e.g. "VIEW_HISTORY", "EXPORT_DATA"
    target_resource = Column(String, nullable=True) # e.g. "soldier:123"
    details = Column(JSON, nullable=True)
    ip_address = Column(String, nullable=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())

    actor = relationship("User", back_populates="audit_logs")
