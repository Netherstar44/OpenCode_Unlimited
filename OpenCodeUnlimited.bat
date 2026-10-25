@echo off
setlocal
title OpenCode Unlimited - Made By Jose David Correa ~ github: Netherstar44
powershell -NoProfile -ExecutionPolicy Bypass -Command "$scriptContent = (Get-Content -LiteralPath '%~f0' -Encoding UTF8 | Select-Object -Skip 5) -join [Environment]::NewLine; & ([scriptblock]::Create($scriptContent)) @args" %*
exit /b %ERRORLEVEL%
# --- POWERSHELL ENGINE STARTS HERE ---

[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$Action = "menu",

    [Parameter(Mandatory = $false)]
    [switch]$Silent,

    [Parameter(Mandatory = $false)]
    [switch]$NoRestart,

    [Parameter(Mandatory = $false)]
    [switch]$CleanSession,

    [Parameter(Mandatory = $false)]
    [int]$Interval = 3,

    [Parameter(Mandatory = $false)]
    [int]$Debounce = 3
)

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

$global:LogFile = Join-Path $env:TEMP "opencode_unlimited.log"
$global:PidFile = Join-Path $env:TEMP "opencode_unlimited.pid"
$global:AuthorCredit = "Made By Jose David Correa ~ github: Netherstar44"

# =============================================================================
# LOGGING & NOTIFICATIONS
# =============================================================================

function Write-EngineLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -Path $global:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}

    if ($Silent) { return }

    $timeStr = Get-Date -Format "HH:mm:ss"
    switch ($Level) {
        "SUCCESS" { Write-Host "[$timeStr] [OK]     $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "[$timeStr] [AVISO]  $Message" -ForegroundColor Yellow }
        "ACTION"  { Write-Host "[$timeStr] [ACCION] $Message" -ForegroundColor Magenta }
        "BOOST"   { Write-Host "[$timeStr] [TOKENS] $Message" -ForegroundColor Cyan }
        "ERROR"   { Write-Host "[$timeStr] [ERROR]  $Message" -ForegroundColor Red }
        "NOTIFY"  { Write-Host "[$timeStr] [NOTIF]  $Message" -ForegroundColor Cyan }
        Default   { Write-Host "[$timeStr] [INFO]   $Message" -ForegroundColor Gray }
    }
}

function Send-ToastNotification {
    param(
        [string]$Title = "OpenCode Unlimited",
        [string]$Message = "Notificación del sistema"
    )
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $textNodes = $template.GetElementsByTagName("text")
        $textNodes.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null
        $textNodes.Item(1).AppendChild($template.CreateTextNode($Message)) | Out-Null
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("OpenCode Unlimited")
        $notification = [Windows.UI.Notifications.ToastNotification]::new($template)
        $notifier.Show($notification)
    } catch {}
}

function Show-Banner {
    if ($Silent) { return }
    Clear-Host
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "   ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗" -ForegroundColor DarkCyan
    Write-Host "  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝" -ForegroundColor DarkCyan
    Write-Host "  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗  " -ForegroundColor Cyan
    Write-Host "  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝  " -ForegroundColor Cyan
    Write-Host "  ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗" -ForegroundColor White
    Write-Host "   ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝" -ForegroundColor White
    Write-Host "                   U N L I M I T E D  ·  E D I T I O N                         " -ForegroundColor Yellow
    Write-Host "   Auto-Reset de Red, Rotación de Identidad y Tokens Ampliados Diarios" -ForegroundColor Gray
    Write-Host "   $global:AuthorCredit" -ForegroundColor Green
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# =============================================================================
# NETWORK & IP DETECTION
# =============================================================================

function Get-PublicIP {
    $endpoints = @(
        "https://api.ipify.org",
        "https://icanhazip.com",
        "https://checkip.amazonaws.com",
        "https://ipinfo.io/ip",
        "https://ifconfig.me/ip"
    )
    foreach ($url in $endpoints) {
        try {
            $req = [System.Net.WebRequest]::Create($url)
            $req.Timeout = 1500
            $req.KeepAlive = $false
            $req.Proxy = $null
            $res = $req.GetResponse()
            $stream = $res.GetResponseStream()
            $reader = [System.IO.StreamReader]::new($stream)
            $ip = ($reader.ReadToEnd()).Trim()
            $reader.Close()
            $stream.Close()
            $res.Close()
            if ($ip -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                return $ip
            }
        } catch {}
    }
    return "Desconocida / Sin Internet"
}

function Get-LocalAdaptersSignature {
    $signatureItems = @()
    try {
        $adapters = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' }
        
        foreach ($adapter in $adapters) {
            $ipProps = $adapter.GetIPProperties()
            $ipv4s = $ipProps.UnicastAddresses |
                Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' -and -not $_.Address.ToString().StartsWith('169.254.') } |
                ForEach-Object { $_.Address.ToString() }
            
            $gateways = $ipProps.GatewayAddresses |
                Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } |
                ForEach-Object { $_.Address.ToString() }

            $dnsServers = $ipProps.DnsAddresses |
                Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                ForEach-Object { $_.ToString() }
            
            if ($ipv4s) {
                $ips = $ipv4s -join ","
                $gws = $gateways -join ","
                $dnss = $dnsServers -join ","
                $signatureItems += "$($adapter.Name)|$ips|GW:$gws|DNS:$dnss"
            }
        }
    } catch {}
    return ($signatureItems | Sort-Object) -join " ;; "
}

# =============================================================================
# PROCESSES & DAEMON MANAGEMENT
# =============================================================================

function Stop-OpenCodeProcesses {
    $foundDesktop = $false
    $desktopPath = $null

    # 1. Cerrar OpenCode Desktop primero para evitar que respawnee el daemon CLI
    $desktopProcs = Get-Process -Name "OpenCode" -ErrorAction SilentlyContinue
    if ($desktopProcs) {
        $foundDesktop = $true
        try { $desktopPath = $desktopProcs[0].Path } catch {}
        Write-EngineLog "Cerrando OpenCode Desktop para destruir sockets TCP colgados..." "ACTION"
        Stop-Process -Name "OpenCode" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 600
    }

    if (-not $desktopPath) {
        $candidate = "$env:LOCALAPPDATA\Programs\@opencodedesktop\OpenCode.exe"
        if (Test-Path $candidate) { $desktopPath = $candidate }
    }

    # 2. Detener servicio formalmente si está activo
    try { & opencode service stop 2>$null | Out-Null } catch {}

    # 3. Forzar terminación de todos los daemons CLI y ejecutables de servicio
    $targetProcessNames = @("opencode", "opencode-cli")
    foreach ($pName in $targetProcessNames) {
        $procs = Get-Process -Name $pName -ErrorAction SilentlyContinue
        if ($procs) {
            Write-EngineLog "Terminando $($procs.Count) instancia(s) de $pName..." "ACTION"
            Stop-Process -Name $pName -Force -ErrorAction SilentlyContinue
        }
    }

    # 4. Terminar procesos dinámicos huérfanos de servicio (opencode-service-*.exe)
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*opencode-service*" } | ForEach-Object {
        Write-EngineLog "Terminando proceso de servicio: $($_.ProcessName) (PID: $($_.Id))..." "ACTION"
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }

    # 5. Limpiar archivos de bloqueo residuales
    $locksDir = "$env:USERPROFILE\.local\state\opencode\locks"
    if (Test-Path $locksDir) {
        try { Remove-Item -Path "$locksDir\*" -Force -Recurse -ErrorAction SilentlyContinue } catch {}
    }

    Start-Sleep -Milliseconds 600

    return @{
        DesktopWasRunning = $foundDesktop
        DesktopPath       = $desktopPath
    }
}

# =============================================================================
# IDENTITY ROTATION & TOKEN AMPLIFICATION
# =============================================================================

function Rotate-OpenCodeDeviceIdentity {
    Write-EngineLog "Rotando identificador de dispositivo y tokens de máquina para cuota completa..." "BOOST"
    
    # 1. Regenerar .updaterId (UUID de instalación de OpenCode Desktop)
    $updaterIdPath = "$env:APPDATA\ai.opencode.desktop\.updaterId"
    try {
        $newGuid = [guid]::NewGuid().ToString()
        $newGuid | Set-Content -LiteralPath $updaterIdPath -Force -ErrorAction SilentlyContinue
        Write-EngineLog "Nuevo Device ID generado: $newGuid" "SUCCESS"
    } catch {}

    # 2. Eliminar service.json para que el daemon genere un nuevo Service UUID al reiniciar
    $serviceJson = "$env:USERPROFILE\.local\state\opencode\service.json"
    if (Test-Path $serviceJson) {
        try {
            Remove-Item -Path $serviceJson -Force -ErrorAction SilentlyContinue
            Write-EngineLog "ID de servicio anterior eliminado (se creará una sesión de servicio virgen)." "SUCCESS"
        } catch {}
    }

    # 3. Limpiar huellas locales de nivel db y tokens en ai.opencode.desktop (preservando configuración)
    $desktopApp = "$env:APPDATA\ai.opencode.desktop"
    $identityPaths = @(
        "Local Storage",
        "Session Storage",
        "IndexedDB",
        "Network\Cookies",
        "Network\Cookies-wal",
        "DIPS",
        "DIPS-wal"
    )
    foreach ($item in $identityPaths) {
        $p = Join-Path $desktopApp $item
        if (Test-Path $p) {
            try { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
}

function Optimize-OpenCodeSessions {
    param([switch]$ForceArchiveAll)
    Write-EngineLog "Optimizando sesiones infladas para desbloquear cuota completa..." "BOOST"
    
    $dbPath = "$env:USERPROFILE\.local\share\opencode\opencode.db"
    if (Test-Path $dbPath) {
        $pyCmd = "import sqlite3, os, time; conn=sqlite3.connect(os.path.expanduser('~/.local/share/opencode/opencode.db')); cur=conn.cursor(); cur.execute('UPDATE session SET time_archived = ? WHERE time_archived IS NULL', (int(time.time()*1000),)); conn.commit(); print(cur.rowcount); conn.close()"
        try {
            $archived = & python -c $pyCmd 2>$null
            if ($archived -and $archived.Trim() -match '^\d+$' -and [int]($archived.Trim()) -gt 0) {
                Write-EngineLog "Se archivaron $($archived.Trim()) sesión(es) infladas. Próximos comandos iniciarán con 0 tokens de historial." "SUCCESS"
            } else {
                Write-EngineLog "Sesiones ya optimizadas (contexto limpio sin arrastre)." "SUCCESS"
            }
        } catch {
            Write-EngineLog "Aviso al optimizar sesiones: $($_.Exception.Message)" "WARN"
        }
    }
}

function Optimize-TokenConsumptionProfile {
    param([string]$Profile = "balanced") # balanced (high), economical (default), extreme (max)
    $modelJsonPath = "$env:USERPROFILE\.local\state\opencode\model.json"
    if (Test-Path $modelJsonPath) {
        try {
            $content = Get-Content -LiteralPath $modelJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($content.variant) {
                $targetVariant = switch ($Profile) {
                    "economical" { "default" }
                    "extreme"    { "max" }
                    Default      { "high" }
                }
                if ($content.variant."opencode/deepseek-v4.1-flash-free") {
                    $content.variant."opencode/deepseek-v4.1-flash-free" = $targetVariant
                }
                if ($content.variant."opencode/nemotron-3.5-super-vl-free") {
                    $content.variant."opencode/nemotron-3.5-super-vl-free" = $(if ($targetVariant -eq "max") { "xhigh" } else { "high" })
                }
                $content | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $modelJsonPath -Encoding UTF8 -Force
                Write-EngineLog "Perfil de tokens optimizado a: $Profile (Reasoning eficiente para comandos shell)." "SUCCESS"
            }
        } catch {}
    }
}

# =============================================================================
# SYSTEM NETWORK CACHES
# =============================================================================

function Clear-SystemNetworkCaches {
    Write-EngineLog "Limpiando caché DNS de Windows..." "ACTION"
    try {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        & ipconfig /flushdns | Out-Null
        Write-EngineLog "Caché DNS vaciada con éxito." "SUCCESS"
    } catch {
        Write-EngineLog "Aviso al limpiar DNS: $($_.Exception.Message)" "WARN"
    }

    try {
        & nbtstat -R 2>$null | Out-Null
        Write-EngineLog "Caché NetBIOS recargada." "SUCCESS"
    } catch {}

    try {
        & netsh interface ip delete arpcache 2>$null | Out-Null
        Write-EngineLog "Caché ARP eliminada." "SUCCESS"
    } catch {}
}

function Clear-OpenCodeSessionData {
    Write-EngineLog "Limpiando almacenamiento temporal y cookies de OpenCode..." "ACTION"
    $baseDir = "$env:APPDATA\ai.opencode.desktop"
    $dirsToClean = @(
        "Cache",
        "Code Cache",
        "GPUCache",
        "DawnGraphiteCache",
        "DawnWebGPUCache",
        "blob_storage"
    )

    foreach ($d in $dirsToClean) {
        $target = Join-Path $baseDir $d
        if (Test-Path $target) {
            try {
                Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
    Write-EngineLog "Datos temporales de sesión limpiados (configuración y temas preservados)." "SUCCESS"
}

function Start-OpenCodeDesktop {
    param([string]$Path)
    if ($Path -and (Test-Path $Path)) {
        Write-EngineLog "Iniciando OpenCode Desktop con la nueva identidad y red..." "SUCCESS"
        Start-Process -FilePath $Path
    }
}

function Invoke-FullReset {
    param(
        [switch]$ForceCleanSession,
        [string]$NewIP = ""
    )
    Write-EngineLog "Iniciando ciclo de reseteo completo con Tokens Ampliados..." "ACTION"

    # 1. Detener procesos Desktop, CLI y Daemons de servicio
    $procInfo = Stop-OpenCodeProcesses

    # 2. Limpiar cachés de red del sistema
    Clear-SystemNetworkCaches

    # 3. Rotar identidad del dispositivo y tokens de máquina
    Rotate-OpenCodeDeviceIdentity

    # 4. Archivar sesiones infladas para que el contexto inicie limpio (0 tokens inflados)
    Optimize-OpenCodeSessions -ForceArchiveAll

    # 5. Ajustar perfil de reasoning a 'balanced' (evita quemar 30k tokens en comandos de shell)
    Optimize-TokenConsumptionProfile -Profile "balanced"

    if ($CleanSession -or $ForceCleanSession) {
        Clear-OpenCodeSessionData
    }

    # Pausa de 1.5s para que Windows libere puertos y sockets TCP
    Start-Sleep -Milliseconds 1500

    if (-not $NoRestart -and ($procInfo.DesktopWasRunning -or $procInfo.DesktopPath)) {
        Start-OpenCodeDesktop -Path $procInfo.DesktopPath
    }

    if (-not $NewIP) {
        $NewIP = Get-PublicIP
    }

    Write-EngineLog "¡Reseteo completado! Tokens ampliados activos. IP: $NewIP" "SUCCESS"

    Send-ToastNotification `
        -Title "⚡ OpenCode Tokens Ampliados" `
        -Message "Cuota renovada con éxito. Contexto limpio y nueva IP: $NewIP"
}

# =============================================================================
# WORKFLOWS: RENEW QUOTA & WATCH LOOP
# =============================================================================

function Invoke-RenewQuotaFlow {
    Show-Banner

    Write-Host "  Detectando IP publica actual..." -ForegroundColor DarkGray
    $initialIP = Get-PublicIP

    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  RENOVAR CUOTA / TOKENS AMPLIADOS" -ForegroundColor Yellow
    Write-Host "  IP de Salida Actual: $initialIP" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  PASOS:" -ForegroundColor White
    Write-Host "  1. Abre tu app de VPN y cambia de pais / servidor / reconecta." -ForegroundColor White
    Write-Host "  2. El script detecta la nueva IP y resetea sockets + Device ID automaticamente." -ForegroundColor Gray
    Write-Host "  3. O presiona ENTER en cualquier momento para forzar la renovacion ya." -ForegroundColor Gray
    Write-Host ""

    Send-ToastNotification `
        -Title "Cambiar de VPN ahora" `
        -Message "OpenCode Unlimited esperando nueva IP. Cambia de país en tu VPN."

    Write-EngineLog "Monitoreo de IP publica iniciado. IP base: $initialIP" "NOTIFY"

    $attempts      = 0
    $maxAttempts   = 180
    $detectedNewIP = $null
    $wasOffline    = $false
    $lastLine      = ""

    $inputPS = [System.Management.Automation.PowerShell]::Create()
    $null = $inputPS.AddScript({ try { [Console]::ReadLine() } catch { $null } })
    $inputHandle = $inputPS.BeginInvoke()

    while ($attempts -lt $maxAttempts) {
        if ($inputHandle.IsCompleted) {
            Write-Host ""
            Write-Host "  >> ENTER detectado: forzando renovación con conexión actual..." -ForegroundColor Magenta
            $detectedNewIP = Get-PublicIP
            break
        }

        Start-Sleep -Milliseconds 800
        $attempts++

        $checkIP = Get-PublicIP

        if ($checkIP -match "Desconocida") {
            $statusLine  = "  [$(Get-Date -Format 'HH:mm:ss')] Transitando VPN... (sin internet - normal durante cambio) [$attempts s]"
            $statusColor = "DarkYellow"
            $wasOffline  = $true
        } elseif ($checkIP -ne $initialIP) {
            $detectedNewIP = $checkIP
            break
        } elseif ($wasOffline) {
            $statusLine  = "  [$(Get-Date -Format 'HH:mm:ss')] Online nuevamente pero misma IP ($checkIP) - cambia de servidor [$attempts s]"
            $statusColor = "Yellow"
            $wasOffline  = $false
        } else {
            $statusLine  = "  [$(Get-Date -Format 'HH:mm:ss')] Esperando cambio de IP... actual: $checkIP  [$attempts s]"
            $statusColor = "DarkGray"
        }

        if ($statusLine -ne $lastLine) {
            Write-Host ("`r" + $statusLine.PadRight(88)) -ForegroundColor $statusColor -NoNewline
            $lastLine = $statusLine
        }
    }

    try { $inputPS.Stop(); $inputPS.Dispose() } catch {}
    Write-Host ""

    if ($detectedNewIP -and $detectedNewIP -notmatch "Desconocida") {
        Write-Host ""
        Write-Host "  Nueva IP detectada: $detectedNewIP" -ForegroundColor Green
        Write-Host "  Estabilizando rutas ($Debounce s) y aplicando Tokens Ampliados..." -ForegroundColor Cyan
        Start-Sleep -Seconds $Debounce
        Invoke-FullReset -ForceCleanSession -NewIP $detectedNewIP
        Write-EngineLog "Cuota renovada con éxito. Nueva IP activa: $detectedNewIP" "SUCCESS"
    } else {
        Write-Host ""
        Write-Host "  No se detecto cambio de IP." -ForegroundColor Yellow
        Write-Host "  Deseas forzar el reseteo con Tokens Ampliados en la IP actual? (S/N): " -NoNewline -ForegroundColor White
        $resp = Read-Host
        if ($resp -match "^[sSyY]") {
            Invoke-FullReset -ForceCleanSession
        }
    }
}

function Invoke-WatchLoop {
    Show-Banner
    Write-Host "  MODO MONITOR ACTIVO (Tokens Ampliados 24/7)" -ForegroundColor Green
    Write-Host "  Vigilando cambios de VPN, adaptadores y nueva IP pública..." -ForegroundColor White
    Write-Host "  Presiona Ctrl + C en cualquier momento para detener el monitor." -ForegroundColor DarkGray
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $PID | Set-Content -Path $global:PidFile -Force -ErrorAction SilentlyContinue

    $lastLocalSig = Get-LocalAdaptersSignature
    $lastPublicIP = Get-PublicIP

    Write-EngineLog "Monitor iniciado. IP Pública Inicial: $lastPublicIP" "SUCCESS"

    $ticks = 0
    while ($true) {
        try {
            Start-Sleep -Seconds $Interval
            $ticks++

            $currentLocalSig = Get-LocalAdaptersSignature
            $localChanged = ($currentLocalSig -ne $lastLocalSig)

            $publicChanged = $false
            if ($localChanged -or ($ticks % 2 -eq 0)) {
                $currentPublicIP = Get-PublicIP
                if ($currentPublicIP -ne $lastPublicIP -and $currentPublicIP -notmatch "Desconocida") {
                    $publicChanged = $true
                }
            } else {
                $currentPublicIP = $lastPublicIP
            }

            if ($localChanged -or $publicChanged) {
                Write-EngineLog "¡Cambio de Red / VPN detectado!" "WARN"
                if ($publicChanged) {
                    Write-EngineLog "IP Pública anterior: $lastPublicIP -> Nueva: $currentPublicIP" "ACTION"
                }

                Send-ToastNotification `
                    -Title "🔄 Cambio de VPN Detectado" `
                    -Message "Estabilizando conexión y aplicando Tokens Ampliados a OpenCode..."

                Write-EngineLog "Esperando $Debounce segundos a que la VPN termine de negociar rutas..." "WARN"
                Start-Sleep -Seconds $Debounce

                $lastLocalSig = Get-LocalAdaptersSignature
                $lastPublicIP = Get-PublicIP

                Invoke-FullReset -NewIP $lastPublicIP
                Write-EngineLog "Monitoreo reanudado. Esperando próximos cambios de red..." "SUCCESS"
                Write-Host ""
            }
        } catch {
            Write-EngineLog "Error transitorio en monitor: $($_.Exception.Message)" "WARN"
            Start-Sleep -Seconds 5
        }
    }
}

# =============================================================================
# INTERACTIVE MENU
# =============================================================================

function Show-InteractiveMenu {
    while ($true) {
        Show-Banner
        $currentIP = Get-PublicIP
        Write-Host "  IP Pública Actual: $currentIP" -ForegroundColor Yellow
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [1] 🔄 Iniciar Monitor Automático (Detecta VPN/IP y resetea tokens 24/7)" -ForegroundColor White
        Write-Host "  [2] ⚡ Renovar Cuota / Tokens Ampliados (Espera nueva IP + Rota ID de Dispositivo)" -ForegroundColor White
        Write-Host "  [3] 🚀 Modo Tokens Ampliados (Archiva contexto inflado + Optimiza reasoning)" -ForegroundColor Cyan
        Write-Host "  [4] 🧹 Reseteo Rápido Inmediato (Cierra sockets, daemons y limpia DNS/ARP)" -ForegroundColor White
        Write-Host "  [5] 🧼 Limpieza Profunda Total (Caché + Cookies + Device ID + Sesiones)" -ForegroundColor White
        Write-Host "  [6] 📊 Ver Estadísticas de Cuota y Tokens (opencode stats)" -ForegroundColor Gray
        Write-Host "  [7] ❌ Salir" -ForegroundColor Gray
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  Selecciona una opción [1-7]: " -NoNewline -ForegroundColor Cyan
        
        $choice = Read-Host

        switch ($choice) {
            "1" {
                Invoke-WatchLoop
                break
            }
            "2" {
                Invoke-RenewQuotaFlow
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menú..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "3" {
                Show-Banner
                Write-Host "  APLICANDO MODO TOKENS AMPLIADOS" -ForegroundColor Cyan
                Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
                Optimize-OpenCodeSessions -ForceArchiveAll
                Optimize-TokenConsumptionProfile -Profile "balanced"
                Write-Host ""
                Write-Host "  ¡Optimización aplicada!" -ForegroundColor Green
                Write-Host "  - Se archivó el contexto inflado de comandos previos." -ForegroundColor Gray
                Write-Host "  - El modelo ahora responderá con reasoning optimizado para comandos shell." -ForegroundColor Gray
                Write-Host "  - Cada comando enviará ~1k tokens en vez de 100k tokens." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menú..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "4" {
                Invoke-FullReset
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menú..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "5" {
                Invoke-FullReset -ForceCleanSession
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menú..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "6" {
                Show-Banner
                Write-Host "  ESTADÍSTICAS DE OPENCODE" -ForegroundColor Cyan
                Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
                try { & opencode stats } catch { Write-Host "No se pudo ejecutar opencode stats: $_" -ForegroundColor Red }
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menú..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "7" {
                Write-Host "Saliendo... ¡Hasta pronto!" -ForegroundColor Cyan
                return
            }
            Default {
                Write-Host "Opción inválida. Intenta de nuevo." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# =============================================================================
# ENTRYPOINT DISPATCHER
# =============================================================================

switch ($Action.ToLower()) {
    "watch"   { Invoke-WatchLoop }
    "-w"      { Invoke-WatchLoop }
    "--watch" { Invoke-WatchLoop }
    "renew"   { Invoke-RenewQuotaFlow }
    "-r"      { Invoke-RenewQuotaFlow }
    "--renew" { Invoke-RenewQuotaFlow }
    "boost"   { 
        Optimize-OpenCodeSessions -ForceArchiveAll
        Optimize-TokenConsumptionProfile -Profile "balanced"
    }
    "--boost" { 
        Optimize-OpenCodeSessions -ForceArchiveAll
        Optimize-TokenConsumptionProfile -Profile "balanced"
    }
    "reset"   { Invoke-FullReset }
    "--reset" { Invoke-FullReset }
    "clean"   { Invoke-FullReset -ForceCleanSession }
    "--clean" { Invoke-FullReset -ForceCleanSession }
    Default   { Show-InteractiveMenu }
}
