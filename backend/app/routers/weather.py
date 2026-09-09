import json
import time
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from ..geocode import resolve_adm4

router = APIRouter(prefix="/api/v1/weather", tags=["weather"])

BMKG_URL = "https://api.bmkg.go.id/publik/prakiraan-cuaca"
DEFAULT_ADM4 = "31.71.03.1001"  # Kemayoran, Jakarta Pusat (lokasi default sementara)
CACHE_TTL_SECONDS = 30 * 60  # 30 menit

_cache: dict[str, tuple[float, dict]] = {}


class WeatherResponse(BaseModel):
    adm4: str
    lokasi: str
    provinsi: str
    condition: str
    weather_icon: str
    temperature: int
    humidity: int
    wind_ms: float
    updated_at: str
    insight: str


def _fetch_bmkg(adm4: str) -> dict:
    url = f"{BMKG_URL}?adm4={adm4}"
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"
            ),
            "Accept": "application/json",
            "Accept-Language": "id-ID,id;q=0.9",
        },
    )
    with urllib.request.urlopen(request, timeout=8) as response:
        body = response.read().decode("utf-8")
    return json.loads(body)


def _pick_current(records: list[dict]) -> dict | None:
    """Pilih record prakiraan yang paling mendekati jam saat ini (WIB)."""
    if not records:
        return None
    now = datetime.now(ZoneInfo("Asia/Jakarta"))
    best = None
    best_diff = None
    for record in records:
        try:
            local = datetime.fromisoformat(record.get("local_datetime", "")).replace(
                tzinfo=ZoneInfo("Asia/Jakarta")
            )
        except (ValueError, TypeError):
            continue
        diff = abs((local - now).total_seconds())
        if best_diff is None or diff < best_diff:
            best = record
            best_diff = diff
    return best


def _build_insight(condition: str, hour: int) -> str:
    desc = condition.lower()
    if "hujan" in desc:
        return "Cuaca hujan, potensi kunjungan menurun; pertimbangkan kurangi porsi ekstra sore ini."
    if "petir" in desc or "badai" in desc:
        return "Waspada cuaca ekstrem; jaga ketersediaan menu hangat dan kurangi stok mudah rusak."
    if "berawan" in desc:
        return "Cuaca berawan, kunjungan cenderung stabil sepanjang hari."
    # Cerah
    if 16 <= hour <= 21:
        return "Cuaca cerah, potensi lonjakan pengunjung malam hari meningkat."
    if 10 <= hour <= 14:
        return "Cuaca cerah, kunjungan siang berpotensi ramai; siapkan porsi ekstra."
    return "Cuaca cerah, kunjungan diperkirakan normal. Pantau tren untuk penyesuaian stok."


@router.get("")
def get_weather(
    adm4: str = Query(None, description="Kode wilayah administrasi tingkat IV (desa/kelurahan)"),
    lat: float = Query(None, description="Garis lintang device (dipakai jika adm4 tidak diberikan)"),
    lon: float = Query(None, description="Garis bujur device (dipakai jika adm4 tidak diberikan)"),
) -> WeatherResponse:
    if not adm4:
        if lat is None or lon is None:
            raise HTTPException(
                status_code=400,
                detail="Parameter 'adm4' atau 'lat'+'lon' wajib diberikan.",
            )
        adm4 = resolve_adm4(lat, lon)
        if not adm4:
            raise HTTPException(status_code=422, detail="Lokasi tidak dapat dipetakan ke wilayah BMKG.")

    try:
        return WeatherResponse(**build_weather_payload(adm4))
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=502,
            detail=f"Gagal mengambil data cuaca dari BMKG ({type(exc).__name__})",
        )


def build_weather_payload(adm4: str) -> dict:
    """Ambil payload cuaca terkini (dengan cache) — dipakai ulang oleh predictions."""
    now = time.time()
    cached = _cache.get(adm4)
    if cached and cached[0] > now:
        return cached[1]

    raw = _fetch_bmkg(adm4)
    area = raw.get("lokasi", {})
    for block in raw.get("data", []):
        flat_records = [rec for day in block.get("cuaca", []) for rec in day]
        record = _pick_current(flat_records)
        if record is None:
            continue

        local_text = record.get("local_datetime", "")
        condition = record.get("weather_desc", "Cerah")
        hour = 0
        try:
            hour = datetime.fromisoformat(local_text).hour
        except (ValueError, TypeError):
            pass

        lokasi = area.get("kecamatan") or area.get("desa") or area.get("kotkab") or ""
        kotkab = area.get("kotkab") or ""
        if lokasi and kotkab and lokasi != kotkab:
            lokasi = f"{lokasi}, {kotkab}"

        payload = {
            "adm4": adm4,
            "lokasi": lokasi,
            "provinsi": area.get("provinsi", ""),
            "condition": condition,
            "weather_icon": record.get("weather_desc") or "",
            "temperature": int(record.get("t") or 0),
            "humidity": int(record.get("hu") or 0),
            "wind_ms": round(float(record.get("ws") or 0), 1),
            "updated_at": local_text,
            "insight": _build_insight(condition, hour),
        }
        _cache[adm4] = (now + CACHE_TTL_SECONDS, payload)
        return payload

    raise HTTPException(status_code=503, detail="Data BMKG tidak ditemukan")