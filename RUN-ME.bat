@echo off
echo Close Minecraft before continuing!
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-Minecraft.ps1"
pause
