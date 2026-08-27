@echo off
:: NO necesita permisos de administrador — solo analiza texto, no ejecuta ni instala nada.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1"
echo.
pause
