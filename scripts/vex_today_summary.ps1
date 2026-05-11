param(
    [string]$Root = "",
    [switch]$Open
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\vex_env.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = $script:VexRoot
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
    if (-not (Test-Path $Path)) { return "" }
    $fileLines = Get-Content -Path $Path
    for ($i = 0; $i -lt $fileLines.Count; $i++) {
        $line = [string]$fileLines[$i]
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

function Get-FirstPostingItem {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $rows = Import-Csv -Path $Path
    if ($null -eq $rows -or $rows.Count -eq 0) { return $null }
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($rows[$i].stream -eq "debt_relief" -and $rows[$i].platform -eq "X") { return $rows[$i] }
    }
    for ($j = 0; $j -lt $rows.Count; $j++) {
        if ($rows[$j].stream -eq "debt_relief") { return $rows[$j] }
    }
    return $rows[0]
}

function Get-TopOpportunity {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $rows = Import-Csv -Path $Path
    if ($null -eq $rows -or $rows.Count -eq 0) { return $null }
    return $rows[0]
}

$topFocus = Get-FirstUsefulLine -Path $focusFile
$firstPost = Get-FirstPostingItem -Path $queueFile
$topOpp = Get-TopOpportunity -Path $oppsCsvFile

if ([string]::IsNullOrWhiteSpace($topFocus)) {
    $topFocus = "Debt Relief / MoneyCrunch: publish or schedule the first trust-building post."
}

$platform = "X"
$stream = "debt_relief"
$basePost = "Debt X Post 1"
$variation = "V1"
$postContent = "Open the posting queue and use the first Debt Relief post."

if ($null -ne $firstPost) {
    if (-not [string]::IsNullOrWhiteSpace($firstPost.platform)) { $platform = $firstPost.platform }
    if (-not [string]::IsNullOrWhiteSpace($firstPost.stream)) { $stream = $firstPost.stream }
    if (-not [string]::IsNullOrWhiteSpace($firstPost.base_post)) { $basePost = $firstPost.base_post }
    if (-not [string]::IsNullOrWhiteSpace($firstPost.variation)) { $variation = $firstPost.variation }
    if (-not [string]::IsNullOrWhiteSpace($firstPost.content)) { $postContent = $firstPost.content }
}

$oppName = "Debt relief affiliate/referral program shortlist"
$oppNextAction = "Open opportunities.csv and work the highest-priority debt opportunity."
$oppScore = ""

if ($null -ne $topOpp) {
    if ($topOpp.PSObject.Properties.Name -contains "opportunity_name" -and -not [string]::IsNullOrWhiteSpace($topOpp.opportunity_name)) { $oppName = $topOpp.opportunity_name }
    if ($topOpp.PSObject.Properties.Name -contains "next_action" -and -not [string]::IsNullOrWhiteSpace($topOpp.next_action)) { $oppNextAction = $topOpp.next_action }
    if ($topOpp.PSObject.Properties.Name -contains "priority_score" -and -not [string]::IsNullOrWhiteSpace($topOpp.priority_score)) { $oppScore = $topOpp.priority_score }
}

$summary = @(
    "VEX TODAY ACTION SUMMARY",
    "========================",
    "Generated: " + (Get-Date).ToString("s"),
    "",
    "PRIMARY MONEY FOCUS",
    "Debt Relief / MoneyCrunch",
    "",
    "DO THIS FIRST",
    "Platform: " + $platform,
    "Stream: " + $stream,
    "Post: " + $basePost + " / " + $variation,
    "",
    "POST THIS",
    $postContent,
    "",
    "WHY THIS FIRST",
    "Debt Relief is currently the fastest-cash stream. The goal is to build trust, create activity, and support affiliate/referral approval.",
    "",
    "NEXT MONEY TASK",
    "Opportunity: " + $oppName
)

if (-not [string]::IsNullOrWhiteSpace($oppScore)) { $summary += "Priority score: " + $oppScore }

$summary += @(
    "Next action: " + $oppNextAction,
    "",
    "FILES TO OPEN",
    "- Today focus: " + $focusFile,
    "- Posting queue: " + $queueFile,
    "- Debt posts: " + $debtPostsFile,
    "- Solar posts: " + $solarPostsFile,
    "- Opportunities: " + $oppsCsvFile,
    "",
    "NEXT 3 ACTIONS",
    "1. Post or schedule the exact post above.",
    "2. Open opportunities.csv and work the listed opportunity/action.",
    "3. Record the post URL or status in your MoneyCrunch tracking notes.",
    "",
    "COMMAND TO RE-RUN TODAY",
    "powershell -ExecutionPolicy Bypass -File .\scripts\vex_today.ps1"
)

Set-Content -Path $actionFile -Value $summary -Encoding UTF8

Write-Host "Vex Today action summary created:" -ForegroundColor Green
Write-Host $actionFile

if ($Open) {
    notepad $actionFile
}
