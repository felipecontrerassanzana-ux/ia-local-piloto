@echo off
:: Lanzador con permisos elevados para instalar-todo.ps1 (instalador con GUI).
:: A diferencia de los demas .bat, este oculta la consola una vez elevado -- solo debe
:: quedar visible la ventana WPF, no una terminal de fondo (corregido 2026-08-27).
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%~dpn0.ps1\"' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dpn0.ps1"
