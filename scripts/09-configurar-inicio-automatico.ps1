<#
.SINOPSIS
  Verifica y deja configurado que los servicios necesarios arranquen solos con Windows,
  sin necesitar que alguien inicie sesión. Ver docs/operacion/mantenimiento.md §1.
#>

. "$PSScriptRoot\_elevar.ps1"

Write-Host "=== Continuidad tras reinicio — verificación y configuración ===" -ForegroundColor Cyan
Write-Host ""

# cloudflared: si se instaló con "service install", ya queda como servicio de Windows con
# arranque automático — solo confirmamos.
$cfService = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
if ($cfService) {
    if ($cfService.StartType -ne "Automatic") {
        Set-Service -Name "cloudflared" -StartupType Automatic
        Write-Host "cloudflared: tipo de inicio corregido a Automático." -ForegroundColor Yellow
    } else {
        Write-Host "cloudflared: ya configurado para inicio automático. OK." -ForegroundColor Green
    }
} else {
    Write-Host "cloudflared: servicio no encontrado — ¿se corrió 08-instalar-cloudflared.ps1?" -ForegroundColor Red
}

# Ollama: el instalador de Windows registra una entrada de inicio para el usuario actual
# (bandeja del sistema). Confirmamos que existe la entrada de arranque.
$ollamaStartup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Ollama" }
if ($ollamaStartup) {
    Write-Host "Ollama: tiene entrada de inicio automático para este usuario. OK." -ForegroundColor Green
} else {
    Write-Host "Ollama: no se encontró entrada de inicio automático." -ForegroundColor Yellow
    Write-Host "  Revisar manualmente: Configuración de Windows > Aplicaciones > Inicio, y confirmar que Ollama esté activado." -ForegroundColor Yellow
    Write-Host "  IMPORTANTE: esto solo aplica si hay una sesión de Windows iniciada — si el equipo requiere login manual" -ForegroundColor Yellow
    Write-Host "  tras un reinicio, Ollama no arrancará hasta que alguien inicie sesión. Evaluar activar inicio de sesión" -ForegroundColor Yellow
    Write-Host "  automático de Windows (netplwiz) si el piloto debe quedar disponible sin intervención." -ForegroundColor Yellow
}

# Qdrant y Open WebUI: desde 2026-08-27 corren nativos vía Tareas Programadas (sin Docker,
# ver docs/arquitectura/docker-y-recursos.md) — se revisan como tal, no como contenedores.
foreach ($nombreTarea in @("Qdrant-Local", "OpenWebUI-Local")) {
    $tarea = Get-ScheduledTask -TaskName $nombreTarea -ErrorAction SilentlyContinue
    if ($tarea) {
        $disparadorAlInicio = $tarea.Triggers | Where-Object { $_.CimClass.CimClassName -eq "MSFT_TaskBootTrigger" }
        if ($disparadorAlInicio) {
            Write-Host "$nombreTarea : configurada para iniciar con Windows (SYSTEM, sin sesión). OK." -ForegroundColor Green
        } else {
            Write-Host "$nombreTarea : existe pero no tiene disparador 'al iniciar el sistema' — revisar." -ForegroundColor Yellow
        }
    } else {
        Write-Host "$nombreTarea : no encontrada — ¿se corrió el script 06/07 correspondiente?" -ForegroundColor Red
    }
}

# Docker Desktop es opcional en este proyecto (ver 05-instalar-docker.ps1) — solo se revisa si está instalado.
$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($docker) {
    Write-Host ""
    Write-Host "Docker está instalado (uso opcional/respaldo) — si hay contenedores corriendo, revisar su política de reinicio a mano." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Nota sobre el arranque automático del EQUIPO tras un corte de luz (no configurable por software) ===" -ForegroundColor Cyan
Write-Host "Esto se configura en la BIOS/UEFI, no desde Windows:" -ForegroundColor Yellow
Write-Host "  Reiniciar el equipo, entrar a la BIOS (tecla según fabricante, común: Supr/F2/F10)," -ForegroundColor Yellow
Write-Host "  buscar 'Restore on AC Power Loss' / 'Power On After Power Failure' / 'AC Recovery'," -ForegroundColor Yellow
Write-Host "  y dejarlo en 'Power On' o 'Last State' (no 'Power Off')." -ForegroundColor Yellow
