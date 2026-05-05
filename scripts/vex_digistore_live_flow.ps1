param(
    [string]$Root = "",
    [int]$TimeoutMinutes = 30
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$browser = Join-Path $Root "browser"
$workspace = Join-Path $Root "workspace"
$digistore = Join-Path $workspace "digistore"
$checkpoints = Join-Path $workspace "checkpoints"
$logs = Join-Path $Root "logs"
$replyFile = Join-Path $digistore "digistore_flow_reply.txt"
$lastReply = Join-Path $workspace "vex_last_reply.txt"
$stateFile = Join-Path $digistore "digistore_flow_state.json"
$doneFile = Join-Path $checkpoints "digistore_login.done"
$nodeScript = Join-Path $browser "vex_digistore_live_flow.js"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputCsv = Join-Path $digistore ("digistore_live_candidates_" + $stamp + ".csv")
$outputJson = Join-Path $digistore ("digistore_live_scan_" + $stamp + ".json")
$outputTxt = Join-Path $digistore "digistore_live_next_actions.txt"
$outputPng = Join-Path $digistore ("digistore_live_scan_" + $stamp + ".png")
$logFile = Join-Path $logs "vex_digistore_live_flow.log"

Ensure-Directory $browser
Ensure-Directory $workspace
Ensure-Directory $digistore
Ensure-Directory $checkpoints
Ensure-Directory $logs

if (-not (Test-Path (Join-Path $browser "node_modules\playwright"))) {
    throw "Playwright missing. Run: cd $browser; npm install; npx playwright install chromium"
}

if (Test-Path $doneFile) { Remove-Item -Path $doneFile -Force }

function Set-Reply {
    param([string]$Text)
    Set-Content -Path $replyFile -Value $Text -Encoding UTF8
    Set-Content -Path $lastReply -Value $Text -Encoding UTF8
    Write-Host $Text
}

[pscustomobject]@{
    flow = "digistore_live_scan"
    status = "waiting_for_login"
    started_at = (Get-Date).ToString("s")
    done_file = $doneFile
} | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

Set-Reply "Vex opened Digistore. Log in, switch to Affiliate Marketplace, search a keyword like debt or credit, then reply yes."

$js = @'
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const root = process.argv[2];
const doneFile = process.argv[3];
const timeoutMinutes = Number(process.argv[4] || "30");
const outputCsv = process.argv[5];
const outputJson = process.argv[6];
const outputTxt = process.argv[7];
const outputPng = process.argv[8];

const profileDir = path.join(root, "workspace", "digistore", "browser-profile");
const startUrl = "https://www.digistore24.com/affiliates?lang=en";

const goodTerms = ["debt", "credit", "finance", "financial", "budget", "budgeting", "money", "loan", "loans", "relief", "saving", "savings", "consumer", "income", "cashflow", "affiliate", "commission", "promote"];
const badTerms = ["casino", "gambling", "betting", "sportsbook", "poker", "adult", "xxx", "porn", "cbd", "thc", "weed", "marijuana", "mushroom", "supplement", "testosterone", "weight loss", "diet pill", "weapon", "knife", "gun"];

function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function clean(s){return String(s || "").replace(/\s+/g," ").trim();}
function csvEscape(v){const s=String(v||""); return '"' + s.replace(/"/g,'""') + '"';}
function scoreLine(line){
  const lower = line.toLowerCase();
  if (badTerms.some(t => lower.includes(t))) return {score:-100, terms:[]};
  let score = 0; const terms = [];
  for (const t of goodTerms){ if(lower.includes(t)){ score += 10; terms.push(t); } }
  if(lower.includes("debt")) score += 35;
  if(lower.includes("credit")) score += 25;
  if(lower.includes("budget")) score += 18;
  if(lower.includes("finance") || lower.includes("financial")) score += 18;
  if(lower.includes("commission") || lower.includes("affiliate") || lower.includes("promote")) score += 8;
  return {score, terms};
}

function extractCandidates(text, pageUrl){
  const lines = text.split(/\r?\n/g).map(clean).filter(Boolean);
  const out = []; const seen = new Set();
  for(let i=0;i<lines.length;i++){
    const line = lines[i];
    if(line.length < 10 || line.length > 260) continue;
    const res = scoreLine(line);
    if(res.score <= 0) continue;
    const key = line.toLowerCase();
    if(seen.has(key)) continue;
    seen.add(key);
    out.push({
      score: res.score,
      matched_terms: res.terms.join("|"),
      candidate_text: line,
      nearby_context: lines.slice(Math.max(0,i-2), Math.min(lines.length,i+3)).join(" || "),
      page_url: pageUrl
    });
  }
  out.sort((a,b)=>b.score-a.score);
  return out.slice(0,80);
}

(async()=>{
  fs.mkdirSync(path.dirname(outputCsv), {recursive:true});
  const context = await chromium.launchPersistentContext(profileDir,{headless:false,viewport:{width:1440,height:1000}});
  const page = context.pages()[0] || await context.newPage();
  await page.goto(startUrl,{waitUntil:"domcontentloaded",timeout:45000}).catch(()=>{});

  const deadline = Date.now() + timeoutMinutes * 60 * 1000;
  while(Date.now() < deadline){
    if(fs.existsSync(doneFile)) break;
    await sleep(3000);
  }

  if(!fs.existsSync(doneFile)){
    const timeoutSummary = [
      "DIGISTORE LIVE SCAN TIMED OUT",
      "No confirmation received before timeout.",
      "Run 'vex check digistore' again when ready."
    ].join("\n");
    fs.writeFileSync(outputTxt, timeoutSummary, "utf8");
    await context.close();
    process.exit(2);
  }

  await page.waitForTimeout(1500);
  const pageUrl = page.url();
  const title = await page.title().catch(()=>"");
  const bodyText = await page.locator("body").innerText({timeout:15000}).catch(()=>"");
  await page.screenshot({path: outputPng, fullPage:true}).catch(()=>{});

  const candidates = extractCandidates(bodyText, pageUrl);
  const csvRows = ["score,matched_terms,candidate_text,nearby_context,page_url"];
  for(const c of candidates){
    csvRows.push([c.score,csvEscape(c.matched_terms),csvEscape(c.candidate_text),csvEscape(c.nearby_context),csvEscape(c.page_url)].join(","));
  }
  fs.writeFileSync(outputCsv, csvRows.join("\n"), "utf8");

  const json = { scanned_at:new Date().toISOString(), title, page_url:pageUrl, screenshot:outputPng, candidate_count:candidates.length, candidates };
  fs.writeFileSync(outputJson, JSON.stringify(json,null,2), "utf8");

  const summary = [];
  summary.push("DIGISTORE LIVE SCAN SUMMARY");
  summary.push("===========================");
  summary.push("Generated: " + new Date().toISOString());
  summary.push("Page: " + pageUrl);
  summary.push("Title: " + title);
  summary.push("Candidates: " + candidates.length);
  summary.push("CSV: " + outputCsv);
  summary.push("Screenshot: " + outputPng);
  summary.push("");
  summary.push("TOP MATCHES");
  if(candidates.length === 0){
    summary.push("- No strong candidates found on the current visible page.");
    summary.push("- Make sure Marketplace search results are visible before replying yes.");
  } else {
    for(let i=0;i<Math.min(10,candidates.length);i++){
      summary.push((i+1) + ". [" + candidates[i].score + "] " + candidates[i].candidate_text);
      summary.push("   Terms: " + candidates[i].matched_terms);
    }
  }
  summary.push("");
  summary.push("NEXT ACTIONS");
  summary.push("1. Open the CSV and inspect the top candidates.");
  summary.push("2. Manually verify top offers before promoting anything.");
  summary.push("3. Avoid unrealistic claims and risky categories.");
  summary.push("4. Add safe offers to moneycrunch_partner_tracker.csv.");
  fs.writeFileSync(outputTxt, summary.join("\n"), "utf8");

  await context.close();
})();
'@

Set-Content -Path $nodeScript -Value $js -Encoding UTF8

Push-Location $browser
try {
    node $nodeScript $Root $doneFile $TimeoutMinutes $outputCsv $outputJson $outputTxt $outputPng
    $exit = $LASTEXITCODE
}
finally {
    Pop-Location
}

if (Test-Path $outputTxt) {
    $summaryText = Get-Content -Path $outputTxt -Raw
    $final = "Vex Digistore live scan finished.`r`n`r`n" + $summaryText
    Set-Reply $final
}
else {
    Set-Reply "Vex Digistore live scan ended, but no summary file was created."
}

$status = "complete"
if ($exit -ne 0) { $status = "failed_or_timeout" }

[pscustomobject]@{
    flow = "digistore_live_scan"
    status = $status
    finished_at = (Get-Date).ToString("s")
    csv = if (Test-Path $outputCsv) { $outputCsv } else { "" }
    summary = if (Test-Path $outputTxt) { $outputTxt } else { "" }
    screenshot = if (Test-Path $outputPng) { $outputPng } else { "" }
} | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Live flow finished with status " + $status) -Encoding UTF8
