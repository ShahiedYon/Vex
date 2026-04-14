$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$workspace = Join-Path $base "workspace"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"
$tasks = Join-Path $base "tasks"
$queue = Join-Path $tasks "queue"
$pending = Join-Path $queue "pending"
$completed = Join-Path $queue "completed"
$failed = Join-Path $queue "failed"

foreach ($dir in @($workspace, $logs, $scripts, $tasks, $queue, $pending, $completed, $failed)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# -----------------------------------
# Sample queued tasks
# -----------------------------------
$task1 = @'
TASK_NAME: Queue Auto Browser Check
TASK_TYPE: browser.inspect
TARGET: https://example.com
OUTPUT_TEXT: C:\Users\yonsh\Vex\workspace\phase10-queue-browser-result.txt
OUTPUT_SCREENSHOT: C:\Users\yonsh\Vex\workspace\phase10-queue-browser-shot.png
OUTPUT_LOG: C:\Users\yonsh\Vex\logs\phase10-queue-browser.log
APPROVED: no
'@

$task2 = @'
TASK_NAME: Queue Blocked Python
TASK_TYPE: python.run
TARGET: C:\Users\yonsh\Vex\scripts\phase8_python_task.py
OUTPUT_TEXT: C:\Users\yonsh\Vex\workspace\phase10-queue-blocked-python-result.txt
OUTPUT_LOG: C:\Users\yonsh\Vex\logs\phase10-queue-blocked-python.log
APPROVED: no
'@

$task3 = @'
TASK_NAME: Queue Approved Python
TASK_TYPE: python.run
TARGET: C:\Users\yonsh\Vex\scripts\phase8_python_task.py
OUTPUT_TEXT: C:\Users\yonsh\Vex\workspace\phase10-queue-approved-python-result.txt
OUTPUT_LOG: C:\Users\yonsh\Vex\logs\phase10-queue-approved-python.log
APPROVED: yes
'@

Write-Utf8NoBom -Path (Join-Path $pending "001-browser-task.txt") -Content $task1
Write-Utf8NoBom -Path (Join-Path $pending "002-blocked-python-task.txt") -Content $task2
Write-Utf8NoBom -Path (Join-Path $pending "003-approved-python-task.txt") -Content $task3

# -----------------------------------
# Queue processor
# -----------------------------------
$queueProcessor = @'
$ErrorActionPreference = "Stop"

$pending = "C:\Users\yonsh\Vex\tasks\queue\pending"
$completed = "C:\Users\yonsh\Vex\tasks\queue\completed"
$failed = "C:\Users\yonsh\Vex\tasks\queue\failed"
$router = "C:\Users\yonsh\Vex\scripts\phase9_router.ps1"
$queueLog = "C:\Users\yonsh\Vex\logs\phase10-queue.log"

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $queueLog -Value "[$ts] $Message" -Encoding UTF8
}

function Get-OutputTextPath {
    param([string]$TaskFile)
    $lines = Get-Content -Path $TaskFile
    foreach ($line in $lines) {
        if ($line -like "OUTPUT_TEXT:*") {
            return $line.Substring(12).Trim()
        }
    }
    return $null
}

Set-Content -Path $queueLog -Value "" -Encoding UTF8

$taskFiles = Get-ChildItem -Path $pending -Filter *.txt | Sort-Object Name

if ($taskFiles.Count -eq 0) {
    Write-Log "No pending tasks found."
    Write-Host "No pending tasks found."
    exit 0
}

Write-Log "Queue run started. Pending count: $($taskFiles.Count)"

foreach ($task in $taskFiles) {
    Write-Log "Processing task: $($task.Name)"

    try {
        powershell -ExecutionPolicy Bypass -File $router -TaskFile $task.FullName

        $outputText = Get-OutputTextPath -TaskFile $task.FullName
        $status = "UNKNOWN"

        if ($outputText -and (Test-Path $outputText)) {
            $content = Get-Content -Path $outputText -Raw
            if ($content -match "Status:\s*BLOCKED") {
                $status = "BLOCKED"
            }
            elseif ($content -match "Status:\s*SUCCESS") {
                $status = "SUCCESS"
            }
        }

        if ($status -eq "SUCCESS" -or $status -eq "BLOCKED") {
            Move-Item -Path $task.FullName -Destination (Join-Path $completed $task.Name) -Force
            Write-Log "Task moved to completed: $($task.Name) (status=$status)"
        }
        else {
            Move-Item -Path $task.FullName -Destination (Join-Path $failed $task.Name) -Force
            Write-Log "Task moved to failed: $($task.Name) (status unresolved)"
        }
    }
    catch {
        Move-Item -Path $task.FullName -Destination (Join-Path $failed $task.Name) -Force
        Write-Log "Task failed with exception and moved to failed: $($task.Name)"
        Write-Log "Error: $($_.Exception.Message)"
    }
}

$remainingPending = (Get-ChildItem -Path $pending -Filter *.txt | Measure-Object).Count
$completedCount = (Get-ChildItem -Path $completed -Filter *.txt | Measure-Object).Count
$failedCount = (Get-ChildItem -Path $failed -Filter *.txt | Measure-Object).Count

Write-Log "Queue run finished. Pending=$remainingPending Completed=$completedCount Failed=$failedCount"

Write-Host "Queue processing complete."
Write-Host "Pending: $remainingPending"
Write-Host "Completed: $completedCount"
Write-Host "Failed: $failedCount"
'@

Write-Utf8NoBom -Path (Join-Path $scripts "phase10_queue_runner.ps1") -Content $queueProcessor

# -----------------------------------
# Run queue validation
# -----------------------------------
Write-Host "Running Phase 10 queue..."
powershell -ExecutionPolicy Bypass -File (Join-Path $scripts "phase10_queue_runner.ps1")

# -----------------------------------
# Check file
# -----------------------------------
$checks = @'
[ ] queue folder created
[ ] pending folder created
[ ] completed folder created
[ ] failed folder created
[ ] sample queued tasks created
[ ] phase10_queue_runner.ps1 created
[ ] queue processed all pending tasks
[ ] completed folder contains processed tasks
[ ] phase10-queue.log created
[ ] queue browser result created
[ ] queue blocked python result created
[ ] queue approved python result created
'@

Set-Content -Path (Join-Path $logs "phase10-check.txt") -Value $checks -Encoding UTF8

Write-Host ""
Write-Host "Phase 10 setup complete."
Write-Host "Review these files:"
Write-Host "C:\Users\yonsh\Vex\logs\phase10-queue.log"
Write-Host "C:\Users\yonsh\Vex\workspace\phase10-queue-browser-result.txt"
Write-Host "C:\Users\yonsh\Vex\workspace\phase10-queue-blocked-python-result.txt"
Write-Host "C:\Users\yonsh\Vex\workspace\phase10-queue-approved-python-result.txt"
Write-Host "C:\Users\yonsh\Vex\tasks\queue\completed"
Write-Host "C:\Users\yonsh\Vex\tasks\queue\failed"