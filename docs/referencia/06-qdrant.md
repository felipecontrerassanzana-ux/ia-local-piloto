# Qdrant — referencia completa

La base vectorial de este piloto (ver `../arquitectura/03-docker-y-recursos.md` para la decisión de correrlo nativo). Este documento cubre los conceptos básicos y la API — útil sobre todo si en algún momento se arma un pipeline de RAG propio además de lo que ya usa Open WebUI. Verificado contra `qdrant.tech/documentation`, 2026-08-27.

## Conceptos básicos

| Concepto | Qué es |
|---|---|
| **Colección** | Un conjunto con nombre de "puntos" (vectores + metadata) sobre los que se puede buscar — el contenedor principal. |
| **Punto** | Un vector + su metadata asociada (el "payload" — ej. el texto original, la fuente del documento). |
| **Vector** | La representación numérica que genera el modelo de embeddings (BGE-M3 en este piloto). Todos los vectores de una misma colección deben tener la misma dimensión. |
| **Métrica de distancia** | Cómo se mide "similitud" entre vectores — Qdrant soporta coseno, producto punto, euclidiana y Manhattan. Coseno es la más común para embeddings de texto. |

## API básica (Python, vía `qdrant-client`)

```python
from qdrant_client import QdrantClient, models

client = QdrantClient(url="http://localhost:6333")

# Crear una colección
client.create_collection(
    collection_name="mi_coleccion",
    vectors_config=models.VectorParams(size=1024, distance=models.Distance.COSINE),
)
```

**Nota de dimensión para este piloto:** BGE-M3 genera vectores de **1024 dimensiones** — al crear una colección propia (fuera de lo que ya gestiona Open WebUI automáticamente), `size` tiene que ser `1024`, no un valor genérico copiado de un ejemplo con otro modelo de embeddings.

```python
# Insertar/actualizar puntos
client.upsert(collection_name="mi_coleccion", points=[...])

# Buscar
client.search(collection_name="mi_coleccion", query_vector=[...], limit=10)
```

## Panel de administración

Con Qdrant corriendo nativo (`06-desplegar-qdrant.ps1`), el dashboard web está en `http://localhost:6333/dashboard` — permite ver colecciones, contar puntos, y probar búsquedas sin escribir código. Útil para confirmar que Open WebUI efectivamente está guardando algo ahí (ver `05-open-webui.md` — antes de la corrección del 2026-08-27, Open WebUI usaba ChromaDB en vez de esto, así que el dashboard de Qdrant habría aparecido vacío aunque el RAG "funcionara" con otro motor por debajo).

## Cuándo esto importa más allá de Open WebUI

Si en algún momento se arma un pipeline de RAG propio (no a través de la interfaz de Open WebUI, sino un script/app propio que consulte directo), esta es la API a usar — mismo Qdrant, mismo puerto (6333 HTTP, 6334 gRPC), sin instalar nada nuevo.

## Fuentes consultadas (2026-08-27)

- [Collections — Qdrant Docs](https://qdrant.tech/documentation/concepts/collections/) — conceptos y ejemplos de API.
