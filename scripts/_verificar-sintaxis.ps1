<#
.SINOPSIS
  Revisa TODOS los .ps1 de esta carpeta sin instalar ni ejecutar nada de su contenido:
  (1) sintaxis válida (parser de PowerShell) y (2) errores/malas prácticas comunes
  (PSScriptAnalyzer, el linter oficial de PowerShell). Correr esto después de editar
  cualquier script, antes de confiar en que funciona.

  No necesita permisos de administrador — solo lee y analiza texto, no ejecuta comandos
  reales (winget, docker, etc.) de los scripts que revisa.

  Código de salida: 0 si no hay errores de sintaxis ni archivos sin BOM (los hallazgos de
  lint no bloquean, incluyen los aceptados a propósito); 1 si hay algo real que corregir.
  Pensado para usarse desde `scripts/hooks/pre-commit` — ver docs/04-instalacion/02-aprendizaje-scripts.md.

  Escanea de forma recursiva (top-level: instalar-todo.ps1, verificar-instalacion.ps1;
  scripts/pasos/: los 17 módulos de instalación) — no asumir que todo vive en una sola carpeta.
#>

$carpeta = $PSScriptRoot
$scripts = Get-ChildItem "$carpeta\*.ps1" -Recurse | Where-Object { $_.Name -ne "_verificar-sintaxis.ps1" }

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
$archivosSinBom = 0
foreach ($s in $scripts) {
    $bytes = [System.IO.File]::ReadAllBytes($s.FullName)
    $tieneBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    if (-not $tieneBom) {
        Write-Host "[SIN BOM] $($s.Name) — los acentos se verán corruptos al ejecutarlo (confirmado empíricamente, ver decisiones.md 2026-08-26)" -ForegroundColor Red
        $archivosSinBom++
    }
}

Write-Host ""
Write-Host "=== 3. PSScriptAnalyzer (linter oficial — detecta errores y malas prácticas más allá de la sintaxis) ===" -ForegroundColor Cyan
$linterDisponible = $true
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "Instalando PSScriptAnalyzer (solo para tu usuario, no afecta el equipo del piloto)..." -ForegroundColor Yellow
    try {
        # En Windows PowerShell 5.1 (la que usan los .bat y los git hooks — distinta de pwsh/PowerShell 7,
        # que tiene su propia carpeta de módulos separada), Install-Module falla si el proveedor NuGet
        # no está bootstrapeado todavía. Confirmado empíricamente 2026-08-27: sin este paso, el error
        # "CouldNotInstallNuGetProvider" se traga silenciosamente el paso de lint completo.
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
        }
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    } catch {
        $linterDisponible = $false
        Write-Host "No se pudo instalar PSScriptAnalyzer automáticamente: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Instalar a mano una vez: Install-PackageProvider NuGet -Force; Install-Module PSScriptAnalyzer -Scope CurrentUser -Force" -ForegroundColor Yellow
    }
}

if ($linterDisponible) {
    try {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        $resultados = Invoke-ScriptAnalyzer -Path $carpeta -Recurse -Severity Warning, Error
    } catch {
        $linterDisponible = $false
        Write-Host "PSScriptAnalyzer está instalado pero no se pudo cargar: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not $linterDisponible) {
    $resultados = @()
    Write-Host "[SIN LINTER] Este paso no corrió — solo se validó sintaxis (paso 1) y codificación (paso 2), no malas prácticas." -ForegroundColor Red
} elseif ($resultados) {
    $resultados | Sort-Object ScriptName, Line | Format-Table ScriptName, Line, Severity, RuleName, Message -AutoSize -Wrap
} else {
    Write-Host "Sin hallazgos." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Hallazgos aceptados a propósito (no son errores, revisar antes de 'arreglarlos') ===" -ForegroundColor Yellow
Write-Host "  PSAvoidUsingWriteHost: intencional — son scripts interactivos, no funciones de librería."
Write-Host "  PSUseApprovedVerbs: funciones con nombres en español (Invocar-Ollama, Registrar-GPU) por legibilidad, no por descuido."
Write-Host ""
if ($linterDisponible) {
    Write-Host "Resumen: $erroresSintaxis error(es) de sintaxis, $archivosSinBom archivo(s) sin BOM, $($resultados.Count) hallazgo(s) de lint (ver cuáles son aceptados arriba)." -ForegroundColor Cyan
} else {
    Write-Host "Resumen: $erroresSintaxis error(es) de sintaxis, $archivosSinBom archivo(s) sin BOM. LINTER NO CORRIÓ (ver arriba) — esto no es '0 hallazgos', es que el paso 3 no se ejecutó." -ForegroundColor Red
}

if ($erroresSintaxis -gt 0 -or $archivosSinBom -gt 0) {
    Write-Host "RESULTADO: hay algo real que corregir antes de comitear." -ForegroundColor Red
    exit 1
} else {
    Write-Host "RESULTADO: OK para comitear." -ForegroundColor Green
    exit 0
}
