param(
    [string]$Root = "",
    [switch]$Open
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function Read-FileSafe {
    param([string]$Path)
    if (Test-Path $Path) { return (Get-Content -Path $Path -Raw) }
    return ""
}

function Count-Files {
    param([string]$Path)
    if (Test-Path $Path) { return @(Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue).Count }
    return 0
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$workspace = Join-Path $Root "workspace"
$money = Join-Path $workspace "money"
$social = Join-Path $workspace "social"
$partners = Join-Path $workspace "partners"
$digistore = Join-Path $workspace "digistore"
$approvals = Join-Path $workspace "approvals"
$pending = Join-Path $approvals "pending"
$approved = Join-Path $approvals "approved"
$rejected = Join-Path $approvals "rejected"
$logs = Join-Path $Root "logs"

Ensure-Directory $workspace
Ensure-Directory $money
Ensure-Directory $social
Ensure-Directory $partners
Ensure-Directory $digistore
Ensure-Directory $approvals
Ensure-Directory $pending
Ensure-Directory $approved
Ensure-Directory $rejected
Ensure-Directory $logs

$today = Get-Date -Format "yyyy-MM-dd"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $money ("daily_money_report_" + $today + ".txt")
$latestReport = Join-Path $money "daily_money_report_latest.txt"
$replyFile = Join-Path $workspace "vex_last_reply.txt"
$logFile = Join-Path $logs "vex_daily_money_report.log"

$moneyIdea = Read-FileSafe (Join-Path $money "daily_money_idea_latest.txt")
$siteAction = Read-FileSafe (Join-Path $workspace "moneycrunch_site_action.txt")
$partnerActions = Read-FileSafe (Join-Path $workspace "moneycrunch_partner_next_actions.txt")
$digistoreReply = Read-FileSafe (Join-Path $digistore "digistore_flow_reply.txt")
$localQwen = Join-Path $Root "scripts\vex_local_qwen.ps1"
$opportunityTracker = Join-Path $money "opportunity_radar.csv"
$partnerTracker = Join-Path $partners "moneycrunch_partner_tracker.csv"
$socialCalendar = Join-Path $social "social_calendar.csv"

$pendingCount = Count-Files $pending
$approvedCount = Count-Files $approved
$rejectedCount = Count-Files $rejected

$opportunityRows = 0
if (Test-Path $opportunityTracker) { try { $opportunityRows = @(Import-Csv $opportunityTracker).Count } catch { $opportunityRows = 0 } }
$partnerRows = 0
if (Test-Path $partnerTracker) { try { $partnerRows = @(Import-Csv $partnerTracker).Count } catch { $partnerRows = 0 } }
$socialRows = 0
if (Test-Path $socialCalendar) { try { $socialRows = @(Import-Csv $socialCalendar).Count } catch { $socialRows = 0 } }

$prompt = @"
You are Vex, Shahied's money-focused OpenClaw operator.

Create a concise daily money report from the local state below.

Today's daily money idea:
$moneyIdea

MoneyCrunch site action:
$siteAction

Partner actions:
$partnerActions

Digistore status:
$digistoreReply

Counts:
Opportunity tracker rows: $opportunityRows
Partner tracker rows: $partnerRows
Social calendar rows: $socialRows
Pending approvals: $pendingCount
Approved items: $approvedCount
Rejected items: $rejectedCount

Output format exactly:
VEX DAILY MONEY REPORT
======================
Status:
Top win:
Main blocker:
Today's best next action:
Pending approvals:
Partner follow-up:
Content/social next step:
One new idea to consider tomorrow:
Decision needed from Shahied:
"@

$report = ""
if (Test-Path $localQwen) {
    try {
        $escaped = $prompt.Replace('"','`"')
        $report = powershell -ExecutionPolicy Bypass -File $localQwen -Root $Root -Prompt $escaped 2>&1 | Out-String
        $report = $report.Trim()
    }
    catch {
        $report = "Local Qwen failed. Error: " + $_.Exception.Message
    }
}
else {
    $report = "VEX DAILY MONEY REPORT`r`n======================`r`nStatus: Local Qwen wrapper missing.`r`nToday's best next action: Fix local Qwen or use cloud router."
}

# Remove wrapper noise if the model produced the desired header.
$lines = $report -split "`r?`n"
$clean = @()
$started = $false
foreach ($line in $lines) {
    if ($line -match "VEX DAILY MONEY REPORT") { $started = $true }
    if ($started) { $clean += $line }
}
if ($clean.Count -gt 0) { $report = ($clean -join "`r`n") }

Set-Content -Path $reportFile -Value $report -Encoding UTF8
Set-Content -Path $latestReport -Value $report -Encoding UTF8
Set-Content -Path $replyFile -Value $report -Encoding UTF8
Add-Content -Path $logFile -Value ("[" + $stamp + "] Created daily money report: " + $reportFile) -Encoding UTF8

Write-Host $report
Write-Host ""
Write-Host "Report saved:" -ForegroundColor Green
Write-Host $reportFile

if ($Open) { notepad $reportFile }
