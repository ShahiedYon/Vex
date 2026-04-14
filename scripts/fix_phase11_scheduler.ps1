$taskName = "VexQueueRunner"
$scriptPath = "C:\Users\yonsh\Vex\scripts\phase11_run_queue.ps1"

# Remove old task
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Create action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

# Create trigger (every 5 minutes)
$trigger = New-ScheduledTaskTrigger -Daily -At (Get-Date).AddMinutes(1)
$trigger.RepetitionInterval = (New-TimeSpan -Minutes 5)
$trigger.RepetitionDuration = (New-TimeSpan -Days 3650)

# CRITICAL: run with proper permissions
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Vex Queue Runner (Fixed)"

Write-Host "Scheduler FIXED. Waiting for next run..."