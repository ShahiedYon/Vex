param(
    [Parameter(Mandatory = $true)]
    [string]$Id,

    [string]$PartnerName,
    [string]$Website,
    [string]$ApplicationUrl,
    [string]$Category,
    [string]$Geo,
    [string]$PayoutModel,
    [string]$PayoutDetails,
    [string]$ApprovalStatus,
    [Nullable[int]]$TrustScore,
    [string]$SpeedToCash,
    [string]$Notes,
    [string]$NextAction
)

$ErrorActionPreference = "Stop"

$csvPath = "C:\Users\yonsh\Vex\workspace\partners\partner_research_intake.csv"

if (-not (Test-Path $csvPath)) {
    throw "Missing file: $csvPath"
}

$validStatuses = @("researching","ready_to_apply","applied","approved","rejected")
$rows = Import-Csv -Path $csvPath
$found = $false

for ($i = 0; $i -lt $rows.Count; $i++) {
    if ([string]$rows[$i].id -eq $Id) {
        $found = $true

        if ($PSBoundParameters.ContainsKey("PartnerName"))   { $rows[$i].partner_name = $PartnerName }
        if ($PSBoundParameters.ContainsKey("Website"))       { $rows[$i].website = $Website }
        if ($PSBoundParameters.ContainsKey("ApplicationUrl")){ $rows[$i].application_url = $ApplicationUrl }
        if ($PSBoundParameters.ContainsKey("Category"))      { $rows[$i].category = $Category }
        if ($PSBoundParameters.ContainsKey("Geo"))           { $rows[$i].geo = $Geo }
        if ($PSBoundParameters.ContainsKey("PayoutModel"))   { $rows[$i].payout_model = $PayoutModel }
        if ($PSBoundParameters.ContainsKey("PayoutDetails")) { $rows[$i].payout_details = $PayoutDetails }

        if ($PSBoundParameters.ContainsKey("ApprovalStatus")) {
            if ($validStatuses -notcontains $ApprovalStatus) {
                throw "Invalid ApprovalStatus. Use: researching, ready_to_apply, applied, approved, rejected"
            }
            $rows[$i].approval_status = $ApprovalStatus
        }

        if ($PSBoundParameters.ContainsKey("TrustScore"))    { $rows[$i].trust_score = [string]$TrustScore }
        if ($PSBoundParameters.ContainsKey("SpeedToCash"))   { $rows[$i].speed_to_cash = $SpeedToCash }
        if ($PSBoundParameters.ContainsKey("Notes"))         { $rows[$i].notes = $Notes }
        if ($PSBoundParameters.ContainsKey("NextAction"))    { $rows[$i].next_action = $NextAction }

        break
    }
}

if (-not $found) {
    throw "ID not found: $Id"
}

$rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "Updated candidate: $Id"
Write-Host "File: $csvPath"
