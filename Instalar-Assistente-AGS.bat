@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
set AGS_VER=v2.8.0
title Assistente do AGS %AGS_VER%
color 0A
cls
echo.
echo  ========================================================
echo    [AGS] ASSISTENTE DO AGS %AGS_VER% - CONFIGURACAO
echo  ========================================================
echo.
echo   Versao do Script: %AGS_VER% (Build 2026.09.01)
echo   Configurando o monitoramento do Antigravity nesta maquina...
echo   Por favor, aguarde alguns segundos.
echo.

set "DEST_DIR=%USERPROFILE%\.gemini\antigravity-ide\scratch\gmail-switcher"
set "SKILL_DIR=%USERPROFILE%\.gemini\config\skills\gmail-switcher"

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
    if not errorlevel 1 (
        for /f "tokens=*" %%a in ('where pythonw.exe') do set "PY_EXE=%%a" & goto :found_py
    )
    where /q python.exe
    if not errorlevel 1 (
        for /f "tokens=*" %%a in ('where python.exe') do set "PY_EXE=%%a" & goto :found_py
    )
    echo   [INFO] Python nao encontrado. Baixando Python Portable (10MB)...
    if not exist "%APPDATA%\AGS\python" mkdir "%APPDATA%\AGS\python"
    curl.exe -s -L --max-time 60 -o "%APPDATA%\AGS\python.zip" "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip"
    tar.exe -xf "%APPDATA%\AGS\python.zip" -C "%APPDATA%\AGS\python" >nul 2>&1
    del /f /q "%APPDATA%\AGS\python.zip" >nul 2>&1
    if exist "%APPDATA%\AGS\python\pythonw.exe" set "PY_EXE=%APPDATA%\AGS\python\pythonw.exe"
    if exist "%APPDATA%\AGS\python\python.exe" set "PY_EXE=%APPDATA%\AGS\python\python.exe"
)
:found_py

if not defined PY_EXE (
    color 0C
    echo.
    echo   [ERRO] Nao foi possivel encontrar ou instalar o Python.
    echo   Instale o Python manualmente em https://www.python.org e rode este bat novamente.
    pause
    exit /b 1
)

echo   [OK] Python localizado: %PY_EXE%

echo   [3/3] Encerrando instancia anterior do servidor (somente server.py)...
:: Mata apenas processos python que estejam rodando server.py especificamente
powershell -NoProfile -Command "Get-WmiObject Win32_Process | Where-Object { ($_.Name -like 'python*') -and ($_.CommandLine -like '*server.py*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
ping 127.0.0.1 -n 2 >nul

echo   Iniciando servidor AGS em segundo plano...
:: Inicia sem registrar Startup - roda somente durante esta sessao
start "" "%PY_EXE%" -u "%DEST_DIR%\server.py"
ping 127.0.0.1 -n 4 >nul

echo.
echo   Verificando status do servidor...
set PORTA_ATIVA=
for %%P in (8000 8999 8998 8997 8996 8995) do (
    if not defined PORTA_ATIVA (
        curl.exe -s -m 2 "http://127.0.0.1:%%P/api/status" >nul 2>&1
        if !errorlevel! equ 0 set "PORTA_ATIVA=%%P"
    )
)

if defined PORTA_ATIVA (
    color 0A
    echo   [OK] SERVIDOR ATIVO na porta %PORTA_ATIVA%!
) else (
    color 0E
    echo   [INFO] Servidor iniciando em segundo plano.
    echo   Aguarde alguns segundos e recarregue a pagina da Vercel.
)

echo.
echo  ========================================================
echo    [AGS] CONFIGURACAO CONCLUIDA - %AGS_VER%
echo  ========================================================
echo.
echo   Para manter o servidor ativo apos fechar esta janela,
echo   abra o terminal do Antigravity IDE (Ctrl+Til) e rode:
echo   python -u "%DEST_DIR%\server.py"
echo.
pause
