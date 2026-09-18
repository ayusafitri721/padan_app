import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# Lokal default; production (Render/dll) isi via env vars.
# Contoh TiDB Cloud:
#   DATABASE_URL=mysql+pymysql://user:pass@host:4000/padan_db?charset=utf8mb4
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "mysql+pymysql://padan:padan123@127.0.0.1:3306/padan_db?charset=utf8mb4",
)


def _connect_args() -> dict:
    # DB cloud (TiDB dkk) wajib TLS. Pakai CA dari env, atau bundle bawaan OS.
    # Lokal (MariaDB tanpa SSL) jangan set apa pun → koneksi polos.
    if "tidbcloud.com" not in DATABASE_URL and "DB_SSL_CA" not in os.environ:
        return {}
    ca = os.environ.get("DB_SSL_CA", "/etc/ssl/certs/ca-certificates.crt")
    if os.path.exists(ca):
        return {"ssl": {"ca": ca}}
    return {}


engine = create_engine(DATABASE_URL, pool_pre_ping=True, connect_args=_connect_args())

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()