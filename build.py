"""Genera out/dash.png para el Kindle.

Uso:
  python build.py                  # elige pantalla según config.yaml y usa datos reales
  python build.py --screen gaming  # fuerza una pantalla
  python build.py --sample         # usa datos de ejemplo (tests/sample_<pantalla>.json), sin red
"""
from __future__ import annotations

import argparse
import datetime as dt
import importlib
import json
import logging
import sys
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader, select_autoescape
from PIL import Image
from playwright.sync_api import sync_playwright

from common.lib import now_ctx, safe, weather

ROOT = Path(__file__).parent
OUT = ROOT / "out"
DIAS = ["lun", "mar", "mie", "jue", "vie", "sab", "dom"]

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger("dash")


# Archivos que el Kindle se autoactualiza (debe coincidir con FILES en update.sh).
KINDLE_FILES = ["dash.sh", "start.sh", "stop.sh", "next-wakeup.sh", "wait-for-wifi.sh",
                "update.sh", "restore.sh", "sleeping.png", "local/env.sh",
                "local/fetch-dashboard.sh"]


def kindle_version() -> str:
    """Huella del contenido de los scripts del Kindle: cambia sólo si cambian."""
    import hashlib
    h = hashlib.sha256()
    for f in KINDLE_FILES:
        h.update(f.encode() + b"\0" + (ROOT / "kindle" / "dashboard" / f).read_bytes())
    return h.hexdigest()[:12]


def publish_kindle(out: Path) -> str:
    import shutil
    dst = out / "kindle"
    for f in KINDLE_FILES:
        (dst / f).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "kindle" / "dashboard" / f, dst / f)
    v = kindle_version()
    (dst / "version.txt").write_text(v + "\n")
    return v


def pick_screen(cfg: dict, n: dt.datetime) -> str:
    for rule in cfg.get("rotation") or []:
        days = rule.get("days") or DIAS
        lo, hi = rule.get("hours", [0, 24])
        if DIAS[n.weekday()] in days and lo <= n.hour < hi:
            return rule["screen"]
    return cfg["default_screen"]


def render_png(html_path: Path, png_path: Path, w: int, h: int) -> None:
    raw = png_path.with_suffix(".raw.png")
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": w, "height": h}, device_scale_factor=1)
        # Todo es local (fuentes del sistema, sin recursos externos).
        page.goto(html_path.resolve().as_uri(), wait_until="load")
        page.evaluate("document.fonts.ready")
        page.screenshot(path=str(raw), full_page=False)
        browser.close()

    # 8 bits en escala de grises, cuantizado a los 16 niveles del panel.
    img = Image.open(raw).convert("L").point(lambda v: round(v / 17) * 17)
    img.save(png_path, optimize=True)
    raw.unlink()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--screen")
    ap.add_argument("--sample", action="store_true")
    ap.add_argument("--kindle-version", action="store_true", help="imprime la versión de los scripts del Kindle")
    args = ap.parse_args()
    if args.kindle_version:
        print(kindle_version())
        return 0

    cfg = yaml.safe_load((ROOT / "config.yaml").read_text(encoding="utf-8"))
    now = now_ctx(cfg["timezone"])
    screen = args.screen or pick_screen(cfg, now["dt"])
    log.info("Pantalla: %s (%s %s)", screen, now["weekday_short"], now["hhmm"])

    if args.sample:
        ctx = json.loads((ROOT / "tests" / f"sample_{screen}.json").read_text(encoding="utf-8"))
    else:
        mod = importlib.import_module(f"screens.{screen}.data")
        ctx = mod.collect(cfg, now)
        ctx["weather"] = safe("weather", lambda: weather(cfg["location"], cfg["timezone"]))
        # Si no llegó nada de la red, mejor no publicar: el Kindle se queda
        # con la última imagen buena en lugar de una pantalla vacía.
        if not ctx.get("weather") and not ctx.get("news"):
            log.error("Sin datos de red: no se publica esta vez.")
            return 3

    env = Environment(
        loader=FileSystemLoader([ROOT / "screens" / screen, ROOT / "common"]),
        autoescape=select_autoescape(["html"]),
    )
    html = env.get_template("template.html").render(cfg=cfg, now=now, **ctx)

    OUT.mkdir(exist_ok=True)
    html_path = OUT / "dash.html"
    html_path.write_text(html, encoding="utf-8")
    render_png(html_path, OUT / "dash.png", cfg["width"], cfg["height"])

    # Página mínima para mirar el resultado desde el navegador.
    (OUT / "index.html").write_text(
        '<!doctype html><meta charset="utf-8"><title>Kindle Dash</title>'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<body style="margin:0;background:#ddd;display:grid;place-items:center;min-height:100vh">'
        '<img src="dash.png" style="max-width:100%;max-height:100vh;box-shadow:0 4px 24px #0003">',
        encoding="utf-8",
    )
    (OUT / "status.json").write_text(json.dumps(
        {"screen": screen, "generated": now["dt"].isoformat()}, ensure_ascii=False), encoding="utf-8")
    log.info("Scripts del Kindle publicados, versión %s", publish_kindle(OUT))
    log.info("Listo: %s", OUT / "dash.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
