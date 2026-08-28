# Cómo funcionan por dentro Qwen Code y Goose (el motor + los addons)

`01-herramientas-trabajo.md` explica **qué** herramientas se eligieron y **por qué**. Este documento explica **cómo funcionan mecánicamente por dentro** — porque de eso depende cómo hay que interactuar con ellas (qué archivos leen, cuándo, en qué orden, qué hace cada pieza). Verificado contra documentación oficial, 2026-08-27.

## El ciclo de vida de una sesión (lo mismo en ambas herramientas, en el fondo)

1. **Arranca con una ventana de contexto vacía.** Ni Qwen Code ni Goose "recuerdan" nada del modelo mismo (ver `01-herramientas-trabajo.md` — el modelo es sin estado). Todo lo que "recuerdan" entre sesiones son archivos que se vuelven a leer al empezar.
2. **Carga archivos de contexto persistente** (ver tabla abajo) — instrucciones que vos escribiste a mano, más lo que la herramienta guardó sola en sesiones anteriores (si tiene auto-memoria).
3. **Corre la conversación/tarea**, con acceso a herramientas (shell, archivos, MCP) según qué esté habilitado.
4. **Al terminar (o periódicamente), algunas herramientas actualizan su memoria** — deciden qué vale la pena guardar para la próxima vez.

## Continuidad de sesión: qué pasa si se corta la luz o se apaga el equipo (agregado 2026-08-27)

Esto es distinto de la memoria automática de arriba — acá no se trata de "qué aprendió la herramienta para la próxima vez", sino de **retomar la conversación misma donde quedó**, igual que esta conversación de Claude Code sigue después de un auto-compact. Verificado contra documentación oficial de cada herramienta:

- **Qwen Code:** `qwen --continue` retoma automáticamente la conversación más reciente; `qwen --resume` muestra un selector con todas las sesiones guardadas (resumen, tiempo transcurrido, cantidad de mensajes, rama de git). **Confirmado explícitamente en la documentación oficial que sobrevive a cerrar la terminal y a reiniciar el equipo** — el historial completo de mensajes se guarda en disco (no en memoria), junto con el estado de las herramientas usadas y la configuración del modelo. Si el corte de luz pasa justo mientras el modelo está generando una respuesta, lo más probable es que se pierda esa respuesta puntual en curso, pero todo lo anterior queda intacto y recuperable con `--continue`.
- **Goose:** desde la versión 1.10.0 guarda las sesiones en una base de datos SQLite (`sessions.db`) en vez de archivos sueltos — al ser una base de datos en disco (no en memoria), en principio también sobrevive a un reinicio, aunque la documentación oficial no lo confirma con esas palabras exactas como sí lo hace la de Qwen Code (queda como algo razonable de asumir, no 100% verificado con cita textual). Se retoma con `goose session --resume` (la más reciente) o `goose session --resume --name <nombre>` (una específica).

**El detalle que sí importa para "local o remota":** ese historial de conversación vive en el disco del equipo donde corre el proceso de Qwen Code/Goose — **no** en Ollama (que no guarda nada, cada consulta es independiente) ni en ningún lado "en la nube". Eso significa:

- Si trabajás **local**, en el equipo piloto mismo, el historial queda en ese equipo — se retoma ahí sin depender de la red ni de si el túnel/Tailscale están activos en ese momento.
- Si trabajás **remoto** (Qwen Code corriendo en tu notebook, conectado por Tailscale al Ollama del equipo piloto, ver `02-qwen-code-a-fondo.md`), el historial queda en **tu notebook**, no en el equipo piloto — porque el proceso de Qwen Code corre ahí, no en la máquina servidor.
- **Estas dos sesiones no se sincronizan solas entre sí:** si empezás una conversación local en el equipo piloto y después querés seguirla desde el notebook (o al revés), `--continue` no la va a encontrar — cada dispositivo tiene su propio historial separado, a menos que se copie el archivo/carpeta de sesión a mano de un equipo al otro (no es un flujo soportado oficialmente, sería una solución casera).
- **Open WebUI es la excepción** — a diferencia de Qwen Code/Goose, su historial de chat vive en el servidor (el equipo piloto), no en el dispositivo que lo mira. Por eso desde cualquier navegador, en cualquier equipo, con el mismo login, se ve la misma conversación — es justamente lo que permite retomarla "desde donde sea", a costa de necesitar el navegador y no ser un agente que edita archivos directamente.

### ¿Vale la pena un "pack de ajustes" de SQLite para este hardware? (investigado 2026-08-27)

Buena pregunta traída de una experiencia real (el runbook de Softland/SQL Server de Felipe, `softland-server-runbook`, donde `max server memory` sin fijar explícitamente quedó como hallazgo pendiente en un servidor de 15,9GB de RAM) — pero al investigarlo a fondo para este caso puntual, **la conclusión honesta es que no hay mucho que ajustar acá, y por una razón estructural, no por pereza:**

- **El problema que hubo con SQL Server no se replica en SQLite.** SQL Server es un proceso servidor que, sin `max server memory` fijado a mano, reclama memoria de forma agresiva por diseño — de ahí el riesgo real en el equipo de Softland. SQLite es una librería embebida, no un proceso servidor: su comportamiento por defecto es **conservador** (`cache_size` por defecto ronda los 2MB), no agresivo. El riesgo que se quería prevenir (que el motor de base de datos "se coma" la RAM del equipo) no aplica de la misma forma acá — si algo, el default de SQLite deja rendimiento arriba de la mesa, no lo contrario.
- **Goose no expone las perillas de ajuste.** El manejo de `sessions.db` es interno — no hay una variable de entorno o archivo de configuración documentado para pasarle `PRAGMA cache_size`/`mmap_size`/etc. Ajustarlo requeriría modificar el código de Goose mismo, no algo razonable para este piloto.
- **Open WebUI sí expone un ajuste real, y ya viene aplicado por defecto.** Existe `DATABASE_ENABLE_SQLITE_WAL` (confirmado en `github.com/open-webui/open-webui`, discusión #16895) — activa el modo WAL (mejor rendimiento con lectores/escritores concurrentes), que es justamente el ajuste más importante de la lista típica de tuning de SQLite. **Desde la versión 0.6.23, Open WebUI ya lo activa por defecto en una instalación nueva** — el ajuste más importante ya viene aplicado sin tocar nada, no es un pendiente.
- **La escala del problema tampoco es comparable.** El servidor de Softland corre 38 bases de datos de producción con transacciones reales de un ERP. El `sessions.db` de Goose guarda el historial de conversación de un solo usuario, en su propio equipo — un volumen de escritura muy por debajo de donde el tuning de SQLite empieza a notarse en la práctica.

**Conclusión:** el instinto de no confiar ciegamente en los defaults de instalación es correcto y vale la pena seguir aplicándolo (es el mismo principio que ya destapó el problema real de Docker/WSL2 con la RAM), pero en este caso concreto la investigación no encontró una acción pendiente real — no por no buscarla, sino porque las dos piezas de este stack que usan SQLite ya están, cada una por su propia razón, en la posición correcta por defecto.

## Archivos de contexto persistente — quién lee qué

| Archivo | Quién lo lee | Quién lo escribe | Alcance |
|---|---|---|---|
| **`AGENTS.md`** (raíz del proyecto) | **Goose** (por defecto, sin configurar nada — confirmado en `goose-docs.ai`: `CONTEXT_FILE_NAMES` por defecto es `["AGENTS.md", ".goosehints"]`) **y Qwen Code** (lee `AGENTS.md` automáticamente si existe, según su propia documentación de memoria) | Vos, a mano | Compartido — es el archivo "universal" entre herramientas de agente distintas, por eso conviene usar este nombre y no duplicar instrucciones en formatos separados |
| `QWEN.md` | Solo Qwen Code | Vos, a mano (o `/init` genera uno automático leyendo el código) | Específico de Qwen Code — usar si hace falta algo que solo aplique ahí, sin mezclarlo con `AGENTS.md` |
| `.goosehints` | Solo Goose (necesita la extensión "Developer" habilitada) | Vos, a mano | Específico de Goose |
| `.continue/rules` | Solo Continue.dev | Vos, a mano | Estático — no se actualiza solo (ver `01-herramientas-trabajo.md`) |
| `~/.qwen/projects/<proyecto>/memory/*.md` | Solo Qwen Code | **Qwen Code solo, automático** (Auto-memory) | Ver `01-herramientas-trabajo.md` § Auto-memory — 4 categorías, limpieza automática diaria |

**Recomendación para este proyecto:** un solo `AGENTS.md` en la raíz, para no mantener el mismo contenido en 3 formatos distintos. Si en algún momento hace falta algo específico de una sola herramienta, ahí sí usar `QWEN.md` o `.goosehints` como complemento, no como reemplazo.

## MCP (Model Context Protocol) — el estándar que conecta herramientas externas

Ya se usa en este entorno de trabajo (el navegador Playwright que usa Claude Code) — el mismo protocolo lo usan Goose (70+ extensiones documentadas: GitHub, bases de datos, navegador, Google Drive) y Qwen Code (soporte de MCP confirmado en su tabla de paridad con Claude Code). En términos simples: es un formato estándar para que un agente de IA le pida a un programa externo que haga algo concreto (leer un archivo, consultar una base de datos, controlar un navegador) sin que el modelo tenga que "saber" programar esa integración desde cero — el servidor MCP expone un menú de acciones posibles, y el agente elige cuál usar.

## SubAgents / Agent Teams — delegar en vez de hacer todo en una sola conversación

Tanto Goose como Qwen Code soportan lanzar sub-agentes (confirmado en la tabla de paridad de funciones de Qwen Code, y en la documentación de Goose) — el mismo patrón que uso yo (Claude) cuando delego una tarea de investigación a un subagente para no llenar la conversación principal con resultados intermedios. Útil para: revisar código en paralelo mientras se sigue conversando, investigar algo largo sin perder el hilo principal, o dividir una tarea grande en partes independientes.

## Skills — instrucciones empaquetadas y reutilizables

Ambas herramientas mencionan "Skills" en su documentación (Qwen Code: "Auto-Skills" en su lista de capacidades; Goose: tiene una extensión "Summon" — "Load skills and delegate tasks to subagents"). La idea general: en vez de escribir la misma instrucción larga cada vez ("cuando revises un PR, fijate en X, Y, Z"), se empaqueta una vez como una "skill" reutilizable que el agente puede invocar por nombre.

## Extensiones/plugins — cómo cada herramienta suma capacidades nuevas

- **Goose:** sistema de extensiones (built-in + comunidad, instalables desde `goose-docs.ai/extensions`) — la mayoría son servidores MCP por debajo.
- **Qwen Code:** también soporta MCP como mecanismo de extensión, más integraciones nativas (canales de mensajería, GitHub Actions).
- **Continue.dev:** modelo de "bloques" de configuración (`ollama/qwen2.5-coder-7b` es un bloque pre-armado) más soporte de MCP.

## Qué significa todo esto para trabajar en este proyecto en concreto

Ver `AGENTS.md` en la raíz de este repo — es el archivo real que aplica lo de arriba: instrucciones ya escritas a mano para que cualquiera de estas herramientas (Goose, Qwen Code) arranque entendiendo las convenciones y decisiones ya tomadas en este proyecto, sin tener que repetirlas cada sesión.
