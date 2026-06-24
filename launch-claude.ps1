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

# Session resume: deterministic UUID per (window, tab) slot as baseline,
# with state file override to persist manual /resume switches.
$slotKey = "devlayout-w$windowNum-t$tabIndex"
$md5 = [System.Security.Cryptography.MD5]::Create()
$hash = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($slotKey))
$hash[6] = ($hash[6] -band 0x0F) -bor 0x30
$hash[8] = ($hash[8] -band 0x3F) -bor 0x80
$defaultSessionId = ([guid]::new($hash)).ToString()

$cwd = (Get-Location).Path
$projectDir = $cwd -replace '[:\\]', '-'
$projectPath = Join-Path $env:USERPROFILE ".claude\projects\$projectDir"

# State file captures whatever session was active on last exit (including manual /resume)
$stateFile = Join-Path $notifyDir ".devlayout-session-w$windowNum-t$tabIndex"
$resumeId = $null
if (Test-Path $stateFile) {
    $candidate = (Get-Content $stateFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($candidate -and (Test-Path (Join-Path $projectPath "$candidate.jsonl"))) {
        $resumeId = $candidate
    }
}

# Expose slot identity so SessionStart hook can persist session ID on /resume
$env:DEVLAYOUT_WINDOW = $windowNum
$env:DEVLAYOUT_TAB = $tabIndex

# Resolve model for resume: stored model (from SessionStart hook) with [1m], else DevLayout default
$modelFile = Join-Path $notifyDir ".devlayout-model-w$windowNum-t$tabIndex"
$resumeModel = $model
if (Test-Path $modelFile) {
    $stored = (Get-Content $modelFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($stored) {
        $base = $stored -replace '\[.*\]$', ''
        $resumeModel = "$base[1m]"
    }
}

# Priority: state file > deterministic UUID > new session
if ($resumeId) {
    & claude --dangerously-skip-permissions --model $resumeModel --resume $resumeId
} elseif (Test-Path (Join-Path $projectPath "$defaultSessionId.jsonl")) {
    & claude --dangerously-skip-permissions --model $resumeModel --resume $defaultSessionId
} else {
    & claude --dangerously-skip-permissions --model $model --session-id $defaultSessionId
}
