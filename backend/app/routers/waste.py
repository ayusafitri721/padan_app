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
    """Ringkasan limbah murni dari data nyata daily_sales.

    Tanpa angka dummy: akun tanpa data mendapat has_data=False agar
    Flutter menampilkan empty state, bukan angka karangan.
    """
    today = date.today()

    all_sales = db.query(DailySales).filter(DailySales.user_id == user_id).all()

    if not all_sales:
        return {
            "has_data": False,
            "financial_cumulative_idr": 0,
            "month_saved_portions": 0,
            "co2_reduced_kg": 0.0,
            "waste_reduction_percent": 0,
            "chart": [],
            "insight": "Belum ada data penjualan. Catat penjualan harian di tab Stok agar ringkasan limbah terisi otomatis.",
            "level_label": "Pejuang Pangan",
            "audit_count": 0,
        }

    # Harga asli per menu (fallback ke rata-rata bila menu belum punya harga)
    prices = {
        m.id: (m.price if m.price and m.price > 0 else AVG_PRICE_PER_PORTION)
        for m in db.query(Menu).filter(Menu.user_id == user_id).all()
    }

    # Hitung real dari DB: waste = remaining, saved = sold. Group by month
    from collections import defaultdict

    monthly_waste_kg: dict[str, float] = defaultdict(float)
    monthly_saved: dict[str, int] = defaultdict(int)
    financial = 0

    for ds in all_sales:
        key = _month_key(ds.date)
        items = db.query(DailySalesItem).filter(DailySalesItem.daily_sales_id == ds.id).all()
        for it in items:
            waste = max(0, it.remaining_portions)
            monthly_waste_kg[key] += waste * KG_PER_PORTION
            monthly_saved[key] += it.sold_portions
            financial += it.sold_portions * prices.get(it.menu_id, AVG_PRICE_PER_PORTION)

    # Ambil 4 bulan terakhir termasuk bulan ini (hanya bulan yang ada datanya
    # yang tampil; tidak ada suntikan angka dummy)
    chart = []
    id_labels = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agt", "Sep", "Okt", "Nov", "Des"]
    for i in range(3, -1, -1):
        y = today.year
        m = today.month - i
        while m <= 0:
            m += 12
            y -= 1
        key = f"{y:04d}-{m:02d}"
        if key not in monthly_waste_kg:
            continue
        chart.append({
            "label": id_labels[m - 1],
            "month_year": key,
            "waste_kg": round(monthly_waste_kg[key], 1),
        })

    total_saved = sum(monthly_saved.values())
    total_waste_kg = sum(monthly_waste_kg.values())
    co2 = round(total_waste_kg * CO2_PER_KG, 1)

    # Persen penurunan limbah (bulan pertama vs terakhir yang ada datanya)
    if len(chart) >= 2 and chart[0]["waste_kg"] > 0:
        first = chart[0]["waste_kg"]
        last = chart[-1]["waste_kg"]
        reduction = int(round((last - first) / first * 100))
    else:
        reduction = 0

    this_key = _month_key(today)
    month_saved = monthly_saved.get(this_key, 0)

    audit_count = db.query(DailySales).filter(DailySales.user_id == user_id, DailySales.status == "final").count()
    if audit_count == 0:
        audit_count = len(all_sales)
    if reduction <= -75:
        level = "Bebas Mubazir Level 3"
    elif reduction <= -40:
        level = "Bebas Mubazir Level 2"
    elif reduction <= -15:
        level = "Bebas Mubazir Level 1"
    else:
        level = "Pejuang Pangan"

    return {
        "has_data": True,
        "financial_cumulative_idr": financial,
        "month_saved_portions": month_saved,
        "co2_reduced_kg": co2,
        "waste_reduction_percent": reduction,
        "chart": chart,
        "insight": (
            "Porsi over-produksi berkurang berkat kalkulator porsi otomatis BMKG & Hari Libur."
            if reduction < 0
            else "Terus catat penjualan harian agar tren limbah menurun dari bulan ke bulan."
        ),
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
