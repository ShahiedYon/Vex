param(
    [string]$TaskFile
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Path, [string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $Path -Value "[$ts] $Message" -Encoding UTF8
}

function Parse-TaskFile {
    param([string]$Path)
    $map = @{}
    $lines = Get-Content -Path $Path
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $idx = $line.IndexOf(":")
        if ($idx -lt 0) { continue }
        $key = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $map[$key] = $value
        }
    }
    return $map
}

if ([string]::IsNullOrWhiteSpace($TaskFile)) {
    Write-Host "Error: provide -TaskFile"
    exit 1
}

if (-not (Test-Path $TaskFile)) {
    Write-Host "Error: task file not found"
    exit 1
}

$routerLog = "C:\Users\yonsh\Vex\logs\phase8-router.log"
$task = Parse-TaskFile -Path $TaskFile

$taskName = $task["TASK_NAME"]
$taskType = $task["TASK_TYPE"]
$target = $task["TARGET"]
$outputText = $task["OUTPUT_TEXT"]
$outputLog = $task["OUTPUT_LOG"]

Write-Log -Path $routerLog -Message "TASK RECEIVED: $taskName"
Write-Log -Path $routerLog -Message "TASK TYPE: $taskType"
Write-Log -Path $routerLog -Message "TARGET: $target"

switch ($taskType) {
    "browser.inspect" {
        $runner = "C:\Users\yonsh\Vex\browser\phase8_browser_task.js"
        Write-Log -Path $routerLog -Message "ROUTE SELECTED: browser.inspect"
        node $runner $TaskFile
    }
    "python.run" {
        Write-Log -Path $routerLog -Message "ROUTE SELECTED: python.run"
        python $target
    }
    "node.run" {
        Write-Log -Path $routerLog -Message "ROUTE SELECTED: node.run"
        node $target
    }
    "file.write_report" {
        Write-Log -Path $routerLog -Message "ROUTE SELECTED: file.write_report"
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $lines = @()
        $lines += "Vex Phase 8 Report"
        $lines += "Timestamp: $ts"
        $lines += "Task Name: $taskName"
        $lines += "Status: SUCCESS"
        $lines += "Message: $target"
        Set-Content -Path $outputText -Value $lines -Encoding UTF8
        Add-Content -Path $outputLog -Value "[$ts] Report written successfully" -Encoding UTF8
    }
    default {
        Write-Log -Path $routerLog -Message "UNKNOWN TASK TYPE: $taskType"
        Write-Host "Unknown TASK_TYPE: $taskType"
        exit 1
    }
}

$verified = $false
if (-not [string]::IsNullOrWhiteSpace($outputText)) {
    if (Test-Path $outputText) {
        $verified = $true
    }
}

if ($verified) {
    Write-Log -Path $routerLog -Message "VERIFICATION PASSED: $outputText"
    Write-Host "Task completed successfully."
    Write-Host "Output: $outputText"
}
else {
    Write-Log -Path $routerLog -Message "VERIFICATION FAILED"
    Write-Host "Task failed verification."
    exit 1
}