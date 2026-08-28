<#
.SINOPSIS
  Crea el script de backup real (carpetas nativas de Open WebUI y Qdrant -> carpeta de Drive)
  y lo registra como Tarea Programada semanal. Ver docs/06-operacion/01-mantenimiento.md §2.

  Actualizado 2026-08-27: como Open WebUI y Qdrant ahora corren nativos (sin Docker, ver
  06/07), sus datos son carpetas normales de Windows — ya no hace falta un contenedor
  temporal de Alpine para leerlas, es una copia directa.

.PARAMETER CarpetaDrive
  Ruta local de la carpeta sincronizada con Google Drive donde se guardan los backups.
  AJUSTAR antes de correr — depende de dónde esté instalada la app de Drive en este equipo,
  ej: "C:\Users\<usuario>\Google Drive\ia-local-piloto-backups"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CarpetaDrive
)

. "$PSScriptRoot\_elevar.ps1"

New-Item -ItemType Directory -Force -Path $CarpetaDrive | Out-Null

$backupScriptPath = "$PSScriptRoot\_backup-real.ps1"

@"
`$fecha = Get-Date -Format 'yyyy-MM-dd'
`$destino = '$CarpetaDrive'

Compress-Archive -Path "C:\OpenWebUIData\*" -DestinationPath "`$destino\open-webui-`$fecha.zip" -Force
Compress-Archive -Path "C:\QdrantLocal\storage\*" -DestinationPath "`$destino\qdrant-`$fecha.zip" -Force

# Mantener solo los últimos 8 backups de cada uno (2 meses aprox, con frecuencia semanal)
Get-ChildItem "`$destino\open-webui-*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 8 | Remove-Item -Force
Get-ChildItem "`$destino\qdrant-*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 8 | Remove-Item -Force

Add-Content -Path "$PSScriptRoot\..\logs\backup.log" -Value "`$(Get-Date): backup completado -> `$destino"
"@ | Out-File -FilePath $backupScriptPath -Encoding utf8

Write-Host "Script de backup creado en: $backupScriptPath" -ForegroundColor Green

# Registrar como Tarea Programada semanal (domingos 03:00 AM)
$accion = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$backupScriptPath`""
$disparador = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
$config = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun

Register-ScheduledTask -TaskName "IA-Local-Piloto-Backup" -Action $accion -Trigger $disparador -Settings $config -RunLevel Highest -Force

Write-Host ""
Write-Host "Tarea programada 'IA-Local-Piloto-Backup' creada: corre todos los domingos a las 03:00." -ForegroundColor Green
Write-Host "Para probarla ahora mismo (sin esperar al domingo): Start-ScheduledTask -TaskName 'IA-Local-Piloto-Backup'" -ForegroundColor Cyan
Write-Host "Revisar el resultado en: $PSScriptRoot\..\logs\backup.log" -ForegroundColor Cyan
