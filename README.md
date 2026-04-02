# VIBE FAST

VIBE FAST is a desktop utility for mapping HID device buttons to custom hotkeys.

## 快速安装

### 给普通用户

推荐使用安装包或已编译的 `VibeFast.exe`，不要直接运行源码。

1. 下载发布好的 `VibeFast_Setup.exe`
2. 运行安装程序
3. 安装完成后启动 `VIBE FAST`
4. 连接你的接收器 / HID 设备
5. 在界面里添加映射并点击 `启动拦截`

如果只有单文件版本，也可以直接运行 `VibeFast.exe`，但安装包更适合普通用户。

### 给开发者

如果你是开发或调试用途，可以直接运行：

- `F:\CODE\FastKey\VibeFast.ahk`

前提是本机已安装 AutoHotkey v2。

### 是否需要打包成 EXE

需要。
如果要给别人用，建议始终提供：

- `VibeFast.exe`
- `VibeFast_Setup.exe`

原因：

- 普通用户不需要额外安装 AutoHotkey
- 使用门槛更低
- 更接近正常桌面软件的交付方式
- 开机自启动、图标、安装路径这些体验也更完整

## 中文说明

VIBE FAST 是一个桌面工具，用来把 HID 设备按钮映射成自定义快捷键。

### 当前支持范围

- 接收器 / USB HID 模式是当前主支持路径，稳定性最好。
- 蓝牙设备只有在 Windows 把它暴露成标准 HID 输入时，才比较容易被识别。
- 配置修改会自动保存。
- 开机自启动使用当前用户的 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`。

### 当前已知限制

- `RawInput` 能识别输入来源，但不能真正吞掉系统原始媒体键行为。
- 像 `Alt + Space` 这样的系统保留快捷键，可能会被 Windows 优先处理。
- 有些蓝牙设备会以音频 / 免提控制方式接入系统，而不是标准输入设备，这种情况下 VIBE FAST 通常看不到按钮事件。

### 重要文件

- 主入口：`F:\CODE\FastKey\VibeFast.ahk`
- 前端：`F:\CODE\FastKey\WebUI\index.html`
- 配置：`F:\CODE\FastKey\config.ini`
- 调试日志：`F:\CODE\FastKey\DevTools\rawinput_trace.log`
- 安装脚本：`F:\CODE\FastKey\VibeFastSetup.iss`

### 打包方式

1. 使用 AutoHotkey v2 将 `VibeFast.ahk` 编译成 `VibeFast.exe`
2. 用 Inno Setup 打开 `VibeFastSetup.iss`
3. 生成安装包

### 备注

- 映射改动默认自动保存。
- `启动拦截` 只负责启动后台拦截流程。
- 文本文件建议统一使用 UTF-8，避免不明确编码的覆盖写入。

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