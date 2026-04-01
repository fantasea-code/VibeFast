#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn Unreachable, Off
Persistent

; ==============================================================================
; EMERGENCY KILL SWITCH - 紧急终止热键，防止鼠标/键盘被全局拦截后卡死系统
; ==============================================================================
^Esc::ExitApp

; ==============================================================================
; HARDCODED DEVICE ID - 纯粹的 RawInput 拦截，不带有任何多余的查找逻辑
; ==============================================================================
; 请使用 PowerShell 提前查出设备的 VID 和 PID 后，直接写在这里。
; 例如：大疆 Mic 可能 VID 是 0xXXXX, MCHOSE 鼠标可能是 0xXXXX
global TargetVID := 0x2717  ; <--- 修改为你要拦截的蓝牙设备 VID
global TargetPID := 0x32B0  ; <--- 修改为你要拦截的蓝牙设备 PID


; ==============================================================================
; Windows 消息挂钩初始化
; ==============================================================================
global RIDI_DEVICENAME := 0x20000007
global DeviceHandleMap := Map()  ; hDevice -> {vid, pid}

OnMessage(0x00FF, HandleRawInput)  ; WM_INPUT = 0x00FF

; 注册需要捕获的 RawInput 设备类别 (UsagePage 和 Usage)
; 1 = Generic Desktop
;   0x02 = Mouse
;   0x06 = Keyboard
; 12 = Consumer (0x0C)
;   0x01 = Consumer Control (多媒体键)
RegisterRawInput(1, 0x02) ; Mouse
RegisterRawInput(1, 0x06) ; Keyboard
RegisterRawInput(12, 1)   ; Multimedia

MsgBox(
    "Raw Input Debugger 已启动！`n`n" . 
    "当前监听设备: VID: 0x" . Format("{:04X}", TargetVID) . " PID: 0x" . Format("{:04X}", TargetPID) . "`n`n" . 
    "=== 紧急终止键: Ctrl + Esc ===",
    "RawInput Hook",
    "Iconi T1"
)
return

; ==============================================================================
; 获取设备的 VID 和 PID (绕过名字查询机制)
; ==============================================================================
GetDeviceId(hDevice) {
    pSize := 64
    pBuf := Buffer(128, 0)
    res := DllCall("GetRawInputDeviceInfoW", "Ptr", hDevice, "UInt", 0x2000000B, "Ptr", pBuf, "UInt*", &pSize) ; RIDI_DEVICEINFO
    if (res == -1)
        return { vid: 0, pid: 0 }

    dwType := NumGet(pBuf, 8, "UInt")
    if (dwType == 0 || dwType == 1 || dwType == 2) { 
        ; Mouse(0), Keyboard(1), HID(2)
        vid := NumGet(pBuf, 12, "UInt")
        pid := NumGet(pBuf, 16, "UInt")
        return { vid: vid, pid: pid }
    }
    return { vid: 0, pid: 0 }
}

; ==============================================================================
; 核心捕获函数
; ==============================================================================
HandleRawInput(wParam, lParam, msg, hwnd) {
    pSize := 0
    DllCall("GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", &pSize, "UInt", A_PtrSize == 8 ? 24 : 16)
    if (pSize == 0)
        return

    buf := Buffer(pSize, 0)
    DllCall("GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", buf, "UInt*", &pSize, "UInt", A_PtrSize == 8 ? 24 : 16)
    
    dwType := NumGet(buf, 0, "UInt")
    dwSize := NumGet(buf, 4, "UInt")
    hDevice := NumGet(buf, 8, "Ptr")

    ; 如果是第一次见到这个句柄，缓存其 VID PID，绝不进行耗时的字符串或系统调用查询
    if !DeviceHandleMap.Has(hDevice) {
        info := GetDeviceId(hDevice)
        DeviceHandleMap[hDevice] := info
    }

    devInfo := DeviceHandleMap[hDevice]
    
    ; 只处理匹配目标硬编码 VID PID 的设备（纯粹的验证）
    if (devInfo.vid != TargetVID || devInfo.pid != TargetPID)
        return

    ; --- 以下是解析按键信号 ---
    signal := ""

    if (dwType == 0) {  ; Mouse
        usFlags := NumGet(buf, A_PtrSize == 8 ? 16 : 12, "UShort")
        usButtonFlags := NumGet(buf, A_PtrSize == 8 ? 20 : 16, "UShort")
        usButtonData := NumGet(buf, A_PtrSize == 8 ? 22 : 18, "UShort")
        if (usButtonFlags)
            signal := "M:" . Format("{:04X}", usButtonFlags)
    } 
    else if (dwType == 1) {  ; Keyboard
        MakeCode := NumGet(buf, A_PtrSize == 8 ? 16 : 12, "UShort")
        Flags := NumGet(buf, A_PtrSize == 8 ? 18 : 14, "UShort")
        VKey := NumGet(buf, A_PtrSize == 8 ? 22 : 18, "UShort")
        isKeyUp := Flags & 0x01
        if (!isKeyUp && VKey != 255)
            signal := "K:" . Format("{:04X}", VKey)
    } 
    else if (dwType == 2) {  ; HID (多媒体键等)
        dwSizeHid := NumGet(buf, A_PtrSize == 8 ? 16 : 12, "UInt")
        dwCountHid := NumGet(buf, A_PtrSize == 8 ? 20 : 16, "UInt")
        pRawData := buf.Ptr + (A_PtrSize == 8 ? 24 : 20)
        
        hexStr := "HID:"
        Loop (dwSizeHid * dwCountHid) {
            byte := NumGet(pRawData, A_Index - 1, "UChar")
            if (byte != 0) 
                hexStr .= Format("{:02X} ", byte)
        }
        if (hexStr != "HID:")
            signal := hexStr
    }

    if (signal != "") {
        ToolTip("拦截到目标设备按键:`n" . signal)
        SetTimer () => ToolTip(), -2000
    }
}

RegisterRawInput(usagePage, usage) {
    RAWINPUTDEVICE := Buffer(12, 0) # 修正: AHK v2 中结构大小，12位对 64位和 32 位系统都需要对齐，更安全的写法如下
    RAWINPUTDEVICE := Buffer(A_PtrSize == 8 ? 16 : 12, 0)
    NumPut("UShort", usagePage, RAWINPUTDEVICE, 0)
    NumPut("UShort", usage,       RAWINPUTDEVICE, 2)
    NumPut("UInt",   0x00000100,  RAWINPUTDEVICE, 4)  ; RIDEV_INPUTSINK (后台拦截)
    NumPut("Ptr",    A_ScriptHwnd,     RAWINPUTDEVICE, 8)

    DllCall("RegisterRawInputDevices", "Ptr", RAWINPUTDEVICE, "UInt", 1, "UInt", A_PtrSize == 8 ? 16 : 12)
}
