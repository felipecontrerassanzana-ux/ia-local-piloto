<#
.SINOPSIS
  Crea el script de backup real (volúmenes Docker de Open WebUI y Qdrant -> carpeta de Drive)
  y lo registra como Tarea Programada semanal. Ver docs/mantenimiento.md §2.

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

# Script real de backup — usa un contenedor temporal de Alpine para leer los volúmenes de Docker
# (los volúmenes nombrados no son carpetas normales accesibles directo desde Windows con Docker Desktop/WSL2).
$backupScriptPath = "$PSScriptRoot\_backup-real.ps1"

@"
`$fecha = Get-Date -Format 'yyyy-MM-dd'
`$destino = '$CarpetaDrive'

docker run --rm -v open-webui:/data -v "`${destino}:/backup" alpine tar czf "/backup/open-webui-`$fecha.tar.gz" -C /data .
docker run --rm -v qdrant_storage:/data -v "`${destino}:/backup" alpine tar czf "/backup/qdrant-`$fecha.tar.gz" -C /data .

# Mantener solo los últimos 8 backups de cada uno (2 meses aprox, con frecuencia semanal)
Get-ChildItem "`$destino\open-webui-*.tar.gz" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 8 | Remove-Item -Force
Get-ChildItem "`$destino\qdrant-*.tar.gz" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 8 | Remove-Item -Force

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
