# dev-layout

One-click development workspace setup for Windows Terminal.

Opens two Windows Terminal windows on your second monitor, each with 4 Claude Code tabs:

| Window | Position | Tabs 1-4 |
|--------|----------|----------|
| Repos  | Left half  | Claude Code |
| Repos2 | Right half | Claude Code |

All tabs launch with `--dangerously-skip-permissions` and a configurable model (default: `claude-opus-4-6[1m]`).

Each tab automatically resumes its previous conversation on relaunch.

## Requirements

- Windows 10/11
- [Windows Terminal](https://github.com/microsoft/terminal) with `wt.exe` on PATH
- [PowerShell 7+](https://github.com/PowerShell/PowerShell) (`pwsh.exe`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

## Setup

### 1. Install session resume hook

```powershell
powershell -ExecutionPolicy Bypass -File Setup-SessionHook.ps1
```

Copies `hooks/devlayout-session-save.ps1` to `~/.claude/hooks/` and registers a `SessionStart` hook in Claude Code settings. This captures the active session ID whenever Claude starts or the user runs `/resume`.

### 2. Set up Ctrl+Alt+D hotkey (optional)

```powershell
powershell -ExecutionPolicy Bypass -File Setup-DevLayoutShortcut.ps1
```

### 3. Pin to taskbar (optional)

Right-click `DevLayout.bat` and select "Pin to taskbar".

## Usage

```powershell
# Default model (Opus 4.6, 1M context)
powershell -ExecutionPolicy Bypass -File DevLayout.ps1

# Override model
powershell -ExecutionPolicy Bypass -File DevLayout.ps1 -Model claude-opus-4-7
```

Or press **Ctrl+Alt+D** if you set up the hotkey.

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

### Window management

1. Launches `wt.exe` with 4 tabs per window, waits for HWNDs to appear
2. Snaps windows left/right on target monitor via `Win+Arrow` key simulation (`keybd_event`)
3. Each tab runs `launch-claude.ps1` for env cleanup, notification setup, and session resume

### Session resume

Each (window, tab) slot gets a deterministic UUID derived from its position (e.g. `w1-t3`). This UUID is used as the Claude session ID via `--session-id` on first launch and `--resume` on subsequent launches.

When the user manually switches conversations with `/resume` inside Claude, a `SessionStart` hook fires and saves the new session ID to a state file. On next relaunch, the state file takes priority over the deterministic UUID.

**Priority order:** state file (manual /resume) > deterministic UUID > new session

This survives force-close and OS restart -- the hook captures the session ID at start time, not exit time.

## Files

| File | Purpose |
|------|---------|
| `DevLayout.ps1` | Main launcher, window management |
| `DevLayout.bat` | Thin wrapper for taskbar/shortcut |
| `launch-claude.ps1` | Per-tab launcher (env, notifications, session resume) |
| `hooks/devlayout-session-save.ps1` | SessionStart hook (captures session ID) |
| `Setup-SessionHook.ps1` | One-time hook installation |
| `Setup-DevLayoutShortcut.ps1` | Ctrl+Alt+D hotkey setup |

## License

MIT
