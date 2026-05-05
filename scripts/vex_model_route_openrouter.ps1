param(
    [string]$Root = "",
    [switch]$Open
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$workspace = Join-Path $Root "workspace"
$brainDir = Join-Path $workspace "brain"
$logs = Join-Path $Root "logs"
$backupDir = Join-Path $Root "_backups\openclaw"
$openclawConfig = Join-Path $env:USERPROFILE ".openclaw\openclaw.json"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $backupDir ("openclaw_before_openrouter_route_" + $stamp + ".json")
$reportPath = Join-Path $brainDir "vex_model_route_report.txt"
$logFile = Join-Path $logs "vex_model_route_openrouter.log"

Ensure-Directory $workspace
Ensure-Directory $brainDir
Ensure-Directory $logs
Ensure-Directory $backupDir

if (-not (Test-Path $openclawConfig)) {
    throw "OpenClaw config not found: $openclawConfig"
}

Copy-Item -Path $openclawConfig -Destination $backupPath -Force

$cfg = Get-Content -Path $openclawConfig -Raw | ConvertFrom-Json

if ($null -eq $cfg.agents) { $cfg | Add-Member -MemberType NoteProperty -Name agents -Value ([pscustomobject]@{}) }
if ($null -eq $cfg.agents.defaults) { $cfg.agents | Add-Member -MemberType NoteProperty -Name defaults -Value ([pscustomobject]@{}) }
if ($null -eq $cfg.agents.defaults.model) { $cfg.agents.defaults | Add-Member -MemberType NoteProperty -Name model -Value ([pscustomobject]@{}) }
if ($null -eq $cfg.agents.defaults.models) { $cfg.agents.defaults | Add-Member -MemberType NoteProperty -Name models -Value ([pscustomobject]@{}) }

$cfg.agents.defaults.model.primary = "openai/gpt-4o-mini"
$cfg.agents.defaults.model.fallbacks = @("openrouter/ai21/jamba-large-1.7", "ollama/mistral:latest")

$modelsObj = $cfg.agents.defaults.models
$existing = @($modelsObj.PSObject.Properties.Name)
if ($existing -notcontains "openai/gpt-4o-mini") {
    $modelsObj | Add-Member -MemberType NoteProperty -Name "openai/gpt-4o-mini" -Value ([pscustomobject]@{})
}
if ($existing -notcontains "openrouter/ai21/jamba-large-1.7") {
    $modelsObj | Add-Member -MemberType NoteProperty -Name "openrouter/ai21/jamba-large-1.7" -Value ([pscustomobject]@{})
}
if ($existing -notcontains "ollama/mistral:latest") {
    $modelsObj | Add-Member -MemberType NoteProperty -Name "ollama/mistral:latest" -Value ([pscustomobject]@{})
}

$cfg | ConvertTo-Json -Depth 25 | Set-Content -Path $openclawConfig -Encoding UTF8

$modelsList = powershell -NoProfile -ExecutionPolicy Bypass -Command "openclaw models list" 2>&1 | Out-String
$modelsProbe = powershell -NoProfile -ExecutionPolicy Bypass -Command "openclaw models status --probe" 2>&1 | Out-String

$report = @()
$report += "VEX MODEL ROUTE REPORT"
$report += "======================"
$report += "Generated: " + (Get-Date).ToString("s")
$report += "OpenClaw config: " + $openclawConfig
$report += "Backup: " + $backupPath
$report += ""
$report += "ACTIVE ROUTING"
$report += "Primary: openai/gpt-4o-mini"
$report += "Fallback #1: openrouter/ai21/jamba-large-1.7"
$report += "Fallback #2: ollama/mistral:latest"
$report += ""
$report += "WHY"
$report += "- OpenAI is the reliable primary right now."
$report += "- OpenRouter probed OK and gives a cloud fallback."
$report += "- Ollama remains the zero-cost local fallback, but needs timeout tuning."
$report += ""
$report += "OPENCLAW MODELS LIST"
$report += "--------------------"
$report += $modelsList
$report += ""
$report += "OPENCLAW MODELS PROBE"
$report += "---------------------"
$report += $modelsProbe
$report += ""
$report += "NEXT"
$report += "Run: powershell -ExecutionPolicy Bypass -File .\scripts\vex_ollama_diagnostic.ps1 -Open"

Set-Content -Path $reportPath -Value $report -Encoding UTF8
Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Model route updated. Backup: " + $backupPath) -Encoding UTF8

Write-Host "Vex model route updated." -ForegroundColor Green
Write-Host "Primary: openai/gpt-4o-mini"
Write-Host "Fallback #1: openrouter/ai21/jamba-large-1.7"
Write-Host "Fallback #2: ollama/mistral:latest"
Write-Host "Report: $reportPath"

if ($Open) { notepad $reportPath }
