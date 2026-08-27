# Bitácora de decisiones

Registro cronológico, append-only — mismo patrón que `decisiones.md` en `ia-local`, `ia-tecnoingenieria` y `cumplimiento-tecnoingenieria`. No se reescribe el historial, solo se agrega.

## 2026-08-26 — Creación del proyecto

Nace como proyecto independiente, a pedido explícito de Felipe: "esto debe quedar como un proyecto independiente, fuera de todo lo demás... por ende este debiese ser el proyecto IA Local Piloto". Explícitamente **fuera** de la estructura transversal de `ia-local` (que se mantiene teórica, sin ejecución) y **fuera** de `ia-tecnoingenieria` (caso de negocio de la empresa, hardware distinto y más grande).

**Origen concreto:** Felipe tiene acceso a un equipo real (RTX 5070 12GB / 16GB RAM / Ryzen 5 3600), distinto y más chico que el hardware recomendado para el piloto de la empresa en `ia-tecnoingenieria` (RTX 5070 Ti 16GB, ~$2,6M CLP). Ese equipo no alcanza para el modelo generalista de la empresa (Qwen3.6-27B, confirmado "Too big" en 12GB según `ia-local/docs/modelos.md`), pero sí es suficiente para un modelo de programación más chico — ya se había identificado Qwen 2.5 Coder 7B en la conversación previa, pero esa conclusión nunca había quedado escrita en ningún archivo. Este proyecto es donde se documenta y ejecuta esa idea.

**Decisión de estructura:** repo hermano nuevo (`ia-local-piloto`) bajo `Documents/Proyectos IA/`, que referencia la base de conocimiento de `ia-local` (modelos, hardware, arquitectura, conceptos-fundamentales) vía links relativos, sin duplicar contenido — mismo patrón de referencia cruzada que ya usan los otros tres repos entre sí.

**Estado al cierre de esta entrada:** estructura de documentos creada (README, hardware-real.md, modelo-elegido.md, plan-instalacion.md, plan-pruebas.md, decisiones.md) — ningún paso de instalación real ejecutado todavía en el equipo.

## 2026-08-26 (mismo día) — Verificación con datos reales de la GPU exacta

El usuario pidió verificar `willitrunai.com/es/can-run/qwen-3.5-9b-on-rtx-5070-12gb`, lo que llevó a descubrir que el sitio tiene también la página exacta para el modelo ya elegido: `willitrunai.com/es/can-run/qwen-2.5-coder-7b-on-rtx-5070-12gb`. Esto cierra un hueco que había quedado pendiente (antes solo había datos de RTX 4070/3060 12GB como proxy, con otro modelo).

**Hallazgos:** Qwen 2.5 Coder 7B en esta GPU exacta — "Runs Great" (grado A/78), 7,5GB de 12GB en Q4_K_M (98,0 tok/s), contexto seguro real de 100K (no 131K teóricos), sin offload en ningún workload evaluado. El sitio recomienda **Q8_0** (no Q4_K_M) como mejor cuantización para esta tarjeta específica, dado el margen de VRAM disponible. Se comparó contra la alternativa generalista Qwen 3.5 9B (grado S pero peor rendimiento específico en el workload de código y un tercio del contexto útil) — se mantiene Qwen 2.5 Coder 7B como elección. Detalle completo en `modelo-elegido.md`.

**Sigue pendiente:** medición de primera mano en el equipo real (esto sigue siendo una estimación del sitio, no una medición) — ver `resultados.md` una vez se ejecute la instalación.

## 2026-08-26 (mismo día) — Fundamentación de la elección de modelo

El usuario pidió explícitamente: al ser un proyecto piloto, hay que **fundamentar** por qué Qwen, qué es, algo de su historia, y **esquematizar la decisión** — no basta con la ficha técnica de `modelo-elegido.md`. Se creó `fundamentacion-modelo.md` con: qué es Qwen (Alibaba Cloud / Tongyi Qianwen), historia real verificada contra el blog oficial de Qwen (qwen.ai/blog) — Qwen2.5 anunciado 2024-09-18, familia completa de Qwen2.5-Coder (6 tamaños) el 2024-11-11, con reporte técnico propio (Hui et al. 2024) — y un esquema en 5 filtros (VRAM → caso de uso → contexto real → verificación en la GPU exacta → licencia) que muestra cómo se llegó a Qwen 2.5 Coder 7B específicamente, no solo el resultado final.

## 2026-08-26 (mismo día) — Qué esperar en la práctica, por tipo de operación

El usuario pidió especificar qué se puede conseguir con este modelo en este equipo específico, y qué esperar en distintas operaciones — no solo los números crudos (tok/s, VRAM). Se agregó una sección nueva en `modelo-elegido.md` con: calibración explícita de que el 7B no es el 32B insignia (las comparaciones con GPT-4o del anuncio oficial son del 32B, no de este modelo — el propio equipo de Qwen declara "correlación positiva entre tamaño y desempeño"), traducción de 98 tok/s y 100K de contexto a términos intuitivos (palabras/segundo, líneas de código aproximadas), y una tabla de qué esperar / qué no esperar por operación (chat, autocompletado, debugging, contexto largo, agentic coding, RAG, español) — fuentes: blog oficial de Qwen y ficha de Hugging Face (huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct), verificadas con navegador real.

## 2026-08-26 (mismo día) — Herramientas de trabajo y memoria persistente

El usuario preguntó si el modelo tiene memoria persistente por proyecto (como la que usa Claude Code) y, al confirmar que no, pidió las herramientas necesarias para trabajar de forma efectiva dado que se va a programar harto. Se creó `herramientas-trabajo.md` con investigación verificada contra documentación oficial (2026-08-26):

- **Continue.dev** recomendado como herramienta principal (extensión VS Code, soporte oficial empaquetado para `ollama/qwen2.5-coder-7b`, modos Agent/Chat/Autocomplete/Edit, y "Rules" para convenciones persistentes del proyecto).
- **Aider** evaluado como alternativa de terminal (soporte oficial de Ollama confirmado).
- **Hallazgo crítico de la documentación de Aider, aplica a cualquier herramienta sobre Ollama:** Ollama usa 2K de contexto por defecto y descarta el resto en silencio si no se configura `OLLAMA_CONTEXT_LENGTH` — sin este paso se pierde la ventaja de 100K de contexto que fue el criterio principal de elección del modelo. Se agregó como paso obligatorio en `plan-instalacion.md`.
- **Memoria persistente:** Nivel 1 (ahora) = archivos de reglas estáticos, mismo patrón que `decisiones.md` ya usado en los 4 repos. Nivel 2 (si hace falta más adelante) = **Mem0**, librería open-source de memoria para agentes, confirmado compatible con Ollama (LLM y embeddings) con cookbook oficial 100% local — no se instala de entrada, sigue el mismo criterio de [[feedback-no-sobredimensionar]] (empezar acotado, escalar si se justifica).

## 2026-08-26 (mismo día) — Alternativas de motor y acceso remoto sin IP fija

El usuario pidió ver qué opciones hay además de Ollama, porque quiere que el piloto cumpla distintas funciones, y planteó que el equipo va a vivir en una red con fibra Movistar 800 megas **sin IP fija**, con la meta de poder acceder por navegador desde afuera. Se investigó contra documentación oficial (2026-08-26) y se crearon `motor-alternativas.md` y `acceso-remoto.md`:

- **Motor:** Ollama cubre solo texto/código. **LocalAI** (MIT, open-source) cubre texto+voz+imagen+visión desde un solo binario, con API compatible Ollama/OpenAI/Anthropic/ElevenLabs — la opción si "distintas funciones" incluye algo más que código. **LM Studio** como alternativa de interfaz gráfica. **Open WebUI** como capa de interfaz web encima de cualquiera de los dos, con RAG incorporado — se detectó un producto nuevo relacionado ("Open WebUI Computer", agente con acceso remoto por navegador ya incorporado) que queda marcado para evaluar más adelante, no adoptar todavía (no se verificó cómo funciona su acceso remoto por dentro).
- **Acceso remoto sin IP fija:** confirmado que existe una diferencia real entre "IP dinámica pero pública" (resoluble con DDNS) y "CGNAT" (no hay forma de abrir puertos, sin importar la config del router) — se dejó el paso concreto para que Felipe lo verifique él mismo (comparar IP del router vs. whatismyip.com). Recomendación mientras tanto, funciona en ambos casos: **Tailscale Funnel** (expone un servicio a cualquier navegador sin que la otra persona instale nada, gratis, con límite de ancho de banda) como opción para partir — **Cloudflare Tunnel** como alternativa sin ese límite si el uso remoto crece. Se propagó el hallazgo genérico a `../ia-local/docs/arquitectura.md` (sección de acceso remoto), ya que antes solo mencionaba Tailscale de forma vaga sin esta distinción.

## 2026-08-26 (mismo día) — Cierre de motor y arquitectura de acceso remoto con dominio propio

Felipe confirmó directamente (sin necesidad de verificación indirecta) que Movistar **no tiene CGNAT** en esta conexión, y aportó dos datos nuevos: tiene un **dominio propio** disponible y un **hosting reseller (cPanel/WHM)** del que es administrador, planteando si serviría para "triangular" el acceso.

- **Motor — decisión cerrada:** Ollama para partir (mejor soporte en Continue.dev/Aider, más simple), LocalAI queda como escalón si en el uso real aparece necesidad concreta de otras funciones (voz/imagen) — no antes. Ver `motor-alternativas.md`.
- **Hosting reseller — descartado como intermediario de tráfico:** se preguntó explícitamente si tenía shell/SSH y procesos persistentes; Felipe confirmó que es cPanel/WHM compartido, sin esa capacidad — PHP con timeouts cortos no sirve para respuestas de un LLM en streaming. Sí sirve para administrar el DNS del dominio.
- **Arquitectura de acceso remoto actualizada:** con CGNAT descartado y dominio propio disponible, la recomendación pasa a **Cloudflare Tunnel + dominio propio** (URL propia, sin límite de ancho de banda, sin exponer el router) como opción principal, con **DDNS directo + Caddy** documentado como alternativa "100% propia" (sin intermediarios, pero expone el router) y **Tailscale Funnel** como respaldo rápido. Ver `acceso-remoto.md` reescrito completo.

## 2026-08-26 (mismo día) — Un agente tipo Claude Code para este equipo: Goose

El usuario preguntó específicamente por algo "como Claude Code" — que interactúe directo con el equipo, maneje proyectos, y pueda iniciar una carpeta de proyecto por su cuenta, no solo autocompletar dentro de un archivo. Se identificó y verificó **Goose** (goose-docs.ai, 2026-08-26): agente de propósito general que corre en la máquina (CLI + app de escritorio, Rust), soporte directo de Ollama con Qwen nombrado explícitamente en su documentación de proveedores, extensible vía MCP (mismo estándar del Playwright ya instalado), con subagentes propios, y gobernanza abierta bajo la Agentic AI Foundation (Linux Foundation). Confirmado en su propio tutorial que crea archivos/carpetas nuevas a partir de una instrucción en lenguaje natural — es lo más cercano a "una app como la tuya" disponible hoy, compatible con el modelo elegido sin adaptar nada. Se agregó a `herramientas-trabajo.md` como la pieza principal para esta necesidad, con Continue.dev reposicionado como complemento para trabajar dentro de un proyecto ya iniciado.

## 2026-08-26 (mismo día) — Autenticación para lo que queda expuesto a internet

El usuario preguntó si hace falta API key, autorización o registro de correo para poder usar esto de forma segura. Se aclaró la distinción: Goose corre local (no expuesto a internet, no necesita login propio); lo que sí queda expuesto por el túnel es Open WebUI. Verificado en la guía oficial de hardening de Open WebUI (docs.openwebui.com, 2026-08-26):

- El login por correo/contraseña **se activa solo**: el registro público se cierra automáticamente apenas se crea la primera cuenta (que queda como admin) — no requiere configuración.
- Cuentas nuevas posteriores (si se reactiva el registro) quedan en estado "pending" hasta aprobación manual del admin — comportamiento por defecto.
- API Keys disponibles para acceso programático, separado del login de navegador.
- La propia guía oficial de Open WebUI recomienda textualmente sumar un proxy de acceso zero-trust como **Cloudflare Access** para todo despliegue expuesto a internet — encaja directo con el Cloudflare Tunnel ya elegido en la decisión anterior.

Se actualizó `acceso-remoto.md` con la respuesta y los próximos pasos concretos (configurar Cloudflare Access con la lista de correos autorizados, antes de dejar el túnel activo).

## 2026-08-26 (mismo día) — Esquema estructural completo + revisión proactiva

El usuario pidió juntar todo lo decidido hasta ahora en un esquema estructural del montaje del proyecto, y pidió explícitamente que fuera propositivo: señalar qué más podría hacer falta, no solo responder lo preguntado. Se creó `arquitectura-piloto.md` con el diagrama completo del stack (Cloudflare Access → Cloudflare Tunnel → Open WebUI → Ollama → RAG, y por separado Goose/Continue.dev en uso local) y una tabla que conecta cada capa con el documento que la fundamenta.

**Hallazgos proactivos agregados (ninguno pedido explícitamente, detectados al mirar el conjunto):**
1. Dos bloqueantes que siguen sin resolver desde el principio: si el equipo es de uso exclusivo o compartido, y sistema operativo (Windows/Linux) — ambos condicionan cómo se instala todo lo demás.
2. Nunca se verificó el ancho de banda de **subida** real de la conexión — todo el acceso remoto depende de eso, no de la bajada, y "800 megas" podría ser asimétrico en el plan hogar (la fuente que confirmó velocidad simétrica era de un plan de empresa, no necesariamente el mismo).
3. Nada de lo planeado deja los servicios corriendo automáticamente tras un reinicio/corte de luz.
4. No existe ningún plan de backup para el estado real del piloto (base de datos de Open WebUI, índice de Qdrant) — a diferencia de `ia-tecnoingenieria`, que sí tiene uno (Drive corporativo).
5. Actualizaciones de las piezas del stack (Ollama, Goose, Continue.dev, cloudflared, Open WebUI, el modelo mismo) sin un punto de revisión periódico definido.
6. Protección básica contra abuso/fuerza bruta a nivel de red, disponible gratis en Cloudflare ya que está en el camino de todas formas, no activada todavía.

## 2026-08-26 (mismo día) — Respuestas a los puntos proactivos, cierre de casi todos

Felipe respondió los 6 puntos planteados en la revisión proactiva anterior, en el mismo mensaje:

- **Equipo:** confirmado uso compartido, no exclusivo (detalle de quién más lo usa es referencial, no necesario en la documentación del proyecto) — se documentó en `hardware-real.md` que Ollama libera VRAM cuando no está en uso, así que no compite de forma permanente, pero sí queda un riesgo real de continuidad si otra persona reinicia/apaga el equipo.
- **Usuarios remotos:** solo Felipe, sin más personas conectadas de forma persistente — simplifica la lista de Cloudflare Access a un solo correo.
- **Ancho de banda:** Felipe cree que el plan es "800 sincrónico" — se toma como supuesto de trabajo, no bloqueante, queda como verificación de baja prioridad.
- **Continuidad:** no hay UPS todavía, pero la BIOS quedará configurada para reencender solo tras un corte de luz — combinado con servicios configurados para iniciar con el sistema, resuelve la continuidad salvo por la brecha durante el corte mismo (sin UPS no hay funcionamiento ininterrumpido, solo recuperación automática). UPS queda anotado como mejora futura.
- **Backup:** confirmado destino — una carpeta de Google Drive personal (no el corporativo de Tecnoingeniería, son proyectos distintos).
- **Actualizaciones ("el P5"):** Felipe pidió formularlo en serio, no dejarlo vago — se creó `mantenimiento.md` con checklist mensual concreto (Ollama, modelo, Goose, Continue.dev, cloudflared, Open WebUI, verificación de backup y de servicios de inicio).
- **Costos:** Felipe pidió confirmar que toda la estructura sea gratis. Verificado directamente en la página oficial de precios de Cloudflare: **Cloudflare Access es gratis hasta 50 usuarios** y **Cloudflare Tunnel no tiene costo aparte** (incluido en cualquier cuenta). Se armó una tabla completa en `mantenimiento.md` confirmando que cada pieza del stack (Ollama, Qwen, Goose, Continue.dev, Aider, Open WebUI, BGE-M3, Qdrant, Mem0) es gratuita/self-hosted — no hay ningún costo recurrente nuevo en todo el diseño.

Se creó `mantenimiento.md` y se actualizaron `hardware-real.md`, `acceso-remoto.md` y `arquitectura-piloto.md` con todo lo anterior. Del listado proactivo original, el único punto que sigue realmente abierto es el **sistema operativo** (Windows vs. Linux).

## 2026-08-26 (mismo día) — SO confirmado, corrección de contenido personal, scripts reales y GitHub

Felipe confirmó **Windows 11 Pro 25H2**, con dos discos (NVMe ~500GB + HDD 1TB, reparto sin definir) — cierra el último bloqueante que quedaba abierto. Se creó `almacenamiento.md` con el criterio de reparto (modelo/backups en HDD, SO/proyectos activos/RAG en NVMe) y `OLLAMA_MODELS` como mecanismo concreto.

**Corrección de contenido:** Felipe pidió explícitamente que la documentación oficial no mencione que el equipo es de un familiar — ese dato es solo referencial para la conversación (surgió en un momento anterior), no necesario para el proyecto. Se corrigió `hardware-real.md` y esta bitácora para hablar solo de "uso compartido" sin especificar de quién. **Aprendizaje para aplicar hacia adelante:** no todo lo que se conversa en el contexto de una sesión debe quedar escrito en la documentación de un proyecto — detalles personales o familiares mencionados de pasada se mantienen fuera salvo pedido explícito, igual que ya se aplica con el contenido específico de empresa entre `ia-local` y los proyectos de Tecnoingeniería.

**Hallazgo al verificar el modelo en Ollama (no solo en Hugging Face):** la página oficial de Ollama (`ollama.com/library/qwen2.5-coder/tags`) lista el contexto de todas las variantes de 7B como 32K, no los 131K del modelo original ni los 100K estimados por willitrunai.com — probablemente solo el valor por defecto empaquetado en el Modelfile, pero queda marcado como pendiente de verificar empíricamente, no asumido. Se corrigió también el dato de "Ollama usa 2K de contexto por defecto" (venía de la documentación de Aider) — la documentación oficial y más actual de Ollama dice que el default depende de la VRAM (4K para menos de 24GB, el caso de esta GPU) — se mantiene la recomendación de configurar el contexto explícitamente, solo se corrigió el número exacto del default.

**Petición explícita:** crear este proyecto en GitHub con todo lo necesario — no solo documentación, también los pasos de instalación, ejecución y verificación como scripts reales, con lanzadores `.bat` de permisos elevados. Se construyó `scripts/` con 11 scripts PowerShell (verificación de equipo, instalación de Ollama/Goose/Docker, configuración de contexto y ubicación de modelos, despliegue de Qdrant/Open WebUI, instalación de cloudflared como servicio, configuración de inicio automático, backup programado a Drive, y verificación integral) más sus lanzadores `.bat` con auto-elevación UAC — cada comando verificado contra documentación oficial (Ollama, Goose, Cloudflare) antes de escribirlo, no inventado. Repositorio creado en GitHub — ver README para el link.

## 2026-08-26 (mismo día) — Documentación de aprendizaje de los scripts + pruebas de estrés

El usuario pidió dos cosas más: (1) documentación de aprendizaje sobre los `.ps1` — que se entienda qué hace cada uno, porque es parte del proceso de conocimiento del proyecto, no solo de la elección del modelo; (2) un set de pruebas de estrés post-instalación, con esquema real, testeado y analizado, para ver el rendimiento real del modelo instalado (distinto de `plan-pruebas.md`, que evalúa calidad de respuestas, no velocidad/estabilidad).

- Se creó `aprendizaje-scripts.md`: explica cada script (00 al verificar-instalacion) en términos de los conceptos de Windows/PowerShell involucrados (variables de entorno de sistema vs. de usuario, servicios de Windows, volúmenes de Docker, Tareas Programadas, WMI/CIM, auto-elevación UAC) — no solo qué comando corre, sino por qué funciona así.
- Se creó `scripts/11-prueba-estres.ps1` + `.bat`: batería de 3 pruebas (baseline, carga sostenida de 20 corridas, rampa de contexto hasta >100K tokens) usando exclusivamente los campos de métricas que la propia API de Ollama devuelve (`prompt_eval_count`, `eval_count`, `eval_duration` — verificado en `github.com/ollama/ollama/docs/api.md`), no un cronómetro externo aproximado. Genera CSV + resumen en `logs/`.
- Se creó `pruebas-rendimiento.md`: explica qué mide cada prueba, cómo interpretar los resultados (ej. degradación en carga sostenida como señal de throttling térmico, verificado cruzando con lecturas de `nvidia-smi`), y cómo esta prueba cierra específicamente el pendiente que había quedado abierto en `modelo-elegido.md` sobre si el límite de 32K de contexto de Ollama es real o solo un default de fábrica.
- Se actualizó `plan-instalacion.md` con un Paso 6 (prueba de estrés) y una nota inicial apuntando a `aprendizaje-scripts.md` antes de empezar a instalar.

## 2026-08-26 (mismo día) — Control de calidad de los scripts sin instalar nada

El usuario preguntó si valía la pena testear los `.ps1` sin ejecutar instalaciones reales, para encontrar errores que debieron evaluarse en el desarrollo. Se hizo en el momento, con herramientas reales (no una revisión manual superficial):

1. **Parser de PowerShell** (`[System.Management.Automation.Language.Parser]::ParseFile`) sobre los 14 scripts — 0 errores de sintaxis.
2. **PSScriptAnalyzer** (linter oficial de PowerShell, instalado en este equipo solo para el usuario actual) — encontró dos hallazgos reales, no solo de estilo:
   - **Bug real en `00-verificar-equipo.ps1`:** la variable que calculaba el tipo de disco (SSD/HDD) usaba una consulta que no correlacionaba con la unidad correcta (`Get-PhysicalDisk | Where-Object {...}` sin relación con la letra iterada), y encima nunca se usaba en el texto del reporte — quedaba calculada y descartada. Corregido correlacionando letra de unidad → partición → disco → disco físico (`Get-Partition -DriveLetter` → `Get-Disk` → `Get-PhysicalDisk`), y **verificado en vivo en este equipo** (devolvió "SSD" correctamente para C:).
   - **Problema de codificación en los 14 scripts:** ninguno tenía BOM UTF-8. Se probó empíricamente ejecutando un script de prueba con tildes vía `powershell.exe -File` (la misma forma en que los `.bat` invocan los scripts) — sin BOM, el texto salía corrupto (`funciÃ³n` en vez de `función`); con BOM, correcto. Se reescribieron los 14 archivos con BOM y se confirmó que el problema desapareció.
3. Se creó `scripts/_verificar-sintaxis.ps1` + `.bat` como herramienta reutilizable — no numerada (con `_` al inicio, como `_elevar.ps1`) porque no es un paso de instalación, es control de calidad para correr después de cualquier edición futura a los scripts. No pide permisos de administrador (solo analiza texto, no ejecuta nada).

Documentado en `aprendizaje-scripts.md` (nueva sección) y `scripts/README.md`. Los únicos hallazgos restantes del linter (uso de `Write-Host`, verbos en español en nombres de función) se revisaron y se dejaron a propósito — no son errores, son decisiones de diseño (scripts interactivos en español, no funciones de librería en inglés).

## 2026-08-26 (mismo día) — Conectores a GitHub para el piloto (git, gh CLI, extensión GitHub de Goose)

El usuario preguntó si para este sistema existen herramientas conectoras a GitHub como el `gh` CLI usado en esta conversación, para que el trabajo proyectado quede comiteado a repos reales — parte de la estructura de montaje, igual que PowerShell/Python. Verificado 2026-08-26:

- **`gh` no es exclusivo de Claude Code** — es un programa de terminal normal. Cualquier agente con acceso a shell en el equipo (Goose, vía su extensión built-in "Developer") puede usarlo igual que se usa acá, una vez instalado y autenticado.
- IDs de winget verificados en un equipo real: `Git.Git`, `GitHub.cli`, y de paso `Python.Python.3.12` (Python también mencionado por el usuario como herramienta necesaria).
- **Hallazgo adicional:** Goose tiene una extensión dedicada de GitHub en su directorio oficial de extensiones — resultó ser el **servidor MCP oficial de GitHub** (`https://api.githubcopilot.com/mcp/`, alojado por GitHub mismo, 32.5k estrellas), instalable con `goose session --with-streamable-http-extension "..."` y un Personal Access Token. Es una vía más estructurada que shell+gh CLI, documentada como alternativa.
- Continue.dev/VS Code: mismo principio — VS Code trae Git integrado y la extensión oficial "GitHub Pull Requests and Issues"; Continue.dev en modo Agent también puede correr `git`/`gh` por shell.

Se creó `scripts/12-instalar-herramientas-dev.ps1` + `.bat` (pasó por `_verificar-sintaxis.ps1` sin hallazgos nuevos) y se actualizaron `herramientas-trabajo.md` (nueva sección "Conectores a GitHub"), `plan-instalacion.md` (nuevo Paso 1.4) y `scripts/README.md`.

## 2026-08-26 (mismo día) — Extensión Qwen para VS Code: Qwen Code

El usuario preguntó específicamente si existe una extensión de Qwen para VS Code que conecte con el servidor de IA local, igual que se usa Claude Code acá. Se encontró y verificó **Qwen Code** (`github.com/QwenLM/qwen-code`, 27,4k estrellas): agente de terminal hecho por el propio equipo de Qwen, con tabla comparativa oficial de paridad de funciones contra Claude Code (SubAgents, memoria automática, MCP, Plan Mode, sandboxing), **extensión oficial de VS Code (Beta, Marketplace)**, y soporte confirmado de Ollama como proveedor local — con un ejemplo de configuración oficial que usa justo la familia Qwen (`baseUrl: http://localhost:11434/v1`). Tiene también su propio archivo de contexto por proyecto (`QWEN.md`, equivalente a `CLAUDE.md`), modo demonio multi-cliente, y SDKs.

Requiere Node.js 22+ (se instala vía npm). Se creó `scripts/13-instalar-qwen-code.ps1` + `.bat` — instala Node.js si falta, instala Qwen Code, y genera automáticamente `~/.qwen/settings.json` apuntando al Ollama local (sin pisar una configuración existente). Pasó por `_verificar-sintaxis.ps1` sin hallazgos nuevos.

Se actualizó `herramientas-trabajo.md` con una comparación Qwen Code vs. Goose (ambos responden "una app como Claude Code" — Qwen Code tiene extensión de VS Code oficial y es del propio fabricante del modelo; Goose es más agnóstico de modelo y con más extensiones vía MCP) — recomendación: no elegir uno solo, ambos apuntan al mismo Ollama sin competir por recursos distintos.

## 2026-08-27 — Qué va en Docker (fundamentado) y el presupuesto real de RAM

El usuario preguntó si idealmente todo debería ir en Docker. Se respondió que no, con fundamentación técnica (Ollama necesita paso de GPU vía WSL2 si se dockeriza, más frágil que la app nativa; Goose/Continue.dev/Qwen Code necesitan tocar el sistema de archivos/editor real; cloudflared como servicio nativo arranca antes que cualquier contenedor) y se pidió dejarlo documentado, más cómo habilitar/interconectar, más un hallazgo aparte: con 16GB de RAM compartidos, hay que tener cuidado.

Se creó `docker-y-recursos.md`, con un hallazgo importante verificado contra documentación oficial de Microsoft (`learn.microsoft.com/windows/wsl/wsl-config`): **WSL2 reserva por defecto el 50% de la RAM total de Windows** — en este equipo de 16GB, hasta 8GB solo para Docker Desktop, antes de correr una imagen. Se corrigieron los scripts en consecuencia:
- `05-instalar-docker.ps1`: ahora crea `%UserProfile%\.wslconfig` con límite de 4GB para WSL2.
- `06-desplegar-qdrant.ps1` y `07-desplegar-openwebui.ps1`: `--memory="1g"` agregado a cada contenedor.
- `03-descargar-modelo.ps1`: se agregó `ollama pull bge-m3` — se confirmó que BGE-M3 está disponible directo en la biblioteca de Ollama (1,2GB, 567M params), corre en la misma GPU que el modelo de código, evitando sumar un proceso Python aparte que consuma RAM del sistema. Se corrigió `plan-instalacion.md` Paso 2 en consecuencia (antes decía vagamente "instalar/descargar BGE-M3" sin mecanismo concreto).

Presupuesto estimado con las correcciones: de ~14-15GB de 16GB (sin margen, si no se corrige nada) a ~9,5GB (margen real de ~6,5GB) — queda pendiente medir el uso real una vez instalado y corregir la estimación. Todos los scripts modificados pasaron por `_verificar-sintaxis.ps1` sin hallazgos nuevos.

## 2026-08-27 — Se elimina Docker del camino por defecto: Qdrant y Open WebUI nativos

El usuario preguntó si esas dos apps no se podían dejar corriendo nativas en Windows en vez de en Docker, dado el ajuste de RAM del día anterior. Se verificó a fondo (no se había chequeado antes de recomendar Docker como "la única opción"):

- **Qdrant tiene binario oficial nativo de Windows** — confirmado en `github.com/qdrant/qdrant/releases`: cada release publica `qdrant-x86_64-pc-windows-msvc.zip`, una build real, no un contenedor.
- **Open WebUI tiene instalación oficial vía pip** — confirmado en su documentación oficial: *"Python: Suitable for low-resource environments or manual setups"*, un método soportado, no un atajo no documentado.

Con esto, **Docker deja de ser necesario para todo el piloto** — se reescribieron `06-desplegar-qdrant.ps1` y `07-desplegar-openwebui.ps1` para instalar nativo y dejar corriendo cada uno con una Tarea Programada (disparador "al iniciar sistema", usuario `SYSTEM`, reintento automático). `05-instalar-docker.ps1` pasó a ser opcional/respaldo, no el camino por defecto. Efectos en cascada, todos corregidos: `10-configurar-backup.ps1` se simplificó (ya no hace falta el truco del contenedor Alpine, son carpetas normales de Windows — `Compress-Archive` alcanza); `09-configurar-inicio-automatico.ps1` y `verificar-instalacion.ps1` ahora chequean las Tareas Programadas en vez de contenedores Docker; `08-instalar-cloudflared.ps1` corregido para apuntar al puerto nativo de Open WebUI (8080, no el 3000 remapeado que solo existía en el `docker run`). Se reescribió `docker-y-recursos.md` con la fundamentación completa y el presupuesto de RAM actualizado (~7-8GB de 16GB, ~8GB de margen real — mejor que los ~9,5GB de la versión con Docker limitado).

**Nota de proceso:** al reescribir 06 y 07 completos con la herramienta de escritura de archivos (no edición incremental), se perdió el BOM UTF-8 de ambos — detectado por `_verificar-sintaxis.ps1` (que existe justamente para esto) antes de comitear, corregido de inmediato. Confirma que vale la pena correr ese script después de cualquier reescritura completa, no solo tras ediciones parciales.

## 2026-08-27 (mismo día) — Nota de trazabilidad: por qué Docker existió antes de descartarse

Docker fue la primera aproximación para Qdrant/Open WebUI (ver entrada anterior). Se descartó al confirmar dos cosas contra restricciones del equipo ya documentadas desde el inicio del proyecto (`hardware-real.md`: 16GB de RAM): (1) ambas piezas tienen alternativa nativa oficial para Windows, y (2) esa alternativa evita el costo de RAM de WSL2 (que reserva 50% de la RAM por defecto). `05-instalar-docker.ps1` se mantiene en el repo como respaldo opcional — no se eliminó, solo dejó de ser el camino por defecto. El detalle técnico completo de la comparación vive en `docker-y-recursos.md`; el histórico de cómo cambió esta decisión queda en el `git log` del repo, commit por commit.

## 2026-08-27 (mismo día) — Propagación hacia `ia-local`, con luz verde total

El usuario notó que varios aprendizajes de este piloto (Goose/Qwen Code, la trampa de RAM de Docker/WSL2, verificación de scripts sin ejecutarlos, git/gh como base) son genéricos — útiles para cualquier proyecto futuro de IA local, no solo este — y pidió propagarlos a `ia-local` con autorización total, sin preguntas. Se agregaron a `ia-local/docs/arquitectura.md` tres secciones nuevas ("Herramientas de código tipo agente", verificación de scripts, "Presupuesto de RAM y la trampa de Docker/WSL2"), enlazando de vuelta a los documentos de este repo como caso aplicado con números reales. Detalle completo en `ia-local/CHANGELOG.md` y `ia-local/PROYECTOS.md` (sección nueva "Tercera pasada — piloto real hacia atrás").

De paso, el usuario planteó si `ia-local` debería reenmarcarse como base de una consultoría (ya tenía esa visión anotada a futuro). Se recomendó no renombrar todavía — queda como pregunta abierta en `ia-local/PROYECTOS.md` §3.5, a revisar si en algún momento existe una consultoría real que use este material.

## 2026-08-27 (mismo día) — Control de calidad como parte del flujo de git, no solo un script suelto

El control de calidad de scripts (`_verificar-sintaxis.ps1`) pasó a estar mecanizado dentro del flujo de trabajo, no solo disponible para correr manualmente:

- `_verificar-sintaxis.ps1` ahora bootstrapea el proveedor NuGet antes de instalar PSScriptAnalyzer si hace falta, y reporta explícitamente `[SIN LINTER]` si no logra cargarlo, en vez de reportar "0 hallazgos" de forma ambigua. Corrige un caso real: el script fallaba en silencio al ejecutarse vía `powershell.exe` (Windows PowerShell 5.1, el intérprete que usan todos los `.bat` del proyecto) porque el proveedor NuGet no viene bootstrapeado ahí por defecto — distinto de pwsh 7, que sí lo tenía. El script también termina ahora con código de salida 0/1 según si hay errores reales (antes siempre salía en 0).
- Se agregó `scripts/hooks/pre-commit` + `scripts/instalar-git-hooks.sh`: cualquier commit que modifique un `.ps1` corre la verificación automáticamente y se bloquea si hay errores de sintaxis o archivos sin BOM. Probado en vivo con un script deliberadamente roto (bloqueó) y un commit real válido (lo dejó pasar).

Detalle completo, incluyendo la explicación del porqué de la diferencia entre intérpretes de PowerShell, en `aprendizaje-scripts.md`.

## 2026-08-27 (mismo día) — Aclaración: Qwen Code sí puede identificar cosas solo, como memoria automática

El usuario aclaró que su pregunta anterior sobre "parser+linter+BOM como regla" en realidad apuntaba a algo más de fondo: si Qwen (el motor) puede identificar factores durante el trabajo y dejarlos establecidos implícitamente para el futuro, igual que hace Claude. Verificado en la documentación oficial de Qwen Code (`qwenlm.github.io/qwen-code-docs/en/users/features/memory/`, 2026-08-27):

- **Qwen Code tiene "Auto-memory", activado por defecto** — identifica sola 4 categorías (sobre el usuario, su feedback, contexto del proyecto, referencias externas) casi idénticas a la propia taxonomía de memoria de Claude (usuario/feedback/proyecto/referencia). Se guarda como markdown plano en `~/.qwen/projects/<proyecto>/memory/`, con limpieza automática diaria (`/dream`) y comandos manuales (`/remember`, `/forget`, `/memory`).
- Comparado con Goose: su extensión "Memory" existe pero no viene activada por defecto y está mucho menos documentada.
- **Se aclaró la distinción que sigue aplicando:** esto es una capacidad de la aplicación Qwen Code, no del modelo Qwen 2.5 Coder 7B en sí (que sigue sin estado) — misma relación que entre Claude Code y el modelo que lo potencia.

Se actualizó `herramientas-trabajo.md` con una sección nueva y se corrigió la tabla comparativa Qwen Code vs. Goose para incluir esta diferencia real.

## 2026-08-27 (mismo día) — Base de conocimiento del motor + archivo de arranque para los agentes

El usuario pidió dos cosas: (1) que cómo funcionan el motor y los addons (Qwen Code, Goose) quede en una base de conocimiento, porque de eso depende cómo se interactúa con ellos; (2) un archivo con instrucciones iniciales que permita arrancar de forma esquemática y efectiva desde el principio, según el tipo de proyecto.

- Se creó `docs/como-funcionan-los-agentes.md`: ciclo de vida de una sesión (contexto vacío → carga de archivos persistentes → tarea → actualización de memoria), tabla de qué archivo lee cada herramienta (`AGENTS.md`, `QWEN.md`, `.goosehints`, `.continue/rules`, memoria automática de Qwen Code), y explicación de MCP/SubAgents/Skills/extensiones.
- **Hallazgo verificado que simplificó todo:** `AGENTS.md` es un archivo que **Goose lee por defecto** (confirmado en `goose-docs.ai`: `CONTEXT_FILE_NAMES` por defecto es `["AGENTS.md", ".goosehints"]`) **y Qwen Code también lee automáticamente** si existe — un solo archivo sirve para ambas herramientas, sin duplicar instrucciones en formatos separados.
- Se creó `AGENTS.md` en la raíz de este repo — instrucciones reales (no genéricas): decisiones ya cerradas, convenciones (incluyendo la de no narrar autocrítica en `decisiones.md`, aplicando la corrección de un par de turnos atrás), restricciones duras del equipo, y qué revisar antes de proponer algo nuevo.
- Se propagó la plantilla genérica a `ia-local/plantillas/AGENTS.md` (adaptable según tipo de proyecto: scripts, investigación, caso de negocio, desarrollo de software) y se documentó en `ia-local/docs/arquitectura.md`.

## 2026-08-27 (mismo día) — Corrección: la fila de memoria persistente había quedado desactualizada tras confirmar Auto-memory

Al revisar el estado general del proyecto se detectó que la tabla resumen de `arquitectura-piloto.md` y la sección de memoria de `herramientas-trabajo.md` seguían describiendo un plan de dos niveles ("reglas estáticas ahora, Mem0 como escalamiento futuro") que quedó superado por el hallazgo de Auto-memory documentado en la entrada anterior.

- Se actualizó `arquitectura-piloto.md` (tabla y diagrama del stack) y `herramientas-trabajo.md` (sección "Memoria persistente") para reflejar que Auto-memory de Qwen Code es la solución de fábrica, `AGENTS.md`/reglas estáticas quedan como respaldo legible por humanos y para Continue.dev/Aider, y Mem0 sigue descartado — ahora por dar memoria compartida entre herramientas, no por falta de una alternativa automática.
- Se corrigió la misma referencia en `README.md`.
