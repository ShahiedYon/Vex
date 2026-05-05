param(
    [string]$Root = ""
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
$logFile = Join-Path $logs "vex_digistore_finish.log"

Ensure-Directory $workspace
Ensure-Directory $digistore
Ensure-Directory $logs

function Write-AllReply {
    param([string[]]$Lines)
    $text = $Lines -join "`r`n"
    Set-Content -Path $replyFile -Value $text -Encoding UTF8
    Set-Content -Path $lastReply -Value $text -Encoding UTF8
    Write-Host $text
}

$csv = Get-ChildItem -Path $digistore -Filter "digistore_autoscan_candidates_*.csv" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$png = Get-ChildItem -Path $digistore -Filter "digistore_autoscan_*.png" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$json = Get-ChildItem -Path $digistore -Filter "digistore_autoscan_*.json" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$summary = Get-ChildItem -Path $digistore -Filter "digistore_autoscan_next_actions.txt" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $csv) {
    $files = Get-ChildItem -Path $digistore -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 20
    $out = @()
    $out += "Vex Digistore finish could not find a candidate CSV."
    $out += "Folder checked: " + $digistore
    $out += ""
    $out += "Latest files found:"
    foreach ($f in $files) { $out += "- " + $f.FullName }
    $out += ""
    $out += "Next: rerun the scan with Digistore Marketplace results visible."
    Write-AllReply -Lines $out
    [pscustomobject]@{ flow="digistore_scan"; status="failed_no_csv"; finished_at=(Get-Date).ToString("s"); folder=$digistore } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
    exit 1
}

$rows = @()
try { $rows = Import-Csv -Path $csv.FullName } catch { $rows = @() }

$out = @()
$out += "Vex Digistore scan complete."
$out += ""
$out += "DIGISTORE24 SCAN SUMMARY"
$out += "========================="
$out += "Generated: " + (Get-Date).ToString("s")
$out += "Candidate rows: " + $rows.Count
$out += "CSV: " + $csv.FullName
if ($null -ne $png) { $out += "Screenshot: " + $png.FullName }
if ($null -ne $json) { $out += "JSON: " + $json.FullName }
if ($null -ne $summary) { $out += "Summary TXT: " + $summary.FullName }
$out += ""
$out += "TOP MATCHES"

if ($rows.Count -eq 0) {
    $out += "- CSV was created, but it has no candidate rows. Open Digistore Marketplace, search a finance keyword, then scan again."
}
else {
    $limit = [Math]::Min(10, $rows.Count)
    for ($i = 0; $i -lt $limit; $i++) {
        $row = $rows[$i]
        $score = ""
        $candidate = ""
        $keyword = ""
        $terms = ""

        if ($row.PSObject.Properties.Name -contains "score") { $score = $row.score }
        if ($row.PSObject.Properties.Name -contains "candidate_text") { $candidate = $row.candidate_text }
        if ($row.PSObject.Properties.Name -contains "keyword") { $keyword = $row.keyword }
        if ($row.PSObject.Properties.Name -contains "matched_terms") { $terms = $row.matched_terms }
        if ([string]::IsNullOrWhiteSpace($candidate) -and ($row.PSObject.Properties.Name -contains "nearby_context")) { $candidate = $row.nearby_context }
        if ([string]::IsNullOrWhiteSpace($candidate)) { $candidate = ($row | ConvertTo-Json -Compress) }

        $out += ("" + ($i + 1) + ". [" + $score + "] " + $candidate)
        if (-not [string]::IsNullOrWhiteSpace($keyword) -or -not [string]::IsNullOrWhiteSpace($terms)) {
            $out += "   Keyword: " + $keyword + " | Terms: " + $terms
        }
    }
}

$out += ""
$out += "NEXT ACTIONS"
$out += "1. Open the CSV and inspect the top candidates."
$out += "2. Manually verify the top 3 offers before promoting anything."
$out += "3. Avoid unrealistic claims, gambling, adult, drugs, supplements, or risky finance offers."
$out += "4. Add safe offers to moneycrunch_partner_tracker.csv."

Write-AllReply -Lines $out

[pscustomobject]@{
    flow = "digistore_scan"
    status = "complete"
    finished_at = (Get-Date).ToString("s")
    csv = $csv.FullName
    screenshot = if ($null -ne $png) { $png.FullName } else { "" }
    json = if ($null -ne $json) { $json.FullName } else { "" }
    rows = $rows.Count
} | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Completed from CSV: " + $csv.FullName) -Encoding UTF8
