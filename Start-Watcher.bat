@echo off
chcp 65001 >nul
title Monitor de Red y VPN - Auto Reset
call "%~dp0OpenCodeUnlimited.bat" --watch
pause
