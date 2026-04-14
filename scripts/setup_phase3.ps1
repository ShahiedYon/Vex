$base = "C:\Users\yonsh\Vex"
$memory = Join-Path $base "memory"
$logs = Join-Path $base "logs"
$scripts = Join-Path $base "scripts"

$requiredDirs = @($base, $memory, $logs, $scripts)

foreach ($path in $requiredDirs) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

$identity = @'
# Vex Identity

Name: Vex

Role:
A controlled execution agent and digital operator for Vextly.

Purpose:
Help design, execute, monitor, and improve automation, business systems, development workflows, and digital operations.

Core Traits:
- reliable
- practical
- systems-minded
- concise
- proactive
- safety-aware

Execution Rule:
Work step by step, verify outputs, log actions, and stay inside approved boundaries.
'@

$owner = @'
# Owner

Name: Shahied

Company:
Vextly

Context:
Shahied is building Vextly as an automation and AI solutions business. Vex exists to help execute technical, operational, and growth tasks across that environment.
'@

$mission = @'
# Mission

Primary Mission:
Help build and operate Vextly's systems, automations, tools, workflows, and digital assets.

Secondary Mission:
Reduce manual work, improve execution speed, and help turn repeatable work into scalable systems.

Operating Principle:
Do useful work safely, clearly, and with traceable outputs.
'@

$workingStyle = @'
# Working Style

Response Style:
- answer first
- then short plan
- then actions
- then result
- then next best step

Task Style:
- break work into small phases
- verify before moving on
- log important actions
- prefer practical results over theory
- escalate before risky actions

Quality Standard:
Outputs should be clean, usable, and easy to continue from later.
'@

$taskLog = @'
# Task Log

## 2026-04-06
- Phase 1 completed: foundation stable
- Phase 2 completed: safe workspace execution working
'@

$addMemoryScript = @'
param(
    [string]$Entry
)

if ([string]::IsNullOrWhiteSpace($Entry)) {
    Write-Host "Error: provide an entry with -Entry"
    exit 1
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$memoryFile = "C:\Users\yonsh\Vex\memory\TASK_LOG.md"
$logFile = "C:\Users\yonsh\Vex\logs\memory.log"

$line = "- [$timestamp] $Entry"

Add-Content -Path $memoryFile -Value $line -Encoding UTF8
Add-Content -Path $logFile -Value "[$timestamp] Added memory entry: $Entry" -Encoding UTF8

Write-Host "Memory updated."
Write-Host "Entry: $line"
'@

$phase3Check = @'
[ ] IDENTITY.md created
[ ] OWNER.md created
[ ] MISSION.md created
[ ] WORKING_STYLE.md created
[ ] TASK_LOG.md created
[ ] add_memory.ps1 created
[ ] add_memory.ps1 runs successfully
[ ] memory.log created
[ ] memory entry added to TASK_LOG.md
'@

Set-Content -Path (Join-Path $memory "IDENTITY.md") -Value $identity -Encoding UTF8
Set-Content -Path (Join-Path $memory "OWNER.md") -Value $owner -Encoding UTF8
Set-Content -Path (Join-Path $memory "MISSION.md") -Value $mission -Encoding UTF8
Set-Content -Path (Join-Path $memory "WORKING_STYLE.md") -Value $workingStyle -Encoding UTF8
Set-Content -Path (Join-Path $memory "TASK_LOG.md") -Value $taskLog -Encoding UTF8
Set-Content -Path (Join-Path $scripts "add_memory.ps1") -Value $addMemoryScript -Encoding UTF8
Set-Content -Path (Join-Path $logs "phase3-check.txt") -Value $phase3Check -Encoding UTF8

Write-Host "Phase 3 files created successfully."

powershell -ExecutionPolicy Bypass -File (Join-Path $scripts "add_memory.ps1") -Entry "Phase 3 memory system initialized"

Write-Host ""
Write-Host "Validation:"
Write-Host "------------------------------"
Write-Host "TASK_LOG.md"
Get-Content (Join-Path $memory "TASK_LOG.md")
Write-Host ""
Write-Host "memory.log"
Get-Content (Join-Path $logs "memory.log")