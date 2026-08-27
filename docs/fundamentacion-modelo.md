# Fundamentación de la elección de modelo

Este documento existe porque un piloto no se sostiene solo con "correr un script que funciona" — si alguien pregunta *por qué Qwen* o *qué es Qwen*, la respuesta no puede ser "es lo que recomendó una calculadora". Acá está el qué, el de dónde viene, y el esquema completo de cómo se llegó a la decisión final para este equipo.

## Qué es Qwen

Qwen (nombre completo original: **Tongyi Qianwen**, 通义千问) es la familia de modelos de lenguaje desarrollada por **Alibaba Cloud**, dentro de Alibaba Group (China). No es un modelo único — es una familia con muchas variantes (tamaños, especializaciones, generaciones) publicada de forma muy frecuente, a diferencia de laboratorios que publican una vez cada mucho tiempo.

## Breve historia real (verificada, no de memoria sin chequear)

Verificado contra el blog oficial de Qwen (qwen.ai/blog) el 2026-08-26:

| Cuándo | Qué pasó |
|---|---|
| Agosto 2023 | Primera apertura de pesos de Qwen (7B/14B) — Alibaba entra al espacio open-weight. |
| Febrero 2024 | Qwen 1.5 — familia ampliada de tamaños. |
| Junio 2024 | Qwen 2 — salto de capacidad relevante, empieza a competir de cerca con Llama 3. |
| **18 de septiembre de 2024** | **Qwen 2.5** — anunciado por el propio equipo como *"posiblemente el lanzamiento open-source más grande de la historia"* hasta ese momento. Trae de entrada **Qwen2.5-Coder** (inicialmente solo 1.5B y 7B, con 32B "en camino") y **Qwen2.5-Math**, como líneas especializadas separadas del modelo generalista. |
| **11 de noviembre de 2024** | **Familia completa de Qwen2.5-Coder** (0.5B / 1.5B / 3B / 7B / 14B / 32B — seis tamaños). El insignia, Qwen2.5-Coder-32B-Instruct, es presentado como el modelo de código open-source más fuerte del momento, con desempeño comparable a GPT-4o en generación y reparación de código (benchmarks propios: EvalPlus, LiveCodeBench, BigCodeBench, Aider). **Qwen2.5-Coder-7B** (el tamaño de este proyecto): 7,61 mil millones de parámetros, contexto de 128K, licencia Apache 2.0. |
| 2025 | Qwen 3 — introduce modos híbridos de razonamiento ("thinking"/"non-thinking") en el mismo modelo. |
| Abril 2026 (dato ya verificado en `ia-local/docs/modelos.md`) | Qwen 3.6-27B — el candidato generalista elegido para el proyecto de la empresa (`ia-tecnoingenieria`), de la misma familia que el modelo de este piloto. |

**Fuente:** blog oficial de Qwen — [qwen.ai/blog?id=qwen2.5](https://qwen.ai/blog?id=qwen2.5) (anuncio de Qwen2.5, 2024-09-18) y [qwen.ai/blog?id=qwen2.5-coder-family](https://qwen.ai/blog?id=qwen2.5-coder-family) (familia completa de Qwen2.5-Coder, 2024-11-11) — navegados con el motor de navegador real disponible en este entorno, no de memoria sin verificar.

## Por qué esto importa para este proyecto

Qwen2.5-Coder **no es un experimento aislado** — es una línea especializada con casi dos años de desarrollo continuo (desde la primera versión Coder de septiembre 2024 hasta hoy), con su propio reporte técnico publicado (*"Qwen2.5-Coder Technical Report"*, Hui et al. 2024), probado en herramientas reales de la industria (Cursor, Open WebUI/Artifacts) antes de publicarse. Elegirlo no es "la opción más simple que aparece primero" — es una línea de producto con historial, filosofía declarada ("scaling law": más tamaño = más capacidad, validado empíricamente por el propio equipo en las 6 variantes) y evidencia pública de uso real.

## Esquema de la decisión — cómo se llegó a Qwen 2.5 Coder 7B para este equipo

```
Universo de modelos open-weight disponibles en 2026
        │
        ▼
Filtro 1 — ¿Cabe en 12GB de VRAM (la GPU real de este equipo)?
        │  Elimina: todo el ranking "top" de llm-stats.com (GLM-5.2, DeepSeek-V4-Pro-Max,
        │  Kimi K3, Qwen3.6-27B mismo) — son de 27B a 2.800B params, pensados
        │  para datacenter, no para una GPU consumer de 12GB.
        ▼
Sobreviven: modelos de ~7-9B en cuantización Q4/Q8
        │
        ▼
Filtro 2 — ¿El caso de uso es programación específicamente?
        │  (ver ia-tecnoingenieria/docs/05-casos-de-uso/por-area.md, TI: "asistente
        │  de código para desarrollo interno/automatizaciones")
        │  Esto separa dos caminos: modelo generalista (ej. Qwen 3.5 9B) vs.
        │  modelo especializado en código (ej. Qwen 2.5 Coder 7B, StarCoder,
        │  DevStral, CodeLlama).
        ▼
Filtro 3 — Entre especializados en código, ¿cuál rinde mejor en contexto real de trabajo?
        │  StarCoder 7B / DevStral 7B / CodeLlama 7B-13B: grado de benchmark más alto,
        │  pero contexto corto (no alcanza para archivos completos o hilos largos
        │  de depuración real).
        │  Qwen3-Coder 30B A3B: mejor arquitectura MoE, pero 14,9GB — no cabe en 12GB.
        │  Qwen 2.5 Coder 7B: contexto de 128-131K (confirmado oficial y por
        │  willitrunai.com) — muy superior al resto, con solo un escalón de
        │  grado de diferencia.
        ▼
Filtro 4 — ¿Verificación con la GPU exacta de este equipo (no un proxy)?
        │  Confirmado en willitrunai.com/es/can-run/qwen-2.5-coder-7b-on-rtx-5070-12gb
        │  (2026-08-26): "Runs Great", 7,5GB de 12GB, 98 tok/s, contexto seguro
        │  real de 100K, sin offload en ningún workload evaluado.
        ▼
Filtro 5 — ¿Licencia permite el uso sin restricciones?
        │  Apache 2.0 confirmado en el reporte técnico oficial — sin restricción
        │  por tamaño de organización ni uso comercial.
        ▼
DECISIÓN FINAL: Qwen 2.5 Coder 7B, cuantización a probar Q4_K_M y Q8_0
(ver ../ia-local-piloto/docs/modelo-elegido.md para el detalle técnico completo)
```

Cada filtro de este esquema tiene su hallazgo documentado por separado — este documento existe para juntarlos en una sola narrativa explicable, no para repetir los datos técnicos (esos viven en `modelo-elegido.md`).

## Qué preguntar si alguien cuestiona esta elección

- *"¿Por qué no el modelo con mejor benchmark?"* → porque el benchmark más alto (StarCoder/DevStral/CodeLlama) viene con un contexto mucho más corto, y en programación real el contexto importa más que un par de puntos de benchmark (ver `../ia-local/docs/conceptos-fundamentales.md` §7).
- *"¿Por qué no el modelo más grande de Qwen (Qwen3.6-27B)?"* → no cabe en esta GPU (12GB) — confirmado, no supuesto.
- *"¿Es un modelo de fiar / con historial?"* → sí: casi dos años de desarrollo continuo de la línea Coder, reporte técnico publicado, probado en herramientas de industria antes de publicarse (ver historia arriba).
- *"¿Hay algún problema de licencia para usarlo en un contexto de piloto de empresa?"* → no, Apache 2.0, sin restricciones de uso comercial.
