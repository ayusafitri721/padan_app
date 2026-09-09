from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Time,
)
from sqlalchemy.orm import relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    warung_name = Column(String(255), nullable=False)
    phone_or_email = Column(String(255), nullable=False, unique=True)
    business_type = Column(String(100), nullable=False)
    password_hash = Column(String(255), nullable=False)
    avatar_url = Column(String(500), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)

    menus = relationship("Menu", back_populates="user")


class Menu(Base):
    __tablename__ = "menus"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(255), nullable=False)
    category = Column(String(50), nullable=False, default="Makanan Utama")
    target_portions = Column(Integer, nullable=False, default=0)
    accuracy = Column(Integer, nullable=False, default=0)  # persen akurasi historis
    sold_today = Column(Integer, nullable=False, default=0)
    remaining = Column(Integer, nullable=False, default=0)
    price = Column(Integer, nullable=False, default=25000)  # harga jual per porsi (untuk preview diskon)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)

    user = relationship("User", back_populates="menus")


class DailySales(Base):
    __tablename__ = "daily_sales"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(Date, nullable=False)
    is_holiday_toggle = Column(Boolean, nullable=False, default=False)
    status = Column(String(20), nullable=False, default="final")  # final / draft
    created_at = Column(DateTime, nullable=False, default=datetime.now)

    items = relationship(
        "DailySalesItem", back_populates="daily_sales", cascade="all, delete-orphan"
    )


class DailySalesItem(Base):
    __tablename__ = "daily_sales_items"

    id = Column(Integer, primary_key=True, autoincrement=True)
    daily_sales_id = Column(Integer, ForeignKey("daily_sales.id"), nullable=False)
    menu_id = Column(Integer, ForeignKey("menus.id"), nullable=False)
    target_portions = Column(Integer, nullable=False, default=0)
    sold_portions = Column(Integer, nullable=False, default=0)
    remaining_portions = Column(Integer, nullable=False, default=0)

    daily_sales = relationship("DailySales", back_populates="items")


class PredictionPlan(Base):
    """Target masak hasil prediksi AI yang sudah dikunci/diterapkan user."""

    __tablename__ = "prediction_plans"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    menu_id = Column(Integer, ForeignKey("menus.id"), nullable=False)
    plan_date = Column(Date, nullable=False)
    recommended_portions = Column(Integer, nullable=False, default=0)
    locked_portions = Column(Integer, nullable=False, default=0)
    source = Column(String(20), nullable=False, default="ai")  # ai / manual
    created_at = Column(DateTime, nullable=False, default=datetime.now)


class DynamicPricingRule(Base):
    __tablename__ = "dynamic_pricing_rules"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    is_enabled = Column(Boolean, nullable=False, default=True)
    max_discount_percentage = Column(Integer, nullable=False, default=35)
    start_intervention_time = Column(Time, nullable=False)
    broadcast_whatsapp = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)
    updated_at = Column(DateTime, nullable=False, default=datetime.now, onupdate=datetime.now)

    schedules = relationship("PricingSchedule", back_populates="rule", cascade="all, delete-orphan")


class PricingSchedule(Base):
    __tablename__ = "pricing_schedules"

    id = Column(Integer, primary_key=True, autoincrement=True)
    rule_id = Column(Integer, ForeignKey("dynamic_pricing_rules.id"), nullable=False)
    time_interval = Column(Time, nullable=False)
    discount_percentage = Column(Integer, nullable=False, default=0)
    description = Column(String(255), nullable=False, default="")

    rule = relationship("DynamicPricingRule", back_populates="schedules")


class Outlet(Base):
    __tablename__ = "outlets"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    outlet_name = Column(String(255), nullable=False)
    address = Column(String(500), nullable=False, default="Jl. Tebet Raya No. 42")
    opening_time = Column(Time, nullable=False)
    closing_time = Column(Time, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.now)
    updated_at = Column(DateTime, nullable=False, default=datetime.now, onupdate=datetime.now)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    plan_name = Column(String(100), nullable=False, default="PADAN Pro Plan")
    status = Column(String(20), nullable=False, default="ACTIVE")
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.now)


class AiPreference(Base):
    __tablename__ = "ai_preferences"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    weather_sensitivity_mode = Column(String(20), nullable=False, default="MODERATE")
    max_critical_discount = Column(Integer, nullable=False, default=35)
    last_offline_sync = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)
    updated_at = Column(DateTime, nullable=False, default=datetime.now, onupdate=datetime.now)