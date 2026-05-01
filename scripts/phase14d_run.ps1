param(
    [string]$InputDir = "",
    [string]$OutputDir = "",
    [string]$RulesFile = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\vex_env.ps1"

if ([string]::IsNullOrWhiteSpace($InputDir)) {
    $InputDir = Join-Path $VexWorkspace "reports"
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $VexWorkspace "scored"
}
if ([string]::IsNullOrWhiteSpace($RulesFile)) {
    $RulesFile = Join-Path $VexConfig "lead_scoring_rules.json"
}

$null = New-Item -ItemType Directory -Force -Path $OutputDir

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$summaryCsv = Join-Path $OutputDir ("lead_score_summary_" + $timestamp + ".csv")
$logFile = Join-Path $VexWorkspaceLogs ("phase14d_" + $timestamp + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

Write-Log "Starting Phase 14d batch scoring"
Write-Log "InputDir=$InputDir"
Write-Log "OutputDir=$OutputDir"

$files = Get-ChildItem -Path $InputDir -Filter *.json -File
if ($files.Count -eq 0) {
    Write-Log "No JSON report files found."
    exit 0
}

$rows = New-Object System.Collections.Generic.List[object]

for ($i = 0; $i -lt $files.Count; $i++) {
    $file = $files[$i]
    $outFile = Join-Path $OutputDir ($file.BaseName + ".scored.json")

    try {
        Write-Log ("Scoring " + $file.FullName)
        & (Join-Path $VexScripts "score_lead.ps1") -InputFile $file.FullName -RulesFile $RulesFile -OutputFile $outFile

        $scored = Get-Content -Raw -Path $outFile | ConvertFrom-Json
        $rows.Add([pscustomobject]@{
            url = $scored.url
            lead_score = $scored.lead_score
            quality = $scored.quality
            recommendation = $scored.recommendation
            reasons = (($scored.reasons | ForEach-Object { [string]$_ }) -join "; ")
        }) | Out-Null

        Write-Log ("SUCCESS " + $outFile)
    }
    catch {
        Write-Log ("FAILED " + $file.FullName + " :: " + $_.Exception.Message)
    }
}

if ($rows.Count -gt 0) {
    $rows | Export-Csv -Path $summaryCsv -NoTypeInformation -Encoding UTF8
    Write-Log ("Summary created: " + $summaryCsv)
}

Write-Log "Phase 14d batch scoring complete"
