# AGS (Antigravity Gmail Switcher) Auto-Setup Script for Windows
$ErrorActionPreference = "Stop"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " 🚀 INICIANDO AUTO-SETUP DO AGS (GMAIL SWITCHER)" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$destDir = "$env:USERPROFILE\.gemini\antigravity-ide\scratch\gmail-switcher"
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
}

$baseUrl = "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main"
$files = @("server.py", "database.py", "start-server.vbs")

foreach ($file in $files) {
    Write-Host "  ↳ Baixando $file..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "$baseUrl/$file" -OutFile "$destDir\$file" -UseBasicParsing
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
    $res = Invoke-RestMethod -Uri "http://localhost:8000/api/status" -TimeoutSec 3
    Write-Host "`n========================================================" -ForegroundColor Green
    Write-Host " ✅ SUCESSO! Monitor AGS rodando em '$($res.machine.hostname)'" -ForegroundColor Green
    Write-Host "========================================================`n" -ForegroundColor Green
} catch {
    Write-Host "`n⚠️ Servidor em inicialização. Recarregue o painel no Vercel." -ForegroundColor Yellow
}
