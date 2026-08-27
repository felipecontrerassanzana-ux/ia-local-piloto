@echo off
:: Lanzador con permisos elevados para 10-configurar-backup.ps1
:: Pide la ruta de la carpeta de Google Drive antes de elevar.
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Este script necesita permisos de administrador. Solicitando elevacion...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
set /p DRIVEFOLDER="Ruta de la carpeta de Google Drive para los backups (ej. C:\Users\%USERNAME%\Google Drive\ia-local-piloto-backups): "
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" -CarpetaDrive "%DRIVEFOLDER%"
echo.
pause
