<#
.SYNOPSIS
    Bootstrap a project with this pack's `-warden` subagents, governing docs,
    and the <KEY>-<n> ticket commit hook.

.DESCRIPTION
    Run from the ROOT of the target project (or pass -TargetRoot). The script:
      1. Scaffolds any MISSING governing doc (CLAUDE.md, SPEC.md, BUG.md,
         README.md) from the bundled templates. Existing docs are never touched.
      2. Copies the bundled agents into <target>/.claude/agents/.
      3. Injects (or refreshes) the "Agent-driven development" section in
         CLAUDE.md, between <!-- BEGIN agent-pack --> / <!-- END agent-pack -->
         markers, so re-running is idempotent.
      4. Installs the .githooks/commit-msg backstop and points git at it
         (core.hooksPath), unless -NoHooks is given or the target is not a git repo.

    The goal: run this once in a new project and it is ready to work in.

.PARAMETER TargetRoot
    Project root to install into. Defaults to the current directory.

.PARAMETER Force
    Overwrite agent files that already exist in the target (default: skip them).
    Governing docs are never overwritten regardless of this flag.

.PARAMETER NoHooks
    Skip installing the commit-msg hook and setting core.hooksPath.

.PARAMETER New
    Brand-new project: git-init the target first if it is not already a repo, so
    the hook step enables core.hooksPath automatically. No-op on an existing repo.

.PARAMETER Prefix
    Ticket key for the target, e.g. ACME for ACME-<n> commits. If omitted, the
    key already installed in the target is kept (hook, then CLAUDE.md); otherwise
    it is derived from the target folder name (my-shop-api -> MSA, billing -> BIL).

.EXAMPLE
    ./install-agents.ps1
.EXAMPLE
    ./install-agents.ps1 -Prefix ACME
.EXAMPLE
    ./install-agents.ps1 -New -TargetRoot C:\code\my-new-project
.EXAMPLE
    ./install-agents.ps1 -TargetRoot C:\code\my-project -Force
.EXAMPLE
    ./install-agents.ps1 -NoHooks
#>
[CmdletBinding()]
param(
    [string]$TargetRoot = (Get-Location).Path,
    [switch]$Force,
    [switch]$NoHooks,
    [switch]$New,
    [string]$Prefix = ''
)

$ErrorActionPreference = 'Stop'

# A ticket key is a letter followed by up to 9 letters/digits; accept a trailing
# dash ("SR-") and lowercase, and normalize both away.
if ($Prefix) {
    $Prefix = $Prefix.TrimEnd('-').ToUpperInvariant()
    if ($Prefix -cnotmatch '^[A-Z][A-Z0-9]{0,9}$') {
        Write-Host "ERROR: invalid -Prefix '$Prefix' (want a letter then up to 9 letters/digits, e.g. ACME)" -ForegroundColor Red
        exit 1
    }
}

# Read payload/target text as UTF-8. Get-Content -Raw in Windows PowerShell 5.1
# decodes BOM-less files as ANSI, which turned every em dash into mojibake.
function Read-Utf8([string]$Path) { [System.IO.File]::ReadAllText($Path) }

# Key recorded in an existing hook: the TICKET_PREFIX line, or, for a v1.0 hook
# that predates it, the literal key baked into the grep pattern.
function Get-InstalledHookPrefix([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $text = Read-Utf8 $Path
    $m = [regex]::Match($text, "(?m)^TICKET_PREFIX='([A-Z][A-Z0-9]*)'")
    if (-not $m.Success) { $m = [regex]::Match($text, "'\^([A-Z][A-Z0-9]*)-\[0-9\]\+") }
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

# Key named in an existing agent-pack block ("tickets are `KEY-<n>`").
function Get-InstalledClaudePrefix([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $m = [regex]::Match((Read-Utf8 $Path), '[Tt]ickets are `([A-Z][A-Z0-9]*)-<n>`')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

# Initials of a multi-word folder name (max 4), else its first 3 characters.
function Get-DerivedPrefix([string]$Path) {
    $words = @([regex]::Split((Split-Path -Leaf $Path), '[^A-Za-z0-9]+') | Where-Object { $_ })
    if ($words.Count -ge 2) {
        $p = -join ($words | ForEach-Object { $_.Substring(0, 1) })
        if ($p.Length -gt 4) { $p = $p.Substring(0, 4) }
    } elseif ($words.Count -eq 1) {
        $p = $words[0].Substring(0, [Math]::Min(3, $words[0].Length))
    } else {
        $p = ''
    }
    $p = $p.ToUpperInvariant()
    if ($p -cnotmatch '^[A-Z]') { $p = 'TKT' }
    return $p
}

# Probe whether a path is inside a git work tree. On a non-repo, git writes to
# stderr, which under $ErrorActionPreference='Stop' would surface as a terminating
# NativeCommandError in Windows PowerShell 5.1 - even with a redirect. The
# try/catch swallows that so a non-git target is simply reported as "not a repo"
# (mirrors the bash probe's `>/dev/null 2>&1`).
function Test-IsGitRepo([string]$Path) {
    try { git -C $Path rev-parse --is-inside-work-tree 2>$null | Out-Null } catch { return $false }
    return ($LASTEXITCODE -eq 0)
}

# Resolve the pack payload relative to THIS script, so it works from anywhere.
$PackDir       = $PSScriptRoot
$PayloadAgents = Join-Path $PackDir 'payload/agents'
$SectionFile   = Join-Path $PackDir 'payload/claude-md-section.md'
$TemplatesDir  = Join-Path $PackDir 'payload/templates'
$HookSrc       = Join-Path $PackDir 'payload/hooks/commit-msg'

if (-not (Test-Path -LiteralPath $PayloadAgents)) {
    Write-Host "ERROR: bundled payload not found at $PayloadAgents" -ForegroundColor Red
    Write-Host "       Run this script from inside an intact agent-pack folder." -ForegroundColor Red
    exit 1
}

Write-Host "Installing agent pack into: $TargetRoot" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
$TargetRoot = (Resolve-Path -LiteralPath $TargetRoot).Path

# --- ticket key: flag > key already installed > derived from folder name ---
if ($Prefix) {
    $PrefixFrom = '-Prefix'
} else {
    $Prefix = Get-InstalledHookPrefix (Join-Path $TargetRoot '.githooks/commit-msg'); $PrefixFrom = 'existing hook'
    if (-not $Prefix) { $Prefix = Get-InstalledClaudePrefix (Join-Path $TargetRoot 'CLAUDE.md'); $PrefixFrom = 'existing CLAUDE.md' }
    if (-not $Prefix) { $Prefix = Get-DerivedPrefix $TargetRoot; $PrefixFrom = 'folder name; override with -Prefix' }
}
Write-Host "  ticket key: $Prefix ($PrefixFrom)" -ForegroundColor Cyan

# Payload text with the ticket key placeholder filled in.
function Get-FilledPayload([string]$Path) { (Read-Utf8 $Path).Replace('__TICKET_PREFIX__', $Prefix) }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# --- 0. -New: initialize a git repo if the target isn't one yet ------------
# Opt-in for brand-new projects: this makes the target a repo up front, so the
# hook step below (step 4) detects it and enables core.hooksPath automatically,
# leaving the <KEY>-<n> workflow live in one command. No-op on an existing repo.
if ($New) {
    if (Test-IsGitRepo $TargetRoot) {
        Write-Host "  git: already a repo (skipping init)" -ForegroundColor Yellow
    } else {
        & git -C $TargetRoot init -q
        Write-Host "  git: initialized empty repo" -ForegroundColor Green
    }
}

# --- 1. Scaffold missing governing docs (never overwrite an existing one) --
# CLAUDE.md must exist before the injection step below, so scaffold it here.
foreach ($doc in @('CLAUDE.md', 'SPEC.md', 'BUG.md', 'README.md')) {
    $dest = Join-Path $TargetRoot $doc
    $src  = Join-Path $TemplatesDir $doc
    if (Test-Path -LiteralPath $dest) {
        Write-Host "  keep (exists): $doc" -ForegroundColor Yellow
    } elseif (Test-Path -LiteralPath $src) {
        [System.IO.File]::WriteAllText($dest, (Get-FilledPayload $src), $utf8NoBom)
        Write-Host "  scaffolded:    $doc" -ForegroundColor Green
    }
}

$ClaudeMd = Join-Path $TargetRoot 'CLAUDE.md'

# --- 2. Copy agents --------------------------------------------------------
$AgentsDest = Join-Path $TargetRoot '.claude/agents'
New-Item -ItemType Directory -Force -Path $AgentsDest | Out-Null

foreach ($item in Get-ChildItem -LiteralPath $PayloadAgents) {
    $dest = Join-Path $AgentsDest $item.Name
    if ((Test-Path -LiteralPath $dest) -and -not $Force) {
        Write-Host "  skip (exists): $($item.Name)   [use -Force to overwrite]" -ForegroundColor Yellow
        continue
    }
    Copy-Item -LiteralPath $item.FullName -Destination $AgentsDest -Recurse -Force
    Write-Host "  installed: $($item.Name)" -ForegroundColor Green
}

# --- 3. Inject / refresh the CLAUDE.md section -----------------------------
$content = Read-Utf8 $ClaudeMd
$section = (Get-FilledPayload $SectionFile).TrimEnd()
$block   = "<!-- BEGIN agent-pack -->`n$section`n<!-- END agent-pack -->"

$pattern = '(?s)<!-- BEGIN agent-pack -->.*?<!-- END agent-pack -->'
if ([regex]::IsMatch($content, $pattern)) {
    # Use a MatchEvaluator so `$` inside the block is never treated as a
    # regex-replacement backreference.
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $block }
    # NOTE: not named $new - that collides (PowerShell is case-insensitive) with
    # the [switch]$New parameter and would try to coerce this string into it.
    $updatedClaude = [regex]::Replace($content, $pattern, $evaluator)
    Write-Host "  CLAUDE.md: refreshed existing agent-pack section" -ForegroundColor Green
} else {
    $updatedClaude = $content.TrimEnd() + "`n`n" + $block + "`n"
    Write-Host "  CLAUDE.md: appended agent-pack section" -ForegroundColor Green
}

# Write UTF-8 with NO BOM so the file stays clean in editors and git.
[System.IO.File]::WriteAllText($ClaudeMd, $updatedClaude, (New-Object System.Text.UTF8Encoding($false)))

# --- 4. Install the commit-msg hook ----------------------------------------
if ($NoHooks) {
    Write-Host "  hooks: skipped (-NoHooks)" -ForegroundColor Yellow
} elseif (-not (Test-Path -LiteralPath $HookSrc)) {
    Write-Host "  hooks: skipped (bundled hook not found at $HookSrc)" -ForegroundColor Yellow
} else {
    $HooksDest = Join-Path $TargetRoot '.githooks'
    New-Item -ItemType Directory -Force -Path $HooksDest | Out-Null
    # Write with LF line endings and no BOM - it runs under git's sh, not PowerShell.
    $hookText = (Get-FilledPayload $HookSrc) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText((Join-Path $HooksDest 'commit-msg'), $hookText, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  installed: .githooks/commit-msg" -ForegroundColor Green
    # Force LF on everything under .githooks so a clone/checkout under
    # autocrlf=true can't rewrite the hook to CRLF (which breaks it under sh).
    # Ensure the rule exists without clobbering an existing .gitattributes.
    $Ga = Join-Path $TargetRoot '.gitattributes'
    $GaRule = '.githooks/** text eol=lf'
    if (-not (Test-Path -LiteralPath $Ga)) {
        [System.IO.File]::WriteAllText($Ga, "$GaRule`n", $utf8NoBom)
        Write-Host "  created: .gitattributes ($GaRule)" -ForegroundColor Green
    } else {
        $gaContent = Get-Content -LiteralPath $Ga -Raw
        if ($gaContent -notmatch [regex]::Escape($GaRule)) {
            # Add a trailing newline first if the file doesn't end with one.
            $prefix = if ($gaContent.Length -gt 0 -and $gaContent[-1] -ne "`n") { "`n" } else { "" }
            [System.IO.File]::AppendAllText($Ga, "$prefix$GaRule`n", $utf8NoBom)
            Write-Host "  updated: .gitattributes (+ $GaRule)" -ForegroundColor Green
        } else {
            Write-Host "  .gitattributes: LF rule already present" -ForegroundColor Yellow
        }
    }
    # Point git at .githooks - but only if the target is actually a git repo.
    if (Test-IsGitRepo $TargetRoot) {
        & git -C $TargetRoot config core.hooksPath .githooks
        Write-Host "  git: core.hooksPath = .githooks" -ForegroundColor Green
    } else {
        Write-Host "  git: target is not a git repo - hook copied but not enabled." -ForegroundColor Yellow
        Write-Host "       After 'git init', run: git config core.hooksPath .githooks" -ForegroundColor Yellow
    }
}

Write-Host "Done." -ForegroundColor Cyan
exit 0
