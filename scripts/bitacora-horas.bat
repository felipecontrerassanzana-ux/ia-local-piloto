@echo off
:: NO necesita permisos de administrador -- solo lee logs propios de esta cuenta de Windows
:: y escribe un archivo en logs/. Ver bitacora-horas.ps1 para el detalle completo.
::
:: Si todo sale bien, esta ventana se cierra sola y el navegador abre solo con el
:: resultado -- no hay que copiar ninguna ruta a mano. Si algo falla, la ventana
:: se queda abierta con el error para poder leerlo (no tiene sentido que desaparezca
:: justo cuando hay algo que revisar).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" -AbrirNavegador
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Hubo un error -- revisar el mensaje de arriba.
    pause
)
