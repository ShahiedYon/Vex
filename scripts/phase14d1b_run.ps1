param(
    [string]$Root = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

$workspaceDir = Join-Path $Root "workspace"
$reportsDir = Join-Path $workspaceDir "reports"
$scoredDir = Join-Path $workspaceDir "scored"
$enhancedDir = Join-Path $workspaceDir "enhanced"
$logsDir = Join-Path $workspaceDir "logs"
$phase14d = Join-Path $Root "scripts\phase14d_run.ps1"
$phase14d2 = Join-Path $Root "scripts\phase14d2_run.ps1"
$logFile = Join-Path $logsDir ("phase14d1b_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Test-IsLikelyReportJson {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return (
        $Text -match '"url"\s*:' -or
        $Text -match '"emails"\s*:' -or
        $Text -match '"phones"\s*:' -or
        $Text -match '"social_links"\s*:'
    )
}

function Normalize-Array {
    param([object]$Value)

    if ($null -eq $Value) { return @() }

    if ($Value -is [System.Array]) {
        $out = @()
        for ($i = 0; $i -lt $Value.Count; $i++) {
            if ($null -ne $Value[$i] -and [string]$Value[$i] -ne "") {
                $out += [string]$Value[$i]
            }
        }
        return $out
    }

    $text = ([string]$Value).Trim()
    if ($text -eq "") { return @() }

    if ($text.Contains(",")) {
        $parts = $text.Split(",")
        $out2 = @()
        for ($j = 0; $j -lt $parts.Length; $j++) {
            $p = $parts[$j].Trim()
            if ($p -ne "") { $out2 += $p }
        }
        return $out2
    }

    return @($text)
}

function Convert-ToStandardReport {
    param([object]$Data, [string]$FallbackUrl)

    $url = ""
    if ($null -ne $Data.url) { $url = [string]$Data.url }
    if ([string]::IsNullOrWhiteSpace($url)) { $url = $FallbackUrl }

    $title = ""
    if ($null -ne $Data.title) { $title = [string]$Data.title }

    $h1 = ""
    if ($null -ne $Data.h1) { $h1 = [string]$Data.h1 }

    $preview = ""
    if ($null -ne $Data.preview) { $preview = [string]$Data.preview }

    $emails = @()
    if ($null -ne $Data.emails) { $emails = Normalize-Array -Value $Data.emails }
    elseif ($null -ne $Data.email) { $emails = Normalize-Array -Value $Data.email }

    $phones = @()
    if ($null -ne $Data.phones) { $phones = Normalize-Array -Value $Data.phones }
    elseif ($null -ne $Data.phone) { $phones = Normalize-Array -Value $Data.phone }

    $contactPages = @()
    if ($null -ne $Data.contact_pages) { $contactPages = Normalize-Array -Value $Data.contact_pages }
    elseif ($null -ne $Data.contact_page) { $contactPages = Normalize-Array -Value $Data.contact_page }

    $aboutPages = @()
    if ($null -ne $Data.about_pages) { $aboutPages = Normalize-Array -Value $Data.about_pages }
    elseif ($null -ne $Data.about_page) { $aboutPages = Normalize-Array -Value $Data.about_page }

    $linkedin = @()
    $facebook = @()
    $instagram = @()
    $xlinks = @()

    if ($null -ne $Data.social_links) {
        if ($null -ne $Data.social_links.linkedin) { $linkedin = Normalize-Array -Value $Data.social_links.linkedin }
        if ($null -ne $Data.social_links.facebook) { $facebook = Normalize-Array -Value $Data.social_links.facebook }
        if ($null -ne $Data.social_links.instagram) { $instagram = Normalize-Array -Value $Data.social_links.instagram }
        if ($null -ne $Data.social_links.x) { $xlinks = Normalize-Array -Value $Data.social_links.x }
    }

    $https = $false
    if ($url -like "https://*") { $https = $true }

    return [ordered]@{
        url = $url
        title = $title
        h1 = $h1
        preview = $preview
        emails = $emails
        phones = $phones
        contact_pages = $contactPages
        about_pages = $aboutPages
        social_links = [ordered]@{
            linkedin = $linkedin
            facebook = $facebook
            instagram = $instagram
            x = $xlinks
        }
        status = "success"
        https = $https
    }
}

Write-Log "Scanning workspace for existing JSON report files"

$allJson = Get-ChildItem -Path $workspaceDir -Filter *.json -File -Recurse -ErrorAction SilentlyContinue
$copied = 0

for ($i = 0; $i -lt $allJson.Count; $i++) {
    $file = $allJson[$i]

    if ($file.DirectoryName -eq $reportsDir -or $file.DirectoryName -eq $scoredDir -or $file.DirectoryName -eq $enhancedDir) {
        continue
    }

    try {
        $raw = Get-Content -Raw -Path $file.FullName
        if (-not (Test-IsLikelyReportJson -Text $raw)) {
            continue
        }

        $data = $raw | ConvertFrom-Json
        $fallbackUrl = "file://" + $file.BaseName
        $standard = Convert-ToStandardReport -Data $data -FallbackUrl $fallbackUrl
        $dest = Join-Path $reportsDir ($file.BaseName + ".normalized.json")
        $standard | ConvertTo-Json -Depth 10 | Set-Content -Path $dest -Encoding UTF8
        $copied++
        Write-Log ("Normalized report: " + $file.FullName + " -> " + $dest)
    }
    catch {
        Write-Log ("Skipped invalid JSON: " + $file.FullName)
    }
}

$reportFiles = Get-ChildItem -Path $reportsDir -Filter *.json -File -ErrorAction SilentlyContinue

if ($reportFiles.Count -eq 0) {
    Write-Log "No real reports found. Creating test fixtures."

    $debt = [ordered]@{
        url = "https://example-debt-help.com"
        title = "Debt Relief Options USA"
        h1 = "Behind on payments? Get help."
        preview = "Credit card debt, loan stress, and payment relief help for US consumers."
        emails = @("help@example-debt-help.com")
        phones = @("+1-800-555-1001")
        contact_pages = @("https://example-debt-help.com/contact")
        about_pages = @("https://example-debt-help.com/about")
        social_links = [ordered]@{
            linkedin = @("https://linkedin.com/company/exampledebt")
            facebook = @("https://facebook.com/exampledebt")
            instagram = @()
            x = @("https://x.com/exampledebt")
        }
        status = "success"
        https = $true
    }

    $solar = [ordered]@{
        url = "https://example-solar.com"
        title = "Solar Savings For Homeowners"
        h1 = "Cut your electricity bill with solar panels"
        preview = "Home solar, energy savings, installer match, and panel financing."
        emails = @("info@example-solar.com")
        phones = @("+1-800-555-2002")
        contact_pages = @("https://example-solar.com/contact")
        about_pages = @("https://example-solar.com/about")
        social_links = [ordered]@{
            linkedin = @()
            facebook = @("https://facebook.com/examplesolar")
            instagram = @("https://instagram.com/examplesolar")
            x = @()
        }
        status = "success"
        https = $true
    }

    $vextly = [ordered]@{
        url = "https://example-ops-company.com"
        title = "Business Process Improvement"
        h1 = "Automation for small business operations"
        preview = "Workflow automation, reporting, and productivity systems."
        emails = @("ops@example-ops-company.com")
        phones = @()
        contact_pages = @("https://example-ops-company.com/contact")
        about_pages = @()
        social_links = [ordered]@{
            linkedin = @("https://linkedin.com/company/exampleops")
            facebook = @()
            instagram = @()
            x = @()
        }
        status = "success"
        https = $true
    }

    $debt | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $reportsDir "test_debt_relief.json") -Encoding UTF8
    $solar | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $reportsDir "test_solar.json") -Encoding UTF8
    $vextly | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $reportsDir "test_vextly.json") -Encoding UTF8
    Write-Log "Created 3 test fixture reports"
}

if (Test-Path $phase14d) {
    Write-Log "Running Phase 14d"
    & $phase14d
} else {
    Write-Log "Phase 14d script not found: $phase14d"
}

if (Test-Path $phase14d2) {
    Write-Log "Running Phase 14d.2"
    & $phase14d2
} else {
    Write-Log "Phase 14d.2 script not found: $phase14d2"
}

Write-Log "Bridge complete"
