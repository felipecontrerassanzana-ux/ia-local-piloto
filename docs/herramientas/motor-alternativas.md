# Alternativas a Ollama (motor de inferencia)

El plan de instalación parte con Ollama por ser lo más simple para arrancar (ver `../ia-local/docs/arquitectura.md`), pero el usuario quiere que este piloto cumpla **distintas funciones**, no solo servir un modelo de código. Esto evalúa qué tan lejos llega Ollama y qué alternativas existen si se necesita más — verificado contra documentación oficial de cada proyecto (2026-08-26).

## Ollama — qué cubre y dónde se queda corto

Cubre bien: servir un modelo de texto (chat/código) vía API compatible OpenAI, gestión simple de modelos (`ollama pull`/`run`). **Se queda corto en:** un solo tipo de función (solo texto/chat) — no genera imágenes, no transcribe audio, no hace texto-a-voz, sin eso hay que sumar otro proceso aparte para cada función nueva.

## Alternativas evaluadas

### LocalAI — la opción para "distintas funciones" reales

**Verificado en localai.io:** open-source, licencia MIT, un solo binario con **API compatible con OpenAI, Anthropic, Ollama y ElevenLabs** — herramientas ya configuradas para Ollama pueden apuntar acá con solo cambiar la URL. El motor detrás de la API es intercambiable (llama.cpp, vLLM, MLX, SGLang) según lo que pida cada modelo, sin que el cliente note la diferencia.

Funciones que cubre, todas desde el mismo runtime:
- **REASON** — modelos de lenguaje, tool calling, salida estructurada (esto es lo que hoy cubre Ollama).
- **LISTEN** — voz en tiempo real, transcripción, diarización (whisper, parakeet).
- **SPEAK** — síntesis de voz y clonación de voz (piper, moss-tts).
- **SEE** — visión, detección, reconocimiento, profundidad/3D.
- **CREATE** — imágenes, video, música (diffusers, ace-step).
- **ACT** — agentes, MCP, RAG, herramientas interactivas.

Corre con o sin GPU (cada función tiene camino de CPU probado), soporta CUDA (relevante para la RTX 5070 de este equipo). **Es la opción a evaluar si "distintas funciones" incluye algo más que texto/código** — ej. generar imágenes para documentación, transcribir audio de reuniones, etc.

### LM Studio — la opción de interfaz gráfica

**Verificado en lmstudio.ai:** cierra el hueco de "gestionar modelos sin usar la terminal" — interfaz gráfica de escritorio, con servidor local que expone API compatible **tanto OpenAI como Anthropic** (esto último es poco común, permite usar herramientas pensadas para Claude apuntando al modelo local), modo headless/servicio para dejarlo corriendo sin la ventana abierta, soporte de MCP. Es de código cerrado (gratis para uso personal, no para redistribuir).

### Otras mencionadas (no verificadas en profundidad esta vez, quedan para evaluar si hace falta)

- **text-generation-webui (oobabooga):** muy extensible por plugins (incluye extensiones de imagen/voz), popular en la comunidad de código abierto.
- **vLLM:** ya evaluado en `../ia-local/docs/arquitectura.md` — se justifica solo con concurrencia real de varios usuarios, no es la prioridad de este piloto todavía.

## Capa de interfaz encima del motor: Open WebUI

Independiente de qué motor se use abajo (Ollama o LocalAI, ambos hablan API compatible OpenAI), **Open WebUI** es la interfaz web estándar de la comunidad open-source para esto — confirmado en docs.openwebui.com:

- Interfaz tipo chat en el navegador, multi-usuario, con **RAG incorporado** (subir documentos y consultarlos, sin armar el pipeline a mano si no se necesita algo más custom).
- Se conecta a Ollama, OpenAI, Anthropic, vLLM "y más" — no ata este piloto a un solo motor.
- Historial de conversaciones incorporado — ya mencionado en `../ia-local/docs/arquitectura.md` como posible solución de logging sin construir nada aparte.

**Hallazgo nuevo, para explorar más adelante (no adoptar todavía):** Open WebUI ahora tiene un producto hermano más nuevo, **"Open WebUI Computer"** — un agente que opera directo sobre archivos/terminal/git de la máquina real, con acceso por navegador (incluso desde el celular) ya incorporado. Se ve prometedor para exactamente lo que se está buscando (multi-función + acceso remoto), pero es un producto que "se mueve más rápido" (en desarrollo activo) y no se verificó todavía cómo funciona su acceso remoto por dentro (si depende de una cuenta/servicio de terceros o es 100% local) — **no recomendar sin esa verificación**, dado que el diseño de este proyecto prioriza que todo quede local. Ver `../operacion/acceso-remoto.md` para la solución ya verificada mientras tanto.

## Decisión final (2026-08-26, cerrada)

**Motor: Ollama.** El uso principal confirmado de este equipo es programación (ver `README.md`) — para eso, Ollama tiene mejor soporte directo en las herramientas ya evaluadas (Continue.dev y Aider documentan `ollama`/`ollama_chat` como integración de primera clase, sin capas extra). Es más simple de instalar y mantener que LocalAI, que suma alcance (voz/imagen/visión) a costa de más piezas moviéndose.

**Escalamiento (no ahora, solo si se necesita de verdad):** migrar a LocalAI si aparece una necesidad real y concreta de otra función (imágenes, voz) — no antes. El costo de migrar después es bajo porque LocalAI habla el mismo tipo de API (Ollama-compatible) — las herramientas ya configuradas solo necesitarían apuntar a otra URL, no reconfigurarse desde cero. Mismo criterio que ya se aplicó con el hardware: no sumar alcance/infraestructura antes de que el uso real lo pida (ver [[feedback-no-sobredimensionar]]).

**Open WebUI** se suma de todas formas como interfaz web — no depende de si el motor es Ollama o LocalAI, y es la pieza que se expone por el acceso remoto (ver `../operacion/acceso-remoto.md`).
