param(
    [string]$Root = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

$workspaceDir = Join-Path $Root "workspace"
$contentDir = Join-Path $workspaceDir "content"
$logsDir = Join-Path $workspaceDir "logs"
$logFile = Join-Path $logsDir ("phase15b_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

Write-Log "Starting Phase 15b solar content generation"

$xPosts = @(
    "Electricity prices do not usually move in your favor. A home solar setup can be one way to take back control over monthly power costs.",
    "A lot of homeowners think solar is only for high-income households. In reality, the real question is whether your monthly bill is already costing you too much.",
    "If your power bill keeps climbing, it may be time to compare what you are paying now versus what solar could look like over time.",
    "Solar is not only about going green. For many families, it starts with wanting more predictable energy costs.",
    "One of the smartest home-upgrade questions right now is simple: how much are you spending on electricity every month?"
)

$fbPosts = @(
    "Most people do not wake up one day suddenly excited about solar panels. It usually starts when the electricity bill keeps rising and there is no clear relief in sight. That is why we are building content focused on helping homeowners understand whether solar could make financial sense for them.",
    "Solar is often framed as a big luxury purchase, but for many households it is really about long-term savings, more predictable bills, and investing in the value of the home. We are building this page to help people explore those options more clearly.",
    "If you are already paying a high electricity bill every month, it may be worth comparing that cost against the long-term picture of solar. Even before making a decision, understanding the numbers can be a smart move.",
    "Many homeowners want upgrades that improve both quality of life and property value. Solar is one of the few conversations where monthly savings, energy resilience, and home appeal can all come together."
)

$hooks = @(
    "Power bill too high?",
    "Thinking about solar?",
    "What is your monthly electricity bill?",
    "Could solar save you money?",
    "Still renting your power from the grid?"
)

$ctas = @(
    "Follow for solar savings content and homeowner tips.",
    "Learn what to compare before choosing solar.",
    "See whether solar could make sense for your home.",
    "Start by understanding your current power costs.",
    "Watch this page for practical solar insights."
)

$positioningRules = @(
    "Focus on homeowner savings and education.",
    "Avoid unrealistic savings claims.",
    "Do not promise approval or exact bill reduction.",
    "Use simple non-technical wording.",
    "Keep LumaSunUS positioned as a connector and information brand."
)

$offerTracker = @"
partner_name,niche,status,source,notes,next_action
,solar_affiliate,prospecting,,Prioritize US homeowner-focused offers,Research and add 5 candidates
,solar_referral,prospecting,,Track approval requirements and payout style,Research and add 5 candidates
,home_energy,prospecting,,Look for savings and home-upgrade aligned offers,Research and add 5 candidates
"@

$payload = [ordered]@{
    generated_at = (Get-Date).ToString("s")
    stream = "solar"
    brand = "LumaSunUS"
    brand_positioning = [ordered]@{
        tone = "clear, trustworthy, homeowner-focused"
        positioning = "educational and referral-based"
        audience = @("US homeowners", "high electricity bill households", "people interested in home upgrades")
    }
    x_posts = $xPosts
    facebook_posts = $fbPosts
    hooks = $hooks
    ctas = $ctas
    positioning_rules = $positioningRules
}

$jsonPath = Join-Path $contentDir "solar_content_pack.json"
$xPath = Join-Path $contentDir "solar_posts_x.txt"
$fbPath = Join-Path $contentDir "solar_posts_facebook.txt"
$offerPath = Join-Path $contentDir "solar_offer_tracker.csv"

$payload | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
($xPosts -join [Environment]::NewLine + [Environment]::NewLine) | Set-Content -Path $xPath -Encoding UTF8
($fbPosts -join [Environment]::NewLine + [Environment]::NewLine) | Set-Content -Path $fbPath -Encoding UTF8
Set-Content -Path $offerPath -Value $offerTracker -Encoding UTF8

Write-Log ("Created: " + $jsonPath)
Write-Log ("Created: " + $xPath)
Write-Log ("Created: " + $fbPath)
Write-Log ("Created: " + $offerPath)
Write-Log "Phase 15b complete"
