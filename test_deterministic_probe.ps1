$lsProcs = Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'language_server*' }
$ideProcs = Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Antigravity IDE*' -or $_.Name -like 'code*' } | Sort-Object CreationDate -Descending

Write-Host "Latest Antigravity IDE Process PID:" $ideProcs[0].ProcessId "Created:" $ideProcs[0].CreationDate

# Filter language_server processes that are children of the latest IDE instance OR sort by CreationDate descending
$sortedLs = $lsProcs | Sort-Object @{Expression={
    if ($_.ParentProcessId -eq $ideProcs[0].ProcessId) { 0 } else { 1 }
}}, @{Expression={$_.CreationDate}; Descending=$true}

$netstat = netstat -ano 2>$null

foreach ($p in $sortedLs) {
    $cl = $p.CommandLine
    $pidVal = $p.ProcessId
    Write-Host "`nTesting LS PID $pidVal (Parent: $($p.ParentProcessId), Date: $($p.CreationDate))"
    
    $m = [regex]::Match($cl, '--csrf_token[=\s]+([\w-]+)')
    if (-not $m.Success) { continue }
    $csrf = $m.Groups[1].Value

    $listeningPorts = @()
    foreach ($line in ($netstat -split "\r?\n")) {
        if ($line -like "*LISTENING*" -and $line.Trim().EndsWith($pidVal.ToString())) {
            $pm = [regex]::Match($line, '127\.0\.0\.1:(\d+)')
            if ($pm.Success) {
                $listeningPorts += [int]$pm.Groups[1].Value
            }
        }
    }

    foreach ($port in $listeningPorts) {
        try {
            $url = "https://127.0.0.1:$port/exa.language_server_pb.LanguageServerService/GetUserStatus"
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            $req = [System.Net.HttpWebRequest]::Create($url)
            $req.Method = "POST"
            $req.Headers.Add("x-codeium-csrf-token", $csrf)
            $req.ContentType = "application/json"
            $req.Timeout = 2000
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes("{}")
            $req.ContentLength = $bodyBytes.Length
            $st = $req.GetRequestStream()
            $st.Write($bodyBytes, 0, $bodyBytes.Length)
            $st.Close()

            $resp = $req.GetResponse()
            $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $jsonStr = $reader.ReadToEnd()
            $reader.Close()
            $resp.Close()

            $parsed = $jsonStr | ConvertFrom-Json
            if ($parsed.userStatus) {
                $em = $null
                $us = $parsed.userStatus
                if ($us.email) { $em = $us.email }
                elseif ($us.user -and $us.user.email) { $em = $us.user.email }
                elseif ($us.userInfo -and $us.userInfo.email) { $em = $us.userInfo.email }
                
                Write-Host "DETERMINISTIC RESULT -> PID $pidVal Port $port Email: $em"
                break
            }
        } catch {
            Write-Host "Port $port failed: $($_.Exception.Message)"
        }
    }
}
