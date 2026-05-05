param(
    [string]$Root = "",
    [string]$StartUrl = "https://www.digistore24.com/affiliates?lang=en",
    [switch]$OpenResults
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) {
        $Root = Split-Path -Parent $PSScriptRoot
    }
    else {
        $Root = (Get-Location).Path
    }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$browserDir = Join-Path $Root "browser"
$workspace = Join-Path $Root "workspace"
$digistoreDir = Join-Path $workspace "digistore"
$partnersDir = Join-Path $workspace "partners"
$logsDir = Join-Path $Root "logs"
$nodeScript = Join-Path $browserDir "vex_digistore_scan.js"
$outputJson = Join-Path $digistoreDir ("digistore_scan_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".json")
$outputCsv = Join-Path $digistoreDir ("digistore_candidates_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".csv")
$summaryTxt = Join-Path $digistoreDir "digistore_next_actions.txt"
$screenshot = Join-Path $digistoreDir ("digistore_scan_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".png")
$tracker = Join-Path $partnersDir "moneycrunch_partner_tracker.csv"
$logFile = Join-Path $logsDir "vex_digistore_scan.log"

Ensure-Directory $browserDir
Ensure-Directory $workspace
Ensure-Directory $digistoreDir
Ensure-Directory $partnersDir
Ensure-Directory $logsDir

if (-not (Test-Path (Join-Path $browserDir "node_modules\playwright"))) {
    throw "Playwright is missing. Run: cd $browserDir; npm install; npx playwright install chromium"
}

$js = @'
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");
const readline = require("readline");

const startUrl = process.argv[2];
const outputJson = process.argv[3];
const outputCsv = process.argv[4];
const summaryTxt = process.argv[5];
const screenshotPath = process.argv[6];
const root = process.argv[7];

const profileDir = path.join(root, "workspace", "digistore", "browser-profile");

const goodTerms = [
  "debt", "credit", "finance", "financial", "budget", "budgeting", "money",
  "loan", "loans", "personal finance", "relief", "saving", "savings", "consumer"
];

const badTerms = [
  "casino", "gambling", "betting", "sportsbook", "poker", "adult", "xxx",
  "porn", "cbd", "thc", "weed", "marijuana", "crypto casino", "magic mushroom",
  "supplement", "pills", "testosterone", "weight loss", "diet pill", "weapon", "knife", "gun"
];

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => rl.question(question, answer => { rl.close(); resolve(answer); }));
}

function csvEscape(value) {
  const s = String(value || "");
  return '"' + s.replace(/"/g, '""') + '"';
}

function cleanLine(line) {
  return String(line || "").replace(/\s+/g, " ").trim();
}

function classifyLine(line) {
  const lower = line.toLowerCase();
  const blocked = badTerms.some(term => lower.includes(term));
  const matchedTerms = goodTerms.filter(term => lower.includes(term));
  let score = matchedTerms.length * 10;

  if (lower.includes("debt")) score += 30;
  if (lower.includes("credit")) score += 20;
  if (lower.includes("budget")) score += 15;
  if (lower.includes("finance") || lower.includes("financial")) score += 15;
  if (lower.includes("loan")) score += 8;
  if (lower.includes("commission") || lower.includes("earnings") || lower.includes("promote")) score += 5;
  if (blocked) score = -100;

  return { blocked, matchedTerms, score };
}

(async () => {
  fs.mkdirSync(path.dirname(outputJson), { recursive: true });

  const context = await chromium.launchPersistentContext(profileDir, {
    headless: false,
    viewport: { width: 1440, height: 1000 }
  });

  const page = context.pages()[0] || await context.newPage();
  await page.goto(startUrl, { waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => {});

  console.log("");
  console.log("Vex Digistore Assisted Scanner");
  console.log("================================");
  console.log("1. In the browser window, log into Digistore24 if needed.");
  console.log("2. Switch to Affiliate View.");
  console.log("3. Open Marketplace.");
  console.log("4. Search one keyword, e.g. debt, credit, finance, budget, money.");
  console.log("5. When results are visible, return here and press ENTER.");
  console.log("");

  await ask("Press ENTER after marketplace results are visible...");

  await page.waitForTimeout(1500);
  const title = await page.title().catch(() => "");
  const url = page.url();
  const bodyText = await page.locator("body").innerText({ timeout: 10000 }).catch(() => "");

  await page.screenshot({ path: screenshotPath, fullPage: true }).catch(() => {});

  const rawLines = bodyText.split(/\r?\n/g).map(cleanLine).filter(Boolean);
  const candidates = [];
  const seen = new Set();

  for (let i = 0; i < rawLines.length; i++) {
    const line = rawLines[i];
    if (line.length < 12 || line.length > 220) continue;
    const c = classifyLine(line);
    if (c.score <= 0 || c.blocked) continue;
    const key = line.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    candidates.push({
      line,
      score: c.score,
      matched_terms: c.matchedTerms.join("|"),
      nearby: rawLines.slice(Math.max(0, i - 2), Math.min(rawLines.length, i + 3)).join(" || ")
    });
  }

  candidates.sort((a, b) => b.score - a.score);
  const top = candidates.slice(0, 40);

  const result = {
    scanned_at: new Date().toISOString(),
    page_title: title,
    page_url: url,
    screenshot: screenshotPath,
    candidate_count: top.length,
    candidates: top
  };

  fs.writeFileSync(outputJson, JSON.stringify(result, null, 2), "utf8");

  const csv = ["score,matched_terms,candidate_text,nearby_context"];
  for (const item of top) {
    csv.push([
      item.score,
      csvEscape(item.matched_terms),
      csvEscape(item.line),
      csvEscape(item.nearby)
    ].join(","));
  }
  fs.writeFileSync(outputCsv, csv.join("\n"), "utf8");

  const summary = [];
  summary.push("DIGISTORE24 MONEYCRUNCH SCAN SUMMARY");
  summary.push("====================================");
  summary.push("Generated: " + new Date().toISOString());
  summary.push("Page: " + url);
  summary.push("Title: " + title);
  summary.push("Screenshot: " + screenshotPath);
  summary.push("Candidates found: " + top.length);
  summary.push("");
  summary.push("TOP CANDIDATES / TEXT MATCHES");
  if (top.length === 0) {
    summary.push("- No strong finance/debt/credit/budget candidates found on the visible page.");
    summary.push("- Try searching another marketplace keyword, then rerun this script.");
  } else {
    for (let i = 0; i < Math.min(10, top.length); i++) {
      summary.push((i + 1) + ". [score " + top[i].score + "] " + top[i].line);
      summary.push("   Terms: " + top[i].matched_terms);
    }
  }
  summary.push("");
  summary.push("NEXT ACTIONS");
  summary.push("1. Manually open the top matching marketplace entries.");
  summary.push("2. Avoid scammy, adult, gambling, drug, supplement, or unrealistic claim offers.");
  summary.push("3. Add 3 to 5 safe candidates into moneycrunch_partner_tracker.csv.");
  summary.push("4. Prefer offers with clear affiliate support pages, normal compliance wording, and relevant finance/debt/credit/budget audience fit.");

  fs.writeFileSync(summaryTxt, summary.join("\n"), "utf8");

  console.log("");
  console.log("Scan complete.");
  console.log("JSON: " + outputJson);
  console.log("CSV: " + outputCsv);
  console.log("Summary: " + summaryTxt);
  console.log("Screenshot: " + screenshotPath);
  console.log("");

  await context.close();
})();
'@

Set-Content -Path $nodeScript -Value $js -Encoding UTF8

Push-Location $browserDir
try {
    node $nodeScript $StartUrl $outputJson $outputCsv $summaryTxt $screenshot $Root
}
finally {
    Pop-Location
}

Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Digistore scan output: " + $summaryTxt) -Encoding UTF8

Write-Host ""
Write-Host "Digistore scan files:" -ForegroundColor Green
Write-Host $summaryTxt
Write-Host $outputCsv
Write-Host $screenshot

if ($OpenResults) {
    notepad $summaryTxt
    notepad $outputCsv
}
