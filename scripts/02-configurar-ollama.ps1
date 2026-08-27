<#
.SINOPSIS
  Configura Ollama: contexto largo (OLLAMA_CONTEXT_LENGTH) y ubicación de modelos en el HDD (OLLAMA_MODELS).
  Ver docs/almacenamiento.md y docs/herramientas-trabajo.md para el porqué de cada valor.

.PARAMETER LetraHDD
  Letra de la unidad del HDD (ej. "D"). AJUSTAR antes de correr — no asumir, confirmar con
  00-verificar-equipo.ps1 cuál letra es realmente el HDD en este equipo.

.PARAMETER ContextoTokens
  Cuántos tokens de contexto pedirle a Ollama. 100000 es el máximo seguro confirmado para
  Qwen 2.5 Coder 7B en esta GPU (ver docs/modelo-elegido.md) — pero ver también la nota sobre
  el límite de 32K que Ollama declara por defecto en el modelo empaquetado, a verificar.
#>

param(
    [string]$LetraHDD = "D",
    [int]$ContextoTokens = 32000
)

. "$PSScriptRoot\_elevar.ps1"

$modelsPath = "${LetraHDD}:\OllamaModels"

Write-Host "Configurando variables de entorno de sistema para Ollama..." -ForegroundColor Cyan
Write-Host "  OLLAMA_MODELS -> $modelsPath"
Write-Host "  OLLAMA_CONTEXT_LENGTH -> $ContextoTokens"
Write-Host ""
Write-Host "Si $LetraHDD no es la letra real del HDD en este equipo, cancela (Ctrl+C) y" -ForegroundColor Yellow
Write-Host "vuelve a correr con -LetraHDD <letra correcta>, ej: .\02-configurar-ollama.ps1 -LetraHDD E" -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Seconds 3

New-Item -ItemType Directory -Force -Path $modelsPath | Out-Null

[Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $modelsPath, "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_CONTEXT_LENGTH", $ContextoTokens, "Machine")

Write-Host "Variables configuradas a nivel de sistema." -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANTE: hay que cerrar Ollama por completo (icono en la bandeja del sistema > Salir)" -ForegroundColor Yellow
Write-Host "y volver a abrirlo (o reiniciar el equipo) para que tome estas variables." -ForegroundColor Yellow

# Intentar cerrar el proceso si está corriendo, para forzar que la próxima vez arranque con las nuevas variables
Get-Process -Name "ollama app","ollama" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Procesos de Ollama detenidos (si estaban corriendo). Vuelve a abrir Ollama desde el menú Inicio." -ForegroundColor Cyan
Write-Host ""
Write-Host "Después de reabrir Ollama, verifica con: ollama ps  (mientras un modelo esté cargado, la columna CONTEXT debe mostrar $ContextoTokens, no 4096)." -ForegroundColor Cyan
