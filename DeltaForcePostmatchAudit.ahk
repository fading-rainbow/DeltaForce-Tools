#NoEnv
#SingleInstance Force
#Warn
SendMode Input
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
ListLines, Off

global APP_TITLE := "DeltaForce Radar"
global GuiH1, GuiV1, GuiStage1Ms, GuiH2, GuiV2, GuiMaxHoldMs, GuiIntervalMs, GuiJitter, GuiHoldMode, GuiM14Hotkey, GuiLightHotkey, GuiLightWindowS, GuiLightSendKeyL, GuiLightSendKeyR, GuiBreathEnabled, GuiBreathKey
global LOG_PATH := ""
global XOR_KEY := 0x5C
global MAX_CHUNK := 1048576
global MAX_RECOVERY_BYTES := 67108864
global CORPSE_TO_BOX_MS := 120000
global MATCH_END_GRACE_MS := 60000
global g_File := ""
global g_FileCreated := ""
global g_Offset := 0
global g_Pending := ""
global g_PendingLen := 0
global g_Match := ""
global g_LastReport := ""
global g_SelfTest := false
global g_IntegrationTest := false
global g_ReaderState := "正在初始化..."
global g_PollCount := 0
global g_LastWin32Error := 0
global g_LastParserError := ""
global g_Recovering := false
global g_PreserveCompletedRecovery := false
global g_OverlayReady := false
global g_OverlayVisible := false
global g_OverlayHwnd := 0
global g_OverlayTextHwnd := 0
global g_SoftRescanning := false
global g_StartSpotCatalog := {}
global g_ReaderRequest := ""

; 脚本与 DeltaForce 文件夹同级时，自动监听：
; <脚本目录>\DeltaForce\Saved\Logs\DeltaForce.log
LOG_PATH := DefaultLogPath()
commandLineLogPath := FindCommandLineLogPath()
if (commandLineLogPath != "" && IsValidLogPath(commandLineLogPath))
    LOG_PATH := commandLineLogPath

if HasCommandLineFlag("--self-test") {
    g_SelfTest := true
    RunSelfTest()
    ExitApp
}
if HasCommandLineFlag("--integration-test") {
    g_SelfTest := true
    g_IntegrationTest := true
    RunIntegrationTest()
    ExitApp
}
if HasCommandLineFlag("--recovery-test") {
    g_SelfTest := true
    g_IntegrationTest := true
    RunRecoveryTest()
    ExitApp
}
if HasCommandLineFlag("--no-active-test") {
    g_SelfTest := true
    RunNoActiveTest()
    ExitApp
}
if HasCommandLineFlag("--active-now-test") {
    g_SelfTest := true
    RunActiveNowTest()
    ExitApp
}
if HasCommandLineFlag("--replay-current-test") {
    g_SelfTest := true
    RunReplayCurrentTest()
    ExitApp
}
if HasCommandLineFlag("--soft-rescan-test") {
    g_SelfTest := true
    RunSoftRescanTest()
    ExitApp
}
if HasCommandLineFlag("--latest-completed-test") {
    g_SelfTest := true
    RunLatestCompletedTest()
    ExitApp
}
if HasCommandLineFlag("--overlay-test") {
    g_SelfTest := true
    RunOverlayTest()
    ExitApp
}
if HasCommandLineFlag("--gui-routing-test") {
    RunGuiRoutingTest()
    ExitApp
}

InitDeltaHelp()
BuildGui()
BuildOverlay()
ResetMatch()
try {
    OpenLogRecovering()
} catch startupError {
    HandlePollError(startupError)
}
Loop {
    try {
        request := g_ReaderRequest
        g_ReaderRequest := ""
        if (request = "rescan")
            SoftRescanLatestMatch()
        else if (request = "tail") {
            CloseLog()
            ResetMatch()
            g_LastReport := ""
            GuiControl, 1:, ReportEdit,
            OpenLogAtTail()
        } else
            PollLog()
        UpdateLivePanel()
    } catch pollError {
        ; 轮询线程永不因单次文件竞争、编码边界或解析异常退出。
        HandlePollError(pollError)
    }
    Sleep, 250
}
return

F9::
    ToggleOverlay()
    if !g_SoftRescanning
        g_ReaderRequest := "rescan"
    KeyWait, F9
return

RestartTail:
    g_ReaderRequest := "tail"
return

CopyReport:
    if (g_LastReport = "") {
        MsgBox, 64, %APP_TITLE%, 尚无已完成对局的赛后报告。
        return
    }
    Clipboard := g_LastReport
    ClipWait, 1
    MsgBox, 64, %APP_TITLE%, 赛后报告已复制到剪贴板。
return

OpenLogFolder:
    SplitPath, LOG_PATH,, logDir
    Run, explorer.exe "%logDir%"
return

RunCourseworkDemo:
    demoScript := A_ScriptDir "\CourseworkLogReplayer.ahk"
    if !FileExist(demoScript) {
        MsgBox, 16, %APP_TITLE%, 未找到作业日志回放器。
        return
    }
    Run, "%A_AhkPath%" "%demoScript%"
return

GuiClose:
    CloseLog()
    ExitApp
return

GuiEscape:
return

BuildGui() {
    global APP_TITLE, ReaderText, MatchText, PrivacyText, ReportEdit
    Gui, 1:New, +Resize +MinSize780x520, %APP_TITLE%
    Gui, 1:Margin, 14, 12
    Gui, 1:Font, s10, Microsoft YaHei UI
    Gui, 1:Add, Text, xm ym w750 vReaderText, Log:In preparation...
    Gui, 1:Add, Text, xm y+7 w750 vMatchText, game: witing next games
    Gui, 1:Add, Text, xm y+7 w750 c1F6F43 vPrivacyText, Radar Mode：Working...
    Gui, 1:Add, Button, xm y+12 w145 h30 gRestartTail, Listen form the end
    Gui, 1:Add, Button, x+9 yp w115 h30 gCopyReport, Copy the report
    Gui, 1:Add, Button, x+9 yp w105 h30 gOpenLogFolder, Open log 
    Gui, 1:Add, Button, x+9 yp w105 h30 gRunCourseworkDemo, Run job demo
    Gui, 1:Add, Button, x+9 yp w120 h30 gShowDeltaHelp, 参数设置 (F8)
    Gui, 1:Add, Text, xm y+12 w750, Real-time status / Completed report：
    Gui, 1:Font, s9, Consolas
    Gui, 1:Add, Edit, xm y+6 w750 h350 vReportEdit ReadOnly -Wrap HScroll WantTab
    Gui, 1:Font, s9, Microsoft YaHei UI
    Gui, 1:Show, w780 h560, %APP_TITLE%
}

BuildOverlay() {
    global g_OverlayReady, g_OverlayHwnd, g_OverlayTextHwnd, OverlayText
    GetOverlayMetrics(windowW, windowH, textW, textH, textY, fontSize, edgeMargin)
    Gui, Overlay:New, +AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale +Hwndg_OverlayHwnd
    Gui, Overlay:Margin, 0, 0
    Gui, Overlay:Color, EEAA99
    Gui, Overlay:Font, % "s" fontSize " q3 cFF0000", Microsoft YaHei UI
    Gui, Overlay:Add, Text, % "x0 y" textY " w" textW " h" textH " Right BackgroundTrans vOverlayText Hwndg_OverlayTextHwnd", 剩余人数：--
    Gui, Overlay:Show, % "Hide NoActivate x0 y0 w" windowW " h" windowH
    WinSet, TransColor, EEAA99, ahk_id %g_OverlayHwnd%
    g_OverlayReady := true
    UpdateOverlay()
}

ToggleOverlay() {
    global g_OverlayReady, g_OverlayVisible
    if !g_OverlayReady
        return
    ; 剩余人数始终显示；F9 只切换统计与存活玩家详情。
    g_OverlayVisible := !g_OverlayVisible
    UpdateOverlay()
}

SoftRescanLatestMatch() {
    global g_SoftRescanning, g_PreserveCompletedRecovery, g_Recovering
    global g_Match, g_LastReport, g_Offset, g_Pending, g_PendingLen
    global g_FileCreated, g_ReaderState, g_LastWin32Error, g_LastParserError, g_SelfTest

    ; 防止按键连发或长按 F9 时并发重建同一份全局状态。
    if g_SoftRescanning
        return false
    g_SoftRescanning := true
    g_ReaderState := "F9 软重启：正在从最近一局开头复盘补漏..."
    UpdateReaderStatus()
    UpdateOverlay()

    ; 回扫失败时恢复原状态，避免一次软重启反而清空仍可用的结果。
    oldMatch := g_Match
    oldReport := g_LastReport
    oldOffset := g_Offset
    oldPending := g_Pending
    oldPendingLen := g_PendingLen
    oldFileCreated := g_FileCreated
    oldReaderState := g_ReaderState
    oldWin32Error := g_LastWin32Error
    oldParserError := g_LastParserError
    oldPreserve := g_PreserveCompletedRecovery

    ok := false
    failureText := ""
    g_PreserveCompletedRecovery := true
    try {
        ok := OpenLogRecovering()
    } catch rescanError {
        failureText := ErrorText(rescanError)
    }
    g_PreserveCompletedRecovery := oldPreserve
    g_Recovering := false

    oldHadMatch := IsObject(oldMatch) && (oldMatch.Active || oldReport != "")
    rebuiltMatch := ok && IsObject(g_Match) && (g_Match.Active || g_LastReport != "")
    if (!ok || (oldHadMatch && !rebuiltMatch)) {
        g_Match := oldMatch
        g_LastReport := oldReport
        g_Offset := oldOffset
        g_Pending := oldPending
        g_PendingLen := oldPendingLen
        g_FileCreated := oldFileCreated
        g_LastWin32Error := oldWin32Error
        g_LastParserError := oldParserError
        if (failureText = "")
            failureText := "未找到可重建的最近一局锚点"
        g_ReaderState := "F9 复盘补漏失败，已保留原状态：" failureText
        if !g_SelfTest {
            if (IsObject(g_Match) && g_Match.Active)
                GuiControl, 1:, ReportEdit, % BuildLiveReport()
            else if (g_LastReport != "")
                GuiControl, 1:, ReportEdit, %g_LastReport%
        }
        g_SoftRescanning := false
        UpdateReaderStatus()
        UpdateMatchStatus()
        UpdateOverlay()
        return false
    }

    if !g_SelfTest {
        if g_Match.Active
            GuiControl, 1:, ReportEdit, % BuildLiveReport()
        else if (g_LastReport != "")
            GuiControl, 1:, ReportEdit, %g_LastReport%
        else
            GuiControl, 1:, ReportEdit,
    }
    if g_Match.Active
        g_ReaderState := "F9 软重启完成；已从本局开头复盘补漏并继续监听；偏移 " g_Offset
    else if (g_LastReport != "")
        g_ReaderState := "F9 软重启完成；已重建最近完成对局并继续等待下一局；偏移 " g_Offset
    else
        g_ReaderState := "F9 软重启完成；未发现最近对局，继续等待开局"
    g_SoftRescanning := false
    UpdateReaderStatus()
    UpdateMatchStatus()
    UpdateOverlay()
    return true
}

PositionOverlay() {
    global g_OverlayHwnd
    GetOverlayMetrics(windowW, windowH, textW, textH, textY, fontSize, edgeMargin)
    SysGet, monitorArea, Monitor, 1
    overlayX := monitorAreaRight - windowW - edgeMargin
    overlayY := monitorAreaTop + edgeMargin
    Gui, Overlay:Font, % "s" fontSize " q3 cFF0000", Microsoft YaHei UI
    GuiControl, Overlay:Font, OverlayText
    GuiControl, Overlay:Move, OverlayText, % "x0 y" textY " w" textW " h" textH
    Gui, Overlay:Show, % "NoActivate x" overlayX " y" overlayY " w" windowW " h" windowH
    WinSet, TransColor, EEAA99, ahk_id %g_OverlayHwnd%
}

GetOverlayMetrics(ByRef windowW, ByRef windowH, ByRef textW, ByRef textH, ByRef textY, ByRef fontSize, ByRef edgeMargin) {
    global g_OverlayVisible, g_Match
    SysGet, monitorArea, Monitor, 1
    screenW := monitorAreaRight - monitorAreaLeft
    screenH := monitorAreaBottom - monitorAreaTop
    scale := OverlayScaleForResolution(screenW, screenH)
    fontSize := Round(10 * scale)
    if (fontSize < 8)
        fontSize := 8
    if g_OverlayVisible {
        aliveRows := IsObject(g_Match) ? SortedRosterBySpawn(true).Length() : 0
        lineCount := 3 + (aliveRows > 0 ? aliveRows : 1)
        windowW := Round(520 * scale)
        textW := Round(510 * scale)
        ; 微软雅黑的实际中文行高明显大于字号。按 28px 基准为每行
        ; 留足空间，F9 展开时优先保证全部存活玩家都可见。
        textH := Round((lineCount * 28 + 16) * scale)
        windowH := textH + Round(8 * scale)
    } else {
        windowW := Round(190 * scale)
        windowH := Round(28 * scale)
        textW := Round(180 * scale)
        textH := Round(24 * scale)
    }
    textY := Round(2 * scale)
    edgeMargin := Round(10 * scale)
}

OverlayScaleForResolution(screenW, screenH) {
    scaleW := screenW / 1920.0
    scaleH := screenH / 1080.0
    scale := scaleW < scaleH ? scaleW : scaleH
    if (scale < 0.75)
        scale := 0.75
    else if (scale > 2.5)
        scale := 2.5
    return scale
}

CandidateRemaining() {
    global g_Match
    if !IsObject(g_Match) || !g_Match.Active || g_Match.InitialCount <= 0
        return ""
    remaining := g_Match.InitialCount - ObjectCount(g_Match.Corpses) - ObjectCount(g_Match.Boxes) - ObjectCount(g_Match.Escaped) - (g_Match.LocalCorpseUnknown ? 1 : 0)
    return remaining < 0 ? 0 : remaining
}

UpdateOverlay() {
    global g_OverlayReady, g_OverlayVisible
    if !g_OverlayReady
        return
    text := BuildOverlayText()
    GuiControl, Overlay:, OverlayText, %text%
    PositionOverlay()
}

BuildOverlayText() {
    global g_Match, g_OverlayVisible, g_SoftRescanning
    remaining := CandidateRemaining()
    text := remaining = "" ? "剩余人数：--" : "剩余人数：" remaining
    if g_SoftRescanning
        text .= "  复盘中..."
    if !g_OverlayVisible
        return text

    if !IsObject(g_Match) || !g_Match.Active {
        text .= "`n存活数：--  死亡数：--  成盒数：--  撤离数：--"
        text .= "`n暂无进行中的对局"
        return text
    }

    aliveUids := SortedRosterBySpawn(true)
    deathCount := ObjectCount(g_Match.Corpses) + (g_Match.LocalCorpseUnknown ? 1 : 0)
    text .= "`n存活数：" aliveUids.Length() "  死亡数：" deathCount "  成盒数：" ObjectCount(g_Match.Boxes) "  撤离数：" ObjectCount(g_Match.Escaped)
    text .= "`n存活玩家（" aliveUids.Length() "）"
    if (aliveUids.Length() = 0)
        text .= "`n暂无"
    else {
        for _, uid in aliveUids
            text .= "`n" OverlayPlayerRow(uid)
    }
    return text
}

IsAbsolutePath(path) {
    return RegExMatch(path, "i)^[A-Z]:\\") || (SubStr(path, 1, 2) = "\\")
}

IsValidLogPath(path) {
    return IsAbsolutePath(path) && RegExMatch(path, "i)\.log$")
}

DefaultLogPath() {
    ; 常规部署：脚本与 DeltaForce 文件夹同级。
    primary := A_ScriptDir "\DeltaForce\Saved\Logs\DeltaForce.log"
    ; 兼容当前安装目录外层还带一个“Delta Force”文件夹的情况，
    ; 这样从 E:\Delta Force 直接运行脚本也能自动找到实际日志。
    candidates := [primary
        , A_ScriptDir "\Delta Force\DeltaForce\Saved\Logs\DeltaForce.log"]
    for _, candidate in candidates {
        if FileExist(candidate)
            return candidate
    }
    ; 日志尚未生成时仍返回标准目标，轮询会等待文件出现。
    return primary
}

FindCommandLineLogPath() {
    for index, argument in A_Args {
        if (argument = "--log" && index < A_Args.Length())
            return A_Args[index + 1]
    }
    return ""
}

HasCommandLineFlag(flag) {
    for _, argument in A_Args {
        if (argument = flag)
            return true
    }
    return false
}

GuiSize:
    if (A_EventInfo = 1)
        return
    editW := A_GuiWidth - 28
    editH := A_GuiHeight - 174
    if (editH < 220)
        editH := 220
    GuiControl, 1:Move, ReaderText, % "w" editW
    GuiControl, 1:Move, MatchText, % "w" editW
    GuiControl, 1:Move, PrivacyText, % "w" editW
    GuiControl, 1:Move, ReportEdit, % "w" editW " h" editH
return

ResetMatch(showStatus := true) {
    global g_Match
    ; 所有入口（新开局、文件重建、切换路径、测试）都通过同一工厂创建状态，
    ; 避免遗漏映射/队列导致下一局继承上一局数据。
    g_Match := NewMatchState()
    if showStatus {
        UpdateMatchStatus()
        UpdateOverlay()
    }
}

NewMatchState() {
    return {Active:false
        , Finalized:false
        , EndReason:""
        , StartTime:""
        , StartAnchorSource:""
        , EndTime:""
        , PendingEnd:""
        , LastLogTime:""
        , InitialCount:0
        , Roster:{}
        , RosterOrder:[]
        , Teams:{}
        , SpawnPoints:{}
        , StartSpotGroups:{}
        , PendingSpawnGroups:{}
        , SpawnNameToTeamStart:{}
        , NameToUid:{}
        , UidToName:{}
        , ActorToUid:{}
        , ActorToHero:{}
        , HeroByUid:{}
        , PendingRescueCheck:""
        , SelfUid:""
        , Corpses:{}
        , CorpseOrder:[]
        , Rescued:{}
        , RescueEvents:[]
        , Downed:{}
        , DownedRescueEvents:[]
        , LocalCorpseUnknown:false
        , LocalCorpseTime:""
        , Escaped:{}
        , EscapeOrder:[]
        , Exit3ByName:{}
        , EscapedActionByName:{}
        , Exit3ByUid:{}
        , EscapedActionByUid:{}
        , ExitRuntimeEvents:[]
        , RocketHiddenCandidates:{}
        , RocketEscapePending:""
        , Knockdowns:{}
        , DeadBodyActors:[]
        , Boxes:{}
        , BoxOrder:[]
        , Timeline:[]
        , Warnings:[]
        , BytesAtStart:0}
}

OpenLogAtTail() {
    global LOG_PATH, g_File, g_FileCreated, g_Offset, g_Pending, g_PendingLen, g_ReaderState, g_LastWin32Error
    if (LOG_PATH = "") {
        g_ReaderState := "自动监听路径未就绪"
        UpdateReaderStatus()
        return false
    }
    if !FileExist(LOG_PATH) {
        g_ReaderState := "未找到日志；每 250 ms 重试"
        UpdateReaderStatus()
        return false
    }
    size := SharedFileSize(LOG_PATH, errorCode)
    if (size < 0) {
        g_LastWin32Error := errorCode
        g_ReaderState := "日志共享只读打开失败；Win32=" errorCode "；每 250 ms 重试"
        UpdateReaderStatus()
        return false
    }
    FileGetTime, g_FileCreated, %LOG_PATH%, C
    g_Offset := size
    CloseLog()
    g_Pending := ""
    g_PendingLen := 0
    g_LastWin32Error := 0
    g_ReaderState := "已从当前文件尾部开始共享只读监听；偏移 " g_Offset "/" size
    UpdateReaderStatus()
    return true
}

OpenLogRecovering() {
    global LOG_PATH, XOR_KEY, MAX_CHUNK, MAX_RECOVERY_BYTES
    global g_File, g_FileCreated, g_Offset, g_Pending, g_PendingLen, g_ReaderState
    global g_LastWin32Error, g_Recovering, g_Match, g_LastReport, g_SelfTest
    global g_PreserveCompletedRecovery

    if (LOG_PATH = "") {
        g_FileCreated := ""
        g_ReaderState := "自动监听路径未就绪"
        UpdateReaderStatus()
        return false
    }
    if !FileExist(LOG_PATH) {
        g_FileCreated := ""
        g_ReaderState := "未找到日志；每 250 ms 重试，文件出现后尝试恢复当前局"
        UpdateReaderStatus()
        return false
    }

    size := SharedFileSize(LOG_PATH, errorCode)
    if (size < 0) {
        g_LastWin32Error := errorCode
        g_ReaderState := "启动恢复时打开日志失败；Win32=" errorCode
        UpdateReaderStatus()
        return false
    }

    FileGetTime, g_FileCreated, %LOG_PATH%, C
    CloseLog()
    scanStart := size > MAX_RECOVERY_BYTES ? size - MAX_RECOVERY_BYTES : 0
    g_Offset := scanStart
    g_Pending := ""
    g_PendingLen := 0
    g_LastReport := ""
    g_LastWin32Error := 0
    g_Recovering := true
    ; 回扫期间不主动清空浮层文字；F9 触发时保留旧结果，直到新状态
    ; 完整重建后一次性替换，避免长日志复盘期间闪成“--”。
    ResetMatch(false)

    g_ReaderState := "正在回扫已有日志并尝试恢复当前局；起始偏移 " scanStart "/" size
    UpdateReaderStatus()
    if !g_SelfTest
        Sleep, 10

    targetSize := size
    recoveredBytes := targetSize - scanStart
    got := SharedReadAt(LOG_PATH, scanStart, recoveredBytes, encoded, errorCode)
    if (got < 0) {
        g_Recovering := false
        g_LastWin32Error := errorCode
        g_ReaderState := "启动恢复读取失败；Win32=" errorCode "；偏移 " scanStart "/" targetSize
        UpdateReaderStatus()
        return false
    }

    ms23Anchor := "TempMS23-Alloc - Begin[PlayerNum:"
    memberAnchor := "UStartSpotAllocator_SOL - PlayerMembers(Team):"
    ; PlayerMembers 在普通 TempMS23 与绝密 TempMa2 两种分配器中都会出现，
    ; 因此先找它，既只需一次全缓冲逆向扫描，也不会因为绝密局没有
    ; TempMS23 Begin 而错误退回上一局。极旧日志缺少它时才回退 MS23。
    anchorOffset := FindLastXorAsciiInBuffer(encoded, got, memberAnchor, XOR_KEY)
    if (anchorOffset < 0)
        anchorOffset := FindLastXorAsciiInBuffer(encoded, got, ms23Anchor, XOR_KEY)
    ; StartSpotGroup/OrientationGroups 通常紧邻 Alloc Begin 之前输出。
    ; 仅从 PlayerNum 锚点回放会丢掉 TId -> TeamStart 名称，导致
    ; Member-End 虽然能恢复 UID，却只能显示“未记录”。恢复时把同一
    ; 分配块的 InitializeAllocator 前缀一并纳入；实时监听仍会自然收到这段前缀。
    metadataOffset := FindLastXorAsciiBefore(encoded, got, "InitializeAllocator SpecifiedTemplateId=", XOR_KEY, anchorOffset)
    if (metadataOffset >= 0 && anchorOffset - metadataOffset <= 262144)
        anchorOffset := metadataOffset
    else {
        ; 兼容缺少 InitializeAllocator 行的版本：至少回放最近的
        ; Find StartSpotGroup 行，并让后续 TeamStartId 补齐区域信息。
        metadataOffset := FindLastXorAsciiBefore(encoded, got, "Find StartSpotGroup:", XOR_KEY, anchorOffset)
        if (metadataOffset >= 0 && anchorOffset - metadataOffset <= 262144)
            anchorOffset := metadataOffset
    }
    g_Offset := targetSize
    if (anchorOffset >= 0) {
        lineOffset := anchorOffset
        encodedLf := 10 ^ XOR_KEY
        while (lineOffset > 0 && NumGet(encoded, lineOffset - 1, "UChar") != encodedLf)
            lineOffset -= 1
        replayLength := got - lineOffset
        VarSetCapacity(replayBytes, replayLength, 0)
        Loop, %replayLength% {
            value := NumGet(encoded, lineOffset + A_Index - 1, "UChar") ^ XOR_KEY
            NumPut(value, replayBytes, A_Index - 1, "UChar")
        }
        QueueDecodedBytes(replayBytes, replayLength)
    }

    g_Recovering := false
    g_File := ""
    if g_Match.Active {
        g_ReaderState := "已从已有日志恢复正在进行的对局；回扫 " FormatBytes(recoveredBytes) "；偏移 " g_Offset "/" targetSize
        UpdateReaderStatus()
        UpdateMatchStatus()
        UpdateLivePanel()
    } else if (g_PreserveCompletedRecovery && g_LastReport != "") {
        g_ReaderState := "已回放最近一局并保留结算报告；偏移 " g_Offset "/" targetSize
        UpdateReaderStatus()
        UpdateMatchStatus()
    } else {
        ResetMatch()
        g_LastReport := ""
        if !g_SelfTest
            GuiControl, 1:, ReportEdit,
        g_ReaderState := "回扫完成，未找到尚未结算的对局；已从当前文件尾部继续监听；偏移 " g_Offset "/" targetSize
        UpdateReaderStatus()
        UpdateMatchStatus()
    }
    return true
}

FindLastXorAsciiInBuffer(ByRef buffer, length, needleText, xorKey) {
    needleLength := StrPut(needleText, "UTF-8") - 1
    if (needleLength <= 0 || length < needleLength)
        return -1
    VarSetCapacity(needle, needleLength + 1, 0)
    StrPut(needleText, &needle, needleLength + 1, "UTF-8")
    start := length - needleLength
    Loop, % start + 1 {
        candidate := start - (A_Index - 1)
        if ((NumGet(buffer, candidate, "UChar") ^ xorKey) != NumGet(needle, 0, "UChar"))
            continue
        matched := true
        Loop, %needleLength% {
            index := A_Index - 1
            if ((NumGet(buffer, candidate + index, "UChar") ^ xorKey) != NumGet(needle, index, "UChar")) {
                matched := false
                break
            }
        }
        if matched
            return candidate
    }
    return -1
}

FindLastXorAsciiBefore(ByRef buffer, length, needleText, xorKey, endExclusive) {
    needleLength := StrPut(needleText, "UTF-8") - 1
    if (needleLength <= 0 || length < needleLength || endExclusive <= 0)
        return -1
    VarSetCapacity(needle, needleLength + 1, 0)
    StrPut(needleText, &needle, needleLength + 1, "UTF-8")
    start := endExclusive - needleLength
    if (start > length - needleLength)
        start := length - needleLength
    if (start < 0)
        return -1
    Loop, % start + 1 {
        candidate := start - (A_Index - 1)
        if ((NumGet(buffer, candidate, "UChar") ^ xorKey) != NumGet(needle, 0, "UChar"))
            continue
        matched := true
        Loop, %needleLength% {
            index := A_Index - 1
            if ((NumGet(buffer, candidate + index, "UChar") ^ xorKey) != NumGet(needle, index, "UChar")) {
                matched := false
                break
            }
        }
        if matched
            return candidate
    }
    return -1
}

OpenLogAtStart() {
    global LOG_PATH, g_File, g_FileCreated, g_Offset, g_Pending, g_PendingLen, g_ReaderState, g_LastWin32Error
    CloseLog()
    size := SharedFileSize(LOG_PATH, errorCode)
    if (size < 0) {
        g_LastWin32Error := errorCode
        return false
    }
    FileGetTime, g_FileCreated, %LOG_PATH%, C
    g_Offset := 0
    g_Pending := ""
    g_PendingLen := 0
    g_LastWin32Error := 0
    g_ReaderState := "检测到日志重建，已从新文件开头继续"
    UpdateReaderStatus()
    return true
}

CloseLog() {
    global g_File
    if IsObject(g_File)
        g_File.Close()
    g_File := ""
}

PollLog() {
    global LOG_PATH, g_File, g_FileCreated, g_Offset, g_Pending, g_PendingLen, g_ReaderState, MAX_CHUNK, g_PollCount, g_LastWin32Error, g_LastParserError, g_LastReport, g_SelfTest
    g_PollCount += 1
    if (LOG_PATH = "") {
        CloseLog()
        g_ReaderState := "自动监听路径未就绪"
        UpdateReaderStatus()
        return
    }
    if !FileExist(LOG_PATH) {
        CloseLog()
        g_FileCreated := ""
        g_ReaderState := "日志暂时不存在；等待重建"
        UpdateReaderStatus()
        return
    }
    if (g_FileCreated = "") {
        OpenLogRecovering()
        return
    }

    FileGetTime, currentCreated, %LOG_PATH%, C
    size := SharedFileSize(LOG_PATH, errorCode)
    if (size < 0) {
        g_LastWin32Error := errorCode
        g_ReaderState := "共享只读检查失败；Win32=" errorCode "；轮询 " g_PollCount
        UpdateReaderStatus()
        return
    }
    if (size < g_Offset || (currentCreated != "" && g_FileCreated != "" && currentCreated != g_FileCreated)) {
        ; 回放器会删除并重建文件；旧的半行、事件集合和结算报告不能带入下一局。
        CloseLog()
        g_FileCreated := currentCreated
        g_Offset := 0
        g_Pending := ""
        g_PendingLen := 0
        g_LastReport := ""
        g_LastWin32Error := 0
        g_LastParserError := ""
        ResetMatch(false)
        if !g_SelfTest
            GuiControl, 1:, ReportEdit,
        g_ReaderState := "检测到日志重建，已从新文件开头继续"
        UpdateReaderStatus()
    }

    if (size <= g_Offset) {
        if PromoteCorpseTimeouts()
            UpdateLivePanel()
        TryFinalizePendingEnd()
        if (Mod(g_PollCount, 4) = 0) {
            g_ReaderState := "共享只读监听正常；偏移 " g_Offset "/" size "；轮询 " g_PollCount
            UpdateReaderStatus()
        }
        return
    }

    totalRead := 0
    while (g_Offset < size && totalRead < MAX_CHUNK * 4) {
        available := size - g_Offset
        toRead := available > MAX_CHUNK ? MAX_CHUNK : available
        got := SharedReadAt(LOG_PATH, g_Offset, toRead, encoded, errorCode)
        if (got < 0) {
            g_LastWin32Error := errorCode
            g_ReaderState := "增量读取失败；Win32=" errorCode "；偏移 " g_Offset "/" size "；轮询 " g_PollCount
            UpdateReaderStatus()
            return
        }
        if (got = 0)
            break
        totalRead += got
        g_Offset += got
        DecodeAndQueue(encoded, got)
    }
    if (totalRead > 0) {
        g_LastWin32Error := 0
        g_LastParserError := ""
        g_ReaderState := "共享只读监听正常；本次读取 " FormatBytes(totalRead) "；偏移 " g_Offset "/" size "；轮询 " g_PollCount
        UpdateReaderStatus()
    }
    TryFinalizePendingEnd()
}

HandlePollError(e) {
    global g_ReaderState, g_LastParserError
    message := ErrorText(e)
    if (message = "")
        message := "未知轮询异常"
    g_LastParserError := message
    g_ReaderState := "轮询异常已隔离；下一轮继续重试：" message
    UpdateReaderStatus()
}

HandleParserError(e, line := "") {
    global g_Match, g_ReaderState, g_LastParserError, g_Recovering
    message := ErrorText(e)
    if (message = "")
        message := "未知解析异常"
    g_LastParserError := message
    if (line != "")
        message .= "（已跳过一条异常日志行）"
    if IsObject(g_Match) && g_Match.Active
        AddWarning("解析器已跳过一条异常日志记录：" message)
    g_ReaderState := "解析异常已隔离；继续监听"
    if !g_Recovering {
        UpdateReaderStatus()
        UpdateLivePanel()
    }
}

ErrorText(e) {
    if IsObject(e) {
        if (e.HasKey("Message") && e.Message != "")
            return e.Message
        if (e.HasKey("What") && e.What != "")
            return e.What
        if (e.HasKey("Extra") && e.Extra != "")
            return e.Extra
    }
    return Trim(e "")
}

SharedFileSize(path, ByRef errorCode) {
    handle := DllCall("CreateFileW"
        , "WStr", path
        , "UInt", 0x80000000
        , "UInt", 0x00000007
        , "Ptr", 0
        , "UInt", 3
        , "UInt", 0x00000080
        , "Ptr", 0
        , "Ptr")
    if (handle = -1 || handle = 0) {
        errorCode := A_LastError
        return -1
    }
    VarSetCapacity(sizeBuffer, 8, 0)
    ok := DllCall("GetFileSizeEx", "Ptr", handle, "Ptr", &sizeBuffer)
    if !ok {
        errorCode := A_LastError
        DllCall("CloseHandle", "Ptr", handle)
        return -1
    }
    size := NumGet(sizeBuffer, 0, "Int64")
    DllCall("CloseHandle", "Ptr", handle)
    errorCode := 0
    return size
}

SharedReadAt(path, offset, requested, ByRef buffer, ByRef errorCode) {
    handle := DllCall("CreateFileW"
        , "WStr", path
        , "UInt", 0x80000000
        , "UInt", 0x00000007
        , "Ptr", 0
        , "UInt", 3
        , "UInt", 0x00000080
        , "Ptr", 0
        , "Ptr")
    if (handle = -1 || handle = 0) {
        errorCode := A_LastError
        return -1
    }
    moved := DllCall("SetFilePointerEx"
        , "Ptr", handle
        , "Int64", offset
        , "Ptr", 0
        , "UInt", 0)
    if !moved {
        errorCode := A_LastError
        DllCall("CloseHandle", "Ptr", handle)
        return -1
    }
    VarSetCapacity(buffer, requested, 0)
    bytesRead := 0
    ok := DllCall("ReadFile"
        , "Ptr", handle
        , "Ptr", &buffer
        , "UInt", requested
        , "UIntP", bytesRead
        , "Ptr", 0)
    if !ok {
        errorCode := A_LastError
        DllCall("CloseHandle", "Ptr", handle)
        return -1
    }
    DllCall("CloseHandle", "Ptr", handle)
    errorCode := 0
    return bytesRead
}

DecodeAndQueue(ByRef encoded, length) {
    global XOR_KEY
    VarSetCapacity(decoded, length, 0)
    Loop, %length% {
        value := NumGet(encoded, A_Index - 1, "UChar") ^ XOR_KEY
        NumPut(value, decoded, A_Index - 1, "UChar")
    }
    QueueDecodedBytes(decoded, length)
}

QueueDecodedBytes(ByRef source, length) {
    global g_Pending, g_PendingLen, g_Recovering, g_Match
    if (length <= 0)
        return
    oldLen := g_PendingLen
    newLen := oldLen + length
    ; Native writes use an owned local buffer; UI callbacks must never resize it.
    if (VarSetCapacity(joined, newLen, 0) < newLen)
        throw Exception("日志缓冲区分配失败")
    if (oldLen > 0)
        DllCall("RtlMoveMemory", "Ptr", &joined, "Ptr", &g_Pending, "UPtr", oldLen)
    DllCall("RtlMoveMemory", "Ptr", &joined + oldLen, "Ptr", &source, "UPtr", length)

    lastLf := -1
    Loop, %newLen% {
        if (NumGet(joined, A_Index - 1, "UChar") = 10)
            lastLf := A_Index - 1
    }
    if (lastLf < 0) {
        if (newLen > 1048576) {
            g_PendingLen := 0
            VarSetCapacity(g_Pending, 0)
            throw Exception("日志单行超过 1 MiB，已清理异常半行")
        }
        VarSetCapacity(g_Pending, newLen, 0)
        DllCall("RtlMoveMemory", "Ptr", &g_Pending, "Ptr", &joined, "UPtr", newLen)
        g_PendingLen := newLen
        return
    }

    parseLen := lastLf + 1
    text := StrGet(&joined, parseLen, "UTF-8")
    remain := newLen - parseLen
    VarSetCapacity(g_Pending, remain, 0)
    if (remain > 0)
        DllCall("RtlMoveMemory", "Ptr", &g_Pending, "Ptr", &joined + parseLen, "UPtr", remain)
    g_PendingLen := remain
    for _, line in StrSplit(text, "`n", "`r") {
        if (line != "")
            ProcessLine(line)
        ; 回扫缓冲区已经从“最新一局”的最后开局锚点开始；一旦该局
        ; 正式封存，后面的大厅噪声无需继续逐行解析。
        if (g_Recovering && IsObject(g_Match) && g_Match.Finalized)
            break
    }

}

ProcessLine(line) {
    global g_SelfTest
    try {
        ProcessLineCore(line)
    } catch parseError {
        if g_SelfTest {
            FileAppend, % "SELFTEST FAIL: parser exception " ErrorText(parseError) "`n", *
            ExitApp, 1
        }
        HandleParserError(parseError, line)
    }
}

ProcessLineCore(line) {
    global g_Match
    time := ParseLogTime(line)

    ; 出生分组元数据通常在 TempMS23-Alloc 开局锚点之前输出，先放入
    ; 跨锚点缓存；否则 BeginMatch 清空状态后会丢失 TGroupI -> TeamStart。
    CaptureStartSpotMetadata(line)

    startCount := ""
    startSource := ""
    if RegExMatch(line, "TempMS23-Alloc - Begin\[PlayerNum:(\d+)", m) {
        startCount := m1 + 0
        startSource := "TempMS23"
    } else if RegExMatch(line, "UStartSpotAllocator_SOL - PlayerMembers\(Team\):\s*(\d+)\s*,\s*AIPlayerMembers:", m) {
        startCount := m1 + 0
        startSource := "PlayerMembers/TempMa2"
    }
    if (startCount != "") {
        BeginMatch(time, startCount, startSource)
        return
    }

    if !g_Match.Active
        return

    g_Match.LastLogTime := time
    isLifecycleSignal := InStr(line, "ClientNotifySOLRescue") || InStr(line, "CourseworkEvent Type=RESCUE") || InStr(line, "IsCanBeRescue")
    if !isLifecycleSignal
        PromoteCorpseTimeouts(time)

    if RegExMatch(line, "PlayerName\s*[:=]\s*([^,\]\r\n]+).*?\bUin\s*[:=]\s*(\d+)", m)
        RememberPlayerName(Trim(m1), m2)
    else if RegExMatch(line, "\bUin\s*[:=]\s*(\d+).*?PlayerName\s*[:=]\s*([^,\]\r\n]+)", m)
        RememberPlayerName(Trim(m2), m1)
    else if RegExMatch(line, "UDFMFSM_ZiplineControlAction\s+(?:Enter|Exit)\s+(.+?)\s+BP_DFMCharacter_C_\d+\s+(\d+)\s+Autonomous=", m)
        RememberPlayerName(Trim(m1), m2)
    else if RegExMatch(line, "DFMFSM_UseItemAllControlAction.*?uin\s*:\s*(\d+)\s*\}.*?\bName\s*=\s*(.+?)\s*$", m)
        RememberPlayerName(Trim(m2), m1)

    ; 选人/小队界面会直接给出 HeroId + UID；这是本地玩家最早、
    ; 最强的干员绑定证据，不必等待角色 Actor 后续再次暴露 UID。
    if RegExMatch(line, "AssemblyLabel:SetHeroInfo,\s*(880\d+)\s*,\s*(\d+)", m)
        RememberUidHero(m2, m1)
    else if RegExMatch(line, "OnCSMatchRoomSolChangeHeroNtf,\s*playerId,\s*(\d+)\s*,\s*heroId,\s*(880\d+)", m)
        RememberUidHero(m1, m2)

    ; 角色 Actor 是昵称/UID 与 AvatarId(HeroId) 之间的稳定中间键。
    ; 两类日志的先后顺序并不固定，因此分别缓存，并在任一侧到达时合并。
    if RegExMatch(line, "\{\s*BP_DFMCharacter_C_(\d+)\s*,\s*uin\s*:\s*(\d+)\s*\}", m)
        RememberActorUid(m1, m2)
    else if RegExMatch(line, "\[Client\|(\d+)\|[^\]]*\].*?\[BP_DFMCharacter_C_(\d+)\]", m)
        RememberActorUid(m2, m1)
    else if RegExMatch(line, "AGPCharacterBase::BeginDestroy,\s*Uin=(\d+),\s*Name=BP_DFMCharacter_C_(\d+)", m)
        RememberActorUid(m2, m1)
    else if RegExMatch(line, "UDFMFSM_ZiplineControlAction\s+(?:Enter|Exit)\s+.+?\s+BP_DFMCharacter_C_(\d+)\s+(\d+)\s+Autonomous=", m)
        RememberActorUid(m1, m2)

    if RegExMatch(line, "Owner\s+BP_DFMCharacter_C_(\d+)\s+AfterCheckSetAvatar:.*?->\s*(880\d+)", m)
        RememberActorHero(m1, m2)
    else if RegExMatch(line, "OwnerCharacter:\s*BP_DFMCharacter_C_(\d+),\s*AvatarId:\s*(880\d+)", m)
        RememberActorHero(m1, m2)

    if RegExMatch(line, "ADFMCharacter::IsCanBeRescue Name\s+(.+?)\s*$", m)
        g_Match.PendingRescueCheck := {Name:Trim(m1), Time:time}

    if (IsObject(g_Match.PendingRescueCheck) && RegExMatch(line, "ADFMCharacter::IsCanBeRescue\s+bTmpIsDead=(\d+).*?DeathWaitRescueTime=(-?\d+(?:\.\d+)?)\s+bDeathCanRescue=([01])", m)) {
        pendingCheck := g_Match.PendingRescueCheck
        checkAge := TimeDiffMs(pendingCheck.Time, time)
        nameKey := NameKey(pendingCheck.Name)
        if (checkAge >= 0 && checkAge <= 1000 && g_Match.NameToUid.HasKey(nameKey))
            UpdateCorpseRescueWindow(g_Match.NameToUid[nameKey], time, m2 + 0.0, m3 + 0)
        g_Match.PendingRescueCheck := ""
    }

    if RegExMatch(line, "UStartSpotAllocator_SOL - PlayerUid:\s*(\d+)", m) {
        AddRosterUid(m1)
    }

    ; Allocator 的 Member-End 行还会带有可靠的分组证据：
    ; `- [TId:<StartSpotGroupId> - <slot>]`。这一字段覆盖整队成员，
    ; 而 AllocStartSpot AdjustLoc 通常只为本地玩家输出，不能只依赖后者。
    if RegExMatch(line, "Member-End(?:\(Allocated\))?:\s*\[UId:(\d+),\s*TeamId:(\d+),\s*TeamIdx:(\d+)\](?:\s*-\s*\[TId:\s*(\d+)\s*-\s*(\d+)\])?", m) {
        AddRosterUid(m1)
        g_Match.Teams[UidKey(m1)] := {Team:m2 + 0, Index:m3 + 0}
        if (m4 != "") {
            groupId := m4 + 0
            g_Match.PendingSpawnGroups[UidKey(m1)] := groupId
            BindSpawnGroup(m1, groupId, time)
        }
    }

    if RegExMatch(line, "AllocStartSpot\s+Success:\s*UID:(\d+),\s*TId:(\d+),\s*TIdx:(\d+),\s*TGroupI:(\d+)", m) {
        g_Match.PendingSpawnGroups[UidKey(m1)] := m4 + 0
        ; 某些版本只为本地玩家输出 AdjustLoc；Success 本身也足以把
        ; UID 绑定到出生分组，因此先建立无 PlayerStart/XYZ 的记录。
        BindSpawnGroup(m1, m4, time)
    }

    ; Pre Allocate 行只对本地玩家明确给出 MyStart -> TeamStart，作为
    ; 后到的交叉证据；它也能补齐某些日志中分组行被截断的情况。
    if RegExMatch(line, "Pre Allocate StartSpotSuccess\s+MyStart=([^,\s]+),\s*TeamStart=([^,\s]+)", m) {
        playerStart := Trim(m1)
        teamStart := Trim(m2)
        g_Match.SpawnNameToTeamStart[NameKey(playerStart)] := teamStart
        for key, spawn in g_Match.SpawnPoints {
            if (spawn.Name = playerStart) {
                spawn.TeamStart := teamStart
                spawn.Area := TeamStartArea(teamStart)
                spawn.Alias := TeamStartAlias(teamStart)
                ; Pre Allocate 的 MyStart -> TeamStart 是本地玩家的
                ; 交叉证据；在缺少 isAutonomous=1 的日志版本中补齐 self 标记。
                if (g_Match.SelfUid = "")
                    SetSelfUid(spawn.Uid)
            }
        }
    }

    ; 出生点名称使用日志的规范字段，不根据队伍号猜测。
    ; 典型格式：AllocStartSpot AdjustLoc: UID:..., TId:..., TIdx:...,
    ; Find Name:PlayerStart58, ...（这里只读取 UID 与名称）
    if RegExMatch(line, "AllocStartSpot\s+AdjustLoc:\s*UID:(\d+),\s*TId:(\d+),\s*TIdx:(\d+),\s*Find Name:([^,]+),", m) {
        groupId := g_Match.PendingSpawnGroups.HasKey(UidKey(m1)) ? g_Match.PendingSpawnGroups[UidKey(m1)] : 0
        RecordSpawnPoint(m1, Trim(m4), time, groupId)
    }

    if RegExMatch(line, "TempMa2-Alloc - InputMember:\s*PlayerUin=(\d+),\s*TeamId=(\d+),.*?PlayerIdx=(\d+)", m) {
        AddRosterUid(m1)
        g_Match.Teams[UidKey(m1)] := {Team:m2 + 0, Index:m3 + 0}
    }

    ; 绝密局启用 TeamWeight 后改走 TempMa2，没有 MS23 Member-End；
    ; FINAL MAPPING 是全员 UID -> 出生分组的直接证据。
    if RegExMatch(line, "TempMa2-Alloc - FINAL MAPPING:\s*PlayerUin=(\d+)\s*->\s*TeamStartGroupId=(\d+),\s*SpotIdx=(\d+),\s*TeamId=(\d+)", m) {
        key := UidKey(m1)
        if !g_Match.Teams.HasKey(key)
            g_Match.Teams[key] := {Team:m4 + 0, Index:m3 + 0}
        g_Match.PendingSpawnGroups[key] := m2 + 0
        BindSpawnGroup(m1, m2, time)
    }

    if RegExMatch(line, "Uin\s*=\s*(\d+).*?isAutonomous\s*=\s*1", m)
        SetSelfUid(m1)

    if (InStr(line, "UDFMFSM_ZiplineControlAction Exit") && RegExMatch(line, "BP_DFMCharacter_C_\d+\s+(\d+)\s+Autonomous=([01])", m)) {
        uid := m1
        if (m2 = "1")
            SetSelfUid(uid)
    }

    if RegExMatch(line, "OnEnter ImpendingDeath\s*:\s*(\d+)\s+isAutonomous\s*=\s*([01])", m) {
        uid := m1
        key := UidKey(uid)
        if (m2 = "1")
            SetSelfUid(uid)
        count := g_Match.Knockdowns.HasKey(key) ? g_Match.Knockdowns[key] : 0
        g_Match.Knockdowns[key] := count + 1
        g_Match.Downed[key] := {Uid:uid, Time:time}
        if g_Match.Corpses.HasKey(key)
            AddWarning(PlayerLabel(uid) " 在尸体候选之后再次出现倒地事件。")
    }

    if RegExMatch(line, "UGPCharacterVoiceComponent::OnPlayerDied.*?Character:(\d+)\s+SetTimer\s+StopCharacterGameAk", m)
        RecordCorpse(m1, time, "OnPlayerDied（尸体状态强候选）")

    if RegExMatch(line, "CourseworkEvent\s+Type=(DEATH|BOX)\s+UID:(\d+)", m) {
        kind := m1
        uid := m2
        if (kind = "DEATH") {
            RecordCorpse(uid, time, "作业 DEATH（UID + 状态）")
        } else {
            RecordBox(uid, time, "作业 BOX（UID + 状态）")
        }
    }

    if RegExMatch(line, "CourseworkEvent\s+Type=RESCUE\s+UID:(\d+)", m)
        RecordCorpseRescue(m1, time, "作业 RESCUE（尸体恢复存活）")

    if RegExMatch(line, "ClientNotifySOLRescue\s*-\s*RescueType:\s*2,\s*Rescuer:\s*(\d+),\s*Target:\s*(\d+)", m)
        RecordCorpseRescue(m2, time, "ClientNotifySOLRescue RescueType=2", m1)

    if RegExMatch(line, "UDFMFSM_RebornAction::OnEnter:\s*(.+?)\s*$", m) {
        name := Trim(m1)
        nameKey := NameKey(name)
        if g_Match.NameToUid.HasKey(nameKey) {
            uid := g_Match.NameToUid[nameKey]
            key := UidKey(uid)
            if (g_Match.Corpses.HasKey(key) || (g_Match.Boxes.HasKey(key) && g_Match.Boxes[key].IsInferred))
                RecordCorpseRescue(uid, time, "RebornAction（尸体/超时盒子状态后恢复）")
            else if g_Match.Downed.HasKey(key)
                RecordDownedRescue(uid, time, "RebornAction（倒地后恢复）")
        }
    }

    if RegExMatch(line, "_OnCharacterIsAliveStateChanged,\s*([123]),\s*([123])", m) {
        newState := m1 + 0
        oldState := m2 + 0
        if (newState = 2 && (oldState = 1 || oldState = 3)) {
            g_Match.LocalCorpseTime := time
            if (g_Match.SelfUid != "")
                RecordCorpse(g_Match.SelfUid, time, "本地 AliveState " oldState "->" newState)
            else {
                g_Match.LocalCorpseUnknown := true
                AddTimeline(time, "本地角色进入尸体状态（UID 尚未绑定）")
            }
        } else if (newState = 1 && oldState = 2) {
            if (g_Match.SelfUid != "")
                RecordCorpseRescue(g_Match.SelfUid, time, "本地 AliveState 2->1")
            else if g_Match.LocalCorpseUnknown {
                g_Match.LocalCorpseUnknown := false
                AddTimeline(time, "本地 AliveState 2->1，尸体状态恢复存活（UID 尚未绑定）")
            }
        }
    }

    if RegExMatch(line, "OnRep_ExitState\s+ExitState\s*=\s*3.*?Uin\s*=\s*(\d+).*?PlayerName\s*=\s*([^,\]\r\n]+)", m) {
        name := Trim(m2)
        RememberPlayerName(name, m1)
        nameKey := NameKey(name)
        g_Match.Exit3ByName[nameKey] := {Uid:m1, Time:time}
        g_Match.Exit3ByUid[UidKey(m1)] := {Uid:m1, Time:time}
        TryConfirmEscape(name)
        TryConfirmEscapeUid(m1)
        TryConfirmRocketEscapes(time)
    }

    if RegExMatch(line, "UDFMFSM_SOLEscapedStateAction Enter PlayerName\s*=\s*([^,\]\r\n]+)", m) {
        name := Trim(m1)
        nameKey := NameKey(name)
        g_Match.EscapedActionByName[nameKey] := {Time:time}
        if g_Match.NameToUid.HasKey(nameKey) {
            uid := g_Match.NameToUid[nameKey]
            g_Match.EscapedActionByUid[UidKey(uid)] := {Uid:uid, Time:time}
            TryConfirmEscapeUid(uid)
        }
        TryConfirmEscape(name)
        TryConfirmRocketEscapes(time)
    }

    if RegExMatch(line, "\[(\d+)\]\[1\]\s+AGPCharacterBase::OnRep_GPCharacterHiddenInGame\s+HiddenInGameBitValue=2", m) {
        uid := m1
        if g_Match.Roster.HasKey(UidKey(uid)) {
            g_Match.RocketHiddenCandidates[UidKey(uid)] := {Uid:uid, Time:time}
            TryConfirmRocketEscapes(time)
        }
    }

    if RegExMatch(line, "APlayerExitBase::OnRep_ExitRuntimeInfo\s+Exit=([^,\r\n]+).*?RealPlayerEscapeNum=(\d+)", m) {
        exitPointName := Trim(m1)
        escapedCount := m2 + 0
        if (escapedCount > 0) {
            exitRuntime := {Time:time, Name:exitPointName, Count:escapedCount}
            g_Match.ExitRuntimeEvents.Push(exitRuntime)
            BackfillEscapePoint(exitRuntime)
        }
    }

    if RegExMatch(line, "APlayerExitBase::OnRep_ExitRuntimeInfo\s+Exit=火箭撤离点.*?RealPlayerEscapeNum=(\d+)", m) {
        rocketCount := m1 + 0
        if (rocketCount > 0) {
            g_Match.RocketEscapePending := {Time:time, Count:rocketCount}
            TryConfirmRocketEscapes(time)
        }
    }
    ; 火箭成功人数经常先于最后一个 HiddenInGame UID 到达；让随后任意日志行
    ; 都能在短暂收集窗口结束后触发关联，而不是依赖恰好再来一种特定事件。
    TryConfirmRocketEscapes(time)

    if RegExMatch(line, "\{\s*(BP_Inventory_(?:CarryBody|DeadBody)_C_\d+)\s*\}", m)
        g_Match.DeadBodyActors.Push({Time:time, Actor:m1})

    if InStr(line, "SettlementLogic._OnPlayerMatchOver") {
        if !IsObject(g_Match.PendingEnd) {
            g_Match.PendingEnd := {Time:time, Tick:A_TickCount, Evidence:"_OnPlayerMatchOver"}
            AddTimeline(time, "本地玩家进入结算；继续接收同局尾随事件，60 s 后可兜底封局")
        }
    }

    if InStr(line, "BeginStage GFStageName = EGameFlowStageType::GameSettlement") {
        if !IsObject(g_Match.PendingEnd) {
            g_Match.PendingEnd := {Time:time, Tick:A_TickCount, Evidence:"进入 GameSettlement"}
            AddTimeline(time, "进入 GameSettlement；继续接收结算阶段尾随事件")
        }
    }

    endEvidence := ""
    ; GameSettlement 开始后仍可能出现同局撤离尾随事件，因此只在
    ; GameSettlement 明确结束或进入 SafeHouse 时正式封局。
    if InStr(line, "SettlementLogic._OnGameSettlementEnd")
        endEvidence := "GameSettlement 流程结束"
    else if InStr(line, "BeginStage GFStageName = EGameFlowStageType::SafeHouse")
        endEvidence := "进入 SafeHouse"
    else if InStr(line, "SettlementModule:_OnSettlementEnd")
        endEvidence := "大厅结算步骤结束"
    else if RegExMatch(line, "SettlementModule:OnGameFlowChangeEnter,\s*14(?:\D|$)")
        endEvidence := "结算模块进入 SafeHouse 流程"
    else if InStr(line, "SettlementModule:_StartLobbySettlement settlementInfoSource")
        endEvidence := "大厅结算步骤开始"
    if (endEvidence != "") {
        CompleteMatch(time, endEvidence)
        return
    }
    if isLifecycleSignal
        PromoteCorpseTimeouts(time)
    UpdateLivePanel()
}

BeginMatch(time, initialCount, source := "TempMS23") {
    global g_Match, g_LastReport, g_SelfTest, g_StartSpotCatalog
    if IsObject(g_Match) && g_Match.Active {
        ; 同一分配流程通常同时写 PlayerMembers 与 TempMS23 两个锚点。
        ; 相同人数且相隔很短时视为同局重复锚点，不能重置已收集的 UID。
        forwardAge := TimeDiffMs(g_Match.StartTime, time)
        reverseAge := TimeDiffMs(time, g_Match.StartTime)
        sameAnchorWindow := ((forwardAge >= 0 && forwardAge <= 15000) || (reverseAge >= 0 && reverseAge <= 15000))
        if (sameAnchorWindow && g_Match.InitialCount = initialCount) {
            if (g_Match.StartAnchorSource = "")
                g_Match.StartAnchorSource := source
            else if !InStr(g_Match.StartAnchorSource, source)
                g_Match.StartAnchorSource .= "+" source
            return
        }
    }
    ; 新锚点是跨局边界。若旧局没有结算信号，先封存为不完整报告，
    ; 再创建全新的状态容器，绝不把旧局的 UID/队伍/盒子带入新局。
    if IsObject(g_Match) && g_Match.Active {
        AddWarning("本局未见结算即出现新的开局锚点；上局按不完整报告封存。")
        CompleteMatch(time, "新开局锚点覆盖上一局")
    }
    ResetMatch(false)
    ; 出生点目录写在开局锚点之前。把本次分配周期收集到的目录复制进
    ; 对局状态，避免下一局 InitializeAllocator 刷新全局目录时反向污染本局。
    for groupId, spotInfo in g_StartSpotCatalog
        g_Match.StartSpotGroups[groupId] := {Name:spotInfo.Name "", Area:spotInfo.Area ""}
    g_LastReport := ""
    if !g_SelfTest
        GuiControl, 1:, ReportEdit,
    g_Match.Active := true
    g_Match.StartTime := time
    g_Match.StartAnchorSource := source
    g_Match.InitialCount := initialCount + 0
    AddTimeline(time, "开局锚点 PlayerNum=" g_Match.InitialCount "（" source "）")
    UpdateMatchStatus()
    UpdateLivePanel()
}

CompleteMatch(time, evidence) {
    global g_Match
    if !g_Match.Active
        return false
    g_Match.EndTime := time
    g_Match.EndReason := evidence
    g_Match.PendingEnd := ""
    AddTimeline(time, "本地进入结算（" evidence "）")
    g_Match.Active := false
    FinalizeMatch()
    return true
}

TryFinalizePendingEnd() {
    global g_Match, MATCH_END_GRACE_MS
    if !IsObject(g_Match) || !g_Match.Active || !IsObject(g_Match.PendingEnd)
        return false
    elapsed := A_TickCount - g_Match.PendingEnd.Tick
    if (elapsed < 0)
        elapsed += 4294967296
    if (elapsed < MATCH_END_GRACE_MS)
        return false
    pendingEvidence := g_Match.PendingEnd.HasKey("Evidence") ? g_Match.PendingEnd.Evidence : "结算信号"
    return CompleteMatch(g_Match.PendingEnd.Time, pendingEvidence " 后 60 s 未见更晚结束锚点，兜底封局")
}

AddRosterUid(uid) {
    global g_Match
    key := UidKey(uid)
    if !g_Match.Roster.HasKey(key) {
        g_Match.Roster[key] := true
        g_Match.RosterOrder.Push(uid)
    }
}

CaptureStartSpotMetadata(line) {
    global g_StartSpotCatalog, g_Match
    ; Group Id 只在一次出生点分配/一张地图的目录中有意义。近期巴克什
    ; 日志会复用航天基地使用过的 101/102/20x，因此每次初始化必须清空，
    ; 不能把旧地图的 Id -> 名称关系带到下一局。
    if InStr(line, "InitializeAllocator SpecifiedTemplateId=") {
        g_StartSpotCatalog := {}
        return
    }
    if RegExMatch(line, "Find StartSpotGroup:\s*\[Id:(\d+),\s*name:([^\]]+)\]", m) {
        groupId := m1 + 0
        name := Trim(m2)
        area := TeamStartArea(name)
        if !g_StartSpotCatalog.HasKey(groupId)
            g_StartSpotCatalog[groupId] := {Name:name, Area:area}
        else {
            g_StartSpotCatalog[groupId].Name := name
            g_StartSpotCatalog[groupId].Area := area
        }
        if IsObject(g_Match) && g_Match.Active {
            if !g_Match.StartSpotGroups.HasKey(groupId)
                g_Match.StartSpotGroups[groupId] := {Name:name, Area:area}
            else {
                g_Match.StartSpotGroups[groupId].Name := name
                g_Match.StartSpotGroups[groupId].Area := area
            }
        }
    }

    if RegExMatch(line, "TeamStartId\[O:\s*(\d+)\]\s*\[TId:\s*(\d+)\]", m) {
        groupId := m2 + 0
        area := StartSpotArea(m1)
        knownName := KnownTeamStartForGroup(groupId)
        fallbackName := knownName != "" ? knownName : "TeamStart" groupId
        if !g_StartSpotCatalog.HasKey(groupId)
            g_StartSpotCatalog[groupId] := {Name:fallbackName, Area:area}
        else if (g_StartSpotCatalog[groupId].Area = "")
            g_StartSpotCatalog[groupId].Area := area
        if IsObject(g_Match) && g_Match.Active {
            if !g_Match.StartSpotGroups.HasKey(groupId)
                g_Match.StartSpotGroups[groupId] := {Name:fallbackName, Area:area}
            else if (g_Match.StartSpotGroups[groupId].Area = "")
                g_Match.StartSpotGroups[groupId].Area := area
        }
    }
}

StartSpotInfo(groupId) {
    global g_Match, g_StartSpotCatalog
    groupId := groupId + 0
    if (!groupId)
        return ""
    if IsObject(g_Match) && g_Match.StartSpotGroups.HasKey(groupId)
        return g_Match.StartSpotGroups[groupId]
    if g_StartSpotCatalog.HasKey(groupId)
        return g_StartSpotCatalog[groupId]
    ; 工具可能在 Begin 之后启动，回扫会看不到紧邻 Begin 之前的
    ; Find StartSpotGroup。此时 Member-End 尾部仍有稳定的分组 ID，
    ; 用本地多局日志直接确认的映射恢复规范 TeamStart 名。
    knownName := KnownTeamStartForGroup(groupId)
    if (knownName != "")
        return {Name:knownName, Area:TeamStartArea(knownName)}
    return ""
}

KnownTeamStartForGroup(groupId) {
    groupId := groupId + 0
    ; 航天基地日志的 StartSpotGroup Id -> 规范 TeamStart 名。
    static names := {101:"TeamStart6", 102:"TeamStart7", 103:"TeamStart8"
        , 201:"TeamStart4", 202:"TeamStart3", 203:"TeamStart2"
        , 204:"TeamStart1", 205:"TeamStart5", 301:"TeamStart9"}
    return names.HasKey(groupId) ? names[groupId] : ""
}

BindSpawnGroup(uid, groupId, time := "") {
    global g_Match
    uid := Trim(uid "")
    groupId := groupId + 0
    if (uid = "" || !groupId)
        return false
    AddRosterUid(uid)
    key := UidKey(uid)
    teamStart := ""
    area := ""
    spotInfo := StartSpotInfo(groupId)
    if IsObject(spotInfo) {
        teamStart := Trim(spotInfo.Name "")
        area := Trim(spotInfo.Area "")
    }
    if (area = "" && teamStart != "")
        area := TeamStartArea(teamStart)
    alias := TeamStartAlias(teamStart)
    if !g_Match.SpawnPoints.HasKey(key) {
        g_Match.SpawnPoints[key] := {Uid:uid, Name:"", TeamStart:teamStart, Area:area, Alias:alias, GroupId:groupId, Time:time
            , X:"", Y:"", Z:""}
    } else {
        spawn := g_Match.SpawnPoints[key]
        if (spawn.TeamStart = "" && teamStart != "")
            spawn.TeamStart := teamStart
        if (spawn.Area = "" && area != "")
            spawn.Area := area
        if (spawn.Alias = "" && alias != "")
            spawn.Alias := alias
        if (!spawn.GroupId)
            spawn.GroupId := groupId
        if (spawn.Time = "" && time != "")
            spawn.Time := time
    }
    return true
}

RecordSpawnPoint(uid, name, time, groupId := 0) {
    global g_Match
    uid := Trim(uid "")
    name := Trim(name "")
    if (uid = "" || name = "")
        return false
    AddRosterUid(uid)
    key := UidKey(uid)
    if (groupId)
        BindSpawnGroup(uid, groupId, time)
    teamStart := ""
    area := ""
    spotInfo := StartSpotInfo(groupId)
    if IsObject(spotInfo) {
        teamStart := Trim(spotInfo.Name "")
        area := Trim(spotInfo.Area "")
    }
    if (teamStart = "" && g_Match.SpawnNameToTeamStart.HasKey(NameKey(name)))
        teamStart := g_Match.SpawnNameToTeamStart[NameKey(name)]
    if (area = "" && teamStart != "")
        area := TeamStartArea(teamStart)
    alias := TeamStartAlias(teamStart)
    if !g_Match.SpawnPoints.HasKey(key) {
        g_Match.SpawnPoints[key] := {Uid:uid, Name:name, TeamStart:teamStart, Area:area, Alias:alias, GroupId:(groupId + 0), Time:time}
    } else {
        spawn := g_Match.SpawnPoints[key]
        if (spawn.Name = "")
            spawn.Name := name
        if (spawn.TeamStart = "" && teamStart != "")
            spawn.TeamStart := teamStart
        if (spawn.Area = "" && area != "")
            spawn.Area := area
        if (spawn.Alias = "" && alias != "")
            spawn.Alias := alias
        if (!spawn.GroupId && groupId)
            spawn.GroupId := groupId + 0
        if (spawn.Time = "" && time != "")
            spawn.Time := time
    }
    return true
}

UidKey(uid) {
    return "uid:" uid
}

NameKey(name) {
    return "name:" Trim(name)
}

RememberPlayerName(name, uid) {
    global g_Match
    name := Trim(name "")
    uid := Trim(uid "")
    ; UID=0 和组件类名是日志占位符，不属于玩家身份。
    if (name = "" || uid = "" || uid = "0" || SubStr(name, 1, 3) = "BP_")
        return
    g_Match.NameToUid[NameKey(name)] := uid
    g_Match.UidToName[UidKey(uid)] := name
    ; 用户确认的人工覆盖：Reze2nsj 本局只暴露皮肤 AvatarId，
    ; 已确认该皮肤对应红狼。仅在没有更强的直接 HeroId 证据时应用，
    ; 后续若日志给出 880... 直接 ID，RememberUidHero 可正常覆盖该推定。
    if (!g_Match.HeroByUid.HasKey(UidKey(uid)))
        ApplyManualHeroOverride(uid, name)
}

RememberActorUid(actorId, uid) {
    global g_Match
    actorId := Trim(actorId "")
    uid := Trim(uid "")
    if (actorId = "" || uid = "" || uid = "0")
        return false
    actorKey := "actor:" actorId
    g_Match.ActorToUid[actorKey] := uid
    if g_Match.ActorToHero.HasKey(actorKey)
        g_Match.HeroByUid[UidKey(uid)] := g_Match.ActorToHero[actorKey]
    return true
}

RememberActorHero(actorId, heroId) {
    global g_Match
    actorId := Trim(actorId "")
    heroId := Trim(heroId "")
    if (actorId = "" || heroId = "")
        return false
    actorKey := "actor:" actorId
    g_Match.ActorToHero[actorKey] := heroId
    if g_Match.ActorToUid.HasKey(actorKey)
        g_Match.HeroByUid[UidKey(g_Match.ActorToUid[actorKey])] := heroId
    return true
}

RememberUidHero(uid, heroId) {
    global g_Match
    uid := Trim(uid "")
    heroId := Trim(heroId "")
    if (uid = "" || uid = "0" || heroId = "" || !RegExMatch(heroId, "^880\d+$"))
        return false
    g_Match.HeroByUid[UidKey(uid)] := heroId
    return true
}

ApplyManualHeroOverride(uid, playerName) {
    global g_Match
    uid := Trim(uid "")
    playerName := Trim(playerName "")
    if (uid = "" || uid = "0" || playerName = "")
        return false
    static overrides := {"name:Reze2nsj":"30000060001"
        , "name:Flacidusax":"30000060007"
        , "name:苏沉鋭":"30000060001"}
    key := NameKey(playerName)
    if !overrides.HasKey(key)
        return false
    if !g_Match.HeroByUid.HasKey(UidKey(uid))
        g_Match.HeroByUid[UidKey(uid)] := overrides[key]
    return true
}

UpdateCorpseRescueWindow(uid, time, remainingSeconds, canRescue) {
    global g_Match
    key := UidKey(uid)
    if !g_Match.Corpses.HasKey(key)
        return false

    event := g_Match.Corpses[key]
    if (!canRescue && remainingSeconds <= 0.05)
        return RecordBox(uid, time, "IsCanBeRescue 明确显示救援窗口已结束")

    if (canRescue && remainingSeconds > 0) {
        elapsed := TimeDiffMs(event.Time, time)
        if (elapsed >= 0) {
            observedTimeout := elapsed + Round(remainingSeconds * 1000)
            if (observedTimeout > event.TimeoutMs)
                event.TimeoutMs := observedTimeout
        }
        if !event.HasKey("WindowEvidence") {
            event.WindowEvidence := true
            AddTimeline(time, PlayerLabel(uid) " 仍可救援，日志剩余窗口 " Format("{:.3f}", remainingSeconds) " s")
        }
        return true
    }
    return false
}

SetSelfUid(uid) {
    global g_Match
    if (g_Match.SelfUid = "")
        g_Match.SelfUid := uid
    if (g_Match.LocalCorpseUnknown && g_Match.LocalCorpseTime != "") {
        g_Match.LocalCorpseUnknown := false
        RecordCorpse(uid, g_Match.LocalCorpseTime, "本地 AliveState（延迟绑定 UID）")
    }
}

RecordCorpse(uid, time, evidence) {
    global g_Match, CORPSE_TO_BOX_MS
    key := UidKey(uid)
    if !g_Match.Roster.HasKey(key) {
        AddWarning("尸体候选 UID 不在已建立的本局名单中，未纳入人数计算。")
        return
    }
    if g_Match.Corpses.HasKey(key)
        return
    if g_Match.Boxes.HasKey(key)
        return
    if g_Match.Downed.HasKey(key)
        g_Match.Downed.Delete(key)
    event := {Uid:uid, Time:time, Evidence:evidence, ObservedTick:A_TickCount, TimeoutMs:CORPSE_TO_BOX_MS}
    g_Match.Corpses[key] := event
    g_Match.CorpseOrder.Push(uid)
    AddTimeline(time, PlayerLabel(uid) " " evidence)
}

RecordBox(uid, time, evidence, inferred := false) {
    global g_Match
    key := UidKey(uid)
    if !g_Match.Roster.HasKey(key) {
        AddWarning("盒子 UID 不在已建立的本局名单中，未纳入人数计算。")
        return false
    }
    if g_Match.Boxes.HasKey(key)
        return false

    if g_Match.Corpses.HasKey(key) {
        g_Match.Corpses.Delete(key)
        RemoveUidFromOrder(g_Match.CorpseOrder, uid)
    }
    box := {Uid:uid, Time:time, Evidence:evidence, IsInferred:inferred}
    g_Match.Boxes[key] := box
    g_Match.BoxOrder.Push(uid)
    if inferred
        AddTimeline(time, PlayerLabel(uid) " 未见更强盒子/救援信号，按救援窗口超时推定进入盒子状态")
    else
        AddTimeline(time, PlayerLabel(uid) " 进入盒子状态（" evidence "）")
    return true
}

PromoteCorpseTimeouts(nowTime := "") {
    global g_Match, CORPSE_TO_BOX_MS
    if !IsObject(g_Match) || !g_Match.Active || ObjectCount(g_Match.Corpses) = 0
        return false

    expired := []
    for key, event in g_Match.Corpses {
        logAge := IsObject(nowTime) ? TimeDiffMs(event.Time, nowTime) : -1
        wallAge := A_TickCount - event.ObservedTick
        if (wallAge < 0)
            wallAge += 4294967296
        timeoutMs := event.HasKey("TimeoutMs") ? event.TimeoutMs : CORPSE_TO_BOX_MS
        if (logAge >= timeoutMs || wallAge >= timeoutMs)
            expired.Push(event.Uid)
    }

    changed := false
    for _, uid in expired {
        key := UidKey(uid)
        if !g_Match.Corpses.HasKey(key)
            continue
        event := g_Match.Corpses[key]
        boxTime := IsObject(nowTime) ? nowTime : event.Time
        if RecordBox(uid, boxTime, "未见明确生命周期信号，按救援窗口超时兜底推定", true)
            changed := true
    }
    return changed
}

RecordCorpseRescue(uid, time, evidence, rescuerUid := "") {
    global g_Match
    key := UidKey(uid)
    if !g_Match.Roster.HasKey(key) {
        AddWarning("尸体救援 Target UID 不在已建立的本局名单中，未改变人数。")
        return false
    }
    inferredBoxCorrected := false
    if g_Match.Boxes.HasKey(key) {
        box := g_Match.Boxes[key]
        if box.IsInferred {
            g_Match.Boxes.Delete(key)
            RemoveUidFromOrder(g_Match.BoxOrder, uid)
            inferredBoxCorrected := true
            AddTimeline(time, PlayerLabel(uid) " 明确救援信号纠正了先前的超时盒子推定")
        } else {
            AddWarning(PlayerLabel(uid) " 已有明确盒子事件后又出现尸体救援；本次未改变人数。")
            return false
        }
    }
    if (!g_Match.Corpses.HasKey(key) && !inferredBoxCorrected) {
        AddWarning(PlayerLabel(uid) " 出现尸体救援信号，但此前没有尸体候选；本次未改变人数。")
        return false
    }

    if g_Match.Corpses.HasKey(key) {
        g_Match.Corpses.Delete(key)
        RemoveUidFromOrder(g_Match.CorpseOrder, uid)
    }
    event := {Uid:uid, Time:time, Evidence:evidence, RescuerUid:rescuerUid}
    g_Match.Rescued[key] := event
    g_Match.RescueEvents.Push(event)
    if g_Match.Downed.HasKey(key)
        g_Match.Downed.Delete(key)
    AddTimeline(time, PlayerLabel(uid) " 尸体状态被救援，恢复存活（" evidence "）")
    return true
}

RecordDownedRescue(uid, time, evidence) {
    global g_Match
    key := UidKey(uid)
    if !g_Match.Downed.HasKey(key)
        return false
    g_Match.Downed.Delete(key)
    event := {Uid:uid, Time:time, Evidence:evidence}
    g_Match.DownedRescueEvents.Push(event)
    AddTimeline(time, PlayerLabel(uid) " 倒地后被救起，仍计为存活（人数不重复增加；" evidence "）")
    return true
}

RemoveUidFromOrder(order, uid) {
    key := UidKey(uid)
    for index, item in order {
        if (UidKey(item) = key) {
            order.RemoveAt(index)
            return true
        }
    }
    return false
}

RecordEscape(uid, time, evidence := "ExitState=3 + EscapedStateAction", method := "普通撤离", exitPoint := "") {
    global g_Match
    key := UidKey(uid)
    if !g_Match.Roster.HasKey(key) {
        AddWarning("成功撤离 UID 不在本局名单中，未纳入人数计算。")
        return
    }
    if g_Match.Escaped.HasKey(key)
        return
    if g_Match.Corpses.HasKey(key)
        RecordCorpseRescue(uid, time, "成功撤离反证此前尸体状态已恢复")
    else if g_Match.Boxes.HasKey(key) {
        box := g_Match.Boxes[key]
        if box.IsInferred
            RecordCorpseRescue(uid, time, "成功撤离纠正先前的超时盒子推定")
        else {
            AddWarning(PlayerLabel(uid) " 同时出现明确盒子事件和成功撤离；未把该玩家重复计入撤离。")
            return
        }
    }
    if (exitPoint = "") {
        pointEvent := FindEscapePointAt(time)
        if IsObject(pointEvent)
            exitPoint := pointEvent.Name
        else if (method = "火箭/飞升撤离")
            exitPoint := "火箭撤离点"
        else
            exitPoint := "撤离点未知"
    }
    g_Match.Escaped[key] := {Uid:uid, Time:time, Evidence:evidence, Method:method, ExitPoint:exitPoint}
    g_Match.EscapeOrder.Push(uid)
    AddTimeline(time, PlayerLabel(uid) " 成功撤离（撤离点=" exitPoint "；" evidence "）")
}

TryConfirmEscape(name) {
    global g_Match
    nameKey := NameKey(name)
    if (!g_Match.Exit3ByName.HasKey(nameKey) || !g_Match.EscapedActionByName.HasKey(nameKey))
        return false
    exitEvent := g_Match.Exit3ByName[nameKey]
    actionEvent := g_Match.EscapedActionByName[nameKey]
    forwardAge := TimeDiffMs(exitEvent.Time, actionEvent.Time)
    reverseAge := TimeDiffMs(actionEvent.Time, exitEvent.Time)
    if !((forwardAge >= 0 && forwardAge <= 2000) || (reverseAge >= 0 && reverseAge <= 2000))
        return false
    eventTime := forwardAge >= 0 ? actionEvent.Time : exitEvent.Time
    method := EscapeMethodAt(eventTime)
    evidence := method = "火箭/飞升撤离" ? "火箭/飞升撤离；ExitState=3 + EscapedStateAction" : "ExitState=3 + EscapedStateAction"
    RecordEscape(exitEvent.Uid, eventTime, evidence, method)
    return true
}

TryConfirmEscapeUid(uid) {
    global g_Match
    key := UidKey(uid)
    if (!g_Match.Exit3ByUid.HasKey(key) || !g_Match.EscapedActionByUid.HasKey(key))
        return false
    exitEvent := g_Match.Exit3ByUid[key]
    actionEvent := g_Match.EscapedActionByUid[key]
    forwardAge := TimeDiffMs(exitEvent.Time, actionEvent.Time)
    reverseAge := TimeDiffMs(actionEvent.Time, exitEvent.Time)
    if !((forwardAge >= 0 && forwardAge <= 2000) || (reverseAge >= 0 && reverseAge <= 2000))
        return false
    eventTime := forwardAge >= 0 ? actionEvent.Time : exitEvent.Time
    method := EscapeMethodAt(eventTime)
    evidence := method = "火箭/飞升撤离" ? "火箭/飞升撤离；ExitState=3 + EscapedStateAction" : "ExitState=3 + EscapedStateAction"
    RecordEscape(uid, eventTime, evidence, method)
    return true
}

EscapeMethodAt(time) {
    global g_Match
    pointEvent := FindEscapePointAt(time)
    if (IsObject(pointEvent) && InStr(pointEvent.Name, "火箭撤离点"))
        return "火箭/飞升撤离"
    if !IsObject(g_Match.RocketEscapePending)
        return "普通撤离"
    forwardAge := TimeDiffMs(g_Match.RocketEscapePending.Time, time)
    reverseAge := TimeDiffMs(time, g_Match.RocketEscapePending.Time)
    if ((forwardAge >= 0 && forwardAge <= 2000) || (reverseAge >= 0 && reverseAge <= 2000))
        return "火箭/飞升撤离"
    return "普通撤离"
}

FindEscapePointAt(time) {
    global g_Match
    best := ""
    bestAge := 2147483647
    for _, event in g_Match.ExitRuntimeEvents {
        forwardAge := TimeDiffMs(event.Time, time)
        reverseAge := TimeDiffMs(time, event.Time)
        if (forwardAge >= 0 && forwardAge <= 2000)
            age := forwardAge
        else if (reverseAge >= 0 && reverseAge <= 2000)
            age := reverseAge
        else
            continue
        if (age < bestAge) {
            bestAge := age
            best := event
        }
    }
    return best
}

BackfillEscapePoint(exitRuntime) {
    global g_Match
    candidates := []
    for key, escaped in g_Match.Escaped {
        if (escaped.ExitPoint != "撤离点未知")
            continue
        forwardAge := TimeDiffMs(exitRuntime.Time, escaped.Time)
        reverseAge := TimeDiffMs(escaped.Time, exitRuntime.Time)
        if ((forwardAge >= 0 && forwardAge <= 2000) || (reverseAge >= 0 && reverseAge <= 2000))
            candidates.Push(key)
    }
    if (candidates.Length() != exitRuntime.Count)
        return false
    for _, key in candidates {
        escaped := g_Match.Escaped[key]
        escaped.ExitPoint := exitRuntime.Name
        if InStr(exitRuntime.Name, "火箭撤离点")
            escaped.Method := "火箭/飞升撤离"
    }
    return true
}

TryConfirmRocketEscapes(nowTime) {
    global g_Match
    if !IsObject(g_Match.RocketEscapePending)
        return false
    pending := g_Match.RocketEscapePending
    pendingAge := TimeDiffMs(pending.Time, nowTime)
    if (pendingAge > 2000) {
        g_Match.RocketEscapePending := ""
        return false
    }
    if (pendingAge < 300)
        return false

    candidates := []
    for key, event in g_Match.RocketHiddenCandidates {
        forwardAge := TimeDiffMs(pending.Time, event.Time)
        reverseAge := TimeDiffMs(event.Time, pending.Time)
        if (forwardAge >= 0 && forwardAge <= 2000)
            age := forwardAge
        else if (reverseAge >= 0 && reverseAge <= 2000)
            age := reverseAge
        else
            continue

        ; 同一时窗可能夹杂其他隐藏事件。按与成功人数日志的时间距离排序，
        ; 只绑定 RealPlayerEscapeNum 指定的最近 UID，避免候选略多时整批漏记。
        candidate := {Uid:event.Uid, Age:age}
        insertAt := candidates.Length() + 1
        for index, existing in candidates {
            if (age < existing.Age) {
                insertAt := index
                break
            }
        }
        candidates.InsertAt(insertAt, candidate)
    }
    if (candidates.Length() < pending.Count)
        return false

    Loop, % pending.Count {
        uid := candidates[A_Index].Uid
        RecordEscape(uid, nowTime, "火箭撤离点 RealPlayerEscapeNum=" pending.Count " + 同时段 HiddenInGame UID", "火箭/飞升撤离", "火箭撤离点")
    }
    g_Match.RocketEscapePending := ""
    return true
}

FinalizeMatch() {
    global g_Match, g_LastReport, g_SelfTest, g_Recovering
    if !IsObject(g_Match)
        return false
    ; 结算日志可能重复出现；报告只生成一次，避免重复刷新和跨局重入。
    if g_Match.Finalized
        return true
    g_Match.Finalized := true
    g_LastReport := BuildReport()
    if !g_SelfTest && !g_Recovering {
        GuiControl, 1:, ReportEdit, %g_LastReport%
        UpdateMatchStatus()
        UpdateOverlay()
    }
    return true
}

UpdateLivePanel() {
    global g_Match, g_SelfTest, g_Recovering
    static lastRefresh := 0
    if g_SelfTest || g_Recovering || !IsObject(g_Match) || !g_Match.Active
        return
    if (A_TickCount >= lastRefresh && A_TickCount - lastRefresh < 250)
        return
    lastRefresh := A_TickCount
    GuiControl, 1:, ReportEdit, % BuildLiveReport()
    UpdateMatchStatus()
    UpdateOverlay()
}

BuildLiveReport() {
    global g_Match
    rosterCount := g_Match.RosterOrder.Length()
    corpseCount := ObjectCount(g_Match.Corpses)
    rescueCount := g_Match.RescueEvents.Length()
    downedRescueCount := g_Match.DownedRescueEvents.Length()
    escapeCount := ObjectCount(g_Match.Escaped)
    candidate := g_Match.InitialCount - corpseCount - ObjectCount(g_Match.Boxes) - escapeCount - (g_Match.LocalCorpseUnknown ? 1 : 0)
    if (candidate < 0)
        candidate := 0
    report := "对局状态：进行中`r`n"
    report .= "开局：" TimeLabel(g_Match.StartTime) "`r`n"
    report .= "初始 PlayerNum：" g_Match.InitialCount "`r`n"
    report .= "名单完整度：" rosterCount "/" g_Match.InitialCount "`r`n"
    report .= "玩家名绑定：" BoundRosterCount(g_Match.UidToName) "/" rosterCount " | 干员ID绑定：" BoundRosterCount(g_Match.HeroByUid) "/" rosterCount "`r`n"
    report .= "出生点映射：" ObjectCount(g_Match.SpawnPoints) "/" rosterCount "（仅统计带 UID 的日志字段）`r`n"
    report .= "候选场内剩余：" candidate "`r`n"
    report .= "当前尸体/死亡候选：" corpseCount " | 尸体救援：" rescueCount " | 倒地救起：" downedRescueCount " | 确认撤离：" escapeCount " | 盒子事件：" ObjectCount(g_Match.Boxes) "`r`n"
    if (rosterCount != g_Match.InitialCount)
        report .= "精度：状态不完整（名单尚未收齐）`r`n"
    else
        report .= "精度：候选值（无服务器权威字段）`r`n"

    aliveUids := SortedRosterBySpawn(true)
    aliveCount := aliveUids.Length()
    report .= "`r`n存活列表（" aliveCount "）`r`n"
    report .= WindowPlayerHeader()
    if (aliveCount = 0)
        report .= "暂无`r`n"
    for _, uid in aliveUids
        report .= WindowPlayerRow(uid) "`r`n"

    report .= "`r`n死亡列表（" corpseCount "）`r`n"
    report .= WindowPlayerHeader()
    if (g_Match.CorpseOrder.Length() = 0)
        report .= "暂无`r`n"
    for _, uid in g_Match.CorpseOrder {
        key := UidKey(uid)
        event := g_Match.Corpses[key]
        report .= WindowPlayerRow(uid) " @ " TimeLabel(event.Time) "`r`n"
    }
    report .= "`r`n尸体救援：" rescueCount "`r`n"
    report .= "倒地救起：" downedRescueCount "`r`n"
    report .= "救援列表（" (rescueCount + downedRescueCount) "）`r`n"
    report .= WindowPlayerHeader()
    if (rescueCount = 0 && downedRescueCount = 0)
        report .= "暂无`r`n"
    for _, event in g_Match.RescueEvents
        report .= WindowPlayerRow(event.Uid) " @ " TimeLabel(event.Time) "  尸体状态恢复存活（" event.Evidence "）`r`n"
    for _, event in g_Match.DownedRescueEvents
        report .= WindowPlayerRow(event.Uid) " @ " TimeLabel(event.Time) "  倒地后恢复，人数不重复增加（" event.Evidence "）`r`n"
    report .= "`r`n盒子列表（" ObjectCount(g_Match.Boxes) "）`r`n"
    report .= WindowPlayerHeader()
    if (g_Match.BoxOrder.Length() = 0)
        report .= "暂无盒子状态`r`n"
    for _, uid in g_Match.BoxOrder {
        box := g_Match.Boxes[UidKey(uid)]
        report .= WindowPlayerRow(uid) " @ " TimeLabel(box.Time) " | " box.Evidence "`r`n"
    }
    report .= "`r`n撤离玩家列表（" escapeCount "）`r`n"
    report .= WindowPlayerHeader()
    if (g_Match.EscapeOrder.Length() = 0)
        report .= "暂无`r`n"
    for _, uid in g_Match.EscapeOrder {
        event := g_Match.Escaped[UidKey(uid)]
        report .= WindowPlayerRow(uid) " @ " TimeLabel(event.Time) " | 撤离点：" event.ExitPoint " | 方式：" event.Method "`r`n"
    }
    return report
}

BuildReport() {
    global g_Match
    rosterCount := g_Match.RosterOrder.Length()
    corpseCount := ObjectCount(g_Match.Corpses)
    rescueCount := g_Match.RescueEvents.Length()
    downedRescueCount := g_Match.DownedRescueEvents.Length()
    escapeCount := ObjectCount(g_Match.Escaped)
    unknownLocal := g_Match.LocalCorpseUnknown ? 1 : 0
    candidate := g_Match.InitialCount - corpseCount - ObjectCount(g_Match.Boxes) - escapeCount - unknownLocal
    if (candidate < 0)
        candidate := 0

    complete := true
    if (rosterCount != g_Match.InitialCount) {
        complete := false
        AddWarning("初始名单不完整：PlayerNum=" g_Match.InitialCount "，唯一 UID=" rosterCount "。")
    }
    for key, event in g_Match.Corpses {
        if g_Match.Escaped.HasKey(key)
            complete := false
    }
    if (g_Match.LocalCorpseUnknown)
        complete := false
    if (g_Match.Warnings.Length() > 0)
        complete := false

    report := "DeltaForce.log 已完成对局赛后审计`r`n"
    report .= "============================================================`r`n"
    report .= "开局：" TimeLabel(g_Match.StartTime) "`r`n"
    report .= "本地结算：" TimeLabel(g_Match.EndTime) "`r`n"
    report .= "初始 PlayerNum：" g_Match.InitialCount "`r`n"
    report .= "已建立名单 UID：" rosterCount "`r`n"
    report .= "玩家名绑定：" BoundRosterCount(g_Match.UidToName) "/" rosterCount " | 干员ID绑定：" BoundRosterCount(g_Match.HeroByUid) "/" rosterCount "`r`n"
    report .= "出生点映射：" ObjectCount(g_Match.SpawnPoints) "/" rosterCount "（仅统计带 UID 的日志字段）`r`n"
    report .= "当前尸体 / 死亡候选：" (corpseCount + unknownLocal) "`r`n"
    report .= "已识别尸体救援：" rescueCount "`r`n"
    report .= "已识别倒地救起：" downedRescueCount "`r`n"
    report .= "当前盒子状态：" ObjectCount(g_Match.Boxes) "`r`n"
    report .= "确认成功撤离：" escapeCount "`r`n"
    if complete
        report .= "候选场内剩余（仅赛后）：" candidate "`r`n"
    else
        report .= "候选场内剩余（仅赛后）：" candidate "，状态不完整 / 不应视为权威值`r`n"
    report .= "口径：倒地不减人；当前尸体和盒子均不计入场内剩余；同一 UID 可经历多次死亡/救援周期，每次仅在尸体状态确实恢复时重新计入；盒子优先采用日志信号，缺失时才按救援窗口超时推定。`r`n`r`n"

    aliveUids := SortedRosterBySpawn(true)
    aliveCount := aliveUids.Length()
    report .= "存活列表（" aliveCount "）`r`n"
    report .= WindowPlayerHeader()
    if (aliveCount = 0)
        report .= "暂无存活且未撤离的名单玩家。`r`n"
    for _, uid in aliveUids
        report .= WindowPlayerRow(uid) "`r`n"

    report .= "`r`n死亡列表（" (corpseCount + unknownLocal) "）`r`n"
    report .= WindowPlayerHeader()
    if (g_Match.CorpseOrder.Length() = 0 && !g_Match.LocalCorpseUnknown) {
        report .= "未观察到带 UID 的尸体候选。`r`n"
    } else {
        for _, uid in g_Match.CorpseOrder {
            key := UidKey(uid)
            event := g_Match.Corpses[key]
            report .= WindowPlayerRow(uid) " @ " TimeLabel(event.Time) "`r`n"
            report .= "  证据：" event.Evidence "`r`n"
        }
        if g_Match.LocalCorpseUnknown {
            report .= "self-unknown @ " TimeLabel(g_Match.LocalCorpseTime) "`r`n"
            report .= "  证据：本地 AliveState 进入 2，但 UID 未绑定`r`n"
        }
    }

    report .= "`r`n尸体救援：" rescueCount "`r`n"
    report .= "倒地救起：" downedRescueCount "`r`n"
    report .= "救援列表（" (rescueCount + downedRescueCount) "）`r`n"
    report .= WindowPlayerHeader()
    if (rescueCount = 0 && downedRescueCount = 0) {
        report .= "未观察到可绑定 UID 的尸体救援。`r`n"
    } else {
        for _, event in g_Match.RescueEvents {
            report .= WindowPlayerRow(event.Uid) " @ " TimeLabel(event.Time) "  尸体状态恢复存活`r`n"
            report .= "  证据：" event.Evidence "`r`n"
        }
        for _, event in g_Match.DownedRescueEvents {
            report .= WindowPlayerRow(event.Uid) " @ " TimeLabel(event.Time) "  倒地后恢复（人数不重复增加）`r`n"
            report .= "  证据：" event.Evidence "`r`n"
        }
    }

    report .= "`r`n盒子列表（" ObjectCount(g_Match.Boxes) "）`r`n"
    report .= WindowPlayerHeader()
    if (g_Match.BoxOrder.Length() = 0) {
        report .= "未观察或推定到盒子状态。`r`n"
    } else {
        for _, uid in g_Match.BoxOrder {
            box := g_Match.Boxes[UidKey(uid)]
            report .= WindowPlayerRow(uid) " @ " TimeLabel(box.Time) "`r`n"
            report .= "  证据：" box.Evidence (box.IsInferred ? "（超时推定）" : "（明确日志信号）") "`r`n"
        }
    }

    report .= "`r`n撤离玩家列表（" escapeCount "）`r`n"
    report .= WindowPlayerHeader()
    if (g_Match.EscapeOrder.Length() = 0) {
        report .= "未观察到确认撤离玩家。`r`n"
    } else {
        for _, uid in g_Match.EscapeOrder {
            event := g_Match.Escaped[UidKey(uid)]
            report .= WindowPlayerRow(uid) " @ " TimeLabel(event.Time) " | 撤离点：" event.ExitPoint " | 方式：" event.Method "`r`n"
            report .= "  证据：" event.Evidence "`r`n"
        }
    }

    report .= "`r`n尸体 / 携带尸体 Actor 日志条目：" g_Match.DeadBodyActors.Length()
    report .= "（只计数，不与玩家强行绑定）`r`n`r`n"

    report .= "事件时间线`r`n"
    report .= "------------------------------------------------------------`r`n"
    for _, event in g_Match.Timeline
        report .= TimeLabel(event.Time) "  " event.Text "`r`n"

    report .= "`r`n证据限制`r`n"
    report .= "------------------------------------------------------------`r`n"
    report .= "- 本结果是本地结算时的日志重建，不是服务器权威存活人数。`r`n"
    report .= "- OnPlayerDied 在目标样本中是尸体状态强候选，不等于已证明成盒。`r`n"
    report .= "- 尸体救援采用 Target UID 的 RescueType=2、本地 AliveState 2->1，或尸体状态后的 RebornAction 名称到 UID 映射。`r`n"
    report .= "- 普通撤离要求 ExitState=3 + EscapedStateAction；火箭/飞升撤离还可由火箭撤离点成功人数与同时段 HiddenInGame UID 联合确认。`r`n"
    report .= "- 撤离点名称优先绑定同一 2 s 窗口内 RealPlayerEscapeNum>0 的 ExitRuntimeInfo；只有地图图标、进入区域或 RealPlayerEscapeNum=0 时不会强行归属给玩家。`r`n"
    report .= "- IsCanBeRescue 的 DeathWaitRescueTime/bDeathCanRescue 优先决定救援窗口；没有该信号时才使用 120 s 兜底。`r`n"
    report .= "- DeadBody/CarryBody Actor 没有可靠 UID 绑定，不能单独用来判定具体玩家成盒。`r`n"
    report .= "- 同一 UID 可经历多次尸体/救援周期；只有当前处于尸体或超时推定盒子状态时，救援才会重新增加候选存活人数。`r`n"
    report .= "- ImpendingDeath 后的 RebornAction 记为倒地救起；因为倒地本身不减人，所以该事件不会重复增加人数。`r`n"
    report .= "- 出生点原始名称只采用带 UID 的 AllocStartSpot AdjustLoc/Find Name；显示时可附加用户确认的 TeamStart 别名，日志未绑定 UID 时仍显示‘未记录’，不从队伍号猜测。`r`n"

    if (g_Match.Warnings.Length() > 0) {
        report .= "`r`n不完整 / 冲突警告`r`n"
        report .= "------------------------------------------------------------`r`n"
        for _, warning in g_Match.Warnings
            report .= "- " warning "`r`n"
    }
    return report
}

AddTimeline(time, text) {
    global g_Match
    g_Match.Timeline.Push({Time:time, Text:text})
}

AddWarning(text) {
    global g_Match
    for _, existing in g_Match.Warnings {
        if (existing = text)
            return
    }
    g_Match.Warnings.Push(text)
}

PlayerLabel(uid, includeSpawn := false) {
    global g_Match
    key := UidKey(uid)
    label := "P??"
    for index, item in g_Match.RosterOrder {
        if (UidKey(item) = key) {
            label := "P" Format("{:02}", index)
            break
        }
    }
    teamText := "?"
    if g_Match.Teams.HasKey(key)
        teamText := g_Match.Teams[key].Team
    label .= " T" teamText
    if (g_Match.SelfUid != "" && key = UidKey(g_Match.SelfUid))
        label .= " (self)"
    if g_Match.UidToName.HasKey(key)
        label .= " [" g_Match.UidToName[key] "]"
    if g_Match.HeroByUid.HasKey(key) {
        heroId := g_Match.HeroByUid[key]
        heroName := HeroName(heroId)
        if (heroName != "")
            label .= " | 干员：" heroName "（" heroId "）"
        else
            label .= " | 干员：未知"
    }
    if includeSpawn
        label .= " | 出生点：" SpawnPointName(uid)
    return label
}

BoundRosterCount(mapping) {
    global g_Match
    count := 0
    if !IsObject(mapping)
        return 0
    for _, uid in g_Match.RosterOrder {
        if mapping.HasKey(UidKey(uid))
            count += 1
    }
    return count
}

HeroName(heroId) {
    heroId := Trim(heroId "")
    ; 2026-09-02 通过本地选人界面按顺序遍历，并由用户逐项命名。
    ; 42/43/44 只有目录加载证据，未进入本次 16 项可选列表，故不映射。
    ; 加非数字前缀，避免 AHK v1 把纯数字对象键在字符串/整数之间转换。
    static names := {"id:88000000030":"红狼"
        , "id:88000000025":"威龙"
        , "id:88000000038":"无名"
        , "id:88000000039":"疾风"
        , "id:88000000027":"蜂医"
        , "id:88000000036":"女医"
        , "id:88000000045":"蝶"
        , "id:88000000029":"老黑"
        , "id:88000000035":"鲁鲁"
        , "id:88000000037":"盾狗"
        , "id:88000000041":"比特"
        , "id:88000000047":"液氮"
        , "id:88000000028":"露娜"
        , "id:88000000026":"小麦"
        , "id:88000000040":"鸟人"
        , "id:88000000046":"回响"
        ; 用户确认：Reze2nsj / 苏沉鋭 使用的皮肤 AvatarId 对应红狼；
        ; Flacidusax 使用的皮肤 AvatarId 对应威龙。
        , "id:30000060001":"红狼"
        , "id:30000060007":"威龙"}
    key := "id:" heroId
    return names.HasKey(key) ? names[key] : ""
}

PlayerSpawnShortName(uid) {
    global g_Match
    key := UidKey(uid)
    if !g_Match.SpawnPoints.HasKey(key)
        return "未记录"
    spawn := g_Match.SpawnPoints[key]
    alias := Trim(spawn.Alias "")
    if (alias != "")
        return alias
    teamStart := Trim(spawn.TeamStart "")
    ; 新版巴克什出生点使用 TeamStartW8_1 / TeamStartE1 一类规范名。
    ; 它与航天基地 TeamStart1..9 不是同一套编号，显示为日志可证明的
    ; 东/西侧短名，绝不套用航天基地的“二员/牢大”等别名。
    if RegExMatch(teamStart, "i)^TeamStart([WE])(\d+)(?:_(\d+))?$", m) {
        side := (m1 = "W" || m1 = "w") ? "西侧" : "东侧"
        return side m2 (m3 != "" ? "-" m3 : "")
    }
    if RegExMatch(teamStart, "i)^TeamStart(\d+)$", m) {
        ; TeamStart5 尚未由用户命名；分组元数据缺失时也不把
        ; TeamStart102/204 之类内部编号冒充成出生点名称。
        if (m1 + 0 = 5)
            return "未命名点位5"
        return "未记录"
    }
    if (teamStart != "")
        return teamStart
    name := Trim(spawn.Name "")
    return name != "" ? name : "未记录"
}

PlayerHeroDisplay(uid) {
    global g_Match
    key := UidKey(uid)
    if !g_Match.HeroByUid.HasKey(key)
        return "未记录"
    heroId := g_Match.HeroByUid[key]
    heroName := HeroName(heroId)
    return heroName != "" ? heroName : "未知"
}

PlayerUserDisplay(uid) {
    global g_Match
    key := UidKey(uid)
    name := g_Match.UidToName.HasKey(key) ? g_Match.UidToName[key] : "未记录"
    if (g_Match.SelfUid != "" && key = UidKey(g_Match.SelfUid))
        name .= " (self)"
    return name
}

PlayerStatus(uid) {
    global g_Match
    key := UidKey(uid)
    if g_Match.Escaped.HasKey(key)
        return "已撤离"
    if g_Match.Boxes.HasKey(key)
        return "成盒"
    if g_Match.Corpses.HasKey(key)
        return "死亡"
    if g_Match.Downed.HasKey(key)
        return "倒地（仍计存活）"
    return "存活"
}

PlayerSlotDisplay(uid) {
    global g_Match
    key := UidKey(uid)
    slot := "P??"
    for index, item in g_Match.RosterOrder {
        if (UidKey(item) = key) {
            slot := "P" Format("{:02}", index)
            break
        }
    }
    team := g_Match.Teams.HasKey(key) ? g_Match.Teams[key].Team : "?"
    return slot " T" team
}

PlayerTableRow(uid) {
    return PlayerSpawnShortName(uid) " | " PlayerHeroDisplay(uid) " | " PlayerUserDisplay(uid) " | " PlayerStatus(uid)
}

OverlayPlayerRow(uid) {
    return PlayerSpawnShortName(uid) " · " PlayerHeroDisplay(uid)
}

WindowPlayerHeader() {
    return "编号 | 出生点名 | 干员名 | 用户名 | 状态`r`n------------------------------------------------------------`r`n"
}

WindowPlayerRow(uid) {
    return PlayerSlotDisplay(uid) " | " PlayerTableRow(uid)
}

PlayerSpawnRank(uid) {
    name := PlayerSpawnShortName(uid)
    static ranks := {"二员":1, "牢大":2, "牢二":3, "牢三":4, "西大":5, "宿舍":6, "中控":7, "发射":8}
    return ranks.HasKey(name) ? ranks[name] : 999
}

SortedRosterBySpawn(aliveOnly := false) {
    global g_Match
    sorted := []
    for rosterOrder, uid in g_Match.RosterOrder {
        if (aliveOnly && !IsAliveUid(uid))
            continue
        key := UidKey(uid)
        team := 2147483647
        memberIndex := 2147483647
        if g_Match.Teams.HasKey(key) {
            team := g_Match.Teams[key].Team + 0
            memberIndex := g_Match.Teams[key].Index + 0
        }
        item := {Uid:uid, Rank:PlayerSpawnRank(uid), Spawn:PlayerSpawnShortName(uid), Team:team, Index:memberIndex, Order:rosterOrder}
        insertAt := sorted.Length() + 1
        for position, existing in sorted {
            if (item.Rank < existing.Rank
                || (item.Rank = existing.Rank && item.Spawn < existing.Spawn)
                || (item.Rank = existing.Rank && item.Spawn = existing.Spawn && item.Team < existing.Team)
                || (item.Rank = existing.Rank && item.Spawn = existing.Spawn && item.Team = existing.Team && item.Index < existing.Index)
                || (item.Rank = existing.Rank && item.Spawn = existing.Spawn && item.Team = existing.Team && item.Index = existing.Index && item.Order < existing.Order)) {
                insertAt := position
                break
            }
        }
        sorted.InsertAt(insertAt, item)
    }
    result := []
    for _, item in sorted
        result.Push(item.Uid)
    return result
}

BuildPlayerTable() {
    global g_Match
    rows := "出生点名 | 干员名 | 用户名 | 状态`r`n"
    rows .= "------------------------------------------------------------`r`n"
    if (g_Match.RosterOrder.Length() = 0)
        return rows "暂无名单玩家`r`n"
    for _, uid in SortedRosterBySpawn()
        rows .= PlayerTableRow(uid) "`r`n"
    return rows
}

SpawnPointName(uid) {
    global g_Match
    key := UidKey(uid)
    if g_Match.SpawnPoints.HasKey(key) {
        spawn := g_Match.SpawnPoints[key]
        name := Trim(spawn.Name "")
        alias := Trim(spawn.Alias "")
        teamStart := Trim(spawn.TeamStart "")
        area := Trim(spawn.Area "")
        if (alias != "") {
            detail := alias
            if (area != "" || teamStart != "" || name != "")
                detail .= "（"
            if (area != "")
                detail .= area
            if (teamStart != "")
                detail .= (area != "" ? " / " : "") teamStart
            if (name != "")
                detail .= ((area != "" || teamStart != "") ? " / " : "") name
            if (area != "" || teamStart != "" || name != "")
                detail .= "）"
            return detail
        }
        if (name != "")
            return name
        if (teamStart != "") {
            detail := teamStart
            if (area != "" || name != "")
                detail .= "（"
            if (area != "")
                detail .= area
            if (name != "")
                detail .= (area != "" ? " / " : "") name
            if (area != "" || name != "")
                detail .= "）"
            return detail
        }
    }
    return "未记录"
}

StartSpotArea(orientation) {
    orientation := Trim(orientation "")
    if (orientation = "1")
        return "Core"
    if (orientation = "2")
        return "West"
    if (orientation = "3")
        return "East"
    return orientation = "" ? "" : "O" orientation
}

TeamStartAlias(teamStart) {
    teamStart := Trim(teamStart "")
    ; 这是用户根据多场日志确认的稳定命名；TeamId/TId 每局会变化，
    ; 只能使用 TeamStart 编号作为键。
    if (teamStart = "TeamStart1")
        return "二员"
    if (teamStart = "TeamStart2")
        return "牢大"
    if (teamStart = "TeamStart3")
        return "牢二"
    if (teamStart = "TeamStart4")
        return "牢三"
    if (teamStart = "TeamStart6")
        return "西大"
    if (teamStart = "TeamStart7")
        return "宿舍"
    if (teamStart = "TeamStart8")
        return "中控"
    if (teamStart = "TeamStart9")
        return "发射"
    return ""
}

TeamStartArea(teamStart) {
    teamStart := Trim(teamStart "")
    if RegExMatch(teamStart, "i)^TeamStartW")
        return "West"
    if RegExMatch(teamStart, "i)^TeamStartE")
        return "East"
    if (teamStart = "TeamStart1" || teamStart = "TeamStart7")
        return "Core"
    if (teamStart = "TeamStart2" || teamStart = "TeamStart3" || teamStart = "TeamStart4")
        return "East"
    if (teamStart = "TeamStart6" || teamStart = "TeamStart8" || teamStart = "TeamStart9")
        return "West"
    return ""
}

IsAliveUid(uid) {
    global g_Match
    key := UidKey(uid)
    return g_Match.Roster.HasKey(key)
        && !g_Match.Corpses.HasKey(key)
        && !g_Match.Boxes.HasKey(key)
        && !g_Match.Escaped.HasKey(key)
}

SortedAliveUids() {
    global g_Match
    sorted := []
    for rosterOrder, uid in g_Match.RosterOrder {
        if !IsAliveUid(uid)
            continue
        key := UidKey(uid)
        team := 2147483647
        memberIndex := 2147483647
        if g_Match.Teams.HasKey(key) {
            team := g_Match.Teams[key].Team + 0
            memberIndex := g_Match.Teams[key].Index + 0
        }
        item := {Uid:uid, Team:team, Index:memberIndex, Order:rosterOrder}
        insertAt := sorted.Length() + 1
        for position, existing in sorted {
            if (team < existing.Team
                || (team = existing.Team && memberIndex < existing.Index)
                || (team = existing.Team && memberIndex = existing.Index && rosterOrder < existing.Order)) {
                insertAt := position
                break
            }
        }
        sorted.InsertAt(insertAt, item)
    }
    result := []
    for _, item in sorted
        result.Push(item.Uid)
    return result
}

ParseLogTime(line) {
    if !RegExMatch(line, "^\[(\d{4})\.(\d{2})\.(\d{2})-(\d{2})\.(\d{2})\.(\d{2}):(\d{3})\]", m)
        return {Stamp:"", Ms:0, Label:"时间不可用"}
    stamp := m1 m2 m3 m4 m5 m6
    label := m1 "-" m2 "-" m3 " " m4 ":" m5 ":" m6 "." m7
    return {Stamp:stamp, Ms:m7 + 0, Label:label}
}

TimeDiffMs(earlier, later) {
    if !IsObject(earlier) || !IsObject(later) || earlier.Stamp = "" || later.Stamp = ""
        return -1
    seconds := later.Stamp
    earlierStamp := earlier.Stamp
    EnvSub, seconds, %earlierStamp%, Seconds
    return seconds * 1000 + later.Ms - earlier.Ms
}

TimeLabel(time) {
    return IsObject(time) ? time.Label : "时间不可用"
}

ObjectCount(object) {
    count := 0
    for _, __ in object
        count += 1
    return count
}

FormatBytes(bytes) {
    if (bytes >= 1048576)
        return Format("{:.2f} MiB", bytes / 1048576.0)
    if (bytes >= 1024)
        return Format("{:.1f} KiB", bytes / 1024.0)
    return bytes " B"
}

UpdateReaderStatus() {
    global g_ReaderState, g_SelfTest
    if !g_SelfTest
        GuiControl, 1:, ReaderText, % "日志读取：" g_ReaderState
}

UpdateMatchStatus() {
    global g_Match, g_LastReport, g_SelfTest, g_Recovering
    if g_SelfTest || g_Recovering
        return
    if !IsObject(g_Match) {
        GuiControl, 1:, MatchText, 对局：等待下一局
        return
    }
    if g_Match.Active {
        rosterCount := g_Match.RosterOrder.Length()
        candidate := g_Match.InitialCount - ObjectCount(g_Match.Corpses) - ObjectCount(g_Match.Boxes) - ObjectCount(g_Match.Escaped) - (g_Match.LocalCorpseUnknown ? 1 : 0)
        GuiControl, 1:, MatchText, % "对局：实时中 | 开局 " TimeLabel(g_Match.StartTime) " | 名单 " rosterCount "/" g_Match.InitialCount " | 候选剩余 " candidate
    } else if (g_LastReport != "") {
        GuiControl, 1:, MatchText, % "对局：已于 " TimeLabel(g_Match.EndTime) " 进入本地结算，赛后报告已解锁"
    } else {
        GuiControl, 1:, MatchText, 对局：等待下一局（请在开局前启动或点击重新监听）
    }
}

#Include *i %A_ScriptDir%\DeltaForcePostmatchAudit.Tests.ahk
#Include %A_ScriptDir%\DeltaHelp.ahk
