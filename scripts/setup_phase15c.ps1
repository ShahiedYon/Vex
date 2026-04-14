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
$logFile = Join-Path $logsDir ("phase15c_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Get-StreamPriority {
    param([string]$Stream)
    if ($Stream -eq "debt_relief") { return 3 }
    if ($Stream -eq "solar") { return 2 }
    if ($Stream -eq "vextly") { return 1 }
    return 0
}

function Get-ApprovalWeight {
    param([string]$Status)
    if ($Status -eq "approved") { return 30 }
    if ($Status -eq "applied") { return 20 }
    if ($Status -eq "researching") { return 12 }
    if ($Status -eq "rejected") { return 0 }
    return 5
}

function Get-PriorityScore {
    param(
        [string]$Stream,
        [string]$ApprovalStatus,
        [string]$PayoutModel
    )

    $score = 0
    $score += (Get-StreamPriority -Stream $Stream) * 20
    $score += Get-ApprovalWeight -Status $ApprovalStatus

    if ($PayoutModel -eq "per_lead") { $score += 20 }
    elseif ($PayoutModel -eq "commission") { $score += 15 }
    elseif ($PayoutModel -eq "service_revenue") { $score += 10 }
    else { $score += 5 }

    if ($score -gt 100) { $score = 100 }
    return $score
}

Write-Log "Starting Phase 15c partner pipeline generation"

$rows = @(
    [pscustomobject]@{
        id = "P-001"
        stream = "debt_relief"
        partner_name = ""
        application_url = ""
        source = ""
        payout_model = "per_lead"
        payout_details = ""
        geo = "US"
        approval_status = "researching"
        rejection_reason = ""
        notes = "Add real debt relief / finance assistance candidates here"
        next_action = "Research and add first 5 real debt partners"
        last_checked = (Get-Date).ToString("s")
    },
    [pscustomobject]@{
        id = "P-002"
        stream = "solar"
        partner_name = ""
        application_url = ""
        source = ""
        payout_model = "commission"
        payout_details = ""
        geo = "US"
        approval_status = "researching"
        rejection_reason = ""
        notes = "Add real solar affiliate or referral candidates here"
        next_action = "Research and add first 5 real solar partners"
        last_checked = (Get-Date).ToString("s")
    },
    [pscustomobject]@{
        id = "P-003"
        stream = "vextly"
        partner_name = "Direct outreach"
        application_url = ""
        source = "internal"
        payout_model = "service_revenue"
        payout_details = "custom proposal"
        geo = "US"
        approval_status = "researching"
        rejection_reason = ""
        notes = "Use for direct automation lead work"
        next_action = "Define first 3 target niches"
        last_checked = (Get-Date).ToString("s")
    }
)

for ($i = 0; $i -lt $rows.Count; $i++) {
    $score = Get-PriorityScore -Stream $rows[$i].stream -ApprovalStatus $rows[$i].approval_status -PayoutModel $rows[$i].payout_model
    $rows[$i] | Add-Member -NotePropertyName priority_score -NotePropertyValue $score -Force
}

$sorted = $rows | Sort-Object -Property @{Expression="priority_score";Descending=$true}, @{Expression="stream";Descending=$false}

$intakePath = Join-Path $partnersDir "partner_intake.csv"
$jsonPath = Join-Path $partnersDir "partner_pipeline.json"
$summaryPath = Join-Path $partnersDir "partner_summary.csv"

$sorted | Export-Csv -Path $intakePath -NoTypeInformation -Encoding UTF8

$payload = [ordered]@{
    generated_at = (Get-Date).ToString("s")
    partners = $sorted
}
$payload | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8

$summary = $sorted | Select-Object id,stream,partner_name,payout_model,approval_status,next_action,priority_score
$summary | Export-Csv -Path $summaryPath -NoTypeInformation -Encoding UTF8

Write-Log ("Created: " + $intakePath)
Write-Log ("Created: " + $jsonPath)
Write-Log ("Created: " + $summaryPath)
Write-Log "Phase 15c complete"
'@

Set-Content -Path (Join-Path $scriptsDir "phase15c_run.ps1") -Value $runner -Encoding UTF8

Write-Host ""
Write-Host "Phase 15c setup complete."
Write-Host "Run with:"
Write-Host "powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\phase15c_run.ps1"