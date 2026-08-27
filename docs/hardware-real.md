# Hardware real de este piloto

## Specs confirmadas

| Componente | Spec |
|---|---|
| GPU | NVIDIA RTX 5070, **12GB VRAM** (no confundir con la RTX 5070 Ti, de 16GB — es la variante base) |
| RAM del sistema | 16GB |
| CPU | AMD Ryzen 5 3600 |
| Sistema operativo | **Windows 11 Pro 25H2** (confirmado 2026-08-26) |
| Almacenamiento | NVMe ~500GB + HDD 1TB (dos discos separados — ver `almacenamiento.md` para cómo repartir qué va en cada uno) |

## Qué confirma esto contra la investigación ya hecha en `ia-local`

Según la tabla de velocidad real medida en `../ia-local/docs/modelos.md` (§ "Velocidad real medida por GPU", willitrunai.com, 2026-08-23), para el modelo generalista más grande de la familia Qwen (Qwen3.6-27B en Q4_K_M):

| Hardware | VRAM | Velocidad | ¿Cabe? |
|---|---|---|---|
| RTX 4070 12GB | 12GB | 3,2 tok/s | **Too big** |
| RTX 3060 12GB | 12GB | 2,2 tok/s | **Too big** |

12GB queda confirmado como insuficiente para ese modelo — este equipo es para un modelo más chico y especializado (ver `modelo-elegido.md`), no para el generalista de 27B.

## Para qué sí alcanza

Un modelo de ~7B en Q4 pesa aproximadamente 4-5GB de VRAM (regla de ~0.5-0.7 GB por cada mil millones de parámetros, ver `../ia-local/docs/conceptos-fundamentales.md` §1) — cabe cómodo en 12GB, con margen de sobra para contexto (KV cache) y para el motor de inferencia.

Los 16GB de RAM del sistema no son el cuello de botella para la inferencia en sí (el modelo vive en VRAM, no en RAM) — importan para lo que corre *alrededor*: sistema operativo, Ollama, el modelo de embeddings (BGE-M3, <1GB) y la base vectorial (Qdrant/Chroma, liviana). Con un modelo de 7B en GPU, 16GB de RAM debería ser suficiente, pero conviene confirmarlo en la práctica una vez instalado (ver `plan-pruebas.md`).

## Uso del equipo — confirmado 2026-08-26: es de uso compartido

Es un equipo de **uso compartido**, no una máquina dedicada en exclusiva a este piloto. Esto trae una consideración operativa concreta:

- **VRAM compartida con otros usos:** Ollama por defecto **descarga el modelo de la VRAM cuando lleva un rato sin uso** (comportamiento estándar, no hay que configurar nada especial) — así que no compite de forma permanente por los 12GB de VRAM, solo mientras efectivamente está respondiendo algo. Si en la práctica se nota que un uso pesado simultáneo choca con una consulta al modelo, se puede ajustar el tiempo de "keep-alive" de Ollama para que libere memoria más rápido.
- **No cambia la elección de modelo** (Qwen 2.5 Coder 7B, ~4,3-7,5GB según cuantización) — deja margen amplio incluso compartiendo el equipo.
- **Sí importa para la continuidad del servicio** (ver `arquitectura-piloto.md`): si alguien más reinicia o apaga el equipo, el piloto se cae con él — es una limitación real de que no sea una máquina dedicada, a tener en cuenta antes de depender de que quede "siempre disponible".

## Pendiente de verificar en el equipo real (antes de instalar)

- [x] Sistema operativo — resuelto 2026-08-26: Windows 11 Pro 25H2.
- [ ] Espacio en disco disponible en cada unidad (NVMe y HDD) — el modelo + embeddings + índices de RAG de prueba no deberían superar unos 10-15GB, pero confirmar cuánto hay libre hoy en cada disco.
- [ ] Versión de drivers NVIDIA / CUDA instalada — verificado automáticamente por `scripts/00-verificar-equipo.ps1`.
