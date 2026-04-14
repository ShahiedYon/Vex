$ErrorActionPreference = "Stop"

$flagFile = "C:\Users\yonsh\Vex\phase11-loop.enabled"
$loopRunner = "C:\Users\yonsh\Vex\scripts\phase11_loop_runner.ps1"

if (-not (Test-Path $flagFile)) {
    New-Item -Path $flagFile -ItemType File -Force | Out-Null
}

Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$loopRunner`""
Write-Host "Vex loop runner started."