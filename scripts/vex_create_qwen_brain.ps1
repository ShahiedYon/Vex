param(
    [string]$Root = "",
    [string]$BaseModel = "qwen3:4b",
    [string]$VexModel = "vex-qwen3:4b",
    [switch]$Open
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function Run-Cmd {
    param([string]$Command)
    try {
        $out = powershell -NoProfile -ExecutionPolicy Bypass -Command $Command 2>&1
        return ($out | Out-String).Trim()
    }
    catch {
        return $_.Exception.Message
    }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$configDir = Join-Path $Root "config"
$workspace = Join-Path $Root "workspace"
$brainDir = Join-Path $workspace "brain"
$logs = Join-Path $Root "logs"
$modelfile = Join-Path $configDir "Modelfile.vex-qwen3"
$reportFile = Join-Path $brainDir "vex_qwen_brain_report.txt"
$logFile = Join-Path $logs "vex_create_qwen_brain.log"

Ensure-Directory $configDir
Ensure-Directory $workspace
Ensure-Directory $brainDir
Ensure-Directory $logs

$systemPrompt = @'
You are Vex, Shahied Yon’s local OpenClaw operator and automation co-pilot.

Your mission:
Help Shahied move fast and safely on MoneyCrunch, LumaSunUS, and Vextly by running practical automation, lead-generation support, research, local scripts, browser workflows, GitHub workflows, partner tracking, and operational checklists.

Core business priority:
1. MoneyCrunch debt relief lead generation and finance/referral partner outreach.
2. LumaSunUS solar affiliate/audience/lead generation.
3. Vextly automation consulting lead generation and delivery systems.

Your operating style:
- Be practical, concise, direct, and action-focused.
- Prefer exact commands, files, next actions, and clear status reports.
- Do not invent facts about Shahied, Vex, OpenClaw, MoneyCrunch, LumaSunUS, or Vextly.
- If unsure, say what is unknown and what to check next.
- Do not expose private chain-of-thought or hidden reasoning.
- Do not roleplay as a game character.
- You are not a MOBA game. You are Vex, Shahied’s local operator.
- Keep WhatsApp-style replies short unless asked for detail.
- For business workflows, recommend the fastest safe next step.

Important context:
- Vex root is usually C:\Users\yonsh\Vex.
- OpenClaw config is usually C:\Users\yonsh\.openclaw\openclaw.json.
- MoneyCrunch live site is https://moneycrunchusa.netlify.app/.
- Vex should help track partner applications, Digistore/CJ outreach, website readiness, and local automation health.

When asked “Who are you?” or “What is your mission?”, answer as Vex in one or two sentences.
'@

$modelfileContent = @()
$modelfileContent += "FROM $BaseModel"
$modelfileContent += ""
$modelfileContent += "PARAMETER temperature 0.3"
$modelfileContent += "PARAMETER top_p 0.8"
$modelfileContent += "PARAMETER num_ctx 8192"
$modelfileContent += ""
$modelfileContent += "SYSTEM \"\"\""
$modelfileContent += $systemPrompt
$modelfileContent += "\"\"\""

Set-Content -Path $modelfile -Value $modelfileContent -Encoding UTF8

$createOutput = Run-Cmd "ollama create $VexModel -f `"$modelfile`""
$testOutput = Run-Cmd "ollama run $VexModel --think=false `"Reply in one sentence: who are you and what is your mission?`""
$listOutput = Run-Cmd "ollama list"

$report = @()
$report += "VEX QWEN LOCAL BRAIN REPORT"
$report += "==========================="
$report += "Generated: " + (Get-Date).ToString("s")
$report += "Base model: " + $BaseModel
$report += "Vex model: " + $VexModel
$report += "Modelfile: " + $modelfile
$report += ""
$report += "CREATE OUTPUT"
$report += "-------------"
$report += $createOutput
$report += ""
$report += "TEST OUTPUT"
$report += "-----------"
$report += $testOutput
$report += ""
$report += "OLLAMA LIST"
$report += "-----------"
$report += $listOutput
$report += ""
$report += "NEXT TESTS"
$report += "ollama run $VexModel --think=false \"Who are you?\""
$report += "ollama run $VexModel --think=false \"What is your mission?\""
$report += ""
$report += "NEXT ROUTING OPTION"
$report += "If the test output is good, update OpenClaw fallback order to include ollama/$VexModel before ollama/mistral:latest."

Set-Content -Path $reportFile -Value $report -Encoding UTF8
Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Created local Vex Qwen brain: " + $VexModel) -Encoding UTF8

Write-Host "Vex local Qwen brain created." -ForegroundColor Green
Write-Host "Model: $VexModel"
Write-Host "Modelfile: $modelfile"
Write-Host "Report: $reportFile"
Write-Host ""
Write-Host "Test command:" -ForegroundColor Yellow
Write-Host "ollama run $VexModel --think=false \"Who are you?\""

if ($Open) { notepad $reportFile }
