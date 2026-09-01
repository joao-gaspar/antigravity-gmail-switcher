@echo off
chcp 65001 >nul
set AGS_VER=v2.5.2
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

:: Create local dir for AGS
set AGS_LOCAL=%APPDATA%\AGS
if not exist "%AGS_LOCAL%" mkdir "%AGS_LOCAL%"

echo   [1/3] Preparando instalador...
set SETUP_FILE=%AGS_LOCAL%\setup.ps1
set LOG_FILE=%AGS_LOCAL%\install.log

(
echo $OutputEncoding = [System.Text.Encoding]::UTF8
echo [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
echo $ErrorActionPreference = 'Continue'
echo $AGS_VERSION = "2.5.2"
echo Write-Host "`n[AGS] INICIANDO SETUP DO AGS v$AGS_VERSION" -ForegroundColor Cyan
echo.
echo $destDir = "$env:USERPROFILE\.gemini\antigravity-ide\scratch\gmail-switcher"
echo if (-not (Test-Path $destDir^)^) { New-Item -ItemType Directory -Force -Path $destDir ^| Out-Null }
echo $skillDir = "$env:USERPROFILE\.gemini\config\skills\gmail-switcher"
echo if (-not (Test-Path $skillDir^)^) { New-Item -ItemType Directory -Force -Path $skillDir ^| Out-Null }
echo.
echo $baseUrl = "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main"
echo $files = @("server.py", "database.py", "start-server.vbs"^)
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
echo foreach ($file in $files^) {
echo     Write-Host "  Baixando $file..." -ForegroundColor Yellow
echo     $dest = "$destDir\$file"
echo     $url  = "$baseUrl/$file"
echo     $ok   = $false
echo     try { curl.exe -s -L --max-time 20 --retry 2 -o $dest $url; if (Test-Path $dest^) { $ok = $true } } catch {}
echo     if (-not $ok^) {
echo         try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 20 -EA Stop; $ok = $true } catch {}
echo     }
echo     if (-not $ok^) { Write-Host "  [AVISO] Falha ao baixar $file" -ForegroundColor Red }
echo }
echo.
echo if (-not (Test-Path "$skillDir\accounts.json"^)^) {
echo     $aUrl = "$baseUrl/accounts.json"
echo     try { curl.exe -s -L --max-time 20 -o "$skillDir\accounts.json" $aUrl } catch {}
echo     if (-not (Test-Path "$skillDir\accounts.json"^)^) { '{"accounts":[]}' ^| Out-File -FilePath "$skillDir\accounts.json" -Encoding utf8 }
echo }
echo.
echo $taskName = "AntigravityServerWatchdog"
echo $vbsPath = "$destDir\start-server.vbs"
echo Write-Host "[INFO] Parando processos anteriores..." -ForegroundColor Yellow
echo Get-Process python*, wscript -ErrorAction SilentlyContinue ^| Stop-Process -Force -ErrorAction SilentlyContinue
echo Start-Sleep -Milliseconds 500
echo.
echo Write-Host "[INFO] Configurando inicializacao automatica na pasta Startup..." -ForegroundColor Yellow
echo try {
echo     $sf = [Environment]::GetFolderPath("Startup"^)
echo     if ($sf -and (Test-Path $sf^)^) {
echo         Copy-Item "$vbsPath" "$sf\start-server.vbs" -Force -ErrorAction SilentlyContinue
echo         Write-Host "[OK] Adicionado a inicializacao do Windows." -ForegroundColor Green
echo     }
echo } catch {}
echo.
echo Write-Host "[INFO] Iniciando watchdog VBS..." -ForegroundColor Cyan
echo Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`"" -WindowStyle Hidden
echo Write-Host "[INFO] Aguardando servidor iniciar..." -ForegroundColor Cyan
echo Start-Sleep -Seconds 4
echo.
echo Write-Host "[INFO] Checando servidor..." -ForegroundColor Cyan
echo try {
echo     $res = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/status" -TimeoutSec 3
echo     Write-Host "[OK] Servidor ON: $($res.machine.hostname)" -ForegroundColor Green
echo } catch {
echo     Write-Host "[INFO] Watchdog ainda iniciando, tentando Python direto..." -ForegroundColor Yellow
echo     $pyCandidates = @("$env:LOCALAPPDATA\Programs\Python\Python312\python.exe","$env:LOCALAPPDATA\Programs\Python\Python311\python.exe","$env:LOCALAPPDATA\Programs\Python\Python310\python.exe","$env:LOCALAPPDATA\Programs\Python\Python39\python.exe","$env:LOCALAPPDATA\Programs\Python\Python38\python.exe","$env:PROGRAMFILES\Python312\python.exe","$env:PROGRAMFILES\Python311\python.exe"^)
echo     $py = $null
echo     foreach ($p in $pyCandidates^) { if (Test-Path $p^) { $py = $p; break } }
echo     if ($py^) {
echo         Write-Host "[INFO] Python encontrado: $py" -ForegroundColor Yellow
echo         Start-Process -FilePath $py -ArgumentList "-u `"$destDir\server.py`"" -WorkingDirectory $destDir -WindowStyle Hidden
echo         Start-Sleep -Seconds 3
echo         try {
echo             $res2 = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/status" -TimeoutSec 3
echo             Write-Host "[OK] Servidor ON: $($res2.machine.hostname)" -ForegroundColor Green
echo         } catch { Write-Host "[INFO] Servidor em segundo plano. Recarregue o Vercel." -ForegroundColor Yellow }
echo     } else {
echo         Write-Host "[AVISO] Python nao encontrado. Instale o Python em python.org e rode novamente." -ForegroundColor Red
echo     }
echo }
) > "%SETUP_FILE%"

echo   [2/3] Executando instalador (Log em %LOG_FILE%)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SETUP_FILE%" 2>&1 | powershell -NoProfile -Command "Tee-Object -FilePath '%LOG_FILE%'"

echo.
echo   [3/3] Verificando servidor...
powershell -NoProfile -Command "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; try{$r=Invoke-RestMethod -Uri 'http://127.0.0.1:8000/api/status' -TimeoutSec 3;Write-Host '   [OK] SERVIDOR ON: '$r.machine.hostname -ForegroundColor Green}catch{Write-Host '   [INFO] Servidor em segundo plano...' -ForegroundColor Yellow}"

echo.
echo  ========================================================
echo    [OK] CONCLUIDO! LOG SALVO EM: %LOG_FILE%
echo  ========================================================
echo.
echo   Pressione QUALQUER TECLA para fechar esta janela.
echo.
pause >nul

