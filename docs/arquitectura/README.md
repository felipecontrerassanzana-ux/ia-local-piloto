# Arquitectura

Cómo queda armado el stack completo — el esquema estructural, por qué no se usa Docker, dónde vive cada cosa en disco, y la capa de diseño visual.

- **`arquitectura-piloto.md`** — **el esquema estructural completo del montaje**: diagrama de todo el stack junto (hardware → modelo → motor → herramientas → red → autenticación), tabla de qué decisión sale de qué documento, y una sección proactiva de qué falta resolver antes de instalar de verdad. Es el punto de partida para ver el conjunto, no solo una pieza.
- **`capa-diseno.md`** — por qué el frontend de una app generada por IA siempre "queda cojo" (el modelo de código es solo texto, no puede evaluar visualmente su propio resultado), y cómo se resuelve: revisor visual (`qwen3-vl:4b`), generador de assets (ComfyUI + Stable Diffusion 1.5), sin tocar la cuantización del modelo de código.
- **`docker-y-recursos.md`** — por qué este piloto corre todo nativo en Windows sin Docker (Qdrant y Open WebUI tienen forma nativa oficial), y el presupuesto real de RAM en un equipo de 16GB.
- **`almacenamiento.md`** — cómo repartir el modelo/RAG/proyectos entre el NVMe y el HDD (corregido 2026-08-27: los modelos van al NVMe, no al HDD, por el diseño de intercambio de modelos bajo demanda).
