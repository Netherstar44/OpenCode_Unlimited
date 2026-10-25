@echo off
chcp 65001 >nul
title Desactivar Auto-Inicio del Monitor VPN
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-AutoStart.ps1"
echo.
pause
