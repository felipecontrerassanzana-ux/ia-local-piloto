<#
.SINOPSIS
  Instala y deja corriendo Open WebUI NATIVO en Windows (vía pip) — sin Docker.
  Ver docs/arquitectura/docker-y-recursos.md. Requiere Python (scripts/pasos/12-instalar-herramientas-dev.ps1).

  Confirmado en documentación oficial (docs.openwebui.com, 2026-08-27): "Python: Suitable
  for low-resource environments" — es un método soportado oficialmente, no un hack.

  Corregido 2026-08-27: sin configurar explícitamente, Open WebUI usa sus defaults internos
  (ChromaDB como vector store, sentence-transformers/all-MiniLM-L6-v2 para embeddings) —
  IGNORANDO a Qdrant y BGE-M3, que ya se instalan en este piloto pero nunca quedaban
  conectados. Ver docs/referencia/open-webui.md para el detalle completo del hallazgo.
#>

. "$PSScriptRoot\_elevar.ps1"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "Python no está instalado. Correr 12-instalar-herramientas-dev.ps1 primero." -ForegroundColor Red
    exit 1
}

$dataDir = "C:\OpenWebUIData"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

$openwebui = Get-Command open-webui -ErrorAction SilentlyContinue
if ($openwebui) {
    Write-Host "Open WebUI ya está instalado." -ForegroundColor Green
} else {
    Write-Host "Instalando Open WebUI vía pip (puede tardar varios minutos, instala varias dependencias)..." -ForegroundColor Cyan
    pip install open-webui
}

# Registrar como Tarea Programada para que arranque solo con Windows (ver docs/operacion/mantenimiento.md §1)
$existe = Get-ScheduledTask -TaskName "OpenWebUI-Local" -ErrorAction SilentlyContinue
if ($existe) {
    Write-Host "La tarea programada 'OpenWebUI-Local' ya existe." -ForegroundColor Yellow
} else {
    $openwebuiPath = (Get-Command open-webui).Source
    $accion = New-ScheduledTaskAction -Execute $openwebuiPath -Argument "serve" -WorkingDirectory $dataDir
    $disparador = New-ScheduledTaskTrigger -AtStartup
    $config = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName "OpenWebUI-Local" -Action $accion -Trigger $disparador -Settings $config -User "SYSTEM" -RunLevel Highest -Force | Out-Null

    # DATA_DIR se fija como variable de entorno de sistema para que la tarea programada la use
    [Environment]::SetEnvironmentVariable("DATA_DIR", $dataDir, "Machine")
    Write-Host "Tarea programada 'OpenWebUI-Local' creada — arranca con Windows, sin necesitar sesión abierta." -ForegroundColor Green
}

# --- Conectar Open WebUI a Qdrant y BGE-M3 (ver docs/referencia/open-webui.md) ---
# Sin esto, Open WebUI usa sus defaults internos (ChromaDB + sentence-transformers/all-MiniLM-L6-v2),
# ignorando en silencio a Qdrant y BGE-M3 aunque ambos ya estén instalados y corriendo.
Write-Host "Configurando Open WebUI para usar Qdrant (RAG) y BGE-M3 vía Ollama (embeddings)..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("VECTOR_DB", "qdrant", "Machine")
[Environment]::SetEnvironmentVariable("QDRANT_URI", "http://localhost:6333", "Machine")
[Environment]::SetEnvironmentVariable("RAG_EMBEDDING_ENGINE", "ollama", "Machine")
[Environment]::SetEnvironmentVariable("RAG_EMBEDDING_MODEL", "bge-m3", "Machine")
[Environment]::SetEnvironmentVariable("RAG_OLLAMA_BASE_URL", "http://localhost:11434", "Machine")

Write-Host "Reiniciando Open WebUI para que tome las variables de entorno nuevas (VECTOR_DB, RAG_*)..." -ForegroundColor Cyan
Stop-ScheduledTask -TaskName "OpenWebUI-Local" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-ScheduledTask -TaskName "OpenWebUI-Local"
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "Open WebUI debería estar corriendo en http://localhost:8080" -ForegroundColor Green
Write-Host "(nota: puerto 8080 nativo, no 3000 — ese remapeo era específico del contenedor Docker)." -ForegroundColor Yellow
Write-Host "Datos guardados en: $dataDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "PASO MANUAL IMPORTANTE:" -ForegroundColor Yellow
Write-Host "  Entra a http://localhost:8080 y crea la PRIMERA cuenta ahora mismo." -ForegroundColor Yellow
Write-Host "  Esa cuenta queda como administrador, y el registro público se cierra automáticamente" -ForegroundColor Yellow
Write-Host "  (comportamiento por defecto de Open WebUI, ver docs/operacion/acceso-remoto.md) — no dejar esto para después." -ForegroundColor Yellow
Write-Host ""
Write-Host "En Settings > Connections de Open WebUI, confirmar que apunta a Ollama en http://localhost:11434" -ForegroundColor Cyan
Write-Host "(nativo también, así que localhost normal alcanza — ya no hace falta host.docker.internal)." -ForegroundColor Cyan
Write-Host ""
Write-Host "Verificar en Settings > Admin > Documents que el motor de embeddings sea 'bge-m3' (no el default" -ForegroundColor Cyan
Write-Host "de fábrica, sentence-transformers) y que Settings > Admin > Database/Vector muestre Qdrant conectado." -ForegroundColor Cyan
