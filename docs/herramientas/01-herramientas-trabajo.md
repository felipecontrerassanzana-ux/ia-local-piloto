# Herramientas para trabajar de forma efectiva (no solo el modelo pelado)

Confirmado en la conversación anterior: Qwen 2.5 Coder 7B no tiene memoria persistente — es sin estado. Para programar/armar proyectos de forma efectiva con él (que es el uso principal de este equipo), hace falta una capa de herramientas alrededor, igual que yo (Claude) no soy solo el modelo, soy el modelo + un entorno con archivos, memoria y herramientas. Esta página documenta qué piezas existen para eso, verificadas contra documentación oficial (2026-08-26), no de memoria sin chequear.

## La respuesta directa a "¿hay una extensión Qwen para VS Code?": sí, Qwen Code

El usuario preguntó específicamente si existe una extensión de Qwen para VS Code que conecte con un servidor de IA local propio, igual que se usa Claude Code acá. Verificado 2026-08-26 en `github.com/QwenLM/qwen-code` (27,4k estrellas, desarrollo muy activo) y su sitio de documentación oficial:

- **Qué es:** "Qwen Code" — un agente de código en el terminal hecho por el propio equipo de Qwen (Alibaba), **explícitamente construido para tener paridad de funciones con Claude Code** (la propia documentación oficial trae una tabla comparativa punto por punto: SubAgents, Memoria automática, MCP, Plan Mode, Sandboxing, hooks, etc. — todo presente en ambos).
- **Sí tiene extensión de VS Code** (Beta, requiere VS Code 1.96+): panel lateral nativo, modo de auto-aceptar cambios, referenciar archivos con `@`, historial de conversaciones, múltiples sesiones en paralelo — se instala directo desde el Marketplace de VS Code. También hay plugins para Zed y JetBrains, y una app de escritorio.
- **Soporta explícitamente Ollama como servidor local**, confirmado con un ejemplo de configuración oficial que usa **justo la familia Qwen** como caso de ejemplo (`baseUrl: "http://localhost:11434/v1"`, el endpoint compatible con OpenAI que expone Ollama) — no hace falta adaptar nada, es el caso de uso que la propia documentación ilustra.
- **`QWEN.md`** — un archivo de contexto por proyecto, el equivalente exacto de `CLAUDE.md`/`.continue/rules` para este ecosistema.
- Va más allá del editor: modo demonio (`qwen serve`, varios clientes comparten una sesión), SDKs (TypeScript/Python/Java), bots de mensajería (Telegram, WeChat, DingTalk, Feishu).

**Configuración concreta para conectarlo a este piloto** — en `%USERPROFILE%\.qwen\settings.json` (settings de usuario, aplica a todas las sesiones):

```json
{
  "env": { "OLLAMA_API_KEY": "ollama" },
  "modelProviders": {
    "openai": [
      {
        "id": "qwen2.5-coder-7b",
        "name": "Qwen 2.5 Coder 7B (Ollama local)",
        "envKey": "OLLAMA_API_KEY",
        "baseUrl": "http://localhost:11434/v1",
        "generationConfig": {
          "contextWindowSize": 32000,
          "samplingParams": { "temperature": 0.7, "top_p": 0.9, "max_tokens": 4096 }
        }
      }
    ]
  }
}
```

(el `contextWindowSize` de 32000 sigue el mismo criterio conservador que `02-configurar-ollama.ps1` — ajustar junto con `OLLAMA_CONTEXT_LENGTH` cuando la prueba de estrés confirme un límite real mayor, ver `../pruebas/02-pruebas-rendimiento.md`).

**Requiere Node.js 22+** (se instala vía npm: `npm install -g @qwen-code/qwen-code`) — ver `scripts/pasos/13-instalar-qwen-code.ps1`.

## Auto-memory de Qwen Code — la respuesta a "¿puede identificar cosas y dejarlas establecidas solo, como vos?" (verificado 2026-08-27)

El usuario preguntó, después de ver cómo Claude identifica patrones durante la conversación y los deja guardados para el futuro sin que se lo pidan explícitamente, si Qwen (como motor) puede hacer lo mismo. La respuesta corta: **el modelo Qwen 2.5 Coder 7B en sí sigue siendo sin estado** (eso no cambia, ver más abajo) — pero **Qwen Code, la aplicación, sí tiene esto integrado y activado por defecto**, confirmado en su documentación oficial (`qwenlm.github.io/qwen-code-docs/en/users/features/memory/`):

- **"Auto-memory" está prendido de fábrica** (no hay que configurar nada para activarlo). Identifica sola 4 tipos de cosas mientras trabaja:
  1. **Sobre vos** — tu rol, cómo te gusta trabajar.
  2. **Tu feedback** — correcciones que hiciste, enfoques que confirmaste.
  3. **Contexto del proyecto** — trabajo en curso, decisiones, objetivos no obvios desde el código.
  4. **Referencias externas** — dashboards, trackers de tickets, links de documentación que mencionaste.

  **Es, prácticamente palabra por palabra, la misma clasificación de mi propio sistema de memoria** (usuario / feedback / proyecto / referencia) — no es una coincidencia de marketing, es la misma arquitectura de fondo aplicada dos veces por equipos distintos.
- **Dónde se guarda:** archivos markdown planos en `~/.qwen/projects/<proyecto>/memory/` — se pueden abrir, editar o borrar a mano en cualquier momento, igual que mis propios archivos de memoria.
- **Limpieza automática:** corre sola una vez al día (`/dream`) para deduplicar y descartar entradas obsoletas — el equivalente de cuando yo reviso y actualizo memorias viejas que quedaron desactualizadas.
- **Control manual si hace falta:** `/remember <texto>` para forzar que guarde algo, `/forget <texto>` para borrarlo, `/memory` para ver qué tiene guardado.
- **`QWEN.md`** (ya mencionado arriba) es la otra mitad — instrucciones que **vos** escribís a mano, en vez de que el modelo las infiera solo. Mismo patrón que `CLAUDE.md`.

**Por qué esto no contradice lo que se explicó antes sobre que el modelo no tiene memoria:** el auto-memory no vive en los pesos de Qwen 2.5 Coder 7B — es lógica de la aplicación Qwen Code, que usa el modelo conectado (acá, el de Ollama) para decidir qué vale la pena recordar y para redactar la nota, pero el mecanismo de guardar/recuperar archivos entre sesiones es de la herramienta, no del modelo. Es exactamente la misma relación que hay entre Claude Code (la app, con su sistema de archivos de memoria) y el modelo que la potencia — la memoria vive un nivel arriba del modelo, no adentro de él.

## Qwen Code vs. Goose — cuál usar

Ambos responden a la misma pregunta ("una app como Claude Code, local"), con un matiz:

| | Qwen Code | Goose |
|---|---|---|
| Quién lo hace | El propio equipo de Qwen (Alibaba) | Block/Square, ahora Agentic AI Foundation |
| Extensión de VS Code oficial | Sí (Beta, Marketplace) | No directamente (se usa vía terminal o su propia app de escritorio) |
| Ejemplo oficial de config con Ollama | Sí, usando la familia Qwen específicamente | Sí, genérico (Ollama con cualquier modelo) |
| Archivo de contexto por proyecto | `QWEN.md` | Reglas vía extensiones/Memory |
| **Memoria automática (identifica sola, sin que se le pida)** | **Sí, "Auto-memory" — activada por defecto**, 4 categorías documentadas, limpieza automática diaria | Existe la extensión "Memory", pero **no viene activada por defecto** y su documentación es mucho más escueta ("sistema de memoria integrado para contexto persistente", sin detalle de qué categoriza ni si limpia sola) |

**Para la pregunta específica de "que identifique factores solo y los deje establecidos para el futuro": Qwen Code es la respuesta más directa y mejor documentada de las dos** — viene lista de fábrica para eso. Igual no hay que elegir uno solo: se puede instalar Qwen Code para trabajar directo en VS Code con memoria automática, y tener Goose como agente de terminal para tareas más autónomas fuera del editor. Ambos apuntan al mismo Ollama, no compiten por recursos distintos.

## Lo más parecido a "una app como Claude Code" en modo agente de terminal general: Goose

El usuario preguntó específicamente por algo como esta misma herramienta (Claude Code) — que interactúe directo con el equipo, maneje proyectos como carpetas de trabajo, y pueda **iniciar una carpeta de proyecto por su cuenta**, no solo autocompletar código dentro de un archivo ya abierto. Eso es una categoría distinta de Continue.dev/Aider (asistentes *dentro* de un proyecto existente) — es un **agente autónomo de propósito general que corre en la máquina**. Verificado en goose-docs.ai (2026-08-26):

- **Qué es:** "goose is a general-purpose AI agent that runs on your machine" — no es solo para código (también research, escritura, automatización, análisis de datos), pero el caso de uso principal documentado es justamente programar.
- **Cómo se usa:** CLI y app de escritorio (Windows/Mac/Linux), ambas construidas en Rust. Se le da una instrucción en lenguaje natural ("crea un juego de tic-tac-toe interactivo en JavaScript") y **crea los archivos y carpetas por su cuenta** — confirmado literalmente en su propio tutorial oficial: la instrucción de ejemplo termina con un archivo `.js` y un `.html` nuevos en el directorio, creados por el agente.
- **Soporta Ollama directamente** (confirmado en su página de proveedores) — "Local model runner supporting **Qwen**, Llama, DeepSeek, and other open-source models" — Qwen 2.5 Coder 7B corre ahí sin adaptar nada.
- **Extensible vía MCP** (Model Context Protocol) — **el mismo estándar del navegador Playwright ya instalado en este entorno de trabajo**. Trae más de 70 extensiones documentadas (bases de datos, GitHub, Google Drive, control del computador/navegador) y se le pueden sumar más.
- **Subagentes:** puede lanzar sub-agentes propios para tareas en paralelo (revisión de código, investigación, procesamiento de archivos) — mismo concepto que uso yo mismo en esta conversación.
- Es parte de la **Agentic AI Foundation** (Linux Foundation) — gobernanza abierta, no depende de una sola empresa.

**Esto es lo más cercano a "una app como la tuya" que existe hoy, open-source y compatible con este modelo sin adaptar nada.**

## Complemento dentro del editor: Continue.dev

Extensión de VS Code (también JetBrains) para programar con un asistente de IA — el rol que Cursor/Copilot cumplen con modelos cerrados, pero funcionando 100% local con Ollama. Sirve mejor para trabajar *dentro* de un proyecto ya iniciado (autocompletar, editar, explicar) que para arrancar uno desde cero — para eso ver Goose arriba.

**Confirmado en la documentación oficial (docs.continue.dev):**
- Soporte directo y ya empaquetado para este modelo exacto: `ollama/qwen2.5-coder-7b` es un bloque de configuración pre-armado en su guía oficial de Ollama.
- Modos: **Agent** (puede editar archivos, ejecutar acciones con varios pasos), **Chat**, **Autocomplete**, **Edit** — no es solo un chat, es un asistente que interactúa con el proyecto.
- **Rules** (`.continue/rules`): archivos de reglas/convenciones del proyecto que el agente respeta siempre — versionables junto al código. Esto es lo más parecido a "memoria" que trae de fábrica, pero es **estático** (lo escribe la persona, no se actualiza solo) — ver sección de memoria más abajo.
- Soporta MCP (Model Context Protocol) — el mismo estándar del navegador Playwright ya instalado en este entorno de trabajo, por si en el futuro se conecta alguna herramienta similar.

## Alternativa evaluada: Aider (CLI)

Asistente de programación por terminal, consciente de git (arma commits automáticamente), con "repo-map" (mapa automático del código del proyecto que le da contexto sin tener que pegar archivos a mano).

**Confirmado en la documentación oficial (aider.chat):** soporte directo de Ollama vía `aider --model ollama_chat/<modelo>`.

**Gotcha crítico — aplica a cualquier herramienta que use Ollama, no solo Aider (verificado y corregido 2026-08-26 contra el repo oficial de Ollama, más actualizado que la mención inicial de la documentación de Aider):**

Ollama **no usa el contexto completo del modelo por defecto** — el límite depende de la VRAM de la tarjeta: menos de 24GB de VRAM (el caso de esta RTX 5070 12GB) usa solo **4K de contexto por defecto**. Muy por debajo de los 100K de contexto seguro que se confirmó que esta GPU puede manejar con Qwen 2.5 Coder 7B (ver `../modelo/02-modelo-elegido.md`) — **si no se configura explícitamente, se pierde la ventaja de contexto largo que fue justamente el criterio principal de elección del modelo.**

Se resuelve de dos formas (documentación oficial de Ollama, `context-length.mdx`):
- **App de Ollama:** mover el slider de "Context length" en la configuración a lo deseado.
- **CLI/servicio:** variable de entorno `OLLAMA_CONTEXT_LENGTH=64000 ollama serve` (o el valor que corresponda).

**Cómo verificar que quedó bien configurado:** correr `ollama ps` mientras el modelo está cargado — muestra una columna `CONTEXT` con el valor real asignado y `PROCESSOR` con el reparto GPU/CPU. Si `CONTEXT` sigue en 4096, no se aplicó el cambio. **Este paso no es opcional.**

## Conectores a GitHub — ¿existe algo como lo que uso yo (gh CLI) para este sistema?

El usuario preguntó si para este piloto existen herramientas tipo conector a GitHub (como el `gh` CLI que se usa en esta misma conversación), para que el trabajo que se proyecte hacer quede comiteado a repos reales, como parte de la estructura de montaje — igual que PowerShell, Python u otras herramientas necesarias. Verificado 2026-08-26:

**Punto clave: `gh` (GitHub CLI) no es una herramienta exclusiva de Claude Code — es un programa de línea de comandos normal**, igual que `git`. Cualquier agente que pueda ejecutar comandos de terminal en el equipo (y Goose lo hace, con su extensión **Developer**, "built-in developer tools for file editing and **shell command execution**") puede usarlo exactamente igual que se usa acá. No hace falta un "conector especial" — hace falta que `git` y `gh` estén instalados en el equipo y autenticados una vez, y de ahí en adelante Goose puede correr `git commit`, `git push`, `gh repo create`, `gh pr create`, etc. tal cual como se hizo con este mismo repo (`ia-local-piloto`).

**Instalación confirmada (winget, IDs verificados en este equipo, 2026-08-26):**
- `git`: paquete `Git.Git`
- `gh` (GitHub CLI): paquete `GitHub.cli`

**Autenticación:** `gh auth login` es un paso interactivo (abre el navegador para el login de OAuth) — no se puede dejar 100% automatizado en un script, hay que completarlo una vez a mano después de instalar. Ver `scripts/pasos/12-instalar-herramientas-dev.ps1`.

### Opción más nativa para Goose específicamente: extensión "GitHub" vía MCP

Además de shell + `gh` CLI, Goose tiene una **extensión dedicada de GitHub** en su directorio oficial (goose-docs.ai/extensions, 32.5k estrellas en GitHub — es el servidor MCP oficial de GitHub, alojado por la propia GitHub, no algo de terceros). Se conecta así:

```
goose session --with-streamable-http-extension "https://api.githubcopilot.com/mcp/"
```

Requiere un **Personal Access Token de GitHub** (se genera en GitHub.com, no es lo mismo que la sesión de `gh auth login`) puesto como header `Authorization: Bearer <token>`. Esta vía es más "estructurada" (llamadas de herramienta directas, no depende de que el agente escriba y parsee comandos de texto) — vale la pena evaluarla si el uso con GitHub se vuelve intensivo, pero para empezar, `git`/`gh` por shell alcanza y es más simple de configurar.

### VS Code + Continue.dev — misma lógica

VS Code ya trae control de código fuente (Git) integrado de fábrica, y existe la extensión oficial "GitHub Pull Requests and Issues" para gestionar PRs/issues sin salir del editor. Continue.dev en modo **Agent** (con acceso a archivos/terminal) puede también ejecutar `git`/`gh` directamente, con el mismo principio que Goose — la interconexión con GitHub no depende de Continue.dev en sí, depende de que el editor/terminal tengan `git`/`gh` disponibles, que es justamente lo que resuelve `12-instalar-herramientas-dev.ps1`.

### Python — la otra herramienta mencionada

Se agrega también a la instalación base, ya que es de uso general (scripts, procesamiento de datos, herramientas de IA que a veces solo tienen SDK en Python) — paquete winget verificado: `Python.Python.3.12`. No está atado a ningún paso específico del piloto todavía, es infraestructura base para lo que se proyecte trabajar más adelante.

## Memoria persistente — cómo resolverlo en la práctica (actualizado 2026-08-27)

Con Auto-memory de Qwen Code verificado (sección de arriba), la respuesta ya no es un plan de dos niveles a futuro — es una pieza que **ya viene resuelta de fábrica** en una de las dos herramientas que se van a instalar. Queda así, de mayor a menor automatización:

### Automática, de fábrica: Auto-memory de Qwen Code

Ya prendida por defecto en cuanto se instala Qwen Code (`13-instalar-qwen-code.ps1`) — identifica sola usuario/feedback/proyecto/referencias y las guarda en `~/.qwen/projects/<proyecto>/memory/`, sin configurar nada. Es la respuesta principal para el trabajo dentro de VS Code con Qwen Code. Ver sección de arriba para el detalle completo.

### Estática, para Continue.dev/Aider (y como respaldo legible por humanos)

Archivos de reglas/convenciones estáticos — `.continue/rules` en Continue, o un archivo de convenciones que Aider lea al iniciar. Continue.dev **no** trae memoria automática (confirmado en la tabla comparativa de arriba), así que si se usa como asistente de editor en vez de o junto a Qwen Code, esta sigue siendo la única vía. **Es el mismo patrón que ya se usa en los 4 repos de `Documents/Proyectos IA/`** (`../decisiones.md`, bitácora mantenida a mano) — no se actualiza sola, pero es memoria persistente real, sostenida por la disciplina de mantener el archivo al día, no por magia del modelo. `AGENTS.md` (raíz del repo) cumple este mismo rol para Goose.

### Mem0 — no se instala, sigue descartado

Librería open-source dedicada a dar memoria persistente a agentes de IA (extrae/actualiza/recupera automáticamente, soporta Ollama de punta a punta — verificado en docs.mem0.ai, 2026-08-26). Se evaluó como el "Nivel 2" antes de confirmar que Qwen Code ya trae Auto-memory de fábrica; con eso resuelto, Mem0 dejó de ser necesario para el caso de uso principal (programar con ayuda de un agente en VS Code) y solo tendría sentido si más adelante se necesita una memoria **compartida entre herramientas distintas** (ej. que Goose y Qwen Code vean las mismas memorias) — no es el caso hoy, así que sigue sin instalarse, siguiendo el mismo criterio de no sobredimensionar ([[feedback-no-sobredimensionar]]).

## Próximos pasos

- [ ] Instalar Ollama y confirmar `OLLAMA_CONTEXT_LENGTH` configurado (no dejar el default de 2K).
- [ ] Instalar **Goose** (CLI o desktop) y configurarlo contra Ollama/Qwen 2.5 Coder 7B — es la pieza que resuelve "iniciar un proyecto/carpeta por su cuenta".
- [ ] Instalar **Qwen Code** (`13-instalar-qwen-code.ps1`) y su extensión de VS Code (a mano, desde el Marketplace) — resuelve tanto el trabajo dentro del editor como la memoria automática, sin depender de Continue.dev.
- [ ] Instalar Continue.dev en VS Code solo si hace falta un asistente adicional (ej. autocompletado inline que Qwen Code no cubra); en ese caso, crear `.continue/rules` con las convenciones básicas.
- [ ] Evaluar Aider como alternativa/complemento de terminal si el flujo de trabajo lo pide.
- [ ] Revisar después de las primeras semanas de uso real si hace falta compartir memoria entre Goose y Qwen Code (Mem0) — no antes.
