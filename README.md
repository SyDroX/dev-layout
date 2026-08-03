# dev-layout

Multi-repo Claude Code workspace launcher for Windows Terminal.

![DevLayout demo](https://github.com/user-attachments/assets/7873ef4d-c73b-42a6-9720-6af570691389)

Opens two Windows Terminal windows on your second monitor, each with 4 Claude Code tabs:

| Window | Position | Tabs 1-4 |
|--------|----------|----------|
| Repos  | Left half  | Claude Code |
| Repos2 | Right half | Claude Code |

All tabs launch with `--dangerously-skip-permissions` and a configurable model (default: `claude-fable-5[1m]`).

Each tab automatically resumes its previous conversation on relaunch.

## Why

Claude Code runs in a single directory. When your project spans multiple repos (app, backend, dashboard, plugins, bridges), you need Claude in a 
**parent directory** that contains all of them. From there, Claude uses absolute paths and `git -C <path>` to operate across repos without ever 
changing the working directory.

DevLayout automates this setup: 8 Claude Code tabs across 2 workspace roots, all pre-configured with session persistence and a `cd`-blocking hook 
that prevents Claude from breaking out of the multi-repo pattern.

### The cd problem

If Claude runs `cd my-backend` to work on the backend, it loses access to the other repos. Every subsequent command runs in the wrong directory. The 
`block-bare-cd.sh` hook prevents this by blocking `cd`, `chdir`, `Set-Location`, and equivalents at the PreToolUse level, forcing absolute paths 
instead.

## Requirements

- Windows 10/11
- [Windows Terminal](https://github.com/microsoft/terminal) with `wt.exe` on PATH
- [PowerShell 7+](https://github.com/PowerShell/PowerShell) (`pwsh.exe`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Python 3 (for the cd-blocking hook)

## Setup

### 1. Install hooks

```powershell
powershell -ExecutionPolicy Bypass -File Setup-SessionHook.ps1
```

Installs two hooks:

- **Session resume** (`~/.claude/hooks/devlayout-session-save.ps1`) -- SessionStart hook that captures the active session ID whenever Claude starts 
or the user runs `/resume`, so tabs restore their conversation on relaunch.
- **CD blocker** (`<workspace>/.claude/hooks/block-bare-cd.sh`) -- PreToolUse hook that blocks `cd`, `chdir`, `Set-Location`, etc. in Bash and 
PowerShell tool calls, forcing Claude to use absolute paths and `git -C` for multi-repo work.

### 2. Set up Ctrl+Alt+D hotkey (optional)

```powershell
powershell -ExecutionPolicy Bypass -File Setup-DevLayoutShortcut.ps1
```

### 3. Pin to taskbar (optional)

Right-click `DevLayout.bat` and select "Pin to taskbar".

## Usage

```powershell
# Default model (Fable 5, 1M context)
powershell -ExecutionPolicy Bypass -File DevLayout.ps1

# Override model
powershell -ExecutionPolicy Bypass -File DevLayout.ps1 -Model claude-opus-4-8
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

Each (window, tab) slot gets a deterministic UUID derived from its position (e.g. `w1-t3`). This UUID is used as the Claude session ID via 
`--session-id` on first launch and `--resume` on subsequent launches.

When the user manually switches conversations with `/resume` inside Claude, a `SessionStart` hook fires and saves the new session ID to a state file. 
On next relaunch, the state file takes priority over the deterministic UUID.

**Priority order:** state file (manual /resume) > deterministic UUID > new session

This survives force-close and OS restart -- the hook captures the session ID at start time, not exit time.

### CD blocking

The `block-bare-cd.sh` hook intercepts every Bash and PowerShell tool call via PreToolUse. It splits the command on `;`, `&&`, `||`, `|`, and 
newlines, then checks the first token of each segment against a banned list: `cd`, `chdir`, `set-location`, `push-location`, `pop-location`, `sl`. If 
matched, the command is blocked with exit code 2 and Claude is told to use absolute paths or `git -C` instead.

## Files

| File | Purpose |
|------|---------|
| `DevLayout.ps1` | Main launcher, window management |
| `DevLayout.bat` | Thin wrapper for taskbar/shortcut |
| `launch-claude.ps1` | Per-tab launcher (env, notifications, session resume) |
| `hooks/devlayout-session-save.ps1` | SessionStart hook (captures session ID) |
| `hooks/block-bare-cd.sh` | PreToolUse hook (blocks cd commands) |
| `Setup-SessionHook.ps1` | One-time hook installation |
| `Setup-DevLayoutShortcut.ps1` | Ctrl+Alt+D hotkey setup |

## License

MIT
