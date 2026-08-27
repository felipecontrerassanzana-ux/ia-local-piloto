# Acceso remoto por navegador — sin IP fija

Condición real de este equipo: fibra óptica Movistar Hogar, 800 megas, **sin IP fija, sin CGNAT (confirmado por Felipe directamente, 2026-08-26)**. Felipe además tiene **dominio propio** y un **hosting reseller (cPanel/WHM) del que es administrador** — evaluados como piezas posibles de la solución. Investigado 2026-08-26 contra documentación oficial de cada opción.

## Punto de partida: sin CGNAT, se abren más opciones

Sin CGNAT significa que el router sí recibe una IP pública real (aunque cambie de vez en cuando) — technicamente se puede recibir tráfico entrante directo si se abre un puerto. Esto no obliga a usarlo así (sigue siendo más expuesto que un túnel), pero sí habilita la opción "propia" (sin depender de Tailscale/Cloudflare en el camino de los datos) como alternativa real, no solo teórica.

## El hosting reseller (cPanel/WHM) — confirmado que NO sirve como intermediario de tráfico

Felipe confirmó que es hosting compartido cPanel/WHM, sin acceso SSH ni posibilidad de dejar un proceso propio escuchando en un puerto. Esto descarta usarlo como "triangulación" real (un proxy o túnel que reciba las conexiones y las reenvíe a la casa) — el hosting compartido no soporta procesos persistentes, y PHP tiene límites de tiempo de ejecución (segundos, no minutos) que no sirven para una respuesta de un LLM en streaming. **Conclusión: no usar el hosting reseller como intermediario de tráfico.**

**Lo que el hosting/dominio sí aporta:** administrar el DNS del dominio propio. Esto es justo lo que hace falta para las dos opciones de abajo — no como intermediario de tráfico, sino como el nombre público de la solución.

## Opción A — Cloudflare Tunnel + dominio propio (recomendada)

Se arma con la información ya investigada (`developers.cloudflare.com`, verificado 2026-08-26): se delega la zona DNS del dominio propio (o de un subdominio, ej. `ia.tudominio.cl`) a Cloudflare (plan gratis), y `cloudflared` corre en el equipo de la casa con una conexión saliente hacia Cloudflare — sin abrir ningún puerto en el router, sin exponer la IP de la casa.

**Por qué esta combinación es mejor que lo planteado antes:** ya se tenía la idea de Cloudflare Tunnel, pero sin dominio propio hubiera quedado con una URL genérica. Ahora se puede publicar en una URL del propio dominio (`ia.tudominio.cl`), sin límite de ancho de banda (a diferencia de Tailscale Funnel), y sin exponer el router.

**Costo de esta opción:** mover la administración del DNS de ese dominio/subdominio a Cloudflare (gratis, pero es un cambio de dónde se gestiona el DNS, hay que hacerlo con cuidado si el dominio ya sirve otras cosas — ej. correo).

## Opción B — DDNS directo + dominio propio (alternativa "100% propia")

Con CGNAT descartado, esta opción ya no es solo teórica: DNS dinámico apuntando un registro del dominio propio a la IP pública de la casa (actualizado automáticamente cuando cambia, con un script simple o el cliente DDNS del router si lo soporta) + reverse proxy con HTTPS automático (**Caddy** es la opción más simple — genera certificados Let's Encrypt solo) + apertura de puerto en el router + autenticación fuerte en la aplicación.

**Trade-off frente a la Opción A:** cero intermediarios en el camino de los datos (todo el tráfico va directo a la casa) — pero expone el router de la casa directo a internet, con el riesgo que eso implica si algo queda mal configurado. Requiere más cuidado de mantenimiento (mantener Caddy actualizado, revisar logs de acceso).

## Opción C — Tailscale Funnel (queda como respaldo, no como principal)

Sigue siendo válida (ver detalle ya investigado: gratis, funciona sin importar CGNAT, HTTPS automático) pero con límite de ancho de banda no configurable y con una URL de Tailscale (`*.ts.net`), no del dominio propio. Con las opciones A y B ahora disponibles, Tailscale Funnel queda mejor como plan de respaldo rápido (ej. mientras se configura la Opción A) que como solución definitiva.

## Recomendación final para este piloto

**Opción A — Cloudflare Tunnel con el dominio propio.** Da lo mejor de ambos mundos: URL con el dominio de Felipe, sin exponer el router de la casa, sin límite de tráfico, y sin depender del hosting reseller (que ya se descartó como intermediario). La Opción B queda documentada como alternativa si en algún momento se prefiere sacar a Cloudflare del camino por completo.

**Qué exponer:** la interfaz de Open WebUI (ver `../herramientas/motor-alternativas.md`), no el puerto crudo de Ollama — con autenticación (usuario/clave) activada en Open WebUI antes de dejar el túnel activo de forma permanente.

## Autenticación — qué existe y qué activar (verificado 2026-08-26, docs.openwebui.com)

Importante distinguir dos cosas que quedaron mezcladas en la pregunta: **Goose** (el agente, ver `../herramientas/herramientas-trabajo.md`) corre local en el equipo — no está expuesto a internet, así que no necesita login propio, solo importa quién tiene acceso físico/remoto al equipo en sí. Lo que sí queda expuesto a internet por el túnel es **Open WebUI**, y ahí la autenticación es necesaria, no opcional — pero ya viene resuelta en gran parte por defecto:

- **Login con correo/contraseña — activado automáticamente, sin configurar nada:** confirmado en la guía oficial de "Hardening": *"Signup is open only until the first user registers, who becomes the administrator. After that, signup is automatically disabled."* — es decir, apenas Felipe cree su cuenta la primera vez (queda como admin), **el registro público se cierra solo** — nadie más puede crear una cuenta nueva sin que él la vuelva a habilitar explícitamente.
- **Aprobación manual de cuentas nuevas:** si en algún momento se reactiva el registro (`ENABLE_SIGNUP=true`), toda cuenta nueva cae por defecto en estado **"pending"** — no puede usar nada hasta que un admin la apruebe a mano. No es necesario configurar esto, es el comportamiento por defecto.
- **API Keys:** para acceso programático (scripts, integraciones) separado del login por navegador — hereda los permisos del usuario que la crea. Se genera desde la cuenta ya autenticada, no reemplaza el login, lo complementa para uso no interactivo.
- **Recomendación oficial para exposición a internet (textual de la guía de hardening de Open WebUI):** *"the recommended deployment places Open WebUI behind [...] a zero-trust access proxy (**Cloudflare Access**, Pomerium)"* — Cloudflare Access es exactamente el complemento del Cloudflare Tunnel ya elegido arriba: agrega una verificación (ej. código enviado al correo, o login con Google) **antes** de que la persona llegue siquiera a la pantalla de login de Open WebUI. Es gratis en el plan básico de Cloudflare para una lista chica de correos autorizados.

**Respuesta directa a la pregunta:** sí hace falta, y la parte de correo/contraseña ya viene resuelta sin hacer nada extra (se activa sola al crear la primera cuenta). Lo único que hay que agregar a propósito es **Cloudflare Access** delante del túnel — es la recomendación oficial de la propia documentación de Open WebUI para cuando algo queda expuesto a internet, no es sobre-ingeniería.

## Confirmado: es solo para uso de Felipe, y todo esto es gratis (2026-08-26)

Felipe confirmó que la conexión remota es para su propio uso — no espera otras personas conectadas de forma persistente. Esto simplifica la lista de correos autorizados en Cloudflare Access a **un solo correo** (el de Felipe), no una lista a mantener.

**Verificado directamente en la página oficial de precios de Cloudflare (2026-08-26):**
- **Cloudflare Access: plan gratis hasta 50 usuarios, "$0 forever"** — un solo usuario está muy por debajo de ese límite, no hay riesgo de necesitar el plan pago (que recién aplica sobre 50 asientos, a US$7/usuario/mes).
- **Cloudflare Tunnel: sin costo aparte** — no es un producto separado con su propio precio, es una función incluida en cualquier cuenta de Cloudflare (incluida la gratuita), sin límite de túneles ni de tráfico asociado a su uso.

**Sobre el ancho de banda de subida (Felipe cree que el plan es "800 sincrónico", simétrico):** se toma como supuesto de trabajo razonable, pero sigue sin confirmarse con un test real — no bloquea nada de lo planeado (Cloudflare Tunnel funciona igual sea cual sea la velocidad, solo cambia qué tan rápido se siente desde afuera), así que queda como verificación de bajo costo para hacer cuando se pueda, no como paso obligatorio antes de avanzar.

## Segunda ruta en el mismo túnel — el monitor de estado (agregado 2026-08-27)

El mismo túnel de Cloudflare de arriba puede exponer más de un "Public Hostname" a la vez, cada uno apuntando a un puerto local distinto — no hace falta un túnel nuevo por cada servicio. Para ver el dashboard del monitor de estado (`../operacion/monitor-estado.md`) desde internet, basta con agregar en el mismo dashboard de Zero Trust otra entrada apuntando a `http://localhost:8090` (ej. `estado.tudominio.cl`), protegida por el mismo Cloudflare Access ya configurado. Es un paso opcional — sin él, el monitor sigue siendo alcanzable local (`http://localhost:8090`) y por Tailscale.

## Nota: esto cubre acceso por navegador — para agentes de código remotos (Qwen Code/Goose), ver otro documento

Todo lo de arriba es sobre **exponer la interfaz web** (Open WebUI) para usar desde un navegador. Es un caso distinto de "quiero correr Qwen Code en el VS Code de otro dispositivo, apuntando directo al servidor de este equipo" — ese caso (con sus propios modos de conexión y su propia recomendación, Tailscale) queda documentado en `../herramientas/qwen-code-a-fondo.md` § "Modos de conexión, de local a remoto fuera de la red".

## Próximos pasos

- [x] Confirmar si hay CGNAT — resuelto 2026-08-26: no hay.
- [x] Evaluar el hosting reseller como intermediario — resuelto 2026-08-26: descartado (cPanel compartido, sin shell ni procesos propios).
- [x] Definir qué autenticación usar — resuelto 2026-08-26: login de Open WebUI (automático) + Cloudflare Access delante del túnel (recomendación oficial para exposición a internet).
- [ ] Decidir qué subdominio usar para esto (ej. `ia.tudominio.cl`) y delegar su DNS a Cloudflare.
- [ ] Instalar `cloudflared` en el equipo y configurar el túnel hacia Open WebUI.
- [ ] Configurar Cloudflare Access sobre ese túnel con la lista de correos autorizados (para empezar, solo el de Felipe).
- [ ] Crear la primera cuenta de Open WebUI (queda como admin, cierra el registro público automáticamente).
- [ ] Instalar Tailscale — ya no es solo un respaldo de esto: es la recomendación principal para conectar Qwen Code/Goose remotos (ver `../herramientas/qwen-code-a-fondo.md`), además de servir como acceso rápido de respaldo mientras se configura Cloudflare Tunnel.
- [ ] (Opcional) Agregar una segunda "Public Hostname" al mismo túnel, apuntando a `http://localhost:8090`, para ver el monitor de estado desde internet (ver `monitor-estado.md`).
