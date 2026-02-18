#Requires -Version 5.1
<#
.SYNOPSIS
    Creates a Ctrl+Alt+D shortcut for DevLayout.
.DESCRIPTION
    Creates a shortcut in the Start Menu Programs folder (required for
    keyboard shortcuts to work). Optionally creates a desktop shortcut.
.NOTES
    Run once to set up. Press Ctrl+Alt+D from anywhere to trigger DevLayout.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BatPath = Join-Path $ScriptDir "DevLayout.bat"
$ShortcutDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$ShortcutPath = Join-Path $ShortcutDir "DevLayout.lnk"

if (-not (Test-Path $BatPath)) {
    Write-Error "DevLayout.bat not found at: $BatPath"
    exit 1
}

$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $BatPath
$Shortcut.WorkingDirectory = $ScriptDir
$Shortcut.Description = "Launch and arrange development windows"
$Shortcut.WindowStyle = 7  # Minimized
$Shortcut.Hotkey = "Ctrl+Alt+D"
$Shortcut.Save()

Write-Host "Shortcut created!" -ForegroundColor Green
Write-Host "  Location: $ShortcutPath" -ForegroundColor Cyan
Write-Host "  Hotkey: Ctrl+Alt+D" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+Alt+D from anywhere to launch DevLayout." -ForegroundColor Yellow

$CreateDesktop = Read-Host "Create desktop shortcut too? (y/N)"
if ($CreateDesktop -eq 'y' -or $CreateDesktop -eq 'Y') {
    $DesktopPath = "$env:USERPROFILE\Desktop\DevLayout.lnk"
    $DesktopShortcut = $WScriptShell.CreateShortcut($DesktopPath)
    $DesktopShortcut.TargetPath = $BatPath
    $DesktopShortcut.WorkingDirectory = $ScriptDir
    $DesktopShortcut.Description = "Launch and arrange development windows"
    $DesktopShortcut.WindowStyle = 7
    $DesktopShortcut.Save()
    Write-Host "Desktop shortcut created at: $DesktopPath" -ForegroundColor Green
}

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($WScriptShell) | Out-Null
