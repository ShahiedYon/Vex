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

function Save-Json {
    param(
        [string]$Path,
        [object]$Data
    )
    $json = $Data | ConvertTo-Json -Depth 30
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function Invoke-DsApi {
    param(
        [string]$FunctionName,
        [hashtable]$Params,
        [hashtable]$Headers
    )

    $uri = "https://www.digistore24.com/api/call/$FunctionName"

    try {
        if ($null -eq $Params) {
            $Params = @{}
        }

        $response = Invoke-RestMethod -Uri $uri -Headers $Headers -Method Post -Body $Params
        return @{
            ok       = $true
            function = $FunctionName
            response = $response
            error    = $null
        }
    }
    catch {
        $detail = $_.Exception.Message
        $raw = $null

        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $raw = $_.ErrorDetails.Message
        }

        return @{
            ok       = $false
            function = $FunctionName
            response = $null
            error    = $detail
            raw      = $raw
        }
    }
}

$ApiKey = [System.Environment]::GetEnvironmentVariable("DIGISTORE24_API_KEY", "User")
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "DIGISTORE24_API_KEY is not set in User environment variables."
}

$DataPath       = Join-Path $BasePath "data\digistore24"
$RawPath        = Join-Path $DataPath "raw"
$DiscoveryPath  = Join-Path $DataPath "discovery"
$LogPath        = Join-Path $BasePath "logs"

Ensure-Folder -Path $DataPath
Ensure-Folder -Path $RawPath
Ensure-Folder -Path $DiscoveryPath
Ensure-Folder -Path $LogPath

$RunStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile  = Join-Path $LogPath "digistore24_discovery.log"
$OutFile  = Join-Path $DiscoveryPath "discovery_$RunStamp.json"
$CsvFile  = Join-Path $DiscoveryPath "discovery_$RunStamp.csv"

$Headers = @{
    "X-DS-API-KEY" = $ApiKey
    "Accept"       = "application/json"
    "Content-Type" = "application/x-www-form-urlencoded"
}

# Candidate functions for discovery.
# Keep this list small and practical for phase 2.
$Tests = @(
    @{ Name = "getUserInfo";             Params = @{} },
    @{ Name = "listMarketplaceEntries";  Params = @{} },
    @{ Name = "listProductTypes";        Params = @{} },
    @{ Name = "listProducts";            Params = @{} },
    @{ Name = "listOrders";              Params = @{} }
)

$Results = @()

Write-Log -LogFile $LogFile -Message "Starting Digistore24 phase 2 discovery."

foreach ($test in $Tests) {
    $fn = [string]$test.Name
    $pr = $test.Params

    Write-Log -LogFile $LogFile -Message "Testing function: $fn"

    $result = Invoke-DsApi -FunctionName $fn -Params $pr -Headers $Headers

    $row = [PSCustomObject]@{
        timestamp      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        function       = $fn
        ok             = $result.ok
        api_result     = $null
        has_data       = $false
        data_type      = $null
        item_count     = $null
        error          = $null
        raw_error_body = $null
    }

    if ($result.ok) {
        $resp = $result.response

        if ($null -ne $resp.result) {
            $row.api_result = [string]$resp.result
        }

        if ($null -ne $resp.data) {
            $row.has_data = $true
            $row.data_type = $resp.data.GetType().FullName

            if ($resp.data -is [System.Array]) {
                $row.item_count = $resp.data.Count
            }
            elseif ($resp.data -is [System.Collections.IEnumerable] -and -not ($resp.data -is [string])) {
                try {
                    $tmpCount = @($resp.data).Count
                    $row.item_count = $tmpCount
                }
                catch {
                    $row.item_count = $null
                }
            }
        }

        $rawFile = Join-Path $RawPath ("{0}_{1}.json" -f $fn, $RunStamp)
        Save-Json -Path $rawFile -Data $resp
        Write-Log -LogFile $LogFile -Message "SUCCESS: $fn -> $rawFile"
    }
    else {
        $row.error = $result.error
        $row.raw_error_body = $result.raw
        Write-Log -LogFile $LogFile -Message "ERROR: $fn -> $($result.error)"
        if ($result.raw) {
            Write-Log -LogFile $LogFile -Message "RAW: $($result.raw)"
        }
    }

    $Results += $row
}

Save-Json -Path $OutFile -Data $Results
$Results | Export-Csv -LiteralPath $CsvFile -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Digistore24 Phase 2 Discovery Complete"
Write-Host "Summary JSON: $OutFile"
Write-Host "Summary CSV : $CsvFile"
Write-Host ""

$Results | Format-Table -AutoSize function, ok, api_result, has_data, item_count, error