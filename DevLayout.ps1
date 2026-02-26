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
# ENVIRONMENT
# ============================================================================

# Resolve pwsh.exe full path (wt.exe is a UWP app and won't inherit PATH changes)
$registryPath = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User") + ";" + $env:Path
$PwshExe = ($registryPath.Split(';') |
    Where-Object { $_ -and (Test-Path (Join-Path $_ "pwsh.exe") -ErrorAction SilentlyContinue) } |
    Select-Object -First 1 |
    ForEach-Object { Join-Path $_ "pwsh.exe" })
if (-not $PwshExe) {
    Write-Error "pwsh.exe not found. Install PowerShell 7: winget install Microsoft.PowerShell"
    return
}

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
    # Which monitor to use (0 = leftmost, 1 = next, etc.)
    TargetMonitor = 0
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

    public static List<IntPtr> FindWindowsByProcess(string processName)
    {
        List<IntPtr> windows = new List<IntPtr>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            if (!IsWindowVisible(hWnd)) return true;
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            try
            {
                var proc = System.Diagnostics.Process.GetProcessById((int)pid);
                if (proc.ProcessName == processName)
                {
                    string title = GetWindowTitle(hWnd);
                    if (!string.IsNullOrEmpty(title) && title != "PopupHost")
                        windows.Add(hWnd);
                }
            }
            catch {}
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
        [string]$WorkingDir,
        [int]$WindowNum
    )

    # Short name from window title for popup labels (e.g. "[DEV] Repos" -> "Repos")
    $shortName = $Title -replace '^\[.*?\]\s*', ''

    # Launcher script clears CLAUDECODE env var, runs claude-notify setup, then Claude Code
    $launcher = Join-Path $PSScriptRoot "launch-claude.ps1"

    # Build wt.exe command as a single string to avoid PowerShell array quoting issues.
    # Tab 1: brv (ByteRover CLI) in pwsh
    # Tabs 2-4: Claude Code via launcher (handles env cleanup + notification setup)
    # WindowNum is passed so launcher can resolve the correct HWND from DevLayout
    $wtArgs = "-w new" +
        " --title `"$Title`" -d `"$WorkingDir`" `"$PwshExe`" -NoExit -Command `"`$Host.UI.RawUI.WindowTitle = '$Title'\; brv`"" +
        " ; new-tab --title `"Claude 1`" -d `"$WorkingDir`" `"$PwshExe`" -NoExit -ExecutionPolicy Bypass -Command `"& '$launcher' 2 '$shortName / Claude 1' $WindowNum`"" +
        " ; new-tab --title `"Claude 2`" -d `"$WorkingDir`" `"$PwshExe`" -NoExit -ExecutionPolicy Bypass -Command `"& '$launcher' 3 '$shortName / Claude 2' $WindowNum`"" +
        " ; new-tab --title `"Claude 3`" -d `"$WorkingDir`" `"$PwshExe`" -NoExit -ExecutionPolicy Bypass -Command `"& '$launcher' 4 '$shortName / Claude 3' $WindowNum`""

    $wtPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
    Start-Process $wtPath -ArgumentList $wtArgs
}

# ============================================================================
# MAIN
# ============================================================================

function Find-NewWTWindow {
    param([System.Collections.Generic.List[IntPtr]]$ExistingWindows, [IntPtr[]]$KnownNew)
    $allWT = [WinApi]::FindWindowsByProcess("WindowsTerminal")
    foreach ($hwnd in $allWT) {
        if ($ExistingWindows -notcontains $hwnd -and $KnownNew -notcontains $hwnd) {
            return $hwnd
        }
    }
    return [IntPtr]::Zero
}

function Invoke-DevLayout {
    Write-Host "DevLayout: Setting up development environment..." -ForegroundColor Cyan

    $monitors = [System.Windows.Forms.Screen]::AllScreens | Sort-Object { $_.Bounds.X }
    $monitorIndex = [Math]::Min($Config.TargetMonitor, $monitors.Count - 1)
    $targetMonitor = $monitors[$monitorIndex].WorkingArea

    if ($monitors.Count -lt 2) {
        Write-Warning "Single monitor detected. Using primary monitor."
    }

    $notifyDir = Join-Path $env:USERPROFILE ".claude\hooks\claude-notify"

    # Clean stale DevLayout HWND files
    Remove-Item (Join-Path $notifyDir ".devlayout-hwnd-*") -ErrorAction SilentlyContinue

    # Snapshot existing WT windows before launching
    $existingWTWindows = [WinApi]::FindWindowsByProcess("WindowsTerminal")

    # Launch Window 1 and wait for its HWND
    Write-Host "  Launching: $($Config.Window1.Title)" -ForegroundColor Yellow
    Start-TerminalWindow -Title $Config.Window1.Title -WorkingDir $Config.Window1.WorkingDir -WindowNum 1

    Write-Host "  Waiting for window 1..." -ForegroundColor Gray
    $w1Handle = [IntPtr]::Zero
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 200
        $w1Handle = Find-NewWTWindow -ExistingWindows $existingWTWindows -KnownNew @()
        if ($w1Handle -ne [IntPtr]::Zero) { break }
    }

    if ($w1Handle -ne [IntPtr]::Zero) {
        # Write HWND file so Window 1's tabs can pick it up
        Set-Content (Join-Path $notifyDir ".devlayout-hwnd-1") $w1Handle.ToInt64()
        Write-Host "    Window 1 HWND: $($w1Handle.ToInt64())" -ForegroundColor Gray
    } else {
        Write-Host "    Window 1 -> NOT FOUND" -ForegroundColor Red
    }

    # Launch Window 2 and wait for its HWND
    Write-Host "  Launching: $($Config.Window2.Title)" -ForegroundColor Yellow
    Start-TerminalWindow -Title $Config.Window2.Title -WorkingDir $Config.Window2.WorkingDir -WindowNum 2

    Write-Host "  Waiting for window 2..." -ForegroundColor Gray
    $w2Handle = [IntPtr]::Zero
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 200
        $w2Handle = Find-NewWTWindow -ExistingWindows $existingWTWindows -KnownNew @($w1Handle)
        if ($w2Handle -ne [IntPtr]::Zero) { break }
    }

    if ($w2Handle -ne [IntPtr]::Zero) {
        # Write HWND file so Window 2's tabs can pick it up
        Set-Content (Join-Path $notifyDir ".devlayout-hwnd-2") $w2Handle.ToInt64()
        Write-Host "    Window 2 HWND: $($w2Handle.ToInt64())" -ForegroundColor Gray
    } else {
        Write-Host "    Window 2 -> NOT FOUND" -ForegroundColor Red
    }

    # Snap windows: Window 1 (Repos) left, Window 2 (Repos2) right
    Write-Host "  Snapping windows to monitor $($monitorIndex + 1)..." -ForegroundColor Cyan

    if ($w1Handle -ne [IntPtr]::Zero) {
        Snap-Window -Handle $w1Handle -Position "Left" -MonitorBounds $targetMonitor
        $title = [WinApi]::GetWindowTitle($w1Handle)
        Write-Host "    $title -> LEFT" -ForegroundColor Gray
    }

    Start-Sleep -Milliseconds $Config.SnapDelayMs

    if ($w2Handle -ne [IntPtr]::Zero) {
        Snap-Window -Handle $w2Handle -Position "Right" -MonitorBounds $targetMonitor
        $title = [WinApi]::GetWindowTitle($w2Handle)
        Write-Host "    $title -> RIGHT" -ForegroundColor Gray
    }

    Write-Host "DevLayout: Complete!" -ForegroundColor Green
}

Invoke-DevLayout
