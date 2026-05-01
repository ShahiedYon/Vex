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
$summaryFile = Join-Path $VexWorkspace "vex_money_today.txt"
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

Write-TodayLog "Queueing money workflow task"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $enqueueScript -Root $Root

Write-TodayLog "Running queue"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $queueRunner

if (-not (Test-Path $summaryFile)) {
    throw "Summary file was not created: " + $summaryFile
}

Write-TodayLog ("Summary ready: " + $summaryFile)
Write-TodayLog "Vex Today command complete"

Write-Host ""
Write-Host "Vex Today complete." -ForegroundColor Green
Write-Host "Summary:"
Write-Host $summaryFile

if (-not $NoOpen) {
    notepad $summaryFile
}
