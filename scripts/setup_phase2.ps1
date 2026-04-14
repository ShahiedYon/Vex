$base = "C:\Users\yonsh\Vex"
$workspace = Join-Path $base "workspace"
$logs = Join-Path $base "logs"
$memory = Join-Path $base "memory"
$scripts = Join-Path $base "scripts"

$filesToCreate = @(
    $base,
    $workspace,
    $logs,
    $memory,
    $scripts
)

foreach ($path in $filesToCreate) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

$allowedCommands = @'
python
py
node
npm
git
git status
git pull
git add
git commit
git clone
dir
ls
cd
type
cat
copy
xcopy
mkdir
echo
powershell -File
ollama list
ollama run
'@

$blockedPaths = @'
C:\Windows
C:\Program Files
C:\Program Files (x86)
C:\Users\yonsh\AppData
C:\Users\yonsh\.ssh
C:\Users\yonsh\.aws
C:\Users\yonsh\.gitconfig
C:\Users\yonsh\Desktop
C:\Users\yonsh\Documents
'@

$systemRules = @'
# Vex System Rules

## Identity
You are Vex, a controlled execution agent operating on a dedicated laptop workspace.

## Primary Workspace
You may work only inside:
- C:\Users\yonsh\Vex\workspace
- C:\Users\yonsh\Vex\logs
- C:\Users\yonsh\Vex\memory
- C:\Users\yonsh\Vex\scripts

## Allowed Behavior
- Read and write files only in approved Vex folders
- Run only approved commands
- Log every action before and after execution
- Prefer local tools first
- Ask for escalation before risky actions

## Forbidden Behavior
- Do not access blocked paths
- Do not delete files unless explicitly instructed
- Do not expose secrets, tokens, or credentials
- Do not install software without approval
- Do not modify system settings
- Do not operate outside the approved workspace

## Execution Pattern
For every task:
1. Restate goal
2. Make a short plan
3. Execute one step at a time
4. Verify result
5. Log outcome
6. Report back
'@

$vexTest = @'
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logFile = "C:\Users\yonsh\Vex\logs\vex-test.log"
$outputFile = "C:\Users\yonsh\Vex\workspace\vex-output.txt"

"[$timestamp] Vex test started" | Out-File -FilePath $logFile -Append -Encoding utf8
"Vex is operational inside the approved workspace." | Out-File -FilePath $outputFile -Encoding utf8
"[$timestamp] Wrote test output to workspace" | Out-File -FilePath $logFile -Append -Encoding utf8

Write-Host "Done. Log: $logFile"
Write-Host "Done. Output: $outputFile"
'@

$phase2Check = @'
[ ] allowed-commands.txt created
[ ] blocked-paths.txt created
[ ] system-rules.md created
[ ] vex_test.ps1 created
[ ] vex_test.ps1 runs successfully
[ ] vex-test.log created
[ ] vex-output.txt created
[ ] all files stayed inside Vex folders
'@

Set-Content -Path (Join-Path $base "allowed-commands.txt") -Value $allowedCommands -Encoding UTF8
Set-Content -Path (Join-Path $base "blocked-paths.txt") -Value $blockedPaths -Encoding UTF8
Set-Content -Path (Join-Path $base "system-rules.md") -Value $systemRules -Encoding UTF8
Set-Content -Path (Join-Path $scripts "vex_test.ps1") -Value $vexTest -Encoding UTF8
Set-Content -Path (Join-Path $logs "phase2-check.txt") -Value $phase2Check -Encoding UTF8

Write-Host "Phase 2 files created successfully."

powershell -ExecutionPolicy Bypass -File (Join-Path $scripts "vex_test.ps1")

Write-Host ""
Write-Host "Validation:"
Write-Host "------------------------------"
Get-ChildItem $base -Recurse | Select-Object FullName