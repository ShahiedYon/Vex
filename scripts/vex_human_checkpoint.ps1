param(
    [string]$Root = "",
    [string]$Name = "digistore_login",
    [string]$Message = "Vex needs you to log in, then confirm when done.",
    [string]$ConfirmText = "done",
    [int]$TimeoutMinutes = 30,
    [switch]$CreateOnly,
    [switch]$WaitOnly,
    [switch]$MarkDone,
    [switch]$Open
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot }
    else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$workspace = Join-Path $Root "workspace"
$checkpoints = Join-Path $workspace "checkpoints"
$logs = Join-Path $Root "logs"
Ensure-Directory $workspace
Ensure-Directory $checkpoints
Ensure-Directory $logs

$checkpointFile = Join-Path $checkpoints ($Name + ".json")
$doneFile = Join-Path $checkpoints ($Name + ".done")
$messageFile = Join-Path $checkpoints ($Name + "_whatsapp_message.txt")
$logFile = Join-Path $logs "vex_human_checkpoint.log"

if ($MarkDone) {
    Set-Content -Path $doneFile -Value ("done " + (Get-Date).ToString("s")) -Encoding UTF8
    Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Marked done: " + $Name) -Encoding UTF8
    Write-Host "Checkpoint marked done:" -ForegroundColor Green
    Write-Host $doneFile
    exit 0
}

if (-not $WaitOnly) {
    if (Test-Path $doneFile) { Remove-Item -Path $doneFile -Force }

    $payload = [pscustomobject]@{
        name = $Name
        status = "waiting_for_user"
        message = $Message
        confirm_text = $ConfirmText
        created_at = (Get-Date).ToString("s")
        timeout_minutes = $TimeoutMinutes
        done_file = $doneFile
    }

    $payload | ConvertTo-Json -Depth 5 | Set-Content -Path $checkpointFile -Encoding UTF8

    $wa = @()
    $wa += "Vex checkpoint: " + $Name
    $wa += ""
    $wa += $Message
    $wa += ""
    $wa += "When done, reply/trigger Vex with: " + $ConfirmText
    $wa += "Or run this command:"
    $wa += "powershell -ExecutionPolicy Bypass -File .\scripts\vex_human_checkpoint.ps1 -Name " + $Name + " -MarkDone"
    Set-Content -Path $messageFile -Value $wa -Encoding UTF8

    Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Created checkpoint: " + $Name) -Encoding UTF8

    Write-Host "Human checkpoint created:" -ForegroundColor Green
    Write-Host $checkpointFile
    Write-Host ""
    Write-Host "WhatsApp message text:" -ForegroundColor Green
    Write-Host $messageFile

    if ($Open) { notepad $messageFile }
}

if ($CreateOnly) { exit 0 }

Write-Host ""
Write-Host "Waiting for checkpoint confirmation: $Name" -ForegroundColor Yellow
Write-Host "Done file: $doneFile"
Write-Host "Timeout: $TimeoutMinutes minutes"
Write-Host ""

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ((Get-Date) -lt $deadline) {
    if (Test-Path $doneFile) {
        Write-Host "Checkpoint confirmed:" -ForegroundColor Green
        Write-Host $Name
        Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Confirmed checkpoint: " + $Name) -Encoding UTF8
        exit 0
    }
    Start-Sleep -Seconds 5
}

throw "Timed out waiting for checkpoint: $Name"
