@echo off
chcp 65001 >nul
title Detener Monitor de Red VPN

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$pidFiles = @(Join-Path $env:TEMP 'opencode_unlimited.pid', Join-Path $env:TEMP 'vpn_network_watcher.pid');" ^
    "foreach ($pidFile in $pidFiles) {" ^
    "    if (Test-Path $pidFile) {" ^
    "        $wPid = Get-Content $pidFile -ErrorAction SilentlyContinue;" ^
    "        if ($wPid) {" ^
    "            $p = Get-Process -Id $wPid -ErrorAction SilentlyContinue;" ^
    "            if ($p) {" ^
    "                Stop-Process -Id $wPid -Force;" ^
    "                Write-Host '[OK] Monitor de red (PID: ' $wPid ') detenido correctamente.' -ForegroundColor Green;" ^
    "            }" ^
    "        }" ^
    "        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue;" ^
    "    }" ^
    "}"

echo.
pause
