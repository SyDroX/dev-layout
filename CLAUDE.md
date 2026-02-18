# dev-layout

Windows Terminal workspace launcher. Opens 2 WT windows on the second monitor, each with 4 tabs (1 brv + 3 Claude Code).

## Architecture

- `DevLayout.ps1` - Main script. Launches WT windows via `wt.exe` with multi-tab arguments, then snaps them using Win32 `keybd_event` (Win+Arrow simulation).
- `DevLayout.bat` - Thin wrapper for taskbar pinning and shortcut hotkey.
- `Setup-DevLayoutShortcut.ps1` - Creates Start Menu shortcut with Ctrl+Alt+D hotkey.

## Key Details

- Window matching uses title strings (`[DEV] Repos`, `[DEV] Repos2`). WT tab titles are set via `--title` flag and `$Host.UI.RawUI.WindowTitle`.
- `wt.exe` tab separator is `\;` (escaped semicolon in PowerShell argument arrays).
- Claude Code launched via `cmd.exe /c claude --dangerously-skip-permissions` to avoid PowerShell quoting issues.
- `ForceForeground` uses `AttachThreadInput` trick to bypass Windows foreground restrictions.
- Snapping requires the window to be on the target monitor first (`MoveWindow` to center, then `keybd_event` Win+Arrow).

## Coding Rules

- No emojis
- PowerShell 5.1 compatible
- All P/Invoke in a single `Add-Type` block
