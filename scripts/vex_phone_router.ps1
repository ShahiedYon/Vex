param(
    [string]$Root = "",
    [string]$Message = ""
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
$logs = Join-Path $Root "logs"
$replyFile = Join-Path $workspace "vex_last_reply.txt"
$logFile = Join-Path $logs "vex_phone_router.log"

Ensure-Directory $workspace
Ensure-Directory $logs

function Reply {
    param([string]$Text)
    Set-Content -Path $replyFile -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Run-Script {
    param([string]$Script, [string[]]$ArgsList)
    $path = Join-Path $Root ("scripts\" + $Script)
    if (-not (Test-Path $path)) {
        Reply "Missing script: $path"
        exit 1
    }
    $args = @("-ExecutionPolicy", "Bypass", "-File", $path, "-Root", $Root) + $ArgsList
    powershell @args
}

$clean = ($Message + "").Trim()
$lower = $clean.ToLowerInvariant()
Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $clean) -Encoding UTF8

if ($lower -eq "vex money today" -or $lower -eq "money today" -or $lower -eq "vex daily money idea") {
    Run-Script "vex_money_brain.ps1" @()
    exit 0
}

if ($lower -eq "vex daily report" -or $lower -eq "daily report") {
    Run-Script "vex_daily_money_report.ps1" @()
    exit 0
}

if ($lower -eq "approvals" -or $lower -eq "vex approvals" -or $lower -eq "pending approvals") {
    Run-Script "vex_approval_queue.ps1" @("-Action", "list")
    exit 0
}

if ($lower -match "^(approve|reject)\s+(.+)$") {
    $action = $matches[1]
    $target = $matches[2]
    Run-Script "vex_approval_queue.ps1" @("-Action", $action, "-Target", $target)
    exit 0
}

if ($lower -match "^vex\s+create\s+(\d+)\s+(x|twitter|fb|facebook|insta|instagram)\s+posts?\s+(.+)$") {
    $count = $matches[1]
    $platform = $matches[2]
    $stream = $matches[3]
    if ($platform -eq "twitter") { $platform = "x" }
    if ($platform -eq "fb") { $platform = "facebook" }
    if ($platform -eq "insta") { $platform = "instagram" }
    Run-Script "vex_social_draft_queue.ps1" @("-Count", $count, "-Platform", $platform, "-Stream", $stream)
    exit 0
}

if ($lower -match "^vex\s+create\s+(x|twitter|fb|facebook|insta|instagram)\s+posts?\s+(.+)$") {
    $platform = $matches[1]
    $stream = $matches[2]
    if ($platform -eq "twitter") { $platform = "x" }
    if ($platform -eq "fb") { $platform = "facebook" }
    if ($platform -eq "insta") { $platform = "instagram" }
    Run-Script "vex_social_draft_queue.ps1" @("-Count", "3", "-Platform", $platform, "-Stream", $stream)
    exit 0
}

if ($lower -eq "vex check digistore" -or $lower -eq "check digistore") {
    Run-Script "vex_digistore_fullauto_flow.ps1" @()
    exit 0
}

if ($lower -eq "yes" -or $lower -eq "done" -or $lower -eq "logged in") {
    Run-Script "vex_message_router.ps1" @("-Message", "yes")
    exit 0
}

Reply @"
Vex command not recognized yet.

Try:
- vex money today
- vex create 3 x posts moneycrunch
- approvals
- approve 1
- reject 1
- vex daily report
- vex check digistore
"@
