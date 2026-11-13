# Windows Debloat

A tool that cleans up the extra stuff Windows 10/11 ships with, so your PC is quieter, less cluttered and sends less data to Microsoft. You can undo it later.

## In plain words: what does this do?

A new Windows PC comes with a lot of things most people never asked for: games like Candy Crush, apps that keep pushing news and ads, OneDrive popping up to sync your files, and background tasks that send usage data to Microsoft. This tool clears that out.

**With the window version (`Debloat-GUI.ps1`):**

1. You open it and a small window appears with a list of tick boxes.
2. Each box is one kind of clean-up (for example "Remove OneDrive"). Tick the ones you want.
3. Click **Run Selected**. It first saves a "restore point", which is like a save game for Windows, and then makes the changes. A black log box shows what it's doing.
4. Changed your mind? Tick the same boxes and click **Undo Selected** to put things back.
5. If something goes really wrong, **Open System Restore** lets you go back to the save point from step 3.

**With the command version (`debloat.bat`):**

It does the same clean-up in a text window with no buttons. It asks you once to type `Y` to confirm and then runs everything. It has no undo button, but it still makes a restore point first.

### What gets cleaned up

| Option | In plain words |
|---|---|
| Remove OneDrive | Stops OneDrive from starting, syncing and nagging you. **Your files are not deleted.** |
| Disable telemetry | Turns off the background jobs that send usage and diagnostic data to Microsoft. |
| Remove Store bloatware | Uninstalls pre-loaded apps you probably don't use: Candy Crush, Solitaire, Xbox apps, Bing News/Weather, Skype, Clipchamp and similar. |
| Disable Cortana / Copilot / suggestions | Start menu search stays on your PC instead of searching the web, Copilot is turned off, and Windows stops quietly reinstalling "suggested" apps. |
| Remove trial antivirus | Uninstalls the free-trial McAfee or Norton that some PC makers preinstall. Off by default, and **can't be undone** by this tool. |

### What it leaves alone

- **Windows Defender**, the built-in antivirus. It stays on so your PC is never left unprotected.
- Microsoft Store, Calculator, Photos, Snipping Tool and anything else Windows needs to work properly.
- Your personal files.

## How to run it

> Try it on a spare PC or a virtual machine first. You need administrator rights.

**Window version:** right-click `Debloat-GUI.ps1` and choose **Run with PowerShell**, then click **Yes** on the admin prompt. If Windows blocks it, open PowerShell as administrator in the same folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Debloat-GUI.ps1
```

**Command version:** right-click `debloat.bat` and choose **Run as administrator**.

Restart your PC when it finishes.

## How to undo

- **Window version:** tick the same options and click **Undo Selected**. This turns telemetry back on, clears the Cortana/Copilot settings, reinstalls OneDrive, and re-registers Store apps. Any app that doesn't come back can be reinstalled from the Microsoft Store.
- **Either version:** go back to the restore point via **Control Panel > Recovery > Open System Restore** (or the **Open System Restore** button in the window).

## Technical details

<details>
<summary>Exactly what each option changes</summary>

**OneDrive**
- Kills `OneDrive.exe` and runs `OneDriveSetup.exe /uninstall`
- Sets `HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive\DisableFileSyncNGSC = 1`
- The `.bat` version also removes leftover app folders and the Explorer sidebar entry

**Telemetry**
- Disables scheduled tasks under `Application Experience`, `Customer Experience Improvement Program`, `Autochk`, `DiskDiagnostic`, `Feedback\Siuf` and `Windows Error Reporting`
- Stops and disables the `DiagTrack` and `dmwappushservice` services
- Sets `AllowTelemetry = 0` and turns off the advertising ID

**Store bloatware**
- `Remove-AppxPackage -AllUsers` plus `Remove-AppxProvisionedPackage`, so new user accounts don't get the apps either
- The full list is the `$BloatApps` array at the top of `Debloat-GUI.ps1`

**Cortana / Copilot / suggestions**
- `AllowCortana = 0`, `DisableWebSearch = 1`, `TurnOffWindowsCopilot = 1`
- `DisableWindowsConsumerFeatures = 1`, `SilentInstalledAppsEnabled = 0`

**Trial antivirus**
- Runs McAfee's own uninstaller if present, then any `QuietUninstallString` registered for McAfee/Norton products
- If a trial resists removal, use the vendor tools: MCPR (McAfee) or Norton Remove and Reinstall

</details>

## Disclaimer

Use at your own risk. These scripts change system settings and remove apps. They make a restore point first, but test on a non-critical machine before using them on one you depend on.
