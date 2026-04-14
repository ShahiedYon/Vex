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

$taskName = "VexQueueRunner"
$launcherPath = Join-Path $scripts "phase11_run_queue.ps1"
$removePath = Join-Path $scripts "phase11_remove_schedule.ps1"
$manualPath = Join-Path $scripts "phase11_run_now.ps1"
$scheduleLog = Join-Path $logs "phase11-schedule.log"
$checkFile = Join-Path $logs "phase11-check.txt"

foreach ($dir in @($base, $workspace, $logs, $scripts, $tasks, $queue, $pending, $completed, $failed)) {
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

function Test-SchtaskExists {
    param([string]$Name)

    $null = & schtasks.exe /Query /TN $Name 2>$null
    return ($LASTEXITCODE -eq 0)
}

# -----------------------------------
# Queue launcher script
# -----------------------------------
$launcher = @'
$ErrorActionPreference = "Stop"

$queueRunner = "C:\Users\yonsh\Vex\scripts\phase10_queue_runner.ps1"
$scheduleLog = "C:\Users\yonsh\Vex\logs\phase11-schedule.log"

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $scheduleLog -Value "[$ts] $Message" -Encoding UTF8
}

try {
    Write-Log "Scheduled run started"

    if (-not (Test-Path $queueRunner)) {
        Write-Log "Queue runner not found: $queueRunner"
        exit 1
    }

    powershell.exe -ExecutionPolicy Bypass -File $queueRunner | Out-Null

    Write-Log "Scheduled run finished successfully"
}
catch {
    Write-Log "Scheduled run failed: $($_.Exception.Message)"
    exit 1
}
'@

Write-Utf8NoBom -Path $launcherPath -Content $launcher

# -----------------------------------
# Manual run-now helper
# -----------------------------------
$manualRun = @'
$ErrorActionPreference = "Stop"
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\yonsh\Vex\scripts\phase11_run_queue.ps1"
Write-Host "Phase 11 manual queue run triggered."
'@

Write-Utf8NoBom -Path $manualPath -Content $manualRun

# -----------------------------------
# Remove scheduled task helper
# -----------------------------------
$removeScript = @'
$ErrorActionPreference = "Stop"

$taskName = "VexQueueRunner"

$null = & schtasks.exe /Query /TN $taskName 2>$null
if ($LASTEXITCODE -eq 0) {
    & schtasks.exe /Delete /TN $taskName /F | Out-Null
    Write-Host "Scheduled task removed: $taskName"
}
else {
    Write-Host "Scheduled task not found: $taskName"
}
'@

Write-Utf8NoBom -Path $removePath -Content $removeScript

# -----------------------------------
# Reset log
# -----------------------------------
Set-Content -Path $scheduleLog -Value "" -Encoding UTF8

# -----------------------------------
# Remove old task if present
# -----------------------------------
if (Test-SchtaskExists -Name $taskName) {
    & schtasks.exe /Delete /TN $taskName /F | Out-Null
}

# -----------------------------------
# Create start time 1 minute from now
# -----------------------------------
$startTime = (Get-Date).AddMinutes(1).ToString("HH:mm")

# -----------------------------------
# Create task with schtasks
# -----------------------------------
$taskCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$launcherPath`""

& schtasks.exe /Create `
    /TN $taskName `
    /SC MINUTE `
    /MO 5 `
    /ST $startTime `
    /TR $taskCommand `
    /F | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create scheduled task."
}

# -----------------------------------
# Immediate validation run
# -----------------------------------
powershell.exe -ExecutionPolicy Bypass -File $launcherPath

# -----------------------------------
# Check file
# -----------------------------------
$checks = @'
[ ] phase11_run_queue.ps1 created
[ ] phase11_run_now.ps1 created
[ ] phase11_remove_schedule.ps1 created
[ ] VexQueueRunner scheduled task registered
[ ] scheduled task set to repeat every 5 minutes
[ ] phase11-schedule.log created
[ ] immediate validation run executed
'@

Set-Content -Path $checkFile -Value $checks -Encoding UTF8

Write-Host ""
Write-Host "Phase 11 schtasks v2 setup complete."
Write-Host "Review these:"
Write-Host "C:\Users\yonsh\Vex\logs\phase11-schedule.log"
Write-Host "Scheduled Task name: $taskName"
Write-Host "Manual run script: $manualPath"
Write-Host "Remove schedule script: $removePath"