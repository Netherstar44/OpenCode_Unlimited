<#
.SYNOPSIS
    Monitor en segundo plano que detecta cambios de VPN, Red o IP y resetea automáticamente las herramientas y cachés.
.DESCRIPTION
    Monitorea de forma continua los adaptadores de red, IPs asignadas, puertas de enlace y servidores DNS.
    Cuando detecta un cambio (ej. conectar, desconectar o cambiar de servidor VPN):
    1. Espera unos segundos (debounce) a que la nueva VPN establezca rutas y DNS completamente.
    2. Vía Reset-NetworkApps.ps1:
       - Vaciá la caché DNS de Windows (Clear-DnsClientCache / flushdns).
       - Cierra instancias de OpenCode Desktop y CLI para destruir los sockets TCP viejos/colgados.
       - Vuelve a iniciar OpenCode Desktop automáticamente con la nueva IP asignada.
    3. Envía una notificación Toast de Windows informando del cambio.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [int]$CheckIntervalSeconds = 3,

    [Parameter(Mandatory = $false)]
    [int]$DebounceSeconds = 3,

    [Parameter(Mandatory = $false)]
    [switch]$NoRestartDesktop,

    [Parameter(Mandatory = $false)]
    [switch]$NoDesktop,

    [Parameter(Mandatory = $false)]
    [switch]$NoKillCli,

    [Parameter(Mandatory = $false)]
    [string[]]$ExtraProcesses = @(),

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$resetScriptPath = Join-Path $scriptDir "Reset-NetworkApps.ps1"
$pidFile = Join-Path $env:TEMP "vpn_network_watcher.pid"
$logFile = Join-Path $env:TEMP "vpn_network_watcher.log"

# Control de instancia única
if (Test-Path $pidFile) {
    try {
        $oldPid = Get-Content $pidFile -ErrorAction Stop
        if ($oldPid -and ($oldPid -ne $PID) -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
            Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
    } catch {}
}
$PID | Set-Content $pidFile -Force

function Write-WatcherLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -Path $logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
    if ($Quiet) { return }
    try {
        switch ($Level) {
            "SUCCESS" { Write-Host "[$timestamp] [OK]     $Message" -ForegroundColor Green }
            "WARN"    { Write-Host "[$timestamp] [CAMBIO] $Message" -ForegroundColor Yellow }
            "RESET"   { Write-Host "[$timestamp] [RESET]  $Message" -ForegroundColor Magenta }
            "ERROR"   { Write-Host "[$timestamp] [ERROR]  $Message" -ForegroundColor Red }
            Default   { Write-Host "[$timestamp] [MONITOR] $Message" -ForegroundColor Cyan }
        }
    } catch {}
}

# Obtener firma única del estado actual de la red (adaptadores activos, IPs, DNS, Gateways)
function Get-NetworkSignature {
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
                $signatureItems += "$($adapter.Name)|IPs:$($ipv4s -join ',')|GW:$($gateways -join ',')|DNS:$($dnsServers -join ',')"
            }
        }
    } catch {
        # Fallback si ocurre un error temporal leyendo adaptadores
    }
    return ($signatureItems | Sort-Object) -join " ;; "
}

Write-WatcherLog "=========================================================="
Write-WatcherLog "  VPN / Network Auto-Watcher para OpenCode y Herramientas"
Write-WatcherLog "  Presiona Ctrl + C para detener el monitor."
Write-WatcherLog "=========================================================="

$lastSignature = Get-NetworkSignature
Write-WatcherLog "Estado inicial de la red registrado." "SUCCESS"
Write-WatcherLog "Firma de red actual: $lastSignature"

while ($true) {
    try {
        Start-Sleep -Seconds $CheckIntervalSeconds
        
        $currentSignature = Get-NetworkSignature
        
        # Si la firma cambió (conexión, desconexión o cambio de servidor VPN)
        if ($currentSignature -ne $lastSignature) {
            Write-WatcherLog "¡Cambio de Red / VPN detectado!" "WARN"
            Write-WatcherLog "Esperando $DebounceSeconds segundos a que la VPN termine de negociar rutas y DNS..." "WARN"
            
            Start-Sleep -Seconds $DebounceSeconds
            
            # Leer la firma estabilizada
            $stabilizedSignature = Get-NetworkSignature
            $lastSignature = $stabilizedSignature
            
            Write-WatcherLog "Red estabilizada. Ejecutando reseteo de cachés y software..." "RESET"
            
            # Construir argumentos para el script de reseteo
            $resetArgs = @("-SendNotification")
            if ($NoRestartDesktop) { $resetArgs += "-NoRestartDesktop" }
            if ($NoDesktop)        { $resetArgs += "-NoDesktop" }
            if ($NoKillCli)        { $resetArgs += "-NoKillCli" }
            if ($Quiet)            { $resetArgs += "-Silent" }
            if ($ExtraProcesses.Count -gt 0) {
                $resetArgs += "-ExtraProcesses"
                $resetArgs += ($ExtraProcesses -join ",")
            }

            if (Test-Path $resetScriptPath) {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $resetScriptPath @resetArgs
            } else {
                Write-WatcherLog "No se encontró Reset-NetworkApps.ps1 en $resetScriptPath" "ERROR"
            }
            
            Write-WatcherLog "Monitoreo reanudado. Esperando próximos cambios de red..." "SUCCESS"
        }
    } catch {
        Write-WatcherLog "Error transitorio en ciclo del monitor: $($_.Exception.Message)" "WARN"
        Start-Sleep -Seconds 5
    }
}
