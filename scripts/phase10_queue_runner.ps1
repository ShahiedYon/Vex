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