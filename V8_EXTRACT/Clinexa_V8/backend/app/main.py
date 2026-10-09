from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import get_settings
from app.api.routes import system,auth,patients,doctors,appointments,records,documents,communications,operations,ai,admin,advanced,portal,doctor_portal,care_tasks
settings=get_settings()
app=FastAPI(title="Clinexa API",version="8.0.0",description="Clinexa healthcare and hospital management API")
app.add_middleware(CORSMiddleware,allow_origins=settings.cors_origins_list,allow_credentials=True,allow_methods=["*"],allow_headers=["*"])
@app.middleware("http")
async def security_headers(request,call_next):
    response=await call_next(request)
    response.headers["X-Content-Type-Options"]="nosniff"
    response.headers["X-Frame-Options"]="DENY"
    response.headers["Referrer-Policy"]="no-referrer"
    return response
app.include_router(system.router)
for router in [auth.router,patients.router,doctors.router,appointments.router,records.router,documents.router,communications.router,operations.router,ai.router,admin.router,advanced.router,portal.router,doctor_portal.router,care_tasks.router]:
    app.include_router(router,prefix=settings.API_V1_PREFIX)
@app.get("/")
def root(): return {"name":"Clinexa","version":"8.0.0","docs":"/docs"}
