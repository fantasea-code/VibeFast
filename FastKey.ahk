#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn Unreachable, Off
Persistent

; 紧急退出热键 (Ctrl+Esc)，防止任何情况下的鼠标/系统卡死
^Esc::ExitApp

#Include <WebView2>

; ============================================================
;  VIBE FAST — WebView2 + RawInput + 三段式循环
; ============================================================
global APP_NAME    := "VIBE FAST"
global CONFIG_FILE := A_ScriptDir "\config.ini"
global Paused      := false

; WebView2
global wvc  := ""   ; Controller
global core := ""   ; CoreWebView2

; RawInput
global HIDDevices      := []
global DeviceHandleMap := Map()
global TargetVID       := 0
global TargetPID       := 0
global ActiveWhitelist := Map()

; 捕获
global IsCapturing  := false
global CaptureRowIdx := -1

; 映射
global Mappings := []

; 常量
global WM_INPUT        := 0x00FF
global RIDEV_INPUTSINK := 0x00000100
global RID_INPUT       := 0x10000003
global RIDI_DEVICEINFO := 0x2000000b
global RIDI_DEVICENAME := 0x20000007

; ── 入口与全局变量 ──
global HooksActive := false

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
    SetupTray()
} else {
    ShowMainGui()
}
return

; ============================================================
;  GUI + WebView2
; ============================================================
global GuiHwnd := 0
global MainGui := 0

ShowMainGui() {
    global wvc, core, GuiHwnd

    if IsObject(core) {
        try WinShow(APP_NAME)
        return
    }

    g := Gui("+Resize", APP_NAME)
    g.OnEvent("Close", OnGuiClose)
    g.OnEvent("Size", OnGuiResize)
    g.Show("w900 h650")
    GuiHwnd := g.Hwnd
    ; 拦截 WM_SYSCOMMAND 防止 ALT+SPACE 弹出系统菜单（保留窗口按钮）
    OnMessage(0x0112, OnSysCommand)

    dllPath := A_ScriptDir "\WebView2Loader.dll"
    ; 使用回调模式（而非 .await()）
    WebView2.create(g.Hwnd, OnWvReady, , A_ScriptDir "\WebView2Data", , , dllPath)
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
    global core
    if !IsObject(core) {
        return
    }
    eventType := args.KeyEventKind  ; 0=KeyDown 1=KeyUp 2=SystemKeyDown 3=SystemKeyUp
    vkey := args.VirtualKey

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
    result := MsgBox("最小化到托盘继续运行？`n`n是=最小化  否=退出", APP_NAME, "YesNo Icon?")
    if (result == "Yes") {
        gui.Hide()
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
}

; ============================================================
;  JS → AHK 通信（WebMessage）
; ============================================================
OnWebMessage(sender, args) {
    global IsCapturing, CaptureRowIdx, TargetVID, TargetPID, Mappings

    msgStr := args.TryGetWebMessageAsString()
    ; 格式: "action:payload"
    colonPos := InStr(msgStr, ":")
    if (colonPos == 0)
        return
    action := SubStr(msgStr, 1, colonPos - 1)
    payload := SubStr(msgStr, colonPos + 1)

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
        StartHooks()
    }
    else if (action == "save") {
        ParseAndSaveMappings(payload)
        StopHooks() ; 仅保存时，卸载钩子
        MsgBox("配置已保存！", APP_NAME, "Iconi")
    }
    else if (action == "saveAndRun") {
        ParseAndSaveMappings(payload)
        ; 第二阶段：正式下达系统级的 RawInput 挂钩
        StartHooks()
        WinHide(APP_NAME)
        SetupTray()
        TrayTip("VIBE FAST 已在后台极速拦截运行", APP_NAME)
    }
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
        src := m.source ? "HID:" RegExReplace(m.source, "(..)", "$1 ") : ""
        src := Trim(src)
        pidStr := m.HasOwnProp("pid") ? m.pid : 0
        vidStr := m.HasOwnProp("vid") ? m.vid : 0
        enabled := m.HasOwnProp("enabled") ? m.enabled : true
        json .= '{"vid":' vidStr ',"pid":' pidStr ',"source":"' src '","hk1":"' EscapeJS(m.hk1) '","hk2":"' EscapeJS(m.hk2) '","hk3":"' EscapeJS(m.hk3) '","enabled":' (enabled ? "true" : "false") '},'
    }
    json := RTrim(json, ",") "]"
    RunJS("LoadMappings('" EscapeJS(json) "');")
}

EscapeJS(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "'", "\'")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "")
    return s
}

; ============================================================
;  配置读写
; ============================================================
LoadConfig() {
    global CONFIG_FILE, Mappings, ActiveWhitelist
    if !FileExist(CONFIG_FILE) {
        Mappings := []
        return
    }

    count := Integer(IniRead(CONFIG_FILE, "Mappings", "Count", "0"))
    Mappings := []
    ActiveWhitelist.Clear()
    Loop count {
        sec := "Mapping" A_Index
        m_vidHex := IniRead(CONFIG_FILE, sec, "VID", "0")
        m_pidHex := IniRead(CONFIG_FILE, sec, "PID", "0")
        src := IniRead(CONFIG_FILE, sec, "Source", "")
        hk1 := IniRead(CONFIG_FILE, sec, "HK1", "")
        hk2 := IniRead(CONFIG_FILE, sec, "HK2", "")
        hk3 := IniRead(CONFIG_FILE, sec, "HK3", "")
        enabled := IniRead(CONFIG_FILE, sec, "Enabled", "1")
        if (src != "") {
            vidInt := Integer("0x" m_vidHex)
            pidInt := Integer("0x" m_pidHex)
            Mappings.Push({vid: vidInt, pid: pidInt, source: src, hk1: hk1, hk2: hk2, hk3: hk3, step: 1, enabled: (enabled == "1")})
            if (enabled == "1")
                ActiveWhitelist[vidInt "_" pidInt] := true
        }
    }
}

ParseAndSaveMappings(jsonStr) {
    global CONFIG_FILE, Mappings, ActiveWhitelist

    ; 正则解析新增 vid, pid, enabled
    Mappings := []
    ActiveWhitelist.Clear()
    pos := 1
    ; 我们简单匹配关键字段，不需要强依赖JSON结构顺序
    pattern := "\{" Chr(34) "vid" Chr(34) ":(\d+)," Chr(34) "pid" Chr(34) ":(\d+)," Chr(34) "source" Chr(34) ":" Chr(34) "(.*?)" Chr(34) "," Chr(34) "hk1" Chr(34) ":" Chr(34) "(.*?)" Chr(34) "," Chr(34) "hk2" Chr(34) ":" Chr(34) "(.*?)" Chr(34) "," Chr(34) "hk3" Chr(34) ":" Chr(34) "(.*?)" Chr(34) "," Chr(34) "enabled" Chr(34) ":(true|false)\}"
    while (pos := RegExMatch(jsonStr, pattern, &m, pos)) {
        src := StrReplace(m[3], "HID:", "")
        src := RegExReplace(src, "\s+", "")
        isEnabled := (m[7] == "true")
        if (src != "") {
            vidInt := Integer(m[1])
            pidInt := Integer(m[2])
            Mappings.Push({vid: vidInt, pid: pidInt, source: src, hk1: m[4], hk2: m[5], hk3: m[6], step: 1, enabled: isEnabled})
            if (isEnabled)
                ActiveWhitelist[vidInt "_" pidInt] := true
        }
        pos += m.Len[0]
    }

    IniWrite(Mappings.Length, CONFIG_FILE, "Mappings", "Count")
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
        if (vid == 0 && pid == 0)
            continue
        DeviceHandleMap[hDevice] := {vid: vid, pid: pid, type: type}
        k := Format("{:04X}_{:04X}", vid, pid)
        if seen.Has(k)
            continue
        seen[k] := true
        pname := GetProductName(hDevice)
        if (!pname)
            pname := Format("HID ({:04X}:{:04X})", vid, pid)
        HIDDevices.Push({vid: vid, pid: pid, name: pname, usagePage: uPage})
    }
}

GetProductName(hDevice) {
    pSize := 1024
    pBuf := Buffer(2048, 0)
    DllCall("GetRawInputDeviceInfoW", "Ptr", hDevice, "UInt", RIDI_DEVICENAME, "Ptr", pBuf, "UInt*", &pSize)
    devPath := StrGet(pBuf, "UTF-16")
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
        NumPut("Ptr", hwnd, rid, offset + 8)
    }
    
    DllCall("RegisterRawInputDevices", "Ptr", rid, "UInt", usages.Length, "UInt", cbSize)
}

; ============================================================
;  音量补偿机制（不依赖 Hook 时序，映射触发后自动撤销音量变化）
; ============================================================
global SavedVolumeLevel := -1

RestoreVolume() {
    global SavedVolumeLevel
    if (SavedVolumeLevel >= 0) {
        try SoundSetVolume(SavedVolumeLevel)
        SavedVolumeLevel := -1
    }
}

; ============================================================
;  WM_INPUT 核心拦截
; ============================================================
HandleRawInput(wParam, lParam, msg, hwnd) {
    global DeviceHandleMap, IsCapturing, CaptureRowIdx
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
        if (dataLen <= 0)
            return

        ; 第一个字节是 ReportId，第二个字节通常是按钮状态
        Loop dataLen {
            b := NumGet(buf, headerSz + 8 + (A_Index - 1), "UChar")
            reportHex .= Format("{:02X}", b)
            if (A_Index == 2 && b != 0)
                isPress := true
        }
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

    ; --- 分流处理 ---
    if (IsCapturing && CaptureRowIdx >= 0) {
        IsCapturing := false
        RunJS("SetSourceCapture(" CaptureRowIdx ",'" fmtHex "', " vid ", " pid ");")
        ; 捕获完毕后卸载全局钩子
        StopHooks()
        PushDevices()
        CaptureRowIdx := -1
        return
    }

    if (Paused)
        return

    ; 极其精准的循环映射匹配
    for m in Mappings {
        if (m.enabled && m.vid == vid && m.pid == pid && m.source == reportHex) {
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
                ; 音量补偿：先记住当前音量，防止设备的原生音量键改变系统音量
                global SavedVolumeLevel
                try SavedVolumeLevel := SoundGetVolume()
                SendMappedHotkey(targetHK)
                ; 100ms 后自动恢复音量（足够让系统音量变化完成后再撤消）
                SetTimer(RestoreVolume, -100)
            }

            m.step++
            if (m.step > 3)
                m.step := 1
            return
        }
    }
}

; ============================================================
;  发送快捷键（将 "Ctrl + H" 转为 AHK 格式 "^h"）
; ============================================================
SendMappedHotkey(str) {
    if (str == "")
        return
    str := StrReplace(str, "Ctrl + ", "^")
    str := StrReplace(str, "Alt + ", "!")
    str := StrReplace(str, "Shift + ", "+")
    str := StrReplace(str, "Win + ", "#")
    if RegExMatch(str, "i)^[\^!+#]*(Enter|Escape|Space|Tab|Backspace|Delete|Up|Down|Left|Right|Home|End|PgUp|PgDn|F\d{1,2})$", &km)
    str := RegExReplace(str, "i)(Enter|Escape|Space|Tab|Backspace|Delete|Up|Down|Left|Right|Home|End|PgUp|PgDn|F\d{1,2})", "{$1}")
    str := StrReplace(str, " ", "") ; Remove spaces between modifiers and braces
    try Send(str)
}

; ============================================================
;  托盘菜单
; ============================================================
SetupTray() {
    tray := A_TrayMenu
    tray.Delete()
    tray.Add("打开配置", (*) => ShowMainGui())
    tray.Add("暂停", OnTrayPause)
    tray.Add()
    tray.Add("退出", (*) => ExitApp())
    tray.Default := "打开配置"
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
