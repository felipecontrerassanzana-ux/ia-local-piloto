# Ollama — referencia completa

El motor de inferencia de este piloto. Este documento cubre el CLI completo, la API REST, y — lo más importante para este equipo puntual — las variables de entorno de rendimiento que no están cubiertas en otros documentos del proyecto. Verificado contra la documentación oficial (`github.com/ollama/ollama/tree/main/docs`), 2026-08-27.

## CLI — comandos completos

| Comando | Qué hace |
|---|---|
| `ollama run <modelo>` | Descarga si falta y abre un chat interactivo. `ollama run <modelo> ""` (prompt vacío) precarga el modelo en VRAM sin generar nada — útil para "calentar" el modelo antes de necesitarlo. |
| `ollama pull <modelo>` | Descarga sin ejecutar. |
| `ollama rm <modelo>` | Elimina un modelo del disco. |
| `ollama ls` (o `ollama list`) | Lista los modelos descargados. |
| `ollama ps` | Lista los modelos **cargados en VRAM ahora mismo** — el comando clave para verificar qué está consumiendo memoria en un momento dado, central para el diseño de intercambio de modelos de `../01-arquitectura/02-capa-diseno.md`. |
| `ollama stop <modelo>` | Descarga el modelo de VRAM inmediatamente, sin esperar el timeout de inactividad. |
| `ollama show --modelfile <modelo>` | Muestra la configuración completa de un modelo (parámetros, plantilla, sistema). |
| `ollama create <nombre> -f Modelfile` | Crea una variante personalizada de un modelo (ver sección Modelfile abajo). |
| `ollama cp <origen> <destino>` | Duplica un modelo con otro nombre. |
| `ollama serve` | Arranca el servidor manualmente (normalmente ya corre como app de bandeja del sistema en Windows). `ollama serve --help` lista las variables de entorno disponibles. |
| `ollama launch` | Configura integraciones con agentes de código externos de forma interactiva. **Verificado 2026-08-27: solo soporta OpenCode, Claude Code, Codex, VS Code y Droid — no incluye Qwen Code ni Goose todavía**, así que para este piloto la configuración de `~/.qwen/settings.json` sigue siendo manual (ver `13-instalar-qwen-code.ps1`). |

## API REST (puerto 11434 por defecto)

| Endpoint | Para qué |
|---|---|
| `POST /api/generate` | Completado de texto simple (un prompt, una respuesta). |
| `POST /api/chat` | Conversación multi-turno — acepta `messages[]`, soporta `tools` para function-calling. Es lo que usan Qwen Code/Goose/Open WebUI por debajo. |
| `POST /api/embed` | Genera embeddings — lo que usa BGE-M3 para el RAG. |
| `GET /api/tags` | Lista modelos descargados (equivalente API de `ollama ls`). |
| `GET /api/ps` | Modelos cargados en VRAM (equivalente API de `ollama ps`) — útil para un script propio que quiera chequear el estado antes de pedir algo pesado. |
| `POST /api/show` | Detalle de un modelo (Modelfile, parámetros, licencia). |
| `POST /api/pull` | Descarga programática. |

Todos los endpoints de streaming aceptan `"stream": false` para una respuesta única en vez de streaming.

## `keep_alive` — la perilla que más importa para el diseño de intercambio de modelos

Por defecto, **un modelo queda cargado en VRAM 5 minutos después de la última consulta**, después se descarga solo. Esto se puede controlar de dos formas:

- **Por request:** el parámetro `keep_alive` en `/api/generate` o `/api/chat` — acepta una duración (`"10m"`), segundos, `0` (descargar apenas termina de responder), o un número negativo (`-1`, mantener cargado indefinidamente).
- **Global:** la variable de entorno `OLLAMA_KEEP_ALIVE` al arrancar el servidor, mismo formato — la sobreescribe el parámetro por request si ambos están presentes.

**Aplicado a este piloto:** el modelo de código (uso más frecuente) se beneficia de un `keep_alive` largo o `-1` para no perder tiempo recargándolo entre preguntas seguidas; `qwen3-vl:4b` y cualquier uso puntual del generador de imágenes se benefician de dejar el default (5 min) o incluso `0` si se quiere liberar VRAM apenas termina la revisión, para que el modelo de código no tenga que esperar a que expire el timeout del otro.

## Variables de entorno de rendimiento — no cubiertas en otros documentos del proyecto

Encontradas al investigar esto a fondo (2026-08-27) — relevantes directamente para sostener de forma eficiente los **32K reales de entrenamiento** de este modelo en 12GB de VRAM (ver `../02-modelo/02-modelo-elegido.md`; los 100K/131K originales quedaron descartados como meta salvo que se active YaRN, no expuesto por Ollama todavía):

- **`OLLAMA_FLASH_ATTENTION=1`** — Ollama la activa sola si el modelo/hardware la soportan, pero se puede forzar. Reduce el uso de memoria a medida que crece el contexto — directamente relevante para sostener los 32K sin agotar VRAM.
- **`OLLAMA_KV_CACHE_TYPE`** — cuantización de la caché KV (contexto), default `f16`. `q8_0` usa la mitad de memoria que `f16` "con una pérdida de precisión muy pequeña, normalmente sin impacto notable en la calidad" (textual de la doc oficial). `q4_0` usa un cuarto, con más pérdida. **Advertencia textual de la propia doc: "modelos con un conteo de GQA alto (ej. Qwen2) pueden ver un impacto mayor en precisión por la cuantización"** — Qwen está nombrado explícitamente como una familia sensible a esto, así que conviene probar `q8_0` primero (no `q4_0` de entrada) y verificar calidad antes de confiar en él para el contexto largo.
- **`OLLAMA_MAX_LOADED_MODELS`** (default: 3× GPUs) y **`OLLAMA_NUM_PARALLEL`** (default: 1) — controlan cuántos modelos pueden estar cargados a la vez y cuántas consultas paralelas procesa cada uno. Relevante si en algún momento dos personas usan el equipo a la vez (ver la restricción ya documentada de "uso compartido" en `AGENTS.md`).
- **`OLLAMA_ORIGINS`** — qué orígenes web pueden llamar a la API sin CORS — relevante solo si se construye algo propio en el navegador que hable directo con Ollama (no aplica al uso actual vía Open WebUI/Qwen Code/Goose).

**Pendiente de aplicar en la práctica:** agregar `OLLAMA_FLASH_ATTENTION=1` y probar `OLLAMA_KV_CACHE_TYPE=q8_0` como parte de `11-prueba-estres.ps1`, para ver si ayudan a sostener los 32K de contexto real sin perder calidad — no confirmado todavía, nada se ha ejecutado en el equipo real.

## Modelfile — crear una variante propia en vez de repetir parámetros

Un `Modelfile` es un archivo de texto que define un modelo personalizado a partir de uno base — útil para no tener que pasar los mismos parámetros cada vez (contexto, temperatura, system prompt):

```text
FROM qwen2.5-coder:7b
PARAMETER num_ctx 32000
PARAMETER temperature 0.7
SYSTEM Sos un asistente de programación local, respondé en español salvo que el código lo requiera en inglés.
```

Se construye con `ollama create qwen-coder-100k -f Modelfile` y después se usa como cualquier otro modelo (`ollama run qwen-coder-100k`). Esto es una alternativa a configurar `OLLAMA_CONTEXT_LENGTH` globalmente (`02-configurar-ollama.ps1`) — la ventaja de un Modelfile es que el valor queda atado a un nombre de modelo específico, no afecta a todos los modelos que corran en el servidor.

## Dónde se guarda todo

- Modelos: carpeta definida por `OLLAMA_MODELS` (en este piloto, el NVMe — ver `../01-arquitectura/04-almacenamiento.md`).
- El servidor escucha por defecto solo en `127.0.0.1:11434` — `OLLAMA_HOST` lo cambia (usado en este piloto vía el switch `-PermitirRed` de `02-configurar-ollama.ps1`, ver `../03-herramientas/02-qwen-code-a-fondo.md`).

## Fuentes consultadas (2026-08-27)

- [CLI Reference](https://github.com/ollama/ollama/blob/main/docs/cli.mdx)
- [API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [FAQ](https://github.com/ollama/ollama/blob/main/docs/faq.mdx) — `keep_alive`, concurrencia, Flash Attention, cuantización de KV cache.
- [Modelfile Reference](https://github.com/ollama/ollama/blob/main/docs/modelfile.mdx)
