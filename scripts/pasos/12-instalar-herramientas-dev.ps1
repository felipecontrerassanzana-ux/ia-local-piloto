<#
.SINOPSIS
  Instala las herramientas base de desarrollo que le dan a Goose/Continue.dev/Aider la
  misma capacidad de "comitear a GitHub" que tiene este mismo entorno (git + gh CLI),
  más Python como herramienta de propósito general. Ver docs/herramientas/01-herramientas-trabajo.md.

  IDs de winget verificados en un equipo real (2026-08-26) antes de escribir este script.
#>

. "$PSScriptRoot\_elevar.ps1"

function Instalar-SiFalta($comando, $wingetId, $nombre) {
    if (Get-Command $comando -ErrorAction SilentlyContinue) {
        Write-Host "$nombre ya está instalado: $(& $comando --version 2>$null | Select-Object -First 1)" -ForegroundColor Green
    } else {
        Write-Host "Instalando $nombre vía winget ($wingetId)..." -ForegroundColor Cyan
        winget install --id $wingetId -e --accept-source-agreements --accept-package-agreements
    }
}

Instalar-SiFalta "git" "Git.Git" "Git"
Instalar-SiFalta "gh" "GitHub.cli" "GitHub CLI"
Instalar-SiFalta "python" "Python.Python.3.12" "Python 3.12"

Write-Host ""
Write-Host "=== Paso manual pendiente: autenticar gh ===" -ForegroundColor Yellow
Write-Host "gh auth login es interactivo (abre el navegador) — no se puede automatizar del todo." -ForegroundColor Yellow
Write-Host "Cierra y vuelve a abrir la terminal si 'gh'/'git'/'python' no se reconocen todavía (PATH)," -ForegroundColor Yellow
Write-Host "y después corre:" -ForegroundColor Yellow
Write-Host "  gh auth login" -ForegroundColor White
Write-Host ""
Write-Host "Con esto, Goose (extensión Developer, shell habilitado) puede correr git/gh" -ForegroundColor Cyan
Write-Host "exactamente igual que se usa en esta conversación con Claude Code." -ForegroundColor Cyan
