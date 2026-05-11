# Vex shared environment helper

$script:VexRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$script:VexScripts = Join-Path $script:VexRoot "scripts"
$script:VexWorkspace = Join-Path $script:VexRoot "workspace"
$script:VexLogs = Join-Path $script:VexRoot "logs"
$script:VexMemory = Join-Path $script:VexRoot "memory"
$script:VexTasks = Join-Path $script:VexRoot "tasks"

function Ensure-VexDirectory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

Ensure-VexDirectory $script:VexWorkspace
Ensure-VexDirectory $script:VexLogs
Ensure-VexDirectory $script:VexMemory
Ensure-VexDirectory $script:VexTasks
