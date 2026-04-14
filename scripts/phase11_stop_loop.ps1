$ErrorActionPreference = "Stop"

$flagFile = "C:\Users\yonsh\Vex\phase11-loop.enabled"

if (Test-Path $flagFile) {
    Remove-Item $flagFile -Force
    Write-Host "Vex loop stop flag removed. Current loop will exit after its sleep cycle."
}
else {
    Write-Host "Flag file already absent."
}