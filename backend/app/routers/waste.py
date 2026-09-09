from datetime import date, timedelta
from calendar import monthrange

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
import io

from ..auth import get_current_user_id
from ..database import get_db
from ..models import DailySales, DailySalesItem, Menu

router = APIRouter(prefix="/api/v1/waste", tags=["waste"])

# Harga rata-rata per porsi untuk hitung rugi dicegah (fallback jika tidak ada harga menu)
AVG_PRICE_PER_PORTION = 15000  # Rp
KG_PER_PORTION = 0.35
CO2_PER_KG = 2.1  # kg CO2e per kg waste dicegah (estimasi)


def _month_key(d: date) -> str:
    return f"{d.year:04d}-{d.month:02d}"


@router.get("/summary")
def get_waste_summary(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """Ringkasan limbah: kalkulasi dari daily_sales vs target.
    Mengembalikan data sesuai spec md/limbah.md (kumulatif + 4 bulan chart).
    """
    today = date.today()

    # Ambil semua daily_sales user untuk kalkulasi — murni dari DB, tidak ada dummy
    all_sales = db.query(DailySales).filter(DailySales.user_id == user_id).all()

    # Hitung real dari DB: waste = remaining, saved = sold
    # Group by month
    from collections import defaultdict

    monthly_waste_kg: dict[str, float] = defaultdict(float)
    monthly_saved: dict[str, int] = defaultdict(int)

    for ds in all_sales:
        key = _month_key(ds.date)
        items = db.query(DailySalesItem).filter(DailySalesItem.daily_sales_id == ds.id).all()
        for it in items:
            waste = max(0, it.remaining_portions)
            monthly_waste_kg[key] += waste * KG_PER_PORTION
            monthly_saved[key] += it.sold_portions

    # Ambil 4 bulan terakhir termasuk bulan ini — murni DB (0 jika belum ada data)
    chart = []
    id_labels = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agt", "Sep", "Okt", "Nov", "Des"]
    for i in range(3, -1, -1):
        y = today.year
        m = today.month - i
        while m <= 0:
            m += 12
            y -= 1
        key = f"{y:04d}-{m:02d}"
        label = id_labels[m - 1]
        waste_kg = round(monthly_waste_kg.get(key, 0.0), 1)
        chart.append({"label": label, "month_year": key, "waste_kg": waste_kg})

    # Hitung financial kumulatif & emisi dari total saved — murni DB tanpa clamp dummy
    total_saved = sum(monthly_saved.values())
    total_waste_kg = sum(monthly_waste_kg.values())
    financial = total_saved * AVG_PRICE_PER_PORTION
    co2 = round(total_waste_kg * CO2_PER_KG, 1)

    # Persen penurunan limbah (bulan pertama vs terakhir) — 0 jika belum ada data
    first = chart[0]["waste_kg"] if chart else 0
    last = chart[-1]["waste_kg"] if chart else 0
    reduction = int(round((last - first) / first * 100)) if first else 0

    # Bulan ini saved — murni DB
    this_key = _month_key(today)
    month_saved = monthly_saved.get(this_key, 0)

    # Audit count & level dinamis — murni DB
    audit_count = db.query(DailySales).filter(DailySales.user_id == user_id, DailySales.status == "final").count()
    if audit_count == 0 and all_sales:
        audit_count = len(all_sales)
    # level berdasarkan reduction real; jika belum ada data → Pejuang Pangan
    if reduction <= -75:
        level = "Bebas Mubazir Level 3"
    elif reduction <= -40:
        level = "Bebas Mubazir Level 2"
    elif reduction <= -15:
        level = "Bebas Mubazir Level 1"
    else:
        level = "Pejuang Pangan" if all_sales else "Pejuang Pangan"

    # Insight dinamis berhubungan dengan data
    if not all_sales:
        insight = "Belum ada data penjualan — mulai catat penjualan harian agar audit limbah terbentuk."
    elif reduction <= -30:
        insight = "Porsi over-produksi berkurang drastis berkat kalkulator porsi otomatis BMKG & Hari Libur."
    elif total_waste_kg > 5:
        insight = "Limbah masih terdeteksi — aktifkan Dynamic Pricing di tab Harga untuk kurangi sisa >3 porsi."
    else:
        insight = "Performa stabil — pertahankan pencatatan harian untuk jaga tren penurunan limbah."

    return {
        "financial_cumulative_idr": financial,
        "month_saved_portions": month_saved,
        "co2_reduced_kg": co2,
        "waste_reduction_percent": reduction,
        "chart": chart,
        "insight": insight,
        "level_label": level,
        "audit_count": audit_count,
    }


@router.get("/download-report")
def download_report(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """Kembalikan PDF placeholder (1 halaman) untuk Laporan Lengkap Food Waste."""
    # Minimal PDF 1 halaman (agar bisa diunduh & dibuka)
    pdf_bytes = (
        b"%PDF-1.4\n1 0 obj<< /Type /Catalog /Pages 2 0 R>>endobj\n"
        b"2 0 obj<< /Type /Pages /Kids [3 0 R] /Count 1>>endobj\n"
        b"3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        b"/Contents 4 0 R /Resources << /Font << /F1 5 0 R>>>>>>endobj\n"
        b"4 0 obj<< /Length 120>>stream\nBT /F1 14 Tf 40 780 Td (PADAN - Laporan Food Waste) Tj "
        b"0 -30 Td (Rekap bulanan - Bebas Mubazir) Tj ET\nendstream endobj\n"
        b"5 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica>>endobj\n"
        b"xref\n0 6\n0000000000 65535 f \n0000000009 00000 n \n0000000056 00000 n \n"
        b"0000000111 00000 n \n0000000315 00000 n \n0000000489 00000 n \n"
        b"trailer<< /Size 6 /Root 1 0 R>>\nstartxref\n580\n%%EOF"
    )
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=padan-laporan-limbah.pdf"},
    )
