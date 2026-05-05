# dev-layout

One-click development workspace setup for Windows Terminal.

Opens two Windows Terminal windows on your second monitor, each with 4 Claude Code tabs:

| Window | Position | Tabs 1-4 |
|--------|----------|----------|
| Repos  | Left half  | Claude Code |
| Repos2 | Right half | Claude Code |

All tabs launch with `--dangerously-skip-permissions` and a configurable model (default: `claude-opus-4-6[1m]`).

Each tab automatically resumes its previous session on relaunch. Session state is tracked per (window, tab) via state files.

## Requirements

- Windows 10/11
- [Windows Terminal](https://github.com/microsoft/terminal) with `wt.exe` on PATH
- [PowerShell 7+](https://github.com/PowerShell/PowerShell) (`pwsh.exe`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

## Usage

### Run directly

```powershell
# Default model (Opus 4.6, 1M context)
powershell -ExecutionPolicy Bypass -File DevLayout.ps1

# Override model
powershell -ExecutionPolicy Bypass -File DevLayout.ps1 -Model claude-opus-4-7
```

### Set up Ctrl+Alt+D hotkey

```powershell
powershell -ExecutionPolicy Bypass -File Setup-DevLayoutShortcut.ps1
```

Then press **Ctrl+Alt+D** from anywhere.

### Pin to taskbar

Right-click `DevLayout.bat` and select "Pin to taskbar".

## Configuration

Edit the `$Config` block at the top of `DevLayout.ps1`:

```powershell
$Config = @{
    Window1 = @{
        Title      = "[DEV] Repos"
        WorkingDir = "$env:USERPROFILE\repos"
    }
    Window2 = @{
        Title      = "[DEV] Repos2"
        WorkingDir = "$env:USERPROFILE\Repos2"
    }
    TargetMonitor = 1    # 0 = left monitor, 1 = right monitor
    LaunchDelayMs = 2000 # Wait time for windows to spawn
    SnapDelayMs   = 150  # Delay between snap operations
}
```

## How It Works

1. Launches `wt.exe` with 4 tabs per window, waits for HWNDs to appear, then snaps left/right on target monitor
2. Window snapping uses `Win+Arrow` key simulation via Win32 `keybd_event` for resolution-independent positioning
3. Each tab runs `launch-claude.ps1` which handles env cleanup, notification setup, and session resume
4. On first launch, Claude picks a random session ID; on exit, the launcher saves it to a state file
5. On subsequent launches, the launcher reads the state file and passes `--resume <id>` to restore the previous conversation

## License

MIT
