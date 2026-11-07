"""Utilidades compartidas por todas las pantallas: HTTP, fecha en español y tiempo."""
from __future__ import annotations

import datetime as dt
import logging
from zoneinfo import ZoneInfo

import requests

log = logging.getLogger("dash")

UA = "kindle-dash/1.0 (+https://github.com)"
SESSION = requests.Session()
SESSION.headers.update({"User-Agent": UA})

DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
DIAS_CORTOS = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]
MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
         "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
MESES_CORTOS = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]


def get_json(url: str, **params):
    r = SESSION.get(url, params=params or None, timeout=20)
    r.raise_for_status()
    return r.json()


def get_bytes(url: str) -> bytes:
    r = SESSION.get(url, timeout=20)
    r.raise_for_status()
    return r.content


def safe(name: str, fn, default=None):
    """Ejecuta una fuente de datos; si falla, registra y devuelve default.
    Así una API caída deja su bloque vacío en lugar de romper la pantalla."""
    try:
        return fn()
    except Exception as e:  # noqa: BLE001
        log.warning("Fuente '%s' falló: %s", name, e)
        return default


def now_ctx(tz: str) -> dict:
    n = dt.datetime.now(ZoneInfo(tz))
    return {
        "dt": n,
        "date": n.date(),
        "weekday_name": DIAS[n.weekday()],
        "weekday_short": DIAS_CORTOS[n.weekday()],
        "day": n.day,
        "month_name": MESES[n.month - 1],
        "year": n.year,
        "week": n.isocalendar().week,
        "hhmm": n.strftime("%H:%M"),
    }


def countdown(days: int) -> str:
    if days == 0:
        return "hoy"
    if days == 1:
        return "mañana"
    return f"en {days} días"


# Códigos WMO de Open-Meteo → descripción corta.
WMO = {
    0: "despejado", 1: "casi despejado", 2: "parcialmente nublado", 3: "nublado",
    45: "niebla", 48: "niebla", 51: "llovizna", 53: "llovizna", 55: "llovizna",
    56: "llovizna helada", 57: "llovizna helada", 61: "lluvia débil", 63: "lluvia",
    65: "lluvia fuerte", 66: "lluvia helada", 67: "lluvia helada", 71: "nieve",
    73: "nieve", 75: "nieve fuerte", 77: "granizo fino", 80: "chubascos",
    81: "chubascos", 82: "chubascos fuertes", 85: "nieve", 86: "nieve",
    95: "tormenta", 96: "tormenta con granizo", 99: "tormenta con granizo",
}


def parse_weather(d: dict) -> dict:
    cur, day = d["current"], d["daily"]
    return {
        "temp": round(cur["temperature_2m"]),
        "desc": WMO.get(cur.get("weather_code"), ""),
        "max": round(day["temperature_2m_max"][0]),
        "min": round(day["temperature_2m_min"][0]),
    }


def weather(loc: dict, tz: str) -> dict:
    d = get_json(
        "https://api.open-meteo.com/v1/forecast",
        latitude=loc["lat"], longitude=loc["lon"], timezone=tz, forecast_days=1,
        current="temperature_2m,weather_code",
        daily="temperature_2m_max,temperature_2m_min",
    )
    return parse_weather(d)
