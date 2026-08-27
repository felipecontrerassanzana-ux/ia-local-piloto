<#
.SINOPSIS
  Instala cloudflared y lo registra como servicio de Windows usando un túnel creado desde el
  dashboard de Cloudflare Zero Trust (método "remotely-managed", el más simple para uso personal).
  Ver docs/acceso-remoto.md para la decisión y docs/mantenimiento.md para la continuidad.

.PARAMETER Token
  El token del túnel, obtenido así (paso manual, no se puede automatizar — es específico de tu cuenta):
    1. Entrar a https://one.dash.cloudflare.com/ (Zero Trust) -> Networks -> Tunnels -> Create a tunnel.
    2. Elegir "Cloudflared" como conector, ponerle un nombre (ej. "ia-local-piloto").
    3. En el paso de instalación, Cloudflare muestra un comando para Windows con un token largo
       (empieza con "eyJ..."). Copiar SOLO el valor del token y pasarlo acá.
    4. En "Public Hostname", apuntar el subdominio elegido (ver almacenamiento.md) al servicio
       local http://localhost:3000 (Open WebUI, no Ollama directo).
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Token
)

. "$PSScriptRoot\_elevar.ps1"

$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue

if (-not $cloudflared) {
    Write-Host "Instalando cloudflared vía winget..." -ForegroundColor Cyan
    winget install --id Cloudflare.cloudflared -e --accept-source-agreements --accept-package-agreements
}

Write-Host "Registrando cloudflared como servicio de Windows con el túnel dado..." -ForegroundColor Cyan
cloudflared service install $Token

Write-Host ""
Write-Host "Servicio instalado. Verificar que está corriendo:" -ForegroundColor Green
Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType

Write-Host ""
Write-Host "cloudflared NO se actualiza solo en Windows (confirmado en la documentación oficial) —" -ForegroundColor Yellow
Write-Host "queda anotado en el checklist mensual de mantenimiento.md, revisar manualmente." -ForegroundColor Yellow
