# AGS (Antigravity Gmail Switcher) Auto-Setup Script for Windows
$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$AGS_VERSION = "2.4.6"
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " [AGS] INICIANDO AUTO-SETUP DO AGS v$AGS_VERSION" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$destDir = "$env:USERPROFILE\.gemini\antigravity-ide\scratch\gmail-switcher"
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
}

$skillDir = "$env:USERPROFILE\.gemini\config\skills\gmail-switcher"
if (-not (Test-Path $skillDir)) {
    New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
}

$baseUrl = "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main"
$files = @("server.py", "database.py", "start-server.vbs")

foreach ($file in $files) {
    Write-Host "  ↳ Baixando $file..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "$baseUrl/$file" -OutFile "$destDir\$file" -UseBasicParsing
}

# Download initial accounts.json if not present
if (-not (Test-Path "$skillDir\accounts.json")) {
    Write-Host "  ↳ Criando pool inicial de contas em accounts.json..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main/accounts.json" -OutFile "$skillDir\accounts.json" -UseBasicParsing
    } catch {
        # Fallback empty accounts pool
        '{"accounts":[]}' | Out-File -FilePath "$skillDir\accounts.json" -Encoding utf8
    }
}

Write-Host "`n[INFO] Configurando inicializacao automatica..." -ForegroundColor Cyan
$taskName = "AntigravityServerWatchdog"
$vbsPath = "$destDir\start-server.vbs"

# Stop existing processes
Get-Process python*, wscript -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# 1. Try Windows Scheduled Task (catch permission denied for non-admin users)
$scheduledTaskOk = $false
try {
    $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable:$false
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    $scheduledTaskOk = $true
} catch {
    Write-Host "  [INFO] Usando pasta de Inicializacao do Windows (sem necessidade de Admin)..." -ForegroundColor Yellow
}

# 2. Always add fallback to Windows Startup Folder (shell:startup)
try {
    $startupFolder = [Environment]::GetFolderPath("Startup")
    if ($startupFolder -and (Test-Path $startupFolder)) {
        Copy-Item -Path "$vbsPath" -Destination "$startupFolder\start-server.vbs" -Force -ErrorAction SilentlyContinue
    }
} catch {}

# 3. Directly launch server right now
Write-Host "`n[INFO] Iniciando servico de monitoramento..." -ForegroundColor Cyan
if ($scheduledTaskOk) {
    try { Start-ScheduledTask -TaskName $taskName } catch {}
}
Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`"" -WindowStyle Hidden
Start-Sleep -Seconds 2

# Check status
try {
    $res = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/status" -TimeoutSec 3
    Write-Host "`n========================================================" -ForegroundColor Green
    Write-Host " [OK] SUCESSO! Monitor AGS rodando em '$($res.machine.hostname)'" -ForegroundColor Green
    Write-Host "========================================================`n" -ForegroundColor Green
} catch {
    # Fallback: locate python.exe and launch server directly
    $py = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Source }
    if (-not $py) { $py = (Get-Item "$env:LOCALAPPDATA\Programs\Python\Python*\python.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
    if (-not $py) { $py = "python.exe" }
    
    Start-Process -FilePath $py -ArgumentList "-u server.py" -WorkingDirectory $destDir -WindowStyle Hidden
    Start-Sleep -Seconds 2
    try {
        $res2 = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/status" -TimeoutSec 3
        Write-Host "`n========================================================" -ForegroundColor Green
        Write-Host " [OK] SUCESSO! Monitor AGS rodando em '$($res2.machine.hostname)'" -ForegroundColor Green
        Write-Host "========================================================`n" -ForegroundColor Green
    } catch {
        Write-Host "`n[INFO] Servidor em inicializacao. Recarregue o painel no Vercel." -ForegroundColor Yellow
    }
}
