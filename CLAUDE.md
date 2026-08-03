# dev-layout

Windows Terminal workspace launcher. Opens 2 WT windows on the second monitor, each with 4 Claude Code tabs.

## Architecture

- `DevLayout.ps1` - Main script. Launches WT windows via `wt.exe` with multi-tab arguments, then snaps them using Win32 `keybd_event` (Win+Arrow 
simulation).
- `launch-claude.ps1` - Per-tab launcher. Clears inherited `CLAUDECODE` env var, runs claude-notify setup, handles session resume logic.
- `hooks/devlayout-session-save.ps1` - SessionStart hook. Captures session ID on start and `/resume`, writes to state file keyed by (window, tab).
- `hooks/sync-tab-title.py` - UserPromptSubmit hook. Reads last `custom-title` record from the session transcript, emits OSC 2 via `terminalSequence` 
so the WT tab shows the session name. Honors the clear-marker (stays blank until a new rename).
- `hooks/clear-tab-title.py` - SessionStart hook, matcher `clear`. Blanks the WT tab title on `/clear` and saves the pre-clear title to 
`~/.claude/hooks/state/tab-cleared-<session-id>.txt` so sync only resumes after a NEW rename.
- `Setup-SessionHook.ps1` - Copies hook scripts to `~/.claude/hooks/` and registers SessionStart/UserPromptSubmit entries in 
`~/.claude/settings.json`.
- `Setup-DevLayoutShortcut.ps1` - Creates Start Menu shortcut with Ctrl+Alt+D hotkey.
- `DevLayout.bat` - Thin wrapper for taskbar pinning and shortcut hotkey.

## Session Resume

- Each (window, tab) slot gets a deterministic UUID via MD5 hash of `"devlayout-w{N}-t{N}"`.
- First launch: `--session-id <uuid>` creates session with known ID.
- Subsequent launches: `--resume <uuid>` restores the conversation.
- Manual `/resume` inside Claude fires SessionStart hook, which saves new session ID to state file.
- State file takes priority over deterministic UUID on next launch.
- Env vars `DEVLAYOUT_WINDOW` and `DEVLAYOUT_TAB` passed to Claude so hook knows which slot to update.

## Key Details

- Window detection uses HWND diff (snapshot before/after launch) via `FindWindowsByProcess("WindowsTerminal")`.
- `wt.exe` arguments are passed as a single flat string to avoid PowerShell array quoting issues. Tab separator is `;`.
- `ForceForeground` uses `AttachThreadInput` trick to bypass Windows foreground restrictions.
- Snapping requires the window to be on the target monitor first (`MoveWindow` to center, then `keybd_event` Win+Arrow).

## Coding Rules

- No emojis
- PowerShell 5.1 compatible
- All P/Invoke in a single `Add-Type` block
