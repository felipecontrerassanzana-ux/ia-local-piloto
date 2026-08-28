<#
.SINOPSIS
  OPCIONAL — no forma parte del camino por defecto (ver docs/01-arquitectura/03-docker-y-recursos.md, actualizado
  2026-08-27). Open WebUI y Qdrant ahora corren NATIVOS en Windows sin Docker (06/07), lo que
  evita la sobrecarga de RAM de WSL2 en un equipo de 16GB. Correr este script solo si:
  (a) se prefiere Docker por algún motivo, o (b) la instalación nativa de Qdrant/Open WebUI
  da problemas y se quiere usar la alternativa en contenedor documentada como respaldo.
#>

. "$PSScriptRoot\_elevar.ps1"

Write-Host "Este script es OPCIONAL — Open WebUI y Qdrant ya corren nativos sin Docker (ver 06/07)." -ForegroundColor Yellow
Write-Host "Instalar Docker Desktop solo si se necesita como respaldo. Continuar? (Ctrl+C para cancelar)" -ForegroundColor Yellow
Start-Sleep -Seconds 3

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
Write-Host "  2. En Settings > General, confirmar que 'Start Docker Desktop when you log in' esté activado (continuidad, ver docs/06-operacion/01-mantenimiento.md)."
Write-Host "  3. Si el equipo no tiene WSL2 habilitado, el instalador debería pedirlo — reiniciar si lo solicita."

# --- Capar la RAM de WSL2 (crítico en un equipo de 16GB — ver docs/01-arquitectura/03-docker-y-recursos.md) ---
# Por defecto WSL2 reserva el 50% de la RAM total de Windows (8GB en este equipo),
# confirmado en la documentación oficial de Microsoft (learn.microsoft.com/windows/wsl/wsl-config).
$wslConfigPath = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslConfigPath) {
    Write-Host ""
    Write-Host "Ya existe $wslConfigPath — no se sobrescribe. Confirmar a mano que tenga un límite de memoria razonable (ver docs/01-arquitectura/03-docker-y-recursos.md)." -ForegroundColor Yellow
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
