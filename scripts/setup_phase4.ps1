$base = "C:\Users\yonsh\Vex"
$workspace = Join-Path $base "workspace"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"
$tools = Join-Path $base "tools"

$dirs = @($tools)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -Path $d -ItemType Directory -Force | Out-Null
    }
}

# ---------------------------
# TOOL REGISTRY
# ---------------------------
$toolRegistry = @'
# Vex Tool Registry

## Python
Command: python
Use: scripting, data processing, automation

## Node
Command: node
Use: JavaScript execution, web tools

## Git
Command: git
Use: version control, cloning, commits

## PowerShell
Command: powershell
Use: system scripts, automation

## Ollama
Command: ollama
Use: local model execution
'@

Set-Content -Path (Join-Path $tools "tool-registry.md") -Value $toolRegistry -Encoding UTF8

# ---------------------------
# PYTHON TEST SCRIPT
# ---------------------------
$pythonScript = @'
from datetime import datetime

log_file = r"C:\Users\yonsh\Vex\logs\python-test.log"

with open(log_file, "a", encoding="utf-8") as f:
    f.write(f"[{datetime.now()}] Python tool executed successfully\n")

print("Python test complete")
'@

Set-Content -Path (Join-Path $scripts "test_python.py") -Value $pythonScript -Encoding UTF8

# ---------------------------
# NODE TEST SCRIPT
# ---------------------------
$nodeScript = @'
const fs = require("fs");

const logFile = "C:\\Users\\yonsh\\Vex\\logs\\node-test.log";
const timestamp = new Date().toISOString();

fs.appendFileSync(logFile, `[${timestamp}] Node tool executed successfully\n`);

console.log("Node test complete");
'@

Set-Content -Path (Join-Path $scripts "test_node.js") -Value $nodeScript -Encoding UTF8

# ---------------------------
# TASK RUNNER
# ---------------------------
$taskRunner = @'
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
'@

Set-Content -Path (Join-Path $scripts "task_runner.ps1") -Value $taskRunner -Encoding UTF8

# ---------------------------
# GIT INIT (SAFE)
# ---------------------------
Set-Location $workspace
if (-not (Test-Path ".git")) {
    git init | Out-Null
}

# ---------------------------
# TEST EXECUTION
# ---------------------------
Write-Host "Running Python test..."
python C:\Users\yonsh\Vex\scripts\test_python.py

Write-Host "Running Node test..."
node C:\Users\yonsh\Vex\scripts\test_node.js

Write-Host "Running task runner test..."
powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\task_runner.ps1 -Task "python-test"

# ---------------------------
# CHECK FILE
# ---------------------------
$phase4Check = @'
[ ] tool-registry.md created
[ ] test_python.py created
[ ] test_node.js created
[ ] task_runner.ps1 created
[ ] python script runs
[ ] node script runs
[ ] task runner executes python-test
[ ] python-test.log created
[ ] node-test.log created
[ ] task-runner.log created
[ ] git initialized in workspace
'@

Set-Content -Path (Join-Path $logs "phase4-check.txt") -Value $phase4Check -Encoding UTF8

Write-Host ""
Write-Host "Phase 4 setup complete."
Write-Host "Check logs in:"
Write-Host "$logs"