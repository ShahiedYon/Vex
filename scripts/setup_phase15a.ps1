$ErrorActionPreference = "Stop"

$root = "C:\Users\yonsh\Vex"
$scriptsDir = Join-Path $root "scripts"
$workspaceDir = Join-Path $root "workspace"
$contentDir = Join-Path $workspaceDir "content"
$logsDir = Join-Path $workspaceDir "logs"

$null = New-Item -ItemType Directory -Force -Path $scriptsDir
$null = New-Item -ItemType Directory -Force -Path $workspaceDir
$null = New-Item -ItemType Directory -Force -Path $contentDir
$null = New-Item -ItemType Directory -Force -Path $logsDir

$runner = @'
param(
    [string]$Root = "C:\Users\yonsh\Vex"
)

$ErrorActionPreference = "Stop"

$workspaceDir = Join-Path $Root "workspace"
$contentDir = Join-Path $workspaceDir "content"
$logsDir = Join-Path $workspaceDir "logs"
$logFile = Join-Path $logsDir ("phase15a_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[" + (Get-Date -Format "yyyyMMdd_HHmmss") + "] " + $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

Write-Log "Starting Phase 15a debt relief content generation"

$xPosts = @(
    "If your debt keeps growing even though you are making payments, you are not alone. The first step is understanding your options.",
    "Struggling with monthly payments? A lot of people wait too long before asking for help. Looking at your options early can make a real difference.",
    "Debt stress can affect sleep, focus, and daily life. There may be relief options worth exploring before things get worse.",
    "Feeling buried by credit card balances or loan payments? Start by getting clear on what help may be available.",
    "Not all debt solutions are the same. The right next step starts with understanding your situation clearly."
)

$fbPosts = @(
    "Money stress can build quietly over time. One missed payment becomes two, and suddenly it feels impossible to catch up. The good news is that many people have more options than they think. This page is here to help people understand what debt relief and finance assistance paths may be worth exploring.",
    "If you are feeling pressure from debt, you are not weak and you are not alone. The most important thing is to look at your options early. We share practical information, warning signs to watch for, and ways to connect with trusted debt help options.",
    "A lot of people keep paying the minimum and hope things improve on their own. Sometimes the better move is to step back, assess the full picture, and explore relief options that may reduce pressure and help you move forward.",
    "Debt problems do not always start with bad decisions. Job changes, medical costs, family needs, and rising living expenses can hit hard. We are building a page focused on helpful information and referral pathways for people looking for support."
)

$hooks = @(
    "Behind on payments?",
    "Debt getting harder to manage?",
    "Trying to keep up with bills?",
    "Need a clearer next step?",
    "Feeling pressure from monthly payments?"
)

$ctas = @(
    "Follow for practical debt help content and next-step guidance.",
    "Watch this page for helpful information and trusted referral options.",
    "Start by learning what options may be available.",
    "Get informed before the problem gets worse.",
    "A better plan often starts with one clear next step."
)

$complianceRules = @(
    "Do not claim guaranteed results.",
    "Do not present the brand as a licensed financial advisor.",
    "Use referral and educational wording.",
    "Avoid promising debt removal or approval.",
    "Use calm, non-judgmental language."
)

$offerTracker = @"
partner_name,niche,status,source,notes,next_action
,debt_relief,prospecting,,Prioritize compliant US-focused offers,Research and add 5 candidates
,finance_assistance,prospecting,,Look for lead-gen and referral opportunities,Research and add 5 candidates
,credit_help,prospecting,,Track approval requirements and terms,Research and add 5 candidates
"@

$payload = [ordered]@{
    generated_at = (Get-Date).ToString("s")
    stream = "debt_relief"
    brand_positioning = [ordered]@{
        tone = "calm, trustworthy, non-judgmental"
        positioning = "educational and referral-based"
        audience = @("US consumers seeking debt help", "people under bill pressure", "people looking for finance assistance options")
    }
    x_posts = $xPosts
    facebook_posts = $fbPosts
    hooks = $hooks
    ctas = $ctas
    compliance_rules = $complianceRules
}

$jsonPath = Join-Path $contentDir "debt_relief_content_pack.json"
$xPath = Join-Path $contentDir "debt_relief_posts_x.txt"
$fbPath = Join-Path $contentDir "debt_relief_posts_facebook.txt"
$offerPath = Join-Path $contentDir "debt_relief_offer_tracker.csv"

$payload | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
($xPosts -join [Environment]::NewLine + [Environment]::NewLine) | Set-Content -Path $xPath -Encoding UTF8
($fbPosts -join [Environment]::NewLine + [Environment]::NewLine) | Set-Content -Path $fbPath -Encoding UTF8
Set-Content -Path $offerPath -Value $offerTracker -Encoding UTF8

Write-Log ("Created: " + $jsonPath)
Write-Log ("Created: " + $xPath)
Write-Log ("Created: " + $fbPath)
Write-Log ("Created: " + $offerPath)
Write-Log "Phase 15a complete"
'@

Set-Content -Path (Join-Path $scriptsDir "phase15a_run.ps1") -Value $runner -Encoding UTF8

Write-Host ""
Write-Host "Phase 15a setup complete."
Write-Host "Run with:"
Write-Host "powershell -ExecutionPolicy Bypass -File C:\Users\yonsh\Vex\scripts\phase15a_run.ps1"
