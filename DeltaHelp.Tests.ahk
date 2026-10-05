; AutoHotkey v1 regression tests. No game access or generated keyboard input.
#NoEnv
#SingleInstance Off
#Warn All, StdOut
SendMode Input
SetBatchLines, -1
ListLines, Off
global GuiH1, GuiV1, GuiStage1Ms, GuiH2, GuiV2, GuiMaxHoldMs, GuiIntervalMs, GuiJitter, GuiHoldMode, GuiM14Hotkey, GuiLightHotkey, GuiLightWindowS, GuiLightSendKeyL, GuiLightSendKeyR, GuiBreathEnabled, GuiBreathKey
global GuiShiftZHotkey, GuiShiftZIntervalS, DH_ShiftZStatus
global DH_TestEvents := [], DH_TestChecks := 0

DH_testDir := A_Temp "\DeltaHelp-Tests-" DllCall("GetCurrentProcessId") "-" A_TickCount
FileCreateDir, %DH_testDir%
DH_testConfig := DH_testDir "\DeltaHelp.ini"
; 模拟旧版 INI，确认新增参数使用默认值，不覆盖已有设置。
FileAppend, [Settings]`nGuiV1=1.2`nGuiV2=1.2`n, %DH_testConfig%
InitDeltaHelp(DH_testConfig)
DetectHiddenWindows, On
Gui, M14:+HwndDH_testGuiHwnd
WinGetPos, DH_guiX, DH_guiY, DH_guiW, DH_guiH, ahk_id %DH_testGuiHwnd%
SysGet, DH_workArea, MonitorWorkArea
DH_TestCheck(DH_guiW <= DH_workAreaRight - DH_workAreaLeft && DH_guiH <= DH_workAreaBottom - DH_workAreaTop, "settings window fits current monitor work area")
FileAppend, % "LAYOUT width=" DH_guiW " height=" DH_guiH " work=" (DH_workAreaRight - DH_workAreaLeft) "x" (DH_workAreaBottom - DH_workAreaTop) " dpi=" A_ScreenDPI "`n", *
DH_TestCheck(!shiftZActive && !macroActive, "startup switches OFF")
DH_TestCheck(ShiftZIntervalMs = 300 && DH_HotkeyId(ShiftZToggleHotkey) = "XBUTTON1", "old INI migrates to 0.3s / XButton1")
DH_TestCheck(GuiV1 = 1.2 && GuiV2 = 1.2, "existing parameters preserved")
DH_TestCheck(DH_RegisteredHotkeys.Length() = 2, "shared switch registered once")
DH_ShiftZSender := Func("DH_TestRecordKey")
; 只记录按键，测试期间所有鼠标位移也置零。
fastStep := 0, slowStep := 0

DH_HandleHotkey("~XButton1")
DH_TestCheck(shiftZActive && macroActive, "shared XButton1 enables both switches")
DH_TestCheck(DH_TestEvents.Length() = 1 && DH_TestEvents[1].key = "Shift", "first press immediately taps Shift")
DH_waitStarted := A_TickCount
while (DH_TestEvents.Length() < 4 && A_TickCount - DH_waitStarted < 1600) {
    Sleep, 10
}
DH_HandleHotkey("~XButton1")
DH_TestCheck(!shiftZActive && !macroActive, "second press stops both switches")
DH_TestCheck(DH_TestEvents.Length() >= 4, "real 300ms timer fires repeatedly")
DH_CheckEventSequence(300)
DH_stoppedCount := DH_TestEvents.Length()
Sleep, 400
DH_TestCheck(DH_TestEvents.Length() = DH_stoppedCount, "no events after stop")

; 更换循环热键与间隔，走与 Apply 按钮相同的路径。
GuiControl, M14:, GuiShiftZHotkey, F6
GuiControl, M14:, GuiShiftZIntervalS, 0.07
Gosub, M14ApplySettings
DH_TestCheck(ShiftZIntervalMs = 70 && DH_HotkeyId(ShiftZToggleHotkey) = "F6", "Apply custom key and interval")
DH_TestCheck(DH_RegisteredHotkeys.Length() = 3, "independent hotkeys registered")
IniRead, DH_savedHotkey, %DH_testConfig%, Settings, GuiShiftZHotkey
IniRead, DH_savedInterval, %DH_testConfig%, Settings, GuiShiftZIntervalS
DH_TestCheck(DH_savedHotkey = "F6" && DH_savedInterval + 0 = 0.07, "custom parameters persisted")
DH_TestEvents := []
DH_HandleHotkey("~F6")
DH_TestCheck(shiftZActive && !macroActive, "independent key only enables cycle")
DH_waitStarted := A_TickCount
while (DH_TestEvents.Length() < 4 && A_TickCount - DH_waitStarted < 700) {
    Sleep, 5
}
DH_HandleHotkey("~F6")
DH_TestCheck(!shiftZActive && !macroActive, "independent key stops cycle")
DH_TestCheck(DH_TestEvents.Length() >= 4, "real custom timer fires")
DH_CheckEventSequence(70)

; 循环正在运行时修改间隔，继续循环且下一次按原有顺序发出。
DH_TestEvents := []
DH_HandleHotkey("~F6")
GuiControl, M14:, GuiShiftZIntervalS, 0.11
Gosub, M14ApplySettings
DH_TestCheck(shiftZActive && ShiftZIntervalMs = 110, "Apply updates running timer without stopping cycle")
DH_waitStarted := A_TickCount
while (DH_TestEvents.Length() < 3 && A_TickCount - DH_waitStarted < 700) {
    Sleep, 5
}
DH_HandleHotkey("~F6")
DH_TestCheck(DH_TestEvents.Length() >= 3, "updated timer keeps firing")
DH_CheckEventSequence(110)
GuiControl, M14:, GuiShiftZIntervalS, 0.07
Gosub, M14ApplySettings

DH_TestCheck(DH_ParseShiftZInterval("0.3") = 300, "parse 0.3s")
DH_TestCheck(DH_ParseShiftZInterval(".125") = 125, "parse fractional seconds")
DH_TestCheck(DH_ParseShiftZInterval("0.01") = 10 && DH_ParseShiftZInterval("3600") = 3600000, "valid interval bounds")
for _, DH_badInterval in ["", "abc", "0", "-0.3", "0.009", "3600.01", "0.3s"]
    DH_TestCheck(DH_ParseShiftZInterval(DH_badInterval) = 0, "reject invalid interval: " DH_badInterval)
DH_TestCheck(DH_HotkeyError("~XButton1", "~XButton1", "~XButton1") = "", "no shared-key conflict restrictions")
DH_TestCheck(DH_HotkeyError("~XButton1", "~XButton2", "") != "", "empty hotkey rejected")

; 部分注册失败后可以恢复原热键，且不会留下半套新绑定。
DH_TestCheck(!DH_RegisterHotkeys(["~F7", "~NotARealKey"]), "invalid OS hotkey fails registration")
DH_TestCheck(DH_RegisterHotkeys([M14ToggleHotkey, LightArmHotkey, ShiftZToggleHotkey]), "previous bindings restored")
DH_TestCheck(DH_RegisteredHotkeys.Length() = 3, "restored bindings complete")

; 重新初始化读取保存的参数，但不恢复运行中的开关。
DH_HandleHotkey("~F6")
Gui, M14:Destroy
InitDeltaHelp(DH_testConfig)
DH_TestCheck(!shiftZActive && !macroActive, "restart does not resume active cycle")
DH_TestCheck(ShiftZIntervalMs = 70 && DH_HotkeyId(ShiftZToggleHotkey) = "F6", "restart restores custom parameters")
DH_ShiftZSender := Func("DH_TestRecordKey")
DH_TestEvents := []
DH_HandleHotkey("~F6")
DH_OnExit("test", 0)
DH_stoppedCount := DH_TestEvents.Length()
Sleep, 150
DH_TestCheck(!shiftZActive && DH_TestEvents.Length() = DH_stoppedCount, "exit cleanup stops timer")
GuiControlGet, DH_statusText, M14:, DH_ShiftZStatus
DH_TestCheck(InStr(DH_statusText, "关闭"), "GUI reports stopped state")
FileAppend, % "DELTAHELP PASS checks=" DH_TestChecks " default=300ms custom=70ms persistence=PASS stop=PASS`n", *
FileDelete, %DH_testConfig%
FileRemoveDir, %DH_testDir%
ExitApp, 0

DH_TestRecordKey(key) {
    global DH_TestEvents
    DH_TestEvents.Push({key: key, time: A_TickCount})
}
DH_TestCheck(condition, description) {
    global DH_TestChecks
    DH_TestChecks++
    if !condition {
        FileAppend, % "DELTAHELP FAIL: " description "`n", *
        ExitApp, 1
    }
}
DH_CheckEventSequence(interval) {
    global DH_TestEvents
    for index, event in DH_TestEvents {
        expected := Mod(index, 2) ? "Shift" : "z"
        DH_TestCheck(event.key = expected, "alternating key " index)
        if (index > 1) {
            actual := event.time - DH_TestEvents[index - 1].time
            DH_TestCheck(actual >= interval - 20 && actual <= interval + 180, "timer spacing " actual "ms / expected " interval "ms")
        }
    }
}

#Include %A_ScriptDir%\DeltaHelp.ahk
