<#
.SINOPSIS
  Genera docs/../logs/bitacora-horas.html: cuanto tiempo activo real (y tokens consumidos)
  se paso trabajando en cada proyecto, dia por dia, a partir del historial de sesiones de
  Claude Code de ESTA cuenta de Windows (~/.claude/projects/*.jsonl). No instala nada, no
  necesita permisos de administrador -- solo lee logs propios y escribe un archivo en logs/.

  Por que por cuenta de Windows y no por "usuario logueado en una app": Qwen Code y Goose,
  las herramientas que corren contra el Ollama local de este piloto, no tienen ningun login
  ni cuenta asociada (es a proposito, para no depender de ningun servicio externo) -- no hay
  ningun correo ni ID que capturar desde ahi. La cuenta de Windows es la unica separacion real
  disponible: si Vicente usa este mismo equipo con su propia cuenta, sus logs (de cualquier
  herramienta que log ee localmente) quedan en su propia carpeta de usuario, sin mezclarse
  con los de Felipe. Ver docs/decisiones.md, entrada de este mismo dia, para la investigacion
  completa (incluye Open WebUI, que si tiene multiusuario real via su propio login).

  Metodo (mismo que el prototipo verificado en un Artifact antes de portar esto): se ordenan
  cronologicamente todos los eventos con timestamp de cada sesion, y el hueco entre dos
  eventos consecutivos solo cuenta como tiempo activo si es menor al umbral configurado --
  un hueco mayor se asume que la persona se fue a hacer otra cosa. El proyecto de cada tramo
  se detecta mirando los parametros de las herramientas que Claude Code invoco (rutas de
  archivo, comandos), no el texto de la conversacion -- reduce falsos positivos de mencionar
  un proyecto de pasada sin trabajar ahi.

  Limite conocido, no oculto: Windows PowerShell 5.1 (el interprete que usan los .bat de este
  proyecto) tiene un limite de ~2MB por linea en ConvertFrom-Json. Una linea de log mas grande
  que eso (ej. el resultado de leer un archivo grande) se salta en silencio -- subestima el
  tiempo activo en ese tramo puntual, nunca lo sobreestima. No se resuelve con un parser propio
  porque seria sumar complejidad real para un caso de uso de referencia personal, no critico.

  Los tokens (entrada/salida) se muestran como metrica aparte, no como si fueran equivalentes
  al tiempo -- varian mucho segun la complejidad de la tarea, no son un buen proxy de esfuerzo.

  Si un proyecto en la config trae "repoPath", el script tambien corre `git` sobre esa carpeta
  (una vez por proyecto, no por bloque) para saber si vive solo local o tiene remoto (GitHub),
  y si hay cambios sin commitear o commits sin pushear en ese momento -- relevante porque horas
  invertidas en un proyecto que nunca se subio a ningun lado es tiempo sin respaldo real.

.PARAMETER ConfigPath
  Que proyectos reconocer y como. Ver bitacora-proyectos.example.json -- copiarlo a
  bitacora-proyectos.json (sin ".example") y completar con tus propios proyectos. Ese archivo
  queda fuera de git (ver .gitignore): los nombres de tus otros repos son tuyos, no de este
  piloto, mismo criterio de independencia que ya se aplica entre ia-local y Tecnoingenieria.

.PARAMETER Salida
  Donde queda el HTML generado. Por defecto logs/bitacora-horas.html (logs/ ya esta en
  .gitignore -- es un archivo generado, no documentacion del proyecto).

.PARAMETER AbrirNavegador
  Si se pasa, abre el HTML generado en el navegador predeterminado al terminar --
  bitacora-horas.bat siempre lo pasa (correrlo a mano no debería terminar en "copiar
  la ruta y pegarla en el navegador"). Se deja como switch, no comportamiento fijo,
  para que una futura Tarea Programada que regenere esto solo (sin que nadie lo este
  mirando) pueda omitirlo y no abrir una ventana de navegador sin que nadie la pidió.
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\bitacora-proyectos.json",
    [string]$Salida = "$PSScriptRoot\..\logs\bitacora-horas.html",
    [switch]$AbrirNavegador
)

if (-not (Test-Path $ConfigPath)) {
    $ejemploPath = "$PSScriptRoot\bitacora-proyectos.example.json"
    if (-not (Test-Path $ejemploPath)) {
        Write-Host "No se encontro ni $ConfigPath ni el .example.json de referencia." -ForegroundColor Red
        exit 1
    }
    Write-Host "No existe $ConfigPath todavia -- usando el .example.json genérico mientras tanto." -ForegroundColor Yellow
    Write-Host "Copialo a bitacora-proyectos.json y completalo con tus propios proyectos para resultados reales." -ForegroundColor Yellow
    $ConfigPath = $ejemploPath
}

$utf8SinBom = New-Object System.Text.UTF8Encoding($false)
# Get-Content -Raw en Windows PowerShell 5.1 NO detecta UTF-8 sin BOM -- lo lee con el codepage
# del sistema (Windows-1252 en instalaciones en español), corrompiendo cada tilde/ñ/acento
# ("Bitácora" -> "BitÃ¡cora"). Leer con [System.IO.File]::ReadAllText + encoding explícito evita
# esto por completo, sin depender del BOM ni de la configuración regional del equipo.
$config = [System.IO.File]::ReadAllText($ConfigPath, $utf8SinBom) | ConvertFrom-Json
$umbralHuecoMs = [double]$config.umbralHuecoMinutos * 60000.0
$offsetHoras = [double]$config.offsetHorasZonaHoraria
$reglas = @($config.reglas)
$defecto = $config.proyectoPorDefecto

function Detectar-Proyecto {
    param([string]$Texto)
    foreach ($regla in $reglas) {
        foreach ($patron in $regla.patrones) {
            if ($Texto -match $patron) { return $regla }
        }
    }
    return $null
}

function Obtener-EstadoRepo {
    # Info de "vive local vs. GitHub" para un proyecto -- no se calcula por bloque (seria
    # correr git cientos de veces), se calcula una sola vez por proyecto al armar projectMeta.
    param([string]$RepoPath)

    if ([string]::IsNullOrWhiteSpace($RepoPath)) { return $null }
    if (-not (Test-Path $RepoPath)) {
        return [ordered]@{ carpetaExiste = $false; esRepoGit = $false }
    }
    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        return [ordered]@{ carpetaExiste = $true; esRepoGit = $false }
    }
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        return [ordered]@{ carpetaExiste = $true; esRepoGit = $true; gitNoDisponible = $true }
    }

    $remoto = $null
    try {
        $lineasRemoto = git -C $RepoPath remote -v 2>$null
        if ($lineasRemoto) {
            $primera = @($lineasRemoto)[0]
            if ($primera -match '^\S+\s+(\S+)') { $remoto = $matches[1] }
        }
    } catch { }

    $sinCommitear = $false
    try {
        $porcelain = git -C $RepoPath status --porcelain 2>$null
        $sinCommitear = [bool]$porcelain
    } catch { }

    $commitsSinPushear = 0
    if ($remoto) {
        try {
            $cuenta = git -C $RepoPath rev-list --count '@{u}..HEAD' 2>$null
            if ($cuenta -match '^\d+$') { $commitsSinPushear = [int]$cuenta }
        } catch { }
    }

    return [ordered]@{
        carpetaExiste     = $true
        esRepoGit         = $true
        tieneRemoto       = [bool]$remoto
        remoto            = $remoto
        sinCommitear      = $sinCommitear
        commitsSinPushear = $commitsSinPushear
    }
}

$carpetaSesiones = Join-Path $env:USERPROFILE ".claude\projects"
if (-not (Test-Path $carpetaSesiones)) {
    Write-Host "No se encontro $carpetaSesiones -- ¿Claude Code corrio alguna vez con esta cuenta de Windows?" -ForegroundColor Red
    exit 1
}
$archivos = Get-ChildItem -Path $carpetaSesiones -Recurse -Filter "*.jsonl" -ErrorAction SilentlyContinue
if (-not $archivos) {
    Write-Host "No se encontraron archivos .jsonl en $carpetaSesiones." -ForegroundColor Red
    exit 1
}

Write-Host "Encontrados $($archivos.Count) archivo(s) de sesion. Procesando..." -ForegroundColor Cyan

$todosLosBloques = New-Object System.Collections.Generic.List[object]
$resumenSesiones = New-Object System.Collections.Generic.List[object]
$lineasSaltadas = 0

foreach ($archivo in $archivos) {
    $sesionId = $archivo.BaseName
    $eventos = New-Object System.Collections.Generic.List[object]

    $reader = New-Object System.IO.StreamReader($archivo.FullName)
    try {
        while ($null -ne ($linea = $reader.ReadLine())) {
            if ([string]::IsNullOrWhiteSpace($linea)) { continue }
            try {
                $obj = $linea | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $lineasSaltadas++
                continue
            }
            if (-not $obj.timestamp -or -not $obj.message) { continue }
            try {
                $t = [DateTimeOffset]::Parse($obj.timestamp, [System.Globalization.CultureInfo]::InvariantCulture).ToUnixTimeMilliseconds()
            } catch { continue }

            $pista = $null
            $tokIn = 0.0
            $tokOut = 0.0

            if ($obj.type -eq 'assistant' -and $obj.message.content) {
                foreach ($bloque in $obj.message.content) {
                    if (-not $pista -and $bloque.type -eq 'tool_use' -and $bloque.input) {
                        try {
                            $jsonInput = ($bloque.input | ConvertTo-Json -Compress -Depth 8)
                            $pista = Detectar-Proyecto -Texto $jsonInput
                        } catch {
                            # Best-effort: si este tool_use puntual no se puede serializar (ej. un
                            # input con caracteres raros), simplemente no aporta pista de proyecto --
                            # no es un error del script, y no vale la pena contarlo aparte.
                        }
                    }
                }
                if ($obj.message.usage) {
                    $u = $obj.message.usage
                    $tokIn = [double]([int64]($u.input_tokens) + [int64]($u.cache_creation_input_tokens) + [int64]($u.cache_read_input_tokens))
                    $tokOut = [double][int64]($u.output_tokens)
                }
            }

            $eventos.Add([PSCustomObject]@{ T = $t; Pista = $pista; TokIn = $tokIn; TokOut = $tokOut })
        }
    } finally {
        $reader.Close()
    }

    if ($eventos.Count -lt 2) { continue }
    $ev = @($eventos | Sort-Object T)

    $proyectoActual = $defecto
    $bloqueActual = $null

    for ($i = 0; $i -lt $ev.Count; $i++) {
        if ($ev[$i].Pista) { $proyectoActual = $ev[$i].Pista }
        if ($i -eq 0) { continue }
        $delta = $ev[$i].T - $ev[$i - 1].T

        if ($delta -le $umbralHuecoMs) {
            if ($bloqueActual -and $bloqueActual.ProyectoClave -eq $proyectoActual.clave) {
                $bloqueActual.Fin = $ev[$i].T
                $bloqueActual.TokIn += $ev[$i].TokIn
                $bloqueActual.TokOut += $ev[$i].TokOut
            } else {
                if ($bloqueActual) { $todosLosBloques.Add($bloqueActual) }
                $bloqueActual = [PSCustomObject]@{
                    SesionId = $sesionId
                    ProyectoClave = $proyectoActual.clave
                    Inicio = $ev[$i - 1].T
                    Fin = $ev[$i].T
                    TokIn = $ev[$i].TokIn
                    TokOut = $ev[$i].TokOut
                }
            }
        } else {
            if ($bloqueActual) { $todosLosBloques.Add($bloqueActual); $bloqueActual = $null }
        }
    }
    if ($bloqueActual) { $todosLosBloques.Add($bloqueActual) }

    $minutosActivos = 0.0
    foreach ($b in ($todosLosBloques | Where-Object { $_.SesionId -eq $sesionId })) {
        $minutosActivos += ($b.Fin - $b.Inicio) / 60000.0
    }

    $resumenSesiones.Add([PSCustomObject]@{
        sessionId     = $sesionId
        firstEvent    = [DateTimeOffset]::FromUnixTimeMilliseconds($ev[0].T).UtcDateTime.ToString("o")
        lastEvent     = [DateTimeOffset]::FromUnixTimeMilliseconds($ev[$ev.Count - 1].T).UtcDateTime.ToString("o")
        eventCount    = $ev.Count
        activeMinutes = [math]::Round($minutosActivos, 0)
    })
}

if ($lineasSaltadas -gt 0) {
    Write-Host "$lineasSaltadas linea(s) de log no se pudieron parsear (probablemente por el limite de ~2MB de ConvertFrom-Json) -- omitidas, ver .SINOPSIS." -ForegroundColor Yellow
}

# Fusionar bloques con hueco <= 2 min entre si, misma sesion y mismo proyecto -- evita
# fragmentar el timeline en decenas de micro-bloques cuando en la practica fue continuo.
$bloquesOrdenados = @($todosLosBloques | Sort-Object Inicio)
$fusionados = New-Object System.Collections.Generic.List[object]
foreach ($b in $bloquesOrdenados) {
    $ultimo = if ($fusionados.Count -gt 0) { $fusionados[$fusionados.Count - 1] } else { $null }
    if ($ultimo -and $ultimo.ProyectoClave -eq $b.ProyectoClave -and $ultimo.SesionId -eq $b.SesionId -and (($b.Inicio - $ultimo.Fin) -le 120000)) {
        if ($b.Fin -gt $ultimo.Fin) { $ultimo.Fin = $b.Fin }
        $ultimo.TokIn += $b.TokIn
        $ultimo.TokOut += $b.TokOut
    } else {
        $fusionados.Add([PSCustomObject]@{ SesionId = $b.SesionId; ProyectoClave = $b.ProyectoClave; Inicio = $b.Inicio; Fin = $b.Fin; TokIn = $b.TokIn; TokOut = $b.TokOut })
    }
}

function Obtener-DiaLocal {
    param([double]$Ms)
    ([DateTimeOffset]::FromUnixTimeMilliseconds($Ms).UtcDateTime.AddHours($offsetHoras)).ToString("yyyy-MM-dd")
}
function Obtener-HoraLocal {
    param([double]$Ms)
    ([DateTimeOffset]::FromUnixTimeMilliseconds($Ms).UtcDateTime.AddHours($offsetHoras)).Hour
}

$todasLasClaves = @($reglas | ForEach-Object { $_.clave }) + @($defecto.clave)
$projectTotals = [ordered]@{}
$projectTokens = [ordered]@{}
$dayTotals = [ordered]@{}
$hourHistogram = [ordered]@{}
foreach ($clave in $todasLasClaves) {
    $projectTotals[$clave] = 0.0
    $projectTokens[$clave] = [ordered]@{ 'in' = 0.0; out = 0.0 }
    $hourHistogram[$clave] = [double[]](@(0.0) * 24)
}

$bloquesSalida = New-Object System.Collections.Generic.List[object]

foreach ($b in $fusionados) {
    $durMin = [math]::Round((($b.Fin - $b.Inicio) / 60000.0), 1)
    $dia = Obtener-DiaLocal $b.Inicio
    $hora = Obtener-HoraLocal $b.Inicio
    $clave = $b.ProyectoClave

    $projectTotals[$clave] += $durMin
    $projectTokens[$clave]['in'] += $b.TokIn
    $projectTokens[$clave]['out'] += $b.TokOut

    if (-not $dayTotals.Contains($dia)) { $dayTotals[$dia] = [ordered]@{} }
    if (-not $dayTotals[$dia].Contains($clave)) { $dayTotals[$dia][$clave] = 0.0 }
    $dayTotals[$dia][$clave] += $durMin

    $hourHistogram[$clave][$hora] += $durMin

    $bloquesSalida.Add([ordered]@{
        project     = $clave
        start       = [DateTimeOffset]::FromUnixTimeMilliseconds($b.Inicio).UtcDateTime.ToString("o")
        end         = [DateTimeOffset]::FromUnixTimeMilliseconds($b.Fin).UtcDateTime.ToString("o")
        day         = $dia
        durationMin = $durMin
        sessionId   = $b.SesionId
    })
}

Write-Host "Chequeando estado de repo (local/GitHub) de cada proyecto con repoPath configurado..." -ForegroundColor Cyan

$projectMeta = [ordered]@{}
foreach ($regla in $reglas) {
    $entrada = [ordered]@{ label = $regla.etiqueta; color = $regla.color; desc = $regla.desc }
    if ($regla.repoPath) {
        $estadoRepo = Obtener-EstadoRepo -RepoPath $regla.repoPath
        if ($estadoRepo) { $entrada['repo'] = $estadoRepo }
    }
    $projectMeta[$regla.clave] = $entrada
}
$projectMeta[$defecto.clave] = [ordered]@{ label = $defecto.etiqueta; color = $defecto.color; desc = $defecto.desc }

$datos = [ordered]@{
    generatedAt         = (Get-Date).ToUniversalTime().ToString("o")
    gapThresholdMinutes = $config.umbralHuecoMinutos
    tzOffsetHours       = $offsetHoras
    projectMeta         = $projectMeta
    projectTotals       = $projectTotals
    projectTokens       = $projectTokens
    dayTotals           = $dayTotals
    hourHistogram       = $hourHistogram
    sessions            = $resumenSesiones
    blocks              = $bloquesSalida
}

$json = $datos | ConvertTo-Json -Depth 12 -Compress
$plantilla = [System.IO.File]::ReadAllText("$PSScriptRoot\bitacora-plantilla.html", $utf8SinBom)
$html = $plantilla.Replace('__DATA_JSON__', $json)

$carpetaSalida = Split-Path $Salida -Parent
if (-not (Test-Path $carpetaSalida)) { New-Item -ItemType Directory -Force -Path $carpetaSalida | Out-Null }
[System.IO.File]::WriteAllText($Salida, $html, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Bitacora generada: $Salida" -ForegroundColor Green
Write-Host "Sesiones: $($resumenSesiones.Count) -- bloques: $($bloquesSalida.Count) -- proyectos: $($todasLasClaves -join ', ')" -ForegroundColor Cyan
Write-Host "Verla localmente: abrir el archivo, o si el monitor de estado esta corriendo, http://localhost:8090/bitacora" -ForegroundColor White

if ($AbrirNavegador) {
    Start-Process $Salida
}
