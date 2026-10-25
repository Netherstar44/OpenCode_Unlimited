<#
.SYNOPSIS
    Instala el monitor de red VPN para que se ejecute siempre de forma automática al iniciar Windows.
.DESCRIPTION
    Crea un acceso directo permanente en la carpeta de Inicio de Windows (shell:startup)
    e inicia el monitor de inmediato en segundo plano para que esté activo desde ya.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$targetVbs = Join-Path $scriptDir "Start-Watcher-Hidden.vbs"
$startupPath = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupPath "VPN-AutoReset-Watcher.lnk"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Configurando Inicio Automatico para Monitor VPN / Red    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Crear el acceso directo en Startup
try {
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "wscript.exe"
    $shortcut.Arguments = "`"$targetVbs`""
    $shortcut.WorkingDirectory = $scriptDir
    $shortcut.Description = "VPN Network Auto-Reset Watcher"
    $shortcut.Save()
    Write-Host "[OK] Acceso directo de inicio automatico creado en:" -ForegroundColor Green
    Write-Host "     $shortcutPath" -ForegroundColor Gray
} catch {
    Write-Host "[ERROR] No se pudo crear el acceso directo de inicio: $_" -ForegroundColor Red
    exit 1
}

# 2. Iniciar el monitor ahora mismo en segundo plano
Write-Host "`nIniciando el monitor en segundo plano ahora mismo..." -ForegroundColor Cyan
try {
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$targetVbs`""
    Start-Sleep -Seconds 1
    
    $pidFile = Join-Path $env:TEMP "vpn_network_watcher.pid"
    if (Test-Path $pidFile) {
        $wPid = Get-Content $pidFile -ErrorAction SilentlyContinue
        Write-Host "[OK] Monitor iniciado correctamente en segundo plano (PID: $wPid)." -ForegroundColor Green
    } else {
        Write-Host "[OK] Comando de inicio ejecutado." -ForegroundColor Green
    }
} catch {
    Write-Host "[AVISO] Error al iniciar el monitor inmediatamente: $_" -ForegroundColor Yellow
}

# 3. Enviar notificación Toast
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $textNodes = $template.GetElementsByTagName("text")
    $textNodes.Item(0).AppendChild($template.CreateTextNode("✅ Monitor VPN Auto-Inicio Activo")) | Out-Null
    $textNodes.Item(1).AppendChild($template.CreateTextNode("El monitor se ejecutará siempre automáticamente con Windows.")) | Out-Null
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("VPN Network Auto-Reset")
    $notification = [Windows.UI.Notifications.ToastNotification]::new($template)
    $notifier.Show($notification)
} catch {}

Write-Host "`nListo. A partir de ahora el monitor se ejecutara siempre solo al encender tu PC." -ForegroundColor Green
Write-Host "Ya esta activo en segundo plano en este momento." -ForegroundColor Green
Write-Host "Para desactivarlo en el futuro, solo ejecuta Desinstalar-AutoInicio.bat." -ForegroundColor Yellow
