<#
.SINOPSIS
  Servidor HTTP liviano (System.Net.HttpListener, sin dependencias nuevas) que expone el
  estado del piloto en tiempo real: GET /estado (JSON) y GET / (dashboard HTML). Pensado
  para quedar corriendo todo el tiempo vía la Tarea Programada "Monitor-Estado-Local"
  (registrada por 16-instalar-monitor-estado.ps1) -- este archivo no se corre a mano
  normalmente, es el "daemon" que esa tarea lanza.

  Reutiliza el mismo criterio que scripts/verificar-instalacion.ps1 (mismos puertos, mismos
  nombres de tarea programada, mismas variables de entorno) pero para consumo programático,
  no para lectura humana en consola. Es duplicación deliberada, no un descuido: uno imprime
  texto coloreado para una persona, el otro arma JSON para un navegador/otro programa, y no
  vale la pena la abstracción extra para dos scripts de este tamaño (ver
  docs/operacion/monitor-estado.md).

  Alcance de red: escucha en TODAS las interfaces (prefijo "http://+:PUERTO/"), no solo
  localhost -- así se puede ver desde otro dispositivo por Tailscale sin pasar por Cloudflare.
  La Tarea Programada corre como SYSTEM, que tiene permiso de sobra para reservar ese prefijo
  sin necesitar "netsh http add urlacl" a mano. El tráfico que llega vía Cloudflare Tunnel no
  depende de esto -- cloudflared habla con localhost (loopback), no pasa por el firewall de
  conexiones entrantes.
#>

param(
    [int]$Puerto = 8090
)

function Obtener-Estado {
    $estado = [ordered]@{
        timestamp = (Get-Date).ToString("o")
    }

    # Ollama
    $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    $ollamaInfo = [ordered]@{ instalado = [bool]$ollamaCmd; responde = $false; modelos = @(); modeloEnGpu = $false }
    if ($ollamaCmd) {
        try {
            $respuestaOllama = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5
            $ollamaInfo.responde = $true
            $ollamaInfo.modelos = @($respuestaOllama.models.name)
        } catch { }
        $psOutput = ollama ps 2>$null
        $ollamaInfo.modeloEnGpu = [bool]($psOutput -match "GPU")
    }
    $estado.ollama = $ollamaInfo

    # Qdrant
    $qdrantTarea = Get-ScheduledTask -TaskName "Qdrant-Local" -ErrorAction SilentlyContinue
    $qdrantResponde = $false
    try { Invoke-WebRequest -Uri "http://localhost:6333" -TimeoutSec 5 -UseBasicParsing | Out-Null; $qdrantResponde = $true } catch { }
    $estado.qdrant = [ordered]@{ tareaConfigurada = [bool]$qdrantTarea; responde = $qdrantResponde }

    # Open WebUI
    $openwebuiTarea = Get-ScheduledTask -TaskName "OpenWebUI-Local" -ErrorAction SilentlyContinue
    $openwebuiResponde = $false
    try { Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -UseBasicParsing | Out-Null; $openwebuiResponde = $true } catch { }
    $estado.openWebUI = [ordered]@{
        tareaConfigurada = [bool]$openwebuiTarea
        responde         = $openwebuiResponde
        vectorDbQdrant   = ([Environment]::GetEnvironmentVariable("VECTOR_DB", "Machine") -eq "qdrant")
        embeddingBgeM3   = ([Environment]::GetEnvironmentVariable("RAG_EMBEDDING_MODEL", "Machine") -eq "bge-m3")
    }

    # cloudflared
    $cfService = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
    $estado.cloudflared = [ordered]@{
        instalado        = [bool]$cfService
        corriendo        = [bool]($cfService -and $cfService.Status -eq "Running")
        inicioAutomatico = [bool]($cfService -and $cfService.StartType -eq "Automatic")
    }

    # Tailscale
    $tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue
    $tsInfo = [ordered]@{ instalado = [bool]$tailscaleCmd; conectado = $false; ip = $null }
    if ($tailscaleCmd) {
        $tsStatus = tailscale status 2>$null
        if ($LASTEXITCODE -eq 0 -and $tsStatus) {
            $tsInfo.conectado = $true
            $tsInfo.ip = (tailscale ip -4 2>$null)
        }
    }
    $estado.tailscale = $tsInfo

    # ComfyUI -- no auto-inicia a propósito, solo se informa si está instalado
    $estado.comfyUI = [ordered]@{ instalado = (Test-Path "C:\ComfyUI\run_nvidia_gpu.bat") }

    # Backup
    $infoBackup = Get-ScheduledTaskInfo -TaskName "IA-Local-Piloto-Backup" -ErrorAction SilentlyContinue
    $estado.backup = [ordered]@{
        tareaConfigurada = [bool]$infoBackup
        ultimaEjecucion  = if ($infoBackup) { $infoBackup.LastRunTime } else { $null }
        ultimoResultado  = if ($infoBackup) { $infoBackup.LastTaskResult } else { $null }
    }

    # GPU (vía nvidia-smi)
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nvidiaSmi) {
        try {
            $partes = (& nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits) -split ","
            $estado.gpu = [ordered]@{
                nombre         = $partes[0].Trim()
                vramUsadaMB    = [int]$partes[1].Trim()
                vramTotalMB    = [int]$partes[2].Trim()
                utilizacionPct = [int]$partes[3].Trim()
            }
        } catch {
            $estado.gpu = [ordered]@{ error = "nvidia-smi no respondió correctamente" }
        }
    } else {
        $estado.gpu = [ordered]@{ error = "nvidia-smi no está en el PATH" }
    }

    # Discos
    $estado.discos = @(
        Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | ForEach-Object {
            [ordered]@{
                letra   = "$($_.DriveLetter)"
                libreGB = [math]::Round($_.SizeRemaining / 1GB, 1)
                totalGB = [math]::Round($_.Size / 1GB, 1)
            }
        }
    )

    # CPU / RAM
    $os = Get-CimInstance Win32_OperatingSystem
    $cpuInfo = Get-CimInstance Win32_Processor
    $cpuPct = ($cpuInfo | Measure-Object -Property LoadPercentage -Average).Average
    $estado.sistema = [ordered]@{
        cpuUsoPct  = if ($null -ne $cpuPct) { [math]::Round($cpuPct, 0) } else { $null }
        ramUsadaGB = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB) / 1GB, 1)
        ramTotalGB = [math]::Round(($os.TotalVisibleMemorySize * 1KB) / 1GB, 1)
    }

    return $estado
}

function Obtener-PaginaHtml {
    return @'
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Monitor -- IA Local Piloto</title>
<style>
  :root { color-scheme: dark; }
  body { background:#1E1E1E; color:#D4D4D4; font-family: Consolas, "Courier New", monospace; margin:0; padding:24px; }
  h1 { color:#4FC3F7; font-size:20px; margin:0 0 4px; }
  .actualizado { color:#9A9A9A; font-size:12px; margin-bottom:20px; }
  .tarjeta { background:#252526; border:1px solid #3C3C3C; border-radius:6px; padding:12px 16px; margin-bottom:10px; display:flex; align-items:center; gap:10px; }
  .punto { width:12px; height:12px; border-radius:50%; flex-shrink:0; }
  .ok { background:#6A9955; }
  .mal { background:#F44747; }
  .info { background:#6E6E6E; }
  .nombre { font-weight:bold; min-width:200px; }
  .detalle { color:#9A9A9A; font-size:12px; }
</style>
</head>
<body>
  <h1>IA Local Piloto -- estado en vivo</h1>
  <div class="actualizado" id="actualizado">cargando...</div>
  <div id="tarjetas">cargando...</div>
<script>
async function actualizar() {
  try {
    const r = await fetch('/estado', { cache: 'no-store' });
    const e = await r.json();
    document.getElementById('actualizado').textContent = 'Actualizado: ' + new Date(e.timestamp).toLocaleString();
    const filas = [];
    filas.push(fila('Ollama', e.ollama.responde, e.ollama.responde ? ('modelos: ' + e.ollama.modelos.join(', ') + (e.ollama.modeloEnGpu ? ' (corriendo en GPU)' : '')) : 'no responde'));
    filas.push(fila('Qdrant', e.qdrant.responde, e.qdrant.responde ? 'responde en :6333' : 'no responde'));
    filas.push(fila('Open WebUI', e.openWebUI.responde, e.openWebUI.responde ? ('responde en :8080' + (e.openWebUI.vectorDbQdrant ? ' -- RAG con Qdrant' : ' -- RAG SIN Qdrant, revisar')) : 'no responde'));
    filas.push(fila('Cloudflare Tunnel', e.cloudflared.corriendo, e.cloudflared.instalado ? (e.cloudflared.corriendo ? 'servicio corriendo' : 'instalado pero detenido') : 'no instalado'));
    filas.push(fila('Tailscale', e.tailscale.conectado, e.tailscale.instalado ? (e.tailscale.conectado ? ('conectado, IP ' + e.tailscale.ip) : 'instalado, sin autenticar') : 'no instalado', !e.tailscale.instalado));
    filas.push(fila('ComfyUI', e.comfyUI.instalado, e.comfyUI.instalado ? 'instalado (se abre a mano, no auto-inicia)' : 'no instalado', true));
    filas.push(fila('Backup', !!e.backup.tareaConfigurada, e.backup.ultimaEjecucion ? ('ultima corrida: ' + new Date(e.backup.ultimaEjecucion).toLocaleString()) : 'sin corridas registradas todavia'));
    if (e.gpu && e.gpu.nombre) {
      filas.push(fila('GPU -- ' + e.gpu.nombre, true, e.gpu.vramUsadaMB + ' / ' + e.gpu.vramTotalMB + ' MB VRAM -- ' + e.gpu.utilizacionPct + '% uso', true));
    }
    (e.discos || []).forEach(function(d) { filas.push(fila('Disco ' + d.letra + ':', true, d.libreGB + ' / ' + d.totalGB + ' GB libres', true)); });
    if (e.sistema) {
      filas.push(fila('CPU / RAM', true, 'CPU ' + e.sistema.cpuUsoPct + '% -- RAM ' + e.sistema.ramUsadaGB + ' / ' + e.sistema.ramTotalGB + ' GB', true));
    }
    document.getElementById('tarjetas').innerHTML = filas.join('');
  } catch (err) {
    document.getElementById('actualizado').textContent = 'No se pudo leer /estado: ' + err;
  }
}
function fila(nombre, ok, detalle, neutral) {
  const clase = neutral ? 'info' : (ok ? 'ok' : 'mal');
  return '<div class="tarjeta"><div class="punto ' + clase + '"></div><div class="nombre">' + nombre + '</div><div class="detalle">' + detalle + '</div></div>';
}
actualizar();
setInterval(actualizar, 10000);
</script>
</body>
</html>
'@
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Puerto/")

try {
    $listener.Start()
} catch {
    Write-Host "No se pudo iniciar el monitor en el puerto $Puerto -- $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Monitor de estado escuchando en el puerto $Puerto (todas las interfaces)." -ForegroundColor Green

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
    } catch {
        continue
    }

    $request = $context.Request
    $response = $context.Response
    try {
        if ($request.Url.AbsolutePath -eq "/estado") {
            $json = (Obtener-Estado) | ConvertTo-Json -Depth 6
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } elseif ($request.Url.AbsolutePath -eq "/") {
            $html = Obtener-PaginaHtml
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType = "text/html; charset=utf-8"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
        }
    } catch {
        try { $response.StatusCode = 500 } catch { }
    } finally {
        $response.OutputStream.Close()
    }
}
