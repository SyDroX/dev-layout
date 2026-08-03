#Requires -Version 5.1
<#
.SYNOPSIS
    Installs DevLayout hooks into Claude Code settings.
.DESCRIPTION
    1. Copies devlayout-session-save.ps1 to ~/.claude/hooks/ and registers
       a SessionStart hook in ~/.claude/settings.json
    2. Copies block-bare-cd.sh to each workspace's .claude/hooks/ and registers
       PreToolUse hooks in each workspace's .claude/settings.local.json

    Session hook: captures active session ID on start and /resume so DevLayout
    can restore conversations across relaunches.

    CD-blocking hook: prevents Claude from using cd/chdir/Set-Location, forcing
    absolute paths and git -C for multi-repo orchestration.
.NOTES
    Run once after cloning. Re-run after updating hook scripts.
    Workspace directories are read from $Config in DevLayout.ps1.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ============================================================================
# 1. SESSION RESUME HOOK (global — ~/.claude/)
# ============================================================================

$SessionHookSource = Join-Path $ScriptDir "hooks\devlayout-session-save.ps1"
$SessionHookDest = Join-Path $env:USERPROFILE ".claude\hooks\devlayout-session-save.ps1"
$GlobalSettings = Join-Path $env:USERPROFILE ".claude\settings.json"

if (-not (Test-Path $SessionHookSource)) {
    Write-Error "Hook script not found: $SessionHookSource"
    exit 1
}

$hooksDir = Join-Path $env:USERPROFILE ".claude\hooks"
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
}
Copy-Item $SessionHookSource $SessionHookDest -Force
Write-Host "Session hook installed: $SessionHookDest" -ForegroundColor Green

$hookCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $($SessionHookDest -replace '\\','/')"

if (-not (Test-Path $GlobalSettings)) {
    $settings = @{}
} else {
    $settings = Get-Content $GlobalSettings -Raw | ConvertFrom-Json -AsHashtable
}

if (-not $settings.ContainsKey('hooks')) {
    $settings['hooks'] = @{}
}

$hookEntry = @{
    hooks = @(
        @{
            type    = "command"
            command = $hookCommand
            timeout = 5
        }
    )
}

if (-not $settings['hooks'].ContainsKey('SessionStart')) {
    $settings['hooks']['SessionStart'] = @($hookEntry)
    Write-Host "  SessionStart hook registered in settings.json" -ForegroundColor Green
} else {
    $existing = $settings['hooks']['SessionStart']
    $alreadyRegistered = $false
    foreach ($entry in $existing) {
        foreach ($h in $entry.hooks) {
            if ($h.command -and $h.command -like '*devlayout-session-save*') {
                $alreadyRegistered = $true
                break
            }
        }
        if ($alreadyRegistered) { break }
    }

    if ($alreadyRegistered) {
        Write-Host "  SessionStart hook already registered, skipping" -ForegroundColor Yellow
    } else {
        $settings['hooks']['SessionStart'] = @($existing) + @($hookEntry)
        Write-Host "  SessionStart hook added to settings.json" -ForegroundColor Green
    }
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $GlobalSettings -Encoding UTF8

# ============================================================================
# 2. CD-BLOCKING HOOK (per workspace — <workspace>/.claude/)
# ============================================================================

$CdHookSource = Join-Path $ScriptDir "hooks\block-bare-cd.sh"

if (-not (Test-Path $CdHookSource)) {
    Write-Error "Hook script not found: $CdHookSource"
    exit 1
}

# Read workspace directories from DevLayout.ps1 config
# Default to common layout if DevLayout.ps1 can't be parsed
$workspaces = @(
    "$env:USERPROFILE\repos",
    "$env:USERPROFILE\Repos2"
)

function Install-CdHook {
    param([string]$WorkspaceDir)

    if (-not (Test-Path $WorkspaceDir)) {
        Write-Host "  Workspace not found, skipping: $WorkspaceDir" -ForegroundColor Yellow
        return
    }

    $wsHooksDir = Join-Path $WorkspaceDir ".claude\hooks"
    $wsDest = Join-Path $wsHooksDir "block-bare-cd.sh"
    $wsSettings = Join-Path $WorkspaceDir ".claude\settings.local.json"

    if (-not (Test-Path $wsHooksDir)) {
        New-Item -ItemType Directory -Path $wsHooksDir -Force | Out-Null
    }
    Copy-Item $CdHookSource $wsDest -Force
    Write-Host "  CD-blocking hook installed: $wsDest" -ForegroundColor Green

    $bashCommand = "bash $($wsDest -replace '\\','/')"

    if (-not (Test-Path $wsSettings)) {
        $ws = @{}
    } else {
        $ws = Get-Content $wsSettings -Raw | ConvertFrom-Json -AsHashtable
    }

    if (-not $ws.ContainsKey('hooks')) {
        $ws['hooks'] = @{}
    }
    if (-not $ws['hooks'].ContainsKey('PreToolUse')) {
        $ws['hooks']['PreToolUse'] = @()
    }

    $alreadyRegistered = $false
    foreach ($entry in $ws['hooks']['PreToolUse']) {
        foreach ($h in $entry.hooks) {
            if ($h.command -and $h.command -like '*block-bare-cd*') {
                $alreadyRegistered = $true
                break
            }
        }
        if ($alreadyRegistered) { break }
    }

    if ($alreadyRegistered) {
        Write-Host "  PreToolUse hook already registered in $wsSettings, skipping" -ForegroundColor Yellow
    } else {
        $bashEntry = @{
            matcher = "Bash"
            hooks = @(
                @{
                    type    = "command"
                    command = $bashCommand
                    timeout = 5
                }
            )
        }
        $pwshEntry = @{
            matcher = "PowerShell"
            hooks = @(
                @{
                    type    = "command"
                    command = $bashCommand
                    timeout = 5
                }
            )
        }
        $ws['hooks']['PreToolUse'] = @($ws['hooks']['PreToolUse']) + @($bashEntry, $pwshEntry)
        Write-Host "  PreToolUse hooks registered for Bash + PowerShell" -ForegroundColor Green
    }

    $ws | ConvertTo-Json -Depth 10 | Set-Content $wsSettings -Encoding UTF8
}

Write-Host ""
Write-Host "Installing CD-blocking hooks per workspace..." -ForegroundColor Cyan
foreach ($ws in $workspaces) {
    Write-Host "Workspace: $ws" -ForegroundColor Cyan
    Install-CdHook -WorkspaceDir $ws
}

# ============================================================================
# 3. TAB TITLE HOOKS (global — ~/.claude/)
# ============================================================================

function Register-GlobalHook {
    param(
        [hashtable]$Settings,
        [string]$EventName,
        [hashtable]$Entry,
        [string]$Marker
    )
    if (-not $Settings['hooks'].ContainsKey($EventName)) {
        $Settings['hooks'][$EventName] = @()
    }
    foreach ($e in $Settings['hooks'][$EventName]) {
        foreach ($h in $e.hooks) {
            if ($h.command -and $h.command -like "*$Marker*") {
                Write-Host "  $EventName hook already registered ($Marker), skipping" -ForegroundColor Yellow
                return
            }
        }
    }
    $Settings['hooks'][$EventName] = @($Settings['hooks'][$EventName]) + @($Entry)
    Write-Host "  $EventName hook registered ($Marker)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installing tab title hooks..." -ForegroundColor Cyan

foreach ($name in @("sync-tab-title.py", "clear-tab-title.py")) {
    $src = Join-Path $ScriptDir "hooks\$name"
    if (-not (Test-Path $src)) {
        Write-Error "Hook script not found: $src"
        exit 1
    }
    Copy-Item $src (Join-Path $hooksDir $name) -Force
    Write-Host "Tab title hook installed: $(Join-Path $hooksDir $name)" -ForegroundColor Green
}

$settings = Get-Content $GlobalSettings -Raw | ConvertFrom-Json -AsHashtable
if (-not $settings.ContainsKey('hooks')) {
    $settings['hooks'] = @{}
}

$syncCommand = "py $((Join-Path $hooksDir 'sync-tab-title.py') -replace '\\','/')"
$clearCommand = "py $((Join-Path $hooksDir 'clear-tab-title.py') -replace '\\','/')"

Register-GlobalHook -Settings $settings -EventName 'UserPromptSubmit' -Marker 'sync-tab-title' -Entry @{
    hooks = @(
        @{
            type    = "command"
            command = $syncCommand
            timeout = 5
        }
    )
}

# matcher "clear" scopes the hook to SessionStart fired by /clear (not startup/resume/compact)
Register-GlobalHook -Settings $settings -EventName 'SessionStart' -Marker 'clear-tab-title' -Entry @{
    matcher = "clear"
    hooks = @(
        @{
            type    = "command"
            command = $clearCommand
            timeout = 5
        }
    )
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $GlobalSettings -Encoding UTF8

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
