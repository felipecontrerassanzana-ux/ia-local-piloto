# Scripts de instalación, configuración y verificación

Cada script `.ps1` tiene un lanzador `.bat` con el mismo nombre — **correr el `.bat`, no el `.ps1` directo**. El `.bat` pide permisos de administrador (UAC) automáticamente y llama al `.ps1` correspondiente con la política de ejecución correcta.

No hay que cambiar la política de ejecución de PowerShell del sistema — los `.bat` ya la pasan por alto (`-ExecutionPolicy Bypass`) solo para esa ejecución puntual.

## Orden de ejecución (sigue `../docs/plan-instalacion.md`)

| # | Script | Qué hace | Necesita algo tuyo antes de correr |
|---|---|---|---|
| 00 | `00-verificar-equipo.bat` | Reporta SO, GPU, drivers, discos, RAM — no cambia nada | No |
| 01 | `01-instalar-ollama.bat` | Instala Ollama vía winget | No |
| 02 | `02-configurar-ollama.bat` | Configura contexto largo y mueve modelos al HDD | Confirmar la letra del HDD (te la pide al correrlo) |
| 03 | `03-descargar-modelo.bat` | Descarga Qwen 2.5 Coder 7B (Q4 y Q8_0) | No (correr después del 02) |
| 04 | `04-instalar-goose.bat` | Instala Goose CLI | No |
| 05 | `05-instalar-docker.bat` | Instala Docker Desktop | No |
| 06 | `06-desplegar-qdrant.bat` | Levanta Qdrant (RAG) | No (correr después del 05) |
| 07 | `07-desplegar-openwebui.bat` | Levanta Open WebUI | No (correr después del 05) |
| 08 | `08-instalar-cloudflared.bat` | Instala cloudflared como servicio | **Sí** — el token del túnel, creado a mano en el dashboard de Cloudflare (instrucciones dentro del script) |
| 09 | `09-configurar-inicio-automatico.bat` | Verifica/ajusta que todo arranque solo con Windows | No (correr al final, después de 01-08) |
| 10 | `10-configurar-backup.bat` | Crea la tarea programada de backup a Drive | **Sí** — la ruta de tu carpeta de Google Drive |
| — | `verificar-instalacion.bat` | Chequeo integral, se puede correr las veces que se quiera | No |

## Qué NO automatizan estos scripts (pasos manuales, no evitables)

- **BIOS:** "Restore on AC Power Loss" se configura en la BIOS/UEFI, no desde Windows — ningún script puede tocarlo. Instrucciones en `09-configurar-inicio-automatico.ps1` y `../docs/mantenimiento.md`.
- **Crear el túnel de Cloudflare y el correo autorizado en Cloudflare Access:** son pasos en el dashboard web de Cloudflare, específicos de tu cuenta — no automatizables desde un script local.
- **Crear la primera cuenta de Open WebUI:** paso manual único (entrar a `http://localhost:3000` y registrarse) — automatizarlo no tendría sentido, es tu cuenta de administrador.
- **Continue.dev y `.continue/rules`:** se instala desde el marketplace de VS Code, no por script.

## Logs

Todos los scripts que generan reportes o logs los guardan en `../logs/` (carpeta ignorada por git, ver `.gitignore` — son datos locales, no documentación del proyecto).
