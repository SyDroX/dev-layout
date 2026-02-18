# dev-layout

Windows Terminal workspace launcher. Opens 2 WT windows on the second monitor, each with 4 tabs (1 brv + 3 Claude Code).

## Architecture

- `DevLayout.ps1` - Main script. Launches WT windows via `wt.exe` with multi-tab arguments, then snaps them using Win32 `keybd_event` (Win+Arrow simulation).
- `launch-claude.cmd` - Tab launcher for Claude Code tabs. Clears inherited `CLAUDECODE` env var, runs claude-notify setup, then starts Claude Code.
- `DevLayout.bat` - Thin wrapper for taskbar pinning and shortcut hotkey.
- `Setup-DevLayoutShortcut.ps1` - Creates Start Menu shortcut with Ctrl+Alt+D hotkey.

## Key Details

- Window detection uses HWND diff (snapshot before/after launch) via `FindWindowsByProcess("WindowsTerminal")`.
- `wt.exe` arguments are passed as a single flat string to avoid PowerShell array quoting issues. Tab separator is `;`.
- Claude Code tabs use `launch-claude.cmd` wrapper to: (1) clear `CLAUDECODE` env var (prevents nested session error), (2) run claude-notify setup with tab index + label, (3) launch Claude Code.
- `ForceForeground` uses `AttachThreadInput` trick to bypass Windows foreground restrictions.
- Snapping requires the window to be on the target monitor first (`MoveWindow` to center, then `keybd_event` Win+Arrow).

## Coding Rules

- No emojis
- PowerShell 5.1 compatible
- All P/Invoke in a single `Add-Type` block
