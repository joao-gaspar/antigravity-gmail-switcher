# AGS (Antigravity Gmail Switcher) Native Auto-Setup for Windows
$ErrorActionPreference = "SilentlyContinue"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " [AGS] CONECTANDO NOVO COMPUTADOR AO ANTIGRAVITY" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$destDir = "$env:USERPROFILE\.gemini\config\skills\gmail-switcher"
if (-not (Test-Path "$destDir\scripts")) {
    New-Item -ItemType Directory -Force -Path "$destDir\scripts" | Out-Null
}

$baseUrl = "https://raw.githubusercontent.com/joao-gaspar/antigravity-gmail-switcher/main"

Write-Host "  ↳ Sincronizando scripts e interface nativa..." -ForegroundColor Yellow
Invoke-WebRequest -Uri "$baseUrl/server.ps1" -OutFile "$destDir\scripts\server.ps1" -UseBasicParsing
Invoke-WebRequest -Uri "$baseUrl/gmail-switcher.ps1" -OutFile "$destDir\scripts\gmail-switcher.ps1" -UseBasicParsing
Invoke-WebRequest -Uri "$baseUrl/index.html" -OutFile "$destDir\index.html" -UseBasicParsing
Invoke-WebRequest -Uri "$baseUrl/app.js" -OutFile "$destDir\app.js" -UseBasicParsing
Invoke-WebRequest -Uri "$baseUrl/styles.css" -OutFile "$destDir\styles.css" -UseBasicParsing
if (-not (Test-Path "$destDir\accounts.json")) {
    Invoke-WebRequest -Uri "$baseUrl/accounts.json" -OutFile "$destDir\accounts.json" -UseBasicParsing
}

# Install global hooks.json so the check fires in ANY workspace automatically
Write-Host "  ↳ Instalando hook global do Antigravity..." -ForegroundColor Yellow
$hooksJson = @"
{
  "gmail-switcher-autostart": {
    "enabled": true,
    "PreInvocation": [
      {
        "type": "command",
        "command": "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.gemini\\config\\skills\\gmail-switcher\\scripts\\gmail-switcher.ps1\" check"
      }
    ]
  }
}
"@
$hooksJson | Out-File -FilePath "$env:USERPROFILE\.gemini\config\hooks.json" -Encoding utf8 -Force

# Kill any process currently holding port 8000 (PS 5.1 compatible — CommandLine not available on Get-Process)
Write-Host "  ↳ Reiniciando servidor local com o código atualizado..." -ForegroundColor Yellow
try {
    $conns = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
    foreach ($conn in $conns) {
        $ownerPid = $conn.OwningProcess
        if ($ownerPid -and $ownerPid -ne $PID) {
            Stop-Process -Id $ownerPid -Force -ErrorAction SilentlyContinue
        }
    }
} catch {}
# Also kill via netstat fallback
try {
    $lines = netstat -ano 2>$null
    foreach ($line in $lines) {
        if ($line -match "TCP\s+\S+:8000\s+\S+\s+LISTENING\s+(\d+)\s*$") {
            $ownerPid = [int]$Matches[1]
            if ($ownerPid -ne $PID) { Stop-Process -Id $ownerPid -Force -ErrorAction SilentlyContinue }
        }
    }
} catch {}
Start-Sleep -Milliseconds 800

Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$destDir\scripts\server.ps1`"" -WindowStyle Hidden
Start-Sleep -Seconds 2


# Perform immediate initial check & telemetry sync to Vercel
Write-Host "  ↳ Transmitindo conta ativa e cotas do $env:COMPUTERNAME..." -ForegroundColor Green
powershell -ExecutionPolicy Bypass -File "$destDir\scripts\gmail-switcher.ps1" check

Write-Host "`n[SUCESSO] Computador $env:COMPUTERNAME conectado ao painel local!" -ForegroundColor Green
Write-Host "Abrindo switcher local em http://localhost:8000..." -ForegroundColor Cyan
Start-Process "http://localhost:8000"
