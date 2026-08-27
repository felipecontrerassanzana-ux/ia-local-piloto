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

# Docker y contenedores
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
Check "Docker instalado" ($null -ne $dockerCmd)

if ($dockerCmd) {
    $qdrantUp = (docker ps --filter "name=qdrant" --filter "status=running" --format "{{.Names}}") -eq "qdrant"
    Check "Qdrant corriendo" $qdrantUp

    $openwebuiUp = (docker ps --filter "name=open-webui" --filter "status=running" --format "{{.Names}}") -eq "open-webui"
    Check "Open WebUI corriendo" $openwebuiUp

    if ($openwebuiUp) {
        try {
            Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 5 -UseBasicParsing | Out-Null
            Check "Open WebUI responde en localhost:3000" $true
        } catch {
            Check "Open WebUI responde en localhost:3000" $false
        }
    }
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
