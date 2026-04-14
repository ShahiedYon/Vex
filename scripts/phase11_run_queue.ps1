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