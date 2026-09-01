#Requires -Version 5.1
$ErrorActionPreference = "SilentlyContinue"

# Determine candidate ports
$ports = @(8000, 8999, 8998, 8997, 8996, 8995)
$listener = $null
$activePort = 0

foreach ($p in $ports) {
    try {
        $l = New-Object System.Net.HttpListener
        $l.Prefixes.Add("http://127.0.0.1:$p/")
        $l.Start()
        $listener = $l
        $activePort = $p
        break
    } catch {
        if ($l) { $l.Close() }
    }
}

if (-not $listener) {
    Write-Host "CRITICAL: Could not bind HttpListener to any candidate port."
    exit 1
}

Write-Host "AGS Server running on http://127.0.0.1:$activePort/"

# Helper for probing LanguageServer
function Get-LanguageServerStatus {
    try {
        $procs = Get-CimInstance Win32_Process -Filter "name LIKE 'language_server%'" | Select-Object ProcessId, CommandLine
        if (-not $procs) { return $null }

        $netstat = netstat -ano 2>$null

        foreach ($p in $procs) {
            $cl = $p.CommandLine
            $pidVal = $p.ProcessId
            if (-not $cl -or $cl.Contains("--enable_lsp")) { continue }

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
                        return @{
                            userStatus = $parsed.userStatus
                            port = $port
                            pid = $pidVal
                        }
                    }
                } catch {}
            }
        }
    } catch {}
    return $null
}

# Main loop
while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $response.Headers.Add("Access-Control-Allow-Origin", "*")
        $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $response.Headers.Add("Access-Control-Allow-Headers", "*")

        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.Close()
            continue
        }

        $path = $request.Url.AbsolutePath
        $buffer = [byte[]]@()

        if ($path -eq "/api/status" -or $path -eq "/api/live") {
            $statusObj = Get-LanguageServerStatus

            $agentEmail = $null
            $agentName = $null
            $modelQuotas = @{}

            if ($statusObj -and $statusObj.userStatus) {
                $us = $statusObj.userStatus
                if ($us.email) {
                    $agentEmail = [string]$us.email
                } elseif ($us.user -and $us.user.email) {
                    $agentEmail = [string]$us.user.email
                }

                if ($us.name) {
                    $agentName = [string]$us.name
                } elseif ($us.user -and $us.user.name) {
                    $agentName = [string]$us.user.name
                }

                if ($us.cascadeModelConfigData -and $us.cascadeModelConfigData.clientModelConfigs) {
                    foreach ($mq in $us.cascadeModelConfigData.clientModelConfigs) {
                        $lbl = if ($mq.label) { $mq.label } else { $mq.modelId }
                        if ($lbl) {
                            $rem = 1.0
                            if ($mq.quotaInfo) {
                                if ($mq.quotaInfo.remainingFraction -ne $null) {
                                    $rem = [double]$mq.quotaInfo.remainingFraction
                                } elseif ($mq.quotaInfo.resetTime) {
                                    $rem = 0.0
                                }
                            }
                            $modelQuotas[$lbl] = @{
                                remaining = $rem
                                resetTime = if ($mq.quotaInfo) { $mq.quotaInfo.resetTime } else { $null }
                            }
                        }
                    }
                }
            }

            $resMap = @{
                status = "ok"
                port = $activePort
                agent = if ($agentEmail) { @{ email = $agentEmail; name = $agentName } } else { $null }
                modelQuotas = $modelQuotas
                live = if ($statusObj) { $statusObj.userStatus } else { $null }
                machine = @{
                    hostname = $env:COMPUTERNAME
                    username = $env:USERNAME
                    machine_id = "mac-" + $env:COMPUTERNAME.ToLower()
                }
            }

            $json = $resMap | ConvertTo-Json -Depth 6
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
        } else {
            $resMap = @{ status = "ok"; message = "AGS Native PowerShell Server Ready" }
            $json = $resMap | ConvertTo-Json
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
        }

        $response.ContentLength64 = $buffer.Length
        $output = $response.OutputStream
        $output.Write($buffer, 0, $buffer.Length)
        $output.Close()
        $response.Close()
    } catch {}
}