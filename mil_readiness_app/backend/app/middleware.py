from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from .database import SessionLocal
from . import models, auth
from .routers.readiness import oauth2_scheme, get_current_user_id
from jose import jwt
from .config import settings

class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Proceed with request
        response = await call_next(request)
        
        # Only log write operations or critical reads
        # Skip OPTIONS (CORS) and standard GETs to reduce noise (unless it's critical like /history)
        if request.method in ["POST", "PUT", "DELETE"]:
            await self.log_action(request, response)
            
        return response

    async def log_action(self, request: Request, response):
        try:
            # Create a new DB session for logging independent of the request session
            db = SessionLocal()
            
            # Attempt to identify actor from Authorization header
            actor_id = None
            auth_header = request.headers.get("Authorization")
            if auth_header and auth_header.startswith("Bearer "):
                token = auth_header.split(" ")[1]
                try:
                    payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
                    actor_id = payload.get("user_id")
                except:
                    pass # Token invalid or expired, log as anonymous
            
            # Construct log entry
            log = models.AuditLog(
                actor_id=actor_id,
                action=f"{request.method} {request.url.path}",
                target_resource=str(request.url.path),
                ip_address=request.client.host,
                details={
                    "status_code": response.status_code,
                    "user_agent": request.headers.get("user-agent")
                }
            )
            
            db.add(log)
            db.commit()
            db.close()
            
        except Exception as e:
            print(f"⚠️ Audit Logging Failed: {e}")
