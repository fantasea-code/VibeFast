# VIBE FAST Handoff Brief

## Project summary

- Stack: AutoHotkey v2 + WebView2
- Main entry: `F:\CODE\VibeFast\VibeFast.ahk`
- Frontend: `F:\CODE\VibeFast\WebUI\index.html`
- Config: `F:\CODE\VibeFast\config.ini`

## Main conclusions

### Receiver mode is the mainline

`DJI Mic Mini` works best through the receiver path because it shows up as a standard HID device in `RawInput`.

### Bluetooth support depends on what Windows exposes

- If a Bluetooth device exposes standard HID input or media-control collections, VIBE FAST can often see it.
- If a Bluetooth device behaves like audio or hands-free control only, VIBE FAST usually cannot see device-level button events.

`Mic Mini` Bluetooth mode currently looks closer to the second case.

### RawInput has a hard limit

`RawInput` can identify the source device, but it cannot truly block the original system media key behavior.

## Current product direction

- Keep receiver mode stable.
- Keep config auto-save.
- Keep user-level auto start.
- Use backend-driven hotkey capture.

## Do not promise these as core features

- Fully swallowing system media keys.
- Supporting every Bluetooth device.
- Competing with vendor firmware or driver level remapping depth.

## Key files

- `VibeFast.ahk`: main logic
- `WebUI/index.html`: frontend
- `DevTools/rawinput_trace.log`: debug log
- `VibeFastSetup.iss`: installer

## Reminder

When editing text files in this project, prefer UTF-8 and avoid bulk rewrite operations that may change encoding unexpectedly.
