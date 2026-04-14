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
