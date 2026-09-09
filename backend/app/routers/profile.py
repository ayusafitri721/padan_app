from datetime import datetime, time, timedelta

import os
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from ..auth import get_current_user_id
from ..database import get_db
from ..models import AiPreference, DailySales, DailySalesItem, DynamicPricingRule, Outlet, PricingSchedule, Subscription, User
from .. import schemas

router = APIRouter(prefix="/api/v1/profile", tags=["profile"])


def _parse_time(s: str) -> time:
    for fmt in ("%H:%M:%S", "%H:%M"):
        try:
            return datetime.strptime(s, fmt).time()
        except ValueError:
            continue
    raise HTTPException(status_code=422, detail=f"Format waktu tidak valid: {s}")


def _ensure_outlet(db: Session, user_id: int, user: User) -> Outlet:
    o = db.query(Outlet).filter(Outlet.user_id == user_id).first()
    if o:
        return o
    o = Outlet(
        user_id=user_id,
        outlet_name=user.warung_name,
        address="Jl. Tebet Raya No. 42",
        opening_time=time(9, 0),
        closing_time=time(22, 0),
    )
    db.add(o)
    db.commit()
    db.refresh(o)
    return o


def _ensure_subscription(db: Session, user_id: int) -> Subscription:
    s = db.query(Subscription).filter(Subscription.user_id == user_id).first()
    if s:
        return s
    # Aktif s/d 14 Des 2025 sesuai spec MD (tahun dinamis jika sudah lewat, set +1 tahun)
    exp = datetime(2025, 12, 14, 23, 59, 59)
    if exp < datetime.now():
        exp = datetime.now() + timedelta(days=365)
    s = Subscription(user_id=user_id, plan_name="PADAN Pro Plan", status="ACTIVE", expires_at=exp)
    db.add(s)
    db.commit()
    db.refresh(s)
    return s


def _ensure_ai_pref(db: Session, user_id: int) -> AiPreference:
    p = db.query(AiPreference).filter(AiPreference.user_id == user_id).first()
    if p:
        return p
    # sinkronkan max_critical_discount dengan dynamic pricing jika ada
    rule = db.query(DynamicPricingRule).filter(DynamicPricingRule.user_id == user_id).first()
    max_disc = rule.max_discount_percentage if rule else 35
    p = AiPreference(user_id=user_id, weather_sensitivity_mode="MODERATE", max_critical_discount=max_disc, last_offline_sync=datetime.now())
    db.add(p)
    db.commit()
    db.refresh(p)
    return p


@router.get("/details", response_model=schemas.ProfileDetailsOut)
def get_details(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User tidak ditemukan")

    outlet = _ensure_outlet(db, user_id, user)
    sub = _ensure_subscription(db, user_id)
    pref = _ensure_ai_pref(db, user_id)

    # Stats murni DB: konsistensi = hari aktif (distinct daily_sales final), pangan terjaga = total sold, skor = efisiensi
    all_sales = db.query(DailySales).filter(DailySales.user_id == user_id, DailySales.status == "final").all()
    total_days = len({s.date for s in all_sales}) if all_sales else 0
    # fallback jika belum ada sales: 0 hari
    konsistensi = total_days if total_days else 0
    # total porsi terjaga = sum sold
    total_saved = 0
    for s in all_sales:
        items = db.query(DailySalesItem).filter(DailySalesItem.daily_sales_id == s.id).all()
        for it in items:
            total_saved += it.sold_portions

    # skor dapur: rata-rata efisiensi dari semua sales
    avg_eff = 0.0
    if all_sales:
        effs = []
        for s in all_sales:
            items = db.query(DailySalesItem).filter(DailySalesItem.daily_sales_id == s.id).all()
            sold = sum(i.sold_portions for i in items)
            target = sum(i.target_portions for i in items)
            if target:
                effs.append(sold / target * 100)
        avg_eff = round(sum(effs) / len(effs), 1) if effs else 0.0
    # jika belum ada data, 0
    skor = avg_eff

    # jika belum ada data sama sekali, fallback tetap 0 (murni DB)
    # Untuk demo visual, jika user demo tanpa sales, biarkan 0 — frontend akan tampilkan 0

    stats = {
        "consistency_days": konsistensi,
        "saved_portions": total_saved,
        "kitchen_score": skor,
    }

    cert = {
        "issuer": "Dinas Lingkungan Hidup & Ketahanan Pangan DKI Jakarta",
        "valid_until": "2026-12-31",
        "level": "Emas",
    }

    return schemas.ProfileDetailsOut(
        user=user,
        outlet=schemas.OutletOut(
            outlet_name=outlet.outlet_name,
            address=outlet.address,
            opening_time=outlet.opening_time.strftime("%H:%M"),
            closing_time=outlet.closing_time.strftime("%H:%M"),
        ),
        subscription=schemas.SubscriptionOut(
            plan_name=sub.plan_name,
            status=sub.status,
            expires_at=sub.expires_at,
        ),
        ai_preference=schemas.AiPreferenceOut(
            weather_sensitivity_mode=pref.weather_sensitivity_mode,
            max_critical_discount=pref.max_critical_discount,
            last_offline_sync=pref.last_offline_sync,
        ),
        stats=stats,
        certification=cert,
    )


@router.put("/ai-preferences", response_model=schemas.AiPreferenceOut)
def put_ai_preferences(
    payload: schemas.AiPreferenceIn,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    mode = payload.weather_sensitivity_mode.upper()
    if mode not in ("MODERATE", "AGGRESSIVE"):
        raise HTTPException(status_code=422, detail="Mode harus MODERATE atau AGGRESSIVE")
    max_disc = max(15, min(60, payload.max_critical_discount))

    pref = _ensure_ai_pref(db, user_id)
    pref.weather_sensitivity_mode = mode
    pref.max_critical_discount = max_disc
    pref.updated_at = datetime.now()  # type: ignore

    # Sinkronkan ke dynamic pricing rule juga (satu sumber kebenaran) + rebuild jadwal
    rule = db.query(DynamicPricingRule).filter(DynamicPricingRule.user_id == user_id).first()
    if rule:
        rule.max_discount_percentage = max_disc
        # rebuild schedules agar preview harga langsung mencerminkan max baru
        db.query(PricingSchedule).filter(PricingSchedule.rule_id == rule.id).delete()
        db.flush()
        base = datetime.combine(datetime.today(), rule.start_intervention_time)
        for mins, disc, desc in [
            (0, min(10, max_disc), "Pemanasan jam santai"),
            (30, min(20, max_disc), "Jam kritis 1 jam sebelum tutup"),
            (60, max_disc, "Flash Promo Anti-Mubazir"),
            (90, 0, "Tutup Warung"),
        ]:
            t = (base + timedelta(minutes=mins)).time()
            db.add(PricingSchedule(rule_id=rule.id, time_interval=t, discount_percentage=disc, description=desc))
    else:
        # buat rule baru jika belum ada
        from ..models import DynamicPricingRule as DPR
        rule = DPR(
            user_id=user_id,
            is_enabled=True,
            max_discount_percentage=max_disc,
            start_intervention_time=time(20, 30),
            broadcast_whatsapp=True,
        )
        db.add(rule)
        db.flush()
        base = datetime.combine(datetime.today(), rule.start_intervention_time)
        for mins, disc, desc in [
            (0, min(10, max_disc), "Pemanasan jam santai"),
            (30, min(20, max_disc), "Jam kritis 1 jam sebelum tutup"),
            (60, max_disc, "Flash Promo Anti-Mubazir"),
            (90, 0, "Tutup Warung"),
        ]:
            t = (base + timedelta(minutes=mins)).time()
            db.add(PricingSchedule(rule_id=rule.id, time_interval=t, discount_percentage=disc, description=desc))

    db.commit()
    db.refresh(pref)

    return schemas.AiPreferenceOut(
        weather_sensitivity_mode=pref.weather_sensitivity_mode,
        max_critical_discount=pref.max_critical_discount,
        last_offline_sync=pref.last_offline_sync,
    )


@router.put("/user", response_model=schemas.UserOut)
def put_user(
    payload: schemas.UserUpdateIn,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User tidak ditemukan")
    if payload.warung_name is not None and payload.warung_name.strip():
        user.warung_name = payload.warung_name.strip()
        # sinkronkan outlet_name jika outlet ada dan masih default
        outlet = db.query(Outlet).filter(Outlet.user_id == user_id).first()
        if outlet and outlet.outlet_name == user.warung_name:
            pass  # sudah sinkron
        elif outlet:
            # tidak auto-sync, biarkan outlet_name terpisah
            pass
    if payload.phone_or_email is not None and payload.phone_or_email.strip():
        # cek unik
        exists = db.query(User).filter(User.phone_or_email == payload.phone_or_email.strip(), User.id != user_id).first()
        if exists:
            raise HTTPException(status_code=409, detail="Email/HP sudah digunakan")
        user.phone_or_email = payload.phone_or_email.strip()
    if payload.business_type is not None and payload.business_type.strip():
        user.business_type = payload.business_type.strip()
    db.commit()
    db.refresh(user)
    return user


@router.put("/outlet", response_model=schemas.OutletOut)
def put_outlet(
    payload: schemas.OutletIn,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    outlet = _ensure_outlet(db, user_id, user)
    if payload.outlet_name is not None and payload.outlet_name.strip():
        outlet.outlet_name = payload.outlet_name.strip()
    if payload.address is not None:
        outlet.address = payload.address.strip()
    if payload.opening_time is not None:
        outlet.opening_time = _parse_time(payload.opening_time)
    if payload.closing_time is not None:
        outlet.closing_time = _parse_time(payload.closing_time)
    db.commit()
    db.refresh(outlet)
    return schemas.OutletOut(
        outlet_name=outlet.outlet_name,
        address=outlet.address,
        opening_time=outlet.opening_time.strftime("%H:%M"),
        closing_time=outlet.closing_time.strftime("%H:%M"),
    )


@router.post("/avatar", response_model=schemas.UserOut)
async def post_avatar(
    file: UploadFile = File(...),
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=422, detail="File harus berupa gambar")
    data = await file.read()
    if len(data) > 3 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Ukuran maksimal 3MB")
    # Simpan ke uploads/avatars/{user_id}_{uuid}.ext
    ext = Path(file.filename or "avatar.jpg").suffix or ".jpg"
    if ext.lower() not in (".jpg", ".jpeg", ".png", ".webp"):
        ext = ".jpg"
    upload_dir = Path(__file__).resolve().parents[2] / "uploads" / "avatars"
    upload_dir.mkdir(parents=True, exist_ok=True)
    fname = f"{user_id}_{uuid.uuid4().hex}{ext}"
    fpath = upload_dir / fname
    fpath.write_bytes(data)
    # hapus avatar lama jika ada
    user = db.query(User).filter(User.id == user_id).first()
    if user and user.avatar_url:
        old = upload_dir / Path(user.avatar_url).name
        try:
            if old.exists():
                old.unlink()
        except Exception:
            pass
    avatar_url = f"/uploads/avatars/{fname}"
    user.avatar_url = avatar_url
    db.commit()
    db.refresh(user)
    return user


@router.post("/sync-offline")
def sync_offline(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    pref = _ensure_ai_pref(db, user_id)
    pref.last_offline_sync = datetime.now()
    db.commit()
    return {"last_offline_sync": pref.last_offline_sync.isoformat(), "status": "synced"}
