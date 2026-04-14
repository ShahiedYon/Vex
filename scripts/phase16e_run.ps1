param(
    [string]$Root = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

$workspaceDir = Join-Path $Root "workspace"
$contentDir = Join-Path $workspaceDir "content"
$campaignsDir = Join-Path $workspaceDir "campaigns"
$logsDir = Join-Path $workspaceDir "logs"
$logFile = Join-Path $logsDir ("phase16e_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Get-NonEmptyLines {
    param([string]$Path)
    $lines = Get-Content -Path $Path
    $out = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $out += $line.Trim()
        }
    }
    return $out
}

function Take-FirstN {
    param(
        [object[]]$Items,
        [int]$Count
    )
    $out = @()
    for ($i = 0; $i -lt $Items.Count -and $i -lt $Count; $i++) {
        $out += $Items[$i]
    }
    return $out
}

Write-Log "Starting Phase 16e real campaign starter"

$debtXPath = Join-Path $contentDir "debt_relief_posts_x.txt"
$debtFBPath = Join-Path $contentDir "debt_relief_posts_facebook.txt"
$solarXPath = Join-Path $contentDir "solar_posts_x.txt"
$solarFBPath = Join-Path $contentDir "solar_posts_facebook.txt"

if (-not (Test-Path $debtXPath)) { throw "Missing file: $debtXPath" }
if (-not (Test-Path $debtFBPath)) { throw "Missing file: $debtFBPath" }
if (-not (Test-Path $solarXPath)) { throw "Missing file: $solarXPath" }
if (-not (Test-Path $solarFBPath)) { throw "Missing file: $solarFBPath" }

$debtX = Take-FirstN -Items (Get-NonEmptyLines -Path $debtXPath) -Count 3
$debtFB = Take-FirstN -Items (Get-NonEmptyLines -Path $debtFBPath) -Count 2
$solarX = Take-FirstN -Items (Get-NonEmptyLines -Path $solarXPath) -Count 3
$solarFB = Take-FirstN -Items (Get-NonEmptyLines -Path $solarFBPath) -Count 2

$debtOut = @()
$debtOut += "DEBT RELIEF - WEEK 1 POSTS"
$debtOut += "=========================="
$debtOut += ""
$debtOut += "X POSTS"
$debtOut += "-------"
for ($i = 0; $i -lt $debtX.Count; $i++) {
    $debtOut += ("[" + ($i + 1) + "] " + $debtX[$i])
    $debtOut += ""
}
$debtOut += "FACEBOOK POSTS"
$debtOut += "--------------"
for ($j = 0; $j -lt $debtFB.Count; $j++) {
    $debtOut += ("[" + ($j + 1) + "] " + $debtFB[$j])
    $debtOut += ""
}

$solarOut = @()
$solarOut += "SOLAR - WEEK 1 POSTS"
$solarOut += "===================="
$solarOut += ""
$solarOut += "X POSTS"
$solarOut += "-------"
for ($k = 0; $k -lt $solarX.Count; $k++) {
    $solarOut += ("[" + ($k + 1) + "] " + $solarX[$k])
    $solarOut += ""
}
$solarOut += "FACEBOOK POSTS"
$solarOut += "--------------"
for ($m = 0; $m -lt $solarFB.Count; $m++) {
    $solarOut += ("[" + ($m + 1) + "] " + $solarFB[$m])
    $solarOut += ""
}

$plan = @(
    [pscustomobject]@{day="Day 1"; stream="debt_relief"; platform="X"; task="Post debt X post 1"; priority=100},
    [pscustomobject]@{day="Day 1"; stream="debt_relief"; platform="Facebook"; task="Post debt Facebook post 1"; priority=95},
    [pscustomobject]@{day="Day 2"; stream="debt_relief"; platform="X"; task="Post debt X post 2"; priority=90},
    [pscustomobject]@{day="Day 3"; stream="debt_relief"; platform="Facebook"; task="Post debt Facebook post 2"; priority=88},
    [pscustomobject]@{day="Day 4"; stream="debt_relief"; platform="X"; task="Post debt X post 3"; priority=85},
    [pscustomobject]@{day="Day 5"; stream="solar"; platform="X"; task="Post solar X post 1"; priority=80},
    [pscustomobject]@{day="Day 5"; stream="solar"; platform="Facebook"; task="Post solar Facebook post 1"; priority=78},
    [pscustomobject]@{day="Day 6"; stream="solar"; platform="X"; task="Post solar X post 2"; priority=75},
    [pscustomobject]@{day="Day 7"; stream="solar"; platform="Facebook"; task="Post solar Facebook post 2"; priority=73},
    [pscustomobject]@{day="Day 7"; stream="solar"; platform="X"; task="Post solar X post 3"; priority=70}
)

$debtWeekPath = Join-Path $campaignsDir "debt_week1_posts.txt"
$solarWeekPath = Join-Path $campaignsDir "solar_week1_posts.txt"
$planPath = Join-Path $campaignsDir "week1_campaign_plan.csv"
$focusPath = Join-Path $campaignsDir "today_posting_focus.txt"

Set-Content -Path $debtWeekPath -Value $debtOut -Encoding UTF8
Set-Content -Path $solarWeekPath -Value $solarOut -Encoding UTF8
$plan | Export-Csv -Path $planPath -NoTypeInformation -Encoding UTF8

$focus = @()
$focus += "TODAY POSTING FOCUS"
$focus += "==================="
$focus += "1. Debt Relief X Post 1"
$focus += "2. Debt Relief Facebook Post 1"
$focus += "3. Review debt partner follow-up queue"
Set-Content -Path $focusPath -Value $focus -Encoding UTF8

Write-Log ("Created: " + $debtWeekPath)
Write-Log ("Created: " + $solarWeekPath)
Write-Log ("Created: " + $planPath)
Write-Log ("Created: " + $focusPath)
Write-Log "Phase 16e complete"
