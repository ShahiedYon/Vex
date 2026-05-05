param(
    [string]$Root = "",
    [switch]$Open
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) {
        $Root = Split-Path -Parent $PSScriptRoot
    }
    else {
        $Root = (Get-Location).Path
    }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$workspace = Join-Path $Root "workspace"
$partners = Join-Path $workspace "partners"
$logs = Join-Path $Root "logs"

Ensure-Directory $workspace
Ensure-Directory $partners
Ensure-Directory $logs

$tracker = Join-Path $partners "moneycrunch_partner_tracker.csv"
$actionFile = Join-Path $workspace "moneycrunch_partner_next_actions.txt"
$logFile = Join-Path $logs "vex_partner_tracker.log"

$headers = "date_added,partner_name,category,website,application_url,status,login_email,notes,next_action,priority"

$seedRows = @(
    [pscustomobject]@{
        date_added = (Get-Date -Format "yyyy-MM-dd")
        partner_name = "CJ Affiliate"
        category = "affiliate_network"
        website = "CJ Affiliate"
        application_url = ""
        status = "not_started"
        login_email = ""
        notes = "Use MoneyCrunch live site. Emphasize debt relief lead generation and compliant consent wording."
        next_action = "Log in or apply; confirm whether MoneyCrunch profile/site is accepted."
        priority = "high"
    },
    [pscustomobject]@{
        date_added = (Get-Date -Format "yyyy-MM-dd")
        partner_name = "Digistore24"
        category = "marketplace"
        website = "Digistore24"
        application_url = ""
        status = "not_started"
        login_email = ""
        notes = "Look for finance, debt, credit, budgeting, or consumer-help offers."
        next_action = "Search marketplace manually and record promising offers."
        priority = "high"
    },
    [pscustomobject]@{
        date_added = (Get-Date -Format "yyyy-MM-dd")
        partner_name = "Debt Relief / Finance Lead Buyers"
        category = "direct_partner"
        website = ""
        application_url = ""
        status = "research_needed"
        login_email = ""
        notes = "Find lead buyers/referral partners that accept U.S. debt relief traffic. Avoid unrealistic claims."
        next_action = "Research 5 candidate partners and add each as its own row."
        priority = "high"
    },
    [pscustomobject]@{
        date_added = (Get-Date -Format "yyyy-MM-dd")
        partner_name = "Impact / Finance Programs"
        category = "affiliate_network"
        website = "Impact"
        application_url = ""
        status = "watch_later"
        login_email = ""
        notes = "Use later if prior application blocks are resolved."
        next_action = "Do not spend time here until easier paths are tested."
        priority = "medium"
    },
    [pscustomobject]@{
        date_added = (Get-Date -Format "yyyy-MM-dd")
        partner_name = "MoneyCrunch Manual Lead Intake"
        category = "fallback"
        website = "https://moneycrunchusa.netlify.app/"
        application_url = ""
        status = "active"
        login_email = ""
        notes = "Fallback path: capture leads first, then route manually once partner is approved."
        next_action = "Keep form live and test submissions after each deploy."
        priority = "high"
    }
)

if (-not (Test-Path $tracker)) {
    $seedRows | Export-Csv -Path $tracker -NoTypeInformation -Encoding UTF8
    Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Created tracker: " + $tracker) -Encoding UTF8
}
else {
    $existing = Import-Csv -Path $tracker
    $existingNames = @{}
    foreach ($row in $existing) {
        if ($row.partner_name) { $existingNames[$row.partner_name] = $true }
    }

    $toAdd = @()
    foreach ($seed in $seedRows) {
        if (-not $existingNames.ContainsKey($seed.partner_name)) {
            $toAdd += $seed
        }
    }

    if ($toAdd.Count -gt 0) {
        $toAdd | Export-Csv -Path $tracker -NoTypeInformation -Append -Encoding UTF8
        Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Appended missing seed rows: " + $toAdd.Count) -Encoding UTF8
    }
    else {
        Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Tracker already up to date") -Encoding UTF8
    }
}

$rows = Import-Csv -Path $tracker
$high = @()
foreach ($row in $rows) {
    if ($row.priority -eq "high" -and $row.status -ne "approved" -and $row.status -ne "rejected") {
        $high += $row
    }
}

$out = @()
$out += "MONEYCRUNCH PARTNER TRACKER"
$out += "==========================="
$out += "Generated: " + (Get-Date).ToString("s")
$out += "Tracker: " + $tracker
$out += ""
$out += "CURRENT PRIORITY"
$out += "Use the live MoneyCrunch URL for affiliate/referral applications: https://moneycrunchusa.netlify.app/"
$out += ""
$out += "HIGH-PRIORITY NEXT ACTIONS"
if ($high.Count -eq 0) {
    $out += "- No high-priority pending rows found. Review tracker manually."
}
else {
    for ($i = 0; $i -lt $high.Count; $i++) {
        $item = $high[$i]
        $out += ("" + ($i + 1) + ". " + $item.partner_name + " [" + $item.status + "]")
        $out += "   Next: " + $item.next_action
        if (-not [string]::IsNullOrWhiteSpace($item.notes)) {
            $out += "   Notes: " + $item.notes
        }
    }
}
$out += ""
$out += "STATUS VALUES TO USE"
$out += "not_started, research_needed, applied, pending, approved, rejected, follow_up_needed, watch_later, active"
$out += ""
$out += "NEXT 3 MONEY ACTIONS"
$out += "1. Apply/login to CJ Affiliate using the MoneyCrunch site."
$out += "2. Search Digistore24 for finance/debt/credit/budgeting offers and record candidates."
$out += "3. Research 5 direct debt/finance lead buyers and add rows to the tracker."
$out += ""
$out += "COMMANDS"
$out += "notepad " + $tracker
$out += "notepad " + $actionFile

Set-Content -Path $actionFile -Value $out -Encoding UTF8

Write-Host "MoneyCrunch partner tracker ready:" -ForegroundColor Green
Write-Host $tracker
Write-Host ""
Write-Host "Next-actions file:" -ForegroundColor Green
Write-Host $actionFile

if ($Open) {
    notepad $actionFile
    notepad $tracker
}
