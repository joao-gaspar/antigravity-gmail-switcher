$appData = $env:APPDATA
$vscdb = "$appData\Antigravity IDE\User\globalStorage\state.vscdb"

if (Test-Path $vscdb) {
    $fs = [System.IO.File]::Open($vscdb, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $reader = New-Object System.IO.StreamReader($fs)
    $str = $reader.ReadToEnd()
    $reader.Close()
    $fs.Close()

    $matches = [regex]::Matches($str, '[\w\.-]+@[\w\.-]+\.\w+')
    $emails = @{}
    foreach ($m in $matches) {
        $emails[$m.Value] = $true
    }
    Write-Host "Found emails in state.vscdb:"
    $emails.Keys | Write-Host
}
