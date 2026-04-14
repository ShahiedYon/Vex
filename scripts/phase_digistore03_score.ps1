param(
    [string]$BasePath = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

function Ensure-Folder {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Get-LatestFile {
    param($Folder, $Pattern)
    return (Get-ChildItem $Folder -Filter $Pattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Read-Json {
    param($Path)
    return (Get-Content $Path -Raw | ConvertFrom-Json)
}

function Extract-AllObjects {
    param($Node)

    $results = @()

    if ($Node -is [System.Array]) {
        foreach ($item in $Node) {
            if ($item -is [PSCustomObject]) {
                $results += $item
            }
            $results += Extract-AllObjects $item
        }
    }
    elseif ($Node -is [PSCustomObject]) {
        $results += $Node
        foreach ($prop in $Node.PSObject.Properties) {
            $results += Extract-AllObjects $prop.Value
        }
    }

    return $results
}

function Get-FirstValue {
    param($obj, $names)

    foreach ($n in $names) {
        if ($obj.PSObject.Properties[$n]) {
            $val = $obj.$n
            if ($val) { return $val }
        }
    }
    return $null
}

function ToNumber($val) {
    if ($null -eq $val) { return $null }
    $v = ($val.ToString() -replace '[^0-9\.]', '')
    $num = 0
    if ([double]::TryParse($v, [ref]$num)) { return $num }
    return $null
}

function Score($r) {
    $score = 0

    if ($r.commission -ge 50) { $score += 20 }
    elseif ($r.commission -ge 30) { $score += 15 }

    if ($r.earnings -ge 100) { $score += 20 }
    elseif ($r.earnings -ge 40) { $score += 10 }

    if ($r.epv -ge 2) { $score += 15 }

    if ($r.conversion -ge 5) { $score += 10 }

    if ($r.cancel -le 10) { $score += 10 }

    if ($r.name -match "debt|credit|loan|finance") { $score += 10 }
    if ($r.name -match "solar|energy") { $score += 10 }
    if ($r.name -match "ai|software|automation") { $score += 8 }

    if ($r.name -match "crypto|casino|betting") { $score -= 20 }

    if ($score -lt 0) { $score = 0 }
    if ($score -gt 100) { $score = 100 }

    return $score
}

# Paths
$raw = "$BasePath\data\digistore24\raw"
$out = "$BasePath\data\digistore24\scored"

Ensure-Folder $out

$file = Get-LatestFile $raw "listMarketplaceEntries_*.json"

if (-not $file) {
    throw "No marketplace file found"
}

$data = Read-Json $file
$objects = Extract-AllObjects $data

$rows = @()

foreach ($o in $objects) {

    $name = Get-FirstValue $o @("name","title","product_name")
    if (-not $name) { continue }

    $vendor = Get-FirstValue $o @("vendor","seller")
    $category = Get-FirstValue $o @("category")
    $commission = ToNumber (Get-FirstValue $o @("commission"))
    $earnings = ToNumber (Get-FirstValue $o @("earnings_per_sale"))
    $epv = ToNumber (Get-FirstValue $o @("epv"))
    $conversion = ToNumber (Get-FirstValue $o @("conversion"))
    $cancel = ToNumber (Get-FirstValue $o @("cancellation_rate"))
    $url = Get-FirstValue $o @("url","sales_page")

    $row = [PSCustomObject]@{
        name       = $name
        vendor     = $vendor
        category   = $category
        commission = $commission
        earnings   = $earnings
        epv        = $epv
        conversion = $conversion
        cancel     = $cancel
        url        = $url
    }

    $row | Add-Member -NotePropertyName score -NotePropertyValue (Score $row)

    $rows += $row
}

if ($rows.Count -eq 0) {
    throw "Still no rows extracted"
}

$sorted = $rows | Sort-Object -Property score -Descending

$fileOut = "$out\digistore_scored_$(Get-Date -Format yyyyMMdd_HHmmss).csv"

$sorted | Export-Csv $fileOut -NoTypeInformation

Write-Host ""
Write-Host "DONE"
Write-Host "Output: $fileOut"
Write-Host ""

$sorted | Select-Object -First 15 | Format-Table name, commission, earnings, score