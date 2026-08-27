@echo off
:: Lanzador con permisos elevados para 02-configurar-ollama.ps1
:: Pide la letra del disco HDD antes de elevar (confirmar con 00-verificar-equipo.bat cual es).
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Este script necesita permisos de administrador. Solicitando elevacion...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
set /p HDDLETTER="Letra de la unidad del HDD (ej. D), Enter para usar D por defecto: "
if "%HDDLETTER%"=="" set HDDLETTER=D
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" -LetraHDD "%HDDLETTER%"
echo.
pause
