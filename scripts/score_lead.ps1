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
