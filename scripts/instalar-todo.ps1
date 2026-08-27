<#
.SINOPSIS
  Instalador único con interfaz gráfica (WPF nativo de Windows, sin Python) para todo el
  piloto. Corre los scripts 00-15 en el ORDEN REAL de dependencias (no el orden numérico de
  archivo -- ver docs/instalacion/plan-instalacion.md, ej. 07 necesita 12 primero aunque el
  número de archivo diga lo contrario), verificando cada paso antes de seguir al siguiente.

  Pasos que necesitan login/token (Cloudflare, Tailscale) quedan deliberadamente AL FINAL,
  listados con instrucciones -- no pausan la instalación automática (decisión de Felipe,
  2026-08-27, ver docs/decisiones.md).

  No reemplaza los scripts individuales -- los reutiliza tal cual (viven en scripts/pasos/,
  ver docs/instalacion/aprendizaje-scripts.md), en el orden correcto, con verificación
  automática entre cada uno. `verificar-instalacion.ps1` sigue existiendo aparte para
  chequeos posteriores (no ligados a una instalación en curso).
#>

. "$PSScriptRoot\pasos\_elevar.ps1"

$script:CarpetaPasos = Join-Path $PSScriptRoot "pasos"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

# ============================================================================
# Definición de pasos, en el orden REAL de dependencias (no el numérico de archivo)
# ============================================================================

$script:Pasos = @(
    [PSCustomObject]@{ Id = "00"; Nombre = "Verificar equipo (SO, GPU, discos)";        Archivo = "00-verificar-equipo.ps1";       Manual = $false }
    [PSCustomObject]@{ Id = "01"; Nombre = "Instalar Ollama";                           Archivo = "01-instalar-ollama.ps1";        Manual = $false }
    [PSCustomObject]@{ Id = "02"; Nombre = "Configurar Ollama (NVMe, contexto)";        Archivo = "02-configurar-ollama.ps1";      Manual = $false }
    [PSCustomObject]@{ Id = "03"; Nombre = "Descargar modelos (coder, embeddings, VL)"; Archivo = "03-descargar-modelo.ps1";       Manual = $false }
    [PSCustomObject]@{ Id = "12"; Nombre = "Herramientas dev (git, gh, Python)";        Archivo = "12-instalar-herramientas-dev.ps1"; Manual = $false }
    [PSCustomObject]@{ Id = "04"; Nombre = "Instalar Goose";                            Archivo = "04-instalar-goose.ps1";         Manual = $false }
    [PSCustomObject]@{ Id = "13"; Nombre = "Instalar Qwen Code";                        Archivo = "13-instalar-qwen-code.ps1";     Manual = $false }
    [PSCustomObject]@{ Id = "06"; Nombre = "Desplegar Qdrant";                          Archivo = "06-desplegar-qdrant.ps1";       Manual = $false }
    [PSCustomObject]@{ Id = "07"; Nombre = "Desplegar Open WebUI (+ conectar RAG)";     Archivo = "07-desplegar-openwebui.ps1";    Manual = $false }
    [PSCustomObject]@{ Id = "09"; Nombre = "Confirmar inicio automático";               Archivo = "09-configurar-inicio-automatico.ps1"; Manual = $false }
    [PSCustomObject]@{ Id = "10"; Nombre = "Configurar backup a Drive";                 Archivo = "10-configurar-backup.ps1";      Manual = $false }
    [PSCustomObject]@{ Id = "15"; Nombre = "Instalar ComfyUI + Stable Diffusion 1.5";   Archivo = "15-instalar-comfyui.ps1";       Manual = $false }
)

# Pasos que se listan al final, no se automatizan (necesitan login/token) — ver arriba
$script:PasosManuales = @(
    "08 — Cloudflare Tunnel: crear el túnel en el dashboard de Cloudflare Zero Trust, pegar el token, y correr scripts\pasos\08-instalar-cloudflared.bat -Token <token>."
    "14 — Tailscale: correr scripts\pasos\14-instalar-tailscale.bat, después 'tailscale up' en una terminal para autenticar por navegador."
    "VS Code: instalar desde el Marketplace las extensiones 'Qwen Code' y 'Continue.dev' (no se puede automatizar la instalación de extensiones de otro programa)."
    "Open WebUI: entrar a http://localhost:8080 y crear la primera cuenta (queda como admin)."
)

# ============================================================================
# Funciones de verificación — un chequeo puntual por paso, no un monitor activo
# (ver docs/decisiones.md, 2026-08-27, la distinción entre verificar y monitorear)
# ============================================================================

function Test-Paso {
    param([string]$Id)
    try {
        switch ($Id) {
            "00" { return $true }  # es un reporte, no tiene estado de éxito/fracaso
            "01" { return [bool](Get-Command ollama -ErrorAction SilentlyContinue) }
            "02" {
                $modelsPath = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "Machine")
                return [bool]$modelsPath
            }
            "03" {
                $lista = & ollama list 2>$null
                return ($lista -match "qwen2.5-coder" -and $lista -match "bge-m3" -and $lista -match "qwen3-vl")
            }
            "12" {
                return [bool](Get-Command git -ErrorAction SilentlyContinue) -and [bool](Get-Command gh -ErrorAction SilentlyContinue)
            }
            "04" { return [bool](Get-Command goose -ErrorAction SilentlyContinue) }
            "13" {
                return [bool](Get-Command qwen -ErrorAction SilentlyContinue) -and (Test-Path "$env:USERPROFILE\.qwen\settings.json")
            }
            "06" {
                $tarea = Get-ScheduledTask -TaskName "Qdrant-Local" -ErrorAction SilentlyContinue
                if (-not $tarea) { return $false }
                try { Invoke-WebRequest -Uri "http://localhost:6333" -TimeoutSec 5 -UseBasicParsing | Out-Null; return $true } catch { return $false }
            }
            "07" {
                $tarea = Get-ScheduledTask -TaskName "OpenWebUI-Local" -ErrorAction SilentlyContinue
                if (-not $tarea) { return $false }
                $vectorDb = [Environment]::GetEnvironmentVariable("VECTOR_DB", "Machine")
                try { Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -UseBasicParsing | Out-Null } catch { return $false }
                return ($vectorDb -eq "qdrant")
            }
            "09" {
                $ollamaOk = (Get-Process -Name "ollama" -ErrorAction SilentlyContinue) -or (Get-Command ollama -ErrorAction SilentlyContinue)
                return [bool]$ollamaOk
            }
            "10" { return [bool](Get-ScheduledTask -TaskName "IA-Local-Piloto-Backup" -ErrorAction SilentlyContinue) }
            "15" {
                return (Test-Path "${script:LetraNVMe}:\ComfyUI\run_nvidia_gpu.bat") -and (Test-Path "${script:LetraNVMe}:\ComfyUI\ComfyUI\models\checkpoints\v1-5-pruned-emaonly-fp16.safetensors")
            }
            default { return $true }
        }
    } catch {
        return $false
    }
}

# ============================================================================
# XAML de la ventana
# ============================================================================

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Instalador — IA Local Piloto" Height="780" Width="900"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="180"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="IA Local Piloto — Instalación completa" FontSize="18" FontWeight="Bold" Margin="0,0,0,10"/>

        <GroupBox Grid.Row="1" Header="Parámetros" Margin="0,0,0,10" Padding="8">
            <StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <TextBlock Text="Letra del disco NVMe:" Width="220" VerticalAlignment="Center"/>
                    <TextBox Name="TxtNVMe" Width="40" Text="C"/>
                    <TextBlock Text="  (confirmar con el reporte del Paso 00 antes de avanzar)" FontStyle="Italic" Foreground="Gray" VerticalAlignment="Center"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <TextBlock Text="Carpeta de Google Drive (backup):" Width="220" VerticalAlignment="Center"/>
                    <TextBox Name="TxtBackup" Width="400" Text=""/>
                </StackPanel>
                <CheckBox Name="ChkDocker" Content="Instalar Docker también (opcional/respaldo, normalmente no hace falta)" Margin="0,4,0,0"/>
                <CheckBox Name="ChkRed" Content="Preparar el equipo para conexión remota de agentes (activa OLLAMA_HOST=0.0.0.0 — instalar Tailscale aparte después)" Margin="0,4,0,0"/>
            </StackPanel>
        </GroupBox>

        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" BorderBrush="Gray" BorderThickness="1">
            <StackPanel Name="PanelPasos" Margin="6"/>
        </ScrollViewer>

        <TextBox Name="TxtLog" Grid.Row="3" Margin="0,10,0,0" IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                 HorizontalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11" TextWrapping="NoWrap"/>

        <ProgressBar Name="Barra" Grid.Row="4" Height="18" Margin="0,10,0,6" Minimum="0" Maximum="100"/>

        <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="BtnIniciar" Content="Iniciar instalación" Width="160" Height="32" Margin="0,0,8,0"/>
            <Button Name="BtnCerrar" Content="Cerrar" Width="100" Height="32"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$TxtNVMe    = $window.FindName("TxtNVMe")
$TxtBackup  = $window.FindName("TxtBackup")
$ChkDocker  = $window.FindName("ChkDocker")
$ChkRed     = $window.FindName("ChkRed")
$PanelPasos = $window.FindName("PanelPasos")
$TxtLog     = $window.FindName("TxtLog")
$Barra      = $window.FindName("Barra")
$BtnIniciar = $window.FindName("BtnIniciar")
$BtnCerrar  = $window.FindName("BtnCerrar")

# Una fila de texto por paso, guardadas para poder actualizar el color/estado después
$script:FilasPaso = @{}
foreach ($p in $script:Pasos) {
    $fila = New-Object System.Windows.Controls.TextBlock
    $fila.Text = "  [ pendiente ]  $($p.Id) — $($p.Nombre)"
    $fila.Margin = "2"
    $fila.FontFamily = "Consolas"
    $PanelPasos.Children.Add($fila) | Out-Null
    $script:FilasPaso[$p.Id] = $fila
}

function Escribir-Log {
    param([string]$Texto)
    $TxtLog.AppendText("$Texto`r`n")
    $TxtLog.ScrollToEnd()
}

function Actualizar-Fila {
    param([string]$Id, [string]$Estado, [string]$Color)
    $p = $script:Pasos | Where-Object { $_.Id -eq $Id }
    $fila = $script:FilasPaso[$Id]
    $fila.Text = "  [ $Estado ]  $Id — $($p.Nombre)"
    $fila.Foreground = $Color
}

# ============================================================================
# Botón: iniciar instalación
# ============================================================================

$BtnIniciar.Add_Click({
    $BtnIniciar.IsEnabled = $false
    $script:LetraNVMe = $TxtNVMe.Text.Trim().TrimEnd(':')
    $carpetaBackup = $TxtBackup.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($carpetaBackup)) {
        Escribir-Log "ERROR: falta la carpeta de Google Drive para el backup (Paso 10 la necesita)."
        [System.Windows.MessageBox]::Show("Completá la carpeta de Google Drive antes de iniciar (el Paso 10 la necesita).", "Falta un dato") | Out-Null
        $BtnIniciar.IsEnabled = $true
        return
    }

    Escribir-Log "=== Instalación iniciada — $(Get-Date) ==="
    Escribir-Log "NVMe: ${script:LetraNVMe}:  |  Backup: $carpetaBackup  |  Docker opcional: $($ChkDocker.IsChecked)  |  Preparar red: $($ChkRed.IsChecked)"

    $pasosAEjecutar = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $script:Pasos) { $pasosAEjecutar.Add($p) }
    if ($ChkDocker.IsChecked) {
        $pasosAEjecutar.Insert(1, [PSCustomObject]@{ Id = "05"; Nombre = "Instalar Docker (respaldo opcional)"; Archivo = "05-instalar-docker.ps1"; Manual = $false })
        $fila = New-Object System.Windows.Controls.TextBlock
        $fila.Text = "  [ pendiente ]  05 — Instalar Docker (respaldo opcional)"
        $fila.Margin = "2"; $fila.FontFamily = "Consolas"
        $PanelPasos.Children.Insert(1, $fila) | Out-Null
        $script:FilasPaso["05"] = $fila
    }

    $total = $pasosAEjecutar.Count
    $hecho = 0
    $fallo = $false

    foreach ($p in $pasosAEjecutar) {
        if ($fallo) { break }
        Actualizar-Fila -Id $p.Id -Estado "corriendo..." -Color "Blue"
        Escribir-Log ""
        Escribir-Log ">>> Paso $($p.Id): $($p.Nombre)"
        $window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

        $rutaScript = Join-Path $script:CarpetaPasos $p.Archivo
        $argumentos = switch ($p.Id) {
            "02" { if ($ChkRed.IsChecked) { @("-LetraNVMe", $script:LetraNVMe, "-PermitirRed") } else { @("-LetraNVMe", $script:LetraNVMe) } }
            "10" { @("-CarpetaDrive", $carpetaBackup) }
            "15" { @("-LetraNVMe", $script:LetraNVMe) }
            default { @() }
        }

        try {
            $salida = & $rutaScript @argumentos 2>&1 | Out-String
            Escribir-Log $salida.TrimEnd()
        } catch {
            Escribir-Log "EXCEPCIÓN: $($_.Exception.Message)"
        }

        Start-Sleep -Seconds 2
        $ok = Test-Paso -Id $p.Id

        if ($ok) {
            Actualizar-Fila -Id $p.Id -Estado "OK" -Color "Green"
            Escribir-Log "<<< Paso $($p.Id) verificado: OK"
            $hecho++
            $Barra.Value = [math]::Round(($hecho / $total) * 100)
        } else {
            Actualizar-Fila -Id $p.Id -Estado "FALLÓ" -Color "Red"
            Escribir-Log "<<< Paso $($p.Id) NO PASÓ LA VERIFICACIÓN — instalación detenida acá."
            Escribir-Log "    Revisar el log de arriba, corregir, y volver a correr este instalador (los pasos ya OK no se repiten a mano, pero si se corre de nuevo sí se re-ejecutan todos — no hay resumen de dónde quedó todavía)."
            [System.Windows.MessageBox]::Show("El paso $($p.Id) ($($p.Nombre)) no pasó la verificación. Revisar el log antes de seguir.", "Instalación detenida") | Out-Null
            $fallo = $true
        }
    }

    if (-not $fallo) {
        Escribir-Log ""
        Escribir-Log "=== Instalación automática completa ==="
        Escribir-Log ""
        Escribir-Log "Quedan estos pasos MANUALES (necesitan login/token, no se automatizan a propósito):"
        foreach ($m in $script:PasosManuales) { Escribir-Log "  - $m" }
        [System.Windows.MessageBox]::Show("Instalación automática completa. Quedan pasos manuales listados en el log (Cloudflare, Tailscale, extensiones de VS Code).", "Listo") | Out-Null
    }

    $BtnIniciar.IsEnabled = $true
})

$BtnCerrar.Add_Click({ $window.Close() })

Escribir-Log "Instalador listo. Confirmá la letra del NVMe (ver el reporte del Paso 00 si no estás seguro) y la carpeta de backup, y presioná 'Iniciar instalación'."
Escribir-Log ""
Escribir-Log "IMPORTANTE: cada paso corre de forma directa, sin hilo aparte -- mientras un paso largo está"
Escribir-Log "corriendo (una descarga, una instalación), Windows puede marcar esta ventana como 'No responde'."
Escribir-Log "Es esperable, no significa que se colgó -- no cerrar la ventana, solo esperar a que el paso termine."
Escribir-Log ""
Escribir-Log "Nota: esta es la primera vez que se corre este instalador -- no se ha probado todavía en el equipo real del piloto."

$window.ShowDialog() | Out-Null
