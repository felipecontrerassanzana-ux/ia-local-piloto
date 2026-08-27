<#
.SINOPSIS
  Instala y deja corriendo Open WebUI NATIVO en Windows (vía pip) — sin Docker.
  Ver docs/docker-y-recursos.md. Requiere Python (scripts/12-instalar-herramientas-dev.ps1).

  Confirmado en documentación oficial (docs.openwebui.com, 2026-08-27): "Python: Suitable
  for low-resource environments" — es un método soportado oficialmente, no un hack.
#>

. "$PSScriptRoot\_elevar.ps1"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "Python no está instalado. Correr 12-instalar-herramientas-dev.ps1 primero." -ForegroundColor Red
    exit 1
}

$dataDir = "C:\OpenWebUIData"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

$openwebui = Get-Command open-webui -ErrorAction SilentlyContinue
if ($openwebui) {
    Write-Host "Open WebUI ya está instalado." -ForegroundColor Green
} else {
    Write-Host "Instalando Open WebUI vía pip (puede tardar varios minutos, instala varias dependencias)..." -ForegroundColor Cyan
    pip install open-webui
}

# Registrar como Tarea Programada para que arranque solo con Windows (ver mantenimiento.md §1)
$existe = Get-ScheduledTask -TaskName "OpenWebUI-Local" -ErrorAction SilentlyContinue
if ($existe) {
    Write-Host "La tarea programada 'OpenWebUI-Local' ya existe." -ForegroundColor Yellow
} else {
    $openwebuiPath = (Get-Command open-webui).Source
    $accion = New-ScheduledTaskAction -Execute $openwebuiPath -Argument "serve" -WorkingDirectory $dataDir
    $disparador = New-ScheduledTaskTrigger -AtStartup
    $config = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName "OpenWebUI-Local" -Action $accion -Trigger $disparador -Settings $config -User "SYSTEM" -RunLevel Highest -Force | Out-Null

    # DATA_DIR se fija como variable de entorno de sistema para que la tarea programada la use
    [Environment]::SetEnvironmentVariable("DATA_DIR", $dataDir, "Machine")
    Write-Host "Tarea programada 'OpenWebUI-Local' creada — arranca con Windows, sin necesitar sesión abierta." -ForegroundColor Green
}

Write-Host "Iniciando Open WebUI ahora (para no esperar al próximo reinicio)..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName "OpenWebUI-Local"
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "Open WebUI debería estar corriendo en http://localhost:8080" -ForegroundColor Green
Write-Host "(nota: puerto 8080 nativo, no 3000 — ese remapeo era específico del contenedor Docker)." -ForegroundColor Yellow
Write-Host "Datos guardados en: $dataDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "PASO MANUAL IMPORTANTE:" -ForegroundColor Yellow
Write-Host "  Entra a http://localhost:8080 y crea la PRIMERA cuenta ahora mismo." -ForegroundColor Yellow
Write-Host "  Esa cuenta queda como administrador, y el registro público se cierra automáticamente" -ForegroundColor Yellow
Write-Host "  (comportamiento por defecto de Open WebUI, ver docs/acceso-remoto.md) — no dejar esto para después." -ForegroundColor Yellow
Write-Host ""
Write-Host "En Settings > Connections de Open WebUI, confirmar que apunta a Ollama en http://localhost:11434" -ForegroundColor Cyan
Write-Host "(nativo también, así que localhost normal alcanza — ya no hace falta host.docker.internal)." -ForegroundColor Cyan
