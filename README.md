# dev-layout

One-click development workspace setup for Windows Terminal.

Opens two Windows Terminal windows on your second monitor, each with 4 tabs:

| Window | Position | Tab 1 | Tabs 2-4 |
|--------|----------|-------|----------|
| Repos  | Left half  | [ByteRover](https://byterover.com) CLI (`brv`) | Claude Code |
| Repos2 | Right half | ByteRover CLI (`brv`) | Claude Code |

All Claude Code tabs launch with `--dangerously-skip-permissions` for uninterrupted autonomous work.

Re-running the script when windows already exist snaps them back into position without relaunching.

## Requirements

- Windows 10/11
- [Windows Terminal](https://github.com/microsoft/terminal) with `wt.exe` on PATH
- [PowerShell 7+](https://github.com/PowerShell/PowerShell) (`pwsh.exe`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [ByteRover](https://byterover.com) CLI (`brv`)

## Usage

### Run directly

```powershell
powershell -ExecutionPolicy Bypass -File DevLayout.ps1
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

1. Checks if windows with the configured titles already exist
2. If both exist: snaps them to position (left/right on target monitor)
3. If missing: launches `wt.exe` with 4 tabs per window, waits for them to appear, then snaps
4. Window snapping uses `Win+Arrow` key simulation via Win32 `keybd_event` for resolution-independent positioning

## License

MIT
