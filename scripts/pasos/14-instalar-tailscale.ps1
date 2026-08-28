<#
.SINOPSIS
  Instala Tailscale (winget) y deja el equipo listo para conectarse a la red privada — es el
  mecanismo elegido para conectar Qwen Code/Goose desde un dispositivo remoto (fuera de la red
  de casa) sin exponer nada a internet público. Ver docs/03-herramientas/02-qwen-code-a-fondo.md § "Escenario C1".

  Paquete verificado 2026-08-27: Tailscale.Tailscale (winget.run/pkg/tailscale/tailscale).

.NOTAS
  Este script NO configura OLLAMA_HOST=0.0.0.0 — eso sigue siendo un paso aparte
  (scripts/pasos/02-configurar-ollama.ps1 -PermitirRed), porque son dos decisiones independientes:
  "¿este equipo está en la red de Tailscale?" y "¿Ollama acepta conexiones que no sean de sí
  mismo?". Tailscale sin OLLAMA_HOST=0.0.0.0 no sirve para conectar Qwen Code remoto — hacen
  falta los dos.

  El login (`tailscale up`) es interactivo — abre una URL en el navegador para autenticar con
  tu cuenta. No se puede automatizar desde este script sin generar una auth key desde el
  dashboard (dashboard.tailscale.com), que es un paso manual y específico de tu cuenta, igual
  que el token de Cloudflare en 08-instalar-cloudflared.ps1.
#>

. "$PSScriptRoot\_elevar.ps1"

$tailscale = Get-Command tailscale -ErrorAction SilentlyContinue

if ($tailscale) {
    Write-Host "Tailscale ya está instalado: $(tailscale version | Select-Object -First 1)" -ForegroundColor Green
} else {
    Write-Host "Instalando Tailscale vía winget..." -ForegroundColor Cyan
    winget install --id Tailscale.Tailscale -e --accept-source-agreements --accept-package-agreements
    Write-Host "Puede que haga falta cerrar y volver a abrir la terminal para que 'tailscale' se reconozca." -ForegroundColor Yellow
}

Write-Host ""
$estado = tailscale status 2>$null
if ($LASTEXITCODE -eq 0 -and $estado) {
    Write-Host "Tailscale ya está conectado a una red (tailnet):" -ForegroundColor Green
    Write-Host $estado -ForegroundColor Gray
} else {
    Write-Host "=== Falta autenticar (paso manual, no se puede automatizar) ===" -ForegroundColor Cyan
    Write-Host "Correr en una terminal nueva: tailscale up" -ForegroundColor White
    Write-Host "Se abre una URL en el navegador — iniciar sesión con tu cuenta (Google/Microsoft/GitHub/correo)." -ForegroundColor White
}

Write-Host ""
Write-Host "Una vez conectado, la IP de Tailscale de este equipo se obtiene con: tailscale ip -4" -ForegroundColor Cyan
Write-Host "Esa IP es la que va en 'baseUrl' de ~/.qwen/settings.json cuando Qwen Code corre en otro dispositivo (ver docs/03-herramientas/02-qwen-code-a-fondo.md)." -ForegroundColor Cyan
Write-Host ""
Write-Host "Recordatorio: para que Ollama acepte esas conexiones remotas, correr también:" -ForegroundColor Yellow
Write-Host "  scripts\pasos\02-configurar-ollama.bat -PermitirRed" -ForegroundColor Yellow
