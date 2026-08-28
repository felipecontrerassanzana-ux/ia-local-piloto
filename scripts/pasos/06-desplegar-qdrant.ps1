<#
.SINOPSIS
  Instala y deja corriendo Qdrant (base vectorial para el RAG) NATIVO en Windows —
  sin Docker. Ver docs/01-arquitectura/03-docker-y-recursos.md: en un equipo de 16GB, evitar la capa
  de WSL2/Docker Desktop cuando existe una alternativa nativa real ahorra varios GB de RAM.

  Binario oficial verificado en github.com/qdrant/qdrant/releases (2026-08-27):
  qdrant-x86_64-pc-windows-msvc.zip — build nativa de Windows, no un contenedor.
#>

. "$PSScriptRoot\_elevar.ps1"

$instalarEn = "C:\QdrantLocal"
$exePath = "$instalarEn\qdrant.exe"

if (Test-Path $exePath) {
    Write-Host "Qdrant ya está instalado en $instalarEn." -ForegroundColor Green
} else {
    Write-Host "Descargando Qdrant (binario nativo de Windows)..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $instalarEn | Out-Null

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/qdrant/qdrant/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "*pc-windows-msvc.zip" } | Select-Object -First 1
    if (-not $asset) {
        Write-Host "No se encontró el asset de Windows en la última release — revisar github.com/qdrant/qdrant/releases a mano." -ForegroundColor Red
        exit 1
    }

    $zipPath = "$env:TEMP\qdrant.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $instalarEn -Force
    Remove-Item $zipPath

    Write-Host "Qdrant $($release.tag_name) instalado en $instalarEn." -ForegroundColor Green
}

New-Item -ItemType Directory -Force -Path "$instalarEn\storage" | Out-Null

# Registrar como Tarea Programada para que arranque solo con Windows (ver docs/06-operacion/01-mantenimiento.md §1)
$existe = Get-ScheduledTask -TaskName "Qdrant-Local" -ErrorAction SilentlyContinue
if ($existe) {
    Write-Host "La tarea programada 'Qdrant-Local' ya existe." -ForegroundColor Yellow
} else {
    $accion = New-ScheduledTaskAction -Execute $exePath -WorkingDirectory $instalarEn
    $disparador = New-ScheduledTaskTrigger -AtStartup
    $config = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName "Qdrant-Local" -Action $accion -Trigger $disparador -Settings $config -User "SYSTEM" -RunLevel Highest -Force | Out-Null
    Write-Host "Tarea programada 'Qdrant-Local' creada — arranca con Windows, sin necesitar sesión abierta." -ForegroundColor Green
}

Write-Host "Iniciando Qdrant ahora (para no esperar al próximo reinicio)..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName "Qdrant-Local"
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Qdrant debería estar corriendo en http://localhost:6333 (panel: http://localhost:6333/dashboard)" -ForegroundColor Green
Write-Host "Datos guardados en: $instalarEn\storage" -ForegroundColor Cyan
Write-Host ""
Write-Host "Nota: una Tarea Programada no reinicia el proceso solo si se cae por un error interno" -ForegroundColor Yellow
Write-Host "(a diferencia de un servicio de Windows real) — se agregó reintento automático (3 veces)" -ForegroundColor Yellow
Write-Host "como mitigación razonable sin sumar una dependencia nueva (ej. NSSM)." -ForegroundColor Yellow
