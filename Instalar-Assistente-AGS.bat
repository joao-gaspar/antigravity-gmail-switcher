@echo off
chcp 65001 >nul
set AGS_VER=v2.7.0
title Assistente do AGS %AGS_VER% - Instalador Automatico
color 0A
cls
echo.
echo  ========================================================
echo    [AGS] ASSISTENTE DO AGS %AGS_VER% - CONFIGURACAO AUTOMATICA
echo  ========================================================
echo.
echo   Versao do Script: %AGS_VER% (Build 2026.08.31)
echo   Configurando o monitoramento do Antigravity nesta maquina...
echo   Por favor, aguarde alguns segundos.
echo.

set "DEST_DIR=%USERPROFILE%\.gemini\antigravity-ide\scratch\gmail-switcher"
set "SKILL_DIR=%USERPROFILE%\.gemini\config\skills\gmail-switcher"
set "STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"
if not exist "%SKILL_DIR%" mkdir "%SKILL_DIR%"

echo   [1/3] Baixando arquivos do assistente...
curl.exe -s -L --max-time 15 -o "%DEST_DIR%\server.py" "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main/server.py"
curl.exe -s -L --max-time 15 -o "%DEST_DIR%\database.py" "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main/database.py"

if not exist "%SKILL_DIR%\accounts.json" (
    curl.exe -s -L --max-time 15 -o "%SKILL_DIR%\accounts.json" "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main/accounts.json"
    if not exist "%SKILL_DIR%\accounts.json" (
        echo {"accounts":[]} > "%SKILL_DIR%\accounts.json"
    )
)

echo   [2/3] Localizando Python nesta maquina...
set PY_EXE=
if exist "%LOCALAPPDATA%\Programs\Python\Python312\pythonw.exe" set "PY_EXE=%LOCALAPPDATA%\Programs\Python\Python312\pythonw.exe"
if not defined PY_EXE if exist "%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe" set "PY_EXE=%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe"
if not defined PY_EXE if exist "%LOCALAPPDATA%\Programs\Python\Python310\pythonw.exe" set "PY_EXE=%LOCALAPPDATA%\Programs\Python\Python310\pythonw.exe"
if not defined PY_EXE if exist "%LOCALAPPDATA%\Programs\Python\Python39\pythonw.exe" set "PY_EXE=%LOCALAPPDATA%\Programs\Python\Python39\pythonw.exe"
if not defined PY_EXE if exist "%PROGRAMFILES%\Python312\pythonw.exe" set "PY_EXE=%PROGRAMFILES%\Python312\pythonw.exe"
if not defined PY_EXE if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PY_EXE=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not defined PY_EXE if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PY_EXE=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if not defined PY_EXE if exist "%APPDATA%\AGS\python\pythonw.exe" set "PY_EXE=%APPDATA%\AGS\python\pythonw.exe"

if not defined PY_EXE (
    where /q pythonw.exe
    if errorlevel 1 (
        where /q python.exe
        if errorlevel 1 (
            echo   [INFO] Python nao encontrado. Baixando Python Portable (10MB)...
            if not exist "%APPDATA%\AGS\python" mkdir "%APPDATA%\AGS\python"
            curl.exe -s -L --max-time 30 -o "%APPDATA%\AGS\python.zip" "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip"
            tar.exe -xf "%APPDATA%\AGS\python.zip" -C "%APPDATA%\AGS\python" >nul 2>&1
            del /f /q "%APPDATA%\AGS\python.zip" >nul 2>&1
            if exist "%APPDATA%\AGS\python\pythonw.exe" set "PY_EXE=%APPDATA%\AGS\python\pythonw.exe"
            if exist "%APPDATA%\AGS\python\python.exe" set "PY_EXE=%APPDATA%\AGS\python\python.exe"
        ) else (
            for /f "tokens=*" %%a in ('where python.exe') do set "PY_EXE=%%a" & goto :found_py
        )
    ) else (
        for /f "tokens=*" %%a in ('where pythonw.exe') do set "PY_EXE=%%a" & goto :found_py
    )
)
:found_py

echo   [OK] Python localizado: %PY_EXE%

echo   [3/3] Configurando autostart e iniciando servidor...
(
    echo @echo off
    echo start "" "%PY_EXE%" -u "%DEST_DIR%\server.py"
) > "%STARTUP_DIR%\start-ags.cmd"

:: Finalizar processos antigos e iniciar servidor limpo
taskkill /f /im python.exe /im pythonw.exe >nul 2>&1
ping 127.0.0.1 -n 2 >nul
start "" "%PY_EXE%" -u "%DEST_DIR%\server.py"
ping 127.0.0.1 -n 3 >nul

echo.
echo   Verificando status do servidor...
curl.exe -s -m 3 "http://127.0.0.1:8999/api/status" >nul 2>&1
if %errorlevel% equ 0 (
    color 0A
    echo   [OK] SERVIDOR ON na porta 8999!
) else (
    color 0E
    echo   [INFO] Servidor iniciando em segundo plano...
)

echo.
echo  ========================================================
echo    [OK] INSTALACAO DO AGS %AGS_VER% CONCLUIDA COM SUCESSO!
echo  ========================================================
echo.
echo   O Assistente do AGS ja esta ativo nesta maquina.
echo   Pressione qualquer tecla para fechar esta janela e recarregar a Vercel.
echo.
pause


