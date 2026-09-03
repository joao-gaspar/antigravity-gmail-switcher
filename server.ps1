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
        $rawProcs = Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'language_server*' }
        if (-not $rawProcs) { return $null }

        # Prioritize Agente process (WITHOUT --enable_lsp) over IDE Geral (with --enable_lsp), matching gmail-switcher.ps1
        $procs = $rawProcs | Sort-Object @{Expression={
            if ($_.CommandLine -and -not $_.CommandLine.Contains("--enable_lsp")) { 0 } else { 1 }
        }}, @{Expression={[long]$_.ProcessId}; Descending=$true}

        $netstat = netstat -ano 2>$null

        foreach ($p in $procs) {
            $cl = $p.CommandLine
            $pidVal = $p.ProcessId
            if (-not $cl) { continue }

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
                    if ($parsed.userStatus -and ($parsed.userStatus.email -or ($parsed.userStatus.user -and $parsed.userStatus.user.email))) {
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
                if ($us.email) { $agentEmail = [string]$us.email }
                elseif ($us.user -and $us.user.email) { $agentEmail = [string]$us.user.email }
                elseif ($us.userInfo -and $us.userInfo.email) { $agentEmail = [string]$us.userInfo.email }
                elseif ($us.userAccount -and $us.userAccount.email) { $agentEmail = [string]$us.userAccount.email }
                elseif ($us.profile -and $us.profile.email) { $agentEmail = [string]$us.profile.email }
                elseif ($us.primaryEmail) { $agentEmail = [string]$us.primaryEmail }

                if ($us.name) { $agentName = [string]$us.name }
                elseif ($us.user -and $us.user.name) { $agentName = [string]$us.user.name }
                elseif ($us.userInfo -and $us.userInfo.name) { $agentName = [string]$us.userInfo.name }

                $configs = @()
                if ($us.cascadeModelConfigData -and $us.cascadeModelConfigData.clientModelConfigs) {
                    $configs = $us.cascadeModelConfigData.clientModelConfigs
                } elseif ($us.clientModelConfigs) {
                    $configs = $us.clientModelConfigs
                } elseif ($us.modelConfigs) {
                    $configs = $us.modelConfigs
                }
                # availableModels is the actual field used in recent Antigravity builds
                if ($us.availableModels) {
                    $configs = $us.availableModels
                }

                if ($configs) {
                    foreach ($mq in $configs) {
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

            # Direct PowerShell Cloud Push to Vercel api/sync
            if ($global:lastCloudSync -eq $null -or ((Get-Date) - $global:lastCloudSync).TotalSeconds -ge 4) {
                $global:lastCloudSync = Get-Date
                try {
                    $syncPayload = @{
                        machine_id   = "mac-" + $env:COMPUTERNAME.ToLower()
                        hostname     = $env:COMPUTERNAME
                        username     = $env:USERNAME
                        active_email = $agentEmail
                        model_quotas = $modelQuotas
                        last_seen    = (Get-Date).ToString("o")
                    } | ConvertTo-Json -Depth 6 -Compress

                    $null = Invoke-RestMethod -Uri "https://antigravity-gmail-switcher.vercel.app/api/sync" -Method POST -Body $syncPayload -ContentType "application/json" -TimeoutSec 4
                } catch {}
            }
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