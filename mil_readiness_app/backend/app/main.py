from fastapi import FastAPI, Depends, HTTPException
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import text
from .database import engine, get_db
from .routers import auth, readiness
from . import models

# Create tables on startup (Basic migration alternative)
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Project ATLAS Backend",
    description="Defense-grade readiness monitoring API",
    version="1.0.0"
)

# Register Routers
app.include_router(auth.router)
app.include_router(readiness.router)

# Mount Dashboard Static Files
import os
dashboard_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "dashboard")
if os.path.exists(dashboard_path):
    app.mount("/dashboard", StaticFiles(directory=dashboard_path, html=True), name="dashboard")
else:
    print(f"Warning: Dashboard path not found: {dashboard_path}")

@app.get("/")
def read_root():
    return {"message": "Project ATLAS Backend System online", "status": "nominal"}

@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        # Test database connection
        db.execute(text('SELECT 1'))
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")
