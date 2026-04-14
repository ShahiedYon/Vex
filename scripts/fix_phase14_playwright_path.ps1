$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$scripts = Join-Path $base "scripts"
$workspace = Join-Path $base "workspace"
$logs = Join-Path $base "logs"
$browser = Join-Path $base "browser"

$nodeScript = Join-Path $browser "phase14_site_research.js"
$runnerScript = Join-Path $scripts "phase14_run.ps1"
$logFile = Join-Path $logs "phase14.log"

foreach ($dir in @($scripts, $workspace, $logs, $browser)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$playwrightModule = Join-Path $browser "node_modules\playwright"
if (-not (Test-Path $playwrightModule)) {
    throw "Playwright is not installed in $browser. Phase 6 browser environment is missing or incomplete."
}

$js = @'
const { chromium } = require("playwright");
const fs = require("fs");

(async () => {
  const url = process.argv[2];
  const output = process.argv[3];

  if (!url || !output) {
    console.log("Missing arguments");
    process.exit(1);
  }

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 20000 });

    const title = await page.title();
    const h1 = await page.locator("h1").first().textContent().catch(() => "");
    const bodyText = await page.locator("body").innerText().catch(() => "");
    const preview = bodyText.substring(0, 500);

    const emailMatch = bodyText.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
    const phoneMatch = bodyText.match(/\+?\d[\d\s\-()]{7,}/);

    const email = emailMatch ? emailMatch[0] : "Not found";
    const phone = phoneMatch ? phoneMatch[0] : "Not found";

    const screenshot = output.replace(".txt", ".png");
    await page.screenshot({ path: screenshot, fullPage: true });

    const result = [
      "Vex Phase 14 Site Report",
      `URL: ${url}`,
      `Title: ${title}`,
      `H1: ${h1}`,
      "",
      "Preview:",
      preview,
      "",
      `Email: ${email}`,
      `Phone: ${phone}`,
      "",
      `Screenshot: ${screenshot}`,
      "Status: SUCCESS"
    ].join("\n");

    fs.writeFileSync(output, result, "utf8");
  } catch (err) {
    fs.writeFileSync(output, "FAILED: " + err.message, "utf8");
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
'@

Set-Content -Path $nodeScript -Value $js -Encoding UTF8

$ps = @'
param(
    [string]$url = "https://example.com"
)

$base = "C:\Users\yonsh\Vex"
$browser = Join-Path $base "browser"
$workspace = Join-Path $base "workspace"
$log = Join-Path $base "logs\phase14.log"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$output = Join-Path $workspace ("site_report_" + $timestamp + ".txt")
$script = Join-Path $browser "phase14_site_research.js"

Add-Content -Path $log -Value ("[" + $timestamp + "] Running site research: " + $url) -Encoding UTF8

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
'@

Set-Content -Path $runnerScript -Value $ps -Encoding UTF8

if (-not (Test-Path $logFile)) {
    New-Item -ItemType File -Path $logFile -Force | Out-Null
}

Write-Host ""
Write-Host "Phase 14 Playwright path fix applied."
Write-Host "Run:"
Write-Host "powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\phase14_run.ps1 -url https://example.com"