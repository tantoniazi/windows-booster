@echo off
title Windows Booster
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permissao de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Windows-Booster.ps1"
if %errorlevel% neq 0 (
    echo.
    echo Erro ao iniciar o Windows Booster.
    echo Verifique se o Windows-Booster.ps1 esta na mesma pasta.
    pause
)
