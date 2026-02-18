# Clear inherited CLAUDECODE env var to prevent nested session error
Remove-Item Env:CLAUDECODE -ErrorAction SilentlyContinue

# Run claude-notify setup with tab index and label
$tabIndex = $args[0]
$label = $args[1]
if ($tabIndex -and $label) {
    & bash "$env:USERPROFILE/.claude/hooks/claude-notify/setup.sh" $tabIndex $label
}

# Launch Claude Code
& claude --dangerously-skip-permissions
