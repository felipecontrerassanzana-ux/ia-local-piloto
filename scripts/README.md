# Scripts de instalación, configuración y verificación

Cada script `.ps1` tiene un lanzador `.bat` con el mismo nombre — **correr el `.bat`, no el `.ps1` directo**. El `.bat` pide permisos de administrador (UAC) automáticamente y llama al `.ps1` correspondiente con la política de ejecución correcta.

No hay que cambiar la política de ejecución de PowerShell del sistema — los `.bat` ya la pasan por alto (`-ExecutionPolicy Bypass`) solo para esa ejecución puntual.

## `instalar-todo.bat` — instalador único con interfaz gráfica (2026-08-27, recomendado)

Corrida manual, uno por uno, de 17 scripts en el orden numérico de archivo **no funciona** — el orden real de dependencias no coincide con la numeración (ej. `07` necesita `12` instalado primero, aunque el número diga lo contrario). `instalar-todo.bat` resuelve esto: una ventana (WPF nativo de Windows, sin Python) que corre los pasos automatizables **en el orden real**, verifica cada uno antes de seguir al siguiente, y se detiene con un error claro si algo no queda bien — no sigue a ciegas.

- Pide la letra del NVMe y la carpeta de backup de Drive una sola vez, al principio.
- Los pasos que necesitan login/token (Cloudflare, Tailscale) quedan **deliberadamente al final**, listados con instrucciones — no pausan la instalación automática.
- **Nota honesta:** mientras corre un paso largo (una descarga, una instalación), Windows puede marcar la ventana como "No responde" — es esperable (cada paso corre directo, sin hilo aparte, para minimizar riesgo de bugs de concurrencia sin poder probarlos antes en el equipo real), no es que se colgó. Ver `../docs/04-instalacion/02-aprendizaje-scripts.md` para el porqué de esta decisión.
- Verificado hasta donde se pudo sin una sesión interactiva real: sintaxis correcta, el XAML carga como ventana WPF de verdad y los 9 controles se resuelven por nombre — el flujo completo (correr los pasos de verdad) todavía no se probó en el equipo real del piloto.
- Los 17 scripts individuales de abajo **siguen existiendo y funcionando igual** — el instalador los reutiliza tal cual, no los reemplaza. Sirven para correr un paso puntual de nuevo, o si se prefiere no usar la GUI.

## Orden de ejecución manual, paso a paso (si no se usa `instalar-todo.bat` — sigue `../docs/04-instalacion/01-plan-instalacion.md`)

Los pasos numerados (00 a 16) viven en **`scripts/pasos/`** (ej. `pasos\00-verificar-equipo.bat`) — son los módulos que `instalar-todo.bat` orquesta, y también se pueden correr sueltos desde ahí. Lo que queda en `scripts/` (esta carpeta) son las herramientas que se corren directo: el instalador, el verificador de salud, y las de mantenimiento del repo mismo.

| # | Script (en `pasos/`) | Qué hace | Necesita algo tuyo antes de correr |
|---|---|---|---|
| 00 | `00-verificar-equipo.bat` | Reporta SO, GPU, drivers, discos, RAM — no cambia nada | No |
| 01 | `01-instalar-ollama.bat` | Instala Ollama vía winget | No |
| 02 | `02-configurar-ollama.bat` | Configura contexto largo y mueve modelos al **NVMe** (corregido 2026-08-27, ver `../docs/01-arquitectura/04-almacenamiento.md`). Con `-PermitirRed`, además pone `OLLAMA_HOST=0.0.0.0` (necesario para conectar Qwen Code/Goose remotos, ver script 14) | Confirmar la letra del NVMe (te la pide al correrlo) |
| 03 | `03-descargar-modelo.bat` | Descarga Qwen 2.5 Coder 7B (Q4 y Q8_0), BGE-M3 y `qwen3-vl:4b` (revisor visual de diseño) | No (correr después del 02) |
| 04 | `04-instalar-goose.bat` | Instala Goose CLI | No |
| 05 | `05-instalar-docker.bat` | **Opcional/respaldo** — instala Docker Desktop solo si algo nativo (06/07) da problemas. Ver `../docs/01-arquitectura/03-docker-y-recursos.md` | No, y normalmente no hace falta |
| 06 | `06-desplegar-qdrant.bat` | Levanta Qdrant **nativo** (binario oficial de Windows, sin Docker) | No |
| 07 | `07-desplegar-openwebui.bat` | Levanta Open WebUI **nativo** (vía pip, sin Docker) — puerto 8080 | No (requiere Python del paso 12) |
| 08 | `08-instalar-cloudflared.bat` | Instala cloudflared como servicio | **Sí** — el token del túnel, creado a mano en el dashboard de Cloudflare (instrucciones dentro del script) |
| 09 | `09-configurar-inicio-automatico.bat` | Verifica/ajusta que todo arranque solo con Windows | No (correr al final, después de 01-08) |
| 10 | `10-configurar-backup.bat` | Crea la tarea programada de backup a Drive | **Sí** — la ruta de tu carpeta de Google Drive |
| 11 | `11-prueba-estres.bat` | Mide rendimiento real (tok/s, carga sostenida, límite de contexto) — ver `../docs/05-pruebas/02-pruebas-rendimiento.md` | No (correr al final, con todo ya instalado) |
| 12 | `12-instalar-herramientas-dev.bat` | Instala git, GitHub CLI (`gh`) y Python — para que Goose/Continue.dev/Aider puedan comitear a GitHub igual que se hace en esta conversación. Ver `../docs/03-herramientas/01-herramientas-trabajo.md` § "Conectores a GitHub" | No (pero después hay que correr `gh auth login` a mano, es interactivo) |
| 13 | `13-instalar-qwen-code.bat` | Instala Node.js + Qwen Code (el agente hecho por el propio equipo de Qwen) y configura el proveedor apuntando al Ollama local | No — instala Node.js si falta, y deja `settings.json` ya configurado |
| 14 | `14-instalar-tailscale.bat` | Instala Tailscale — red privada para conectar Qwen Code/Goose desde un dispositivo remoto sin exponer nada a internet. Ver `../docs/03-herramientas/02-qwen-code-a-fondo.md` | **Sí** — el login (`tailscale up`) es interactivo, abre el navegador para autenticar |
| 15 | `15-instalar-comfyui.bat` | Instala ComfyUI (portable) + checkpoint de Stable Diffusion 1.5 — generador de assets para la capa de diseño. **No** se registra como inicio automático a propósito (protege la VRAM del modelo de código). Ver `../docs/01-arquitectura/02-capa-diseno.md` | No |
| 16 | `16-instalar-monitor-estado.bat` | Registra el "Monitor de estado" — servidor HTTP liviano (`monitor-estado-servidor.ps1`, sin dependencias nuevas) con un dashboard en tiempo real (`http://localhost:8090/`) y un JSON de estado (`http://localhost:8090/estado`), alcanzable también por Tailscale. Ver `../docs/06-operacion/03-monitor-estado.md` | No (opcional: agregar el dominio público en Cloudflare después, ver ese doc) |

## Herramientas de esta carpeta (`scripts/`, top-level — no viven en `pasos/`)

| Script | Qué hace |
|---|---|
| `instalar-todo.bat` | Instalador único con GUI — ver arriba. |
| `verificar-instalacion.bat` | Chequeo integral de salud, se puede correr las veces que se quiera. |
| `_verificar-sintaxis.bat` | Control de calidad de los scripts mismos (sintaxis, codificación, linter) — escanea recursivamente esta carpeta y `pasos/`. **Sin instalar ni ejecutar nada de su contenido.** No pide administrador. Correr después de editar cualquier script. |
| `instalar-git-hooks.sh` | Instala el hook de pre-commit una vez por copia local del repo. |
| `bitacora-horas.bat` | Genera `../logs/bitacora-horas.html` — cuánto tiempo activo real (y tokens) se trabajó en cada proyecto, día por día, a partir de los logs de sesión de Claude Code de esta cuenta de Windows — y **abre el resultado solo en el navegador predeterminado** al terminar (la ventana se cierra sola si todo salió bien; queda abierta con el error si algo falló). Servido también en `http://localhost:8090/bitacora` una vez generado (ver `../docs/06-operacion/03-monitor-estado.md`). Necesita `bitacora-proyectos.json` (copiar de `.example.json` y completar con tus propios proyectos — queda fuera de git). |

**Antes de correr nada, leer `../docs/04-instalacion/02-aprendizaje-scripts.md`** — explica qué hace cada script y por qué, para que esto sea parte de entender el proyecto, no solo ejecutarlo.

**Control de calidad ya aplicado (2026-08-26/27):** todos los scripts pasaron por `_verificar-sintaxis.bat` antes de subirse — se encontró y corrigió un bug real (detección de tipo de disco en `00-verificar-equipo.ps1`), un problema de codificación (faltaba BOM UTF-8), y un tercero más sutil: el propio `_verificar-sintaxis.ps1` fallaba en silencio al correr vía `powershell.exe` (el intérprete real que usan los `.bat`, distinto de pwsh 7) porque el proveedor NuGet no estaba bootstrapeado — corregido, y ahora avisa en vez de fallar en silencio. `instalar-todo.ps1` pasó por el mismo control, más una verificación adicional del XAML (XML válido, carga como ventana WPF real, controles resueltos por nombre) — el parser de sintaxis no valida XAML por sí solo. Detalle completo en `../docs/04-instalacion/02-aprendizaje-scripts.md`.

**Hook de git instalado:** `.git/hooks/pre-commit` corre `_verificar-sintaxis.ps1` automáticamente en cada commit que toque un `.ps1`, y bloquea el commit si encuentra errores reales — instalado con `bash scripts/instalar-git-hooks.sh` (correr una vez por cada copia local del repo, git no versiona los hooks). Probado en vivo: bloquea scripts rotos, deja pasar commits válidos.

## Qué NO automatizan estos scripts (pasos manuales, no evitables)

- **BIOS:** "Restore on AC Power Loss" se configura en la BIOS/UEFI, no desde Windows — ningún script puede tocarlo. Instrucciones en `pasos/09-configurar-inicio-automatico.ps1` y `../docs/06-operacion/01-mantenimiento.md`.
- **Crear el túnel de Cloudflare y el correo autorizado en Cloudflare Access:** son pasos en el dashboard web de Cloudflare, específicos de tu cuenta — no automatizables desde un script local.
- **Crear la primera cuenta de Open WebUI:** paso manual único (entrar a `http://localhost:8080` y registrarse) — automatizarlo no tendría sentido, es tu cuenta de administrador.
- **Continue.dev y `.continue/rules`:** se instala desde el marketplace de VS Code, no por script.

## Logs

Todos los scripts que generan reportes o logs los guardan en `../logs/` (carpeta ignorada por git, ver `.gitignore` — son datos locales, no documentación del proyecto).
