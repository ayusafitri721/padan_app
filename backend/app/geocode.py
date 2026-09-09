import json
import math
from functools import lru_cache
from pathlib import Path

DATA_FILE = Path(__file__).resolve().parent.parent / "data" / "wilayah_reverse.json"


@lru_cache(maxsize=1)
def _load_points() -> list[dict]:
    with open(DATA_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


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