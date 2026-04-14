param(
    [string]$Task
)

$logFile = "C:\Users\yonsh\Vex\logs\task-runner.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if ([string]::IsNullOrWhiteSpace($Task)) {
    Write-Host "Provide -Task"
    exit 1
}

"[$timestamp] Running task: $Task" | Out-File -Append -FilePath $logFile

switch ($Task) {
    "python-test" {
        python C:\Users\yonsh\Vex\scripts\test_python.py
    }
    "node-test" {
        node C:\Users\yonsh\Vex\scripts\test_node.js
    }
    default {
        Write-Host "Unknown task"
        "[$timestamp] Unknown task: $Task" | Out-File -Append -FilePath $logFile
    }
}

"[$timestamp] Task completed: $Task" | Out-File -Append -FilePath $logFile
