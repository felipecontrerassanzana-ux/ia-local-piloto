<#
.SINOPSIS
  Levanta Qdrant (base vectorial para el RAG) como contenedor Docker persistente.
  Ver docs/plan-instalacion.md Paso 2 y docs/almacenamiento.md.
#>

. "$PSScriptRoot\_elevar.ps1"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    Write-Host "Docker no está instalado. Correr 05-instalar-docker.ps1 primero." -ForegroundColor Red
    exit 1
}

$existente = docker ps -a --filter "name=qdrant" --format "{{.Names}}"
if ($existente -eq "qdrant") {
    Write-Host "El contenedor 'qdrant' ya existe. Iniciándolo si estaba detenido..." -ForegroundColor Yellow
    docker start qdrant
    exit 0
}

Write-Host "Creando contenedor de Qdrant (persistente, con reinicio automático)..." -ForegroundColor Cyan
docker run -d `
    --name qdrant `
    --restart unless-stopped `
    -p 6333:6333 `
    -v qdrant_storage:/qdrant/storage `
    qdrant/qdrant

Write-Host ""
Write-Host "Qdrant corriendo en http://localhost:6333 (panel: http://localhost:6333/dashboard)" -ForegroundColor Green
Write-Host "'--restart unless-stopped' hace que vuelva a arrancar solo si Docker Desktop inicia con Windows (ver mantenimiento.md)." -ForegroundColor Cyan
