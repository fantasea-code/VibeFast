#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn Unreachable, Off
Persistent
;@Ahk2Exe-SetMainIcon app_icon.ico
TraySetIcon(A_ScriptDir "\app_icon.ico")

; --- 定制化系统原生托盘菜单 ---
A_IconTip := "VIBE FAST HID 拦截服务"
A_TrayMenu.Delete() ; 清理掉系统默认的无用英文（如 Suspend, Pause 等）
A_TrayMenu.Add("显示主界面", (*) => ShowMainGui())
A_TrayMenu.Add("开机自动启动", ToggleTrayAutoStart)
A_TrayMenu.Add("完全退出", (*) => ExitApp())
A_TrayMenu.Default := "显示主界面"

; 在启动时初始化勾选状态
SetTimer(InitTrayCheck, -100)

InitTrayCheck() {
    global AutoStartEnabled
    if (AutoStartEnabled) {
        A_TrayMenu.Check("开机自动启动")
    }
}

ToggleTrayAutoStart(*) {

global AutoStartEnabled

AutoStartEnabled := !AutoStartEnabled

A_TrayMenu.ToggleCheck("开机自动启动")

SaveAutoStartSetting()

ApplyAutoStartSetting()

}

; 紧急退出热键 (Ctrl+Esc)，防止任何情况下的鼠标/系统卡死

^Esc::ExitApp

~Volume_Up::AppendDebugLog("HOTKEY Volume_Up")

~Volume_Down::AppendDebugLog("HOTKEY Volume_Down")

~Volume_Mute::AppendDebugLog("HOTKEY Volume_Mute")

~Media_Play_Pause::AppendDebugLog("HOTKEY Media_Play_Pause")

~Media_Next::AppendDebugLog("HOTKEY Media_Next")

~Media_Prev::AppendDebugLog("HOTKEY Media_Prev")

~Media_Stop::AppendDebugLog("HOTKEY Media_Stop")

#Include <WebView2>

; ============================================================

;  VIBE FAST — WebView2 + RawInput + 三段式循环

; ============================================================

; ── 常量 ──
global APP_NAME        := "VIBE FAST"
global CONFIG_FILE     := A_ScriptDir "\config.ini"
global DEBUG_LOG_FILE  := A_ScriptDir "\DevTools\rawinput_trace.log"
global AUTOSTART_REG_KEY  := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
global AUTOSTART_REG_NAME := "VibeFast"
global WM_INPUT        := 0x00FF
global WM_APPCOMMAND   := 0x0319
global RIDEV_INPUTSINK := 0x00000100
global RID_INPUT       := 0x10000003
global RIDI_DEVICEINFO := 0x2000000b
global RIDI_DEVICENAME := 0x20000007

; ── 应用状态 ──
global Paused           := false
global AutoStartEnabled := true
global SidebarWidth     := 280
global HooksActive      := false

; ── WebView2 ──
global wvc     := ""   ; Controller
global core    := ""   ; CoreWebView2
global GuiHwnd := 0
global MainGui := 0

; ── RawInput / 设备 ──
global HIDDevices      := []
global DeviceHandleMap := Map()
global ActiveWhitelist := Map()

; ── HID 信号捕获 ──
global IsCapturing             := false
global CaptureRowIdx           := -1
global CaptureShouldStopHooks  := false

; ── 快捷键录入 ──
global IsHotkeyCapturing              := false
global HotkeyCaptureRow               := -1
global HotkeyCaptureStep              := -1
global HotkeyCaptureLastCombo         := ""
global HotkeyCaptureBestCombo         := ""
global HotkeyCaptureBestCount         := 0
global HotkeyCaptureSeenInput         := false
global HotkeyCaptureBlockingInput     := false
global HotkeyCaptureAccelKey          := ""
global HotkeyCaptureAccelTick         := 0
global HotkeyCaptureAccelModifiers    := []
global HotkeyCaptureRegisteredHotkeys := []
global HotkeyCaptureSuspendedHooks    := false

; ── 映射 ──
global Mappings         := []
global LastTriggerAt    := Map()
global MappingDebounceMs := 220

ResetDebugLog()

OnMessage(WM_APPCOMMAND, HandleAppCommand)

EnumerateHIDDevices()

; ★ 第一阶段：绝对不挂载系统钩子，保持 0% 性能占用

; RegisterForRawInput() 和 OnMessage(WM_INPUT, ...) 将被推迟到“第二阶段”用户显式点击启动后执行

isBackground := false

for arg in A_Args {

if (arg = "/background")

isBackground := true

}

if (isBackground && FileExist(CONFIG_FILE)) {

LoadConfig()
    ; If the HKCU Run entry was removed externally, restore it from saved settings.
    ApplyAutoStartSetting()
    StartHooks()

SetupTray()

} else {

LoadConfig()
    ; Keep HKCU Run in sync on normal launches too.
    ApplyAutoStartSetting()
    ShowMainGui()
}

return

; ============================================================

;  GUI + WebView2

ShowMainGui() {

global wvc, core
    global GuiHwnd
    global HooksActive, IsHotkeyCapturing

    hwnd := GetMainGuiHwnd()

    if (hwnd && WinExist("ahk_id " hwnd)) {
        try {
            AppendDebugLog("ShowMainGui reuse hwnd=" hwnd " hooksActive=" HooksActive " isHotkeyCapturing=" IsHotkeyCapturing)
            StopHotkeyCapture(true)
            StopHooks()

if IsObject(wvc) {

try wvc.IsVisible := true
                try wvc.NotifyParentWindowPositionChanged()

}

WinShow("ahk_id " hwnd)

FillBounds()

if IsObject(core) {

RunJS("ResetTransientUiState();")

PushDevices()

PushMappings()

PushSettings()

}

WinActivate("ahk_id " hwnd)

}
        return

}

g := Gui("+Resize", APP_NAME)

g.OnEvent("Close", OnGuiClose)

g.OnEvent("Size", OnGuiResize)

g.Show("w1050 h650")

MainGui := g
    GuiHwnd := g.Hwnd

; 拦截 WM_SYSCOMMAND 防止 ALT+SPACE 弹出系统菜单（保留窗口按钮）

OnMessage(0x0112, OnSysCommand)

dllPath := A_ScriptDir "\WebView2Loader.dll"

; 使用回调模式（而非 .await()）

WebView2.create(g.Hwnd, OnWvReady, , A_ScriptDir "\WebView2Data", , , dllPath)

}

GetMainGuiHwnd() {

global GuiHwnd

return GuiHwnd

}

HideMainGui() {

global MainGui, GuiHwnd, wvc

try {

AppendDebugLog("HideMainGui hwnd=" GuiHwnd)

if IsObject(wvc)

try wvc.IsVisible := false

if (GuiHwnd && WinExist("ahk_id " GuiHwnd))

WinHide("ahk_id " GuiHwnd)

}

}

DestroyMainGui() {

global MainGui, GuiHwnd, wvc, core

try {

if IsObject(MainGui)

MainGui.Destroy()

else if (GuiHwnd && WinExist("ahk_id " GuiHwnd))

WinClose("ahk_id " GuiHwnd)

}

MainGui := 0

GuiHwnd := 0

wvc := ""

core := ""

}

OnWvReady(ctrl) {

global wvc := ctrl

global core := ctrl.CoreWebView2

global GuiHwnd

FillBounds()

core.add_WebMessageReceived(OnWebMessage)

; 拦截所有加速键/系统键，防止 WebView2 吞掉 ALT 组合键等

ctrl.add_AcceleratorKeyPressed(OnAccelKey)

htmlPath := "file:///" StrReplace(A_ScriptDir "\WebUI\index.html", "\", "/")

core.Navigate(htmlPath)

core.add_NavigationCompleted(OnNavCompleted)

}

OnAccelKey(ctrl, args) {
    global core, IsHotkeyCapturing, HotkeyCaptureAccelKey, HotkeyCaptureAccelTick, HotkeyCaptureAccelModifiers
    if !IsObject(core) {
        return
    }
    eventType := args.KeyEventKind  ; 0=KeyDown 1=KeyUp 2=SystemKeyDown 3=SystemKeyUp
    vkey := args.VirtualKey
    if IsHotkeyCapturing {
        if (eventType = 2) {
            args.Handled := true
            if (vkey != 0x1B && vkey != 0x73 && vkey != 0x12) {
                accelKey := MapAccelVirtualKey(vkey)
                if (accelKey != "") {
                    modifiers := BuildCapturedModifierList()
                    hasAlt := false
                    for modifier in modifiers {
                        if (modifier = "Alt") {
                            hasAlt := true
                            break
                        }
                    }
                    if !hasAlt
                        modifiers.Push("Alt")
                    combo := BuildCapturedHotkeyFromParts(modifiers, accelKey)
                    if (combo != "") {
                        AppendDebugLog("Capture hotkey combo=" combo " source=accel")
                        SetTimer(FinalizeCapturedHotkey.Bind(combo), -1)
                    }
                }
            }
            return
        }
        args.Handled := true
        return
    }

; 只处理 SystemKeyDown（ALT组合）

if (eventType != 2) {

return

}

; 放行 Escape 和 F4（ALT+F4 关闭窗口）

if (vkey == 0x1B || vkey == 0x73) {

return

}

; 如果是单独按 ALT（VK_MENU=0x12），放行不处理

if (vkey == 0x12) {

return

}

args.Handled := true

; 把虚拟键码映射为 JS key 名

keyName := ""

code := ""

if (vkey == 0x20) {

keyName := "Space"

code := "Space"

} else if (vkey >= 0x41 && vkey <= 0x5A) {

keyName := Chr(vkey)

code := "Key" Chr(vkey)

} else if (vkey >= 0x30 && vkey <= 0x39) {

keyName := Chr(vkey)

code := "Digit" Chr(vkey)

} else if (vkey >= 0x70 && vkey <= 0x7B) {

keyName := "F" (vkey - 0x6F)

code := "F" (vkey - 0x6F)

} else if (vkey == 0x09) {

keyName := "Tab"

code := "Tab"

} else if (vkey == 0x0D) {

keyName := "Enter"

code := "Enter"

} else if (vkey == 0x08) {

keyName := "Backspace"

code := "Backspace"

} else if (vkey == 0x2E) {

keyName := "Delete"

code := "Delete"

} else {

keyName := "Unknown"

code := "Unknown"

}

; 用 dispatchEvent 派发合成键盘事件到 JS

js := "document.dispatchEvent(new KeyboardEvent('keydown',{key:'" keyName "',code:'" code "',altKey:true,ctrlKey:" (GetKeyState("Control") ? "true" : "false") ",shiftKey:" (GetKeyState("Shift") ? "true" : "false") ",metaKey:false,bubbles:true,cancelable:true}));"

core.ExecuteScriptAsync(js)

}

MapAccelVirtualKey(vkey) {

if (vkey == 0x20)

return "Space"

if (vkey >= 0x41 && vkey <= 0x5A)

return Chr(vkey)

if (vkey >= 0x30 && vkey <= 0x39)

return Chr(vkey)

if (vkey >= 0x70 && vkey <= 0x87)

return "F" (vkey - 0x6F)

static keyMap := Map(
        0x09, "Tab",
        0x0D, "Enter",
        0x08, "Backspace",
        0x2E, "Delete",
        0x2D, "Insert",
        0x24, "Home",
        0x23, "End",
        0x21, "PgUp",
        0x22, "PgDn",
        0x25, "Left",
        0x26, "Up",
        0x27, "Right",
        0x28, "Down",
        0xBA, ";",
        0xBF, "/",
        0xBE, ".",
        0xBC, ",",
        0xBD, "-",
        0xBB, "=",
        0xDB, "[",
        0xDD, "]",
        0xDC, "\",
        0xDE, "'",
        0xC0, "``"
    )

return keyMap.Has(vkey) ? keyMap[vkey] : ""

}

FillBounds() {

global wvc, GuiHwnd

if (!IsObject(wvc) || !GuiHwnd)

return

r := Buffer(16, 0)

DllCall("GetClientRect", "Ptr", GuiHwnd, "Ptr", r)

wvc.Bounds := r

}

OnGuiResize(gui, minMax, w, h) {

if (minMax != -1)

FillBounds()

}

OnSysCommand(wParam, lParam, msg, hwnd) {

; SC_KEYMENU = 0xF100，由 ALT+SPACE 或 ALT 键触发系统菜单

if ((wParam & 0xFFF0) == 0xF100) {

return 0  ; 吞掉，不弹系统菜单

}

}

OnGuiClose(gui) {

global core

result := MsgBox("最小化到托盘继续运行？`n`n是=最小化  否=退出", APP_NAME, "YesNo Icon?")

if (result == "Yes") {

StopHotkeyCapture(true)

HideMainGui()

SetupTray()

} else {

ExitApp()

}

return true

}

OnNavCompleted(sender, args) {

LoadConfig()

PushDevices()

PushMappings()

PushSettings()

}

; ============================================================

;  JS → AHK 通信（WebMessage）

; ============================================================

OnWebMessage(sender, args) {

global IsCapturing, CaptureRowIdx, CaptureShouldStopHooks, HooksActive, Mappings, AutoStartEnabled, MainGui, GuiHwnd

msgStr := args.TryGetWebMessageAsString()

; 格式: "action:payload"

colonPos := InStr(msgStr, ":")

if (colonPos == 0)

return

action := SubStr(msgStr, 1, colonPos - 1)

payload := SubStr(msgStr, colonPos + 1)

if (action = "debugTrace") {

AppendDebugLog("UI " payload)

return

}

if (action == "selectDevice") {

; AHK 端完全不关心前端选了什么设备，这是纯UI行为

return

}

else if (action == "refresh") {

EnumerateHIDDevices()

PushDevices()

}

else if (action == "startCapture") {

; 进入捕获状态：临时开启拦截

IsCapturing := true

CaptureRowIdx := Integer(payload)

CaptureShouldStopHooks := !HooksActive

StartHooks()

}

else if (action == "startHotkeyCapture") {

AppendDebugLog("OnWebMessage startHotkeyCapture payload=" payload " hooksActive=" HooksActive " isHotkeyCapturing=" IsHotkeyCapturing)

parts := StrSplit(payload, ",")

if (parts.Length >= 2)

StartHotkeyCapture(Integer(parts[1]), Integer(parts[2]))

}

else if (action == "stopHotkeyCapture") {

AppendDebugLog("OnWebMessage stopHotkeyCapture hooksActive=" HooksActive " isHotkeyCapturing=" IsHotkeyCapturing)

StopHotkeyCapture()

}

else if (action == "syncConfig") {

ParseAndSaveMappings(payload)

ApplyAutoStartSetting()

}

else if (action == "run") {

; 在 WebView 消息回调里直接销毁宿主窗口，容易留下白屏残窗。
        ; 这里改成异步切换，让当前回调先完整返回。
        SetTimer(BeginInterceptionMode, -1)

}

else if (action == "runWithConfig") {

AppendDebugLog("OnWebMessage runWithConfig")

ParseAndSaveMappings(payload)

ApplyAutoStartSetting()

; 配置保存和进入拦截共用同一份前端快照，避免拆成两条消息后的时序问题。
        SetTimer(BeginInterceptionMode, -1)

}

else if (action == "setAutoStart") {
        AutoStartEnabled := (payload = "1")
        SaveAutoStartSetting()
        ApplyAutoStartSetting()
    }
    else if (action == "saveSidebarWidth") {
        global SidebarWidth
        SidebarWidth := Integer(payload)
        IniWrite(SidebarWidth, CONFIG_FILE, "Settings", "SidebarWidth")
    }

}

BeginInterceptionMode() {

global APP_NAME

; 第二阶段：正式下达系统级的 RawInput 挂钩
    AppendDebugLog("BeginInterceptionMode hooksActive=" HooksActive)
    StartHooks()

StopHotkeyCapture(true)

HideMainGui()
    SetupTray()

TrayTip("VIBE FAST 已在后台极速拦截运行", APP_NAME)

}

; ============================================================

;  AHK → JS 通信（ExecuteScript）

; ============================================================

RunJS(js) {

global core

if IsObject(core) {

try core.ExecuteScriptAsync(js)

}

}

ResetDebugLog() {

global DEBUG_LOG_FILE

try FileDelete(DEBUG_LOG_FILE)

AppendDebugLog("=== Session " A_Now " ===")

}

AppendDebugLog(msg) {

global DEBUG_LOG_FILE

try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " | " msg "`r`n", DEBUG_LOG_FILE, "UTF-8")

}

GetRawDevicePath(hDevice) {

pSize := 1024

pBuf := Buffer(2048, 0)

DllCall("GetRawInputDeviceInfoW", "Ptr", hDevice, "UInt", RIDI_DEVICENAME, "Ptr", pBuf, "UInt*", &pSize)

return StrGet(pBuf, "UTF-16")

}

GetAppCommandName(cmd) {

static names := Map(

1, "BROWSER_BACKWARD",

2, "BROWSER_FORWARD",

8, "BACK",

9, "FORWARD",

10, "REFRESH",

11, "STOP",

12, "SEARCH",

13, "FAVORITES",

14, "HOME",

15, "VOLUME_MUTE",

16, "VOLUME_DOWN",

17, "VOLUME_UP",

18, "MEDIA_NEXTTRACK",

19, "MEDIA_PREVIOUSTRACK",

20, "MEDIA_STOP",

21, "MEDIA_PLAY_PAUSE",

22, "LAUNCH_MAIL",

23, "LAUNCH_MEDIA_SELECT",

24, "LAUNCH_APP1",

25, "LAUNCH_APP2",

46, "MIC_ON_OFF_TOGGLE"

)

return names.Has(cmd) ? names[cmd] : "UNKNOWN"

}

HandleAppCommand(wParam, lParam, msg, hwnd) {

cmd := (lParam >> 16) & 0x7FF

device := (lParam >> 24) & 0xF

AppendDebugLog("WM_APPCOMMAND cmd=" cmd " name=" GetAppCommandName(cmd) " device=" device " hwnd=" hwnd)

}

PushDevices() {

global HIDDevices, TargetVID, TargetPID

json := "["

for dev in HIDDevices {

n := StrReplace(dev.name, '"', '\"')

json .= '{"vid":' dev.vid ',"pid":' dev.pid ',"name":"' n '","usagePage":' dev.usagePage "},"

}

json := RTrim(json, ",") "]"

RunJS("UpdateDeviceList('" EscapeJS(json) "');")

}

PushMappings() {

global Mappings

if (Mappings.Length == 0) {

RunJS("LoadMappings('[]');")

return

}

json := "["

for m in Mappings {

src := FormatSourceForUi(m.source)

pidStr := m.HasOwnProp("pid") ? m.pid : 0

vidStr := m.HasOwnProp("vid") ? m.vid : 0

enabled := m.HasOwnProp("enabled") ? m.enabled : true

json .= '{"vid":' vidStr ',"pid":' pidStr ',"source":"' src '","hk1":"' EscapeJS(m.hk1) '","hk2":"' EscapeJS(m.hk2) '","hk3":"' EscapeJS(m.hk3) '","enabled":' (enabled ? "true" : "false") '},'

}

json := RTrim(json, ",") "]"
    RunJS("LoadMappings('" EscapeJS(json) "');")
}

PushSettings() {
    global AutoStartEnabled, SidebarWidth
    json := AutoStartEnabled ? '{"autoStart":true' : '{"autoStart":false'
    json .= ',"sidebarWidth":' SidebarWidth '}'
    RunJS("LoadSettings('" EscapeJS(json) "');")
}

EscapeJS(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "'", "\'")

s := StrReplace(s, "`n", "\n")

s := StrReplace(s, "`r", "")

return s

}

FormatSourceForUi(src) {

src := NormalizeMappingSource(src)

if (src = "")

return ""

if InStr(src, ":")

return src

return "HID:" Trim(RegExReplace(src, "(..)", "$1 "))

}

NormalizeBareHidSource(src) {

src := StrUpper(RegExReplace(src, "\s+", ""))

while (StrLen(src) > 4 && SubStr(src, -1) = "00")

src := SubStr(src, 1, -2)

return src

}

NormalizeMappingSource(src) {

src := Trim(src)

src := StrReplace(src, "HID:", "")

src := RegExReplace(src, "\s+", "")

src := StrUpper(src)

if (src = "")

return ""

if !InStr(src, ":")

return NormalizeBareHidSource(src)

return src

}

GetSourceMatchScore(mappingSource, reportHex) {

mappingSource := NormalizeMappingSource(mappingSource)

reportHex := NormalizeMappingSource(reportHex)

if (mappingSource = "" || reportHex = "")

return 0

if (mappingSource = reportHex)

return 1000 + StrLen(mappingSource)

if InStr(mappingSource, ":") || InStr(reportHex, ":")

return 0

if (InStr(reportHex, mappingSource) = 1)

return 500 + StrLen(mappingSource)

if (InStr(mappingSource, reportHex) = 1)

return 400 + StrLen(reportHex)

return 0

}

SourcesMatch(mappingSource, reportHex) {

return GetSourceMatchScore(mappingSource, reportHex) > 0

}

BuildMappingKey(m) {

return m.vid "|" m.pid "|" NormalizeMappingSource(m.source)

}

DeduplicateMappings(items) {

deduped := []

seen := Map()

for m in items {

key := BuildMappingKey(m)

if (key = "")

continue

if seen.Has(key)

deduped[seen[key]] := m

else {

seen[key] := deduped.Length + 1

deduped.Push(m)

}

}

return deduped

}

IsHidPressPacket(buf, headerSz, dataLen, &reportHex) {

reportHex := ""

if (dataLen <= 0)

return false

hasActiveUsage := false

Loop dataLen {

b := NumGet(buf, headerSz + 8 + (A_Index - 1), "UChar")

reportHex .= Format("{:02X}", b)

if (A_Index > 1 && b != 0)

hasActiveUsage := true

}

return hasActiveUsage

}

ShouldFireMapping(mappingKey) {

global LastTriggerAt, MappingDebounceMs

now := A_TickCount

last := LastTriggerAt.Has(mappingKey) ? LastTriggerAt[mappingKey] : 0

if (last && now - last < MappingDebounceMs) {

AppendDebugLog("Debounce skip key=" mappingKey " delta=" (now - last))

return false

}

LastTriggerAt[mappingKey] := now

return true

}

; ============================================================

;  配置读写

; ============================================================

LoadConfig() {

global CONFIG_FILE, Mappings, ActiveWhitelist, AutoStartEnabled, SidebarWidth

if !FileExist(CONFIG_FILE) {

Mappings := []

AutoStartEnabled := true

return

}

count := Integer(IniRead(CONFIG_FILE, "Mappings", "Count", "0"))

Mappings := []

ActiveWhitelist.Clear()

AutoStartEnabled := (IniRead(CONFIG_FILE, "Settings", "AutoStart", "1") = "1")
    SidebarWidth := Integer(IniRead(CONFIG_FILE, "Settings", "SidebarWidth", "280"))

Loop count {

sec := "Mapping" A_Index

m_vidHex := IniRead(CONFIG_FILE, sec, "VID", "0")

m_pidHex := IniRead(CONFIG_FILE, sec, "PID", "0")

src := IniRead(CONFIG_FILE, sec, "Source", "")

hk1 := IniRead(CONFIG_FILE, sec, "HK1", "")

hk2 := IniRead(CONFIG_FILE, sec, "HK2", "")

hk3 := IniRead(CONFIG_FILE, sec, "HK3", "")

enabled := IniRead(CONFIG_FILE, sec, "Enabled", "1")

src := NormalizeMappingSource(src)

if (src != "") {

vidInt := Integer("0x" m_vidHex)

pidInt := Integer("0x" m_pidHex)

Mappings.Push({vid: vidInt, pid: pidInt, source: src, hk1: hk1, hk2: hk2, hk3: hk3, step: 1, enabled: (enabled == "1")})

}

}

NormalizeMappingsState()

}

ParseAndSaveMappings(jsonStr) {

global CONFIG_FILE, Mappings, ActiveWhitelist, AutoStartEnabled

; 正则解析新增 vid, pid, enabled

Mappings := []

ActiveWhitelist.Clear()

pos := 1

; 我们简单匹配关键字段，不需要强依赖JSON结构顺序

pattern := "\{" Chr(34) "vid" Chr(34) ":(\d+)," Chr(34) "pid" Chr(34) ":(\d+)," Chr(34) "source" Chr(34) ":" Chr(34) "(.*?)" Chr(34) "," Chr(34) "hk1" Chr(34) ":" Chr(34) "(.*?)" Chr(34) "," Chr(34) "hk2" Chr(34) ":" Chr(34) "(.*?)" Chr(34) "," Chr(34) "hk3" Chr(34) ":" Chr(34) "(.*?)" Chr(34) "," Chr(34) "enabled" Chr(34) ":(true|false)\}"

while (pos := RegExMatch(jsonStr, pattern, &m, pos)) {

src := NormalizeMappingSource(m[3])

isEnabled := (m[7] == "true")

if (src != "") {

vidInt := Integer(m[1])

pidInt := Integer(m[2])

Mappings.Push({vid: vidInt, pid: pidInt, source: src, hk1: m[4], hk2: m[5], hk3: m[6], step: 1, enabled: isEnabled})

}

pos += m.Len[0]

}

NormalizeMappingsState()
    SaveMappingsToConfig()

}

NormalizeMappingsState() {

global Mappings, ActiveWhitelist

Mappings := DeduplicateMappings(Mappings)
    ActiveWhitelist.Clear()

for m in Mappings {

if (m.enabled)

ActiveWhitelist[m.vid "_" m.pid] := true

}

}

SaveMappingsToConfig() {

global CONFIG_FILE, Mappings, AutoStartEnabled

DeleteAllMappingSections()

IniWrite(Mappings.Length, CONFIG_FILE, "Mappings", "Count")

IniWrite(AutoStartEnabled ? "1" : "0", CONFIG_FILE, "Settings", "AutoStart")

for i, m in Mappings {

sec := "Mapping" i

IniWrite(Format("{:04X}", m.vid), CONFIG_FILE, sec, "VID")

IniWrite(Format("{:04X}", m.pid), CONFIG_FILE, sec, "PID")

IniWrite(m.source, CONFIG_FILE, sec, "Source")

IniWrite(m.hk1, CONFIG_FILE, sec, "HK1")

IniWrite(m.hk2, CONFIG_FILE, sec, "HK2")

IniWrite(m.hk3, CONFIG_FILE, sec, "HK3")

IniWrite(m.enabled ? "1" : "0", CONFIG_FILE, sec, "Enabled")

}

}

CommitCapturedHotkey(rowIdx, stepIdx, hotkey) {

global Mappings

mappingIdx := rowIdx + 1

if (mappingIdx < 1 || mappingIdx > Mappings.Length)

return false

switch stepIdx {
        case 1:
            Mappings[mappingIdx].hk1 := hotkey
        case 2:
            Mappings[mappingIdx].hk2 := hotkey
        case 3:
            Mappings[mappingIdx].hk3 := hotkey
        default:
            return false
    }

SaveMappingsToConfig()
    return true

}

DeleteAllMappingSections() {

global CONFIG_FILE

if !FileExist(CONFIG_FILE) {

return

}

iniText := FileRead(CONFIG_FILE, "UTF-8")
    pos := 1

while (pos := RegExMatch(iniText, "m)^\[(Mapping\d+)\]\R", &m, pos)) {

try IniDelete(CONFIG_FILE, m[1])
        pos += m.Len[0]

}

}

SaveAutoStartSetting() {

global CONFIG_FILE, AutoStartEnabled

IniWrite(AutoStartEnabled ? "1" : "0", CONFIG_FILE, "Settings", "AutoStart")

}

ApplyAutoStartSetting() {
    global APP_NAME, AutoStartEnabled, AUTOSTART_REG_KEY, AUTOSTART_REG_NAME
    try {
        if AutoStartEnabled {
            try RegWrite(GetAutoStartCommand(), "REG_SZ", AUTOSTART_REG_KEY, AUTOSTART_REG_NAME)
            if !IsAutoStartRegistered()
                RunWait(A_ComSpec ' /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "' AUTOSTART_REG_NAME '" /t REG_SZ /d "' GetAutoStartCommand() '" /f',, "Hide")
        } else {
            try RegDelete(AUTOSTART_REG_KEY, AUTOSTART_REG_NAME)
            if IsAutoStartRegistered()
                RunWait(A_ComSpec ' /c reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "' AUTOSTART_REG_NAME '" /f',, "Hide")
        }
    }
    catch Error as err {
        MsgBox("开机自启动设置失败:`n" err.Message, APP_NAME, "Iconx")
    }
}

IsAutoStartRegistered() {
    global AUTOSTART_REG_KEY, AUTOSTART_REG_NAME
    try {
        return RegRead(AUTOSTART_REG_KEY, AUTOSTART_REG_NAME) != ""
    } catch {
        return false
    }
}

GetAutoStartCommand() {

if A_IsCompiled

return Chr(34) A_ScriptFullPath Chr(34) " /background"

return Chr(34) A_AhkPath Chr(34) " " Chr(34) A_ScriptFullPath Chr(34) " /background"

}

; ============================================================

;  RawInput

; ============================================================

EnumerateHIDDevices() {

global HIDDevices, DeviceHandleMap

HIDDevices := []

DeviceHandleMap := Map()

structSize := A_PtrSize == 8 ? 16 : 8

numDev := 0

DllCall("GetRawInputDeviceList", "Ptr", 0, "UInt*", &numDev, "UInt", structSize)

AppendDebugLog("Enumerate start numDev=" numDev)

if (numDev == 0)

return

buf := Buffer(structSize * numDev, 0)

DllCall("GetRawInputDeviceList", "Ptr", buf, "UInt*", &numDev, "UInt", structSize)

seen := Map()

Loop numDev {

hDevice := NumGet(buf, (A_Index - 1) * structSize, "Ptr")

isz := 32

info := Buffer(32, 0)

NumPut("UInt", 32, info, 0)

DllCall("GetRawInputDeviceInfo", "Ptr", hDevice, "UInt", RIDI_DEVICEINFO, "Ptr", info, "UInt*", &isz)

type := NumGet(info, 4, "UInt")

vid := NumGet(info, 8, "UInt")

pid := NumGet(info, 12, "UInt")

uPage := NumGet(info, 20, "UShort")

devPath := GetRawDevicePath(hDevice)

if (vid == 0 && pid == 0) {

AppendDebugLog("Skip device type=" type " usagePage=" uPage " vid=0 pid=0 path=" devPath)

continue

}

DeviceHandleMap[hDevice] := {vid: vid, pid: pid, type: type}

k := Format("{:04X}_{:04X}", vid, pid)

if seen.Has(k) {

AppendDebugLog("Duplicate device vid=" Format("{:04X}", vid) " pid=" Format("{:04X}", pid) " path=" devPath)

continue

}

seen[k] := true

pname := GetProductName(hDevice)

if (!pname)

pname := Format("HID ({:04X}:{:04X})", vid, pid)

AppendDebugLog("Device type=" type " usagePage=" uPage " vid=" Format("{:04X}", vid) " pid=" Format("{:04X}", pid) " name=" pname " path=" devPath)

HIDDevices.Push({vid: vid, pid: pid, name: pname, usagePage: uPage})

}

}

GetProductName(hDevice) {

devPath := GetRawDevicePath(hDevice)

if (!devPath)

return ""

; 判断是标准 USB HID 还是蓝牙设备

; USB 路径格式:  \\?\HID#VID_1BBB&PID_AF50#...

; 蓝牙路径格式: \\?\HID#{00001812-0000-1000-8000-00805f9b34fb}_Dev_VID&012717_PID&32b0...

isUSB := InStr(devPath, "VID_") && InStr(devPath, "PID_")

isBT  := InStr(devPath, "{0000") || (InStr(devPath, "VID&") && InStr(devPath, "PID&"))

; --- 对于标准 USB 设备：使用快速的 HidD_GetProductString ---

if (isUSB && !isBT) {

try {

hFile := DllCall("CreateFileW", "Str", devPath, "UInt", 0, "UInt", 3, "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")

if (hFile != -1 && hFile) {

prod := Buffer(256, 0)

res := DllCall("hid.dll\HidD_GetProductString", "Ptr", hFile, "Ptr", prod, "UInt", 256, "Int")

DllCall("CloseHandle", "Ptr", hFile)

if res {

foundName := StrGet(prod, "UTF-16")

if (foundName != "")

return foundName

}

}

}

}

; --- 对于蓝牙 / BLE 设备：绝不调用 CreateFileW（会阻塞内核唤醒蓝牙），直接查注册表 ---

if (isBT) {

try {

; 方法 1（最可靠）：从设备路径提取蓝牙 MAC 地址，去 BTHPORT 读配对名称

; 路径中 MAC 格式举例: ..._c314a3c3de2f&Col01#...

; 这会返回跟 Windows 蓝牙设置里完全一样的设备名称

RegExMatch(devPath, "i)_([0-9a-f]{12})(&|#)", &macMatch)

if macMatch {

btMac := macMatch[1]

try {

bthKey := "HKLM\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices\" btMac

; Name 是 REG_BINARY，AHK中读取出来是一串十六进制字符

nameHex := RegRead(bthKey, "Name")

if (nameHex != "") {

realName := HexToUTF8(nameHex)

if (realName != "")

return realName

}

}

}

; 方法 2：在 BTHENUM / BTHLEDevice 下用 VID&PID 模式搜索 FriendlyName

regPath := SubStr(devPath, 5)

RegExMatch(regPath, "i)VID&([0-9A-F]+)_PID&([0-9A-F]+)", &vpMatch)

if vpMatch {

hwid := vpMatch[0]

for _, baseKey in ["HKLM\SYSTEM\CurrentControlSet\Enum\BTHENUM",

"HKLM\SYSTEM\CurrentControlSet\Enum\BTHLEDevice"] {

try {

loop reg, baseKey, "K" {

topName := A_LoopRegName

if InStr(topName, hwid) {

topPath := A_LoopRegKey "\" topName

loop reg, topPath, "K" {

instPath := topPath "\" A_LoopRegName

try {

fname := RegRead(instPath, "FriendlyName")

if (fname != "")

return fname

}

}

}

}

}

}

}

}

}

; --- 兜底：尝试直接读 HID 枚举节点下的 DeviceDesc ---

try {

regPath := SubStr(devPath, 5)

if (pos := InStr(regPath, "#{"))

regPath := SubStr(regPath, 1, pos - 1)

regPath := StrReplace(regPath, "#", "\")

fullRegKey := "HKLM\SYSTEM\CurrentControlSet\Enum\" regPath

try {

desc := RegRead(fullRegKey, "DeviceDesc")

if (pos := InStr(desc, ";"))

desc := SubStr(desc, pos + 1)

if (desc != "")

return desc

}

}

return ""

}

StartHooks() {

global HooksActive

if (HooksActive)

return

HooksActive := true

OnMessage(WM_INPUT, HandleRawInput)

; 包含各种可能触发目标按键的热点 Usage Page

usages := [

{up: 0x0C, u: 0x01},  ; Consumer Control (多媒体控制，很多蓝牙 Mic / 翻页笔走这个)

{up: 0x0B, u: 0x01},  ; Telephony (电话接听控制)

{up: 0x01, u: 0x06},  ; Keyboard (标准键盘)

{up: 0x01, u: 0x05},  ; Gamepad (游戏手柄，一些大疆遥控器冒充这个)

{up: 0x01, u: 0x04},  ; Joystick (摇杆)

{up: 0x01, u: 0x80}   ; System Control (电源、睡眠等系统控制)

]

hwnd := A_ScriptHwnd

cbSize := A_PtrSize == 8 ? 16 : 12

rid := Buffer(cbSize * usages.Length, 0)

for i, item in usages {

offset := (i - 1) * cbSize

NumPut("UShort", item.up, rid, offset)

NumPut("UShort", item.u,  rid, offset + 2)

NumPut("UInt", RIDEV_INPUTSINK, rid, offset + 4)

NumPut("Ptr", hwnd, rid, offset + 8)

}

DllCall("RegisterRawInputDevices", "Ptr", rid, "UInt", usages.Length, "UInt", cbSize)

}

StopHooks() {

global HooksActive

if (!HooksActive)

return

AppendDebugLog("StopHooks")
    HooksActive := false

OnMessage(WM_INPUT, HandleRawInput, 0)

usages := [

{up: 0x0C, u: 0x01}, {up: 0x0B, u: 0x01}, {up: 0x01, u: 0x06},

{up: 0x01, u: 0x05}, {up: 0x01, u: 0x04}, {up: 0x01, u: 0x80}

]

hwnd := A_ScriptHwnd

cbSize := A_PtrSize == 8 ? 16 : 12

rid := Buffer(cbSize * usages.Length, 0)

for i, item in usages {

offset := (i - 1) * cbSize

NumPut("UShort", item.up, rid, offset)

NumPut("UShort", item.u,  rid, offset + 2)

NumPut("UInt", 0x00000001, rid, offset + 4) ; RIDEV_REMOVE

NumPut("Ptr", 0, rid, offset + 8)

}

DllCall("RegisterRawInputDevices", "Ptr", rid, "UInt", usages.Length, "UInt", cbSize)

}

; ============================================================

;  音量补偿机制（不依赖 Hook 时序，映射触发后自动撤销音量变化）

; ============================================================

; ============================================================

;  WM_INPUT 核心拦截

; ============================================================

HandleRawInput(wParam, lParam, msg, hwnd) {

global DeviceHandleMap, IsCapturing, CaptureRowIdx, CaptureShouldStopHooks
    global Mappings, Paused, ActiveWhitelist

; 绝不能使用 Critical "On"。它会强制 Windows 底层输入列队等待 AHK 处理，

; 导致高回报率鼠标发生严重的轨迹断层和卡顿。让 AHK 异步处理即可！

headerSz := A_PtrSize == 8 ? 24 : 16

cbSize := 0

DllCall("GetRawInputData", "Ptr", lParam, "UInt", RID_INPUT, "Ptr", 0, "UInt*", &cbSize, "UInt", headerSz)

if (cbSize <= 0)

return

buf := Buffer(cbSize, 0)

ret := DllCall("GetRawInputData", "Ptr", lParam, "UInt", RID_INPUT, "Ptr", buf, "UInt*", &cbSize, "UInt", headerSz)

if (ret < 0)

return

type := NumGet(buf, 0, "UInt")

if (type > 2)

return

; 获取此事件属于哪个物理设备句柄

hDevice := NumGet(buf, 8, "Ptr")

vid := 0

pid := 0

; 1. 极其保守的字典查询，绝不在 WM_INPUT 里调系统 API

if DeviceHandleMap.Has(hDevice) {

dev := DeviceHandleMap[hDevice]

vid := dev.vid

pid := dev.pid

} else {

; 如果是不认识的设备在发数据，且不在全捕获模式，直接丢弃！绝对不要当场查！

if (!IsCapturing)

return

; 只有在极少发生的捕获模式下，才允许按需查一次设备 VID PID

isz := 32

info := Buffer(32, 0)

NumPut("UInt", 32, info, 0)

DllCall("GetRawInputDeviceInfo", "Ptr", hDevice, "UInt", RIDI_DEVICEINFO, "Ptr", info, "UInt*", &isz)

vid := NumGet(info, 8, "UInt")

pid := NumGet(info, 12, "UInt")

DeviceHandleMap[hDevice] := {vid: vid, pid: pid, type: type}

}

; 2. 拦截模式过滤：如果这台设备不在放行白名单里，光速返回！O(1) 零开销防止鼠标掉帧！

if (!IsCapturing && !ActiveWhitelist.Has(vid "_" pid)) {

return

}

; 3. 接下来是对目标设备的按键信号解析

isPress := false

reportHex := ""

fmtHex := ""

if (type == 2) { ; HID 信号

sizeHid := NumGet(buf, headerSz, "UInt")

countHid := NumGet(buf, headerSz + 4, "UInt")

dataLen := sizeHid * countHid

isPress := IsHidPressPacket(buf, headerSz, dataLen, &reportHex)

fmtHex := "HID:" RegExReplace(reportHex, "(..)", "$1 ")

fmtHex := Trim(fmtHex)

} else if (type == 1) { ; 键盘信号 (如某些蓝牙遥控器被系统识别为键盘)

Flags := NumGet(buf, headerSz + 2, "UShort")

VKey := NumGet(buf, headerSz + 6, "UShort")

isPress := !(Flags & 1) ; 0 = KeyDown, 1 = KeyUp

if (VKey == 255 || VKey == 0)

return

reportHex := Format("K:{:04X}", VKey)

fmtHex := reportHex

} else if (type == 0) { ; 鼠标额外按键信号 (如大疆摇杆有时走鼠标通道)

usButtonFlags := NumGet(buf, headerSz + 4, "UShort")

if (usButtonFlags != 0) {

isPress := true

reportHex := Format("M:{:04X}", usButtonFlags)

fmtHex := reportHex

} else {

return

}

}

; 只处理按下事件

if (!isPress)

return

if (InStr(fmtHex, "K:") || InStr(fmtHex, "HID:"))

AppendDebugLog("Event type=" type " vid=" Format("{:04X}", vid) " pid=" Format("{:04X}", pid) " source=" fmtHex)

; --- 分流处理 ---

if (IsCapturing && CaptureRowIdx >= 0) {

IsCapturing := false

RunJS("SetSourceCapture(" CaptureRowIdx ",'" fmtHex "', " vid ", " pid ");")

; 只回收这次临时开启的钩子，不影响本来就在运行的拦截

if (CaptureShouldStopHooks)

StopHooks()

PushDevices()

CaptureRowIdx := -1

CaptureShouldStopHooks := false

return

}

if (Paused)

return

; 极其精准的循环映射匹配

bestIdx := 0

bestScore := 0

loop Mappings.Length {

m := Mappings[A_Index]

if !(m.enabled && m.vid == vid && m.pid == pid)

continue

score := GetSourceMatchScore(m.source, reportHex)

if (score > bestScore) {

bestScore := score

bestIdx := A_Index

}

}

if (bestIdx = 0)

{

AppendDebugLog("No mapping match vid=" Format("{:04X}", vid) " pid=" Format("{:04X}", pid) " source=" fmtHex)

return

}

m := Mappings[bestIdx]

mappingKey := BuildMappingKey(m)

if !ShouldFireMapping(mappingKey)

return

targetHK := ""

if (m.step == 1)

targetHK := m.hk1

else if (m.step == 2)

targetHK := m.hk2

else if (m.step == 3)

targetHK := m.hk3

if (targetHK == "") {

m.step := 1

targetHK := m.hk1

}

if (targetHK != "") {

AppendDebugLog("Trigger mapping key=" mappingKey " step=" m.step " hotkey=" targetHK)

QueueMappedHotkey(targetHK)

} else {

AppendDebugLog("Trigger mapping key=" mappingKey " step=" m.step " hotkey=<empty>")

}

m.step++

if (m.step > 3)

m.step := 1

}

; ============================================================

;  发送快捷键

; ============================================================

NormalizeHotkeyToken(token) {

token := Trim(token)

static aliases := Map(

"CONTROL", "Ctrl",

"CTRL", "Ctrl",

"ALT", "Alt",

"SHIFT", "Shift",

"WIN", "Win",

"WINDOWS", "Win",

"SPACE", "Space",

"ESC", "Escape",

"ESCAPE", "Escape",

"ENTER", "Enter",

"RETURN", "Enter",

"BACKSPACE", "Backspace",

"DELETE", "Delete",

"DEL", "Delete",

"TAB", "Tab",

"PGUP", "PgUp",

"PGDN", "PgDn",

"UP", "Up",

"DOWN", "Down",

"LEFT", "Left",

"RIGHT", "Right",

"HOME", "Home",

"END", "End"

)

upper := StrUpper(token)

if aliases.Has(upper)

return aliases[upper]

if RegExMatch(upper, "^F\d{1,2}$")

return upper

if RegExMatch(upper, "^[A-Z0-9]$")
        return upper
    static punct := Map(
        ";", ";",
        ":", ";",
        "/", "/",
        "?", "/",
        ".", ".",
        ">", ".",
        ",", ",",
        "<", ",",
        "-", "-",
        "_", "-",
        "=", "=",
        "+", "=",
        "[", "[",
        "{", "[",
        "]", "]",
        "}", "]",
        "\", "\",
        "|", "\",
        "'", "'",
        '"', "'",
        "``", "``",
        "~", "``"
    )
    if punct.Has(token)
        return punct[token]
    if punct.Has(upper)
        return punct[upper]
    return token
}

BuildSendKeyName(token) {

token := NormalizeHotkeyToken(token)

if RegExMatch(token, "^(Ctrl|Alt|Shift|Win)$")

return token

if RegExMatch(token, "^[A-Z]$")

return StrLower(token)

if RegExMatch(token, "^(Enter|Escape|Space|Tab|Backspace|Delete|Up|Down|Left|Right|Home|End|PgUp|PgDn|F\d{1,2})$")

return "{" token "}"

return token

}

QueueMappedHotkey(str) {

if (str == "")

return

SetTimer(SendMappedHotkey.Bind(str), -1)

}

BuildSendHotkeySpec(str) {

if (str == "")

return ""

parts := StrSplit(str, "+")
    modifierSpec := ""
    mainKey := ""

for rawPart in parts {

token := NormalizeHotkeyToken(rawPart)

if (token = "")

continue

switch token {
            case "Ctrl":
                modifierSpec .= "^"
            case "Alt":
                modifierSpec .= "!"
            case "Shift":
                modifierSpec .= "+"
            case "Win":
                modifierSpec .= "#"
            default:
                if (mainKey = "")
                    mainKey := token
        }

}

if (mainKey = "")

return ""

return modifierSpec BuildSendKeyName(mainKey)

}

BuildHotkeyCaptureBindings() {
    static bindings := ""

if IsObject(bindings)
        return bindings

bindings := []

for key in ["Space", "Tab", "Enter", "Escape", "Backspace", "Delete", "Insert", "Home", "End", "PgUp", "PgDn", "Up", "Down", "Left", "Right"] {
        bindings.Push({spec: "*" key, token: key})
    }

Loop 26 {
        letter := Chr(64 + A_Index)
        bindings.Push({spec: "*" StrLower(letter), token: letter})
    }

Loop 10 {
        digit := Mod(A_Index, 10)
        bindings.Push({spec: "*" digit, token: "" digit})
    }

Loop 24 {
        fkey := "F" A_Index
        bindings.Push({spec: "*" fkey, token: fkey})
    }

return bindings
}

EnableHotkeyCaptureHotkeys() {
    global HotkeyCaptureRegisteredHotkeys

if (HotkeyCaptureRegisteredHotkeys.Length > 0)
        return

for binding in BuildHotkeyCaptureBindings() {
        handler := HandleCapturedMainKey.Bind(binding.token)
        Hotkey(binding.spec, handler, "On")
        HotkeyCaptureRegisteredHotkeys.Push({spec: binding.spec, handler: handler})
    }
}

DisableHotkeyCaptureHotkeys() {
    global HotkeyCaptureRegisteredHotkeys

for binding in HotkeyCaptureRegisteredHotkeys {
        try Hotkey(binding.spec, binding.handler, "Off")
    }

HotkeyCaptureRegisteredHotkeys := []
}

BuildCapturedModifierList() {
    modifiers := []

if GetKeyState("Ctrl", "P")
        modifiers.Push("Ctrl")
    if GetKeyState("Alt", "P")
        modifiers.Push("Alt")
    if GetKeyState("Shift", "P")
        modifiers.Push("Shift")
    if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        modifiers.Push("Win")

return modifiers
}

BuildCapturedHotkeyFromParts(modifiers, mainKey) {
    hotkey := ""

for modifier in modifiers {
        if (hotkey != "")
            hotkey .= " + "
        hotkey .= modifier
    }

if (mainKey != "") {
        if (hotkey != "")
            hotkey .= " + "
        hotkey .= mainKey
    }

return hotkey
}

FinalizeCapturedHotkey(combo) {
    global IsHotkeyCapturing, HotkeyCaptureLastCombo, HotkeyCaptureBestCombo, HotkeyCaptureBestCount, HotkeyCaptureSeenInput

if !IsHotkeyCapturing
        return

HotkeyCaptureSeenInput := true
    HotkeyCaptureLastCombo := combo
    HotkeyCaptureBestCombo := combo
    HotkeyCaptureBestCount := GetHotkeyPartCount(combo)
    PushHotkeyCaptureValue(combo, true)
    StopHotkeyCapture(true)
}

HandleCapturedMainKey(mainKey, *) {
    global IsHotkeyCapturing

if !IsHotkeyCapturing
        return

combo := BuildCapturedHotkeyFromParts(BuildCapturedModifierList(), mainKey)
    if (combo = "")
        return

AppendDebugLog("Capture hotkey combo=" combo " source=backend")
    SetTimer(FinalizeCapturedHotkey.Bind(combo), -1)
}

ParseHotkeyParts(str, &modifiers, &mainKey) {

modifiers := []
    mainKey := ""

if (str == "")

return

parts := StrSplit(str, "+")

for rawPart in parts {

token := NormalizeHotkeyToken(rawPart)

if (token = "")

continue

if RegExMatch(token, "^(Ctrl|Alt|Shift|Win)$")
            modifiers.Push(token)
        else if (mainKey = "")
            mainKey := token

}

}

SendModifierKey(token, isDown) {

keyName := token

if (token = "Win")
        keyName := "LWin"

SendEvent("{" keyName " " (isDown ? "down" : "up") "}")

}

SendMappedHotkeyEvent(str) {

ParseHotkeyParts(str, &modifiers, &mainKey)

if (mainKey = "")
        return

try {

SetKeyDelay(10, 10)

for modifier in modifiers
            SendModifierKey(modifier, true)

SendEvent(BuildSendKeyName(mainKey))

AppendDebugLog("Send hotkey raw=" str " mode=event main=" mainKey " modifiers=" modifiers.Length)

} finally {

Loop modifiers.Length
            SendModifierKey(modifiers[modifiers.Length - A_Index + 1], false)

}

}

ShouldSendHotkeyViaEvent(modifiers, mainKey) {

if (modifiers.Length > 0)
        return true

return RegExMatch(mainKey, "^(Enter|Escape|Space|Tab|Backspace|Delete|Insert|Up|Down|Left|Right|Home|End|PgUp|PgDn|F\d{1,2})$")

}

GetPressedMainKey() {
    global HotkeyCaptureAccelKey, HotkeyCaptureAccelTick

static keys := [

"A","B","C","D","E","F","G","H","I","J","K","L","M",

"N","O","P","Q","R","S","T","U","V","W","X","Y","Z",

"0","1","2","3","4","5","6","7","8","9",

"F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",

"F13","F14","F15","F16","F17","F18","F19","F20","F21","F22","F23","F24",

"Space","Tab","Enter","Escape","Backspace","Delete","Insert",

"Up","Down","Left","Right","Home","End","PgUp","PgDn",

        ";","/","\",".",",","-","=","[","]","'","``"
    ]

for key in keys {

if GetKeyState(key, "P")

return key

}

if (HotkeyCaptureAccelKey != "" && (A_TickCount - HotkeyCaptureAccelTick) <= 250)

return HotkeyCaptureAccelKey

return ""

}

BuildAccelCapturedHotkey() {
    global HotkeyCaptureAccelKey, HotkeyCaptureAccelTick, HotkeyCaptureAccelModifiers

if (HotkeyCaptureAccelKey = "" || (A_TickCount - HotkeyCaptureAccelTick) > 250)
        return ""

hotkey := ""
    for modifier in HotkeyCaptureAccelModifiers {
        if (hotkey != "")
            hotkey .= " + "
        hotkey .= modifier
    }

if (hotkey != "")
        hotkey .= " + "
    hotkey .= HotkeyCaptureAccelKey
    return hotkey
}

BuildCapturedHotkey() {

accelHotkey := BuildAccelCapturedHotkey()
    if (accelHotkey != "")
        return accelHotkey

parts := []

if GetKeyState("Ctrl", "P")

parts.Push("Ctrl")

if GetKeyState("Alt", "P")

parts.Push("Alt")

if GetKeyState("Shift", "P")

parts.Push("Shift")

if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))

parts.Push("Win")

mainKey := GetPressedMainKey()

if (mainKey != "")

parts.Push(mainKey)

if (parts.Length = 0)

return ""

hotkey := ""

for part in parts {

if (hotkey != "")

hotkey .= " + "

hotkey .= part

}

return hotkey

}

GetHotkeyPartCount(hotkey) {

if (hotkey = "")

return 0

count := 0

for _ in StrSplit(hotkey, "+")

count++

return count

}

PushHotkeyCaptureValue(hotkey, done := false) {

global HotkeyCaptureRow, HotkeyCaptureStep

if (done)

CommitCapturedHotkey(HotkeyCaptureRow, HotkeyCaptureStep, hotkey)

RunJS("SetHotkeyCapture(" HotkeyCaptureRow ", " HotkeyCaptureStep ", '" EscapeJS(hotkey) "', " (done ? "true" : "false") ");")

}

PollHotkeyCapture() {

global IsHotkeyCapturing, HotkeyCaptureLastCombo, HotkeyCaptureSeenInput

global HotkeyCaptureBestCombo, HotkeyCaptureBestCount

if !IsHotkeyCapturing

return

combo := BuildCapturedHotkey()

if (combo != "") {

partCount := GetHotkeyPartCount(combo)

HotkeyCaptureSeenInput := true

if (partCount > HotkeyCaptureBestCount) {

HotkeyCaptureBestCount := partCount

HotkeyCaptureBestCombo := combo

}

if (combo != HotkeyCaptureLastCombo) {

HotkeyCaptureLastCombo := combo

PushHotkeyCaptureValue(combo, false)

}

return

}

if (HotkeyCaptureSeenInput && (HotkeyCaptureBestCombo != "" || HotkeyCaptureLastCombo != "")) {

finalCombo := HotkeyCaptureBestCount > 1 ? HotkeyCaptureBestCombo : HotkeyCaptureLastCombo

PushHotkeyCaptureValue(finalCombo, true)

StopHotkeyCapture(true)

}

}

StartHotkeyCapture(rowIdx, stepIdx) {

global IsHotkeyCapturing, HotkeyCaptureRow, HotkeyCaptureStep

global HotkeyCaptureLastCombo, HotkeyCaptureBestCombo, HotkeyCaptureBestCount, HotkeyCaptureSeenInput

global HotkeyCaptureBlockingInput, HotkeyCaptureAccelKey, HotkeyCaptureAccelTick, HotkeyCaptureAccelModifiers
    global HotkeyCaptureSuspendedHooks, HooksActive

if IsHotkeyCapturing

StopHotkeyCapture()

HotkeyCaptureRow := rowIdx

HotkeyCaptureStep := stepIdx

HotkeyCaptureLastCombo := ""

HotkeyCaptureBestCombo := ""

HotkeyCaptureBestCount := 0

HotkeyCaptureSeenInput := false

HotkeyCaptureAccelKey := ""
HotkeyCaptureAccelTick := 0
HotkeyCaptureAccelModifiers := []
HotkeyCaptureBlockingInput := false

; BlockInput made Enter / arrows unreliable in capture on this machine.
    ; Keep capture accurate even if it is slightly less aggressive.
    HotkeyCaptureBlockingInput := false
    HotkeyCaptureSuspendedHooks := false
    if HooksActive {
        AppendDebugLog("StartHotkeyCapture suspending hooks for capture")
        StopHooks()
        HotkeyCaptureSuspendedHooks := true
    }
    IsHotkeyCapturing := true
    AppendDebugLog("StartHotkeyCapture row=" rowIdx " step=" stepIdx " hooksActive=" HooksActive)
    EnableHotkeyCaptureHotkeys()
    SetTimer(PollHotkeyCapture, 10)
}

StopHotkeyCapture(keepValue := false) {

global IsHotkeyCapturing, HotkeyCaptureRow, HotkeyCaptureStep

global HotkeyCaptureLastCombo, HotkeyCaptureBestCombo, HotkeyCaptureBestCount, HotkeyCaptureSeenInput

global HotkeyCaptureBlockingInput, HotkeyCaptureAccelKey, HotkeyCaptureAccelTick, HotkeyCaptureAccelModifiers
    global HotkeyCaptureSuspendedHooks

SetTimer(PollHotkeyCapture, 0)
    DisableHotkeyCaptureHotkeys()

AppendDebugLog("StopHotkeyCapture keepValue=" keepValue " seenInput=" HotkeyCaptureSeenInput " row=" HotkeyCaptureRow " step=" HotkeyCaptureStep)

IsHotkeyCapturing := false

if (!keepValue && HotkeyCaptureSeenInput && (HotkeyCaptureBestCombo != "" || HotkeyCaptureLastCombo != "")) {

finalCombo := HotkeyCaptureBestCount > 1 ? HotkeyCaptureBestCombo : HotkeyCaptureLastCombo

PushHotkeyCaptureValue(finalCombo, true)

}

if HotkeyCaptureBlockingInput {

try BlockInput("Off")

HotkeyCaptureBlockingInput := false

}

HotkeyCaptureRow := -1

HotkeyCaptureStep := -1

HotkeyCaptureLastCombo := ""

HotkeyCaptureBestCombo := ""

HotkeyCaptureBestCount := 0

HotkeyCaptureSeenInput := false

HotkeyCaptureAccelModifiers := []

HotkeyCaptureSuspendedHooks := false

}

SendMappedHotkey(str) {

if (str == "")

return

ParseHotkeyParts(str, &modifiers, &mainKey)

if (mainKey = "")
        return

sendSpec := BuildSendHotkeySpec(str)

try {

        if ShouldSendHotkeyViaEvent(modifiers, mainKey) {

SendMappedHotkeyEvent(str)

} else {

            if (sendSpec = "")
                return

SendInput(sendSpec)

AppendDebugLog("Send hotkey raw=" str " mode=input spec=" sendSpec)

}

}

}

; ============================================================

;  托盘菜单

; ============================================================

SetupTray() {
    global AutoStartEnabled
    tray := A_TrayMenu
    tray.Delete()
    tray.Add("显示主页面", (*) => ShowMainGui())
    tray.Add("开机自动启动", ToggleTrayAutoStart)
    if AutoStartEnabled
        tray.Check("开机自动启动")
    tray.Add("暂停", OnTrayPause)
    tray.Add()
    tray.Add("完全退出", (*) => ExitApp())
    tray.Default := "显示主页面"
    A_IconTip := APP_NAME " - 运行中"
}

OnTrayPause(itemName, itemPos, myMenu) {

global Paused := !Paused

tray := A_TrayMenu

if Paused {

tray.Rename("暂停", "恢复")

A_IconTip := APP_NAME " - 已暂停"

} else {

tray.Rename("恢复", "暂停")

A_IconTip := APP_NAME " - 运行中"

}

}

; ============================================================

;  十六进制字符串转 UTF-8 文本

; ============================================================

HexToUTF8(hex) {

if (Mod(StrLen(hex), 2) != 0)

return hex

byteLen := StrLen(hex) / 2

buf := Buffer(byteLen + 1, 0)

Loop byteLen {

b := "0x" SubStr(hex, 1 + (A_Index - 1) * 2, 2)

NumPut("UChar", Integer(b), buf, A_Index - 1)

}

; BTHPORT中由于是C语言字符串，通常结尾有\0，但也可能没有，StrGet 会自动处理 UTF-8 并在遇到 \0 截断

return StrGet(buf, "UTF-8")

}
