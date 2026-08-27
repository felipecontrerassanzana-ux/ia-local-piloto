@echo off
:: Lanzador con permisos elevados (UAC) para el script de PowerShell del mismo nombre.
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Este script necesita permisos de administrador. Solicitando elevacion...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" %*
echo.
pause
