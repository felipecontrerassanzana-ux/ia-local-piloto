<#
.SINOPSIS
  Instala Docker Desktop si no está presente. Necesario para Open WebUI y Qdrant (Paso 2).
#>

. "$PSScriptRoot\_elevar.ps1"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($docker) {
    Write-Host "Docker ya está instalado: $(docker --version)" -ForegroundColor Green
    exit 0
}

Write-Host "Instalando Docker Desktop vía winget..." -ForegroundColor Cyan
winget install --id Docker.DockerDesktop -e --accept-source-agreements --accept-package-agreements

Write-Host ""
Write-Host "Docker Desktop instalado. Hay que:" -ForegroundColor Yellow
Write-Host "  1. Abrirlo manualmente una vez para aceptar los términos y que arranque el motor."
Write-Host "  2. En Settings > General, confirmar que 'Start Docker Desktop when you log in' esté activado (continuidad, ver mantenimiento.md)."
Write-Host "  3. Si el equipo no tiene WSL2 habilitado, el instalador debería pedirlo — reiniciar si lo solicita."
