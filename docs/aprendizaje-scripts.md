# Aprendizaje: qué hace cada script y por qué

El objetivo de este proyecto no es solo llegar a tener el piloto funcionando — es entender cómo se armó, igual que con la elección del modelo (`fundamentacion-modelo.md`). Este documento explica cada script línea por línea en concepto, no solo qué comando correr. Si en algún momento hay que tocar algo a mano o algo falla, esto debería ser suficiente para entender qué se rompió.

## El patrón común: `.bat` + `.ps1` + auto-elevación

Todos los scripts siguen la misma estructura de dos archivos:

- **El `.bat`** es el que se ejecuta con doble clic. Su único trabajo es: (1) revisar si ya está corriendo con permisos de administrador (`net session` falla si no lo está), (2) si no lo está, volver a lanzarse a sí mismo pidiendo elevación vía UAC (`Start-Process ... -Verb RunAs` — esto es lo que hace aparecer el cuadro de "¿Permitir que esta app haga cambios?"), y (3) llamar al `.ps1` del mismo nombre.
- **El `.ps1`** (PowerShell) es donde vive la lógica real. `-ExecutionPolicy Bypass` al llamarlo evita el bloqueo por defecto de Windows a scripts no firmados, solo para esa ejecución puntual — no cambia la configuración general del sistema.
- **`_elevar.ps1`** es un archivo compartido que todos los `.ps1` cargan al principio (`. "$PSScriptRoot\_elevar.ps1"`) — vuelve a chequear que hay permisos de administrador, por si alguien corre el `.ps1` directo sin pasar por el `.bat`. El punto (`.`) antes de la ruta es "dot sourcing": ejecuta el script en el mismo contexto, no en uno aparte, para que sus variables queden disponibles.

**Por qué hace falta administrador para casi todo:** instalar programas (`winget`), crear variables de entorno a nivel de sistema (no solo de tu usuario), registrar servicios de Windows, y crear tareas programadas, todas son operaciones que Windows reserva para cuentas administrativas.

## 00-verificar-equipo — inventario, no instala nada

Usa cmdlets de PowerShell que consultan **WMI/CIM** (Windows Management Instrumentation — la base de datos interna de Windows sobre el propio hardware): `Get-CimInstance Win32_OperatingSystem`, `Win32_Processor`, `Win32_VideoController`. Es la misma información que ves en el Administrador de tareas, pero en formato que un script puede leer. También corre `nvidia-smi` si existe (la herramienta de línea de comandos que instalan los drivers de NVIDIA) para leer el estado real de la GPU. Todo lo que averigua queda en un archivo de texto con fecha, en `logs/`, para poder comparar más adelante ("¿tenía menos espacio libre hace un mes?").

## 01-instalar-ollama — instalación vía winget

`winget` es el gestor de paquetes que trae Windows 11 (equivalente a `apt` en Linux o `brew` en Mac) — permite instalar programas por línea de comandos desde un catálogo verificado por Microsoft, sin tener que buscar y descargar un instalador a mano. El script primero revisa si el comando `ollama` ya existe (`Get-Command`) para no reinstalar de más.

## 02-configurar-ollama — variables de entorno de sistema

Este es el paso conceptualmente más importante de entender. Una **variable de entorno** es un valor que el sistema operativo guarda y que cualquier programa puede leer al arrancar — Ollama lee `OLLAMA_MODELS` y `OLLAMA_CONTEXT_LENGTH` de ahí, no de un archivo de configuración propio. `[Environment]::SetEnvironmentVariable(..., "Machine")` las crea a **nivel de sistema** (no solo para tu usuario) — el `"Machine"` es la parte clave, sin eso quedaría solo para la sesión de tu cuenta. Por eso hay que **reiniciar Ollama** después: un programa lee sus variables de entorno una sola vez, al arrancar, no las vuelve a consultar mientras corre.

**El switch `-PermitirRed` (agregado 2026-08-27):** por defecto Ollama solo escucha conexiones que vienen de sí mismo (`localhost`) — ni siquiera otro dispositivo de la misma red de casa puede alcanzarlo. `OLLAMA_HOST=0.0.0.0` es lo que le dice "escucha en todas las interfaces de red, no solo en la interna" — el mismo mecanismo que hace posible el Escenario B (otro equipo de la casa) y, junto con Tailscale, el Escenario C1 (remoto) de `qwen-code-a-fondo.md`. Queda **desactivado por defecto** (no pasar el switch = seguir como estaba) porque ampliar quién puede alcanzar el servidor es una decisión que vale la pena tomar a propósito, no como default de un script de configuración general.

## 03-descargar-modelo — `ollama pull`

Descarga los pesos del modelo desde la biblioteca de Ollama (que a su vez los toma de Hugging Face) a la carpeta configurada en el paso anterior. Se descargan dos versiones (Q4_K_M por defecto y Q8_0) para poder comparar calidad/velocidad reales entre ambas — ver `modelo-elegido.md`.

## 04-instalar-goose — descarga directa + script del proveedor

A diferencia de Ollama, Goose no está en winget — se instala con `Invoke-WebRequest` (el equivalente de PowerShell a `curl`, descarga un archivo desde una URL) para bajar el script oficial de instalación, y después se ejecuta ese script. Es un patrón común en herramientas de código abierto que priorizan tener un solo instalador multiplataforma en vez de mantener paquetes separados para cada gestor.

## 05-instalar-docker — respaldo opcional, no el camino por defecto (revisado 2026-08-27)

Este script instalaba Docker Desktop porque en un principio parecía la única forma de correr Open WebUI y Qdrant en Windows. Al verificar en profundidad (`docker-y-recursos.md`) resultó que **ambos tienen forma nativa oficial** para Windows — así que este script pasó a ser opcional, solo un respaldo por si la instalación nativa da problemas. Vale la pena entender igual el hallazgo que motivó revisarlo: WSL2 (la máquina virtual Linux sobre la que corre Docker Desktop en Windows) **reserva por defecto el 50% de la RAM total del equipo**, confirmado en la documentación oficial de Microsoft — 8GB de los 16GB de este equipo, solo por existir Docker Desktop, antes de correr una sola imagen. Si de todas formas se usa este script, crea `%UserProfile%\.wslconfig` con `memory=4GB` para no dejar ese 50% por defecto.

## 06-desplegar-qdrant y 07-desplegar-openwebui — instalación nativa, sin contenedores (reescritos 2026-08-27)

Ambos siguen el mismo patrón: descargar el binario/paquete oficial, y dejarlo corriendo con una **Tarea Programada** (no un servicio de Windows real, porque ninguno de los dos trae un instalador de servicio — ver la nota sobre esa diferencia más abajo, en el script 10).

- **Qdrant:** se descarga el ZIP de la última release desde la API de GitHub (`api.github.com/repos/qdrant/qdrant/releases/latest`, buscando el asset que termina en `pc-windows-msvc.zip` — es la build real de Windows, no un contenedor), se descomprime en `C:\QdrantLocal`, y `qdrant.exe` guarda sus datos en una carpeta `storage` al lado, sin nada especial que aprender ahí — es un programa de Windows como cualquier otro.
- **Open WebUI:** `pip install open-webui` (el mismo gestor de paquetes de Python que ya se usa para librerías) y después `open-webui serve` — la variable de entorno `DATA_DIR` le dice dónde guardar sus datos (`C:\OpenWebUIData`), igual que `OLLAMA_MODELS` le dice a Ollama dónde guardar los modelos.
- **La Tarea Programada** en ambos usa un disparador "al iniciar el sistema" (`New-ScheduledTaskTrigger -AtStartup`) y corre como usuario `SYSTEM` — así no depende de que alguien inicie sesión en Windows, igual que el servicio de `cloudflared`. Se le suma un reintento automático (`-RestartCount 3 -RestartInterval ...`) por si el proceso se cae solo — una Tarea Programada, a diferencia de un servicio real de Windows, no reinicia el proceso automáticamente sin decírselo explícitamente.
- **Por qué ya no hace falta `host.docker.internal`:** eso solo existía para que un contenedor Docker "aislado" pudiera alcanzar servicios fuera de sí mismo. Con todo nativo en el mismo Windows, todo se habla por `localhost` normal.

## 08-instalar-cloudflared — servicio de Windows con token

Un **servicio de Windows** es un programa que corre en segundo plano sin necesitar que nadie inicie sesión ni abra una ventana — se administra con `Get-Service`/`Set-Service`, y arranca automáticamente con el sistema si su `StartType` es `Automatic`. `cloudflared service install <token>` no solo instala el programa, también lo registra como uno de estos servicios. El token identifica **cuál túnel específico de tu cuenta de Cloudflare** debe usar — por eso no se puede generar desde el script, viene del dashboard web (ver instrucciones dentro del propio `.ps1`).

## 09-configurar-inicio-automatico — auditoría de continuidad

No instala nada nuevo — revisa que las piezas de los pasos anteriores queden efectivamente configuradas para sobrevivir un reinicio: el `StartType` del servicio de `cloudflared`, si existe una entrada de arranque para Ollama (`Win32_StartupCommand`, otra tabla de WMI), y (desde 2026-08-27) si las Tareas Programadas `Qdrant-Local` y `OpenWebUI-Local` tienen el disparador correcto — revisando el tipo exacto del disparador (`MSFT_TaskBootTrigger`, el nombre interno de "al iniciar el sistema"). Deja además, como texto, el único paso que ningún script puede tocar: la configuración de la BIOS (vive fuera de Windows, antes de que el sistema operativo arranque).

## 10-configurar-backup — Tareas Programadas, y por qué el backup se simplificó

Una **Tarea Programada** (`Register-ScheduledTask`) es el mecanismo de Windows para correr algo automáticamente en un horario, sin que nadie lo recuerde — el equivalente de `cron` en Linux. Acá se configura para los domingos a las 3 AM. Antes de que Qdrant/Open WebUI pasaran a ser nativos, el backup necesitaba un contenedor temporal de `alpine` para leer sus volúmenes de Docker (carpetas especiales que Docker gestiona por dentro de la máquina virtual WSL2, no accesibles directo desde Windows). Con todo nativo, sus datos son carpetas normales de Windows (`C:\QdrantLocal\storage`, `C:\OpenWebUIData`) — el backup se simplificó a `Compress-Archive` (el cmdlet nativo de PowerShell para crear .zip), sin necesitar nada de Docker.

## 11-prueba-estres — medición real vía la API de Ollama

Distinto a todos los anteriores: no instala ni configura nada, **mide**. Usa `Invoke-RestMethod` para hablarle directo a la API que Ollama expone en `localhost:11434` (la misma que usan Continue.dev, Goose y Open WebUI por debajo) y lee los campos de rendimiento que el propio Ollama calcula (`eval_count`, `eval_duration`, etc. — documentados oficialmente). Ver `pruebas-rendimiento.md` para el detalle de qué prueba cada parte y cómo interpretar los números.

## 12-instalar-herramientas-dev — git, gh CLI y Python

Mismo patrón que `01-instalar-ollama.ps1` (winget, revisando primero si ya está instalado), pero acá para tres herramientas de propósito general, no específicas de IA: **Git** (control de versiones), **GitHub CLI** (`gh` — permite crear repos, hacer push, abrir Pull Requests desde la terminal, sin abrir el navegador para cada acción), y **Python**. La razón de este script: Goose (con su extensión "Developer", que le da acceso a shell) puede correr `git`/`gh` exactamente igual que se hace en esta conversación — no es una capacidad exclusiva de Claude Code, es que cualquier agente con acceso a una terminal puede usar cualquier programa que esté instalado en ella. Ver `herramientas-trabajo.md` § "Conectores a GitHub" para el detalle completo, incluyendo la extensión nativa de GitHub que tiene Goose vía MCP como alternativa más estructurada.

**Por qué `gh auth login` queda fuera del script:** es un flujo de autenticación OAuth que necesita abrir el navegador y que una persona apruebe el acceso — no hay forma de automatizarlo sin intervención humana, así que el script instala las herramientas y deja ese único paso para hacer a mano.

## 13-instalar-qwen-code — instalación + configuración generada como archivo

Distinto a los scripts anteriores en un punto: además de instalar (Node.js vía winget, Qwen Code vía `npm install -g`, el gestor de paquetes de Node), **genera un archivo de configuración** (`settings.json`) construyendo un objeto en PowerShell (`@{ ... }`, una tabla hash) y convirtiéndolo a JSON con `ConvertTo-Json` — más confiable que escribir el JSON como texto plano, porque PowerShell se encarga de las comillas y el formato correctos. El script revisa primero si ya existe el archivo para no pisar una configuración que la persona ya haya ajustado a mano.

**`timeout`/`streamIdleTimeoutMs`/`maxRetries` (agregado 2026-08-27, verificado contra el ejemplo oficial de Qwen Code para modelos locales):** un modelo en la nube casi siempre responde rápido porque corre en hardware dedicado grande; un modelo local en este equipo puede demorar más, sobre todo la primera respuesta después de cargar el modelo en la GPU. Sin estos tres valores, Qwen Code usa timeouts pensados para la nube y podría cortar la espera antes de que el modelo local termine de responder — no es un ajuste de rendimiento, es evitar que se corte una respuesta válida solo porque tardó más de lo esperado.

## 14-instalar-tailscale — misma familia que 08, pero login interactivo en vez de token

Instala Tailscale vía winget, igual patrón que `08-instalar-cloudflared` (misma familia: un servicio que crea una red privada/túnel saliente). La diferencia está en cómo se autentica: Cloudflare usa un **token** que se pega una sola vez al correr el script (se genera antes, en el dashboard); Tailscale usa un **login interactivo por navegador** (`tailscale up` abre una URL, uno inicia sesión con su cuenta ahí) — no hay token que copiar y pegar, así que el script no puede completarlo por uno, solo detecta si ya se hizo (`tailscale status`) y avisa si falta. Existe una forma de automatizarlo con una "auth key" generada en el dashboard, pero es una pieza más específica de la cuenta que no se justifica para un uso de un solo equipo.

## 15-instalar-comfyui — un "servicio" que a propósito no se registra como servicio

Distinto de todos los scripts anteriores que instalan un motor (Ollama, Qdrant, Open WebUI, cloudflared): esos sí quedan corriendo en segundo plano, con Tarea Programada e inicio automático. **ComfyUI no** — se instala pero se deja para abrir a mano. La razón es de presupuesto de VRAM, no de descuido: si ComfyUI quedara siempre corriendo con el checkpoint de Stable Diffusion cargado, competiría por VRAM con el modelo de código todo el tiempo, incluso cuando nadie está generando una imagen — rompiendo la regla explícita de este proyecto de no tocar la cuantización del modelo de código para hacerle espacio a otra cosa (ver `capa-diseno.md`).

**Por qué .7z y no .zip:** el paquete portable de ComfyUI se distribuye solo en formato `.7z` (más eficiente que `.zip` para archivos grandes) — el script instala 7-Zip vía winget si no está, y lo usa para extraer. Es la misma idea que "instalar una herramienta si falta" que ya se ve en otros scripts (Node.js en `13-instalar-qwen-code.ps1`, por ejemplo), solo que acá la herramienta que falta es un extractor de archivos, no un lenguaje de programación.

**Por qué ComfyUI y no AUTOMATIC1111 (la opción más conocida):** AUTOMATIC1111 exige una versión exacta de Python (3.10.6) porque versiones más nuevas no son compatibles con la librería `torch` que usa por debajo — eso chocaría con el Python 3.12 que ya se instala para el resto del proyecto en `12-instalar-herramientas-dev.ps1`, obligando a mantener dos Pythons distintos en el mismo equipo. ComfyUI resuelve esto trayendo su propio Python empaquetado dentro del `.7z` — no depende del Python que ya esté instalado en el sistema.

## _verificar-sintaxis — probar los scripts sin instalar nada (control de calidad)

Antes de confiar en cualquiera de los scripts de arriba, este revisa que estén bien escritos **sin ejecutar ni una sola de sus instrucciones reales** (no llama a `winget`, `docker` ni nada que cambie algo):

1. **Parser de PowerShell** (`[System.Management.Automation.Language.Parser]::ParseFile`): PowerShell puede analizar la gramática de un script sin correrlo — igual que un corrector ortográfico no necesita que leas el texto en voz alta para encontrar errores. Esto encuentra llaves/comillas sin cerrar, sintaxis inválida, etc.
2. **Codificación de caracteres:** revisa que cada archivo tenga BOM UTF-8 (los primeros 3 bytes del archivo, `EF BB BF`) — el marcador que le dice a `powershell.exe` (la versión clásica de Windows, la que usan los `.bat`) que el archivo es UTF-8. **Esto no era solo una formalidad:** se probó en este equipo y, sin BOM, el mismo texto con tildes se ve así al ejecutarlo: `funciÃ³n, configuraciÃ³n` en vez de `función, configuración` — un bug real que habría afectado a los 14 scripts.
3. **PSScriptAnalyzer:** el linter oficial de PowerShell (mismo tipo de herramienta que ESLint para JavaScript) — revisa patrones que suelen esconder errores reales, no solo estilo. Así se encontró que `00-verificar-equipo.ps1` calculaba el tipo de disco (SSD/HDD) con una consulta que no lo relacionaba con la unidad correcta, y encima nunca llegaba a mostrarse en el reporte — quedaba calculado y descartado. Se corrigió correlacionando la letra de unidad → partición → disco → disco físico, y se verificó en vivo que da el resultado correcto.

**Cómo correrlo:** `_verificar-sintaxis.bat` — a diferencia de todos los demás, **no pide permisos de administrador**, porque solo lee y analiza texto. Correrlo después de cualquier cambio a un script, antes de confiar en que funciona.

### El gotcha que solo apareció al probarlo en el camino real (2026-08-27)

Todas las corridas de este script durante el desarrollo se habían probado con **PowerShell 7 (pwsh)** — pero **todos los `.bat` de este proyecto invocan `powershell.exe` (Windows PowerShell 5.1)**, que es un programa distinto con su propia carpeta de módulos separada (`Documents\WindowsPowerShell\Modules`, no `Documents\PowerShell\Modules`). Al probarlo por primera vez en el camino real (vía `powershell.exe`, como lo hace el hook de git de abajo), `Invoke-ScriptAnalyzer` fallaba en silencio con `CouldNotInstallNuGetProvider` — Windows PowerShell 5.1 necesita el proveedor NuGet bootstrapeado antes de poder instalar cualquier módulo, y eso no pasa solo porque pwsh 7 ya lo tenga. El resultado, sin la corrección: el script reportaba **"0 hallazgos de lint"**, que parecía buena noticia pero en realidad significaba que el paso 3 completo nunca corrió. Corregido: el script ahora bootstrapea `NuGet` explícitamente si falta, y si aun así no puede cargar el linter, lo dice en rojo (`[SIN LINTER]`) en vez de reportar silenciosamente "0 hallazgos" como si hubiera revisado algo.

**Lección genérica:** cuando un equipo tiene más de una versión de PowerShell instalada (pwsh 7 y Windows PowerShell 5.1 conviven en Windows 11 normalmente), probar una herramienta en una no garantiza que funcione en la otra — hay que probarla específicamente en el intérprete que realmente la va a ejecutar en producción, no en el que resulte más cómodo para probar.

### Hook de git — de "hay que acordarse de correrlo" a "no se puede comitear sin pasarlo"

`scripts/hooks/pre-commit` (instalado con `scripts/instalar-git-hooks.sh`, una sola vez por copia local del repo — git no versiona `.git/hooks/`) convierte esto de una buena práctica que hay que recordar en algo que la herramienta impone sola: si el commit toca algún `.ps1`, corre `_verificar-sintaxis.ps1` automáticamente y **bloquea el commit** si hay errores de sintaxis o archivos sin BOM (no bloquea por hallazgos de lint, esos incluyen los aceptados a propósito). Probado en vivo con un script deliberadamente roto (bloqueó correctamente) y con un commit real válido (lo dejó pasar). Se puede saltar a propósito con `git commit --no-verify` si hiciera falta.

## verificar-instalacion — chequeo de salud, sin cambiar nada

Repite muchas de las mismas consultas que los scripts de instalación (¿existe el comando?, ¿responde el servicio?, ¿está el contenedor corriendo?) pero solo para reportar, nunca para corregir — la idea es poder correrlo las veces que se quiera, en cualquier momento, sin riesgo de romper algo, para saber de un vistazo qué falta.

**Qwen Code y Tailscale (agregados 2026-08-27):** eran instalables (scripts 13 y 14) pero no se chequeaban acá — un vacío real, no intencional, encontrado al revisar el estado general del proyecto. El de Tailscale además distingue tres estados, no solo sí/no: no instalado, instalado pero sin autenticar, o instalado y conectado (y en ese caso muestra la IP de Tailscale, que es justo el dato que hace falta para configurar Qwen Code en un dispositivo remoto).
