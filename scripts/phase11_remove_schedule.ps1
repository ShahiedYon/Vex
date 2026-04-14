$ErrorActionPreference = "Stop"

$taskName = "VexQueueRunner"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($null -ne $task) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Scheduled task removed: $taskName"
}
else {
    Write-Host "Scheduled task not found: $taskName"
}