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