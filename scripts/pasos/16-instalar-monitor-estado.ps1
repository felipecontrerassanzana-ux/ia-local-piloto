<#
.SINOPSIS
  Registra el "Monitor de estado" como Tarea Programada -- un servidor HTTP liviano
  (monitor-estado-servidor.ps1, System.Net.HttpListener, sin dependencias nuevas) que expone
  el estado del piloto en tiempo real: GET /estado (JSON) y GET / (dashboard visual, mismo
  tema oscuro que el instalador).

  Pensado para dos usos, sin infraestructura nueva (ver docs/operacion/monitor-estado.md):
    - Local, en el mismo equipo: http://localhost:8090/
    - Remoto por Tailscale (Paso 14, ya instalado): http://<IP-de-Tailscale>:8090/
    - Remoto público (opcional, manual): agregar una segunda "Public Hostname" al mismo túnel
      de Cloudflare del Paso 08, apuntando a http://localhost:8090 -- protegida por el mismo
      Cloudflare Access, ver docs/operacion/acceso-remoto.md.

.PARAMETER Puerto
  Puerto donde escucha el monitor. Default 8090 (no choca con Ollama 11434, Qdrant 6333,
  Open WebUI 8080).
#>

param(
    [int]$Puerto = 8090
)

. "$PSScriptRoot\_elevar.ps1"

$rutaServidor = "$PSScriptRoot\monitor-estado-servidor.ps1"

# Regla de firewall -- sin esto, Windows bloquea la conexión entrante por Tailscale aunque el
# listener sí esté escuchando (el tráfico por Cloudflare Tunnel no la necesita: cloudflared
# habla con localhost, tráfico de loopback, no pasa por el firewall de conexiones entrantes).
$reglaExiste = Get-NetFirewallRule -DisplayName "IA-Local-Piloto-Monitor" -ErrorAction SilentlyContinue
if ($reglaExiste) {
    Write-Host "La regla de firewall 'IA-Local-Piloto-Monitor' ya existe." -ForegroundColor Yellow
} else {
    New-NetFirewallRule -DisplayName "IA-Local-Piloto-Monitor" -Direction Inbound -Protocol TCP -LocalPort $Puerto -Action Allow | Out-Null
    Write-Host "Regla de firewall creada: permite entrada TCP en el puerto $Puerto (necesario para verlo desde Tailscale)." -ForegroundColor Green
}

# Tarea Programada -- mismo patrón que Qdrant/Open WebUI: corre como SYSTEM, sin sesión abierta.
$existe = Get-ScheduledTask -TaskName "Monitor-Estado-Local" -ErrorAction SilentlyContinue
if ($existe) {
    Write-Host "La tarea programada 'Monitor-Estado-Local' ya existe." -ForegroundColor Yellow
} else {
    $accion = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$rutaServidor`" -Puerto $Puerto"
    $disparador = New-ScheduledTaskTrigger -AtStartup
    $config = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName "Monitor-Estado-Local" -Action $accion -Trigger $disparador -Settings $config -User "SYSTEM" -RunLevel Highest -Force | Out-Null
    Write-Host "Tarea programada 'Monitor-Estado-Local' creada -- arranca con Windows, sin necesitar sesión abierta." -ForegroundColor Green
}

Write-Host "Iniciando el monitor ahora (para no esperar al próximo reinicio)..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName "Monitor-Estado-Local"
Start-Sleep -Seconds 3

Write-Host ""
try {
    Invoke-WebRequest -Uri "http://localhost:$Puerto/estado" -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "Monitor respondiendo en http://localhost:$Puerto/ (dashboard) y http://localhost:$Puerto/estado (JSON)." -ForegroundColor Green
} catch {
    Write-Host "El monitor todavía no responde en localhost:$Puerto -- puede tardar unos segundos más en levantar. Si sigue sin responder, revisar 'Get-ScheduledTaskInfo -TaskName Monitor-Estado-Local'." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Para verlo desde otro dispositivo por Tailscale: http://<IP-de-Tailscale-de-este-equipo>:$Puerto/" -ForegroundColor Cyan
Write-Host "Para verlo desde internet: agregar una segunda 'Public Hostname' al túnel de Cloudflare del Paso 08," -ForegroundColor Cyan
Write-Host "apuntando a http://localhost:$Puerto (ver docs/operacion/acceso-remoto.md)." -ForegroundColor Cyan
