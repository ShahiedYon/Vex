param(
    [string]$Root = "",
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\vex_env.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = $script:VexRoot
}

$runner = Join-Path $script:VexScripts "vex_money_run.ps1"
$summaryScript = Join-Path $script:VexScripts "vex_today_summary.ps1"
$actionSummaryFile = Join-Path $script:VexWorkspace "vex_today_action.txt"

if (-not (Test-Path $runner)) {
    throw "Missing money workflow runner: $runner"
}

if (-not (Test-Path $summaryScript)) {
    throw "Missing today summary script: $summaryScript"
}

Write-Host "Starting Vex Today..." -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Root $Root
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $summaryScript -Root $Root

Write-Host ""
Write-Host "Vex Today complete." -ForegroundColor Green
Write-Host "Action summary:"
Write-Host $actionSummaryFile

if (-not $NoOpen) {
    notepad $actionSummaryFile
}
