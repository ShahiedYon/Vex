param(
    [string]$Root = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

$workspaceDir = Join-Path $Root "workspace"
$campaignsDir = Join-Path $workspaceDir "campaigns"
$logsDir = Join-Path $workspaceDir "logs"
$logFile = Join-Path $logsDir ("phase16f_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Get-NonEmptyLines {
    param([string]$Path)
    $lines = Get-Content -Path $Path
    $out = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $out += $line.Trim()
        }
    }
    return $out
}

function Get-PostBodyLines {
    param([object[]]$Lines)

    $out = @()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = [string]$Lines[$i]
        if ($line -match '^\[\d+\]\s+') {
            $clean = $line -replace '^\[\d+\]\s+', ''
            $out += $clean.Trim()
        }
    }
    return $out
}

function New-XVariations {
    param([string]$Text)

    $v1 = $Text
    $v2 = "A lot of people ignore this too long: " + $Text
    $v3 = $Text + " Start by looking at the numbers clearly."

    return @($v1, $v2, $v3)
}

function New-FacebookVariations {
    param([string]$Text)

    $v1 = $Text
    $v2 = "A practical way to think about this: " + $Text

    return @($v1, $v2)
}

Write-Log "Starting Phase 16f post variation engine"

$debtWeekPath = Join-Path $campaignsDir "debt_week1_posts.txt"
$solarWeekPath = Join-Path $campaignsDir "solar_week1_posts.txt"

if (-not (Test-Path $debtWeekPath)) { throw "Missing file: $debtWeekPath" }
if (-not (Test-Path $solarWeekPath)) { throw "Missing file: $solarWeekPath" }

$debtLines = Get-NonEmptyLines -Path $debtWeekPath
$solarLines = Get-NonEmptyLines -Path $solarWeekPath

$debtBodies = Get-PostBodyLines -Lines $debtLines
$solarBodies = Get-PostBodyLines -Lines $solarLines

$debtOut = @()
$solarOut = @()
$queue = @()

$debtOut += "DEBT POST VARIATIONS"
$debtOut += "===================="
$debtOut += ""

$solarOut += "SOLAR POST VARIATIONS"
$solarOut += "====================="
$solarOut += ""

$debtXCount = 0
$debtFBCount = 0
$solarXCount = 0
$solarFBCount = 0

for ($i = 0; $i -lt $debtBodies.Count; $i++) {
    $text = [string]$debtBodies[$i]

    if ($debtXCount -lt 3) {
        $vars = New-XVariations -Text $text
        $debtOut += ("DEBT X POST " + ($debtXCount + 1))
        $debtOut += "---------------"
        for ($j = 0; $j -lt $vars.Count; $j++) {
            $debtOut += ("V" + ($j + 1) + ": " + $vars[$j])
            $queue += [pscustomobject]@{
                stream = "debt_relief"
                platform = "X"
                base_post = ("Debt X Post " + ($debtXCount + 1))
                variation = ("V" + ($j + 1))
                content = $vars[$j]
            }
        }
        $debtOut += ""
        $debtXCount++
        continue
    }

    if ($debtFBCount -lt 2) {
        $vars = New-FacebookVariations -Text $text
        $debtOut += ("DEBT FACEBOOK POST " + ($debtFBCount + 1))
        $debtOut += "----------------------"
        for ($k = 0; $k -lt $vars.Count; $k++) {
            $debtOut += ("V" + ($k + 1) + ": " + $vars[$k])
            $queue += [pscustomobject]@{
                stream = "debt_relief"
                platform = "Facebook"
                base_post = ("Debt Facebook Post " + ($debtFBCount + 1))
                variation = ("V" + ($k + 1))
                content = $vars[$k]
            }
        }
        $debtOut += ""
        $debtFBCount++
    }
}

for ($m = 0; $m -lt $solarBodies.Count; $m++) {
    $text = [string]$solarBodies[$m]

    if ($solarXCount -lt 3) {
        $vars = New-XVariations -Text $text
        $solarOut += ("SOLAR X POST " + ($solarXCount + 1))
        $solarOut += "----------------"
        for ($n = 0; $n -lt $vars.Count; $n++) {
            $solarOut += ("V" + ($n + 1) + ": " + $vars[$n])
            $queue += [pscustomobject]@{
                stream = "solar"
                platform = "X"
                base_post = ("Solar X Post " + ($solarXCount + 1))
                variation = ("V" + ($n + 1))
                content = $vars[$n]
            }
        }
        $solarOut += ""
        $solarXCount++
        continue
    }

    if ($solarFBCount -lt 2) {
        $vars = New-FacebookVariations -Text $text
        $solarOut += ("SOLAR FACEBOOK POST " + ($solarFBCount + 1))
        $solarOut += "-----------------------"
        for ($p = 0; $p -lt $vars.Count; $p++) {
            $solarOut += ("V" + ($p + 1) + ": " + $vars[$p])
            $queue += [pscustomobject]@{
                stream = "solar"
                platform = "Facebook"
                base_post = ("Solar Facebook Post " + ($solarFBCount + 1))
                variation = ("V" + ($p + 1))
                content = $vars[$p]
            }
        }
        $solarOut += ""
        $solarFBCount++
    }
}

$debtVarPath = Join-Path $campaignsDir "debt_post_variations.txt"
$solarVarPath = Join-Path $campaignsDir "solar_post_variations.txt"
$queuePath = Join-Path $campaignsDir "posting_variation_queue.csv"

Set-Content -Path $debtVarPath -Value $debtOut -Encoding UTF8
Set-Content -Path $solarVarPath -Value $solarOut -Encoding UTF8
$queue | Export-Csv -Path $queuePath -NoTypeInformation -Encoding UTF8

Write-Log ("Created: " + $debtVarPath)
Write-Log ("Created: " + $solarVarPath)
Write-Log ("Created: " + $queuePath)
Write-Log "Phase 16f complete"
