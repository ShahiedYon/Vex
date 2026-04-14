param(
    [string]$Root = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

$workspaceDir = Join-Path $Root "workspace"
$partnersDir = Join-Path $workspaceDir "partners"
$queueDir = Join-Path $workspaceDir "queue"
$logsDir = Join-Path $workspaceDir "logs"

$intakePath = Join-Path $partnersDir "partner_research_intake.csv"
$rankedPath = Join-Path $partnersDir "partner_master_ranked.csv"
$actionQueuePath = Join-Path $queueDir "partner_action_queue.csv"
$focusPath = Join-Path $queueDir "partner_focus.txt"
$logFile = Join-Path $logsDir ("phase16b_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

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

function Get-ApprovalWeight {
    param([string]$Status)
    if ($Status -eq "approved") { return 25 }
    if ($Status -eq "applied") { return 18 }
    if ($Status -eq "ready_to_apply") { return 15 }
    if ($Status -eq "researching") { return 8 }
    if ($Status -eq "rejected") { return 0 }
    return 5
}

function Get-PriorityScore {
    param(
        [string]$Stream,
        [string]$SpeedToCash,
        [int]$TrustScore,
        [string]$ApprovalStatus
    )

    $score = 0
    $score += Get-StreamWeight -Stream $Stream
    $score += Get-SpeedWeight -Speed $SpeedToCash
    $score += Get-TrustWeight -TrustScore $TrustScore
    $score += Get-ApprovalWeight -Status $ApprovalStatus

    if ($score -gt 100) { $score = 100 }
    if ($score -lt 0) { $score = 0 }
    return $score
}

function Get-NextActionFromRow {
    param([object]$Row)

    $partnerName = [string]$Row.partner_name
    $approvalStatus = [string]$Row.approval_status
    $applicationUrl = [string]$Row.application_url
    $trustScore = 0
    if ($null -ne $Row.trust_score -and [string]$Row.trust_score -ne "") {
        $trustScore = [int]$Row.trust_score
    }

    if ($approvalStatus -eq "approved") {
        return "Move approved partner into active publishing and lead routing workflow"
    }

    if ($approvalStatus -eq "applied") {
        return "Check response timing and follow up if needed"
    }

    if ($approvalStatus -eq "ready_to_apply" -and -not [string]::IsNullOrWhiteSpace($applicationUrl)) {
        return "Review terms and submit application"
    }

    if ($trustScore -ge 60 -and -not [string]::IsNullOrWhiteSpace($applicationUrl)) {
        return "Review program details and prepare application"
    }

    if ([string]::IsNullOrWhiteSpace($partnerName)) {
        return "Find candidate and complete row"
    }

    return "Research website, terms, and approval requirements"
}

function Get-ActionType {
    param([object]$Row)

    $approvalStatus = [string]$Row.approval_status
    $applicationUrl = [string]$Row.application_url
    $trustScore = 0
    if ($null -ne $Row.trust_score -and [string]$Row.trust_score -ne "") {
        $trustScore = [int]$Row.trust_score
    }

    if ($approvalStatus -eq "approved") { return "activate_partner" }
    if ($approvalStatus -eq "applied") { return "follow_up" }
    if ($approvalStatus -eq "ready_to_apply" -and -not [string]::IsNullOrWhiteSpace($applicationUrl)) { return "apply_now" }
    if ($trustScore -ge 60 -and -not [string]::IsNullOrWhiteSpace($applicationUrl)) { return "review_for_application" }
    return "research"
}

Write-Log "Starting Phase 16b research-to-queue sync"

if (-not (Test-Path $intakePath)) {
    throw "Missing input file: $intakePath"
}

$rows = Import-Csv -Path $intakePath
$ranked = @()
$actionQueue = @()

for ($i = 0; $i -lt $rows.Count; $i++) {
    $row = $rows[$i]

    $trustScore = 0
    if ($null -ne $row.trust_score -and [string]$row.trust_score -ne "") {
        $trustScore = [int]$row.trust_score
    }

    $priorityScore = Get-PriorityScore -Stream ([string]$row.stream) -SpeedToCash ([string]$row.speed_to_cash) -TrustScore $trustScore -ApprovalStatus ([string]$row.approval_status)
    $nextAction = Get-NextActionFromRow -Row $row
    $actionType = Get-ActionType -Row $row

    $rankedRow = [pscustomobject]@{
        id = [string]$row.id
        stream = [string]$row.stream
        partner_name = [string]$row.partner_name
        website = [string]$row.website
        application_url = [string]$row.application_url
        category = [string]$row.category
        geo = [string]$row.geo
        payout_model = [string]$row.payout_model
        payout_details = [string]$row.payout_details
        approval_status = [string]$row.approval_status
        trust_score = $trustScore
        speed_to_cash = [string]$row.speed_to_cash
        notes = [string]$row.notes
        next_action = $nextAction
        priority_score = $priorityScore
    }

    $ranked += $rankedRow

    $actionQueue += [pscustomobject]@{
        queue_id = ("AQ-" + "{0:D3}" -f ($i + 1))
        source_id = [string]$row.id
        stream = [string]$row.stream
        partner_name = [string]$row.partner_name
        action_type = $actionType
        next_action = $nextAction
        priority_score = $priorityScore
        status = "pending"
        created_at = (Get-Date).ToString("s")
    }
}

$rankedSorted = $ranked | Sort-Object -Property @{Expression="priority_score";Descending=$true}, @{Expression="id";Descending=$false}
$queueSorted = $actionQueue | Sort-Object -Property @{Expression="priority_score";Descending=$true}, @{Expression="queue_id";Descending=$false}

$rankedSorted | Export-Csv -Path $rankedPath -NoTypeInformation -Encoding UTF8
$queueSorted | Export-Csv -Path $actionQueuePath -NoTypeInformation -Encoding UTF8

$top3 = $queueSorted | Select-Object -First 3
$focusLines = @()
$focusLines += "PARTNER FOCUS"
$focusLines += "============="
for ($j = 0; $j -lt $top3.Count; $j++) {
    $name = [string]$top3[$j].partner_name
    if ([string]::IsNullOrWhiteSpace($name)) { $name = "(unnamed candidate)" }
    $focusLines += ($top3[$j].queue_id + " | " + $top3[$j].stream + " | " + $name)
    $focusLines += ("Action: " + $top3[$j].next_action)
    $focusLines += ""
}
Set-Content -Path $focusPath -Value $focusLines -Encoding UTF8

Write-Log ("Created: " + $rankedPath)
Write-Log ("Created: " + $actionQueuePath)
Write-Log ("Created: " + $focusPath)
Write-Log "Phase 16b complete"
