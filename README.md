# IA Local Piloto

Piloto real de un LLM autoalojado sobre un equipo concreto que ya se tiene: **RTX 5070 12GB / 16GB RAM / AMD Ryzen 5 3600, Windows 11 Pro 25H2**. Es un proyecto **independiente**, autocontenido.

**Uso principal:** asistente de programación local — por eso se eligió un modelo especializado en código (Qwen 2.5 Coder 7B) en vez de uno generalista.

Repositorio: [github.com/felipecontrerassanzana-ux/ia-local-piloto](https://github.com/felipecontrerassanzana-ux/ia-local-piloto) (privado).

## Por qué es un proyecto aparte

Es un proyecto **independiente y autocontenido** — no depende de nada externo para tener sentido por sí solo. La única relación real con otro repo es con `ia-local`, la base teórica transversal (modelos, hardware, arquitectura, conceptos) que nunca ejecuta nada — este repo sí ejecuta, sobre un equipo específico y real. Esa base teórica es genérica (no contiene nada específico de ningún proyecto en particular), así que se puede referenciar sin arrastrar contexto ajeno a este piloto.

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
- `docs/herramientas-trabajo.md` — el modelo no tiene memoria propia: qué herramientas usar para programar de forma efectiva (Goose, Qwen Code, Continue.dev, Aider) y cómo se resuelve la memoria persistente en la práctica (Auto-memory de Qwen Code de fábrica, `AGENTS.md`/reglas estáticas como respaldo, Mem0 descartado por ahora).
- `docs/qwen-code-a-fondo.md` — qué funciones de Qwen Code sacan más provecho al modelo instalado (Plan Mode, SubAgents, contexto largo, Auto-memory, cruzado contra los números reales de `modelo-elegido.md`), y los tres modos de conexión posibles: mismo equipo, misma red de casa, y remoto fuera de la red (Tailscale recomendado, Cloudflare Tunnel+Access como alternativa reutilizando lo ya planeado).
- `docs/motor-alternativas.md` — alternativas a Ollama si el piloto necesita más funciones que solo código (LocalAI para voz/imagen/visión, LM Studio como GUI, Open WebUI como interfaz web).
- `docs/acceso-remoto.md` — cómo acceder por navegador desde afuera sin IP fija (Tailscale Funnel / Cloudflare Tunnel), con la condición real de este equipo (fibra Movistar 800 megas, sin IP fija).
- `docs/mantenimiento.md` — continuidad tras corte de luz (sin UPS por ahora), backup a Drive personal, checklist mensual de actualizaciones, y confirmación de que toda la estructura es gratuita.
- `docs/como-funcionan-los-agentes.md` — cómo funcionan por dentro Goose y Qwen Code (ciclo de vida de sesión, qué archivo de contexto lee cada uno, MCP, subagentes, skills) — para entender el motor y los addons, no solo instalarlos.
- `AGENTS.md` (raíz) — instrucciones reales que Goose y Qwen Code leen automáticamente al trabajar en este proyecto: decisiones ya tomadas, convenciones, restricciones duras del equipo, qué revisar antes de proponer algo nuevo.
- `DESIGN.md` (raíz) — reglas de diseño del frontend (qué sistema de componentes usar, revisión visual obligatoria) para que el resultado no dependa de que el modelo de código "invente" estilo. Ver `docs/capa-diseno.md` para el porqué completo.
- `docs/capa-diseno.md` — **por qué el frontend siempre "queda cojo" con un modelo de solo texto, y cómo se resuelve**: revisor visual (`qwen3-vl:4b`), generador de assets (ComfyUI + Stable Diffusion 1.5), y el loop generar → revisar → corregir — todo protegiendo la VRAM del modelo de código, que no se toca.
- `docs/plan-pruebas.md` — protocolo de evaluación y criterios de éxito de este piloto.
- `docs/decisiones.md` — bitácora cronológica de decisiones (mismo patrón que los otros repos).
- `docs/almacenamiento.md` — cómo repartir el modelo/RAG/proyectos entre el NVMe y el HDD.
- `docs/docker-y-recursos.md` — por qué este piloto corre todo nativo en Windows sin Docker (Qdrant y Open WebUI tienen forma nativa oficial), y el presupuesto real de RAM en un equipo de 16GB.
- `docs/resultados.md` — se crea una vez haya pruebas reales corridas en el equipo.
- `docs/aprendizaje-scripts.md` — **qué hace cada script y por qué**, explicado en conceptos (variables de entorno, servicios de Windows, volúmenes de Docker, Tareas Programadas) — para entender el montaje, no solo ejecutarlo.
- `docs/pruebas-rendimiento.md` — esquema de pruebas de estrés post-instalación (tok/s real, estabilidad bajo carga, límite real de contexto) — distinto de `plan-pruebas.md` (que evalúa calidad, no rendimiento).
- `scripts/` — **instalación ejecutable, no solo documentada**: un `.ps1` por paso más su `.bat` con elevación de permisos (UAC) para correrlo con doble clic. Ver `scripts/README.md` para el orden y qué necesita input tuyo (token de Cloudflare, ruta de Drive). Incluye el chequeo integral (`verificar-instalacion.bat`) y la prueba de estrés (`11-prueba-estres.bat`).

## Estado actual

Documentación y scripts de instalación completos — **ningún script se ha ejecutado todavía en el equipo real**. Ver `docs/plan-instalacion.md` para el orden de pasos y `scripts/README.md` para cómo correrlos.
