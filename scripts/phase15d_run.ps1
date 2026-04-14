param(
    [string]$Root = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

$workspaceDir = Join-Path $Root "workspace"
$queueDir = Join-Path $workspaceDir "queue"
$logsDir = Join-Path $workspaceDir "logs"
$logFile = Join-Path $logsDir ("phase15d_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Get-BasePriority {
    param([string]$Stream)
    if ($Stream -eq "debt_relief") { return 90 }
    if ($Stream -eq "solar") { return 70 }
    if ($Stream -eq "vextly") { return 40 }
    return 10
}

function Get-TaskWeight {
    param([string]$TaskType)
    if ($TaskType -eq "partner_research") { return 20 }
    if ($TaskType -eq "content_publish") { return 15 }
    if ($TaskType -eq "content_create") { return 12 }
    if ($TaskType -eq "niche_definition") { return 8 }
    return 0
}

function New-QueueItem {
    param(
        [string]$Id,
        [string]$Stream,
        [string]$TaskType,
        [string]$TaskName,
        [string]$NextAction,
        [string]$Status
    )

    $priority = (Get-BasePriority -Stream $Stream) + (Get-TaskWeight -TaskType $TaskType)
    if ($priority -gt 100) { $priority = 100 }

    return [pscustomobject]@{
        id = $Id
        stream = $Stream
        task_type = $TaskType
        task_name = $TaskName
        next_action = $NextAction
        status = $Status
        priority_score = $priority
        created_at = (Get-Date).ToString("s")
    }
}

Write-Log "Starting Phase 15d weekly action queue generation"

$tasks = @(
    (New-QueueItem -Id "Q-001" -Stream "debt_relief" -TaskType "partner_research" -TaskName "Research first 5 debt partners" -NextAction "Add 5 real debt partner candidates to partner_intake.csv" -Status "pending"),
    (New-QueueItem -Id "Q-002" -Stream "debt_relief" -TaskType "content_create" -TaskName "Select best 3 debt X posts" -NextAction "Choose 3 posts from debt_relief_posts_x.txt for first-week publishing" -Status "pending"),
    (New-QueueItem -Id "Q-003" -Stream "debt_relief" -TaskType "content_publish" -TaskName "Prepare first 2 debt Facebook posts" -NextAction "Choose 2 posts from debt_relief_posts_facebook.txt and stage for publishing" -Status "pending"),
    (New-QueueItem -Id "Q-004" -Stream "solar" -TaskType "partner_research" -TaskName "Research first 5 solar partners" -NextAction "Add 5 real solar partner candidates to partner_intake.csv" -Status "pending"),
    (New-QueueItem -Id "Q-005" -Stream "solar" -TaskType "content_create" -TaskName "Select best 3 solar X posts" -NextAction "Choose 3 posts from solar_posts_x.txt for first-week publishing" -Status "pending"),
    (New-QueueItem -Id "Q-006" -Stream "solar" -TaskType "content_publish" -TaskName "Prepare first 2 solar Facebook posts" -NextAction "Choose 2 posts from solar_posts_facebook.txt and stage for publishing" -Status "pending"),
    (New-QueueItem -Id "Q-007" -Stream "vextly" -TaskType "niche_definition" -TaskName "Define first 3 Vextly niches" -NextAction "Choose 3 SMB niches most likely to need automation work" -Status "pending")
)

$sorted = $tasks | Sort-Object -Property @{Expression="priority_score";Descending=$true}, @{Expression="id";Descending=$false}

$csvPath = Join-Path $queueDir "weekly_action_queue.csv"
$jsonPath = Join-Path $queueDir "weekly_action_queue.json"
$focusPath = Join-Path $queueDir "today_focus.txt"

$sorted | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

$payload = [ordered]@{
    generated_at = (Get-Date).ToString("s")
    week_focus = "Debt relief first, solar second, Vextly third"
    tasks = $sorted
}
$payload | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8

$top3 = $sorted | Select-Object -First 3
$focusLines = @()
$focusLines += "TODAY FOCUS"
$focusLines += "=========="
for ($i = 0; $i -lt $top3.Count; $i++) {
    $focusLines += ($top3[$i].id + " | " + $top3[$i].stream + " | " + $top3[$i].task_name)
    $focusLines += ("Next: " + $top3[$i].next_action)
    $focusLines += ""
}
Set-Content -Path $focusPath -Value $focusLines -Encoding UTF8

Write-Log ("Created: " + $csvPath)
Write-Log ("Created: " + $jsonPath)
Write-Log ("Created: " + $focusPath)
Write-Log "Phase 15d complete"
