<#
.SINOPSIS
  Configura Ollama: contexto largo (OLLAMA_CONTEXT_LENGTH) y ubicación de modelos en el NVMe (OLLAMA_MODELS).
  Ver docs/arquitectura/04-almacenamiento.md y docs/herramientas/01-herramientas-trabajo.md para el porqué de cada valor.

  Corregido 2026-08-27: los modelos van al NVMe, no al HDD como se planeó originalmente — con el
  diseño de intercambio de modelos bajo demanda (coder / revisor visual / generador de imágenes,
  ver docs/arquitectura/02-capa-diseno.md), cada modelo se lee del disco varias veces por sesión de trabajo, no
  una sola vez al arrancar. En HDD eso son ~30s de espera por cada cambio de tarea; en NVMe, 1-2s.

.PARAMETER LetraNVMe
  Letra de la unidad del NVMe (ej. "C"). AJUSTAR antes de correr — no asumir, confirmar con
  00-verificar-equipo.ps1 cuál letra es realmente el NVMe en este equipo.

.PARAMETER ContextoTokens
  Cuántos tokens de contexto pedirle a Ollama. 100000 es el máximo seguro confirmado para
  Qwen 2.5 Coder 7B en esta GPU (ver docs/modelo/02-modelo-elegido.md) — pero ver también la nota sobre
  el límite de 32K que Ollama declara por defecto en el modelo empaquetado, a verificar.

.PARAMETER PermitirRed
  Switch opcional. Por defecto Ollama solo escucha en localhost (nadie fuera de este equipo
  puede alcanzarlo). Si se pasa -PermitirRed, se configura OLLAMA_HOST=0.0.0.0 para que también
  responda a la IP de la red local y de Tailscale — necesario para los Escenarios B y C1 de
  docs/herramientas/02-qwen-code-a-fondo.md (Qwen Code/Goose desde otro dispositivo). No activar si no se va a
  usar ninguno de esos escenarios — mantiene la superficie expuesta al mínimo por defecto.
#>

param(
    [string]$LetraNVMe = "C",
    [int]$ContextoTokens = 32000,
    [switch]$PermitirRed
)

. "$PSScriptRoot\_elevar.ps1"

$modelsPath = "${LetraNVMe}:\OllamaModels"

Write-Host "Configurando variables de entorno de sistema para Ollama..." -ForegroundColor Cyan
Write-Host "  OLLAMA_MODELS -> $modelsPath (NVMe)"
Write-Host "  OLLAMA_CONTEXT_LENGTH -> $ContextoTokens"
if ($PermitirRed) {
    Write-Host "  OLLAMA_HOST -> 0.0.0.0 (accesible desde la red local y desde Tailscale)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Si $LetraNVMe no es la letra real del NVMe en este equipo, cancela (Ctrl+C) y" -ForegroundColor Yellow
Write-Host "vuelve a correr con -LetraNVMe <letra correcta>, ej: .\02-configurar-ollama.ps1 -LetraNVMe D" -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Seconds 3

New-Item -ItemType Directory -Force -Path $modelsPath | Out-Null

[Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $modelsPath, "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_CONTEXT_LENGTH", $ContextoTokens, "Machine")

if ($PermitirRed) {
    [Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "Machine")
} else {
    [Environment]::SetEnvironmentVariable("OLLAMA_HOST", $null, "Machine")
}

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
