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
        # El backup corre semanal (domingos 3am, ver docs/operacion/mantenimiento.md) -- más de
        # 8 días sin corrida (1 día de margen) es señal de que la tarea se rompió en silencio,
        # no solo que "todavía no le toca". Sin esto, una tarea rota se ve igual que una sana
        # (agregado 2026-08-27, a pedido de Felipe).
        atrasado         = [bool](-not $infoBackup -or -not $infoBackup.LastRunTime -or ((Get-Date) - $infoBackup.LastRunTime).TotalDays -gt 8)
    }

    # GPU (vía nvidia-smi)
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nvidiaSmi) {
        try {
            $partes = (& nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv,noheader,nounits) -split ","
            $estado.gpu = [ordered]@{
                nombre         = $partes[0].Trim()
                vramUsadaMB    = [int]$partes[1].Trim()
                vramTotalMB    = [int]$partes[2].Trim()
                utilizacionPct = [int]$partes[3].Trim()
                temperaturaC   = [int]$partes[4].Trim()
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
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Monitor -- IA Local Piloto</title>
<style>
  :root {
    color-scheme: dark;
    --bg: #1E1E1E;
    --superficie: #252526;
    --superficie-2: #2D2D30;
    --borde: #3C3C3C;
    --texto: #D4D4D4;
    --tenue: #9A9A9A;
    --acento: #4FC3F7;
    --ok: #6A9955;
    --alerta: #D7BA7D;
    --mal: #F44747;
    --neutral: #6E6E6E;
  }
  * { box-sizing: border-box; }
  body {
    background: var(--bg); color: var(--texto);
    font-family: Consolas, "Cascadia Code", "Courier New", monospace;
    margin: 0; padding: 20px 24px 40px;
    font-variant-numeric: tabular-nums;
  }
  .topbar { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 8px 20px; margin-bottom: 24px; }
  .titulo h1 { color: var(--acento); font-size: 19px; margin: 0; font-weight: 700; }
  .titulo .subtitulo { color: var(--tenue); font-size: 12px; }
  .resumen { display: flex; align-items: center; gap: 12px; }
  .actualizado { color: var(--tenue); font-size: 11px; }
  .chip-resumen { font-size: 12px; font-weight: 700; padding: 4px 12px; border-radius: 999px; border: 1px solid var(--borde); }
  .chip-resumen.ok { color: var(--ok); border-color: var(--ok); background: rgba(106,153,85,0.12); }
  .chip-resumen.mal { color: var(--mal); border-color: var(--mal); background: rgba(244,71,71,0.12); }

  section.seccion { margin-bottom: 26px; }
  .titulo-seccion { color: var(--tenue); font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; margin: 0 0 10px; }

  .grid { display: grid; gap: 12px; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); align-items: start; }

  .card { background: var(--superficie); border: 1px solid var(--borde); border-radius: 8px; padding: 12px 14px; min-width: 0; }
  .card-head { display: flex; justify-content: space-between; align-items: baseline; gap: 8px; margin-bottom: 8px; font-size: 12px; }
  .card-head .etiqueta { color: var(--tenue); }
  .card-head .valor { font-weight: 700; }

  canvas.grafico { display: block; width: 100%; height: 56px; }

  .barra { height: 8px; background: var(--superficie-2); border-radius: 4px; overflow: hidden; }
  .barra-fill { height: 100%; border-radius: 4px; transition: width 0.4s ease; }
  @media (prefers-reduced-motion: reduce) { .barra-fill { transition: none; } }

  .card-servicio { display: flex; align-items: flex-start; gap: 10px; }
  .pill { flex-shrink: 0; font-size: 10px; font-weight: 700; letter-spacing: 0.04em; padding: 3px 8px; border-radius: 999px; margin-top: 1px; }
  .pill.ok { color: var(--ok); background: rgba(106,153,85,0.15); }
  .pill.mal { color: var(--mal); background: rgba(244,71,71,0.15); }
  .pill.neutral { color: var(--neutral); background: rgba(110,110,110,0.15); }
  .card-servicio .cuerpo { min-width: 0; }
  .card-servicio .nombre { font-weight: 700; font-size: 13px; }
  .card-servicio .detalle { color: var(--tenue); font-size: 11px; margin-top: 2px; overflow-wrap: break-word; }
</style>
</head>
<body>
  <div class="topbar">
    <div class="titulo">
      <h1>IA Local Piloto</h1>
      <div class="subtitulo">Monitor de estado</div>
    </div>
    <div class="resumen">
      <span class="chip-resumen" id="chipResumen">cargando...</span>
      <span class="actualizado" id="actualizado">--</span>
    </div>
  </div>

  <section class="seccion">
    <p class="titulo-seccion">Actividad en tiempo real (ultimos 5 min)</p>
    <div class="grid" id="grillaGraficos"></div>
  </section>

  <section class="seccion">
    <p class="titulo-seccion">Capacidad</p>
    <div class="grid" id="grillaCapacidad"></div>
  </section>

  <section class="seccion">
    <p class="titulo-seccion">Servicios</p>
    <div class="grid" id="grillaServicios"></div>
  </section>

<script>
const MAX_MUESTRAS = 30; // 30 x 10s = 5 minutos de historia, guardada en memoria del navegador
const historia = { cpu: [], gpu: [], vram: [], temp: [] };

function colorPorPorcentaje(pct) {
  if (pct >= 90) return 'var(--mal)';
  if (pct >= 70) return 'var(--alerta)';
  return 'var(--ok)';
}

function dibujarGrafico(canvas, muestras, colorCss) {
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth, h = canvas.clientHeight;
  if (canvas.width !== w * dpr || canvas.height !== h * dpr) {
    canvas.width = w * dpr; canvas.height = h * dpr;
  }
  const ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);

  ctx.strokeStyle = 'rgba(255,255,255,0.07)';
  ctx.lineWidth = 1;
  [0.25, 0.5, 0.75].forEach(function(f) {
    const y = h * f;
    ctx.beginPath(); ctx.moveTo(0, y + 0.5); ctx.lineTo(w, y + 0.5); ctx.stroke();
  });

  if (muestras.length < 2) return;
  const color = getComputedStyle(document.body).getPropertyValue(colorCss.replace('var(', '').replace(')', '')) || '#4FC3F7';
  const paso = w / (MAX_MUESTRAS - 1);
  const offset = MAX_MUESTRAS - muestras.length;
  const puntos = muestras.map(function(v, i) { return [(offset + i) * paso, h - (Math.min(v, 100) / 100) * h]; });

  const grad = ctx.createLinearGradient(0, 0, 0, h);
  grad.addColorStop(0, color.trim() + '55');
  grad.addColorStop(1, color.trim() + '00');
  ctx.beginPath();
  ctx.moveTo(puntos[0][0], h);
  puntos.forEach(function(p) { ctx.lineTo(p[0], p[1]); });
  ctx.lineTo(puntos[puntos.length - 1][0], h);
  ctx.closePath();
  ctx.fillStyle = grad;
  ctx.fill();

  ctx.beginPath();
  puntos.forEach(function(p, i) { i === 0 ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]); });
  ctx.strokeStyle = color.trim();
  ctx.lineWidth = 1.75;
  ctx.stroke();

  const ultimo = puntos[puntos.length - 1];
  ctx.beginPath();
  ctx.arc(ultimo[0], ultimo[1], 2.5, 0, Math.PI * 2);
  ctx.fillStyle = color.trim();
  ctx.fill();
}

function tarjetaGrafico(id, etiqueta, valorTexto) {
  return '<div class="card"><div class="card-head"><span class="etiqueta">' + etiqueta + '</span><span class="valor">' + valorTexto + '</span></div><canvas class="grafico" id="' + id + '"></canvas></div>';
}

function tarjetaCapacidad(etiqueta, usado, total, unidad, pct) {
  const color = colorPorPorcentaje(pct);
  return '<div class="card"><div class="card-head"><span class="etiqueta">' + etiqueta + '</span><span class="valor">' + usado + ' / ' + total + ' ' + unidad + '</span></div><div class="barra"><div class="barra-fill" style="width:' + Math.min(pct, 100).toFixed(0) + '%;background:' + color + '"></div></div></div>';
}

function tarjetaServicio(nombre, estado, detalle, textoPersonalizado) {
  // estado: 'ok' | 'mal' | 'neutral' -- textoPersonalizado pisa la etiqueta por defecto
  // cuando "SIN RESPUESTA" no tiene sentido para ese caso (ej. un backup atrasado no es que
  // "no responda", es que no corrió a tiempo).
  const texto = textoPersonalizado || (estado === 'ok' ? 'OK' : (estado === 'mal' ? 'SIN RESPUESTA' : 'INFO'));
  return '<div class="card card-servicio"><span class="pill ' + estado + '">' + texto + '</span><div class="cuerpo"><div class="nombre">' + nombre + '</div><div class="detalle">' + detalle + '</div></div></div>';
}

function resumirModelos(modelos) {
  // Evita que la tarjeta de Ollama quede mucho mas alta que sus vecinas cuando hay 4+ modelos
  // descargados -- con align-items:start ya no se estira toda la fila, pero igual conviene
  // que el texto en si sea compacto (ver docs/decisiones.md, feedback de Felipe 2026-08-27).
  if (modelos.length <= 2) return modelos.join(', ');
  return modelos.slice(0, 2).join(', ') + ' +' + (modelos.length - 2) + ' mas';
}

function empujarMuestra(arr, valor) {
  arr.push(typeof valor === 'number' && !isNaN(valor) ? valor : 0);
  if (arr.length > MAX_MUESTRAS) arr.shift();
}

async function actualizar() {
  try {
    const r = await fetch('/estado', { cache: 'no-store' });
    const e = await r.json();
    document.getElementById('actualizado').textContent = 'Actualizado ' + new Date(e.timestamp).toLocaleTimeString();

    const criticos = [e.ollama.responde, e.qdrant.responde, e.openWebUI.responde, e.cloudflared.corriendo];
    const fallando = criticos.filter(function(x) { return !x; }).length;
    const chip = document.getElementById('chipResumen');
    if (fallando === 0) { chip.textContent = 'Todo operativo'; chip.className = 'chip-resumen ok'; }
    else { chip.textContent = fallando + ' de ' + criticos.length + ' con problemas'; chip.className = 'chip-resumen mal'; }

    const gpuPct = (e.gpu && e.gpu.vramTotalMB) ? (e.gpu.vramUsadaMB / e.gpu.vramTotalMB) * 100 : 0;
    empujarMuestra(historia.cpu, e.sistema ? e.sistema.cpuUsoPct : null);
    empujarMuestra(historia.gpu, e.gpu ? e.gpu.utilizacionPct : null);
    empujarMuestra(historia.vram, gpuPct);
    empujarMuestra(historia.temp, e.gpu ? e.gpu.temperaturaC : null);

    document.getElementById('grillaGraficos').innerHTML =
      tarjetaGrafico('gCpu', 'CPU', (e.sistema ? e.sistema.cpuUsoPct : '--') + '%') +
      tarjetaGrafico('gGpu', 'GPU (' + (e.gpu && e.gpu.nombre ? e.gpu.nombre : 'sin datos') + ')', (e.gpu ? e.gpu.utilizacionPct : '--') + '%') +
      tarjetaGrafico('gVram', 'VRAM', gpuPct.toFixed(0) + '%') +
      tarjetaGrafico('gTemp', 'Temp. GPU', (e.gpu && e.gpu.temperaturaC != null ? e.gpu.temperaturaC : '--') + 'C');
    dibujarGrafico(document.getElementById('gCpu'), historia.cpu, 'var(--acento)');
    dibujarGrafico(document.getElementById('gGpu'), historia.gpu, 'var(--acento)');
    dibujarGrafico(document.getElementById('gVram'), historia.vram, 'var(--acento)');
    dibujarGrafico(document.getElementById('gTemp'), historia.temp, 'var(--acento)');

    const capacidad = [];
    if (e.gpu && e.gpu.vramTotalMB) {
      capacidad.push(tarjetaCapacidad('VRAM GPU', (e.gpu.vramUsadaMB / 1024).toFixed(1), (e.gpu.vramTotalMB / 1024).toFixed(1), 'GB', gpuPct));
    }
    if (e.sistema) {
      capacidad.push(tarjetaCapacidad('RAM', e.sistema.ramUsadaGB, e.sistema.ramTotalGB, 'GB', (e.sistema.ramUsadaGB / e.sistema.ramTotalGB) * 100));
    }
    (e.discos || []).forEach(function(d) {
      const usado = (d.totalGB - d.libreGB);
      capacidad.push(tarjetaCapacidad('Disco ' + d.letra + ':', usado.toFixed(0), d.totalGB.toFixed(0), 'GB', (usado / d.totalGB) * 100));
    });
    document.getElementById('grillaCapacidad').innerHTML = capacidad.join('');

    const servicios = [];
    servicios.push(tarjetaServicio('Ollama', e.ollama.responde ? 'ok' : 'mal', e.ollama.responde ? (resumirModelos(e.ollama.modelos) + (e.ollama.modeloEnGpu ? ' -- en GPU' : '')) : 'no responde en :11434'));
    servicios.push(tarjetaServicio('Qdrant', e.qdrant.responde ? 'ok' : 'mal', e.qdrant.responde ? 'responde en :6333' : 'no responde'));
    servicios.push(tarjetaServicio('Open WebUI', e.openWebUI.responde ? 'ok' : 'mal', e.openWebUI.responde ? ('responde en :8080' + (e.openWebUI.vectorDbQdrant ? ' -- RAG con Qdrant' : ' -- RAG sin Qdrant, revisar')) : 'no responde'));
    servicios.push(tarjetaServicio('Cloudflare Tunnel', e.cloudflared.corriendo ? 'ok' : (e.cloudflared.instalado ? 'mal' : 'neutral'), e.cloudflared.instalado ? (e.cloudflared.corriendo ? 'servicio corriendo' : 'instalado pero detenido') : 'no instalado'));
    servicios.push(tarjetaServicio('Tailscale', e.tailscale.conectado ? 'ok' : 'neutral', e.tailscale.instalado ? (e.tailscale.conectado ? ('conectado, IP ' + e.tailscale.ip) : 'instalado, sin autenticar') : 'no instalado (opcional)'));
    servicios.push(tarjetaServicio('ComfyUI', 'neutral', e.comfyUI.instalado ? 'instalado -- se abre a mano, no auto-inicia' : 'no instalado (opcional)'));
    const backupEstado = !e.backup.tareaConfigurada ? 'mal' : (e.backup.atrasado ? 'mal' : 'ok');
    const backupPill = !e.backup.tareaConfigurada ? 'SIN CONFIGURAR' : (e.backup.atrasado ? 'ATRASADO' : 'OK');
    servicios.push(tarjetaServicio('Backup', backupEstado, e.backup.ultimaEjecucion ? ('ultima corrida: ' + new Date(e.backup.ultimaEjecucion).toLocaleString()) : 'sin corridas registradas todavia', backupPill));
    document.getElementById('grillaServicios').innerHTML = servicios.join('');
  } catch (err) {
    document.getElementById('actualizado').textContent = 'No se pudo leer /estado: ' + err;
  }
}

const historiaPorId = { gCpu: 'cpu', gGpu: 'gpu', gVram: 'vram', gTemp: 'temp' };
window.addEventListener('resize', function() {
  Object.keys(historiaPorId).forEach(function(id) {
    const c = document.getElementById(id);
    if (c) dibujarGrafico(c, historia[historiaPorId[id]], 'var(--acento)');
  });
});

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
