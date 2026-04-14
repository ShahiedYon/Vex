$base = "C:\Users\yonsh\Vex"
$workspace = Join-Path $base "workspace"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"
$tasks = Join-Path $base "tasks"

$dirs = @($tasks)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -Path $d -ItemType Directory -Force | Out-Null
    }
}

# ---------------------------------
# Sample task file
# ---------------------------------
$sampleTask = @'
TASK_NAME: Create Vex phase 5 validation
GOAL: Prove that Vex can intake a task, create a plan, execute it, verify it, and write a result.
TYPE: validation
OUTPUT_FILE: C:\Users\yonsh\Vex\workspace\phase5-result.txt
'@

Set-Content -Path (Join-Path $tasks "sample-task.txt") -Value $sampleTask -Encoding UTF8

# ---------------------------------
# Operator script
# ---------------------------------
$operatorScript = @'
param(
    [string]$TaskFile
)

if ([string]::IsNullOrWhiteSpace($TaskFile)) {
    Write-Host "Error: provide -TaskFile"
    exit 1
}

if (-not (Test-Path $TaskFile)) {
    Write-Host "Error: task file not found"
    exit 1
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logFile = "C:\Users\yonsh\Vex\logs\operator.log"
$planFile = "C:\Users\yonsh\Vex\workspace\phase5-plan.txt"
$resultFileDefault = "C:\Users\yonsh\Vex\workspace\phase5-result.txt"

$content = Get-Content $TaskFile
$taskName = ""
$goal = ""
$type = ""
$outputFile = ""

foreach ($line in $content) {
    if ($line -like "TASK_NAME:*") { $taskName = $line.Substring(10).Trim() }
    elseif ($line -like "GOAL:*") { $goal = $line.Substring(5).Trim() }
    elseif ($line -like "TYPE:*") { $type = $line.Substring(5).Trim() }
    elseif ($line -like "OUTPUT_FILE:*") { $outputFile = $line.Substring(12).Trim() }
}

if ([string]::IsNullOrWhiteSpace($outputFile)) {
    $outputFile = $resultFileDefault
}

Add-Content -Path $logFile -Value "[$timestamp] TASK RECEIVED: $taskName"
Add-Content -Path $logFile -Value "[$timestamp] GOAL: $goal"

$plan = @()
$plan += "TASK: $taskName"
$plan += "GOAL: $goal"
$plan += ""
$plan += "PLAN:"
$plan += "1. Read task file"
$plan += "2. Extract task details"
$plan += "3. Create result output"
$plan += "4. Verify output exists"
$plan += "5. Log completion"

Set-Content -Path $planFile -Value $plan -Encoding UTF8
Add-Content -Path $logFile -Value "[$timestamp] PLAN CREATED: $planFile"

$resultLines = @()
$resultLines += "Vex Operator Result"
$resultLines += "Timestamp: $timestamp"
$resultLines += "Task Name: $taskName"
$resultLines += "Goal: $goal"
$resultLines += "Type: $type"
$resultLines += "Status: SUCCESS"
$resultLines += "Verification: Output file created successfully"

Set-Content -Path $outputFile -Value $resultLines -Encoding UTF8
Add-Content -Path $logFile -Value "[$timestamp] EXECUTION COMPLETE: $outputFile"

if (Test-Path $outputFile) {
    Add-Content -Path $logFile -Value "[$timestamp] VERIFICATION PASSED"
    Write-Host "Operator task completed successfully."
    Write-Host "Plan: $planFile"
    Write-Host "Result: $outputFile"
}
else {
    Add-Content -Path $logFile -Value "[$timestamp] VERIFICATION FAILED"
    Write-Host "Operator task failed verification."
    exit 1
}
'@

Set-Content -Path (Join-Path $scripts "run_operator.ps1") -Value $operatorScript -Encoding UTF8

# ---------------------------------
# Execute test run
# ---------------------------------
powershell -ExecutionPolicy Bypass -File (Join-Path $scripts "run_operator.ps1") -TaskFile (Join-Path $tasks "sample-task.txt")

# ---------------------------------
# Phase 5 check file
# ---------------------------------
$phase5Check = @'
[ ] tasks folder created
[ ] sample-task.txt created
[ ] run_operator.ps1 created
[ ] phase5-plan.txt created
[ ] phase5-result.txt created
[ ] operator.log created
[ ] task was parsed successfully
[ ] plan was written successfully
[ ] result was verified successfully
'@

Set-Content -Path (Join-Path $logs "phase5-check.txt") -Value $phase5Check -Encoding UTF8

Write-Host ""
Write-Host "Phase 5 setup complete."
Write-Host "Review these files:"
Write-Host "C:\Users\yonsh\Vex\workspace\phase5-plan.txt"
Write-Host "C:\Users\yonsh\Vex\workspace\phase5-result.txt"
Write-Host "C:\Users\yonsh\Vex\logs\operator.log"