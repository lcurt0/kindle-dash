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

No hace falta descargar nada más: todo lo que corre en el Kindle está en `kindle/`.

1. Conectá el Kindle por USB.
2. Copiá `kindle/dashboard` a la raíz del Kindle (queda `/mnt/us/dashboard`).
3. Copiá `kindle/extensions/kindle-dash` dentro de `extensions/` del Kindle.
4. Expulsá el Kindle, conectalo al Wi‑Fi y abrí **KUAL → Lo justo · Dashboard**:
   - **Probar una descarga**: baja la imagen una vez y la muestra. Ideal para la primera prueba.
   - **Iniciar dashboard**: arranca el ciclo despertar → descargar → dormir.
   - **Detener y volver al Kindle**: vuelve a la interfaz normal.

**Un clic al botón de encendido** prende la luz unos segundos y, de día, baja la
imagen más reciente. Para forzar contenido nuevo: *Actions → Render dashboard →
Run workflow*, esperá un minuto y hacé clic en el Kindle.

Horario y zona en `dashboard/local/env.sh`. Por defecto actualiza a las y cuarto
de 7:15 a 22:15 y muestra la pantalla de noche de 23:15 a 7:15.

**Si algo no anda:** conectá por USB y mirá `dashboard/logs/dash.log`
(o `logs/prueba.log` para la descarga de prueba).

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
- **Kindle:** `kindle/dashboard/local/env.sh` → `WAKE_MINUTES`, `WAKE_FROM`, `WAKE_TO`
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

`kindle/dashboard/dash.sh` está basado en [pascalw/kindle-dash](https://github.com/pascalw/kindle-dash) (MIT).
