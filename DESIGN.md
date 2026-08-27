# Reglas de diseño para cualquier app generada en este equipo

Este archivo define cómo debe verse el frontend de cualquier app que se construya con Qwen Code/Goose en este equipo — la idea es que el "look" quede consistente y de calidad desde el primer prompt, sin que cada proyecto nuevo invente su propio estilo. Ver `docs/arquitectura/capa-diseno.md` para el razonamiento completo detrás de esto.

## Regla principal

**No inventar estilos visuales desde cero.** El motor de código (Qwen 2.5 Coder 7B) es bueno generando lógica, pero un modelo de este tamaño tiende a producir un diseño genérico si se le pide "hacé que se vea bien" sin más contexto. En vez de eso: ensamblar la interfaz con un sistema de componentes ya diseñado, elegido según el tipo de proyecto.

## Qué sistema usar, según el tipo de proyecto

- **App web (HTML/React/lo que sea basado en navegador):** Tailwind CSS + shadcn/ui. Componentes ya accesibles y con buen contraste por defecto — copiar/adaptar componentes existentes de la librería en vez de escribir CSS desde cero.
- **App de escritorio con tecnología web por dentro (Electron/Tauri):** mismo criterio que arriba — es HTML/CSS por debajo, aplica Tailwind + shadcn/ui igual.
- **App de escritorio nativa de Windows (WinUI/WPF):** Fluent UI (el sistema de diseño oficial de Microsoft) — no inventar controles propios cuando los nativos ya existen y se sienten "de Windows".

## Paleta y tipografía por defecto (ajustar por proyecto si hace falta, pero no dejarlo en blanco)

- Paleta neutra con un color de acento — no usar más de 2-3 colores principales.
- Tipografía del sistema por defecto (`system-ui`/Segoe UI en Windows) salvo que el proyecto pida algo específico — evita depender de una fuente externa que no esté garantizada en el equipo donde corra la app.
- Espaciado consistente (usar la escala de espaciado que trae Tailwind/Fluent, no números arbitrarios).

## Revisión visual antes de dar por terminado

Cualquier pantalla nueva generada debe pasar por el loop de revisión con `qwen3-vl:4b` antes de darse por lista — screenshot del resultado renderizado, comparado contra estas reglas. Ver `docs/arquitectura/capa-diseno.md` § "El loop generar → revisar → corregir" para el procedimiento exacto.

## Generación de assets custom (íconos, ilustraciones)

Si hace falta un gráfico que no existe en la librería de componentes (un ícono específico, una ilustración), usar ComfyUI + Stable Diffusion 1.5 (`scripts/pasos/15-instalar-comfyui.ps1`) — no pedirle al modelo de código que "dibuje" algo en SVG a mano salvo que sea geométricamente simple (un ícono de línea básico sí, una ilustración compleja no).

## Qué no hacer

- No pedir "hacé un diseño bonito" sin especificar el sistema de componentes — es la forma más segura de terminar con algo genérico.
- No mezclar sistemas de diseño distintos en el mismo proyecto (ej. Tailwind en una pantalla y Fluent en otra).
- No saltarse la revisión visual en pantallas que el usuario final va a ver — sí se puede saltar en herramientas internas/de un solo uso.
