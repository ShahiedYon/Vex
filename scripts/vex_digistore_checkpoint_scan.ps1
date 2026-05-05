param(
    [string]$Root = "",
    [string]$Keywords = "debt,credit,finance,budget,money,loan,financial wellness",
    [int]$TimeoutMinutes = 30,
    [switch]$OpenResults
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot }
    else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$checkpointScript = Join-Path $Root "scripts\vex_human_checkpoint.ps1"
$autoscanScript = Join-Path $Root "scripts\vex_digistore_autoscan.ps1"

if (-not (Test-Path $checkpointScript)) { throw "Missing checkpoint script: $checkpointScript" }
if (-not (Test-Path $autoscanScript)) { throw "Missing autoscan script: $autoscanScript" }

$message = "Please log in to Digistore24 in the browser window. Then go to Affiliate View and open Marketplace. When marketplace is visible, confirm done so Vex can continue scanning."

powershell -ExecutionPolicy Bypass -File $checkpointScript -Root $Root -Name "digistore_login" -Message $message -ConfirmText "done" -TimeoutMinutes $TimeoutMinutes -CreateOnly -Open

Write-Host ""
Write-Host "Checkpoint created. Log in to Digistore in the browser window." -ForegroundColor Yellow
Write-Host "When ready, open another PowerShell window in C:\Users\yonsh\Vex and run:" -ForegroundColor Yellow
Write-Host "powershell -ExecutionPolicy Bypass -File .\scripts\vex_human_checkpoint.ps1 -Name digistore_login -MarkDone" -ForegroundColor White
Write-Host ""

powershell -ExecutionPolicy Bypass -File $checkpointScript -Root $Root -Name "digistore_login" -TimeoutMinutes $TimeoutMinutes -WaitOnly

if ($OpenResults) {
    powershell -ExecutionPolicy Bypass -File $autoscanScript -Root $Root -Keywords $Keywords -OpenResults
}
else {
    powershell -ExecutionPolicy Bypass -File $autoscanScript -Root $Root -Keywords $Keywords
}
