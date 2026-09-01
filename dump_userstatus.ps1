$procs = Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'language_server*' } | Sort-Object CreationDate -Descending
$netstat = netstat -ano 2>$null

foreach ($p in $procs) {
    $cl = $p.CommandLine
    $pidVal = $p.ProcessId
    if (-not $cl) { continue }

    $m = [regex]::Match($cl, '--csrf_token[=\s]+([\w-]+)')
    if (-not $m.Success) { continue }
    $csrf = $m.Groups[1].Value
    Write-Host "=== PID $pidVal csrf=$csrf ==="

    $listeningPorts = @()
    foreach ($line in ($netstat -split "\r?\n")) {
        if ($line -like "*LISTENING*" -and $line.Trim().EndsWith($pidVal.ToString())) {
            $pm = [regex]::Match($line, '127\.0\.0\.1:(\d+)')
            if ($pm.Success) { $listeningPorts += [int]$pm.Groups[1].Value }
        }
    }
    Write-Host "Ports: $($listeningPorts -join ', ')"

    foreach ($port in $listeningPorts) {
        try {
            $url = "https://127.0.0.1:$port/exa.language_server_pb.LanguageServerService/GetUserStatus"
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            $req = [System.Net.HttpWebRequest]::Create($url)
            $req.Method = "POST"
            $req.Headers.Add("x-codeium-csrf-token", $csrf)
            $req.ContentType = "application/json"
            $req.Timeout = 3000
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

            Write-Host "--- Response from Port $port ---"
            Write-Host $jsonStr
            $jsonStr | Out-File -FilePath "$PSScriptRoot\debug_userstatus.json" -Encoding utf8
            Write-Host "Saved to debug_userstatus.json"
            break
        } catch {
            Write-Host "Port $port failed: $($_.Exception.Message)"
        }
    }
}
