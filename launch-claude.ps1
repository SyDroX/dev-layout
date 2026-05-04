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

# Session resume: state file maps (window, tab) -> last session id assigned by Claude.
# --session-id flag is silently ignored in interactive mode, so we let Claude pick its UUID,
# then capture the new jsonl on exit and save its id for next launch to --resume.
$stateFile = Join-Path $notifyDir ".devlayout-session-w$windowNum-t$tabIndex"
$cwd = (Get-Location).Path
$projectDir = $cwd -replace '[:\\]', '-'
$projectPath = Join-Path $env:USERPROFILE ".claude\projects\$projectDir"

$resumeId = $null
if (Test-Path $stateFile) {
    $candidate = (Get-Content $stateFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($candidate -and (Test-Path (Join-Path $projectPath "$candidate.jsonl"))) {
        $resumeId = $candidate
    }
}

# Snapshot existing sessions so we can detect the one Claude creates this run.
$beforeIds = @{}
if (Test-Path $projectPath) {
    Get-ChildItem (Join-Path $projectPath '*.jsonl') -ErrorAction SilentlyContinue | ForEach-Object {
        $beforeIds[[System.IO.Path]::GetFileNameWithoutExtension($_.Name)] = $true
    }
}
$startTime = Get-Date

try {
    if ($resumeId) {
        & claude --dangerously-skip-permissions --model $model --resume $resumeId
    } else {
        & claude --dangerously-skip-permissions --model $model
    }
} finally {
    # On new-session run, find the jsonl Claude just created and save its id for next launch.
    # On resume, the same jsonl is reused so the existing state file is still correct.
    if (-not $resumeId -and (Test-Path $projectPath)) {
        $newest = Get-ChildItem (Join-Path $projectPath '*.jsonl') -ErrorAction SilentlyContinue |
                  Where-Object {
                      -not $beforeIds[[System.IO.Path]::GetFileNameWithoutExtension($_.Name)] -and
                      $_.CreationTime -ge $startTime
                  } |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1
        if ($newest) {
            Set-Content $stateFile ([System.IO.Path]::GetFileNameWithoutExtension($newest.Name))
        }
    }
}
