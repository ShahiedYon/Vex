param(
    [string]$Root = "",
    [string]$Prompt = "Who are you?",
    [string]$PromptFile = "",
    [string]$Model = "vex-qwen3:4b",
    [switch]$Save,
    [switch]$Quiet
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
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outFile = Join-Path $brainDir ("vex_qwen_reply_" + $stamp + ".txt")
$lastFile = Join-Path $workspace "vex_local_qwen_last_reply.txt"
$logFile = Join-Path $logs "vex_local_qwen.log"

Ensure-Directory $workspace
Ensure-Directory $brainDir
Ensure-Directory $logs

if (-not [string]::IsNullOrWhiteSpace($PromptFile)) {
    if (-not (Test-Path $PromptFile)) { throw "Prompt file not found: $PromptFile" }
    $Prompt = Get-Content -Path $PromptFile -Raw
}

if (-not $Quiet) {
    Write-Host "Running local Vex Qwen..." -ForegroundColor Cyan
    Write-Host "Model: $Model" -ForegroundColor DarkGray
    if (-not [string]::IsNullOrWhiteSpace($PromptFile)) { Write-Host "Prompt file: $PromptFile" -ForegroundColor DarkGray }
    Write-Host "Prompt length: $($Prompt.Length) chars" -ForegroundColor DarkGray
    Write-Host ""
}

try {
    $reply = & ollama run $Model --hidethinking $Prompt 2>&1 | Out-String
    $reply = $reply.Trim()
}
catch {
    $reply = "ERROR: " + $_.Exception.Message
}

Write-Host $reply
Set-Content -Path $lastFile -Value $reply -Encoding UTF8
Add-Content -Path $logFile -Value ("[" + $stamp + "] Model: " + $Model) -Encoding UTF8
Add-Content -Path $logFile -Value ("[" + $stamp + "] Prompt length: " + $Prompt.Length) -Encoding UTF8
Add-Content -Path $logFile -Value ("[" + $stamp + "] Reply length: " + $reply.Length) -Encoding UTF8

if ($Save) {
    Set-Content -Path $outFile -Value $reply -Encoding UTF8
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "Saved reply:" -ForegroundColor Green
        Write-Host $outFile
    }
}
