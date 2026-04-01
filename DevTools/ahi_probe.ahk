#Requires AutoHotkey v2.0
probeFile := A_ScriptDir '\ahi_probe.txt'
FileDelete(probeFile)
FileAppend('START`r`n', probeFile)
#Include "F:\CODE\TOOLS\AutoHotInterception\AHK v2\Lib\AutoHotInterception.ahk"
AHI := AutoHotInterception()
FileAppend('AFTER_NEW`r`n', probeFile)
out := ''
for id, dev in AHI.GetDeviceList() {
    if (dev.VID = 0x2CA3 && dev.PID = 0x4011)
        out .= 'ID=' id ',IsMouse=' dev.IsMouse ',Handle=' dev.Handle '`r`n'
}
if (out = '')
    out := 'NO_MATCH`r`n'
FileAppend(out, probeFile)
ExitApp
