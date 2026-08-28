# Instrucciones para agentes de IA (Goose, Qwen Code) trabajando en este proyecto

Este archivo lo leen automáticamente Goose y Qwen Code al empezar una sesión en esta carpeta (ver `docs/03-herramientas/03-como-funcionan-los-agentes.md` para por qué). Está escrito para que cualquiera de las dos herramientas entienda de entrada las convenciones y decisiones ya tomadas, sin que Felipe tenga que repetirlas cada vez.

## Qué es este proyecto

Piloto real de un LLM autoalojado (Qwen 2.5 Coder 7B vía Ollama) sobre un equipo concreto de Felipe. Es un proyecto **independiente y autocontenido** — solo se apoya en `../ia-local` (teoría transversal genérica, sin contenido de ningún proyecto en particular). Ver `README.md` y `docs/01-arquitectura/01-arquitectura-piloto.md` para el panorama completo antes de proponer cambios grandes.

## Decisiones ya tomadas — no reabrir sin una razón nueva y concreta

- **Modelo:** Qwen 2.5 Coder 7B (Q4_K_M para partir, Q8_0 "best for your GPU"). Fundamentación completa en `docs/02-modelo/01-fundamentacion-modelo.md`.
- **Sin Docker por defecto:** Qdrant y Open WebUI corren nativos en Windows (no contenedores) — el equipo tiene solo 16GB de RAM y WSL2 reserva 50% por defecto. Ver `docs/01-arquitectura/03-docker-y-recursos.md`. `05-instalar-docker.ps1` existe solo como respaldo opcional.
- **Motor de código:** Ollama. Goose y Qwen Code para agente/edición de proyectos; Continue.dev para trabajo dentro del editor; Aider como alternativa de terminal.
- **Acceso remoto por navegador (Open WebUI):** Cloudflare Tunnel + dominio propio + Cloudflare Access.
- **Acceso remoto de agentes de código (Qwen Code/Goose):** Tailscale — no Cloudflare, ver `docs/03-herramientas/02-qwen-code-a-fondo.md`.
- **Capa de diseño:** `DESIGN.md` (sistema de componentes a usar, no inventar estilos) + Qwen3-VL 4B como revisor visual + ComfyUI/Stable Diffusion 1.5 para generar assets — ambos modelos nuevos entran/salen de VRAM bajo demanda, nunca compiten con el modelo de código por espacio fijo. Ver `docs/01-arquitectura/02-capa-diseno.md`.
- **Todo gratuito / self-hosted** — no proponer servicios pagos sin que Felipe lo pida explícitamente.

## Convenciones de este repo

- **Documentación y comentarios en español.** Nombres de función en PowerShell también pueden ir en español (`Instalar-SiFalta`, no forzar verbos aprobados en inglés) — es una decisión de legibilidad, no un descuido.
- **Cualquier `.ps1` nuevo o editado debe pasar `scripts/_verificar-sintaxis.ps1` antes de darse por terminado.** Esto está además **forzado por un git hook** (`scripts/hooks/pre-commit`) — un commit que toque un `.ps1` con errores de sintaxis o sin BOM UTF-8 se bloquea solo. Si el hook no está instalado en esta copia, correr `bash scripts/instalar-git-hooks.sh` una vez.
- **Todo `.ps1` con texto en español necesita BOM UTF-8** — confirmado empíricamente que sin BOM las tildes se corrompen al ejecutar vía `powershell.exe` (el intérprete que usan los `.bat`, distinto de `pwsh`/PowerShell 7 — no asumir que probar en uno prueba el otro).
- **Mensajes de commit: técnicos y neutrales, sin narrar el proceso de cómo se llegó a la decisión.** Qué se decidió y por qué, no "cómo me equivoqué antes de corregirlo" — esa reflexión de proceso va en la memoria del asistente, no en este repo (ver `docs/decisiones.md`, entrada 2026-08-27 sobre este mismo punto).
- **`docs/decisiones.md` es append-only** — no reescribir entradas viejas, agregar una nueva si hace falta corregir algo.
- **No incluir datos personales/familiares** en la documentación (ej. de quién es el equipo) — solo "uso compartido" si aplica.
- **Verificar contra documentación oficial antes de escribir código que dependa del comportamiento de una herramienta externa** — no asumir desde conocimiento entrenado (pasó más de una vez en este proyecto que la primera suposición estaba desactualizada o incompleta).

## Antes de proponer instalar algo nuevo

1. Revisar `docs/01-arquitectura/01-arquitectura-piloto.md` (el esquema completo) y `scripts/README.md` (qué ya existe) — puede que ya esté evaluado o descartado con una razón documentada.
2. Cruzar la propuesta contra las restricciones duras ya conocidas de este equipo: **16GB de RAM**, 12GB de VRAM, uso compartido con otra persona, sin UPS. No proponer algo que choque con esto sin decirlo explícitamente.
3. Preferir alternativas nativas/gratuitas sobre las que agreguen una capa nueva de infraestructura (ver el caso de Docker en `docs/01-arquitectura/03-docker-y-recursos.md` como ejemplo de este criterio aplicado).

## Estado actual

Documentación y scripts completos — **ningún script se ha ejecutado todavía en el equipo real del piloto**. Instalador único con GUI en `scripts/instalar-todo.bat` (recomendado, corre todo en el orden real de dependencias con verificación entre pasos) — ver `docs/04-instalacion/01-plan-instalacion.md` para el detalle desglosado.
