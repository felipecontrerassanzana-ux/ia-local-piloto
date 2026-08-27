# Open WebUI — referencia completa

La interfaz web de este piloto (ver `../herramientas/motor-alternativas.md` para la decisión). Este documento cubre la configuración real de RAG — y un hallazgo importante: **tal como estaba el script de instalación, Open WebUI nunca quedaba conectado a Qdrant ni a BGE-M3**, ya corregido. Verificado contra la documentación oficial (`docs.openwebui.com/reference/env-configuration`), 2026-08-27.

## Hallazgo real: el RAG corría con los defaults de fábrica, no con lo que este piloto instala

Open WebUI trae más de 200 variables de entorno — sin configurarlas explícitamente, usa sus propios valores por defecto:

- **`VECTOR_DB`** — default `chroma` (ChromaDB embebido), no `qdrant`. Opciones válidas incluyen `qdrant`, `milvus`, `pgvector`, entre otras.
- **`RAG_EMBEDDING_MODEL`** — default `sentence-transformers/all-MiniLM-L6-v2` (se descarga solo, un modelo de embeddings distinto), **no** `bge-m3`.
- **`RAG_EMBEDDING_ENGINE`** — vacío por defecto usa SentenceTransformers local; hay que poner `ollama` explícitamente para que use un modelo servido por Ollama (como BGE-M3).

`scripts/07-desplegar-openwebui.ps1` instalaba Open WebUI y por separado se instalaban Qdrant (`06-desplegar-qdrant.ps1`) y BGE-M3 (`03-descargar-modelo.ps1`) — pero nada los conectaba entre sí. Sin las variables correctas, Open WebUI habría usado su ChromaDB interno y su propio modelo de embeddings, ignorando en silencio las dos piezas que este piloto instala específicamente para el RAG.

**Corregido:** `07-desplegar-openwebui.ps1` ahora fija estas variables a nivel de sistema antes de (re)iniciar el servicio:

```
VECTOR_DB=qdrant
QDRANT_URI=http://localhost:6333
RAG_EMBEDDING_ENGINE=ollama
RAG_EMBEDDING_MODEL=bge-m3
RAG_OLLAMA_BASE_URL=http://localhost:11434
```

`verificar-instalacion.ps1` ahora chequea estas dos variables explícitamente, para que este error no pase desapercibido en una instalación futura.

## Otras variables relevantes para este piloto

| Variable | Para qué |
|---|---|
| `OLLAMA_BASE_URL` | Default ya correcto para uso nativo: `http://localhost:11434` — no hace falta tocarla (el default de Docker sería distinto, `host.docker.internal`, pero acá no aplica). |
| `DATA_DIR` | Dónde vive la base de datos de usuarios/chats y los archivos subidos — ya configurado por el script a `C:\OpenWebUIData` (ver `../arquitectura/almacenamiento.md`). |
| `RAG_TOP_K` | Cuántos resultados trae la búsqueda por similitud para inyectar en el prompt — default `3`. Ajustar si las respuestas de RAG se sienten con poco contexto recuperado. |
| `WEBUI_SECRET_KEY` | Clave para firmar sesiones — la propia doc recomienda "siempre fijarla a un valor seguro en producción". No crítico para un solo usuario local, pero vale la pena fijarla si se expone por Cloudflare Tunnel (ver `../operacion/acceso-remoto.md`). |
| `DATABASE_URL` | Permite usar Postgres en vez de SQLite — no aplica a este piloto (un solo usuario, SQLite alcanza, ver `../herramientas/como-funcionan-los-agentes.md` § SQLite). |

## Fuentes consultadas (2026-08-27)

- [Environment Configuration — Open WebUI Docs](https://github.com/open-webui/docs/blob/main/docs/reference/env-configuration.mdx) — referencia completa de variables de entorno.
- [RAG — Open WebUI Docs](https://docs.openwebui.com/features/chat-conversations/rag/) — configuración de fuentes de conocimiento externas.
