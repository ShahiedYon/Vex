$ErrorActionPreference = "Stop"

$base = "C:\Users\yonsh\Vex"
$workspace = Join-Path $base "workspace"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"
$browser = Join-Path $base "browser"
$tasks = Join-Path $base "tasks"

foreach ($dir in @($workspace, $logs, $scripts, $browser, $tasks)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

$routerLog = Join-Path $logs "phase8-router.log"
$checkFile = Join-Path $logs "phase8-check.txt"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# -------------------------------------------------
# Sample task files
# -------------------------------------------------
$browserTask = @'
TASK_NAME: Check Example Site
TASK_TYPE: browser.inspect
TARGET: https://example.com
OUTPUT_TEXT: C:\Users\yonsh\Vex\workspace\phase8-browser-result.txt
OUTPUT_SCREENSHOT: C:\Users\yonsh\Vex\workspace\phase8-browser-shot.png
OUTPUT_LOG: C:\Users\yonsh\Vex\logs\phase8-browser.log
'@

$pythonTask = @'
TASK_NAME: Run Python Validation
TASK_TYPE: python.run
TARGET: C:\Users\yonsh\Vex\scripts\phase8_python_task.py
OUTPUT_TEXT: C:\Users\yonsh\Vex\workspace\phase8-python-result.txt
OUTPUT_LOG: C:\Users\yonsh\Vex\logs\phase8-python.log
'@

$nodeTask = @'
TASK_NAME: Run Node Validation
TASK_TYPE: node.run
TARGET: C:\Users\yonsh\Vex\scripts\phase8_node_task.js
OUTPUT_TEXT: C:\Users\yonsh\Vex\workspace\phase8-node-result.txt
OUTPUT_LOG: C:\Users\yonsh\Vex\logs\phase8-node.log
'@

$reportTask = @'
TASK_NAME: Write Summary Report
TASK_TYPE: file.write_report
TARGET: Phase 8 routing test completed successfully.
OUTPUT_TEXT: C:\Users\yonsh\Vex\workspace\phase8-report.txt
OUTPUT_LOG: C:\Users\yonsh\Vex\logs\phase8-report.log
'@

Write-Utf8NoBom -Path (Join-Path $tasks "phase8-browser-task.txt") -Content $browserTask
Write-Utf8NoBom -Path (Join-Path $tasks "phase8-python-task.txt") -Content $pythonTask
Write-Utf8NoBom -Path (Join-Path $tasks "phase8-node-task.txt") -Content $nodeTask
Write-Utf8NoBom -Path (Join-Path $tasks "phase8-report-task.txt") -Content $reportTask

# -------------------------------------------------
# Support scripts
# -------------------------------------------------
$pythonWorker = @'
from datetime import datetime

out_file = r"C:\Users\yonsh\Vex\workspace\phase8-python-result.txt"
log_file = r"C:\Users\yonsh\Vex\logs\phase8-python.log"
ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

with open(out_file, "w", encoding="utf-8") as f:
    f.write("Vex Phase 8 Python Result\n")
    f.write(f"Timestamp: {ts}\n")
    f.write("Status: SUCCESS\n")
    f.write("Message: Python handler executed successfully.\n")

with open(log_file, "a", encoding="utf-8") as f:
    f.write(f"[{ts}] Python handler executed successfully\n")

print("Python Phase 8 task complete")
'@

$nodeWorker = @'
const fs = require("fs");

const outFile = "C:\\Users\\yonsh\\Vex\\workspace\\phase8-node-result.txt";
const logFile = "C:\\Users\\yonsh\\Vex\\logs\\phase8-node.log";
const ts = new Date().toISOString();

fs.writeFileSync(
  outFile,
  [
    "Vex Phase 8 Node Result",
    `Timestamp: ${ts}`,
    "Status: SUCCESS",
    "Message: Node handler executed successfully."
  ].join("\n"),
  "utf8"
);

fs.appendFileSync(logFile, `[${ts}] Node handler executed successfully\n`, "utf8");
console.log("Node Phase 8 task complete");
'@

$browserWorker = @'
const fs = require("fs");
const { chromium } = require("playwright");

function parseTaskFile(path) {
  const lines = fs.readFileSync(path, "utf8").split(/\r?\n/);
  const data = {};
  for (const line of lines) {
    const idx = line.indexOf(":");
    if (idx > -1) {
      const key = line.slice(0, idx).trim();
      const value = line.slice(idx + 1).trim();
      if (key) data[key] = value;
    }
  }
  return data;
}

(async () => {
  const taskPath = process.argv[2];
  if (!taskPath) {
    console.error("Missing task file path");
    process.exit(1);
  }

  const task = parseTaskFile(taskPath);
  const logFile = task.OUTPUT_LOG;
  const textFile = task.OUTPUT_TEXT;
  const shotFile = task.OUTPUT_SCREENSHOT;
  const timestamp = new Date().toISOString();

  const log = (msg) => fs.appendFileSync(logFile, `[${new Date().toISOString()}] ${msg}\n`, "utf8");

  let browser;
  try {
    log(`TASK RECEIVED: ${task.TASK_NAME || ""}`);
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    await page.goto(task.TARGET, { waitUntil: "domcontentloaded", timeout: 30000 });

    const title = await page.title();
    const url = page.url();
    const bodyText = await page.locator("body").innerText().catch(() => "");

    await page.screenshot({ path: shotFile, fullPage: true });

    const lines = [
      "Vex Phase 8 Browser Result",
      `Timestamp: ${timestamp}`,
      `Task Name: ${task.TASK_NAME || ""}`,
      `Title: ${title}`,
      `URL: ${url}`,
      "",
      "Body Preview:",
      (bodyText || "").slice(0, 1000),
      "",
      `Screenshot: ${shotFile}`,
      "Status: SUCCESS"
    ];

    fs.writeFileSync(textFile, lines.join("\n"), "utf8");
    log(`RESULT WRITTEN: ${textFile}`);
    log(`SCREENSHOT WRITTEN: ${shotFile}`);
    log("VERIFICATION PASSED");
    console.log("Browser Phase 8 task complete");
  } catch (err) {
    try {
      log(`FAILED: ${err.message}`);
    } catch {}
    console.error(err.message);
    process.exit(1);
  } finally {
    if (browser) await browser.close();
  }
})();
'@

Write-Utf8NoBom -Path (Join-Path $scripts "phase8_python_task.py") -Content $pythonWorker
Write-Utf8NoBom -Path (Join-Path $scripts "phase8_node_task.js") -Content $nodeWorker
Write-Utf8NoBom -Path (Join-Path $browser "phase8_browser_task.js") -Content $browserWorker

# -------------------------------------------------
# Router script
# -------------------------------------------------
$routerScript = @'
param(
    [string]$TaskFile
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Path, [string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $Path -Value "[$ts] $Message" -Encoding UTF8
}

function Parse-TaskFile {
    param([string]$Path)
    $map = @{}
    $lines = Get-Content -Path $Path
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $idx = $line.IndexOf(":")
        if ($idx -lt 0) { continue }
        $key = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $map[$key] = $value
        }
    }
    return $map
}

if ([string]::IsNullOrWhiteSpace($TaskFile)) {
    Write-Host "Error: provide -TaskFile"
    exit 1
}

if (-not (Test-Path $TaskFile)) {
    Write-Host "Error: task file not found"
    exit 1
}

$routerLog = "C:\Users\yonsh\Vex\logs\phase8-router.log"
$task = Parse-TaskFile -Path $TaskFile

$taskName = $task["TASK_NAME"]
$taskType = $task["TASK_TYPE"]
$target = $task["TARGET"]
$outputText = $task["OUTPUT_TEXT"]
$outputLog = $task["OUTPUT_LOG"]

Write-Log -Path $routerLog -Message "TASK RECEIVED: $taskName"
Write-Log -Path $routerLog -Message "TASK TYPE: $taskType"
Write-Log -Path $routerLog -Message "TARGET: $target"

switch ($taskType) {
    "browser.inspect" {
        $runner = "C:\Users\yonsh\Vex\browser\phase8_browser_task.js"
        Write-Log -Path $routerLog -Message "ROUTE SELECTED: browser.inspect"
        node $runner $TaskFile
    }
    "python.run" {
        Write-Log -Path $routerLog -Message "ROUTE SELECTED: python.run"
        python $target
    }
    "node.run" {
        Write-Log -Path $routerLog -Message "ROUTE SELECTED: node.run"
        node $target
    }
    "file.write_report" {
        Write-Log -Path $routerLog -Message "ROUTE SELECTED: file.write_report"
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $lines = @()
        $lines += "Vex Phase 8 Report"
        $lines += "Timestamp: $ts"
        $lines += "Task Name: $taskName"
        $lines += "Status: SUCCESS"
        $lines += "Message: $target"
        Set-Content -Path $outputText -Value $lines -Encoding UTF8
        Add-Content -Path $outputLog -Value "[$ts] Report written successfully" -Encoding UTF8
    }
    default {
        Write-Log -Path $routerLog -Message "UNKNOWN TASK TYPE: $taskType"
        Write-Host "Unknown TASK_TYPE: $taskType"
        exit 1
    }
}

$verified = $false
if (-not [string]::IsNullOrWhiteSpace($outputText)) {
    if (Test-Path $outputText) {
        $verified = $true
    }
}

if ($verified) {
    Write-Log -Path $routerLog -Message "VERIFICATION PASSED: $outputText"
    Write-Host "Task completed successfully."
    Write-Host "Output: $outputText"
}
else {
    Write-Log -Path $routerLog -Message "VERIFICATION FAILED"
    Write-Host "Task failed verification."
    exit 1
}
'@

Write-Utf8NoBom -Path (Join-Path $scripts "phase8_router.ps1") -Content $routerScript

# -------------------------------------------------
# Run validations
# -------------------------------------------------
Set-Content -Path $routerLog -Value "" -Encoding UTF8

Write-Host "Running Phase 8 browser task..."
powershell -ExecutionPolicy Bypass -File (Join-Path $scripts "phase8_router.ps1") -TaskFile (Join-Path $tasks "phase8-browser-task.txt")

Write-Host "Running Phase 8 python task..."
powershell -ExecutionPolicy Bypass -File (Join-Path $scripts "phase8_router.ps1") -TaskFile (Join-Path $tasks "phase8-python-task.txt")

Write-Host "Running Phase 8 node task..."
powershell -ExecutionPolicy Bypass -File (Join-Path $scripts "phase8_router.ps1") -TaskFile (Join-Path $tasks "phase8-node-task.txt")

Write-Host "Running Phase 8 report task..."
powershell -ExecutionPolicy Bypass -File (Join-Path $scripts "phase8_router.ps1") -TaskFile (Join-Path $tasks "phase8-report-task.txt")

# -------------------------------------------------
# Check file
# -------------------------------------------------
$checks = @'
[ ] phase8-browser-task.txt created
[ ] phase8-python-task.txt created
[ ] phase8-node-task.txt created
[ ] phase8-report-task.txt created
[ ] phase8_python_task.py created
[ ] phase8_node_task.js created
[ ] phase8_browser_task.js created
[ ] phase8_router.ps1 created
[ ] browser.inspect routed successfully
[ ] python.run routed successfully
[ ] node.run routed successfully
[ ] file.write_report routed successfully
[ ] phase8-router.log created
[ ] all output files created
'@

Set-Content -Path $checkFile -Value $checks -Encoding UTF8

Write-Host ""
Write-Host "Phase 8 setup complete."
Write-Host "Review these files:"
Write-Host "C:\Users\yonsh\Vex\logs\phase8-router.log"
Write-Host "C:\Users\yonsh\Vex\workspace\phase8-browser-result.txt"
Write-Host "C:\Users\yonsh\Vex\workspace\phase8-python-result.txt"
Write-Host "C:\Users\yonsh\Vex\workspace\phase8-node-result.txt"
Write-Host "C:\Users\yonsh\Vex\workspace\phase8-report.txt"