$ErrorActionPreference = "Stop"

$root = "C:\Users\yonsh\Vex"
$scriptsDir = Join-Path $root "scripts"
$configDir = Join-Path $root "config"
$workspaceDir = Join-Path $root "workspace"
$oppsDir = Join-Path $workspaceDir "opportunities"
$logsDir = Join-Path $workspaceDir "logs"

$null = New-Item -ItemType Directory -Force -Path $scriptsDir
$null = New-Item -ItemType Directory -Force -Path $configDir
$null = New-Item -ItemType Directory -Force -Path $workspaceDir
$null = New-Item -ItemType Directory -Force -Path $oppsDir
$null = New-Item -ItemType Directory -Force -Path $logsDir

$streamsJson = @'
{
  "streams": [
    {
      "id": "debt_relief",
      "name": "Debt Relief",
      "priority_order": 1,
      "goal": "Fast cash through finance assistance and debt lead generation for US customers",
      "brand": "TBD",
      "status": "active"
    },
    {
      "id": "solar",
      "name": "Solar",
      "priority_order": 2,
      "goal": "Affiliate, audience building, and solar lead generation",
      "brand": "LumaSunUS",
      "status": "active"
    },
    {
      "id": "vextly",
      "name": "Vextly",
      "priority_order": 3,
      "goal": "Automation consulting lead generation",
      "brand": "Vextly",
      "status": "active"
    }
  ]
}
'@

Set-Content -Path (Join-Path $configDir "streams.json") -Value $streamsJson -Encoding UTF8

$runner = @'
param(
    [string]$Root = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

$configDir = Join-Path $Root "config"
$workspaceDir = Join-Path $Root "workspace"
$oppsDir = Join-Path $workspaceDir "opportunities"
$logsDir = Join-Path $workspaceDir "logs"
$streamsFile = Join-Path $configDir "streams.json"
$oppsJsonFile = Join-Path $oppsDir "opportunities.json"
$oppsCsvFile = Join-Path $oppsDir "opportunities.csv"
$logFile = Join-Path $logsDir ("phase14e_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Get-StreamWeight {
    param([string]$StreamId)
    if ($StreamId -eq "debt_relief") { return 30 }
    if ($StreamId -eq "solar") { return 20 }
    if ($StreamId -eq "vextly") { return 10 }
    return 0
}

function Get-SpeedWeight {
    param([string]$Value)
    if ($Value -eq "fast") { return 30 }
    if ($Value -eq "medium") { return 20 }
    if ($Value -eq "slow") { return 10 }
    return 0
}

function Get-DifficultyWeight {
    param([string]$Value)
    if ($Value -eq "low") { return 25 }
    if ($Value -eq "medium") { return 15 }
    if ($Value -eq "high") { return 5 }
    return 0
}

function Get-StatusWeight {
    param([string]$Value)
    if ($Value -eq "ready_to_apply") { return 20 }
    if ($Value -eq "researching") { return 12 }
    if ($Value -eq "waiting") { return 6 }
    if ($Value -eq "approved") { return 18 }
    return 0
}

function Get-PriorityScore {
    param(
        [string]$StreamId,
        [string]$SpeedToCash,
        [string]$Difficulty,
        [string]$Status
    )

    $score = 0
    $score += Get-StreamWeight -StreamId $StreamId
    $score += Get-SpeedWeight -Value $SpeedToCash
    $score += Get-DifficultyWeight -Value $Difficulty
    $score += Get-StatusWeight -Value $Status

    if ($score -gt 100) { $score = 100 }
    if ($score -lt 0) { $score = 0 }
    return $score
}

Write-Log "Loading stream configuration"
$streams = Get-Content -Raw -Path $streamsFile | ConvertFrom-Json

$opportunities = @(
    [pscustomobject]@{
        id = "debt-001"
        stream = "debt_relief"
        opportunity_name = "Debt relief affiliate/referral program shortlist"
        opportunity_type = "affiliate_research"
        payout_model = "per_lead"
        speed_to_cash = "fast"
        difficulty = "medium"
        status = "researching"
        next_action = "Build shortlist of debt relief and finance assistance partner programs"
        notes = "Prioritize fast approval and compliant US offers"
    },
    [pscustomobject]@{
        id = "debt-002"
        stream = "debt_relief"
        opportunity_name = "Debt relief social presence launch"
        opportunity_type = "content_engine"
        payout_model = "indirect"
        speed_to_cash = "fast"
        difficulty = "low"
        status = "ready_to_apply"
        next_action = "Create X and Facebook posting plan for trust-building debt help content"
        notes = "Use non-advisory wording and referral positioning"
    },
    [pscustomobject]@{
        id = "solar-001"
        stream = "solar"
        opportunity_name = "Solar affiliate application pipeline"
        opportunity_type = "affiliate_research"
        payout_model = "commission"
        speed_to_cash = "medium"
        difficulty = "medium"
        status = "researching"
        next_action = "Track active solar affiliate/referral programs and approval requirements"
        notes = "LumaSunUS brand should be used"
    },
    [pscustomobject]@{
        id = "solar-002"
        stream = "solar"
        opportunity_name = "Solar audience growth engine"
        opportunity_type = "content_engine"
        payout_model = "indirect"
        speed_to_cash = "medium"
        difficulty = "low"
        status = "ready_to_apply"
        next_action = "Create X and Facebook solar content plan and lead magnets"
        notes = "Target homeowners, bill savings, and home upgrade interest"
    },
    [pscustomobject]@{
        id = "vextly-001"
        stream = "vextly"
        opportunity_name = "Automation lead finder for SMBs"
        opportunity_type = "lead_generation"
        payout_model = "service_revenue"
        speed_to_cash = "slow"
        difficulty = "medium"
        status = "researching"
        next_action = "Define target verticals and build first lead list"
        notes = "Keep this active in the background"
    }
)

for ($i = 0; $i -lt $opportunities.Count; $i++) {
    $opportunities[$i] | Add-Member -NotePropertyName priority_score -NotePropertyValue (
        Get-PriorityScore -StreamId $opportunities[$i].stream -SpeedToCash $opportunities[$i].speed_to_cash -Difficulty $opportunities[$i].difficulty -Status $opportunities[$i].status
    ) -Force
}

$sorted = $opportunities | Sort-Object -Property @{Expression="priority_score";Descending=$true}, @{Expression="stream";Descending=$false}

$payload = [ordered]@{
    generated_at = (Get-Date).ToString("s")
    streams = $streams.streams
    opportunities = $sorted
}

$payload | ConvertTo-Json -Depth 10 | Set-Content -Path $oppsJsonFile -Encoding UTF8
$sorted | Export-Csv -Path $oppsCsvFile -NoTypeInformation -Encoding UTF8

Write-Log ("Created: " + $oppsJsonFile)
Write-Log ("Created: " + $oppsCsvFile)
Write-Log "Phase 14e complete"
'@

Set-Content -Path (Join-Path $scriptsDir "phase14e_run.ps1") -Value $runner -Encoding UTF8

Write-Host ""
Write-Host "Phase 14e setup complete."
Write-Host "Run with:"
Write-Host "powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\phase14e_run.ps1"