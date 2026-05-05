param(
    [string]$Root = "",
    [string]$Action = "list",
    [string]$Target = ""
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
$approvals = Join-Path $workspace "approvals"
$pending = Join-Path $approvals "pending"
$approved = Join-Path $approvals "approved"
$rejected = Join-Path $approvals "rejected"
$logs = Join-Path $Root "logs"
$replyFile = Join-Path $workspace "vex_last_reply.txt"
$logFile = Join-Path $logs "vex_approval_queue.log"

Ensure-Directory $workspace
Ensure-Directory $approvals
Ensure-Directory $pending
Ensure-Directory $approved
Ensure-Directory $rejected
Ensure-Directory $logs

function Get-PendingFiles {
    return @(Get-ChildItem -Path $pending -Filter "*.txt" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
}

function Write-Reply {
    param([string[]]$Lines)
    $text = $Lines -join "`r`n"
    Set-Content -Path $replyFile -Value $text -Encoding UTF8
    Write-Host $text
}

function Resolve-TargetFile {
    param([string]$T)
    $files = Get-PendingFiles
    if ($files.Count -eq 0) { return $null }
    $trim = ($T + "").Trim()
    $num = 0
    if ([int]::TryParse($trim, [ref]$num)) {
        if ($num -ge 1 -and $num -le $files.Count) { return $files[$num - 1] }
    }
    foreach ($f in $files) {
        if ($f.BaseName -eq $trim -or $f.Name -eq $trim) { return $f }
    }
    return $null
}

$actionLower = $Action.ToLowerInvariant()

if ($actionLower -eq "list") {
    $files = Get-PendingFiles
    $out = @()
    $out += "Pending approvals: " + $files.Count
    $out += ""
    if ($files.Count -eq 0) {
        $out += "No pending drafts."
    }
    else {
        for ($i = 0; $i -lt $files.Count; $i++) {
            $n = $i + 1
            $content = Get-Content -Path $files[$i].FullName -Raw
            $preview = ($content -replace "(?s).*POST_TEXT:\s*", "").Trim()
            if ($preview.Length -gt 280) { $preview = $preview.Substring(0, 280) + "..." }
            $out += "$n. " + $files[$i].BaseName
            $out += $preview
            $out += ""
        }
    }
    $out += "Commands: approve 1, reject 1, approvals"
    Write-Reply $out
    exit 0
}

if ($actionLower -ne "approve" -and $actionLower -ne "reject") {
    Write-Reply @("Unknown approval action: $Action", "Use: approvals, approve 1, reject 1")
    exit 1
}

$file = Resolve-TargetFile -T $Target
if ($null -eq $file) {
    Write-Reply @("Could not find pending item: $Target", "Use: approvals")
    exit 1
}

$destDir = if ($actionLower -eq "approve") { $approved } else { $rejected }
$dest = Join-Path $destDir $file.Name
Move-Item -Path $file.FullName -Destination $dest -Force

$pastTense = if ($actionLower -eq "approve") { "approved" } else { "rejected" }
Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $pastTense + " " + $file.Name) -Encoding UTF8

$content = Get-Content -Path $dest -Raw
$preview = ($content -replace "(?s).*POST_TEXT:\s*", "").Trim()
$out = @()
$out += "Draft " + $pastTense + "."
$out += "ID: " + $file.BaseName
$out += "Saved to: " + $dest
$out += ""
$out += $preview
Write-Reply $out
