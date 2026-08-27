# Goose — referencia completa

El agente general de este piloto (ver `../herramientas/herramientas-trabajo.md` para la decisión). Cubre el CLI completo y, en particular, el equivalente de Goose a los "comandos personalizados" de Qwen Code — para poder formalizar el mismo procedimiento (ej. el loop de revisión de diseño) en las dos herramientas, no solo en una. Verificado contra `goose-docs.ai`, 2026-08-27.

## Comandos principales

| Comando | Qué hace |
|---|---|
| `goose session` | Inicia o retoma una sesión de chat interactiva. `--resume` retoma, `--fork` duplica con el historial copiado, `--edit` abre el historial en el editor de texto para modificarlo. |
| `goose session list` | Lista las sesiones guardadas (`--format json`, `-w` filtra por carpeta, `-l` limita resultados). |
| `goose session export` | Exporta una sesión a markdown/JSON/YAML — para backup, compartir, o documentar. |
| `goose session remove` | Borra sesiones por ID, nombre, o patrón. |
| `goose run` | Ejecuta un archivo de instrucciones o algo desde stdin — para automatizar sin abrir una sesión interactiva. |
| `goose configure` | Configura providers/extensiones — el comando ya usado en `04-instalar-goose.ps1`. |
| `goose info` (`-v` para detalle) | Versión, ubicación de config, dónde se guardan las sesiones y logs. |
| `goose mcp` | Corre un servidor MCP habilitado por nombre. |

## Recipes — el equivalente de Goose a los comandos personalizados de Qwen Code

Igual que Qwen Code tiene `.qwen/commands/*.md` para guardar prompts reutilizables (ver `qwen-code.md`), Goose tiene **Recipes**:

| Comando | Qué hace |
|---|---|
| `goose recipe list` | Lista los recipes disponibles |
| `goose recipe validate` | Chequea la sintaxis de un recipe |
| `goose recipe open` | Lanza un recipe en la app de escritorio |
| `goose recipe deeplink` | Genera un link para compartir un recipe |

**Aplicado a este piloto:** el mismo loop de revisión de diseño documentado como comando personalizado de Qwen Code (`.qwen/commands/diseno/revisar.md`, ver `qwen-code.md`) debería tener su equivalente como Recipe de Goose, para que ambas herramientas puedan invocarlo — pendiente de armar el archivo real una vez se confirme la sintaxis exacta de un Recipe en el equipo real (no verificado en detalle todavía, la documentación cubre el concepto pero no se fetcheó el formato completo del archivo).

## `goose schedule` — automatizar recipes con cron

Corre un recipe en un horario definido (`add`, `list`, `remove`, `run-now`). **Relevante como alternativa a las Tareas Programadas de Windows** ya usadas en este proyecto (`09-configurar-inicio-automatico.ps1`) — para tareas que son lógica de agente (ej. "revisar todas las pantallas nuevas cada noche"), no procesos de servidor (Qdrant/Open WebUI siguen mejor como Tarea Programada de Windows, eso no cambia).

## Otros comandos con valor real

| Comando | Para qué |
|---|---|
| `goose skills` | Lista skills instaladas y descubribles, con conteo de tokens — Goose también tiene un sistema de Skills, además de Recipes. |
| `goose plugin` | Instala plugins respaldados por git (skills o componentes) — el mecanismo de extensión más allá de MCP. |
| `goose review [rango]` | Revisa el diff de git actual — descubre checks propios en `.agents/checks/*.md` (convención distinta de `AGENTS.md`, específica de esta función de review). |
| `goose local-models` (alias `lm`) | Busca, descarga y gestiona modelos GGUF/MLX locales **directo desde Hugging Face, sin pasar por Ollama**. No se usa en este piloto (la arquitectura ya decidió Ollama como motor único, ver `AGENTS.md`) pero vale saber que existe, por si en algún momento hace falta un modelo que Ollama no tenga publicado. |
| `goose term init <shell>` | Integra Goose a la terminal — habilita los alias `@goose`/`@g` para preguntar con el historial de comandos como contexto, sin abrir una sesión completa. |

## Comandos dentro de una sesión (slash commands)

`/help`, `/plan`, `/mode`, `/skills`, `/compact`, `/recipe`, `/extension`, `/builtin`, `/clear`, `/exit`, `/t` (cambiar tema visual).

**`/mode`** es el equivalente de Goose al `/approval-mode` de Qwen Code (ver `qwen-code.md`) — cuánta autonomía darle al agente antes de pedir aprobación. Misma recomendación que ahí: no usar el modo más autónomo en este equipo compartido.

## Fuentes consultadas (2026-08-27)

- [CLI Commands — Goose Docs](https://goose-docs.ai/docs/guides/goose-cli-commands/)
