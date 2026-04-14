$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"

$monitorPath = Join-Path $scripts "phase13_monitor.ps1"
$runNowPath = Join-Path $scripts "phase13_run_now.ps1"
$startup = [Environment]::GetFolderPath("Startup")
$startupCmdPath = Join-Path $startup "VexMonitor.cmd"
$monitorLog = Join-Path $logs "phase13-monitor.log"
$alertFile = Join-Path $logs "phase13-alerts.txt"
$checkFile = Join-Path $logs "phase13-check.txt"

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

$monitorScript = @'
$ErrorActionPreference = "Continue"

$monitorLog = "C:\Users\yonsh\Vex\logs\phase13-monitor.log"
$alertFile = "C:\Users\yonsh\Vex\logs\phase13-alerts.txt"
$ollamaShortcut = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup\Ollama.lnk")
$openclawCmd = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup\OpenClaw Gateway.cmd")
$loopStartScript = "C:\Users\yonsh\Vex\scripts\phase11_start_now.ps1"

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $monitorLog -Value "[$ts] $Message" -Encoding UTF8
}

function Write-Alert {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $alertFile -Value "[$ts] $Message" -Encoding UTF8
}

function Is-OpenClawRunning {
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.CommandLine -and (
            $p.CommandLine -like "*openclaw*" -or
            $p.CommandLine -like "*gateway*"
        )) {
            return $true
        }
    }
    return $false
}

function Is-QueueLoopRunning {
    $procs = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.CommandLine -and $p.CommandLine -like "*phase11_loop_runner.ps1*") {
            return $true
        }
    }
    return $false
}

function Start-OllamaIfNeeded {
    $proc = Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) {
        Write-Log "Ollama healthy"
        return
    }

    Write-Alert "Ollama not running. Attempting restart."
    if (Test-Path $ollamaShortcut) {
        Start-Process $ollamaShortcut
    }
    else {
        Start-Process "ollama"
    }
    Start-Sleep -Seconds 8

    $proc2 = Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc2) {
        Write-Log "Ollama restart succeeded"
    }
    else {
        Write-Alert "Ollama restart failed"
    }
}

function Start-OpenClawIfNeeded {
    if (Is-OpenClawRunning) {
        Write-Log "OpenClaw Gateway healthy"
        return
    }

    Write-Alert "OpenClaw Gateway not running. Attempting restart."
    if (Test-Path $openclawCmd) {
        Start-Process cmd.exe -ArgumentList "/c `"$openclawCmd`"" -WindowStyle Hidden
    }
    Start-Sleep -Seconds 10

    if (Is-OpenClawRunning) {
        Write-Log "OpenClaw Gateway restart succeeded"
    }
    else {
        Write-Alert "OpenClaw Gateway restart failed"
    }
}

function Start-LoopIfNeeded {
    if (Is-QueueLoopRunning) {
        Write-Log "Vex Queue Loop healthy"
        return
    }

    Write-Alert "Vex Queue Loop not running. Attempting restart."
    if (Test-Path $loopStartScript) {
        Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$loopStartScript`""
    }
    Start-Sleep -Seconds 5

    if (Is-QueueLoopRunning) {
        Write-Log "Vex Queue Loop restart succeeded"
    }
    else {
        Write-Alert "Vex Queue Loop restart failed"
    }
}

Write-Log "Phase 13 monitor cycle started"
Start-OllamaIfNeeded
Start-OpenClawIfNeeded
Start-LoopIfNeeded
Write-Log "Phase 13 monitor cycle finished"
'@

$runNowScript = @'
$ErrorActionPreference = "Stop"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\yonsh\Vex\scripts\phase13_monitor.ps1"
Write-Host "Phase 13 monitor run triggered."
'@

$startupCmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\yonsh\Vex\scripts\phase13_monitor.ps1"
'@

Write-Utf8NoBom -Path $monitorPath -Content $monitorScript
Write-Utf8NoBom -Path $runNowPath -Content $runNowScript
Write-Utf8NoBom -Path $startupCmdPath -Content $startupCmd

Set-Content -Path $monitorLog -Value "" -Encoding UTF8
Set-Content -Path $alertFile -Value "" -Encoding UTF8

powershell.exe -NoProfile -ExecutionPolicy Bypass -File $monitorPath

$checks = @'
[ ] phase13_monitor.ps1 created
[ ] phase13_run_now.ps1 created
[ ] VexMonitor.cmd created in Startup folder
[ ] phase13-monitor.log created
[ ] phase13-alerts.txt created
[ ] monitor validation run completed
[ ] self-healing checks in place
'@

Set-Content -Path $checkFile -Value $checks -Encoding UTF8

Write-Host ""
Write-Host "Phase 13 setup complete."
Write-Host "Review:"
Write-Host "C:\Users\yonsh\Vex\logs\phase13-monitor.log"
Write-Host "C:\Users\yonsh\Vex\logs\phase13-alerts.txt"
Write-Host $startupCmdPath