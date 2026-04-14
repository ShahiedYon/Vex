$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$scripts = Join-Path $base "scripts"
$workspace = Join-Path $base "workspace"
$logs = Join-Path $base "logs"
$inputDir = Join-Path $base "inputs"

$csvPath = Join-Path $inputDir "phase14b_leads.csv"
$runnerPath = Join-Path $scripts "phase14b_run.ps1"
$batchLog = Join-Path $logs "phase14b.log"
$checkFile = Join-Path $logs "phase14b-check.txt"

foreach ($dir in @($scripts, $workspace, $logs, $inputDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$sampleCsv = @'
Company,URL
Example,https://example.com
'@

Set-Content -Path $csvPath -Value $sampleCsv -Encoding UTF8

$runner = @'
param(
    [string]$CsvPath = "C:\Users\yonsh\Vex\inputs\phase14b_leads.csv"
)

$ErrorActionPreference = "Continue"

$base = "C:\Users\yonsh\Vex"
$workspace = Join-Path $base "workspace"
$logFile = Join-Path $base "logs\phase14b.log"
$summaryFile = Join-Path $workspace "phase14b-summary.txt"
$singleRunner = Join-Path $base "scripts\phase14_run.ps1"

function Safe-Name {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "unknown" }
    $name = $Text -replace '[\\/:*?"<>|]', '_'
    $name = $name -replace '\s+', '_'
    return $name
}

if (-not (Test-Path $CsvPath)) {
    Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Missing CSV: " + $CsvPath) -Encoding UTF8
    Write-Host "CSV not found."
    exit 1
}

$rows = Import-Csv -Path $CsvPath
$summary = @()
$summary += "Vex Phase 14b Batch Summary"
$summary += "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$summary += ""

foreach ($row in $rows) {
    $company = $row.Company
    $url = $row.URL
    $safeCompany = Safe-Name -Text $company
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"

    Add-Content -Path $logFile -Value ("[" + $ts + "] Processing: " + $company + " | " + $url) -Encoding UTF8

    powershell.exe -ExecutionPolicy Bypass -File $singleRunner -url $url | Out-Null

    $latestReport = Get-ChildItem -Path $workspace -Filter "site_report_*.txt" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestReport) {
        $newReportName = "lead_" + $safeCompany + "_" + $ts + ".txt"
        $newReportPath = Join-Path $workspace $newReportName
        Copy-Item -Path $latestReport.FullName -Destination $newReportPath -Force

        $latestPng = $latestReport.FullName -replace '\.txt$', '.png'
        if (Test-Path $latestPng) {
            $newPngName = "lead_" + $safeCompany + "_" + $ts + ".png"
            $newPngPath = Join-Path $workspace $newPngName
            Copy-Item -Path $latestPng -Destination $newPngPath -Force
        }

        $summary += "Company: $company"
        $summary += "URL: $url"
        $summary += "Report: $newReportPath"
        $summary += "Status: SUCCESS"
        $summary += ""
        Add-Content -Path $logFile -Value ("[" + $ts + "] SUCCESS: " + $company) -Encoding UTF8
    }
    else {
        $summary += "Company: $company"
        $summary += "URL: $url"
        $summary += "Status: FAILED"
        $summary += ""
        Add-Content -Path $logFile -Value ("[" + $ts + "] FAILED: " + $company) -Encoding UTF8
    }

    Start-Sleep -Seconds 2
}

Set-Content -Path $summaryFile -Value $summary -Encoding UTF8
Write-Host "Batch complete."
Write-Host $summaryFile
'@

Set-Content -Path $runnerPath -Value $runner -Encoding UTF8

$checks = @'
[ ] phase14b_leads.csv created
[ ] phase14b_run.ps1 created
[ ] phase14b.log created
[ ] phase14b-summary.txt will be created on run
[ ] batch runner ready
'@

Set-Content -Path $checkFile -Value $checks -Encoding UTF8

Write-Host ""
Write-Host "Phase 14b setup complete."
Write-Host "Run with:"
Write-Host "powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\phase14b_run.ps1"
Write-Host ""
Write-Host "Edit your input CSV here:"
Write-Host $csvPath