from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..auth import get_current_user_id
from ..database import get_db
from ..geocode import resolve_adm4
from ..models import DailySales, DailySalesItem, Menu, PredictionPlan
from .. import schemas
from .weather import build_weather_payload

router = APIRouter(prefix="/api/v1/predictions", tags=["predictions"])

DEFAULT_ADM4 = "31.71.03.1001"  # Kemayoran, Jakarta Pusat

HARI_INDONESIA = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]

SEMINGGU: dict[int, int] = {
    0: 2,   # Senin
    1: 3,   # Selasa
    2: 4,   # Rabu
    3: 5,   # Kamis
    4: 6,   # Jumat (+ tren puncak akhir pekan)
    5: 5,   # Sabtu
    6: 3,   # Minggu
}

BASE_BAKER = {
    "Makanan Utama": [
        {"name": "Beras Pulen", "unit": "kg", "per_portion": 0.15},
        {"name": "Telur Ayam", "unit": "butir", "per_portion": 1.0},
        {"name": "Daging Ayam", "unit": "kg", "per_portion": 0.08},
        {"name": "Minyak Goreng", "unit": "L", "per_portion": 0.015},
    ],
    "Mie & Bakso": [
        {"name": "Mie Basah", "unit": "kg", "per_portion": 0.12},
        {"name": "Bakso Sapi", "unit": "butir", "per_portion": 5.0},
        {"name": "Daging Sapi Cincang", "unit": "kg", "per_portion": 0.05},
    ],
    "Minuman": [
        {"name": "Teh Celup", "unit": "selop", "per_portion": 1.0},
        {"name": "Gula Pasir", "unit": "kg", "per_portion": 0.02},
        {"name": "Es Batu", "unit": "kg", "per_portion": 0.15},
    ],
    "Camilan": [
        {"name": "Tepung Terigu", "unit": "kg", "per_portion": 0.08},
        {"name": "Telur Ayam", "unit": "butir", "per_portion": 0.5},
        {"name": "Minyak Goreng", "unit": "L", "per_portion": 0.02},
    ],
    "Dessert": [
        {"name": "Tepung Terigu", "unit": "kg", "per_portion": 0.06},
        {"name": "Gula Pasir", "unit": "kg", "per_portion": 0.03},
        {"name": "Margarin", "unit": "kg", "per_portion": 0.02},
    ],
    "Lainnya": [
        {"name": "Bahan Pokok Campuran", "unit": "kg", "per_portion": 0.1},
        {"name": "Bumbu & Saus", "unit": "porsi", "per_portion": 1.0},
    ],
}


class PredictionFactorOut(BaseModel):
    key: str
    label: str
    description: str
    delta: int
    icon: str


class IngredientOut(BaseModel):
    name: str
    quantity: float
    unit: str
    low_stock: bool


class PredictionDetailOut(BaseModel):
    menu_id: int
    menu_name: str
    sku: str
    category: str
    accuracy_score: float
    prediction_date: str
    target_time: str
    recommended_portions: int
    safe_low: int
    safe_sweet: int
    safe_high: int
    co2e_saved_kg: float
    weather_location: str = ""  # lokasi BMKG yang dipakai faktor cuaca
    factors: list[PredictionFactorOut]
    ingredients: list[IngredientOut]


def _make_sku(menu_name: str, menu_id: int) -> str:
    words = [w for w in menu_name.replace("-", " ").split() if w]
    if not words:
        prefix = "MN"
    elif len(words) == 1:
        prefix = words[0][:2].upper()
    else:
        prefix = (words[0][:1] + words[1][:1]).upper()
    return f"SKU #{prefix}-{menu_id:02d}"


def _avg_sold_last_week(db: Session, user_id: int, menu_id: int) -> float:
    """Rata-rata porsi terjual menu ini pada 7 hari terakhir (eksklusif hari ini)."""
    today = date.today()
    start = today - timedelta(days=7)
    rows = (
        db.query(DailySalesItem.sold_portions)
        .join(DailySales, DailySales.id == DailySalesItem.daily_sales_id)
        .filter(
            DailySales.user_id == user_id,
            DailySalesItem.menu_id == menu_id,
            DailySales.date >= start,
            DailySales.date < today,
        )
        .all()
    )
    if not rows:
        return 0.0
    return sum(r[0] for r in rows) / len(rows)


def _resolve_weather_adm4(
    adm4: str | None, lat: float | None, lon: float | None
) -> str:
    """Tentukan kode adm4 BMKG dari query.

    Prioritas: adm4 eksplisit > lat/lon device > default Kemayoran.
    Selalu fallback ke default agar klien lama tidak rusak.
    """
    if adm4:
        return adm4
    if lat is not None and lon is not None:
        resolved = resolve_adm4(lat, lon)
        if resolved:
            return resolved
    return DEFAULT_ADM4


def _weather_factor(adm4: str = DEFAULT_ADM4) -> tuple[int, str, str]:
    """Faktor cuaca BMKG real-time (dengan fallback default bila gagal).

    Mengembalikan (delta, deskripsi, lokasi).
    """
    try:
        data = build_weather_payload(adm4)
        condition = data.get("condition", "").lower()
        temp = data.get("temperature", 0)
        lokasi = data.get("lokasi", "")
        if "hujan" in condition:
            delta, desc = -3, "Hujan turun, kurangi porsi ekstra"
        elif "cerah" in condition and temp >= 30:
            delta, desc = 3, f"Cerah {temp}°C, dorong kunjungan siang & sore"
        elif "berawan" in condition:
            delta, desc = 1, "Berawan, kunjungan cenderung stabil"
        else:
            delta, desc = 2, f"Kondisi {condition.title()} {temp}°C, cukup bersahabat"
        if lokasi:
            desc = f"{desc} — berdasarkan cuaca {lokasi}"
        return delta, desc, lokasi
    except Exception:  # noqa: BLE001
        return 1, "Prakiraan cuaca tidak memengaruhi signifikan", ""


def _weekday_factor(target_date: date) -> tuple[int, str]:
    nama_hari = HARI_INDONESIA[target_date.weekday()]
    delta = SEMINGGU[target_date.weekday()]
    return delta, f"Pola kunjungan {nama_hari} cenderung stabil sepanjang hari"


def _event_factor(target_date: date) -> tuple[int, str]:
    """Faktor event eksternal bila ada (contoh demo lokasi GBK)."""
    # Basis sederhana: akhir pekan = peluang event lokal naik.
    if target_date.weekday() >= 5:
        return 3, "Event lokal akhir pekan disekitar lokasi (estimasi)"
    return 0, "Tidak ada event besar terjadwal hari itu"


def _leftover_factor(db: Session, user_id: int, menu_id: int) -> int:
    """Sisa kemarin = target - terjual hari kemarin untuk menu ini."""
    yesterday = date.today() - timedelta(days=1)
    row = (
        db.query(DailySales)
        .filter(DailySales.user_id == user_id, DailySales.date == yesterday)
        .first()
    )
    if not row:
        return 0
    items = (
        db.query(DailySalesItem)
        .filter(DailySalesItem.daily_sales_id == row.id, DailySalesItem.menu_id == menu_id)
        .first()
    )
    if not items:
        return 0
    return items.remaining_portions


class PredictionTodayItemOut(BaseModel):
    menu_id: int
    menu_name: str
    category: str
    accuracy_score: float
    recommended_portions: int
    safe_low: int
    safe_high: int
    reason: str  # deskripsi faktor dominan (untuk kartu dashboard)


def _recommendation(
    db: Session, user_id: int, menu: Menu, target_date: date, w_delta: int
) -> tuple[int, int, int, dict[str, int]]:
    """Inti formula prediksi, dipakai /detail dan /today agar konsisten.

    Mengembalikan (sweet, low, high, deltas_per_faktor).
    """
    today = date.today()
    wk_delta, _ = _weekday_factor(target_date)
    ev_delta, _ = _event_factor(target_date)
    leftovers = _leftover_factor(db, user_id, menu.id)
    lf_delta = -min(leftovers, 4)  # sedot koreksi hingga -4 porsi

    # Akurasi model dari riwayat menu (0-100) → bobot koreksi.
    accuracy = float(menu.accuracy or 70)
    base = float(menu.target_portions)

    # Rata-rata terjual 7 hari terakhir jadi acuan kalau memungkinkan.
    avg_last = _avg_sold_last_week(db, user_id, menu.id)
    if avg_last > 0 and today.weekday() == target_date.weekday() - 1:
        base = avg_last

    delta_total = w_delta + wk_delta + ev_delta + lf_delta
    sweet = int(round(base * (accuracy / 100.0) + delta_total))
    sweet = max(1, sweet)

    low = max(1, sweet - max(2, int(sweet * 0.05)))
    high = sweet + max(3, int(sweet * 0.08))
    return sweet, low, high, {
        "weekday": wk_delta,
        "event": ev_delta,
        "leftover": lf_delta,
        "leftover_count": leftovers,
    }
@router.get("/detail/{menu_id}", response_model=PredictionDetailOut)
def prediction_detail(
    menu_id: int,
    adm4: str | None = Query(
        None, description="Kode wilayah adm4 BMKG (dipakai jika diberikan)"
    ),
    lat: float | None = Query(
        None, description="Garis lintang device (dipakai jika adm4 tidak diberikan)"
    ),
    lon: float | None = Query(
        None, description="Garis bujur device (dipakai jika adm4 tidak diberikan)"
    ),
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    menu = (
        db.query(Menu)
        .filter(Menu.id == menu_id, Menu.user_id == user_id, Menu.is_active.is_(True))
        .first()
    )
    if not menu:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan.")

    target_date = date.today() + timedelta(days=1)
    today = date.today()

    weather_adm4 = _resolve_weather_adm4(adm4, lat, lon)
    w_delta, w_desc, w_lokasi = _weather_factor(weather_adm4)
    wk_delta, wk_desc = _weekday_factor(target_date)
    ev_delta, ev_desc = _event_factor(target_date)
    sweet, low, high, deltas = _recommendation(db, user_id, menu, target_date, w_delta)
    # Yang dikirim ke UI = riwayat asli (0 = belum ada riwayat); formula di
    # atas tetap pakai baseline 70 secara internal bila 0.
    raw_accuracy = float(menu.accuracy or 0)
    leftovers = deltas["leftover_count"]
    lf_delta = deltas["leftover"]
    lf_desc = (
        f"Mitigasi sisa kemarin {leftovers} porsi belum terserap"
        if leftovers > 0
        else "Tidak ada sisa kemarin yang perlu dikoreksi"
    )

    safe_sweet = sweet

    # Estimasi emisi karbon tersimpan (kg CO2e) vs masak berlebih.
    co2e = round((high - low) * 0.8 * (1.2 if menu.category == "Makanan Utama" else 1.0), 1)

    ingredients: list[IngredientOut] = []
    low_stock_flag = False
    baker = BASE_BAKER.get(menu.category, BASE_BAKER["Lainnya"])
    for i, recipe in enumerate(baker):
        qty = round(recipe["per_portion"] * safe_sweet, 2)
        low_stock = False
        if i == len(baker) - 1 and not low_stock_flag:
            low_stock = True
            low_stock_flag = True
        ingredients.append(
            IngredientOut(
                name=recipe["name"],
                quantity=qty,
                unit=recipe["unit"],
                low_stock=low_stock,
            )
        )

    factors: list[PredictionFactorOut] = [
        PredictionFactorOut(
            key="trend",
            label=f"Riwayat Tren {HARI_INDONESIA[target_date.weekday()]}",
            description=wk_desc,
            delta=wk_delta,
            icon="trending_up",
        ),
        PredictionFactorOut(
            key="weather",
            label="Cuaca BMKG Real-Time",
            description=w_desc,
            delta=w_delta,
            icon="wb_sunny",
        ),
        PredictionFactorOut(
            key="event",
            label="Event Eksternal Sekitar",
            description=ev_desc,
            delta=ev_delta,
            icon="celebration",
        ),
        PredictionFactorOut(
            key="leftover",
            label="Koreksi Sisa Kemarin",
            description=lf_desc,
            delta=lf_delta,
            icon="replay",
        ),
    ]

    return PredictionDetailOut(
        menu_id=menu.id,
        menu_name=menu.name,
        sku=_make_sku(menu.name, menu.id),
        category=menu.category,
        accuracy_score=raw_accuracy,
        prediction_date=target_date.strftime("%Y-%m-%d"),
        target_time="Malam",
        recommended_portions=safe_sweet,
        safe_low=low,
        safe_sweet=safe_sweet,
        safe_high=high,
        co2e_saved_kg=co2e,
        weather_location=w_lokasi,
        factors=factors,
        ingredients=ingredients,
    )


@router.get("/today", response_model=list[PredictionTodayItemOut])
def predictions_today(
    adm4: str | None = Query(
        None, description="Kode wilayah adm4 BMKG (dipakai jika diberikan)"
    ),
    lat: float | None = Query(
        None, description="Garis lintang device (dipakai jika adm4 tidak diberikan)"
    ),
    lon: float | None = Query(
        None, description="Garis bujur device (dipakai jika adm4 tidak diberikan)"
    ),
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """Ringkas rekomendasi semua menu aktif untuk kartu dashboard.

    Satu request (cuaca diambil sekali), bukan N request /detail.
    """
    menus = (
        db.query(Menu)
        .filter(Menu.user_id == user_id, Menu.is_active.is_(True))
        .order_by(Menu.id)
        .all()
    )
    if not menus:
        return []

    target_date = date.today() + timedelta(days=1)
    weather_adm4 = _resolve_weather_adm4(adm4, lat, lon)
    w_delta, w_desc, _ = _weather_factor(weather_adm4)
    wk_delta, wk_desc = _weekday_factor(target_date)
    ev_delta, ev_desc = _event_factor(target_date)

    items: list[PredictionTodayItemOut] = []
    for menu in menus:
        sweet, low, high, deltas = _recommendation(db, user_id, menu, target_date, w_delta)
        # Alasan = faktor dengan bobot absolut terbesar
        candidates = [
            (w_delta, w_desc),
            (wk_delta, wk_desc),
            (ev_delta, ev_desc),
            (deltas["leftover"], (
                f"Sisa kemarin {deltas['leftover_count']} porsi belum terserap"
                if deltas["leftover_count"] > 0
                else "Tidak ada sisa kemarin"
            )),
        ]
        reason = max(candidates, key=lambda c: abs(c[0]))[1]
        items.append(
            PredictionTodayItemOut(
                menu_id=menu.id,
                menu_name=menu.name,
                category=menu.category,
                accuracy_score=float(menu.accuracy or 0),
                recommended_portions=sweet,
                safe_low=low,
                safe_high=high,
                reason=reason,
            )
        )
    return items


@router.post("/plan", response_model=schemas.PredictionPlanOut, status_code=201)
def lock_plan(
    payload: schemas.PredictionPlanIn,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """Kunci & terapkan target masak untuk tanggal target (koreksi manual).

    Menutup loop: target menu ikut diperbarui ke locked_portions sehingga
    besok Stok/prediksi berangkat dari angka yang dikunci. Riwayat
    DailySalesItem tidak ikut berubah (snapshot saat pencatatan).
    """
    menu = (
        db.query(Menu)
        .filter(Menu.id == payload.menu_id, Menu.user_id == user_id, Menu.is_active.is_(True))
        .first()
    )
    if not menu:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan.")

    locked = max(0, payload.locked_portions)

    existing = (
        db.query(PredictionPlan)
        .filter(
            PredictionPlan.user_id == user_id,
            PredictionPlan.menu_id == payload.menu_id,
            PredictionPlan.plan_date == payload.plan_date,
        )
        .first()
    )
    if existing:
        existing.recommended_portions = max(0, payload.recommended_portions)
        existing.locked_portions = locked
        existing.source = payload.source or "manual"
        plan = existing
    else:
        plan = PredictionPlan(
            user_id=user_id,
            menu_id=payload.menu_id,
            plan_date=payload.plan_date,
            recommended_portions=max(0, payload.recommended_portions),
            locked_portions=locked,
            source=payload.source or "manual",
        )
        db.add(plan)

    # Tutup loop: target menu mengikuti angka yang dikunci.
    menu.target_portions = locked
    db.commit()
    db.refresh(plan)
    return plan


@router.get("/plan/{plan_date}/{menu_id}", response_model=schemas.PredictionPlanOut | None)
def get_plan(
    plan_date: date,
    menu_id: int,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    plan = (
        db.query(PredictionPlan)
        .filter(
            PredictionPlan.user_id == user_id,
            PredictionPlan.menu_id == menu_id,
            PredictionPlan.plan_date == plan_date,
        )
        .first()
    )
    return plan