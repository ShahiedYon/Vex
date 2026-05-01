param(
    [string]$Root = "",
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\vex_env.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = $VexRoot
}

$enqueueScript = Join-Path $VexScripts "vex_money_enqueue.ps1"
$queueRunner = Join-Path $VexScripts "phase10_queue_runner.ps1"
$summaryScript = Join-Path $VexScripts "vex_today_summary.ps1"
$moneySummaryFile = Join-Path $VexWorkspace "vex_money_today.txt"
$actionSummaryFile = Join-Path $VexWorkspace "vex_today_action.txt"
$logsDir = Join-Path $VexWorkspace "logs"
$todayLog = Join-Path $logsDir ("vex_today_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

function Write-TodayLog {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $todayLog -Value $line -Encoding UTF8
    Write-Host $line
}

Write-TodayLog "Starting Vex Today command"
Write-TodayLog ("Root=" + $Root)

if (-not (Test-Path $enqueueScript)) {
    throw "Missing enqueue script: " + $enqueueScript
}

if (-not (Test-Path $queueRunner)) {
    throw "Missing queue runner: " + $queueRunner
}

if (-not (Test-Path $summaryScript)) {
    throw "Missing action summary script: " + $summaryScript
}

Write-TodayLog "Queueing money workflow task"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $enqueueScript -Root $Root

Write-TodayLog "Running queue"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $queueRunner

if (-not (Test-Path $moneySummaryFile)) {
    throw "Money summary file was not created: " + $moneySummaryFile
}

Write-TodayLog "Creating action summary"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $summaryScript -Root $Root

if (-not (Test-Path $actionSummaryFile)) {
    throw "Action summary file was not created: " + $actionSummaryFile
}

Write-TodayLog ("Money summary ready: " + $moneySummaryFile)
Write-TodayLog ("Action summary ready: " + $actionSummaryFile)
Write-TodayLog "Vex Today command complete"

Write-Host ""
Write-Host "Vex Today complete." -ForegroundColor Green
Write-Host "Action summary:"
Write-Host $actionSummaryFile
Write-Host ""
Write-Host "Money workflow summary:"
Write-Host $moneySummaryFile

if (-not $NoOpen) {
    notepad $actionSummaryFile
}
