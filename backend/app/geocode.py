import json
import logging
import math
import os
import tempfile
import urllib.request
from functools import lru_cache
from pathlib import Path

log = logging.getLogger("padan.geocode")

DATA_FILE = Path(__file__).resolve().parent.parent / "data" / "wilayah_reverse.json"
# Cadangan bila file tidak ikut ke-deploy (terbukti di Railway):
# unduh sekali dari repo publik, cache di /tmp selama container hidup.
WILAYAH_URL = os.environ.get(
    "WILAYAH_URL",
    "https://raw.githubusercontent.com/baradika/padan_app/main/backend/data/wilayah_reverse.json",
)
_TMP_FILE = Path(tempfile.gettempdir()) / "wilayah_reverse.json"

log.warning("wilayah data: %s (exists=%s)", DATA_FILE, DATA_FILE.exists())


def _download_points() -> list[dict]:
    if _TMP_FILE.is_file():
        try:
            with open(_TMP_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError):
            pass
    log.warning("mengunduh data wilayah dari %s", WILAYAH_URL)
    request = urllib.request.Request(WILAYAH_URL, headers={"User-Agent": "padan-app"})
    with urllib.request.urlopen(request, timeout=30) as response:
        points = json.loads(response.read().decode("utf-8"))
    try:
        with open(_TMP_FILE, "w", encoding="utf-8") as f:
            json.dump(points, f)
    except OSError:
        pass
    return points


@lru_cache(maxsize=1)
def _load_points() -> list[dict]:
    if DATA_FILE.is_file():
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError):
            pass
    try:
        return _download_points()
    except Exception as exc:  # noqa: BLE001 — offline total, dll.
        # Gagal lembut: pemanggil fallback ke default, bukan 500.
        log.warning("data wilayah tak tersedia (%s)", type(exc).__name__)
        return []


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2) ** 2
    )
    return r * 2 * math.asin(math.sqrt(a))


@lru_cache(maxsize=2048)
def _resolve_cached(lat_r: float, lon_r: float) -> str | None:
    """Scan 83rb titik sekali per koordinat (dibulatkan ±100 m).

    GPS device jitter tiap request, jadi tanpa pembulatan cache tidak pernah hit.
    """
    points = _load_points()
    best_code = None
    best_distance = math.inf
    for point in points:
        distance = _haversine_km(lat_r, lon_r, point["lat"], point["lon"])
        if distance < best_distance:
            best_distance = distance
            best_code = point["code"]
    return best_code


def resolve_adm4(lat: float, lon: float) -> str | None:
    """Cari kode adm4 (desa/kelurahan) terdekat dari koordinat."""
    return _resolve_cached(round(lat, 3), round(lon, 3))