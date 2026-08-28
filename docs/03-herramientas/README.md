# Herramientas

El modelo no tiene memoria propia ni sabe programar solo — esto cubre qué herramientas se usan alrededor de él, cómo funcionan por dentro, y qué alternativas se evaluaron.

- **`01-herramientas-trabajo.md`** — qué herramientas usar para programar de forma efectiva (Goose, Qwen Code, Continue.dev, Aider) y cómo se resuelve la memoria persistente en la práctica (Auto-memory de Qwen Code de fábrica, `AGENTS.md`/reglas estáticas como respaldo, Mem0 descartado por ahora).
- **`02-qwen-code-a-fondo.md`** — qué funciones de Qwen Code sacan más provecho al modelo instalado (Plan Mode, SubAgents, contexto largo, Auto-memory, cruzado contra los números reales de `../02-modelo/02-modelo-elegido.md`), y los tres modos de conexión posibles: mismo equipo, misma red de casa, y remoto fuera de la red (Tailscale recomendado).
- **`03-como-funcionan-los-agentes.md`** — cómo funcionan por dentro Goose y Qwen Code (ciclo de vida de sesión, qué archivo de contexto lee cada uno, MCP, subagentes, skills, continuidad de sesión ante corte de luz) — para entender el motor y los addons, no solo instalarlos.
- **`04-motor-alternativas.md`** — alternativas a Ollama si el piloto necesita más funciones que solo código (LocalAI para voz/imagen/visión, LM Studio como GUI, Open WebUI como interfaz web).
