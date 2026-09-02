# Qwen Code a fondo: qué sacarle al modelo instalado, y cómo conectarlo desde fuera de la red de casa

Este documento responde dos preguntas distintas que en la práctica están relacionadas: (1) qué hace fuerte a Qwen Code como herramienta, y cómo eso se traduce en provecho real dado el modelo que se instala en este equipo (Qwen 2.5 Coder 7B); y (2) estructuralmente, de cuántas formas se puede conectar a él — no solo en el mismo equipo, sino desde otro dispositivo, en la misma red o completamente afuera. Verificado contra documentación oficial (Qwen Code, Open WebUI, Cloudflare, Tailscale), 2026-08-27.

## Parte 1 — Puntos fuertes de Qwen Code, aplicados a este modelo específico

`01-herramientas-trabajo.md` ya documenta *qué es* Qwen Code (agente de terminal con paridad de funciones con Claude Code: SubAgents, Plan Mode, MCP, hooks, sandboxing, Auto-memory). Lo que falta acá es cruzar esas funciones contra los números reales de `../02-modelo/02-modelo-elegido.md` — qué tan bien se aprovechan en este equipo puntual, no en abstracto.

| Función de Qwen Code | Por qué le saca provecho a Qwen 2.5 Coder 7B en esta GPU | Límite real a tener en cuenta |
|---|---|---|
| **Plan Mode** (propone un plan antes de tocar archivos) | El modelo es de 7B, no 32B — el propio fabricante confirma "correlación positiva entre tamaño y desempeño" (`../02-modelo/02-modelo-elegido.md`). Plan Mode compensa eso: separa "pensar el enfoque" de "ejecutar", dando a Felipe un punto de revisión antes de que el agente toque código | No espera que el plan mismo sea perfecto en tareas de arquitectura compleja — sigue siendo un 7B, la revisión humana en el plan importa tanto como en el resultado |
| **SubAgents / flujos de varios pasos (agentic coding)** | Confirmado en `../02-modelo/02-modelo-elegido.md`: el workload "Agentic Coding" da **"Runs well" sin offload**, a 98 tok/s — un flujo de varios pasos (leer → proponer → aplicar → verificar) corre a velocidad completa, no se degrada por falta de VRAM | Sigue siendo "asistente, no ingeniero autónomo" (mismo texto de `../02-modelo/02-modelo-elegido.md`) — requiere revisión en cada paso, la ventaja acá es velocidad, no autonomía |
| **Contexto largo dentro de una sesión** | Con 100K de contexto seguro confirmado para esta GPU (no los 131K teóricos), Qwen Code puede mantener a la vista varios archivos relacionados de un mismo módulo, o una sesión de depuración larga, sin "olvidar" el inicio — esto es justo lo que separó a este modelo de alternativas con mejor "grado" pero contexto corto (`../02-modelo/02-modelo-elegido.md`) | 100K no alcanza para un repo completo mediano/grande de una sola vez — para eso sigue haciendo falta RAG (recuperar solo lo relevante), no meter todo el proyecto en el contexto |
| **Auto-memory (identifica sola usuario/feedback/proyecto/referencias)** | El modelo en sí es sin estado — cada sesión de Ollama parte de cero. Auto-memory es la pieza que compensa exactamente eso: las convenciones del proyecto, decisiones ya tomadas y feedback de Felipe quedan guardadas entre sesiones sin tener que repetirlas cada vez (ver `01-herramientas-trabajo.md` para el detalle completo) | Es una capacidad de la aplicación Qwen Code, no del modelo — si se cambia de herramienta (ej. se usa Continue.dev en vez de Qwen Code) esa memoria automática no viaja con el modelo, hay que reconstruirla en la herramienta nueva |
| **MCP (extensiones)** | Mismo protocolo que ya usan Claude Code y Goose — cualquier servidor MCP que se arme o instale (ej. acceso a GitHub, a una base de datos propia) sirve para ambas herramientas sin duplicar trabajo | No hay nada instalado todavía en este frente — queda como capacidad disponible, no como pieza activa del piloto por ahora |

**En una frase:** el mayor riesgo de un modelo de 7B no es la velocidad (sobra, 98 tok/s) ni el contexto (100K reales), es la profundidad de razonamiento en problemas grandes — y las funciones de Qwen Code que más aportan acá son justo las que **acotan el trabajo en pasos pequeños y revisables** (Plan Mode, SubAgents) en vez de pedirle una sola respuesta gigante.

## Parte 2 — Modos de conexión, de local a remoto fuera de la red

Hasta ahora el diseño (`../01-arquitectura/01-arquitectura-piloto.md`) solo contemplaba dos casos: uso local en el mismo equipo (Goose/Qwen Code apuntando a `localhost:11434`), y acceso remoto **por navegador** a Open WebUI vía Cloudflare Tunnel. Falta un tercer caso: **Qwen Code corriendo en el VS Code de otro dispositivo (ej. un notebook fuera de la casa), conectado directo al servidor de Ollama de este equipo** — no a través de un navegador ni de Open WebUI, sino como cliente de una API remota, con autenticación propia. Confirmado que es técnicamente posible; hay que elegir cómo.

### Confirmado: Qwen Code sí soporta un servidor remoto por API key (verificado en la doc oficial, `qwenlm.github.io/qwen-code-docs`)

La configuración de un proveedor OpenAI-compatible en `~/.qwen/settings.json` acepta cualquier URL HTTPS remota (no solo `localhost`), más credenciales vía variable de entorno, más headers HTTP personalizados:

```json
{
  "modelProviders": {
    "openai": [
      {
        "id": "qwen2.5-coder-7b",
        "name": "Servidor de casa",
        "envKey": "SERVIDOR_CASA_API_KEY",
        "baseUrl": "https://TU-ENDPOINT-REMOTO/v1",
        "generationConfig": {
          "customHeaders": {
            "CF-Access-Client-Id": "...",
            "CF-Access-Client-Secret": "..."
          }
        }
      }
    ]
  }
}
```

La clave real va en `~/.qwen/.env` (`SERVIDOR_CASA_API_KEY=...`), nunca en texto plano dentro de `settings.json` — la propia doc lo marca como riesgo de seguridad.

Con esa base confirmada, quedan tres escenarios reales según dónde esté el dispositivo que corre Qwen Code:

### Escenario A — mismo equipo (ya decidido, sin cambios)

`baseUrl: "http://localhost:11434/v1"`, sin necesidad de API key real (Ollama no la valida, cualquier texto sirve). Es el caso ya cubierto por `13-instalar-qwen-code.ps1`.

### Escenario B — otro dispositivo, misma red de casa (nuevo, pero simple)

Un notebook conectado al mismo Wi-Fi/cable que el equipo servidor puede apuntar directo a la IP local de ese equipo (ej. `http://192.168.1.X:11434/v1`) — el router doméstico ya aísla esa red del resto de internet, así que no hace falta ninguna capa de autenticación adicional para este caso, más allá de que Ollama por defecto solo escucha en `localhost` y hay que poner `OLLAMA_HOST=0.0.0.0` para que acepte conexiones de otros equipos de la red. No pasa por Cloudflare ni por Tailscale — es tráfico que nunca sale de la casa.

### Escenario C — fuera de la red de casa, dos opciones reales

#### C1 — Tailscale (recomendada para este caso específico)

Tailscale ya estaba documentado como respaldo en `../06-operacion/02-acceso-remoto.md` (Opción C) para el acceso por navegador — acá se le da un uso distinto y, para este caso puntual, mejor encaje: crea una red privada tipo VPN entre los dispositivos de Felipe (cifrada, punto a punto, verificado oficialmente como "Personal plan": **gratis para siempre, hasta 6 usuarios, dispositivos ilimitados**, `tailscale.com/pricing`, 2026-08-27). Con Tailscale instalado en el equipo de casa y en el notebook remoto, ambos quedan en la misma red privada aunque estén geográficamente lejos — Qwen Code apunta a la IP de Tailscale del equipo (`http://100.x.y.z:11434/v1`) exactamente igual que en el Escenario A, solo cambiando `localhost` por esa IP. **No hace falta ninguna capa de autenticación HTTP adicional** — Tailscale ya autentica el dispositivo antes de que el tráfico llegue, y nada de esto queda expuesto a internet público (a diferencia de Cloudflare Tunnel, que sí publica una URL pública).

**Por qué esto no contradice la decisión ya cerrada de "no exponer el puerto crudo de Ollama"** (`../06-operacion/02-acceso-remoto.md`, línea 37): esa decisión era específicamente sobre **exposición pública** vía Cloudflare Tunnel — un desconocido en internet no debe poder llegar directo a Ollama. Tailscale es una red privada cerrada entre los propios dispositivos de Felipe, no expone nada a internet — es una situación distinta, no una que se esté revirtiendo.

#### C2 — Reutilizar el Cloudflare Tunnel ya planeado (alternativa, más piezas)

En vez de exponer Ollama, Qwen Code se conecta al **endpoint OpenAI-compatible que Open WebUI ya expone** (`/api/chat/completions`, confirmado en `docs.openwebui.com`) — el mismo túnel y el mismo Cloudflare Access que ya se planeaba instalar para el navegador, sin exponer nada nuevo:

1. `baseUrl` apunta a `https://ia.tudominio.cl/api` (el hostname del túnel ya decidido).
2. La API key se genera desde la cuenta de Open WebUI (Settings → Account → API keys) — hereda los permisos del usuario que la crea, va como header `Authorization: Bearer <key>` (Qwen Code lo arma solo desde `envKey`).
3. **Problema a resolver:** Cloudflare Access, tal como está planeado, exige login interactivo por correo/Google antes de dejar pasar cualquier tráfico al hostname — un cliente no interactivo como Qwen Code no puede completar ese login. La solución oficial de Cloudflare para esto es un **Service Token** (`CF-Access-Client-Id` + `CF-Access-Client-Secret` como headers, con la política de Access de esa ruta puesta en modo "Service Auth" en vez de login de identidad) — confirmado en `developers.cloudflare.com/cloudflare-one/identity/service-tokens/`. Esos dos headers son justo los que se agregarían en `customHeaders` del ejemplo de arriba.
4. **Investigado a fondo (2026-08-27) y sigue sin poder confirmarse solo con documentación:** ni la página oficial de Service Tokens, ni la de precios de Zero Trust, ni la comparativa de planes mencionan explícitamente si los Service Tokens vienen incluidos en el plan gratis. La única señal encontrada es indirecta y débil: un hilo en el foro oficial de la comunidad de Cloudflare titulado *"Supporting Service Tokens for All subscription plans"* (no se pudo leer el contenido completo — el foro bloquea el acceso sin sesión iniciada), cuyo título por sí solo sugiere que en algún momento no estuvieron disponibles en todos los planes — pero no se pudo verificar si sigue siendo así hoy, ni en qué plan exacto aplicaba. **Conclusión: esto no se puede resolver leyendo documentación, requiere una comprobación práctica** — entrar al dashboard gratis de Cloudflare Zero Trust y ver si la opción de crear un Service Token/política "Service Auth" está disponible sin pedir upgrade, antes de construir este camino. No bloquea nada mientras tanto, porque Tailscale (C1) es la ruta recomendada y no depende de esto.

### Comparación y recomendación

| | C1 — Tailscale | C2 — Cloudflare Tunnel + Access reutilizado |
|---|---|---|
| Piezas nuevas a instalar | Tailscale en el equipo de casa + en cada dispositivo remoto | Ninguna nueva — reutiliza lo ya planeado para el navegador |
| Capas de autenticación | Una (el dispositivo mismo, vía Tailscale) | Dos (Service Token de Access + API key de Open WebUI) |
| Costo confirmado gratis | Sí, verificado directo (Personal plan) | Access confirmado gratis; **Service Tokens sin confirmar** |
| Expone algo a internet público | No — red privada cerrada | Sí — mismo hostname público que ya se expone para el navegador |
| Qué tan directo es el camino a Ollama | Directo (sin pasar por Open WebUI) | Indirecto (pasa por Open WebUI como intermediario) |

**Recomendación:** usar **Tailscale (C1)** como el camino principal para Qwen Code/Goose remotos — es más simple, tiene menos piezas moviéndose, y ya estaba planeado instalarlo igual como respaldo del acceso por navegador. Cloudflare Tunnel + Access queda enfocado en lo que ya se decidió que resuelve mejor: **el acceso por navegador a Open WebUI**, para cuando Felipe no tiene su propio dispositivo con Tailscale instalado a mano (ej. un equipo prestado). No son excluyentes — cada uno cubre un caso de uso distinto, y ambos pueden convivir sin conflicto.

### Un cuarto camino que existe pero todavía no está maduro: `qwen serve` (verificado 2026-08-27)

Investigando más a fondo cómo opera Qwen Code se encontró una función que no estaba mapeada: **modo daemon** (`qwen serve`) — Qwen Code puede correr como un servidor HTTP local, y varios clientes (una IDE, un navegador, un script) comparten **una sola sesión de agente** en vez de que cada uno abra la suya. Trae una interfaz web propia (Web Shell UI, `http://127.0.0.1:4170/`) con chat, diffs, historial de commits y permisos de herramientas — parecido en espíritu a lo que hace Open WebUI para el chat, pero para el agente de código en sí.

**Por qué no se suma como quinto escenario de conexión todavía:** confirmado en la propia doc oficial que es una función **alpha (`v0.16-alpha`)** — el bind por defecto es solo `127.0.0.1` (ni siquiera la red local), y la propia documentación dice textualmente que **"el endurecimiento remoto/multi-daemon llega en un parche posterior"** — es decir, Qwen mismo todavía no lo da por listo para exponerlo más allá del propio equipo. Queda anotado acá como algo a revisar más adelante (podría simplificar el acceso remoto — un solo daemon en la casa, cualquier dispositivo entra por navegador vía Tailscale/túnel, sin configurar `settings.json` en cada uno) pero no como parte del plan de instalación actual.

### Ajuste real encontrado en la doc oficial: timeouts para modelos locales

La propia documentación de Qwen Code, en su ejemplo oficial de configuración para "Local Self-Hosted Models" (Ollama/vLLM/LM Studio), incluye tres campos que la configuración generada por `13-instalar-qwen-code.ps1` no traía: `timeout: 300000`, `streamIdleTimeoutMs: 600000`, `maxRetries: 1` — pensados justo para el caso de un modelo local en hardware modesto, que puede tardar más en responder que un modelo en la nube. **Corregido:** se agregaron esos tres campos al script, con los mismos valores del ejemplo oficial.

## Qué falta para ejecutar esto

- [x] `14-instalar-tailscale.ps1`/`.bat` — resuelto 2026-08-27, instala Tailscale vía winget y detecta si falta autenticar.
- [x] `OLLAMA_HOST=0.0.0.0` — resuelto 2026-08-27, vía el switch `-PermitirRed` de `02-configurar-ollama.ps1` (desactivado por defecto).
- [ ] Si más adelante se decide construir C2: entrar al dashboard gratis de Cloudflare Zero Trust y comprobar en la práctica si la creación de Service Tokens/política "Service Auth" está disponible sin pedir upgrade — investigado a fondo en documentación (2026-08-27) sin llegar a una respuesta clara, no se puede resolver sin entrar a la cuenta real.
- [ ] Documentar el archivo `~/.qwen/settings.json` final una vez que Qwen Code esté instalado (script `13-instalar-qwen-code.ps1`) y probado en el Escenario A.

## Fuentes consultadas (2026-08-27)

- [Model Providers — Qwen Code Docs](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/model-providers/) — esquema de `modelProviders.openai`, `baseUrl` remoto, `customHeaders`.
- [API Keys — Open WebUI](https://docs.openwebui.com/features/authentication-access/api-keys/) — generación de API key, header `Authorization: Bearer`.
- [API Endpoints — Open WebUI](https://docs.openwebui.com/reference/api-endpoints/) — endpoint OpenAI-compatible `/api/chat/completions`.
- [Service Tokens — Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/identity/service-tokens/) — headers `CF-Access-Client-Id`/`CF-Access-Client-Secret`, política "Service Auth".
- [Tailscale Pricing](https://tailscale.com/pricing) — plan Personal gratis, dispositivos ilimitados.
- [Qwen3-Coder — GitHub oficial](https://github.com/QwenLM/Qwen3-Coder) — confirma que no existe variante bajo los 30B en esta línea.
- [Daemon mode (qwen serve) — Qwen Code Docs](https://qwenlm.github.io/qwen-code-docs/en/users/qwen-serve/) — modo servidor HTTP local, estado alpha, endurecimiento remoto pendiente.
