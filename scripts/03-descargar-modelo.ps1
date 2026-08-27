<#
.SINOPSIS
  Descarga Qwen 2.5 Coder 7B en dos cuantizaciones para comparar (ver docs/modelo-elegido.md).
  Tags confirmados en ollama.com/library/qwen2.5-coder/tags (2026-08-26).
  Correr DESPUÉS de 02-configurar-ollama.ps1 (para que se descarguen ya en la ruta del HDD).
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
Write-Host "Modelos descargados. Listado actual:" -ForegroundColor Green
ollama list

Write-Host ""
Write-Host "Para probar rápido: ollama run qwen2.5-coder:7b" -ForegroundColor Cyan
Write-Host "Para comparar el de mayor calidad: ollama run qwen2.5-coder:7b-instruct-q8_0" -ForegroundColor Cyan
