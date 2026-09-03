#Requires -Version 5.1
<#
.SYNOPSIS
    Antigravity IDE - Google Account Switcher CLI v2
.DESCRIPTION
    Detecta em tempo real qual conta esta ativa no agente e no IDE.
    Monitora esgotamento de modelos e atualiza accounts.json automaticamente.
    Sugere a proxima conta quando a atual esgota.
.EXAMPLE
    .\gmail-switcher.ps1 check              # verifica e atualiza agora
    .\gmail-switcher.ps1 monitor            # loop continuo (Ctrl+C para parar)
    .\gmail-switcher.ps1 suggest            # proxima conta recomendada
    .\gmail-switcher.ps1 whoami             # contas ativas (Agente + IDE Geral)
    .\gmail-switcher.ps1 quota              # quota por modelo
    .\gmail-switcher.ps1 status             # status completo
    .\gmail-switcher.ps1 best               # abre melhor conta disponivel
    .\gmail-switcher.ps1 limit "aluno07" "167h33m56s"
    .\gmail-switcher.ps1 restore "aluno07"
#>
param(
    [Parameter(Position=0)][string]$Command       = "",
    [Parameter(Position=1)][string]$Target        = "",
    [Parameter(Position=2)][string]$ResetDuration = "",
    [string]$label = "",
    [string]$group = "geral",
    [string]$alias = "",
    [int]$IntervalSeconds = 60
)

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$AccountsFile = Join-Path $ScriptDir "..\accounts.json"
$WatchFile    = Join-Path $ScriptDir "..\watch_state.json"
$r = Resolve-Path $AccountsFile -ErrorAction SilentlyContinue
if ($r) { $AccountsFile = $r.Path }
$r = Resolve-Path $WatchFile -ErrorAction SilentlyContinue
if ($r) { $WatchFile = $r.Path } else { $WatchFile = Join-Path (Split-Path $AccountsFile) "watch_state.json" }
if (-not (Test-Path $AccountsFile)) { Write-Error "accounts.json nao encontrado"; exit 1 }

function Load-Accounts  { (Get-Content $AccountsFile -Raw -Encoding UTF8) | ConvertFrom-Json }
function Save-Accounts  { param($d); $d | ConvertTo-Json -Depth 10 | Out-File $AccountsFile -Encoding UTF8 }
function Load-WatchState {
    if (Test-Path $WatchFile) { try { return (Get-Content $WatchFile -Raw -Encoding UTF8) | ConvertFrom-Json } catch {} }
    return $null
}
function Save-WatchState { param($s); $s | ConvertTo-Json -Depth 10 | Out-File $WatchFile -Encoding UTF8 }

function Resolve-Account {
    param($q, $accounts)
    $m = $accounts | Where-Object { $_.email -eq $q }; if ($m) { return $m }
    $ql = $q.ToLower().Trim()
    return $accounts | Where-Object { $found=$false; foreach($a in $_.aliases){if($a.ToLower()-eq$ql){$found=$true;break}}; $found }
}
function Parse-ResetDuration {
    param([string]$s); $s=$s.Trim(); $t=0
    if($s -match '(\d+)h'){$t+=[int]$Matches[1]*3600}
    if($s -match '(\d+)m'){$t+=[int]$Matches[1]*60}
    if($s -match '(\d+)s'){$t+=[int]$Matches[1]}
    return $t
}
function Get-TimeRemaining {
    param([string]$r); if(-not $r){return $null}
    $d=([datetime]::Parse($r))-(Get-Date); if($d.TotalSeconds-le 0){return $null}; return $d
}
function Format-TimeSpan {
    param([timespan]$ts); if(-not $ts){return "pronto"}
    return "$([int]$ts.TotalHours)h$($ts.Minutes)m$($ts.Seconds)s"
}
function Check-AutoRestore {
    param($accounts); $changed=$false
    foreach($acc in $accounts){
        if($acc.status-eq'rate_limited' -and $acc.reset_at){
            if((Get-Date)-ge[datetime]::Parse($acc.reset_at)){
                $acc.status='active';$acc.rate_limited_at=$null;$acc.reset_at=$null;$changed=$true
                Write-Host "  INFO: $($acc.label) restaurada automaticamente." -ForegroundColor DarkGray
            }
        }
    }
    return $changed
}

# ── Live Detection ─────────────────────────────────────────────────────────────
function Get-LsProcesses {
    $result=@()
    Get-CimInstance Win32_Process -Filter "name='language_server_windows_x64.exe'" | Select-Object ProcessId,CommandLine | ForEach-Object {
        $cl=$_.CommandLine
        $result += [PSCustomObject]@{
            PID      = $_.ProcessId
            CsrfToken= if($cl -match '--csrf_token\s+([\w-]+)'){$Matches[1]}else{$null}
            ExtPort  = if($cl -match '--extension_server_port\s+(\d+)'){[int]$Matches[1]}else{0}
            HttpsPort= if($cl -match '--https_server_port\s+(\d+)'){[int]$Matches[1]}else{0}
            Endpoint = if($cl -match '--cloud_code_endpoint\s+(\S+)'){$Matches[1]}else{""}
            HasLsp   = ($cl -match '--enable_lsp')
        }
    }
    return $result
}
function Get-ListeningPortsForPid {
    param([int]$ProcessId)
    $ports = @()
    $lines = netstat -ano 2>$null
    foreach ($line in $lines) {
        if ($line -match "LISTENING\s+$ProcessId`$" -and $line -match '127\.0\.0\.1:(\d+)') {
            $ports += [int]$Matches[1]
        }
    }
    return $ports | Sort-Object
}
function Invoke-LsGetUserStatus {
    param([int]$Port,[string]$CsrfToken)
    try {
        # Ignora certificado SSL auto-assinado do language server
        if (-not ([System.Management.Automation.PSTypeName]"TrustAll").Type) {
            Add-Type -TypeDefinition @"
using System.Net; using System.Net.Security; using System.Security.Cryptography.X509Certificates;
public class TrustAll { public static void Enable() { ServicePointManager.ServerCertificateValidationCallback = (s,c,ch,e) => true; } }
"@ -ErrorAction SilentlyContinue
        }
        [TrustAll]::Enable() | Out-Null
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $url = "https://127.0.0.1:$Port/exa.language_server_pb.LanguageServerService/GetUserStatus"
        $resp = Invoke-WebRequest -Uri $url -Method Post -Body "{}" -ContentType "application/json" -Headers @{"x-codeium-csrf-token"=$CsrfToken} -TimeoutSec 4 -UseBasicParsing -ErrorAction Stop
        return ($resp.Content | ConvertFrom-Json)
    } catch {}
    return $null
}
function Get-ActiveAccounts {
    $results=@()
    foreach($proc in (Get-LsProcesses)){
        if(-not $proc.CsrfToken){continue}
        $portsToTry=@(); if($proc.HttpsPort-gt 0){$portsToTry+=$proc.HttpsPort}
        foreach($p in (Get-ListeningPortsForPid -ProcessId $proc.PID)){
            if($p -notin $portsToTry -and $p -ne $proc.ExtPort){$portsToTry+=$p}
        }
        $us=$null;$fp=0
        foreach($port in $portsToTry){
            $r=Invoke-LsGetUserStatus -Port $port -CsrfToken $proc.CsrfToken
            if($r -and $r.userStatus){$us=$r.userStatus;$fp=$port;break}
        }
        $results += [PSCustomObject]@{
            Role     = if($proc.HasLsp){"IDE Geral"}else{"Agente"}
            PID      = $proc.PID; Port=$fp
            Email    = if($us){$us.email}else{$null}
            Name     = if($us){$us.name}else{""}
            UserStatus=$us; Endpoint=$proc.Endpoint
        }
    }
    return $results
}

function Get-ModelQuotaMap {
    param($userStatus); $map=@{}
    if(-not $userStatus -or -not $userStatus.cascadeModelConfigData){return $map}
    foreach($m in $userStatus.cascadeModelConfigData.clientModelConfigs){
        $lbl=if($m.label){$m.label}else{$m.modelOrAlias.model}
        if($m.quotaInfo -and $null -ne $m.quotaInfo.remainingFraction){
            $map[$lbl]=@{remaining=[double]$m.quotaInfo.remainingFraction;resetTime=$m.quotaInfo.resetTime}
        }
    }
    return $map
}

function Show-QuotaForUserStatus {
    param($userStatus)
    if(-not $userStatus){Write-Host "  Sem dados de quota." -ForegroundColor DarkGray;return}
    $plan=$userStatus.planStatus
    if($plan){Write-Host ("  Creditos: {0} prompt | {1} flow" -f $plan.availablePromptCredits,$plan.availableFlowCredits) -ForegroundColor White}
    $models=$userStatus.cascadeModelConfigData.clientModelConfigs
    if(-not $models){Write-Host "  Sem dados de modelo." -ForegroundColor DarkGray;return}
    Write-Host ""
    Write-Host ("  {0,-46} {1,-10} {2,-12} {3}" -f "Modelo","Restante","Consumido","Reset (local)") -ForegroundColor Yellow
    Write-Host ("  "+("-"*88)) -ForegroundColor DarkGray
    foreach($m in $models){
        $lbl=if($m.label){$m.label}else{$m.modelOrAlias.model}
        $q=$m.quotaInfo; if(-not $q){continue}
        $frac=$q.remainingFraction; $rl="?"
        if($q.resetTime){try{$rl=([datetime]::Parse($q.resetTime).ToLocalTime()).ToString("dd/MM HH:mm")}catch{}}
        if($null -ne $frac){
            $rem="{0:0.0}%" -f ($frac*100); $used="{0:0.0}%" -f ((1-$frac)*100)
            $col=if($frac -ge 0.7){"Green"}elseif($frac -ge 0.3){"Yellow"}else{"Red"}
            Write-Host ("  {0,-46} {1,-10} {2,-12} {3}" -f $lbl,$rem,$used,$rl) -ForegroundColor $col
        }
    }
    Write-Host ""
}

# ── Auto-Update Account From Live Data ────────────────────────────────────────
function Update-AccountFromLiveData {
    param([string]$CurrentEmail,[string]$CurrentName,[hashtable]$QuotaMap,$PreviousState)
    $data=Load-Accounts; $changed=$false; $msgs=@()
    $now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")

    # 1. Conta mudou desde o ultimo check?
    if($PreviousState -and $PreviousState.agent_email -and $PreviousState.agent_email -ne $CurrentEmail){
        $prevEmail=$PreviousState.agent_email
        $prevAcc=Resolve-Account $prevEmail $data.accounts
        if($prevAcc){
            $exhaustedInPrev=@(); $earliestReset=$null
            if($PreviousState.model_quotas){
                foreach($mn in $PreviousState.model_quotas.PSObject.Properties.Name){
                    $info=$PreviousState.model_quotas.$mn
                    $frac=if($info.PSObject.Properties['remaining']){[double]$info.remaining}else{[double]$info}
                    if($frac -le 0.01){
                        $rt=if($info.PSObject.Properties['resetTime']){$info.resetTime}else{$null}
                        $exhaustedInPrev+=@{model=$mn;resetTime=$rt}
                        if($rt -and -not $earliestReset){$earliestReset=$rt}
                    }
                }
            }
            # Atualiza last_seen da conta anterior
            if(-not $prevAcc.PSObject.Properties['last_seen']){$prevAcc|Add-Member -NotePropertyName 'last_seen' -NotePropertyValue $now -Force}
            else{$prevAcc.last_seen=$now}

            if($exhaustedInPrev.Count -gt 0){
                # Esgotou modelos - auto-limit
                $prevAcc.status='rate_limited'; $prevAcc.rate_limited_at=$now
                if($earliestReset){
                    $rs=([datetime]::Parse($earliestReset).ToLocalTime()).ToString("yyyy-MM-dd HH:mm:ss")
                    $prevAcc.reset_at=$rs
                    if(-not $prevAcc.PSObject.Properties['auto_reset_at']){$prevAcc|Add-Member -NotePropertyName 'auto_reset_at' -NotePropertyValue $rs -Force}
                    else{$prevAcc.auto_reset_at=$rs}
                }
                $eObjs=$exhaustedInPrev|ForEach-Object{[PSCustomObject]@{model=$_.model;exhausted_at=$now;reset_at=$_.resetTime}}
                if(-not $prevAcc.PSObject.Properties['exhausted_models']){$prevAcc|Add-Member -NotePropertyName 'exhausted_models' -NotePropertyValue @($eObjs) -Force}
                else{$prevAcc.exhausted_models=@($eObjs)}
                $msgs+="AUTO-LIMIT: $($prevAcc.label) ($prevEmail) BLOQUEADA automaticamente ($($exhaustedInPrev.Count) modelos em 0%). Reset: $($prevAcc.reset_at)"
            } else {
                $msgs+="INFO: '$($prevAcc.label)' ($prevEmail) trocada manualmente (modelos ainda disponiveis)."
            }
        }
        $msgs+="TROCA detectada: $prevEmail -> $CurrentEmail"
        $changed=$true
    }

    # 2. Atualiza dados da conta atual
    $currAcc=Resolve-Account $CurrentEmail $data.accounts
    if($currAcc){
        $ts=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $currAcc.last_used=$ts
        if(-not $currAcc.PSObject.Properties['last_seen']){$currAcc|Add-Member -NotePropertyName 'last_seen' -NotePropertyValue $ts -Force}
        else{$currAcc.last_seen=$ts}

        # Snapshot de quota + modelos esgotados
        $snap=[ordered]@{}; $exhaustedNow=@(); $earliestResetNow=$null
        foreach($mn in $QuotaMap.Keys){
            $info=$QuotaMap[$mn]; $snap[$mn]=@{remaining=$info.remaining;resetTime=$info.resetTime}
            if($info.remaining -le 0.01){
                $exhaustedNow+=@{model=$mn;exhausted_at=$now;reset_at=$info.resetTime}
                if($info.resetTime -and -not $earliestResetNow){$earliestResetNow=$info.resetTime}
            }
        }
        if(-not $currAcc.PSObject.Properties['last_quota_snapshot']){$currAcc|Add-Member -NotePropertyName 'last_quota_snapshot' -NotePropertyValue $snap -Force}
        else{$currAcc.last_quota_snapshot=$snap}

        # Detecta modelos que acabaram de chegar a 0% (comparando com estado anterior)
        if($PreviousState -and $PreviousState.agent_email -eq $CurrentEmail -and $PreviousState.model_quotas){
            foreach($mn in $QuotaMap.Keys){
                $cur=$QuotaMap[$mn]; $prev=$PreviousState.model_quotas.$mn
                if($prev){
                    $pf=if($prev.PSObject.Properties['remaining']){[double]$prev.remaining}else{[double]$prev}
                    if($pf -gt 0.01 -and $cur.remaining -le 0.01){$msgs+="MODELO ESGOTADO: '$mn' chegou a 0% para $CurrentEmail"}
                }
            }
        }

        # Conta esta marcada como bloqueada mas ainda ativa na API?
        if($currAcc.status -eq 'rate_limited'){
            $msgs+="AVISO: $CurrentEmail esta marcada como BLOQUEADA no pool mas ainda ativa no Antigravity IDE."
            if($earliestResetNow){
                $nr=([datetime]::Parse($earliestResetNow).ToLocalTime()).ToString("yyyy-MM-dd HH:mm:ss")
                if(-not $currAcc.PSObject.Properties['auto_reset_at']){$currAcc|Add-Member -NotePropertyName 'auto_reset_at' -NotePropertyValue $nr -Force}
                else{$currAcc.auto_reset_at=$nr}
            }
        }

        # TODOS os modelos em 0% -> auto-limit
        if($exhaustedNow.Count -gt 0 -and $QuotaMap.Count -gt 0 -and $exhaustedNow.Count -ge $QuotaMap.Count){
            if($currAcc.status -ne 'rate_limited'){
                $currAcc.status='rate_limited'; $currAcc.rate_limited_at=$now
                if($earliestResetNow){
                    $rs=([datetime]::Parse($earliestResetNow).ToLocalTime()).ToString("yyyy-MM-dd HH:mm:ss")
                    $currAcc.reset_at=$rs
                    if(-not $currAcc.PSObject.Properties['auto_reset_at']){$currAcc|Add-Member -NotePropertyName 'auto_reset_at' -NotePropertyValue $rs -Force}
                    else{$currAcc.auto_reset_at=$rs}
                }
                $msgs+="AUTO-LIMIT: $($currAcc.label) todos os modelos em 0%. Bloqueada automaticamente. Reset: $($currAcc.reset_at)"
            }
        }

        # Salva lista de modelos esgotados
        $eObjs=$exhaustedNow|ForEach-Object{[PSCustomObject]@{model=$_.model;exhausted_at=$_.exhausted_at;reset_at=$_.reset_at}}
        if(-not $currAcc.PSObject.Properties['exhausted_models']){$currAcc|Add-Member -NotePropertyName 'exhausted_models' -NotePropertyValue @($eObjs) -Force}
        else{$currAcc.exhausted_models=@($eObjs)}

        $changed=$true
    }

    if($changed){Save-Accounts $data}
    return $msgs
}

function Get-SuggestedNextAccount {
    param($data)
    Check-AutoRestore $data.accounts | Out-Null
    $available=@($data.accounts | Where-Object {$_.status -eq 'active'})
    if($available.Count -eq 0){return $null}
    $scored=$available | ForEach-Object {
        $s=0
        if(-not $_.PSObject.Properties['last_seen'] -or -not $_.last_seen){$s+=1000}
        if($_.PSObject.Properties['exhausted_models'] -and @($_.exhausted_models).Count -gt 0){$s-=500}
        if($_.last_used){$s-=[int]((Get-Date)-[datetime]::Parse($_.last_used)).TotalHours}
        [PSCustomObject]@{Account=$_;Score=$s}
    }
    return ($scored | Sort-Object Score -Descending | Select-Object -First 1).Account
}

# ── Core Check ────────────────────────────────────────────────────────────────
function Invoke-Check {
    param([bool]$Silent=$false)
    $active=Get-ActiveAccounts
    $agent=$active | Where-Object {$_.Role -eq "Agente"} | Select-Object -First 1
    if(-not $agent -or -not $agent.Email){
        if(-not $Silent){Write-Host "  [CHECK] Nenhum agente detectado." -ForegroundColor DarkGray}; return @()
    }
    $quotaMap=Get-ModelQuotaMap -userStatus $agent.UserStatus
    $prevState=Load-WatchState
    $msgs=Update-AccountFromLiveData -CurrentEmail $agent.Email -CurrentName $agent.Name -QuotaMap $quotaMap -PreviousState $prevState

    # Salva watch_state
    $snap=[ordered]@{}
    foreach($k in $quotaMap.Keys){$snap[$k]=@{remaining=$quotaMap[$k].remaining;resetTime=$quotaMap[$k].resetTime}}
    Save-WatchState ([PSCustomObject]@{
        last_check=$((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"))
        agent_email=$agent.Email; agent_name=$agent.Name
        agent_pid=$agent.PID; agent_port=$agent.Port
        model_quotas=$snap
    })

    # Sincronizacao automatica nativa com a Vercel Cloud (sem necessidade de daemon ou .bat)
    try {
        $syncPayload = @{
            machine_id   = "mac-" + $env:COMPUTERNAME.ToLower()
            hostname     = $env:COMPUTERNAME
            username     = $env:USERNAME
            active_email = $agent.Email
            model_quotas = $snap
            last_seen    = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 6 -Compress
        $null = Invoke-RestMethod -Uri "https://antigravity-gmail-switcher.vercel.app/api/sync" -Method POST -Body $syncPayload -ContentType "application/json" -TimeoutSec 4
    } catch {}

    if(-not $Silent){
        foreach($msg in $msgs){
            $col=if($msg -match '^AUTO-LIMIT|^TROCA'){"Yellow"}elseif($msg -match '^MODELO ESGOTADO'){"Red"}elseif($msg -match '^AVISO'){"DarkYellow"}else{"DarkGray"}
            Write-Host "  $msg" -ForegroundColor $col
        }
        # Sugestao se conta esgotada
        $data=Load-Accounts; $ca=Resolve-Account $agent.Email $data.accounts
        if($ca -and $ca.status -eq 'rate_limited'){
            Write-Host ""; Write-Host "  [!] Conta ativa ESGOTADA. Proxima recomendada:" -ForegroundColor Red
            $next=Get-SuggestedNextAccount $data
            if($next){Write-Host "      $($next.label)  ($($next.email))" -ForegroundColor Green; Write-Host "      Execute: .\gmail-switcher.ps1 best" -ForegroundColor DarkGray}
            else{
                Write-Host "      Nenhuma conta disponivel." -ForegroundColor Red
                @($data.accounts|Where-Object{$_.reset_at}|Sort-Object{[datetime]::Parse($_.reset_at)}|Select-Object -First 3) | ForEach-Object {
                    Write-Host "      $($_.label): $(Format-TimeSpan (Get-TimeRemaining $_.reset_at))" -ForegroundColor DarkGray
                }
            }
        }
    }
    return $msgs
}

# ── Commands ──────────────────────────────────────────────────────────────────
switch ($Command.ToLower()) {

"check" {
    Write-Host ""; Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "  CHECK - Verificando estado atual..." -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan; Write-Host ""
    $active=Get-ActiveAccounts
    foreach($a in $active){
        $rc=if($a.Role -eq "Agente"){"Magenta"}else{"Cyan"}
        Write-Host "  [$($a.Role)]" -ForegroundColor $rc -NoNewline
        Write-Host " $($a.Name)  <$($a.Email)>  PID $($a.PID) :$($a.Port)" -ForegroundColor White
    }
    Write-Host ""; Invoke-Check -Silent $false | Out-Null
    Write-Host ""; Write-Host "  watch_state: $WatchFile" -ForegroundColor DarkGray
    Write-Host "=====================================================" -ForegroundColor Cyan; Write-Host ""
}

"monitor" {
    Write-Host ""; Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "  MONITOR - intervalo: ${IntervalSeconds}s  (Ctrl+C para parar)" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    while($true){
        $ts=(Get-Date).ToString("HH:mm:ss"); Write-Host ""; Write-Host "[$ts] Verificando..." -ForegroundColor DarkGray
        $msgs=Invoke-Check -Silent $false
        if($msgs.Count -eq 0){Write-Host "  Sem mudancas." -ForegroundColor DarkGray}
        Write-Host "  Proximo em ${IntervalSeconds}s..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $IntervalSeconds
    }
}

"suggest" {
    $data=Load-Accounts; Check-AutoRestore $data.accounts | Out-Null
    Write-Host ""; Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "  SUGGEST - Proxima conta recomendada" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    $active=Get-ActiveAccounts; $agent=$active|Where-Object{$_.Role-eq"Agente"}|Select-Object -First 1
    if($agent -and $agent.Email){
        Write-Host ""; Write-Host "  Conta ativa agora:" -ForegroundColor Yellow
        Write-Host "  $($agent.Name)  <$($agent.Email)>" -ForegroundColor White
        $qm=Get-ModelQuotaMap -userStatus $agent.UserStatus
        $usedM=$qm.Keys|Where-Object{$qm[$_].remaining -le 0.01}
        if(@($usedM).Count -gt 0){Write-Host "  Modelos ESGOTADOS:" -ForegroundColor Red; $usedM|ForEach-Object{Write-Host "    - $_" -ForegroundColor DarkGray}}
        else{Write-Host "  Todos os modelos com quota disponivel." -ForegroundColor Green}
    }
    Write-Host ""; $next=Get-SuggestedNextAccount $data
    if($next){
        Write-Host "  Recomendacao:" -ForegroundColor Green
        Write-Host "  $($next.label)  ($($next.email))" -ForegroundColor White
        $ls=if($next.PSObject.Properties['last_seen'] -and $next.last_seen){$next.last_seen}else{"nunca usada"}
        Write-Host "  Ultimo uso: $ls" -ForegroundColor DarkGray
        $exh=if($next.PSObject.Properties['exhausted_models']){@($next.exhausted_models)}else{@()}
        if($exh.Count -gt 0){
            Write-Host "  Modelos anteriormente esgotados:" -ForegroundColor DarkYellow
            $exh|ForEach-Object{Write-Host "    - $($_.model)  (reset: $($_.reset_at))" -ForegroundColor DarkGray}
        } else {Write-Host "  Sem historico de esgotamento registrado." -ForegroundColor Green}
        Write-Host ""; Write-Host "  Para usar: .\gmail-switcher.ps1 best" -ForegroundColor Cyan
    } else {
        Write-Host "  Nenhuma conta disponivel no pool." -ForegroundColor Red
        @($data.accounts|Where-Object{$_.reset_at}|Sort-Object{[datetime]::Parse($_.reset_at)}|Select-Object -First 5)|ForEach-Object{
            $src=if($_.PSObject.Properties['auto_reset_at'] -and $_.auto_reset_at){"(API)"}else{"(manual)"}
            Write-Host "  $($_.label): $(Format-TimeSpan (Get-TimeRemaining $_.reset_at)) $src" -ForegroundColor DarkGray
        }
    }
    Write-Host ""; Write-Host "=====================================================" -ForegroundColor Cyan; Write-Host ""
}

"whoami" {
    Write-Host ""; Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "  Contas Ativas - Deteccao em Tempo Real" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "  (consultando API interna do language server...)" -ForegroundColor DarkGray
    $active=Get-ActiveAccounts
    if($active.Count -eq 0){Write-Host "  Nenhum language server detectado." -ForegroundColor Yellow}
    foreach($a in $active){
        $rc=if($a.Role -eq "Agente"){"Magenta"}else{"Cyan"}
        Write-Host ""; Write-Host "  [$($a.Role)]" -ForegroundColor $rc -NoNewline
        Write-Host "  PID $($a.PID) | porta $($a.Port)" -ForegroundColor DarkGray
        Write-Host "  Conta : $($a.Name)  <$($a.Email)>" -ForegroundColor White
        Write-Host "  API   : $($a.Endpoint)" -ForegroundColor DarkGray
    }
    Write-Host ""; Write-Host "=====================================================" -ForegroundColor Cyan; Write-Host ""
}

"quota" {
    Write-Host ""; Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "  Quota por Modelo - Deteccao em Tempo Real" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    $active=Get-ActiveAccounts
    $targets=if($Target){$active|Where-Object{$_.Email -like "*$Target*"}}else{$active}
    if(-not $targets -or @($targets).Count -eq 0){Write-Host "  Nenhum resultado."-ForegroundColor Yellow;Write-Host "";exit 0}
    foreach($a in @($targets)){
        $rc=if($a.Role -eq "Agente"){"Magenta"}else{"Cyan"}
        Write-Host ""; Write-Host "  [$($a.Role)] $($a.Name)  <$($a.Email)>" -ForegroundColor $rc; Write-Host ""
        Show-QuotaForUserStatus -userStatus $a.UserStatus
    }
    Write-Host "=====================================================" -ForegroundColor Cyan; Write-Host ""
}

"status" {
    $data=Load-Accounts; $ch=Check-AutoRestore $data.accounts; if($ch){Save-Accounts $data}
    Write-Host ""; Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "  Status Completo - Antigravity IDE" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host ""; Write-Host "  [LIVE] Contas ativas nos processos:" -ForegroundColor Yellow
    $active=Get-ActiveAccounts
    if($active.Count -eq 0){Write-Host "  Nenhum language server detectado." -ForegroundColor DarkGray}
    foreach($a in $active){
        $rc=if($a.Role -eq "Agente"){"Magenta"}else{"Cyan"}
        Write-Host ""; Write-Host "  [$($a.Role)] PID $($a.PID) | porta $($a.Port)" -ForegroundColor $rc
        Write-Host "    $($a.Name)  <$($a.Email)>" -ForegroundColor White
        if($a.Role -eq "Agente" -and $a.UserStatus){
            $qm=Get-ModelQuotaMap -userStatus $a.UserStatus
            $used=$qm.Keys|Where-Object{$qm[$_].remaining -lt 1.0}
            if(@($used).Count -gt 0){
                Write-Host "    Consumo detectado:" -ForegroundColor DarkGray
                foreach($mn in $used){
                    $f=$qm[$mn].remaining; $col=if($f -ge 0.3){"Yellow"}else{"Red"}
                    Write-Host ("      {0,-40} usado={1,-8} restante={2:0.0}%" -f $mn,("{0:0.0}%"-f((1-$f)*100)),($f*100)) -ForegroundColor $col
                }
            } else {Write-Host "    Todos os modelos: 100% disponivel" -ForegroundColor Green}
        }
    }
    Write-Host ""; Write-Host "  [POOL] Contas no switcher:" -ForegroundColor Yellow
    $ac=0;$lc=0
    foreach($acc in $data.accounts){
        $sc=if($acc.status -eq 'active'){"Green"}else{"Red"}
        $sl=if($acc.status -eq 'active'){"[ATIVA]    "}else{"[BLOQUEADA]"}
        Write-Host ""; Write-Host "  $sl $($acc.label)  ($($acc.email))" -ForegroundColor $sc
        if($acc.status -eq 'rate_limited'){
            $lc++
            if($acc.rate_limited_at){Write-Host "    Bloqueada em  : $($acc.rate_limited_at)" -ForegroundColor DarkGray}
            if($acc.reset_at){
                $src=if($acc.PSObject.Properties['auto_reset_at'] -and $acc.auto_reset_at){"(API)"}else{"(manual)"}
                Write-Host "    Reset $src     : $($acc.reset_at)  [$(Format-TimeSpan (Get-TimeRemaining $acc.reset_at))]" -ForegroundColor Yellow
            }
            if($acc.PSObject.Properties['exhausted_models'] -and @($acc.exhausted_models).Count -gt 0){
                Write-Host "    Modelos esgotados:" -ForegroundColor DarkGray
                $acc.exhausted_models|ForEach-Object{Write-Host "      - $($_.model)" -ForegroundColor DarkGray}
            }
        } else {
            $ac++
            Write-Host "    Ultimo uso: $(if($acc.last_used){$acc.last_used}else{'nunca'})" -ForegroundColor DarkGray
        }
    }
    Write-Host ""; Write-Host "  Pool: $ac ativa(s) | $lc bloqueada(s)" -ForegroundColor Cyan
    Write-Host "  Use 'check' para atualizar | 'suggest' para proxima | 'quota' para detalhe" -ForegroundColor DarkGray
    Write-Host "======================================================" -ForegroundColor Cyan; Write-Host ""
}

"list" {
    $data=Load-Accounts; $ch=Check-AutoRestore $data.accounts; if($ch){Save-Accounts $data}
    Write-Host ""; Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "  Contas - Account Switcher" -ForegroundColor Cyan; Write-Host "======================================================" -ForegroundColor Cyan
    $data.accounts|Group-Object -Property group|ForEach-Object{
        Write-Host ""; Write-Host "  Grupo: $($_.Name.ToUpper())" -ForegroundColor Yellow
        foreach($acc in $_.Group){Write-Host "    - $($acc.label)  ($($acc.email))" -ForegroundColor White; Write-Host "      Aliases: $(($acc.aliases-join', '))" -ForegroundColor DarkGray}
    }
    Write-Host ""; Write-Host "  Total: $($data.accounts.Count) conta(s)" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan; Write-Host ""
}

"open" {
    if(-not $Target){Write-Error "Uso: open EMAIL_OU_ALIAS";exit 1}
    $data=Load-Accounts; Check-AutoRestore $data.accounts|Out-Null; $acc=Resolve-Account $Target $data.accounts
    if(-not $acc){Write-Host "ERRO: '$Target' nao encontrado." -ForegroundColor Red;exit 1}
    if($acc.status -eq 'rate_limited'){Write-Host "AVISO: $($acc.label) bloqueada. Reset: $(Format-TimeSpan (Get-TimeRemaining $acc.reset_at)). Use 'best' para alternativa." -ForegroundColor Yellow}
    $acc.last_used=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); Save-Accounts $data
    $url="https://accounts.google.com/AccountChooser?Email=$($acc.email)&continue=$([uri]::EscapeDataString('https://accounts.google.com/'))"
    Write-Host "Abrindo: $($acc.label)  ($($acc.email))" -ForegroundColor Cyan
    Write-Host "Clique em 'Sign in with Google' no Antigravity IDE apos abrir." -ForegroundColor Green
    Start-Process $url
}

"best" {
    $data=Load-Accounts; $ch=Check-AutoRestore $data.accounts; if($ch){Save-Accounts $data}
    $next=Get-SuggestedNextAccount $data
    if(-not $next){
        Write-Host "AVISO: Nenhuma conta ativa." -ForegroundColor Yellow
        @($data.accounts|Where-Object{$_.reset_at}|Sort-Object{[datetime]::Parse($_.reset_at)})|ForEach-Object{
            Write-Host "  $($_.label): $(Format-TimeSpan (Get-TimeRemaining $_.reset_at))" -ForegroundColor White
        }; exit 0
    }
    $next.last_used=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); Save-Accounts $data
    $url="https://accounts.google.com/AccountChooser?Email=$($next.email)&continue=$([uri]::EscapeDataString('https://accounts.google.com/'))"
    Write-Host ""; Write-Host "Melhor conta: $($next.label)  ($($next.email))" -ForegroundColor Green
    Write-Host "Clique em 'Sign in with Google' no Antigravity IDE apos abrir." -ForegroundColor Green; Write-Host ""
    Start-Process $url
}

"limit" {
    if(-not $Target){Write-Error "Uso: limit EMAIL DURACAO";exit 1}
    $data=Load-Accounts; $acc=Resolve-Account $Target $data.accounts
    if(-not $acc){Write-Host "ERRO: '$Target' nao encontrado." -ForegroundColor Red;exit 1}
    $now=Get-Date; $resetAt=$null
    if($ResetDuration){$s=Parse-ResetDuration $ResetDuration; if($s -gt 0){$resetAt=$now.AddSeconds($s).ToString("yyyy-MM-dd HH:mm:ss")}}
    $acc.status='rate_limited'; $acc.rate_limited_at=$now.ToString("yyyy-MM-dd HH:mm:ss"); $acc.reset_at=$resetAt
    Save-Accounts $data; Write-Host "OK: $($acc.label) BLOQUEADA." -ForegroundColor Red
    if($resetAt){Write-Host "    Reset: $resetAt" -ForegroundColor Yellow}; Write-Host ""
}

"restore" {
    if(-not $Target){Write-Error "Uso: restore EMAIL";exit 1}
    $data=Load-Accounts; $acc=Resolve-Account $Target $data.accounts
    if(-not $acc){Write-Host "ERRO: '$Target' nao encontrado." -ForegroundColor Red;exit 1}
    $acc.status='active'; $acc.rate_limited_at=$null; $acc.reset_at=$null
    if($acc.PSObject.Properties['exhausted_models']){$acc.exhausted_models=@()}
    if($acc.PSObject.Properties['auto_reset_at']){$acc.auto_reset_at=$null}
    Save-Accounts $data; Write-Host "OK: $($acc.label) ATIVA." -ForegroundColor Green
}

"add" {
    if(-not $Target){Write-Error "Uso: add EMAIL [--label x] [--group y] [--alias z]";exit 1}
    $data=Load-Accounts
    if($data.accounts|Where-Object{$_.email -eq $Target}){Write-Host "AVISO: '$Target' ja existe."-ForegroundColor Yellow;exit 0}
    $list=[System.Collections.ArrayList]$data.accounts
    $list.Add([PSCustomObject][ordered]@{
        email=$Target;aliases=@(if($alias){$alias});group=$group
        label=if($label){$label}else{$Target};status='active'
        last_used=$null;last_seen=$null;rate_limited_at=$null;reset_at=$null
        exhausted_models=@();last_quota_snapshot=$null;auto_reset_at=$null
    })|Out-Null
    $data.accounts=$list; Save-Accounts $data; Write-Host "OK: $Target adicionado." -ForegroundColor Green
}

"remove" {
    if(-not $Target){Write-Error "Uso: remove EMAIL";exit 1}
    $data=Load-Accounts; $before=$data.accounts.Count
    $data.accounts=@($data.accounts|Where-Object{$_.email -ne $Target})
    if($data.accounts.Count -eq $before){Write-Host "AVISO: '$Target' nao encontrado."-ForegroundColor Yellow;exit 0}
    Save-Accounts $data; Write-Host "OK: $Target removido." -ForegroundColor Green
}

default {
    Write-Host ""; Write-Host "Antigravity IDE - Google Account Switcher v2" -ForegroundColor Cyan; Write-Host ""
    Write-Host "Monitoramento automatico:" -ForegroundColor Yellow
    Write-Host "  check                         Verifica e atualiza accounts.json agora"
    Write-Host "  monitor [-IntervalSeconds N]   Loop continuo (padrao: 60s)"
    Write-Host "  suggest                        Proxima conta recomendada"
    Write-Host ""
    Write-Host "Inspecao em tempo real:" -ForegroundColor Yellow
    Write-Host "  whoami                         Contas ativas (Agente + IDE Geral)"
    Write-Host "  quota [EMAIL]                  Quota por modelo"
    Write-Host "  status                         Status completo"
    Write-Host ""
    Write-Host "Gerenciamento do pool:" -ForegroundColor Yellow
    Write-Host "  list | open | best | limit | restore | add | remove"
    Write-Host ""
    Write-Host "Fluxo tipico:" -ForegroundColor DarkGray
    Write-Host "  1. check      -> verifica estado, auto-limita se necessario" -ForegroundColor DarkGray
    Write-Host "  2. quota      -> ve consumo por modelo" -ForegroundColor DarkGray
    Write-Host "  3. suggest    -> qual e a proxima conta?" -ForegroundColor DarkGray
    Write-Host "  4. best       -> abre no browser e registra last_used" -ForegroundColor DarkGray
    Write-Host ""
}
}



