# Pruebas de estrés y rendimiento post-instalación

Esto es distinto de `plan-pruebas.md`: aquel evalúa **calidad** (¿la respuesta es correcta?, ¿alucina?, ¿el español es natural?) con tareas de programación reales, juzgadas por una persona. Este documento evalúa **rendimiento técnico puro**: velocidad, estabilidad bajo carga, y el límite real de contexto — con números medidos, no juicio de calidad. Script: `scripts/11-prueba-estres.ps1`.

## Por qué hace falta esto además de `plan-pruebas.md`

Varios números usados en este proyecto son **estimaciones de terceros** (willitrunai.com) o **valores por defecto de una página de catálogo** (ollama.com/library) — nunca medidos en este equipo exacto. Esta prueba cierra esa brecha con datos de primera mano, usando los propios campos de métricas que Ollama devuelve en cada respuesta (documentado oficialmente en `github.com/ollama/ollama/docs/api.md`): `prompt_eval_count`, `eval_count`, `eval_duration`, etc. — no es un cronómetro externo aproximado, es lo que el propio motor reporta.

## Las 3 pruebas del script

### 1. Baseline — prompt corto, 5 repeticiones

Establece un número de referencia (tok/s) en condiciones ideales (poco contexto, GPU "fría"). Sirve como punto de comparación para las otras dos pruebas — si algo más adelante da mucho menos que esto, hay un problema que investigar, no es "normal".

**Qué comparar:** el promedio debería acercarse a los ~98 tok/s estimados por willitrunai.com para Q4_K_M (ver `../modelo/modelo-elegido.md`) — no tiene que ser idéntico (es otra metodología de medición), pero si está muy por debajo (ej. menos de 50 tok/s), algo no está bien configurado (revisar si el modelo está cargando en GPU o si está haciendo offload a CPU — ver `ollama ps`, columna `PROCESSOR`).

### 2. Carga sostenida — 20 repeticiones seguidas

El mismo prompt, veinte veces seguidas sin pausa. El objetivo es detectar **degradación**: si el equipo (compartido, sin gabinete de servidor, con refrigeración de PC de escritorio normal) sufre de acumulación de calor bajo uso sostenido, el tok/s de la corrida #20 debería ser notablemente menor que el de la #1.

**Cómo interpretar:**
- Si el tok/s se mantiene estable (variación menor a ~10%): el equipo aguanta uso sostenido sin problema térmico.
- Si cae progresivamente: revisar la temperatura de GPU registrada en el archivo de resumen (capturada antes/después con `nvidia-smi`) — sobre ~83-85°C en una GPU NVIDIA moderna suele activar throttling automático (reducción de velocidad para no sobrecalentarse). Si se confirma esto, es un dato real para decidir si hace falta mejorar la ventilación del gabinete antes de darle uso diario pesado.

### 3. Rampa de contexto — el pendiente que quedó abierto en `../modelo/modelo-elegido.md`

Envía textos sintéticos cada vez más largos (apuntando aproximadamente a 1K, 8K, 32K, 64K y 100K+ tokens — Ollama mismo informa el conteo real vía `prompt_eval_count`, no hace falta adivinarlo) y pide un resumen corto de cada uno. Esto responde directamente la pregunta que quedó pendiente: **¿el modelo realmente sostiene más de 32K de contexto en la práctica, o el límite de 32K que muestra la página de Ollama es real?**

**Cómo interpretar el resultado:**
- Si la prueba de `Contexto-x1200` o `Contexto-x2000` (los tamaños más grandes) se completa sin error: el modelo sí acepta más de 32K, confirmando que ese número era solo el default de fábrica, no un techo real. Registrar el resultado en `../modelo/modelo-elegido.md` (actualizar el pendiente marcado ahí).
- Si el script falla o corta en un tamaño específico (ej. justo pasando 32K): eso es el límite real de esta instalación — hay que documentarlo como el contexto verdadero utilizable, no los 100K que se habían proyectado, y ajustar `OLLAMA_CONTEXT_LENGTH` acorde en `02-configurar-ollama.ps1`.
- **Esta prueba no evalúa si el modelo "recuerda bien" el contenido largo** (eso sería una prueba de calidad, no de estrés) — solo si la petición se procesa técnicamente. Para saber si realmente usa bien un contexto largo, agregar ese caso a `plan-pruebas.md` con una persona revisando la respuesta.

## Qué hacer con los resultados

Cada corrida genera dos archivos en `logs/` (no versionados en git, ver `.gitignore`):
- `prueba-estres-<fecha>.csv` — el detalle fila por fila, para abrir en Excel/Sheets y graficar si se quiere (ej. tok/s a lo largo de la carga sostenida).
- `prueba-estres-<fecha>-resumen.txt` — el resumen legible, con las lecturas de GPU.

**Después de la primera corrida real:** volcar los hallazgos clave (tok/s real medido, límite de contexto real, si hubo throttling) a `resultados.md` — ese archivo es justamente el lugar reservado para datos de primera mano, no estimaciones (ver README del proyecto).

## Cuándo volver a correr esta prueba

- La primera vez, apenas termine la instalación (antes de empezar a usar el equipo para trabajo real).
- Cada vez que cambie algo relevante: cuantización usada (Q4_K_M vs Q8_0), drivers de NVIDIA actualizados, o si en el uso diario se nota que "se siente más lento que antes" — ahí esta prueba da un número objetivo para confirmar o descartar la sensación.
