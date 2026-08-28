# Cloudflare Tunnel + Access — referencia completa

En este piloto, Cloudflare cumple dos roles puntuales: **Tunnel** expone Open WebUI (y opcionalmente el monitor de estado) a internet sin abrir puertos en el router de casa, y **Access** exige login antes de dejar pasar tráfico a esas rutas (ver `../06-operacion/02-acceso-remoto.md`). Este documento no cubre el catálogo completo de Cloudflare (Workers, DNS avanzado, WAF) — solo lo configurado realmente en este proyecto. Verificado contra `developers.cloudflare.com/cloudflare-one`, 2026-08-27.

## El tipo de túnel usado acá: remotely-managed

Cloudflare distingue dos formas de administrar un túnel:

- **Remotely-managed** (la usada en este piloto, creada desde el dashboard de Zero Trust) — la configuración (rutas, Public Hostnames) vive en Cloudflare, no en un archivo local. Se instala con un solo comando y un token: `cloudflared service install <token>` (ver `08-instalar-cloudflared.ps1`).
- **Locally-managed** (no usada acá) — se crea por CLI (`cloudflared tunnel create <NOMBRE>`) y la configuración vive en un `config.yml` local. Cloudflare la reserva para desarrollo local o casos legacy, y recomienda la remotely-managed para el resto.

**Por qué remotely-managed es la elegida:** es la que recomienda la propia documentación de Cloudflare para el caso general, y en la práctica significa que agregar o cambiar una ruta se hace entero desde el dashboard, sin tocar el equipo de casa.

## Cómo se agrega una ruta nueva (Public Hostname)

Zero Trust dashboard → Networks → Tunnels → (el túnel de este piloto) → pestaña **Public Hostname** → *Add a public hostname* → subdominio elegido + servicio local (`http://localhost:PUERTO`). Cloudflare crea sola el registro DNS (`CNAME` hacia `<uuid-del-túnel>.cfargotunnel.com`) — no hay que tocar el DNS a mano.

Ya usado así dos veces en este piloto (mismo túnel, dos rutas — no hace falta un túnel por servicio):
- Open WebUI → `http://localhost:8080` (ver `../06-operacion/02-acceso-remoto.md`).
- Monitor de estado → `http://localhost:8090` (ver `../06-operacion/03-monitor-estado.md`), paso opcional.

**Pendiente de confirmar en la práctica:** la documentación oficial no dice explícitamente si una ruta agregada en el dashboard queda activa de inmediato o si `cloudflared` necesita reiniciarse — es consistente con el diseño remotely-managed (la config vive en Cloudflare, no en el equipo) que se aplique sin reinicio, pero no se encontró una confirmación textual de Cloudflare; queda por verificar la primera vez que se agregue una ruta nueva en el equipo real.

## Comandos y mantenimiento en Windows

| Comando | Qué hace |
|---|---|
| `cloudflared service install <token>` | Registra `cloudflared` como servicio de Windows, apuntado al túnel del token dado (paso único, ya en `08-instalar-cloudflared.ps1`). |
| `Get-Service -Name cloudflared` | Verifica que el servicio está corriendo. |

**`cloudflared` no se autoactualiza en Windows** (confirmado, ya señalado en `08-instalar-cloudflared.ps1`) — queda en el checklist mensual de `../06-operacion/01-mantenimiento.md`, hay que revisarlo a mano.

## Cloudflare Access — el gate delante del túnel

Zero Trust → Access controls → Applications → una política que exige login (código al correo, o Google) antes de dejar pasar a la ruta del túnel. En este piloto, la lista de correos autorizados es uno solo (el de Felipe) — ver `../06-operacion/02-acceso-remoto.md` para la decisión completa y por qué es la recomendación oficial de la propia guía de hardening de Open WebUI.

**Service Tokens (para clientes no interactivos, ej. Qwen Code remoto vía Escenario C2):** en vez de login humano, dos headers — `CF-Access-Client-Id` y `CF-Access-Client-Secret` — con la política de esa ruta puesta en modo "Service Auth". Se generan desde Access controls → Service credentials → Service Tokens (el Client Secret se muestra **una sola vez**, hay que guardarlo ahí mismo). **Sin confirmar si vienen incluidos en el plan gratis** — investigado a fondo contra documentación oficial sin encontrar una respuesta explícita (ver el detalle completo de esa investigación en `../03-herramientas/02-qwen-code-a-fondo.md`); no bloquea nada porque Tailscale (C1) es el camino recomendado y no depende de esto.

## Costo (verificado)

- **Cloudflare Tunnel:** sin costo aparte, incluido en cualquier cuenta (incluida la gratuita), sin límite de túneles ni de tráfico.
- **Cloudflare Access:** gratis hasta 50 usuarios — un solo correo autorizado está muy por debajo del límite.

(Ambos ya verificados y citados en `../06-operacion/02-acceso-remoto.md`, 2026-08-26 — no se repite la fuente de precios acá.)

## Fuentes consultadas (2026-08-27)

- [Connect networks — Cloudflare One Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Useful terms — Cloudflare One Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/tunnel-useful-terms/) — distinción remotely-managed vs. locally-managed.
- [Cloudflare Tunnel — Cloudflare One Docs](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)
- [Service Tokens — Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/identity/service-tokens/)
