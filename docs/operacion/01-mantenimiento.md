# Plan de mantenimiento y continuidad

Formulado a pedido explícito de Felipe ("tiene que estar todo en orden y actualizado") — no basta con decir "revisar cada tanto", esto deja el procedimiento concreto: qué se revisa, con qué frecuencia, y cómo se recupera el servicio si algo falla.

## 1. Continuidad tras un reinicio o corte de luz

**Situación real (2026-08-26):** no hay UPS todavía (queda como mejora futura, ver más abajo). Mientras tanto, la resiliencia se arma con dos piezas que sí se pueden dejar listas ahora:

- **BIOS configurada para "restaurar último estado" (Restore on AC Power Loss / Power On After Power Failure):** el equipo vuelve a encender solo apenas vuelve la luz, sin necesitar que alguien presione el botón de encendido. Esto es responsabilidad de configurar una sola vez en el setup de la BIOS/UEFI.
- **Todos los servicios deben arrancar solos al iniciar Windows, sin necesitar que alguien inicie sesión:**
  - `cloudflared` tiene un instalador de servicio nativo (`cloudflared service install`) — queda como servicio de Windows, arranca con el sistema.
  - Ollama, al instalarse en Windows, ya se registra para iniciar con el sistema por defecto — confirmar que esa opción quede activa.
  - Open WebUI (si se corre vía Docker): configurar el contenedor con política de reinicio `--restart unless-stopped` (o `always`), y que Docker Desktop (o el motor de contenedores que se use) también inicie con Windows.
  - **Monitor de estado** (agregado 2026-08-27, ver `03-monitor-estado.md`): Tarea Programada `Monitor-Estado-Local`, mismo patrón que Qdrant/Open WebUI — arranca con Windows, corre como `SYSTEM`.
- **Brecha real que esto no cubre:** durante el corte de luz en sí, el servicio está caído (no hay UPS que lo mantenga andando sin interrupción) — la garantía es que se recupera solo apenas vuelve la energía, no que nunca se cae.

**Mejora futura (no ahora):** sumar un UPS chico cuando se pueda — eliminaría la brecha de arriba (el equipo seguiría andando durante cortes breves, y con software de gestión de UPS se podría hacer un apagado ordenado si el corte se alarga). Anotado como pendiente, no bloquea nada de lo planeado hoy.

## 2. Backup

**Destino confirmado:** una carpeta de Google Drive personal (de Felipe, no un Drive del trabajo — este es un proyecto personal, ver `README.md`).

**Qué respaldar (lo que no está en git, ver `../arquitectura/01-arquitectura-piloto.md` punto 4):**
- Base de datos de Open WebUI (cuentas, historial de conversaciones, API keys).
- Índice de Qdrant (colecciones del RAG).
- `.continue/rules` una vez que tenga contenido real (aunque esto podría además versionarse en este mismo repo git si se quiere).

**Mecanismo simple para partir:** una tarea programada de Windows (Task Scheduler) que copie esas carpetas a una ruta sincronizada con Google Drive (ej. si se usa la app de escritorio de Drive, apuntar a esa carpeta local sincronizada) — con frecuencia semanal es razonable para el volumen de uso de un piloto. No hace falta nada más sofisticado (versionado, cifrado especial) mientras no haya datos sensibles de terceros involucrados.

## 3. Actualizaciones — el "P5" formulado

Revisión mensual (ej. el primer fin de semana de cada mes), checklist fijo:

- [ ] **Ollama:** revisar versión instalada vs. la última disponible, actualizar si hay una nueva.
- [ ] **Modelo (Qwen 2.5 Coder):** revisar en `../ia-local/docs/02-modelos.md` o directamente en Ollama/Hugging Face si salió una versión nueva de la familia Qwen Coder — la familia se actualiza seguido (ver historia en `../modelo/01-fundamentacion-modelo.md`), vale la pena revisar aunque no se migre de inmediato.
- [ ] **Goose:** revisar cambios (`goose-docs.ai` tiene changelog) y actualizar.
- [ ] **Continue.dev:** se actualiza solo como cualquier extensión de VS Code, solo confirmar que no quedó desactivada la actualización automática.
- [ ] **cloudflared:** revisar versión, actualizar (Cloudflare publica actualizaciones de seguridad con cierta frecuencia).
- [ ] **Open WebUI:** revisar changelog oficial antes de actualizar (a veces cambian variables de entorno o requieren migración de base de datos) — no actualizar a ciegas.
- [ ] **Qwen3-VL, ComfyUI:** revisar si salió una versión más chica/mejor del revisor visual o del motor de imágenes (agregado 2026-08-27) — mismo criterio que el modelo de código, la familia de modelos de visión también evoluciona seguido.
- [ ] **Confirmar que el backup semanal (punto 2) efectivamente se está generando** — revisar que el archivo más reciente en Drive tenga fecha de la semana, no asumir que "está andando" sin mirar.
- [ ] **Confirmar que los servicios siguen configurados para iniciar solos** (punto 1) — sobre todo después de cualquier actualización grande de Windows, que a veces resetea configuraciones de inicio.
- [ ] **Revisar el monitor de estado** (`http://localhost:8090/`, ver `03-monitor-estado.md`) — de hecho, este chequeo mensual es exactamente para lo que existe: un vistazo rápido en vez de revisar cada pieza a mano.

## 4. Costos — confirmado que toda la estructura es gratuita (2026-08-26)

A pedido explícito de Felipe, se revisó cada pieza del stack (ver `../arquitectura/01-arquitectura-piloto.md` para el diagrama completo):

| Pieza | Costo | Nota |
|---|---|---|
| Ollama | Gratis, open-source | Sin límites de uso local |
| Qwen 2.5 Coder 7B | Gratis, Apache 2.0 | Sin restricción de uso comercial |
| Goose | Gratis, open-source (Linux Foundation) | |
| Qwen Code | Gratis, open-source (Alibaba/Qwen) | Incluye Auto-memory sin costo adicional |
| Continue.dev | Gratis para uso local con Ollama | Sin necesidad de cuenta para esto |
| Aider | Gratis, open-source | |
| Open WebUI | Gratis, self-hosted | Los planes "Enterprise" son solo para soporte/SLA/branding — el uso normal no los necesita |
| BGE-M3 (embeddings) | Gratis, open-source | |
| Qdrant | Gratis, self-hosted | (existe una versión cloud paga, no es la que se usa acá) |
| Mem0 (si se llega a sumar) | Gratis, self-hosted | (existe una versión cloud paga, no es la que se usaría acá) |
| Qwen3-VL 4B | Gratis, pesos abiertos | Revisor visual de diseño, vía Ollama |
| ComfyUI | Gratis, open-source | Motor de generación de imágenes |
| Stable Diffusion 1.5 | Gratis, pesos abiertos (mirror de Comfy-Org) | Checkpoint de generación de imágenes |
| **Cloudflare Tunnel** | **Gratis**, sin costo aparte | Verificado 2026-08-26, incluido en cualquier cuenta de Cloudflare |
| **Cloudflare Access** | **Gratis hasta 50 usuarios** | Verificado 2026-08-26 en la página oficial de precios — un solo usuario está muy por debajo del límite |
| **Tailscale** | **Gratis** (plan Personal) | Verificado 2026-08-27 en la página oficial de precios: hasta 6 usuarios, dispositivos ilimitados — usado para conectar Qwen Code/Goose remotos, ver `../herramientas/02-qwen-code-a-fondo.md` |
| Monitor de estado | Gratis | PowerShell puro (`System.Net.HttpListener`, parte de .NET/Windows) — sin librería ni servicio de terceros, ver `03-monitor-estado.md` |
| Dominio propio | Ya lo tiene Felipe (costo hundido, no nuevo) | |

**No hay ninguna pieza de este stack que tenga costo recurrente nuevo.** El único gasto es el que ya existía (el dominio) y, a futuro si se decide, un UPS (hardware, compra única).
