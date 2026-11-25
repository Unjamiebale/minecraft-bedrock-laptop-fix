# Runs inside Windows Sandbox: applies the optimizer, checks results, reverts, checks again.
$ErrorActionPreference = 'Continue'
$desk = 'C:\Users\WDAGUtilityAccount\Desktop'
$out  = Join-Path $desk 'results\results.txt'
Start-Transcript -Path (Join-Path $desk 'results\transcript.txt') -Force | Out-Null

# Writable copy of the mod (mapped folder is read-only)
Copy-Item (Join-Path $desk 'mod') C:\modtest -Recurse -Force
Remove-Item C:\modtest\backup -Recurse -Force -ErrorAction SilentlyContinue

# Fake Minecraft settings file (Minecraft isn't installed in the sandbox)
$optDir = "$env:APPDATA\Minecraft Bedrock\Users\1234\games\com.mojang\minecraftpe"
New-Item -ItemType Directory -Force $optDir | Out-Null
$opt = Join-Path $optDir 'options.txt'
@('gfx_viewdistance:320','gfx_fancygraphics:1','gfx_smoothlighting:1','gfx_vsync:1','gfx_msaa:4','mp_username:Steve','ctrl_sensitivity2:0.5') | Set-Content $opt -Encoding ASCII
$optOriginal = Get-Content $opt -Raw

$results = @()
function Check($name, $actual, $expected) {
    $ok = "$actual" -eq "$expected"
    $script:results += ('{0}  {1}  (got "{2}", expected "{3}")' -f ($(if ($ok) {'PASS'} else {'FAIL'})), $name, $actual, $expected)
}
function Get-Reg($p, $n) { (Get-ItemProperty -Path $p -Name $n -ErrorAction SilentlyContinue).$n }
$tp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad'
$ms = 'HKCU:\Control Panel\Mouse'
$beforeTp = Get-Reg $tp 'AAPThreshold'
$beforeMs = Get-Reg $ms 'MouseSpeed'
$usb = '2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
function Get-UsbAc { $s = (powercfg /getactivescheme) -replace '.*GUID:\s*([0-9a-f-]+).*', '$1'
    $q = powercfg /query $s 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
    $line = $q | Where-Object { $_ -match 'Current AC Power Setting Index' }; if ($line) { [int]($line -replace '.*0x', '0x') } else { 'n/a' } }
$beforeUsb = Get-UsbAc

$results += '=== APPLY ==='
& powershell -NoProfile -ExecutionPolicy Bypass -File C:\modtest\Optimize-Minecraft.ps1 -InputMode Laptop *>&1 | Out-String | Add-Content (Join-Path $desk 'results\optimizer-output.txt')
Check 'Touchpad AAPThreshold'   (Get-Reg $tp 'AAPThreshold') 0
Check 'MouseSpeed'              (Get-Reg $ms 'MouseSpeed') 0
Check 'MouseThreshold1'         (Get-Reg $ms 'MouseThreshold1') 0
Check 'Game Mode'               (Get-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') 1
Check 'GameDVR off'             (Get-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled') 0
Check 'USB selective suspend'   (Get-UsbAc) 0
$o = Get-Content $opt
Check 'options viewdistance'    (($o | ? { $_ -like 'gfx_viewdistance:*' }) -replace '.*:') 128
Check 'options fancygraphics'   (($o | ? { $_ -like 'gfx_fancygraphics:*' }) -replace '.*:') 0
Check 'options vsync'           (($o | ? { $_ -like 'gfx_vsync:*' }) -replace '.*:') 0
Check 'options username kept'   (($o | ? { $_ -like 'mp_username:*' }) -replace '.*:') 'Steve'
Check 'backup created'          (Test-Path C:\modtest\backup\registry.json) True

$results += '=== REVERT ==='
& powershell -NoProfile -ExecutionPolicy Bypass -File C:\modtest\Revert-Minecraft.ps1 *>&1 | Out-String | Add-Content (Join-Path $desk 'results\revert-output.txt')
Check 'Touchpad restored'       (Get-Reg $tp 'AAPThreshold') $beforeTp
Check 'MouseSpeed restored'     (Get-Reg $ms 'MouseSpeed') $beforeMs
Check 'USB suspend restored'    (Get-UsbAc) $beforeUsb
Check 'options.txt restored'    ((Get-Content $opt -Raw) -eq $optOriginal) True

$fails = @($results | ? { $_ -like 'FAIL*' }).Count
$results += "=== $fails failure(s) ==="
$results | Set-Content $out
Stop-Transcript | Out-Null
'finished' | Set-Content (Join-Path $desk 'results\DONE')
