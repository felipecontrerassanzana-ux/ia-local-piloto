# IA Local Piloto

Piloto real de un LLM autoalojado sobre un equipo concreto que ya se tiene: **RTX 5070 12GB / 16GB RAM / AMD Ryzen 5 3600**. Es un proyecto **independiente**, no una carpeta ni una extensión de los otros tres repos de `Documents/Proyectos IA/`.

## Por qué es un proyecto aparte

- **No es `ia-local`:** ese repo es investigación teórica transversal (modelos, hardware, arquitectura, conceptos) — nunca ejecuta nada, es reutilizable para cualquier proyecto de IA local futuro. Este repo sí ejecuta, y lo hace sobre un equipo específico y real, no sobre proyecciones.
- **No es `ia-tecnoingenieria`:** ese repo es el caso de negocio del servidor compartido de la empresa (hardware recomendado: RTX 5070 Ti 16GB, ~$2,6M CLP, para el modelo generalista Qwen3.6-27B, con las 8 áreas de la empresa como usuarios). Este equipo (12GB de VRAM) no alcanza para ese candidato — confirmado en `ia-local/docs/modelos.md`, donde 12GB queda etiquetado "Too big" para Qwen3.6-27B (2,2–3,2 tok/s). Es un equipo distinto, para un objetivo distinto.
- **No es `cumplimiento-tecnoingenieria`:** no aplica, es un proyecto técnico sin relación con cumplimiento legal de la empresa.

## Qué usa de `ia-local` (sin duplicar)

Este proyecto parte de la base teórica ya construida en el repo hermano `../ia-local/`:
- `../ia-local/docs/modelos.md` — catálogo de modelos y su VRAM real.
- `../ia-local/docs/hardware.md` — contexto de hardware y precios.
- `../ia-local/docs/arquitectura.md` — stack de RAG, motor de inferencia, protocolo de evaluación de modelos.
- `../ia-local/docs/conceptos-fundamentales.md` — teoría de cuantización, VRAM, RAG, etc.
- `../ia-local/docs/guia-aprendizaje.md` — la guía previa (pensada para un notebook sin GPU); este proyecto es el paso siguiente, con GPU real.

Lo que **no** está en `ia-local` y sí vive acá: las specs exactas de este equipo, la decisión de modelo para este hardware puntual, los pasos reales de instalación, el plan de pruebas, y los resultados medidos de verdad (no de un sitio de benchmarks de terceros).

## Estructura

- `docs/arquitectura-piloto.md` — **el esquema estructural completo del montaje**: diagrama de todo el stack junto (hardware → modelo → motor → herramientas → red → autenticación), tabla de qué decisión sale de qué documento, y una sección proactiva de qué falta resolver antes de instalar de verdad. Es el punto de partida para ver el conjunto, no solo una pieza.
- `docs/hardware-real.md` — specs del equipo y qué modelo cabe realmente.
- `docs/fundamentacion-modelo.md` — **qué es Qwen, de dónde viene, historia real verificada de la línea Coder, y el esquema completo de la decisión** (filtro por filtro) que llevó a elegirlo para este equipo. Es el documento a leer antes de instalar, para poder explicar la elección, no solo ejecutarla.
- `docs/modelo-elegido.md` — decisión técnica de modelo para este hardware (Qwen 2.5 Coder 7B): VRAM, velocidad, cuantización, comparación con alternativas.
- `docs/plan-instalacion.md` — pasos para dejar el equipo funcionando (Ollama, embeddings, base vectorial, RAG).
- `docs/herramientas-trabajo.md` — el modelo no tiene memoria propia: qué herramientas usar para programar de forma efectiva (Continue.dev, Aider) y cómo resolver la memoria persistente (reglas estáticas ahora, Mem0 como escalamiento si hace falta).
- `docs/motor-alternativas.md` — alternativas a Ollama si el piloto necesita más funciones que solo código (LocalAI para voz/imagen/visión, LM Studio como GUI, Open WebUI como interfaz web).
- `docs/acceso-remoto.md` — cómo acceder por navegador desde afuera sin IP fija (Tailscale Funnel / Cloudflare Tunnel), con la condición real de este equipo (fibra Movistar 800 megas, sin IP fija).
- `docs/mantenimiento.md` — continuidad tras corte de luz (sin UPS por ahora), backup a Drive personal, checklist mensual de actualizaciones, y confirmación de que toda la estructura es gratuita.
- `docs/plan-pruebas.md` — protocolo de evaluación y criterios de éxito de este piloto.
- `docs/decisiones.md` — bitácora cronológica de decisiones (mismo patrón que los otros repos).
- `docs/almacenamiento.md` — cómo repartir el modelo/RAG/proyectos entre el NVMe y el HDD.
- `docs/resultados.md` — se crea una vez haya pruebas reales corridas en el equipo.
- `scripts/` — **instalación ejecutable, no solo documentada**: un `.ps1` por paso más su `.bat` con elevación de permisos (UAC) para correrlo con doble clic. Ver `scripts/README.md` para el orden y qué necesita input tuyo (token de Cloudflare, ruta de Drive). Incluye también el chequeo integral (`verificar-instalacion.bat`).

## Estado actual

Documentación y scripts de instalación completos — **ningún script se ha ejecutado todavía en el equipo real**. Ver `docs/plan-instalacion.md` para el orden de pasos y `scripts/README.md` para cómo correrlos.
