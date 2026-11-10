@echo off
chcp 65001 >nul
title SnowLuma + AstrBot Deploy Tools
cd /d "%~dp0"

echo ========================================
echo  SnowLuma + AstrBot Deploy Tools
echo ========================================
echo.
echo  [1] Start services          (start.ps1)
echo  [2] Show passwords / URLs   (show-passwords.ps1)
echo  [3] Show status             (status.ps1)
echo  [4] Stop services           (stop.ps1)
echo  [5] Exit
echo.
set /p choice=Select (1-5): 

if "%choice%"=="1" powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1"
if "%choice%"=="2" powershell -ExecutionPolicy Bypass -File "%~dp0show-passwords.ps1"
if "%choice%"=="3" powershell -ExecutionPolicy Bypass -File "%~dp0status.ps1"
if "%choice%"=="4" powershell -ExecutionPolicy Bypass -File "%~dp0stop.ps1"

echo.
pause
