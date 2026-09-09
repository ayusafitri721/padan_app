from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .routers import auth, predictions, pricing, sales, waste, weather

app = FastAPI(title="PADAN API", version="0.1.0")

# Foto menu yang diupload (lihat sales.UPLOAD_DIR). check_dir=False agar
# server tetap jalan walau folder belum ada (dibuat saat upload pertama).
app.mount(
    "/uploads",
    StaticFiles(directory=str(sales.UPLOAD_DIR), check_dir=False),
    name="uploads",
)

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


@app.get("/")
def root():
    return {"message": "PADAN API - Selaraskan Pangan, Cegah Sisa"}