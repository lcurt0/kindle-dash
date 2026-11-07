# Kindle Dash · Lo justo — documento del proyecto

*Compilado el 7 de noviembre de 2026. Fuente de verdad técnica: el repo
[lcurt0/kindle-dash](https://github.com/lcurt0/kindle-dash) y su `CLAUDE.md`.*

## Qué es

Un Kindle Paperwhite 7ª gen convertido en una pantalla e‑ink de escritorio que
se actualiza sola. La primera pantalla es **"Lo justo · gaming"**, parte de un
detox digital: enterarse de lo importante de videojuegos sin abrir redes, con
contenido finito y curado. El sistema está pensado para sumar más pantallas
(la siguiente: un semanal personal).

Principios que guiaron todas las decisiones:

- **Autónomo y de bajo consumo.** El Kindle duerme casi todo el tiempo y no
  depende de ninguna compu encendida.
- **Nada urgente.** Se actualiza una vez por hora y de noche descansa.
- **A prueba de futuro.** Dependencias fijadas, tests que protegen el aparato,
  autoactualización con respaldo y reglas escritas.

## Cómo funciona

```
GitHub Actions (cada 30 min, 06:00–23:30)        Kindle (y cuarto, 7:15–22:15)
  RSS · Steam · Open-Meteo · GamerPower     →      despierta (reloj o botón)
  → HTML → PNG 1072×1448, 16 grises                → baja dash.png → dibuja
  → GitHub Pages (dash.png + scripts)              → ¿scripts nuevos? → duerme
```

- **Servidor:** GitHub Actions genera la imagen y la publica en
  `https://lcurt0.github.io/kindle-dash/dash.png`. Vista previa:
  `https://lcurt0.github.io/kindle-dash/`.
- **Kindle:** apaga la interfaz de Amazon, se despierta a las y cuarto, baja la
  imagen, la dibuja y se suspende. De 23:15 a 7:15 muestra "Fuera de horario".
- **Botón de encendido (un clic):** prende la luz 20 s y baja la imagen más
  reciente. De noche, al apagarse la luz, vuelve la pantalla de noche.
- **Autoactualización:** en cada despertar programado el Kindle compara su
  versión con la publicada y, si cambió, instala los scripts nuevos con
  verificación y respaldo. KUAL → "Restaurar versión anterior" para volver atrás.

## La pantalla gaming

| Bloque | Fuente | Notas |
|---|---|---|
| Encabezado | Open‑Meteo | fecha, semana y tiempo en Córdoba |
| Tus juegos | RSS (Vandal, 3DJuegos, VidaExtra) | 1 noticia por juego seguido, se completa con "Mercado" |
| Próximos lanzamientos | `releases.yaml`, curado a mano | 3 más cercanos; los pasados se borran solos |
| Oferta | Steam (precios en €) | de la wishlist; si no hay, la mejor destacada ≥50 % |
| Gratis | GamerPower | Epic y GOG, una línea |
| Pie | — | "Datos de las HH:MM": hora del render, no de la descarga |

Diseño e‑ink: negro, blanco y dos grises; sin líneas finas; textos acotados para
que nunca se corte el pie; probado con el peor caso.

## Decisiones y por qué

- **Imagen generada en servidor, no web en el Kindle.** Control total del diseño
  y consumo casi nulo. El navegador del Kindle es pobre con CSS moderno.
- **GitHub Pages + Actions.** Gratis, sin servidor propio, y cada cambio en el
  repo regenera la imagen.
- **Dashboard propio en vez del salvapantallas de Amazon.** Más control del
  horario y de la pantalla; a cambio, para salir hay que reiniciar.
- **Sin binarios de terceros en el Kindle.** Se usa el `curl` del propio aparato
  y el horario se calcula en shell.
- **El botón y no la pantalla táctil.** Suspendido, el táctil no existe para el
  sistema; solo el reloj o el botón lo despiertan.
- **Render cada 30 min.** Para un detox, media hora de margen alcanza; generar
  "en el momento" del clic exigiría tener el Kindle despierto un minuto y una
  clave de GitHub guardada en el aparato.

## Problemas que aparecieron y cómo se resolvieron

1. **El dashboard moría al iniciar.** KUAL corre dentro de la interfaz de
   Amazon; al apagarla se mataba también al dashboard. → Se lanza con `setsid`.
2. **"Actualizado" parecía no cambiar.** Era la hora del render, no de la
   descarga. → El pie dice "Datos de las HH:MM".
3. **`dash.png` en 0 bytes y log incompleto.** La memoria del Kindle es FAT y un
   reinicio brusco perdía lo no grabado. → `sync` tras cada escritura y antes de
   dormir.
4. **TLS sin verificar en la autoactualización.** Lo frenó un control de
   seguridad. → Eliminado: los scripts solo se bajan por HTTPS verificado.
5. **Dependabot propuso una versión incompatible de `pyee`.** → Se ignoran las
   dependencias internas de Playwright.

## Seguridad

- El Kindle no abre puertos; solo hace pedidos salientes por HTTPS verificado.
- El repo es público: nada personal ni secreto en pantallas ni configuración.
- La llave real es la cuenta de GitHub (quien publique en el repo controla el
  Kindle): **verificación en dos pasos activada**.
- La pantalla semanal personal **no puede ir a una URL pública**: hay que
  resolver la privacidad antes de construirla.

## Cómo operarlo

| Quiero… | Cómo |
|---|---|
| Ver lo último ya | Un clic al botón de encendido |
| Datos frescos al minuto | GitHub → Actions → Render dashboard → Run workflow, y después clic |
| Cambiar juegos, medios o wishlist | `screens/gaming/sources.yaml` |
| Agregar lanzamientos | `screens/gaming/releases.yaml` |
| Cambiar horario del Kindle | `kindle/dashboard/local/env.sh` (llega solo) |
| Salir al Kindle normal | Mantener el botón 40 s |
| Volver atrás una actualización | Reiniciar → KUAL → Restaurar versión anterior |
| Diagnosticar | Enchufar por USB y pedirle a Claude que lea `dashboard/logs/dash.log` |

## Estado (7/11/2026)

- ✅ Render real con todas las fuentes, publicado en Pages.
- ✅ Kindle con jailbreak, dashboard corriendo, botón probado (luz + descarga).
- ✅ Autoactualización instalada (versión `6e8209ff51cd`).
- ✅ Blindaje: dependencias y acciones fijadas, 15 tests, Dependabot mensual.
- ⏳ Falta confirmar un despertar automático por reloj (primero: 14:15).

## Pendientes

1. **Lanzamientos:** curar una lista corta nov–ene para PS5, Switch, Mac y
   Steam Deck (sin Xbox).
2. **Wishlist de Steam:** SteamID64 (si es pública) o IDs de juegos a vigilar.
3. **Overwatch:** sumar una fuente específica; los medios en español casi no lo cubren.
4. **Pantalla semanal personal:** definir contenido y resolver privacidad.
