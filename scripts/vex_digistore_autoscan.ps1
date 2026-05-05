param(
    [string]$Root = "",
    [string]$Keywords = "debt,credit,finance,budget,money,loan,financial wellness",
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
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot }
    else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$browserDir = Join-Path $Root "browser"
$workspace = Join-Path $Root "workspace"
$digistoreDir = Join-Path $workspace "digistore"
$logsDir = Join-Path $Root "logs"
$nodeScript = Join-Path $browserDir "vex_digistore_autoscan.js"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputCsv = Join-Path $digistoreDir ("digistore_autoscan_candidates_" + $stamp + ".csv")
$outputJson = Join-Path $digistoreDir ("digistore_autoscan_" + $stamp + ".json")
$summaryTxt = Join-Path $digistoreDir "digistore_autoscan_next_actions.txt"
$screenshot = Join-Path $digistoreDir ("digistore_autoscan_" + $stamp + ".png")
$logFile = Join-Path $logsDir "vex_digistore_autoscan.log"

Ensure-Directory $browserDir
Ensure-Directory $workspace
Ensure-Directory $digistoreDir
Ensure-Directory $logsDir

if (-not (Test-Path (Join-Path $browserDir "node_modules\playwright"))) {
    throw "Playwright is missing. Run: cd $browserDir; npm install; npx playwright install chromium"
}

$js = @'
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");
const readline = require("readline");

const root = process.argv[2];
const keywords = process.argv[3].split(",").map(x => x.trim()).filter(Boolean);
const outputCsv = process.argv[4];
const outputJson = process.argv[5];
const summaryTxt = process.argv[6];
const screenshotPath = process.argv[7];

const profileDir = path.join(root, "workspace", "digistore", "browser-profile");

const possibleMarketplaceUrls = [
  "https://www.digistore24.com/marketplace",
  "https://www.digistore24.com/en/home/marketplace",
  "https://www.digistore24.com/affiliates/marketplace",
  "https://www.digistore24.com/affiliate/marketplace",
  "https://www.digistore24.com/affiliates?lang=en",
  "https://www.digistore24.com/"
];

const goodTerms = ["debt", "credit", "finance", "financial", "budget", "budgeting", "money", "loan", "loans", "relief", "saving", "savings", "consumer", "income", "cashflow"];
const badTerms = ["casino", "gambling", "betting", "sportsbook", "poker", "adult", "xxx", "porn", "cbd", "thc", "weed", "marijuana", "mushroom", "supplement", "testosterone", "weight loss", "diet pill", "weapon", "knife", "gun", "forex signals", "binary options"];

function ask(q) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => rl.question(q, answer => { rl.close(); resolve(answer); }));
}

function csvEscape(value) {
  const s = String(value || "");
  return '"' + s.replace(/"/g, '""') + '"';
}

function clean(s) {
  return String(s || "").replace(/\s+/g, " ").trim();
}

function scoreText(text) {
  const lower = text.toLowerCase();
  if (badTerms.some(t => lower.includes(t))) return -100;
  let score = 0;
  const matched = [];
  for (const term of goodTerms) {
    if (lower.includes(term)) { score += 10; matched.push(term); }
  }
  if (lower.includes("debt")) score += 35;
  if (lower.includes("credit")) score += 25;
  if (lower.includes("budget")) score += 18;
  if (lower.includes("finance") || lower.includes("financial")) score += 18;
  if (lower.includes("loan")) score += 8;
  if (lower.includes("promote") || lower.includes("commission") || lower.includes("affiliate")) score += 8;
  return { score, matched };
}

async function tryClickText(page, patterns) {
  for (const p of patterns) {
    try {
      const loc = page.getByText(p, { exact: false }).first();
      if (await loc.count()) {
        await loc.click({ timeout: 3000 });
        await page.waitForTimeout(2000);
        return true;
      }
    } catch {}
  }
  return false;
}

async function findSearchBox(page) {
  const selectors = [
    'input[type="search"]',
    'input[placeholder*="Search" i]',
    'input[placeholder*="search" i]',
    'input[name*="search" i]',
    'input[id*="search" i]',
    'input[type="text"]'
  ];
  for (const sel of selectors) {
    try {
      const loc = page.locator(sel).first();
      if (await loc.count()) return loc;
    } catch {}
  }
  return null;
}

async function visibleText(page) {
  return await page.locator("body").innerText({ timeout: 10000 }).catch(() => "");
}

function extractCandidates(keyword, text, pageUrl) {
  const lines = text.split(/\r?\n/g).map(clean).filter(Boolean);
  const out = [];
  const seen = new Set();
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.length < 12 || line.length > 240) continue;
    const result = scoreText(line + " " + keyword);
    if (result.score <= 0) continue;
    const key = line.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({
      keyword,
      score: result.score,
      matched_terms: result.matched.join("|"),
      candidate_text: line,
      nearby_context: lines.slice(Math.max(0, i - 2), Math.min(lines.length, i + 3)).join(" || "),
      page_url: pageUrl
    });
  }
  return out;
}

(async () => {
  fs.mkdirSync(path.dirname(outputCsv), { recursive: true });

  const context = await chromium.launchPersistentContext(profileDir, {
    headless: false,
    viewport: { width: 1440, height: 1000 }
  });
  const page = context.pages()[0] || await context.newPage();

  console.log("Vex Digistore Auto Scanner");
  console.log("==========================");
  console.log("Vex will reuse this browser profile. If Digistore asks you to log in, do it once.");
  console.log("After login, Vex will try to scan marketplace keywords automatically.");
  console.log("");

  let reached = false;
  for (const url of possibleMarketplaceUrls) {
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
      await page.waitForTimeout(2500);
      const txt = (await visibleText(page)).toLowerCase();
      if (txt.includes("marketplace") || txt.includes("affiliate") || txt.includes("login") || txt.includes("log in")) {
        reached = true;
        break;
      }
    } catch {}
  }

  let body = (await visibleText(page)).toLowerCase();
  if (body.includes("login") || body.includes("log in") || body.includes("password") || body.includes("sign in")) {
    console.log("Login appears to be required.");
    console.log("Please log in manually in the browser window. Then navigate to Affiliate View > Marketplace if needed.");
    await ask("Press ENTER when you are logged in and marketplace is visible, or at least when Digistore dashboard is open...");
  }

  await tryClickText(page, ["Affiliate View", "Affiliate", "Marketplace", "Products", "Market"]);
  await page.waitForTimeout(1500);

  const allCandidates = [];

  for (const keyword of keywords) {
    console.log("Scanning keyword: " + keyword);

    let searchBox = await findSearchBox(page);
    if (searchBox) {
      try {
        await searchBox.click({ timeout: 3000 });
        await searchBox.fill("");
        await searchBox.fill(keyword);
        await searchBox.press("Enter");
        await page.waitForTimeout(3500);
      } catch {
        // If the visible search box fails, still capture current page text.
      }
    }

    const txt = await visibleText(page);
    allCandidates.push(...extractCandidates(keyword, txt, page.url()));
  }

  await page.screenshot({ path: screenshotPath, fullPage: true }).catch(() => {});

  const dedupe = new Map();
  for (const item of allCandidates) {
    const key = item.candidate_text.toLowerCase();
    if (!dedupe.has(key) || dedupe.get(key).score < item.score) dedupe.set(key, item);
  }

  const ranked = [...dedupe.values()].sort((a, b) => b.score - a.score).slice(0, 60);

  const csvRows = ["score,keyword,matched_terms,candidate_text,nearby_context,page_url"];
  for (const item of ranked) {
    csvRows.push([
      item.score,
      csvEscape(item.keyword),
      csvEscape(item.matched_terms),
      csvEscape(item.candidate_text),
      csvEscape(item.nearby_context),
      csvEscape(item.page_url)
    ].join(","));
  }
  fs.writeFileSync(outputCsv, csvRows.join("\n"), "utf8");

  const result = {
    scanned_at: new Date().toISOString(),
    keywords,
    final_url: page.url(),
    screenshot: screenshotPath,
    candidate_count: ranked.length,
    candidates: ranked
  };
  fs.writeFileSync(outputJson, JSON.stringify(result, null, 2), "utf8");

  const summary = [];
  summary.push("DIGISTORE24 AUTO SCAN SUMMARY");
  summary.push("=============================");
  summary.push("Generated: " + new Date().toISOString());
  summary.push("Final page: " + page.url());
  summary.push("Screenshot: " + screenshotPath);
  summary.push("Candidates: " + ranked.length);
  summary.push("");
  summary.push("TOP MATCHES");
  if (ranked.length === 0) {
    summary.push("- No strong matches captured. Make sure Marketplace results are visible, then rerun.");
  } else {
    for (let i = 0; i < Math.min(15, ranked.length); i++) {
      const item = ranked[i];
      summary.push((i + 1) + ". [" + item.score + "] " + item.candidate_text);
      summary.push("   Keyword: " + item.keyword + " | Terms: " + item.matched_terms);
    }
  }
  summary.push("");
  summary.push("NEXT ACTIONS");
  summary.push("1. Open the CSV and review top candidates.");
  summary.push("2. Manually inspect the top 3 offers before promoting anything.");
  summary.push("3. Avoid offers with unrealistic claims or risky categories.");
  summary.push("4. Add safe candidates to moneycrunch_partner_tracker.csv.");

  fs.writeFileSync(summaryTxt, summary.join("\n"), "utf8");

  console.log("");
  console.log("Auto scan complete.");
  console.log("Summary: " + summaryTxt);
  console.log("CSV: " + outputCsv);
  console.log("JSON: " + outputJson);
  console.log("Screenshot: " + screenshotPath);
  console.log("");

  await context.close();
})();
'@

Set-Content -Path $nodeScript -Value $js -Encoding UTF8

Push-Location $browserDir
try {
    node $nodeScript $Root $Keywords $outputCsv $outputJson $summaryTxt $screenshot
}
finally {
    Pop-Location
}

Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Digistore autoscan output: " + $summaryTxt) -Encoding UTF8

Write-Host ""
Write-Host "Digistore autoscan files:" -ForegroundColor Green
Write-Host $summaryTxt
Write-Host $outputCsv
Write-Host $screenshot

if ($OpenResults) {
    notepad $summaryTxt
    notepad $outputCsv
}
