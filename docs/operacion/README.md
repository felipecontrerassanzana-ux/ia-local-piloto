# Operación

Cómo se mantiene el piloto funcionando una vez instalado: continuidad, backup, actualizaciones, y acceso remoto por navegador.

- **`01-mantenimiento.md`** — continuidad tras corte de luz (sin UPS por ahora), backup a Drive personal, checklist mensual de actualizaciones, y confirmación de que toda la estructura es gratuita.
- **`02-acceso-remoto.md`** — cómo acceder por navegador desde afuera sin IP fija (Cloudflare Tunnel + dominio propio), con la condición real de este equipo (fibra Movistar 800 megas, sin IP fija). Distinto del acceso remoto de agentes de código (Qwen Code/Goose), que vive en `../herramientas/02-qwen-code-a-fondo.md`.
- **`03-monitor-estado.md`** — dashboard/JSON de estado en tiempo real (Ollama, Qdrant, Open WebUI, GPU, discos, backup, etc.), corriendo todo el tiempo como un servicio más, alcanzable local, por Tailscale, o por internet (agregando una segunda ruta al mismo túnel de Cloudflare).
