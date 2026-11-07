# Kindle Dash · Lo justo

Un Kindle Paperwhite viejo convertido en pantalla e‑ink para el escritorio.
GitHub genera una imagen cada 30 minutos; el Kindle se despierta una vez por hora,
la descarga, la muestra y vuelve a dormir. De noche no hace nada.

```
GitHub Actions (cada 30 min)          Kindle (cada hora, 7–23 h)
  datos → HTML → PNG 1072×1448   →   despierta → baja dash.png → muestra → duerme
            │
            └─ GitHub Pages: https://<usuario>.github.io/kindle-dash/dash.png
```

Vista previa en el navegador: `https://<usuario>.github.io/kindle-dash/`

---

## Puesta en marcha

### 1. GitHub (una sola vez)

1. El repo tiene que ser **público** (GitHub Pages gratis lo requiere).
2. **Settings → Pages → Build and deployment → Source: GitHub Actions.**
3. **Actions → Render dashboard → Run workflow** para la primera imagen.
   A partir de ahí corre solo.

### 2. Kindle

Requisitos: jailbreak con WinterBreak + hotfix, KUAL instalado y actualizaciones
bloqueadas. Guía: https://kindlemodding.org

1. Descargá la última release de [kindle-dash](https://github.com/pascalw/kindle-dash/releases)
   y descomprimila. Trae los binarios para el Kindle (`xh`, `next-wakeup`).
2. Copiá encima los archivos de la carpeta `kindle/` de este repo, reemplazando:
   - `dash.sh` → versión adaptada al Paperwhite 7
   - `sleeping.png` → pantalla de noche
   - `local/env.sh`, `local/fetch-dashboard.sh`
3. Revisá la URL en `local/env.sh` (`DASH_URL`).
4. Conectá el Kindle por USB y copiá esa carpeta como `dashboard` en la raíz
   (queda en `/mnt/us/dashboard`). Copiá también `KUAL/kindle-dash` dentro de `extensions/`.
5. Conectá el Kindle al Wi‑Fi, abrí **KUAL → Kindle Dashboard**.

**Salir del dashboard:** mantené el botón de encendido ~30 s. Reinicia normal.

**Si algo no anda:** conectá por USB y abrí `dashboard/logs/dash.log`.

---

## Editar el contenido (sin tocar código)

Todo está en `screens/gaming/`:

| Archivo | Qué controla |
|---|---|
| `sources.yaml` | juegos que seguís, medios RSS, wishlist de Steam |
| `releases.yaml` | fechas de lanzamiento clave (las pasadas se borran solas) |
| `template.html` | diseño de la pantalla |

Cada cambio que subas a `main` regenera la imagen al momento.

## Horarios

- **Servidor:** `.github/workflows/render.yml` → `cron`
- **Kindle:** `kindle/local/env.sh` → `REFRESH_SCHEDULE`
- **Qué pantalla cuándo:** `config.yaml` → `rotation`

## Agregar una pantalla nueva

```
screens/semanal/
  data.py        → función collect(cfg, now) que devuelve un dict
  template.html  → {% extends "base.html" %} y bloques style / content
```

Después sumala a `rotation` en `config.yaml`. El Kindle no se toca.

## Probar en local

```bash
pip install -r requirements.txt && python -m playwright install chromium
python build.py --sample   # datos de ejemplo, sin red
python build.py            # datos reales
open out/dash.png
```

## Fuentes de datos

Open‑Meteo (tiempo), RSS de medios (noticias), Steam Store (ofertas en euros),
GamerPower (gratis de Epic y GOG). Ninguna pide clave. Si una falla, su bloque
queda vacío; si fallan todas, no se publica y el Kindle mantiene la imagen anterior.

---

`kindle/dash.sh` está basado en [pascalw/kindle-dash](https://github.com/pascalw/kindle-dash) (MIT).
