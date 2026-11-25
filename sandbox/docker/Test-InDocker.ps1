# Runs inside a Linux PowerShell container. Windows-only pieces (registry, powercfg)
# are replaced with in-memory fakes; the real Optimize/Revert scripts run unmodified.
$ErrorActionPreference = 'Continue'

# --- Fake Windows environment ---
$env:APPDATA      = '/home/fake/AppData/Roaming'
$env:LOCALAPPDATA = '/home/fake/AppData/Local'
$global:FakeReg = @{}
$global:FakeUsb = @{ AC = 1; DC = 1 }
$global:FakeReg['HKCU:\Control Panel\Mouse|MouseSpeed']      = '1'
$global:FakeReg['HKCU:\Control Panel\Mouse|MouseThreshold1'] = '6'
$global:FakeReg['HKCU:\Control Panel\Mouse|MouseThreshold2'] = '10'
$global:FakeReg['HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad|AAPThreshold'] = 2

function global:Test-Path { param([Parameter(Position=0)]$Path)
    if ("$Path" -like 'HKCU:*') { return $true }
    Microsoft.PowerShell.Management\Test-Path -Path $Path }
function global:New-Item { param([Parameter(Position=0)]$Path, $ItemType, [switch]$Force)
    if ("$Path" -like 'HKCU:*') { return }
    if ($ItemType) { Microsoft.PowerShell.Management\New-Item -Path $Path -ItemType $ItemType -Force:$Force }
    else { Microsoft.PowerShell.Management\New-Item -Path $Path -Force:$Force } }
function global:Get-ItemProperty { param($Path, $Name, $ErrorAction)
    $k = "$Path|$Name"
    if ($global:FakeReg.ContainsKey($k)) { [pscustomobject]@{ $Name = $global:FakeReg[$k] } } }
function global:Set-ItemProperty { param($Path, $Name, $Value, $Type)
    $global:FakeReg["$Path|$Name"] = $Value }
function global:Remove-ItemProperty { param($Path, $Name, $ErrorAction)
    $global:FakeReg.Remove("$Path|$Name") }
function global:powercfg {
    $a = $args
    switch ($a[0]) {
        '/getactivescheme'  { 'Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)' }
        '/setacvalueindex'  { $global:FakeUsb.AC = [int]$a[4] }
        '/setdcvalueindex'  { $global:FakeUsb.DC = [int]$a[4] }
        default { } } }

# --- Fake Minecraft settings file (new GDK location) ---
$optDir = "$env:APPDATA/Minecraft Bedrock/Users/1234/games/com.mojang/minecraftpe"
Microsoft.PowerShell.Management\New-Item -ItemType Directory -Force $optDir | Out-Null
$opt = "$optDir/options.txt"
@('gfx_viewdistance:320','gfx_fancygraphics:1','gfx_smoothlighting:1','gfx_vsync:1','gfx_msaa:4','mp_username:Steve','ctrl_sensitivity2:0.5') | Set-Content $opt -Encoding ASCII
$optOriginal = Get-Content $opt -Raw

# Writable copy of the mod
Copy-Item /mod /tmp/modtest -Recurse -Force
Remove-Item /tmp/modtest/backup -Recurse -Force -ErrorAction SilentlyContinue

$results = @()
function Check($name, $actual, $expected) {
    $ok = "$actual" -eq "$expected"
    $script:results += ('{0}  {1}  (got "{2}", expected "{3}")' -f ($(if ($ok) {'PASS'} else {'FAIL'})), $name, $actual, $expected) }
function Get-FakeReg($p, $n) { $global:FakeReg["$p|$n"] }
function Get-Opt($k) { ((Get-Content $opt) | Where-Object { $_ -like "${k}:*" }) -replace '^[^:]*:' }
$tp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad'
$ms = 'HKCU:\Control Panel\Mouse'

function Run-Mode($m) { Write-Host "`n########## OPTIMIZER: $m ##########"; & /tmp/modtest/Optimize-Minecraft.ps1 -InputMode $m }
function Check-Common($m) {
    Check 'Game Mode on'           (Get-FakeReg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') 1
    Check 'GameDVR off'            (Get-FakeReg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled') 0
    Check 'App capture off'        (Get-FakeReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled') 0
    Check 'Chosen mode saved'      (Get-Content /tmp/modtest/backup/mode.txt) $m
    Check 'options still optimized' (Get-Opt 'gfx_viewdistance') 128
}

# --- 1. Laptop keyboard + touchpad ---
Run-Mode Laptop
$results += '=== MODE: Laptop keyboard + touchpad ==='
Check 'Touchpad never ignores clicks'  (Get-FakeReg $tp 'AAPThreshold') 0
Check 'Touchpad-with-mouse untouched'  ($null -eq (Get-FakeReg $tp 'LeaveOnWithMouse')) True
Check 'Mouse accel off'                (Get-FakeReg $ms 'MouseSpeed') 0
Check 'MouseThreshold1 off'            (Get-FakeReg $ms 'MouseThreshold1') 0
Check 'MouseThreshold2 off'            (Get-FakeReg $ms 'MouseThreshold2') 0
Check 'USB suspend untouched'          $global:FakeUsb.AC 1
Check-Common Laptop
Check 'options fancygraphics'    (Get-Opt 'gfx_fancygraphics') 0
Check 'options smoothlighting'   (Get-Opt 'gfx_smoothlighting') 0
Check 'options vsync'            (Get-Opt 'gfx_vsync') 0
Check 'options msaa'             (Get-Opt 'gfx_msaa') 1
Check 'options username kept'    (Get-Opt 'mp_username') 'Steve'
Check 'options sensitivity kept' (Get-Opt 'ctrl_sensitivity2') 0.5
Check 'options line count same'  (Get-Content $opt).Count 7
Check 'registry backup exists'   (Microsoft.PowerShell.Management\Test-Path /tmp/modtest/backup/registry.json) True
Check 'options backup exists'    (Microsoft.PowerShell.Management\Test-Path /tmp/modtest/backup/options_1.txt) True

# --- 2. Switch to USB mouse + keyboard ---
Run-Mode UsbMouseKeyboard
$results += '=== MODE: USB mouse + keyboard (switched from Laptop) ==='
Check 'Touchpad palm setting restored' (Get-FakeReg $tp 'AAPThreshold') 2
Check 'Touchpad off with USB mouse'    (Get-FakeReg $tp 'LeaveOnWithMouse') 0
Check 'Mouse accel off'                (Get-FakeReg $ms 'MouseSpeed') 0
Check 'USB suspend AC off'             $global:FakeUsb.AC 0
Check 'USB suspend DC off'             $global:FakeUsb.DC 0
Check-Common UsbMouseKeyboard

# --- 3. Switch to controller ---
Run-Mode Controller
$results += '=== MODE: USB controller (switched from USB mouse) ==='
Check 'Touchpad palm setting original' (Get-FakeReg $tp 'AAPThreshold') 2
Check 'Touchpad-with-mouse restored'   ($null -eq (Get-FakeReg $tp 'LeaveOnWithMouse')) True
Check 'Mouse accel restored'           (Get-FakeReg $ms 'MouseSpeed') 1
Check 'MouseThreshold1 restored'       (Get-FakeReg $ms 'MouseThreshold1') 6
Check 'MouseThreshold2 restored'       (Get-FakeReg $ms 'MouseThreshold2') 10
Check 'USB suspend still off'          $global:FakeUsb.AC 0
Check-Common Controller

# --- 4. Back to laptop: USB suspend goes back to default ---
Run-Mode Laptop
$results += '=== MODE: Laptop again (switched from Controller) ==='
Check 'USB suspend AC restored'        $global:FakeUsb.AC 1
Check 'USB suspend DC restored'        $global:FakeUsb.DC 1
Check 'Touchpad never ignores clicks'  (Get-FakeReg $tp 'AAPThreshold') 0
Check-Common Laptop

# --- 5. Menu with bad input must not crash or change anything ---
$beforeMenu = ($global:FakeReg.GetEnumerator() | Sort-Object Name | Out-String)
$results += '=== MENU: no valid answer ==='
$menuOut = 'x', '', '9', 'abc', '' | pwsh -NoProfile -Command '& /tmp/modtest/Optimize-Minecraft.ps1' *>&1 | Out-String
Check 'Gives up cleanly'               ($menuOut -match 'No valid choice') True

# --- 6. Switch to USB again, then REVERT everything ---
Run-Mode UsbMouseKeyboard | Out-Null
Write-Host "`n########## RUNNING REVERT ##########"
& /tmp/modtest/Revert-Minecraft.ps1
$results += '=== REVERT (after runs in every mode) ==='
Check 'Touchpad restored'        (Get-FakeReg $tp 'AAPThreshold') 2
Check 'LeaveOnWithMouse removed' ($null -eq (Get-FakeReg $tp 'LeaveOnWithMouse')) True
Check 'MouseSpeed restored'      (Get-FakeReg $ms 'MouseSpeed') 1
Check 'MouseThreshold1 restored' (Get-FakeReg $ms 'MouseThreshold1') 6
Check 'GameMode key removed'     ($null -eq (Get-FakeReg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled')) True
Check 'USB suspend AC restored'  $global:FakeUsb.AC 1
Check 'USB suspend DC restored'  $global:FakeUsb.DC 1
Check 'options.txt restored'     ((Get-Content $opt -Raw) -eq $optOriginal) True

$fails = @($results | Where-Object { $_ -like 'FAIL*' }).Count
Write-Host "`n########## RESULTS ##########"
$results | ForEach-Object { Write-Host $_ }
Write-Host "=== $fails failure(s) ==="
exit $fails
