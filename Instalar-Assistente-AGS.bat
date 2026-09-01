@echo off
chcp 65001 >nul
set AGS_VER=v2.6.0
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

set AGS_LOCAL=%APPDATA%\AGS
if not exist "%AGS_LOCAL%" mkdir "%AGS_LOCAL%"

echo   [1/3] Preparando instalador...
set SETUP_FILE=%AGS_LOCAL%\setup.ps1

(
echo $OutputEncoding = [System.Text.Encoding]::UTF8
echo [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
echo $ErrorActionPreference = 'Continue'
echo $AGS_VERSION = "2.6.0"
echo Write-Host "`n[AGS] INICIANDO SETUP DO AGS v$AGS_VERSION" -ForegroundColor Cyan
echo.
echo $destDir = "$env:USERPROFILE\.gemini\antigravity-ide\scratch\gmail-switcher"
echo if (-not (Test-Path $destDir^)^) { New-Item -ItemType Directory -Force -Path $destDir ^| Out-Null }
echo $skillDir = "$env:USERPROFILE\.gemini\config\skills\gmail-switcher"
echo if (-not (Test-Path $skillDir^)^) { New-Item -ItemType Directory -Force -Path $skillDir ^| Out-Null }
echo.
echo $baseUrl = "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main"
echo $files = @("server.py", "database.py"^)
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
echo Write-Host "[INFO] Parando processos anteriores..." -ForegroundColor Yellow
echo Get-Process python*, wscript -ErrorAction SilentlyContinue ^| Stop-Process -Force -ErrorAction SilentlyContinue
echo Start-Sleep -Milliseconds 500
echo.
echo Write-Host "[INFO] Localizando instalacao do Python..." -ForegroundColor Yellow
echo $pyCandidates = @("$env:LOCALAPPDATA\Programs\Python\Python312\pythonw.exe","$env:LOCALAPPDATA\Programs\Python\Python311\pythonw.exe","$env:LOCALAPPDATA\Programs\Python\Python310\pythonw.exe","$env:LOCALAPPDATA\Programs\Python\Python39\pythonw.exe","$env:LOCALAPPDATA\Programs\Python\Python38\pythonw.exe","$env:PROGRAMFILES\Python312\pythonw.exe","$env:PROGRAMFILES\Python311\pythonw.exe","$env:LOCALAPPDATA\Programs\Python\Python312\python.exe","$env:LOCALAPPDATA\Programs\Python\Python311\python.exe","$env:LOCALAPPDATA\Programs\Python\Python310\python.exe","$env:LOCALAPPDATA\Programs\Python\Python39\python.exe","$env:LOCALAPPDATA\Programs\Python\Python38\python.exe","$env:PROGRAMFILES\Python312\python.exe","$env:PROGRAMFILES\Python311\python.exe"^)
echo $pyExe = $null
echo foreach ($p in $pyCandidates^) { if (Test-Path $p^) { $pyExe = $p; break } }
echo if (-not $pyExe^) {
echo     try { $found = (Get-Command pythonw -ErrorAction Stop^).Source; if ($found^) { $pyExe = $found } } catch {}
echo }
echo if (-not $pyExe^) {
echo     try { $found = (Get-Command python -ErrorAction Stop^).Source; if ($found^) { $pyExe = $found } } catch {}
echo }
echo if (-not $pyExe^) { $pyExe = "pythonw.exe" }
echo Write-Host "[OK] Executavel Python: $pyExe" -ForegroundColor Green
echo.
echo Write-Host "[INFO] Configurando inicializacao automatica do Windows..." -ForegroundColor Yellow
echo try {
echo     $sf = [Environment]::GetFolderPath("Startup"^)
echo     if ($sf -and (Test-Path $sf^)^) {
echo         $cmdContent = "@echo off`r`nstart /min `"`" `"$pyExe`" -u `"$destDir\server.py`""
echo         $cmdContent ^| Out-File -FilePath "$sf\start-ags.cmd" -Encoding utf8 -Force
echo         Write-Host "[OK] Adicionado a pasta Startup ($sf\start-ags.cmd^)" -ForegroundColor Green
echo     }
echo } catch {}
echo.
echo Write-Host "[INFO] Iniciando servidor em segundo plano..." -ForegroundColor Cyan
echo Start-Process -FilePath $pyExe -ArgumentList "-u `"$destDir\server.py`"" -WorkingDirectory $destDir -WindowStyle Hidden
echo Start-Sleep -Seconds 3
echo.
echo Write-Host "[INFO] Verificando conexao com o servidor..." -ForegroundColor Cyan
echo $ports = @(8999, 8998, 8997, 8996, 8995, 8000^)
echo $online = $false
echo foreach ($p in $ports^) {
echo     try {
echo         $res = Invoke-RestMethod -Uri "http://127.0.0.1:$p/api/status" -TimeoutSec 2
echo         Write-Host "[OK] SERVIDOR ON na porta $p - Hostname: $($res.machine.hostname)" -ForegroundColor Green
echo         $online = $true
echo         break
echo     } catch {}
echo }
echo if (-not $online^) {
echo     Write-Host "[INFO] Servidor iniciando em segundo plano. Recarregue a pagina na Vercel." -ForegroundColor Yellow
echo }
) > "%SETUP_FILE%"

echo   [2/3] Executando instalador...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SETUP_FILE%"

echo.
echo   [3/3] Checando status final...
powershell -NoProfile -Command "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; $ports=@(8999,8998,8997,8996,8995,8000); $ok=$false; foreach($p in $ports){try{$r=Invoke-RestMethod -Uri ('http://127.0.0.1:'+$p+'/api/status') -TimeoutSec 2; Write-Host '   [OK] SERVIDOR ON na porta '$p': Hostname '$r.machine.hostname -ForegroundColor Green; $ok=$true; break}catch{}}; if(-not $ok){Write-Host '   [INFO] Servidor iniciando em segundo plano...' -ForegroundColor Yellow}"

echo.
echo  ========================================================
echo    [OK] INSTALACAO DO AGS %AGS_VER% CONCLUIDA COM SUCESSO!
echo  ========================================================
echo.
echo   O Assistente do AGS ja esta ativo nesta maquina.
echo   Pressione qualquer tecla para fechar esta janela e recarregar a Vercel.
echo.
pause
