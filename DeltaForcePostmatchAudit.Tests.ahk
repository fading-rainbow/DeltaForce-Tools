; DeltaForcePostmatchAudit development regression tests.
; Optional include: the release script runs normally when this file is absent.

RunSelfTest() {
    RunBufferStabilityTest()
    global g_LastReport, g_Match, MATCH_END_GRACE_MS
    ResetMatch()
    lines := []
    lines.Push("[2026.08.26-12.00.00:000] LogStartSpotAlloc: Display: TempMS23-Alloc - Begin[PlayerNum:3, TeamStartNums:1]")
    lines.Push("[2026.08.26-12.00.00:001] LogStartSpotAlloc: Display: UStartSpotAllocator_SOL - PlayerMembers(Team): 3, AIPlayerMembers: 0")
    lines.Push("[2026.08.26-12.00.00:010] UStartSpotAllocator_SOL - PlayerUid: 13885455241972588702")
    lines.Push("[2026.08.26-12.00.00:011] UStartSpotAllocator_SOL - PlayerUid: 1002")
    lines.Push("[2026.08.26-12.00.00:012] UStartSpotAllocator_SOL - PlayerUid: 14262046314591977102")
    lines.Push("[2026.08.26-12.00.00:020] Member-End: [UId:13885455241972588702, TeamId:1, TeamIdx:0]")
    lines.Push("[2026.08.26-12.00.00:021] Member-End: [UId:1002, TeamId:1, TeamIdx:1]")
    lines.Push("[2026.08.26-12.00.00:022] Member-End: [UId:14262046314591977102, TeamId:1, TeamIdx:2]")
    lines.Push("[2026.08.26-12.00.00:030] AllocStartSpot AdjustLoc: UID:13885455241972588702, TId:1, TIdx:0, Find Name:PlayerStart58, Rot:")
    lines.Push("[2026.08.26-12.00.00:031] AllocStartSpot AdjustLoc: UID:1002, TId:1, TIdx:1, Find Name:PlayerStart59, Rot:")
    lines.Push("[2026.08.26-12.00.00:032] AllocStartSpot AdjustLoc: UID:14262046314591977102, TId:1, TIdx:2, Find Name:PlayerStart60, Rot:")
    lines.Push("[2026.08.26-12.01.00:000] UDFMFSM_ZiplineControlAction Exit x BP_DFMCharacter_C_42 13885455241972588702 Autonomous=0")
    lines.Push("[2026.08.26-12.01.01:500] UGPCharacterVoiceComponent::OnPlayerDied, Character:13885455241972588702 SetTimer StopCharacterGameAk")
    lines.Push("[2026.08.26-12.01.02:000] LogGPHighlightMoment: Display: UHighlightMomentComponent::ClientNotifySOLRescue - RescueType: 2, Rescuer: 1002, Target: 13885455241972588702")
    lines.Push("[2026.08.26-12.01.02:200] UDFMFSM_ZiplineControlAction Exit x BP_DFMCharacter_C_42 13885455241972588702 Autonomous=0")
    lines.Push("[2026.08.26-12.01.03:700] UGPCharacterVoiceComponent::OnPlayerDied, Character:13885455241972588702 SetTimer StopCharacterGameAk")
    lines.Push("[2026.08.26-12.01.03:900] APlayerExitBase::OnRep_ExitRuntimeInfo Exit=条件撤离点：试车场, ResetRealNum=0, CoolDownTargetTime=0, RealPlayerEscapeNum=1, PaidPlayerArrayNum=0")
    lines.Push("[2026.08.26-12.01.04:000] ADFMPlayerState::OnRep_ExitState ExitState=3, Uin=14262046314591977102, PlayerName=runner")
    lines.Push("[2026.08.26-12.01.04:500] UDFMFSM_SOLEscapedStateAction Enter PlayerName=runner")
    lines.Push("[2026.08.26-12.01.05:000] UGameFlowStage::BeginStage() BeginStage GFStageName = EGameFlowStageType::SafeHouse")
    for _, line in lines {
        ProcessLine(line)
        if InStr(line, "ClientNotifySOLRescue") {
            AssertContains(BuildLiveReport(), "名单完整度：3/3", "overflow UID roster keys")
            AssertContains(BuildLiveReport(), "候选场内剩余：3", "corpse rescue restores candidate population")
            AssertContains(BuildLiveReport(), "尸体救援：1", "corpse rescue count")
            AssertContains(BuildLiveReport(), "存活列表（3）", "rescued player returns to alive list")
            AssertContains(BuildLiveReport(), "救援列表（1）", "rescue list section")
            AssertContains(BuildLiveReport(), "P02 T1 | PlayerStart59 | 未记录 | 未记录 | 存活", "spawn point appears in live roster")
            AssertContains(BuildLiveReport(), "出生点映射：3/3", "spawn mapping coverage")
        }
    }

    AssertContains(g_LastReport, "候选场内剩余（仅赛后）：1", "candidate population")
    AssertContains(g_LastReport, "已建立名单 UID：3", "overflow UID roster count")
    AssertContains(g_LastReport, "已识别尸体救援：1", "corpse rescue report")
    AssertNotContains(g_LastReport, "坐标", "completed report has no coordinate module")
    AssertContains(g_LastReport, "确认成功撤离：1", "escape confirmation")
    AssertContains(g_LastReport, "存活列表（1）", "final alive list")
    AssertContains(g_LastReport, "死亡列表（1）", "final death list")
    AssertContains(g_LastReport, "救援列表（1）", "final rescue list")
    AssertContains(g_LastReport, "盒子列表（0）", "final box list")
    AssertContains(g_LastReport, "撤离玩家列表（1）", "escape player section")
    AssertContains(g_LastReport, "撤离点：条件撤离点：试车场", "original package-drop exit name")
    AssertContains(g_LastReport, "P03 T1", "player label includes team")
    AssertContains(g_LastReport, "P01 T1 | PlayerStart58 |", "spawn point appears in completed report")

    ; PlayerMembers 与 TempMS23 可能前后各出现一次；验证前一个锚点收集的 UID 不会被后一个抹掉。
    ResetMatch()
    ProcessLine("[2026.08.26-15.30.00:000] UStartSpotAllocator_SOL - PlayerMembers(Team): 4, AIPlayerMembers: 0")
    ProcessLine("[2026.08.26-15.30.00:001] UStartSpotAllocator_SOL - PlayerUid: 7001")
    ProcessLine("[2026.08.26-15.30.00:002] UStartSpotAllocator_SOL - PlayerUid: 7002")
    ProcessLine("[2026.08.26-15.30.00:003] UStartSpotAllocator_SOL - PlayerUid: 7003")
    ProcessLine("[2026.08.26-15.30.00:004] UStartSpotAllocator_SOL - PlayerUid: 7004")
    ProcessLine("[2026.08.26-15.30.00:005] TempMS23-Alloc - Begin[PlayerNum:4, TeamStartNums:2]")
    ProcessLine("[2026.08.26-15.30.00:010] Member-End: [UId:7001, TeamId:1, TeamIdx:0]")
    ProcessLine("[2026.08.26-15.30.00:011] Member-End: [UId:7002, TeamId:1, TeamIdx:1]")
    ProcessLine("[2026.08.26-15.30.00:012] Member-End: [UId:7003, TeamId:2, TeamIdx:0]")
    AssertContains(BuildLiveReport(), "名单完整度：4/4", "duplicate start anchors preserve pre-collected UID")

    ; 不调用 ResetMatch，直接连续注入下一局，覆盖“上一局结束后开下一局”的实际路径。
    ProcessLine("[2026.08.26-16.00.00:000] TempMS23-Alloc - Begin[PlayerNum:2, TeamStartNums:2]")
    ProcessLine("[2026.08.26-16.00.00:010] Member-End: [UId:8001, TeamId:9, TeamIdx:0]")
    ProcessLine("[2026.08.26-16.00.00:011] Member-End: [UId:8002, TeamId:8, TeamIdx:0]")
    ProcessLine("[2026.08.26-16.00.00:020] AllocStartSpot AdjustLoc: UID:8001, TId:9, TIdx:0, Find Name:PlayerStart9, Rot:")
    ProcessLine("[2026.08.26-16.00.00:021] AllocStartSpot AdjustLoc: UID:8002, TId:8, TIdx:0, Find Name:PlayerStart8, Rot:")
    liveSecond := BuildLiveReport()
    AssertOrder(liveSecond, "P02 T8 | PlayerStart8", "P01 T9 | PlayerStart9", "alive teams sorted by TeamId")

    ; 旧局尚未给出结算就出现新锚点时，也必须安全封存并清空旧 UID。
    ProcessLine("[2026.08.26-16.00.01:000] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.26-16.00.01:010] Member-End: [UId:9001, TeamId:1, TeamIdx:0]")
    ProcessLine("[2026.08.26-16.00.01:020] AllocStartSpot AdjustLoc: UID:9001, TId:1, TIdx:0, Find Name:PlayerStart1, Rot:")
    AssertContains(BuildLiveReport(), "名单完整度：1/1", "new match roster after previous match")
    AssertContains(BuildLiveReport(), "P01 T1 | PlayerStart1 | 未记录 | 未记录 | 存活", "new match spawn after previous match")
    AssertNotContains(BuildLiveReport(), "PlayerStart8", "previous match spawn was cleared")
    ProcessLine("[2026.08.26-16.00.02:000] BeginStage GFStageName = EGameFlowStageType::SafeHouse")
    AssertContains(g_LastReport, "已建立名单 UID：1", "second match finalized")
    AssertNotContains(g_LastReport, "P02 T8", "previous match UID was not carried into report")

    ResetMatch()
    ProcessLine("[2026.08.26-13.00.00:000] LogStartSpotAlloc: Display: TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.26-13.00.00:010] Member-End: [UId:13885455241972588702, TeamId:1, TeamIdx:0]")
    ProcessLine("[2026.08.26-13.00.00:020] UDFMFSM_WaitingStartSOLAction::OnEnter, PlayerName=timeout-target, Uin=13885455241972588702, isAutonomous = 0")
    ProcessLine("[2026.08.26-13.00.00:500] UDFMFSM_ZiplineControlAction Exit x BP_DFMCharacter_C_42 13885455241972588702 Autonomous=0")
    ProcessLine("[2026.08.26-13.00.01:000] UGPCharacterVoiceComponent::OnPlayerDied, Character:13885455241972588702 SetTimer StopCharacterGameAk")
    ProcessLine("[2026.08.26-13.01.01:000] ADFMCharacter::IsCanBeRescue Name timeout-target")
    ProcessLine("[2026.08.26-13.01.01:001] ADFMCharacter::IsCanBeRescue bTmpIsDead=1 DeadTickNum=1, bFinishGame=0 IsMatchOver=0 DeathWaitRescueTime=120.000000 bDeathCanRescue=1")
    ProcessLine("[2026.08.26-13.02.02:000] unrelated heartbeat")
    AssertContains(BuildLiveReport(), "当前尸体/死亡候选：1", "log rescue window overrides fallback timeout")
    ProcessLine("[2026.08.26-13.03.01:100] unrelated heartbeat")
    AssertContains(BuildLiveReport(), "盒子事件：1", "corpse timeout becomes inferred box")
    AssertContains(BuildLiveReport(), "候选场内剩余：0", "box remains outside candidate population")
    AssertNotContains(BuildLiveReport(), "坐标", "live report has no coordinate module")
    ProcessLine("[2026.08.26-13.03.02:000] ClientNotifySOLRescue - RescueType: 2, Rescuer: 1002, Target: 13885455241972588702")
    AssertContains(BuildLiveReport(), "盒子事件：0", "explicit rescue corrects inferred box")
    AssertContains(BuildLiveReport(), "候选场内剩余：1", "late explicit rescue restores population")

    ResetMatch()
    ProcessLine("[2026.08.26-14.00.00:000] LogStartSpotAlloc: Display: TempMS23-Alloc - Begin[PlayerNum:3, TeamStartNums:1]")
    ProcessLine("[2026.08.26-14.00.00:010] Member-End: [UId:2001, TeamId:5, TeamIdx:0]")
    ProcessLine("[2026.08.26-14.00.00:011] Member-End: [UId:2002, TeamId:5, TeamIdx:1]")
    ProcessLine("[2026.08.26-14.00.00:012] Member-End: [UId:2003, TeamId:6, TeamIdx:0]")
    ProcessLine("[2026.08.26-14.00.00:020] UDFMFSM_WaitingStartSOLAction::OnEnter, PlayerName=reborn-target, Uin=2001, isAutonomous = 0")
    ProcessLine("[2026.08.26-14.00.00:021] UDFMFSM_WaitingStartSOLAction::OnEnter, PlayerName=action-first, Uin=2002, isAutonomous = 0")
    ProcessLine("[2026.08.26-14.00.01:000] UGPCharacterVoiceComponent::OnPlayerDied, Character:2001 SetTimer StopCharacterGameAk")
    ProcessLine("[2026.08.26-14.00.02:000] UDFMFSM_RebornAction::OnEnter:reborn-target")
    ProcessLine("[2026.08.26-14.00.03:000] UDFMFSM_SOLEscapedStateAction Enter PlayerName=reborn-target")
    ProcessLine("[2026.08.26-14.00.03:200] ADFMPlayerState::OnRep_ExitState ExitState=3, Uin=2001, PlayerName=reborn-target")
    ProcessLine("[2026.08.26-14.00.03:300] UDFMFSM_SOLEscapedStateAction Enter PlayerName=action-first")
    ProcessLine("[2026.08.26-14.00.03:500] ADFMPlayerState::OnRep_ExitState ExitState=3, Uin=2002, PlayerName=action-first")
    ProcessLine("[2026.08.26-14.00.04:000] CourseworkEvent Type=BOX UID:2003")
    ProcessLine("[2026.08.26-14.00.05:000] UGameFlowStage::BeginStage() BeginStage GFStageName = EGameFlowStageType::SafeHouse")
    AssertContains(g_LastReport, "已识别尸体救援：1", "RebornAction corpse rescue")
    AssertContains(g_LastReport, "当前盒子状态：1", "box and escape mutual exclusion")
    AssertContains(g_LastReport, "确认成功撤离：2", "action-first escape pairing")
    AssertContains(g_LastReport, "候选场内剩余（仅赛后）：0", "SafeHouse match completion")
    AssertContains(g_LastReport, "存活列表（0）", "completed no-alive list")
    AssertContains(g_LastReport, "P01 T5", "team label in completed report")

    ResetMatch()
    ProcessLine("[2026.08.26-15.00.00:000] TempMS23-Alloc - Begin[PlayerNum:4, TeamStartNums:2]")
    ProcessLine("[2026.08.26-15.00.00:010] Member-End: [UId:3001, TeamId:6, TeamIdx:0]")
    ProcessLine("[2026.08.26-15.00.00:011] Member-End: [UId:3002, TeamId:6, TeamIdx:1]")
    ProcessLine("[2026.08.26-15.00.00:012] Member-End: [UId:3003, TeamId:6, TeamIdx:2]")
    ProcessLine("[2026.08.26-15.00.00:013] Member-End: [UId:3004, TeamId:7, TeamIdx:0]")
    ProcessLine("[2026.08.26-15.00.00:020] UDFMFSM_WaitingStartSOLAction::OnEnter, PlayerName=rocket-a, Uin=3001, isAutonomous = 0")
    ProcessLine("[2026.08.26-15.00.00:021] UDFMFSM_WaitingStartSOLAction::OnEnter, PlayerName=rocket-b, Uin=3002, isAutonomous = 0")
    ProcessLine("[2026.08.26-15.00.00:022] UDFMFSM_WaitingStartSOLAction::OnEnter, PlayerName=rocket-c, Uin=3003, isAutonomous = 0")
    ProcessLine("[2026.08.26-15.09.58:500][90][3004][1] AGPCharacterBase::OnRep_GPCharacterHiddenInGame HiddenInGameBitValue=2")
    ProcessLine("[2026.08.26-15.10.00:000][100][3001][1] AGPCharacterBase::OnRep_GPCharacterHiddenInGame HiddenInGameBitValue=2")
    ProcessLine("[2026.08.26-15.10.00:001][100][3002][1] AGPCharacterBase::OnRep_GPCharacterHiddenInGame HiddenInGameBitValue=2")
    ProcessLine("[2026.08.26-15.10.00:007] APlayerExitBase::OnRep_ExitRuntimeInfo Exit=火箭撤离点, ResetRealNum=1, CoolDownTargetTime=0, RealPlayerEscapeNum=3, PaidPlayerArrayNum=0")
    ProcessLine("[2026.08.26-15.10.00:250][101][3003][1] AGPCharacterBase::OnRep_GPCharacterHiddenInGame HiddenInGameBitValue=2")
    ProcessLine("[2026.08.26-15.10.00:400] LogPlayerExit: Display: rocket association settle tick")
    AssertContains(BuildLiveReport(), "确认撤离：3", "rocket fallback escape count")
    AssertContains(BuildLiveReport(), "撤离玩家列表（3）", "rocket fallback escape list")
    AssertContains(BuildLiveReport(), "火箭/飞升撤离", "rocket escape method label")
    AssertContains(BuildLiveReport(), "撤离点：火箭撤离点", "original rocket exit display name")
    ProcessLine("[2026.08.26-15.10.00:300] UDFMFSM_SOLEscapedStateAction Enter PlayerName = rocket-a")
    ProcessLine("[2026.08.26-15.10.00:301] ADFMPlayerState::OnRep_ExitState ExitState=3, Uin=3001, PlayerName=rocket-a")
    ProcessLine("[2026.08.26-15.10.00:302] UDFMFSM_SOLEscapedStateAction Enter PlayerName = rocket-b")
    ProcessLine("[2026.08.26-15.10.00:303] ADFMPlayerState::OnRep_ExitState ExitState=3, Uin=3002, PlayerName=rocket-b")
    ProcessLine("[2026.08.26-15.10.00:304] UDFMFSM_SOLEscapedStateAction Enter PlayerName = rocket-c")
    ProcessLine("[2026.08.26-15.10.00:305] ADFMPlayerState::OnRep_ExitState ExitState=3, Uin=3003, PlayerName=rocket-c")
    ProcessLine("[2026.08.26-15.10.01:000] BeginStage GFStageName = EGameFlowStageType::SafeHouse")
    AssertContains(g_LastReport, "确认成功撤离：3", "rocket escapes remain idempotent")
    AssertContains(g_LastReport, "候选场内剩余（仅赛后）：1", "rocket nearest candidates leave unrelated hidden UID alive")

    ResetMatch()
    ProcessLine("[2026.08.30-10.18.26:118] TempMS23-Alloc - Begin[PlayerNum:3, TeamStartNums:1]")
    ProcessLine("[2026.08.30-10.18.26:119] Member-End: [UId:4001, TeamId:4, TeamIdx:0]")
    ProcessLine("[2026.08.30-10.18.26:120] Member-End: [UId:4002, TeamId:4, TeamIdx:1]")
    ProcessLine("[2026.08.30-10.18.26:121] Member-End: [UId:4003, TeamId:4, TeamIdx:2]")
    ProcessLine("[2026.08.30-10.20.00:000] LogItem: { DFMFSM_UseItemAllControlAction_1,uin:4001 } UDFMFSM_UseItemAllControlAction::OnEnter() Name = T4-A")
    ProcessLine("[2026.08.30-10.20.00:001] LogCharacterFSM: UDFMFSM_ZiplineControlAction Exit T4-B BP_DFMCharacter_C_2 4002 Autonomous=0")
    ProcessLine("[2026.08.30-10.20.00:002] LogItem: { DFMFSM_UseItemAllControlAction_3,uin:4003 } UDFMFSM_UseItemAllControlAction::OnEnter() Name = T4-C")
    ProcessLine("[2026.08.30-10.23.38:210] OnEnter ImpendingDeath : 4001 isAutonomous = 0")
    ProcessLine("[2026.08.30-10.23.58:953] UGPCharacterVoiceComponent::OnPlayerDied, Character:4001 SetTimer StopCharacterGameAk")
    ProcessLine("[2026.08.30-10.25.43:634] UDFMFSM_RebornAction::OnEnter:T4-A")
    AssertContains(BuildLiveReport(), "存活列表（3）", "item-name mapping restores corpse to alive")
    ProcessLine("[2026.08.30-10.24.52:366] OnEnter ImpendingDeath : 4002 isAutonomous = 0")
    ProcessLine("[2026.08.30-10.25.06:406] UGPCharacterVoiceComponent::OnPlayerDied, Character:4002 SetTimer StopCharacterGameAk")
    ProcessLine("[2026.08.30-10.27.11:744] UDFMFSM_RebornAction::OnEnter:T4-B")
    AssertContains(BuildLiveReport(), "尸体救援：2", "zipline-name mapping restores corpse to alive")
    ProcessLine("[2026.08.30-10.35.20:693] OnEnter ImpendingDeath : 4002 isAutonomous = 0")
    ProcessLine("[2026.08.30-10.35.42:576] UDFMFSM_RebornAction::OnEnter:T4-B")
    AssertContains(BuildLiveReport(), "倒地救起：1", "downed RebornAction is tracked")
    AssertContains(BuildLiveReport(), "候选场内剩余：3", "downed rescue does not double count population")
    ProcessLine("[2026.08.30-10.35.39:834] OnEnter ImpendingDeath : 4001 isAutonomous = 0")
    ProcessLine("[2026.08.30-10.35.44:090] UGPCharacterVoiceComponent::OnPlayerDied, Character:4001 SetTimer StopCharacterGameAk")
    ProcessLine("[2026.08.30-10.39.48:451] OnEnter ImpendingDeath : 4003 isAutonomous = 0")
    ProcessLine("[2026.08.30-10.39.50:359] UGPCharacterVoiceComponent::OnPlayerDied, Character:4003 SetTimer StopCharacterGameAk")
    ProcessLine("[2026.08.30-10.40.30:616] UGPCharacterVoiceComponent::OnPlayerDied, Character:4002 SetTimer StopCharacterGameAk")
    AssertContains(BuildLiveReport(), "存活列表（0）", "T4 final deaths remove all three players")
    AssertContains(BuildLiveReport(), "候选场内剩余：0", "T4 final death times remove all three from candidate population")
    AssertContains(BuildLiveReport(), "死亡列表（2）", "recent T4 deaths remain corpse candidates")
    AssertContains(BuildLiveReport(), "盒子事件：1", "older T4 death advances to inferred box")

    ResetMatch()
    ProcessLine("[2026.08.30-11.00.00:000] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.30-11.00.00:001] Member-End: [UId:5001, TeamId:1, TeamIdx:0]")
    ProcessLine("[2026.08.30-11.00.00:002] UDFMFSM_WaitingStartSOLAction::OnEnter, PlayerName=repeat-rescue, Uin=5001, isAutonomous = 0")
    ProcessLine("[2026.08.30-11.01.00:000] UGPCharacterVoiceComponent::OnPlayerDied, Character:5001 SetTimer StopCharacterGameAk")
    ProcessLine("[2026.08.30-11.01.10:000] UDFMFSM_RebornAction::OnEnter:repeat-rescue")
    ProcessLine("[2026.08.30-11.02.00:000] UGPCharacterVoiceComponent::OnPlayerDied, Character:5001 SetTimer StopCharacterGameAk")
    ProcessLine("[2026.08.30-11.02.10:000] UDFMFSM_RebornAction::OnEnter:repeat-rescue")
    AssertContains(BuildLiveReport(), "尸体救援：2", "same UID can complete multiple corpse rescue cycles")
    AssertContains(BuildLiveReport(), "存活列表（1）", "repeated corpse rescue restores alive state")

    ResetMatch()
    ProcessLine("[2026.08.30-11.09.11:769] UStartSpotAllocator_SOL - PlayerMembers(Team): 2, AIPlayerMembers: 0")
    ProcessLine("[2026.08.30-11.09.11:769] UStartSpotAllocator_SOL - PlayerUid: 6001")
    ProcessLine("[2026.08.30-11.09.11:769] UStartSpotAllocator_SOL - PlayerUid: 6002")
    ProcessLine("[2026.08.30-11.09.11:769] TempMa2-Alloc - InputMember: PlayerUin=6001, TeamId=4, TeamType=6, PlayerIdx=0")
    ProcessLine("[2026.08.30-11.09.11:769] TempMa2-Alloc - InputMember: PlayerUin=6002, TeamId=4, TeamType=6, PlayerIdx=1")
    AssertContains(BuildLiveReport(), "名单完整度：2/2", "TempMa2 PlayerMembers starts match and builds roster")
    AssertContains(BuildLiveReport(), "P01 T4", "TempMa2 team mapping first member")
    AssertContains(BuildLiveReport(), "P02 T4", "TempMa2 team mapping second member")

    ResetMatch()
    ProcessLine("[2026.08.30-12.00.00:000] UStartSpotAllocator_SOL - PlayerMembers(Team): 1, AIPlayerMembers: 0")
    ProcessLine("[2026.08.30-12.10.00:000] SettlementLogic._OnPlayerMatchOver")
    g_Match.PendingEnd.Tick := A_TickCount - MATCH_END_GRACE_MS - 1
    TryFinalizePendingEnd()
    AssertContains(g_LastReport, "_OnPlayerMatchOver 后 60 s", "match-over grace fallback finalizes missed end anchors")

    ResetMatch()
    ProcessLine("[2026.08.30-13.00.00:000] UStartSpotAllocator_SOL - PlayerMembers(Team): 1, AIPlayerMembers: 0")
    ProcessLine("[2026.08.30-13.10.00:000] SettlementModule:OnGameFlowChangeEnter, 14")
    AssertContains(g_LastReport, "结算模块进入 SafeHouse 流程", "SafeHouse settlement module transition finalizes match")

    ; 实际日志会先写 GameSettlement，结算动画期间仍可能继续写撤离事件；
    ; 因此先保持活动状态，直到 _OnGameSettlementEnd 才正式封局。
    ResetMatch()
    ProcessLine("[2026.08.30-13.20.00:000] UStartSpotAllocator_SOL - PlayerMembers(Team): 1, AIPlayerMembers: 0")
    ProcessLine("[2026.08.30-13.30.00:000] LogGPGameFlow: BeginStage GFStageName = EGameFlowStageType::GameSettlement")
    AssertContains(BuildLiveReport(), "对局状态：进行中", "GameSettlement keeps tail event window open")
    ProcessLine("[2026.08.30-13.30.30:000] SettlementLogic._OnGameSettlementEnd")
    AssertContains(g_LastReport, "GameSettlement 流程结束", "GameSettlement end finalizes match")

    ; 出生点别名测试：分组元数据可能早于开局锚点，且 PlayerStart 行只携带
    ; TGroupI；验证最终显示同时包含用户别名、区域和原始日志编号。
    ResetMatch()
    ProcessLine("[2026.08.30-14.00.00:000] Find StartSpotGroup: [Id:204, name:TeamStart1]")
    ProcessLine("[2026.08.30-14.00.00:001] TempMS23 -  OrientationGroups[20:Core][Num:2]")
    ProcessLine("[2026.08.30-14.00.00:002] TempMS23 -  TeamStartId[O: 1] [TId: 204]")
    ProcessLine("[2026.08.30-14.00.00:003] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.30-14.00.00:004] Member-End: [UId:9101, TeamId:6, TeamIdx:0]")
    ProcessLine("[2026.08.30-14.00.00:005] AllocStartSpot Success: UID:9101, TId:6, TIdx:0, TGroupI:204, SpotIdx:0")
    ProcessLine("[2026.08.30-14.00.00:006] AllocStartSpot AdjustLoc: UID:9101, TId:6, TIdx:0, Find Name:PlayerStart32, Rot:")
    ProcessLine("[2026.08.30-14.00.00:007] Pre Allocate StartSpotSuccess MyStart=PlayerStart32, TeamStart=TeamStart1")
    AssertContains(BuildLiveReport(), "P01 T6 | 二员 | 未记录 | 未记录 (self) | 存活", "Pre Allocate binds local self UID")

    ; Member-End 尾部的 TId 是整队成员共享的直接分组证据；即使没有
    ; AllocStartSpot AdjustLoc，也应能显示 TeamStart 别名。
    ResetMatch()
    ProcessLine("[2026.08.30-14.10.00:000] Find StartSpotGroup: [Id:204, name:TeamStart1]")
    ProcessLine("[2026.08.30-14.10.00:001] TempMS23 -  TeamStartId[O: 1] [TId: 204]")
    ProcessLine("[2026.08.30-14.10.00:002] Find StartSpotGroup: [Id:102, name:TeamStart7]")
    ProcessLine("[2026.08.30-14.10.00:003] TempMS23 -  TeamStartId[O: 1] [TId: 102]")
    ProcessLine("[2026.08.30-14.10.00:004] TempMS23-Alloc - Begin[PlayerNum:2, TeamStartNums:2]")
    ProcessLine("[2026.08.30-14.10.00:005] TempMS23 -Alloc: Member-End(Allocated): [UId:9201, TeamId:7, TeamIdx:0] - [TId:204 - 0]")
    ProcessLine("[2026.08.30-14.10.00:006] TempMS23 -Alloc: Member-End(Allocated): [UId:9202, TeamId:4, TeamIdx:0] - [TId:102 - 0]")
    AssertContains(BuildLiveReport(), "出生点映射：2/2", "Member-End TId spawn-group coverage")
    AssertContains(BuildLiveReport(), "P01 T7 | 二员 | 未记录 | 未记录 | 存活", "Member-End TId TeamStart1 alias")
    AssertContains(BuildLiveReport(), "P02 T4 | 宿舍 | 未记录 | 未记录 | 存活", "Member-End TId TeamStart7 alias")

    ; 不同地图会复用相同 Group Id。验证新一轮 InitializeAllocator 会隔离
    ; 目录，且巴克什 W/E 规范名不会误套航天基地别名或错误方向。
    ResetMatch()
    ProcessLine("[2026.09.05-21.04.55:700] InitializeAllocator SpecifiedTemplateId=0, bAllocAllPlayerExits=0")
    ProcessLine("[2026.09.05-21.04.55:701] Find StartSpotGroup: [Id:204, name:TeamStart1]")
    ProcessLine("[2026.09.05-21.04.55:702] TempMS23 - TeamStartId[O: 1] [TId: 204]")
    ProcessLine("[2026.09.05-21.04.55:703] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.09.05-21.04.55:704] Member-End: [UId:9301, TeamId:1, TeamIdx:0] - [TId:204 - 0]")
    AssertContains(BuildLiveReport(), "P01 T1 | 二员 |", "aerospace alias before map switch")
    ProcessLine("[2026.09.05-21.05.55:700] InitializeAllocator SpecifiedTemplateId=0, bAllocAllPlayerExits=0")
    ProcessLine("[2026.09.05-21.05.55:701] Find StartSpotGroup: [Id:204, name:TeamStartE4]")
    ProcessLine("[2026.09.05-21.05.55:702] TempMS23 - TeamStartId[O: 1] [TId: 204]")
    ProcessLine("[2026.09.05-21.05.55:703] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.09.05-21.05.55:704] Member-End: [UId:9302, TeamId:2, TeamIdx:0] - [TId:204 - 0]")
    switchedMapReport := BuildLiveReport()
    AssertContains(switchedMapReport, "P01 T2 | 东侧4 |", "Bakkesh canonical east spawn label")
    if InStr(switchedMapReport, "二员") {
        FileAppend, SELFTEST FAIL: reused group id leaked previous map spawn alias`n, *
        ExitApp, 1
    }

    ; 绝密协议使用 TempMa2 + TeamWeight，不会产生 TempMS23 PlayerNum。
    ; PlayerMembers 必须独立开局，FINAL MAPPING 必须补齐全员出生点。
    ResetMatch()
    ProcessLine("[2026.09.06-22.51.57:660] InitializeAllocator SpecifiedTemplateId=0, bAllocAllPlayerExits=0")
    ProcessLine("[2026.09.06-22.51.57:661] Find StartSpotGroup: [Id:204, name:TeamStart1]")
    ProcessLine("[2026.09.06-22.51.57:662] UStartSpotAllocator_SOL - PlayerMembers(Team): 2, AIPlayerMembers: 0")
    ProcessLine("[2026.09.06-22.51.57:663] UStartSpotAllocator_SOL - PlayerUid: 9351")
    ProcessLine("[2026.09.06-22.51.57:664] UStartSpotAllocator_SOL - PlayerUid: 9352")
    ProcessLine("[2026.09.06-22.51.57:665] TempMa2-Alloc - InputMember: PlayerUin=9351, TeamId=4, TeamType=6, PlayerIdx=0")
    ProcessLine("[2026.09.06-22.51.57:666] TempMa2-Alloc - InputMember: PlayerUin=9352, TeamId=4, TeamType=6, PlayerIdx=1")
    ProcessLine("[2026.09.06-22.51.57:667] TempMa2-Alloc - FINAL MAPPING: PlayerUin=9351 -> TeamStartGroupId=204, SpotIdx=0, TeamId=4")
    ProcessLine("[2026.09.06-22.51.57:668] TempMa2-Alloc - FINAL MAPPING: PlayerUin=9352 -> TeamStartGroupId=204, SpotIdx=1, TeamId=4")
    secretReport := BuildLiveReport()
    AssertContains(secretReport, "对局状态：进行中", "secret TempMa2 starts from PlayerMembers")
    AssertContains(secretReport, "名单完整度：2/2", "secret TempMa2 roster")
    AssertContains(secretReport, "出生点映射：2/2", "secret TempMa2 final mapping")
    AssertContains(secretReport, "P02 T4 | 二员 |", "secret TempMa2 team and spawn")

    ; 工具在 Begin 后才启动时，回扫看不到前置 Find StartSpotGroup；
    ; 验证仅凭 Member-End 的分组 ID 仍能恢复八个已命名出生点。
    ResetMatch()
    ProcessLine("[2026.08.30-14.14.59:999] InitializeAllocator SpecifiedTemplateId=0, bAllocAllPlayerExits=0")
    ProcessLine("[2026.08.30-14.15.00:000] TempMS23-Alloc - Begin[PlayerNum:9, TeamStartNums:9]")
    ProcessLine("[2026.08.30-14.15.00:001] TempMS23 -Alloc: Member-End(Allocated): [UId:9251, TeamId:1, TeamIdx:0] - [TId:204 - 0]")
    ProcessLine("[2026.08.30-14.15.00:002] TempMS23 -Alloc: Member-End(Allocated): [UId:9252, TeamId:2, TeamIdx:0] - [TId:203 - 0]")
    ProcessLine("[2026.08.30-14.15.00:003] TempMS23 -Alloc: Member-End(Allocated): [UId:9253, TeamId:3, TeamIdx:0] - [TId:202 - 0]")
    ProcessLine("[2026.08.30-14.15.00:004] TempMS23 -Alloc: Member-End(Allocated): [UId:9254, TeamId:4, TeamIdx:0] - [TId:201 - 0]")
    ProcessLine("[2026.08.30-14.15.00:005] TempMS23 -Alloc: Member-End(Allocated): [UId:9256, TeamId:6, TeamIdx:0] - [TId:101 - 0]")
    ProcessLine("[2026.08.30-14.15.00:006] TempMS23 -Alloc: Member-End(Allocated): [UId:9257, TeamId:7, TeamIdx:0] - [TId:102 - 0]")
    ProcessLine("[2026.08.30-14.15.00:007] TempMS23 -Alloc: Member-End(Allocated): [UId:9258, TeamId:8, TeamIdx:0] - [TId:103 - 0]")
    ProcessLine("[2026.08.30-14.15.00:008] TempMS23 -Alloc: Member-End(Allocated): [UId:9259, TeamId:9, TeamIdx:0] - [TId:301 - 0]")
    ProcessLine("[2026.08.30-14.15.00:009] TempMS23 -Alloc: Member-End(Allocated): [UId:9255, TeamId:5, TeamIdx:0] - [TId:205 - 0]")
    recoverySpawnTable := BuildPlayerTable()
    for _, alias in ["二员", "牢大", "牢二", "牢三", "西大", "宿舍", "中控", "发射"]
        AssertContains(recoverySpawnTable, alias " |", "recovery spawn alias " alias)
    if InStr(recoverySpawnTable, "TeamStart101") || InStr(recoverySpawnTable, "TeamStart204") {
        FileAppend, SELFTEST FAIL: raw group id leaked into recovered spawn name`n, *
        ExitApp, 1
    }
    AssertContains(recoverySpawnTable, "未命名点位5 |", "unnamed TeamStart5 label")
    previousPos := 0
    for _, alias in ["二员", "牢大", "牢二", "牢三", "西大", "宿舍", "中控", "发射"] {
        currentPos := InStr(recoverySpawnTable, alias " |")
        if (currentPos <= previousPos) {
            FileAppend, SELFTEST FAIL: recovered spawn semantic ordering`n, *
            ExitApp, 1
        }
        previousPos := currentPos
    }

    ; 本地选人界面的 UID + HeroId 同行证据应立即绑定干员，不依赖
    ; 后续 BP_DFMCharacter Actor 是否再次输出非零 Uin。
    ResetMatch()
    ProcessLine("[2026.08.30-14.18.00:000] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.30-14.18.00:001] Member-End: [UId:9291, TeamId:1, TeamIdx:0]")
    ProcessLine("[2026.08.30-14.18.00:002] AssemblyLabel:SetHeroInfo, 88000000027, 9291")
    AssertContains(BuildLiveReport(), "P01 T1 | 未记录 | 蜂医 | 未记录 | 存活", "direct SetHeroInfo UID hero binding")

    ; 玩家昵称由同行 Uin 直接绑定；干员 ID 通过
    ; BP_DFMCharacter Actor -> UID 与同 Actor -> AvatarId 两条证据合并。
    ResetMatch()
    ProcessLine("[2026.08.30-14.20.00:000] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.30-14.20.00:001] Member-End: [UId:9301, TeamId:2, TeamIdx:0]")
    ProcessLine("[2026.08.30-14.20.00:002] DFMFSM_UseItemAllControlAction { BP_DFMCharacter_C_77,uin:9301 } Name=测试玩家")
    ProcessLine("[2026.08.30-14.20.00:003] LogCharacterAppearance: Owner BP_DFMCharacter_C_77 AfterCheckSetAvatar: None -> 88000000027")
    identityReport := BuildLiveReport()
    AssertContains(identityReport, "玩家名绑定：1/1 | 干员ID绑定：1/1", "identity binding coverage")
    AssertContains(identityReport, "P01 T2 | 未记录 | 蜂医 | 测试玩家 | 存活", "player name and mapped hero label")
    if InStr(identityReport, "玩家列表（按出生点名排序）") {
        FileAppend, SELFTEST FAIL: duplicate player table leaked into main window report`n, *
        ExitApp, 1
    }
    if (HeroName("88000000042") != "") {
        FileAppend, SELFTEST FAIL: catalog-only hero must remain unnamed`n, *
        ExitApp, 1
    }

    ; 未收录的干员只显示“未知”，不向用户暴露原始数字 ID。
    ResetMatch()
    ProcessLine("[2026.08.30-14.20.50:000] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.30-14.20.50:001] Member-End: [UId:9300, TeamId:2, TeamIdx:0]")
    ProcessLine("[2026.08.30-14.20.50:002] AssemblyLabel:SetHeroInfo, 88000000042, 9300")
    AssertContains(BuildLiveReport(), "P01 T2 | 未记录 | 未知 | 未记录 | 存活", "unknown hero display")

    ; 武器/角色组件日志也会把 Client UID 和 Character Actor 放在同一行。
    ; 有些远端玩家只出现这一种 Actor -> UID 证据，必须纳入身份合并。
    ResetMatch()
    ProcessLine("[2026.08.30-14.21.00:000] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.30-14.21.00:001] Member-End: [UId:9302, TeamId:2, TeamIdx:0]")
    ProcessLine("[2026.08.30-14.21.00:002] LogCharacterAppearance: Owner BP_DFMCharacter_C_88 AfterCheckSetAvatar: None -> 88000000041")
    ProcessLine("[2026.08.30-14.21.00:003] [Client|9302|123|3P][UWeaponDataComponent][BP_DFMCharacter_C_88]: Test")
    AssertContains(BuildLiveReport(), "P01 T2 | 未记录 | 比特 | 未记录 | 存活", "Client UID plus actor identity binding")

    ; 用户确认的姓名覆盖只补齐缺失 HeroId，不覆盖已有直接 HeroId。
    ResetMatch()
    ProcessLine("[2026.08.30-14.22.00:000] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.30-14.22.00:001] Member-End: [UId:9303, TeamId:4, TeamIdx:0]")
    ProcessLine("[2026.08.30-14.22.00:002] DFMFSM_UseItemAllControlAction { BP_DFMCharacter_C_89,uin:9303 } Name=Reze2nsj")
    AssertContains(BuildLiveReport(), "P01 T4 | 未记录 | 红狼 | Reze2nsj | 存活", "manual player-name hero override")

    ResetMatch()
    ProcessLine("[2026.08.30-14.23.00:000] TempMS23-Alloc - Begin[PlayerNum:2, TeamStartNums:1]")
    ProcessLine("[2026.08.30-14.23.00:001] Member-End: [UId:9304, TeamId:5, TeamIdx:0]")
    ProcessLine("[2026.08.30-14.23.00:002] Member-End: [UId:9305, TeamId:6, TeamIdx:0]")
    ProcessLine("[2026.08.30-14.23.00:003] DFMFSM_UseItemAllControlAction { BP_DFMCharacter_C_90,uin:9304 } Name=Flacidusax")
    ProcessLine("[2026.08.30-14.23.00:004] DFMFSM_UseItemAllControlAction { BP_DFMCharacter_C_91,uin:9305 } Name=苏沉鋭")
    manualMapReport := BuildLiveReport()
    AssertContains(manualMapReport, "P01 T5 | 未记录 | 威龙 | Flacidusax | 存活", "Flacidusax skin hero override")
    AssertContains(manualMapReport, "P02 T6 | 未记录 | 红狼 | 苏沉鋭 | 存活", "苏沉鋭 skin hero override")

    ; 汇总玩家表按出生点语义顺序排列，并组合干员、用户名、状态及 self 标记。
    ResetMatch()
    ProcessLine("[2026.08.30-14.30.00:000] Find StartSpotGroup: [Id:204, name:TeamStart1]")
    ProcessLine("[2026.08.30-14.30.00:001] TempMS23 -  TeamStartId[O: 1] [TId: 204]")
    ProcessLine("[2026.08.30-14.30.00:002] Find StartSpotGroup: [Id:103, name:TeamStart8]")
    ProcessLine("[2026.08.30-14.30.00:003] TempMS23 -  TeamStartId[O: 2] [TId: 103]")
    ProcessLine("[2026.08.30-14.30.00:004] TempMS23-Alloc - Begin[PlayerNum:2, TeamStartNums:2]")
    ProcessLine("[2026.08.30-14.30.00:005] TempMS23 -Alloc: Member-End(Allocated): [UId:9401, TeamId:7, TeamIdx:0] - [TId:103 - 0]")
    ProcessLine("[2026.08.30-14.30.00:006] TempMS23 -Alloc: Member-End(Allocated): [UId:9402, TeamId:6, TeamIdx:0] - [TId:204 - 0]")
    ProcessLine("[2026.08.30-14.30.00:007] DFMFSM_UseItemAllControlAction { BP_DFMCharacter_C_78,uin:9402 } Name=本地测试")
    ProcessLine("[2026.08.30-14.30.00:008] LogCharacterAppearance: Owner BP_DFMCharacter_C_78 AfterCheckSetAvatar: None -> 88000000027")
    ProcessLine("[2026.08.30-14.30.00:009] DFMFSM_UseItemAllControlAction { BP_DFMCharacter_C_79,uin:9401 } Name=远端测试")
    ProcessLine("[2026.08.30-14.30.00:010] LogCharacterAppearance: Owner BP_DFMCharacter_C_79 AfterCheckSetAvatar: None -> 88000000030")
    SetSelfUid("9402")
    ProcessLine("[2026.08.30-14.30.01:000] CourseworkEvent Type=BOX UID:9401")
    playerTable := BuildPlayerTable()
    AssertContains(playerTable, "出生点名 | 干员名 | 用户名 | 状态", "player table header")
    AssertContains(playerTable, "二员 | 蜂医 | 本地测试 (self) | 存活", "player table local row")
    AssertContains(playerTable, "中控 | 红狼 | 远端测试 | 成盒", "player table remote box row")
    if (OverlayPlayerRow("9402") != "二员 · 蜂医") {
        FileAppend, SELFTEST FAIL: compact overlay player row`n, *
        ExitApp, 1
    }
    if (InStr(playerTable, "二员 |") >= InStr(playerTable, "中控 |")) {
        FileAppend, SELFTEST FAIL: player table spawn ordering`n, *
        ExitApp, 1
    }
    FileAppend, SELFTEST PASS`n, *
}

RunBufferStabilityTest() {
    global g_Pending, g_PendingLen
    g_PendingLen := 0
    VarSetCapacity(g_Pending, 0)
    Loop, 1000 {
        VarSetCapacity(part, 4, 0)
        NumPut(65, part, 0, "UChar")
        QueueDecodedBytes(part, 1)
        if (g_PendingLen != 1)
            throw Exception("partial buffer length mismatch")
        NumPut(10, part, 0, "UChar")
        NumPut(66, part, 1, "UChar")
        QueueDecodedBytes(part, 2)
        if (g_PendingLen != 1 || NumGet(g_Pending, 0, "UChar") != 66)
            throw Exception("partial buffer bytes lost")
        NumPut(10, part, 0, "UChar")
        QueueDecodedBytes(part, 1)
        if (g_PendingLen != 0)
            throw Exception("completed buffer not consumed")
    }
}

RunIntegrationTest() {
    global g_LastReport
    ResetMatch()
    OpenLogAtTail()
    deadline := A_TickCount + 25000
    while (A_TickCount < deadline && g_LastReport = "") {
        PollLog()
        Sleep, 100
    }
    CloseLog()
    if (g_LastReport = "") {
        FileAppend, INTEGRATION FAIL: no completed report`n, *
        ExitApp, 1
    }
    AssertContains(g_LastReport, "候选场内剩余（仅赛后）：3", "integration candidate population")
    AssertNotContains(g_LastReport, "坐标", "integration report has no coordinate module")
    AssertContains(g_LastReport, "确认成功撤离：1", "integration escape")
    FileAppend, INTEGRATION PASS`n, *
}

RunRecoveryTest() {
    global g_LastReport, g_Match, g_PreserveCompletedRecovery
    g_PreserveCompletedRecovery := true
    ResetMatch()
    if !OpenLogRecovering() {
        FileAppend, RECOVERY FAIL: startup recovery could not read the log`n, *
        ExitApp, 1
    }
    ; 启动恢复既可能恢复进行中的一局，也可能恢复最近一局已结算报告；
    ; 两种结果都属于合法状态，测试只校验报告结构与后续可轮询性。
    if !g_Match.Active {
        if (g_LastReport = "") {
            FileAppend, RECOVERY FAIL: no active or completed match recovered`n, *
            ExitApp, 1
        }
        g_PreserveCompletedRecovery := false
        AssertContains(g_LastReport, "DeltaForce.log 已完成对局赛后审计", "recovered completed match")
        FileAppend, RECOVERY PASS completed-report`n, *
        return
    }
    g_PreserveCompletedRecovery := false
    AssertContains(BuildLiveReport(), "对局状态：进行中", "recovered active match")
    deadline := A_TickCount + 25000
    while (A_TickCount < deadline && g_LastReport = "") {
        PollLog()
        Sleep, 100
    }
    CloseLog()
    if (g_LastReport = "") {
        FileAppend, RECOVERY FAIL: recovered match did not reach settlement`n, *
        ExitApp, 1
    }
    AssertContains(g_LastReport, "DeltaForce.log 已完成对局赛后审计", "recovery final report")
    FileAppend, RECOVERY PASS active-match-finalized`n, *
}

RunNoActiveTest() {
    global g_LastReport, g_Match
    ResetMatch()
    if !OpenLogRecovering() {
        FileAppend, NO-ACTIVE FAIL: startup recovery could not read the log`n, *
        ExitApp, 1
    }
    if g_Match.Active {
        FileAppend, NO-ACTIVE FAIL: completed log was treated as an active match`n, *
        ExitApp, 1
    }
    if (g_LastReport != "") {
        FileAppend, NO-ACTIVE FAIL: old completed report was not cleared`n, *
        ExitApp, 1
    }
    FileAppend, NO-ACTIVE PASS`n, *
}

RunActiveNowTest() {
    global g_Match
    resultPath := A_Temp "\DeltaForcePostmatchAudit-active-now.txt"
    FileDelete, %resultPath%
    ResetMatch()
    if !OpenLogRecovering() {
        FileAppend, ACTIVE-NOW FAIL: startup recovery could not read the log`n, %resultPath%
        ExitApp, 1
    }
    if !g_Match.Active {
        FileAppend, ACTIVE-NOW FAIL: latest unclosed match was not recovered`n, %resultPath%
        ExitApp, 1
    }
    if (g_Match.InitialCount <= 0) {
        FileAppend, ACTIVE-NOW FAIL: recovered match has no PlayerNum`n, %resultPath%
        ExitApp, 1
    }
    candidate := g_Match.InitialCount - ObjectCount(g_Match.Corpses) - ObjectCount(g_Match.Boxes) - ObjectCount(g_Match.Escaped) - (g_Match.LocalCorpseUnknown ? 1 : 0)
    result := "ACTIVE-NOW PASS roster=" g_Match.RosterOrder.Length() "/" g_Match.InitialCount " corpses=" ObjectCount(g_Match.Corpses) " corpseRescues=" g_Match.RescueEvents.Length() " downedRescues=" g_Match.DownedRescueEvents.Length() " boxes=" ObjectCount(g_Match.Boxes) " escaped=" ObjectCount(g_Match.Escaped) " candidate=" candidate "`n"
    FileAppend, %result%, *
    FileAppend, %result%, %resultPath%
}

RunReplayCurrentTest() {
    global g_Match, g_LastReport, g_PreserveCompletedRecovery
    resultPath := A_Temp "\DeltaForcePostmatchAudit-replay-current.txt"
    FileDelete, %resultPath%
    g_PreserveCompletedRecovery := true
    ResetMatch()
    if !OpenLogRecovering() {
        FileAppend, REPLAY-CURRENT FAIL: startup recovery could not read the log`n, %resultPath%
        ExitApp, 1
    }
    g_PreserveCompletedRecovery := false
    report := g_Match.Active ? BuildLiveReport() : g_LastReport
    if (report = "") {
        FileAppend, REPLAY-CURRENT FAIL: no active or completed match was reconstructed`n, %resultPath%
        ExitApp, 1
    }
    FileAppend, %report%, %resultPath%
}

RunSoftRescanTest() {
    global g_Match, g_LastReport, g_ReaderState
    resultPath := A_Temp "\DeltaForcePostmatchAudit-soft-rescan.txt"
    FileDelete, %resultPath%
    ; 先制造一份不完整的错误状态，再调用与 F9 完全相同的软重启入口。
    ResetMatch()
    ProcessLine("[2026.08.30-00.00.00:000] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.30-00.00.00:001] Member-End: [UId:9999, TeamId:9, TeamIdx:0]")
    if !SoftRescanLatestMatch() {
        FileAppend, SOFT-RESCAN FAIL: recovery entry returned false`n, *
        FileAppend, SOFT-RESCAN FAIL: recovery entry returned false`n, %resultPath%
        ExitApp, 1
    }
    report := g_Match.Active ? BuildLiveReport() : g_LastReport
    if (report = "" || g_Match.Roster.HasKey(UidKey("9999"))) {
        FileAppend, SOFT-RESCAN FAIL: stale pre-rescan state survived`n, *
        FileAppend, SOFT-RESCAN FAIL: stale pre-rescan state survived`n, %resultPath%
        ExitApp, 1
    }
    if !InStr(g_ReaderState, "F9 软重启完成") {
        FileAppend, % "SOFT-RESCAN FAIL: unexpected status: " g_ReaderState "`n", *
        FileAppend, % "SOFT-RESCAN FAIL: unexpected status: " g_ReaderState "`n", %resultPath%
        ExitApp, 1
    }
    stateName := g_Match.Active ? "active" : "completed"
    result := "SOFT-RESCAN PASS state=" stateName " roster=" g_Match.RosterOrder.Length() "/" g_Match.InitialCount "`n"
    FileAppend, %result%, *
    FileAppend, %result%, %resultPath%
}

RunLatestCompletedTest() {
    global g_Match, g_LastReport, g_PreserveCompletedRecovery
    g_PreserveCompletedRecovery := true
    ResetMatch()
    if !OpenLogRecovering() {
        FileAppend, LATEST-COMPLETED FAIL: could not read the log`n, *
        ExitApp, 1
    }
    g_PreserveCompletedRecovery := false
    if (g_Match.Active || g_LastReport = "") {
        FileAppend, LATEST-COMPLETED FAIL: latest match was not finalized`n, *
        ExitApp, 1
    }
    ; 这里验证结构和互斥集合，不绑定某一局的固定人数/撤离方式，
    ; 避免日志更新后测试把正常结果误判为程序错误。
    AssertContains(g_LastReport, "已建立名单 UID：", "latest roster count")
    AssertContains(g_LastReport, "存活列表（", "latest alive section")
    AssertContains(g_LastReport, "死亡列表（", "latest death section")
    AssertContains(g_LastReport, "救援列表（", "latest rescue section")
    AssertContains(g_LastReport, "盒子列表（", "latest box section")
    AssertContains(g_LastReport, "撤离玩家列表（", "latest escape section")
    AssertContains(g_LastReport, "出生点名", "latest spawn section")
    for key, escaped in g_Match.Escaped {
        if g_Match.Boxes.HasKey(key) {
            FileAppend, LATEST-COMPLETED FAIL: player exists in both box and escape sets`n, *
            ExitApp, 1
        }
    }
    candidate := g_Match.InitialCount - ObjectCount(g_Match.Corpses) - ObjectCount(g_Match.Boxes) - ObjectCount(g_Match.Escaped) - (g_Match.LocalCorpseUnknown ? 1 : 0)
    result := "LATEST-COMPLETED PASS roster=" g_Match.RosterOrder.Length() "/" g_Match.InitialCount " rescued=" ObjectCount(g_Match.Rescued) " boxes=" ObjectCount(g_Match.Boxes) " escaped=" ObjectCount(g_Match.Escaped) " candidate=" candidate " end=" TimeLabel(g_Match.EndTime) "`n"
    FileAppend, %result%, *
}

RunOverlayTest() {
    global g_Match, g_OverlayReady, g_OverlayVisible, g_OverlayHwnd
    BuildOverlay()
    ResetMatch()
    if !g_OverlayReady {
        FileAppend, OVERLAY FAIL: overlay was not initialized`n, *
        ExitApp, 1
    }
    g_Match.Active := true
    g_Match.InitialCount := 16
    UpdateOverlay()
    GuiControlGet, overlayValue, Overlay:, OverlayText
    if (overlayValue != "剩余人数：16") {
        FileAppend, % "OVERLAY FAIL: unexpected text " overlayValue "`n", *
        ExitApp, 1
    }
    ToggleOverlay()
    if !g_OverlayVisible {
        FileAppend, OVERLAY FAIL: F9 detail state failed`n, *
        ExitApp, 1
    }
    GuiControlGet, overlayValue, Overlay:, OverlayText
    if !InStr(overlayValue, "存活数：0  死亡数：0  成盒数：0  撤离数：0") || !InStr(overlayValue, "存活玩家（0）") || !InStr(overlayValue, "暂无") || InStr(overlayValue, "用户名") || InStr(overlayValue, "状态") {
        FileAppend, % "OVERLAY FAIL: expanded details=" overlayValue "`n", *
        ExitApp, 1
    }
    ToggleOverlay()
    if g_OverlayVisible {
        FileAppend, OVERLAY FAIL: F9 collapse state failed`n, *
        ExitApp, 1
    }
    GuiControlGet, overlayValue, Overlay:, OverlayText
    if (overlayValue != "剩余人数：16" || !DllCall("IsWindowVisible", "Ptr", g_OverlayHwnd)) {
        FileAppend, % "OVERLAY FAIL: remaining count was not persistent " overlayValue "`n", *
        ExitApp, 1
    }

    ; 覆盖一局 17 名存活玩家的最大常见场景：20 行文本必须完整生成，
    ; 展开控件高度按中文实际行高留有余量，防止最后一行被裁掉。
    g_Match.InitialCount := 17
    Loop, 17 {
        uid := 9600 + A_Index
        AddRosterUid(uid)
    }
    ToggleOverlay()
    UpdateOverlay()
    GuiControlGet, overlayValue, Overlay:, OverlayText
    StrReplace(overlayValue, "`n", "", overlayLineBreaks)
    GetOverlayMetrics(windowW, windowH, textW, textH, textY, fontSize, edgeMargin)
    SysGet, testMonitorArea, Monitor, 1
    testScale := OverlayScaleForResolution(testMonitorAreaRight - testMonitorAreaLeft, testMonitorAreaBottom - testMonitorAreaTop)
    if (overlayLineBreaks != 19 || textH < Round(20 * 24 * testScale)) {
        FileAppend, % "OVERLAY FAIL: 17-player list clipped lines=" overlayLineBreaks " textH=" textH "`n", *
        ExitApp, 1
    }
    if (Abs(OverlayScaleForResolution(1920, 1080) - 1.0) > 0.001
        || Abs(OverlayScaleForResolution(2560, 1440) - 1.333333) > 0.001
        || Abs(OverlayScaleForResolution(3840, 2160) - 2.0) > 0.001) {
        FileAppend, OVERLAY FAIL: resolution scaling failed`n, *
        ExitApp, 1
    }
    FileAppend, OVERLAY PASS persistent=剩余人数 details=F9 rows=17`n, *
}

RunGuiRoutingTest() {
    BuildGui()
    BuildOverlay()
    ResetMatch()
    ProcessLine("[2026.08.30-11.00.00:000] TempMS23-Alloc - Begin[PlayerNum:1, TeamStartNums:1]")
    ProcessLine("[2026.08.30-11.00.00:010] Member-End: [UId:9001, TeamId:9, TeamIdx:0]")
    GuiControlGet, mainMatchText, 1:, MatchText
    GuiControlGet, mainReportText, 1:, ReportEdit
    GuiControlGet, overlayValue, Overlay:, OverlayText
    if !InStr(mainMatchText, "实时中") {
        FileAppend, % "GUI-ROUTING FAIL: main status=" mainMatchText "`n", *
        ExitApp, 1
    }
    if !InStr(mainReportText, "名单完整度：1/1") {
        FileAppend, GUI-ROUTING FAIL: main report was not updated`n, *
        ExitApp, 1
    }
    if (overlayValue != "剩余人数：1") {
        FileAppend, % "GUI-ROUTING FAIL: overlay text=" overlayValue "`n", *
        ExitApp, 1
    }
    FileAppend, GUI-ROUTING PASS main=实时中 overlay=剩余人数：1`n, *
}

AssertContains(haystack, needle, label) {
    if !InStr(haystack, needle) {
        FileAppend, % "SELFTEST FAIL: " label "`n", *
        ExitApp, 1
    }
}

AssertNotContains(haystack, needle, label) {
    if InStr(haystack, needle) {
        FileAppend, % "SELFTEST FAIL: " label "`n", *
        ExitApp, 1
    }
}

AssertOrder(haystack, firstNeedle, secondNeedle, label) {
    firstPos := InStr(haystack, firstNeedle)
    secondPos := InStr(haystack, secondNeedle)
    if (firstPos = 0 || secondPos = 0 || firstPos >= secondPos) {
        FileAppend, % "SELFTEST FAIL: " label "`n", *
        ExitApp, 1
    }
}
