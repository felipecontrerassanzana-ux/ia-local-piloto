# Docker: qué va ahí, cómo se conecta, y el presupuesto real de RAM (16GB)

Este documento junta tres cosas que el usuario pidió dejar explícitas: **por qué** algunas piezas van en Docker y otras no, **cómo** se habilitan e interconectan, y **por qué la RAM (16GB, compartida con otros usos) es la restricción real de este equipo**, no la VRAM.

## Qué va en Docker y qué no — fundamentación

| Pieza | ¿Docker? | Por qué |
|---|---|---|
| Ollama | **No** — nativo en Windows | En Windows, Docker necesita pasar la GPU NVIDIA hacia dentro del contenedor vía WSL2 + NVIDIA Container Toolkit — una capa de más, y una fuente común de fallas ("el contenedor no ve la GPU"). La app nativa habla directo con el driver, sin nada intermedio. |
| Goose, Continue.dev, Qwen Code, Aider | **No** — nativos/extensión de VS Code | Necesitan tocar tu sistema de archivos real y tu editor directamente (crear carpetas, correr comandos de shell en tu equipo) — meterlos en un contenedor los aislaría de lo que necesitan hacer. |
| cloudflared | **No** — servicio nativo de Windows | Arranca directo con Windows. Como contenedor dependería de que Docker Desktop ya esté arriba — una dependencia más en la cadena de arranque automático (ver `mantenimiento.md` §1, no hay UPS, el equipo debe recuperarse solo). |
| Open WebUI | **Sí** | No tiene instalador nativo de Windows — Docker es la opción más simple disponible, no una segunda opción. |
| Qdrant | **Sí** | Mismo caso — sin instalador nativo de Windows. |
| BGE-M3 (embeddings) | **No es necesario un contenedor aparte** — corre directo en Ollama | Confirmado: `ollama pull bge-m3` existe (1,2GB, 567M params, en la biblioteca oficial de Ollama) — corre en la misma GPU que el modelo de código, sin sumar un proceso Python separado que consuma RAM del sistema. Esto reemplaza cualquier plan de correr BGE-M3 vía una librería de Python aparte. |

**Regla general:** Docker para lo que no tiene forma nativa razonable en Windows. Nativo para lo que necesita GPU directa, arranque temprano, o integración profunda con el editor/sistema de archivos.

## Cómo se habilita e interconectan (recapitulando lo ya scripteado)

1. **Docker Desktop** (`05-instalar-docker.ps1`) usa **WSL2** como backend en Windows — Docker en sí corre dentro de una máquina virtual Linux ligera que Windows gestiona.
2. **Red entre contenedores y el host:** Open WebUI (contenedor) necesita hablarle a Ollama (nativo, fuera de Docker) — se resuelve con `--add-host=host.docker.internal:host-gateway` + `OLLAMA_BASE_URL=http://host.docker.internal:11434` (ya en `07-desplegar-openwebui.ps1`). Es el mecanismo estándar de Docker Desktop para que un contenedor alcance servicios del equipo anfitrión.
3. **Puertos expuestos al host:** `-p 3000:8080` (Open WebUI) y `-p 6333:6333` (Qdrant) — así `localhost:3000`/`localhost:6333` en Windows llegan a cada contenedor.
4. **Open WebUI ↔ Qdrant:** cuando se conecte el RAG real (Paso 2 de `plan-instalacion.md`), Open WebUI puede usar Qdrant como base vectorial vía su propia configuración interna (URL `http://host.docker.internal:6333` desde dentro del contenedor de Open WebUI, o `qdrant:6333` si se ponen ambos en la misma red de Docker con `docker network create` — más prolijo que depender de `host.docker.internal` entre dos contenedores, queda como mejora al conectar el RAG real).

## El problema real: RAM, no VRAM (verificado 2026-08-27)

La VRAM (12GB) ya está bien presupuestada (Qwen 2.5 Coder Q8_0 7,5GB + BGE-M3 1,2GB = 8,7GB, deja ~3,3GB de margen). **La RAM del sistema (16GB) es la restricción que no se había cuantificado.**

**Hallazgo verificado en la documentación oficial de Microsoft (`learn.microsoft.com/windows/wsl/wsl-config`):** WSL2 — y por lo tanto Docker Desktop, que corre sobre WSL2 — **reserva por defecto el 50% de la RAM total de Windows**. En este equipo (16GB), eso son **8GB solo para la capa de Docker**, antes de correr una sola imagen. En un equipo dedicado con 32-64GB esto no importaría; acá es la mitad de todo lo que hay.

### Presupuesto estimado si no se corrige nada (orden de magnitud, no medido)

| Componente | RAM estimada |
|---|---|
| Windows 11 en reposo | ~3GB |
| WSL2/Docker Desktop (default, sin capar) | **hasta 8GB** |
| Ollama (proceso, no los pesos — esos van en VRAM) | ~1GB |
| VS Code + extensiones (Continue.dev/Qwen Code) | ~1-1,5GB |
| Goose o Qwen Code CLI activo | ~0,3-0,5GB |
| **Total aproximado** | **~14-15GB de 16GB — sin margen** |

Sin margen significa: cualquier uso adicional del equipo (un navegador con varias pestañas, o el otro uso que comparte esta máquina) empieza a generar swapping (usar disco como RAM de emergencia, mucho más lento) o cierres forzados.

### Corrección recomendada

1. **Capar WSL2 explícitamente** — crear/editar `%UserProfile%\.wslconfig`:
   ```ini
   [wsl2]
   memory=4GB
   ```
   Reduce el consumo máximo de Docker Desktop de 8GB a 4GB — sigue siendo holgado para dos contenedores livianos (Open WebUI + Qdrant), y libera 4GB para el resto del equipo. Requiere reiniciar WSL2 (`wsl --shutdown` desde una terminal) para que tome efecto.
2. **Límite de memoria por contenedor** (defensa adicional, evita que uno solo se coma todo el margen asignado a WSL2): agregar `--memory="1g"` a los `docker run` de Qdrant y Open WebUI.
3. **BGE-M3 vía Ollama, no vía Python/CPU aparte** (ya corregido arriba) — evita sumar un proceso más a la RAM del sistema.
4. **No es necesario tener Goose, Qwen Code y Continue.dev corriendo pesado los tres a la vez** — son herramientas complementarias (ver `herramientas-trabajo.md`), no hace falta usarlas todas en la misma sesión de trabajo.

### Presupuesto con las correcciones aplicadas

| Componente | RAM estimada |
|---|---|
| Windows 11 en reposo | ~3GB |
| WSL2/Docker Desktop (capado) | 4GB |
| Ollama | ~1GB |
| VS Code + una herramienta de código activa | ~1,5GB |
| **Total aproximado** | **~9,5GB de 16GB — ~6,5GB de margen real** |

Ese margen es el que permite que el equipo siga sirviendo para su otro uso sin que el piloto lo deje sin memoria.

## Próximos pasos

- [ ] Aplicar el límite de `.wslconfig` (agregado a `05-instalar-docker.ps1`, ver `aprendizaje-scripts.md`).
- [ ] Agregar `--memory` a los `docker run` de Qdrant y Open WebUI (`06-desplegar-qdrant.ps1`, `07-desplegar-openwebui.ps1`).
- [ ] Usar `ollama pull bge-m3` en vez de instalar una librería de Python aparte para embeddings (corrige `plan-instalacion.md` Paso 2 y `03-descargar-modelo.ps1`).
- [ ] Una vez instalado, medir el uso real de RAM (Administrador de tareas, o `docker stats` para los contenedores) y comparar contra esta estimación — corregir la tabla con datos reales, no solo proyectados.
