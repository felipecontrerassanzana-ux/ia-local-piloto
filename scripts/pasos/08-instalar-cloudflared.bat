@echo off
:: Lanzador con permisos elevados para 08-instalar-cloudflared.ps1
:: Este script pide el token del tunel (ver instrucciones dentro del .ps1) antes de elevar.
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Este script necesita permisos de administrador. Solicitando elevacion...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
set /p CFTOKEN="Pega aqui el token del tunel de Cloudflare (ver instrucciones en 08-instalar-cloudflared.ps1): "
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" -Token "%CFTOKEN%"
echo.
pause
