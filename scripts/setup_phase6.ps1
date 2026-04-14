$base = "C:\Users\yonsh\Vex"
$workspace = Join-Path $base "workspace"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"
$browser = Join-Path $base "browser"

$dirs = @($browser)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -Path $d -ItemType Directory -Force | Out-Null
    }
}

# ---------------------------------
# Check Node and npm
# ---------------------------------
try {
    node -v | Out-Null
    npm -v | Out-Null
}
catch {
    Write-Host "Node or npm is not available. Install Node.js first."
    exit 1
}

# ---------------------------------
# Initialize browser project if needed
# ---------------------------------
Set-Location $browser

if (-not (Test-Path (Join-Path $browser "package.json"))) {
    npm init -y | Out-Null
}

# Install Playwright if needed
$playwrightPkg = Join-Path $browser "node_modules\playwright"
if (-not (Test-Path $playwrightPkg)) {
    Write-Host "Installing Playwright..."
    npm install playwright
}

# Install browser binaries
Write-Host "Installing Playwright Chromium browser..."
npx playwright install chromium

# ---------------------------------
# Browser test script
# ---------------------------------
$browserScript = @'
const { chromium } = require("playwright");
const fs = require("fs");

(async () => {
  const logFile = "C:\\Users\\yonsh\\Vex\\logs\\browser-test.log";
  const outFile = "C:\\Users\\yonsh\\Vex\\workspace\\browser-result.txt";
  const screenshotFile = "C:\\Users\\yonsh\\Vex\\workspace\\browser-shot.png";
  const timestamp = new Date().toISOString();

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    await page.goto("https://example.com", { waitUntil: "domcontentloaded", timeout: 30000 });

    const title = await page.title();
    const url = page.url();

    await page.screenshot({ path: screenshotFile, fullPage: true });

    const lines = [
      "Vex Browser Test Result",
      `Timestamp: ${timestamp}`,
      `Title: ${title}`,
      `URL: ${url}`,
      `Screenshot: ${screenshotFile}`,
      "Status: SUCCESS"
    ];

    fs.writeFileSync(outFile, lines.join("\n"), "utf8");
    fs.appendFileSync(logFile, `[${timestamp}] Browser test succeeded\n`, "utf8");

    console.log("Browser test complete");
    console.log(outFile);
    console.log(screenshotFile);
  } catch (err) {
    fs.appendFileSync(logFile, `[${timestamp}] Browser test failed: ${err.message}\n`, "utf8");
    console.error(err.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
'@

Set-Content -Path (Join-Path $scripts "browser_test.js") -Value $browserScript -Encoding UTF8

# ---------------------------------
# Run browser test
# ---------------------------------
Write-Host "Running browser automation test..."
node (Join-Path $scripts "browser_test.js")

# ---------------------------------
# Phase 6 check file
# ---------------------------------
$phase6Check = @'
[ ] browser folder created
[ ] package.json created
[ ] playwright installed
[ ] chromium installed
[ ] browser_test.js created
[ ] browser test runs successfully
[ ] browser-test.log created
[ ] browser-result.txt created
[ ] browser-shot.png created
'@

Set-Content -Path (Join-Path $logs "phase6-check.txt") -Value $phase6Check -Encoding UTF8

Write-Host ""
Write-Host "Phase 6 setup complete."
Write-Host "Review these files:"
Write-Host "C:\Users\yonsh\Vex\workspace\browser-result.txt"
Write-Host "C:\Users\yonsh\Vex\workspace\browser-shot.png"
Write-Host "C:\Users\yonsh\Vex\logs\browser-test.log"