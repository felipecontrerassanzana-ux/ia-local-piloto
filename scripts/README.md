# Scripts de instalación, configuración y verificación

Cada script `.ps1` tiene un lanzador `.bat` con el mismo nombre — **correr el `.bat`, no el `.ps1` directo**. El `.bat` pide permisos de administrador (UAC) automáticamente y llama al `.ps1` correspondiente con la política de ejecución correcta.

No hay que cambiar la política de ejecución de PowerShell del sistema — los `.bat` ya la pasan por alto (`-ExecutionPolicy Bypass`) solo para esa ejecución puntual.

## Orden de ejecución (sigue `../docs/plan-instalacion.md`)

| # | Script | Qué hace | Necesita algo tuyo antes de correr |
|---|---|---|---|
| 00 | `00-verificar-equipo.bat` | Reporta SO, GPU, drivers, discos, RAM — no cambia nada | No |
| 01 | `01-instalar-ollama.bat` | Instala Ollama vía winget | No |
| 02 | `02-configurar-ollama.bat` | Configura contexto largo y mueve modelos al HDD. Con `-PermitirRed`, además pone `OLLAMA_HOST=0.0.0.0` (necesario para conectar Qwen Code/Goose remotos, ver script 14) | Confirmar la letra del HDD (te la pide al correrlo) |
| 03 | `03-descargar-modelo.bat` | Descarga Qwen 2.5 Coder 7B (Q4 y Q8_0) | No (correr después del 02) |
| 04 | `04-instalar-goose.bat` | Instala Goose CLI | No |
| 05 | `05-instalar-docker.bat` | **Opcional/respaldo** — instala Docker Desktop solo si algo nativo (06/07) da problemas. Ver `../docs/docker-y-recursos.md` | No, y normalmente no hace falta |
| 06 | `06-desplegar-qdrant.bat` | Levanta Qdrant **nativo** (binario oficial de Windows, sin Docker) | No |
| 07 | `07-desplegar-openwebui.bat` | Levanta Open WebUI **nativo** (vía pip, sin Docker) — puerto 8080 | No (requiere Python del paso 12) |
| 08 | `08-instalar-cloudflared.bat` | Instala cloudflared como servicio | **Sí** — el token del túnel, creado a mano en el dashboard de Cloudflare (instrucciones dentro del script) |
| 09 | `09-configurar-inicio-automatico.bat` | Verifica/ajusta que todo arranque solo con Windows | No (correr al final, después de 01-08) |
| 10 | `10-configurar-backup.bat` | Crea la tarea programada de backup a Drive | **Sí** — la ruta de tu carpeta de Google Drive |
| — | `verificar-instalacion.bat` | Chequeo integral, se puede correr las veces que se quiera | No |
| 11 | `11-prueba-estres.bat` | Mide rendimiento real (tok/s, carga sostenida, límite de contexto) — ver `../docs/pruebas-rendimiento.md` | No (correr al final, con todo ya instalado) |
| 12 | `12-instalar-herramientas-dev.bat` | Instala git, GitHub CLI (`gh`) y Python — para que Goose/Continue.dev/Aider puedan comitear a GitHub igual que se hace en esta conversación. Ver `../docs/herramientas-trabajo.md` § "Conectores a GitHub" | No (pero después hay que correr `gh auth login` a mano, es interactivo) |
| 13 | `13-instalar-qwen-code.bat` | Instala Node.js + Qwen Code (el agente hecho por el propio equipo de Qwen) y configura el proveedor apuntando al Ollama local | No — instala Node.js si falta, y deja `settings.json` ya configurado |
| 14 | `14-instalar-tailscale.bat` | Instala Tailscale — red privada para conectar Qwen Code/Goose desde un dispositivo remoto sin exponer nada a internet. Ver `../docs/qwen-code-a-fondo.md` | **Sí** — el login (`tailscale up`) es interactivo, abre el navegador para autenticar |
| — | `_verificar-sintaxis.bat` | Control de calidad de los scripts mismos — sintaxis, codificación, linter — **sin instalar ni ejecutar nada de su contenido**. No pide administrador. Correr después de editar cualquier script. | No |

**Antes de correr nada, leer `../docs/aprendizaje-scripts.md`** — explica qué hace cada script y por qué, para que esto sea parte de entender el proyecto, no solo ejecutarlo.

**Control de calidad ya aplicado (2026-08-26/27):** todos los scripts pasaron por `_verificar-sintaxis.bat` antes de subirse — se encontró y corrigió un bug real (detección de tipo de disco en `00-verificar-equipo.ps1`), un problema de codificación (faltaba BOM UTF-8), y un tercero más sutil: el propio `_verificar-sintaxis.ps1` fallaba en silencio al correr vía `powershell.exe` (el intérprete real que usan los `.bat`, distinto de pwsh 7) porque el proveedor NuGet no estaba bootstrapeado — corregido, y ahora avisa en vez de fallar en silencio. Detalle completo en `../docs/aprendizaje-scripts.md`.

**Hook de git instalado:** `.git/hooks/pre-commit` corre `_verificar-sintaxis.ps1` automáticamente en cada commit que toque un `.ps1`, y bloquea el commit si encuentra errores reales — instalado con `bash scripts/instalar-git-hooks.sh` (correr una vez por cada copia local del repo, git no versiona los hooks). Probado en vivo: bloquea scripts rotos, deja pasar commits válidos.

## Qué NO automatizan estos scripts (pasos manuales, no evitables)

- **BIOS:** "Restore on AC Power Loss" se configura en la BIOS/UEFI, no desde Windows — ningún script puede tocarlo. Instrucciones en `09-configurar-inicio-automatico.ps1` y `../docs/mantenimiento.md`.
- **Crear el túnel de Cloudflare y el correo autorizado en Cloudflare Access:** son pasos en el dashboard web de Cloudflare, específicos de tu cuenta — no automatizables desde un script local.
- **Crear la primera cuenta de Open WebUI:** paso manual único (entrar a `http://localhost:8080` y registrarse) — automatizarlo no tendría sentido, es tu cuenta de administrador.
- **Continue.dev y `.continue/rules`:** se instala desde el marketplace de VS Code, no por script.

## Logs

Todos los scripts que generan reportes o logs los guardan en `../logs/` (carpeta ignorada por git, ver `.gitignore` — son datos locales, no documentación del proyecto).
