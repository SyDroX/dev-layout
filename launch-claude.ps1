# Tab launcher for Claude Code - used by DevLayout
# Args: $args[0] = tab index, $args[1] = label, $args[2] = window number (1 or 2)

# Clear inherited CLAUDECODE env var to prevent nested session error
Remove-Item Env:CLAUDECODE -ErrorAction SilentlyContinue

$tabIndex = $args[0]
$label = $args[1]
$windowNum = $args[2]

$notifyDir = Join-Path $env:USERPROFILE ".claude\hooks\claude-notify"
$hwnd = $null

# Poll for HWND file written by DevLayout (up to 15 seconds)
if ($windowNum) {
    $hwndFile = Join-Path $notifyDir ".devlayout-hwnd-$windowNum"
    for ($i = 0; $i -lt 30; $i++) {
        if (Test-Path $hwndFile) {
            $hwnd = (Get-Content $hwndFile -Raw).Trim()
            if ($hwnd) { break }
        }
        Start-Sleep -Milliseconds 500
    }
}

# Run claude-notify setup with tab index, label, and HWND override
if ($tabIndex -and $label -and $hwnd) {
    & bash "$env:USERPROFILE/.claude/hooks/claude-notify/setup.sh" $tabIndex $label $hwnd
} elseif ($tabIndex -and $label) {
    & bash "$env:USERPROFILE/.claude/hooks/claude-notify/setup.sh" $tabIndex $label
}

# Launch Claude Code
& claude --dangerously-skip-permissions
