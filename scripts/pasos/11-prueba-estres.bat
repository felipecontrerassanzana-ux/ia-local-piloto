@echo off
:: Lanzador con permisos elevados para 11-prueba-estres.ps1
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Este script necesita permisos de administrador. Solicitando elevacion...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
set /p MODELOTEST="Tag del modelo a probar (Enter para usar qwen2.5-coder:7b-instruct-q8_0): "
if "%MODELOTEST%"=="" set MODELOTEST=qwen2.5-coder:7b-instruct-q8_0
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" -Modelo "%MODELOTEST%"
echo.
pause
