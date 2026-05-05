param(
    [string]$Root = "",
    [string]$Keywords = "debt,credit,finance,budget,money,loan,financial wellness",
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
$workspace = Join-Path $Root "workspace"
$digistore = Join-Path $workspace "digistore"
$checkpoints = Join-Path $workspace "checkpoints"
$logs = Join-Path $Root "logs"
$browser = Join-Path $Root "browser"
$doneFile = Join-Path $checkpoints "digistore_login.done"
$replyFile = Join-Path $digistore "digistore_flow_reply.txt"
$stateFile = Join-Path $digistore "digistore_flow_state.json"
$nodeScript = Join-Path $browser "vex_digistore_wait_login.js"
$autoscan = Join-Path $Root "scripts\vex_digistore_autoscan.ps1"

Ensure-Directory $workspace
Ensure-Directory $digistore
Ensure-Directory $checkpoints
Ensure-Directory $logs
Ensure-Directory $browser

if (-not (Test-Path $autoscan)) { throw "Missing autoscan script: $autoscan" }
if (Test-Path $doneFile) { Remove-Item -Path $doneFile -Force }

[pscustomobject]@{
    flow = "digistore_scan"
    status = "waiting_for_login"
    started_at = (Get-Date).ToString("s")
    done_file = $doneFile
} | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

Set-Content -Path $replyFile -Value "Vex opened Digistore. Please log in, open Affiliate Marketplace, then reply yes." -Encoding UTF8

$js = @'
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");
const root = process.argv[2];
const doneFile = process.argv[3];
const timeoutMinutes = Number(process.argv[4] || "30");
const profileDir = path.join(root, "workspace", "digistore", "browser-profile");
const startUrl = "https://www.digistore24.com/affiliates?lang=en";
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
(async()=>{
  const context = await chromium.launchPersistentContext(profileDir,{headless:false,viewport:{width:1440,height:1000}});
  const page = context.pages()[0] || await context.newPage();
  await page.goto(startUrl,{waitUntil:"domcontentloaded",timeout:45000}).catch(()=>{});
  const deadline = Date.now() + timeoutMinutes * 60 * 1000;
  while(Date.now() < deadline){
    if(fs.existsSync(doneFile)) break;
    await sleep(3000);
  }
  await context.close();
})();
'@
Set-Content -Path $nodeScript -Value $js -Encoding UTF8

Push-Location $browser
try { node $nodeScript $Root $doneFile $TimeoutMinutes }
finally { Pop-Location }

if (-not (Test-Path $doneFile)) {
    [pscustomobject]@{ flow="digistore_scan"; status="timed_out"; finished_at=(Get-Date).ToString("s") } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
    Set-Content -Path $replyFile -Value "Digistore login timed out. Send 'vex check digistore' again when ready." -Encoding UTF8
    throw "Timed out waiting for login confirmation."
}

Set-Content -Path $replyFile -Value "Login confirmed. Vex is scanning Digistore now." -Encoding UTF8
[pscustomobject]@{ flow="digistore_scan"; status="scanning"; confirmed_at=(Get-Date).ToString("s") } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

powershell -ExecutionPolicy Bypass -File $autoscan -Root $Root -Keywords $Keywords

$summary = Join-Path $digistore "digistore_autoscan_next_actions.txt"
if (Test-Path $summary) {
    $txt = Get-Content -Path $summary -Raw
    Set-Content -Path $replyFile -Value ("Vex Digistore scan complete.`r`n`r`n" + $txt) -Encoding UTF8
} else {
    Set-Content -Path $replyFile -Value "Vex Digistore scan finished. Check workspace\digistore for output files." -Encoding UTF8
}

[pscustomobject]@{ flow="digistore_scan"; status="complete"; finished_at=(Get-Date).ToString("s"); reply_file=$replyFile } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
Write-Host "Digistore flow complete. Reply file: $replyFile" -ForegroundColor Green
