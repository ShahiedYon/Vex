param(
    [string]$url = "https://example.com"
)

$base = "C:\Users\yonsh\Vex"
$browser = Join-Path $base "browser"
$workspace = Join-Path $base "workspace"
$log = Join-Path $base "logs\phase14c.log"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$output = Join-Path $workspace ("site_report_14c_" + $timestamp + ".txt")
$script = Join-Path $browser "phase14c_site_research.js"

Add-Content -Path $log -Value ("[" + $timestamp + "] Running site enrichment: " + $url) -Encoding UTF8

Push-Location $browser
try {
    node $script $url $output
    if (Test-Path $output) {
        $content = Get-Content -Path $output -Raw
        if ($content -match "Status:\s*SUCCESS") {
            Add-Content -Path $log -Value ("[" + $timestamp + "] SUCCESS: " + $output) -Encoding UTF8
            Write-Host "Report created:"
            Write-Host $output
        }
        else {
            Add-Content -Path $log -Value ("[" + $timestamp + "] FAILED CONTENT: " + $output) -Encoding UTF8
            Write-Host "Report created but indicates failure:"
            Write-Host $output
        }
    }
    else {
        Add-Content -Path $log -Value ("[" + $timestamp + "] FAILED: output file missing") -Encoding UTF8
        Write-Host "Failed"
    }
}
finally {
    Pop-Location
}
