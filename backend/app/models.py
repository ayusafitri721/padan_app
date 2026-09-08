from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
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