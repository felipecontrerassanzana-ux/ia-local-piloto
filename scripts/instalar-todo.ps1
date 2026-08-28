<#
.SINOPSIS
  Instalador único con interfaz gráfica (WPF nativo de Windows, sin Python) para todo el
  piloto. Corre los scripts 00-16 en el ORDEN REAL de dependencias (no el orden numérico de
  archivo -- ver docs/instalacion/01-plan-instalacion.md, ej. 07 necesita 12 primero aunque el
  número de archivo diga lo contrario), verificando cada paso antes de seguir al siguiente.

  Pasos que necesitan login/token (Cloudflare, Tailscale) quedan deliberadamente AL FINAL,
  listados con instrucciones -- no pausan la instalación automática (decisión de Felipe,
  2026-08-27, ver docs/decisiones.md).

  No reemplaza los scripts individuales -- los reutiliza tal cual (viven en scripts/pasos/,
  ver docs/instalacion/02-aprendizaje-scripts.md), en el orden correcto, con verificación
  automática entre cada uno. `verificar-instalacion.ps1` sigue existiendo aparte como
  herramienta independiente (chequeos en cualquier momento, no ligados a una instalación en
  curso) -- al terminar la instalación automática, este instalador también ofrece correrlo
  como paso opcional (pregunta sí/no, no obliga, y no es uno de los 12 pasos del array
  $Pasos -- agregado 2026-08-27, a pedido de Felipe).

  Interfaz con 3 pestañas (agregado 2026-08-27, a pedido de Felipe): Progreso (checklist +
  parámetros), Consola (lo que cada script va imprimiendo), y Logs generados (los archivos
  que los scripts individuales dejan en logs/, ver scripts/README.md § Logs).

  Rediseño visual (2026-08-27, mismo día, a pedido de Felipe -- "está muy blanco"): tema
  oscuro tipo editor de código, resumen fijo del equipo (CPU/RAM/GPU/discos, leído directo
  por WMI al abrir, sin depender de que el Paso 00 ya haya corrido), indicador de estado por
  paso (punto de color, no solo texto) y progreso con número de pasos + tiempo transcurrido.
#>

. "$PSScriptRoot\pasos\_elevar.ps1"

$script:CarpetaPasos = Join-Path $PSScriptRoot "pasos"
$script:CarpetaLogs = Join-Path (Split-Path $PSScriptRoot -Parent) "logs"

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
    [PSCustomObject]@{ Id = "16"; Nombre = "Instalar monitor de estado (dashboard)";    Archivo = "16-instalar-monitor-estado.ps1"; Manual = $false }
)

# Pasos que se listan al final, no se automatizan (necesitan login/token) — ver arriba
$script:PasosManuales = @(
    "08 — Cloudflare Tunnel: crear el túnel en el dashboard de Cloudflare Zero Trust, pegar el token, y correr scripts\pasos\08-instalar-cloudflared.bat -Token <token>."
    "14 — Tailscale: correr scripts\pasos\14-instalar-tailscale.bat, después 'tailscale up' en una terminal para autenticar por navegador."
    "VS Code: instalar desde el Marketplace las extensiones 'Qwen Code' y 'Continue.dev' (no se puede automatizar la instalación de extensiones de otro programa)."
    "Open WebUI: entrar a http://localhost:8080 y crear la primera cuenta (queda como admin)."
    "Monitor de estado (opcional): para verlo desde internet, agregar una segunda 'Public Hostname' al mismo túnel de Cloudflare del paso 08, apuntando a http://localhost:8090 -- queda protegido por el mismo Cloudflare Access. Sin este paso, el monitor sigue funcionando local (http://localhost:8090) y por Tailscale."
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
            "16" {
                $tarea = Get-ScheduledTask -TaskName "Monitor-Estado-Local" -ErrorAction SilentlyContinue
                if (-not $tarea) { return $false }
                try { Invoke-WebRequest -Uri "http://localhost:8090/estado" -TimeoutSec 5 -UseBasicParsing | Out-Null; return $true } catch { return $false }
            }
            default { return $true }
        }
    } catch {
        return $false
    }
}

# ============================================================================
# XAML de la ventana — tema oscuro, 3 pestañas: Progreso, Consola, Logs generados
# ============================================================================

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Instalador — IA Local Piloto" Height="880" Width="920"
        WindowStartupLocation="CenterScreen" Background="#1E1E1E" Foreground="#D4D4D4">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#D4D4D4"/>
        </Style>
        <Style TargetType="GroupBox">
            <Setter Property="Foreground" Value="#D4D4D4"/>
            <Setter Property="BorderBrush" Value="#3C3C3C"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#D4D4D4"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="Foreground" Value="#D4D4D4"/>
            <Setter Property="BorderBrush" Value="#3C3C3C"/>
            <Setter Property="CaretBrush" Value="#D4D4D4"/>
            <Setter Property="Padding" Value="4"/>
        </Style>
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="Foreground" Value="#D4D4D4"/>
            <Setter Property="BorderBrush" Value="#3C3C3C"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#D4D4D4"/>
            <Setter Property="BorderBrush" Value="#3C3C3C"/>
            <Setter Property="Padding" Value="6,4"/>
        </Style>
        <Style TargetType="ProgressBar">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="BorderBrush" Value="#3C3C3C"/>
            <Setter Property="Foreground" Value="#4FC3F7"/>
        </Style>
        <Style TargetType="TabControl">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="BorderBrush" Value="#3C3C3C"/>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Foreground" Value="#B0B0B0"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Bd" Background="#252526" BorderBrush="#3C3C3C" BorderThickness="1,1,1,0" Margin="0,0,2,0">
                            <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#1E1E1E"/>
                                <Setter Property="Foreground" Value="#4FC3F7"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="12" Background="#1E1E1E">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="IA Local Piloto — Instalación completa" FontSize="18" FontWeight="Bold" Foreground="#4FC3F7" Margin="0,0,0,10"/>

        <Border Grid.Row="1" Background="#252526" BorderBrush="#3C3C3C" BorderThickness="1" CornerRadius="4" Padding="10,8" Margin="0,0,0,10">
            <StackPanel>
                <TextBlock Text="Equipo detectado" FontWeight="Bold" Foreground="#4FC3F7" Margin="0,0,0,4"/>
                <TextBlock Name="TxtResumenEquipo" Text="Leyendo specs del equipo..." TextWrapping="Wrap" FontFamily="Consolas" FontSize="11"/>
            </StackPanel>
        </Border>

        <TabControl Grid.Row="2" Name="Pestanas">

            <TabItem Header="Progreso">
                <Grid Margin="8" Background="#1E1E1E">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <GroupBox Grid.Row="0" Header="Parámetros" Margin="0,0,0,10" Padding="8">
                        <StackPanel>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                                <TextBlock Text="Letra del disco NVMe:" Width="220" VerticalAlignment="Center"/>
                                <TextBox Name="TxtNVMe" Width="40" Text="C"/>
                                <TextBlock Text="  (confirmar con el reporte del Paso 00 antes de avanzar)" FontStyle="Italic" Foreground="#9A9A9A" VerticalAlignment="Center"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                                <TextBlock Text="Carpeta de Google Drive (backup):" Width="220" VerticalAlignment="Center"/>
                                <TextBox Name="TxtBackup" Width="400" Text=""/>
                            </StackPanel>
                            <CheckBox Name="ChkDocker" Content="Instalar Docker también (opcional/respaldo, normalmente no hace falta)" Margin="0,4,0,0"/>
                            <CheckBox Name="ChkRed" Content="Preparar el equipo para conexión remota de agentes (activa OLLAMA_HOST=0.0.0.0 — instalar Tailscale aparte después)" Margin="0,4,0,0"/>
                        </StackPanel>
                    </GroupBox>

                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Background="#1E1E1E" BorderBrush="#3C3C3C" BorderThickness="1">
                        <StackPanel Name="PanelPasos" Margin="6"/>
                    </ScrollViewer>
                </Grid>
            </TabItem>

            <TabItem Header="Consola">
                <Grid Margin="8" Background="#1E1E1E">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Margin="0,0,0,6" TextWrapping="Wrap" Foreground="#9A9A9A"
                               Text="Lo que cada script va imprimiendo, paso por paso, a medida que corre — esto es la salida real de scripts\pasos\*.ps1, no un resumen."/>
                    <TextBox Name="TxtLog" Grid.Row="1" IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                             HorizontalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11" TextWrapping="NoWrap"/>
                </Grid>
            </TabItem>

            <TabItem Header="Logs generados">
                <Grid Margin="8" Background="#1E1E1E">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Margin="0,0,0,6" TextWrapping="Wrap" Foreground="#9A9A9A"
                               Text="Archivos que algunos scripts dejan aparte en logs/ (ej. la prueba de estrés genera un .csv y un resumen) — no todos los pasos generan uno, la mayoría solo imprimen en la pestaña Consola."/>
                    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,8">
                        <Button Name="BtnAbrirLogs" Content="Abrir carpeta de logs" Width="180" Height="28" Margin="0,0,8,0"/>
                        <Button Name="BtnActualizarLogs" Content="Actualizar lista" Width="140" Height="28"/>
                    </StackPanel>
                    <ListBox Name="ListaLogs" Grid.Row="2" FontFamily="Consolas" FontSize="11"/>
                </Grid>
            </TabItem>

        </TabControl>

        <TextBlock Grid.Row="3" Name="TxtProgresoInfo" Text="Sin iniciar" Margin="0,8,0,2" FontFamily="Consolas" FontSize="11" Foreground="#9A9A9A"/>

        <ProgressBar Name="Barra" Grid.Row="4" Height="18" Margin="0,2,0,6" Minimum="0" Maximum="100"/>

        <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="BtnIniciar" Content="Iniciar instalación" Width="160" Height="32" Margin="0,0,8,0" Background="#0E639C" Foreground="White" FontWeight="Bold"/>
            <Button Name="BtnCerrar" Content="Cerrar" Width="100" Height="32"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# La altura fija (880) puede no entrar en pantallas más chicas o con la barra de tareas
# ocupando espacio -- se ajusta acá, antes de mostrar la ventana, para que entre siempre
# sin que haya que reposicionarla a mano (reportado por Felipe, 2026-08-27).
$margenPantalla = 60
$alturaDisponible = [System.Windows.SystemParameters]::WorkArea.Height - $margenPantalla
$anchoDisponible = [System.Windows.SystemParameters]::WorkArea.Width - $margenPantalla
if ($window.Height -gt $alturaDisponible) { $window.Height = $alturaDisponible }
if ($window.Width -gt $anchoDisponible) { $window.Width = $anchoDisponible }

$TxtNVMe           = $window.FindName("TxtNVMe")
$TxtBackup         = $window.FindName("TxtBackup")
$ChkDocker         = $window.FindName("ChkDocker")
$ChkRed            = $window.FindName("ChkRed")
$PanelPasos        = $window.FindName("PanelPasos")
$TxtLog            = $window.FindName("TxtLog")
$Barra             = $window.FindName("Barra")
$BtnIniciar        = $window.FindName("BtnIniciar")
$BtnCerrar         = $window.FindName("BtnCerrar")
$Pestanas          = $window.FindName("Pestanas")
$ListaLogs         = $window.FindName("ListaLogs")
$BtnAbrirLogs      = $window.FindName("BtnAbrirLogs")
$BtnActualizarLogs = $window.FindName("BtnActualizarLogs")
$TxtResumenEquipo  = $window.FindName("TxtResumenEquipo")
$TxtProgresoInfo   = $window.FindName("TxtProgresoInfo")

# ============================================================================
# Filas de pasos: punto de color + texto, no solo texto (agregado 2026-08-27)
# ============================================================================

$script:FilasPaso = @{}
$script:NombresPaso = @{}

$script:EstadosPaso = @{
    pendiente = @{ Texto = "pendiente";     ColorTexto = "#D4D4D4"; ColorPunto = "#6E6E6E"; ColorFondo = "Transparent" }
    corriendo = @{ Texto = "corriendo..."; ColorTexto = "#4FC3F7"; ColorPunto = "#4FC3F7"; ColorFondo = "#264F78" }
    ok        = @{ Texto = "OK";            ColorTexto = "#6A9955"; ColorPunto = "#6A9955"; ColorFondo = "Transparent" }
    fallo     = @{ Texto = "FALLÓ";         ColorTexto = "#F44747"; ColorPunto = "#F44747"; ColorFondo = "#4B1818" }
}

function Agregar-FilaPaso {
    param([string]$Id, [string]$Nombre, [int]$Indice = -1)

    $script:NombresPaso[$Id] = $Nombre

    $borde = New-Object System.Windows.Controls.Border
    $borde.Padding = "6,3"
    $borde.Margin = "0,1"
    $borde.CornerRadius = 3

    $panelFila = New-Object System.Windows.Controls.StackPanel
    $panelFila.Orientation = "Horizontal"

    $punto = New-Object System.Windows.Shapes.Ellipse
    $punto.Width = 10
    $punto.Height = 10
    $punto.Margin = "0,0,8,0"
    $punto.VerticalAlignment = "Center"
    $punto.Fill = $script:EstadosPaso.pendiente.ColorPunto

    $texto = New-Object System.Windows.Controls.TextBlock
    $texto.FontFamily = "Consolas"
    $texto.VerticalAlignment = "Center"
    $texto.Foreground = $script:EstadosPaso.pendiente.ColorTexto
    $texto.Text = "  pendiente   $Id — $Nombre"

    $panelFila.Children.Add($punto) | Out-Null
    $panelFila.Children.Add($texto) | Out-Null
    $borde.Child = $panelFila

    if ($Indice -ge 0) {
        $PanelPasos.Children.Insert($Indice, $borde) | Out-Null
    } else {
        $PanelPasos.Children.Add($borde) | Out-Null
    }

    $script:FilasPaso[$Id] = [PSCustomObject]@{ Borde = $borde; Punto = $punto; Texto = $texto }
}

foreach ($p in $script:Pasos) { Agregar-FilaPaso -Id $p.Id -Nombre $p.Nombre }

function Escribir-Log {
    param([string]$Texto)
    $TxtLog.AppendText("$Texto`r`n")
    $TxtLog.ScrollToEnd()
}

function Actualizar-Fila {
    param([string]$Id, [string]$Tipo)
    $info = $script:FilasPaso[$Id]
    $e = $script:EstadosPaso[$Tipo]
    $info.Texto.Text = "  $($e.Texto)   $Id — $($script:NombresPaso[$Id])"
    $info.Texto.Foreground = $e.ColorTexto
    $info.Punto.Fill = $e.ColorPunto
    $info.Borde.Background = $e.ColorFondo
}

function Actualizar-ListaLogs {
    $ListaLogs.Items.Clear()
    if (Test-Path $script:CarpetaLogs) {
        $archivos = Get-ChildItem $script:CarpetaLogs -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        if ($archivos) {
            foreach ($a in $archivos) { $ListaLogs.Items.Add("$($a.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))   $($a.Name)") | Out-Null }
        } else {
            $ListaLogs.Items.Add("(carpeta logs/ vacía todavía — algunos pasos, como la prueba de estrés, todavía no corrieron)") | Out-Null
        }
    } else {
        $ListaLogs.Items.Add("(carpeta logs/ no existe todavía — se crea sola cuando un script escribe el primer log)") | Out-Null
    }
}

# ============================================================================
# Resumen fijo del equipo — lectura directa por WMI al abrir, no depende de
# que el Paso 00 ya haya corrido (agregado 2026-08-27)
# ============================================================================

function Actualizar-ResumenEquipo {
    try {
        $cpu = (Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1).Name
        $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB, 1)

        $gpuInfo = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "NVIDIA" } | Select-Object -First 1
        $gpu = if ($gpuInfo) { $gpuInfo.Name } else { "no detectada vía WMI (ver Paso 00)" }

        $discos = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | ForEach-Object {
            $libreGB = [math]::Round($_.SizeRemaining / 1GB, 1)
            $totalGB = [math]::Round($_.Size / 1GB, 1)
            "$($_.DriveLetter): $libreGB/$totalGB GB libres"
        }
        $discosTexto = if ($discos) { $discos -join "   ·   " } else { "sin datos" }

        $TxtResumenEquipo.Text = "CPU: $cpu   |   RAM: $ramGB GB   |   GPU: $gpu`nDiscos: $discosTexto  (el tipo SSD/HDD de cada uno sale en el reporte del Paso 00)"
    } catch {
        $TxtResumenEquipo.Text = "No se pudo leer el resumen del equipo automáticamente. Correr el Paso 00 para el detalle completo."
    }
}

# ============================================================================
# Pestaña "Logs generados"
# ============================================================================

$BtnAbrirLogs.Add_Click({
    if (-not (Test-Path $script:CarpetaLogs)) {
        New-Item -ItemType Directory -Force -Path $script:CarpetaLogs | Out-Null
    }
    Start-Process explorer.exe $script:CarpetaLogs
})

$BtnActualizarLogs.Add_Click({ Actualizar-ListaLogs })

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

    $Pestanas.SelectedIndex = 1  # saltar a la pestaña "Consola" para que se vea el progreso en vivo

    Escribir-Log "=== Instalación iniciada — $(Get-Date) ==="
    Escribir-Log "NVMe: ${script:LetraNVMe}:  |  Backup: $carpetaBackup  |  Docker opcional: $($ChkDocker.IsChecked)  |  Preparar red: $($ChkRed.IsChecked)"

    $pasosAEjecutar = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $script:Pasos) { $pasosAEjecutar.Add($p) }
    if ($ChkDocker.IsChecked) {
        $pasosAEjecutar.Insert(1, [PSCustomObject]@{ Id = "05"; Nombre = "Instalar Docker (respaldo opcional)"; Archivo = "05-instalar-docker.ps1"; Manual = $false })
        Agregar-FilaPaso -Id "05" -Nombre "Instalar Docker (respaldo opcional)" -Indice 1
    }

    $total = $pasosAEjecutar.Count
    $hecho = 0
    $fallo = $false
    $script:InicioInstalacion = Get-Date
    $TxtProgresoInfo.Text = "0/$total pasos completados · 0% · 0 min transcurridos"

    foreach ($p in $pasosAEjecutar) {
        if ($fallo) { break }
        Actualizar-Fila -Id $p.Id -Tipo "corriendo"
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
        $transcurrido = (Get-Date) - $script:InicioInstalacion
        $transcurridoTexto = "$([math]::Floor($transcurrido.TotalMinutes)) min $($transcurrido.Seconds) s"

        if ($ok) {
            Actualizar-Fila -Id $p.Id -Tipo "ok"
            Escribir-Log "<<< Paso $($p.Id) verificado: OK"
            $hecho++
            $Barra.Value = [math]::Round(($hecho / $total) * 100)
            $TxtProgresoInfo.Text = "$hecho/$total pasos completados · $($Barra.Value)% · $transcurridoTexto transcurridos"
        } else {
            Actualizar-Fila -Id $p.Id -Tipo "fallo"
            Escribir-Log "<<< Paso $($p.Id) NO PASÓ LA VERIFICACIÓN — instalación detenida acá."
            Escribir-Log "    Revisar el log de arriba, corregir, y volver a correr este instalador (los pasos ya OK no se repiten a mano, pero si se corre de nuevo sí se re-ejecutan todos — no hay resumen de dónde quedó todavía)."
            $TxtProgresoInfo.Text = "$hecho/$total pasos completados · $($Barra.Value)% · $transcurridoTexto transcurridos · DETENIDO en el paso $($p.Id)"
            [System.Windows.MessageBox]::Show("El paso $($p.Id) ($($p.Nombre)) no pasó la verificación. Revisar el log en la pestaña 'Consola' antes de seguir.", "Instalación detenida") | Out-Null
            $fallo = $true
        }
    }

    Actualizar-ListaLogs

    if (-not $fallo) {
        Escribir-Log ""
        Escribir-Log "=== Instalación automática completa ==="
        Escribir-Log ""
        Escribir-Log "Quedan estos pasos MANUALES (necesitan login/token, no se automatizan a propósito):"
        foreach ($m in $script:PasosManuales) { Escribir-Log "  - $m" }
        [System.Windows.MessageBox]::Show("Instalación automática completa. Quedan pasos manuales listados en la pestaña 'Consola' (Cloudflare, Tailscale, extensiones de VS Code).", "Listo") | Out-Null

        $respuesta = [System.Windows.MessageBox]::Show("¿Querés correr 'verificar-instalación' ahora para confirmar que todo quedó funcionando?", "Verificar instalación", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($respuesta -eq [System.Windows.MessageBoxResult]::Yes) {
            Escribir-Log ""
            Escribir-Log "=== Corriendo verificar-instalacion.ps1 ==="
            $rutaVerificar = Join-Path $PSScriptRoot "verificar-instalacion.ps1"
            try {
                $salidaVerificacion = & $rutaVerificar 2>&1 | Out-String
                Escribir-Log $salidaVerificacion.TrimEnd()
            } catch {
                Escribir-Log "EXCEPCIÓN al correr verificar-instalacion.ps1: $($_.Exception.Message)"
            }
            Escribir-Log ""
            Escribir-Log "=== Fin de verificar-instalacion.ps1 ==="
        }
    }

    $BtnIniciar.IsEnabled = $true
})

$BtnCerrar.Add_Click({ $window.Close() })

Actualizar-ListaLogs
Actualizar-ResumenEquipo

Escribir-Log "Instalador listo. Confirmá la letra del NVMe (ver el reporte del Paso 00 si no estás seguro) y la carpeta de backup en la pestaña 'Progreso', y presioná 'Iniciar instalación'."
Escribir-Log ""
Escribir-Log "IMPORTANTE: cada paso corre de forma directa, sin hilo aparte -- mientras un paso largo está"
Escribir-Log "corriendo (una descarga, una instalación), Windows puede marcar esta ventana como 'No responde'."
Escribir-Log "Es esperable, no significa que se colgó -- no cerrar la ventana, solo esperar a que el paso termine."

$window.ShowDialog() | Out-Null
