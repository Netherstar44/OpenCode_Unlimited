@echo off
setlocal
title OpenCode Unlimited - Made By Jose David Correa ~Netherstar44 & Juan Esteban Bustos ~juanitogit
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
$global:AuthorCredit = "Made By Jose David Correa ~Netherstar44 & Juan Esteban Bustos ~juanitogit"

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

# Test-OpenCodeQuotaAvailable: Sondea directamente opencode.ai para verificar si la IP actual
# tiene cuota diaria disponible para modelos gratuitos (evita reabrir OpenCode con IP quemada)
function Test-OpenCodeQuotaAvailable {
    param(
        [int]$TimeoutMs = 3500,
        [string]$ProxyUrl = ""
    )
    try {
        $url = 'https://opencode.ai/inference/openai/v1/chat/completions'
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.Method = 'POST'
        $req.Timeout = $TimeoutMs
        $req.ReadWriteTimeout = $TimeoutMs
        $req.KeepAlive = $false
        if ($ProxyUrl) {
            $req.Proxy = [System.Net.WebProxy]::new($ProxyUrl)
        } else {
            $req.Proxy = $null
        }
        $req.ContentType = 'application/json'
        $req.Headers.Add('Authorization', 'Bearer public')
        $req.UserAgent = 'opencode/2.1.4'
        $payload = '{"model":"deepseek-v4.1-flash-free","messages":[{"role":"user","content":"1"}],"max_tokens":1}'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $req.ContentLength = $bytes.Length
        $reqStream = $req.GetRequestStream()
        $reqStream.Write($bytes, 0, $bytes.Length)
        $reqStream.Close()
        $res = $req.GetResponse()
        $res.Close()
        return @{ Available = $true; Status = 200; Reason = "CUOTA_DISPONIBLE" }
    } catch [System.Net.WebException] {
        $ex = $_.Exception
        $statusCode = 0
        $body = ""
        if ($ex.Response) {
            $resp = [System.Net.HttpWebResponse]$ex.Response
            $statusCode = [int]$resp.StatusCode
            try {
                $reader = [System.IO.StreamReader]::new($resp.GetResponseStream())
                $body = $reader.ReadToEnd()
                $reader.Close()
            } catch {}
            $resp.Close()
        }
        if ($statusCode -eq 429 -or $body -match 'FreeUsageLimitError|rate-limit') {
            return @{ Available = $false; Status = $statusCode; Reason = "CUOTA_AGOTADA_HOY" }
        }
        return @{ Available = $false; Status = $statusCode; Reason = "ERROR_CONEXION" }
    } catch {
        return @{ Available = $false; Status = 0; Reason = $_.Exception.Message }
    }
}

# Get-UserAntiCollisionPool: Dispersión matemática de usuarios en 10 canales geográficos
# para que múltiples usuarios de OpenCodeUnlimited nunca compitan por las mismas IPs/nodos
function Get-UserAntiCollisionPool {
    $uuid = ""
    try {
        $uuid = (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID
    } catch {}
    if (-not $uuid) {
        $uuid = [Environment]::MachineName + "_" + [Environment]::UserName
    }
    $hash = 0
    foreach ($char in $uuid.ToCharArray()) {
        $hash = (($hash * 31) + [int]$char) -band 0x7FFFFFFF
    }
    $channel = $hash % 10

    # 10 grupos de países con bajo índice de colisión (excluyendo US/UK/Australia saturados)
    $countryPools = @(
        @("Suiza", "Islandia", "Noruega", "Japon", "Singapur"),
        @("Suecia", "Finlandia", "Nueva Zelanda", "Austria", "Irlanda"),
        @("Canada", "Paises Bajos", "Belgica", "Dinamarca", "Taiwan"),
        @("Alemania", "Republica Checa", "Polonia", "Portugal", "Chile"),
        @("Estonia", "Lituania", "Letonia", "Eslovaquia", "Corea del Sur"),
        @("Espana", "Italia", "Hungria", "Grecia", "Malasia"),
        @("Francia", "Luxemburgo", "Eslovenia", "Rumania", "Israel"),
        @("Brasil", "Mexico", "Argentina", "Colombia", "Sudafrica"),
        @("India", "Vietnam", "Tailandia", "Indonesia", "Filipinas"),
        @("Chipre", "Croacia", "Bulgaria", "Serbia", "Turquia")
    )
    return @{
        Channel   = $channel
        Countries = $countryPools[$channel]
        Uuid      = $uuid
    }
}

# =============================================================================
# TOR SUBSYSTEM - Rotacion anonima de IP via red Tor (miles de nodos de salida)
# Funciona sin instalar nada: descarga Tor Expert Bundle portable automaticamente.
# =============================================================================

$global:TorDir       = Join-Path $env:TEMP "opencode_tor"
$global:TorExe       = Join-Path $global:TorDir "Tor\tor.exe"
$global:TorDataDir   = Join-Path $global:TorDir "Data\Tor"
$global:TorSocksPort = 9150   # Puerto SOCKS5 de Tor
$global:TorCtrlPort  = 9151   # Puerto de control Tor (NEWNYM)
$global:TorHttpPort  = 8119   # Puerto del bridge HTTP→SOCKS5 (para OpenCode)
$global:TorProcess   = $null

function Get-TorBundlePath {
    # Descarga Tor Expert Bundle portable si no existe (sin instalacion)
    if (Test-Path $global:TorExe) { return $true }
    Write-EngineLog "Tor no encontrado. Descargando Tor Expert Bundle portable (~6MB)..." "ACTION"
    try {
        $torUrl  = "https://archive.torproject.org/tor-package-archive/torbrowser/14.5.2/tor-expert-bundle-windows-x86_64-14.5.2.tar.gz"
        $tarGz   = Join-Path $env:TEMP "tor_bundle.tar.gz"
        New-Item -ItemType Directory -Force -Path $global:TorDir | Out-Null
        $wc = [System.Net.WebClient]::new()
        $wc.DownloadFile($torUrl, $tarGz)
        # Extraer con tar (disponible en Windows 10+)
        & tar.exe -xzf $tarGz -C $global:TorDir 2>$null | Out-Null
        Remove-Item $tarGz -Force -ErrorAction SilentlyContinue
        if (Test-Path $global:TorExe) {
            Write-EngineLog "Tor Expert Bundle instalado correctamente en $global:TorDir" "SUCCESS"
            return $true
        }
        Write-EngineLog "Fallo la extraccion de Tor. Verifica conexion a internet." "ERROR"
        return $false
    } catch {
        Write-EngineLog "Error descargando Tor: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Start-TorDaemon {
    # Inicia tor.exe como proxy SOCKS5 local con ControlPort habilitado
    if ($global:TorProcess -and -not $global:TorProcess.HasExited) { return $true }
    if (-not (Get-TorBundlePath)) { return $false }

    New-Item -ItemType Directory -Force -Path $global:TorDataDir | Out-Null
    $torConfig = @"
SocksPort $global:TorSocksPort
ControlPort $global:TorCtrlPort
CookieAuthentication 0
DataDirectory $global:TorDataDir
Log notice stderr
ExitPolicy reject *:*
"@
    $configPath = Join-Path $global:TorDir "torrc_opencode"
    $torConfig | Set-Content -Path $configPath -Encoding ASCII -Force

    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new($global:TorExe)
        $psi.Arguments        = "-f `"$configPath`""
        $psi.UseShellExecute  = $false
        $psi.CreateNoWindow   = $true
        $psi.RedirectStandardError = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $global:TorProcess = $p

        Write-EngineLog "Tor iniciado (PID $($p.Id)). Esperando bootstrap de red (~15s)..." "ACTION"
        # Esperar hasta que Tor esté listo (bootstrap 100%)
        $deadline = (Get-Date).AddSeconds(30)
        $ready    = $false
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 2
            try {
                $tcp = [System.Net.Sockets.TcpClient]::new("127.0.0.1", $global:TorSocksPort)
                $tcp.Close()
                $ready = $true
                break
            } catch {}
        }
        if ($ready) {
            Write-EngineLog "Tor listo en SOCKS5 127.0.0.1:$global:TorSocksPort" "SUCCESS"
            return $true
        }
        Write-EngineLog "Tor no respondio a tiempo. Puede estar lento en la red." "WARN"
        return $false
    } catch {
        Write-EngineLog "Error iniciando Tor: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Stop-TorDaemon {
    if ($global:TorProcess -and -not $global:TorProcess.HasExited) {
        try { $global:TorProcess.Kill() } catch {}
        $global:TorProcess = $null
        Write-EngineLog "Daemon Tor detenido." "INFO"
    }
    # Tambien limpiar el bridge Python
    try { & taskkill.exe /F /IM "python.exe" /FI "WINDOWTITLE eq tor_http_bridge" 2>$null | Out-Null } catch {}
}

function Start-TorHttpBridge {
    # Lanza un micro-servidor HTTP->SOCKS5 en Python para que OpenCode pueda usar Tor
    # (OpenCode usa HTTP_PROXY, no SOCKS5 directo)
    $bridgeScript = @"
import socket, threading, socks, select, sys
LISTEN_PORT  = $global:TorHttpPort
SOCKS5_HOST  = '127.0.0.1'
SOCKS5_PORT  = $global:TorSocksPort

def forward(src, dst):
    try:
        while True:
            r, _, _ = select.select([src, dst], [], [], 5)
            if not r: break
            for s in r:
                d = dst if s is src else src
                data = s.recv(4096)
                if not data: return
                d.sendall(data)
    except: pass
    finally:
        for s in (src, dst): 
            try: s.close()
            except: pass

def handle(conn):
    try:
        raw = b''
        while b'\r\n\r\n' not in raw:
            chunk = conn.recv(4096)
            if not chunk: return
            raw += chunk
        first = raw.split(b'\r\n')[0].decode()
        parts = first.split()
        if len(parts) < 3: return
        method, target = parts[0], parts[1]
        if method == 'CONNECT':
            host, port = target.rsplit(':', 1)
            port = int(port)
            remote = socks.socksocket()
            remote.set_proxy(socks.SOCKS5, SOCKS5_HOST, SOCKS5_PORT)
            remote.connect((host, port))
            conn.sendall(b'HTTP/1.1 200 Connection established\r\n\r\n')
            t = threading.Thread(target=forward, args=(conn, remote), daemon=True)
            t.start()
            forward(remote, conn)
        else:
            from urllib.parse import urlparse
            parsed = urlparse(target)
            host = parsed.hostname
            port = parsed.port or 80
            remote = socks.socksocket()
            remote.set_proxy(socks.SOCKS5, SOCKS5_HOST, SOCKS5_PORT)
            remote.connect((host, port))
            path = parsed.path or '/'
            if parsed.query: path += '?' + parsed.query
            hdrs = raw.split(b'\r\n\r\n', 1)
            new_req = method.encode() + b' ' + path.encode() + b' HTTP/1.1\r\n'
            body_start = hdrs[1] if len(hdrs) > 1 else b''
            lines = hdrs[0].split(b'\r\n')[1:]
            lines = [l for l in lines if not l.lower().startswith(b'proxy-')]
            new_req += b'\r\n'.join(lines) + b'\r\n\r\n' + body_start
            remote.sendall(new_req)
            forward(conn, remote)
    except: pass
    finally:
        try: conn.close()
        except: pass

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', LISTEN_PORT))
srv.listen(64)
sys.stdout.write('BRIDGE_READY\n'); sys.stdout.flush()
while True:
    conn, _ = srv.accept()
    threading.Thread(target=handle, args=(conn,), daemon=True).start()
"@
    $bridgePath = Join-Path $env:TEMP "tor_http_bridge.py"
    $bridgeScript | Set-Content -Path $bridgePath -Encoding ASCII -Force

    $psi = [System.Diagnostics.ProcessStartInfo]::new("python")
    $psi.Arguments        = "`"$bridgePath`""
    $psi.UseShellExecute  = $false
    $psi.CreateNoWindow   = $true
    $psi.RedirectStandardOutput = $true
    $p = [System.Diagnostics.Process]::Start($psi)

    # Esperar confirmacion del bridge
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        $line = $p.StandardOutput.ReadLine()
        if ($line -eq "BRIDGE_READY") { break }
        Start-Sleep -Milliseconds 300
    }
    Write-EngineLog "Bridge HTTP->SOCKS5 listo en 127.0.0.1:$global:TorHttpPort" "SUCCESS"
    return "http://127.0.0.1:$global:TorHttpPort"
}

function Invoke-TorNewCircuit {
    # Ordena a Tor que construya un nuevo circuito anonimo (nueva IP de salida)
    try {
        $tcp = [System.Net.Sockets.TcpClient]::new("127.0.0.1", $global:TorCtrlPort)
        $stream = $tcp.GetStream()
        $writer = [System.IO.StreamWriter]::new($stream)
        $reader = [System.IO.StreamReader]::new($stream)
        $writer.WriteLine("AUTHENTICATE")
        $writer.Flush()
        Start-Sleep -Milliseconds 200
        $writer.WriteLine("SIGNAL NEWNYM")
        $writer.Flush()
        Start-Sleep -Milliseconds 500
        $writer.Close(); $reader.Close(); $tcp.Close()
        Write-EngineLog "Nuevo circuito Tor solicitado (NEWNYM). IP de salida cambiada." "SUCCESS"
        Start-Sleep -Seconds 2  # Tor necesita ~1-2s para establecer el nuevo circuito
        return $true
    } catch {
        Write-EngineLog "No se pudo rotar circuito Tor: $($_.Exception.Message)" "WARN"
        return $false
    }
}

function Test-QuotaViaTor {
    # Prueba la cuota de opencode.ai a traves del proxy HTTP->Tor
    param([string]$HttpProxy = "http://127.0.0.1:$global:TorHttpPort", [int]$TimeoutMs = 6000)
    return (Test-OpenCodeQuotaAvailable -ProxyUrl $HttpProxy -TimeoutMs $TimeoutMs)
}

function Get-TorPublicIP {
    # Consulta la IP de salida actual del circuito Tor
    try {
        $req = [System.Net.HttpWebRequest]::Create("https://check.torproject.org/api/ip")
        $req.Proxy   = [System.Net.WebProxy]::new("http://127.0.0.1:$global:TorHttpPort")
        $req.Timeout = 8000
        $res = $req.GetResponse()
        $body = [System.IO.StreamReader]::new($res.GetResponseStream()).ReadToEnd()
        $res.Close()
        $ip = ($body | ConvertFrom-Json).IP
        return $ip
    } catch { return "Desconocida" }
}

function Invoke-TorQuotaRenew {
    # Workflow completo: inicia Tor, rota circuitos hasta encontrar IP con cuota libre,
    # configura HTTP_PROXY para OpenCode y dispara el reset
    Show-Banner
    Write-Host "  =========================================================================" -ForegroundColor Magenta
    Write-Host "  MODO TOR - Rotacion Anonima (miles de IPs de salida disponibles)" -ForegroundColor Cyan
    Write-Host "  =========================================================================" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "  [1/3] Iniciando daemon Tor local..." -ForegroundColor DarkGray
    if (-not (Start-TorDaemon)) {
        Write-Host "  [ERROR] No se pudo iniciar Tor. Verifica internet y vuelve a intentarlo." -ForegroundColor Red
        Read-Host "  Presiona ENTER para volver al menu"
        return
    }

    Write-Host "  [2/3] Iniciando bridge HTTP->SOCKS5 para OpenCode..." -ForegroundColor DarkGray
    $proxyUrl = Start-TorHttpBridge
    Write-Host ""

    Write-Host "  [3/3] Buscando circuito Tor con cuota disponible en opencode.ai..." -ForegroundColor DarkGray
    Write-Host ""

    $maxRotations = 20
    $foundClean   = $false
    for ($i = 1; $i -le $maxRotations; $i++) {
        $torIP = Get-TorPublicIP
        Write-Host "  Circuito #$i | IP Tor de salida: $torIP" -ForegroundColor Cyan
        $probe = Test-QuotaViaTor -HttpProxy $proxyUrl
        if ($probe.Available) {
            Write-Host "  [CUOTA LIBRE] IP Tor $torIP tiene cuota 100% disponible!" -ForegroundColor Green
            $foundClean = $true
            break
        } elseif ($probe.Reason -eq 'CUOTA_AGOTADA_HOY') {
            Write-Host "  [AGOTADA] Nodo Tor $torIP ya consumido. Rotando a nuevo circuito..." -ForegroundColor Yellow
            Invoke-TorNewCircuit | Out-Null
        } else {
            Write-Host "  [?] Estado: $($probe.Reason). Rotando de todas formas..." -ForegroundColor DarkYellow
            Invoke-TorNewCircuit | Out-Null
        }
    }

    if ($foundClean) {
        Write-Host ""
        Write-Host "  =========================================================================" -ForegroundColor Cyan
        Write-Host "  IP Tor limpia encontrada. Configurando OpenCode para usar proxy Tor..." -ForegroundColor Green
        Write-Host "  =========================================================================" -ForegroundColor Cyan
        Write-Host ""
        # Configurar proxy para la sesion actual (OpenCode hereda estas variables)
        $env:HTTP_PROXY  = $proxyUrl
        $env:HTTPS_PROXY = $proxyUrl
        $env:ALL_PROXY   = "socks5://127.0.0.1:$global:TorSocksPort"
        Invoke-FullReset -ForceCleanSession
        Write-EngineLog "OpenCode iniciado con proxy Tor ($proxyUrl). IP limpia garantizada." "SUCCESS"
        Write-Host "  IMPORTANTE: Inicia un NUEVO CHAT (Ctrl+N) para usar la cuota virgen." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  El proxy Tor se mantiene activo mientras OpenCode esta abierto." -ForegroundColor DarkGray
        Write-Host "  Para desactivar Tor, cierra OpenCode y vuelve al menu (opcion 5 Reset)." -ForegroundColor DarkGray
    } else {
        Write-Host ""
        Write-Host "  [AVISO] No se encontro IP Tor limpia tras $maxRotations intentos." -ForegroundColor Yellow
        Write-Host "  La red Tor tiene cuota agotada en los nodos probados ahora." -ForegroundColor Yellow
        Write-Host "  Prueba mas tarde o usa la Opcion 2 con VPN manual." -ForegroundColor DarkGray
    }

    Write-Host ""
    Read-Host "  Presiona ENTER para volver al menu"
}

# =============================================================================
# PROCESSES & DAEMON MANAGEMENT
# =============================================================================

function Stop-OpenCodeProcesses {
    $foundDesktop = $false
    $desktopPath = $null

    # 1. Localizar ruta de OpenCode Desktop antes del cierre
    $desktopProcs = Get-Process -Name "OpenCode" -ErrorAction SilentlyContinue
    if ($desktopProcs) {
        $foundDesktop = $true
        try { $desktopPath = $desktopProcs[0].Path } catch {}
    }
    if (-not $desktopPath) {
        $candidate = "$env:LOCALAPPDATA\Programs\@opencodedesktop\OpenCode.exe"
        if (Test-Path $candidate) { $desktopPath = $candidate }
    }

    Write-EngineLog "Cerrando OpenCode Desktop, CLI y Daemons para liberar sockets..." "ACTION"

    # 2. Detener servicio formalmente si está activo
    try { & opencode service stop 2>$null | Out-Null } catch {}

    # 3. Forzar terminación completa de todo el árbol de procesos con taskkill
    & taskkill.exe /F /T /IM "OpenCode.exe" /IM "opencode-cli.exe" /IM "opencode.exe" 2>$null | Out-Null

    # 4. Asegurar eliminación vía PowerShell Stop-Process
    @("OpenCode", "opencode-cli", "opencode") | ForEach-Object {
        Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue
    }

    # 5. Terminar procesos dinámicos huérfanos de servicio (opencode-service-*.exe)
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*opencode-service*" } | ForEach-Object {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }

    # 6. Limpiar archivos de bloqueo residuales
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

    # 2. Eliminar service.json en AMBAS rutas (.local y .config) para crear sesión de servicio virgen
    $serviceJsonPaths = @(
        "$env:USERPROFILE\.local\state\opencode\service.json",
        "$env:USERPROFILE\.config\opencode\service.json"
    )
    foreach ($sp in $serviceJsonPaths) {
        if (Test-Path $sp) {
            try {
                Remove-Item -Path $sp -Force -ErrorAction SilentlyContinue
                Write-EngineLog "ID de servicio anterior eliminado en $(Split-Path $sp -Leaf)." "SUCCESS"
            } catch {}
        }
    }

    # 3. Eliminar archivos de estado de ventana para evitar restaurar el chat con error 429
    $desktopApp = "$env:APPDATA\ai.opencode.desktop"
    if (Test-Path $desktopApp) {
        Get-ChildItem -Path $desktopApp -Filter "window-state*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    # 4. Limpiar borradores y prompts caídos de drafts.sqlite
    $draftsDb = Join-Path $desktopApp "drafts.sqlite"
    if (Test-Path $draftsDb) {
        $pyDraft = @"
import sqlite3, os
p = os.path.expanduser(r'~\AppData\Roaming\ai.opencode.desktop\drafts.sqlite')
if os.path.exists(p):
    conn = sqlite3.connect(p)
    cur = conn.cursor()
    cur.execute("DELETE FROM document WHERE key LIKE '%:session:%' OR key LIKE '%:draft:%'")
    conn.commit()
    conn.close()
"@
        try { python -c $pyDraft 2>$null } catch {}
    }

    # 5. Limpiar huellas locales de nivel db y cookies en ai.opencode.desktop (preservando config)
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

    Write-Host "  Comprobando red, cuota y canal anti-colision..." -ForegroundColor DarkGray
    $initialSig = Get-NetworkSignature
    $initialIP  = Get-PublicIP
    $probeInit  = Test-OpenCodeQuotaAvailable -TimeoutMs 3500
    $pool       = Get-UserAntiCollisionPool
    $poolCountries = $pool.Countries -join ', '

    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  RENOVAR CUOTA / TOKENS AMPLIADOS" -ForegroundColor Yellow
    Write-Host "  IP Actual: $initialIP" -ForegroundColor Cyan
    if ($probeInit.Available) {
        Write-Host "  Estado de Cuota en IP Actual: [DISPONIBLE (100% LIMPIA)]" -ForegroundColor Green
    } elseif ($probeInit.Reason -eq 'CUOTA_AGOTADA_HOY') {
        Write-Host "  Estado de Cuota en IP Actual: [AGOTADA HOY (429) - REQUIERE OTRA IP/VPN]" -ForegroundColor Red
    } else {
        Write-Host "  Estado de Cuota en IP Actual: [$($probeInit.Reason)]" -ForegroundColor DarkYellow
    }
    Write-Host "  Canal Anti-Colision Asignado: #$($pool.Channel) de 10" -ForegroundColor Magenta
    Write-Host "  Tus paises dedicados: $poolCountries" -ForegroundColor Green
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  TU CANAL EXCLUSIVO (minimiza colisiones con otros usuarios del script):" -ForegroundColor White
    Write-Host "  Canal #$($pool.Channel) -> $poolCountries" -ForegroundColor Green
    Write-Host ""
    Write-Host "  COMO RENOVAR CUOTA CON EXITO:" -ForegroundColor White
    Write-Host "  1. En tu VPN, conecta a UNO de tus paises del Canal #$($pool.Channel) listados arriba." -ForegroundColor White
    Write-Host "  2. El monitor detecta la nueva conexion y VERIFICA que la IP tenga cuota real." -ForegroundColor Green
    Write-Host "  3. Si la VPN asigna una IP ya usada hoy, te avisara para que cambies de pais." -ForegroundColor Yellow
    Write-Host "  4. Cuando confirme una IP con cuota 100% libre, reseteara y abrira OpenCode." -ForegroundColor Cyan
    Write-Host "  (Presiona ENTER en cualquier momento para forzar renovacion con la IP actual)" -ForegroundColor DarkGray
    Write-Host ""

    Send-ToastNotification `
        -Title "Cambiar de VPN ahora" `
        -Message "OpenCode Unlimited esperando nueva IP limpia. Conecta o cambia de país en tu VPN."

    Write-EngineLog "Esperando cambio de red o IP con cuota libre... (Base: $initialIP)" "NOTIFY"

    $attempts          = 0
    $maxAttempts       = 240
    $detectedCleanIP   = $null
    $lastLine          = ""

    while ($attempts -lt $maxAttempts) {
        # Comprobar si el usuario presiono una tecla (no bloqueante)
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Enter' -or $key.Key -eq 'Spacebar') {
                Write-Host ""
                Write-Host "  >> ENTER detectado: forzando renovacion con la conexion actual..." -ForegroundColor Magenta
                $detectedCleanIP = Get-PublicIP
                break
            }
        }

        Start-Sleep -Milliseconds 800
        $attempts++

        # 1. Deteccion instantanea por cambio de adaptador o rutas VPN
        $curSig = Get-NetworkSignature
        $sigChanged = ($curSig -ne $initialSig)

        if ($sigChanged) {
            Write-Host ""
            Write-EngineLog "¡Cambio de adaptador/VPN detectado en tiempo real!" "SUCCESS"
            Write-Host "  Estabilizando rutas de la nueva conexion ($Debounce s)..." -ForegroundColor Cyan
            Start-Sleep -Seconds $Debounce

            $newIP = Get-PublicIP
            if ($newIP -notmatch "Desconocida") {
                Write-EngineLog "Nueva IP detectada: $newIP. Verificando disponibilidad de cuota en opencode.ai..." "ACTION"
                $probe = Test-OpenCodeQuotaAvailable -TimeoutMs 4000
                if ($probe.Available) {
                    Write-EngineLog "¡IP LIMPIA CONFIRMADA ($newIP)! Cuota de mensajes 100% disponible." "SUCCESS"
                    $detectedCleanIP = $newIP
                    break
                } elseif ($probe.Reason -eq 'CUOTA_AGOTADA_HOY') {
                    Write-EngineLog "AVISO: La IP asignada ($newIP) ya fue quemada hoy por otro usuario en este nodo VPN." "WARN"
                    Write-Host ""
                    Write-Host "  =========================================================================" -ForegroundColor Yellow
                    Write-Host "  LA IP $newIP YA CONSUMIO SU CUOTA GRATUITA HOY" -ForegroundColor Red
                    Write-Host "  IPs compartidas de VPN publica son usadas por muchos desarrolladores." -ForegroundColor Yellow
                    Write-Host "  >> Tu canal #$($pool.Channel) recomienda: $poolCountries" -ForegroundColor Green
                    Write-Host "  Conecta tu VPN a uno de esos paises para obtener una IP limpia." -ForegroundColor Green
                    Write-Host "  =========================================================================" -ForegroundColor Yellow
                    Write-Host ""
                    $initialIP  = $newIP
                    $initialSig = Get-NetworkSignature
                    continue
                } else {
                    Write-EngineLog "IP detectada ($newIP). Estado de cuota: $($probe.Reason)" "INFO"
                    $detectedCleanIP = $newIP
                    break
                }
            }
        }

        # 2. Deteccion complementaria por consulta de IP cada 3 segundos
        if ($attempts % 3 -eq 0) {
            $checkIP = Get-PublicIP
            if ($checkIP -match "Desconocida") {
                $statusLine = "  [$(Get-Date -Format 'HH:mm:ss')] Negociando VPN... (esperando enlace) [$attempts s]"
                $statusColor = "DarkYellow"
            } elseif ($checkIP -ne $initialIP) {
                Write-Host ""
                Write-EngineLog "Nueva IP detectada: $checkIP. Verificando cuota en opencode.ai..." "ACTION"
                $probe = Test-OpenCodeQuotaAvailable -TimeoutMs 4000
                if ($probe.Available) {
                    Write-EngineLog "¡IP LIMPIA CONFIRMADA ($checkIP)! Cuota de mensajes 100% disponible." "SUCCESS"
                    $detectedCleanIP = $checkIP
                    break
                } elseif ($probe.Reason -eq 'CUOTA_AGOTADA_HOY') {
                    Write-EngineLog "AVISO: La IP asignada ($checkIP) ya fue quemada hoy por otro usuario." "WARN"
                    Write-Host ""
                    Write-Host "  =========================================================================" -ForegroundColor Yellow
                    Write-Host "  LA IP $checkIP YA CONSUMIO SU CUOTA GRATUITA HOY" -ForegroundColor Red
                    Write-Host "  >> Tu canal #$($pool.Channel) recomienda: $poolCountries" -ForegroundColor Green
                    Write-Host "  Conecta tu VPN a uno de esos paises para obtener una IP limpia." -ForegroundColor Green
                    Write-Host "  =========================================================================" -ForegroundColor Yellow
                    Write-Host ""
                    $initialIP  = $checkIP
                    $initialSig = Get-NetworkSignature
                    continue
                } else {
                    $detectedCleanIP = $checkIP
                    break
                }
            } else {
                $statusLine = "  [$(Get-Date -Format 'HH:mm:ss')] Esperando cambio en VPN... IP actual: $checkIP [$attempts s]"
                $statusColor = "DarkGray"
            }

            if ($statusLine -ne $lastLine) {
                Write-Host ("`r" + $statusLine.PadRight(88)) -ForegroundColor $statusColor -NoNewline
                $lastLine = $statusLine
            }
        }
    }

    Write-Host ""

    if ($detectedCleanIP -and $detectedCleanIP -notmatch "Desconocida") {
        Write-Host ""
        Write-Host "  =========================================================================" -ForegroundColor Cyan
        Write-Host "  IP CONFIRMADA: $detectedCleanIP" -ForegroundColor Green
        Write-Host "  Aplicando Tokens Ampliados, rotando Device ID y reiniciando OpenCode..." -ForegroundColor Cyan
        Write-Host "  =========================================================================" -ForegroundColor Cyan
        Invoke-FullReset -ForceCleanSession -NewIP $detectedCleanIP
        Write-EngineLog "¡Cuota renovada con exito! OpenCode iniciado con IP limpia: $detectedCleanIP" "SUCCESS"
        Write-Host ""
        Write-Host "  IMPORTANTE: Inicia un NUEVO CHAT (Ctrl + N) para aprovechar la cuota virgen." -ForegroundColor Yellow
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
        Write-Host "  Consultando conexion, cuota y canal anti-colision..." -ForegroundColor DarkGray
        $currentIP   = Get-PublicIP
        $quotaStatus = Test-OpenCodeQuotaAvailable -TimeoutMs 2500
        $pool        = Get-UserAntiCollisionPool

        Write-Host "  IP Publica Actual:  $currentIP" -ForegroundColor Cyan
        if ($quotaStatus.Available) {
            Write-Host "  Estado de Cuota IP: [DISPONIBLE (100% LIMPIA)]" -ForegroundColor Green
        } elseif ($quotaStatus.Reason -eq 'CUOTA_AGOTADA_HOY') {
            Write-Host "  Estado de Cuota IP: [AGOTADA HOY (429) - Cambia de VPN/Pais]" -ForegroundColor Red
        } else {
            Write-Host "  Estado de Cuota IP: [$($quotaStatus.Reason)]" -ForegroundColor DarkYellow
        }
        Write-Host "  Canal Anti-Colision: #$($pool.Channel)/10 -> $($pool.Countries -join ', ')" -ForegroundColor Magenta

        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [1]  Monitor Automatico  (ruteo+IP cada 3s, reset automatico 24/7)" -ForegroundColor White
        Write-Host "  [2]  Renovar Cuota       (detecta nueva IP via VPN + valida cuota + rota ID)" -ForegroundColor White
        Write-Host "  [3]  Renovar via TOR     (auto-rota miles de IPs anonimas hasta encontrar libre)" -ForegroundColor Magenta
        Write-Host "  [4]  Tokens Ampliados    (archiva session_v2 + limpia inbox a contexto 0)" -ForegroundColor Cyan
        Write-Host "  [5]  Reseteo Rapido      (sockets, daemons, DNS/ARP/NetBIOS)" -ForegroundColor White
        Write-Host "  [6]  Limpieza Total      (cache + cookies + Device ID + sesiones)" -ForegroundColor White
        Write-Host "  [7]  Stats de Tokens     (sesiones activas, tokens, TOP infladoras)" -ForegroundColor Green
        Write-Host "  [8]  Cambiar a OpenRouter (fix alternativo: 20+ modelos sin limite diario)" -ForegroundColor Yellow
        Write-Host "  [9]  Salir" -ForegroundColor Gray
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  Selecciona una opcion [1-9]: " -NoNewline -ForegroundColor Cyan
        
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
                Invoke-TorQuotaRenew
            }
            "4" {
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
            "5" {
                Invoke-FullReset
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "6" {
                Invoke-FullReset -ForceCleanSession
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "7" {
                Show-Banner
                Show-TokenStats
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "8" {
                Show-Banner
                Write-Host "  CAMBIAR A OPENROUTER FREE (sin limite diario de mensajes)" -ForegroundColor Yellow
                Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
                Write-Host "  El proveedor 'opencode' impone limite diario gratuito por IP." -ForegroundColor Gray
                Write-Host "  OpenRouter tiene docenas de modelos gratis sin cuota fija de mensajes." -ForegroundColor Gray
                Write-Host ""
                Switch-ToOpenRouterFreeModel
                Write-Host ""
                Write-Host "  Hecho! En OpenCode puedes usar estos modelos gratis:" -ForegroundColor Green
                Write-Host "  - nvidia/nemotron-3.5-lightning:free  (1M contexto)" -ForegroundColor Cyan
                Write-Host "  - nvidia/nemotron-3.5-super-vl:free   (1M contexto)" -ForegroundColor Cyan
                Write-Host "  - deepseek/deepseek-chat-v3-0324:free" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  IMPORTANTE (Si usas OpenRouter):" -ForegroundColor Yellow
                Write-Host "  Si OpenRouter da error 'zdr-violation-by-account', desactiva ZDR en:" -ForegroundColor Gray
                Write-Host "  https://openrouter.ai/settings/privacy -> Desmarcar 'Enforce Zero Data Retention'" -ForegroundColor Magenta
                Write-Host ""
                Write-Host "Presiona cualquier tecla para volver al menu..." -ForegroundColor Gray
                [Console]::ReadKey($true) | Out-Null
            }
            "9" {
                Write-Host "Saliendo... Hasta pronto!" -ForegroundColor Cyan
                Stop-TorDaemon
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
    "tor"           { Invoke-TorQuotaRenew }
    "--tor"         { Invoke-TorQuotaRenew }
    Default         { Show-InteractiveMenu }
}
