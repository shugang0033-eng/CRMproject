@echo off
rem ============================================================
rem  BeiChen CRM - one click stop
rem  Double click this file to stop backend + frontend.
rem ============================================================
setlocal
chcp 65001 >nul

set "SCRIPT=%~dp0scripts\stop-dev.ps1"

if not exist "%SCRIPT%" (
    echo [ERROR] Missing file: scripts\stop-dev.ps1
    echo Please make sure the scripts folder is next to this bat file.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "CODE=%ERRORLEVEL%"

echo.
pause
exit /b %CODE%
