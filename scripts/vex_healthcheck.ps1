param(
    [string]$Root = ""
)

$ErrorActionPreference = "Continue"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "==== $Title ====" -ForegroundColor Cyan
}

function Write-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Details = "",
        [string]$Fix = ""
    )

    if ($Ok) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
    }

    if (-not [string]::IsNullOrWhiteSpace($Details)) {
        Write-Host "       $Details" -ForegroundColor DarkGray
    }

    if (-not $Ok -and -not [string]::IsNullOrWhiteSpace($Fix)) {
        Write-Host "       FIX: $Fix" -ForegroundColor Yellow
    }
}

function Get-CommandText {
    param([string]$Command)
    try {
        $result = & powershell -NoProfile -ExecutionPolicy Bypass -Command $Command 2>$null
        if ($LASTEXITCODE -ne 0 -and $null -eq $result) { return $null }
        return ($result | Out-String).Trim()
    }
    catch {
        return $null
    }
}

function Test-HttpEndpoint {
    param(
        [string]$Url,
        [int]$TimeoutSec = 3
    )
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 500
    }
    catch {
        return $false
    }
}

function Test-TcpPort {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMs = 1200
    )
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $wait) {
            $client.Close()
            return $false
        }
        $client.EndConnect($async)
        $client.Close()
        return $true
    }
    catch {
        return $false
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
$openClawRoot = Join-Path $env:USERPROFILE ".openclaw"
$openClawConfig = Join-Path $openClawRoot "openclaw.json"
$whatsAppCredsDir = Join-Path $openClawRoot "credentials\whatsapp"

Write-Host ""
Write-Host "Vex Local Runtime Healthcheck" -ForegroundColor White
Write-Host "Generated for local read-only diagnostics." -ForegroundColor DarkGray
Write-Host "Root: $Root" -ForegroundColor DarkGray
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray

Write-Section "Repo + Folder Structure"
Write-Check "Vex root exists" (Test-Path $Root) $Root "Check that Vex is cloned to the expected folder."

$requiredDirs = @("scripts", "browser", "workspace", "logs", "tasks", "memory", "config", "data")
foreach ($dir in $requiredDirs) {
    $path = Join-Path $Root $dir
    $required = @("scripts", "browser") -contains $dir
    $exists = Test-Path $path
    if ($required) {
        Write-Check "$dir folder exists" $exists $path "Create or restore this folder from the repo/setup scripts."
    }
    else {
        if ($exists) {
            Write-Check "$dir folder exists" $true $path
        }
        else {
            Write-Host "[WARN] $dir folder missing" -ForegroundColor Yellow
            Write-Host "       $path" -ForegroundColor DarkGray
        }
    }
}

$gitPath = Join-Path $Root ".git"
Write-Check "Git repo detected" (Test-Path $gitPath) $gitPath "Run: git clone https://github.com/ShahiedYon/Vex.git C:\Users\yonsh\Vex"

if (Test-Path $gitPath) {
    Push-Location $Root
    try {
        $branch = Get-CommandText "git branch --show-current"
        $status = Get-CommandText "git status --porcelain"
        $remote = Get-CommandText "git remote -v"
        Write-Check "Git branch readable" (-not [string]::IsNullOrWhiteSpace($branch)) "Branch: $branch" "Run: git status"
        Write-Check "Git working tree clean" ([string]::IsNullOrWhiteSpace($status)) "Uncommitted output: $status" "Commit/stash changes or ask ChatGPT before overwriting local edits."
        Write-Check "Git remote configured" (-not [string]::IsNullOrWhiteSpace($remote)) ($remote -split "`n" | Select-Object -First 1) "Run: git remote -v"
    }
    finally {
        Pop-Location
    }
}

Write-Section "Node + Browser Automation"
$nodeVersion = Get-CommandText "node -v"
Write-Check "Node installed" (-not [string]::IsNullOrWhiteSpace($nodeVersion)) $nodeVersion "Install Node.js LTS, then reopen PowerShell."

$npmVersion = Get-CommandText "npm -v"
Write-Check "npm installed" (-not [string]::IsNullOrWhiteSpace($npmVersion)) $npmVersion "Install Node.js LTS, then reopen PowerShell."

$browserDir = Join-Path $Root "browser"
$packageJson = Join-Path $browserDir "package.json"
$nodeModules = Join-Path $browserDir "node_modules"
$playwrightModule = Join-Path $browserDir "node_modules\playwright"

Write-Check "browser\package.json exists" (Test-Path $packageJson) $packageJson "Run from Vex root: cd browser; npm install"
Write-Check "browser\node_modules exists" (Test-Path $nodeModules) $nodeModules "Run from Vex root: cd browser; npm install"
Write-Check "Playwright npm module installed" (Test-Path $playwrightModule) $playwrightModule "Run from Vex root: cd browser; npm install; npx playwright install chromium"

$msPlaywright = Join-Path $env:LOCALAPPDATA "ms-playwright"
Write-Check "Playwright browser cache exists" (Test-Path $msPlaywright) $msPlaywright "Run from Vex root: cd browser; npx playwright install chromium"

Write-Section "Ollama + Local Models"
$ollamaVersion = Get-CommandText "ollama --version"
Write-Check "Ollama command available" (-not [string]::IsNullOrWhiteSpace($ollamaVersion)) $ollamaVersion "Install/start Ollama, then retry."

$ollamaOk = Test-HttpEndpoint "http://127.0.0.1:11434/api/tags" 3
Write-Check "Ollama API reachable" $ollamaOk "http://127.0.0.1:11434/api/tags" "Start Ollama or run: ollama serve"

if ($ollamaOk) {
    try {
        $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3
        $models = @()
        if ($tags.models) {
            foreach ($m in $tags.models) { $models += $m.name }
        }
        Write-Host "       Models: $($models -join ', ')" -ForegroundColor DarkGray
    }
    catch {}
}

Write-Section "OpenClaw Local Runtime"
Write-Check ".openclaw folder exists" (Test-Path $openClawRoot) $openClawRoot "Run your OpenClaw setup/install first."
Write-Check "OpenClaw config exists" (Test-Path $openClawConfig) $openClawConfig "Expected config path: $openClawConfig"
Write-Check "WhatsApp credentials folder exists" (Test-Path $whatsAppCredsDir) $whatsAppCredsDir "Pair/login WhatsApp through OpenClaw again if missing."

$gatewayPort = 18789
$gatewayTcp = Test-TcpPort "127.0.0.1" $gatewayPort
Write-Check "OpenClaw gateway port reachable" $gatewayTcp "127.0.0.1:$gatewayPort" "Start gateway: openclaw gateway"

$openclawVersion = Get-CommandText "openclaw --version"
Write-Check "OpenClaw command available" (-not [string]::IsNullOrWhiteSpace($openclawVersion)) $openclawVersion "Install OpenClaw CLI or check npm global path."

Write-Section "Vex Business Runtime Files"
$contentDir = Join-Path $Root "workspace\content"
$campaignDir = Join-Path $Root "workspace\campaigns"
Write-Check "workspace\content exists" (Test-Path $contentDir) $contentDir "Create content files before running campaign phases."
Write-Check "workspace\campaigns exists" (Test-Path $campaignDir) $campaignDir "Run phase16e after content files exist."

$contentFiles = @(
    "debt_relief_posts_x.txt",
    "debt_relief_posts_facebook.txt",
    "solar_posts_x.txt",
    "solar_posts_facebook.txt"
)
foreach ($file in $contentFiles) {
    $path = Join-Path $contentDir $file
    $exists = Test-Path $path
    if ($exists) {
        Write-Check "$file exists" $true $path
    }
    else {
        Write-Host "[WARN] $file missing" -ForegroundColor Yellow
        Write-Host "       $path" -ForegroundColor DarkGray
    }
}

Write-Section "Suggested Next Action"
if (-not (Test-Path $playwrightModule)) {
    Write-Host "Run this first:" -ForegroundColor Yellow
    Write-Host "cd $browserDir" -ForegroundColor White
    Write-Host "npm install" -ForegroundColor White
    Write-Host "npx playwright install chromium" -ForegroundColor White
}
elseif (-not $ollamaOk) {
    Write-Host "Start Ollama first:" -ForegroundColor Yellow
    Write-Host "ollama serve" -ForegroundColor White
}
elseif (-not $gatewayTcp) {
    Write-Host "Start OpenClaw gateway first:" -ForegroundColor Yellow
    Write-Host "openclaw gateway" -ForegroundColor White
}
else {
    Write-Host "Core local runtime checks passed enough to continue to Vex stabilization." -ForegroundColor Green
    Write-Host "Next useful test:" -ForegroundColor Yellow
    Write-Host "powershell -ExecutionPolicy Bypass -File $Root\scripts\phase14c_run.ps1 -url https://moneycrunchusa.netlify.app/" -ForegroundColor White
}

Write-Host ""
