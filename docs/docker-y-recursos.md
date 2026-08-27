# Por qué este piloto no usa Docker (y el presupuesto real de RAM, 16GB)

**Actualizado 2026-08-27 — cambio de recomendación respecto a la versión anterior de este documento.** La primera versión asumía Docker como la única forma de correr Open WebUI y Qdrant en Windows. Al verificar en profundidad, ambos tienen una forma **nativa oficial** de correr en Windows sin Docker — y en un equipo de 16GB de RAM compartidos, evitar la capa de Docker Desktop/WSL2 por completo es mejor que solo limitarla.

## Qué va nativo y qué no — fundamentación completa

| Pieza | ¿Cómo corre? | Por qué |
|---|---|---|
| Ollama | Nativo en Windows | Habla directo con el driver de NVIDIA, sin pasar la GPU a través de WSL2. |
| Goose, Continue.dev, Qwen Code, Aider | Nativos / extensión de VS Code | Necesitan tocar tu sistema de archivos y tu editor directamente. |
| cloudflared | Servicio nativo de Windows | Arranca directo con Windows, sin depender de que otra capa (Docker) esté arriba primero. |
| **Qdrant** | **Nativo — binario oficial de Windows** | Verificado en `github.com/qdrant/qdrant/releases` (2026-08-27): cada release publica `qdrant-x86_64-pc-windows-msvc.zip`, una build real para Windows, no un contenedor. Se descarga, se descomprime, y se corre `qdrant.exe` directo. |
| **Open WebUI** | **Nativo — vía pip** | Verificado en la documentación oficial (`docs.openwebui.com`, 2026-08-27): *"Python: Suitable for low-resource environments or manual setups"* — es un método de instalación oficialmente soportado, no un atajo no documentado. `pip install open-webui` + `open-webui serve`. |

**Con esto, Docker Desktop no es necesario para nada en este piloto.** Queda documentado como opción de respaldo (`05-instalar-docker.ps1`, ahora marcado opcional) por si la instalación nativa de alguna pieza da problemas en la práctica — pero ya no es el camino por defecto.

## Cómo quedan corriendo Qdrant y Open WebUI sin Docker

Ninguno de los dos tiene un instalador de servicio de Windows oficial, así que se usa el mismo mecanismo que ya se usaba para el backup (`10-configurar-backup.ps1`): una **Tarea Programada** con disparador "al iniciar el sistema", corriendo como usuario `SYSTEM` (no necesita sesión iniciada) y con reintento automático si el proceso falla (3 intentos, cada 1 minuto — mitigación razonable sin sumar una herramienta nueva como NSSM).

- **Qdrant:** tarea `Qdrant-Local`, instalado en `C:\QdrantLocal\`, datos en `C:\QdrantLocal\storage`, puertos 6333 (REST + panel `/dashboard`) y 6334 (gRPC) — igual que en Docker, esos puertos no cambiaron.
- **Open WebUI:** tarea `OpenWebUI-Local`, datos en `C:\OpenWebUIData\` (variable de entorno `DATA_DIR`), puerto **8080** (no 3000 — ese remapeo de puerto era específico del `docker run`, nativo usa su puerto por defecto).
- **Conexión entre ellos y con Ollama:** al ser todo nativo en el mismo Windows, todo se habla por `localhost` normal — ya no hace falta `host.docker.internal` ni redes de Docker, eso solo existía para que un contenedor aislado alcanzara al resto del sistema.

## El problema que motivó todo esto: RAM, no VRAM

La VRAM (12GB) ya está bien presupuestada (Qwen 2.5 Coder Q8_0 7,5GB + BGE-M3 1,2GB, vía Ollama = 8,7GB, deja ~3,3GB de margen). **La RAM del sistema (16GB, compartida con otro uso) es la restricción real.**

**Hallazgo que originó el cambio (verificado en `learn.microsoft.com/windows/wsl/wsl-config`):** WSL2 — la base de Docker Desktop en Windows — reserva **por defecto el 50% de la RAM total** (8GB en este equipo) solo para existir, antes de correr una sola imagen. Evitar Docker por completo elimina ese costo de raíz, en vez de solo limitarlo con `.wslconfig`.

### Presupuesto estimado, con todo nativo (sin Docker)

| Componente | RAM estimada |
|---|---|
| Windows 11 en reposo | ~3GB |
| Ollama (proceso; los pesos van en VRAM, no acá) | ~1GB |
| Qdrant nativo | ~0,3-0,5GB (crece con el tamaño del índice) |
| Open WebUI nativo (proceso Python) | ~0,5-0,8GB |
| VS Code + una herramienta de código activa | ~1,5GB |
| **Total aproximado** | **~7-8GB de 16GB — ~8GB de margen real** |

Comparado con la versión anterior de este documento (que estimaba ~9,5GB con Docker ya limitado a 4GB de WSL2), esto libera varios GB adicionales — margen real para el otro uso que comparte este equipo, sin depender de que WSL2 respete el límite configurado.

## Si en la práctica algo nativo falla — plan B documentado

Si `qdrant.exe` o `open-webui serve` dan problemas reales en este equipo (drivers, permisos, lo que sea), `05-instalar-docker.ps1` sigue disponible como respaldo — instala Docker Desktop y deja `.wslconfig` limitado a 4GB automáticamente (no al 50% por defecto). No es la primera opción, pero está probado y documentado por si hace falta.

## Próximos pasos

- [x] Verificar que Qdrant y Open WebUI tienen build/instalación nativa real para Windows — confirmado 2026-08-27.
- [x] Reescribir `06-desplegar-qdrant.ps1` y `07-desplegar-openwebui.ps1` para instalar nativo con Tareas Programadas.
- [x] Simplificar `10-configurar-backup.ps1` (copiar carpetas normales, ya no hace falta el truco del contenedor Alpine para leer volúmenes Docker).
- [ ] Una vez instalado, medir el uso real de RAM (Administrador de tareas) y corregir esta tabla con datos reales.
