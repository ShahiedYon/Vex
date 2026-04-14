$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$workspace = Join-Path $base "workspace"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"
$browser = Join-Path $base "browser"
$logFile = Join-Path $logs "browser-test.log"
$resultFile = Join-Path $workspace "browser-result.txt"
$screenshotFile = Join-Path $workspace "browser-shot.png"
$phase6Check = Join-Path $logs "phase6-check.txt"

foreach ($dir in @($base, $workspace, $logs, $scripts, $browser)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$ts] $Message" -Encoding UTF8
}

Set-Content -Path $logFile -Value "" -Encoding UTF8

Write-Host "Step 1: Clearing bad npm proxy settings..."
try { npm config delete proxy | Out-Null } catch {}
try { npm config delete https-proxy | Out-Null } catch {}
try { npm config delete registry | Out-Null } catch {}

Write-Host "Step 2: Clearing proxy environment variables for this session..."
$env:HTTP_PROXY = $null
$env:HTTPS_PROXY = $null
$env:http_proxy = $null
$env:https_proxy = $null

Write-Host "Step 3: Clearing proxy environment variables from User scope if they match placeholder..."
foreach ($name in @("HTTP_PROXY","HTTPS_PROXY","http_proxy","https_proxy")) {
    $userVal = [Environment]::GetEnvironmentVariable($name, "User")
    if ($userVal -and $userVal -like "*user:pass@host:port*") {
        [Environment]::SetEnvironmentVariable($name, $null, "User")
    }

    $machineVal = [Environment]::GetEnvironmentVariable($name, "Machine")
    if ($machineVal -and $machineVal -like "*user:pass@host:port*") {
        Write-Host "Warning: $name is set at Machine scope. Remove it manually in System Environment Variables if needed."
        Write-Log "Warning: $name still exists at Machine scope."
    }
}

Write-Host "Step 4: Preparing browser project..."
Set-Location $browser

if (-not (Test-Path (Join-Path $browser "package.json"))) {
    npm init -y | Out-Null
    Write-Log "Created package.json"
} else {
    Write-Log "package.json already exists"
}

Write-Host "Step 5: Installing Playwright locally in browser folder..."
npm install playwright
Write-Log "Installed playwright package"

Write-Host "Step 6: Installing Chromium..."
npx playwright install chromium
Write-Log "Installed Chromium browser"

Write-Host "Step 7: Creating browser test script in browser folder..."
$browserScript = @'
const { chromium } = require("playwright");
const fs = require("fs");

(async () => {
  const logFile = "C:\\Users\\yonsh\\Vex\\logs\\browser-test.log";
  const outFile = "C:\\Users\\yonsh\\Vex\\workspace\\browser-result.txt";
  const screenshotFile = "C:\\Users\\yonsh\\Vex\\workspace\\browser-shot.png";
  const timestamp = new Date().toISOString();

  const appendLog = (msg) => fs.appendFileSync(logFile, `[${timestamp}] ${msg}\n`, "utf8");

  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
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
    appendLog("Browser test succeeded");
    console.log("Browser test complete");
  } catch (err) {
    appendLog(`Browser test failed: ${err.message}`);
    console.error(err.message);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
})();
'@

Set-Content -Path (Join-Path $browser "browser_test.js") -Value $browserScript -Encoding UTF8
Write-Log "Created browser_test.js"

Write-Host "Step 8: Running browser test..."
node (Join-Path $browser "browser_test.js")
Write-Log "Executed browser_test.js"

$checks = @()
$checks += "[ ] browser folder created"
$checks += "[ ] package.json created"
$checks += "[ ] playwright installed"
$checks += "[ ] chromium installed"
$checks += "[ ] browser_test.js created"
$checks += "[ ] browser test runs successfully"
$checks += "[ ] browser-test.log created"
$checks += "[ ] browser-result.txt created"
$checks += "[ ] browser-shot.png created"

Set-Content -Path $phase6Check -Value $checks -Encoding UTF8

Write-Host ""
Write-Host "Repair complete. Check:"
Write-Host $resultFile
Write-Host $logFile
Write-Host $screenshotFile