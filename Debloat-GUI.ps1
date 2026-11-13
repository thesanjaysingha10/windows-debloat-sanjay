<#
    Windows Debloater - GUI edition
    ---------------------------------
    A clickable WinForms interface to debloat Windows and UNDO it again.

    Each category can be toggled on/off. "Run Selected" applies the debloat
    actions; "Undo Selected" reverses them (re-enables services/tasks, clears
    policies, reinstalls Store apps, etc.).

    HOW TO RUN (must be elevated):
      Right-click  ->  Run with PowerShell  (accept the admin prompt), OR
      from an admin PowerShell:
        powershell -ExecutionPolicy Bypass -File .\Debloat-GUI.ps1

    NOTE: Windows Defender is never touched. Only OEM *trial* AV is removed,
    and that removal cannot be auto-undone (reinstall from the vendor if wanted).
#>

# --- Self-elevate to Administrator ------------------------------------------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ============================================================================
#  DATA: the Store apps we treat as bloat (safe list; essentials excluded)
# ============================================================================
$BloatApps = @(
    'Microsoft.3DBuilder','Microsoft.549981C3F5F10','Microsoft.BingNews',
    'Microsoft.BingWeather','Microsoft.BingFinance','Microsoft.BingSports',
    'Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.Messaging',
    'Microsoft.Microsoft3DViewer','Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftSolitaireCollection','Microsoft.MixedReality.Portal',
    'Microsoft.NetworkSpeedTest','Microsoft.News','Microsoft.Office.OneNote',
    'Microsoft.OneConnect','Microsoft.People','Microsoft.Print3D',
    'Microsoft.SkypeApp','Microsoft.Todos','Microsoft.Wallet',
    'Microsoft.WindowsFeedbackHub','Microsoft.WindowsMaps',
    'Microsoft.YourPhone','Microsoft.ZuneMusic','Microsoft.ZuneVideo',
    'Microsoft.XboxApp','Microsoft.GamingApp','Microsoft.XboxGameOverlay',
    'Microsoft.XboxGamingOverlay','Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.MicrosoftStickyNotes','Clipchamp.Clipchamp',
    'MicrosoftTeams','MSTeams',
    'king.com.CandyCrushSaga','king.com.CandyCrushSodaSaga'
)

$TelemetryTasks = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
    '\Microsoft\Windows\Application Experience\StartupAppTask',
    '\Microsoft\Windows\Autochk\Proxy',
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
    '\Microsoft\Windows\Feedback\Siuf\DmClient',
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
    '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
)

# ============================================================================
#  GUI
# ============================================================================
$form               = New-Object System.Windows.Forms.Form
$form.Text          = 'Windows Debloater'
$form.Size          = New-Object System.Drawing.Size(640, 620)
$form.StartPosition = 'CenterScreen'
$form.Font          = New-Object System.Drawing.Font('Segoe UI', 9)

$title              = New-Object System.Windows.Forms.Label
$title.Text         = 'Windows Debloater'
$title.Font         = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$title.Location     = New-Object System.Drawing.Point(20, 15)
$title.AutoSize     = $true
$form.Controls.Add($title)

$subtitle           = New-Object System.Windows.Forms.Label
$subtitle.Text      = 'Tick what to change, then Run or Undo. Defender is never removed.'
$subtitle.Location  = New-Object System.Drawing.Point(22, 48)
$subtitle.AutoSize  = $true
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($subtitle)

# --- Category checkboxes ----------------------------------------------------
$grp            = New-Object System.Windows.Forms.GroupBox
$grp.Text       = 'Categories'
$grp.Location   = New-Object System.Drawing.Point(20, 80)
$grp.Size       = New-Object System.Drawing.Size(585, 190)
$form.Controls.Add($grp)

$cats = [ordered]@{
    OneDrive   = 'Remove OneDrive'
    Telemetry  = 'Disable telemetry tasks + services'
    StoreApps  = 'Remove preinstalled Store-app bloatware'
    Cortana    = 'Disable Cortana / web search / Copilot / app suggestions'
    TrialAV    = 'Uninstall OEM trial antivirus (McAfee/Norton) - cannot be auto-undone'
}
$checkboxes = @{}
$y = 25
foreach ($key in $cats.Keys) {
    $cb          = New-Object System.Windows.Forms.CheckBox
    $cb.Text     = $cats[$key]
    $cb.Location = New-Object System.Drawing.Point(15, $y)
    $cb.Size     = New-Object System.Drawing.Size(555, 24)
    $cb.Checked  = ($key -ne 'TrialAV')   # AV off by default (irreversible)
    $grp.Controls.Add($cb)
    $checkboxes[$key] = $cb
    $y += 30
}

# --- Log box ----------------------------------------------------------------
$log            = New-Object System.Windows.Forms.TextBox
$log.Multiline  = $true
$log.ScrollBars = 'Vertical'
$log.ReadOnly   = $true
$log.Location   = New-Object System.Drawing.Point(20, 285)
$log.Size       = New-Object System.Drawing.Size(585, 215)
$log.BackColor  = [System.Drawing.Color]::FromArgb(30,30,30)
$log.ForeColor  = [System.Drawing.Color]::Gainsboro
$log.Font       = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($log)

function Write-Log($msg, $color='Gainsboro') {
    $log.AppendText("$msg`r`n")
    $log.SelectionStart = $log.Text.Length
    $log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# ============================================================================
#  ACTIONS
# ============================================================================
function New-RestorePoint {
    Write-Log '[*] Creating system restore point...'
    try {
        Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Debloat-GUI' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log '    restore point created.'
    } catch {
        Write-Log '    (skipped - Windows limits one per ~24h, or disabled. Make one manually if needed.)'
    }
}

# ---- DEBLOAT ---------------------------------------------------------------
function Do-OneDrive {
    Write-Log '[*] Removing OneDrive...'
    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    foreach ($p in @("$env:SystemRoot\System32\OneDriveSetup.exe","$env:SystemRoot\SysWOW64\OneDriveSetup.exe")) {
        if (Test-Path $p) { Start-Process $p '/uninstall' -Wait -ErrorAction SilentlyContinue }
    }
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f | Out-Null
    Write-Log '    OneDrive removed (your files in %UserProfile%\OneDrive are untouched).'
}
function Undo-OneDrive {
    Write-Log '[*] Restoring OneDrive...'
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /f 2>$null | Out-Null
    $setup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (-not (Test-Path $setup)) { $setup = "$env:SystemRoot\System32\OneDriveSetup.exe" }
    if (Test-Path $setup) { Start-Process $setup -ErrorAction SilentlyContinue; Write-Log '    OneDrive reinstaller launched.' }
    else { Write-Log '    OneDriveSetup.exe not found - reinstall from microsoft.com/microsoft-365/onedrive.' }
}

function Do-Telemetry {
    Write-Log '[*] Disabling telemetry tasks + services...'
    foreach ($t in $TelemetryTasks) { schtasks /change /tn $t /disable 2>$null | Out-Null }
    foreach ($s in @('DiagTrack','dmwappushservice')) {
        Stop-Service $s -Force -ErrorAction SilentlyContinue
        Set-Service  $s -StartupType Disabled -ErrorAction SilentlyContinue
    }
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    Write-Log '    telemetry disabled.'
}
function Undo-Telemetry {
    Write-Log '[*] Re-enabling telemetry tasks + services...'
    foreach ($t in $TelemetryTasks) { schtasks /change /tn $t /enable 2>$null | Out-Null }
    foreach ($s in @('DiagTrack','dmwappushservice')) {
        Set-Service   $s -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service $s -ErrorAction SilentlyContinue
    }
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /f 2>$null | Out-Null
    reg add    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 1 /f | Out-Null
    Write-Log '    telemetry restored to defaults.'
}

function Do-StoreApps {
    Write-Log '[*] Removing Store-app bloatware...'
    foreach ($app in $BloatApps) {
        Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log "    removing: $($_.Name)"
            Remove-AppxPackage -AllUsers -Package $_.PackageFullName -ErrorAction SilentlyContinue
        }
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $app } |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
    }
    Write-Log '    bloatware removed.'
}
function Undo-StoreApps {
    Write-Log '[*] Reinstalling removed Store apps (may take a minute)...'
    Get-AppxPackage -AllUsers | ForEach-Object {
        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
    }
    Write-Log '    re-registration attempted. Anything fully removed can be reinstalled from the Microsoft Store.'
}

function Do-Cortana {
    Write-Log '[*] Disabling Cortana / web search / Copilot / app suggestions...'
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v DisableWebSearch /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f | Out-Null
    Write-Log '    disabled.'
}
function Undo-Cortana {
    Write-Log '[*] Restoring Cortana / web search / Copilot / app suggestions...'
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /f 2>$null | Out-Null
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v DisableWebSearch /f 2>$null | Out-Null
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /f 2>$null | Out-Null
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /f 2>$null | Out-Null
    reg add    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 1 /f | Out-Null
    Write-Log '    restored to defaults.'
}

function Do-TrialAV {
    Write-Log '[*] Uninstalling OEM trial antivirus (Defender is left intact)...'
    $mc = "$env:ProgramFiles\McAfee\MSC\mcuihost.exe"
    if (Test-Path $mc) { Write-Log '    launching McAfee uninstaller...'; Start-Process $mc '/uninstall' -Wait -ErrorAction SilentlyContinue }
    $targets = 'McAfee','Norton Security','Norton 360','NortonLifeLock'
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $n=$_.DisplayName; $n -and ($targets | Where-Object { $n -like "*$_*" }) } |
        ForEach-Object {
            Write-Log "    uninstalling: $($_.DisplayName)"
            if ($_.QuietUninstallString) { cmd /c $_.QuietUninstallString }
            elseif ($_.UninstallString)  { Write-Log "      run manually: $($_.UninstallString)" }
        }
    Write-Log '    If a trial survives self-protection, use MCPR (McAfee) or Norton Remove and Reinstall.'
}

# ---- Button handlers -------------------------------------------------------
function Run-Selected([bool]$undo) {
    $verb = if ($undo) { 'UNDO' } else { 'RUN' }
    $msg  = if ($undo) { 'Reverse the selected changes?' } else { 'Apply the selected debloat changes?' }
    if ([System.Windows.Forms.MessageBox]::Show($msg, "Confirm $verb",
        'YesNo', 'Question') -ne 'Yes') { return }

    $log.Clear()
    if (-not $undo) { New-RestorePoint }

    if ($checkboxes['OneDrive'].Checked)  { if ($undo) { Undo-OneDrive }  else { Do-OneDrive } }
    if ($checkboxes['Telemetry'].Checked) { if ($undo) { Undo-Telemetry } else { Do-Telemetry } }
    if ($checkboxes['StoreApps'].Checked) { if ($undo) { Undo-StoreApps } else { Do-StoreApps } }
    if ($checkboxes['Cortana'].Checked)   { if ($undo) { Undo-Cortana }   else { Do-Cortana } }
    if ($checkboxes['TrialAV'].Checked) {
        if ($undo) { Write-Log '[!] Trial AV removal cannot be auto-undone - reinstall from the vendor if wanted.' }
        else { Do-TrialAV }
    }
    Write-Log ''
    Write-Log "=== $verb complete. A restart is recommended. ==="
}

# --- Buttons ----------------------------------------------------------------
$btnRun          = New-Object System.Windows.Forms.Button
$btnRun.Text     = 'Run Selected'
$btnRun.Size     = New-Object System.Drawing.Size(140, 38)
$btnRun.Location = New-Object System.Drawing.Point(20, 515)
$btnRun.BackColor= [System.Drawing.Color]::FromArgb(0,120,215)
$btnRun.ForeColor= [System.Drawing.Color]::White
$btnRun.FlatStyle= 'Flat'
$btnRun.Add_Click({ Run-Selected $false })
$form.Controls.Add($btnRun)

$btnUndo          = New-Object System.Windows.Forms.Button
$btnUndo.Text     = 'Undo Selected'
$btnUndo.Size     = New-Object System.Drawing.Size(140, 38)
$btnUndo.Location = New-Object System.Drawing.Point(170, 515)
$btnUndo.FlatStyle= 'Flat'
$btnUndo.Add_Click({ Run-Selected $true })
$form.Controls.Add($btnUndo)

$btnRestore          = New-Object System.Windows.Forms.Button
$btnRestore.Text     = 'Open System Restore'
$btnRestore.Size     = New-Object System.Drawing.Size(160, 38)
$btnRestore.Location = New-Object System.Drawing.Point(320, 515)
$btnRestore.FlatStyle= 'Flat'
$btnRestore.Add_Click({ Start-Process 'rstrui.exe' })
$form.Controls.Add($btnRestore)

$btnClose          = New-Object System.Windows.Forms.Button
$btnClose.Text     = 'Close'
$btnClose.Size     = New-Object System.Drawing.Size(100, 38)
$btnClose.Location = New-Object System.Drawing.Point(505, 515)
$btnClose.FlatStyle= 'Flat'
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

Write-Log 'Ready. Tick categories above, then click Run Selected or Undo Selected.'
Write-Log 'A restore point is created automatically before any Run.'
[void]$form.ShowDialog()
