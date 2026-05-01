# Vex shared environment helper
# Dot-source from scripts using: . "$PSScriptRoot\vex_env.ps1"

$script:VexRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$script:VexScripts = Join-Path $script:VexRoot "scripts"
$script:VexBrowser = Join-Path $script:VexRoot "browser"
$script:VexWorkspace = Join-Path $script:VexRoot "workspace"
$script:VexLogs = Join-Path $script:VexRoot "logs"
$script:VexWorkspaceLogs = Join-Path $script:VexWorkspace "logs"
$script:VexConfig = Join-Path $script:VexRoot "config"
$script:VexData = Join-Path $script:VexRoot "data"
$script:VexMemory = Join-Path $script:VexRoot "memory"
$script:VexTasks = Join-Path $script:VexRoot "tasks"

function Ensure-VexDirectory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

Ensure-VexDirectory -Path $script:VexWorkspace
Ensure-VexDirectory -Path $script:VexLogs
Ensure-VexDirectory -Path $script:VexWorkspaceLogs
Ensure-VexDirectory -Path $script:VexMemory
Ensure-VexDirectory -Path $script:VexTasks
