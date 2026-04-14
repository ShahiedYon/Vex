$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"

$orchestratorPath = Join-Path $scripts "phase12_startup_orchestrator.ps1"
$healthPath = Join-Path $scripts "phase12_health_check.ps1"
$bootLog = Join-Path $logs "phase12-boot.log"
$healthFile = Join-Path $logs "phase12-health.txt"

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

$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$ollamaProc = Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Select-Object -First 1
$openclawRunning = Is-OpenClawRunning
$loopRunning = Is-QueueLoopRunning

$lines = @()
$lines += "Vex Phase 12 Health Report"
$lines += "Timestamp: $ts"
$lines += ""
$lines += ("Ollama Running: " + ($(if ($ollamaProc) { "YES" } else { "NO" })))
$lines += ("OpenClaw Gateway Running: " + ($(if ($openclawRunning) { "YES" } else { "NO" })))
$lines += ("Vex Queue Loop Running: " + ($(if ($loopRunning) { "YES" } else { "NO" })))

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
        Start-Sleep -Seconds 10
    }
}

Write-Log "Startup orchestrator started (fixed)"

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
    -IsRunning { Is-OpenClawRunning } `
    -Starter {
        if (Test-Path $openclawCmd) {
            Start-Process cmd.exe -ArgumentList "/c `"$openclawCmd`"" -WindowStyle Hidden
        }
        else {
            Write-Log "OpenClaw Gateway.cmd not found"
        }
    }

Start-IfNotRunning -Label "Vex Queue Loop" `
    -IsRunning { Is-QueueLoopRunning } `
    -Starter {
        if (Test-Path $loopStartScript) {
            Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$loopStartScript`""
        }
        else {
            Write-Log "phase11_start_now.ps1 not found"
        }
    }

if (Test-Path $healthScript) {
    Write-Log "Running health check"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $healthScript | Out-Null
}
else {
    Write-Log "Health check script missing"
}

Write-Log "Startup orchestrator finished (fixed)"
'@

Write-Utf8NoBom -Path $healthPath -Content $healthScript
Write-Utf8NoBom -Path $orchestratorPath -Content $orchestratorScript

powershell.exe -NoProfile -ExecutionPolicy Bypass -File $orchestratorPath

Write-Host ""
Write-Host "Phase 12 OpenClaw detection fix applied."
Write-Host "Check:"
Write-Host $bootLog
Write-Host $healthFile