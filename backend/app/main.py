import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles

from .routers import auth, predictions, pricing, profile, sales, waste, weather

app = FastAPI(title="PADAN API", version="0.1.0")

# Production: isi ALLOWED_ORIGINS dengan domain frontend (koma-pisah).
# Default "*" agar dev lokal (web/mobile) tetap jalan tanpa config.
_cors_origins = [
    o.strip()
    for o in os.environ.get("ALLOWED_ORIGINS", "*").split(",")
    if o.strip()
]

# Izinkan semua origin untuk development lokal (Flutter web/desktop/mobile)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(weather.router)
app.include_router(sales.router)
app.include_router(predictions.router)
app.include_router(waste.router)
app.include_router(pricing.router)
app.include_router(profile.router)

# Serve file upload: foto menu (/sales/.../photo) & avatar (/profile/avatar).
# Satu-satunya mount /uploads (duplikatnya sudah dibersihkan).
_uploads_dir = Path(__file__).resolve().parents[1] / "uploads"
_uploads_dir.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(_uploads_dir)), name="uploads")


@app.get("/")
def root():
    return {"message": "PADAN API - Selaraskan Pangan, Cegah Sisa"}


@app.head("/", include_in_schema=False)
def root_head():
    # Untuk monitor keep-alive (UptimeRobot dkk) yang memakai HEAD.
    return Response(status_code=200)