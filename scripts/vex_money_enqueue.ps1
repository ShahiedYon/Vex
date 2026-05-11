param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\vex_env.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = $script:VexRoot
}

$pendingDir = Join-Path $script:VexTasks "queue\pending"
$workspaceDir = Join-Path $Root "workspace"
$logsDir = Join-Path $Root "logs"

New-Item -ItemType Directory -Force -Path $pendingDir | Out-Null
New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$taskFile = Join-Path $pendingDir ("vex_money_button_" + $timestamp + ".txt")
$outputText = Join-Path $workspaceDir ("vex_money_queue_result_" + $timestamp + ".txt")
$outputLog = Join-Path $logsDir ("vex_money_queue_" + $timestamp + ".log")

$taskLines = @(
    "TASK_NAME: Vex Money Button",
    "TASK_TYPE: vex.money_button",
    "TARGET: run_daily_money_workflow",
    "OUTPUT_TEXT: " + $outputText,
    "OUTPUT_LOG: " + $outputLog,
    "APPROVED: yes"
)

Set-Content -Path $taskFile -Value $taskLines -Encoding UTF8

Write-Host "Queued Vex money button task:" -ForegroundColor Green
Write-Host $taskFile
Write-Host ""
Write-Host "Run queue with:"
Write-Host "powershell -ExecutionPolicy Bypass -File .\scripts\phase10_queue_runner.ps1"
