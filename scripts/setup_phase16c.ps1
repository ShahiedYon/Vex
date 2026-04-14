$ErrorActionPreference = "Stop"

$root = "C:\Users\yonsh\Vex"
$scriptsDir = Join-Path $root "scripts"
$workspaceDir = Join-Path $root "workspace"
$partnersDir = Join-Path $workspaceDir "partners"

$null = New-Item -ItemType Directory -Force -Path $scriptsDir
$null = New-Item -ItemType Directory -Force -Path $workspaceDir
$null = New-Item -ItemType Directory -Force -Path $partnersDir

$script = @'
param(
    [Parameter(Mandatory = $true)]
    [string]$Stream,

    [Parameter(Mandatory = $true)]
    [string]$PartnerName,

    [string]$Website = "",
    [string]$ApplicationUrl = "",
    [string]$Category = "",
    [string]$Geo = "US",
    [string]$PayoutModel = "",
    [string]$PayoutDetails = "",
    [string]$ApprovalStatus = "researching",
    [int]$TrustScore = 0,
    [string]$SpeedToCash = "medium",
    [string]$Notes = "",
    [string]$NextAction = ""
)

$ErrorActionPreference = "Stop"

$csvPath = "C:\Users\yonsh\Vex\workspace\partners\partner_research_intake.csv"

if (-not (Test-Path $csvPath)) {
    throw "Missing file: $csvPath"
}

$validStreams = @("debt_relief","solar","vextly")
if ($validStreams -notcontains $Stream) {
    throw "Invalid stream. Use: debt_relief, solar, or vextly"
}

$rows = Import-Csv -Path $csvPath

$maxId = 0
for ($i = 0; $i -lt $rows.Count; $i++) {
    $idText = [string]$rows[$i].id
    if ($idText -match "^R-(\d+)$") {
        $num = [int]$matches[1]
        if ($num -gt $maxId) { $maxId = $num }
    }
}

$newId = "R-" + "{0:D3}" -f ($maxId + 1)

if ([string]::IsNullOrWhiteSpace($Category)) {
    if ($Stream -eq "debt_relief") { $Category = "debt_relief" }
    elseif ($Stream -eq "solar") { $Category = "solar_affiliate" }
    else { $Category = "service_lead" }
}

if ([string]::IsNullOrWhiteSpace($PayoutModel)) {
    if ($Stream -eq "debt_relief") { $PayoutModel = "per_lead" }
    elseif ($Stream -eq "solar") { $PayoutModel = "commission" }
    else { $PayoutModel = "service_revenue" }
}

if ([string]::IsNullOrWhiteSpace($NextAction)) {
    if ($ApprovalStatus -eq "ready_to_apply" -and -not [string]::IsNullOrWhiteSpace($ApplicationUrl)) {
        $NextAction = "Review terms and submit application"
    }
    else {
        $NextAction = "Research website, terms, and approval requirements"
    }
}

$newRow = [pscustomobject]@{
    id = $newId
    stream = $Stream
    partner_name = $PartnerName
    website = $Website
    application_url = $ApplicationUrl
    category = $Category
    geo = $Geo
    payout_model = $PayoutModel
    payout_details = $PayoutDetails
    approval_status = $ApprovalStatus
    trust_score = $TrustScore
    speed_to_cash = $SpeedToCash
    notes = $Notes
    next_action = $NextAction
    priority_score = ""
}

$allRows = @()
for ($j = 0; $j -lt $rows.Count; $j++) {
    $allRows += $rows[$j]
}
$allRows += $newRow

$allRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "Added candidate: $newId | $Stream | $PartnerName"
Write-Host "Updated: $csvPath"
'@

Set-Content -Path (Join-Path $scriptsDir "partner_add.ps1") -Value $script -Encoding UTF8

Write-Host ""
Write-Host "Phase 16c setup complete."
Write-Host "Created:"
Write-Host "C:\Users\yonsh\Vex\scripts\partner_add.ps1"
Write-Host ""
Write-Host "Example:"
Write-Host 'powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\partner_add.ps1 -Stream debt_relief -PartnerName "Example Partner" -Website "https://example.com" -ApplicationUrl "https://example.com/apply" -TrustScore 75 -SpeedToCash "fast" -ApprovalStatus "ready_to_apply"'