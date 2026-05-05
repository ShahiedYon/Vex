param(
    [string]$Root = "",
    [string]$Keywords = "debt,credit,finance,budget,money,loan,financial wellness"
)

$ErrorActionPreference = "Continue"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$workspace = Join-Path $Root "workspace"
$digistore = Join-Path $workspace "digistore"
$logs = Join-Path $Root "logs"
$replyFile = Join-Path $digistore "digistore_flow_reply.txt"
$lastReply = Join-Path $workspace "vex_last_reply.txt"
$stateFile = Join-Path $digistore "digistore_flow_state.json"
$autoscan = Join-Path $Root "scripts\vex_digistore_autoscan.ps1"
$logFile = Join-Path $logs "vex_digistore_rescue.log"

Ensure-Directory $workspace
Ensure-Directory $digistore
Ensure-Directory $logs

function Set-Reply {
    param([string]$Text)
    Set-Content -Path $replyFile -Value $Text -Encoding UTF8
    Set-Content -Path $lastReply -Value $Text -Encoding UTF8
    Write-Host $Text
}

if (-not (Test-Path $autoscan)) {
    Set-Reply "Digistore rescue failed: autoscan script is missing. Pull latest Vex from GitHub."
    exit 1
}

[pscustomobject]@{
    flow = "digistore_scan"
    status = "rescue_scanning"
    started_at = (Get-Date).ToString("s")
} | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

Set-Reply "Vex rescue started. I am running the Digistore autoscan now. Make sure the Digistore browser session is logged in and Marketplace results are visible."
Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Rescue scan started") -Encoding UTF8

try {
    powershell -ExecutionPolicy Bypass -File $autoscan -Root $Root -Keywords $Keywords
    $summary = Join-Path $digistore "digistore_autoscan_next_actions.txt"
    $latestCsv = Get-ChildItem -Path $digistore -Filter "digistore_autoscan_candidates_*.csv" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (Test-Path $summary) {
        $summaryText = Get-Content -Path $summary -Raw
        $final = "Vex Digistore rescue scan complete.`r`n`r`n" + $summaryText
        if ($null -ne $latestCsv) { $final += "`r`nCSV: " + $latestCsv.FullName }
        Set-Reply $final
        [pscustomobject]@{
            flow = "digistore_scan"
            status = "complete"
            finished_at = (Get-Date).ToString("s")
            summary = $summary
            csv = if ($null -ne $latestCsv) { $latestCsv.FullName } else { "" }
        } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
        Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Rescue scan complete") -Encoding UTF8
        exit 0
    }
    else {
        Set-Reply "Vex Digistore rescue ran, but no summary was created. Open Digistore Marketplace manually, search a keyword, then run rescue again."
        [pscustomobject]@{ flow="digistore_scan"; status="failed_no_summary"; finished_at=(Get-Date).ToString("s") } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
        exit 1
    }
}
catch {
    $msg = "Vex Digistore rescue failed: " + $_.Exception.Message
    Set-Reply $msg
    [pscustomobject]@{ flow="digistore_scan"; status="failed"; error=$_.Exception.Message; finished_at=(Get-Date).ToString("s") } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
    Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $msg) -Encoding UTF8
    exit 1
}
