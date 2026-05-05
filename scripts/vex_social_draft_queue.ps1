param(
    [string]$Root = "",
    [string]$Stream = "moneycrunch",
    [string]$Platform = "x",
    [int]$Count = 3,
    [switch]$Open
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function Read-FileSafe {
    param([string]$Path)
    if (Test-Path $Path) { return (Get-Content -Path $Path -Raw) }
    return ""
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$Root = [System.IO.Path]::GetFullPath($Root)
$workspace = Join-Path $Root "workspace"
$social = Join-Path $workspace "social"
$approvals = Join-Path $workspace "approvals"
$pending = Join-Path $approvals "pending"
$approved = Join-Path $approvals "approved"
$rejected = Join-Path $approvals "rejected"
$logs = Join-Path $Root "logs"
$memory = Join-Path $Root "memory"
$money = Join-Path $workspace "money"

Ensure-Directory $workspace
Ensure-Directory $social
Ensure-Directory $approvals
Ensure-Directory $pending
Ensure-Directory $approved
Ensure-Directory $rejected
Ensure-Directory $logs

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$today = Get-Date -Format "yyyy-MM-dd"
$calendar = Join-Path $social "social_calendar.csv"
$replyFile = Join-Path $workspace "vex_last_reply.txt"
$logFile = Join-Path $logs "vex_social_draft_queue.log"
$localQwen = Join-Path $Root "scripts\vex_local_qwen.ps1"

if (-not (Test-Path $calendar)) {
    "date_created,stream,platform,draft_id,status,post_text,notes" | Set-Content -Path $calendar -Encoding UTF8
}

$mission = Read-FileSafe (Join-Path $memory "MONEY_MISSION.md")
$rules = Read-FileSafe (Join-Path $memory "MONEY_RULES.md")
$latestIdea = Read-FileSafe (Join-Path $money "daily_money_idea_latest.txt")
$siteStatus = Read-FileSafe (Join-Path $workspace "moneycrunch_site_action.txt")

$streamContext = ""
if ($Stream.ToLowerInvariant() -eq "moneycrunch") {
    $streamContext = "MoneyCrunch is a U.S.-focused debt relief lead-generation site for people exploring options around unsecured debt. Avoid guarantees, fear tactics, legal/financial advice, or unrealistic claims. CTA can be: check options, learn more, or explore options."
}
elseif ($Stream.ToLowerInvariant() -eq "lumasun" -or $Stream.ToLowerInvariant() -eq "lumasunus") {
    $streamContext = "LumaSunUS is a solar audience/lead-generation stream. Focus on electric bills, homeowner education, home upgrades, and curiosity. Avoid guaranteed savings claims."
}
elseif ($Stream.ToLowerInvariant() -eq "vextly") {
    $streamContext = "Vextly is an automation consultancy stream. Focus on AI automation, Excel/Power Automate, small business operations, and practical workflow improvements."
}
else {
    $streamContext = "Create practical, compliant social content for the stream named $Stream."
}

$platformRules = ""
if ($Platform.ToLowerInvariant() -eq "x") {
    $platformRules = "Write short X/Twitter posts. No hashtags unless useful. Make them conversational. Under 260 characters when possible."
}
elseif ($Platform.ToLowerInvariant() -eq "facebook" -or $Platform.ToLowerInvariant() -eq "fb") {
    $platformRules = "Write Facebook posts. Friendly, clear, slightly longer, with one simple question or CTA."
}
elseif ($Platform.ToLowerInvariant() -eq "instagram" -or $Platform.ToLowerInvariant() -eq "insta") {
    $platformRules = "Write Instagram caption drafts. Include a short hook, simple body, and soft CTA. Avoid spammy hashtag blocks."
}
else {
    $platformRules = "Write social post drafts for platform: $Platform."
}

$prompt = @"
You are Vex, Shahied's local money-focused operator.

Mission:
$mission

Rules:
$rules

Latest money idea/context:
$latestIdea

Site/status context:
$siteStatus

Stream context:
$streamContext

Platform rules:
$platformRules

Task:
Create exactly $Count draft social posts for $Stream on $Platform.
Each draft must be compliant, practical, not misleading, and ready for Shahied to approve or reject.

Output format exactly:
DRAFT 1:
<post text>

DRAFT 2:
<post text>

DRAFT 3:
<post text>
"@

$raw = ""
if (Test-Path $localQwen) {
    $escaped = $prompt.Replace('"','`"')
    $raw = powershell -ExecutionPolicy Bypass -File $localQwen -Root $Root -Prompt $escaped 2>&1 | Out-String
}
else {
    $raw = "DRAFT 1:`r`nManual fallback draft for $Stream on $Platform.`r`n`r`nDRAFT 2:`r`nManual fallback draft 2.`r`n`r`nDRAFT 3:`r`nManual fallback draft 3."
}

$text = $raw.Trim()
$drafts = @()
for ($i = 1; $i -le $Count; $i++) {
    $pattern = "(?s)DRAFT\s+$i\s*:\s*(.*?)(?=\r?\n\s*DRAFT\s+" + ($i + 1) + "\s*:|$)"
    $m = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) { $drafts += $m.Groups[1].Value.Trim() }
}

if ($drafts.Count -eq 0) { $drafts += $text }

$created = @()
for ($i = 0; $i -lt $drafts.Count; $i++) {
    $draftNumber = $i + 1
    $draftId = ($today.Replace("-", "") + "_" + $stamp + "_" + $Stream + "_" + $Platform + "_" + $draftNumber).ToLowerInvariant()
    $file = Join-Path $pending ($draftId + ".txt")
    $body = @()
    $body += "DRAFT_ID: $draftId"
    $body += "DATE_CREATED: $today"
    $body += "STREAM: $Stream"
    $body += "PLATFORM: $Platform"
    $body += "STATUS: pending"
    $body += ""
    $body += "POST_TEXT:"
    $body += $drafts[$i]
    Set-Content -Path $file -Value $body -Encoding UTF8
    $created += [pscustomobject]@{ id=$draftId; file=$file; text=$drafts[$i] }

    $row = [pscustomobject]@{
        date_created = $today
        stream = $Stream
        platform = $Platform
        draft_id = $draftId
        status = "pending"
        post_text = $drafts[$i]
        notes = "Generated by Vex social draft queue"
    }
    $row | Export-Csv -Path $calendar -Append -NoTypeInformation -Encoding UTF8
}

$out = @()
$out += "Vex created $($created.Count) social draft(s)."
$out += ""
for ($i = 0; $i -lt $created.Count; $i++) {
    $n = $i + 1
    $out += "DRAFT $n"
    $out += "ID: " + $created[$i].id
    $out += $created[$i].text
    $out += ""
}
$out += "Reply/command: approve 1, reject 1, approve <draft_id>, or reject <draft_id>."

$reply = $out -join "`r`n"
Set-Content -Path $replyFile -Value $reply -Encoding UTF8
Add-Content -Path $logFile -Value ("[" + $stamp + "] Created " + $created.Count + " drafts for " + $Stream + "/" + $Platform) -Encoding UTF8

Write-Host $reply

if ($Open) { notepad $replyFile }
