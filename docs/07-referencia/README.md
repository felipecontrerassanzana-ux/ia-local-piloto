# Referencia

Material de estudio por herramienta/modelo — para tener dominio completo de cada pieza del stack, no solo saber instalarla. Cada archivo cubre: qué es, el set de comandos/API que trae, mejores prácticas de uso, y para qué sirve en la práctica. Verificado contra documentación oficial, no de memoria entrenada.

Distinto de las otras carpetas de `docs/`: ahí está **la decisión tomada para este piloto** (por qué este modelo, por qué esta herramienta); acá está **cómo dominar la herramienta en sí**, útil incluso si mañana se cambia de decisión.

- **`01-ollama.md`** — el motor de inferencia: CLI completo, API REST, variables de entorno de rendimiento (Flash Attention, cuantización de KV cache, concurrencia), y cómo se relacionan con el resto del stack.
- **`02-qwen-2.5-coder-7b.md`** — el modelo instalado: parámetros de generación recomendados, cómo prompearlo bien para código, y un hallazgo real sobre el límite de contexto (32K vs 100K/131K, YaRN).
- **`03-qwen-code.md`** — comandos reales de Qwen Code, más allá de la tabla de paridad con Claude Code — incluye un hallazgo que podría formalizar de fábrica el loop de la capa de diseño (`/model --vision`/`--image`).
- **`04-goose.md`** — comandos reales de Goose, y su equivalente a los comandos personalizados de Qwen Code (Recipes).
- **`05-open-webui.md`** — configuración real de RAG, incluye un hallazgo importante: sin configurar explícitamente, Open WebUI ignoraba a Qdrant/BGE-M3 y usaba sus defaults internos (ya corregido en `07-desplegar-openwebui.ps1`).
- **`06-qdrant.md`** — conceptos básicos (colecciones, puntos, vectores) y API, para cuando haga falta un pipeline de RAG propio más allá de lo que ya gestiona Open WebUI.
- **`07-qwen3-vl.md`** — el revisor visual de la capa de diseño: variantes descargables, por qué el contexto grande no es relevante acá, y cómo se invoca desde Qwen Code (`/model --vision`).
- **`08-comfyui.md`** — el generador de assets: la particularidad de su API (workflow JSON, no texto), cómo generar una imagen por HTTP, y por qué no queda como servicio de fondo.
- **`09-tailscale.md`** — acceso remoto a los agentes de código: comandos reales, por qué no hace falta `serve`/`funnel` en el camino principal, y el paso que Tailscale por sí solo no resuelve (`OLLAMA_HOST`).
- **`10-cloudflare.md`** — Tunnel remotely-managed + Access: cómo se agrega una ruta nueva, comandos de servicio en Windows, y Service Tokens para clientes no interactivos.
