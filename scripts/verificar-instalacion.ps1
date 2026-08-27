<#
.SINOPSIS
  Chequeo integral post-instalación (Paso 5 de plan-instalacion.md). No instala ni cambia nada,
  solo reporta qué está bien y qué falta.
#>

. "$PSScriptRoot\_elevar.ps1"

$ok = @()
$falta = @()

function Check($nombre, $condicion, $detalle = "") {
    if ($condicion) {
        $script:ok += $nombre
        Write-Host "[OK] $nombre $detalle" -ForegroundColor Green
    } else {
        $script:falta += $nombre
        Write-Host "[FALTA] $nombre $detalle" -ForegroundColor Red
    }
}

Write-Host "=== Verificación integral de la instalación — $(Get-Date) ===" -ForegroundColor Cyan
Write-Host ""

# Ollama
$ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
Check "Ollama instalado" ($null -ne $ollamaCmd)

if ($ollamaCmd) {
    try {
        $respuesta = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5
        Check "Ollama responde en localhost:11434" $true
        $modelos = $respuesta.models.name -join ", "
        Write-Host "       Modelos descargados: $modelos" -ForegroundColor Gray
    } catch {
        Check "Ollama responde en localhost:11434" $false "(¿está corriendo? abrir la app de Ollama)"
    }

    $psOutput = ollama ps 2>$null
    if ($psOutput -match "GPU") {
        Check "Modelo corriendo en GPU (no CPU)" $true
        Write-Host "       $psOutput" -ForegroundColor Gray
    } else {
        Write-Host "[INFO] Ningún modelo cargado en este momento (ollama ps vacío) — cargar uno con 'ollama run' antes de este chequeo para verificar el contexto real." -ForegroundColor Yellow
    }
}

# GPU
$nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
Check "Drivers NVIDIA / nvidia-smi disponible" ($null -ne $nvidiaSmi)

# Qdrant y Open WebUI — nativos vía Tareas Programadas desde 2026-08-27 (ver docs/docker-y-recursos.md)
$qdrantTarea = Get-ScheduledTask -TaskName "Qdrant-Local" -ErrorAction SilentlyContinue
Check "Tarea 'Qdrant-Local' configurada" ($null -ne $qdrantTarea)
try {
    Invoke-WebRequest -Uri "http://localhost:6333" -TimeoutSec 5 -UseBasicParsing | Out-Null
    Check "Qdrant responde en localhost:6333" $true
} catch {
    Check "Qdrant responde en localhost:6333" $false
}

$openwebuiTarea = Get-ScheduledTask -TaskName "OpenWebUI-Local" -ErrorAction SilentlyContinue
Check "Tarea 'OpenWebUI-Local' configurada" ($null -ne $openwebuiTarea)
try {
    Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -UseBasicParsing | Out-Null
    Check "Open WebUI responde en localhost:8080" $true
} catch {
    Check "Open WebUI responde en localhost:8080" $false
}

# Docker es opcional en este proyecto — solo se informa si está presente, no se exige.
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCmd) {
    Write-Host "[INFO] Docker está instalado (uso opcional/respaldo, no requerido)." -ForegroundColor Gray
}

# cloudflared
$cfService = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
Check "Servicio cloudflared instalado" ($null -ne $cfService)
if ($cfService) {
    Check "Servicio cloudflared corriendo" ($cfService.Status -eq "Running")
    Check "Servicio cloudflared con inicio automático" ($cfService.StartType -eq "Automatic")
}

# Goose
$gooseCmd = Get-Command goose -ErrorAction SilentlyContinue
Check "Goose instalado" ($null -ne $gooseCmd)

# Tarea de backup
$tareaBackup = Get-ScheduledTask -TaskName "IA-Local-Piloto-Backup" -ErrorAction SilentlyContinue
Check "Tarea programada de backup configurada" ($null -ne $tareaBackup)

Write-Host ""
Write-Host "=== Resumen: $($ok.Count) OK, $($falta.Count) pendientes ===" -ForegroundColor Cyan
if ($falta.Count -gt 0) {
    Write-Host "Pendientes:" -ForegroundColor Yellow
    $falta | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
