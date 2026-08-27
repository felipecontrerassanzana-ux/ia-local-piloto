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

# --- Capar la RAM de WSL2 (crítico en un equipo de 16GB — ver docs/docker-y-recursos.md) ---
# Por defecto WSL2 reserva el 50% de la RAM total de Windows (8GB en este equipo),
# confirmado en la documentación oficial de Microsoft (learn.microsoft.com/windows/wsl/wsl-config).
$wslConfigPath = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslConfigPath) {
    Write-Host ""
    Write-Host "Ya existe $wslConfigPath — no se sobrescribe. Confirmar a mano que tenga un límite de memoria razonable (ver docs/docker-y-recursos.md)." -ForegroundColor Yellow
} else {
    @"
[wsl2]
memory=4GB
"@ | Out-File -FilePath $wslConfigPath -Encoding ascii
    Write-Host ""
    Write-Host "Creado $wslConfigPath con límite de memoria de 4GB para WSL2/Docker Desktop" -ForegroundColor Green
    Write-Host "(sin esto, WSL2 puede reservar hasta 8GB de los 16GB del equipo por defecto)." -ForegroundColor Green
    Write-Host "Correr 'wsl --shutdown' en una terminal para que el cambio tome efecto." -ForegroundColor Yellow
}
