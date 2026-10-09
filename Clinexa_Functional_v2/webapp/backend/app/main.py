from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import get_settings
from app.api.routes import system,auth,patients,doctors,appointments,records,documents,communications,operations,ai,admin,advanced,portal,doctor_portal,care_tasks,clinical_workspace,lab_workspace,session_security,mfa,recovery,privacy
from app.core.rate_limit import middleware as rate_limit
settings=get_settings()
app=FastAPI(title="Clinexa API",version="9.0.0",description="Clinexa healthcare and hospital management API")
app.middleware("http")(rate_limit)
app.add_middleware(CORSMiddleware,allow_origins=settings.cors_origins_list,allow_credentials=True,allow_methods=["*"],allow_headers=["*"])
@app.middleware("http")
async def security_headers(request,call_next):
    response=await call_next(request)
    response.headers["X-Content-Type-Options"]="nosniff"
    response.headers["X-Frame-Options"]="DENY"
    response.headers["Referrer-Policy"]="strict-origin-when-cross-origin"
    response.headers["Cache-Control"]="no-store, no-cache, must-revalidate"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self' blob:; "
        "img-src 'self' data: https: blob:; "
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: https:; "
        "style-src 'self' 'unsafe-inline' https:; "
        "font-src 'self' data: https:; "
        "connect-src 'self' http: https: ws: wss:; "
        "frame-ancestors 'none';"
    )
    proto = request.headers.get("x-forwarded-proto", request.url.scheme)
    if proto == "https":
        response.headers["Strict-Transport-Security"]="max-age=31536000; includeSubDomains"
    return response
app.include_router(system.router)
for router in [auth.router,patients.router,doctors.router,appointments.router,records.router,documents.router,communications.router,operations.router,ai.router,admin.router,advanced.router,portal.router,doctor_portal.router,care_tasks.router,clinical_workspace.router,lab_workspace.router,session_security.router,mfa.router,recovery.router,privacy.router]:
    app.include_router(router,prefix=settings.API_V1_PREFIX)

from pathlib import Path
from fastapi.staticfiles import StaticFiles

# Candidate directories for web frontend:
candidate_dirs = [
    Path(__file__).resolve().parent.parent.parent / "frontend",
    Path(__file__).resolve().parent.parent / "frontend",
    Path(__file__).resolve().parent.parent.parent / "frontend" / "build" / "web",
]
web_dir = next((d for d in candidate_dirs if d.is_dir() and (d / "index.html").is_file()), None)

if web_dir:
    app.mount("/", StaticFiles(directory=str(web_dir), html=True), name="frontend")
else:
    @app.get("/")
    def root(): return {"name": "Clinexa", "version": "9.0.0", "docs": "/docs"}
