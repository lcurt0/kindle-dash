"""Tests sin red: verifican que cada conector entiende el formato de su API."""
import datetime as dt
from zoneinfo import ZoneInfo

from common.lib import countdown, parse_weather
from screens.gaming import data as g

NOW = dt.datetime(2026, 11, 7, 12, 30, tzinfo=ZoneInfo("Europe/Madrid"))
UTC = NOW.astimezone(dt.timezone.utc)

RSS = b"""<?xml version="1.0"?><rss version="2.0"><channel><title>X</title>
<item><title>GTA 6: Rockstar muestra un nuevo tr&#225;iler</title><pubDate>Sat, 07 Nov 2026 09:00:00 GMT</pubDate></item>
<item><title>Gu\xc3\xada de Overwatch: todos los h\xc3\xa9roes</title><pubDate>Sat, 07 Nov 2026 08:00:00 GMT</pubDate></item>
<item><title>Overwatch presenta su nueva temporada</title><pubDate>Fri, 06 Nov 2026 18:00:00 GMT</pubDate></item>
<item><title>Nintendo anuncia un Direct</title><pubDate>Fri, 06 Nov 2026 10:00:00 GMT</pubDate></item>
<item><title>Noticia vieja de Overwatch</title><pubDate>Mon, 19 Oct 2026 10:00:00 GMT</pubDate></item>
</channel></rss>"""

SRC = {
    "follow": [
        {"label": "GTA VI", "keywords": ["GTA 6", "GTA VI"]},
        {"label": "Overwatch", "keywords": ["Overwatch"]},
    ],
    "news_count": 3, "news_max_age_days": 7, "news_exclude": ["guía"],
}


def test_news_follow_then_market():
    items = g.parse_feed(RSS, "Vandal")
    assert len(items) == 5
    out = g.pick_news(items, SRC, UTC)
    assert [n["label"] for n in out] == ["GTA VI", "Overwatch", "Mercado"]
    assert out[0]["title"] == "GTA 6: Rockstar muestra un nuevo tráiler"
    assert out[1]["title"] == "Overwatch presenta su nueva temporada"  # la guía se descarta
    assert out[2]["title"] == "Nintendo anuncia un Direct"


def test_weather():
    d = {"current": {"temperature_2m": 18.6, "weather_code": 2},
         "daily": {"temperature_2m_max": [21.7], "temperature_2m_min": [8.9]}}
    assert parse_weather(d) == {"temp": 19, "desc": "parcialmente nublado", "max": 22, "min": 9}


def test_releases_skip_past(tmp_path, monkeypatch):
    (tmp_path / "releases.yaml").write_text(
        "- {date: 2026-11-01, name: Pasado, platforms: [PS5]}\n"
        "- {date: 2026-11-19, name: GTA, platforms: [PS5], price: '79,99 €'}\n"
        "- {date: 2026-11-08, name: Mañana, platforms: [Mac]}\n", encoding="utf-8")
    monkeypatch.setattr(g, "HERE", tmp_path)
    r = g.releases(NOW.date())
    assert [x["name"] for x in r] == ["Mañana", "GTA"]
    assert r[0]["left"] == "mañana" and r[1]["left"] == "en 12 días"
    assert r[1]["meta"] == "PS5 · 79,99 €" and r[1]["mon"] == "NOV"


def test_steam_prices_best_discount():
    d = {
        "10": {"success": True, "data": {"price_overview": {"currency": "EUR", "initial": 3999, "final": 1599, "discount_percent": 60}}},
        "20": {"success": True, "data": {"price_overview": {"currency": "EUR", "initial": 1999, "final": 1999, "discount_percent": 0}}},
        "30": {"success": True, "data": []},   # juego gratis: Steam devuelve lista vacía
        "40": {"success": False},
    }
    p = g.parse_price_overview(d)
    assert len(p) == 1 and p[0]["appid"] == 10
    assert g.eur(p[0]["final"]) == "15,99€"


def test_specials_fallback():
    d = {"specials": {"items": [
        {"name": "A", "discount_percent": 20, "final_price": 800, "original_price": 1000},
        {"name": "B", "discount_percent": 75, "final_price": 499, "original_price": 1999},
    ]}}
    assert g.parse_specials(d, 50)["name"] == "B"


def test_free_games():
    items = [
        {"title": "Hogwarts Legacy (Epic Games) Giveaway", "platforms": "PC, Epic Games Store"},
        {"title": "Alien Breed (GOG) Giveaway", "platforms": "PC, GOG"},
        {"title": "Otro (Steam) Giveaway", "platforms": "PC, Steam"},
        {"title": "GMH - Good Morning Human Giveaways", "platforms": "PC, Epic Games Store"},
    ]
    assert g.parse_free(items) == [
        {"store": "Epic", "titles": ["Hogwarts Legacy", "GMH - Good Morning Human"]},
        {"store": "GOG", "titles": ["Alien Breed"]},
    ]


def test_countdown():
    assert countdown(0) == "hoy" and countdown(1) == "mañana" and countdown(5) == "en 5 días"
