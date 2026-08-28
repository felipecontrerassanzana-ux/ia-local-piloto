<#
.SINOPSIS
  Chequeo integral post-instalación (Paso 5 de docs/04-instalacion/01-plan-instalacion.md). No instala ni cambia nada,
  solo reporta qué está bien y qué falta.
#>

. "$PSScriptRoot\pasos\_elevar.ps1"

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

# Qdrant y Open WebUI — nativos vía Tareas Programadas desde 2026-08-27 (ver docs/01-arquitectura/03-docker-y-recursos.md)
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

# Sin esto configurado, Open WebUI usa sus defaults internos (ChromaDB + otro modelo de
# embeddings) en vez de Qdrant/BGE-M3 -- ver docs/07-referencia/05-open-webui.md
$vectorDb = [Environment]::GetEnvironmentVariable("VECTOR_DB", "Machine")
Check "Open WebUI configurado para usar Qdrant (VECTOR_DB=qdrant)" ($vectorDb -eq "qdrant") "(valor actual: $vectorDb)"
$embeddingModel = [Environment]::GetEnvironmentVariable("RAG_EMBEDDING_MODEL", "Machine")
Check "Open WebUI configurado para usar BGE-M3 (RAG_EMBEDDING_MODEL=bge-m3)" ($embeddingModel -eq "bge-m3") "(valor actual: $embeddingModel)"

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

# Qwen Code
$qwenCmd = Get-Command qwen -ErrorAction SilentlyContinue
Check "Qwen Code instalado" ($null -ne $qwenCmd)
Check "Configuración de Qwen Code presente (~/.qwen/settings.json)" (Test-Path "$env:USERPROFILE\.qwen\settings.json")

# Tailscale — opcional, solo se informa (no se exige, no todos los equipos necesitan conexión remota de agentes)
$tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue
if ($tailscaleCmd) {
    $tsStatus = tailscale status 2>$null
    if ($LASTEXITCODE -eq 0 -and $tsStatus) {
        Write-Host "[INFO] Tailscale instalado y conectado." -ForegroundColor Gray
        $tsIp = (tailscale ip -4 2>$null)
        if ($tsIp) { Write-Host "       IP de Tailscale de este equipo: $tsIp" -ForegroundColor Gray }
    } else {
        Write-Host "[INFO] Tailscale instalado pero sin autenticar — correr 'tailscale up'." -ForegroundColor Gray
    }
} else {
    Write-Host "[INFO] Tailscale no instalado (opcional — solo hace falta para Qwen Code/Goose remotos, ver docs/03-herramientas/02-qwen-code-a-fondo.md)." -ForegroundColor Gray
}

# Capa de diseño: qwen3-vl (vía Ollama) y ComfyUI (app aparte, no auto-inicia)
if ($ollamaCmd -and $respuesta) {
    $tieneVL = $respuesta.models.name -contains "qwen3-vl:4b"
    Check "Modelo qwen3-vl:4b descargado (revisor visual de diseño)" $tieneVL
}
$comfyPath = "C:\ComfyUI\run_nvidia_gpu.bat"
if (Test-Path $comfyPath) {
    Write-Host "[INFO] ComfyUI instalado en C:\ComfyUI — se abre a mano, no corre como servicio (ver docs/01-arquitectura/02-capa-diseno.md)." -ForegroundColor Gray
} else {
    Write-Host "[INFO] ComfyUI no instalado (opcional — solo hace falta para generar assets de diseño, ver docs/01-arquitectura/02-capa-diseno.md)." -ForegroundColor Gray
}

# Tarea de backup
$tareaBackup = Get-ScheduledTask -TaskName "IA-Local-Piloto-Backup" -ErrorAction SilentlyContinue
Check "Tarea programada de backup configurada" ($null -ne $tareaBackup)

Write-Host ""
Write-Host "=== Resumen: $($ok.Count) OK, $($falta.Count) pendientes ===" -ForegroundColor Cyan
if ($falta.Count -gt 0) {
    Write-Host "Pendientes:" -ForegroundColor Yellow
    $falta | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
