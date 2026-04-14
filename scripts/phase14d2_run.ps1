param(
    [string]$InputDir = "C:\Users\yonsh\Vex\workspace\scored",
    [string]$OutputDir = "C:\Users\yonsh\Vex\workspace\enhanced"
)

$ErrorActionPreference = "Stop"

function Contains-Any($text, $keywords) {
    foreach ($k in $keywords) {
        if ($text -match $k) { return $true }
    }
    return $false
}

function Get-Stream($text) {
    if (Contains-Any $text @("solar","panel","energy")) { return "solar" }
    if (Contains-Any $text @("debt","credit","loan","payment")) { return "debt_relief" }
    return "vextly"
}

function Get-IntentScore($text) {
    $score = 0
    if ($text -match "debt|credit|loan") { $score += 30 }
    if ($text -match "can't pay|behind|drowning|help|struggling") { $score += 40 }
    if ($text -match "usa|us|texas|california|ny") { $score += 10 }
    return $score
}

function Get-Urgency($score) {
    if ($score -ge 70) { return "High" }
    if ($score -ge 40) { return "Medium" }
    return "Low"
}

function Get-AIEngine($leadScore, $intentScore) {
    if ($intentScore -ge 80 -or $leadScore -ge 75) { return "openai" }
    if ($intentScore -ge 50 -or $leadScore -ge 50) { return "openrouter" }
    return "local"
}

function Get-Action($urgency) {
    if ($urgency -eq "High") { return "Immediate Outreach" }
    if ($urgency -eq "Medium") { return "Review + Engage" }
    return "Low Priority"
}

$files = Get-ChildItem $InputDir -Filter *.json -ErrorAction SilentlyContinue

if ($files.Count -eq 0) {
    Write-Host "No scored files found. Run Phase 14d first."
    exit
}

foreach ($file in $files) {

    $data = Get-Content $file.FullName -Raw | ConvertFrom-Json

    $text = ($data.url + " " + ($data.reasons -join " ")).ToLower()

    $stream = Get-Stream $text
    $intent = Get-IntentScore $text
    $urgency = Get-Urgency $intent
    $engine = Get-AIEngine $data.lead_score $intent
    $action = Get-Action $urgency

    $output = [ordered]@{
        url = $data.url
        stream = $stream
        lead_score = $data.lead_score
        intent_score = $intent
        urgency = $urgency
        ai_engine = $engine
        recommended_action = $action
        scored_at = (Get-Date).ToString("s")
    }

    $outPath = "$OutputDir\" + $file.BaseName + ".enhanced.json"
    $output | ConvertTo-Json -Depth 10 | Set-Content $outPath
}

Write-Host "Phase 14d.2 complete"
