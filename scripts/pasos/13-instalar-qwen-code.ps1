<#
.SINOPSIS
  Instala Node.js (si falta) y Qwen Code (github.com/QwenLM/qwen-code) vía npm, y deja
  configurado el proveedor de modelo apuntando al Ollama local de este equipo.
  Ver docs/herramientas/01-herramientas-trabajo.md § "extensión Qwen para VS Code".

  IDs/paquetes verificados 2026-08-26: OpenJS.NodeJS.LTS (winget), @qwen-code/qwen-code (npm).
  generationConfig verificado 2026-08-27 contra el ejemplo oficial de la doc de Qwen Code para
  "Local Self-Hosted Models (via OpenAI-compatible API)" — timeout/streamIdleTimeoutMs/maxRetries
  más generosos que el default, porque un modelo local en hardware modesto puede tardar más en
  responder que un modelo en la nube, y sin esto Qwen Code podría cortar la espera antes de tiempo.
#>

. "$PSScriptRoot\_elevar.ps1"

# --- Node.js (requisito de Qwen Code: v22+) ---
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    Write-Host "Node.js ya está instalado: $(node --version)" -ForegroundColor Green
} else {
    Write-Host "Instalando Node.js LTS vía winget..." -ForegroundColor Cyan
    winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
    Write-Host "Puede que haga falta cerrar y volver a abrir la terminal para que 'node'/'npm' se reconozcan." -ForegroundColor Yellow
}

# --- Qwen Code ---
$qwen = Get-Command qwen -ErrorAction SilentlyContinue
if ($qwen) {
    Write-Host "Qwen Code ya está instalado: $(qwen --version 2>$null)" -ForegroundColor Green
} else {
    Write-Host "Instalando Qwen Code vía npm..." -ForegroundColor Cyan
    npm install -g "@qwen-code/qwen-code@latest"
}

# --- Configurar el proveedor de modelo -> Ollama local ---
$configDir = "$env:USERPROFILE\.qwen"
$configPath = "$configDir\settings.json"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

if (Test-Path $configPath) {
    Write-Host "Ya existe $configPath — no se sobrescribe automáticamente." -ForegroundColor Yellow
    Write-Host "Agregar a mano el bloque 'modelProviders' de docs/herramientas/01-herramientas-trabajo.md si no está." -ForegroundColor Yellow
} else {
    $config = @{
        env           = @{ OLLAMA_API_KEY = "ollama" }
        modelProviders = @{
            openai = @(
                @{
                    id             = "qwen2.5-coder-7b"
                    name           = "Qwen 2.5 Coder 7B (Ollama local)"
                    envKey         = "OLLAMA_API_KEY"
                    baseUrl        = "http://localhost:11434/v1"
                    generationConfig = @{
                        timeout             = 300000
                        streamIdleTimeoutMs = 600000
                        maxRetries          = 1
                        contextWindowSize   = 32000
                        samplingParams      = @{ temperature = 0.7; top_p = 0.9; max_tokens = 4096 }
                    }
                }
            )
        }
    }
    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding utf8
    Write-Host "Configuración creada en $configPath, apuntando a Ollama local (localhost:11434)." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Siguiente paso ===" -ForegroundColor Cyan
Write-Host "En terminal: qwen   (elegir el proveedor 'qwen2.5-coder-7b' si pregunta)" -ForegroundColor White
Write-Host "En VS Code: instalar la extensión 'Qwen Code' desde el Marketplace (Beta, VS Code 1.96+)." -ForegroundColor White
