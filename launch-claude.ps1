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

# For new sessions: snapshot existing jsonls, spawn a background poller to capture the new
# session id within seconds of Claude starting. The poller runs as a hidden process so it
# survives even if the WT tab is killed (try/finally won't run on tab close).
if (-not $resumeId) {
    $beforeList = ""
    if (Test-Path $projectPath) {
        $beforeList = (Get-ChildItem (Join-Path $projectPath '*.jsonl') -ErrorAction SilentlyContinue |
                       ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }) -join ','
    }
    $startIso = (Get-Date).ToString('o')

    $pollerPath = Join-Path $env:TEMP "devlayout-poller-w$windowNum-t$tabIndex.ps1"
    @"
`$projectPath = '$projectPath'
`$stateFile = '$stateFile'
`$startTime = [DateTime]'$startIso'
`$before = @{}
'$beforeList'.Split(',') | Where-Object { `$_ } | ForEach-Object { `$before[`$_] = `$true }
for (`$i = 0; `$i -lt 30; `$i++) {
    Start-Sleep -Seconds 2
    `$files = Get-ChildItem (Join-Path `$projectPath '*.jsonl') -ErrorAction SilentlyContinue |
             Where-Object { -not `$before[[System.IO.Path]::GetFileNameWithoutExtension(`$_.Name)] -and `$_.CreationTime -ge `$startTime }
    if (`$files) {
        `$newest = `$files | Sort-Object CreationTime | Select-Object -First 1
        Set-Content `$stateFile ([System.IO.Path]::GetFileNameWithoutExtension(`$newest.Name))
        break
    }
}
Remove-Item '$pollerPath' -ErrorAction SilentlyContinue
"@ | Set-Content $pollerPath

    Start-Process pwsh -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", $pollerPath -WindowStyle Hidden
}

if ($resumeId) {
    & claude --dangerously-skip-permissions --model $model --resume $resumeId
} else {
    & claude --dangerously-skip-permissions --model $model
}
