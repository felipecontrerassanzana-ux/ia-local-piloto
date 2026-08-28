# Plan de pruebas

Adaptado del "Protocolo de evaluación de modelos candidatos" de `../ia-local/docs/04-arquitectura.md`, con foco en programación (el caso de uso de este equipo) y en esta máquina específica.

## Tareas de prueba

- [ ] Juntar 5-10 tareas reales de programación (no inventadas) — código o problemas que Felipe haya resuelto de verdad recientemente, en el lenguaje/stack que más use.
- [ ] Incluir al menos una tarea que dependa de contexto largo (ej. un archivo grande completo, o varias funciones relacionadas) para poner a prueba si el contexto de 131K de Qwen 2.5 Coder 7B es realmente aprovechable con solo 12GB de VRAM.

## Qué medir en cada tarea

- ¿La respuesta es correcta / el código corre?
- ¿Sigue las instrucciones dadas?
- ¿Alucina algo verificable (una función que no existe, un import inventado)?
- ¿El español de las explicaciones (si se le pide en español) es natural, no traducido/raro?
- **Tokens/segundo real medido en esta GPU exacta** — dato que no existe todavía en ninguna fuente consultada (willitrunai.com no tiene RTX 5070 12GB con este modelo). Este es el hallazgo más valioso de este piloto: un dato de primera mano que no está en internet.

## Criterios de éxito (equivalente al Etapa 1 de un piloto formal, pero acá independiente)

- [ ] El equipo sostiene el uso diario sin caídas ni degradación notoria.
- [ ] Al menos una tarea real de programación se resuelve mejor o más rápido que sin la herramienta.
- [ ] La velocidad medida (tok/s) es utilizable en la práctica, no solo "técnicamente funciona".
- [ ] El pipeline de RAG (si se prueba) recupera contexto relevante de los documentos de prueba, sin errores evidentes.

## Registro de resultados

Los resultados reales medidos van en `resultados.md` (se crea cuando haya datos que registrar, no antes) — con fecha, tarea evaluada, y métricas concretas. No repetir ahí lo que ya es teoría (eso vive en `../ia-local/docs/01-conceptos-fundamentales.md` §7, "cómo leer benchmarks sin creérselos literalmente") — acá van solo mediciones propias de este equipo.
