<#
.SINOPSIS
  Instala Ollama si no está instalado. Usa winget (viene con Windows 11).
  Fuente: docs.ollama.com / github.com/ollama/ollama/docs/windows.mdx
#>

. "$PSScriptRoot\_elevar.ps1"

$ollama = Get-Command ollama -ErrorAction SilentlyContinue

if ($ollama) {
    Write-Host "Ollama ya está instalado: $(ollama --version)" -ForegroundColor Green
} else {
    Write-Host "Instalando Ollama vía winget..." -ForegroundColor Cyan
    winget install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements

    if ($LASTEXITCODE -ne 0) {
        Write-Host "winget falló. Alternativa manual: descargar el instalador desde https://ollama.com/download/windows y correrlo a mano." -ForegroundColor Red
        exit 1
    }
    Write-Host "Ollama instalado. Puede que haga falta cerrar y volver a abrir la terminal para que el PATH se actualice." -ForegroundColor Green
}

Write-Host ""
Write-Host "Siguiente paso: correr 02-configurar-ollama para dejar el contexto y la ubicación de modelos configurados ANTES de descargar el modelo." -ForegroundColor Yellow
