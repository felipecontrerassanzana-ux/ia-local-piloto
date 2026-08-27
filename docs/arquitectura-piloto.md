# Arquitectura completa de este piloto

Este documento junta en un solo lugar todas las decisiones ya tomadas y dispersas en los demás archivos — es el "esquema estructural del montaje" del proyecto, para no tener que reconstruirlo leyendo documento por documento. Cada pieza enlaza al documento que la fundamenta en detalle.

## Diagrama del stack completo

```
                                    ┌─────────────────────────────┐
                                    │   Usuario (Felipe, remoto)   │
                                    │   navegador o celular        │
                                    └──────────────┬───────────────┘
                                                    │ HTTPS
                                                    ▼
                                    ┌─────────────────────────────┐
                                    │  Cloudflare Access           │  ← gate 1: verifica el correo
                                    │  (lista de correos autorizados)│    autorizado antes de dejar pasar
                                    └──────────────┬───────────────┘
                                                    │
                                    ┌─────────────────────────────┐
                                    │  Cloudflare Tunnel           │  ← conexión saliente desde la casa,
                                    │  (cloudflared, dominio propio)│    sin exponer el router
                                    └──────────────┬───────────────┘
                                                    │
════════════════════════════════════ red de la casa (Movistar 800 megas, sin CGNAT) ═══════════════
                                                    │
                                                    ▼
                                    ┌─────────────────────────────┐
                                    │  Open WebUI                  │  ← gate 2: login propio (correo/clave,
                                    │  (interfaz web, RAG, historial)│   se cierra solo tras el primer usuario)
                                    └──────────────┬───────────────┘
                                                    │ API compatible OpenAI
                                                    ▼
                                    ┌─────────────────────────────┐
                                    │  Ollama                      │
                                    │  Qwen 2.5 Coder 7B (Q4_K_M/Q8_0)│
                                    │  OLLAMA_CONTEXT_LENGTH configurado│
                                    └──────────────┬───────────────┘
                                                    │
                                    ┌─────────────────────────────┐
                                    │  Stack RAG                   │
                                    │  BGE-M3 (embeddings) + Qdrant │
                                    └───────────────────────────────┘

   (en paralelo, uso LOCAL — no pasa por el túnel ni necesita login)
                                    ┌─────────────────────────────┐
   Felipe, en el equipo mismo  ───▶ │  Goose (agente CLI/desktop)   │──┐
   o VS Code local             ───▶ │  Qwen Code (ext., con memoria)│──┤──▶ Ollama (mismo servidor de arriba)
                                    │  Continue.dev (si hace falta) │──┘
                                    └──────────────┬──────────────┘
                                                    │ capa de diseño, bajo demanda
                                                    │ (nunca compite por VRAM con el coder)
                                                    ▼
                                    ┌─────────────────────────────┐
                                    │  qwen3-vl:4b (revisor visual) │  ← vía Ollama, entra/sale solo
                                    │  ComfyUI + SD 1.5 (generador) │  ← app aparte, no auto-inicia
                                    └─────────────────────────────┘
```

## Piezas y de dónde sale cada decisión

| Capa | Decisión | Documento fuente |
|---|---|---|
| Hardware | RTX 5070 12GB / 16GB RAM / Ryzen 5 3600 | `hardware-real.md` |
| Modelo | Qwen 2.5 Coder 7B (Q4_K_M para partir, probar Q8_0) | `modelo-elegido.md`, `fundamentacion-modelo.md` |
| Motor de inferencia | Ollama (LocalAI como escalón futuro si hace falta voz/imagen) | `motor-alternativas.md` |
| Interfaz web + RAG | Open WebUI — **nativo vía pip, no Docker** (puerto 8080) | `motor-alternativas.md`, `docker-y-recursos.md` |
| Agente para iniciar/gestionar proyectos | Goose | `herramientas-trabajo.md` |
| Asistente dentro del editor | Qwen Code (memoria automática incluida) + Continue.dev/Aider si hace falta algo adicional | `herramientas-trabajo.md` |
| Memoria persistente | Auto-memory de Qwen Code (automática, de fábrica). Respaldo estático: `AGENTS.md`/`.continue/rules`. Mem0 descartado por ahora | `herramientas-trabajo.md` |
| Red / acceso remoto (navegador) | Cloudflare Tunnel + dominio propio (sin CGNAT confirmado) | `acceso-remoto.md` |
| Red / acceso remoto (Qwen Code/Goose) | Tailscale — red privada, conecta directo al puerto de Ollama sin exponerlo a internet | `qwen-code-a-fondo.md` |
| Autenticación | Open WebUI (automática) + Cloudflare Access (correo autorizado) para navegador; Tailscale (identidad de dispositivo) para agentes remotos | `acceso-remoto.md`, `qwen-code-a-fondo.md` |
| Embeddings | BGE-M3 | `../ia-local/docs/modelos.md` |
| Base vectorial | Qdrant — **nativo, binario oficial de Windows, no Docker** | `plan-instalacion.md`, `docker-y-recursos.md` |
| Capa de diseño (revisión visual) | `qwen3-vl:4b` vía Ollama — entra/sale de VRAM bajo demanda, nunca compite con el modelo de código | `capa-diseno.md` |
| Capa de diseño (generación de assets) | ComfyUI + Stable Diffusion 1.5 — **no** inicia con Windows a propósito, se abre solo cuando hace falta | `capa-diseno.md` |
| Almacenamiento de modelos | **NVMe**, no HDD (corregido 2026-08-27 — los modelos se intercambian varias veces por sesión) | `almacenamiento.md` |
| Continuidad, backup y actualizaciones | BIOS auto-encendido + servicios en inicio, backup a Drive, checklist mensual | `mantenimiento.md` |

## Puntos proactivos — estado tras las respuestas de Felipe (2026-08-26)

- [x] **¿Equipo exclusivo o compartido?** Resuelto: uso compartido, no exclusivo. Ollama libera la VRAM cuando no está en uso, así que no compite de forma permanente — el riesgo real es de continuidad (si alguien más reinicia/apaga el equipo, el piloto se cae con él), no de recursos. Ver `hardware-real.md`.
- [x] **Sistema operativo:** resuelto 2026-08-26 — Windows 11 Pro 25H2. Ver `plan-instalacion.md` y `almacenamiento.md` (dos discos: NVMe + HDD, con guía de qué va en cada uno).
- [~] **Ancho de banda de subida:** Felipe cree que el plan es "800 sincrónico" (simétrico) — se toma como supuesto de trabajo razonable, no bloqueante; queda como verificación de baja prioridad (ver `acceso-remoto.md`).
- [x] **Continuidad tras reinicio/corte de luz:** resuelto arquitectónicamente — BIOS configurada para reencender solo tras un corte, todos los servicios (`cloudflared`, Ollama, Open WebUI) configurados para iniciar con el sistema sin necesitar sesión abierta. No hay UPS todavía (mejora futura). Detalle completo en `mantenimiento.md` §1.
- [x] **Backup:** resuelto — carpeta de Google Drive personal, mecanismo y qué respaldar detallado en `mantenimiento.md` §2.
- [x] **Actualizaciones (el "P5"):** formulado en detalle como checklist mensual en `mantenimiento.md` §3, ya no es una idea vaga.
- [ ] **Protección contra abuso a nivel de red (rate limiting en Cloudflare):** sigue pendiente de activar, no requiere nada nuevo (ya se cuenta con Cloudflare por el Tunnel).

**Costos — confirmado 2026-08-26/27 que toda la estructura es gratuita**, pieza por pieza (tabla completa en `mantenimiento.md` §4): Ollama, Qwen, Goose, Qwen Code, Continue.dev, Aider, Open WebUI, BGE-M3, Qdrant, Qwen3-VL, ComfyUI, Stable Diffusion 1.5 y Mem0 son gratis/self-hosted (todos Apache 2.0/MIT/GPL o pesos abiertos); **Cloudflare Tunnel no tiene costo aparte**, **Cloudflare Access es gratis hasta 50 usuarios** y **Tailscale es gratis hasta 6 usuarios/dispositivos ilimitados** (Felipe solo necesita 1) — verificado directo en la página oficial de precios de cada proveedor, no de memoria.

## Próximos pasos sugeridos (orden propuesto, actualizado 2026-08-27)

Ya no quedan bloqueantes de diseño — todo lo de arriba está decidido y documentado. Lo que queda es **ejecución real en el equipo**, siguiendo `plan-instalacion.md` (Pasos 0 a 6) con los scripts 00 a 15 de `scripts/`:

- [ ] Correr los scripts en orden (ver `scripts/README.md`), empezando por `00-verificar-equipo` y `12-instalar-herramientas-dev` (git/gh/Python).
- [ ] Manual, cuenta propia: crear el túnel en el dashboard de Cloudflare Zero Trust, obtener el token, elegir el subdominio.
- [ ] Manual: `gh auth login`, e instalar desde el Marketplace de VS Code las extensiones Qwen Code y Continue.dev (los scripts dejan la CLI/config lista, pero la extensión del editor se instala a mano).
- [ ] Configurar BIOS + confirmar servicios de inicio automático (`09-configurar-inicio-automatico`, `mantenimiento.md` §1) como parte de la instalación misma, no después.
- [ ] Configurar el backup a Drive (`10-configurar-backup`, `mantenimiento.md` §2) también como parte de la instalación.
- [ ] Activar rate limiting básico en Cloudflare al configurar el Tunnel.
- [x] Crear `14-instalar-tailscale.ps1`/`.bat` y el switch `-PermitirRed` (`OLLAMA_HOST=0.0.0.0`) — resuelto 2026-08-27, quedan solo por correr en el equipo real.
- [x] Crear la capa de diseño: `15-instalar-comfyui.ps1`/`.bat`, `qwen3-vl:4b` agregado a `03-descargar-modelo.ps1`, `DESIGN.md` — resuelto 2026-08-27, ver `capa-diseno.md`, queda solo por correr en el equipo real.
- [ ] Correr `11-prueba-estres.ps1` (rendimiento real, incluye verificar si el contexto real llega a 100K o se queda en 32K) y las pruebas de calidad de `plan-pruebas.md` — volcar todo en `resultados.md`.
- [ ] (Baja prioridad, no bloqueante) Test de velocidad de subida real de la conexión.
