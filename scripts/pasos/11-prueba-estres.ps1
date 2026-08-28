<#
.SINOPSIS
  Batería de pruebas de estrés y rendimiento real sobre el modelo ya instalado.
  Ver docs/05-pruebas/02-pruebas-rendimiento.md para qué mide cada prueba y cómo interpretar los resultados.

  Usa exclusivamente la API oficial de Ollama (localhost:11434/api/generate) y sus propios
  campos de métricas (prompt_eval_count, eval_count, eval_duration, etc. — documentados en
  github.com/ollama/ollama/docs/api.md) — no mide tiempo "a ojo" desde PowerShell, usa los
  números que el propio Ollama reporta, que son más precisos.

.PARAMETER Modelo
  Tag del modelo a probar. Por defecto el recomendado en docs/02-modelo/02-modelo-elegido.md.
#>

param(
    [string]$Modelo = "qwen2.5-coder:7b-instruct-q8_0"
)

. "$PSScriptRoot\_elevar.ps1"

$logDir = "$PSScriptRoot\..\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
$csvPath = "$logDir\prueba-estres-$timestamp.csv"
$resumenPath = "$logDir\prueba-estres-$timestamp-resumen.txt"

$resultados = New-Object System.Collections.Generic.List[Object]

function Invocar-Ollama($prompt, $etiquetaPrueba) {
    $body = @{
        model  = $Modelo
        prompt = $prompt
        stream = $false
    } | ConvertTo-Json -Compress

    $inicio = Get-Date
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 300
    } catch {
        Write-Host "[ERROR] $etiquetaPrueba : $_" -ForegroundColor Red
        return $null
    }

    $tokPerSec = if ($resp.eval_duration -gt 0) { [math]::Round(($resp.eval_count / $resp.eval_duration) * 1e9, 1) } else { 0 }
    $tiempoAntesDeGenerar_ms = [math]::Round(($resp.total_duration - $resp.eval_duration) / 1e6, 0)

    $fila = [PSCustomObject]@{
        Prueba              = $etiquetaPrueba
        Hora                = $inicio.ToString("HH:mm:ss")
        TokensPrompt        = $resp.prompt_eval_count
        TokensRespuesta     = $resp.eval_count
        TokPorSegundo       = $tokPerSec
        TiempoAntesGenerar_ms = $tiempoAntesDeGenerar_ms
        DuracionTotal_ms    = [math]::Round($resp.total_duration / 1e6, 0)
    }
    $script:resultados.Add($fila)
    Write-Host ("  {0,-28} prompt={1,6} tok  resp={2,4} tok  {3,6} tok/s  antes-de-generar={4,6} ms" -f $etiquetaPrueba, $fila.TokensPrompt, $fila.TokensRespuesta, $fila.TokPorSegundo, $fila.TiempoAntesGenerar_ms)
    return $fila
}

function Registrar-GPU($etiqueta) {
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nvidiaSmi) {
        $linea = & nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader
        Write-Host "  GPU ($etiqueta): $linea" -ForegroundColor Gray
        Add-Content -Path $resumenPath -Value "GPU ($etiqueta): $linea"
    }
}

Write-Host "=== Prueba de estrés — modelo: $Modelo — $(Get-Date) ===" -ForegroundColor Cyan
"=== Prueba de estrés — modelo: $Modelo — $(Get-Date) ===" | Out-File $resumenPath

# Confirmar que el modelo existe localmente
$modelosDisponibles = (Invoke-RestMethod -Uri "http://localhost:11434/api/tags").models.name
if ($modelosDisponibles -notcontains $Modelo) {
    Write-Host "El modelo '$Modelo' no está descargado. Modelos disponibles: $($modelosDisponibles -join ', ')" -ForegroundColor Red
    exit 1
}

Registrar-GPU "antes de empezar"

# --- Prueba 1: Baseline — prompt corto, 5 repeticiones ---
Write-Host ""
Write-Host "--- Prueba 1: Baseline (prompt corto x5) ---" -ForegroundColor Yellow
$promptCorto = "Explica en una frase qué es una función en programación."
for ($i = 1; $i -le 5; $i++) {
    Invocar-Ollama $promptCorto "Baseline-$i" | Out-Null
}

# --- Prueba 2: Carga sostenida — 20 repeticiones seguidas, buscar degradación ---
Write-Host ""
Write-Host "--- Prueba 2: Carga sostenida (20 repeticiones seguidas) ---" -ForegroundColor Yellow
Registrar-GPU "inicio carga sostenida"
for ($i = 1; $i -le 20; $i++) {
    Invocar-Ollama $promptCorto "Sostenida-$i" | Out-Null
}
Registrar-GPU "fin carga sostenida"

# --- Prueba 3: Rampa de contexto — textos cada vez más largos ---
Write-Host ""
Write-Host "--- Prueba 3: Rampa de contexto (verifica el límite real, ver docs/02-modelo/02-modelo-elegido.md) ---" -ForegroundColor Yellow
$parrafoBase = "El procesamiento de lenguaje natural permite que un modelo entienda y genere texto en distintos idiomas, adaptándose al contexto de la conversación y a la tarea solicitada por quien lo usa. "
$repeticiones = @(5, 40, 150, 300, 600, 1200, 2000)  # aproxima ~1K, 8K, 32K, 64K, 100K+ tokens (Ollama reporta el número real)

foreach ($rep in $repeticiones) {
    $textoLargo = ($parrafoBase * $rep)
    $prompt = "$textoLargo`n`nResume el texto anterior en una sola oración."
    $fila = Invocar-Ollama $prompt "Contexto-x$rep"
    if ($null -eq $fila) {
        Write-Host "  (falló en x$rep repeticiones — probable límite real de contexto alcanzado, ver resumen)" -ForegroundColor Red
        break
    }
}

Registrar-GPU "después de la rampa de contexto"

# --- Guardar CSV y resumen ---
$resultados | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "=== Resumen ===" -ForegroundColor Cyan
$baseline = $resultados | Where-Object { $_.Prueba -like "Baseline-*" }
$sostenida = $resultados | Where-Object { $_.Prueba -like "Sostenida-*" }
$contexto = $resultados | Where-Object { $_.Prueba -like "Contexto-*" }

$resumen = @"
Modelo probado: $Modelo
Fecha: $(Get-Date)

Baseline (prompt corto, 5 corridas):
  tok/s promedio: $([math]::Round(($baseline.TokPorSegundo | Measure-Object -Average).Average, 1))
  tok/s min/max:  $(($baseline.TokPorSegundo | Measure-Object -Minimum).Minimum) / $(($baseline.TokPorSegundo | Measure-Object -Maximum).Maximum)

Carga sostenida (20 corridas seguidas):
  tok/s promedio: $([math]::Round(($sostenida.TokPorSegundo | Measure-Object -Average).Average, 1))
  tok/s primera corrida: $($sostenida[0].TokPorSegundo)
  tok/s última corrida:  $($sostenida[-1].TokPorSegundo)
  (si la última es mucho más baja que la primera, revisar temperatura de GPU en este mismo archivo — posible throttling térmico)

Rampa de contexto — mayor tamaño de prompt completado con éxito:
  $(if ($contexto.Count -gt 0) { "$($contexto[-1].TokensPrompt) tokens de prompt, a $($contexto[-1].TokPorSegundo) tok/s" } else { "ninguna prueba de contexto se completó" })

Archivo detallado: $csvPath
"@

$resumen | Out-File -Append $resumenPath
Write-Host $resumen
Write-Host ""
Write-Host "Detalle completo (CSV, abrir con Excel): $csvPath" -ForegroundColor Green
Write-Host "Resumen: $resumenPath" -ForegroundColor Green
