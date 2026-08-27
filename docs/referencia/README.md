# Referencia

Material de estudio por herramienta/modelo — para tener dominio completo de cada pieza del stack, no solo saber instalarla. Cada archivo cubre: qué es, el set de comandos/API que trae, mejores prácticas de uso, y para qué sirve en la práctica. Verificado contra documentación oficial, no de memoria entrenada.

Distinto de las otras carpetas de `docs/`: ahí está **la decisión tomada para este piloto** (por qué este modelo, por qué esta herramienta); acá está **cómo dominar la herramienta en sí**, útil incluso si mañana se cambia de decisión.

- **`ollama.md`** — el motor de inferencia: CLI completo, API REST, variables de entorno de rendimiento (Flash Attention, cuantización de KV cache, concurrencia), y cómo se relacionan con el resto del stack.
- **`qwen-2.5-coder-7b.md`** — el modelo instalado: parámetros de generación recomendados, cómo prompearlo bien para código, límites reales conocidos.

*(en construcción — próximo: Qwen Code, Goose, después el resto del stack)*
