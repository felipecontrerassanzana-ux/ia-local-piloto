@echo off
:: NO necesita permisos de administrador -- solo lee logs propios de esta cuenta de Windows
:: y escribe un archivo en logs/. Ver bitacora-horas.ps1 para el detalle completo.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1"
echo.
pause
