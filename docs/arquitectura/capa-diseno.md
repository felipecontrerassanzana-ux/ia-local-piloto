# Capa de diseño: por qué el frontend siempre "queda cojo" y cómo se resuelve acá

El motor de código (Qwen 2.5 Coder 7B) puede generar una app completa y funcional, pero el frontend tiende a quedar débil frente al resto — la razón de fondo no es falta de una herramienta puntual, es que **es un modelo de solo texto**: puede escribir HTML/CSS que compile, pero no tiene forma de "ver" si el resultado se ve bien. Esta página documenta cómo se cierra esa brecha en este piloto, sin tocar el modelo de código ya elegido. Verificado contra documentación/repos oficiales, 2026-08-27.

## Las tres piezas del pack

1. **`DESIGN.md`** (raíz del repo) — contrato de diseño que Qwen Code/Goose leen, igual que `AGENTS.md`. Define qué sistema de componentes usar (Tailwind+shadcn/ui para web, Fluent UI para escritorio nativo), para que el agente **ensamble** en vez de **inventar** estilo visual.
2. **`qwen3-vl:4b`** (modelo de visión, vía Ollama) — el revisor. Confirmado publicado oficialmente en `ollama.com/library/qwen3-vl` (3,3GB, contexto 256K, entrada texto+imagen) — se instala igual que cualquier otro modelo de Ollama (`ollama pull qwen3-vl:4b`, ya agregado a `scripts/03-descargar-modelo.ps1`).
3. **ComfyUI + Stable Diffusion 1.5** (`scripts/15-instalar-comfyui.ps1`) — el generador, para cuando hace falta un asset custom que no existe en la librería de componentes (un ícono específico, una ilustración).

## Por qué ComfyUI y no AUTOMATIC1111

AUTOMATIC1111 es la opción más conocida, pero su propio README exige **Python 3.10.6 exacto** ("newer version of Python does not support torch") — choca directo con el Python 3.12 que ya instala `12-instalar-herramientas-dev.ps1` para el resto del proyecto, obligando a mantener dos instalaciones de Python separadas. ComfyUI resuelve esto con un **build portable** que trae su propio Python empaquetado (`github.com/Comfy-Org/ComfyUI/releases`, ~2GB, .7z) — nada que instalar aparte salvo 7-Zip para extraerlo. De paso, ComfyUI está confirmado como más eficiente en GPUs de VRAM chica que AUTOMATIC1111.

## Por qué Stable Diffusion 1.5 (no SDXL, no Flux)

Es la opción de menor VRAM entre los modelos de generación de imágenes viables hoy (4-5GB reportado en general; el checkpoint fp16 concreto usado acá pesa ~2,1GB en disco). El origen del archivo (`runwayml/stable-diffusion-v1-5`) fue dado de baja por RunwayML en Hugging Face — se usa el mirror mantenido por el propio equipo de ComfyUI (`huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive`), que preserva el mismo hash que el original, no una versión modificada por terceros.

## La regla de oro: el modelo de código no se toca

Felipe fue explícito en esto: la cuantización de Qwen 2.5 Coder 7B (Q4_K_M o Q8_0, lo que se confirme con la prueba real) **no se reduce ni se cambia** para hacerle espacio a estas piezas nuevas. La forma de resolverlo no es competir por VRAM, es **nunca necesitar estar los tres cargados a la vez**:

- Ollama carga y descarga modelos automáticamente según se usan — `qwen3-vl:4b` entra a VRAM solo cuando se le pide una revisión, y sale después.
- ComfyUI **no se registra como servicio de inicio automático** (a diferencia de Qdrant/Open WebUI) — se abre a mano solo cuando hace falta generar un asset, y se cierra después. Si quedara corriendo de fondo con el checkpoint cargado, competiría por VRAM con el modelo de código todo el tiempo, no solo cuando se usa.
- El costo real de este diseño es **latencia de intercambio** (unos segundos al cambiar de tarea), no falta de espacio — ver `almacenamiento.md` para por qué eso además cambió dónde viven los modelos en disco (NVMe, no HDD).

## El loop: generar → revisar → corregir

1. Qwen Code/Goose genera o modifica una pantalla (web o escritorio), siguiendo `DESIGN.md`.
2. Se saca una captura del resultado renderizado — para web, con Playwright (ya disponible en este entorno de trabajo); para una app de escritorio nativa, con una captura de la ventana (a definir el mecanismo exacto cuando se llegue a ese caso concreto).
3. La captura se le pasa a `qwen3-vl:4b` junto con las reglas de `DESIGN.md`, pidiendo que señale problemas concretos (contraste, elementos que se salen del contenedor, inconsistencia con el sistema de componentes elegido).
4. El feedback vuelve a Qwen Code/Goose, que corrige.
5. Si falta un asset que no existe en el sistema de componentes (un ícono, una ilustración), se genera con ComfyUI (API en `http://localhost:8188/prompt` una vez abierto) antes de continuar.

**Pendiente de formalizar:** empaquetar este loop como una Skill invocable por nombre (Qwen Code y Goose soportan Skills, ver `../herramientas/como-funcionan-los-agentes.md`) — no se armó todavía porque no se verificó el formato exacto de archivo que usa cada herramienta para definir una Skill propia. Por ahora queda como procedimiento documentado en esta página, aplicable a mano.

## Presupuesto de VRAM (con el modelo de código protegido)

| Modelo | VRAM | ¿Cuándo carga? |
|---|---|---|
| Qwen 2.5 Coder 7B | 4,3-7,5GB según cuantización | Residente mientras se programa (uso principal) |
| Qwen3-VL 4B | 3,3GB | Solo durante una revisión puntual |
| Stable Diffusion 1.5 (vía ComfyUI) | ~4-5GB | Solo mientras ComfyUI está abierto generando algo |

Cada uno entra solo en los 12GB por separado — nunca hace falta que los tres convivan a la vez.

## Qué falta

- [ ] Correr `scripts/15-instalar-comfyui.ps1` en el equipo real y confirmar tiempos de generación reales (no medidos todavía, nada se ha ejecutado en el equipo piloto).
- [ ] Definir el mecanismo de captura de pantalla para el caso de app de escritorio nativa (el caso web con Playwright ya está resuelto).
- [ ] Formalizar el loop generar→revisar→corregir como Skill real, una vez verificado el formato de Skills de Qwen Code/Goose.
- [ ] Medir en la práctica si 100K de contexto (una vez confirmado) alcanza para incluir capturas + reglas de diseño + código sin degradar la respuesta.

## Fuentes consultadas (2026-08-27)

- [Qwen3-VL tags — Ollama](https://ollama.com/library/qwen3-vl/tags) — confirma `qwen3-vl:4b` publicado oficialmente, 3.3GB.
- [ComfyUI — Releases en GitHub](https://github.com/Comfy-Org/ComfyUI/releases) — build portable para Windows/NVIDIA.
- [AUTOMATIC1111/stable-diffusion-webui — README](https://github.com/AUTOMATIC1111/stable-diffusion-webui) — confirma el requisito de Python 3.10.6 exacto.
- [Comfy-Org/stable-diffusion-v1-5-archive — Hugging Face](https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive) — mirror oficial del checkpoint original de RunwayML, dado de baja en 2024.
