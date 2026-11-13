# Windows Debloat

Scripts to debloat Windows 10/11, with a clickable GUI and an undo option.

## Files

| File | What it is |
|---|---|
| `Debloat-GUI.ps1` | GUI with checkboxes, **Run Selected**, **Undo Selected**, and **Open System Restore** buttons |
| `debloat.bat` | Command Prompt version (no GUI, no undo) |

## What it does

- Removes OneDrive (your files in `%UserProfile%\OneDrive` are left alone)
- Disables telemetry scheduled tasks and services (`DiagTrack`, `dmwappushservice`)
- Removes preinstalled Store bloatware (Candy Crush, Xbox apps, Bing apps, Solitaire, Clipchamp, and others)
- Disables Cortana, web search in Start, Copilot, and silent app reinstalls
- Optionally uninstalls OEM **trial** antivirus (McAfee/Norton trials). This step can't be undone automatically.

It keeps Windows Defender, the Microsoft Store, Calculator, Photos and Snipping Tool.

## Usage

**GUI:** right-click `Debloat-GUI.ps1` and choose **Run with PowerShell**. It asks for admin rights. Or run it from an admin PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\Debloat-GUI.ps1
```

**CMD:** right-click `debloat.bat` and choose **Run as administrator**.

Both scripts create a System Restore point before changing anything. Restart when they finish.

## Disclaimer

Use at your own risk. Try it on a VM or a spare machine first.
