param(
    [string]$Root = "",
    [switch]$Open
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\vex_env.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = $VexRoot
}

$workspaceDir = Join-Path $Root "workspace"
$campaignsDir = Join-Path $workspaceDir "campaigns"
$oppsDir = Join-Path $workspaceDir "opportunities"
$actionFile = Join-Path $workspaceDir "vex_today_action.txt"

$focusFile = Join-Path $campaignsDir "today_posting_focus.txt"
$queueFile = Join-Path $campaignsDir "posting_variation_queue.csv"
$debtPostsFile = Join-Path $campaignsDir "debt_week1_posts.txt"
$solarPostsFile = Join-Path $campaignsDir "solar_week1_posts.txt"
$oppsCsvFile = Join-Path $oppsDir "opportunities.csv"

function Get-FirstUsefulLine {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return ""
    }

    $lines = Get-Content -Path $Path
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match "^=+$") { continue }
        if ($line -match "TODAY POSTING FOCUS") { continue }
        if ($line -match "DEBT RELIEF") { continue }
        if ($line -match "SOLAR") { continue }
        if ($line -match "X POSTS") { continue }
        if ($line -match "FACEBOOK POSTS") { continue }
        return $line.Trim()
    }

    return ""
}

$topFocus = Get-FirstUsefulLine -Path $focusFile
$firstDebtPost = Get-FirstUsefulLine -Path $debtPostsFile

if ([string]::IsNullOrWhiteSpace($topFocus)) {
    $topFocus = "Debt Relief / MoneyCrunch: publish or schedule the first trust-building post."
}

if ([string]::IsNullOrWhiteSpace($firstDebtPost)) {
    $firstDebtPost = "Open the debt posts file and use the first available post."
}

$summary = @()
$summary += "VEX TODAY ACTION SUMMARY"
$summary += "========================"
$summary += "Generated: " + (Get-Date).ToString("s")
$summary += ""
$summary += "PRIMARY MONEY FOCUS"
$summary += "Debt Relief / MoneyCrunch"
$summary += ""
$summary += "DO THIS FIRST"
$summary += $topFocus
$summary += ""
$summary += "FIRST POST CANDIDATE"
$summary += $firstDebtPost
$summary += ""
$summary += "WHY THIS FIRST"
$summary += "Debt Relief is currently the fastest-cash stream. The goal is to build trust, create activity, and support affiliate/referral approval."
$summary += ""
$summary += "FILES TO OPEN"
$summary += "- Today focus: " + $focusFile
$summary += "- Posting queue: " + $queueFile
$summary += "- Debt posts: " + $debtPostsFile
$summary += "- Solar posts: " + $solarPostsFile
$summary += "- Opportunities: " + $oppsCsvFile
$summary += ""
$summary += "NEXT 3 ACTIONS"
$summary += "1. Post or schedule the first Debt Relief item."
$summary += "2. Open opportunities.csv and check the highest-priority debt item."
$summary += "3. After posting, note the post link or status in your MoneyCrunch tracking file."
$summary += ""
$summary += "COMMAND TO RE-RUN TODAY"
$summary += "powershell -ExecutionPolicy Bypass -File .\scripts\vex_today.ps1"

Set-Content -Path $actionFile -Value $summary -Encoding UTF8

Write-Host "Vex Today action summary created:" -ForegroundColor Green
Write-Host $actionFile

if ($Open) {
    notepad $actionFile
}
