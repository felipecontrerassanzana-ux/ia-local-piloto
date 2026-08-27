# Referencia

Material de estudio por herramienta/modelo — para tener dominio completo de cada pieza del stack, no solo saber instalarla. Cada archivo cubre: qué es, el set de comandos/API que trae, mejores prácticas de uso, y para qué sirve en la práctica. Verificado contra documentación oficial, no de memoria entrenada.

Distinto de las otras carpetas de `docs/`: ahí está **la decisión tomada para este piloto** (por qué este modelo, por qué esta herramienta); acá está **cómo dominar la herramienta en sí**, útil incluso si mañana se cambia de decisión.

- **`ollama.md`** — el motor de inferencia: CLI completo, API REST, variables de entorno de rendimiento (Flash Attention, cuantización de KV cache, concurrencia), y cómo se relacionan con el resto del stack.
- **`qwen-2.5-coder-7b.md`** — el modelo instalado: parámetros de generación recomendados, cómo prompearlo bien para código, y un hallazgo real sobre el límite de contexto (32K vs 100K/131K, YaRN).
- **`qwen-code.md`** — comandos reales de Qwen Code, más allá de la tabla de paridad con Claude Code — incluye un hallazgo que podría formalizar de fábrica el loop de la capa de diseño (`/model --vision`/`--image`).
- **`goose.md`** — comandos reales de Goose, y su equivalente a los comandos personalizados de Qwen Code (Recipes).
- **`open-webui.md`** — configuración real de RAG, incluye un hallazgo importante: sin configurar explícitamente, Open WebUI ignoraba a Qdrant/BGE-M3 y usaba sus defaults internos (ya corregido en `07-desplegar-openwebui.ps1`).
- **`qdrant.md`** — conceptos básicos (colecciones, puntos, vectores) y API, para cuando haga falta un pipeline de RAG propio más allá de lo que ya gestiona Open WebUI.

*(en construcción — próximo: Qwen3-VL, ComfyUI, Tailscale/Cloudflare)*
