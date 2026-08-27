# Cómo funcionan por dentro Qwen Code y Goose (el motor + los addons)

`herramientas-trabajo.md` explica **qué** herramientas se eligieron y **por qué**. Este documento explica **cómo funcionan mecánicamente por dentro** — porque de eso depende cómo hay que interactuar con ellas (qué archivos leen, cuándo, en qué orden, qué hace cada pieza). Verificado contra documentación oficial, 2026-08-27.

## El ciclo de vida de una sesión (lo mismo en ambas herramientas, en el fondo)

1. **Arranca con una ventana de contexto vacía.** Ni Qwen Code ni Goose "recuerdan" nada del modelo mismo (ver `herramientas-trabajo.md` — el modelo es sin estado). Todo lo que "recuerdan" entre sesiones son archivos que se vuelven a leer al empezar.
2. **Carga archivos de contexto persistente** (ver tabla abajo) — instrucciones que vos escribiste a mano, más lo que la herramienta guardó sola en sesiones anteriores (si tiene auto-memoria).
3. **Corre la conversación/tarea**, con acceso a herramientas (shell, archivos, MCP) según qué esté habilitado.
4. **Al terminar (o periódicamente), algunas herramientas actualizan su memoria** — deciden qué vale la pena guardar para la próxima vez.

## Archivos de contexto persistente — quién lee qué

| Archivo | Quién lo lee | Quién lo escribe | Alcance |
|---|---|---|---|
| **`AGENTS.md`** (raíz del proyecto) | **Goose** (por defecto, sin configurar nada — confirmado en `goose-docs.ai`: `CONTEXT_FILE_NAMES` por defecto es `["AGENTS.md", ".goosehints"]`) **y Qwen Code** (lee `AGENTS.md` automáticamente si existe, según su propia documentación de memoria) | Vos, a mano | Compartido — es el archivo "universal" entre herramientas de agente distintas, por eso conviene usar este nombre y no duplicar instrucciones en formatos separados |
| `QWEN.md` | Solo Qwen Code | Vos, a mano (o `/init` genera uno automático leyendo el código) | Específico de Qwen Code — usar si hace falta algo que solo aplique ahí, sin mezclarlo con `AGENTS.md` |
| `.goosehints` | Solo Goose (necesita la extensión "Developer" habilitada) | Vos, a mano | Específico de Goose |
| `.continue/rules` | Solo Continue.dev | Vos, a mano | Estático — no se actualiza solo (ver `herramientas-trabajo.md`) |
| `~/.qwen/projects/<proyecto>/memory/*.md` | Solo Qwen Code | **Qwen Code solo, automático** (Auto-memory) | Ver `herramientas-trabajo.md` § Auto-memory — 4 categorías, limpieza automática diaria |

**Recomendación para este proyecto:** un solo `AGENTS.md` en la raíz, para no mantener el mismo contenido en 3 formatos distintos. Si en algún momento hace falta algo específico de una sola herramienta, ahí sí usar `QWEN.md` o `.goosehints` como complemento, no como reemplazo.

## MCP (Model Context Protocol) — el estándar que conecta herramientas externas

Ya se usa en este entorno de trabajo (el navegador Playwright que usa Claude Code) — el mismo protocolo lo usan Goose (70+ extensiones documentadas: GitHub, bases de datos, navegador, Google Drive) y Qwen Code (soporte de MCP confirmado en su tabla de paridad con Claude Code). En términos simples: es un formato estándar para que un agente de IA le pida a un programa externo que haga algo concreto (leer un archivo, consultar una base de datos, controlar un navegador) sin que el modelo tenga que "saber" programar esa integración desde cero — el servidor MCP expone un menú de acciones posibles, y el agente elige cuál usar.

## SubAgents / Agent Teams — delegar en vez de hacer todo en una sola conversación

Tanto Goose como Qwen Code soportan lanzar sub-agentes (confirmado en la tabla de paridad de funciones de Qwen Code, y en la documentación de Goose) — el mismo patrón que uso yo (Claude) cuando delego una tarea de investigación a un subagente para no llenar la conversación principal con resultados intermedios. Útil para: revisar código en paralelo mientras se sigue conversando, investigar algo largo sin perder el hilo principal, o dividir una tarea grande en partes independientes.

## Skills — instrucciones empaquetadas y reutilizables

Ambas herramientas mencionan "Skills" en su documentación (Qwen Code: "Auto-Skills" en su lista de capacidades; Goose: tiene una extensión "Summon" — "Load skills and delegate tasks to subagents"). La idea general: en vez de escribir la misma instrucción larga cada vez ("cuando revises un PR, fijate en X, Y, Z"), se empaqueta una vez como una "skill" reutilizable que el agente puede invocar por nombre.

## Extensiones/plugins — cómo cada herramienta suma capacidades nuevas

- **Goose:** sistema de extensiones (built-in + comunidad, instalables desde `goose-docs.ai/extensions`) — la mayoría son servidores MCP por debajo.
- **Qwen Code:** también soporta MCP como mecanismo de extensión, más integraciones nativas (canales de mensajería, GitHub Actions).
- **Continue.dev:** modelo de "bloques" de configuración (`ollama/qwen2.5-coder-7b` es un bloque pre-armado) más soporte de MCP.

## Qué significa todo esto para trabajar en este proyecto en concreto

Ver `AGENTS.md` en la raíz de este repo — es el archivo real que aplica lo de arriba: instrucciones ya escritas a mano para que cualquiera de estas herramientas (Goose, Qwen Code) arranque entendiendo las convenciones y decisiones ya tomadas en este proyecto, sin tener que repetirlas cada sesión.
