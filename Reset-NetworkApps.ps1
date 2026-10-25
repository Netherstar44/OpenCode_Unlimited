<#
.SYNOPSIS
    Resetea la caché de red (DNS, ARP, NetBIOS) y reinicia/limpia herramientas como OpenCode (CLI y Desktop).
.DESCRIPTION
    Al cambiar de VPN, Wi-Fi o IP, las herramientas en ejecución (como OpenCode Desktop y CLI)
    conservan conexiones TCP persistentes (HTTP Keep-Alive / WebSockets) y cachés DNS obsoletas,
    provocando errores de tiempo de espera (ETIMEDOUT, ECONNRESET, etc.).
    Este script limpia la caché del sistema y reinicia los procesos para que tomen la nueva red de inmediato.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$NoDesktop,

    [Parameter(Mandatory = $false)]
    [switch]$NoRestartDesktop,

    [Parameter(Mandatory = $false)]
    [switch]$NoKillCli,

    [Parameter(Mandatory = $false)]
    [switch]$NoFlushDns,

    [Parameter(Mandatory = $false)]
    [switch]$NoClearArp,

    [Parameter(Mandatory = $false)]
    [string[]]$ExtraProcesses = @(),

    [Parameter(Mandatory = $false)]
    [switch]$Silent,

    [Parameter(Mandatory = $false)]
    [switch]$NoNotification
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$HandleDesktop = -not $NoDesktop
$RestartDesktop = -not $NoRestartDesktop
$KillCli = -not $NoKillCli
$FlushDns = -not $NoFlushDns
$ClearArp = -not $NoClearArp
$SendNotification = -not $NoNotification

# Configuración de salida
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if ($Silent) { return }
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Level) {
        "SUCCESS" { Write-Host "[$timestamp] [OK]     $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "[$timestamp] [AVISO]  $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "[$timestamp] [ERROR]  $Message" -ForegroundColor Red }
        Default   { Write-Host "[$timestamp] [INFO]   $Message" -ForegroundColor Cyan }
    }
}

# Enviar Notificación Toast Nativa de Windows
function Send-WindowsNotification {
    param([string]$Title, [string]$Message)
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $textNodes = $template.GetElementsByTagName("text")
        $textNodes.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null
        $textNodes.Item(1).AppendChild($template.CreateTextNode($Message)) | Out-Null
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("VPN Network Auto-Reset")
        $notification = [Windows.UI.Notifications.ToastNotification]::new($template)
        $notifier.Show($notification)
    } catch {
        # Fallback silencioso si las notificaciones de Windows están deshabilitadas
    }
}

Write-Log "Iniciando restablecimiento de red y herramientas..."

# 1. Detectar si OpenCode Desktop está corriendo y guardar su ruta para reabrirlo
$desktopWasRunning = $false
$desktopPath = $null

if ($HandleDesktop) {
    $desktopProcesses = Get-Process -Name "OpenCode" -ErrorAction SilentlyContinue
    if ($desktopProcesses) {
        $desktopWasRunning = $true
        try {
            $desktopPath = $desktopProcesses[0].Path
        } catch {}
    }

    if (-not $desktopPath) {
        $potentialPath = "$env:LOCALAPPDATA\Programs\@opencodedesktop\OpenCode.exe"
        if (Test-Path $potentialPath) {
            $desktopPath = $potentialPath
        }
    }

    # 2. Cerrar OpenCode Desktop para matar sockets caídos
    if ($desktopWasRunning) {
        Write-Log "Cerrando OpenCode Desktop para liberar sockets de red..." "WARN"
        Stop-Process -Name "OpenCode" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
    }
}

# 3. Terminar instancias de OpenCode CLI, daemons y servicios
$cliCount = 0
if ($KillCli) {
    try { & opencode service stop 2>$null | Out-Null } catch {}

    $targetProcessNames = @("opencode", "opencode-cli")
    foreach ($pName in $targetProcessNames) {
        $cliProcesses = Get-Process -Name $pName -ErrorAction SilentlyContinue
        if ($cliProcesses) {
            $cliCount += $cliProcesses.Count
            Write-Log "Terminando $($cliProcesses.Count) proceso(s) de $pName..." "WARN"
            Stop-Process -Name $pName -Force -ErrorAction SilentlyContinue
        }
    }

    # Terminar ejecutables de servicio residuales
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*opencode-service*" } | ForEach-Object {
        Write-Log "Terminando proceso de servicio huérfano: $($_.ProcessName)..." "WARN"
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
}

# 4. Rotar Device ID e identidad para tokens ampliados
try {
    $updaterIdPath = "$env:APPDATA\ai.opencode.desktop\.updaterId"
    [guid]::NewGuid().ToString() | Set-Content -LiteralPath $updaterIdPath -Force -ErrorAction SilentlyContinue
    
    $serviceJson = "$env:USERPROFILE\.local\state\opencode\service.json"
    if (Test-Path $serviceJson) { Remove-Item -Path $serviceJson -Force -ErrorAction SilentlyContinue }

    # Limpiar cookies y tokens temporales
    $desktopApp = "$env:APPDATA\ai.opencode.desktop"
    @("Local Storage", "Session Storage", "IndexedDB", "Network\Cookies") | ForEach-Object {
        $targetP = Join-Path $desktopApp $_
        if (Test-Path $targetP) { Remove-Item -Path $targetP -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Log "Identidad y Device ID rotados (cuota virgen)." "SUCCESS"
} catch {}

# 5. Archivar sesiones infladas para desbloquear tokens limpios
try {
    $dbPath = "$env:USERPROFILE\.local\share\opencode\opencode.db"
    if (Test-Path $dbPath) {
        $pyCode = "import sqlite3, os, time; conn=sqlite3.connect(r'$dbPath'); cur=conn.cursor(); cur.execute('UPDATE session SET time_archived = ? WHERE time_archived IS NULL', (int(time.time()*1000),)); conn.commit(); conn.close()"
        python -c $pyCode 2>$null
        Write-Log "Sesiones infladas archivadas: contexto limpio activado." "SUCCESS"
    }
} catch {}

# 6. Procesos adicionales personalizados (si se especificaron)
foreach ($procName in $ExtraProcesses) {
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Log "Terminando proceso adicional: $procName ($($procs.Count) instancias)..." "WARN"
        Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
    }
}

# 5. Limpieza de Caché DNS
if ($FlushDns) {
    Write-Log "Limpiando caché DNS de Windows..."
    try {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        & ipconfig /flushdns | Out-Null
        Write-Log "Caché DNS limpiada con éxito." "SUCCESS"
    } catch {
        Write-Log "No se pudo limpiar la caché DNS: $_" "WARN"
    }
}

# 6. Limpieza de Caché NetBIOS
try {
    & nbtstat -R 2>$null | Out-Null
    Write-Log "Caché NetBIOS recargada." "SUCCESS"
} catch {}

# 7. Limpieza de Caché ARP (si es administrador)
if ($ClearArp) {
    try {
        & netsh interface ip delete arpcache 2>$null | Out-Null
        Write-Log "Caché ARP restablecida." "SUCCESS"
    } catch {}
}

# 8. Pausa de 1.5s para asegurar que el sistema operativo libere los puertos y sockets
Start-Sleep -Milliseconds 1500

# 9. Reiniciar OpenCode Desktop si estaba abierto previamente
if ($HandleDesktop -and $desktopWasRunning -and $RestartDesktop -and $desktopPath -and (Test-Path $desktopPath)) {
    Write-Log "Reiniciando OpenCode Desktop con la nueva red..." "SUCCESS"
    Start-Process -FilePath $desktopPath
}

Write-Log "Restablecimiento completado correctamente." "SUCCESS"

if ($SendNotification) {
    $details = @("Caché DNS vaciada")
    if ($desktopWasRunning -and $RestartDesktop) {
        $details += "OpenCode Desktop reiniciado"
    }
    if ($cliCount -gt 0) {
        $details += "$cliCount CLI opencode reseteados"
    }
    $msg = ($details -join ", ") + " con la nueva red/IP."
    Send-WindowsNotification -Title "🔄 Red / VPN Actualizada" -Message $msg
}
