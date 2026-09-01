$procs = Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'language_server*' } | Sort-Object CreationDate -Descending
$netstat = netstat -ano 2>$null

foreach ($p in $procs) {
    $cl = $p.CommandLine
    $pidVal = $p.ProcessId
    Write-Host "Checking PID: $pidVal Date: $($p.CreationDate)"
    
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
                Write-Host "SUCCESS from PID $pidVal Port $port Email:" $parsed.userStatus.email
                $jsonStr | Out-File -FilePath "C:\Users\JoaoGaspar\.gemini\antigravity-ide\scratch\gmail-switcher\active_status_dump.json" -Encoding utf8
                break
            }
        } catch {
            Write-Host "Failed port $port : $($_.Exception.Message)"
        }
    }
}
