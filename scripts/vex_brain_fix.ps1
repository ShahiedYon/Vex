param(
    [string]$Root = "",
    [switch]$Apply,
    [switch]$Open
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function Write-LogLine {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

function Get-CommandOutput {
    param([string]$Command)
    try {
        $out = powershell -NoProfile -ExecutionPolicy Bypass -Command $Command 2>&1
        return ($out | Out-String).Trim()
    }
    catch {
        return $_.Exception.Message
    }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$workspace = Join-Path $Root "workspace"
$logs = Join-Path $Root "logs"
$memory = Join-Path $Root "memory"
$config = Join-Path $Root "config"
$brainDir = Join-Path $workspace "brain"
$backupDir = Join-Path $Root "_backups\openclaw"
$openclawConfig = Join-Path $env:USERPROFILE ".openclaw\openclaw.json"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $brainDir "vex_brain_audit.txt"
$logFile = Join-Path $logs "vex_brain_fix.log"

Ensure-Directory $workspace
Ensure-Directory $logs
Ensure-Directory $brainDir
Ensure-Directory $backupDir

Write-LogLine "Starting Vex brain fix/audit"
Write-LogLine "Root: $Root"

if (-not (Test-Path $openclawConfig)) {
    throw "OpenClaw config not found: $openclawConfig"
}

$backupPath = Join-Path $backupDir ("openclaw_" + $stamp + ".json")
Copy-Item -Path $openclawConfig -Destination $backupPath -Force
Write-LogLine "Backed up OpenClaw config to: $backupPath"

$jsonText = Get-Content -Path $openclawConfig -Raw
$cfg = $jsonText | ConvertFrom-Json

$currentPrimary = ""
$currentFallbacks = @()
try { $currentPrimary = $cfg.agents.defaults.model.primary } catch {}
try { $currentFallbacks = @($cfg.agents.defaults.model.fallbacks) } catch {}

$recommendedPrimary = "openai/gpt-4o-mini"
$recommendedFallbacks = @("ollama/mistral:latest")
$brokenOrPaused = @("anthropic/claude-sonnet-4-6")

if ($Apply) {
    if ($null -eq $cfg.agents) { $cfg | Add-Member -MemberType NoteProperty -Name agents -Value ([pscustomobject]@{}) }
    if ($null -eq $cfg.agents.defaults) { $cfg.agents | Add-Member -MemberType NoteProperty -Name defaults -Value ([pscustomobject]@{}) }
    if ($null -eq $cfg.agents.defaults.model) { $cfg.agents.defaults | Add-Member -MemberType NoteProperty -Name model -Value ([pscustomobject]@{}) }

    $cfg.agents.defaults.model.primary = $recommendedPrimary
    $cfg.agents.defaults.model.fallbacks = $recommendedFallbacks

    if ($null -eq $cfg.agents.defaults.models) { $cfg.agents.defaults | Add-Member -MemberType NoteProperty -Name models -Value ([pscustomobject]@{}) }

    $newJson = $cfg | ConvertTo-Json -Depth 20
    Set-Content -Path $openclawConfig -Value $newJson -Encoding UTF8
    Write-LogLine "Applied model routing fix. Primary=$recommendedPrimary; Fallbacks=$($recommendedFallbacks -join ', ')"
}
else {
    Write-LogLine "Audit only. No config changes applied. Use -Apply to update OpenClaw routing."
}

$modelsList = Get-CommandOutput "openclaw models list"
$modelsProbe = Get-CommandOutput "openclaw models status --probe"
$channelsProbe = Get-CommandOutput "openclaw channels status --probe"

$memoryFiles = @()
if (Test-Path $memory) {
    $memoryFiles = Get-ChildItem -Path $memory -File -ErrorAction SilentlyContinue | Sort-Object Name
}

$configFiles = @()
if (Test-Path $config) {
    $configFiles = Get-ChildItem -Path $config -File -ErrorAction SilentlyContinue | Sort-Object Name
}

$report = @()
$report += "VEX BRAIN AUDIT"
$report += "==============="
$report += "Generated: " + (Get-Date).ToString("s")
$report += "Root: " + $Root
$report += "OpenClaw config: " + $openclawConfig
$report += "Backup created: " + $backupPath
$report += "Apply mode: " + $Apply
$report += ""
$report += "MODEL ROUTING"
$report += "Current primary before script: " + $currentPrimary
$report += "Current fallbacks before script: " + ($currentFallbacks -join ", ")
if ($Apply) {
    $report += "New primary: " + $recommendedPrimary
    $report += "New fallbacks: " + ($recommendedFallbacks -join ", ")
    $report += "Paused/bypassed model: " + ($brokenOrPaused -join ", ")
} else {
    $report += "Recommended primary: " + $recommendedPrimary
    $report += "Recommended fallbacks: " + ($recommendedFallbacks -join ", ")
    $report += "Recommended paused/bypassed model: " + ($brokenOrPaused -join ", ")
}
$report += ""
$report += "MEMORY FILES"
if ($memoryFiles.Count -eq 0) {
    $report += "- No memory files found."
}
else {
    foreach ($f in $memoryFiles) {
        $report += "- " + $f.Name + " (" + $f.Length + " bytes)"
    }
}
$report += ""
$report += "CONFIG FILES"
if ($configFiles.Count -eq 0) {
    $report += "- No config files found."
}
else {
    foreach ($f in $configFiles) {
        $report += "- " + $f.Name + " (" + $f.Length + " bytes)"
    }
}
$report += ""
$report += "OPENCLAW MODELS LIST"
$report += "--------------------"
$report += $modelsList
$report += ""
$report += "OPENCLAW MODELS STATUS PROBE"
$report += "----------------------------"
$report += $modelsProbe
$report += ""
$report += "OPENCLAW CHANNELS STATUS PROBE"
$report += "------------------------------"
$report += $channelsProbe
$report += ""
$report += "INTERPRETATION"
$report += "- If Anthropic still shows billing error, keep it out of primary routing until credits are restored."
$report += "- If OpenAI probes ok, use openai/gpt-4o-mini as the stable primary for now."
$report += "- If Ollama times out, keep it as low-cost fallback but do not depend on it for urgent workflows until probed clean."
$report += "- Memory files exist locally, but this audit cannot prove OpenClaw injects them into every chat unless we run a prompt test through the active channel/model."
$report += ""
$report += "NEXT TEST"
$report += "After applying, run:"
$report += "openclaw models status --probe"
$report += "Then message Vex on WhatsApp: Who are you and what is your mission?"

Set-Content -Path $reportFile -Value $report -Encoding UTF8
Write-LogLine "Brain audit report created: $reportFile"

Write-Host ""
Write-Host "Vex brain audit report:" -ForegroundColor Green
Write-Host $reportFile
Write-Host ""
if (-not $Apply) {
    Write-Host "No config change was applied. To apply recommended model routing, run:" -ForegroundColor Yellow
    Write-Host "powershell -ExecutionPolicy Bypass -File .\scripts\vex_brain_fix.ps1 -Apply -Open" -ForegroundColor White
}
else {
    Write-Host "Model routing fix applied. Restart OpenClaw gateway if needed, then probe models again." -ForegroundColor Green
}

if ($Open) {
    notepad $reportFile
}
