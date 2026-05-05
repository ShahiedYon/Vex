param(
    [string]$Root = "",
    [string]$ReportPath = "",
    [switch]$Open
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) {
        $Root = Split-Path -Parent $PSScriptRoot
    }
    else {
        $Root = (Get-Location).Path
    }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$workspace = Join-Path $Root "workspace"
$logs = Join-Path $Root "logs"
Ensure-Directory $workspace
Ensure-Directory $logs

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $latest = Get-ChildItem -Path $workspace -Filter "site_report_14c_*.txt" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -ne $latest) { $ReportPath = $latest.FullName }
}

if ([string]::IsNullOrWhiteSpace($ReportPath) -or -not (Test-Path $ReportPath)) {
    throw "No phase14c site report found. Run: powershell -ExecutionPolicy Bypass -File .\scripts\phase14c_run.ps1 -url https://moneycrunchusa.netlify.app/"
}

$text = Get-Content -Path $ReportPath -Raw
$lines = Get-Content -Path $ReportPath

function Get-LabelValue {
    param([string]$Label)
    foreach ($line in $lines) {
        if ($line.StartsWith($Label)) { return $line.Substring($Label.Length).Trim() }
    }
    return ""
}

$url = Get-LabelValue "URL:"
$title = Get-LabelValue "Title:"
$h1 = Get-LabelValue "H1:"
$status = Get-LabelValue "Status:"
$screenshot = Get-LabelValue "Screenshot:"

$score = 0
if ($status -eq "SUCCESS") { $score += 25 }
if ($title.Length -gt 0) { $score += 10 }
if ($h1.Length -gt 0) { $score += 10 }
if ($text -match "First Name" -and $text -match "Email" -and $text -match "Phone Number") { $score += 25 }
if ($text -match "Secure" -and $text -match "No Obligation") { $score += 10 }
if ($text -notmatch "Discovered Contact/About Pages:\s*\r?\n- None found") { $score += 5 }
if ($text -notmatch "Emails:\s*\r?\n- Not found") { $score += 5 }
if ($text -notmatch "Phones:\s*\r?\n- Not found") { $score += 5 }
if ($text -notmatch "Social Links:\s*\r?\n- Not found") { $score += 5 }

$outFile = Join-Path $workspace "moneycrunch_site_action.txt"
$out = @()
$out += "MONEYCRUNCH LIVE SITE ACTION SUMMARY"
$out += "===================================="
$out += "Generated: " + (Get-Date).ToString("s")
$out += "Source report: " + $ReportPath
$out += ""
$out += "URL: " + $url
$out += "Title: " + $title
$out += "H1: " + $h1
$out += "Status: " + $status
$out += "Screenshot: " + $screenshot
$out += "Readiness score: " + $score + "/100"
$out += ""
$out += "WHAT WORKS"
$out += "- Vex can load and scan the live MoneyCrunch page."
$out += "- The form and core debt-relief message are visible."
$out += ""
$out += "MAIN GAPS"
if ($text -match "Discovered Contact/About Pages:\s*\r?\n- None found") { $out += "- Add a Contact or About page/link." }
if ($text -match "Emails:\s*\r?\n- Not found") { $out += "- Add a public support/contact email." }
if ($text -match "Phones:\s*\r?\n- Not found") { $out += "- Phone not found. Optional, but useful later." }
if ($text -match "Social Links:\s*\r?\n- Not found") { $out += "- Social links not found. Optional, but useful later." }
$out += ""
$out += "NEXT FIX ORDER"
$out += "1. Add footer links: Privacy Policy, Terms, Contact."
$out += "2. Add a basic contact email."
$out += "3. Re-run phase14c and this summary script."
$out += ""
$out += "NEXT COMMANDS"
$out += "powershell -ExecutionPolicy Bypass -File .\scripts\phase14c_run.ps1 -url https://moneycrunchusa.netlify.app/"
$out += "powershell -ExecutionPolicy Bypass -File .\scripts\vex_site_report_summary.ps1 -Open"

Set-Content -Path $outFile -Value $out -Encoding UTF8
Add-Content -Path (Join-Path $logs "vex_site_report_summary.log") -Value ("Created summary from " + $ReportPath) -Encoding UTF8

Write-Host "MoneyCrunch site action summary created:" -ForegroundColor Green
Write-Host $outFile

if ($Open) { notepad $outFile }
