# SessionStart hook: persist current session ID for DevLayout tab resume.
# Only runs when DEVLAYOUT_WINDOW and DEVLAYOUT_TAB env vars are set (i.e. launched by DevLayout).
$windowNum = $env:DEVLAYOUT_WINDOW
$tabIndex = $env:DEVLAYOUT_TAB
if (-not $windowNum -or -not $tabIndex) { exit 0 }

$json = [Console]::In.ReadToEnd() | ConvertFrom-Json
$sessionId = $json.session_id
if (-not $sessionId) { exit 0 }

$stateFile = Join-Path $env:USERPROFILE ".claude\hooks\claude-notify\.devlayout-session-w$windowNum-t$tabIndex"
Set-Content $stateFile $sessionId
