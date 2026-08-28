<#
.SINOPSIS
  Verificación inicial del equipo antes de instalar nada (Paso 0 de docs/instalacion/01-plan-instalacion.md).
  No instala ni cambia nada — solo reporta el estado real del equipo.
#>

. "$PSScriptRoot\_elevar.ps1"

$logPath = "$PSScriptRoot\..\logs"
New-Item -ItemType Directory -Force -Path $logPath | Out-Null
$logFile = "$logPath\00-verificacion-equipo-$(Get-Date -Format 'yyyy-MM-dd_HHmm').txt"

function Escribir($texto) {
    Write-Host $texto
    Add-Content -Path $logFile -Value $texto
}

Escribir "=== Verificación del equipo — $(Get-Date) ==="
Escribir ""

# Sistema operativo
$os = Get-CimInstance Win32_OperatingSystem
Escribir "Sistema operativo: $($os.Caption) — versión $($os.Version)"
Escribir ""

# CPU / RAM
$cpu = Get-CimInstance Win32_Processor
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
Escribir "CPU: $($cpu.Name)"
Escribir "RAM total: $ramGB GB"
Escribir ""

# GPU y drivers NVIDIA
Escribir "--- GPU ---"
$gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }
if ($gpu) {
    Escribir "GPU detectada: $($gpu.Name)"
    Escribir "Versión de driver (WMI): $($gpu.DriverVersion)"
} else {
    Escribir "No se detectó una GPU NVIDIA vía WMI — revisar manualmente."
}

$nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($nvidiaSmi) {
    Escribir ""
    Escribir "Salida de nvidia-smi:"
    $smiOutput = & nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used --format=csv
    $smiOutput | ForEach-Object { Escribir $_ }
} else {
    Escribir "nvidia-smi no está en el PATH — si los drivers de NVIDIA están instalados, debería estarlo. Verificar instalación de drivers."
}
Escribir ""

# Discos
Escribir "--- Discos ---"
Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
    $letra = $_.DriveLetter
    $tipo = "N/D"
    try {
        $particion = Get-Partition -DriveLetter $letra -ErrorAction Stop
        $disco = Get-Disk -Number $particion.DiskNumber -ErrorAction Stop
        $tipo = (Get-PhysicalDisk -DeviceNumber $disco.Number -ErrorAction Stop).MediaType
    } catch {
        # Algunas unidades (ópticas, de red) no tienen disco físico asociado — se deja "N/D".
        Write-Verbose "No se pudo determinar el tipo de disco para $($letra): $($_.Exception.Message)"
    }
    $libreGB = [math]::Round($_.SizeRemaining / 1GB, 1)
    $totalGB = [math]::Round($_.Size / 1GB, 1)
    Escribir "$($letra): $libreGB GB libres de $totalGB GB total, tipo: $tipo (etiqueta: $($_.FileSystemLabel))"
}
Escribir ""
Escribir "El campo 'tipo' de arriba (SSD/HDD) ya identifica cuál letra es el NVMe y cuál el HDD."
Escribir "Si aparece 'Unspecified' o 'N/D' en algún disco, confirmar a mano en Administrador de discos"
Escribir "(diskmgmt.msc) o el Administrador de tareas > Rendimiento > cada disco muestra el tipo."
Escribir ""

# Docker (necesario más adelante para Open WebUI / Qdrant)
$docker = Get-Command docker -ErrorAction SilentlyContinue
Escribir "--- Docker ---"
if ($docker) {
    Escribir "Docker ya está instalado: $(docker --version)"
} else {
    Escribir "Docker no está instalado todavía (se instala en el paso 05)."
}

Escribir ""
Escribir "=== Fin de la verificación. Reporte guardado en: $logFile ==="
