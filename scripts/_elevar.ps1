# Fragmento reutilizado por todos los scripts: confirma que la sesión corre elevada.
# Los .bat ya elevan antes de llamar al .ps1, esto es una segunda confirmación
# por si alguien corre el .ps1 directo sin pasar por el .bat.

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script necesita permisos de administrador. Ejecuta el archivo .bat correspondiente en vez del .ps1 directo, o abre PowerShell como administrador." -ForegroundColor Red
    exit 1
}
