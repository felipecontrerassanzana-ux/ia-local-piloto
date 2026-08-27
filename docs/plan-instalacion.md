# Plan de instalación

Estado: **planificado, sin ejecutar todavía en el equipo real.** Cada paso se marca cuando efectivamente se hace en la máquina, no antes. Cada paso tiene un script correspondiente en `scripts/` — ver `scripts/README.md` para cómo correrlos.

Sigue el stack ya definido en `arquitectura-piloto.md` (esquema completo) y en `../ia-local/docs/arquitectura.md` (conceptos generales), adaptado a que acá sí hay una GPU dedicada real.

## Paso 0 — Verificar el equipo antes de instalar

- [x] Sistema operativo — resuelto 2026-08-26: **Windows 11 Pro 25H2**, instalación nativa (no WSL2, Ollama tiene versión nativa para Windows).
- [ ] Confirmar drivers NVIDIA actualizados y que reconocen la RTX 5070 con sus 12GB completos.
- [ ] Confirmar espacio en disco disponible en **ambos discos** (NVMe + HDD, ver `almacenamiento.md`) — modelo + embeddings + índices de prueba: estimar 10-15GB.
- [ ] Confirmar letra de unidad de cada disco (cuál es el NVMe, cuál es el HDD).

Script: `scripts/00-verificar-equipo.ps1` — corre todo lo de arriba automáticamente y deja un reporte.

## Paso 1 — Motor de inferencia: Ollama

Uso de una sola persona — Ollama es la opción correcta según `motor-alternativas.md` (vLLM solo se justifica con concurrencia real de varios usuarios, no es el caso acá).

- [ ] Instalar Ollama (`scripts/01-instalar-ollama.ps1`).
- [ ] **Configurar `OLLAMA_CONTEXT_LENGTH` explícitamente (crítico, no saltarse).** Con menos de 24GB de VRAM (el caso de esta RTX 5070 12GB), Ollama usa por defecto solo **4K de contexto** — muy por debajo del contexto largo (100K) que fue el criterio principal para elegir este modelo (ver `modelo-elegido.md` y `herramientas-trabajo.md`, corregido y verificado contra la documentación oficial de Ollama, 2026-08-26).
- [ ] Configurar `OLLAMA_MODELS` apuntando al HDD (ver `almacenamiento.md`) — no ocupar el NVMe con los pesos del modelo.
- [ ] Descargar Qwen 2.5 Coder 7B en cuantización Q4_K_M (ver `modelo-elegido.md`) — probar también Q8_0, marcado "best for your GPU" en la verificación de hardware.
- [ ] Confirmar que responde vía la API compatible OpenAI que expone Ollama, y que `ollama ps` muestra el `CONTEXT` configurado correctamente (no 4096).

Script: `scripts/02-configurar-ollama.ps1` (variables de entorno) + `scripts/03-descargar-modelo.ps1` (pull del modelo).

## Paso 1.5 — Herramientas de trabajo para programar

Ver `herramientas-trabajo.md` para el detalle completo y las alternativas evaluadas.

- [ ] Instalar **Goose** (`scripts/04-instalar-goose.ps1`) — para iniciar/gestionar proyectos completos.
- [ ] Instalar Continue.dev en VS Code, configurar el bloque `ollama/qwen2.5-coder-7b` — para trabajar dentro de un proyecto ya iniciado.
- [ ] Crear `.continue/rules` con las convenciones básicas de trabajo.
- [ ] (Opcional) Evaluar Aider como alternativa de terminal.

## Paso 2 — Embeddings, base vectorial e interfaz web

- [ ] Instalar Docker Desktop, si no está ya (`scripts/05-instalar-docker.ps1`) — necesario para Open WebUI y Qdrant.
- [ ] Levantar Qdrant (`scripts/06-desplegar-qdrant.ps1`).
- [ ] Levantar Open WebUI apuntando al Ollama del equipo (`scripts/07-desplegar-openwebui.ps1`).
- [ ] Crear la primera cuenta en Open WebUI (queda como admin, cierra el registro público automáticamente — ver `acceso-remoto.md`).
- [ ] Instalar/descargar BGE-M3 como modelo de embeddings, y armar un pipeline básico de prueba con documentos propios.

## Paso 3 — Acceso remoto y autenticación

Ver `acceso-remoto.md` para el detalle completo de la decisión (Cloudflare Tunnel + dominio propio + Cloudflare Access).

- [ ] Crear el túnel en el dashboard de Cloudflare Zero Trust y obtener el token.
- [ ] Instalar `cloudflared` como servicio de Windows con ese token (`scripts/08-instalar-cloudflared.ps1`).
- [ ] Configurar el subdominio propio apuntando al túnel.
- [ ] Configurar Cloudflare Access delante del túnel, con el correo de Felipe como único autorizado.
- [ ] Activar rate limiting básico en el dashboard de Cloudflare.

## Paso 4 — Continuidad y backup

Ver `mantenimiento.md` para el detalle completo.

- [ ] Configurar la BIOS para reencender el equipo solo tras un corte de luz.
- [ ] Confirmar que Ollama, Open WebUI (contenedor Docker) y `cloudflared` quedan configurados para iniciar solos con Windows (`scripts/09-configurar-inicio-automatico.ps1`).
- [ ] Configurar la tarea programada de backup a Drive (`scripts/10-configurar-backup.ps1`).

## Paso 5 — Verificación final

- [ ] Correr `scripts/verificar-instalacion.ps1` — chequeo integral: Ollama responde, contexto configurado, GPU detectada, servicios activos y configurados para auto-inicio, Open WebUI accesible en LAN, túnel de Cloudflare activo, backup programado.

## Siguiente documento

Una vez instalado, pasar a `plan-pruebas.md` para la evaluación real con tareas de programación concretas, y registrar resultados en `resultados.md`.
