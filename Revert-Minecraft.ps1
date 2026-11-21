# Undoes everything Optimize-Minecraft.ps1 changed, using .\backup
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$backup = Join-Path $root 'backup'
if (-not (Test-Path $backup)) { Write-Host "No backup folder found - nothing to revert."; return }

$regFile = Join-Path $backup 'registry.json'
if (Test-Path $regFile) {
    foreach ($r in @(Get-Content $regFile -Raw | ConvertFrom-Json)) {
        if ($r.Existed) { Set-ItemProperty -Path $r.Path -Name $r.Name -Value $r.Old -Type $r.Type }
        else { Remove-ItemProperty -Path $r.Path -Name $r.Name -ErrorAction SilentlyContinue }
    }
    Write-Host "[OK] Registry settings restored"
}

$scheme = Join-Path $backup 'powerscheme.txt'
if (Test-Path $scheme) {
    $s = (Get-Content $scheme).Trim()
    powercfg /setacvalueindex $s 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 2>$null
    powercfg /setdcvalueindex $s 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 2>$null
    powercfg /setactive $s 2>$null
    Write-Host "[OK] USB selective suspend re-enabled"
}

Get-ChildItem $backup -Filter 'options_*.path' | ForEach-Object {
    $target = (Get-Content $_.FullName).Trim()
    $src = $_.FullName -replace '\.path$', '.txt'
    if (Test-Path $src) { Copy-Item $src $target -Force; Write-Host "[OK] Restored $target" }
}
Write-Host "`nReverted. Restart the laptop."
