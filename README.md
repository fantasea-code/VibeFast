# VIBE FAST

VIBE FAST 是一个把外设按钮改成你自己快捷键的小工具。

如果你的设备按钮默认只能做 `音量+`、`音量-`、播放暂停这类系统动作，但你真正想要的是触发某个软件快捷键，那它就是拿来做这个的。

常见用法：

- 把麦克风接收器上的按钮改成输入法快捷键
- 把鼠标侧键改成某个软件里的常用组合键
- 把 HID 设备原本的媒体键，映射成你更顺手的操作

## 为什么做这个工具

我做这个工具的起点其实很简单：

我平时会大量使用语音输入来做 vibe coding，而且还专门买了大疆麦克风。我一直在想，能不能尽量只拿着麦克风、不去碰键盘，也能完成很多常用操作，这样会更省力，也更顺手。

所以后来我做了 VIBE FAST。

它的核心目的不是炫技，而是把麦克风、接收器、鼠标这类设备上原本不好用的按钮，改成我真正想要的快捷键，从而更自然地完成 vibe coding 这件事。

## 去哪里下载

如果你只是普通用户，不需要看源码，也不用自己配环境。

请直接到这个项目的 **Releases / 发布页** 下载：

- `VibeFast_Setup.exe`

下载方式：

1. 打开 GitHub 项目主页
2. 点击右侧的 **Releases**
3. 进入最新版本
4. 在附件里下载 `VibeFast_Setup.exe`

安装完成后，按下面的“快速使用”步骤操作就可以。

## 快速使用

### 给普通用户

安装完成后，最常见的使用方式是：

1. 打开 `VIBE FAST`
2. 在左侧选择你的设备
3. 点击添加映射
4. 按一下你设备上的那个按钮，让程序记住它
5. 在目标快捷键里录入你想触发的组合键
6. 点击 `启动拦截`

这样以后你再按设备按钮，程序就会尝试把它变成你设置的快捷键。

如果你改了映射内容，配置会自动保存，不需要额外点保存。

### 给开发者

如果你是开发或调试用途，可以直接运行：

- `VibeFast.ahk`

前提是本机已安装 AutoHotkey v2。

## 中文说明

VIBE FAST 适合这种场景：

- 你的设备按钮默认功能不好用
- 你想把它改成某个软件自己的快捷键
- 你希望一个小工具来帮你接管这些外设按钮

当前最适合的使用方式，是配合接收器 / USB HID 设备来做按键映射。

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

- 主入口：`VibeFast.ahk`
- 前端：`WebUI/index.html`
- 配置：`config.ini`
- 调试日志：`DevTools/rawinput_trace.log`
- 安装脚本：`VibeFastSetup.iss`

### 打包方式

1. 准备 `AutoHotkey v2` 运行环境
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

- Main entry: `VibeFast.ahk`
- Frontend: `WebUI/index.html`
- Config: `config.ini`
- Debug log: `DevTools/rawinput_trace.log`
- Installer script: `VibeFastSetup.iss`

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

1. Prepare an `AutoHotkey v2` runtime environment.
2. Open `VibeFastSetup.iss` in Inno Setup.
3. Build the installer.

## Notes

- Mapping edits are auto-saved.
- `Start Interception` only starts the background interception flow.
- Keep text files in UTF-8 and avoid bulk overwrite operations with uncertain encodings.
