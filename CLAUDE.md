# Kindle Dash — reglas del proyecto

Dashboard e‑ink para un Kindle Paperwhite 7ª gen (firmware 5.16, jailbreak
WinterBreak, KUAL) en el escritorio de Lau. Primera pantalla: "Lo justo ·
gaming", parte de un detox digital: contenido finito y curado, nada urgente.
El usuario es diseñador de producto; los cambios visuales se cuidan como diseño.

## Cómo funciona

- **GitHub Actions** (`.github/workflows/render.yml`) corre cada 30 min de 06:00 a
  23:30 (Madrid), en cada push a `main` y a mano. `build.py` elige la pantalla
  según `config.yaml`, junta datos, renderiza HTML → PNG 1072×1448 en 16 grises
  y publica en GitHub Pages: `https://lcurt0.github.io/kindle-dash/dash.png`.
- **Kindle** (`kindle/dashboard/`, copiado a `/mnt/us/dashboard`): apaga la
  interfaz de Amazon, se despierta por RTC a las y cuarto de 7:15 a 22:15, baja la
  imagen y se suspende. 23:15–7:15 muestra `sleeping.png`. Un clic al botón de
  encendido = luz `TAP_LIGHT_SECONDS` + descarga; de noche vuelve a la pantalla
  de noche al apagarse la luz.
- **Autoactualización**: en cada despertar programado `update.sh` compara
  `version.txt` con `…/kindle/version.txt` publicado, baja todo a `.update/`,
  valida con `sh -n`, respalda en `.backup/` y reinicia con `exec … resumed`.
  KUAL → "Restaurar versión anterior" vuelve atrás y marca esa versión en
  `.skip-version`.

## Reglas que no se rompen

1. **TLS siempre verificado** en el Kindle. Nada de `curl -k`/`--insecure`; los
   scripts se ejecutan como root. `tests/test_kindle.py` lo controla.
2. **La lista de archivos del Kindle** está en dos lugares: `KINDLE_FILES` en
   `build.py` y `FILES` en `kindle/dashboard/update.sh`. Deben coincidir (test).
3. **Todo lo publicado es público** (repo y Pages). Nada personal ni secreto en
   pantallas, configuración o logs. La futura pantalla semanal personal NO puede
   publicarse en una URL abierta: requiere resolver privacidad primero.
4. **`/mnt/us` es FAT y el usuario reinicia a lo bruto** (botón 40 s): toda
   escritura importante va seguida de `sync`, y siempre antes de suspender.
   Sin eso se perdieron logs y `dash.png` quedó en 0 bytes (test lo controla).
5. **Un cambio en `kindle/dashboard/` llega al aparato solo y lo ejecuta como
   root.** Probar la lógica antes de push (simulación local con servidor y `eips`
   falso) y mantener los scripts compatibles con busybox `sh`.
6. **Si fallan todas las fuentes, no se publica** (exit 3): el Kindle conserva la
   última imagen buena. Cada fuente va envuelta en `safe()`.
7. **Diseño e‑ink**: negro, blanco y dos grises (`--mid #555`, `--soft #bbb`);
   sin líneas de 1 px; textos acotados con clamp para que nunca se corte el pie;
   probar el peor caso (titulares y nombres largos).
8. Dependencias y acciones **fijadas** (versiones exactas / commit SHA).
   Dependabot propone actualizaciones mensuales como PR.

## Tareas frecuentes

- Contenido: `screens/gaming/sources.yaml` (juegos, feeds, wishlist de Steam) y
  `releases.yaml` (lanzamientos; las fechas pasadas se borran solas).
- Nueva pantalla: `screens/<nombre>/data.py` con `collect(cfg, now)` +
  `template.html` que extiende `base.html`; sumarla a `rotation` en `config.yaml`.
- Probar: `python -m pytest -q tests` y `python build.py --sample`.
- Diagnóstico del Kindle: `dashboard/logs/dash.log` (por USB, montado en
  `/Volumes/Kindle` en la Mac de Lau).
- Commits en español, descriptivos.
