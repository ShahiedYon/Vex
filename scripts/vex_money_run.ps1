param(
    [string]$Root = "",
    [switch]$SkipOpportunities,
    [switch]$SkipCampaignPlan,
    [switch]$SkipPostVariations
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\vex_env.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = $VexRoot
}

$workspaceDir = Join-Path $Root "workspace"
$logsDir = Join-Path $workspaceDir "logs"
$campaignsDir = Join-Path $workspaceDir "campaigns"
$opportunitiesDir = Join-Path $workspaceDir "opportunities"

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
New-Item -ItemType Directory -Force -Path $campaignsDir | Out-Null
New-Item -ItemType Directory -Force -Path $opportunitiesDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logsDir ("vex_money_run_" + $timestamp + ".log")
$summaryFile = Join-Path $workspaceDir "vex_money_today.txt"

function Write-RunLog {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

function Invoke-VexPhase {
    param(
        [string]$Name,
        [string]$ScriptPath
    )

    if (-not (Test-Path $ScriptPath)) {
        throw "Missing script for " + $Name + ": " + $ScriptPath
    }

    Write-RunLog ("Starting " + $Name)
    & $ScriptPath -Root $Root
    Write-RunLog ("Completed " + $Name)
}

Write-RunLog "Starting Vex money workflow"
Write-RunLog ("Root=" + $Root)

if (-not $SkipOpportunities) {
    Invoke-VexPhase -Name "Phase 14e opportunity ranking" -ScriptPath (Join-Path $VexScripts "phase14e_run.ps1")
}
else {
    Write-RunLog "Skipped Phase 14e opportunity ranking"
}

if (-not $SkipCampaignPlan) {
    Invoke-VexPhase -Name "Phase 16e campaign starter" -ScriptPath (Join-Path $VexScripts "phase16e_run.ps1")
}
else {
    Write-RunLog "Skipped Phase 16e campaign starter"
}

if (-not $SkipPostVariations) {
    Invoke-VexPhase -Name "Phase 16f post variation engine" -ScriptPath (Join-Path $VexScripts "phase16f_run.ps1")
}
else {
    Write-RunLog "Skipped Phase 16f post variation engine"
}

$summary = @()
$summary += "VEX MONEY RUN SUMMARY"
$summary += "====================="
$summary += "Generated: " + (Get-Date).ToString("s")
$summary += ""
$summary += "Main outputs:"
$summary += "- Opportunities JSON: " + (Join-Path $opportunitiesDir "opportunities.json")
$summary += "- Opportunities CSV: " + (Join-Path $opportunitiesDir "opportunities.csv")
$summary += "- Debt week 1 posts: " + (Join-Path $campaignsDir "debt_week1_posts.txt")
$summary += "- Solar week 1 posts: " + (Join-Path $campaignsDir "solar_week1_posts.txt")
$summary += "- Week 1 campaign plan: " + (Join-Path $campaignsDir "week1_campaign_plan.csv")
$summary += "- Today posting focus: " + (Join-Path $campaignsDir "today_posting_focus.txt")
$summary += "- Debt post variations: " + (Join-Path $campaignsDir "debt_post_variations.txt")
$summary += "- Solar post variations: " + (Join-Path $campaignsDir "solar_post_variations.txt")
$summary += "- Posting variation queue: " + (Join-Path $campaignsDir "posting_variation_queue.csv")
$summary += ""
$summary += "Recommended next action:"
$summary += "Open today_posting_focus.txt, then post or schedule the first Debt Relief item."
$summary += ""
$summary += "Log file: " + $logFile

Set-Content -Path $summaryFile -Value $summary -Encoding UTF8

Write-RunLog ("Summary created: " + $summaryFile)
Write-RunLog "Vex money workflow complete"

Write-Host ""
Write-Host "Vex money workflow complete." -ForegroundColor Green
Write-Host "Summary:"
Write-Host $summaryFile
