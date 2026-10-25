@echo off
chcp 65001 >nul
title Reset de Red y Caches VPN
echo ========================================================
echo  Restableciendo conexion de red, DNS y herramientas...
echo ========================================================
call "%~dp0OpenCodeUnlimited.bat" --reset
echo.
echo Proceso finalizado. Puedes cerrar esta ventana.
pause
