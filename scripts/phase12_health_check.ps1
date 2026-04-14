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