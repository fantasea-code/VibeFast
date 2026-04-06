# VIBE FAST

[中文版](#chinese) | [English](#english)

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

前提是本机已安装以下开发依赖。

#### 开发依赖

- `AutoHotkey v2`
- `WebView2 Runtime`（大多数 Windows 10/11 设备已自带；如果前端界面打不开，需要单独补装）
- `Inno Setup`（仅在你需要自己构建安装包时需要）

<a id="chinese"></a>

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

<a id="english"></a>

VIBE FAST is a small tool that remaps hardware buttons into the shortcuts you actually want.

If your device buttons can only perform default system actions such as `Volume Up`, `Volume Down`, or play/pause, but what you really want is to trigger a shortcut inside a specific application, this tool is designed for exactly that.

Typical use cases:

- Remap a microphone receiver button into an input method shortcut
- Remap a mouse side button into a commonly used shortcut in a specific app
- Turn the original media keys from an HID device into actions that fit your workflow better

## Why This Tool Exists

The original motivation was actually very simple.

I use voice input heavily for vibe coding, and I specifically bought the DJI microphone. I kept wondering whether I could complete more common actions while only holding the microphone and touching the keyboard less often, so the whole workflow would feel lighter and more natural.

That is why I built VIBE FAST.

Its goal is not to show off technical tricks. Its real purpose is to take the awkward default buttons on microphones, receivers, mice, and similar devices, and turn them into the shortcuts I actually want, so vibe coding feels more natural.

## Where To Download

If you are a normal user, you do not need to read the source code or prepare a development environment.

Go directly to this project's **Releases** page and download:

- `VibeFast_Setup.exe`

Download steps:

1. Open the GitHub project homepage
2. Click **Releases** on the right side
3. Open the latest version
4. Download `VibeFast_Setup.exe` from the release assets

After installation, follow the quick start steps below.

## Quick Start
### For End Users

After installation, the most common workflow is:

1. Open `VIBE FAST`
2. Select your device on the left
3. Click Add Mapping
4. Press the hardware button you want the program to remember
5. Record the shortcut you want in the target hotkey fields
6. Click `启动拦截`

After that, whenever you press the device button, the program will try to turn it into the shortcut you configured.

If you change a mapping, the configuration is saved automatically. There is no extra save button.

### For Developers

If you are using it for development or debugging, you can run:

- `VibeFast.ahk`

This requires the following development dependencies to already be installed on the machine.

#### Development Dependencies

- `AutoHotkey v2`
- `WebView2 Runtime` (included on most Windows 10/11 systems; install it manually if the UI does not open)
- `Inno Setup` (only needed if you want to build the installer yourself)

## Current Scope

VIBE FAST is suitable for scenarios like these:

- The default function of your hardware button is not useful
- You want to remap it into an application-specific shortcut
- You want a lightweight tool to take over those external device buttons for you

At the moment, the best-supported usage path is button mapping through receivers / USB HID devices.

### Current Support Range

- Receiver / USB HID mode is currently the main supported path and is the most stable
- Bluetooth devices are easier to support only when Windows exposes them as standard HID input
- Configuration changes are saved automatically
- Auto start uses the current user registry key `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`

### Current Known Limits

- `RawInput` can identify the input source, but it cannot truly swallow the original system media key behavior
- System-reserved shortcuts such as `Alt + Space` may be handled by Windows first
- Some Bluetooth devices connect to Windows as audio / hands-free controls instead of standard input devices, and in those cases VIBE FAST usually cannot see the button events

### Important Files

- Main entry: `VibeFast.ahk`
- Frontend: `WebUI/index.html`
- Config: `config.ini`
- Debug log: `DevTools/rawinput_trace.log`
- Installer script: `VibeFastSetup.iss`

### Packaging

1. Prepare an `AutoHotkey v2` runtime environment
2. Open `VibeFastSetup.iss` in Inno Setup
3. Build the installer

### Notes

- Mapping changes are auto-saved by default
- `启动拦截` only starts the background interception flow
- It is recommended to keep text files in UTF-8 to avoid overwriting files with uncertain encodings
