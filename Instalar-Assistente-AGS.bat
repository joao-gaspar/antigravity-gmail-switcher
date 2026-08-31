@echo off
set AGS_VER=v2.4.1
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

echo   [1/3] Baixando instalador...
curl -s -L -o "%SETUP_FILE%" https://antigravity-gmail-switcher.vercel.app/setup.ps1

if not exist "%SETUP_FILE%" (
    echo   [1/3] Tentando metodo secundario de download...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://antigravity-gmail-switcher.vercel.app/setup.ps1', '%SETUP_FILE%')"
)

if not exist "%SETUP_FILE%" (
    color 0C
    echo.
    echo   ❌ ERRO: Nao foi possivel baixar o script setup.ps1.
    echo   Verifique sua conexao com a internet ou firewall.
    echo.
    pause
    exit /b 1
)

echo   [2/3] Executando configuracao no PowerShell...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SETUP_FILE%"

if exist "%SETUP_FILE%" del /f /q "%SETUP_FILE%" >nul 2>&1

echo.
echo   [3/3] Verificando se o servidor respondeu...
powershell -NoProfile -Command "try { $r = Invoke-RestMethod -Uri 'http://127.0.0.1:8000/api/status' -TimeoutSec 3; Write-Host '   ✅ SERVIDOR ON: Hostname ' $r.machine.hostname -ForegroundColor Green } catch { Write-Host '   ⚠️ Servidor iniciando em segundo plano...' -ForegroundColor Yellow }"

echo.
echo  ========================================================
echo    ✅ INSTALACAO DO AGS %AGS_VER% CONCLUIDA!
echo  ========================================================
echo.
echo   O Assistente do AGS ja esta ativo nesta maquina.
echo   Pressione qualquer tecla para fechar esta janela e recarregar a Vercel.
echo.
pause
