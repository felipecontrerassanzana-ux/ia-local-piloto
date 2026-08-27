# Cómo repartir el almacenamiento (NVMe + HDD)

El equipo tiene dos discos: **NVMe ~500GB** (rápido, más chico) y **HDD 1TB** (lento, más grande). No estaba claro cómo repartir la información entre ambos — esta es la guía concreta.

## Criterio general

Lo que se lee/escribe **todo el tiempo mientras el modelo responde** va en el NVMe. Lo que se lee **una sola vez al cargar** (y después queda en RAM/VRAM) puede vivir en el HDD sin costo real de rendimiento.

| Qué | Dónde | Por qué |
|---|---|---|
| Windows + programas (Ollama, Docker, Goose, VS Code) | **NVMe** | Rendimiento general del sistema — no tiene sentido instalar el sistema operativo en el disco lento. |
| Pesos del modelo (Qwen 2.5 Coder 7B, ~4-8GB según cuantización) | **HDD** (vía `OLLAMA_MODELS`, ver abajo) | Se lee una sola vez al cargar el modelo a VRAM (tarda unos segundos más desde HDD que desde NVMe, una sola vez por reinicio del servicio) — después vive en VRAM, la velocidad del disco ya no importa mientras responde. Libera espacio del NVMe, que es más chico. |
| Índice de Qdrant (RAG) | **NVMe**, si el índice crece grande | A diferencia del modelo, el RAG sí consulta el disco en cada pregunta (búsqueda por similitud) — conviene que esté en el disco rápido. Para el volumen de un piloto (documentos de prueba, no un repositorio gigante), el HDD también sería aceptable — priorizar NVMe si hay espacio. |
| Backups locales antes de subir a Drive | **HDD** | Es almacenamiento "de paso", no se lee con frecuencia — no compite por espacio rápido. |
| Proyectos de código en los que se trabaja activamente (con Goose/Continue.dev) | **NVMe** | Un IDE/editor y las herramientas de análisis de código se sienten mejor en disco rápido, y estos proyectos no suelen pesar mucho. |

## Cómo mover el modelo al HDD

Confirmado en la documentación oficial de Ollama (`docs/windows.mdx`): se cambia con la variable de entorno `OLLAMA_MODELS`, apuntándola a una carpeta en el HDD (ej. `D:\OllamaModels`, ajustar la letra de unidad real del HDD en este equipo).

1. Buscar "variables de entorno" en la configuración de Windows → *Editar las variables de entorno del sistema*.
2. Crear (o editar) la variable `OLLAMA_MODELS` con la ruta deseada en el HDD.
3. Si Ollama ya estaba corriendo, cerrar la aplicación desde la bandeja del sistema y volver a abrirla (o iniciar una terminal nueva) para que tome el cambio.

El script `scripts/02-configurar-ollama.ps1` deja esto configurado automáticamente — solo hay que confirmar la letra de unidad correcta del HDD antes de correrlo.

## Pendiente de confirmar

- [ ] Letra de unidad real de cada disco en este equipo (ej. `C:` para NVMe, `D:` para HDD — confirmar, no asumir).
- [ ] Espacio libre real en cada uno hoy (antes de instalar nada) — lo reporta `scripts/00-verificar-equipo.ps1`.
