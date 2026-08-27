# Monitor de estado en tiempo real

Agregado 2026-08-27, a pedido explícito de Felipe: quería poder ver, de un vistazo, que todo el stack sigue andando bien — tanto estando en el mismo equipo como conectado remoto (por Tailscale o por el túnel de Cloudflare que ya existe para Open WebUI). No es un chequeo puntual como `verificar-instalacion.ps1` (que hay que correr a mano cada vez) — queda **corriendo todo el tiempo**, como un servicio más del piloto.

## Qué es, en concreto

Un servidor HTTP liviano escrito en PowerShell puro (`System.Net.HttpListener` — parte de .NET, viene con Windows, **cero dependencias nuevas**, ni Python ni un framework web). Vive en `scripts/pasos/monitor-estado-servidor.ps1` y lo registra como Tarea Programada `scripts/pasos/16-instalar-monitor-estado.ps1` (mismo patrón que Qdrant/Open WebUI: corre como `SYSTEM`, arranca solo con Windows, sin necesitar sesión abierta).

Expone dos rutas:

- **`GET /estado`** — un JSON con el estado de cada pieza del stack (ver esquema abajo). Pensado para que otro programa lo consuma (o para mirarlo directo en el navegador).
- **`GET /`** — un dashboard visual simple (HTML/CSS/JS autocontenido, sin librerías externas), con el mismo tema oscuro del instalador (`instalar-todo.ps1`), que hace `fetch('/estado')` cada 10 segundos y pinta un punto verde/rojo/gris por cada pieza.

## Por qué no es un Artifact de Claude

La idea original era "¿se puede armar un dashboard como Artifact?" — la respuesta corta es no, directamente: el sandbox donde corren los Artifacts bloquea llamadas de red a hosts externos salvo un par de excepciones muy acotadas (fuentes de Google, nada más), así que un Artifact no podría hacer `fetch()` a este equipo aunque quisiera. Por eso el dashboard es una página HTML servida por el propio equipo (sin esa restricción, porque no es un Artifact, es una página común y corriente vista en un navegador cualquiera) — más simple, y sin depender de infraestructura de Anthropic para ver el estado de tu propio equipo.

## Qué chequea (mismo criterio que `scripts/verificar-instalacion.ps1`)

| Pieza | Qué mira |
|---|---|
| Ollama | ¿Responde en `:11434`? ¿Qué modelos hay descargados? ¿Hay uno corriendo en GPU ahora mismo? |
| Qdrant | ¿Tarea programada configurada? ¿Responde en `:6333`? |
| Open WebUI | ¿Tarea programada configurada? ¿Responde en `:8080`? ¿Sigue apuntando a Qdrant/BGE-M3 (`VECTOR_DB`/`RAG_EMBEDDING_MODEL`)? |
| Cloudflare Tunnel | ¿Servicio `cloudflared` instalado, corriendo, con inicio automático? |
| Tailscale | ¿Instalado? ¿Conectado? ¿Cuál es la IP de este equipo? |
| ComfyUI | ¿Instalado? (solo se informa — no se espera que esté corriendo, no auto-inicia a propósito) |
| Backup | ¿Tarea programada configurada? ¿Cuándo corrió por última vez y con qué resultado? |
| GPU | Nombre, VRAM usada/total, % de uso (vía `nvidia-smi`) |
| Discos | Espacio libre/total por letra |
| CPU/RAM | % de uso de CPU, RAM usada/total |

**Nota sobre la duplicación con `verificar-instalacion.ps1`:** los chequeos son deliberadamente parecidos (mismos puertos, mismos nombres de tarea) pero **no comparten código** — uno imprime texto coloreado para que una persona lo lea en consola, el otro arma JSON para un navegador. Con dos scripts de este tamaño, no vale la pena la abstracción de una función compartida; el riesgo real de que se desalineen con el tiempo es bajo y se acepta a cambio de mantener cada uno simple y autocontenido.

## Cómo se llega a él — dos caminos, sin infraestructura nueva

Reutiliza los dos mecanismos de acceso remoto que este proyecto ya decidió, no agrega un tercero:

1. **Local, en el mismo equipo:** `http://localhost:8090/` — funciona apenas se instala el paso 16, sin configurar nada más.
2. **Remoto por Tailscale** (ver `../herramientas/qwen-code-a-fondo.md`): `http://<IP-de-Tailscale-del-equipo>:8090/` — funciona apenas Tailscale esté conectado (Paso 3.5 de `../instalacion/plan-instalacion.md`), sin pasar por Cloudflare ni por internet.
3. **Remoto público, opcional** (ver `acceso-remoto.md`): agregar una segunda "Public Hostname" al mismo túnel de Cloudflare que ya se crea para Open WebUI (Paso 3), apuntando a `http://localhost:8090` — queda protegido por el mismo Cloudflare Access (el correo de Felipe), sin crear un túnel nuevo ni una cuenta nueva.

## El detalle no obvio: el firewall de Windows

`16-instalar-monitor-estado.ps1` escucha en **todas las interfaces** (`http://+:8090/`, no solo `localhost`) — necesario para que Tailscale (que llega por una interfaz de red real, no loopback) pueda conectarse. Eso solo no alcanza: Windows Firewall bloquea conexiones entrantes nuevas por defecto, así que el script también crea una regla (`New-NetFirewallRule`, puerto 8090, entrada TCP) — sin esto, el listener escucharía bien pero Tailscale nunca lograría conectarse, y hubiera sido un "no funciona" difícil de diagnosticar desde otro dispositivo. El acceso vía Cloudflare Tunnel **no** necesita esta regla: `cloudflared` habla con `localhost` (tráfico de loopback), que no pasa por el firewall de conexiones entrantes.

## Limitaciones honestas

- **No es un servicio de Windows real** (como `cloudflared`) — es una Tarea Programada con reintento (3 veces, cada 1 minuto) si el proceso se cae solo. Mismo trade-off ya aceptado para Qdrant/Open WebUI, ver `docker-y-recursos.md`.
- **No hay alertas proactivas** (Slack/email/notificación push) si algo se cae — hay que abrir el dashboard o el JSON para enterarse. Para un piloto de una sola persona, agregar alertas automáticas es más infraestructura de la que hace falta hoy; si en algún momento se necesitara, sería una capa aparte, no una modificación de este monitor.
- **No se pudo probar en el equipo real** — esta sesión de trabajo no corre en la máquina piloto (RTX 5070), así que no se pudo instalar de verdad ni abrir el dashboard en un navegador. Se verificó sintaxis, BOM y linter (`_verificar-sintaxis.ps1`); el HTML del dashboard se armó a mano siguiendo el mismo esquema de colores ya usado y verificado en `instalar-todo.ps1`, pero su render real (JS, `fetch`, layout) queda para confirmar cuando Felipe lo instale.
