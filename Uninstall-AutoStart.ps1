<#
.SYNOPSIS
    Desinstala el inicio automático del monitor de red VPN y detiene cualquier proceso activo.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$startupPath = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupPath "VPN-AutoReset-Watcher.lnk"
$pidFile = Join-Path $env:TEMP "vpn_network_watcher.pid"

Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host " Desinstalando Inicio Automatico del Monitor VPN          " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Yellow

# 1. Eliminar acceso directo de Inicio
if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Acceso directo eliminado de la carpeta de Inicio de Windows." -ForegroundColor Green
} else {
    Write-Host "[INFO] No se encontro acceso directo en la carpeta de Inicio." -ForegroundColor Gray
}

# 2. Detener proceso activo si está corriendo
if (Test-Path $pidFile) {
    try {
        $wPid = Get-Content $pidFile -ErrorAction SilentlyContinue
        if ($wPid) {
            $proc = Get-Process -Id $wPid -ErrorAction SilentlyContinue
            if ($proc) {
                Stop-Process -Id $wPid -Force -ErrorAction SilentlyContinue
                Write-Host "[OK] Proceso del monitor en segundo plano (PID: $wPid) detenido." -ForegroundColor Green
            }
        }
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    } catch {}
}

Write-Host "`nListo. El monitor ya no se ejecutara automaticamente." -ForegroundColor Green
