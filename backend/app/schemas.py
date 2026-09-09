from datetime import datetime, date

from pydantic import BaseModel, ConfigDict


class RegisterRequest(BaseModel):
    warung_name: str
    phone_or_email: str
    business_type: str
    password: str


class LoginRequest(BaseModel):
    phone_or_email: str
    password: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    warung_name: str
    phone_or_email: str
    business_type: str
    avatar_url: str | None = None
    created_at: datetime


class UserUpdateIn(BaseModel):
    warung_name: str | None = None
    phone_or_email: str | None = None
    business_type: str | None = None


class OutletIn(BaseModel):
    outlet_name: str | None = None
    address: str | None = None
    opening_time: str | None = None  # "HH:MM"
    closing_time: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class MenuOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    category: str
    target_portions: int
    accuracy: int
    sold_today: int
    remaining: int
    price: int
    image_url: str | None = None


class MenuIn(BaseModel):
    name: str
    category: str = "Makanan Utama"
    target_portions: int = 0
    accuracy: int = 0
    price: int = 25000


class DailySalesItemIn(BaseModel):
    menu_id: int
    sold_portions: int


class DailySalesIn(BaseModel):
    date: date
    is_holiday_toggle: bool = False
    items: list[DailySalesItemIn]


class DailySalesItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    menu_id: int
    target_portions: int
    sold_portions: int
    remaining_portions: int


class DailySalesOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    date: date
    is_holiday_toggle: bool
    status: str
    items: list[DailySalesItemOut]


class SalesSummaryOut(BaseModel):
    id: int
    status: str
    total_sold: int
    total_target: int
    efficiency_percent: float
    remaining_total: int


class PredictionPlanIn(BaseModel):
    menu_id: int
    plan_date: date
    recommended_portions: int
    locked_portions: int
    source: str = "ai"


class PredictionPlanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    menu_id: int
    plan_date: date
    recommended_portions: int
    locked_portions: int
    source: str


# ── Dynamic Pricing ──────────────────────────────────────────
class PricingConfigIn(BaseModel):
    is_enabled: bool = True
    max_discount_percentage: int = 35
    # Cara baru (disarankan): jam tutup warung → mulai intervensi = tutup - 90 mnt.
    closing_time: str | None = None  # "HH:MM" atau "HH:MM:SS"
    # Cara lama: jam mulai intervensi langsung (tetap didukung).
    start_intervention_time: str | None = None
    broadcast_whatsapp: bool = True


class PricingScheduleOut(BaseModel):
    time_interval: str
    discount_percentage: int
    description: str


class PricingConfigOut(BaseModel):
    is_enabled: bool
    max_discount_percentage: int
    start_intervention_time: str
    closing_time: str  # start + 90 menit
    broadcast_whatsapp: bool
    schedules: list[PricingScheduleOut]


class PricingLivePreviewOut(BaseModel):
    menu_name: str
    original_price: int
    discounted_price: int
    discount_percentage: int
    remaining_portions: int
    is_active: bool
    description: str


# ── Profile ──────────────────────────────────────────────────
class OutletOut(BaseModel):
    outlet_name: str
    address: str
    opening_time: str
    closing_time: str


class SubscriptionOut(BaseModel):
    plan_name: str
    status: str
    expires_at: datetime


class AiPreferenceOut(BaseModel):
    weather_sensitivity_mode: str
    max_critical_discount: int
    last_offline_sync: datetime | None


class AiPreferenceIn(BaseModel):
    weather_sensitivity_mode: str = "MODERATE"
    max_critical_discount: int = 35


class ProfileDetailsOut(BaseModel):
    user: UserOut
    outlet: OutletOut
    subscription: SubscriptionOut
    ai_preference: AiPreferenceOut
    stats: dict
    certification: dict