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

## 03-descargar-modelo — `ollama pull`

Descarga los pesos del modelo desde la biblioteca de Ollama (que a su vez los toma de Hugging Face) a la carpeta configurada en el paso anterior. Se descargan dos versiones (Q4_K_M por defecto y Q8_0) para poder comparar calidad/velocidad reales entre ambas — ver `modelo-elegido.md`.

## 04-instalar-goose — descarga directa + script del proveedor

A diferencia de Ollama, Goose no está en winget — se instala con `Invoke-WebRequest` (el equivalente de PowerShell a `curl`, descarga un archivo desde una URL) para bajar el script oficial de instalación, y después se ejecuta ese script. Es un patrón común en herramientas de código abierto que priorizan tener un solo instalador multiplataforma en vez de mantener paquetes separados para cada gestor.

## 05-instalar-docker — por qué hace falta Docker

Open WebUI y Qdrant no tienen instalador nativo de Windows — se distribuyen como **imágenes de contenedor** (un paquete que incluye el programa y todo lo que necesita para correr, aislado del resto del sistema). Docker Desktop es el programa que sabe ejecutar esos contenedores en Windows. Sin Docker, esos dos pasos no se pueden hacer.

## 05-instalar-docker — el límite de RAM de WSL2 (agregado 2026-08-27)

Además de instalar Docker Desktop, este script crea `%UserProfile%\.wslconfig` con `memory=4GB`. Esto no es un capricho: WSL2 (la máquina virtual Linux sobre la que corre Docker Desktop en Windows) **reserva por defecto el 50% de la RAM total del equipo** — confirmado en la documentación oficial de Microsoft. En un equipo de 16GB, eso son 8GB solo para la capa de Docker, antes de correr una sola imagen. Ver `docker-y-recursos.md` para el presupuesto completo de RAM y por qué esto importa en este equipo específico (compartido, sin margen de sobra).

## 06-desplegar-qdrant y 07-desplegar-openwebui — `docker run` explicado

Ambos scripts usan el mismo patrón de comando, vale la pena entenderlo una vez:

- `--name` le pone un nombre fijo al contenedor (para poder referirse a él después, en vez de un ID random).
- `--memory="1g"` limita cuánta RAM puede usar ese contenedor como máximo — una segunda defensa además del límite de WSL2 de arriba, para que ningún contenedor se coma todo el margen asignado (ver `docker-y-recursos.md`).
- `--restart unless-stopped` es la política de reinicio — le dice a Docker "si este contenedor se cae o el equipo se reinicia, vuelve a levantarlo solo, salvo que alguien lo haya detenido a propósito". Es la pieza que resuelve la continuidad de estos dos servicios (ver `mantenimiento.md`).
- `-p 6333:6333` (o `3000:8080`) conecta un puerto de tu equipo real (izquierda) a un puerto dentro del contenedor (derecha) — así `localhost:3000` en tu navegador llega al Open WebUI que vive aislado dentro del contenedor.
- `-v nombre:/ruta` es un **volumen** — una carpeta que Docker gestiona por fuera del contenedor, para que los datos (la base de datos de Open WebUI, el índice de Qdrant) sobrevivan aunque el contenedor se borre y se vuelva a crear.
- En Open WebUI, `--add-host=host.docker.internal:host-gateway` + `OLLAMA_BASE_URL=http://host.docker.internal:11434` es lo que le permite al contenedor (que vive "aislado") hablarle al Ollama que corre directo en Windows, fuera de cualquier contenedor.

## 08-instalar-cloudflared — servicio de Windows con token

Un **servicio de Windows** es un programa que corre en segundo plano sin necesitar que nadie inicie sesión ni abra una ventana — se administra con `Get-Service`/`Set-Service`, y arranca automáticamente con el sistema si su `StartType` es `Automatic`. `cloudflared service install <token>` no solo instala el programa, también lo registra como uno de estos servicios. El token identifica **cuál túnel específico de tu cuenta de Cloudflare** debe usar — por eso no se puede generar desde el script, viene del dashboard web (ver instrucciones dentro del propio `.ps1`).

## 09-configurar-inicio-automatico — auditoría de continuidad

No instala nada nuevo — revisa que las piezas de los pasos anteriores queden efectivamente configuradas para sobrevivir un reinicio: el `StartType` del servicio de `cloudflared`, si existe una entrada de arranque para Ollama (`Win32_StartupCommand`, otra tabla de WMI), y si Docker Desktop tiene activado "iniciar con Windows" revisando su archivo de configuración interno. Deja además, como texto, el único paso que ningún script puede tocar: la configuración de la BIOS (vive fuera de Windows, antes de que el sistema operativo arranque).

## 10-configurar-backup — Tareas Programadas + volúmenes de Docker

Dos conceptos nuevos acá:

- Los volúmenes de Docker (`open-webui`, `qdrant_storage`) no son carpetas normales que se puedan copiar con `Copy-Item` — viven dentro de la infraestructura interna de Docker (una máquina virtual Linux ligera, WSL2, por debajo). Por eso el backup usa un contenedor temporal de `alpine` (una distribución de Linux muy chica, se descarga en segundos) solo para leer ese volumen y empaquetarlo en un `.tar.gz` (el equivalente Linux de un .zip) hacia la carpeta de Drive — el contenedor se borra solo al terminar (`--rm`).
- Una **Tarea Programada** (`Register-ScheduledTask`) es el mecanismo de Windows para correr algo automáticamente en un horario, sin que nadie lo recuerde — el equivalente de `cron` en Linux. Acá se configura para los domingos a las 3 AM.

## 11-prueba-estres — medición real vía la API de Ollama

Distinto a todos los anteriores: no instala ni configura nada, **mide**. Usa `Invoke-RestMethod` para hablarle directo a la API que Ollama expone en `localhost:11434` (la misma que usan Continue.dev, Goose y Open WebUI por debajo) y lee los campos de rendimiento que el propio Ollama calcula (`eval_count`, `eval_duration`, etc. — documentados oficialmente). Ver `pruebas-rendimiento.md` para el detalle de qué prueba cada parte y cómo interpretar los números.

## 12-instalar-herramientas-dev — git, gh CLI y Python

Mismo patrón que `01-instalar-ollama.ps1` (winget, revisando primero si ya está instalado), pero acá para tres herramientas de propósito general, no específicas de IA: **Git** (control de versiones), **GitHub CLI** (`gh` — permite crear repos, hacer push, abrir Pull Requests desde la terminal, sin abrir el navegador para cada acción), y **Python**. La razón de este script: Goose (con su extensión "Developer", que le da acceso a shell) puede correr `git`/`gh` exactamente igual que se hace en esta conversación — no es una capacidad exclusiva de Claude Code, es que cualquier agente con acceso a una terminal puede usar cualquier programa que esté instalado en ella. Ver `herramientas-trabajo.md` § "Conectores a GitHub" para el detalle completo, incluyendo la extensión nativa de GitHub que tiene Goose vía MCP como alternativa más estructurada.

**Por qué `gh auth login` queda fuera del script:** es un flujo de autenticación OAuth que necesita abrir el navegador y que una persona apruebe el acceso — no hay forma de automatizarlo sin intervención humana, así que el script instala las herramientas y deja ese único paso para hacer a mano.

## 13-instalar-qwen-code — instalación + configuración generada como archivo

Distinto a los scripts anteriores en un punto: además de instalar (Node.js vía winget, Qwen Code vía `npm install -g`, el gestor de paquetes de Node), **genera un archivo de configuración** (`settings.json`) construyendo un objeto en PowerShell (`@{ ... }`, una tabla hash) y convirtiéndolo a JSON con `ConvertTo-Json` — más confiable que escribir el JSON como texto plano, porque PowerShell se encarga de las comillas y el formato correctos. El script revisa primero si ya existe el archivo para no pisar una configuración que la persona ya haya ajustado a mano.

## _verificar-sintaxis — probar los scripts sin instalar nada (control de calidad)

Antes de confiar en cualquiera de los scripts de arriba, este revisa que estén bien escritos **sin ejecutar ni una sola de sus instrucciones reales** (no llama a `winget`, `docker` ni nada que cambie algo):

1. **Parser de PowerShell** (`[System.Management.Automation.Language.Parser]::ParseFile`): PowerShell puede analizar la gramática de un script sin correrlo — igual que un corrector ortográfico no necesita que leas el texto en voz alta para encontrar errores. Esto encuentra llaves/comillas sin cerrar, sintaxis inválida, etc.
2. **Codificación de caracteres:** revisa que cada archivo tenga BOM UTF-8 (los primeros 3 bytes del archivo, `EF BB BF`) — el marcador que le dice a `powershell.exe` (la versión clásica de Windows, la que usan los `.bat`) que el archivo es UTF-8. **Esto no era solo una formalidad:** se probó en este equipo y, sin BOM, el mismo texto con tildes se ve así al ejecutarlo: `funciÃ³n, configuraciÃ³n` en vez de `función, configuración` — un bug real que habría afectado a los 14 scripts.
3. **PSScriptAnalyzer:** el linter oficial de PowerShell (mismo tipo de herramienta que ESLint para JavaScript) — revisa patrones que suelen esconder errores reales, no solo estilo. Así se encontró que `00-verificar-equipo.ps1` calculaba el tipo de disco (SSD/HDD) con una consulta que no lo relacionaba con la unidad correcta, y encima nunca llegaba a mostrarse en el reporte — quedaba calculado y descartado. Se corrigió correlacionando la letra de unidad → partición → disco → disco físico, y se verificó en vivo que da el resultado correcto.

**Cómo correrlo:** `_verificar-sintaxis.bat` — a diferencia de todos los demás, **no pide permisos de administrador**, porque solo lee y analiza texto. Correrlo después de cualquier cambio a un script, antes de confiar en que funciona.

## verificar-instalacion — chequeo de salud, sin cambiar nada

Repite muchas de las mismas consultas que los scripts de instalación (¿existe el comando?, ¿responde el servicio?, ¿está el contenedor corriendo?) pero solo para reportar, nunca para corregir — la idea es poder correrlo las veces que se quiera, en cualquier momento, sin riesgo de romper algo, para saber de un vistazo qué falta.
