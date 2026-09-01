@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
set AGS_VER=v4.0.0
set "SELF=%~f0"
title Assistente do AGS %AGS_VER%
color 0A
cls
echo.
echo  ========================================================
echo    [AGS] ASSISTENTE DO AGS %AGS_VER% - CONFIGURACAO NATIVA
echo  ========================================================
echo.

:: --- AUTO-UPDATE -----------------------------------------------------------
if "%~1"=="--updated" goto :skip_update
echo   Verificando atualizacoes...
set "TMP_UPD=%TEMP%\ags_upd_%RANDOM%.bat"
curl.exe -s -L --max-time 10 -o "%TMP_UPD%" "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main/Instalar-Assistente-AGS.bat"
if exist "%TMP_UPD%" (
    set "REMOTE_VER="
    for /f "tokens=2 delims==" %%v in ('findstr /i "^set AGS_VER=" "%TMP_UPD%"') do set "REMOTE_VER=%%v"
    if defined REMOTE_VER (
        if "!REMOTE_VER!" neq "%AGS_VER%" (
            echo   Atualizando de %AGS_VER% para !REMOTE_VER!...
            copy /y "%TMP_UPD%" "%SELF%" >nul 2>&1
            del /f /q "%TMP_UPD%" >nul 2>&1
            start "" "%SELF%" --updated
            exit /b 0
        )
    )
    del /f /q "%TMP_UPD%" >nul 2>&1
)
:skip_update
:: --- FIM AUTO-UPDATE -------------------------------------------------------

cls
echo.
echo  ========================================================
echo    [AGS] ASSISTENTE DO AGS %AGS_VER% - CONFIGURACAO NATIVA
echo  ========================================================
echo.
echo   Versao do Script: %AGS_VER% (Build 2026.09.01)
echo   Configurando o monitoramento nativo (PowerShell) nesta maquina...
echo.

set "DEST_DIR=%USERPROFILE%\.gemini\antigravity-ide\scratch\gmail-switcher"
set "SKILL_DIR=%USERPROFILE%\.gemini\config\skills\gmail-switcher"

if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"
if not exist "%SKILL_DIR%" mkdir "%SKILL_DIR%"

echo   [1/2] Baixando assistente nativo (PowerShell)...
curl.exe -s -L --max-time 15 -o "%DEST_DIR%\server.ps1" "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main/server.ps1"

if not exist "%SKILL_DIR%\accounts.json" (
    curl.exe -s -L --max-time 15 -o "%SKILL_DIR%\accounts.json" "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main/accounts.json"
)

echo   [2/2] Encerrando servidor anterior e iniciando assistente nativo...
powershell -NoProfile -Command "Get-WmiObject Win32_Process | Where-Object { ($_.Name -like 'powershell*') -and ($_.CommandLine -like '*server.ps1*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
ping 127.0.0.1 -n 2 >nul

start /b powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%DEST_DIR%\server.ps1"
ping 127.0.0.1 -n 3 >nul

echo.
echo   Verificando status do servidor nativo...
set "PORTA_ATIVA="
for %%P in (8000 8999 8998 8997 8996 8995) do (
    if not defined PORTA_ATIVA (
        curl.exe -s -m 2 "http://127.0.0.1:%%P/api/status" >nul 2>&1
        if !errorlevel! equ 0 set "PORTA_ATIVA=%%P"
    )
)

if defined PORTA_ATIVA (
    color 0A
    echo   [OK] ASSISTENTE NATIVO ATIVO na porta %PORTA_ATIVA%!
) else (
    color 0E
    echo   [INFO] Assistente iniciando em segundo plano...
    echo   Aguarde alguns segundos e recarregue a pagina da Vercel.
)

echo.
echo  ========================================================
echo    [AGS] CONFIGURACAO NATIVA CONCLUIDA COM SUCESSO!
echo  ========================================================
echo.
echo   O Assistente NATIVO (PowerShell) esta rodando em segundo plano.
echo   Pressione qualquer tecla para fechar esta janela.
echo.
pause
