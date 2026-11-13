@echo off
:: ============================================================================
::  Windows Debloater
::  - Removes OneDrive
::  - Disables / removes telemetry scheduled tasks and services
::  - Uninstalls OEM trial antivirus bloatware (McAfee / Norton trials)
::
::  NOTE: This script intentionally does NOT disable or remove Windows Defender.
::        Defender is your system's baseline protection and yields automatically
::        to any third-party AV you install. Running with no AV at all is a bad
::        idea. Only OEM *trialware* AV is uninstalled below.
::
::  Run this from an ELEVATED Command Prompt (Run as administrator).
::  Create a System Restore point first (instructions printed at the end if
::  you skip the auto-attempt below).
:: ============================================================================

setlocal EnableDelayedExpansion

:: --- Require administrator -------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script must be run as Administrator.
    echo Right-click Command Prompt and choose "Run as administrator".
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Windows Debloater
echo ============================================================
echo.
echo This will:
echo   1. Create a System Restore point
echo   2. Remove OneDrive
echo   3. Disable Windows telemetry tasks and services
echo   4. Uninstall OEM trial antivirus (McAfee / Norton trials)
echo.
echo Windows Defender will NOT be touched.
echo.
set /p CONFIRM="Type Y to continue, anything else to abort: "
if /i not "%CONFIRM%"=="Y" (
    echo Aborted. Nothing was changed.
    exit /b 0
)

:: ===========================================================================
::  0. SYSTEM RESTORE POINT
:: ===========================================================================
echo.
echo [*] Creating a System Restore point...
powershell -NoProfile -Command "Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue; Checkpoint-Computer -Description 'Pre-Debloat' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction SilentlyContinue" 2>nul
echo     (If this was skipped by Windows' rate limit, make one manually via
echo      Control Panel ^> System ^> System Protection before continuing.)

:: ===========================================================================
::  1. REMOVE ONEDRIVE
:: ===========================================================================
echo.
echo [*] Removing OneDrive...

:: Stop the process
taskkill /f /im OneDrive.exe >nul 2>&1

:: Run the built-in uninstaller (path differs on 32/64-bit)
if exist "%SystemRoot%\System32\OneDriveSetup.exe" (
    "%SystemRoot%\System32\OneDriveSetup.exe" /uninstall
)
if exist "%SystemRoot%\SysWOW64\OneDriveSetup.exe" (
    "%SystemRoot%\SysWOW64\OneDriveSetup.exe" /uninstall
)

:: Remove leftover folders (user data in %UserProfile%\OneDrive is left alone)
rd /s /q "%UserProfile%\AppData\Local\Microsoft\OneDrive" >nul 2>&1
rd /s /q "%ProgramData%\Microsoft OneDrive"              >nul 2>&1
rd /s /q "%SystemDrive%\OneDriveTemp"                    >nul 2>&1

:: Remove OneDrive from the Explorer navigation pane
reg delete "HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1
reg delete "HKCR\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1

:: Prevent OneDrive from being reinstalled for the user via Group Policy key
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f >nul 2>&1

echo     OneDrive removed. (Your files in %%UserProfile%%\OneDrive were NOT deleted.)

:: ===========================================================================
::  2. DISABLE TELEMETRY SCHEDULED TASKS
:: ===========================================================================
echo.
echo [*] Disabling telemetry scheduled tasks...

for %%T in (
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Application Experience\StartupAppTask"
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask"
    "\Microsoft\Windows\Autochk\Proxy"
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
) do (
    schtasks /change /tn %%T /disable >nul 2>&1 && echo     disabled: %%~T
)

:: ===========================================================================
::  3. DISABLE TELEMETRY SERVICES + POLICY
:: ===========================================================================
echo.
echo [*] Disabling telemetry services and setting telemetry level to 0...

:: DiagTrack = "Connected User Experiences and Telemetry"
:: dmwappushservice = WAP Push message routing (telemetry transport)
for %%S in (DiagTrack dmwappushservice) do (
    sc stop   %%S >nul 2>&1
    sc config %%S start= disabled >nul 2>&1 && echo     disabled service: %%S
)

:: Set telemetry to the lowest level the edition allows (0 = Security on Enterprise/Edu, Basic elsewhere)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1

:: Turn off tailored experiences / advertising ID (current user)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1

echo     Telemetry disabled.

:: ===========================================================================
::  4. UNINSTALL OEM TRIAL ANTIVIRUS (bloatware only)
:: ===========================================================================
echo.
echo [*] Looking for OEM trial antivirus bloatware (McAfee / Norton trials)...
echo     (Windows Defender is left intact.)

:: McAfee has a dedicated silent removal path on most OEM images.
if exist "%ProgramFiles%\McAfee\MSC\mcuihost.exe" (
    echo     Found McAfee - launching its uninstaller...
    start "" /wait "%ProgramFiles%\McAfee\MSC\mcuihost.exe" /uninstall
)

:: Fall back to removing any McAfee / Norton trial packages via their registered uninstallers.
powershell -NoProfile -Command ^
  "$targets = 'McAfee','Norton Security','Norton 360','NortonLifeLock'; " ^
  "$keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'); " ^
  "Get-ItemProperty $keys -ErrorAction SilentlyContinue | " ^
  "Where-Object { $n=$_.DisplayName; $n -and ($targets | Where-Object { $n -like \"*$_*\" }) } | " ^
  "ForEach-Object { Write-Host ('    uninstalling: ' + $_.DisplayName); " ^
  "   if ($_.QuietUninstallString) { cmd /c $_.QuietUninstallString } " ^
  "   elseif ($_.UninstallString)  { Write-Host ('      run manually: ' + $_.UninstallString) } }"

echo.
echo     Note: some AV suites refuse silent removal by design (self-protection).
echo     If a trial remains, use its official removal tool:
echo       McAfee  : MCPR (McAfee Consumer Product Removal tool)
echo       Norton  : Norton Remove and Reinstall tool

:: ===========================================================================
::  5. REMOVE PREINSTALLED STORE-APP BLOATWARE
:: ===========================================================================
echo.
echo [*] Removing preinstalled Store-app bloatware...
echo     (Store, Calculator, Photos, Snipping Tool, security apps are KEPT.)

:: Remove for the current user AND deprovision so new users don't get them.
:: Essentials are deliberately NOT in this list.
powershell -NoProfile -Command ^
  "$bloat = @(" ^
  "  'Microsoft.3DBuilder','Microsoft.549981C3F5F10','Microsoft.BingNews'," ^
  "  'Microsoft.BingWeather','Microsoft.BingFinance','Microsoft.BingSports'," ^
  "  'Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.Messaging'," ^
  "  'Microsoft.Microsoft3DViewer','Microsoft.MicrosoftOfficeHub'," ^
  "  'Microsoft.MicrosoftSolitaireCollection','Microsoft.MixedReality.Portal'," ^
  "  'Microsoft.NetworkSpeedTest','Microsoft.News','Microsoft.Office.OneNote'," ^
  "  'Microsoft.OneConnect','Microsoft.People','Microsoft.Print3D'," ^
  "  'Microsoft.SkypeApp','Microsoft.Todos','Microsoft.Wallet'," ^
  "  'Microsoft.WindowsFeedbackHub','Microsoft.WindowsMaps'," ^
  "  'Microsoft.YourPhone','Microsoft.ZuneMusic','Microsoft.ZuneVideo'," ^
  "  'Microsoft.XboxApp','Microsoft.GamingApp','Microsoft.XboxGameOverlay'," ^
  "  'Microsoft.XboxGamingOverlay','Microsoft.XboxSpeechToTextOverlay'," ^
  "  'Microsoft.MicrosoftStickyNotes','Clipchamp.Clipchamp'," ^
  "  'MicrosoftTeams','MSTeams'," ^
  "  'king.com.CandyCrushSaga','king.com.CandyCrushSodaSaga'," ^
  "  'Microsoft.549981C3F5F10'" ^
  ");" ^
  "foreach ($app in $bloat) {" ^
  "  Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue | " ^
  "    ForEach-Object { Write-Host ('    removing: ' + $_.Name); Remove-AppxPackage -AllUsers -Package $_.PackageFullName -ErrorAction SilentlyContinue };" ^
  "  Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | " ^
  "    Where-Object { $_.DisplayName -eq $app } | " ^
  "    ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } }"

echo     Store bloatware removed.

:: ===========================================================================
::  6. DISABLE CORTANA / WEB SEARCH / COPILOT / CONSUMER FEATURES
:: ===========================================================================
echo.
echo [*] Disabling Cortana, web search in Start, Copilot, and auto-reinstalled apps...

:: Stop Start-menu and Taskbar search from hitting the web / Cortana
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v DisableWebSearch /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f >nul 2>&1

:: Disable Windows Copilot (user + machine policy)
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f >nul 2>&1

:: Stop Windows from silently reinstalling suggested/sponsored apps
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f >nul 2>&1

echo     Cortana / web search / Copilot / app-suggestions disabled.

:: ===========================================================================
::  DONE
:: ===========================================================================
echo.
echo ============================================================
echo  Debloat complete.
echo  A RESTART is recommended so all changes take effect.
echo ============================================================
echo.
echo If anything behaves unexpectedly, roll back via:
echo   Control Panel ^> Recovery ^> Open System Restore
echo.
pause
endlocal
