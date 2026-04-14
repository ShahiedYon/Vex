$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$scripts = "$base\scripts"
$workspace = "$base\workspace"
$logs = "$base\logs"

$nodeScript = "$scripts\phase14_site_research.js"
$runnerScript = "$scripts\phase14_run.ps1"
$logFile = "$logs\phase14.log"

# Ensure folders exist
foreach ($dir in @($scripts, $workspace, $logs)) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# -------------------------
# Node.js browser script
# -------------------------
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

  const browser = await chromium.launch();
  const page = await browser.newPage();

  try {
    await page.goto(url, { timeout: 20000 });

    const title = await page.title();
    const h1 = await page.locator("h1").first().textContent().catch(() => "");
    const bodyText = await page.locator("body").innerText();
    const preview = bodyText.substring(0, 500);

    const emailMatch = bodyText.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
    const phoneMatch = bodyText.match(/\+?\d[\d\s\-]{7,}/);

    const email = emailMatch ? emailMatch[0] : "Not found";
    const phone = phoneMatch ? phoneMatch[0] : "Not found";

    const screenshot = output.replace(".txt", ".png");
    await page.screenshot({ path: screenshot });

    const result = `
Vex Phase 14 Site Report
URL: ${url}
Title: ${title}
H1: ${h1}

Preview:
${preview}

Email: ${email}
Phone: ${phone}

Screenshot: ${screenshot}
Status: SUCCESS
`;

    fs.writeFileSync(output, result);

  } catch (err) {
    fs.writeFileSync(output, "FAILED: " + err.message);
  }

  await browser.close();
})();
'@

Set-Content -Path $nodeScript -Value $js -Encoding UTF8

# -------------------------
# PowerShell runner
# -------------------------
$ps = @'
param(
    [string]$url = "https://example.com"
)

$base = "C:\Users\yonsh\Vex"
$workspace = "$base\workspace"
$log = "$base\logs\phase14.log"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$output = "$workspace\site_report_$timestamp.txt"

Add-Content $log "[$timestamp] Running site research: $url"

node "C:\Users\yonsh\Vex\scripts\phase14_site_research.js" "$url" "$output"

if (Test-Path $output) {
    Add-Content $log "[$timestamp] SUCCESS: $output"
    Write-Host "Report created:"
    Write-Host $output
} else {
    Add-Content $log "[$timestamp] FAILED"
    Write-Host "Failed"
}
'@

Set-Content -Path $runnerScript -Value $ps -Encoding UTF8

Write-Host ""
Write-Host "Phase 14 setup complete."
Write-Host "Run test with:"
Write-Host "powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\phase14_run.ps1 -url https://example.com"