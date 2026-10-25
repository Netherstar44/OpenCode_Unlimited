@echo off
chcp 65001 >nul
title Configurar Auto-Inicio Permanente del Monitor VPN
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AutoStart.ps1"
echo.
pause
