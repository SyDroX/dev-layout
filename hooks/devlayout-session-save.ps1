# SessionStart hook: persist current session ID and model for DevLayout tab resume.
# Only runs when DEVLAYOUT_WINDOW and DEVLAYOUT_TAB env vars are set (i.e. launched by DevLayout).
$windowNum = $env:DEVLAYOUT_WINDOW
$tabIndex = $env:DEVLAYOUT_TAB
if (-not $windowNum -or -not $tabIndex) { exit 0 }

$json = [Console]::In.ReadToEnd() | ConvertFrom-Json
$sessionId = $json.session_id
if (-not $sessionId) { exit 0 }

$stateDir = Join-Path $env:USERPROFILE ".claude\hooks\claude-notify"
$stateFile = Join-Path $stateDir ".devlayout-session-w$windowNum-t$tabIndex"
Set-Content $stateFile $sessionId

if ($json.model) {
    $modelFile = Join-Path $stateDir ".devlayout-model-w$windowNum-t$tabIndex"
    Set-Content $modelFile $json.model
}
