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

# =============================================================================
# NETWORK & IP DETECTION
# =============================================================================

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
    [System.Net.ServicePointManager]::DnsRefreshTimeout = 0
} catch {}

# Get-PublicIP: Consulta HTTP ultrarrápida (icanhazip.com ~90ms, ipify ~380ms)
# NO usa nslookup porque VPNs con DNS-Leak-Protection bloquean UDP 53 a resolvers externos
function Get-PublicIP {
    param([int]$TimeoutMs = 1500)

    $endpoints = @(
        'https://icanhazip.com',
        'https://api.ipify.org',
        'https://checkip.amazonaws.com',
        'https://ipinfo.io/ip'
    )

    foreach ($url in $endpoints) {
        try {
            $req = [System.Net.HttpWebRequest]::Create($url)
            $req.Timeout = $TimeoutMs
            $req.ReadWriteTimeout = $TimeoutMs
            $req.KeepAlive = $false
            $req.Proxy = $null
            $req.UserAgent = 'curl/8.0.0'
            $res = $req.GetResponse()
            $reader = [System.IO.StreamReader]::new($res.GetResponseStream())
            $ip = ($reader.ReadToEnd()).Trim()
            $reader.Close(); $res.Close()
            if ($ip -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                return $ip
            }
        } catch {}
    }
    return "Desconocida"
}

# Get-NetworkSignature: detecta cambios de VPN (UrbanVPN, OpenVPN, Wi-Fi) en 15ms SIN internet
function Get-NetworkSignature {
    try {
        $adapters = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object { $_.NetworkInterfaceType -ne 'Loopback' }
        $parts = @()
        foreach ($a in $adapters) {
            if ($a.OperationalStatus -eq 'Up') {
                $props = $a.GetIPProperties()
                $ips = $props.UnicastAddresses |
                       Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' -and
                                      -not $_.Address.ToString().StartsWith('169.254.') } |
                       ForEach-Object { $_.Address.ToString() }
                $gws = $props.GatewayAddresses |
                       Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } |
                       ForEach-Object { $_.Address.ToString() }
                $dns = $props.DnsAddresses |
                       Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                       ForEach-Object { $_.ToString() }
                $parts += "$($a.Name)|UP|IP:$($ips -join ',')|GW:$($gws -join ',')|DNS:$($dns -join ',')"
            }
        }
        return ($parts | Sort-Object) -join ';;'
    } catch { return '' }
}

function Get-RoutingSignature { return Get-NetworkSignature }
function Get-LocalAdaptersSignature { return Get-NetworkSignature }

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
    Write-EngineLog "Archivando sesiones infladas de session_v2 para limpiar contexto..." "BOOST"

    $dbPath = "$env:USERPROFILE\.local\share\opencode\opencode.db"
    if (-not (Test-Path $dbPath)) {
        Write-EngineLog "Base de datos de OpenCode no encontrada: $dbPath" "WARN"
        return
    }

    # Script Python que archiva TODAS las sesiones activas en session_v2
    # (la tabla real en OpenCode v2.x) y limpia el inbox de contexto pendiente
    $pyScript = @"
import sqlite3, os, time
db = os.path.expanduser(r'~/.local/share/opencode/opencode.db')
conn = sqlite3.connect(db)
cur = conn.cursor()
ts = int(time.time() * 1000)

# Archivar session_v2 (tabla activa en OpenCode >=2.0)
cur.execute('UPDATE session_v2 SET time_archived = ? WHERE time_archived IS NULL', (ts,))
n_v2 = cur.rowcount

# Archivar tabla legacy session por si acaso
cur.execute('UPDATE session SET time_archived = ? WHERE time_archived IS NULL', (ts,))
n_v1 = cur.rowcount

# Vaciar session_inbox (contexto pendiente en cola que infla tokens)
cur.execute('DELETE FROM session_inbox')
n_inbox = cur.rowcount

conn.commit()
conn.close()
print(f'{n_v2},{n_v1},{n_inbox}')
"@

    $tempPy = Join-Path $env:TEMP "oc_archive_sessions.py"
    $pyScript | Set-Content -LiteralPath $tempPy -Encoding UTF8 -Force

    try {
        $result = & python $tempPy 2>&1
        if ($result -and $result -match '^\d+,\d+,\d+$') {
            $parts  = $result.Trim().Split(',')
            $nV2    = [int]$parts[0]
            $nV1    = [int]$parts[1]
            $nInbox = [int]$parts[2]
            $total  = $nV2 + $nV1
            if ($total -gt 0) {
                Write-EngineLog "Archivadas $nV2 sesion(es) activas de session_v2 + $nV1 legado. Inbox limpiado ($nInbox entradas). Los proximos comandos parten con contexto 0." "SUCCESS"
            } else {
                Write-EngineLog "Sesiones ya archivadas (inbox limpiado: $nInbox entradas). Contexto limpio." "SUCCESS"
            }
        } else {
            Write-EngineLog "Respuesta inesperada del optimizador: $result" "WARN"
        }
    } catch {
        Write-EngineLog "Error al optimizar sesiones: $($_.Exception.Message)" "WARN"
    } finally {
        Remove-Item -LiteralPath $tempPy -Force -ErrorAction SilentlyContinue
    }
}

function Show-TokenStats {
    Write-EngineLog "Consultando estadisticas de tokens y sesiones..." "BOOST"
    $dbPath = "$env:USERPROFILE\.local\share\opencode\opencode.db"
    if (-not (Test-Path $dbPath)) { Write-EngineLog "DB no encontrada." "ERROR"; return }

    $pyScript = @"
import sqlite3, os, json
db = os.path.expanduser(r'~/.local/share/opencode/opencode.db')
conn = sqlite3.connect(db)
cur = conn.cursor()
cur.execute('SELECT count(*) FROM session_v2 WHERE time_archived IS NULL')
active = cur.fetchone()[0]
cur.execute('SELECT count(*) FROM session_v2 WHERE time_archived IS NOT NULL')
archived = cur.fetchone()[0]
cur.execute('SELECT sum(tokens_input), sum(tokens_output), sum(tokens_reasoning) FROM session_v2 WHERE time_archived IS NULL')
r = cur.fetchone()
tin, tout, treason = r[0] or 0, r[1] or 0, r[2] or 0
cur.execute('SELECT id, title, tokens_input, tokens_output, time_updated FROM session_v2 WHERE time_archived IS NULL ORDER BY tokens_input DESC LIMIT 5')
top = cur.fetchall()
cur.execute('SELECT count(*) FROM session_inbox')
inbox = cur.fetchone()[0]
conn.close()
print(f'active={active}')
print(f'archived={archived}')
print(f'tokens_in={tin}')
print(f'tokens_out={tout}')
print(f'inbox={inbox}')
for row in top:
    title = (str(row[1]) or 'Sin titulo')[:40]
    print(f'TOP|{title}|in={row[2]}|out={row[3]}')
"@
    $tempPy = Join-Path $env:TEMP "oc_stats.py"
    $pyScript | Set-Content -LiteralPath $tempPy -Encoding UTF8 -Force
    try {
        $lines = (& python $tempPy 2>&1) -split "`n"
        Write-Host ""
        Write-Host "  =============================== ESTADISTICAS DE TOKENS ==============================" -ForegroundColor Cyan
        foreach ($ln in $lines) {
            $ln = $ln.Trim()
            if ($ln -match '^active=(\d+)')          { Write-Host "  Sesiones ACTIVAS (sin archivar): $($Matches[1])" -ForegroundColor $(if ([int]$Matches[1] -gt 5) { 'Red' } else { 'Green' }) }
            elseif ($ln -match '^archived=(\d+)')    { Write-Host "  Sesiones archivadas: $($Matches[1])" -ForegroundColor Gray }
            elseif ($ln -match '^tokens_in=(\d+)')   { $m = [math]::Round([int]$Matches[1]/1000,1); Write-Host "  Tokens INPUT acumulados (sesiones activas): ${m}K" -ForegroundColor $(if ([int]$Matches[1] -gt 500000) { 'Red' } else { 'Yellow' }) }
            elseif ($ln -match '^tokens_out=(\d+)')  { $m = [math]::Round([int]$Matches[1]/1000,1); Write-Host "  Tokens OUTPUT acumulados: ${m}K" -ForegroundColor Gray }
            elseif ($ln -match '^inbox=(\d+)')       { Write-Host "  Session inbox pendiente: $($Matches[1]) entradas" -ForegroundColor $(if ([int]$Matches[1] -gt 0) { 'Yellow' } else { 'Green' }) }
            elseif ($ln -match '^TOP\|(.+)\|in=(\d+)\|out=(\d+)') {
                $ti = [math]::Round([int]$Matches[2]/1000,1)
                Write-Host "  [TOP] $($Matches[1].PadRight(42)) input=${ti}K" -ForegroundColor DarkYellow
            }
        }
        Write-Host "  ==================================================================================" -ForegroundColor Cyan
    } finally {
        Remove-Item -LiteralPath $tempPy -Force -ErrorAction SilentlyContinue
    }
}

function Optimize-TokenConsumptionProfile {
    param([string]$Profile = "balanced") # balanced (high), economical (default), extreme (max)
    $modelJsonPath = "$env:USERPROFILE\.local\state\opencode\model.json"
    if (Test-Path $modelJsonPath) {
        try {
            $content = Get-Content -LiteralPath $modelJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $targetVariant = switch ($Profile) {
                "economical" { "default" }
                "extreme"    { "max" }
                Default      { "high" }
            }
            # Aplicar a todos los modelos presentes en el JSON
            if ($content.variant) {
                $modelKeys = @($content.variant.PSObject.Properties.Name)
                foreach ($mk in $modelKeys) {
                    $isNemotron = $mk -like '*nemotron*' -or $mk -like '*super-vl*'
                    $val = if ($isNemotron -and $targetVariant -eq 'max') { 'xhigh' }
                           elseif ($isNemotron) { 'high' }
                           else { $targetVariant }
                    $content.variant.$mk = $val
                }
            }
            if ($content.model) {
                # Forzar variante tambien en campo raiz si existe
                try { $content.model.variant = $targetVariant } catch {}
            }
            $content | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $modelJsonPath -Encoding UTF8 -Force
            Write-EngineLog "Perfil de consumo de tokens ajustado a '$Profile' en todos los modelos del JSON." "SUCCESS"
        } catch {
            Write-EngineLog "No se pudo ajustar model.json: $($_.Exception.Message)" "WARN"
        }
    } else {
        Write-EngineLog "model.json no encontrado — OpenCode usara configuracion por defecto." "WARN"
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

    Write-Host "  Detectando estado de red inicial..." -ForegroundColor DarkGray
    $initialSig = Get-NetworkSignature
    $initialIP  = Get-PublicIP

    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  RENOVAR CUOTA / TOKENS AMPLIADOS" -ForegroundColor Yellow
    Write-Host "  IP Actual: $initialIP" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  PASOS:" -ForegroundColor White
    Write-Host "  1. Abre tu VPN (ej. UrbanVPN) y conecta o cambia de pais/servidor." -ForegroundColor White
    Write-Host "  2. El monitor detecta la nueva VPN/IP y resetea OpenCode AUTOMATICAMENTE." -ForegroundColor Green
    Write-Host "  3. O presiona ENTER en cualquier momento para forzar la renovacion ya." -ForegroundColor Gray
    Write-Host ""

    Send-ToastNotification `
        -Title "Cambiar de VPN ahora" `
        -Message "OpenCode Unlimited esperando nueva IP. Conecta o cambia de servidor en tu VPN."

    Write-EngineLog "Esperando cambio de red o IP... (Base: $initialIP)" "NOTIFY"

    $attempts      = 0
    $maxAttempts   = 240
    $detectedNewIP = $null
    $detectedSigChange = $false
    $lastLine      = ""

    while ($attempts -lt $maxAttempts) {
        # Comprobar si el usuario presionó una tecla (no bloqueante)
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Enter' -or $key.Key -eq 'Spacebar') {
                Write-Host ""
                Write-Host "  >> ENTER detectado: forzando renovacion con la conexion actual..." -ForegroundColor Magenta
                $detectedNewIP = Get-PublicIP
                break
            }
        }

        Start-Sleep -Milliseconds 800
        $attempts++

        # Detección instantánea por adaptador/ruteo VPN (0ms)
        $curSig = Get-NetworkSignature
        if ($curSig -ne $initialSig) {
            $detectedSigChange = $true
            Write-Host ""
            Write-EngineLog "¡Cambio de adaptador/VPN detectado en tiempo real!" "SUCCESS"
            Write-Host "  Estabilizando rutas de la nueva conexion ($Debounce s)..." -ForegroundColor Cyan
            Start-Sleep -Seconds $Debounce

            # Intentar leer nueva IP
            for ($k = 0; $k -lt 6; $k++) {
                $tryIP = Get-PublicIP
                if ($tryIP -notmatch "Desconocida" -and $tryIP -ne $initialIP) {
                    $detectedNewIP = $tryIP
                    break
                }
                Start-Sleep -Seconds 1
            }
            if (-not $detectedNewIP) {
                $detectedNewIP = Get-PublicIP
            }
            break
        }

        # Detección complementaria por IP pública cada 3 segundos
        if ($attempts % 3 -eq 0) {
            $checkIP = Get-PublicIP
            if ($checkIP -match "Desconocida") {
                $statusLine = "  [$(Get-Date -Format 'HH:mm:ss')] Negociando VPN... (esperando enlace) [$attempts s]"
                $statusColor = "DarkYellow"
            } elseif ($checkIP -ne $initialIP) {
                $detectedNewIP = $checkIP
                Write-Host ""
                Write-EngineLog "¡Nueva IP publica detectada: $checkIP!" "SUCCESS"
                break
            } else {
                $statusLine = "  [$(Get-Date -Format 'HH:mm:ss')] Esperando cambio en VPN... actual: $checkIP [$attempts s]"
                $statusColor = "DarkGray"
            }

            if ($statusLine -ne $lastLine) {
                Write-Host ("`r" + $statusLine.PadRight(88)) -ForegroundColor $statusColor -NoNewline
                $lastLine = $statusLine
            }
        }
    }

    Write-Host ""

    if ($detectedNewIP -and $detectedNewIP -notmatch "Desconocida") {
        Write-Host ""
        Write-Host "  Nueva IP confirmada: $detectedNewIP" -ForegroundColor Green
        Write-Host "  Aplicando Tokens Ampliados y rotando identidad..." -ForegroundColor Cyan
        Invoke-FullReset -ForceCleanSession -NewIP $detectedNewIP
        Write-EngineLog "Cuota renovada con exito. Nueva IP activa: $detectedNewIP" "SUCCESS"
    } elseif ($detectedSigChange) {
        Write-Host ""
        Write-Host "  Red cambiada exitosamente. Aplicando reseteo completo..." -ForegroundColor Green
        $confirmedIP = Get-PublicIP
        Invoke-FullReset -ForceCleanSession -NewIP $confirmedIP
        Write-EngineLog "Cuota renovada con exito. IP activa: $confirmedIP" "SUCCESS"
    } else {
        Write-Host ""
        Write-Host "  No se detecto cambio automatico de red/IP." -ForegroundColor Yellow
        Write-Host "  Deseas forzar el reseteo con Tokens Ampliados ahora? (S/N): " -NoNewline -ForegroundColor White
        $resp = Read-Host
        if ($resp -match "^[sSyY]") {
            Invoke-FullReset -ForceCleanSession
        }
    }
}

function Switch-ToOpenRouterFreeModel {
    param([switch]$Silent)
    # Cambia el modelo activo de OpenCode al proveedor OpenRouter (sin limite diario de mensajes)
    # Esto resuelve el error "You've used today's free messages"
    $modelJsonPath = "$env:USERPROFILE\.local\state\opencode\model.json"
    $freeModels = @(
        @{ providerID = 'openrouter'; modelID = 'nvidia/nemotron-3.5-lightning:free' },
        @{ providerID = 'openrouter'; modelID = 'nvidia/nemotron-3.5-super-vl:free' },
        @{ providerID = 'openrouter'; modelID = 'deepseek/deepseek-chat-v3-0324:free' },
        @{ providerID = 'openrouter'; modelID = 'minimax/minimax-m3.1-flash:free' }
    )
    try {
        $content = Get-Content -LiteralPath $modelJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $existing = @($content.recent)
        $newRecent = $freeModels + $existing | Select-Object -First 12
        $content.recent = $newRecent
        $content | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $modelJsonPath -Encoding UTF8 -Force

        # Actualizar tambien las sesiones activas en session_v2 que usaban el proveedor opencode
        $dbPath = "$env:USERPROFILE\.local\share\opencode\opencode.db"
        if (Test-Path $dbPath) {
            $pyScript = @"
import sqlite3, os
db = os.path.expanduser(r'~/.local/share/opencode/opencode.db')
conn = sqlite3.connect(db)
cur = conn.cursor()
new_model = '{"id":"nvidia/nemotron-3.5-lightning:free","providerID":"openrouter","variant":"balanced"}'
cur.execute("UPDATE session_v2 SET model = ? WHERE model LIKE '%opencode%'", (new_model,))
conn.commit()
conn.close()
"@
            python -c $pyScript 2>$null
        }

        if (-not $Silent) {
            Write-EngineLog "Modelo cambiado a OpenRouter free (sin limite diario). Reinicia OpenCode y usa 'nemotron-3.5-lightning:free'." "SUCCESS"
            Send-ToastNotification -Title "Modelo cambiado a OpenRouter" -Message "Sin limite diario de mensajes. Reinicia OpenCode y disfruta de 1M contexto."
        }
    } catch {
        Write-EngineLog "No se pudo cambiar model.json: $($_.Exception.Message)" "WARN"
    }
}

function Invoke-WatchLoop {
    Show-Banner
    Write-Host "  MODO MONITOR ACTIVO - Deteccion en Tiempo Real de VPN y Red" -ForegroundColor Green
    Write-Host "  Vigilando cambios de adaptadores/VPN cada $Interval segundos." -ForegroundColor White
    Write-Host "  Presiona Ctrl+C para detener." -ForegroundColor DarkGray
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $PID | Set-Content -Path $global:PidFile -Force -ErrorAction SilentlyContinue

    Write-Host "  Obteniendo estado inicial de red..." -ForegroundColor DarkGray
    $lastSig      = Get-NetworkSignature
    $lastPublicIP = Get-PublicIP

    Write-EngineLog "Monitor iniciado. Firma: [$lastSig]" "SUCCESS"
    Write-EngineLog "IP Publica inicial: $lastPublicIP" "SUCCESS"
    Write-Host "  IP actual: $lastPublicIP" -ForegroundColor Cyan
    Write-Host ""

    $tickCount = 0
    while ($true) {
        try {
            Start-Sleep -Seconds $Interval
            $tickCount++

            # 1. Comprobación local instantánea (15ms, 0ms internet)
            $curSig = Get-NetworkSignature
            $sigChanged = ($curSig -ne $lastSig)

            # 2. Comprobación de IP pública (si la firma cambió o cada 15 segundos)
            $curPublicIP = $lastPublicIP
            $ipChanged   = $false

            if ($sigChanged -or ($tickCount % 5 -eq 0)) {
                $checkIP = Get-PublicIP
                if ($checkIP -notmatch 'Desconocida') {
                    if ($checkIP -ne $lastPublicIP) {
                        $ipChanged   = $true
                        $curPublicIP = $checkIP
                    }
                }
            }

            if ($sigChanged -or $ipChanged) {
                $changeDetails = @()
                if ($sigChanged) { $changeDetails += "ADAPTADOR/VPN" }
                if ($ipChanged)  { $changeDetails += "IP($lastPublicIP->$curPublicIP)" }
                $changeDesc = $changeDetails -join " + "

                Write-EngineLog "¡Cambio de Red / VPN detectado! [$changeDesc]" "WARN"
                Send-ToastNotification -Title "VPN Cambiada - Reseteando" -Message "Detectado: $changeDesc. Estabilizando y aplicando Tokens Ampliados..."

                Write-EngineLog "Esperando $Debounce segundos a que la nueva conexion se estabilice..." "WARN"
                Start-Sleep -Seconds $Debounce

                # Confirmar IP post-estabilización
                $confirmedIP = Get-PublicIP
                if ($confirmedIP -notmatch 'Desconocida') {
                    $lastPublicIP = $confirmedIP
                }
                $lastSig = Get-NetworkSignature

                Invoke-FullReset -NewIP $lastPublicIP
                Write-Host "  IP activa post-reset: $lastPublicIP" -ForegroundColor Cyan
                Write-Host ""
            }
        } catch {
            Write-EngineLog "Error en ciclo monitor: $($_.Exception.Message)" "WARN"
            Start-Sleep -Seconds 4
        }
    }
}

# =============================================================================
# INTERACTIVE MENU
# =============================================================================

function Show-InteractiveMenu {
    while ($true) {
        Show-Banner
        Write-Host "  Obteniendo IP publica..." -ForegroundColor DarkGray
        $currentIP = Get-PublicIP
        Write-Host "  IP Publica Actual: $currentIP" -ForegroundColor Yellow
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [1]  Monitor Automatico  (ruteo+IP cada 3s, reset automatico 24/7)" -ForegroundColor White
        Write-Host "  [2]  Renovar Cuota       (espera nueva IP + rota Device ID)" -ForegroundColor White
        Write-Host "  [3]  Tokens Ampliados    (archiva session_v2 + limpia inbox)" -ForegroundColor Cyan
        Write-Host "  [4]  Reseteo Rapido      (sockets, daemons, DNS/ARP/NetBIOS)" -ForegroundColor White
        Write-Host "  [5]  Limpieza Total      (cache + cookies + Device ID + sesiones)" -ForegroundColor White
        Write-Host "  [6]  Stats de Tokens     (sesiones activas, tokens, TOP infladoras)" -ForegroundColor Green
        Write-Host "  [7]  Cambiar a OpenRouter (fix: 'You've used today's free messages')" -ForegroundColor Yellow
        Write-Host "  [8]  Salir" -ForegroundColor Gray
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  Selecciona una opcion [1-8]: " -NoNewline -ForegroundColor Cyan
        
        $choice = Read-Host

        switch ($choice) {
            "1" {
                Invoke-WatchLoop
                break
            }
            "2" {
                Invoke-RenewQuotaFlow
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "3" {
                Show-Banner
                Write-Host "  APLICANDO TOKENS AMPLIADOS (session_v2 archive + reasoning opt)" -ForegroundColor Cyan
                Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
                Show-TokenStats
                Write-Host ""
                Write-Host "  Archivando sesiones activas..." -ForegroundColor DarkGray
                Optimize-OpenCodeSessions -ForceArchiveAll
                Optimize-TokenConsumptionProfile -Profile "balanced"
                Write-Host ""
                Write-Host "  Optimizacion aplicada! RESULTADO:" -ForegroundColor Green
                Write-Host "  - Se archivaron todas las sesiones activas de session_v2." -ForegroundColor Gray
                Write-Host "  - Session inbox vaciado (contexto pendiente eliminado)." -ForegroundColor Gray
                Write-Host "  - Cada NUEVO comando iniciara con 0 tokens de historial." -ForegroundColor Yellow
                Write-Host "  - Model.json ajustado a reasoning 'high' (eficiente para shell)." -ForegroundColor Gray
                Write-Host ""
                Write-Host "  IMPORTANTE: Abre una sesion NUEVA en OpenCode para que aplique." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "4" {
                Invoke-FullReset
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "5" {
                Invoke-FullReset -ForceCleanSession
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "6" {
                Show-Banner
                Show-TokenStats
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "7" {
                Show-Banner
                Write-Host "  CAMBIAR A OPENROUTER FREE (sin limite diario)" -ForegroundColor Yellow
                Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
                Write-Host "  El error 'You ve used today s free messages' ocurre cuando el proveedor" -ForegroundColor Gray
                Write-Host "  opencode agota su cuota diaria. OpenRouter tiene modelos gratis sin ese limite." -ForegroundColor Gray
                Write-Host ""
                Switch-ToOpenRouterFreeModel
                Write-Host ""
                Write-Host "  Hecho! En OpenCode selecciona uno de estos modelos:" -ForegroundColor Green
                Write-Host "  - nvidia/nemotron-3.5-lightning:free  (1M contexto)" -ForegroundColor Cyan
                Write-Host "  - nvidia/nemotron-3.5-super-vl:free   (1M contexto)" -ForegroundColor Cyan
                Write-Host "  - deepseek/deepseek-chat-v3-0324:free" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "8" {
                Write-Host "Saliendo... Hasta pronto!" -ForegroundColor Cyan
                return
            }
            Default {
                Write-Host "Opcion invalida. Intenta de nuevo." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# =============================================================================
# ENTRYPOINT DISPATCHER
# =============================================================================

switch ($Action.ToLower()) {
    "watch"         { Invoke-WatchLoop }
    "-w"            { Invoke-WatchLoop }
    "--watch"       { Invoke-WatchLoop }
    "renew"         { Invoke-RenewQuotaFlow }
    "-r"            { Invoke-RenewQuotaFlow }
    "--renew"       { Invoke-RenewQuotaFlow }
    "boost"         { Optimize-OpenCodeSessions -ForceArchiveAll; Optimize-TokenConsumptionProfile -Profile "balanced" }
    "--boost"       { Optimize-OpenCodeSessions -ForceArchiveAll; Optimize-TokenConsumptionProfile -Profile "balanced" }
    "stats"         { Show-TokenStats }
    "--stats"       { Show-TokenStats }
    "-s"            { Show-TokenStats }
    "switch-model"  { Switch-ToOpenRouterFreeModel }
    "--switch"      { Switch-ToOpenRouterFreeModel }
    "reset"         { Invoke-FullReset }
    "--reset"       { Invoke-FullReset }
    "clean"         { Invoke-FullReset -ForceCleanSession }
    "--clean"       { Invoke-FullReset -ForceCleanSession }
    Default         { Show-InteractiveMenu }
}
