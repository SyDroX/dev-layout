# Tab launcher for Claude Code - used by DevLayout
# Args: $args[0] = tab index, $args[1] = label, $args[2] = window number (1 or 2), $args[3] = model id

# Clear inherited CLAUDECODE env var to prevent nested session error
Remove-Item Env:CLAUDECODE -ErrorAction SilentlyContinue

$tabIndex = $args[0]
$label = $args[1]
$windowNum = $args[2]
$model = $args[3]
if (-not $model) { $model = "claude-opus-4-6[1m]" }

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
    & "C:\Program Files\Git\usr\bin\bash.exe" "$env:USERPROFILE/.claude/hooks/claude-notify/setup.sh" $tabIndex $label $hwnd
} elseif ($tabIndex -and $label) {
    & "C:\Program Files\Git\usr\bin\bash.exe" "$env:USERPROFILE/.claude/hooks/claude-notify/setup.sh" $tabIndex $label
}

# Session resume: deterministic UUID per (window, tab) slot.
# Same slot always maps to the same session ID - no pollers or race conditions.
$slotKey = "devlayout-w$windowNum-t$tabIndex"
$md5 = [System.Security.Cryptography.MD5]::Create()
$hash = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($slotKey))
$hash[6] = ($hash[6] -band 0x0F) -bor 0x30
$hash[8] = ($hash[8] -band 0x3F) -bor 0x80
$sessionId = ([guid]::new($hash)).ToString()

# Resolve project dir the same way Claude Code does (actual filesystem case)
$cwd = (Get-Location).Path
$projectDir = $cwd -replace '[:\\]', '-'
$projectPath = Join-Path $env:USERPROFILE ".claude\projects\$projectDir"
$sessionFile = Join-Path $projectPath "$sessionId.jsonl"

if (Test-Path $sessionFile) {
    & claude --dangerously-skip-permissions --model $model --resume $sessionId
} else {
    & claude --dangerously-skip-permissions --model $model --session-id $sessionId
}
