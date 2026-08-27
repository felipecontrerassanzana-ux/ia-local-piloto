# Herramientas para trabajar de forma efectiva (no solo el modelo pelado)

Confirmado en la conversación anterior: Qwen 2.5 Coder 7B no tiene memoria persistente — es sin estado. Para programar/armar proyectos de forma efectiva con él (que es el uso principal de este equipo), hace falta una capa de herramientas alrededor, igual que yo (Claude) no soy solo el modelo, soy el modelo + un entorno con archivos, memoria y herramientas. Esta página documenta qué piezas existen para eso, verificadas contra documentación oficial (2026-08-26), no de memoria sin chequear.

## Lo más parecido a "una app como Claude Code": Goose

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

Ollama **no usa el contexto completo del modelo por defecto** — el límite depende de la VRAM de la tarjeta: menos de 24GB de VRAM (el caso de esta RTX 5070 12GB) usa solo **4K de contexto por defecto**. Muy por debajo de los 100K de contexto seguro que se confirmó que esta GPU puede manejar con Qwen 2.5 Coder 7B (ver `modelo-elegido.md`) — **si no se configura explícitamente, se pierde la ventaja de contexto largo que fue justamente el criterio principal de elección del modelo.**

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

**Autenticación:** `gh auth login` es un paso interactivo (abre el navegador para el login de OAuth) — no se puede dejar 100% automatizado en un script, hay que completarlo una vez a mano después de instalar. Ver `scripts/12-instalar-herramientas-dev.ps1`.

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

## Memoria persistente — cómo resolverlo en la práctica

### Nivel 1 (para partir, sin instalar nada extra)

Archivos de reglas/convenciones estáticos — `.continue/rules` en Continue, o un archivo de convenciones que Aider lea al iniciar. **Es el mismo patrón que ya se usa en los 4 repos de `Documents/Proyectos IA/`** (`decisiones.md`, bitácora mantenida a mano) — no es memoria automática, pero es memoria persistente real, sostenida por la disciplina de mantener el archivo al día, no por magia del modelo.

### Nivel 2 (si el uso real muestra que hace falta algo que se actualice solo)

**Mem0** — librería open-source dedicada a dar memoria persistente a agentes de IA, que extrae, actualiza y recupera memorias automáticamente a medida que se conversa (no hay que escribirlas a mano). Verificado en su documentación oficial (docs.mem0.ai, 2026-08-26):

- Es **open-source y autoalojable** (`pip install mem0ai`, o un stack Docker con dashboard) — no depende de un servicio en la nube.
- **Soporta Ollama tanto para el LLM de extracción como para los embeddings** — confirmado en su lista de proveedores (`components/llms/models/ollama`, `components/embedders/models/ollama`), con un cookbook oficial dedicado: *"Local Companion (Ollama) — Use when the companion must run entirely on local models"*.
- Usa una base vectorial para guardar las memorias (por defecto Qdrant) — **el mismo tipo de componente que ya se planea instalar para el RAG de este piloto** (ver `plan-instalacion.md`), así que no es tecnología nueva, es reutilizar la misma pieza para dos propósitos.

**Por qué no se instala de entrada:** siguiendo el mismo criterio que ya se aplicó en la elección de hardware ([[feedback-no-sobredimensionar]] — no pedir más de lo que la fase actual necesita), conviene primero validar el piloto básico (Ollama + Continue + Rules estáticas) y sumar Mem0 solo si en el uso real se nota que las reglas estáticas no alcanzan y hace falta algo que aprenda solo.

## Próximos pasos

- [ ] Instalar Ollama y confirmar `OLLAMA_CONTEXT_LENGTH` configurado (no dejar el default de 2K).
- [ ] Instalar **Goose** (CLI o desktop) y configurarlo contra Ollama/Qwen 2.5 Coder 7B — es la pieza que resuelve "iniciar un proyecto/carpeta por su cuenta".
- [ ] Instalar Continue.dev en VS Code, configurar el bloque `ollama/qwen2.5-coder-7b`, para el trabajo dentro del editor una vez que el proyecto ya existe.
- [ ] Crear `.continue/rules` con las convenciones básicas de trabajo (puede partir vacío o con reglas mínimas, e ir creciendo con uso real).
- [ ] Evaluar Aider como alternativa/complemento de terminal si el flujo de trabajo lo pide.
- [ ] Revisar después de las primeras semanas de uso si hace falta Mem0 (Nivel 2) o si las reglas estáticas alcanzan.
