#NoEnv
#SingleInstance Force
#Warn
SetBatchLines, -1

logDir := A_ScriptDir "\simulation"
logPath := logDir "\DeltaForce.log"
FileCreateDir, %logDir%
FileDelete, %logPath%
FileAppend,, %logPath%
Sleep, 1000

lines := []
lines.Push("[2026.08.26-20.00.00:000] LogStartSpotAlloc: Display: TempMS23-Alloc - Begin[PlayerNum:6, TeamStartNums:2]")
lines.Push("[2026.08.26-20.00.00:010] UStartSpotAllocator_SOL - PlayerUid: 1001")
lines.Push("[2026.08.26-20.00.00:011] UStartSpotAllocator_SOL - PlayerUid: 1002")
lines.Push("[2026.08.26-20.00.00:012] UStartSpotAllocator_SOL - PlayerUid: 1003")
lines.Push("[2026.08.26-20.00.00:013] UStartSpotAllocator_SOL - PlayerUid: 1004")
lines.Push("[2026.08.26-20.00.00:014] UStartSpotAllocator_SOL - PlayerUid: 1005")
lines.Push("[2026.08.26-20.00.00:015] UStartSpotAllocator_SOL - PlayerUid: 1006")
lines.Push("[2026.08.26-20.00.00:020] Member-End: [UId:1001, TeamId:1, TeamIdx:0]")
lines.Push("[2026.08.26-20.00.00:021] Member-End: [UId:1002, TeamId:1, TeamIdx:1]")
lines.Push("[2026.08.26-20.00.00:022] Member-End: [UId:1003, TeamId:1, TeamIdx:2]")
lines.Push("[2026.08.26-20.00.00:023] Member-End: [UId:1004, TeamId:2, TeamIdx:0]")
lines.Push("[2026.08.26-20.00.00:024] Member-End: [UId:1005, TeamId:2, TeamIdx:1]")
lines.Push("[2026.08.26-20.00.00:025] Member-End: [UId:1006, TeamId:2, TeamIdx:2]")
lines.Push("[2026.08.26-20.00.00:026] LogStartSpotAlloc: Display: Find StartSpotGroup: [Id:301, name:TeamStart9]")
lines.Push("[2026.08.26-20.00.00:027] LogStartSpotAlloc: Display: TempMS23 - TeamStartId[O: 2] [TId: 301]")
lines.Push("[2026.08.26-20.00.00:028] LogStartSpotAlloc: Display: AllocStartSpot Success: UID:1001, TId:1, TIdx:0, TGroupI:301, SpotIdx:0")
lines.Push("[2026.08.26-20.00.00:030] AllocStartSpot AdjustLoc: UID:1001, TId:1, TIdx:0, Find Name:PlayerStart58, Loc:X=100.000 Y=200.000 Z=300.000, Rot:")
lines.Push("[2026.08.26-20.00.00:031] AllocStartSpot AdjustLoc: UID:1002, TId:1, TIdx:1, Find Name:PlayerStart59, Loc:X=101.000 Y=201.000 Z=301.000, Rot:")
lines.Push("[2026.08.26-20.00.00:032] AllocStartSpot AdjustLoc: UID:1003, TId:1, TIdx:2, Find Name:PlayerStart60, Loc:X=102.000 Y=202.000 Z=302.000, Rot:")
lines.Push("[2026.08.26-20.00.00:033] AllocStartSpot AdjustLoc: UID:1004, TId:2, TIdx:0, Find Name:PlayerStart61, Loc:X=103.000 Y=203.000 Z=303.000, Rot:")
lines.Push("[2026.08.26-20.00.00:034] AllocStartSpot AdjustLoc: UID:1005, TId:2, TIdx:1, Find Name:PlayerStart62, Loc:X=104.000 Y=204.000 Z=304.000, Rot:")
lines.Push("[2026.08.26-20.00.00:035] AllocStartSpot AdjustLoc: UID:1006, TId:2, TIdx:2, Find Name:PlayerStart63, Loc:X=105.000 Y=205.000 Z=305.000, Rot:")
lines.Push("[2026.08.26-20.00.08:000] UDFMFSM_ZiplineControlAction Exit demo BP_DFMCharacter_C_42 1004 Autonomous=0 Loc:X=1234.5 Y=-812.0 Z=96.25")
lines.Push("[2026.08.26-20.00.09:000] OnEnter ImpendingDeath : 1004 isAutonomous = 0")
lines.Push("[2026.08.26-20.00.10:000] UGPCharacterVoiceComponent::OnPlayerDied, Character:1004 SetTimer StopCharacterGameAk")
lines.Push("[2026.08.26-20.00.10:050] CourseworkEvent Type=DEATH UID:1004 Loc:X=1240.0 Y=-805.5 Z=94.0")
lines.Push("[2026.08.26-20.00.12:000] CourseworkEvent Type=BOX UID:1004 Loc:X=1241.0 Y=-805.0 Z=93.5")
lines.Push("[2026.08.26-20.00.15:000] UDFMFSM_ZiplineControlAction Exit demo BP_DFMCharacter_C_43 1005 Autonomous=0 Loc:X=-300.0 Y=401.5 Z=77.0")
lines.Push("[2026.08.26-20.00.16:500] CourseworkEvent Type=DEATH UID:1005 Loc:X=-298.5 Y=405.0 Z=75.25")
lines.Push("[2026.08.26-20.00.20:000] ADFMPlayerState::OnRep_ExitState ExitState=3, Uin=1006, PlayerName=runner")
lines.Push("[2026.08.26-20.00.20:500] UDFMFSM_SOLEscapedStateAction Enter PlayerName=runner")
lines.Push("[2026.08.26-20.00.25:000] SettlementLogic._OnPlayerMatchOver")
lines.Push("[2026.08.26-20.00.26:000] UGameFlowStage::BeginStage() BeginStage GFStageName = EGameFlowStageType::SafeHouse")

for index, line in lines {
    AppendEncodedLine(logPath, line "`r`n")
    Sleep, % (index <= 13 ? 220 : 850)
}

if !(A_Args.Length() && A_Args[1] = "--headless")
    MsgBox, 64, 作业日志回放, XOR 0x5C 实时日志回放已完成。
ExitApp

AppendEncodedLine(path, text) {
    byteCount := StrPut(text, "UTF-8") - 1
    VarSetCapacity(plain, byteCount + 1, 0)
    StrPut(text, &plain, byteCount + 1, "UTF-8")
    VarSetCapacity(encoded, byteCount, 0)
    Loop, %byteCount% {
        value := NumGet(plain, A_Index - 1, "UChar") ^ 0x5C
        NumPut(value, encoded, A_Index - 1, "UChar")
    }
    file := FileOpen(path, "a")
    if !IsObject(file) {
        MsgBox, 16, 作业日志回放, 无法打开模拟日志：%path%
        ExitApp, 1
    }
    file.RawWrite(encoded, byteCount)
    file.Close()
}
