<#
.SINOPSIS
  Levanta Open WebUI como contenedor Docker, conectado al Ollama nativo del equipo (host).
  Comando base verificado en docs.openwebui.com (2026-08-26), adaptado con --restart para continuidad.
#>

. "$PSScriptRoot\_elevar.ps1"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    Write-Host "Docker no está instalado. Correr 05-instalar-docker.ps1 primero." -ForegroundColor Red
    exit 1
}

$existente = docker ps -a --filter "name=open-webui" --format "{{.Names}}"
if ($existente -eq "open-webui") {
    Write-Host "El contenedor 'open-webui' ya existe. Iniciándolo si estaba detenido..." -ForegroundColor Yellow
    docker start open-webui
    exit 0
}

Write-Host "Creando contenedor de Open WebUI..." -ForegroundColor Cyan
docker run -d `
    --name open-webui `
    --restart unless-stopped `
    --memory="1g" `
    -p 3000:8080 `
    --add-host=host.docker.internal:host-gateway `
    -v open-webui:/app/backend/data `
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 `
    ghcr.io/open-webui/open-webui:main

Write-Host ""
Write-Host "Open WebUI corriendo en http://localhost:3000" -ForegroundColor Green
Write-Host ""
Write-Host "PASO MANUAL IMPORTANTE:" -ForegroundColor Yellow
Write-Host "  Entra a http://localhost:3000 y crea la PRIMERA cuenta ahora mismo." -ForegroundColor Yellow
Write-Host "  Esa cuenta queda como administrador, y el registro público se cierra automáticamente" -ForegroundColor Yellow
Write-Host "  (comportamiento por defecto de Open WebUI, ver docs/acceso-remoto.md) — no dejar esto para después." -ForegroundColor Yellow
