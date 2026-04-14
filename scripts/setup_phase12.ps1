$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"
$startup = [Environment]::GetFolderPath("Startup")

$orchestratorPath = Join-Path $scripts "phase12_startup_orchestrator.ps1"
$manualHealthPath = Join-Path $scripts "phase12_health_check.ps1"
$startupCmdPath = Join-Path $startup "VexStartupOrchestrator.cmd"
$bootLog = Join-Path $logs "phase12-boot.log"
$healthFile = Join-Path $logs "phase12-health.txt"
$checkFile = Join-Path $logs "phase12-check.txt"

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

$healthScript = @'
$ErrorActionPreference = "Continue"

$bootLog = "C:\Users\yonsh\Vex\logs\phase12-boot.log"
$healthFile = "C:\Users\yonsh\Vex\logs\phase12-health.txt"

function Find-ProcMatch {
    param(
        [string]$Name,
        [string]$Needle
    )
    $procs = Get-CimInstance Win32_Process -Filter "Name = '$Name'" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.CommandLine -and $p.CommandLine -like "*$Needle*") {
            return $p
        }
    }
    return $null
}

$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$ollamaProc = Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Select-Object -First 1
$gatewayProc = Find-ProcMatch -Name "cmd.exe" -Needle "OpenClaw Gateway.cmd"
$loopProc = Find-ProcMatch -Name "powershell.exe" -Needle "phase11_loop_runner.ps1"

$lines = @()
$lines += "Vex Phase 12 Health Report"
$lines += "Timestamp: $ts"
$lines += ""
$lines += ("Ollama Running: " + ($(if ($ollamaProc) { "YES" } else { "NO" })))
$lines += ("OpenClaw Gateway Running: " + ($(if ($gatewayProc) { "YES" } else { "NO" })))
$lines += ("Vex Queue Loop Running: " + ($(if ($loopProc) { "YES" } else { "NO" })))

Set-Content -Path $healthFile -Value $lines -Encoding UTF8
Add-Content -Path $bootLog -Value "[$ts] Health report written" -Encoding UTF8

Write-Host "Health check complete."
Write-Host $healthFile
'@

$orchestratorScript = @'
$ErrorActionPreference = "Continue"

$bootLog = "C:\Users\yonsh\Vex\logs\phase12-boot.log"
$healthScript = "C:\Users\yonsh\Vex\scripts\phase12_health_check.ps1"
$loopStartScript = "C:\Users\yonsh\Vex\scripts\phase11_start_now.ps1"
$ollamaShortcut = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup\Ollama.lnk")
$openclawCmd = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup\OpenClaw Gateway.cmd")

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $bootLog -Value "[$ts] $Message" -Encoding UTF8
}

function Find-ProcMatch {
    param(
        [string]$Name,
        [string]$Needle
    )
    $procs = Get-CimInstance Win32_Process -Filter "Name = '$Name'" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.CommandLine -and $p.CommandLine -like "*$Needle*") {
            return $p
        }
    }
    return $null
}

function Start-IfNotRunning {
    param(
        [string]$Label,
        [scriptblock]$IsRunning,
        [scriptblock]$Starter
    )

    $running = & $IsRunning
    if ($running) {
        Write-Log "$Label already running"
    }
    else {
        Write-Log "Starting $Label"
        & $Starter
        Start-Sleep -Seconds 8
    }
}

Set-Content -Path $bootLog -Value "" -Encoding UTF8
Write-Log "Startup orchestrator started"

Start-IfNotRunning -Label "Ollama" `
    -IsRunning { Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Select-Object -First 1 } `
    -Starter {
        if (Test-Path $ollamaShortcut) {
            Start-Process $ollamaShortcut
        }
        else {
            Start-Process "ollama"
        }
    }

Start-IfNotRunning -Label "OpenClaw Gateway" `
    -IsRunning { Find-ProcMatch -Name "cmd.exe" -Needle "OpenClaw Gateway.cmd" } `
    -Starter {
        if (Test-Path $openclawCmd) {
            Start-Process $openclawCmd
        }
    }

Start-IfNotRunning -Label "Vex Queue Loop" `
    -IsRunning { Find-ProcMatch -Name "powershell.exe" -Needle "phase11_loop_runner.ps1" } `
    -Starter {
        if (Test-Path $loopStartScript) {
            Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$loopStartScript`""
        }
    }

if (Test-Path $healthScript) {
    Write-Log "Running health check"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $healthScript | Out-Null
}
else {
    Write-Log "Health check script missing"
}

Write-Log "Startup orchestrator finished"
'@

$startupCmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\yonsh\Vex\scripts\phase12_startup_orchestrator.ps1"
'@

Write-Utf8NoBom -Path $manualHealthPath -Content $healthScript
Write-Utf8NoBom -Path $orchestratorPath -Content $orchestratorScript
Write-Utf8NoBom -Path $startupCmdPath -Content $startupCmd

powershell.exe -NoProfile -ExecutionPolicy Bypass -File $orchestratorPath

$checks = @'
[ ] phase12_startup_orchestrator.ps1 created
[ ] phase12_health_check.ps1 created
[ ] VexStartupOrchestrator.cmd created in Startup folder
[ ] phase12-boot.log created
[ ] phase12-health.txt created
[ ] orchestrator validation run completed
[ ] duplicate-safe startup logic in place
'@

Set-Content -Path $checkFile -Value $checks -Encoding UTF8

Write-Host ""
Write-Host "Phase 12 setup complete."
Write-Host "Review these:"
Write-Host "C:\Users\yonsh\Vex\logs\phase12-boot.log"
Write-Host "C:\Users\yonsh\Vex\logs\phase12-health.txt"
Write-Host "$startupCmdPath"