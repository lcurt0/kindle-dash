"""Pantalla GAMING: junta noticias, lanzamientos, ofertas y gratis.

Cada fuente es independiente y tolerante a fallos (ver lib.safe).
Las funciones parse_* no hacen red, así se pueden testear con fixtures.
"""
from __future__ import annotations

import calendar
import datetime as dt
import html
import re
from pathlib import Path

import feedparser
import yaml

from common.lib import DIAS, MESES_CORTOS, countdown, get_bytes, get_json, log, safe

HERE = Path(__file__).parent


# ── Noticias ──────────────────────────────────────────────────

def _norm(s: str) -> str:
    return re.sub(r"\W+", " ", s.lower()).strip()


def parse_feed(raw: bytes, source: str) -> list[dict]:
    feed = feedparser.parse(raw)
    items = []
    for e in feed.entries:
        t = e.get("published_parsed") or e.get("updated_parsed")
        if not t or not e.get("title"):
            continue
        items.append({
            "title": html.unescape(e.title).strip(),
            "source": source,
            "ts": dt.datetime.fromtimestamp(calendar.timegm(t), dt.timezone.utc),
        })
    return items


def pick_news(items: list[dict], src: dict, now: dt.datetime) -> list[dict]:
    max_age = dt.timedelta(days=src.get("news_max_age_days", 7))
    excl = [_norm(w) for w in src.get("news_exclude", [])]
    pool, seen = [], set()
    for it in sorted(items, key=lambda i: i["ts"], reverse=True):
        key = _norm(it["title"])
        if key in seen or now - it["ts"] > max_age:
            continue
        if any(w and w in key for w in excl):
            continue
        seen.add(key)
        pool.append(it)

    out, used = [], set()
    for g in src.get("follow", []):
        kws = [_norm(k) for k in g["keywords"]]
        for it in pool:
            if id(it) in used:
                continue
            if any(re.search(rf"\b{re.escape(k)}\b", _norm(it["title"])) for k in kws):
                out.append({**it, "label": g["label"]})
                used.add(id(it))
                break

    n = src.get("news_count", 3)
    for it in pool:
        if len(out) >= n:
            break
        if id(it) not in used:
            out.append({**it, "label": "Mercado"})
            used.add(id(it))
    return out[:n]


def news(src: dict, now: dt.datetime) -> list[dict]:
    items = []
    for f in src.get("feeds", []):
        items += safe(f"rss:{f['name']}", lambda f=f: parse_feed(get_bytes(f["url"]), f["name"]), [])
    return pick_news(items, src, now)


# ── Lanzamientos ──────────────────────────────────────────────

def releases(today: dt.date, limit: int = 3) -> list[dict]:
    rows = yaml.safe_load((HERE / "releases.yaml").read_text(encoding="utf-8")) or []
    up = sorted((r for r in rows if r["date"] >= today), key=lambda r: r["date"])[:limit]
    out = []
    for r in up:
        meta = list(r.get("platforms") or [])
        if r.get("price"):
            meta.append(str(r["price"]))
        out.append({
            "day": f"{r['date'].day:02d}",
            "mon": MESES_CORTOS[r["date"].month - 1],
            "name": r["name"],
            "meta": " · ".join(meta),
            "left": countdown((r["date"] - today).days),
        })
    return out


# ── Ofertas (Steam, precios en euros) ─────────────────────────

def eur(cents: int) -> str:
    return f"{cents / 100:.2f}".replace(".", ",") + "€"


def _ends(ts: int | None, now: dt.datetime) -> str:
    if not ts:
        return ""
    end = dt.datetime.fromtimestamp(ts, now.tzinfo)
    days = (end.date() - now.date()).days
    if days <= 0:
        return "termina hoy"
    if days == 1:
        return "termina mañana"
    if days < 7:
        return f"termina el {DIAS[end.weekday()].lower()}"
    return f"termina el {end.day}/{end.month}"


def parse_price_overview(d: dict) -> list[dict]:
    out = []
    for appid, v in d.items():
        po = (v or {}).get("data") or {}
        po = po.get("price_overview") if isinstance(po, dict) else None
        if v.get("success") and po and po.get("discount_percent", 0) > 0:
            out.append({"appid": int(appid), **po})
    return sorted(out, key=lambda p: p["discount_percent"], reverse=True)


def parse_specials(d: dict, min_disc: int) -> dict | None:
    for it in d.get("specials", {}).get("items", []):
        if it.get("discount_percent", 0) >= min_disc and it.get("final_price"):
            return it
    return None


def steam_wishlist(steam_id: str) -> list[int]:
    d = get_json("https://api.steampowered.com/IWishlistService/GetWishlist/v1/", steamid=steam_id)
    return [i["appid"] for i in d.get("response", {}).get("items", [])]


def deal(src: dict, now: dt.datetime) -> dict | None:
    ids = list(src.get("wishlist") or [])
    if src.get("steam_id"):
        ids += safe("steam:wishlist", lambda: steam_wishlist(src["steam_id"]), [])
    ids = list(dict.fromkeys(ids))[:60]

    if ids:
        prices = safe("steam:prices", lambda: parse_price_overview(get_json(
            "https://store.steampowered.com/api/appdetails",
            appids=",".join(map(str, ids)), cc="es", filters="price_overview")), [])
        if prices:
            best = prices[0]
            info = safe("steam:name", lambda: get_json(
                "https://store.steampowered.com/api/appdetails",
                appids=best["appid"], cc="es", l="spanish"), {})
            name = (info.get(str(best["appid"]), {}).get("data") or {}).get("name", f"App {best['appid']}")
            return {
                "heading": "De tu wishlist",
                "name": name,
                "meta": "Steam",
                "discount": best["discount_percent"],
                "final": eur(best["final"]),
                "initial": eur(best["initial"]),
            }

    sp = safe("steam:specials", lambda: parse_specials(
        get_json("https://store.steampowered.com/api/featuredcategories", cc="es", l="spanish"),
        src.get("fallback_min_discount", 50)))
    if not sp:
        return None
    meta = " · ".join(x for x in ["Steam", _ends(sp.get("discount_expiration"), now)] if x)
    return {
        "heading": "La oferta de la semana",
        "name": sp["name"],
        "meta": meta,
        "discount": sp["discount_percent"],
        "final": eur(sp["final_price"]),
        "initial": eur(sp["original_price"]),
    }


# ── Gratis (Epic / GOG vía GamerPower) ────────────────────────

STORES = {"Epic Games Store": "Epic", "GOG": "GOG"}


def clean_giveaway(title: str) -> str:
    t = re.sub(r"\s*\([^)]*\)", "", title)
    t = re.sub(r"\s*(Giveaway|Free Download|Free)\s*$", "", t, flags=re.I)
    return t.strip(" -–")


def parse_free(items: list[dict], per_store: int = 2) -> list[dict]:
    groups: dict[str, list[str]] = {}
    for it in items:
        plats = [p.strip() for p in it.get("platforms", "").split(",")]
        for p, short in STORES.items():
            if p in plats:
                name = clean_giveaway(it.get("title", ""))
                if name and name not in groups.setdefault(short, []) and len(groups[short]) < per_store:
                    groups[short].append(name)
    return [{"store": s, "titles": t} for s, t in groups.items() if t]


def free(src: dict) -> list[dict]:
    plats = ".".join(src.get("free_platforms", ["epic-games-store", "gog"]))
    items = safe("gamerpower", lambda: get_json(
        "https://www.gamerpower.com/api/giveaways", platform=plats, type="game"), [])
    # GamerPower responde un objeto (no lista) cuando no hay resultados.
    return parse_free(items if isinstance(items, list) else [])


# ── Punto de entrada de la pantalla ───────────────────────────

def collect(cfg: dict, now: dict) -> dict:
    src = yaml.safe_load((HERE / "sources.yaml").read_text(encoding="utf-8"))
    n = now["dt"]
    ctx = {
        "kicker": "Lo justo · gaming",
        "news": news(src, n.astimezone(dt.timezone.utc)),
        "releases": safe("releases", lambda: releases(now["date"]), []),
        "deal": deal(src, n),
        "free": free(src),
    }
    log.info("gaming: %d noticias, %d lanzamientos, oferta=%s, gratis=%d",
             len(ctx["news"]), len(ctx["releases"]), bool(ctx["deal"]), len(ctx["free"]))
    return ctx
