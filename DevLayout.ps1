#Requires -Version 5.1
<#
.SYNOPSIS
    Opens two Windows Terminal windows on the second monitor, each with 4 tabs.
.DESCRIPTION
    Left window  (repos):  Tab 1 = brv, Tabs 2-4 = Claude Code
    Right window (repos2): Tab 1 = brv, Tabs 2-4 = Claude Code

    All Claude Code tabs launch with --dangerously-skip-permissions.
    Uses Windows native snap (Win+Arrow) for resolution-independent positioning.
.NOTES
    Hotkey: Ctrl+Alt+D (via Setup-DevLayoutShortcut.ps1)
#>

# ============================================================================
# CONFIGURATION
# ============================================================================

$Config = @{
    Window1 = @{
        Title      = "[DEV] Repos"
        WorkingDir = "$env:USERPROFILE\repos"
    }
    Window2 = @{
        Title      = "[DEV] Repos2"
        WorkingDir = "$env:USERPROFILE\Repos2"
    }
    # Which monitor to use (0 = first/left, 1 = second/right)
    TargetMonitor = 1
    # Delays in milliseconds
    LaunchDelayMs = 2000
    SnapDelayMs   = 150
}

# ============================================================================
# WINDOWS API
# ============================================================================

Add-Type -AssemblyName System.Windows.Forms

$WinApiSource = @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;
using System.Threading;

public class WinApi
{
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    public const byte VK_LWIN = 0x5B;
    public const byte VK_LEFT = 0x25;
    public const byte VK_RIGHT = 0x27;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const int SW_RESTORE = 9;

    public static bool ForceForeground(IntPtr hWnd)
    {
        IntPtr foreground = GetForegroundWindow();
        uint dummy1, dummy2;
        uint foregroundThread = GetWindowThreadProcessId(foreground, out dummy1);
        uint targetThread = GetWindowThreadProcessId(hWnd, out dummy2);
        uint currentThread = GetCurrentThreadId();

        if (foregroundThread != currentThread)
            AttachThreadInput(currentThread, foregroundThread, true);
        if (targetThread != currentThread)
            AttachThreadInput(currentThread, targetThread, true);

        SetForegroundWindow(hWnd);
        ShowWindow(hWnd, SW_RESTORE);

        if (foregroundThread != currentThread)
            AttachThreadInput(currentThread, foregroundThread, false);
        if (targetThread != currentThread)
            AttachThreadInput(currentThread, targetThread, false);

        return true;
    }

    public static string GetWindowTitle(IntPtr hWnd)
    {
        int length = GetWindowTextLength(hWnd);
        if (length == 0) return string.Empty;
        StringBuilder sb = new StringBuilder(length + 1);
        GetWindowText(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    public static List<IntPtr> FindWindowsByTitle(string titleContains)
    {
        List<IntPtr> windows = new List<IntPtr>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            if (!IsWindowVisible(hWnd)) return true;
            string title = GetWindowTitle(hWnd);
            if (!string.IsNullOrEmpty(title) && title.Contains(titleContains))
                windows.Add(hWnd);
            return true;
        }, IntPtr.Zero);
        return windows;
    }

    public static void SendWinKey(byte arrowKey)
    {
        keybd_event(VK_LWIN, 0, 0, UIntPtr.Zero);
        Thread.Sleep(10);
        keybd_event(arrowKey, 0, 0, UIntPtr.Zero);
        Thread.Sleep(10);
        keybd_event(arrowKey, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        Thread.Sleep(10);
        keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    public static void SnapLeft() { SendWinKey(VK_LEFT); }
    public static void SnapRight() { SendWinKey(VK_RIGHT); }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'WinApi').Type) {
    Add-Type -TypeDefinition $WinApiSource -Language CSharp
}

# ============================================================================
# HELPERS
# ============================================================================

function Set-WindowForeground {
    param([IntPtr]$Handle)
    if ($Handle -eq [IntPtr]::Zero) { return }
    if ([WinApi]::IsIconic($Handle)) {
        [WinApi]::ShowWindow($Handle, [WinApi]::SW_RESTORE) | Out-Null
        Start-Sleep -Milliseconds 50
    }
    [WinApi]::ForceForeground($Handle) | Out-Null
    Start-Sleep -Milliseconds 50
}

function Snap-Window {
    param(
        [IntPtr]$Handle,
        [ValidateSet("Left", "Right")]
        [string]$Position,
        [System.Drawing.Rectangle]$MonitorBounds
    )
    if ($Handle -eq [IntPtr]::Zero) { return }

    Set-WindowForeground -Handle $Handle

    # Move to center of target monitor first (before snap)
    $centerX = $MonitorBounds.X + [int]($MonitorBounds.Width / 4)
    $centerY = $MonitorBounds.Y + [int]($MonitorBounds.Height / 4)
    [WinApi]::MoveWindow($Handle, $centerX, $centerY, 800, 600, $true) | Out-Null
    Start-Sleep -Milliseconds $Config.SnapDelayMs

    Set-WindowForeground -Handle $Handle
    Start-Sleep -Milliseconds 50

    switch ($Position) {
        "Left"  { [WinApi]::SnapLeft() }
        "Right" { [WinApi]::SnapRight() }
    }
}

function Start-TerminalWindow {
    param(
        [string]$Title,
        [string]$WorkingDir
    )

    # Build wt.exe command: 4 tabs
    # Tab 1: brv (ByteRover CLI)
    # Tabs 2-4: claude-notify setup (with tab index + label) then Claude Code
    $setupScript = "%USERPROFILE%/.claude/hooks/claude-notify/setup.sh"

    # Short name from window title for popup labels (e.g. "[DEV] Repos" -> "Repos")
    $shortName = $Title -replace '^\[.*?\]\s*', ''

    # wt.exe uses ; to separate commands, escaped as \; in PowerShell
    $args = @(
        "-w", "new",
        "--title", "`"$Title`"",
        "-d", "`"$WorkingDir`"",
        "pwsh.exe", "-NoExit", "-Command", "`"& { `$Host.UI.RawUI.WindowTitle = '$Title'; brv }`"",
        "`;"
        "new-tab",
        "--title", "`"Claude 1`"",
        "-d", "`"$WorkingDir`"",
        "cmd.exe", "/c", "`"bash $setupScript 2 `"$shortName / Claude 1`" & claude --dangerously-skip-permissions`"",
        "`;"
        "new-tab",
        "--title", "`"Claude 2`"",
        "-d", "`"$WorkingDir`"",
        "cmd.exe", "/c", "`"bash $setupScript 3 `"$shortName / Claude 2`" & claude --dangerously-skip-permissions`"",
        "`;"
        "new-tab",
        "--title", "`"Claude 3`"",
        "-d", "`"$WorkingDir`"",
        "cmd.exe", "/c", "`"bash $setupScript 4 `"$shortName / Claude 3`" & claude --dangerously-skip-permissions`""
    )

    Start-Process "wt.exe" -ArgumentList $args
}

# ============================================================================
# MAIN
# ============================================================================

function Invoke-DevLayout {
    Write-Host "DevLayout: Setting up development environment..." -ForegroundColor Cyan

    $monitors = [System.Windows.Forms.Screen]::AllScreens | Sort-Object { $_.Bounds.X }
    $monitorIndex = [Math]::Min($Config.TargetMonitor, $monitors.Count - 1)
    $targetMonitor = $monitors[$monitorIndex].WorkingArea

    if ($monitors.Count -lt 2) {
        Write-Warning "Single monitor detected. Using primary monitor."
    }

    # Check for existing windows
    $w1Handle = [IntPtr]::Zero
    $w2Handle = [IntPtr]::Zero

    $w1Windows = [WinApi]::FindWindowsByTitle($Config.Window1.Title)
    if ($w1Windows.Count -gt 0) { $w1Handle = $w1Windows[0] }

    $w2Windows = [WinApi]::FindWindowsByTitle($Config.Window2.Title)
    if ($w2Windows.Count -gt 0) { $w2Handle = $w2Windows[0] }

    # If both exist, just focus and snap them
    if ($w1Handle -ne [IntPtr]::Zero -and $w2Handle -ne [IntPtr]::Zero) {
        Write-Host "  Both windows found - snapping to position" -ForegroundColor Green
        Snap-Window -Handle $w1Handle -Position "Left" -MonitorBounds $targetMonitor
        Start-Sleep -Milliseconds $Config.SnapDelayMs
        Snap-Window -Handle $w2Handle -Position "Right" -MonitorBounds $targetMonitor
        Write-Host "DevLayout: Complete! (snap only)" -ForegroundColor Green
        return
    }

    # Launch missing windows
    if ($w1Handle -eq [IntPtr]::Zero) {
        Write-Host "  Launching: $($Config.Window1.Title)" -ForegroundColor Yellow
        Start-TerminalWindow -Title $Config.Window1.Title -WorkingDir $Config.Window1.WorkingDir
    } else {
        Write-Host "  Found: $($Config.Window1.Title)" -ForegroundColor Green
    }

    Start-Sleep -Milliseconds 500

    if ($w2Handle -eq [IntPtr]::Zero) {
        Write-Host "  Launching: $($Config.Window2.Title)" -ForegroundColor Yellow
        Start-TerminalWindow -Title $Config.Window2.Title -WorkingDir $Config.Window2.WorkingDir
    } else {
        Write-Host "  Found: $($Config.Window2.Title)" -ForegroundColor Green
    }

    # Wait for windows to appear
    Write-Host "  Waiting for windows to launch..." -ForegroundColor Gray
    Start-Sleep -Milliseconds $Config.LaunchDelayMs

    # Re-find windows
    if ($w1Handle -eq [IntPtr]::Zero) {
        $w1Windows = [WinApi]::FindWindowsByTitle($Config.Window1.Title)
        if ($w1Windows.Count -gt 0) { $w1Handle = $w1Windows[0] }
    }
    if ($w2Handle -eq [IntPtr]::Zero) {
        $w2Windows = [WinApi]::FindWindowsByTitle($Config.Window2.Title)
        if ($w2Windows.Count -gt 0) { $w2Handle = $w2Windows[0] }
    }

    # Snap to monitor
    Write-Host "  Snapping windows to monitor $($monitorIndex + 1)..." -ForegroundColor Cyan

    if ($w1Handle -ne [IntPtr]::Zero) {
        Snap-Window -Handle $w1Handle -Position "Left" -MonitorBounds $targetMonitor
        Write-Host "    $($Config.Window1.Title) -> LEFT" -ForegroundColor Gray
    } else {
        Write-Host "    $($Config.Window1.Title) -> NOT FOUND (launch may have been slow)" -ForegroundColor Red
    }

    Start-Sleep -Milliseconds $Config.SnapDelayMs

    if ($w2Handle -ne [IntPtr]::Zero) {
        Snap-Window -Handle $w2Handle -Position "Right" -MonitorBounds $targetMonitor
        Write-Host "    $($Config.Window2.Title) -> RIGHT" -ForegroundColor Gray
    } else {
        Write-Host "    $($Config.Window2.Title) -> NOT FOUND (launch may have been slow)" -ForegroundColor Red
    }

    Write-Host "DevLayout: Complete!" -ForegroundColor Green
}

Invoke-DevLayout
