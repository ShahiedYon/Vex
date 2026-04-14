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