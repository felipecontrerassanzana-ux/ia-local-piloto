# Tailscale — referencia completa (acceso remoto a los agentes de código)

En este piloto, Tailscale cumple un solo rol: conectar Qwen Code/Goose desde un dispositivo fuera de la red de casa directo al Ollama de este equipo, sin exponer nada a internet público (Escenario C1 de `../03-herramientas/02-qwen-code-a-fondo.md`). Este documento no cubre el catálogo completo de Tailscale (ACLs, subredes compartidas, nodos de salida) porque no hacen falta para un solo usuario con dispositivos propios — solo lo necesario para este caso de uso. Verificado contra `tailscale.com/kb`, 2026-08-27.

## CLI — comandos relevantes para este piloto

| Comando | Qué hace |
|---|---|
| `tailscale up` | Conecta este equipo a la red privada (tailnet) — la primera vez abre una URL en el navegador para autenticar con la cuenta (Google/Microsoft/GitHub/correo). Paso manual, no automatizado por `14-instalar-tailscale.ps1` a propósito (es específico de la cuenta de Felipe). |
| `tailscale status` | Lista los dispositivos conectados a la tailnet y su estado. `--json` para salida estructurada. |
| `tailscale ip -4` | Muestra la IP privada de Tailscale de este equipo (`100.x.y.z`) — la que va en `baseUrl` de `~/.qwen/settings.json` cuando Qwen Code corre en otro dispositivo. |
| `tailscale down` | Desconecta este equipo de la tailnet sin cerrar sesión (se puede reconectar con `tailscale up` sin volver a autenticar). |
| `tailscale logout` | Cierra sesión por completo — hay que volver a autenticar con `tailscale up`. |

**Nota sobre autenticación no interactiva:** existe `tailscale up --auth-key=<key>` (generando la key desde `dashboard.tailscale.com`) para evitar el login por navegador — no se usa en este piloto porque el login manual una sola vez por dispositivo ya es suficiente (mismo criterio que el token de Cloudflare en `10-cloudflare.md`: es un paso manual, específico de la cuenta, que no vale la pena automatizar para un solo usuario).

## `serve`/`funnel` — existen, pero no se usan en el camino principal de este piloto

Tailscale también puede publicar un puerto local dentro de la tailnet (`tailscale serve`) o hacia internet público (`tailscale funnel`). No hacen falta para el Escenario C1: ahí, Qwen Code se conecta **directo** a la IP de Tailscale del equipo en el puerto real de Ollama (`http://100.x.y.z:11434/v1`), sin que Tailscale tenga que hacer de proxy. `tailscale funnel` sí aparece mencionado como Opción C (respaldo, no principal) para el acceso por navegador a Open WebUI en `../06-operacion/02-acceso-remoto.md` — no se duplica ese análisis acá.

## Cómo se usa en este piloto, paso a paso

1. Instalar Tailscale en el equipo de casa (`14-instalar-tailscale.ps1`) y en cada dispositivo remoto desde el que se quiera correr Qwen Code/Goose.
2. `tailscale up` en ambos — quedan en la misma tailnet.
3. `tailscale ip -4` en el equipo de casa da la IP privada (`100.x.y.z`).
4. En `~/.qwen/settings.json` del dispositivo remoto, `baseUrl` apunta a `http://100.x.y.z:11434/v1` (ver el detalle completo en `../03-herramientas/02-qwen-code-a-fondo.md`, Escenario C1).
5. **Paso que Tailscale por sí solo no resuelve:** Ollama por defecto solo escucha en `localhost` — hace falta además `OLLAMA_HOST=0.0.0.0` (`02-configurar-ollama.ps1 -PermitirRed`) para que acepte esa conexión entrante. Son dos decisiones independientes, documentado así en el propio `14-instalar-tailscale.ps1`.

## Plan y costo (verificado)

**Personal plan: gratis para siempre, hasta 6 usuarios, dispositivos ilimitados** (`tailscale.com/pricing`, 2026-08-27) — muy por encima de lo que necesita un solo usuario con un puñado de dispositivos propios, sin riesgo de tener que pasar a un plan pago.

## Fuentes consultadas (2026-08-27)

- [CLI Reference — Tailscale KB](https://tailscale.com/kb/1080/cli)
- [Tailscale Pricing](https://tailscale.com/pricing)
