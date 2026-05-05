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
$backupDir = Join-Path $Root "_backups\openclaw"
$workspace = Join-Path $Root "workspace"
$brainDir = Join-Path $workspace "brain"
$logs = Join-Path $Root "logs"
$openclawConfig = Join-Path $env:USERPROFILE ".openclaw\openclaw.json"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $backupDir ("openclaw_before_remove_claude_" + $stamp + ".json")
$reportPath = Join-Path $brainDir "vex_claude_removed_report.txt"
$logFile = Join-Path $logs "vex_remove_claude_api.log"

Ensure-Directory $backupDir
Ensure-Directory $workspace
Ensure-Directory $brainDir
Ensure-Directory $logs

if (-not (Test-Path $openclawConfig)) {
    throw "OpenClaw config not found: $openclawConfig"
}

Copy-Item -Path $openclawConfig -Destination $backupPath -Force

$jsonText = Get-Content -Path $openclawConfig -Raw
$cfg = $jsonText | ConvertFrom-Json

$removed = @()

# Keep routing clean.
$cfg.agents.defaults.model.primary = "openai/gpt-4o-mini"
$cfg.agents.defaults.model.fallbacks = @("ollama/mistral:latest")

# Remove Anthropic/Sonnet model config entry if present.
if ($null -ne $cfg.agents.defaults.models) {
    $modelsObj = $cfg.agents.defaults.models
    $props = @($modelsObj.PSObject.Properties.Name)
    foreach ($name in $props) {
        if ($name -like "anthropic/*" -or $name -like "*claude*" -or $name -eq "sonnet") {
            $modelsObj.PSObject.Properties.Remove($name)
            $removed += $name
        }
    }
}

# Remove Anthropic provider if explicitly present in custom providers.
if ($null -ne $cfg.models.providers) {
    $providersObj = $cfg.models.providers
    $providerProps = @($providersObj.PSObject.Properties.Name)
    foreach ($p in $providerProps) {
        if ($p -eq "anthropic") {
            $providersObj.PSObject.Properties.Remove($p)
            $removed += "provider:anthropic"
        }
    }
}

$newJson = $cfg | ConvertTo-Json -Depth 25
Set-Content -Path $openclawConfig -Value $newJson -Encoding UTF8

$report = @()
$report += "VEX CLAUDE / ANTHROPIC REMOVAL REPORT"
$report += "======================================"
$report += "Generated: " + (Get-Date).ToString("s")
$report += "OpenClaw config: " + $openclawConfig
$report += "Backup: " + $backupPath
$report += ""
$report += "ACTIVE ROUTING NOW"
$report += "Primary: openai/gpt-4o-mini"
$report += "Fallbacks: ollama/mistral:latest"
$report += ""
$report += "REMOVED CONFIG ENTRIES"
if ($removed.Count -eq 0) {
    $report += "- No Anthropic/Claude config entries were found in openclaw.json."
}
else {
    foreach ($r in $removed) { $report += "- " + $r }
}
$report += ""
$report += "NOTE"
$report += "This removes Claude/Anthropic from Vex's OpenClaw config. It does not delete any environment variable or auth-profile secret from your machine. If OpenClaw still probes Anthropic after this, it is likely discovering the ANTHROPIC_API_KEY from your environment/auth profile rather than this config."
$report += ""
$report += "NEXT CHECK"
$report += "openclaw models list"
$report += "openclaw models status --probe"

Set-Content -Path $reportPath -Value $report -Encoding UTF8
Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Removed Claude/Anthropic config. Backup: " + $backupPath) -Encoding UTF8

Write-Host "Claude/Anthropic removed from OpenClaw config." -ForegroundColor Green
Write-Host "Backup: $backupPath"
Write-Host "Report: $reportPath"

if ($Open) { notepad $reportPath }
