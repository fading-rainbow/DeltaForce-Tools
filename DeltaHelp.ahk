; Integrated Delta Help; no login and no session expiry.
InitDeltaHelp() {
global
DH_ConfigPath := A_ScriptDir "\DeltaHelp.ini"
OnExit("DH_OnExit")
macroActive := 0
moveInterval := 10
fastStep := 0
slowStep := 0
leftStep := 0
earlyLeftStep := 0
fastDurationMs := 330
maxHoldMs := 2300
jitterFactor := 0.0
M14ToggleHotkey := "~XBUTTON1"
LightArmHotkey := "~XBUTTON2"
LightWindowMs := 10000
LightSendKeyL := "l"
LightSendKeyR := "l"
lightRightGraceMs := 1000
lightRightDelayMs := 200
lightArmed := 0
lightRightFirstAt := 0
lightLeftSent := 0
lightRightSent := 0
lightRightPending := 0
BreathEnabled := 0
BreathKey := "Shift"
breathIsDown := 0
autoBreathInterval := 10
GuiH1 := earlyLeftStep
GuiV1 := fastStep
GuiStage1Ms := fastDurationMs
GuiH2 := leftStep
GuiV2 := slowStep
GuiMaxHoldMs := maxHoldMs
GuiIntervalMs := moveInterval
GuiJitter := jitterFactor
GuiM14Hotkey := StripLeadingTilde(M14ToggleHotkey)
GuiLightHotkey := StripLeadingTilde(LightArmHotkey)
GuiLightWindowS := (LightWindowMs / 1000.0)
GuiLightSendKeyL := LightSendKeyL
GuiLightSendKeyR := LightSendKeyR
GuiHoldMode := 1
GuiBreathEnabled := BreathEnabled
GuiBreathKey := BreathKey
M14GuiVisible := 0
lbtnWasDown := 0
lbtnDownAt := 0
lbtnSuppressed := 0
runUntilAt := 0
lastTick := 0
carryX := 0.0
carryY := 0.0
DH_LoadSettings()
CreateDeltaHelpGui()
Gosub, M14ApplySettings
Gui, M14:Hide
M14GuiVisible := 0
}
UpdateAutoBreathTimer() {
global BreathEnabled, autoBreathInterval
if (BreathEnabled) {
SetTimer, AutoBreathTick, %autoBreathInterval%
EnsureBreathKey(GetKeyState("LButton", "P"))
} else {
SetTimer, AutoBreathTick, Off
EnsureBreathKey(0)
}
}
EnsureBreathKey(desiredDown) {
global BreathEnabled, BreathKey, breathIsDown
if (!BreathEnabled) {
desiredDown := 0
}
if (desiredDown) {
if (!breathIsDown) {
SendInput, {%BreathKey% down}
breathIsDown := 1
}
} else {
if (breathIsDown) {
SendInput, {%BreathKey% up}
breathIsDown := 0
}
}
}
M14_AddText(ByRef y, x, w, text, options := "") {
Gui, M14:Add, Text, x%x% y%y% w%w% %options% hwndhCtl, %text%
ControlGetPos,,, ,h,, ahk_id %hCtl%
if (!h)
h := 18
y += h + 3
return hCtl
}
M14_AddEdit(ByRef y, x, w, varName, options := "") {
Gui, M14:Add, Edit, x%x% y%y% w%w% v%varName% %options% hwndhCtl
ControlGetPos,,, ,h,, ahk_id %hCtl%
if (!h)
h := 22
y += h + 6
return hCtl
}
M14_AddCheck(ByRef y, x, w, varName, text, options := "") {
Gui, M14:Add, Checkbox, x%x% y%y% w%w% v%varName% %options% hwndhCtl, %text%
ControlGetPos,,, ,h,, ahk_id %hCtl%
if (!h)
h := 22
y += h + 6
return hCtl
}
M14_AddButton(ByRef y, x, w, gLabel, text, options := "") {
Gui, M14:Add, Button, x%x% y%y% w%w% g%gLabel% %options% hwndhCtl, %text%
ControlGetPos,,, ,h,, ahk_id %hCtl%
if (!h)
h := 26
y += h + 8
return hCtl
}
CreateDeltaHelpGui() {
global
Gui, M14:New, +AlwaysOnTop +ToolWindow, Delta Help
Gui, M14:+DPIScale
Gui, M14:Margin, 8, 8
Gui, M14:Font, s10, Microsoft YaHei UI
x1 := 10, x2 := 360
wEdit := 180
wLeft := x2 - x1 - 20
yTop := 10
M14_AddText(yTop, x1, 520, "Remember to click Apply to save your settings.", "cGray")
M14_AddText(yTop, x1, 520, "Settings persist across restarts. Motion starts OFF. F9 remains unchanged.", "cGray")
yTop += 4
yL := yTop
M14_AddText(yL, x1, wLeft, "Stage 1 (first):")
M14_AddText(yL, x1, wLeft, "Stage 1: from press start for ""Stage 1 duration"".", "cGray")
M14_AddText(yL, x1, wLeft, "H speed (px/tick, -left +right):")
M14_AddEdit(yL, x1, wEdit, "GuiH1")
M14_AddText(yL, x1, wLeft, "V speed down (px/tick):")
M14_AddEdit(yL, x1, wEdit, "GuiV1")
M14_AddText(yL, x1, wLeft, "Stage 1 duration (ms):")
M14_AddEdit(yL, x1, wEdit, "GuiStage1Ms")
yL += 2
M14_AddText(yL, x1, wLeft, "Stage 2 (then):")
M14_AddText(yL, x1, wLeft, "Stage 2: after Stage 1 until ""Max hold duration"".", "cGray")
M14_AddText(yL, x1, wLeft, "H speed (px/tick, -left +right):")
M14_AddEdit(yL, x1, wEdit, "GuiH2")
M14_AddText(yL, x1, wLeft, "V speed down (px/tick):")
M14_AddEdit(yL, x1, wEdit, "GuiV2")
M14_AddText(yL, x1, wLeft, "Max hold duration (ms):")
M14_AddEdit(yL, x1, wEdit, "GuiMaxHoldMs")
M14_AddText(yL, x1, wLeft, "Timer interval (ms):")
M14_AddEdit(yL, x1, wEdit, "GuiIntervalMs")
M14_AddText(yL, x1, wLeft, "Jitter factor (0-1):")
M14_AddEdit(yL, x1, wEdit, "GuiJitter")
M14_AddText(yL, x1, wLeft, "Higher = more human-like tremor", "cGray")
yR := yTop
M14_AddCheck(yR, x2, 240, "GuiHoldMode", "Require holding LButton", "Checked")
yR += 2
M14_AddText(yR, x2, 240, "Hotkeys:")
M14_AddText(yR, x2, 240, "Delta Help switch:")
M14_AddEdit(yR, x2, wEdit, "GuiM14Hotkey")
yR += 2
M14_AddText(yR, x2, 240, "Light options:")
M14_AddText(yR, x2, 240, "Light arm:")
M14_AddEdit(yR, x2, wEdit, "GuiLightHotkey")
M14_AddText(yR, x2, 240, "Wait for L/RButton (seconds):")
M14_AddEdit(yR, x2, wEdit, "GuiLightWindowS")
M14_AddText(yR, x2, 240, "While LButton down send:")
M14_AddEdit(yR, x2, wEdit, "GuiLightSendKeyL")
M14_AddText(yR, x2, 240, "While RButton down send:")
M14_AddEdit(yR, x2, wEdit, "GuiLightSendKeyR")
yR += 6
M14_AddText(yR, x2, 240, "Auto breath:")
M14_AddCheck(yR, x2, 240, "GuiBreathEnabled", "Hold a key while LButton is down")
M14_AddText(yR, x2, 240, "Breath key name (e.g. Shift/LCtrl/Space):")
M14_AddEdit(yR, x2, wEdit, "GuiBreathKey")
yR += 6
M14_AddButton(yR, x2, wEdit, "M14ApplySettings", "Apply")
M14_AddText(yR, x2, 240, "F8: show/hide`nLight: arm then next L/RButton sends key", "cGray")
GuiControl, M14:, GuiH1, %GuiH1%
GuiControl, M14:, GuiV1, %GuiV1%
GuiControl, M14:, GuiStage1Ms, %GuiStage1Ms%
GuiControl, M14:, GuiH2, %GuiH2%
GuiControl, M14:, GuiV2, %GuiV2%
GuiControl, M14:, GuiMaxHoldMs, %GuiMaxHoldMs%
GuiControl, M14:, GuiIntervalMs, %GuiIntervalMs%
GuiControl, M14:, GuiJitter, %GuiJitter%
GuiControl, M14:, GuiHoldMode, %GuiHoldMode%
GuiControl, M14:, GuiM14Hotkey, %GuiM14Hotkey%
GuiControl, M14:, GuiLightHotkey, %GuiLightHotkey%
GuiControl, M14:, GuiLightWindowS, %GuiLightWindowS%
GuiControl, M14:, GuiLightSendKeyL, %GuiLightSendKeyL%
GuiControl, M14:, GuiLightSendKeyR, %GuiLightSendKeyR%
GuiControl, M14:, GuiBreathEnabled, %GuiBreathEnabled%
GuiControl, M14:, GuiBreathKey, %GuiBreathKey%
Gui, M14:Show, AutoSize
M14GuiVisible := 1
}
ResetCarry() {
global carryX, carryY
carryX := 0.0
carryY := 0.0
}
ResetMotionState(resetPressState := true) {
global lastTick, lbtnWasDown, lbtnDownAt, lbtnSuppressed, runUntilAt
lastTick := 0
lbtnSuppressed := 0
runUntilAt := 0
ResetCarry()
if (resetPressState) {
lbtnWasDown := 0
lbtnDownAt := 0
}
}
NormalizeHotkey(hk) {
hk := Trim(hk)
hk := RegExReplace(hk, "\s+", "")
return hk
}
StripLeadingTilde(hk) {
hk := NormalizeHotkey(hk)
if (SubStr(hk, 1, 1) = "~")
return SubStr(hk, 2)
return hk
}
EnsureLeadingTilde(hk) {
hk := NormalizeHotkey(hk)
if (hk = "")
return ""
if (SubStr(hk, 1, 1) = "~")
return hk
prefixes := ""
Loop {
ch := SubStr(hk, 1, 1)
if (ch = "$" || ch = "*" || ch = "<" || ch = ">") {
prefixes .= ch
hk := SubStr(hk, 2)
continue
}
break
}
return "~" . prefixes . hk
}
SetDynamicHotkey(ByRef currentHk, newHk, label) {
oldHk := currentHk
if (oldHk != "") {
Hotkey, %oldHk%, Off, UseErrorLevel
}
Hotkey, %newHk%, %label%, On UseErrorLevel
if (ErrorLevel) {
Hotkey, %newHk%, Off, UseErrorLevel
if (oldHk != "")
Hotkey, %oldHk%, %label%, On UseErrorLevel
return false
}
currentHk := newHk
return true
}
ApplyHotkeys(m14Hk, lightHk) {
global M14ToggleHotkey, LightArmHotkey
m14Hk := EnsureLeadingTilde(m14Hk)
lightHk := EnsureLeadingTilde(lightHk)
if (m14Hk = "" || lightHk = "") {
MsgBox, 262192, Invalid input, Hotkeys cannot be empty.
return false
}
if (RegExMatch(m14Hk, "i)F[89]$") || RegExMatch(lightHk, "i)F[89]$")) {
MsgBox, 48, Reserved hotkey, F8 and F9 are reserved.
return false
}
if (m14Hk = lightHk) {
MsgBox, 262192, Invalid input, Delta Help switch hotkey and Light arm hotkey cannot be the same.
return false
}
oldM14 := M14ToggleHotkey
oldLight := LightArmHotkey
ok1 := SetDynamicHotkey(M14ToggleHotkey, m14Hk, "M14_Toggle")
ok2 := SetDynamicHotkey(LightArmHotkey, lightHk, "Light_Arm")
if (!ok1 || !ok2) {
SetDynamicHotkey(M14ToggleHotkey, oldM14, "M14_Toggle")
SetDynamicHotkey(LightArmHotkey, oldLight, "Light_Arm")
MsgBox, 262192, Invalid input, Failed to register hotkey(s). Please check AHK hotkey syntax.
return false
}
return true
}
F8::
ShowDeltaHelp:
if (M14GuiVisible) {
Gui, M14:Hide
M14GuiVisible := 0
} else {
Gui, M14:Show, AutoSize
M14GuiVisible := 1
}
return
M14_Toggle:
macroActive := !macroActive
if (macroActive) {
ResetMotionState()
SetTimer, MouseMoveTick, %moveInterval%
} else {
SetTimer, MouseMoveTick, Off
ResetMotionState()
}
return
Light_Arm:
global lightArmed, LightWindowMs, lightRightFirstAt, lightLeftSent, lightRightSent, lightRightPending
lightArmed := 1
lightRightFirstAt := 0
lightLeftSent := 0
lightRightSent := 0
lightRightPending := 0
SetTimer, Light_SendRightDelayed, Off
SetTimer, Light_Reset, % -LightWindowMs
return
Light_Reset:
global lightArmed, lightRightFirstAt, lightLeftSent, lightRightSent, lightRightPending
lightArmed := 0
lightRightFirstAt := 0
lightLeftSent := 0
lightRightSent := 0
lightRightPending := 0
SetTimer, Light_SendRightDelayed, Off
return
Light_SendRightDelayed:
global lightRightPending, LightSendKeyR
if (lightRightPending) {
lightRightPending := 0
if (LightSendKeyR != "")
SendInput, %LightSendKeyR%
}
return
~LButton::
~RButton::
global lightArmed, LightSendKeyL, lightRightGraceMs, lightRightFirstAt, lightLeftSent, lightRightSent, lightRightDelayMs, lightRightPending
if (lightArmed) {
if (InStr(A_ThisHotkey, "RButton")) {
if (!lightRightSent) {
lightRightSent := 1
lightRightPending := 1
SetTimer, Light_SendRightDelayed, Off
SetTimer, Light_SendRightDelayed, % -lightRightDelayMs
}
if (lightRightFirstAt = 0) {
lightRightFirstAt := A_TickCount
SetTimer, Light_Reset, Off
SetTimer, Light_Reset, % -lightRightGraceMs
}
return
}
if (!lightLeftSent) {
lightLeftSent := 1
if (LightSendKeyL != "")
SendInput, %LightSendKeyL%
}
lightArmed := 0
SetTimer, Light_Reset, Off
}
return
AutoBreathTick:
EnsureBreathKey(GetKeyState("LButton", "P"))
return
M14ApplySettings:
Gui, M14:Submit, NoHide
h1Raw := Trim(GuiH1)
v1Raw := Trim(GuiV1)
h2Raw := Trim(GuiH2)
v2Raw := Trim(GuiV2)
jitterRaw := Trim(GuiJitter)
h1 := GuiH1 + 0
v1 := GuiV1 + 0
stage1 := Floor(GuiStage1Ms + 0)
h2 := GuiH2 + 0
v2 := GuiV2 + 0
maxHold := Floor(GuiMaxHoldMs + 0)
interval := Floor(GuiIntervalMs + 0)
jitter := GuiJitter + 0
holdMode := (GuiHoldMode ? 1 : 0)
newM14Hk := GuiM14Hotkey
newLightHk := GuiLightHotkey
newLightWindowS := GuiLightWindowS + 0
newLightSendKeyL := Trim(GuiLightSendKeyL)
newLightSendKeyR := Trim(GuiLightSendKeyR)
newBreathEnabled := (GuiBreathEnabled ? 1 : 0)
newBreathKey := Trim(GuiBreathKey)
if (!RegExMatch(h1Raw, "^[+-]?[0-9]+(\.[0-9]+)?$") || !RegExMatch(h2Raw, "^[+-]?[0-9]+(\.[0-9]+)?$")) {
MsgBox, 262192, Invalid input, Invalid parameters: Horizontal speeds must be numeric.
return
}
if (!RegExMatch(v1Raw, "^[+]?[0-9]+(\.[0-9]+)?$") || !RegExMatch(v2Raw, "^[+]?[0-9]+(\.[0-9]+)?$")) {
MsgBox, 262192, Invalid input, Invalid parameters: Vertical speeds must be numeric.
return
}
if (v1 < 0 || v2 < 0) {
MsgBox, 262192, Invalid input, Invalid parameters: Vertical speeds cannot be negative.
return
}
if (stage1 < 1) {
MsgBox, 262192, Invalid input, Stage 1 duration must be an integer >= 1 (ms).
return
}
if (maxHold < 1) {
MsgBox, 262192, Invalid input, Max hold duration must be an integer >= 1 (ms).
return
}
if (stage1 >= maxHold) {
MsgBox, 262192, Invalid input, Stage 1 duration must be smaller than Max hold duration.
return
}
if (interval < 1) {
MsgBox, 262192, Invalid input, Timer interval must be an integer >= 1 (ms).
return
}
if (!RegExMatch(jitterRaw, "^[+]?[0-9]+(\.[0-9]+)?$")) {
MsgBox, 262192, Invalid input, Jitter factor must be a number between 0 and 1.
return
}
if (jitter < 0 || jitter > 1) {
MsgBox, 262192, Invalid input, Jitter factor must be between 0 and 1.
return
}
if (newLightWindowS <= 0) {
MsgBox, 262192, Invalid input, Light listen window must be a number > 0 (seconds).
return
}
if (newLightSendKeyL = "") {
MsgBox, 262192, Invalid input, Light send key (LButton) cannot be empty.
return
}
if (newLightSendKeyR = "") {
MsgBox, 262192, Invalid input, Light send key (RButton) cannot be empty.
return
}
if (newBreathEnabled && newBreathKey = "") {
MsgBox, 262192, Invalid input, Auto breath key cannot be empty.
return
}
if (!ApplyHotkeys(newM14Hk, newLightHk))
return
moveInterval := interval
jitterFactor := jitter
maxHoldMs := maxHold
fastDurationMs := stage1
GuiHoldMode := holdMode
LightWindowMs := Floor(newLightWindowS * 1000)
LightSendKeyL := newLightSendKeyL
LightSendKeyR := newLightSendKeyR
oldBreathKey := BreathKey
BreathEnabled := newBreathEnabled
BreathKey := newBreathKey
GuiBreathEnabled := BreathEnabled
GuiBreathKey := BreathKey
if (breathIsDown && oldBreathKey != BreathKey) {
SendInput, {%oldBreathKey% up}
breathIsDown := 0
}
UpdateAutoBreathTimer()
GuiLightWindowS := (LightWindowMs / 1000.0)
GuiLightSendKeyL := LightSendKeyL
GuiLightSendKeyR := LightSendKeyR
fastStep := v1
slowStep := v2
earlyLeftStep := h1
leftStep := h2
ResetMotionState()
if (macroActive) {
SetTimer, MouseMoveTick, %moveInterval%
}
DH_SaveSettings()
return
M14GuiClose:
M14GuiEscape:
Gui, M14:Hide
M14GuiVisible := 0
return
MouseMoveTick:
if (!macroActive) {
SetTimer, MouseMoveTick, Off
return
}
now := A_TickCount
if (lastTick = 0) {
lastTick := now
}
dt := now - lastTick
lastTick := now
physicalDown := GetKeyState("LButton", "P")
if (GuiHoldMode) {
isActive := physicalDown
if (physicalDown && !lbtnWasDown) {
lbtnDownAt := now
lbtnWasDown := 1
lbtnSuppressed := 0
ResetCarry()
} else if (!physicalDown && lbtnWasDown) {
ResetMotionState()
return
}
if (lbtnSuppressed)
return
dhElapsed := now - lbtnDownAt
if (dhElapsed >= maxHoldMs) {
lbtnSuppressed := 1
ResetCarry()
return
}
} else {
if (physicalDown && !lbtnWasDown) {
lbtnDownAt := now
runUntilAt := now + maxHoldMs
lbtnWasDown := 1
ResetCarry()
} else if (!physicalDown && lbtnWasDown) {
lbtnWasDown := 0
}
isActive := (runUntilAt != 0 && now < runUntilAt)
if (!isActive) {
ResetMotionState(false)
return
}
dhElapsed := now - lbtnDownAt
}
if (isActive) {
if (dhElapsed < fastDurationMs) {
carryX += (earlyLeftStep) * (dt / moveInterval)
carryY += fastStep * (dt / moveInterval)
} else {
carryX += (leftStep) * (dt / moveInterval)
carryY += slowStep * (dt / moveInterval)
}
dx := (carryX > 0) ? Floor(carryX) : Ceil(carryX)
dy := (carryY > 0) ? Floor(carryY) : Ceil(carryY)
if (dx != 0)
carryX -= dx
if (dy != 0)
carryY -= dy
if (jitterFactor > 0) {
jitterMax := Round(jitterFactor * 9)
if (jitterMax > 0) {
Random, jx, -%jitterMax%, %jitterMax%
Random, jy, -%jitterMax%, %jitterMax%
dx += jx
dy += jy
}
}
if (dx != 0 || dy != 0) {
DllCall("mouse_event", "UInt", 0x0001, "Int", dx, "Int", dy, "UInt", 0, "UPtr", 0)
}
}
return

DH_Fields() {
    return "GuiH1,GuiV1,GuiStage1Ms,GuiH2,GuiV2,GuiMaxHoldMs,GuiIntervalMs,GuiJitter,GuiHoldMode,GuiM14Hotkey,GuiLightHotkey,GuiLightWindowS,GuiLightSendKeyL,GuiLightSendKeyR,GuiBreathEnabled,GuiBreathKey"
}
DH_LoadSettings() {
    global
    for DH_index, DH_key in StrSplit(DH_Fields(), ",") {
        IniRead, DH_value, %DH_ConfigPath%, Settings, %DH_key%, % %DH_key%
        %DH_key% := DH_value
    }
}
DH_SaveSettings() {
    global
    DH_temp := DH_ConfigPath ".tmp"
    FileDelete, %DH_temp%
    for DH_index, DH_key in StrSplit(DH_Fields(), ",") {
        IniWrite, % %DH_key%, %DH_temp%, Settings, %DH_key%
        if ErrorLevel {
            MsgBox, 48, Settings, Unable to save settings. Check folder write permission.
            return false
        }
    }
    FileMove, %DH_temp%, %DH_ConfigPath%, 1
    if ErrorLevel {
        MsgBox, 48, Settings, Unable to replace settings file.
        return false
    }
    return true
}
DH_OnExit(reason, code) {
    global BreathEnabled
    BreathEnabled := 0
    EnsureBreathKey(0)
}
