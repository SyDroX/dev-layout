#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the DevLayout SessionStart hook into Claude Code settings.
.DESCRIPTION
    1. Copies devlayout-session-save.ps1 to ~/.claude/hooks/
    2. Registers the SessionStart hook in ~/.claude/settings.json (if not already present)

    The hook captures the active session ID whenever Claude starts or the user
    runs /resume, so DevLayout can restore conversations across relaunches.
.NOTES
    Run once after cloning. Re-run after updating the hook script.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$HookSource = Join-Path $ScriptDir "hooks\devlayout-session-save.ps1"
$HookDest = Join-Path $env:USERPROFILE ".claude\hooks\devlayout-session-save.ps1"
$SettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

if (-not (Test-Path $HookSource)) {
    Write-Error "Hook script not found: $HookSource"
    exit 1
}

# Copy hook script
$hooksDir = Join-Path $env:USERPROFILE ".claude\hooks"
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
}
Copy-Item $HookSource $HookDest -Force
Write-Host "Hook script installed: $HookDest" -ForegroundColor Green

# Register in settings.json
$hookCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $($HookDest -replace '\\','/')"

if (-not (Test-Path $SettingsPath)) {
    $settings = @{}
} else {
    $settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json -AsHashtable
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
    Write-Host "SessionStart hook registered in settings.json" -ForegroundColor Green
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
        Write-Host "SessionStart hook already registered, skipping" -ForegroundColor Yellow
    } else {
        $settings['hooks']['SessionStart'] = @($existing) + @($hookEntry)
        Write-Host "SessionStart hook added to existing settings.json" -ForegroundColor Green
    }
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
Write-Host "Setup complete." -ForegroundColor Cyan
