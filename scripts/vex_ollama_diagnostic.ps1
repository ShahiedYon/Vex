param(
    [string]$Root = "",
    [string]$Model = "mistral:latest",
    [switch]$Open
)

$ErrorActionPreference = "Continue"

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

function Measure-OllamaGenerate {
    param(
        [string]$ModelName,
        [string]$Prompt
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $body = @{ model = $ModelName; prompt = $Prompt; stream = $false; options = @{ num_predict = 30 } } | ConvertTo-Json -Depth 5
        $result = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 60
        $sw.Stop()
        return [pscustomobject]@{ ok=$true; ms=$sw.ElapsedMilliseconds; response=($result.response + "").Trim(); error="" }
    }
    catch {
        $sw.Stop()
        return [pscustomobject]@{ ok=$false; ms=$sw.ElapsedMilliseconds; response=""; error=$_.Exception.Message }
    }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$workspace = Join-Path $Root "workspace"
$brainDir = Join-Path $workspace "brain"
$logs = Join-Path $Root "logs"
$reportPath = Join-Path $brainDir "vex_ollama_diagnostic.txt"
$logFile = Join-Path $logs "vex_ollama_diagnostic.log"

Ensure-Directory $workspace
Ensure-Directory $brainDir
Ensure-Directory $logs

$ollamaVersion = Run-Cmd "ollama --version"
$ollamaList = Run-Cmd "ollama list"
$ollamaPs = Run-Cmd "ollama ps"
$apiTags = ""
try { $apiTags = (Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 5 | ConvertTo-Json -Depth 8) } catch { $apiTags = $_.Exception.Message }

$test1 = Measure-OllamaGenerate -ModelName $Model -Prompt "Reply with exactly: Vex local model ok"
$test2 = Measure-OllamaGenerate -ModelName $Model -Prompt "In one short sentence, say what you are."

$report = @()
$report += "VEX OLLAMA DIAGNOSTIC"
$report += "====================="
$report += "Generated: " + (Get-Date).ToString("s")
$report += "Root: " + $Root
$report += "Model tested: " + $Model
$report += ""
$report += "OLLAMA VERSION"
$report += "--------------"
$report += $ollamaVersion
$report += ""
$report += "OLLAMA LIST"
$report += "-----------"
$report += $ollamaList
$report += ""
$report += "OLLAMA PS"
$report += "---------"
$report += $ollamaPs
$report += ""
$report += "OLLAMA API TAGS"
$report += "---------------"
$report += $apiTags
$report += ""
$report += "GENERATE TEST 1"
$report += "---------------"
$report += "OK: " + $test1.ok
$report += "Milliseconds: " + $test1.ms
if ($test1.ok) { $report += "Response: " + $test1.response } else { $report += "Error: " + $test1.error }
$report += ""
$report += "GENERATE TEST 2"
$report += "---------------"
$report += "OK: " + $test2.ok
$report += "Milliseconds: " + $test2.ms
if ($test2.ok) { $report += "Response: " + $test2.response } else { $report += "Error: " + $test2.error }
$report += ""
$report += "INTERPRETATION"
if ($test1.ok -and $test1.ms -lt 15000) {
    $report += "- Ollama model is responding fast enough for fallback use."
}
elseif ($test1.ok) {
    $report += "- Ollama model responds, but slowly. It may time out inside OpenClaw probes."
    $report += "- Recommendation: keep it as last fallback, or add a smaller local model."
}
else {
    $report += "- Ollama generate test failed or timed out."
    $report += "- Recommendation: restart Ollama, test with a smaller model, or keep Ollama as disabled/last fallback."
}
$report += ""
$report += "POSSIBLE FIXES"
$report += "1. Restart Ollama: stop the Ollama app/service, then reopen it."
$report += "2. Preload model: ollama run " + $Model
$report += "3. Try a smaller local fallback, e.g. ollama pull llama3.2:3b or ollama pull qwen2.5:3b, if available on your Ollama install."
$report += "4. Keep OpenRouter as cloud fallback before Ollama for urgent workflows."

Set-Content -Path $reportPath -Value $report -Encoding UTF8
Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] Ollama diagnostic completed. Report: " + $reportPath) -Encoding UTF8

Write-Host "Ollama diagnostic report created:" -ForegroundColor Green
Write-Host $reportPath

if ($Open) { notepad $reportPath }
