# ComfyUI — referencia completa (el generador de assets)

En este piloto, ComfyUI cumple un solo rol: generar un asset visual puntual (un ícono, una ilustración) que no existe en el sistema de componentes elegido en `DESIGN.md`, usando el checkpoint de Stable Diffusion 1.5 ya definido en `15-instalar-comfyui.ps1` (ver `../01-arquitectura/02-capa-diseno.md`). Este documento no es un manual general de ComfyUI — cubre el workflow real de este piloto: cómo se abre, cómo se genera una imagen por API, y cómo se cierra para no competir por VRAM con el modelo de código. Verificado contra `docs.comfy.org`, 2026-08-27.

## Cómo se abre y se cierra (a propósito, manual)

A diferencia de Qdrant/Open WebUI, ComfyUI **no se registra como servicio de inicio automático** — se abre corriendo `run_nvidia_gpu.bat` dentro de la carpeta de instalación (por defecto `C:\ComfyUI\`, ver `15-instalar-comfyui.ps1`), queda escuchando en `http://localhost:8188`, y se cierra la ventana apenas se termina de generar. Esto es intencional: si quedara corriendo de fondo con el checkpoint cargado, competiría todo el tiempo por VRAM con el modelo de código (ver la regla de oro en `../01-arquitectura/02-capa-diseno.md`).

## La particularidad de su API: el "prompt" es un grafo, no texto

A diferencia de Ollama (`POST /api/generate` con un string), ComfyUI **no tiene un endpoint simple de "texto a imagen"** — lo que se envía a `POST /prompt` es el workflow completo en formato JSON (todos los nodos del grafo: carga de checkpoint, sampler, decodificador VAE, etc., con sus valores). Esto es el motivo por el que la pregunta abierta en `../01-arquitectura/02-capa-diseno.md` sobre si ComfyUI puede exponerse compatible con `/model --image` de Qwen Code sigue sin confirmarse — no es un endpoint tipo OpenAI de imágenes, es una API de automatización de grafos.

**Flujo práctico para usarla desde código (no desde la interfaz):**

1. Armar el workflow una vez en la interfaz web de ComfyUI (`http://localhost:8188`), con el checkpoint `v1-5-pruned-emaonly-fp16.safetensors` ya descargado.
2. Exportarlo en **"Save (API Format)"** — este es el JSON que se reutiliza por API, distinto del archivo de workflow normal que abre la interfaz.
3. Ese JSON se guarda en el repo (pendiente de hacer una vez se corra ComfyUI en el equipo real) para no tener que rearmarlo cada vez.

## API HTTP — endpoints relevantes

| Endpoint | Para qué |
|---|---|
| `POST /prompt` | Encola un workflow para ejecutar. Body: `{"prompt": <workflow en formato API>, "client_id": "<uuid>"}`. Devuelve un `prompt_id`. |
| `GET /history/{prompt_id}` | Consulta si terminó y el resultado (nombres de archivo de las imágenes generadas, con metadata). |
| `GET /view?filename=...&subfolder=...&type=...` | Descarga la imagen ya generada, usando los datos que devolvió `/history`. |
| WebSocket (`ws://localhost:8188/ws?clientId=...`) | Progreso en vivo durante la generación — alternativa a hacer polling de `/history`; no necesario para un uso puntual de generar un solo asset. |

**Ejemplo mínimo (Python), adaptado a este piloto:**

```python
import json, urllib.request, uuid

SERVER = "127.0.0.1:8188"
client_id = str(uuid.uuid4())

with open("mi-workflow-api-format.json") as f:
    workflow = json.load(f)

body = json.dumps({"prompt": workflow, "client_id": client_id}).encode("utf-8")
req = urllib.request.Request(f"http://{SERVER}/prompt", data=body)
resp = json.loads(urllib.request.urlopen(req).read())
prompt_id = resp["prompt_id"]

# Luego, hacer polling a /history/{prompt_id} hasta que aparezca,
# y bajar la imagen con /view usando el filename que devuelve.
```

## Dónde vive todo

- Instalación y checkpoint: en el NVMe (`C:\ComfyUI\` por defecto, parámetro `-LetraNVMe` de `15-instalar-comfyui.ps1`) — mismo criterio de almacenamiento que el resto del stack, ver `../01-arquitectura/04-almacenamiento.md`.
- Checkpoint exacto: `ComfyUI\models\checkpoints\v1-5-pruned-emaonly-fp16.safetensors` (~2,1GB) — mirror mantenido por el equipo de ComfyUI en Hugging Face, mismo hash que el original de RunwayML dado de baja (ver `../01-arquitectura/02-capa-diseno.md` para el porqué).

## Qué falta confirmar en la práctica

- Correr `15-instalar-comfyui.ps1` en el equipo real y medir tiempos de generación reales — no medido todavía, nada se ha ejecutado en el equipo piloto.
- Armar y exportar el primer workflow en formato API (paso 1-2 de arriba) — no hecho todavía.
- Confirmar si ComfyUI puede exponerse compatible con `/model --image` de Qwen Code — pregunta abierta, documentada también en `../01-arquitectura/02-capa-diseno.md`.

## Fuentes consultadas (2026-08-27)

- [Server Overview — ComfyUI Docs](https://docs.comfy.org/development/comfyui-server/comms_overview)
- [API Examples — ComfyUI Docs](https://docs.comfy.org/development/comfyui-server/api-examples)
- [ComfyUI — Releases en GitHub](https://github.com/Comfy-Org/ComfyUI/releases)
