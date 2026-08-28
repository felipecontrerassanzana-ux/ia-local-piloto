# Plan de instalación

Estado: **planificado, sin ejecutar todavía en el equipo real.** Cada paso se marca cuando efectivamente se hace en la máquina, no antes. Cada paso tiene un script correspondiente en `scripts/` — ver `scripts/README.md` para cómo correrlos.

**Recomendado (2026-08-27):** correr `scripts/instalar-todo.bat` en vez de los pasos de abajo uno por uno — es una ventana única que corre todo en el orden real de dependencias (que no coincide con el orden numérico de los archivos) y verifica cada paso antes de seguir. Los pasos de abajo describen el mismo trabajo desglosado, útil para entender qué hace cada pieza o para correr un paso puntual de nuevo.

Sigue el stack ya definido en `../arquitectura/01-arquitectura-piloto.md` (esquema completo) y en `../ia-local/docs/04-arquitectura.md` (conceptos generales), adaptado a que acá sí hay una GPU dedicada real.

## Paso 0 — Verificar el equipo antes de instalar

- [x] Sistema operativo — resuelto 2026-08-26: **Windows 11 Pro 25H2**, instalación nativa (no WSL2, Ollama tiene versión nativa para Windows).
- [ ] Confirmar drivers NVIDIA actualizados y que reconocen la RTX 5070 con sus 12GB completos.
- [ ] Confirmar espacio en disco disponible en **ambos discos** (NVMe + HDD, ver `../arquitectura/04-almacenamiento.md`) — modelos + embeddings + capa de diseño + índices de prueba: estimar ~25GB, todo en el NVMe.
- [ ] Confirmar letra de unidad de cada disco (cuál es el NVMe, cuál es el HDD).

Script: `scripts/pasos/00-verificar-equipo.ps1` — corre todo lo de arriba automáticamente y deja un reporte.

## Paso 1 — Motor de inferencia: Ollama

Uso de una sola persona — Ollama es la opción correcta según `../herramientas/04-motor-alternativas.md` (vLLM solo se justifica con concurrencia real de varios usuarios, no es el caso acá).

- [ ] Instalar Ollama (`scripts/pasos/01-instalar-ollama.ps1`).
- [ ] **Configurar `OLLAMA_CONTEXT_LENGTH` explícitamente (crítico, no saltarse).** Con menos de 24GB de VRAM (el caso de esta RTX 5070 12GB), Ollama usa por defecto solo **4K de contexto** — muy por debajo del contexto largo (100K) que fue el criterio principal para elegir este modelo (ver `../modelo/02-modelo-elegido.md` y `../herramientas/01-herramientas-trabajo.md`, corregido y verificado contra la documentación oficial de Ollama, 2026-08-26).
- [ ] Configurar `OLLAMA_MODELS` apuntando al NVMe (ver `../arquitectura/04-almacenamiento.md` — corregido 2026-08-27, los modelos se intercambian en VRAM varias veces por sesión con la capa de diseño, conviene el disco rápido).
- [ ] Descargar Qwen 2.5 Coder 7B en cuantización Q4_K_M (ver `../modelo/02-modelo-elegido.md`) — probar también Q8_0, marcado "best for your GPU" en la verificación de hardware.
- [ ] Confirmar que responde vía la API compatible OpenAI que expone Ollama, y que `ollama ps` muestra el `CONTEXT` configurado correctamente (no 4096).

Script: `scripts/pasos/02-configurar-ollama.ps1` (variables de entorno) + `scripts/pasos/03-descargar-modelo.ps1` (pull del modelo).

## Paso 1.4 — Herramientas base de desarrollo (git, GitHub CLI, Python)

- [ ] Correr `scripts/pasos/12-instalar-herramientas-dev.ps1` (`.bat`) — instala git, `gh` y Python.
- [ ] Autenticar `gh` a mano: `gh auth login` (interactivo, no se puede automatizar).
- [ ] Con esto, Goose ya puede comitear/pushear a GitHub igual que se hace en esta conversación — ver `../herramientas/01-herramientas-trabajo.md` § "Conectores a GitHub".

## Paso 1.5 — Herramientas de trabajo para programar

Ver `../herramientas/01-herramientas-trabajo.md` para el detalle completo y las alternativas evaluadas.

- [ ] Instalar **Goose** (`scripts/pasos/04-instalar-goose.ps1`) — para iniciar/gestionar proyectos completos desde la terminal.
- [ ] Instalar **Qwen Code** (`scripts/pasos/13-instalar-qwen-code.ps1`) — el agente hecho por el propio equipo de Qwen, con extensión oficial de VS Code (Beta) — instalar esa extensión desde el Marketplace además de correr el script.
- [ ] Instalar Continue.dev en VS Code, configurar el bloque `ollama/qwen2.5-coder-7b` — para trabajar dentro de un proyecto ya iniciado.
- [ ] Crear `.continue/rules` con las convenciones básicas de trabajo.
- [ ] (Opcional) Evaluar Aider como alternativa de terminal.

## Paso 2 — Embeddings, base vectorial e interfaz web

Ver `../arquitectura/03-docker-y-recursos.md` antes de este paso — explica por qué **ninguna de estas piezas necesita Docker** (ambas tienen forma nativa oficial en Windows), y el presupuesto real de RAM en un equipo de 16GB.

- [ ] Levantar Qdrant nativo (`scripts/pasos/06-desplegar-qdrant.ps1`) — descarga el binario oficial de Windows, lo deja corriendo vía Tarea Programada.
- [ ] Levantar Open WebUI nativo, vía pip (`scripts/pasos/07-desplegar-openwebui.ps1`) — requiere Python (Paso 1.4). Puerto 8080 (no 3000, eso era específico de Docker).
- [ ] Crear la primera cuenta en Open WebUI (queda como admin, cierra el registro público automáticamente — ver `../operacion/02-acceso-remoto.md`).
- [ ] BGE-M3 se descarga con `scripts/pasos/03-descargar-modelo.ps1` (`ollama pull bge-m3`) — corre en la misma GPU vía Ollama, **no** como proceso Python aparte. Armar el pipeline básico de prueba con documentos propios queda para cuando se conecte el RAG real.
- [ ] (Opcional/respaldo) `scripts/pasos/05-instalar-docker.ps1` — solo si algo nativo da problemas y se prefiere la alternativa en contenedor.

## Paso 3 — Acceso remoto y autenticación

Ver `../operacion/02-acceso-remoto.md` para el detalle completo de la decisión (Cloudflare Tunnel + dominio propio + Cloudflare Access).

- [ ] Crear el túnel en el dashboard de Cloudflare Zero Trust y obtener el token.
- [ ] Instalar `cloudflared` como servicio de Windows con ese token (`scripts/pasos/08-instalar-cloudflared.ps1`).
- [ ] Configurar el subdominio propio apuntando al túnel.
- [ ] Configurar Cloudflare Access delante del túnel, con el correo de Felipe como único autorizado.
- [ ] Activar rate limiting básico en el dashboard de Cloudflare.

## Paso 3.5 — Conexión remota de Qwen Code/Goose (opcional, distinto del acceso por navegador)

Ver `../herramientas/02-qwen-code-a-fondo.md` para el detalle completo — solo hace falta si se va a usar Qwen Code/Goose desde un dispositivo fuera de la casa, no para el uso local ni para el acceso por navegador del Paso 3.

- [ ] Instalar Tailscale (`scripts/pasos/14-instalar-tailscale.ps1`) y autenticar (`tailscale up`, interactivo).
- [ ] Configurar `OLLAMA_HOST=0.0.0.0` (`scripts/pasos/02-configurar-ollama.ps1 -PermitirRed`) — sin esto, Tailscale conecta el equipo pero Ollama sigue sin aceptar tráfico de otros dispositivos.
- [ ] En el dispositivo remoto: instalar Tailscale + Qwen Code, y apuntar `baseUrl` en `~/.qwen/settings.json` a `http://<IP-de-Tailscale>:11434/v1` (obtener la IP con `tailscale ip -4` en el equipo servidor).

## Paso 3.6 — Capa de diseño (revisor visual + generador de assets)

Ver `../arquitectura/02-capa-diseno.md` para el razonamiento completo — cierra la brecha de que el modelo de código es solo texto y no puede evaluar visualmente su propio resultado.

- [ ] `qwen3-vl:4b` se descarga con `scripts/pasos/03-descargar-modelo.ps1` (`ollama pull qwen3-vl:4b`) — mismo mecanismo que el resto de los modelos, entra/sale de VRAM bajo demanda.
- [ ] Instalar ComfyUI + checkpoint de Stable Diffusion 1.5 (`scripts/pasos/15-instalar-comfyui.ps1`) — **no** se registra como inicio automático a propósito, se abre a mano cuando hace falta generar un asset.
- [ ] Confirmar que `DESIGN.md` (raíz del repo) está completo con el sistema de componentes elegido antes de generar la primera pantalla de una app nueva.

## Paso 4 — Continuidad y backup

Ver `../operacion/01-mantenimiento.md` para el detalle completo.

- [ ] Configurar la BIOS para reencender el equipo solo tras un corte de luz.
- [ ] Confirmar que Ollama, Open WebUI (nativo, vía Tarea Programada) y `cloudflared` quedan configurados para iniciar solos con Windows (`scripts/pasos/09-configurar-inicio-automatico.ps1`).
- [ ] Configurar la tarea programada de backup a Drive (`scripts/pasos/10-configurar-backup.ps1`).

## Paso 5 — Verificación final

- [ ] Correr `scripts/verificar-instalacion.ps1` — chequeo integral: Ollama responde, contexto configurado, GPU detectada, servicios activos y configurados para auto-inicio, Open WebUI accesible en LAN, túnel de Cloudflare activo, backup programado, Qwen Code configurado, y estado de Tailscale si se instaló.

## Paso 5.5 — Monitor de estado en tiempo real (opcional, a pedido de Felipe)

Ver `../operacion/03-monitor-estado.md` para el detalle completo — un dashboard/JSON de estado, pensado para revisar de un vistazo que todo sigue andando bien, tanto en el mismo equipo como remoto.

- [ ] Correr `scripts/pasos/16-instalar-monitor-estado.ps1` (`.bat`) — registra la Tarea Programada "Monitor-Estado-Local" y la regla de firewall necesaria.
- [ ] Local: `http://localhost:8090/`. Por Tailscale (Paso 3.5): `http://<IP-de-Tailscale>:8090/`.
- [ ] (Opcional, manual) Agregar una segunda "Public Hostname" al túnel de Cloudflare del Paso 3, apuntando a `http://localhost:8090`, para verlo también desde internet.

## Paso 6 — Prueba de estrés y rendimiento

- [ ] Correr `scripts/pasos/11-prueba-estres.ps1` (`.bat`) — mide tok/s real, estabilidad bajo carga sostenida, y el límite real de contexto (cierra el pendiente de `../modelo/02-modelo-elegido.md` sobre si el límite de 32K de Ollama es real o solo el default). Ver `../pruebas/02-pruebas-rendimiento.md` para cómo interpretar los resultados.

## Siguiente documento

Una vez instalado y con la prueba de estrés corrida, pasar a `../pruebas/01-plan-pruebas.md` para la evaluación de **calidad** con tareas de programación concretas, y registrar todos los resultados (rendimiento + calidad) en `../pruebas/resultados.md`.

## Antes de empezar: entender qué hace cada script

Ver `02-aprendizaje-scripts.md` — explica qué hace cada `.ps1` y por qué, no solo el comando a correr. Es parte del objetivo del proyecto (entender, no solo ejecutar), igual que `../modelo/01-fundamentacion-modelo.md` con la elección del modelo.
