# Modelo elegido para este equipo

## Antes de instalar: entender qué es y de dónde viene

El objetivo de este proyecto no es solo llegar a correr `ollama run qwen2.5-coder:7b` — es entender lo suficiente como para explicarlo si alguien pregunta. Contexto completo (quién hace Qwen, de dónde viene, por qué existe esta familia) en [`../../../ia-local/docs/02-modelos.md` § "Quién está detrás de cada modelo"](../../../ia-local/docs/02-modelos.md#quién-está-detrás-de-cada-modelo--contexto-y-origen-agregado-2026-08-26) — resumen aplicado acá:

**Qwen 2.5 Coder 7B lo hace Alibaba Cloud** (China) — es la variante especializada en programación de la familia Qwen (una de las más prolíficas y con licencias más permisivas del mundo open-weight, Apache 2.0), lo cual además no restringe el uso (ver la tabla completa en `../../../ia-local/docs/02-modelos.md`).

## Candidato principal: Qwen 2.5 Coder 7B

Identificado mediante datos reales de willitrunai.com (filtro "Coding"), navegado con el motor de navegador real disponible en este entorno — no es una recomendación genérica, está evaluada específicamente contra las alternativas que caben en 12GB de VRAM.

| Modelo | VRAM (Q4) | Contexto | Nota |
|---|---|---|---|
| **Qwen 2.5 Coder 7B** (elegido) | ~4,3GB | **131K** | Grado B en el benchmark del sitio, pero contexto muy superior al resto |
| StarCoder 7B | similar | mucho menor | Grado más alto, contexto corto |
| DevStral 7B | similar | mucho menor | Grado más alto, contexto corto |
| CodeLlama 7B/13B | similar/mayor | mucho menor | Grado más alto, contexto corto |
| Qwen3-Coder 30B A3B (ya mencionado en `ia-local/docs/02-modelos.md`) | 14,9GB | — | **No cabe** en 12GB — descartado para este equipo específico |

## Por qué Qwen 2.5 Coder 7B y no la opción de mayor "grado"

Varias alternativas (StarCoder, DevStral, CodeLlama) tienen una calificación de benchmark ligeramente más alta, pero con ventanas de contexto mucho más cortas. Para trabajo de programación real — leer un archivo completo, seguir el hilo de varias funciones relacionadas, mantener contexto de una conversación larga de depuración — el contexto de 131K pesa más en la práctica que un par de puntos extra de benchmark. Ver `../ia-local/docs/01-conceptos-fundamentales.md` §7 (cómo leer benchmarks sin creérselos literalmente) — este es exactamente ese caso: no tomar el "grado" más alto como la decisión automática sin mirar qué mide y qué no mide.

## Verificación con datos reales de esta GPU exacta (2026-08-26, willitrunai.com/es/can-run/qwen-2.5-coder-7b-on-rtx-5070-12gb)

A diferencia de la investigación anterior (que solo tenía datos de RTX 4070/3060 12GB con *otro* modelo, Qwen3.6-27B, como proxy), el sitio tiene una página calculada específicamente para **Qwen 2.5 Coder 7B en RTX 5070 12GB** — coincide exactamente con el hardware de este proyecto. **Nota:** sigue siendo una estimación del sitio (modelo matemático propio, no una medición hecha en el equipo real), pero ya no requiere extrapolar desde otra GPU.

| Dato | Valor |
|---|---|
| Veredicto | **"YES — Runs Great"**, grado A (78/100, "Great") |
| VRAM total requerida (Q4_K_M) | **7,5 GB de 12,0 GB (63% usado)** — Pesos 4,3GB + KV cache 0,9GB + runtime 1,2GB + margen 1,2GB |
| Velocidad (decode) | **98,0 tok/s** |
| TTFT (time to first token) | 1976 ms |
| **Contexto seguro real** | **100K** (no los 131K teóricos del modelo — 100K es lo que realmente cabe con margen en 12GB) |
| Workload "Coding" específico | Grado A, "Runs well" (sin offload), 98,0 tok/s, TTFT 1976ms, contexto 100K |

Los 5 workloads evaluados (Chat/Coding/Agentic Coding/Reasoning/RAG) dan **"Runs well" en los 5, sin ningún offload** — a diferencia de otras opciones de esta misma GPU (ver comparación abajo), este modelo no fuerza ningún compromiso.

### Detalle de cuantización en esta GPU exacta

El sitio marca **Q8_0 (7,5GB, calidad "Very High", Fit A/74) como "BEST FOR YOUR GPU"** — no Q4_K_M. Con 12GB disponibles y el modelo completo en Q8_0 ocupando solo 7,5GB, hay margen de sobra para subir la calidad sin comprometer el ajuste. **Cambio de recomendación:** partir probando **Q8_0** en vez de Q4_K_M — mejor calidad al mismo costo práctico de VRAM en este equipo específico (con Q4_K_M a 4,3GB sigue quedando aún más margen, útil si se corre el stack de RAG completo en la misma tarjeta).

### Comparación con la alternativa generalista Qwen 3.5 9B (misma GPU, mismo sitio)

El sitio lista alternativas evaluadas para esta misma RTX 5070 12GB ("More models your RTX 5070 12GB can run"):

| Modelo | Grado | Decode (dato oficial de la FAQ del sitio) | VRAM total | Contexto seguro |
|---|---|---|---|---|
| Qwen 3.5 9B (generalista) | **S (94, "Excellent")** | 77,1 tok/s | 9,8GB (82% usado) | 32K — y con offload en Agentic Coding/RAG |
| **Qwen 2.5 Coder 7B (elegido)** | A (78, "Great") | 98,0 tok/s | 7,5GB (63% usado) | **100K**, sin offload en ningún workload |

**Nota de precisión (2026-08-26):** el widget interactivo de la página mostraba 82,9 tok/s para Qwen 3.5 9B en un recuadro ("DECODE"), inconsistente con el resto de la página (tabla por workload y FAQ, ambos en 77,1). Se verificó contra los datos estructurados (schema.org FAQPage) que el propio sitio expone — ahí el número oficial es **77,1 tok/s**, igual al de la tabla de workloads. Para Qwen 2.5 Coder 7B no hubo esa inconsistencia (98,0 tok/s en todos lados). Se usa 77,1 como el dato correcto.

Qwen 3.5 9B saca mejor grado general, pero eso es "grado" de ajuste/calidad global, no específico de código — en el workload "Coding" puntual, Qwen 3.5 9B da 77,1 tok/s con TTFT 2511ms, más lento que Qwen 2.5 Coder 7B (98,0 tok/s), y con un tercio del contexto útil (32K vs 100K) y bastante más VRAM ocupada. **Se mantiene la elección de Qwen 2.5 Coder 7B** — sigue siendo la mejor opción para el caso de uso específico (programación con contexto largo), ahora confirmado con datos de la GPU exacta, no solo por analogía.

## Qué esperar en la práctica, por tipo de operación (en este equipo exacto)

Los números de arriba (98 tok/s, 100K de contexto) no dicen por sí solos qué se puede hacer con esto. Acá se traduce a expectativas concretas, separado por tipo de tarea — para no llegar a instalar sin saber qué pedirle ni qué no pedirle.

### Primero, una calibración importante: 7B no es 32B

El anuncio oficial de Qwen2.5-Coder (qwen.ai/blog, 2024-11-11) dice que **Qwen2.5-Coder-32B-Instruct** iguala a GPT-4o en generación y reparación de código — ese es el modelo insignia de la familia, no el que se instala acá. El propio equipo de Qwen declara una **"correlación positiva entre tamaño y desempeño"** validada en sus propias pruebas entre los 6 tamaños. Qwen 2.5 Coder 7B **hereda la misma arquitectura, los mismos datos de entrenamiento (5,5 billones de tokens) y el mismo enfoque**, pero con una fracción de la capacidad bruta del 32B — es capaz y rápido para lo que este equipo puede correr, no es "un GPT-4o gratis en 12GB". Cualquier expectativa debe calibrarse contra el 7B, no contra los titulares de marketing del 32B.

### Qué tan rápido se siente 98 tok/s

Un token no es exactamente una palabra, pero en español/código ronda 0,7-1 palabra por token. **98 tok/s ≈ 70-90 palabras por segundo** — mucho más rápido de lo que cualquier persona puede leer (una persona lee cómodo unas 3-5 palabras por segundo). En la práctica: la respuesta se genera visiblemente más rápido de lo que se puede leer, el cuello de botella pasa a ser el usuario, no el modelo. El TTFT (~2 segundos para pedir código, hasta ~3,6-4,5s si hay mucho contexto de RAG de por medio) es la única espera real — el tiempo antes de que empiece a aparecer la primera palabra.

### Qué tan lejos llegan los 100K de contexto

100.000 tokens de contexto seguro equivalen, muy aproximado (varía mucho según lenguaje y densidad del código), a **unas 1.500-2.500 líneas de código típico**, o varios archivos medianos a la vez. Alcanza para: un archivo grande completo, varios archivos relacionados de un mismo módulo, o una conversación de depuración larga sin que el modelo "olvide" el principio. No alcanza para un repositorio completo de tamaño mediano/grande de una sola vez — para eso hace falta RAG (recuperar solo las partes relevantes) en vez de meter todo el proyecto en el contexto.

### Por tipo de operación

| Operación | Qué esperar en este equipo | Qué NO esperar |
|---|---|---|
| **Chat / consultas generales** | Respuestas casi instantáneas (98 tok/s, TTFT ~1s), buena base de conocimiento general heredada de Qwen2.5 (el modelo "mantiene sus fortalezas en matemáticas y competencias generales", según Hugging Face) | Un modelo de propósito general tan pulido como uno 10x más grande — para chat puro sin código, Qwen 3.5 9B (ver comparación arriba) da mejor grado |
| **Autocompletado y generación de código** | Rápido y confiable en tareas acotadas: funciones, clases, snippets, boilerplate, en más de 40 lenguajes (dato oficial del anuncio) | Que resuelva de una sola vez un problema de arquitectura complejo o un algoritmo muy novedoso — ahí la brecha con el 32B/modelos frontier se nota más |
| **Reparación de errores (debugging)** | Bueno explicando y corrigiendo errores puntuales con el archivo/función a la vista — la línea Coder está entrenada específicamente en "code repair" | No reemplaza probar el código — sigue pudiendo alucinar una corrección que no compila; siempre correr y verificar |
| **Depuración con contexto largo** | Gracias a los 100K de contexto, puede seguir el hilo de varias funciones/archivos relacionados sin perder de vista el inicio de la conversación | Cargar un proyecto entero de una vez y esperar que "entienda todo" — mejor acotar a los archivos relevantes |
| **Agentic coding (tareas de varios pasos, tipo agente)** | "Runs well" según los datos verificados (sin offload) — puede sostener flujos de varios pasos (leer → proponer cambio → explicar) | Que actúe sin supervisión en cambios grandes — es un asistente, no un ingeniero autónomo; requiere revisión humana en cada paso, igual que cualquier LLM |
| **RAG sobre documentación/código propio** | "Runs well" también, con más margen de espera (TTFT más alto cuando hay mucho contexto recuperado inyectado) — sirve para responder preguntas sobre documentación indexada del área de TI | La calidad depende tanto del modelo como de qué tan bien está armado el índice (embeddings, chunking) — un mal RAG da mala respuesta aunque el modelo sea bueno (ver `../ia-local/docs/01-conceptos-fundamentales.md` §3) |
| **Español** | El modelo declara amplio soporte de idiomas (familia Qwen, 100+ idiomas a nivel Qwen3.6), pero el benchmark de código citado es en inglés | No hay benchmark propio verificado de calidad en español para esta variante — queda como ítem a probar en `../pruebas/01-plan-pruebas.md`, no asumir que rinde igual que en inglés |

## Modelo de embeddings (para el RAG de prueba)

**BGE-M3** (ver `../ia-local/docs/02-modelos.md` § "Modelos de embeddings") — liviano (<1GB), multilingüe, no compite de forma relevante por la VRAM que ya usa el modelo generativo. Con Qwen 2.5 Coder 7B en Q8_0 usando 7,5GB, quedan ~4,5GB libres en la tarjeta — de sobra para BGE-M3 corriendo en la misma GPU sin desalojar al modelo generativo.

## Qué queda pendiente de confirmar con uso real

- [x] Velocidad estimada específica de esta GPU exacta (no proxy) — resuelto 2026-08-26: 98,0 tok/s en Q4_K_M según willitrunai.com. **Sigue pendiente la medición real de primera mano** una vez instalado (ver `../pruebas/resultados.md`) — el sitio mismo aclara que son estimaciones, no mediciones.
- [ ] Calidad real en español y en el tipo de código que se use en la práctica — el benchmark "Coding" del sitio de referencia es en inglés.
- [x] Contexto usable en la práctica — resuelto: 100K de contexto seguro confirmado por el sitio para esta GPU exacta (no los 131K teóricos), sin necesidad de reducirlo manualmente.
- [ ] Probar Q8_0 (recomendado como "best for your GPU") contra Q4_K_M en tareas reales — confirmar si la mejora de calidad se nota en la práctica antes de fijarlo como cuantización definitiva.
- [x] **Hallazgo resuelto en profundidad (2026-08-26, actualizado 2026-08-27):** la página oficial de Ollama lista el contexto de este modelo como **32K** — inicialmente se pensó que era solo el default empaquetado en el Modelfile. **Investigado a fondo el `config.json` real del modelo (`huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct/raw/main/config.json`): `max_position_embeddings` es literalmente `32768` — 32K es el contexto con el que el modelo fue entrenado, no un límite artificial.** Los 131K/128K citados como "contexto completo" requieren activar **YaRN** explícitamente (`rope_scaling` en el config, confirmado textual en la ficha oficial) — no vienen activados de fábrica, y Ollama todavía no expone soporte formal de YaRN (solo parámetros RoPE de bajo nivel, ver `github.com/ollama/ollama/issues/11871`). **Implicación real, no solo de configuración:** subir `OLLAMA_CONTEXT_LENGTH` por encima de 32K sin YaRN no da error, pero es esperable que **degrade la calidad** de las respuestas que realmente usan ese contexto extra (documentado como principio general: contexto extendido vía RoPE sin re-entrenar rinde peor que el nativo). El estimado de "100K seguro" de willitrunai.com parece ser capacidad de VRAM (cuánto cabe la caché KV), no una garantía de que el modelo razone bien a esa distancia. **`11-prueba-estres.ps1` ahora tiene que medir calidad a distintos tamaños de contexto, no solo si "no se cae"** — ver `../referencia/02-qwen-2.5-coder-7b.md` para el detalle completo. Tags exactos confirmados para instalar: `qwen2.5-coder:7b` (4,7GB) y `qwen2.5-coder:7b-instruct-q8_0` (8,1GB).
- [x] **Re-chequeado si hay algo más nuevo/chico que reemplace la elección (2026-08-27):** verificado contra el repositorio oficial de GitHub (`github.com/QwenLM/Qwen3-Coder`) — la línea Qwen3-Coder **no tiene ninguna variante bajo los 30B** (solo existen `Qwen3-Coder-480B-A35B-Instruct`, `Qwen3-Coder-30B-A3B-Instruct` y `Qwen3-Coder-Next`, este último construido sobre una base de 80B). No salió nada intermedio que calce mejor en 12GB desde la elección original. **La decisión se mantiene: Qwen 2.5 Coder 7B sigue siendo la mejor opción de la familia Qwen para este equipo**, no por falta de revisión sino porque no existe (todavía) un Qwen3-Coder de tamaño chico.
