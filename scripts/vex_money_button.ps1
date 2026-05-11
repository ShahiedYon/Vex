param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\vex_env.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = $script:VexRoot
}

$runner = Join-Path $script:VexScripts "vex_money_run.ps1"
$workspaceDir = Join-Path $Root "workspace"
$logsDir = Join-Path $workspaceDir "logs"
$buttonLog = Join-Path $logsDir ("vex_money_button_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

function Write-ButtonLog {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $buttonLog -Value $line -Encoding UTF8
    Write-Host $line
}

Write-ButtonLog "Vex money button pressed"
Write-ButtonLog "Root=$Root"

if (-not (Test-Path $runner)) {
    throw "Missing money runner: $runner"
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Root $Root

$summaryFile = Join-Path $workspaceDir "vex_money_today.txt"

Write-ButtonLog "Vex money button complete"
Write-ButtonLog "Summary=$summaryFile"

Write-Host ""
Write-Host "Vex money button complete." -ForegroundColor Green
Write-Host "Open summary:"
Write-Host $summaryFile
