# VIBE FAST

VIBE FAST is a desktop utility for mapping HID device buttons to custom hotkeys.

## Current scope

- Stable receiver / USB HID mapping is the main supported path.
- Some Bluetooth devices are supported only if they expose standard HID input to Windows.
- Config changes are saved automatically.
- Auto start uses the current user `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.

## Known limits

- `RawInput` can identify input, but it cannot truly swallow the original system media key.
- System reserved shortcuts such as `Alt + Space` may be intercepted by Windows first.
- Some Bluetooth devices expose audio or hands-free control instead of standard input events, so VIBE FAST cannot see them.

## Important files

- Main entry: `F:\CODE\FastKey\VibeFast.ahk`
- Frontend: `F:\CODE\FastKey\WebUI\index.html`
- Config: `F:\CODE\FastKey\config.ini`
- Debug log: `F:\CODE\FastKey\DevTools\rawinput_trace.log`
- Installer script: `F:\CODE\FastKey\VibeFastSetup.iss`

## Project layout

```text
FastKey/
- VibeFast.ahk
- VibeFastSetup.iss
- config.ini
- app_icon.ico
- app_icon.png
- Lib/
- WebUI/
- DevTools/
- Docs/
```

## Packaging

1. Compile `VibeFast.ahk` into `VibeFast.exe` with AutoHotkey v2.
2. Open `VibeFastSetup.iss` in Inno Setup.
3. Build the installer.

## Notes

- Mapping edits are auto-saved.
- `Start Interception` only starts the background interception flow.
- Keep text files in UTF-8 and avoid bulk overwrite operations with uncertain encodings.
