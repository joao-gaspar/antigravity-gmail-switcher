# AGS (Antigravity Gmail Switcher) Auto-Setup Script for Windows
$ErrorActionPreference = "Stop"

$AGS_VERSION = "2.4.0"
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " 🚀 INICIANDO AUTO-SETUP DO AGS v$AGS_VERSION" -ForegroundColor Cyan
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

Write-Host "`n⚙️ Configurando Agendador de Tarefas do Windows..." -ForegroundColor Cyan
$taskName = "AntigravityServerWatchdog"
$vbsPath = "$destDir\start-server.vbs"

# Kill existing python server / wscript if running
Get-Process python*, wscript -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

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

Write-Host "`n▶️ Iniciando serviço de monitoramento..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 4

try {
    $res = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/status" -TimeoutSec 3
    Write-Host "`n========================================================" -ForegroundColor Green
    Write-Host " ✅ SUCESSO! Monitor AGS rodando em '$($res.machine.hostname)'" -ForegroundColor Green
    Write-Host "========================================================`n" -ForegroundColor Green
} catch {
    Write-Host "`n⚠️ Servidor em inicialização. Recarregue o painel no Vercel." -ForegroundColor Yellow
}
