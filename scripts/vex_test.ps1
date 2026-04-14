$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logFile = "C:\Users\yonsh\Vex\logs\vex-test.log"
$outputFile = "C:\Users\yonsh\Vex\workspace\vex-output.txt"

"[$timestamp] Vex test started" | Out-File -FilePath $logFile -Append -Encoding utf8
"Vex is operational inside the approved workspace." | Out-File -FilePath $outputFile -Encoding utf8
"[$timestamp] Wrote test output to workspace" | Out-File -FilePath $logFile -Append -Encoding utf8

Write-Host "Done. Log: $logFile"
Write-Host "Done. Output: $outputFile"
