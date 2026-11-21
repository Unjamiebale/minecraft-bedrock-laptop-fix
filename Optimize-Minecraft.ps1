# Minecraft Bedrock laptop optimizer + mouse input fix
# Run via RUN-ME.bat (right-click > Run as administrator for the power tweaks).
# Everything changed is backed up to .\backup so Revert-Minecraft.ps1 can undo it.

$ErrorActionPreference = 'Continue'
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$backup = Join-Path $root 'backup'
New-Item -ItemType Directory -Force $backup | Out-Null
$regBackupFile = Join-Path $backup 'registry.json'
$regBackup = @()
if (Test-Path $regBackupFile) { $regBackup = @(Get-Content $regBackupFile -Raw | ConvertFrom-Json) }

function Set-Reg($path, $name, $value, $type = 'DWord') {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    $old = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name
    if (-not ($script:regBackup | Where-Object { $_.Path -eq $path -and $_.Name -eq $name })) {
        $script:regBackup += [pscustomobject]@{ Path = $path; Name = $name; Old = $old; Existed = ($null -ne $old); Type = $type }
    }
    Set-ItemProperty -Path $path -Name $name -Value $value -Type $type
}

Write-Host "`n=== MOUSE INPUT FIXES ===" -ForegroundColor Cyan

# 1. Touchpad palm rejection: Windows ignores touchpad clicks/taps while keys are held
#    (i.e. while you're walking with WASD). 0 = "Most sensitive" = never ignore.
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' 'AAPThreshold' 0
Write-Host " [OK] Touchpad: clicks no longer ignored while keys are held"

# 2. Enhanced pointer precision (mouse acceleration) off - makes aiming consistent
Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed'      '0' 'String'
Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
Write-Host " [OK] Mouse acceleration (enhanced pointer precision) disabled"

# 3. USB selective suspend off - stops USB mice from 'sleeping' and dropping inputs
$scheme = (powercfg /getactivescheme) -replace '.*GUID:\s*([0-9a-f-]+).*', '$1'
"$scheme" | Set-Content (Join-Path $backup 'powerscheme.txt')
powercfg /setacvalueindex $scheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /setdcvalueindex $scheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /setactive $scheme 2>$null
Write-Host " [OK] USB selective suspend disabled (if this failed, re-run as administrator)"

Write-Host "`n=== WINDOWS PERFORMANCE ===" -ForegroundColor Cyan

# Game Mode on
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'   1
Write-Host " [OK] Game Mode enabled"

# Game Bar background recording off (eats CPU/GPU on weak laptops)
Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
Write-Host " [OK] Xbox Game Bar background recording disabled"

# Force high-performance GPU for Minecraft (matters on Dells with Intel + NVIDIA/AMD)
$exes = @()
$exes += Get-ChildItem 'C:\XboxGames\Minecraft for Windows\Content' -Filter 'Minecraft.Windows.exe' -Recurse -ErrorAction SilentlyContinue
$exes += Get-ChildItem 'C:\Program Files\WindowsApps' -Filter 'Minecraft.Windows.exe' -Recurse -ErrorAction SilentlyContinue
foreach ($e in $exes | Select-Object -Unique FullName) {
    Set-Reg 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' $e.FullName 'GpuPreference=2;' 'String'
    Write-Host " [OK] High-performance GPU set for $($e.FullName)"
}
if (-not $exes) { Write-Host " [--] Minecraft.Windows.exe not found; set GPU manually: Settings > Display > Graphics" -ForegroundColor Yellow }

$script:regBackup | ConvertTo-Json | Set-Content $regBackupFile

Write-Host "`n=== IN-GAME SETTINGS (options.txt) ===" -ForegroundColor Cyan
Write-Host " Close Minecraft first or it will overwrite these!" -ForegroundColor Yellow

# New (GDK) builds store data in %APPDATA%\Minecraft Bedrock; older (UWP) in LocalAppData\Packages
$optionFiles = @()
$optionFiles += Get-ChildItem "$env:APPDATA\Minecraft Bedrock\Users" -Filter options.txt -Recurse -ErrorAction SilentlyContinue
$uwp = "$env:LOCALAPPDATA\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang\minecraftpe\options.txt"
if (Test-Path $uwp) { $optionFiles += Get-Item $uwp }

# Only keys that already exist in the file are changed (safe across versions)
$tweaks = [ordered]@{
    'gfx_viewdistance'          = '128'  # 8 chunks
    'gfx_particleviewdistance'  = '32'
    'gfx_fancygraphics'         = '0'
    'gfx_smoothlighting'        = '0'
    'gfx_fancyskies'            = '0'
    'gfx_transparentleaves'     = '0'
    'gfx_msaa'                  = '1'
    'gfx_texel_aa_2'            = '0'
    'gfx_vsync'                 = '0'
    'gfx_hidepaperdoll'         = '1'
    'gfx_field_of_view'         = '70'
    'gfx_safe_zone_all'         = '1'
}

if (-not $optionFiles) { Write-Host " [--] No options.txt found. Launch Minecraft once, close it, re-run." -ForegroundColor Yellow }
$i = 0
foreach ($f in $optionFiles) {
    $i++
    Copy-Item $f.FullName (Join-Path $backup "options_$i.txt") -Force
    "$($f.FullName)" | Set-Content (Join-Path $backup "options_$i.path")
    $lines = Get-Content $f.FullName
    $changed = 0
    $lines = foreach ($l in $lines) {
        $k = ($l -split ':', 2)[0]
        if ($tweaks.Contains($k)) { $changed++; "${k}:$($tweaks[$k])" } else { $l }
    }
    Set-Content -Path $f.FullName -Value $lines -Encoding ASCII
    Write-Host " [OK] $changed settings tuned in $($f.FullName)"
}

Write-Host "`nDone. RESTART the laptop so the mouse/touchpad changes fully apply." -ForegroundColor Green
Write-Host "To undo everything: run REVERT.bat`n"
