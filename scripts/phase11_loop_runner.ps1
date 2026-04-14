$ErrorActionPreference = "Continue"

$flagFile = "C:\Users\yonsh\Vex\phase11-loop.enabled"
$queueRunner = "C:\Users\yonsh\Vex\scripts\phase10_queue_runner.ps1"
$loopLog = "C:\Users\yonsh\Vex\logs\phase11-loop.log"

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $loopLog -Value "[$ts] $Message" -Encoding UTF8
}

Write-Log "Loop runner process started"

while (Test-Path $flagFile) {
    try {
        Write-Log "Loop cycle started"

        if (Test-Path $queueRunner) {
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File $queueRunner | Out-Null
            Write-Log "Queue runner completed"
        }
        else {
            Write-Log "Queue runner missing: $queueRunner"
        }
    }
    catch {
        Write-Log "Loop cycle failed: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 300
}

Write-Log "Loop runner stopped because flag file is missing"