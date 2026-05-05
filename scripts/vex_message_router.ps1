param(
    [string]$Root = "",
    [string]$Message = "",
    [string]$From = ""
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
$digistore = Join-Path $workspace "digistore"
$checkpoints = Join-Path $workspace "checkpoints"
$logs = Join-Path $Root "logs"
$replyFile = Join-Path $workspace "vex_last_reply.txt"
$digistoreReply = Join-Path $digistore "digistore_flow_reply.txt"
$digistoreFlow = Join-Path $Root "scripts\vex_digistore_flow.ps1"
$doneFile = Join-Path $checkpoints "digistore_login.done"
$logFile = Join-Path $logs "vex_message_router.log"

Ensure-Directory $workspace
Ensure-Directory $digistore
Ensure-Directory $checkpoints
Ensure-Directory $logs

$clean = ($Message + "").Trim().ToLowerInvariant()
Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] From=" + $From + " Message=" + $Message) -Encoding UTF8

if ($clean -eq "vex check digistore" -or $clean -eq "check digistore" -or $clean -eq "digistore scan") {
    Set-Content -Path $replyFile -Value "Starting Digistore scan. I will open Digistore now. Log in and open Affiliate Marketplace, then reply yes." -Encoding UTF8
    Start-Process powershell -ArgumentList @("-ExecutionPolicy", "Bypass", "-File", $digistoreFlow, "-Root", $Root) -WindowStyle Normal
    Write-Host (Get-Content -Path $replyFile -Raw)
    exit 0
}

if ($clean -eq "yes" -or $clean -eq "done" -or $clean -eq "logged in" -or $clean -eq "i am in" -or $clean -eq "marketplace ready") {
    Set-Content -Path $doneFile -Value ("confirmed " + (Get-Date).ToString("s")) -Encoding UTF8
    Set-Content -Path $replyFile -Value "Confirmed. Vex will continue the Digistore scan now." -Encoding UTF8
    Write-Host (Get-Content -Path $replyFile -Raw)
    exit 0
}

if ($clean -eq "digistore status" -or $clean -eq "vex digistore status") {
    if (Test-Path $digistoreReply) {
        Copy-Item -Path $digistoreReply -Destination $replyFile -Force
    }
    else {
        Set-Content -Path $replyFile -Value "No Digistore scan reply found yet." -Encoding UTF8
    }
    Write-Host (Get-Content -Path $replyFile -Raw)
    exit 0
}

Set-Content -Path $replyFile -Value "Vex did not recognize that command yet. Try: vex check digistore" -Encoding UTF8
Write-Host (Get-Content -Path $replyFile -Raw)
