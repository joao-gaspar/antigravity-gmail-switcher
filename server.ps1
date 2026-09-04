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
        if (-not $rawProcs) {
            $rawProcs = Get-Process -Name "*language_server*" -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue
                    if ($wmi) { $wmi } else { $_ }
                } catch { $_ }
            }
        }

        if ($rawProcs) {
            # Prioritize Agente process (WITHOUT --enable_lsp) over IDE Geral (with --enable_lsp)
            $procs = $rawProcs | Sort-Object @{Expression={
                if ($_.CommandLine -and -not $_.CommandLine.Contains("--enable_lsp")) { 0 } else { 1 }
            }}, @{Expression={[long]$_.ProcessId}; Descending=$true}

            $netstat = netstat -ano 2>$null

            foreach ($p in $procs) {
                $cl = $p.CommandLine
                $pidVal = $p.ProcessId
                if (-not $cl) { continue }

                $csrfTokens = @()
                if ($cl -match '--csrf_token[=\s"]+([^"\s]+)') { $csrfTokens += $Matches[1] }
                if ($cl -match '--extension_server_csrf_token[=\s"]+([^"\s]+)') { $csrfTokens += $Matches[1] }
                if ($csrfTokens.Count -eq 0) { continue }

                $listeningPorts = @()

                # 1. Native Get-NetTCPConnection
                try {
                    $tcpPorts = Get-NetTCPConnection -OwningProcess $pidVal -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort
                    if ($tcpPorts) {
                        foreach ($tp in $tcpPorts) {
                            if ($tp -notin $listeningPorts) { $listeningPorts += [int]$tp }
                        }
                    }
                } catch {}

                # 2. Command-line argument ports
                if ($cl -match '--https_server_port\s+(\d+)') {
                    $p1 = [int]$Matches[1]
                    if ($p1 -notin $listeningPorts) { $listeningPorts += $p1 }
                }
                if ($cl -match '--extension_server_port\s+(\d+)') {
                    $p2 = [int]$Matches[1]
                    if ($p2 -notin $listeningPorts) { $listeningPorts += $p2 }
                }

                # 3. netstat -ano fallback matching any binding IP format
                if ($netstat) {
                    foreach ($line in ($netstat -split "\r?\n")) {
                        if ($line -match "TCP\s+\S+:(\d+)\s+\S+\s+LISTENING\s+$pidVal\s*$") {
                            $portFound = [int]$Matches[1]
                            if ($portFound -notin $listeningPorts) {
                                $listeningPorts += $portFound
                            }
                        }
                    }
                }

                foreach ($port in $listeningPorts) {
                    foreach ($proto in @("https", "http")) {
                        foreach ($csrf in $csrfTokens) {
                            foreach ($hdr in @("x-codeium-csrf-token", "x-csrf-token")) {
                                try {
                                    $url = "$($proto)://127.0.0.1:$port/exa.language_server_pb.LanguageServerService/GetUserStatus"
                                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls
                                    $req = [System.Net.HttpWebRequest]::Create($url)
                                    $req.Method = "POST"
                                    $req.Headers.Add($hdr, $csrf)
                                    $req.ContentType = "application/json"
                                    $req.Timeout = 1500
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
                                    $us = if ($parsed.userStatus) { $parsed.userStatus } else { $parsed }
                                    $email = $null
                                    if ($us.email) { $email = [string]$us.email }
                                    elseif ($us.user -and $us.user.email) { $email = [string]$us.user.email }
                                    elseif ($us.userInfo -and $us.userInfo.email) { $email = [string]$us.userInfo.email }
                                    elseif ($us.userAccount -and $us.userAccount.email) { $email = [string]$us.userAccount.email }
                                    elseif ($us.profile -and $us.profile.email) { $email = [string]$us.profile.email }
                                    elseif ($us.primaryEmail) { $email = [string]$us.primaryEmail }

                                    if ($email -or ($us -and ($us.cascadeModelConfigData -or $us.clientModelConfigs -or $us.availableModels))) {
                                        return @{
                                            userStatus = $us
                                            port = $port
                                            pid = $pidVal
                                            email = $email
                                            name = if ($us.name) { [string]$us.name } elseif ($us.user -and $us.user.name) { [string]$us.user.name } else { "" }
                                        }
                                    }
                                } catch {}
                            }
                        }
                    }
                }
            }
        }

        # 4. Storage Fallback: state.vscdb
        $vscdbCandidates = @(
            "$env:APPDATA\Antigravity IDE\User\globalStorage\state.vscdb",
            "$env:APPDATA\Antigravity\User\globalStorage\state.vscdb"
        )
        foreach ($vscdb in $vscdbCandidates) {
            if (Test-Path $vscdb) {
                try {
                    $fs = [System.IO.File]::Open($vscdb, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    $reader = New-Object System.IO.StreamReader($fs)
                    $raw = $reader.ReadToEnd()
                    $reader.Close()
                    $fs.Close()

                    $matches = [regex]::Matches($raw, '([\w\.-]+@(tilab\.com\.br|gmail\.com|google\.com|[\w\.-]+\.\w+))')
                    if ($matches.Count -gt 0) {
                        $emailFound = $matches[$matches.Count - 1].Groups[1].Value
                        if ($emailFound) {
                            return @{
                                userStatus = @{ email = $emailFound; name = $emailFound.Split('@')[0] }
                                port = 0
                                pid = 0
                                email = $emailFound
                                name = $emailFound.Split('@')[0]
                            }
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

            if ($statusObj -and $statusObj.email) { $agentEmail = [string]$statusObj.email }
            if ($statusObj -and $statusObj.name)  { $agentName  = [string]$statusObj.name }

            if ($statusObj -and $statusObj.userStatus) {
                $us = $statusObj.userStatus
                if (-not $agentEmail) {
                    if ($us.email) { $agentEmail = [string]$us.email }
                    elseif ($us.user -and $us.user.email) { $agentEmail = [string]$us.user.email }
                    elseif ($us.userInfo -and $us.userInfo.email) { $agentEmail = [string]$us.userInfo.email }
                    elseif ($us.userAccount -and $us.userAccount.email) { $agentEmail = [string]$us.userAccount.email }
                    elseif ($us.profile -and $us.profile.email) { $agentEmail = [string]$us.profile.email }
                    elseif ($us.primaryEmail) { $agentEmail = [string]$us.primaryEmail }
                }

                if (-not $agentName) {
                    if ($us.name) { $agentName = [string]$us.name }
                    elseif ($us.user -and $us.user.name) { $agentName = [string]$us.user.name }
                    elseif ($us.userInfo -and $us.userInfo.name) { $agentName = [string]$us.userInfo.name }
                }

                $configs = @()
                if ($us.cascadeModelConfigData -and $us.cascadeModelConfigData.clientModelConfigs) {
                    $configs = $us.cascadeModelConfigData.clientModelConfigs
                } elseif ($us.clientModelConfigs) {
                    $configs = $us.clientModelConfigs
                } elseif ($us.modelConfigs) {
                    $configs = $us.modelConfigs
                }
                if (-not $configs -or @($configs).Count -eq 0) {
                    if ($us.availableModels) {
                        $configs = $us.availableModels
                    }
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