@echo off
:: DevLayout.bat - Launcher wrapper for taskbar pinning / shortcut hotkey
:: Right-click and "Pin to taskbar", or use Setup-DevLayoutShortcut.ps1 for Ctrl+Alt+D
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0DevLayout.ps1"
