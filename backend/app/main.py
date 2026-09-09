import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .routers import auth, predictions, pricing, profile, sales, waste, weather

app = FastAPI(title="PADAN API", version="0.1.0")

# Izinkan semua origin untuk development lokal (Flutter web/desktop/mobile)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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