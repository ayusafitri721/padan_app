from datetime import datetime, time, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import get_current_user_id
from ..database import get_db
from ..models import DynamicPricingRule, Menu, PricingSchedule
from .. import schemas

router = APIRouter(prefix="/api/v1/pricing", tags=["pricing"])


def _parse_time(s: str) -> time:
    for fmt in ("%H:%M:%S", "%H:%M"):
        try:
            return datetime.strptime(s, fmt).time()
        except ValueError:
            continue
    raise HTTPException(status_code=422, detail=f"Format waktu tidak valid: {s} (gunakan HH:MM)")


def _time_to_str(t: time) -> str:
    return t.strftime("%H:%M")


def _build_schedules(rule: DynamicPricingRule) -> list[dict]:
    """Hasilkan 4 jadwal dari start time: +0m 10%, +30m 20%, +60m 35% (max), +90m tutup."""
    base = datetime.combine(datetime.today(), rule.start_intervention_time)
    max_disc = rule.max_discount_percentage
    # Interpolasi: 10%, 20%, max, 0 (tutup)
    steps = [
        (0, min(10, max_disc), "Pemanasan jam santai"),
        (30, min(20, max_disc), "Jam kritis 1 jam sebelum tutup"),
        (60, max_disc, "Flash Promo Anti-Mubazir"),
        (90, 0, "Tutup Warung"),
    ]
    out = []
    for mins, disc, desc in steps:
        t = (base + timedelta(minutes=mins)).time()
        # discount 0 untuk tutup tetap 0
        out.append({"time_interval": _time_to_str(t), "discount_percentage": disc, "description": desc})
    return out


def _ensure_rule(db: Session, user_id: int) -> DynamicPricingRule:
    rule = db.query(DynamicPricingRule).filter(DynamicPricingRule.user_id == user_id).first()
    if rule:
        return rule
    # Default sesuai spec
    rule = DynamicPricingRule(
        user_id=user_id,
        is_enabled=True,
        max_discount_percentage=35,
        start_intervention_time=_parse_time("20:30"),
        broadcast_whatsapp=True,
    )
    db.add(rule)
    db.flush()
    # buat schedules default
    for s in _build_schedules(rule):
        db.add(PricingSchedule(rule_id=rule.id, time_interval=_parse_time(s["time_interval"]), discount_percentage=s["discount_percentage"], description=s["description"]))
    db.commit()
    db.refresh(rule)
    return rule


def _schedules_out(rule: DynamicPricingRule) -> list[schemas.PricingScheduleOut]:
    return [
        schemas.PricingScheduleOut(time_interval=_time_to_str(s.time_interval), discount_percentage=s.discount_percentage, description=s.description)
        for s in sorted(rule.schedules, key=lambda x: x.time_interval)
    ]


@router.get("/config", response_model=schemas.PricingConfigOut)
def get_config(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    rule = _ensure_rule(db, user_id)
    return schemas.PricingConfigOut(
        is_enabled=rule.is_enabled,
        max_discount_percentage=rule.max_discount_percentage,
        start_intervention_time=_time_to_str(rule.start_intervention_time),
        broadcast_whatsapp=rule.broadcast_whatsapp,
        schedules=_schedules_out(rule),
    )


@router.put("/config", response_model=schemas.PricingConfigOut)
def put_config(
    payload: schemas.PricingConfigIn,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    max_disc = max(10, min(60, payload.max_discount_percentage))
    t = _parse_time(payload.start_intervention_time)

    rule = db.query(DynamicPricingRule).filter(DynamicPricingRule.user_id == user_id).first()
    if not rule:
        rule = DynamicPricingRule(user_id=user_id, is_enabled=payload.is_enabled, max_discount_percentage=max_disc, start_intervention_time=t, broadcast_whatsapp=payload.broadcast_whatsapp)
        db.add(rule)
        db.flush()
    else:
        rule.is_enabled = payload.is_enabled
        rule.max_discount_percentage = max_disc
        rule.start_intervention_time = t
        rule.broadcast_whatsapp = payload.broadcast_whatsapp
        # hapus jadwal lama
        db.query(PricingSchedule).filter(PricingSchedule.rule_id == rule.id).delete()
        db.flush()

    # bangun ulang jadwal sesuai max & start
    for s in _build_schedules(rule):
        db.add(PricingSchedule(rule_id=rule.id, time_interval=_parse_time(s["time_interval"]), discount_percentage=s["discount_percentage"], description=s["description"]))
    db.commit()
    db.refresh(rule)
    return schemas.PricingConfigOut(
        is_enabled=rule.is_enabled,
        max_discount_percentage=rule.max_discount_percentage,
        start_intervention_time=_time_to_str(rule.start_intervention_time),
        broadcast_whatsapp=rule.broadcast_whatsapp,
        schedules=_schedules_out(rule),
    )


@router.get("/live-preview", response_model=schemas.PricingLivePreviewOut)
def live_preview(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    rule = _ensure_rule(db, user_id)

    # Cari menu dengan sisa >3 porsi (prioritas tinggi) — jika tidak ada, ambil menu pertama
    menus = db.query(Menu).filter(Menu.user_id == user_id, Menu.is_active.is_(True)).order_by(Menu.id).all()
    if not menus:
        raise HTTPException(status_code=404, detail="Belum ada menu")

    candidate = None
    for m in menus:
        if m.remaining > 3:
            candidate = m
            break
    if not candidate:
        # fallback: menu dengan sisa terbanyak
        candidate = max(menus, key=lambda m: m.remaining)

    now = datetime.now().time()
    # Tentukan diskon saat ini berdasarkan jadwal
    schedules = sorted(rule.schedules, key=lambda s: s.time_interval)
    active_disc = 0
    active_desc = "Belum ada promo"
    for s in schedules:
        if now >= s.time_interval:
            active_disc = s.discount_percentage
            active_desc = s.description
        else:
            break
    # Jika tutup (last entry discount 0 tapi status tutup) — anggap sisa 0
    is_tutup = schedules and now >= schedules[-1].time_interval
    if is_tutup:
        active_disc = 0
        active_desc = "Tutup Warung — Sisa 0 Porsi"
        remaining = 0
    else:
        remaining = candidate.remaining
        # Jika toggle mati atau sisa <=3, tidak aktif
        if not rule.is_enabled or remaining <= 3:
            active_disc = 0
            active_desc = "Promo belum aktif — sisa stok masih aman" if rule.is_enabled else "Dynamic Pricing nonaktif"

    original = candidate.price or 25000
    discounted = int(round(original * (100 - active_disc) / 100)) if active_disc else original

    return schemas.PricingLivePreviewOut(
        menu_name=candidate.name,
        original_price=original,
        discounted_price=discounted,
        discount_percentage=active_disc,
        remaining_portions=remaining,
        is_active=active_disc > 0 and rule.is_enabled and remaining > 3 and not is_tutup,
        description=active_desc,
    )
