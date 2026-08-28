<#
.SINOPSIS
  Descarga Qwen 2.5 Coder 7B en dos cuantizaciones para comparar (ver docs/modelo/02-modelo-elegido.md),
  el modelo de visión para revisión de diseño (ver docs/arquitectura/02-capa-diseno.md), y los embeddings del RAG.
  Tags confirmados en ollama.com/library/qwen2.5-coder/tags y ollama.com/library/qwen3-vl/tags (2026-08-27).
  Correr DESPUÉS de 02-configurar-ollama.ps1 (para que se descarguen ya en la ruta del NVMe).
#>

. "$PSScriptRoot\_elevar.ps1"

$ollama = Get-Command ollama -ErrorAction SilentlyContinue
if (-not $ollama) {
    Write-Host "Ollama no está instalado o no está en el PATH. Correr 01-instalar-ollama.ps1 primero." -ForegroundColor Red
    exit 1
}

Write-Host "Descargando qwen2.5-coder:7b (Q4_K_M, ~4.7GB)..." -ForegroundColor Cyan
ollama pull qwen2.5-coder:7b

Write-Host ""
Write-Host "Descargando qwen2.5-coder:7b-instruct-q8_0 (~8.1GB) — recomendado como 'best for your GPU'..." -ForegroundColor Cyan
ollama pull qwen2.5-coder:7b-instruct-q8_0

Write-Host ""
Write-Host "Descargando bge-m3 (~1.2GB) — embeddings para el RAG, corre en la misma GPU vía Ollama" -ForegroundColor Cyan
Write-Host "(NO se instala como librería de Python aparte — ver docs/arquitectura/03-docker-y-recursos.md, por qué)." -ForegroundColor Cyan
ollama pull bge-m3

Write-Host ""
Write-Host "Descargando qwen3-vl:4b (~3.3GB) — revisor visual de diseño, ver docs/arquitectura/02-capa-diseno.md" -ForegroundColor Cyan
Write-Host "(entra y sale de VRAM bajo demanda, no compite con el modelo de código por espacio fijo)." -ForegroundColor Cyan
ollama pull qwen3-vl:4b

Write-Host ""
Write-Host "Modelos descargados. Listado actual:" -ForegroundColor Green
ollama list

Write-Host ""
Write-Host "Para probar rápido: ollama run qwen2.5-coder:7b" -ForegroundColor Cyan
Write-Host "Para comparar el de mayor calidad: ollama run qwen2.5-coder:7b-instruct-q8_0" -ForegroundColor Cyan
