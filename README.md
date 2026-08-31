# IA Local Piloto

Piloto real de un LLM autoalojado sobre un equipo concreto que ya se tiene: **RTX 5070 12GB / 16GB RAM / AMD Ryzen 5 3600, Windows 11 Pro 25H2**. Es un proyecto **independiente**, autocontenido.

**Uso principal:** asistente de programación local — por eso se eligió un modelo especializado en código (Qwen 2.5 Coder 7B) en vez de uno generalista.

Repositorio: [github.com/felipecontrerassanzana-ux/ia-local-piloto](https://github.com/felipecontrerassanzana-ux/ia-local-piloto) (privado).

## Por qué es un proyecto aparte

Es un proyecto **independiente y autocontenido** — no depende de nada externo para tener sentido por sí solo. La única relación real con otro repo es con `ia-local`, la base teórica transversal (modelos, hardware, arquitectura, conceptos) que nunca ejecuta nada — este repo sí ejecuta, sobre un equipo específico y real. Esa base teórica es genérica (no contiene nada específico de ningún proyecto en particular), así que se puede referenciar sin arrastrar contexto ajeno a este piloto.

## Qué usa de `ia-local` (sin duplicar)

Este proyecto parte de la base teórica ya construida en el repo hermano `../ia-local/` (orden ascendente, mismo criterio de numeración que el resto de la documentación):
- `../ia-local/docs/01-conceptos-fundamentales.md` — teoría de cuantización, VRAM, RAG, etc.
- `../ia-local/docs/02-modelos.md` — catálogo de modelos y su VRAM real.
- `../ia-local/docs/03-hardware.md` — contexto de hardware y precios.
- `../ia-local/docs/04-arquitectura.md` — stack de RAG, motor de inferencia, protocolo de evaluación de modelos.
- `../ia-local/docs/05-metodologia-de-proyecto.md` — prácticas de planificación/proceso extraídas de auditar este mismo piloto de principio a fin.
- `../ia-local/docs/06-guia-aprendizaje.md` — la guía previa (pensada para un notebook sin GPU); este proyecto es el paso siguiente, con GPU real.

Lo que **no** está en `ia-local` y sí vive acá: las specs exactas de este equipo, la decisión de modelo para este hardware puntual, los pasos reales de instalación, el plan de pruebas, y los resultados medidos de verdad (no de un sitio de benchmarks de terceros).

## Estructura

`docs/` está organizado por categoría — cada subcarpeta tiene su propio `README.md` con el detalle de qué hay adentro (reordenado 2026-08-27, antes eran 18 archivos sueltos):

| Carpeta | Qué contiene |
|---|---|
| [`docs/01-arquitectura/`](docs/01-arquitectura/README.md) | El esquema completo del stack, por qué no hay Docker, dónde vive cada cosa en disco, y la capa de diseño visual. |
| [`docs/02-modelo/`](docs/02-modelo/README.md) | Por qué Qwen 2.5 Coder 7B, su historia, y las specs del equipo cruzadas contra qué modelo cabe. |
| [`docs/03-herramientas/`](docs/03-herramientas/README.md) | Goose, Qwen Code, Continue.dev/Aider, cómo funcionan por dentro, y alternativas a Ollama. |
| [`docs/04-instalacion/`](docs/04-instalacion/README.md) | Los pasos concretos y qué hace cada script por dentro. |
| [`docs/05-pruebas/`](docs/05-pruebas/README.md) | Protocolo de evaluación de calidad y de rendimiento real. |
| [`docs/06-operacion/`](docs/06-operacion/README.md) | Continuidad, backup, actualizaciones, y acceso remoto por navegador. |
| [`docs/07-referencia/`](docs/07-referencia/README.md) | Manual por herramienta/modelo — comandos, API, mejores prácticas, para tener dominio completo de cada pieza del stack. |

Fuera de `docs/`:

- **`AGENTS.md`** (raíz) — instrucciones reales que Goose y Qwen Code leen automáticamente al trabajar en este proyecto: decisiones ya tomadas, convenciones, restricciones duras del equipo, qué revisar antes de proponer algo nuevo.
- **`DESIGN.md`** (raíz) — reglas de diseño del frontend (qué sistema de componentes usar, revisión visual obligatoria) para que el resultado no dependa de que el modelo de código "invente" estilo.
- **`docs/decisiones.md`** — bitácora cronológica de decisiones (mismo patrón que los otros repos) — queda fuera de las subcarpetas porque se consulta todo el tiempo.
- **`scripts/`** — **instalación ejecutable, no solo documentada**: un `.ps1` por paso más su `.bat` con elevación de permisos (UAC) para correrlo con doble clic, más `instalar-todo.bat` como instalador único con interfaz gráfica que corre todos los pasos automatizables en el orden real de dependencias, verificando cada uno. Ver `scripts/README.md` para el detalle y qué necesita input tuyo (token de Cloudflare, ruta de Drive). Incluye el chequeo integral (`verificar-instalacion.bat`), la prueba de estrés (`11-prueba-estres.bat`), y la bitácora de horas por proyecto (`bitacora-horas.bat`, ver `docs/06-operacion/04-bitacora-horas.md`).

## Estado actual

Documentación y scripts de instalación completos — **ningún script se ha ejecutado todavía en el equipo real**. Instalador recomendado: `scripts/instalar-todo.bat`. Ver `docs/04-instalacion/01-plan-instalacion.md` para el detalle paso a paso y `scripts/README.md` para cómo correr cualquiera de los dos.
