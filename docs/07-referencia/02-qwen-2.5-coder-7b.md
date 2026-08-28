# Qwen 2.5 Coder 7B — referencia completa

El modelo instalado en este piloto. Este documento va más allá de "por qué se eligió" (eso vive en `../02-modelo/02-modelo-elegido.md` y `../02-modelo/01-fundamentacion-modelo.md`) — cubre cómo usarlo bien: parámetros de generación, prompting efectivo, y un hallazgo importante sobre el límite real de contexto que cambia cómo hay que leer la duda pendiente del proyecto. Verificado contra la ficha oficial de Hugging Face y su `config.json` real, 2026-08-27.

## Hallazgo importante: por qué el contexto de "32K vs 100K/131K" no es solo una duda de configuración

Este proyecto tenía anotado como pendiente "verificar si el límite de 32K que muestra Ollama es solo un default empaquetado o el límite real" (ver `../02-modelo/02-modelo-elegido.md`). Investigando el `config.json` real del modelo y su ficha técnica, la respuesta tiene una capa más de fondo de la que se pensaba:

- El `config.json` oficial de `Qwen/Qwen2.5-Coder-7B-Instruct` trae `"max_position_embeddings": 32768` — **32K es el contexto con el que el modelo fue efectivamente entrenado**, no un límite artificial de empaquetado.
- La propia ficha del modelo lo dice explícito: *"The current `config.json` is set for context length up to 32,768 tokens. To handle extensive inputs exceeding 32,768 tokens, we utilize YaRN [...] For supported frameworks, you could add the following to `config.json` to enable YaRN"* — con un bloque `rope_scaling` concreto que hay que agregar a mano.
- **Los 131K/128K "de contexto completo" que se venían citando en `01-fundamentacion-modelo.md` y `02-modelo-elegido.md` requieren activar YaRN explícitamente — no vienen activados por defecto.**
- Confirmado además (`github.com/ollama/ollama`, discusión de la comunidad): Ollama expone parámetros de RoPE (`rope_frequency_base`/`rope_frequency_scale`) en el Modelfile, pero el soporte formal de YaRN específicamente "está planeado, no completamente expuesto todavía" — configurarlo a mano hoy sería una técnica avanzada, no un flag simple.
- **Advertencia real, no solo teórica:** extender el contexto más allá de lo entrenado nativamente **degrada la calidad de las respuestas**, no solo consume más VRAM — "un modelo entrenado en 8K y extendido a 32K vía RoPE rinde peor a 32K que un modelo entrenado nativamente en 32K" (mismo principio aplica acá: entrenado en 32K, forzado a 100K sin YaRN, previsiblemente peor que sin forzar nada).

**Qué significa esto para `11-prueba-estres.ps1` (todavía no corrido):** la pregunta ya no es solo "¿el número más alto funciona?" — es "¿la calidad se mantiene?". Si se sube `OLLAMA_CONTEXT_LENGTH` por encima de 32.768 sin configurar YaRN, es esperable que el modelo acepte la configuración (no tire error) pero degrade en tareas que realmente usan ese contexto extra — hay que medir calidad, no solo que "no se caiga". El estimado de "100K seguro" de willitrunai.com parece ser un cálculo de capacidad de VRAM (cuánto cabe la caché KV), no una garantía de que el modelo razone bien a esa distancia.

## Parámetros de generación

La ficha oficial de Hugging Face **no publica valores recomendados de `temperature`/`top_p`/`top_k`** para este modelo específico (solo aparece `max_new_tokens=512` en los ejemplos de código, que es un límite de salida, no de contexto). Los valores usados en este proyecto (`temperature 0.7`, `top_p 0.9`, en `13-instalar-qwen-code.ps1`) vienen del ejemplo oficial de configuración de Qwen Code para modelos locales, no de una recomendación específica de Qwen para este modelo — son razonables por convención general de modelos instruct, no una cifra mágica verificada para este caso puntual.

## Prompting efectivo para código (aplicado a un modelo de 7B)

- **Acotar el pedido, no pedir "hacé todo el proyecto".** Ya documentado en `../02-modelo/02-modelo-elegido.md`: un 7B rinde mejor con pasos chicos y revisables (por eso Plan Mode/SubAgents de Qwen Code ayudan tanto, ver `../03-herramientas/02-qwen-code-a-fondo.md`).
- **Dar el archivo/función relevante en el prompt, no asumir que "ya lo sabe".** El modelo no tiene memoria del código entre sesiones (eso lo resuelve Auto-memory/`AGENTS.md`, no el modelo en sí) — cuanto más contexto directo se le da del código real, menos alucina.
- **Pedir que explique el cambio antes de aplicarlo**, sobre todo en cambios no triviales — barato de pedir, ayuda a pescar un razonamiento erróneo antes de que se convierta en código roto.
- **Siempre correr y probar lo generado** — la propia línea de Coder está entrenada en reparación de código, pero "sigue pudiendo alucinar una corrección que no compila" (ya documentado en `02-modelo-elegido.md`).

## Fortalezas y límites declarados oficialmente

- **Fortalezas (ficha oficial):** "mejoras significativas en generación, razonamiento y reparación de código"; mantiene fortalezas heredadas en matemáticas y competencias generales; soporte de más de 40 lenguajes de programación (anuncio oficial).
- **Límite de calibración importante (ya en `02-modelo-elegido.md`, reafirmado acá):** las comparaciones con GPT-4o del anuncio oficial son del hermano de 32B, no de este modelo — "correlación positiva entre tamaño y desempeño" declarada por el propio equipo de Qwen.
- **Licencia:** Apache 2.0, sin restricción de uso comercial ni personal.

## Fuentes consultadas (2026-08-27)

- [Qwen2.5-Coder-7B-Instruct — Hugging Face](https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct) — ficha oficial, sección de contexto largo/YaRN.
- [config.json del modelo](https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct/raw/main/config.json) — `max_position_embeddings: 32768` confirmado directo de la fuente.
- [ollama/ollama — Issue #11871](https://github.com/ollama/ollama/issues/11871) — estado real del soporte de RoPE/YaRN en Ollama (parámetros expuestos, soporte formal de YaRN todavía no completo).
