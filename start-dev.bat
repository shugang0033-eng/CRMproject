@echo off
rem ============================================================
rem  BeiChen CRM - one click start
rem  Double click this file to start backend + frontend.
rem ============================================================
setlocal
chcp 65001 >nul

set "SCRIPT=%~dp0scripts\start-dev.ps1"

if not exist "%SCRIPT%" (
    echo [ERROR] Missing file: scripts\start-dev.ps1
    echo Please make sure the scripts folder is next to this bat file.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "CODE=%ERRORLEVEL%"

echo.
if not "%CODE%"=="0" (
    echo [FAILED] exit code %CODE%
) else (
    echo [DONE] You can close this window. Services keep running in background.
)
echo.
pause
exit /b %CODE%
