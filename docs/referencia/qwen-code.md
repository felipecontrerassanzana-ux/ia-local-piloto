# Qwen Code — referencia completa

El agente principal dentro del editor para este piloto (ver `../herramientas/herramientas-trabajo.md` y `../herramientas/qwen-code-a-fondo.md` para la decisión y sus puntos fuertes ya cruzados contra el modelo). Este documento cubre el set de comandos real — es un CLI mucho más grande de lo que parecía al evaluarlo solo por su tabla de paridad con Claude Code. Verificado contra la documentación oficial (`github.com/QwenLM/qwen-code/docs/users/features/commands.md`), 2026-08-27. No es exhaustivo a propósito — `/help` y `/docs` dentro de la herramienta dan la lista completa; acá está lo que aplica de verdad a este piloto.

## Los tres tipos de comando

| Prefijo | Para qué |
|---|---|
| `/comando` | Control del agente mismo (sesión, config, herramientas) |
| `@archivo` o `@carpeta/` | Inyecta contenido de un archivo/carpeta a la conversación (`@src/main.py explicá esto`) |
| `!comando` | Ejecuta un comando de shell directo (`!git status`) — marca la variable de entorno `QWEN_CODE=1` en lo que ejecuta |

## Hallazgo importante para la capa de diseño: `/model --vision` y `/model --image`

Investigando el comando `/model` a fondo se encontraron dos flags que **formalizan de fábrica** parte de lo que `../arquitectura/capa-diseno.md` documentó como procedimiento manual:

- **`/model --vision <modelo>`** — "configura el modelo puente de visión usado para transcribir imágenes cuando el modelo principal es de solo texto". Esto es exactamente el rol de `qwen3-vl:4b` en este piloto — en vez de armar el loop screenshot→describir a mano, se podría configurar `qwen3-vl:4b` acá y que Qwen Code lo invoque solo cada vez que se le pase una imagen (ej. un screenshot pegado o referenciado con `@`).
- **`/model --image <modelo>`** — configura un modelo con capacidad de generar imágenes para la "herramienta de generación de imágenes incorporada" del propio Qwen Code.

**Pendiente de verificar en el equipo real:** si ComfyUI puede exponerse como un modelo compatible con `/model --image` (necesitaría un endpoint tipo OpenAI-compatible para imágenes, no confirmado que ComfyUI lo tenga nativo — su API real es por "workflow" JSON, distinta) — de confirmarse, cerraría el loop generar→revisar→corregir de forma nativa en vez de con un procedimiento manual armado a mano. Anotado como próximo paso en `capa-diseno.md`.

## Comandos de sesión (ver también `../herramientas/como-funcionan-los-agentes.md` para la continuidad ante corte de luz)

| Comando | Qué hace |
|---|---|
| `/resume` (alias `/continue`) | Retoma una sesión anterior |
| `/branch` | Bifurca la conversación actual en una sesión nueva |
| `/fork <instrucción>` | Lanza un subagente en segundo plano que hereda toda la conversación |
| `/rewind` (alias `/rollback`) | Retrocede la conversación a un turno anterior |
| `/restore` | Revierte los archivos del proyecto al estado justo antes de una llamada a herramienta (checkpointing, ver `como-funcionan-los-agentes.md`) |
| `/compress` | Reemplaza el historial por un resumen para ahorrar tokens de contexto — relevante dado que el modelo local tiene contexto limitado (ver `../referencia/qwen-2.5-coder-7b.md`) |
| `/context` | Muestra cuánto contexto se está usando y en qué — el comando a correr si algo empieza a sentirse lento o a "olvidar" cosas |
| `qwen sessions list` / `qwen sessions ps` | Comandos de terminal (no dentro de la sesión) para listar sesiones guardadas o ver cuáles CLI de Qwen Code están corriendo ahora mismo en el equipo |

## Modos de aprobación — cuánta autonomía darle al agente

`/approval-mode`, de más a menos supervisado:

| Modo | Comportamiento |
|---|---|
| `plan` | Solo analiza, no ejecuta nada — revisión segura |
| `default` | Pide aprobación para cada edición (uso diario) |
| `auto-edit` | Aprueba ediciones solo, sin preguntar |
| `auto` | Un clasificador decide qué aprobar solo |
| `yolo` | Aprueba todo sin preguntar — **advertencia oficial: solo en entornos de prueba/descartables, incluye comandos de shell y red sin confirmar** |

**Recomendación para este piloto:** `default` para uso normal (dado que es un modelo de 7B, con más probabilidad de error que uno grande — ver `../modelo/modelo-elegido.md`), `plan` quinientos si se le pide algo grande/riesgoso, `yolo` no se recomienda dado que corre en un equipo compartido.

## Skills y comandos personalizados — la respuesta al pendiente de "formalizar el loop de diseño"

`capa-diseno.md` tenía anotado como pendiente "formalizar el loop generar→revisar→corregir como Skill, formato no verificado" — investigado, hay dos mecanismos reales, no uno:

- **`/learn <fuente>`** — crea una skill reutilizable a partir de un archivo, carpeta, URL, video o texto (ej. `/learn ./tutorial.mp4 focus on deployment`). Se accede después con `/skills` o invocando `/<nombre-skill>`.
- **Comandos personalizados** (más simple para este caso) — un archivo Markdown en `.qwen/commands/` (por proyecto, versionable con git) o `~/.qwen/commands/` (global), con el prompt como contenido. Ejemplo aplicable directo a este piloto:

```markdown
---
description: Revisa una pantalla generada contra DESIGN.md con el modelo de vision
---

Sacá una captura de la pantalla en {{args}} con Playwright, pasásela a qwen3-vl:4b
junto con las reglas de DESIGN.md, y aplicá las correcciones que sugiera.
```

Guardado como `.qwen/commands/diseno/revisar.md`, quedaría disponible como `/diseno:revisar <ruta>` — versionado junto al proyecto, a diferencia de una Skill de `/learn` que vive en el perfil del usuario. **Recomendación: usar un comando personalizado, no `/learn`**, porque el loop ya está completamente definido (no hace falta que el agente "aprenda" un procedimiento nuevo desde una fuente externa) y conviene que quede versionado en el repo del piloto, no en el perfil de Felipe.

## Otros comandos con valor real para este proyecto

| Comando | Para qué |
|---|---|
| `/init` | Analiza la carpeta actual y genera un archivo de contexto inicial — útil al arrancar un proyecto nuevo con este piloto |
| `/mcp` | Lista servidores MCP configurados — para cuando se sume alguno (ver `como-funcionan-los-agentes.md`) |
| `/agents` | Gestión de subagentes |
| `/diff` | Visor interactivo de diffs (el diff actual contra HEAD, o por turno de conversación) |
| `/stats` | Dashboard de uso — tokens, por modelo, por herramienta |
| `/doctor` | Diagnóstico de instalación/entorno — el primer comando a correr si algo no anda bien |
| `/hooks` | Gestión de hooks propios de Qwen Code (paralelo conceptual a los git hooks ya usados en este repo) |

## Fuentes consultadas (2026-08-27)

- [Commands — Qwen Code Docs](https://github.com/QwenLM/qwen-code/blob/main/docs/users/features/commands.md) — referencia completa de comandos, usada como base de este documento.
