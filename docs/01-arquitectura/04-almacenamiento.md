# Cómo repartir el almacenamiento (NVMe + HDD)

El equipo tiene dos discos: **NVMe ~500GB** (rápido, más chico) y **HDD 1TB** (lento, más grande). No estaba claro cómo repartir la información entre ambos — esta es la guía concreta.

## Criterio general (corregido 2026-08-27)

Lo que se lee/escribe **repetidamente durante una sesión de trabajo** va en el NVMe. Lo que se lee **una sola vez, o casi nunca** (backups, overflow) puede vivir en el HDD sin costo real de rendimiento.

**Por qué cambió el criterio:** la versión anterior de esta guía asumía que un modelo se carga una sola vez al arrancar Ollama y se queda en VRAM todo el día — bajo esa idea, el HDD era aceptable para los pesos del modelo. Con el diseño de intercambio de modelos bajo demanda (coder de código / revisor visual de diseño / generador de imágenes, ver `02-capa-diseno.md`), un modelo se carga y descarga de VRAM **varias veces por sesión**, no una sola vez — cada intercambio paga el costo de leer el disco de nuevo. La diferencia real: un HDD mecánico ronda 100-160 MB/s, un NVMe ronda 2.000-7.000+ MB/s — para un modelo de ~4-5GB, eso es la diferencia entre ~30 segundos de espera por cada cambio de tarea (HDD) y 1-2 segundos (NVMe).

| Qué | Dónde | Por qué |
|---|---|---|
| Windows + programas (Ollama, Goose, Qwen Code, VS Code) | **NVMe** | Rendimiento general del sistema — no tiene sentido instalar el sistema operativo en el disco lento. |
| **Pesos de todos los modelos** (Qwen 2.5 Coder 7B, Qwen3-VL 4B, checkpoint de Stable Diffusion) | **NVMe** (vía `OLLAMA_MODELS` y la carpeta `models/checkpoints` de ComfyUI, ver abajo) | Se intercambian en VRAM varias veces por sesión de trabajo (ver criterio de arriba) — el costo de disco se paga en cada intercambio, no una sola vez. Entre los tres modelos suman ~20GB, una fracción chica de los 500GB del NVMe — no compite en serio por espacio. |
| Historial de sesión (`sessions.db` de Goose, checkpoints de Qwen Code) | **NVMe** | Se lee y escribe activamente en cada turno de la conversación, no una sola vez — igual que el modelo, no como un backup. |
| Índice de Qdrant (RAG) | **NVMe**, si el índice crece grande | A diferencia del modelo, el RAG sí consulta el disco en cada pregunta (búsqueda por similitud) — conviene que esté en el disco rápido. Para el volumen de un piloto (documentos de prueba, no un repositorio gigante), el HDD también sería aceptable como overflow si el NVMe se queda corto. |
| Backups locales antes de subir a Drive | **HDD** | Es almacenamiento "de paso", no se lee con frecuencia — solo en un escenario de recuperación real. No compite por espacio rápido. |
| Corpus/datasets grandes descargados una sola vez | **HDD** | Se leen una vez para indexar (si aplica) y después casi no se tocan — igual lógica que los backups. |
| Proyectos de código en los que se trabaja activamente (con Goose/Qwen Code) | **NVMe** | Un IDE/editor y las herramientas de análisis de código se sienten mejor en disco rápido, y estos proyectos no suelen pesar mucho. |

## Cómo configurar dónde viven los modelos

Confirmado en la documentación oficial de Ollama (`docs/windows.mdx`): se cambia con la variable de entorno `OLLAMA_MODELS`, apuntándola a una carpeta en el NVMe (ej. `C:\OllamaModels`, ajustar la letra de unidad real del NVMe en este equipo).

1. Buscar "variables de entorno" en la configuración de Windows → *Editar las variables de entorno del sistema*.
2. Crear (o editar) la variable `OLLAMA_MODELS` con la ruta deseada en el NVMe.
3. Si Ollama ya estaba corriendo, cerrar la aplicación desde la bandeja del sistema y volver a abrirla (o iniciar una terminal nueva) para que tome el cambio.

El script `scripts/pasos/02-configurar-ollama.ps1` deja esto configurado automáticamente — solo hay que confirmar la letra de unidad correcta del NVMe antes de correrlo (parámetro `-LetraNVMe`, default `C`).

ComfyUI (el motor de generación de imágenes, ver `02-capa-diseno.md`) guarda su propio checkpoint en `models/checkpoints/` dentro de su carpeta de instalación — el script `15-instalar-comfyui.ps1` la instala directo en el NVMe, no hace falta configurarlo aparte.

## Pendiente de confirmar

- [ ] Letra de unidad real de cada disco en este equipo (ej. `C:` para NVMe, `D:` para HDD — confirmar, no asumir).
- [ ] Espacio libre real en cada uno hoy (antes de instalar nada) — lo reporta `scripts/pasos/00-verificar-equipo.ps1`.
