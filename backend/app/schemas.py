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
    created_at: datetime


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


class MenuIn(BaseModel):
    name: str
    category: str = "Makanan Utama"
    target_portions: int = 0
    accuracy: int = 0


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