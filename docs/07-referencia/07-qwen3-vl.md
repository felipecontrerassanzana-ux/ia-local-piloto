# Qwen3-VL — referencia completa (el revisor visual)

En este piloto, Qwen3-VL cumple un solo rol: el revisor de la capa de diseño (ver `../01-arquitectura/02-capa-diseno.md`) — la pieza que "ve" si el frontend generado por el modelo de código realmente se ve bien. Este documento no cubre las capacidades generales de Qwen3-VL (video, grounding 3D, uso de computadora como agente) porque no se usan acá — solo lo relevante para revisar capturas de pantalla contra `DESIGN.md`. Verificado contra `ollama.com/library/qwen3-vl` y su pestaña de tags, 2026-08-27.

## Variante instalada en este piloto

Ya agregado a `scripts/pasos/03-descargar-modelo.ps1`: `qwen3-vl:4b` (equivale a `4b-instruct-q4_K_M`).

| Tag | Tamaño | Nota |
|---|---|---|
| `qwen3-vl:4b` | 3,3GB | Alias del `4b-instruct` — el que instala este piloto |
| `4b-instruct-q4_K_M` | 3,3GB | Mismo peso que el alias de arriba |
| `4b-instruct-q8_0` | 5,1GB | Más precisión, sigue cabiendo cómodo en 12GB junto al modelo de código (ver presupuesto de VRAM abajo) |
| `4b-instruct-bf16` | 8,9GB | Sin cuantizar — no evaluado para este piloto, deja poco margen si tuviera que convivir con otra cosa |
| `4b-thinking-*` (mismos tres niveles) | Igual peso que su contraparte no-thinking | Razona paso a paso antes de responder — podría dar mejor detección de problemas visuales a costa de más latencia; no probado todavía en este piloto |

## Por qué el contexto de 256K (hasta 1M) no es relevante acá

A diferencia del modelo de código, donde el límite real de contexto es una preocupación central (ver `02-qwen-2.5-coder-7b.md`), acá no aplica: una revisión de diseño son una captura + las reglas de `DESIGN.md`, muy por debajo de cualquier límite práctico. El contexto grande de Qwen3-VL es una característica de la familia, no algo que este piloto necesite explotar.

## Capacidades relevantes para el loop de revisión

- **Revisión de capturas de UI** — el uso principal: señalar contraste insuficiente, elementos que se salen del contenedor, inconsistencia con el sistema de componentes.
- **OCR (32 idiomas, según la doc oficial)** — útil como chequeo adicional de que el texto en la interfaz generada es legible, no solo que "existe".
- **Grounding 2D (cajas delimitadoras)** — podría usarse para que el feedback señale la coordenada exacta del problema, no solo lo describa en texto; no explotado todavía en el comando `.qwen/commands/diseno/revisar.md` (ver `03-qwen-code.md`).

No usadas en este piloto (parte del modelo, pero fuera del rol de revisor de diseño): comprensión de video, grounding 3D, tareas de agente visual sobre una pantalla completa.

## Cómo se invoca en este piloto

**Vía Qwen Code (camino ya resuelto):** `/model --vision qwen3-vl:4b` en `~/.qwen/settings.json` configura el modelo puente de visión — Qwen Code lo invoca solo cuando se le pasa una imagen, sin pasos manuales aparte (ver `03-qwen-code.md` y `../01-arquitectura/02-capa-diseno.md`).

**Vía API directa de Ollama (para un script propio, si hiciera falta fuera de Qwen Code):** mismo endpoint `POST /api/chat` de `01-ollama.md`, agregando un arreglo `images` (strings en base64) a cada mensaje — es la única diferencia respecto de usar el modelo de código por API.

## VRAM y por qué no compite con el modelo de código

Carga solo durante una revisión puntual y se descarga sola (mismo mecanismo de `keep_alive` de `01-ollama.md`) — el detalle completo del presupuesto de VRAM de las tres piezas de la capa de diseño ya está en `../01-arquitectura/02-capa-diseno.md`, no se duplica acá. Si se nota que el `keep_alive` por defecto (5 minutos) deja el modelo de visión ocupando VRAM más tiempo del necesario entre revisiones espaciadas, se puede fijar `keep_alive: 0` en la llamada para liberarlo apenas responde.

## Qué falta confirmar en la práctica

- Si `q4_K_M` (el default instalado) detecta bien los problemas de diseño reales, o si conviene pasar a `q8_0` (5,1GB, sigue cabiendo cómodo) — no probado todavía, nada se ha ejecutado en el equipo real.
- Si vale la pena probar una variante `-thinking` para revisiones más exigentes, a costa de más latencia.
- Si `/model --image` de Qwen Code puede apuntar a ComfyUI de forma compatible — pregunta abierta documentada en `../01-arquitectura/02-capa-diseno.md`, no en este documento (ese es un tema de ComfyUI, ver `08-comfyui.md`).

## Fuentes consultadas (2026-08-27)

- [Qwen3-VL — Ollama library](https://ollama.com/library/qwen3-vl)
- [Qwen3-VL — tags](https://ollama.com/library/qwen3-vl/tags)
- [Commands — Qwen Code Docs](https://github.com/QwenLM/qwen-code/blob/main/docs/users/features/commands.md) — confirma `/model --vision`.
