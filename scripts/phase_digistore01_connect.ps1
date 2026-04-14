param(
    [string]$BasePath = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

function Ensure-Folder {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Write-Log {
    param(
        [string]$LogFile,
        [string]$Message
    )
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $LogFile -Value "[$stamp] $Message"
}

$ApiKey = [System.Environment]::GetEnvironmentVariable("DIGISTORE24_API_KEY", "User")
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "DIGISTORE24_API_KEY is not set in User environment variables."
}

$DataPath = Join-Path $BasePath "data\digistore24"
$RawPath  = Join-Path $DataPath "raw"
$LogPath  = Join-Path $BasePath "logs"

Ensure-Folder -Path $DataPath
Ensure-Folder -Path $RawPath
Ensure-Folder -Path $LogPath

$RunStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogPath "digistore24_connector.log"
$RawFile = Join-Path $RawPath "getUserInfo_$RunStamp.json"

$Headers = @{
    "X-DS-API-KEY" = $ApiKey
    "Accept"       = "application/json"
    "Content-Type" = "application/x-www-form-urlencoded"
}

$Url = "https://www.digistore24.com/api/call/getUserInfo"

try {
    Write-Log -LogFile $LogFile -Message "Starting Digistore24 connector run."

    $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method Post -Body ""

    $ResponseJson = $Response | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $RawFile -Value $ResponseJson -Encoding UTF8

    Write-Log -LogFile $LogFile -Message "SUCCESS: Saved response to $RawFile"

    Write-Host ""
    Write-Host "Digistore24 connection successful."
    Write-Host "Raw file: $RawFile"
    Write-Host "User: $($Response.data.user_name)"
    Write-Host "Roles: $($Response.data.granted_roles_msg)"
    Write-Host "Permissions: $($Response.data.api_key_permissions)"
}
catch {
    Write-Log -LogFile $LogFile -Message "ERROR: $($_.Exception.Message)"
    Write-Host "Digistore24 connection failed."
    Write-Host $_.Exception.Message
    exit 1
}