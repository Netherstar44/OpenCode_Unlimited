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
    } catch {
        # Fallback silencioso si las notificaciones están desactivadas en Windows
    }
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
    Write-Host "                          U N L I M I T E D                            " -ForegroundColor Yellow
    Write-Host "  Auto-Reset de Red, Enrutamiento de VPN y Gestión de Cuota para OpenCode" -ForegroundColor Gray
    Write-Host "  $global:AuthorCredit" -ForegroundColor Green
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
        "https://ifconfig.me/ip"
    )
    foreach ($url in $endpoints) {
        try {
            $req = [System.Net.WebRequest]::Create($url)
            $req.Timeout = 2500
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
# PROCESSES & CACHE OPERATIONS
# =============================================================================

function Stop-OpenCodeProcesses {
    $foundDesktop = $false
    $desktopPath = $null

    $desktopProcs = Get-Process -Name "OpenCode" -ErrorAction SilentlyContinue
    if ($desktopProcs) {
        $foundDesktop = $true
        try { $desktopPath = $desktopProcs[0].Path } catch {}
        Write-EngineLog "Cerrando OpenCode Desktop para destruir sockets TCP colgados..." "ACTION"
        Stop-Process -Name "OpenCode" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
    }

    if (-not $desktopPath) {
        $candidate = "$env:LOCALAPPDATA\Programs\@opencodedesktop\OpenCode.exe"
        if (Test-Path $candidate) { $desktopPath = $candidate }
    }

    $cliProcs = Get-Process -Name "opencode" -ErrorAction SilentlyContinue
    if ($cliProcs) {
        Write-EngineLog "Terminando $($cliProcs.Count) instancia(s) de OpenCode CLI..." "ACTION"
        Stop-Process -Name "opencode" -Force -ErrorAction SilentlyContinue
    }

    return @{
        DesktopWasRunning = $foundDesktop
        DesktopPath       = $desktopPath
    }
}

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
        "Session Storage",
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

    # Limpiar cookies de red temporales
    $cookiesFile = Join-Path $baseDir "Network\Cookies"
    if (Test-Path $cookiesFile) {
        try { Remove-Item -Path $cookiesFile -Force -ErrorAction SilentlyContinue } catch {}
    }
    $cookiesWal = Join-Path $baseDir "Network\Cookies-wal"
    if (Test-Path $cookiesWal) {
        try { Remove-Item -Path $cookiesWal -Force -ErrorAction SilentlyContinue } catch {}
    }

    Write-EngineLog "Datos temporales de sesión limpiados (configuración y temas preservados)." "SUCCESS"
}

function Start-OpenCodeDesktop {
    param([string]$Path)
    if ($Path -and (Test-Path $Path)) {
        Write-EngineLog "Iniciando OpenCode Desktop con la nueva conexión..." "SUCCESS"
        Start-Process -FilePath $Path
    }
}

function Invoke-FullReset {
    param(
        [switch]$ForceCleanSession,
        [string]$NewIP = ""
    )
    Write-EngineLog "Iniciando ciclo de reseteo completo..." "ACTION"

    $procInfo = Stop-OpenCodeProcesses
    Clear-SystemNetworkCaches

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

    Write-EngineLog "¡Reseteo completado con éxito! IP activa: $NewIP" "SUCCESS"

    Send-ToastNotification `
        -Title "🔄 OpenCode Unlimited Actualizado" `
        -Message "Conexión restablecida con éxito. Nueva IP: $NewIP"
}

# =============================================================================
# WORKFLOWS: RENEW QUOTA & WATCH LOOP
# =============================================================================

function Invoke-RenewQuotaFlow {
    Show-Banner
    $initialIP = Get-PublicIP
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  RENOVAR CUOTA / CAMBIAR DE VPN" -ForegroundColor Yellow
    Write-Host "  IP Pública Actual: $initialIP" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1/2] Por favor, ve a tu aplicación de VPN (ej. UrbanVPN) y cambia de país o reconecta." -ForegroundColor White
    Write-Host "  [2/2] Esperando automáticamente a que tu IP pública cambie..." -ForegroundColor Gray
    Write-Host ""

    # Notificación no invasiva de Windows
    Send-ToastNotification `
        -Title "⚡ OpenCode Unlimited: Cuota / VPN" `
        -Message "Límite detectado. Cambia de país/servidor en tu VPN para continuar. Esperando nueva IP..."

    Write-EngineLog "Esperando detección de nueva IP pública externa..." "NOTIFY"

    $attempts = 0
    $maxAttempts = 120 # 2 minutos
    $detectedNewIP = $null

    while ($attempts -lt $maxAttempts) {
        Start-Sleep -Seconds 1
        $attempts++
        $checkIP = Get-PublicIP

        if ($checkIP -ne $initialIP -and $checkIP -notmatch "Desconocida") {
            $detectedNewIP = $checkIP
            break
        }

        if ($attempts % 5 -eq 0) {
            Write-Host "  ... Siguiendo a la espera de cambio de IP ($attempts segs) - IP actual: $checkIP" -ForegroundColor DarkGray
        }
    }

    if ($detectedNewIP) {
        Write-Host ""
        Write-Host "  ¡Nueva IP detectada: $detectedNewIP!" -ForegroundColor Green
        Write-Host "  Estabilizando rutas y ejecutando limpieza de entorno..." -ForegroundColor Cyan
        Start-Sleep -Seconds $Debounce
        Invoke-FullReset -ForceCleanSession -NewIP $detectedNewIP
    } else {
        Write-Host ""
        Write-Host "  No se detectó cambio de IP tras 2 minutos." -ForegroundColor Yellow
        Write-Host "  ¿Deseas forzar el reseteo de red y OpenCode con la IP actual? (S/N): " -NoNewline -ForegroundColor White
        $resp = Read-Host
        if ($resp -match "^[sSyY]") {
            Invoke-FullReset -ForceCleanSession
        }
    }
}

function Invoke-WatchLoop {
    Show-Banner
    Write-Host "  MODO MONITOR ACTIVO (Watch Mode)" -ForegroundColor Green
    Write-Host "  Vigilando cambios de VPN, adaptadores y nueva IP pública..." -ForegroundColor White
    Write-Host "  Presiona Ctrl + C en cualquier momento para detener el monitor." -ForegroundColor DarkGray
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray

    # Instancia única del watcher
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

            # Consultamos la IP pública cada 2 ciclos (o de inmediato si cambió el adaptador local)
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

                # Notificación rápida no invasiva
                Send-ToastNotification `
                    -Title "🔄 Cambio de VPN Detectado" `
                    -Message "Estabilizando conexión y reseteando OpenCode..."

                Write-EngineLog "Esperando $Debounce segundos a que la VPN termine de negociar rutas..." "WARN"
                Start-Sleep -Seconds $Debounce

                # Actualizar estados
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
        Write-Host "  [1] 🔄 Iniciar Monitor en Segundo Plano (Auto-Detecta cambio de VPN/IP y resetea)" -ForegroundColor White
        Write-Host "  [2] ⚡ Renovar Cuota Ahora (Te avisa para cambiar de país y resetea al detectar nueva IP)" -ForegroundColor White
        Write-Host "  [3] 🧹 Reseteo Rápido Inmediato (Cierra sockets, limpia DNS/ARP y reinicia OpenCode)" -ForegroundColor White
        Write-Host "  [4] 🧼 Limpieza Profunda (Caché DNS + Limpieza de sesión y cookies de OpenCode)" -ForegroundColor White
        Write-Host "  [5] ❌ Salir" -ForegroundColor Gray
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  Selecciona una opción [1-5]: " -NoNewline -ForegroundColor Cyan
        
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
                Invoke-FullReset
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menú..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "4" {
                Invoke-FullReset -ForceCleanSession
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menú..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "5" {
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
    "reset"   { Invoke-FullReset }
    "--reset" { Invoke-FullReset }
    "clean"   { Invoke-FullReset -ForceCleanSession }
    "--clean" { Invoke-FullReset -ForceCleanSession }
    Default   { Show-InteractiveMenu }
}
