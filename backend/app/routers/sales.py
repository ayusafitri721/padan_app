from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ..auth import get_current_user_id
from ..database import get_db
from ..models import DailySales, DailySalesItem, Menu, User
from .. import schemas

router = APIRouter(prefix="/api/v1/sales", tags=["sales"])

# Menu contoh awal untuk warung yang baru mendaftar (belum punya data menu di DB).
_DEFAULT_MENUS = [
    {"name": "Nasi Goreng Spesial", "category": "Makanan Utama", "target_portions": 50, "accuracy": 96},
    {"name": "Ayam Geprek", "category": "Makanan Utama", "target_portions": 35, "accuracy": 92},
    {"name": "Bakso Sapi", "category": "Mie & Bakso", "target_portions": 30, "accuracy": 88},
    {"name": "Es Teh Manis", "category": "Minuman", "target_portions": 60, "accuracy": 100},
]


def _seed_menus_if_empty(db: Session, user_id: int) -> None:
    count = db.query(Menu).filter(Menu.user_id == user_id).count()
    if count > 0:
        return
    for item in _DEFAULT_MENUS:
        db.add(Menu(user_id=user_id, name=item["name"], category=item["category"],
                    target_portions=item["target_portions"], accuracy=item["accuracy"]))
    db.commit()


@router.get("/menus", response_model=list[schemas.MenuOut])
def list_menus(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    _seed_menus_if_empty(db, user_id)
    menus = (
        db.query(Menu)
        .filter(Menu.user_id == user_id, Menu.is_active.is_(True))
        .order_by(Menu.id)
        .all()
    )
    return menus


@router.post("/menus", response_model=schemas.MenuOut, status_code=201)
def create_menu(
    payload: schemas.MenuIn,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    menu = Menu(
        user_id=user_id,
        name=payload.name.strip(),
        category=payload.category.strip() or "Makanan Utama",
        target_portions=max(0, payload.target_portions),
        accuracy=max(0, payload.accuracy),
        price=max(1000, payload.price),
    )
    db.add(menu)
    db.commit()
    db.refresh(menu)
    return menu


@router.put("/menus/{menu_id}", response_model=schemas.MenuOut)
def update_menu(
    menu_id: int,
    payload: schemas.MenuIn,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    menu = (
        db.query(Menu)
        .filter(Menu.id == menu_id, Menu.user_id == user_id)
        .first()
    )
    if not menu:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan.")
    menu.name = payload.name.strip()
    menu.category = payload.category.strip() or "Makanan Utama"
    menu.target_portions = max(0, payload.target_portions)
    menu.accuracy = max(0, payload.accuracy)
    menu.price = max(1000, payload.price)
    db.commit()
    db.refresh(menu)
    return menu


@router.delete("/menus/{menu_id}", status_code=204)
def delete_menu(
    menu_id: int,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    menu = (
        db.query(Menu)
        .filter(Menu.id == menu_id, Menu.user_id == user_id)
        .first()
    )
    if not menu:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan.")
    # Soft-delete: menu tidak muncul lagi di daftar aktif.
    menu.is_active = False
    db.commit()
    return None


def _save_sales(
    payload: schemas.DailySalesIn,
    user_id: int,
    status_value: str,
    db: Session,
) -> schemas.SalesSummaryOut:
    _seed_menus_if_empty(db, user_id)
    menus = {m.id: m for m in db.query(Menu).filter(Menu.user_id == user_id).all()}
    if not menus:
        raise HTTPException(status_code=404, detail="Belum ada menu aktif.")
    today = payload.date or date.today()
    existing = (
        db.query(DailySales)
        .filter(DailySales.user_id == user_id, DailySales.date == today)
        .first()
    )
    if existing:
        # Upsert: timpa record tanggal yang sama (koreksi harian).
        db.query(DailySalesItem).filter(DailySalesItem.daily_sales_id == existing.id).delete()
        existing.is_holiday_toggle = payload.is_holiday_toggle
        existing.status = status_value
        record = existing
        db.flush()
    else:
        record = DailySales(
            user_id=user_id,
            date=today,
            is_holiday_toggle=payload.is_holiday_toggle,
            status=status_value,
        )
        db.add(record)
        db.flush()

    total_target = 0
    total_sold = 0
    active_menus = {
        m.id: m for m in db.query(Menu).filter(Menu.user_id == user_id, Menu.is_active.is_(True)).all()
    }
    if not active_menus:
        raise HTTPException(status_code=404, detail="Belum ada menu aktif.")

    for item in payload.items:
        menu = active_menus.get(item.menu_id)
        if menu is None:
            raise HTTPException(
                status_code=422,
                detail=f"Menu id={item.menu_id} bukan milik akun ini.",
            )
        target = menu.target_portions
        sold = max(0, item.sold_portions)
        remaining = max(0, target - sold)
        total_target += target
        total_sold += sold
        menu.sold_today = sold
        menu.remaining = remaining
        db.add(
            DailySalesItem(
                daily_sales_id=record.id,
                menu_id=menu.id,
                target_portions=target,
                sold_portions=sold,
                remaining_portions=remaining,
            )
        )

    # Menu aktif yang tidak ikut diisikan direset hari ini (0).
    for menu in active_menus.values():
        if menu.id not in {i.menu_id for i in payload.items}:
            menu.sold_today = 0
            menu.remaining = max(0, menu.target_portions)

    db.commit()
    db.refresh(record)

    efficiency = (total_sold / total_target * 100) if total_target else 0.0
    return schemas.SalesSummaryOut(
        id=record.id,
        status=record.status,
        total_sold=total_sold,
        total_target=total_target,
        efficiency_percent=round(efficiency, 1),
        remaining_total=total_target - total_sold,
    )


@router.post("/daily-record", response_model=schemas.SalesSummaryOut, status_code=201)
def save_daily_record(
    payload: schemas.DailySalesIn,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _save_sales(payload, user_id, "final", db)


@router.post("/save-draft", response_model=schemas.SalesSummaryOut, status_code=201)
def save_draft(
    payload: schemas.DailySalesIn,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _save_sales(payload, user_id, "draft", db)


@router.get("/today", response_model=schemas.DailySalesOut | None)
def get_today(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    today = date.today()
    record = (
        db.query(DailySales)
        .filter(DailySales.user_id == user_id, DailySales.date == today)
        .first()
    )
    return record


@router.get("/by-date", response_model=schemas.DailySalesOut | None)
def get_by_date(
    target_date: date = Query(alias="date"),
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    record = (
        db.query(DailySales)
        .filter(DailySales.user_id == user_id, DailySales.date == target_date)
        .first()
    )
    return record