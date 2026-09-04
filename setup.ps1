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

Write-Host "  ↳ Sincronizando scripts..." -ForegroundColor Yellow
Invoke-WebRequest -Uri "$baseUrl/server.ps1" -OutFile "$destDir\scripts\server.ps1" -UseBasicParsing
Invoke-WebRequest -Uri "$baseUrl/gmail-switcher.ps1" -OutFile "$destDir\scripts\gmail-switcher.ps1" -UseBasicParsing
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

# Always restart server.ps1 to ensure the newest code is running
Write-Host "  ↳ Reiniciando servidor local com o código atualizado..." -ForegroundColor Yellow
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
    ($_.CommandLine -like "*server.ps1*") -and $_.Id -ne $PID
} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$destDir\scripts\server.ps1`"" -WindowStyle Hidden


# Perform immediate initial check & telemetry sync to Vercel
Write-Host "  ↳ Transmitindo conta ativa e cotas do $env:COMPUTERNAME..." -ForegroundColor Green
powershell -ExecutionPolicy Bypass -File "$destDir\scripts\gmail-switcher.ps1" check

Write-Host "`n[SUCESSO] Computador $env:COMPUTERNAME conectado ao painel web!" -ForegroundColor Green
Write-Host "Abrindo switcher..." -ForegroundColor Cyan
Start-Process "https://antigravity-gmail-switcher.vercel.app/?machine=mac-$($env:COMPUTERNAME.ToLower())"
