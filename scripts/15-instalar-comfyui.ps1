<#
.SINOPSIS
  Instala ComfyUI (motor de generacion de imagenes, portable para Windows) y descarga el
  checkpoint de Stable Diffusion 1.5 -- la pieza que genera assets/graficos para la capa de
  diseno (ver docs/capa-diseno.md). Se instala en el NVMe (ver docs/almacenamiento.md).

  Por que ComfyUI y no AUTOMATIC1111: AUTOMATIC1111 exige Python 3.10.6 exacto ("newer version
  of Python does not support torch", confirmado en su propio README) -- choca con el Python 3.12
  que ya instala 12-instalar-herramientas-dev.ps1. ComfyUI portable trae su propio Python
  empaquetado (sin instalar nada aparte) y es mas eficiente en GPUs de VRAM chica.

  A PROPOSITO no se registra como Tarea Programada de inicio automatico (a diferencia de Qdrant/
  Open WebUI): el diseno de este piloto protege la VRAM del modelo de codigo (ver capa-diseno.md)
  -- ComfyUI se abre solo cuando hace falta generar un asset, no queda residente en segundo plano
  compitiendo por VRAM.

  Fuentes verificadas 2026-08-27: github.com/Comfy-Org/ComfyUI/releases (build portable nvidia),
  huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive (checkpoint fp16, ~2.1GB, mismo hash que
  el original de RunwayML antes de que lo dieran de baja).
#>

param(
    [string]$LetraNVMe = "C"
)

. "$PSScriptRoot\_elevar.ps1"

$instalarEn = "${LetraNVMe}:\ComfyUI"
$checkpointsDir = "$instalarEn\ComfyUI\models\checkpoints"

if (Test-Path "$instalarEn\run_nvidia_gpu.bat") {
    Write-Host "ComfyUI ya está instalado en $instalarEn." -ForegroundColor Green
} else {
    # --- 7-Zip: necesario para extraer el paquete portable (.7z, no .zip) ---
    $sevenZip = Get-Command 7z -ErrorAction SilentlyContinue
    if (-not $sevenZip) {
        Write-Host "Instalando 7-Zip (necesario para extraer el paquete portable de ComfyUI)..." -ForegroundColor Cyan
        winget install --id 7zip.7zip -e --accept-source-agreements --accept-package-agreements
        Write-Host "Puede que haga falta cerrar y volver a abrir la terminal para que '7z' se reconozca." -ForegroundColor Yellow
        $sevenZipPath = "C:\Program Files\7-Zip\7z.exe"
    } else {
        $sevenZipPath = $sevenZip.Source
    }

    Write-Host "Descargando ComfyUI (build portable para NVIDIA)..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $instalarEn | Out-Null

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/Comfy-Org/ComfyUI/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -eq "ComfyUI_windows_portable_nvidia.7z" } | Select-Object -First 1
    if (-not $asset) {
        Write-Host "No se encontró el asset portable de NVIDIA en la última release — revisar github.com/Comfy-Org/ComfyUI/releases a mano." -ForegroundColor Red
        exit 1
    }

    $archivePath = "$env:TEMP\comfyui-portable.7z"
    Write-Host "Descargando $($asset.name) ($([math]::Round($asset.size / 1GB, 1)) GB)..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archivePath

    Write-Host "Extrayendo (puede tardar varios minutos)..." -ForegroundColor Cyan
    & $sevenZipPath x $archivePath -o"$instalarEn" -y | Out-Null
    Remove-Item $archivePath

    # El .7z trae una subcarpeta "ComfyUI_windows_portable" -- aplanar un nivel para que
    # run_nvidia_gpu.bat quede directo en $instalarEn.
    $subcarpeta = Get-ChildItem -Path $instalarEn -Directory | Where-Object { $_.Name -like "ComfyUI_windows_portable*" } | Select-Object -First 1
    if ($subcarpeta) {
        Get-ChildItem -Path $subcarpeta.FullName | Move-Item -Destination $instalarEn -Force
        Remove-Item $subcarpeta.FullName -Force -ErrorAction SilentlyContinue
    }

    Write-Host "ComfyUI $($release.tag_name) instalado en $instalarEn." -ForegroundColor Green
}

# --- Checkpoint de Stable Diffusion 1.5 ---
New-Item -ItemType Directory -Force -Path $checkpointsDir | Out-Null
$checkpointPath = "$checkpointsDir\v1-5-pruned-emaonly-fp16.safetensors"

if (Test-Path $checkpointPath) {
    Write-Host "El checkpoint de Stable Diffusion 1.5 ya está descargado." -ForegroundColor Green
} else {
    Write-Host "Descargando checkpoint de Stable Diffusion 1.5 (~2.1GB, fp16)..." -ForegroundColor Cyan
    $checkpointUrl = "https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors"
    Invoke-WebRequest -Uri $checkpointUrl -OutFile $checkpointPath
    Write-Host "Checkpoint descargado en $checkpointPath." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Instalación completa. No se registró como servicio de inicio automático, a propósito ===" -ForegroundColor Cyan
Write-Host "Para usarlo: correr $instalarEn\run_nvidia_gpu.bat (queda escuchando en http://localhost:8188)." -ForegroundColor White
Write-Host "API para uso programático (parte de la Skill de capa-diseno.md): http://localhost:8188/prompt" -ForegroundColor White
Write-Host "Cerrar la ventana cuando no se esté generando nada, para liberar la VRAM que use el modelo de código." -ForegroundColor Yellow
