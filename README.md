# Minecraft Bedrock Laptop Fix

Fixes **mouse/touchpad clicks not registering** in Minecraft Bedrock (Windows) and squeezes
more FPS out of older, low-end laptops.

> **This is not a code mod.** Minecraft Bedrock has no mod loader, and tools that inject
> code into the game break with every update. Instead, this changes the Windows and
> in-game settings that actually cause dropped clicks and low FPS. It works on any
> Bedrock version, and everything can be undone.

---

## Why clicks don't register

The most common cause on laptops is **Windows touchpad palm rejection**: Windows
deliberately ignores touchpad clicks and taps *while a key is held down*. In Minecraft
you're almost always holding W, A, S or D, so your clicks get thrown away.

Other causes this fixes:

- **USB selective suspend** – Windows puts USB mice/controllers to sleep to save power, and they miss inputs while waking up.
- **Enhanced pointer precision** (mouse acceleration) – makes aiming inconsistent.
- **Touchpad + USB mouse both active** – your palm brushing the touchpad causes stray inputs.

---

## Install

1. Download this repo: click the green **Code** button → **Download ZIP**, then
   right-click the ZIP → **Extract All**.
2. **Close Minecraft** (otherwise it overwrites the new settings when it exits).
3. If you've never launched Minecraft on this PC, launch it once and close it, so its
   settings file exists.
4. Right-click **`RUN-ME.bat`** → **Run as administrator** → click **Yes**.
   (Administrator is only needed for the USB power setting; everything else works without it.)
5. Choose what you play with:

   ```
   === INPUT DEVICE ===
     [1] Controller (USB)
     [2] Mouse and keyboard (USB)  (default)
     [3] Built-in laptop keyboard and touchpad
   What will you play Minecraft with? (1/2/3, Enter = 2)
   ```

6. **Restart the laptop** so the mouse/touchpad changes fully apply.

If Windows shows a blue **"Windows protected your PC"** box, click **More info** → **Run anyway**.

---

## What each choice does

| Setting | 1. Controller (USB) | 2. Mouse + keyboard (USB) | 3. Laptop keyboard + touchpad |
|---|:-:|:-:|:-:|
| Touchpad never ignores clicks while keys are held | | | ✅ |
| Touchpad turns off while a USB mouse is plugged in | | ✅ | |
| Mouse acceleration off | | ✅ | ✅ |
| USB power saving off (no dropped USB inputs) | ✅ | ✅ | |
| Performance tweaks (below) | ✅ | ✅ | ✅ |

**Switching devices:** just run `RUN-ME.bat` again and pick a different number. Settings
the previous choice needed are put back first, so nothing piles up.

### Performance tweaks (all choices)

**Windows**
- Game Mode on
- Xbox Game Bar background recording off
- Minecraft set to use the high-performance graphics card (on laptops with two GPUs)

**Minecraft video settings** (only settings already in your file are changed; keybinds,
sensitivity, username etc. are left alone)

| Setting | New value |
|---|---|
| Render distance | 8 chunks |
| Particle distance | Low |
| Fancy graphics | Off |
| Smooth lighting | Off |
| Fancy skies | Off |
| Transparent leaves | Off |
| Antialiasing | Off |
| VSync | Off |
| Paper doll | Hidden |
| Field of view | 70 |

Want a different render distance? Open `Optimize-Minecraft.ps1` in Notepad and change
`'gfx_viewdistance' = '128'` (16 blocks per chunk: `96` = 6 chunks is faster, `192` = 12 chunks looks better).

---

## Undo everything

Run **`REVERT.bat`**, then restart. It restores your original registry values, power
setting and Minecraft `options.txt` from the `backup` folder that `RUN-ME.bat` created.

> Don't delete the `backup` folder if you might want to undo later.

Note: Revert sets USB power saving back to **on** (the Windows default), even if you had
it off before.

---

## Still dropping clicks?

1. **Check the touchpad setting:** Settings → Bluetooth & devices → Touchpad → Taps →
   **Touchpad sensitivity** should be **Most sensitive**.
2. **Dell / manufacturer touchpad software** (e.g. *Dell Touchpad*, *Dell Peripheral
   Manager*, Synaptics, ELAN) can override Windows. Open it and turn off any
   "palm detection" / "disable while typing" option.
3. **Try a USB mouse.** If a USB mouse works and the touchpad doesn't, it's the touchpad.
4. **Alt-Tab out and back in.** Bedrock occasionally loses mouse capture after a pop-up
   or notification.
5. **Update drivers:** Windows Update → Advanced options → Optional updates (touchpad
   and graphics drivers).

---

## Running without the menu

```powershell
powershell -ExecutionPolicy Bypass -File .\Optimize-Minecraft.ps1 -InputMode UsbMouseKeyboard
```

`-InputMode` accepts `Controller`, `UsbMouseKeyboard` or `Laptop`.

---

## Files

| File | Purpose |
|---|---|
| `RUN-ME.bat` | Starts the optimizer (shows the input device menu) |
| `REVERT.bat` | Undoes everything |
| `Optimize-Minecraft.ps1` | The optimizer script |
| `Revert-Minecraft.ps1` | The undo script |
| `backup/` | Created on first run – your original settings (not uploaded to Git) |
| `sandbox/docker/Test-InDocker.ps1` | Automated test (see below) |
| `sandbox/ModTest.wsb` | Windows Sandbox test config |

## Testing (for developers)

The Docker test runs the real scripts in a Linux PowerShell container with a **fake**
registry and power settings, and checks every input mode, switching between modes, the
menu (default and bad input) and revert:

```powershell
docker run --rm --network none -v "${PWD}:/mod:ro" mcr.microsoft.com/powershell:latest pwsh -NoProfile -File /mod/sandbox/docker/Test-InDocker.ps1
```

Exit code `0` means every check passed. Because Windows settings are faked, this proves
the logic, not that Windows applies the changes; test on a real laptop too.

`sandbox/ModTest.wsb` does a similar run in **Windows Sandbox** against the real registry
(needs the *Windows Sandbox* feature enabled), writing results to `sandbox/results/`.

## Notes

- Minecraft Bedrock settings are found in both the new location
  (`%APPDATA%\Minecraft Bedrock\Users\...`) and the older Microsoft Store location.
- Only your user's settings are changed (`HKCU`), plus the active power plan's USB setting.
- Not affiliated with Mojang or Microsoft.
