from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import auth, schemas
from ..database import get_db
from ..models import User

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post(
    "/register",
    response_model=schemas.TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(payload: schemas.RegisterRequest, db: Session = Depends(get_db)):
    existing = (
        db.query(User)
        .filter(User.phone_or_email == payload.phone_or_email.strip())
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Nomor HP / Email sudah terdaftar",
        )

    user = User(
        warung_name=payload.warung_name.strip(),
        phone_or_email=payload.phone_or_email.strip(),
        business_type=payload.business_type.strip(),
        password_hash=auth.hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = auth.create_access_token(user.id, user.warung_name)
    return schemas.TokenResponse(access_token=token, user=user)


@router.post("/login", response_model=schemas.TokenResponse)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = (
        db.query(User)
        .filter(User.phone_or_email == payload.phone_or_email.strip())
        .first()
    )
    if not user or not auth.verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Kredensial tidak valid",
        )

    token = auth.create_access_token(user.id, user.warung_name)
    return schemas.TokenResponse(access_token=token, user=user)