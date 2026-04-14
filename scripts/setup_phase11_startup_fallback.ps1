$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"
$startup = [Environment]::GetFolderPath("Startup")

$loopRunnerPath = Join-Path $scripts "phase11_loop_runner.ps1"
$startNowPath = Join-Path $scripts "phase11_start_now.ps1"
$stopPath = Join-Path $scripts "phase11_stop_loop.ps1"
$startupCmdPath = Join-Path $startup "VexQueueRunner.cmd"
$startupFlag = Join-Path $base "phase11-loop.enabled"
$loopLog = Join-Path $logs "phase11-loop.log"
$checkFile = Join-Path $logs "phase11-check.txt"

foreach ($dir in @($base, $logs, $scripts)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$loopRunner = @'
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
'@

$startNow = @'
$ErrorActionPreference = "Stop"

$flagFile = "C:\Users\yonsh\Vex\phase11-loop.enabled"
$loopRunner = "C:\Users\yonsh\Vex\scripts\phase11_loop_runner.ps1"

if (-not (Test-Path $flagFile)) {
    New-Item -Path $flagFile -ItemType File -Force | Out-Null
}

Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$loopRunner`""
Write-Host "Vex loop runner started."
'@

$stopLoop = @'
$ErrorActionPreference = "Stop"

$flagFile = "C:\Users\yonsh\Vex\phase11-loop.enabled"

if (Test-Path $flagFile) {
    Remove-Item $flagFile -Force
    Write-Host "Vex loop stop flag removed. Current loop will exit after its sleep cycle."
}
else {
    Write-Host "Flag file already absent."
}
'@

$startupCmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\yonsh\Vex\scripts\phase11_start_now.ps1"
'@

Write-Utf8NoBom -Path $loopRunnerPath -Content $loopRunner
Write-Utf8NoBom -Path $startNowPath -Content $startNow
Write-Utf8NoBom -Path $stopPath -Content $stopLoop
Write-Utf8NoBom -Path $startupCmdPath -Content $startupCmd

Set-Content -Path $loopLog -Value "" -Encoding UTF8

if (-not (Test-Path $startupFlag)) {
    New-Item -Path $startupFlag -ItemType File -Force | Out-Null
}

powershell.exe -NoProfile -ExecutionPolicy Bypass -File $startNowPath

$checks = @'
[ ] phase11_loop_runner.ps1 created
[ ] phase11_start_now.ps1 created
[ ] phase11_stop_loop.ps1 created
[ ] VexQueueRunner.cmd created in Startup folder
[ ] phase11-loop.enabled created
[ ] phase11-loop.log created
[ ] background loop started
'@

Set-Content -Path $checkFile -Value $checks -Encoding UTF8

Write-Host ""
Write-Host "Phase 11 fallback setup complete."
Write-Host "Review these:"
Write-Host "Startup CMD: $startupCmdPath"
Write-Host "Loop log: C:\Users\yonsh\Vex\logs\phase11-loop.log"
Write-Host "Stop script: C:\Users\yonsh\Vex\scripts\phase11_stop_loop.ps1"