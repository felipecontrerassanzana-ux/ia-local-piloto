<#
.SINOPSIS
  Instala Goose CLI (ver docs/herramientas-trabajo.md).
  Fuente verificada 2026-08-26: goose-docs.ai/docs/getting-started/installation (pestaña Windows > goose CLI).
#>

. "$PSScriptRoot\_elevar.ps1"

$goose = Get-Command goose -ErrorAction SilentlyContinue
if ($goose) {
    Write-Host "Goose ya está instalado: $(goose --version)" -ForegroundColor Green
    exit 0
}

Write-Host "Descargando el instalador oficial de Goose CLI para Windows..." -ForegroundColor Cyan
$scriptPath = "$PSScriptRoot\..\logs\download_cli.ps1"
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\..\logs" | Out-Null

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aaif-goose/goose/main/download_cli.ps1" -OutFile $scriptPath

Write-Host "Ejecutando instalador..." -ForegroundColor Cyan
& $scriptPath

Write-Host ""
Write-Host "Si aparece una advertencia de que 'goose' no está en el PATH, cierra y reabre la terminal." -ForegroundColor Yellow
Write-Host "Configura el proveedor con: goose configure   (elegir 'Other Providers' -> apuntar a Ollama, http://localhost:11434)" -ForegroundColor Cyan
