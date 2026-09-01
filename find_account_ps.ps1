$appData = $env:APPDATA
$vscdb = "$appData\Antigravity IDE\User\globalStorage\state.vscdb"
$storage = "$appData\Antigravity IDE\User\globalStorage\storage.json"

Write-Host "Checking storage.json..."
if (Test-Path $storage) {
    Get-Content $storage -Raw | Select-String -Pattern "email|user|totalcad|aluno" | Write-Host
}

Write-Host "Checking state.vscdb..."
if (Test-Path $vscdb) {
    $bytes = [System.IO.File]::ReadAllBytes($vscdb)
    $str = [System.Text.Encoding]::UTF8.GetString($bytes)
    $matches = [regex]::Matches($str, '[\w\.-]+@[\w\.-]+\.\w+')
    foreach ($m in $matches) {
        Write-Host "Found email in state.vscdb:" $m.Value
    }
}
