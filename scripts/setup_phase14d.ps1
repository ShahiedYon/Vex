$ErrorActionPreference = "Stop"

$root = "C:\Users\yonsh\Vex"
$scriptsDir = Join-Path $root "scripts"
$workspaceDir = Join-Path $root "workspace"
$reportsDir = Join-Path $workspaceDir "reports"
$scoredDir = Join-Path $workspaceDir "scored"
$logsDir = Join-Path $workspaceDir "logs"
$configDir = Join-Path $root "config"

$null = New-Item -ItemType Directory -Force -Path $scriptsDir
$null = New-Item -ItemType Directory -Force -Path $workspaceDir
$null = New-Item -ItemType Directory -Force -Path $reportsDir
$null = New-Item -ItemType Directory -Force -Path $scoredDir
$null = New-Item -ItemType Directory -Force -Path $logsDir
$null = New-Item -ItemType Directory -Force -Path $configDir

$rulesJson = @'
{
  "weights": {
    "email_found": 30,
    "phone_found": 20,
    "contact_page_found": 15,
    "about_page_found": 5,
    "linkedin_found": 10,
    "facebook_found": 5,
    "instagram_found": 5,
    "x_found": 3,
    "title_present": 3,
    "h1_present": 3,
    "preview_present": 2,
    "https_site": 2,
    "multiple_emails": 3,
    "multiple_phones": 3,
    "cross_page_contact_signals": 4,
    "no_email_no_phone": -25,
    "placeholder_site": -40,
    "social_only_no_direct_contact": -10
  },
  "qualityBands": {
    "high_min": 80,
    "medium_min": 50
  },
  "placeholderPatterns": [
    "domain for sale",
    "coming soon",
    "under construction",
    "parked",
    "buy this domain"
  ]
}
'@

Set-Content -Path (Join-Path $configDir "lead_scoring_rules.json") -Value $rulesJson -Encoding UTF8

$scoreLeadScript = @'
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$RulesFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

$ErrorActionPreference = "Stop"

function Get-ArrayCount {
    param([object]$Value)
    if ($null -eq $Value) { return 0 }
    if ($Value -is [System.Array]) { return $Value.Count }
    return 1
}

function Get-FirstNonEmptyText {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    return $text.Trim()
}

function Test-HasItems {
    param([object]$Value)
    return ((Get-ArrayCount -Value $Value) -gt 0)
}

function Add-ReasonAndScore {
    param(
        [ref]$Score,
        [ref]$Reasons,
        [int]$Points,
        [string]$Reason
    )
    $Score.Value += $Points
    $Reasons.Value.Add($Reason) | Out-Null
}

$rules = Get-Content -Raw -Path $RulesFile | ConvertFrom-Json
$data = Get-Content -Raw -Path $InputFile | ConvertFrom-Json

$score = 0
$reasons = New-Object System.Collections.Generic.List[string]

$status = Get-FirstNonEmptyText -Value $data.status
if ($status -ne "" -and $status -ne "success") {
    $result = [ordered]@{
        url = $data.url
        lead_score = 0
        quality = "Low"
        recommendation = "Skip"
        reasons = @("Site unreachable or failed during extraction")
        scored_at = (Get-Date).ToString("s")
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFile -Encoding UTF8
    exit 0
}

$weights = $rules.weights

$emails = $data.emails
$phones = $data.phones
$contactPages = $data.contact_pages
$aboutPages = $data.about_pages

$linkedin = $null
$facebook = $null
$instagram = $null
$xlinks = $null

if ($null -ne $data.social_links) {
    $linkedin = $data.social_links.linkedin
    $facebook = $data.social_links.facebook
    $instagram = $data.social_links.instagram
    $xlinks = $data.social_links.x
}

if (Test-HasItems -Value $emails) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.email_found -Reason "Email found"
}
if (Test-HasItems -Value $phones) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.phone_found -Reason "Phone found"
}
if (Test-HasItems -Value $contactPages) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.contact_page_found -Reason "Contact page found"
}
if (Test-HasItems -Value $aboutPages) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.about_page_found -Reason "About page found"
}
if (Test-HasItems -Value $linkedin) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.linkedin_found -Reason "LinkedIn detected"
}
if (Test-HasItems -Value $facebook) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.facebook_found -Reason "Facebook detected"
}
if (Test-HasItems -Value $instagram) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.instagram_found -Reason "Instagram detected"
}
if (Test-HasItems -Value $xlinks) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.x_found -Reason "X/Twitter detected"
}

$title = Get-FirstNonEmptyText -Value $data.title
$h1 = Get-FirstNonEmptyText -Value $data.h1
$preview = Get-FirstNonEmptyText -Value $data.preview

if ($title -ne "") {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.title_present -Reason "Title present"
}
if ($h1 -ne "") {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.h1_present -Reason "H1 present"
}
if ($preview -ne "") {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.preview_present -Reason "Preview present"
}

$httpsSite = $false
if ($null -ne $data.https) {
    $httpsSite = [bool]$data.https
} elseif ($null -ne $data.url) {
    $httpsSite = ([string]$data.url).StartsWith("https://")
}
if ($httpsSite) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.https_site -Reason "HTTPS site"
}

if ((Get-ArrayCount -Value $emails) -gt 1) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.multiple_emails -Reason "Multiple emails found"
}
if ((Get-ArrayCount -Value $phones) -gt 1) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.multiple_phones -Reason "Multiple phones found"
}

$hasDirectContact = ((Get-ArrayCount -Value $emails) -gt 0) -or ((Get-ArrayCount -Value $phones) -gt 0)
$hasCrossPageSignals = (((Get-ArrayCount -Value $contactPages) -gt 0) -or ((Get-ArrayCount -Value $aboutPages) -gt 0)) -and $hasDirectContact
if ($hasCrossPageSignals) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.cross_page_contact_signals -Reason "Contact signals found across pages"
}

if (-not $hasDirectContact) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.no_email_no_phone -Reason "No direct contact method found"
}

$combinedText = ($title + " " + $h1 + " " + $preview).ToLowerInvariant()
$placeholderHit = $false
for ($i = 0; $i -lt $rules.placeholderPatterns.Count; $i++) {
    $pattern = [string]$rules.placeholderPatterns[$i]
    if ($combinedText.Contains($pattern.ToLowerInvariant())) {
        $placeholderHit = $true
        break
    }
}
if ($placeholderHit) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.placeholder_site -Reason "Placeholder or parked site indicators found"
}

$hasSocial = ((Get-ArrayCount -Value $linkedin) -gt 0) -or ((Get-ArrayCount -Value $facebook) -gt 0) -or ((Get-ArrayCount -Value $instagram) -gt 0) -or ((Get-ArrayCount -Value $xlinks) -gt 0)
if ($hasSocial -and (-not $hasDirectContact)) {
    Add-ReasonAndScore -Score ([ref]$score) -Reasons ([ref]$reasons) -Points $weights.social_only_no_direct_contact -Reason "Social presence without direct contact path"
}

if ($score -lt 0) { $score = 0 }
if ($score -gt 100) { $score = 100 }

$quality = "Low"
$recommendation = "Skip"

if ($score -ge [int]$rules.qualityBands.high_min) {
    $quality = "High"
    $recommendation = "Pursue"
}
elseif ($score -ge [int]$rules.qualityBands.medium_min) {
    $quality = "Medium"
    $recommendation = "Review"
}

$result = [ordered]@{
    url = $data.url
    lead_score = $score
    quality = $quality
    recommendation = $recommendation
    reasons = $reasons
    scored_at = (Get-Date).ToString("s")
}

$result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFile -Encoding UTF8
'@

Set-Content -Path (Join-Path $scriptsDir "score_lead.ps1") -Value $scoreLeadScript -Encoding UTF8

$batchScript = @'
param(
    [string]$InputDir = "C:\Users\yonsh\Vex\workspace\reports",
    [string]$OutputDir = "C:\Users\yonsh\Vex\workspace\scored",
    [string]$RulesFile = "C:\Users\yonsh\Vex\config\lead_scoring_rules.json"
)

$ErrorActionPreference = "Stop"

$null = New-Item -ItemType Directory -Force -Path $OutputDir

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$summaryCsv = Join-Path $OutputDir ("lead_score_summary_" + $timestamp + ".csv")
$logFile = "C:\Users\yonsh\Vex\workspace\logs\phase14d_" + $timestamp + ".log"

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
        & "C:\Users\yonsh\Vex\scripts\score_lead.ps1" -InputFile $file.FullName -RulesFile $RulesFile -OutputFile $outFile

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
'@

Set-Content -Path (Join-Path $scriptsDir "phase14d_run.ps1") -Value $batchScript -Encoding UTF8

Write-Host ""
Write-Host "Phase 14d setup complete."
Write-Host "Run with:"
Write-Host "powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\phase14d_run.ps1"