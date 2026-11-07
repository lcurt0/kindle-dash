"""Guardas para los scripts del Kindle: lo que se rompe acá se rompe en el
aparato, donde arreglarlo es más difícil. Corren en cada render."""
import json
import re
import subprocess
from pathlib import Path

import build

ROOT = Path(__file__).resolve().parent.parent
KDIR = ROOT / "kindle" / "dashboard"


def test_file_lists_match():
    # build.py publica KINDLE_FILES; update.sh descarga FILES. Deben coincidir,
    # o el Kindle pediría un archivo que no existe y nunca se actualizaría.
    sh = (KDIR / "update.sh").read_text()
    files = re.search(r'^FILES="([^"]+)"', sh, re.M).group(1).split()
    assert files == build.KINDLE_FILES
    for f in files:
        assert (KDIR / f).is_file(), f"falta {f}"


def test_shell_syntax():
    for f in KDIR.rglob("*.sh"):
        r = subprocess.run(["sh", "-n", str(f)], capture_output=True, text=True)
        assert r.returncode == 0, f"{f.name}: {r.stderr}"


def test_never_insecure_tls():
    # Los scripts se ejecutan como root en el Kindle: nunca aceptar TLS sin verificar.
    for f in KDIR.rglob("*.sh"):
        text = f.read_text()
        assert not re.search(r"curl[^\n]*\s-[A-Za-z]*k", text), f"curl -k en {f.name}"
        assert "--insecure" not in text, f"--insecure en {f.name}"


def test_scripts_only_over_https():
    assert "--proto =https" in (KDIR / "update.sh").read_text()
    url = re.search(r'DASH_URL="([^"]+)"', (KDIR / "local" / "env.sh").read_text()).group(1)
    assert url.startswith("https://")


def test_kual_menu_valid():
    menu = json.loads((ROOT / "kindle" / "extensions" / "kindle-dash" / "menu.json").read_text())
    names = [i["name"] for i in menu["items"][0]["items"]]
    assert "Iniciar dashboard" in names and "Restaurar versión anterior" in names


def test_version_is_stable():
    assert build.kindle_version() == build.kindle_version()
    assert re.fullmatch(r"[0-9a-f]{12}", build.kindle_version())


def test_next_wakeup_math():
    env = {"WAKE_MINUTES": "15", "WAKE_FROM": "7", "WAKE_TO": "23", "PATH": "/usr/bin:/bin"}
    cases = {"12 58 00": 1020, "23 20 00": 28500, "07 14 50": 3610, "02 00 00": 18900}
    for now, expected in cases.items():
        out = subprocess.run(["sh", str(KDIR / "next-wakeup.sh")], env={**env, "NOW": now},
                             capture_output=True, text=True).stdout.strip()
        assert int(out) == expected, f"{now}: {out} != {expected}"
