<#
.SINOPSIS
  Revisa TODOS los .ps1 de esta carpeta sin instalar ni ejecutar nada de su contenido:
  (1) sintaxis válida (parser de PowerShell) y (2) errores/malas prácticas comunes
  (PSScriptAnalyzer, el linter oficial de PowerShell). Correr esto después de editar
  cualquier script, antes de confiar en que funciona.

  No necesita permisos de administrador — solo lee y analiza texto, no ejecuta comandos
  reales (winget, docker, etc.) de los scripts que revisa.
#>

$carpeta = $PSScriptRoot
$scripts = Get-ChildItem "$carpeta\*.ps1" | Where-Object { $_.Name -ne "_verificar-sintaxis.ps1" }

Write-Host "=== 1. Sintaxis (parser de PowerShell, no ejecuta nada) ===" -ForegroundColor Cyan
$erroresSintaxis = 0
foreach ($s in $scripts) {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($s.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        Write-Host "[ERROR] $($s.Name)" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "    Línea $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red }
        $erroresSintaxis += $errors.Count
    } else {
        Write-Host "[OK] $($s.Name)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== 2. Codificación (acentos/ñ se ven bien al ejecutar vía powershell.exe -File) ===" -ForegroundColor Cyan
foreach ($s in $scripts) {
    $bytes = [System.IO.File]::ReadAllBytes($s.FullName)
    $tieneBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    if (-not $tieneBom) {
        Write-Host "[SIN BOM] $($s.Name) — los acentos se verán corruptos al ejecutarlo (confirmado empíricamente, ver decisiones.md 2026-08-26)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== 3. PSScriptAnalyzer (linter oficial — detecta errores y malas prácticas más allá de la sintaxis) ===" -ForegroundColor Cyan
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "Instalando PSScriptAnalyzer (solo para tu usuario, no afecta el equipo del piloto)..." -ForegroundColor Yellow
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber
}
Import-Module PSScriptAnalyzer

$resultados = Invoke-ScriptAnalyzer -Path "$carpeta\*.ps1" -Severity Warning, Error
if ($resultados) {
    $resultados | Sort-Object ScriptName, Line | Format-Table ScriptName, Line, Severity, RuleName, Message -AutoSize -Wrap
} else {
    Write-Host "Sin hallazgos." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Hallazgos aceptados a propósito (no son errores, revisar antes de 'arreglarlos') ===" -ForegroundColor Yellow
Write-Host "  PSAvoidUsingWriteHost: intencional — son scripts interactivos, no funciones de librería."
Write-Host "  PSUseApprovedVerbs: funciones con nombres en español (Invocar-Ollama, Registrar-GPU) por legibilidad, no por descuido."
Write-Host ""
Write-Host "Resumen: $erroresSintaxis error(es) de sintaxis, $($resultados.Count) hallazgo(s) de lint (ver cuáles son aceptados arriba)." -ForegroundColor Cyan
