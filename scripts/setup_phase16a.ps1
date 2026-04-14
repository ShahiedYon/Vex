$ErrorActionPreference = "Stop"

$root = "C:\Users\yonsh\Vex"
$scriptsDir = Join-Path $root "scripts"
$workspaceDir = Join-Path $root "workspace"
$partnersDir = Join-Path $workspaceDir "partners"
$logsDir = Join-Path $workspaceDir "logs"

$null = New-Item -ItemType Directory -Force -Path $scriptsDir
$null = New-Item -ItemType Directory -Force -Path $workspaceDir
$null = New-Item -ItemType Directory -Force -Path $partnersDir
$null = New-Item -ItemType Directory -Force -Path $logsDir

$runner = @'
param(
    [string]$Root = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

$workspaceDir = Join-Path $Root "workspace"
$partnersDir = Join-Path $workspaceDir "partners"
$logsDir = Join-Path $workspaceDir "logs"
$logFile = Join-Path $logsDir ("phase16a_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Get-StreamWeight {
    param([string]$Stream)
    if ($Stream -eq "debt_relief") { return 35 }
    if ($Stream -eq "solar") { return 20 }
    if ($Stream -eq "vextly") { return 10 }
    return 0
}

function Get-SpeedWeight {
    param([string]$Speed)
    if ($Speed -eq "fast") { return 30 }
    if ($Speed -eq "medium") { return 20 }
    if ($Speed -eq "slow") { return 10 }
    return 0
}

function Get-TrustWeight {
    param([int]$TrustScore)
    if ($TrustScore -ge 80) { return 25 }
    if ($TrustScore -ge 60) { return 15 }
    if ($TrustScore -ge 40) { return 8 }
    return 0
}

function Get-PriorityScore {
    param(
        [string]$Stream,
        [string]$SpeedToCash,
        [int]$TrustScore
    )

    $score = 0
    $score += Get-StreamWeight -Stream $Stream
    $score += Get-SpeedWeight -Speed $SpeedToCash
    $score += Get-TrustWeight -TrustScore $TrustScore

    if ($score -gt 100) { $score = 100 }
    if ($score -lt 0) { $score = 0 }
    return $score
}

Write-Log "Starting Phase 16a real partner research intake generation"

$researchRows = @(
    [pscustomobject]@{
        id = "R-001"
        stream = "debt_relief"
        partner_name = ""
        website = ""
        application_url = ""
        category = "debt_relief"
        geo = "US"
        payout_model = "per_lead"
        payout_details = ""
        approval_status = "researching"
        trust_score = 0
        speed_to_cash = "fast"
        notes = "Add real candidate here after research"
        next_action = "Find candidate and complete row"
    },
    [pscustomobject]@{
        id = "R-002"
        stream = "solar"
        partner_name = ""
        website = ""
        application_url = ""
        category = "solar_affiliate"
        geo = "US"
        payout_model = "commission"
        payout_details = ""
        approval_status = "researching"
        trust_score = 0
        speed_to_cash = "medium"
        notes = "Add real candidate here after research"
        next_action = "Find candidate and complete row"
    },
    [pscustomobject]@{
        id = "R-003"
        stream = "vextly"
        partner_name = "Direct outreach"
        website = ""
        application_url = ""
        category = "service_lead"
        geo = "US"
        payout_model = "service_revenue"
        payout_details = "custom proposal"
        approval_status = "researching"
        trust_score = 70
        speed_to_cash = "slow"
        notes = "Used for direct client acquisition"
        next_action = "Define first outreach targets"
    }
)

for ($i = 0; $i -lt $researchRows.Count; $i++) {
    $score = Get-PriorityScore -Stream $researchRows[$i].stream -SpeedToCash $researchRows[$i].speed_to_cash -TrustScore ([int]$researchRows[$i].trust_score)
    $researchRows[$i] | Add-Member -NotePropertyName priority_score -NotePropertyValue $score -Force
}

$master = $researchRows | Sort-Object -Property @{Expression="priority_score";Descending=$true}, @{Expression="id";Descending=$false}
$debtView = $master | Where-Object { $_.stream -eq "debt_relief" }

$intakePath = Join-Path $partnersDir "partner_research_intake.csv"
$masterPath = Join-Path $partnersDir "partner_master.csv"
$debtPath = Join-Path $partnersDir "debt_priority_view.csv"

$researchRows | Export-Csv -Path $intakePath -NoTypeInformation -Encoding UTF8
$master | Export-Csv -Path $masterPath -NoTypeInformation -Encoding UTF8
$debtView | Export-Csv -Path $debtPath -NoTypeInformation -Encoding UTF8

Write-Log ("Created: " + $intakePath)
Write-Log ("Created: " + $masterPath)
Write-Log ("Created: " + $debtPath)
Write-Log "Phase 16a complete"
'@

Set-Content -Path (Join-Path $scriptsDir "phase16a_run.ps1") -Value $runner -Encoding UTF8

Write-Host ""
Write-Host "Phase 16a setup complete."
Write-Host "Run with:"
Write-Host "powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\phase16a_run.ps1"