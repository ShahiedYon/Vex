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

function Get-LatestFile {
    param(
        [string]$Folder,
        [string]$Filter
    )
    $file = Get-ChildItem -Path $Folder -Filter $Filter -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $file) { return $null }
    return $file
}

function Complete-FromOutputs {
    $summary = Join-Path $digistore "digistore_autoscan_next_actions.txt"
    $latestCsv = Get-LatestFile -Folder $digistore -Filter "digistore_autoscan_candidates_*.csv"
    $latestPng = Get-LatestFile -Folder $digistore -Filter "digistore_autoscan_*.png"

    if ((Test-Path $summary) -or ($null -ne $latestCsv)) {
        $final = @()
        $final += "Vex Digistore scan complete."
        $final += ""

        if (Test-Path $summary) {
            $final += (Get-Content -Path $summary -Raw)
        }
        elseif ($null -ne $latestCsv) {
            $rows = @()
            try { $rows = Import-Csv -Path $latestCsv.FullName } catch { $rows = @() }
            $final += "DIGISTORE24 AUTO SCAN SUMMARY"
            $final += "============================="
            $final += "Generated: " + (Get-Date).ToString("s")
            $final += "Candidates CSV: " + $latestCsv.FullName
            if ($null -ne $latestPng) { $final += "Screenshot: " + $latestPng.FullName }
            $final += "Candidate rows: " + $rows.Count
            $final += ""
            $final += "TOP MATCHES"
            if ($rows.Count -eq 0) {
                $final += "- No candidate rows found in the CSV. Open Digistore Marketplace, search a keyword, then scan again."
            }
            else {
                $limit = [Math]::Min(10, $rows.Count)
                for ($i = 0; $i -lt $limit; $i++) {
                    $row = $rows[$i]
                    $score = ""
                    $candidate = ""
                    $keyword = ""
                    if ($row.PSObject.Properties.Name -contains "score") { $score = $row.score }
                    if ($row.PSObject.Properties.Name -contains "candidate_text") { $candidate = $row.candidate_text }
                    if ($row.PSObject.Properties.Name -contains "keyword") { $keyword = $row.keyword }
                    if ([string]::IsNullOrWhiteSpace($candidate) -and ($row.PSObject.Properties.Name -contains "nearby_context")) { $candidate = $row.nearby_context }
                    $final += ("" + ($i + 1) + ". [" + $score + "] " + $candidate)
                    if (-not [string]::IsNullOrWhiteSpace($keyword)) { $final += "   Keyword: " + $keyword }
                }
            }
            $final += ""
            $final += "NEXT ACTIONS"
            $final += "1. Open the CSV and review the top candidates."
            $final += "2. Manually inspect the top 3 offers before promoting anything."
            $final += "3. Avoid unrealistic claims, gambling, adult, drugs, supplements, or risky finance offers."
            $final += "4. Add safe candidates to moneycrunch_partner_tracker.csv."
        }

        if ($null -ne $latestCsv) { $final += ""; $final += "CSV: " + $latestCsv.FullName }
        if ($null -ne $latestPng) { $final += "Screenshot: " + $latestPng.FullName }

        Set-Reply ($final -join "`r`n")
        [pscustomobject]@{
            flow = "digistore_scan"
            status = "complete"
            finished_at = (Get-Date).ToString("s")
            summary = if (Test-Path $summary) { $summary } else { "built_from_csv" }
            csv = if ($null -ne $latestCsv) { $latestCsv.FullName } else { "" }
            screenshot = if ($null -ne $latestPng) { $latestPng.FullName } else { "" }
        } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
        return $true
    }

    return $false
}

[pscustomobject]@{
    flow = "digistore_scan"
    status = "rescue_scanning"
    started_at = (Get-Date).ToString("s")
} | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

Set-Reply "Vex rescue started. I am checking Digistore scan outputs and will build the reply from CSV if needed."
Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Rescue scan started") -Encoding UTF8

if (Complete-FromOutputs) {
    Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Completed from existing outputs") -Encoding UTF8
    exit 0
}

if (-not (Test-Path $autoscan)) {
    Set-Reply "Digistore rescue failed: autoscan script is missing. Pull latest Vex from GitHub."
    exit 1
}

try {
    powershell -ExecutionPolicy Bypass -File $autoscan -Root $Root -Keywords $Keywords
    if (Complete-FromOutputs) {
        Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Rescue scan complete after autoscan") -Encoding UTF8
        exit 0
    }

    Set-Reply "Vex Digistore rescue ran, but no CSV or summary was created. Open Digistore Marketplace manually, search a keyword, then run rescue again."
    [pscustomobject]@{ flow="digistore_scan"; status="failed_no_outputs"; finished_at=(Get-Date).ToString("s") } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
    exit 1
}
catch {
    if (Complete-FromOutputs) { exit 0 }
    $msg = "Vex Digistore rescue failed: " + $_.Exception.Message
    Set-Reply $msg
    [pscustomobject]@{ flow="digistore_scan"; status="failed"; error=$_.Exception.Message; finished_at=(Get-Date).ToString("s") } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
    Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $msg) -Encoding UTF8
    exit 1
}
