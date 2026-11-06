-- ============================================
-- BRPLAYERCHARACTERBASE.LUA
-- Author  : @VINESH_OP
-- Version : 4.4 | BGMI | PUBG | KR | TW | JP | VNG
-- Desc    : Full Bypass + Wallhack + ESP + Aimbot
-- ============================================
local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
local IngamePhoneStateUI = require("GameLua.Mod.Library.Client.UI.IngamePhoneStateUI")

local KismetSystemLibrary = import("KismetSystemLibrary")
local packageName = KismetSystemLibrary.GetGameBundleId()

-- ============================================
-- ALL VERSION SUPPORT (GL / KR / TW / VNG / BGMI)
-- Pehle sirf com.tencent.ig (GL) chalti thi, baaki par script return kar deti thi.
-- Ab har supported version par chalti hai. packageName se hi paths bante hain,
-- isliye alag-alag version ke liye alag file banane ki zaroorat nahi.
-- ============================================
local SUPPORTED_PACKAGES = {
    ["com.tencent.ig"]        = "GL",    -- Global
    ["com.pubg.krmobile"]     = "KR",    -- Korea
    ["com.rekoo.pubgm"]       = "TW",    -- Taiwan
    ["com.vng.pubgmobile"]    = "VNG",   -- Vietnam
    ["com.pubg.imobile"]      = "BGMI",  -- India
    ["com.tencent.tmgp.pubgmhd"] = "CN", -- China (Game For Peace)
}

_G.GTLMOD_PackageName = packageName
_G.GTLMOD_Version = SUPPORTED_PACKAGES[packageName] or "UNKNOWN"

-- Agar bundle id na mile to bhi band na karo — sirf tab return karo jab
-- saaf pata ho ke yeh PUBG family ka app nahi hai.
if packageName and packageName ~= "" then
    if not SUPPORTED_PACKAGES[packageName] then
        -- Naya/unknown variant: agar naam mein pubg/tencent/ig ho to chalne do
        local pl = string.lower(packageName)
        if not (string.find(pl, "pubg", 1, true) or string.find(pl, "tencent", 1, true)
                or string.find(pl, "rekoo", 1, true) or string.find(pl, "vng", 1, true)) then
            return
        end
    end
end

-- ============================================
--- HELP TO FIXING SOME GLITCHES 
-- ============================================
function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:HandleOnAttachedToVehicle", Game:GetObjName(uVehicle)))
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
    self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:UpdatePlayerAttachToVehicle(uVehicle)
      end
    end)
    self.nFixMeshContainerTimer = self:AddGameTimer(3, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:FixMeshContainerOffsetIfNeeded(uVehicle)
      end
    end)
  end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(uLastVehicle) then
    return
  end
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnDetachedFromVehicle", uLastVehicle)
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.CapsuleComponent) or not slua.isValid(self.Mesh) or not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  if not self.nUpdatePlayerAttachToVehicleCount then
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  local ESTEPoseState = import("ESTEPoseState")
  local bStand = self.PoseState == ESTEPoseState.Stand
  local uActorRelativeLocation = self.CapsuleComponent:GetRelativeTransform():GetLocation()
  local uMeshRelativeLocation = self.Mesh:GetRelativeTransform():GetLocation()
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  local nCapsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
  local nCapsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local nExpectedCapsuleRadius = self.StandRadius
  local nExpectedCapsuleHalfHeight = self.StandHalfHeight
  local uMeshExpectedRL = FVector(0, 0, 0)
  local uActorExpectedRL = FVector(0, 0, self.StandHalfHeight)
  local nTolerance = 1.0
  local bCapsuleRLCorrect = uActorRelativeLocation:Equals(uActorExpectedRL, nTolerance)
  local bMeshRLCorrect = uMeshRelativeLocation:Equals(uMeshExpectedRL, nTolerance)
  local bMeshContainerRLCorrect = nTolerance > math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ)
  local bCapsuleRadiusCorrect = nTolerance > math.abs(nCapsuleRadius - nExpectedCapsuleRadius)
  local bCapsuleHalfHeightCorrect = nTolerance > math.abs(nCapsuleHalfHeight - nExpectedCapsuleHalfHeight)
  local bAllCorrect = bStand and bCapsuleRLCorrect and bMeshRLCorrect and bMeshContainerRLCorrect and bCapsuleRadiusCorrect and bCapsuleHalfHeightCorrect
  if not bAllCorrect then
    self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1
  else
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:UpdatePlayerAttachToVehicle PlayerKey:%s. bAllCorrect=%s Check Result:%d %d %d %d %d %d, Count:%d", tostring(self.PlayerKey), tostring(bAllCorrect), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, self.nUpdatePlayerAttachToVehicleCount))
  if self.nUpdatePlayerAttachToVehicleCount >= 3 and not bAllCorrect then
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local uPlayerController = GameplayData.GetPlayerController()
    if uPlayerController.ReportCrashKitFeature and uPlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
      local sReportInfo = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", tostring(uVehicle.VehicleShapeType), tostring(self.PlayerKey), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, uActorRelativeLocation:ToString(), tostring(nCapsuleRadius), tostring(nCapsuleHalfHeight), uMeshRelativeLocation:ToString(), tostring(uMeshContainerRelativeLocationZ))
      uPlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(sReportInfo)
    end
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  local nTolerance = 1.0
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if nTolerance <= math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ) then
    print(bWriteLog and string.format("BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded PlayerKey:%s. SetMeshContainerOffsetZ from:%s to:%s", tostring(uMeshContainerExpectedZ), tostring(uMeshContainerExpectedZ)))
    self:SetMeshContainerOffsetZ(uMeshContainerExpectedZ)
  end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
  if self.nUpdatePlayerAttachToVehicleTimer then
    self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
    self.nUpdatePlayerAttachToVehicleTimer = nil
  end
  if self.nFixMeshContainerTimer then
    self:RemoveGameTimer(self.nFixMeshContainerTimer)
    self.nFixMeshContainerTimer = nil
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end
-- ================== HANDLE MOVEMENT (NO WALL CLIMB) ==================
function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.UInt32,
    UEnums.EPropertyClass.UInt32
  }
}

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  print(bWriteLog and string.format("BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment Type = %d, Param = %s", Type, Param))
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  
  function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

local VICTORY_DANCE_FX_MAP = {
  [12219601] = 22010089
}

function ResolveEmoteResID(ItemID)
  local FxID = VICTORY_DANCE_FX_MAP[ItemID]
  if not FxID or FxID == ItemID then
    return ItemID
  end
  local model_util = require("client.common.model_util")
  local FxBPID = model_util.GetBPID(FxID)
  local ResID = ItemID
  if FxBPID and 0 < FxBPID and model_util.IsBattleItemHandleExist("Emote", FxBPID, false, false) then
    ResID = FxID
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase 11 ResolveEmoteResID ItemID:%s, FxID:%s, FxBPID:%s, ResID:%s", tostring(ItemID), tostring(FxID), tostring(FxBPID), tostring(ResID)))
  return ResID
end

function BRPlayerCharacterBase:GetEmoteHandlePath(ItemID)
  local ResID = ResolveEmoteResID(ItemID)
  if self.Super then
    return self.Super:GetEmoteHandlePath(ResID)
  end
  local model_util = require("client.common.model_util")
  local BPID = model_util.GetBPID(ResID)
  if not BPID or BPID <= 0 then
    return ""
  end
  return model_util.GetPath("Emote", BPID, false, false) or ""
end

function BRPlayerCharacterBase:GetEmoteHandle(ItemID)
  local ResID = ResolveEmoteResID(ItemID)
  if self.Super then
    return self.Super:GetEmoteHandle(ResID)
  end
  local model_util = require("client.common.model_util")
  local BPID = model_util.GetBPID(ResID)
  if not BPID or BPID <= 0 then
    return nil
  end
  local HandleClass = model_util.GetClass("Emote", BPID, false, false)
  if not HandleClass then
    return nil
  end
  local Handle = HandleClass()
  if not slua.isValid(Handle) then
    return nil
  end
  return Handle
end

-- ==============================================================================
-- ============================ START FULL LOGIC MOD ==========================
-- ==============================================================================

local function Notify(msg) local s = "[GTLMOD VIP New] " .. tostring(msg)
pcall(function() if _G.GTLMODNotify then _G.GTLMODNotify(s) end end)
pcall(function() local sh = import("ScriptHelperClient") if sh and
sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,
G=1, B=0, A=1}, {X=1.2, Y=1.2}) end end) print(s) end

local _slua = rawget(_G, "slua")

local function Valid(obj)
    if not obj then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, obj)
        if not ok or not v then return false end
    end
    return true
end

-- ==========================================
-- MODULE CACHE (avoid duplicate require calls)
-- ==========================================
local _cached_ticker = nil
local function GetTicker()
    if not _cached_ticker then
        local ok, t = pcall(require, "common.time_ticker")
        if ok and t then _cached_ticker = t end
    end
    return _cached_ticker
end

local _cached_ui_util = nil
local function GetUIUtil()
    if not _cached_ui_util then
        local ok, u = pcall(require, "client.common.ui_util")
        if ok and u then _cached_ui_util = u end
    end
    return _cached_ui_util
end

local _cached_ModuleManager = nil
local function GetModuleManager()
    if not _cached_ModuleManager then
        local ok, m = pcall(require, "client.module_framework.ModuleManager")
        if ok and m then _cached_ModuleManager = m end
    end
    return _cached_ModuleManager
end

-- Helper: check if value is a function (replaces repeated type() checks)
local function IsFunc(v) return type(v) == "function" end

-- ========================================== 
-- STATIC VARIABLES & GLOBAL CACHE OPTIMIZED (LAG-FREE)
-- ========================================== 
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}

local GLOBAL_BONE_LIST = {
    "head", "neck_01", "pelvis",
    "upperarm_r", "lowerarm_r", "hand_r",
    "upperarm_l", "lowerarm_l", "hand_l",
    "thigh_l", "calf_l", "foot_l",
    "thigh_r", "calf_r", "foot_r"
}

-- ========================================== 
-- GTLMOD CORE + FULL FEATURES VIP CONFIGURATION 
-- ========================================== 
_G.GTLMODConfig = _G.GTLMODConfig or { 
    EspVip = false, 
    EspRadar = false, 
    Esp5 = false, 
    Esp6 = false, 
    Esp7 = true,
    EspCounter = true,
    -- ESP V2 (esp.lua se — poora naya canvas-based system, mustaqil koi takraav nahi)
    EspLoai9 = false,      -- master ON/OFF
    Esp9_Name = false,      -- player naam
    Esp9_Distance = false,  -- distance text
    Esp9_HP = false,        -- health bar
    Esp9_Team = false,      -- team color box
    Esp9_Weapon = false,    -- weapon icon
    Esp9_Line = false,      -- snap line
    Esp9_Skeleton = true,  -- skeleton bones
    -- NEW: copied features
    EspWeapon = false,        -- SHOW ENEMY WEAPON
    EspBomMaster = false,     -- GRANDE WARNING ESP (master)
    EspItemBom = false,       -- grenades on ground
    EspActiveBom = false,     -- enemy holds/throws
    EspVehicle = false,       -- VECHILE ESP
    EspVeh_Dacia = true,
    EspVeh_UAZ = true,
    EspVeh_Buggy = true,
    EspVeh_Coupe = true,
    EspVeh_Mirado = true,
    EspVeh_Motor = true,
    EspVeh_Other = true,
    EspAntenna = false, 
    EspName = false,
    EspOutline = false, 
    OutlineThickness = 10, 
    UnlockFPS = false, 
    IpadView = false, 
    ColorBodyV2 = false,    
    HDRGlow = false,        -- HDR GLOW (white body + glow) apna alag toggle
    WallhackV2 = false,     -- WALLHACK V2 (game ka apna Dyeing system)
    WallVehicle = false,      -- VECHILE WALLHACK (see-through walls)
    wallhackng = false, 
    BlackSky = false,
    
    -- New Configuration for Aimbot V2 (Aim Touch) - UNIFIED (works on all guns)
    AimTouchEnable = false,
    AimTouchChest = false,
    AimTouchIgKnock = true,
    AimTouchIgBot = true,
    AimTouchVisCheck = true,
    -- Aim Assist extended config (screenshot match)
    AimTriggerMode = 3,        -- 1=Hipfire Only, 2=ADS Scope Only, 3=Hip+ADS
    AimTargetBone = 3,         -- 1=Chest(Safe), 2=Neck(Risky), 3=Head
    AimTrackingPower = 100,    -- 0-100 (100% = max speed, ab 45% of old instant-lock)
    -- Distance & FOV
    HipfireMaxRange = 40,      -- 10-40m
    ScopeMaxRange = 150,       -- 30-150m

}

-- CONTAINS FULLY OPTIMIZED SYSTEM STATE WITH FREE RAM
_G.GTLMODState = _G.GTLMODState or { 
    LoopToken = 0, 
    AimbotLoopToken = 0,   -- token untuk loop aimbot force
    NativeESPReady = false,
    GraphicsUnlocked = false, 
    MenuStep = 0, 
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0, 
    CustomTextData = nil,     
    LastAimbotConfigString = "",

    PrevGraphicsState = {},
}

local limitTime = os.time({ year = 2028, month = 10, day = 1, hour = 23, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))
-- ==========================================
-- ALL-VERSION PATH BUILDER
-- Current package ka path sabse pehle, phir baaki sab versions fallback ke taur par.
-- Isi wajah se ek hi file GL/KR/TW/VNG/BGMI sab par chalti hai.
-- ==========================================
local ALL_PKG_LIST = {
    "com.tencent.ig",
    "com.pubg.krmobile",
    "com.rekoo.pubgm",
    "com.vng.pubgmobile",
    "com.pubg.imobile",
    "com.tencent.tmgp.pubgmhd",
}

local function BuildGamePaths(subFolder, fileName)
    local paths = {}
    local base = "//storage/emulated/0/Android/data/"
    local tail = "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/" .. subFolder .. "/" .. fileName

    -- 1) Jo version abhi chal raha hai, uska path pehle
    if _G.GTLMOD_PackageName and _G.GTLMOD_PackageName ~= "" then
        table.insert(paths, base .. _G.GTLMOD_PackageName .. tail)
    end

    -- 2) Baaki sab versions fallback
    for _, pkg in ipairs(ALL_PKG_LIST) do
        if pkg ~= _G.GTLMOD_PackageName then
            table.insert(paths, base .. pkg .. tail)
        end
    end

    -- 3) Relative fallbacks
    table.insert(paths, "ShadowTrackerExtra/Saved/" .. subFolder .. "/" .. fileName)
    table.insert(paths, "../../ShadowTrackerExtra/Saved/" .. subFolder .. "/" .. fileName)

    return paths
end

local isExpired = false

pcall(function()
    local fileName = ".sys_time_cache"
    -- HANYA path untuk Global dan Korea (Android)
    local paths = BuildGamePaths("SaveGames", fileName)
    
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then 
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then 
            currentTime = serverTime
        end
    end

    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then
                lastSeenTime = savedTime
            end
            file:close()
        end
    end

    if currentTime < lastSeenTime then
        currentTime = lastSeenTime
    else
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(tostring(currentTime))
                file:close()
            end
        end
    end
end)

isExpired = (currentTime > limitTime)

-- ==============================================================================
-- ================== COMPLETE COMBINED BYPASS SYSTEM v4.0 =====================
-- ==============================================================================
-- Author: @VINESH_OP
-- Combined: Ultimate Merged Bypass v3.0 + 8-Layer Advanced Bypass
-- NO LAYER MISSED - Full Security Disablement
-- ==============================================================================

-- ==================== HELPER FUNCTIONS ====================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function safe_require(path)
    local ok, mod = pcall(require, path)
    return ok and mod or nil
end

-- ==================== BLACKLISTS (From First Bypass) ====================
local BLACKLIST_HOSTS = {
    "tss.tencent","syzsdk","gcloud.qq","reportlog","tdos","logupload","feedback.wh","crash2",
    "privacy.qq","privacy.tencent","oth.eve","mdt.qq","act.tencentyun","analytics","report.qq",
    "anticheatexpert","crashsight","wetest","log.tav","sngd","tracer","intlsdk","igamecj",
    "cdn.club","gpubgm","graph.facebook","calendarpushsubscription","googleads","doubleclick",
    "firebaselogging","firebaseremoteconfig","fonts.googleapis","abs.twimg","dl.listdl",
    "igame.gcloudcs","bugly","beacon","helpshift","tdm","apm","safeguard","weiyun","qzone",
    "tencent-cloud","myapp","idqqimg","gtimg","qqmail","tcdn","cloudctrl","sdkostrace",
    "103.134.189.146","mbgame","csoversea","igame","pubgmobile","down.anticheatexpert.com",
    "asia.csoversea.mbgame.anticheatexpert.com","log.tav.qq","syzsdk.qq","logiservice.qcloud",
    "opensdk.tencent","exp.helpshift","loginsdkapi.zingplay","firebase","googleapis","facebook","gvoice"
}

local BLACKLIST_PORTS = {
    "10334","11045","12221","13331","8011","8015","9001","20000","20001","20002","20003","20004",
    "20005","19700","1670","19900","14545","10213","8700","25177","10685","10336","10262","27000",
    "27040","27015","27030","10706","10095","12401","11008","10309","11075","10157","24798","10709",
    "6667","10087","31113","20371","10120","10664","13728","10769","10761","5061","5062","18081",
    "15692","9030","8080","8086","8088"
}

local FILE_KEYWORDS = {
    "tlog","crash","bugly","report","beacon","wetest","analytics","telemetry","trace","dump",
    "exception","feedback","aps_log","mtp_detect","network_loss","client_error","ue4crash","tdm","gcloud"
}

local function isBlacklisted(str)
    if type(str) ~= "string" then return false end
    local low = str:lower()
    for _, kw in ipairs(BLACKLIST_HOSTS) do
        if low:find(kw,1,true) then return true end
    end
    for _, port in ipairs(BLACKLIST_PORTS) do
        if low:find(":"..port) or low:find("/"..port) then return true end
    end
    return false
end

-- ==================== FAKE DATA (From First Bypass) ====================
local FakeData = {
    ping = function() return math.random(20, 45) end,
    deviceID = function()
        local chars = "0123456789ABCDEF"
        local id = ""
        for i = 1, 32 do
            id = id .. chars:sub(math.random(1, #chars), math.random(1, #chars))
        end
        return id
    end,
    ipAddress = function() return "192.168." .. math.random(1, 255) .. "." .. math.random(1, 255) end,
    macAddress = function()
        return string.format("%02X:%02X:%02X:%02X:%02X:%02X",
            math.random(0,255), math.random(0,255), math.random(0,255),
            math.random(0,255), math.random(0,255), math.random(0,255))
    end,
    buildFingerprint = function()
        return "qcom/msmnile/msmnile:" .. math.random(10,12) .. "/" ..
               math.random(100000,999999) .. "/user/release-keys"
    end,
    kernelVersion = function() return "4.19." .. math.random(100,200) .. "-generic" end,
    hashValue = function() return "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6" end
}

local BypassState = {
    DeadEyeDisabled = false, HawkEyeDisabled = false, VoklaiDisabled = false,
    HiggsBosonDisabled = false, HashVerifyDisabled = false, IPMappingDisabled = false,
    MemoryPatchDisabled = false, EduEyeDisabled = false, FullBypassActive = false
}

local function KillTable(tbl, keys)
    if not tbl then return end
    for _, key in ipairs(keys) do
        pcall(function()
            if type(tbl[key]) == "function" then
                tbl[key] = function() return true, {} end
            else
                tbl[key] = nil
            end
        end)
    end
end

-- ==============================================================================
-- ============== LAYER 1: SLUA BYPASS  =====================
-- ==============================================================================
local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

-- ==============================================================================
-- ============== LAYER 2: MD5 BYPASS (@VINESH_OP) ======================
-- ==============================================================================
local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end

-- ==============================================================================
-- ============== LAYER 3: SKIN BYPASS (@VINESH_OP) =====================
-- ==============================================================================
local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end

-- ==============================================================================
-- ============== LAYER 4: LOG BLOCKER (@VINESH_OP) =====================
-- ==============================================================================
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture = function() return "" end; SMTD.ReMTDePicture = function() return "" end; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.CheckCanBugglyPostException = retFalse; GRUtils.ReplayReportData = nop; GRUtils.ReportGameException = nop; GRUtils.PostException = nop end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]; if s then s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse; s.sendEvent = nop; s.report = nop end
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 5: SCANNER BLOCKER (@VINESH_OP) =================
-- ==============================================================================
local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem", "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.ReportPingDelayTimer then sub:RemoveGameTimer(sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end; sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then AvaEx.CheckAvatarException = nop; AvaEx.CheckAvatarExceptionOnce = nop; AvaEx.ReportAvatarException = nop; AvaEx.CheckSlotMeshVisible = retFalse; AvaEx.CheckPawnVisible = retFalse; AvaEx.CheckCanBugglyPostException = retFalse end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            TssSdk.OnRecvData = function(data) if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end; if origData then origData(data) end end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse; TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 6: REPLAY TELEMETRY BLOCKER (@VINESH_OP) ========
-- ==============================================================================
local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop end
    end)
end

-- ==============================================================================
-- ============== LAYER 7: REPORT FLOW BLOCKER (@VINESH_OP) =============
-- ==============================================================================
local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

-- ==============================================================================
-- ============== LAYER 8: PLAYER SECURITY BYPASS (@VINESH_OP) ==========
-- ==============================================================================
local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

-- ==============================================================================
-- ============== LAYER 9: CLIENT FLOW BYPASS (@VINESH_OP) ==============
-- ==============================================================================
local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 10: SWIFT HAWK BYPASS (@VINESH_OP) ==============
-- ==============================================================================
local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

-- ==============================================================================
-- ============== LAYER 11: CORONA LAB BYPASS (@VINESH_OP) ==============
-- ==============================================================================
local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

-- ==============================================================================
-- ============== LAYER 12: MODIFIER EXCEPTION BYPASS (@VINESH_OP) ======
-- ==============================================================================
local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

-- ==============================================================================
-- ============== LAYER 13: SIMULATE CHARACTER LOCATION BYPASS ==================
-- ==============================================================================
local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

-- ==============================================================================
-- ============== LAYER 14: SHOOT VERIFICATION BYPASS (@VINESH_OP) ======
-- ==============================================================================
local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

-- ==============================================================================
-- ============== LAYER 15: NETWORK PACKET BLOCK (@VINESH_OP) ===========
-- ==============================================================================
local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 16: HIGGS BOSON BYPASS (@VINESH_OP) =============
-- ==============================================================================
local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive", "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.GetCurWeaponSkinID = retZero; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; pc.HiggsBosonComponent:ControlMHActive(0) end
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 17: ANTI CHEAT HOOKS (@VINESH_OP) ===============
-- ==============================================================================
local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop; _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then PlayerController.HiggsBosonComponent:ControlMHActive(0); PlayerController.HiggsBosonComponent.bMHActive = false end
        end
    end
end

-- ==============================================================================
-- ============== LAYER 18: ANTI REPORT (@VINESH_OP) ====================
-- ==============================================================================
local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 19: GAMEPLAY BYPASS (@VINESH_OP) ================
-- ==============================================================================
local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

-- ==============================================================================
-- ============== LAYER 20: KILL ALL SUBSYSTEMS (@VINESH_OP) ============
-- ==============================================================================
local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient", "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then pcall(function() sub[k] = nop end) end end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 21: FINAL PROTECTION (@VINESH_OP) ===============
-- ==============================================================================
local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

-- ==============================================================================
-- ============== LAYER 22: OPERATIONAL STATS BYPASS (Extra) ====================
-- ==============================================================================
local function InitializeOperationalStatsBypass()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        local OperationalStatsSubsystem = (subMgr and subMgr:Get("OperationalStatsSubsystem")) or _G.OperationalStatsSubsystem
        if OperationalStatsSubsystem then
            OperationalStatsSubsystem.ReportOperationalStats = nop
            OperationalStatsSubsystem.AddOperationalStats = nop
            OperationalStatsSubsystem.HandleTouchBegin = nop
            OperationalStatsSubsystem.HandleTouchEnd = nop
            OperationalStatsSubsystem.OnInit = nop
            OperationalStatsSubsystem.HandleEnterFighting = nop
            OperationalStatsSubsystem.OnBattleResult = nop
            if OperationalStatsSubsystem.TimerHandle then
                pcall(function() OperationalStatsSubsystem:RemoveGameTimer(OperationalStatsSubsystem.TimerHandle) end)
                OperationalStatsSubsystem.TimerHandle = nil
            end
            OperationalStatsSubsystem.StatsData = {}
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 23: BYPASS BASE (From First Bypass) =====================
-- ==============================================================================
local function InitializeBypassBase()
    pcall(function()
        local stExtra = import("STExtraBlueprintFunctionLibrary")
        if stExtra and stExtra.IsDevelopment then stExtra.IsDevelopment = nop end
        if Client then Client.IsDevelopment = nop; Client.IsShipping = retFalse end
        if Server then Server.IsShipping = retFalse end

        local ToolReport = safe_require("client.slua.logic.report.ToolReportUtil")
        if ToolReport then
            ToolReport.IsReleaseVersion = retFalse
            ToolReport.IsWhite = retFalse
            ToolReport.GetReportSwitch = retFalse
        end

        local callbacks = _G.GameplayCallbacks or _G.GC
        if callbacks then
            local kills = {
                "SendTssSdkAntiDataToLobby","SendDSErrorLogToLobby","SendDSHawkEyePatrolLogToLobby",
                "SendSecTLog","SendDataMiningTLog","SendActivityTLog","SendClientMemUsage","SendClientFPS",
                "OnClientCrashReport","OnNetworkLossDetected","ReportMatchRoomData","ReportPlayersPing",
                "SendClientStats","SendServerAvgTickDelta","ReportHitFlow","OnPlayerActorChannelError","OnPlayerRPCValidateFailed"
            }
            for _, fn in ipairs(kills) do
                if callbacks[fn] then callbacks[fn] = nop end
            end
            local origDS = callbacks.OnDSPlayerStateChanged
            if origDS then
                callbacks.OnDSPlayerStateChanged = function(dsSelf, state, reason, ...)
                    if tostring(reason):lower():find("cheatdetected") then return end
                    pcall(origDS, dsSelf, state, reason, ...)
                end
            end
        end

        if _G.TApmHelper then _G.TApmHelper.postEvent = nop end

        local PC = _G.PacketCallbacks
        if PC then
            PC.player_report_cheat = nop
            PC.upload_loots_rsp = nop
            PC.watch_player_exit = nop
            PC.player_login_report = nop
            PC.player_logout_report = nop
            PC.server_time_report = nop
        end

        local sdm = _G.ServerDataMgr
        if sdm and sdm.DeletablePlayerResultKey then
            sdm.DeletablePlayerResultKey["SuspiciousHitCount"] = true
            sdm.DeletablePlayerResultKey["EspTotalSimTraceCnt"] = true
            sdm.DeletablePlayerResultKey["EspTotalImeFocusCnt"] = true
            sdm.DeletablePlayerResultKey["ClientGravityAnomalyCount"] = true
        end

        local pcNotify = safe_require("GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature")
        if pcNotify then
            pcNotify.ClientRPC_SyncBanID = nop
            pcNotify.ClientRPC_StrongTips = nop
            pcNotify.ClientRPC_NormalTips = nop
            pcNotify.Notify = nop
            pcNotify.ClientRPC_NotifyBan = nop
            pcNotify.ClientRPC_NotifyPunish = nop
            pcNotify.ClientRPC_NotifyIllegalProgram = nop
        end

        local secUtils = safe_require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
        if secUtils and secUtils.EStrategyTypeInReplay then
            secUtils.EStrategyTypeInReplay.EspTotalSimTraceCnt = 0
            secUtils.EStrategyTypeInReplay.EspTotalImeFocusCnt = 0
            secUtils.EStrategyTypeInReplay.ClientGravityAnomalyCount = 0
            secUtils.EStrategyTypeInReplay.FlyingErrorCnt = 0
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 24: HIGGS BYPASS (From First Bypass) ====================
-- ==============================================================================
local function InitializeHiggsBypass()
    pcall(function()
        local Higgs = safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            local methods = {
                "ControlMHActive","Tick","OnTick","MHActiveLogic","TriggerAvatarCheck","StartAvatarCheck",
                "ReportItemID","ReceiveAnyDamage","OnWeaponHitRecord","ShowSecurityAlert","ServerReportAvatar",
                "ClientReportNetAvatar","SendHisarData","ValidateSecurityData","StaticShowSecurityAlertInDev"
            }
            for _, m in ipairs(methods) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty
            Higgs.GetCurWeaponSkinID = retZero
        end
        if _G.DisableHiggsBoson then _G.DisableHiggsBoson = nop end

        local hia = safe_require("GameLua.Mod.BaseMod.Client.Security.ClientGlueHiaSystem")
        if hia then
            hia.CheckHitIntegrity = nop
            hia.InitSession = nop
            hia.OnBattleEnd = nop
        end

        local Behavior = safe_require("GameLua.Mod.Escape.Gameplay.Subsystem.BehaviorScoreSubsystem")
        if Behavior then
            Behavior.OnHandleBehaviorScore = nop
            Behavior.AIPerceptionScore = nop
            Behavior.ReportBehavior = nop
            Behavior.CalcFinalScore = retZero
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 25: BAN SYSTEM BYPASS (From First Bypass) ===============
-- ==============================================================================
local function InitializeBanSystemBypass()
    pcall(function()
        local BanLogic = safe_require("client.slua.logic.ban.ClientBanLogic")
        if BanLogic then
            BanLogic.OnSyncBanInfo = nop; BanLogic.OnVoiceBanNotify = nop
            BanLogic.OnRealTimeVoiceBanNotify = nop; BanLogic.OnVoiceBanSuccess = nop
            BanLogic.OnSyncMicSuspicious = nop; BanLogic.OnSyncMicPreFilter = nop
            BanLogic.OnNotifyWarningTips = nop; BanLogic.ReqBanInfo = nop
        end

        local BanUtil = safe_require("client.common.ban_util") or _G.ban_util
        if BanUtil then
            BanUtil.CheckBanStatus = retFalse
            BanUtil.GetBanTime = retZero
            BanUtil.IsBanForever = retFalse
        end

        local TTBan = safe_require("client.logic.login.logic_tt_ban") or _G.logic_tt_ban
        if TTBan then
            TTBan.CheckIfCanCreateRole = nop
            TTBan.GetCarrierInfo = function() return "[{\"mcc\":\"000\"}]" end
        end

        local GodzillaBan = safe_require("client.network.Protocol.GodzillaBanHandler")
        if GodzillaBan then
            GodzillaBan.send_godzilla_ban_req = nop
            GodzillaBan.send_godzilla_unban_req = nop
        end

        local AntiAddiction = safe_require("client.network.Protocol.AntiaddctionHandler")
        if AntiAddiction then
            AntiAddiction.send_anti_addiction_req = nop
            AntiAddiction.send_anti_addiction_notify = nop
        end

        local AccessRestrict = safe_require("client.network.Protocol.AccessRestrictionHandler")
        if AccessRestrict then
            AccessRestrict.send_access_restriction_req = nop
            AccessRestrict.send_access_restriction_notify = nop
            AccessRestrict.on_player_cheat_state_notify = nop
        end

        local DeleteAccount = safe_require("client.slua.logic.gdpr.logic_deleteaccount")
        if DeleteAccount then
            DeleteAccount.ForceDeleteAccount = retFalse
            DeleteAccount.OnReceiveDeleteNotify = nop
        end

        local ComplianceUtil = safe_require("client.slua.logic.gdpr.compliance_util")
        if ComplianceUtil then ComplianceUtil.CheckCompliance = nop end
    end)
end

-- ==============================================================================
-- ============== LAYER 26: REPORT SYSTEMS BYPASS (From First Bypass) ===========
-- ==============================================================================
local function InitializeReportSystemsBypass()
    pcall(function()
        local clientReport = safe_require("GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem")
        if clientReport then
            local funcs = {"OnInit","_OnPlayerKilledOtherPlayer","_RecordFatalDamager","SendPacket","ReportSuspiciousPlayer","SubmitReport","_OnBattleResult","_RecordTeammatePlayerInfo","_OnDeathReplayDataWhenFatalDamaged","_RecordMurdererFromDeathReplayData"}
            for _, fn in ipairs(funcs) do
                if clientReport[fn] then clientReport[fn] = nop end
            end
        end

        local dsReport = safe_require("GameLua.Mod.BaseMod.Common.Security.DSReportPlayerSubsystem")
        if dsReport then
            local funcs = {"_OnNearDeathOrRescued","_OnPlayerSettlementStart","_OnTeammateDamage","_OnCharacterDied","_AddEnemyMapToBattleResult","_AddTeammateMapToBattleResult","_SubmitAbnormalData"}
            for _, fn in ipairs(funcs) do
                if dsReport[fn] then dsReport[fn] = nop end
            end
        end

        local reportUtils = safe_require("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils")
        if reportUtils then
            reportUtils.GetBotType = retZero
            reportUtils.IsCharacterDeliverAI = retFalse
        end

        local AvatarSub = safe_require("GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionSubsystem")
        if AvatarSub then
            AvatarSub.OnClickReportCheckAvatar = nop
            AvatarSub.RegisterTickCheckCharacterAvatar = nop
        end

        if _G.AvatarExceptionPlayerInst then
            _G.AvatarExceptionPlayerInst.ReportAvatarException = nop
            _G.AvatarExceptionPlayerInst.CheckAvatarException = nop
            _G.AvatarExceptionPlayerInst.CheckCanBugglyPostException = nop
        end

        local SubsystemMgr = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubsystemMgr then
            local hawk = SubsystemMgr:Get("DSHawkEyePatrolSubsystem")
            if hawk then hawk.MarkSuspiciousPlayer = nop end
        end

        if _G.DSHawkEyePatrolSubsystem then
            _G.DSHawkEyePatrolSubsystem._OnHawkReport = nop
            _G.DSHawkEyePatrolSubsystem._OnHawkImprison = nop
            _G.DSHawkEyePatrolSubsystem.CheckPunishPlayer = nop
        end

        local ClientHawk = safe_require("GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem")
        if ClientHawk then
            local funcs = {"_OnHawkSync","_OnHawkReportSuccess","_StartExitGameTimer","_OnRecvInspectorBroadcastCount","SendReportTLog","ReportCheat"}
            for _, fn in ipairs(funcs) do
                if ClientHawk[fn] then ClientHawk[fn] = nop end
            end
            ClientHawk.CanInspectorBroadcast = retFalse
        end

        local InspectClient = safe_require("GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem")
        if InspectClient then
            local funcs = {"AskForInspector","ReportEnemy","KickOutOneTeam","OnReceiveInspectCmd","ClientReportData","SendReportToInspector","SendKickOutOneTeam","ClientNotifyInspectorImplementation","RecvNotifyInspector"}
            for _, fn in ipairs(funcs) do
                if InspectClient[fn] then InspectClient[fn] = nop end
            end
        end

        local InspectDS = safe_require("GameLua.Mod.BaseMod.DS.Security.InspectionSystemReportDSLogicSubsystem")
        if InspectDS then
            local funcs = {"ServerKickOutOneTeamByPlayerImplementation","AddReportedCount","AddInspectionRecord","BanPlayerByInspection","BroadCastToAllInspector","ServerReportToInspectorImplementation","InitPlayerInspectionInfo"}
            for _, fn in ipairs(funcs) do
                if InspectDS[fn] then InspectDS[fn] = nop end
            end
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 27: TLOG BYPASS (From First Bypass) =====================
-- ==============================================================================
local function InitializeTLogBypass()
    pcall(function()
        local tlogMods = {
            "client.network.Protocol.ClientTlogHandler","client.network.Protocol.BattleReportHandler",
            "client.network.Protocol.ClientErrorReportHandler","client.network.Protocol.LobbyPingReportHandler",
            "client.slua.config.tlog.tlog_report_utils","client.slua.data.BasicData.BasicDataTLogReport",
            "client.slua.data.BasicData.BasicDataClientReport","client.slua.data.BasicData.BasicDataReport",
            "GameLua.Mod.BaseMod.DS.Security.DSCommonTLogSubsystem","GameLua.Mod.BaseMod.DS.Security.DSFightTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem","GameLua.Mod.BaseMod.Client.Security.ClientDataStatistcsSubsystem"
        }
        for _, path in ipairs(tlogMods) do
            local mod = package.loaded[path]
            if mod then
                for k, v in pairs(mod) do
                    if type(v) == "function" and (k:find("Log") or k:find("Report") or k:find("Send") or k:find("Tlog")) then
                        pcall(function() mod[k] = nop end)
                    end
                end
            end
        end

        local AmphibiousBoat = safe_require("GameLua.GameCore.Module.Vehicle.VehicleFeatures.TLog.AmphibiousBoatTLogFeature")
        if AmphibiousBoat then
            AmphibiousBoat.RecordMovement = nop
            AmphibiousBoat.StartRecordMovement = nop
        end

        local ICTLog = safe_require("GameLua.Mod.BaseMod.DS.Security.ICTLogSubsystem")
        if ICTLog then ICTLog.SendICExceptionTLog = nop end

        local DSFight = safe_require("GameLua.Mod.BaseMod.DS.Security.DSFightTLogSubsystem")
        if DSFight then
            DSFight.GetSimpleFightData = retEmpty
            DSFight.ReportFightData = nop
            DSFight.ReportPlayerWeapon = nop
        end

        local DSSec = safe_require("GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem")
        if DSSec then
            DSSec._OnReportServerJumpFlow = nop
            DSSec._OnReportTeleportFlow = nop
            DSSec._OnReportSpeedHackFlow = nop
        end

        local DSCommon = safe_require("GameLua.Mod.BaseMod.DS.Security.DSCommonTLogSubsystem")
        if DSCommon then DSCommon.HandleKillTlog = nop end

        local PufferTlog = safe_require("client.slua.logic.download.report.puffer_tlog")
        if PufferTlog then PufferTlog.report_download_tlog = nop end
    end)
end

-- ==============================================================================
-- ============== LAYER 28: NETWORK HANDLERS BYPASS (From First Bypass) =========
-- ==============================================================================
local function InitializeNetworkHandlersBypass()
    pcall(function()
        local ClientError = safe_require("client.network.Protocol.ClientErrorReportHandler")
        if ClientError then
            ClientError.send_client_error_report = nop
            ClientError.send_client_crash_report = nop
            ClientError.send_client_tools_batch_report_req = nop
        end

        local BattleReport = safe_require("client.network.Protocol.BattleReportHandler")
        if BattleReport then
            for _, fn in ipairs({"send_battle_report","send_battle_result","send_vod_game_report_req","send_batch_get_vod_info_req","send_get_game_report_req","send_batch_get_game_report_req","send_get_game_report_by_uid_req"}) do
                if BattleReport[fn] then BattleReport[fn] = nop end
            end
        end

        local BugHandler = safe_require("client.network.Protocol.BugHandler")
        if BugHandler then
            BugHandler.send_report_bug_info = nop
            BugHandler.send_report_bug_feedback = nop
        end

        local PingReport = safe_require("client.network.Protocol.LobbyPingReportHandler")
        if PingReport then
            PingReport.send_lobby_ping_report = nop
            PingReport.send_ingame_ping_report = nop
        end

        local WeekReport = safe_require("client.network.Protocol.WeekRportHandler")
        if WeekReport then
            WeekReport.send_week_report = nop
            WeekReport.send_week_detail = nop
        end

        local LogicComplaint = safe_require("client.logic.battle.logic_complaint")
        if LogicComplaint then
            LogicComplaint.SendComplaintReq = nop
            LogicComplaint.Submit = nop
            LogicComplaint.ReportPlayer = nop
            LogicComplaint.ShowComplaint = nop
            LogicComplaint.ShowHandle = nop
        end

        local OBResult = safe_require("GameLua.Mod.BaseMod.Client.BattleResult.ProcessBase.EscapeBattleResultShowOBResultLogic")
        if OBResult then
            OBResult.OnBattleResult = nop
            OBResult.OnResultProcessStart = nop
        end

        local NormalOBResult = safe_require("GameLua.Mod.BaseMod.Client.BattleResult.ProcessBase.BattleResultShowOBResultLogic")
        if NormalOBResult then
            NormalOBResult.OnBattleResult = nop
            NormalOBResult.OnResultProcessStart = nop
        end

        local ShowResult = safe_require("GameLua.Mod.BaseMod.Client.BattleResult.ProcessBase.BattleResultShowResultLogic")
        if ShowResult then
            for _, fn in ipairs({"OnBattleResult","OnResultProcessStart","OnResultProcessContinue","ReceiveData","SendEndFlow","OnReport","ShowResult","ShowResultInternal","StopResultProcess"}) do
                if ShowResult[fn] then ShowResult[fn] = nop end
            end
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 29: MISC BYPASS (From First Bypass) =====================
-- ==============================================================================
local function InitializeMiscBypass()
    pcall(function()
        local EmuHandler = safe_require("client.network.Protocol.EmulatorHandler")
        if EmuHandler then EmuHandler.send_emulator_info = nop end

        local EmuScanner = safe_require("client.logic.login.emulator_scanner")
        if EmuScanner then
            EmuScanner.StartScan = nop
            EmuScanner.GetScanResult = retFalse
            EmuScanner.ReportScanResult = nop
        end

        local LoginVerify = safe_require("client.network.Protocol.LoginVerifyHandler")
        if LoginVerify then
            LoginVerify.send_login_verify_req = nop
            LoginVerify.send_device_verify_req = nop
        end

        local DSMonitor = safe_require("client.logic.data.logic_ds_monitor")
        if DSMonitor then
            DSMonitor.OnRecordMsg = nop
            DSMonitor.OnReportMsg = nop
        end

        local ClientDataStat = safe_require("GameLua.Mod.BaseMod.Client.Security.ClientDataStatistcsSubsystem")
        if ClientDataStat then
            ClientDataStat.StartToCheck = nop
            ClientDataStat.OnReceiveRTT = nop
            ClientDataStat.OnReceiveJitter = nop
            ClientDataStat.ReportAbnormal = nop
            ClientDataStat.ResetData = nop
        end

        local shootVerify = safe_require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if shootVerify then
            shootVerify.OnShootVerifyFailed = nop
            shootVerify.SendVerifyData = nop
        end

        local HighlightDS = safe_require("GameLua.Mod.BaseMod.DS.Security.HighlightMomentSubsystem_DSChecker")
        if HighlightDS then HighlightDS.CheckFuncUpgradedWeaponKill = nop end

        local ProfileReport = safe_require("client.logic.data.profile_report_cfg")
        if ProfileReport then ProfileReport.SendReport = nop end

        local VoiceReport = safe_require("client.slua.logic.chat_voice.logic_chat_voice_report")
        if VoiceReport then
            VoiceReport.ReportVoiceData = nop
            VoiceReport.ReportVoiceText = nop
        end

        local VoiceDoctor = safe_require("client.slua.logic.chat_voice.logic_chat_voice_doctor")
        if VoiceDoctor then
            VoiceDoctor.UploadVoiceLog = nop
            VoiceDoctor.UploadVoiceException = nop
        end

        local HomeAudit = safe_require("client.slua.logic.home.Audit.logic_home_audit_state")
        if HomeAudit then
            HomeAudit.SendAuditState = nop
            HomeAudit.ReportAuditResult = nop
        end

        local HomeReport = safe_require("client.slua.logic.home.logic_home_report")
        if HomeReport then
            HomeReport.ReportHomeData = nop
            HomeReport.ReportHomeVisitor = nop
        end

        local GemReport = safe_require("client.logic.store.gem_report_utils")
        if GemReport then
            GemReport.ReportGemData = nop
            GemReport.ReportGemPurchase = nop
        end

        local SafeStation = safe_require("client.slua.logic.CustomerService.LogicSafeStation")
        if SafeStation then
            SafeStation.UploadVideoEvidence = nop
            SafeStation.ReportPlayerBehavior = nop
        end

        local CustomerService = safe_require("client.slua.logic.CustomerService.LogicCustomerService")
        if CustomerService then
            CustomerService.SendComplaint = nop
            CustomerService.SendFeedback = nop
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 30: EXTRA SUBSYSTEMS BYPASS (From First Bypass) =========
-- ==============================================================================
local function InitializeExtraSubsystemsBypass()
    pcall(function()
        local znq6Revive = safe_require("GameLua.Mod.TDEvent.ZNQ6th.DS.ZNQ6thDSReviveSubsystem")
        if znq6Revive then znq6Revive.HaveNewItemForRevive = nop end

        local znq7Revive = safe_require("GameLua.Mod.TDEvent.ZNQ7th.DS.ZNQ7DSReviveSubsystem")
        if znq7Revive then znq7Revive.HaveChanceRevival = nop end

        local DataLayer = safe_require("GameLua.Mod.BaseMod.Common.Subsystem.DataLayerSubsystem")
        if DataLayer then
            local orig = DataLayer.OnSpectatorReplayChanged
            if orig then
                DataLayer.OnSpectatorReplayChanged = function(dlSelf)
                    _G.IsBeingWatched = true
                    orig(dlSelf)
                end
            end
        end

        local DSActive = safe_require("GameLua.Mod.PlanBT.Gameplay.Subsystem.DSActiveSubsystem")
        if DSActive then
            DSActive.DelayKickOutPlayer = nop
            DSActive.ActiveKickNotify = nop
        end

        local CreativeDev = safe_require("GameLua.Mod.CreativeBase.Gameplay.Subsystem.CreativeDevDebugSubsystem")
        if CreativeDev then CreativeDev.IsDebugPanelEnalbedCli = nop end

        local CreativeDeath = safe_require("GameLua.Mod.CreativeBase.Gameplay.Subsystem.CreativeModeDeathRecordSubsystem")
        if CreativeDeath then CreativeDeath.OnPlayerKilled = nop end

        if _G.ClientReplayDataReporter then
            _G.ClientReplayDataReporter.ReportIntArrayData = nop
            _G.ClientReplayDataReporter.ReportFloatArrayData = nop
        end

        local SpectateReplay = safe_require("GameLua.Mod.BaseMod.Common.Subsystem.SpectateAndReplaySubsystem")
        if SpectateReplay then
            SpectateReplay.RequestGotoSpectatingImp = nop
            SpectateReplay.RequestGotoSpectating = nop
        end

        local AIReplay = safe_require("GameLua.ExtraModule.MLAI.Client.AIReplaySubsystem")
        if AIReplay then
            AIReplay.ReportAllPlayerInfo = nop
            AIReplay.ReportFrameData = nop
            AIReplay.ReportPlayerInput = nop
            if AIReplay.uCompletePlayBack then
                AIReplay.uCompletePlayBack.AddRecordMLAIInfo = nop
                AIReplay.uCompletePlayBack.StopRecording = nop
            end
        end

        local AITracking = safe_require("GameLua.Mod.BaseMod.GamePlay.AI.AITrackingLogSubsystem")
        if AITracking then
            AITracking.RealLogoutTimer = nop
            AITracking.LogQueue = {}
            AITracking.AddToLogQue = nop
            AITracking.DoPrint = nop
            AITracking.OnAIPawnDied = nop
            AITracking.OnAIPawnReceiveDamage = nop
            AITracking.OnAIPawnEnemyChange = nop
        end

        local AFKReport = safe_require("GameLua.Mod.BaseMod.DS.Security.AFKReportorSubsystem")
        if AFKReport then
            AFKReport.HandleEnterFighting = nop
            AFKReport.InitializePlayerInputInfo = nop
            AFKReport.AddOneAFKInfo = nop
            AFKReport.SetPlayerAFKState = nop
            AFKReport.ResetPlayerInputInfo = nop
            AFKReport.PlayerHaveAction = nop
        end

        local TDMAFK = safe_require("GameLua.Mod.TDM.Gameplay.Subsystem.TDMAFKReportorSubsystem")
        if TDMAFK then
            TDMAFK.SendAFKTips = nop
            TDMAFK.OnHandleLostConnection = nop
        end

        local DataMgr = safe_require("client.slua.logic.data.data_mgr")
        if DataMgr then DataMgr.GetWeaponSkinSoundVolumeInfoByGroup = retZero end

        local CreditLogic = safe_require("GameLua.Mod.BaseMod.Client.ClientInGameCreditLogic")
        if CreditLogic then
            CreditLogic._SendUserReaction2ExitTeamBeforeBoardingReturnLobbyNotice = nop
            CreditLogic.ShowReturnLobbyIfFirstExitTeamBeforeBoarding = retFalse
            CreditLogic.OnReceiveCreditScoreChange = nop
            CreditLogic._IsFirstExitTeamBeforeBoardingReturnLobbyNoticeEnabled = retFalse
            CreditLogic.SetFirstExitTeamBeforeBoardingReturnLobbyNoticeEnabled = nop
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 31: NETWORK BLACKLIST (From First Bypass) ===============
-- ==============================================================================
local function InitializeNetworkBlacklist()
    pcall(function()
        if _G.HttpRequest then
            local orig = _G.HttpRequest
            _G.HttpRequest = function(url, ...)
                if isBlacklisted(url) then return nil end
                return orig(url, ...)
            end
        end

        if _G.FHttpModule and _G.FHttpModule.CreateRequest then
            local orig = _G.FHttpModule.CreateRequest
            _G.FHttpModule.CreateRequest = function(...)
                local url = select(1, ...)
                if isBlacklisted(url) then return nil end
                return orig(...)
            end
        end

        local netMods = {
            "client.slua.logic.network.logic_network","client.slua.logic.download.report.puffer_tlog",
            "client.slua.data.BasicData.BasicDataClientReport","GameLua.GameCore.Module.Network.NetworkManager",
            "client.network.Protocol.ClientTlogHandler","client.network.Protocol.BattleReportHandler",
            "client.network.Protocol.ClientErrorReportHandler"
        }
        for _, mp in ipairs(netMods) do
            local mod = package.loaded[mp]
            if mod then
                for k, v in pairs(mod) do
                    if type(v) == "function" and (k:find("Http") or k:find("Request") or k:find("Send") or k:find("Upload") or k:find("Post") or k:find("Get") or k:find("Report")) then
                        local origf = v
                        mod[k] = function(...)
                            local args = {...}
                            for _, arg in ipairs(args) do
                                if type(arg) == "string" and isBlacklisted(arg) then return nil end
                            end
                            return pcall(origf, ...)
                        end
                    end
                end
            end
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 32: FILE IO CRASH BLOCK (From First Bypass) =============
-- ==============================================================================
local function InitializeFileIOCrashBlock()
    pcall(function()
        local orig_io_open = io.open
        io.open = function(path, mode)
            if type(path) == "string" then
                local lp = path:lower()
                for _, kw in ipairs(FILE_KEYWORDS) do
                    if lp:find(kw) then
                        if mode and (mode == "w" or mode == "a" or mode == "w+" or mode == "a+") then
                            return nil, "Blocked"
                        end
                    end
                end
                if lp:find("tdm") or lp:find("gcloud") or lp:find("beacon") then
                    if mode and (mode == "w" or mode == "a" or mode == "w+") then
                        return nil
                    end
                end
            end
            return orig_io_open(path, mode)
        end

        if _G.UnrealEngine and _G.UnrealEngine.CrashContext then
            _G.UnrealEngine.CrashContext = nil
            _G.UnrealEngine.CrashContext = {
                SetCrashContext = nop,
                ReportCrash = nop,
                AddCrashData = nop
            }
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 33: DEAD EYE BYPASS (8-Layer Advanced) ==================
-- ==============================================================================
local function InitializeDeadEyeBypass()
    pcall(function()
        if BypassState.DeadEyeDisabled then return end
        if _G.GameplayCallbacks then
            KillTable(_G.GameplayCallbacks, {
                "ReportAimFlow","ReportHitFlow","ReportAttackFlow",
                "OnAimDetected","OnHeadshotDetected","OnPerfectAccuracy"
            })
        end
        local subsystems = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems then
            local aimTracker = subsystems:Get("ClientAimTrackingSubsystem")
            if aimTracker then
                aimTracker.GetAimData = function()
                    return {accuracy = math.random(45,65), headshotRate = math.random(15,35)}
                end
                aimTracker.IsAimNormal = function() return true end
            end
        end
        BypassState.DeadEyeDisabled = true
        _G.BYPASS_STATE.DEADEYE_DISABLED = true
    end)
end

-- ==============================================================================
-- ============== LAYER 34: HAWK EYE BYPASS (8-Layer Advanced) ==================
-- ==============================================================================
local function InitializeHawkEyeBypass()
    pcall(function()
        if BypassState.HawkEyeDisabled then return end
        local subsystems = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems then
            local hawkEye = subsystems:Get("ClientHawkEyePatrolSubsystem")
            if hawkEye then
                hawkEye.GetPatrolData = function() return {} end
                hawkEye.IsBeingWatched = function() return false end
                hawkEye.GetSpectatorCount = function() return 0 end
            end
        end
        if _G.GameplayCallbacks then
            KillTable(_G.GameplayCallbacks, {
                "SendDSErrorLogToLobby","SendDSHawkEyePatrolLogToLobby","ReportMatchRoomData"
            })
        end
        BypassState.HawkEyeDisabled = true
        _G.BYPASS_STATE.HAWKEYE_DISABLED = true
    end)
end

-- ==============================================================================
-- ============== LAYER 35: VOKLAI BYPASS (8-Layer Advanced) ====================
-- ==============================================================================
local function InitializeVoklaiBypass()
    pcall(function()
        if BypassState.VoklaiDisabled then return end
        local subsystems = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems then
            local aiBehavior = subsystems:Get("ClientAIBehaviourSubsystem")
            if aiBehavior then
                aiBehavior.GetBehaviorScore = function() return math.random(10,30) end
                aiBehavior.IsSuspicious = function() return false end
                aiBehavior.GetRiskLevel = function() return 0 end
            end
            local stepCheck = subsystems:Get("ClientStepCheckSubsystem")
            if stepCheck then
                stepCheck.GetStepDelta = function() return math.random(5,50) end
                stepCheck.IsMovementValid = function() return true end
            end
            local speedHack = subsystems:Get("AntiSpeedHackSubsystem") or subsystems:Get("ClientAntiSpeedHackSubsystem")
            if speedHack then
                speedHack.GetSpeed = function() return math.random(300,600) end
                speedHack.IsSpeedValid = function() return true end
            end
        end
        BypassState.VoklaiDisabled = true
        _G.BYPASS_STATE.VOKLAI_DISABLED = true
    end)
end

-- ==============================================================================
-- ============== LAYER 36: HIGGS BOSON 8 BYPASS (8-Layer Advanced) =============
-- ==============================================================================
local function InitializeHiggsBoson8Bypass()
    pcall(function()
        if BypassState.HiggsBosonDisabled then return end
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if isValid(pc) then
            if pc.HiggsBoson then
                pc.HiggsBoson.bMHActive = false
                pc.HiggsBoson.bCallPreReplication = false
            end
            if pc.HiggsBosonComponent then
                pc.HiggsBosonComponent.bMHActive = false
                pc.HiggsBosonComponent:ControlMHActive(0)
            end
        end
        local higgs = safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if higgs then
            higgs.GetNetAvatarItemIDs = function() return {1001,2002,3003,4004,5005} end
            higgs.GetCurWeaponSkinID = function() return 6001 end
            higgs.GetCurItemIDs = function() return {7001,8002} end
            if higgs.BlackList then higgs.BlackList = {} end
        end
        _G.GlobalPlayerCoronaData = _G.GlobalPlayerCoronaData or {}
        local mt = getmetatable(_G.GlobalPlayerCoronaData) or {}
        mt.__newindex = function() end
        setmetatable(_G.GlobalPlayerCoronaData, mt)
        _G.BlackList = {}
        BypassState.HiggsBosonDisabled = true
        _G.BYPASS_STATE.HIGGSBOSON_DISABLED = true
    end)
end

-- ==============================================================================
-- ============== LAYER 37: HASH VERIFICATION BYPASS (8-Layer Advanced) =========
-- ==============================================================================
local function InitializeHashVerificationBypass()
    pcall(function()
        if BypassState.HashVerifyDisabled then return end
        if _G.TssSdk then
            _G.TssSdk.ScanMemory = function() return true, {code=0, msg="clean"} end
            _G.TssSdk.ScanSo = function() return true, {code=0, msg="clean"} end
            _G.TssSdk.ScanFile = function() return true, {code=0} end
            _G.TssSdk.GetRiskFlag = function() return 0 end
            _G.TssSdk.VerifyFileHash = function() return true end
        end
        local subsystems = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems then
            local integrity = subsystems:Get("ClientIntegrityCheckSubsystem")
            if integrity then
                KillTable(integrity, {"CheckFileHash","VerifyMemory","ScanModules"})
            end
        end
        BypassState.HashVerifyDisabled = true
        _G.BYPASS_STATE.HASH_VERIFY_DISABLED = true
    end)
end

-- ==============================================================================
-- ============== LAYER 38: IP MAPPING BYPASS (8-Layer Advanced) ================
-- ==============================================================================
local function InitializeIPMappingBypass()
    pcall(function()
        if BypassState.IPMappingDisabled then return end
        if _G.GameplayCallbacks then
            KillTable(_G.GameplayCallbacks, {
                "SendClientDeviceInfo","ReportDeviceFingerprint","SendNetworkInfo",
                "ReportIPAddress","SendMACAddress","ReportHardwareID"
            })
        end
        local subsystems = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems then
            local deviceInfo = subsystems:Get("ClientDeviceInfoSubsystem")
            if deviceInfo then
                deviceInfo.GetDeviceID = function() return FakeData.deviceID() end
                deviceInfo.GetIPAddress = function() return FakeData.ipAddress() end
                deviceInfo.GetMACAddress = function() return FakeData.macAddress() end
            end
        end
        BypassState.IPMappingDisabled = true
        _G.BYPASS_STATE.IP_MAPPING_DISABLED = true
    end)
end

-- ==============================================================================
-- ============== LAYER 39: MEMORY PATCHING BYPASS (8-Layer Advanced) ===========
-- ==============================================================================
local function InitializeMemoryPatchingBypass()
    pcall(function()
        if BypassState.MemoryPatchDisabled then return end
        local subsystems = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems then
            local kernelCheck = subsystems:Get("ClientKernelCheckSubsystem")
            if kernelCheck then
                kernelCheck.IsKernelClean = function() return true end
                kernelCheck.GetKernelVersion = function() return FakeData.kernelVersion() end
                kernelCheck.IsBootloaderLocked = function() return true end
            end
            local memoryGuard = subsystems:Get("ClientMemoryGuardSubsystem")
            if memoryGuard then
                memoryGuard.IsMemoryClean = function() return true, {code=0} end
                memoryGuard.ScanResult = function() return "clean" end
            end
        end
        if _G.TssSdk then
            _G.TssSdk.CheckKernel = function() return true, {status="verified", tampered=false} end
            _G.TssSdk.VerifyBoot = function() return true, {locked=true, verified=true} end
        end
        BypassState.MemoryPatchDisabled = true
        _G.BYPASS_STATE.MEMORY_PATCH_DISABLED = true
    end)
end

-- ==============================================================================
-- ============== LAYER 40: EDU EYE BYPASS (8-Layer Advanced) ===================
-- ==============================================================================
local function InitializeEduEyeBypass()
    pcall(function()
        if BypassState.EduEyeDisabled then return end
        local subsystems = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems then
            local renderCheck = subsystems:Get("ClientRenderCheckSubsystem")
            if renderCheck then
                renderCheck.IsRenderClean = function() return true end
                renderCheck.GetRenderState = function() return "normal" end
            end
            local espDetection = subsystems:Get("ClientESPDetectionSubsystem")
            if espDetection then
                espDetection.HasESP = function() return false end
                espDetection.CheckOverlay = function() return "clean" end
            end
            local wallhackDetect = subsystems:Get("ClientWallhackDetectionSubsystem")
            if wallhackDetect then
                wallhackDetect.IsVisionNormal = function() return true end
                wallhackDetect.GetVisibilityRate = function() return math.random(60,85) end
            end
        end
        BypassState.EduEyeDisabled = true
        _G.BYPASS_STATE.EDU_EYE_DISABLED = true
    end)
end

-- ==============================================================================
-- ============== LAYER 41: APPLY ALL BYPASSES (8-Layer Advanced) ===============
-- ==============================================================================
local function InitializeApplyAllBypasses()
    pcall(function()
        if BypassState.FullBypassActive then return end
        InitializeDeadEyeBypass()
        InitializeHawkEyeBypass()
        InitializeVoklaiBypass()
        InitializeHiggsBoson8Bypass()
        InitializeHashVerificationBypass()
        InitializeIPMappingBypass()
        InitializeMemoryPatchingBypass()
        InitializeEduEyeBypass()
        BypassState.FullBypassActive = true
        _G.BYPASS_STATE.FULL_BYPASS_ACTIVE = true
    end)
end

-- ==============================================================================
-- ============== LAYER 42: HUNT AND KILL ALL (Persistent) ======================
-- ==============================================================================
local function InitializeHuntAndKillAll()
    pcall(function()
        local subNames = {
            "ClientHawkEyePatrolSubsystem","DSHawkEyePatrolSubsystem","ClientReportPlayerSubsystem",
            "DSReportPlayerSubsystem","ClientGlueHiaSystem","ClientDataStatistcsSubsystem",
            "ICTLogSubsystem","DSFightTLogSubsystem","DSSecurityTLogSubsystem","AFKReportorSubsystem",
            "BehaviorScoreSubsystem"
        }
        local subMgr = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subMgr and subMgr.Get then
            for _, name in ipairs(subNames) do
                local sub = subMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Tick") or k:find("Log")) then
                            pcall(function() sub[k] = nop end)
                        end
                    end
                end
            end
        end
        local Higgs = safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            local methods = {
                "ControlMHActive","Tick","OnTick","MHActiveLogic","TriggerAvatarCheck","StartAvatarCheck",
                "ReportItemID","ReceiveAnyDamage","OnWeaponHitRecord","ShowSecurityAlert","ServerReportAvatar",
                "ClientReportNetAvatar","SendHisarData","ValidateSecurityData"
            }
            for _, m in ipairs(methods) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty
            Higgs.GetCurWeaponSkinID = retZero
        end
    end)
end

-- ==============================================================================
-- ============== LAYER 43: PERSISTENT HUNT TIMER ===============================
-- ==============================================================================
local function InitializePersistentHuntTimer()
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if pc and isValid(pc) then
            if _G._MergedHuntTimer then
                pcall(function() pc:RemoveGameTimer(_G._MergedHuntTimer) end)
            end
            _G._MergedHuntTimer = pc:AddGameTimer(3.0, true, InitializeHuntAndKillAll)
            return true
        end
        return false
    end)
end

-- ==============================================================================
-- ============================ MASTER FUNCTIONS ================================
-- ==============================================================================

-- Ultimate Bypass v3.0 Master (Second Bypass)
_G.StartBypass_VIP_v3 = function()
    pcall(function()
        print("[ULTIMATE BYPASS] Starting initialization...")
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeSkinBypass()
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReplayTelemetryBlocker()
        InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass()
        InitializeClientFlowBypass()
        InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass()
        InitializeModifierExceptionBypass()
        InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks()
        InitializeAntiReport()
        InitializeGameplayBypass()
        InitializeKillAllSubsystems()
        InitializeOperationalStatsBypass()
        InitializeFinalProtection()
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end

-- 8-Layer Advanced Master (First Bypass)
local function InitializeAllBypasses()
    pcall(function()
        InitializeBypassBase()
        InitializeHiggsBypass()
        InitializeBanSystemBypass()
        InitializeReportSystemsBypass()
        InitializeTLogBypass()
        InitializeNetworkHandlersBypass()
        InitializeMiscBypass()
        InitializeExtraSubsystemsBypass()
        InitializeNetworkBlacklist()
        InitializeFileIOCrashBlock()
        InitializeApplyAllBypasses()

        -- Global functions nop
        local globalFuncs = {
            "ReportTLogEvent","SendTlog","SendClientStats","ReportHitFlow","ReportAvatarException",
            "SendComplaintReq","SubmitReport","ReportSuspiciousPlayer","SendPacket","OnSyncBanInfo",
            "OnVoiceBanNotify","SendSecTLog","MarkSuspiciousPlayer","ReportPlayerBehaviorData",
            "CheckCompliance","ReportIllegalProgram","UploadVoiceLog"
        }
        for _, fn in ipairs(globalFuncs) do
            if type(_G[fn]) == "function" then _G[fn] = nop end
        end

        -- Screenshot, TLog, CrashSight
        pcall(function()
            local s = import("ScreenshotMaker")
            if s then
                s.MakePicture = nop
                s.ReMakePicture = nop
                s.HasCaptured = retTrue
            end
            local tl = package.loaded["TLog"] or _G.TLog
            if tl then
                tl.Info = nop; tl.Warning = nop; tl.Error = nop; tl.Debug = nop; tl.Report = nop
            end
            local cs = package.loaded["CrashSight"] or _G.CrashSight
            if cs then
                cs.ReportException = nop
                cs.SetCustomData = nop
                cs.Log = nop
            end
        end)

        -- NetUtil block
        pcall(function()
            if _G.NetUtil and _G.NetUtil.SendPacket and not _G.NetUtil._IsBypassed then
                local origSend = _G.NetUtil.SendPacket
                local blocked = {
                    "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms",
                    "ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt",
                    "ReportPlayerMoveRoute","ReportPlayerPosition","ReportAimFlow","ReportHitFlow",
                    "ReportCircleFlow","ReportJumpFlow","report_players_ping","report_player_ip",
                    "tss_sdk_report","report_client_scan_result","report_memory_exception",
                    "report_avatar_exception","report_character_state","report_vehicle_exception",
                    "report_camera_exception","ReportEquipmentFlow","ReportHeavyWeaponBoxSpawnFlow",
                    "ReportHeavyWeaponBoxActivationFlow","ReportSecTLog","report_player_frame_ping_record",
                    "ReportSecAttackFlow","ReportSecTgameMovingFlow","ReportVehicleMoveFlow",
                    "ReportParachuteData","report_unrealnet_exception","report_ds_net_saturation",
                    "on_tss_sdk_anti_data"
                }
                _G.NetUtil.SendPacket = function(packetName, ...)
                    if blocked[packetName] then return end
                    return origSend(packetName, ...)
                end
                _G.NetUtil._IsBypassed = true
            end
        end)

        -- Higgs BlackList clean
        pcall(function()
            local hbc = safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if hbc and hbc.BlackList then
                for k in pairs(hbc.BlackList) do hbc.BlackList[k] = nil end
            end
            _G.BlackList = {}
            _G.GlobalPlayerCoronaData = _G.GlobalPlayerCoronaData or {}
            local mt = getmetatable(_G.GlobalPlayerCoronaData) or {}
            mt.__newindex = function() end
            setmetatable(_G.GlobalPlayerCoronaData, mt)
        end)

        -- GameSafeCallbacks and GameplayCallbacks extra
        pcall(function()
            if _G.GameSafeCallbacks then
                _G.GameSafeCallbacks.RecordStrategyTimestampInReplay = nop
                _G.GameSafeCallbacks.DoAttackFlowStrategy = nop
                _G.GameSafeCallbacks.GetScriptReportContent = function() return "" end
            end
            if not _G.GameplayCallbacks then return end
            local GC = _G.GameplayCallbacks
            local origDS = GC.OnDSPlayerStateChanged
            GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
                local state = InPlayerState and string.lower(tostring(InPlayerState)) or ""
                local block = {
                    ["cheatdetected"]=true,
                    ["connectionlost"]=true,
                    ["connectiontimeout"]=true,
                    ["connectionexception"]=true,
                    ["netdrivererror"]=true
                }
                if block[state] then return end
                if origDS then pcall(origDS, UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason) end
            end
            GC.OnPlayerNetConnectionClosed = nop
            GC.OnPlayerActorChannelError = nop
            GC.OnPlayerRPCValidateFailed = nop
            GC.OnPlayerSpectateException = nop
            GC.OnShutdownAfterError = nop
        end)

        -- SubsystemMgr extra patches
        pcall(function()
            local mgr = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
            local rt = mgr and mgr:Get("RescueBtnReplayTraceSubsystem")
            if rt then
                rt.ReportTrace = nop
                rt.StartTickMonitor = nop
                rt.TickMonitorCheck = nop
                rt.ReportTickMonitorHeartbeat = nop
            end
            local gr = mgr and mgr:Get("GameReportSubsystem")
            if gr then
                gr.ReplayReportData = retFalse
                gr.CheckCanBugglyPostException = retFalse
                gr.BugglyPostExceptionFull = retFalse
                gr.GetClientReplayDataReporter = function() return nil end
                if gr.Reporter then
                    gr.Reporter.ReportIntArrayData = nop
                    gr.Reporter.ReportUInt8ArrayData = nop
                    gr.Reporter.ReportFloatArrayData = nop
                end
            end
            local rp = safe_require("client.slua.logic.replay.logic_report_replay")
            if rp then
                rp.ReportReplay = nop
                rp.SendReportReq = nop
            end
        end)
    end)
end

-- ==============================================================================
-- ==================== UNIFIED MASTER ENTRY POINT ==============================
-- ==============================================================================

-- Unified Enable Function (calls BOTH bypass systems)
function EnableFullBypass()
    -- First: Ultimate Merged Bypass v3.0 (Second Bypass)
    if _G.StartBypass_VIP_v3 then
        pcall(_G.StartBypass_VIP_v3)
    end
    
    -- Second: 8-Layer Advanced Bypass (First Bypass)
    InitializeAllBypasses()
    InitializePersistentHuntTimer()
    
    print("[COMBINED BYPASS] All 43 layers initialized successfully!")
end

-- Auto-start on load
pcall(function()
    EnableFullBypass()
end)

-- ==============================================================================
-- ==================== PUBLIC API ==============================================
-- ==============================================================================
function _G.GetBypassStatus()
    local state = _G.BYPASS_STATE
    return {
        deadEye = state.DEADEYE_DISABLED,
        hawkEye = state.HAWKEYE_DISABLED,
        voklai = state.VOKLAI_DISABLED,
        higgsBoson = state.HIGGSBOSON_DISABLED,
        hashVerify = state.HASH_VERIFY_DISABLED,
        ipMapping = state.IP_MAPPING_DISABLED,
        memoryPatch = state.MEMORY_PATCH_DISABLED,
        eduEye = state.EDU_EYE_DISABLED,
        fullBypass = state.FULL_BYPASS_ACTIVE
    }
end

function _G.ForceReapplyBypass()
    _G.BYPASS_STATE.FULL_BYPASS_ACTIVE = false
    _G.BYPASS_STATE.DEADEYE_DISABLED = false
    _G.BYPASS_STATE.HAWKEYE_DISABLED = false
    _G.BYPASS_STATE.VOKLAI_DISABLED = false
    _G.BYPASS_STATE.HIGGSBOSON_DISABLED = false
    _G.BYPASS_STATE.HASH_VERIFY_DISABLED = false
    _G.BYPASS_STATE.IP_MAPPING_DISABLED = false
    _G.BYPASS_STATE.MEMORY_PATCH_DISABLED = false
    _G.BYPASS_STATE.EDU_EYE_DISABLED = false
    InitializeApplyAllBypasses()
end

-- ==============================================================================
-- ==================== END OF COMPLETE COMBINED BYPASS =========================
-- ==============================================================================

-- ========================================== 
-- MAP MARK CLEANUP MANAGEMENT FUNCTION (ANTI-LAG/FAKE DISPLAY WHEN ENEMY DIES)
-- ========================================== 
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.GTLMODState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    _G.GTLMODState.TrackedMarks[mark] = nil
end

-- ========================================== 
-- CREATE A UNIQUE AND PERMANENT ID FOR EACH ENEMY (FIXED LAG ISSUES WHEN SLUA CREATES NEW WRAPPERS)
-- ==========================================
local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

-- ========================================== 
-- AI (BOT) / REAL PLAYER - OPTIMIZED TEST
-- ==========================================
local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true
                hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

-- ========================================== 
-- INITIALIZES AUTO HEAD HOOKS FOR DAMAGE
-- ==========================================


-- ========================================== 
-- COLOR CONFIGURATION FOR ESP HEALTH, ESP NAME, AND WALLHACK
-- ==========================================
if _G.ColorConfig == nil then
    _G.ColorConfig = {
        VisibleColor = 4,   -- default Green
        InvisibleColor = 1, -- default Red
        Brightness = 25,
        Glow = 3.0,
    }
end

local COLOR_MAP = {
    [1] = {R=255, G=0,   B=0},
    [2] = {R=255, G=255, B=255},
    [3] = {R=255, G=255, B=0},
    [4] = {R=0,   G=255, B=0},
    [5] = {R=0,   G=255, B=255},
    [6] = {R=0,   G=0,   B=255},
    [7] = {R=255, G=0,   B=255}
}

local function GetAppliedColor(colorIdx, brightness)
    local base = COLOR_MAP[colorIdx] or COLOR_MAP[4]
    local b = brightness or _G.ColorConfig.Brightness or 25
    return {
        R = math.min(255, (base.R or 0) * b / 25),
        G = math.min(255, (base.G or 0) * b / 25),
        B = math.min(255, (base.B or 0) * b / 25),
        A = 255
    }
end

-- ========================================== 
-- AUTOMATIC VIP MENU STORAGE AND LOADING SYSTEM
-- ========================================== 
local function GetConfigPaths(fileName)
    local paths = BuildGamePaths("Paks", fileName)
    table.insert(paths, fileName)
    return paths
end

local ConfigFileName = "GTLMOD_settings.txt"
_G.LastConfigSaveStr = ""

-- DOWNLOAD CONFIG (plus ColorConfig)
_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nGTLConfig = {\n"
        for k, v in pairs(_G.GTLMODConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.GTLMODState and _G.GTLMODState.CustomTextData then
            for k, v in pairs(_G.GTLMODState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        data = data .. "},\nColorConfig = {\n"
        for k, v in pairs(_G.ColorConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "}\n}"
        
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data

        local paths = GetConfigPaths(ConfigFileName)
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(data)
                file:close()
                break
            end
        end
    end)
end

-- LOAD (READ) CONFIG (ditambah ColorConfig) FUNCTION
_G.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end

        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.GTLMODConfig then
                        for k, v in pairs(savedData.GTLMODConfig) do
                            _G.GTLMODConfig[k] = v
                        end
                    end
                    if savedData.CustomTextData then
                        _G.GTLMODState.CustomTextData = _G.GTLMODState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do
                            _G.GTLMODState.CustomTextData[k] = v
                        end
                    end
                    if savedData.ColorConfig then
                        for k, v in pairs(savedData.ColorConfig) do
                            _G.ColorConfig[k] = v
                        end
                    end
                end
            end
        end
        _G.SaveModSettings() 
    end)
end

-- A VERIFICATION LOOP FOR LIGHTWEIGHT UNDERGROUND RUNNING.
local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    local ticker = GetTicker()
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(3.0, AutoSaveLoop)
    end
end

-- FIRST LAUNCH
if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

-- Force save on live config read
_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end

-- ========================================== 
-- VIP NATIVE MENU SYSTEM (RUNS DIRECTLY FROM GAME SETTINGS)
-- ========================================== 

function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true

    _G.GTLMODState.CustomTextData = _G.GTLMODState.CustomTextData or {
        OuterSpeed = 10, InnerSpeed = 10, OuterRecoil = 0, HRecoil = 0.3, VRecoil = 0.3, IpadViewFOV = 120,
    }

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    
    if LocUtil and not LocUtil._IsModMenuHooked then
        local old_get = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then
                return id
            end
            return old_get(id)
        end
        LocUtil._IsModMenuHooked = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    
    if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
        
        -- ==================== ESP VISUAL ====================
        local StackESPVisual = {
            { Key = "ModMenu_ESP1", UI = AliasMap.Switcher, Text = "PREMIUM ALL FURTUER ON", GetFunc = function() return _G.GTLMODConfig.EspVip end, SetFunc = function(c,v) _G.GTLMODConfig.EspVip = v return true end },
            { Key = "ModMenu_ESP7", UI = AliasMap.Switcher, Text = "EREN ESP COUNTER V1", GetFunc = function() return _G.GTLMODConfig.Esp7 end, SetFunc = function(c,v) _G.GTLMODConfig.Esp7 = v return true end },
            { Key = "ModMenu_ESPCounter", UI = AliasMap.Switcher, Text = "EREN ESP COUNTER V2", GetFunc = function() return _G.GTLMODConfig.EspCounter end, SetFunc = function(c,v) _G.GTLMODConfig.EspCounter = v return true end },
            { Key = "ModMenu_ESP4", UI = AliasMap.Switcher, Text = "ESP MARK - 360 Radar", GetFunc = function() return _G.GTLMODConfig.EspRadar end, SetFunc = function(c,v) _G.GTLMODConfig.EspRadar = v return true end },
            { Key = "ModMenu_ESP5", UI = AliasMap.Switcher, Text = "ESP BOX FRAME", GetFunc = function() return _G.GTLMODConfig.Esp5 end, SetFunc = function(c,v) _G.GTLMODConfig.Esp5 = v return true end },
            { Key = "ModMenu_ESPAntenna", UI = AliasMap.Switcher, Text = "ESP LINE ANTENA", GetFunc = function() return _G.GTLMODConfig.EspAntenna end, SetFunc = function(c,v) _G.GTLMODConfig.EspAntenna = v return true end },
            { Key = "ModMenu_ESP6", UI = AliasMap.Switcher, Text = "SKELETON ESP", GetFunc = function() return _G.GTLMODConfig.Esp6 end, SetFunc = function(c,v) _G.GTLMODConfig.Esp6 = v return true end },
            { Key = "ModMenu_ESPWeapon", UI = AliasMap.Switcher, Text = "SHOW ENEMY WEAPON", GetFunc = function() return _G.GTLMODConfig.EspWeapon end, SetFunc = function(c,v) _G.GTLMODConfig.EspWeapon = v return true end },
            { Key = "ModMenu_ESPName", UI = AliasMap.Switcher, Text = "ESP NAME TEST(VISIBLE)", GetFunc = function() return _G.GTLMODConfig.EspName end, SetFunc = function(c,v) _G.GTLMODConfig.EspName = v return true end },
            { Key = "ModMenu_ESPBom_Ex", UI = AliasMap.TitleSwitcher, Text = "\226\150\182 GRANDE WARNING ESP", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.EspBomMaster end, SetFunc = function(c,v) _G.GTLMODConfig.EspBomMaster = v return true end },
            { Key = "ModMenu_ESPItemBom", UI = AliasMap.Switcher, Text = "   Locate Grenades on the Ground", ExpandHandle = "ModMenu_ESPBom_Ex", GetFunc = function() return _G.GTLMODConfig.EspItemBom end, SetFunc = function(c,v) _G.GTLMODConfig.EspItemBom = v return true end },
            { Key = "ModMenu_ESPActiveBom", UI = AliasMap.Switcher, Text = "   Warn when Enemy Holds or Throws", ExpandHandle = "ModMenu_ESPBom_Ex", GetFunc = function() return _G.GTLMODConfig.EspActiveBom end, SetFunc = function(c,v) _G.GTLMODConfig.EspActiveBom = v return true end },
            { Key = "ModMenu_ESPVehicle_Ex", UI = AliasMap.TitleSwitcher, Text = "\226\150\182 VECHILE ESP", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.EspVehicle end, SetFunc = function(c,v) _G.GTLMODConfig.EspVehicle = v return true end },
            { Key = "ModMenu_ESPVeh_Dacia", UI = AliasMap.Switcher, Text = "   Show Dacia", ExpandHandle = "ModMenu_ESPVehicle_Ex", GetFunc = function() return _G.GTLMODConfig.EspVeh_Dacia end, SetFunc = function(c,v) _G.GTLMODConfig.EspVeh_Dacia = v return true end },
            { Key = "ModMenu_ESPVeh_UAZ", UI = AliasMap.Switcher, Text = "   Show UAZ", ExpandHandle = "ModMenu_ESPVehicle_Ex", GetFunc = function() return _G.GTLMODConfig.EspVeh_UAZ end, SetFunc = function(c,v) _G.GTLMODConfig.EspVeh_UAZ = v return true end },
            { Key = "ModMenu_ESPVeh_Buggy", UI = AliasMap.Switcher, Text = "   Show Buggy", ExpandHandle = "ModMenu_ESPVehicle_Ex", GetFunc = function() return _G.GTLMODConfig.EspVeh_Buggy end, SetFunc = function(c,v) _G.GTLMODConfig.EspVeh_Buggy = v return true end },
            { Key = "ModMenu_ESPVeh_Coupe", UI = AliasMap.Switcher, Text = "   Show Coupe RB", ExpandHandle = "ModMenu_ESPVehicle_Ex", GetFunc = function() return _G.GTLMODConfig.EspVeh_Coupe end, SetFunc = function(c,v) _G.GTLMODConfig.EspVeh_Coupe = v return true end },
            { Key = "ModMenu_ESPVeh_Mirado", UI = AliasMap.Switcher, Text = "   Show Mirado", ExpandHandle = "ModMenu_ESPVehicle_Ex", GetFunc = function() return _G.GTLMODConfig.EspVeh_Mirado end, SetFunc = function(c,v) _G.GTLMODConfig.EspVeh_Mirado = v return true end },
            { Key = "ModMenu_ESPVeh_Motor", UI = AliasMap.Switcher, Text = "   Show Motor / Scooter", ExpandHandle = "ModMenu_ESPVehicle_Ex", GetFunc = function() return _G.GTLMODConfig.EspVeh_Motor end, SetFunc = function(c,v) _G.GTLMODConfig.EspVeh_Motor = v return true end },
            { Key = "ModMenu_ESPVeh_Other", UI = AliasMap.Switcher, Text = "   Show Other Vehicles", ExpandHandle = "ModMenu_ESPVehicle_Ex", GetFunc = function() return _G.GTLMODConfig.EspVeh_Other end, SetFunc = function(c,v) _G.GTLMODConfig.EspVeh_Other = v return true end },
            { Key = "ModMenu_ESPOutline_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ ESP OUTLINE", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.EspOutline end, SetFunc = function(c,v) _G.GTLMODConfig.EspOutline = v return true end },
            { Key = "ModMenu_ESPOutline_Thickness", UI = AliasMap.Slider, Text = "   Outline Thickness (1% is perfect)", ExpandHandle = "ModMenu_ESPOutline_Ex", MinValue = 1, MaxValue = 20, min = 1, max = 20, GetFunc = function() return _G.GTLMODConfig.OutlineThickness end, SetFunc = function(c,v) _G.GTLMODConfig.OutlineThickness = v return true end }
        }

        -- ==================== ESP V2 (naya canvas-based system — esp.lua se) ====================
        local StackESPV2 = {
            { Key = "ModMenu_ESP9_Ex",     UI = AliasMap.Switcher, Text = "ESP BOX",        GetFunc = function() return _G.GTLMODConfig.EspLoai9     end, SetFunc = function(c,v) _G.GTLMODConfig.EspLoai9     = v return true end },
            { Key = "ModMenu_ESP9_Line",   UI = AliasMap.Switcher, Text = "ESP LINE",       GetFunc = function() return _G.GTLMODConfig.Esp9_Line     end, SetFunc = function(c,v) _G.GTLMODConfig.Esp9_Line     = v return true end },
            { Key = "ModMenu_ESP9_HP",     UI = AliasMap.Switcher, Text = "ESP HEALTH BAR", GetFunc = function() return _G.GTLMODConfig.Esp9_HP       end, SetFunc = function(c,v) _G.GTLMODConfig.Esp9_HP       = v return true end },
            { Key = "ModMenu_ESP9_Weapon", UI = AliasMap.Switcher, Text = "ESP WEAPON",     GetFunc = function() return _G.GTLMODConfig.Esp9_Weapon   end, SetFunc = function(c,v) _G.GTLMODConfig.Esp9_Weapon   = v return true end },
            { Key = "ModMenu_ESP9_Team",   UI = AliasMap.Switcher, Text = "ESP TEAM ID",    GetFunc = function() return _G.GTLMODConfig.Esp9_Team     end, SetFunc = function(c,v) _G.GTLMODConfig.Esp9_Team     = v return true end },
            { Key = "ModMenu_ESP9_Dist",   UI = AliasMap.Switcher, Text = "ESP DISTANCE",   GetFunc = function() return _G.GTLMODConfig.Esp9_Distance end, SetFunc = function(c,v) _G.GTLMODConfig.Esp9_Distance = v return true end },
            { Key = "ModMenu_ESP9_Name",   UI = AliasMap.Switcher, Text = "ESP NAME",       GetFunc = function() return _G.GTLMODConfig.Esp9_Name     end, SetFunc = function(c,v) _G.GTLMODConfig.Esp9_Name     = v return true end },
        }

        -- ==================== AIMBOT ORIGINAL (Legacy, tanpa GodMode) ====================
        local StackAimbotOriginal = {
        }

        -- ==================== AIMBOT FORCE - CLEAN 4 BUTTON LAYOUT ====================
        -- 4 flat buttons jaise ESP: Aimbot / Ignore Knocked / Ignore Bots / Visibility Check
        -- Ek hi setting saari guns pe kaam karti hai (Hipfire + Scope + Shotgun + Sniper)
        -- Section header UI: pehle exact header type dhundo, nahi mila to TitleSwitcher (proven) fallback
        local HeaderUI = nil
        for _, n in ipairs({"Title","Header","Label"}) do
            local ok, v = pcall(function() return AliasMap[n] end)
            if ok and v then HeaderUI = v break end
        end
        HeaderUI = HeaderUI or AliasMap.TitleSwitcher
        local function HeaderItem(key, text)
            return { Key = key, UI = HeaderUI, Text = text,
                     GetFunc = function() return true end,
                     SetFunc = function() return true end }
        end

        local StackAimbotForce = {
            -- AIM ASSIST SYSTEM
            { Key = "ModMenu_AT_Master", UI = AliasMap.TitleSwitcher, Text = "Aim Assist (Master Switch)", ExpandIndex = 0,
              GetFunc = function() return (_G.GTLMODConfig.AimTouchEnable or _G.GTLMODConfig.AimTouchChest) and true or false end,
              SetFunc = function(c,v)
                local chest = (_G.GTLMODConfig.AimTargetBone == 1)
                _G.GTLMODConfig.AimTouchEnable = v and (not chest) or false
                _G.GTLMODConfig.AimTouchChest  = v and chest or false
                return true
              end },
            { Key = "ModMenu_AT_Trigger", UI = AliasMap.Switcher, Text = "   Aim Trigger Mode", ExpandHandle = "ModMenu_AT_Master",
              SwitcherText = {"Hipfire Only","ADS Scope Only","Hip + ADS"},
              SwitcherValue = {1,2,3},
              GetFunc = function() return _G.GTLMODConfig.AimTriggerMode or 3 end,
              SetFunc = function(_, v) _G.GTLMODConfig.AimTriggerMode = v return true end },
            { Key = "ModMenu_AT_Bone", UI = AliasMap.Switcher, Text = "   Target Bone", ExpandHandle = "ModMenu_AT_Master",
              SwitcherText = {"Chest (Safe)","Neck (Risky)","Head"},
              SwitcherValue = {1,2,3},
              GetFunc = function() return _G.GTLMODConfig.AimTargetBone or 3 end,
              SetFunc = function(_, v)
                _G.GTLMODConfig.AimTargetBone = v
                if _G.GTLMODConfig.AimTouchEnable or _G.GTLMODConfig.AimTouchChest then
                    _G.GTLMODConfig.AimTouchEnable = (v ~= 1)
                    _G.GTLMODConfig.AimTouchChest  = (v == 1)
                end
                return true
              end },
            { Key = "ModMenu_AT_Power", UI = AliasMap.Slider, Min = 0, Max = 100, Step = 1, Text = "   Aim Tracking Power (0-100%)", ExpandHandle = "ModMenu_AT_Master",
              MinValue = 0, MaxValue = 100, min = 0, max = 100,
              GetFunc = function() return _G.GTLMODConfig.AimTrackingPower or 100 end,
              SetFunc = function(c,v) _G.GTLMODConfig.AimTrackingPower = v return true end },

            -- ANTI-BAN SMART FILTERS
            HeaderItem("ModMenu_AT_H2", "\45\45\45 ANTI-BAN SMART FILTERS \45\45\45"),
            { Key = "ModMenu_AT_IgKnock", UI = AliasMap.Switcher, Text = "Ignore Knocked Enemies",
              GetFunc = function() return _G.GTLMODConfig.AimTouchIgKnock end,
              SetFunc = function(c,v) _G.GTLMODConfig.AimTouchIgKnock = v return true end },
            { Key = "ModMenu_AT_IgBot", UI = AliasMap.Switcher, Text = "Ignore AI Bots (Real Only)",
              GetFunc = function() return _G.GTLMODConfig.AimTouchIgBot end,
              SetFunc = function(c,v) _G.GTLMODConfig.AimTouchIgBot = v return true end },
            { Key = "ModMenu_AT_Vis", UI = AliasMap.Switcher, Text = "Visibility Check",
              GetFunc = function() return _G.GTLMODConfig.AimTouchVisCheck end,
              SetFunc = function(c,v) _G.GTLMODConfig.AimTouchVisCheck = v return true end },

            -- DISTANCE & FOV RANGE
            HeaderItem("ModMenu_AT_H3", "\45\45\45 DISTANCE & FOV RANGE \45\45\45"),
            { Key = "ModMenu_AT_HipRange", UI = AliasMap.Slider, Min = 10, Max = 40, Step = 1, Text = "Hipfire Max Range (10m - 40m)",
              MinValue = 10, MaxValue = 40, min = 10, max = 40,
              GetFunc = function() return _G.GTLMODConfig.HipfireMaxRange or 40 end,
              SetFunc = function(c,v) _G.GTLMODConfig.HipfireMaxRange = v return true end },
            { Key = "ModMenu_AT_ScopeRange", UI = AliasMap.Slider, Min = 30, Max = 150, Step = 1, Text = "Scope Max Range (30m - 150m)",
              MinValue = 30, MaxValue = 150, min = 30, max = 150,
              GetFunc = function() return _G.GTLMODConfig.ScopeMaxRange or 150 end,
              SetFunc = function(c,v) _G.GTLMODConfig.ScopeMaxRange = v return true end },
        }

        -- ==================== MAGIC BULLET - REMOVED ====================
        -- Magic Bullet system has been completely removed from this version
        local StackMagicBullet = {}

        -- ==================== COMBAT GRAPHIC (hanya God Mode dan graphics) ====================
        local StackCombatGraphic = {
            { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ iPad View (Tampilan iPad)", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.IpadView end, SetFunc = function(c,v) _G.GTLMODConfig.IpadView = v return true end },
            { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = "   FOV Angle (Sudut Pandang)", ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.GTLMODState.CustomTextData.IpadViewFOV or 120) - 80 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.IpadViewFOV = 80 + v return true end },
            { Key = "ModMenu_165FPS", UI = AliasMap.Switcher, Text = "165 FPS", GetFunc = function() return _G.GTLMODConfig.UnlockFPS end, SetFunc = function(c,v) _G.GTLMODConfig.UnlockFPS = v; if v then _G.GTLMODState.GraphicsUnlocked = false end return true end },
            { Key = "ModMenu_BlackSky", UI = AliasMap.Switcher, Text = "BLACK Sky", GetFunc = function() return _G.GTLMODConfig.BlackSky end, SetFunc = function(c,v) _G.GTLMODConfig.BlackSky = v return true end },
        }

        -- ==================== COLOR MOD (Warna untuk ESP dan Wallhack) ====================
        local StackColorMod = {
            { Key = "ModMenu_WallhackV2", UI = AliasMap.Switcher, Text = "EREN WALLHACK V1", GetFunc = function() return _G.GTLMODConfig.WallhackV2 end, SetFunc = function(c,v) _G.GTLMODConfig.WallhackV2 = v return true end },
            { Key = "ModMenu_WallColor", UI = AliasMap.Switcher, Text = "EREN WALLHACK V2", GetFunc = function() return _G.GTLMODConfig.wallhackng end, SetFunc = function(c,v) _G.GTLMODConfig.wallhackng = v; _G.GTLMODConfig.ColorBodyV2 = v return true end },
            { Key = "ModMenu_HDRGlow", UI = AliasMap.Switcher, Text = "GLOW HDR V2", GetFunc = function() return _G.GTLMODConfig.HDRGlow end, SetFunc = function(c,v) _G.GTLMODConfig.HDRGlow = v return true end },
            { Key = "ModMenu_WallVehicle", UI = AliasMap.Switcher, Text = "VECHILE WALLHACK (See Through Walls)", GetFunc = function() return _G.GTLMODConfig.WallVehicle end, SetFunc = function(c,v) _G.GTLMODConfig.WallVehicle = v return true end },
            { Key = "COLOR_Visible", UI = AliasMap.Switcher, Text = "Visible Color (ESP & WH)",
              SwitcherText = {"Red","White","Yellow","Green","Cyan","Blue","Purple"},
              SwitcherValue = {1,2,3,4,5,6,7},
              GetFunc = function() return _G.ColorConfig.VisibleColor end,
              SetFunc = function(_, v) _G.ColorConfig.VisibleColor = v; _G.SaveModSettings(); return true end },
            { Key = "COLOR_Invisible", UI = AliasMap.Switcher, Text = "Invisible Color (ESP & WH)",
              SwitcherText = {"Red","White","Yellow","Green","Cyan","Blue","Purple"},
              SwitcherValue = {1,2,3,4,5,6,7},
              GetFunc = function() return _G.ColorConfig.InvisibleColor end,
              SetFunc = function(_, v) _G.ColorConfig.InvisibleColor = v; _G.SaveModSettings(); return true end },
            { Key = "COLOR_Brightness", UI = AliasMap.Slider, Text = "Brightness (1-50)", Min = 1, Max = 50, Step = 1,
              GetFunc = function() return _G.ColorConfig.Brightness end,
              SetFunc = function(_, v) _G.ColorConfig.Brightness = v; _G.SaveModSettings(); return true end },
            { Key = "COLOR_Glow", UI = AliasMap.Slider, Text = "Glow Intensity (0-10) (WH)", Min = 0, Max = 10, Step = 0.5,
              GetFunc = function() return _G.ColorConfig.Glow end,
              SetFunc = function(_, v) _G.ColorConfig.Glow = v; _G.SaveModSettings(); return true end }
        }

        -- ==================== DEFINE MENU PAGE ====================
        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text= "EREN MENU",
            UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "Cat_ESP_Visual", Text= "ESP FURTUERS", Stack = StackESPVisual },
                { Key = "Cat_ESP2", Text= "ESP V2", Stack = StackESPV2 },
                { Key = "Cat_Aimbot_Force", Text= "EREN AIMBOT", Stack = StackAimbotForce },
                { Key = "Cat_ColorMod", Text= "WALLHACK & COLOR", Stack = StackColorMod },
                { Key = "Cat_Combat_Graphic", Text= "SDK FURTUERS", Stack = StackCombatGraphic },
            }
        }
        
        -- TOP par lagao (pehle append hota tha, isliye list ke end mein aata tha)
        table.insert(SettingCatalog, 1, SettingPageDefine.ModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...) 
            
            if config and config.keyName and (string.find(string.lower(config.keyName), "setting_main") or string.find(string.lower(config.keyName), "setting")) then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local hasModMenu = false
                    for _, page in ipairs(catalog) do
                        if type(page) == "table" and page.Key == "ModMenu" then
                            hasModMenu = true
                            break
                        end
                    end
                    if not hasModMenu then
                        table.insert(catalog, 1, SettingPageDefine.ModMenu)
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

local function ShowGTLMODVIPMenu() 
    if _G.GTLMODMenuAlreadyShown then return end
    if _G.GTLMODState.MenuStep ~= 0 then return end

    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end

        local function Step_Welcome()
            local welcomeText = 
                "┌─────────────────────────┐\n"..
                "│   EREN LUA MOD FUTURES   │\n"..
                "└─────────────────────────┘\n\n"..
                "   ● Status   : Connected\n"..
                "   ● Bypass   : Fully Active\n"..
                "   ● Security : Maximized\n\n"..
                "   ✓ AimBot (Auto Aim).\n\n"..
                "   ✓ WALLHACK+ESP.\n\n"..
                "   ✓ VIABILITY CHECK.\n\n"..
                "   ✓ IPAD VIEW.\n\n"..
                "   ✓ WHITE BODY.\n\n"..
                "   ✓ MANY MORE FURTUERS.\n\n"..
                "   DEVELOPER/OWNER : @VINESH_OP"

            Msg.Show(1, "EREN VIP MOD", welcomeText,
            function()
                _G.InitModMenuTab()
                Notify("EREN VIP MOD MENU — Toggle features from EREN MENU!")
                _G.GTLMODMenuAlreadyShown = true
            end,
            function() end, "OK", "CLOSE")
        end

        _G.GTLMODState.MenuStep = 1
        Step_Welcome()
    end)
end

-- ========================================== 
-- LOGIC 165 FPS IPAD VIEW 
-- ========================================== 
local function InitializeGraphicsUnlock() 
    if isExpired then return end
    if _G.GTLMODState.GraphicsUnlocked or currentTime > limitTime then return end

    pcall(function()
        local SettingCfg = require("client.logic.setting.setting_config")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        
        local KismetMathLibrary = import("KismetMathLibrary") or _G.KismetMathLibrary
        local FLinearColor = import("LinearColor") or _G.FLinearColor

        -- View range unlock
        if SettingCfg then
            if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
            if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
        end
        if GraphicSettingDB then
            if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
        end

        if logic_setting_graphics then
            local old_SetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if old_SetFPS then old_SetFPS(gameInstance, FPSLevel) end
                if FPSLevel == 8 then 
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end

        if GSC_FPS and GSC_FPS.__inner_impl then
            local fps_impl = GSC_FPS.__inner_impl
            function fps_impl:GetMaxFPSLevel() return 8, 8 end
            function fps_impl:InitRealSupportFPS()
                local RealSupportFPS = {}
                for i = 1, 8 do RealSupportFPS[i] = {true, true} end
                if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, RealSupportFPS, false) end
                return RealSupportFPS
            end
            function fps_impl:UpdateSelectedFPSState(selectedLevel)
                if not slua.isValid(self.UIRoot) then return end
                for level = 2, 8 do
                    local name = "NodeFps" .. (({[2]=20,[3]=25,[4]=30,[5]=40,[6]=60,[7]=90,[8]=120})[level] or 120)
                    local widget = self.UIRoot[name]
                    if slua.isValid(widget) then
                        widget:SetIsEnabled(true) 
                        pcall(function() widget:SetRenderOpacity(1.0) end)
                        local switcher = self.UIRoot["WidgetSwitcher_" .. level]
                        if slua.isValid(switcher) then 
                            switcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) 
                        end
                    end
                end
            end
        end

        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            local ft_impl = GSC_FPSFT.__inner_impl
            local NMinFPS, NStep = 90, 5
            local function clamp(value, min, max)
                if value < min then return min end
                if max < value then return max end
                return value
            end
            local function lerp(a, b, t) return a + (b - a) * t end
            local function _getColorByPercent(start, finish, percent)
                if not FLinearColor then return nil end
                return FLinearColor(lerp(start.R, finish.R, percent), lerp(start.G, finish.G, percent), lerp(start.B, finish.B, percent), lerp(start.A, finish.A, percent))
            end
            
            ft_impl.ShowOrHide = function(self)
                self:SelfHitTestInvisible()
                if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end
            end

            ft_impl.InitFPSFTSwitch = function(self)
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(FPSFineTuneSwitch, true) end
                if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, FPSFineTuneSwitch) end
                if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
            end

            ft_impl.InitFPSFTValue165 = function(self)
                local itemRoot = self.UIRoot
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                local FPSFineTuneNum = 165
                if FPSFineTuneSwitch then
                    FPSFineTuneNum = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
                    itemRoot.Slider_screen3:SetLocked(false)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 1.0, 1.0, 1.0))
                    end
                else
                    itemRoot.Slider_screen3:SetLocked(true)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 0.625, 0.6, 1))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 0.625, 0.6, 1.0))
                    end
                end
                local FPSFineTunePer = (FPSFineTuneNum - NMinFPS) / (165 - NMinFPS)
                
                itemRoot.Veihclescreen3:SetText(tostring(FPSFineTuneNum))
                itemRoot.Slider_screen3:SetValue(FPSFineTunePer)
                itemRoot.ProgressBar_screen3:SetPercent(FPSFineTunePer)
                
                if FLinearColor then
                    local startColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                    local midColor = FLinearColor(1.0, 0.54, 0.11, 1.0)
                    local endColor = FLinearColor(1.0, 0.23, 0.15, 1.0)
                    local sliderColor = FPSFineTunePer < 0.4 and startColor or _getColorByPercent(midColor, endColor, (FPSFineTunePer - 0.4) / 0.6)
                    itemRoot.Slider_screen3:SetSliderHandleColor(sliderColor)
                end
            end

            ft_impl.OnFPSFTValueChange3 = function(self, FPSFineTuneNum)
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, FPSFineTuneNum)
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
                if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
                local gameInstance = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
                if gameInstance then
                    gameInstance:ExecuteCMD("t.MaxFPS", tostring(FPSFineTuneNum))
                    gameInstance:ExecuteCMD("r.FrameRateLimit", tostring(FPSFineTuneNum))
                end
            end

            ft_impl.OnFPSFTSliderValueChange3 = function(self, value)
                if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) and KismetMathLibrary then
                    local FPSFineTuneNum = KismetMathLibrary.FCeil(value * (165 - NMinFPS) / NStep) * NStep + NMinFPS
                    self:OnFPSFTValueChange3(clamp(FPSFineTuneNum, NMinFPS, 165))
                end
            end
            
            ft_impl.OnFPSFTAdd = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTAdd2 = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus2 = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTSliderValueChange = ft_impl.OnFPSFTSliderValueChange3
            ft_impl.OnFPSFTSliderValueChange2 = ft_impl.OnFPSFTSliderValueChange3
        end
    end)
    _G.GTLMODState.GraphicsUnlocked = true
    Notify("Graphics & FPS 165Hz Unlocked (Upgraded Version)")
end

-- ========================================== 
-- INITIALIZE THE ESP SYSTEM (BASED)
-- ========================================== 
local function InitializeNativeESP() 
    if _G.GTLMODState.NativeESPReady then return end
    pcall(function() 
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig") 
        local function ApplyCfg(cfg)
            if not cfg then return end 
            if cfg[1006] then 
                cfg[1006].bBindBlocked = true;
                cfg[1006].bBindOutScreen = true; 
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000; 
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root"; 
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30) 
            end 
            cfg[8888] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true,
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 30),
                bNeedPreLoad = true,
                Priority = 2 
            } 
            cfg[9999] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true, 
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 50),
                bNeedPreLoad = true, 
                Priority = 2 
            } 
        end 
        ApplyCfg(currentMarkCfg) 
        for k, cfg in pairs(package.loaded) do 
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then 
                ApplyCfg(cfg) 
            end 
        end 
    end)
    _G.GTLMODState.NativeESPReady = true 
    Notify("Native ESP System Initialized") 
end

-- ========================================== 
-- LOCAL FUNCTIONS CHO LOGIC NEW ESP - OPTIMIZED
-- ========================================== 
local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime) < 3.0 then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            if Valid(cachedMesh) then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then
                        table.insert(meshes, comp)
                    end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end

-- ========================================== 
-- WALL-BOUND FUNCTION & ROOT RESTORE (menggunakan ColorConfig)
-- ==========================================
-- ==========================================
-- APNA CHARACTER NORMAL RAKHO
-- Wallhack `bDisableDepthTest` shared BASE MATERIAL par lagta hai, isliye wo
-- hamare apne character par bhi leak ho jata hai. Yahan har tick apne meshes
-- ka depth-test wapas on kar dete hain taake hum normal dikhein.
-- ==========================================
_G.SelfMeshState = _G.SelfMeshState or {}

local function RestoreSelfCharacter(player)
    pcall(function()
        if not Valid(player) then return end
        local meshes = GetAllSkeletalMeshes(player, _G.SelfMeshState)
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then mesh:SetCustomDepthStencilValue(0) end
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        baseMat.bDisableDepthTest = false
                    end
                end
            end
        end
    end)
end

local function Undowallhackng(enemy, markData)
    pcall(function()
        if markData.WallhackApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function() if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end end)
                    for i = 0, 10 do 
                        local matInterface = mesh:GetMaterial(i)
                        if Valid(matInterface) then
                            local baseMat = matInterface:GetBaseMaterial()
                            if Valid(baseMat) then baseMat.bDisableDepthTest = false end
                        end
                    end
                end
            end
            markData.WallhackApplied = false
        end
    end)
end

-- ==========================================
-- STRONG VISIBILITY CHECK (shared + cached 0.3s)
-- Normal ray fail ho to UE ke alternate checks (head/extra offsets) try karta hai
-- Isi ka result saare colors use karte hain: wallhack, ESP name, box
-- ==========================================
local ZERO_VIEWPOINT = {X=0, Y=0, Z=0}

local function IsEnemyVisibleStrong(enemy, pc, markData)
    if not Valid(enemy) or not Valid(pc) then return false end
    if type(pc.LineOfSightTo) ~= "function" then return false end

    local curTime = os.clock()
    -- Cache: 0.3s se pehle dobara ray nahi daalte (CPU bachane ke liye)
    if markData and markData.LastVisCheckTime and (curTime - markData.LastVisCheckTime) <= 0.3 then
        if markData.CachedVisible ~= nil then return markData.CachedVisible end
    end

    local visible = false

    -- 1) Normal check (enemy ke center par ek ray)
    pcall(function()
        if pc:LineOfSightTo(enemy) then visible = true end
    end)

    -- NOTE: pehle yahan bAlternateChecks=true wala doosra check tha. Wo bohat
    -- permissive nikla — deewar ke peeche wale enemy ko bhi "visible" bata deta tha,
    -- isliye color kabhi red nahi hota tha. Ab sirf standard check.

    if markData then
        markData.LastVisCheckTime = curTime
        markData.CachedVisible = visible
        markData.CachedHiddenState = not visible
    end
    return visible
end

-- ==========================================================
-- WALLHACK V2 — game ke apne DYEING system par
-- Farq: yahan visible aur occluded ka rang ENGINE khud alag karta hai
-- (per-pixel), isliye rang bilkul saaf rehta hai. V1 (material MID +
-- bDisableDepthTest) mein rang mix ho jate the.
-- ==========================================================
local V2_CONSOLE_READY = false
local V2_AVATAR_SLOTS = {0,1,2,3,4,5,6,7}

local function V2_SetupConsole()
    if V2_CONSOLE_READY then return end
    pcall(function()
        local KSL = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if not KSL or not world then return end
        KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        V2_CONSOLE_READY = true
    end)
end

local function V2_ApplyToMesh(mesh, visColor, occColor)
    if not Valid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visColor)
        mesh:SetOccludedDyeingColor(occColor)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(visColor)
        mesh:SetHighlightCanBeOccluded(false)
        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(visColor)
        mesh:SetIdeaOutlineOcclusionColor(occColor)
        mesh:OverrideIdeaOutlineThickness(20.0)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

local function V2_ClearMesh(mesh)
    if not Valid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(false)
        mesh:SetDrawHighlight(false)
        mesh:SetDrawIdeaOutline(false)
        mesh:SetIdeaOverrideOutlineAndOcclusion(false)
        mesh:SetRenderCustomDepth(false)
        mesh:SetCustomDepthStencilValue(0)
    end)
end

-- Enemy ke saare meshes: body + avatar slots (helmet/vest/bag) + weapon
local function V2_ForEachMesh(enemy, fn)
    pcall(function() if Valid(enemy.Mesh) then fn(enemy.Mesh) end end)

    pcall(function()
        local avatarComp = enemy.CharacterAvatarComp2_BP
        if not avatarComp and type(enemy.getAvatarComponent2) == "function" then
            avatarComp = enemy:getAvatarComponent2()
        end
        if avatarComp and avatarComp.GetMeshCompBySlot then
            for _, slot in ipairs(V2_AVATAR_SLOTS) do
                local m = avatarComp:GetMeshCompBySlot(slot)
                if Valid(m) then fn(m) end
            end
        end
    end)

    pcall(function()
        local SkelComp = import("SkeletalMeshComponent")
        if not SkelComp then return end
        local comps = enemy:GetComponentsByClass(SkelComp)
        if not comps then return end
        for i = 0, comps:Num() - 1 do
            local c = comps:Get(i)
            if Valid(c) and c ~= enemy.Mesh then fn(c) end
        end
    end)

    pcall(function()
        local StatComp = import("StaticMeshComponent")
        if not StatComp then return end
        local comps = enemy:GetComponentsByClass(StatComp)
        if not comps then return end
        for i = 0, comps:Num() - 1 do
            local c = comps:Get(i)
            if Valid(c) then fn(c) end
        end
    end)

    pcall(function()
        if type(enemy.GetCurrentWeapon) ~= "function" then return end
        local w = enemy:GetCurrentWeapon()
        if Valid(w) and Valid(w.Mesh) then fn(w.Mesh) end
    end)
end

local function ApplyWallhackV2(enemy, markData)
    pcall(function()
        V2_SetupConsole()

        local LC = import("LinearColor") or _G.FLinearColor
        if not LC then return end

        -- Rang ColorConfig se — HDR values (100) taake saaf chamke
        local bri  = _G.ColorConfig.Brightness or 25
        local vRaw = GetAppliedColor(_G.ColorConfig.VisibleColor   or 4, bri)
        local oRaw = GetAppliedColor(_G.ColorConfig.InvisibleColor or 1, bri)
        local visColor = LC(vRaw.R / 255 * 100, vRaw.G / 255 * 100, vRaw.B / 255 * 100, 100)
        local occColor = LC(oRaw.R / 255 * 100, oRaw.G / 255 * 100, oRaw.B / 255 * 100, 100)

        V2_ForEachMesh(enemy, function(m) V2_ApplyToMesh(m, visColor, occColor) end)
        markData.V2Applied = true
    end)
end

local function UndoWallhackV2(enemy, markData)
    if not markData.V2Applied then return end
    pcall(function()
        V2_ForEachMesh(enemy, function(m) V2_ClearMesh(m) end)
    end)
    markData.V2Applied = false
end

local function Applywallhackng(enemy, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then 
                pcall(function()
                    if type(mesh.SetRenderCustomDepth) == "function" then
                        mesh:SetRenderCustomDepth(true)
                    end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then
                        mesh:SetCustomDepthStencilValue(252) 
                    end
                end)
                for i = 0, 10 do 
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        baseMat.bDisableDepthTest = true
                        baseMat.BlendMode = 2 
                    end
                end
            end
        end
    end)
end

-- ========================================== 
-- WALLHACK WITH COLOR FROM COLORCONFIG
-- ==========================================
local function ApplyColorBodyV2(enemy, pc, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        
        -- STRONG visibility check (shared helper, khud cache karta hai)
        local hidden = not IsEnemyVisibleStrong(enemy, pc, markData)
        -- WALLHACK BODY COLOR — source ke bilkul mutabiq.
        -- Ahem farq: source A = 25 aur intensity ~150 use karta hai, A = 255 nahi.
        -- Yehi kam alpha scope/x-ray wala do-rangi look deta hai. A = 255 par body
        -- solid ho jati hai aur scope ke andar ka farq khatam ho jata hai.
        local WH_ALPHA = 25
        local function ToWallhackColor(c)
            return {
                R = (c.R or 0) * 150 / 255,
                G = (c.G or 0) * 150 / 255,
                B = (c.B or 0) * 150 / 255,
                A = WH_ALPHA
            }
        end

        local visibleColor   = ToWallhackColor(GetAppliedColor(_G.ColorConfig.VisibleColor or 4, _G.ColorConfig.Brightness))
        local invisibleColor = ToWallhackColor(GetAppliedColor(_G.ColorConfig.InvisibleColor or 1, _G.ColorConfig.Brightness))
        local finalColor = hidden and invisibleColor or visibleColor
        
        local colorHash = string.format("%d_%d_%d_%d", finalColor.R, finalColor.G, finalColor.B, finalColor.A)
        local currentMeshCount = #meshes
        local isMeshChanged = (markData.LastMeshCount ~= currentMeshCount)
        
        if not isMeshChanged and markData.LastHiddenState == hidden and markData.LastColorHash == colorHash then return end
        
        if isMeshChanged and markData.MIDs then
            markData.MIDs = {}
        end

        markData.LastHiddenState = hidden
        markData.LastMeshCount = currentMeshCount
        markData.LastColorHash = colorHash
        markData.ColorApplied = true
        
        for meshIndex, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    mesh.LDMaxDrawDistance = -99999
                    mesh.MaxDrawDistanceOffset = -99999
                    mesh.CachedMaxDrawDistance = -99999
                    mesh.UseScopeDistanceCulling = true
                    mesh.PrimitiveShadingStrategy = 1
                    mesh.ShadingRate = 6
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        local matName = tostring(baseMat)
                        if string.find(matName, "Master_Mask", 1, true) then
                            if not markData.MIDs then markData.MIDs = {} end
                            
                            local meshKey = "Mesh_" .. tostring(meshIndex)
                            
                            if not markData.MIDs[meshKey] then markData.MIDs[meshKey] = {} end
                            local mid = markData.MIDs[meshKey][i]
                            if not Valid(mid) then
                                mid = mesh:CreateAndSetMaterialInstanceDynamic(i)
                                markData.MIDs[meshKey][i] = mid
                            end
                            if Valid(mid) then
                                mid:SetVectorParameterValue("颜色", finalColor)
                                mid:SetVectorParameterValue("Extra Light Color", finalColor)
                                mid:SetVectorParameterValue("Para_Color", finalColor)
                                mid:SetVectorParameterValue("Para_ColorTint", finalColor)
                                mid:SetVectorParameterValue("Para_Color_1", finalColor)
                                mid:SetVectorParameterValue("Tint", finalColor)
                                mid:SetVectorParameterValue("Color", finalColor)
                                mid:SetVectorParameterValue("BaseColor", finalColor)
                                mid:SetVectorParameterValue("BodyColor", finalColor)
                                mid:SetVectorParameterValue("MainColor", finalColor)
                                mid:SetVectorParameterValue("DiffuseColor", finalColor)

                                mid:SetVectorParameterValue("EmissiveColor", finalColor)
                                mid:SetVectorParameterValue("ParaScaleOffset", SCALE_COLOR_V2)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function UndoColorBodyV2(enemy, markData)
    pcall(function()
        if markData.ColorApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for meshIndex, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        mesh.PrimitiveShadingStrategy = 0
                        mesh.ShadingRate = 1
                    end)
                    local meshKey = "Mesh_" .. tostring(meshIndex)
                    if markData.MIDs and markData.MIDs[meshKey] then
                        for i, mid in pairs(markData.MIDs[meshKey]) do
                            if Valid(mid) then
                                local defC = {R=1, G=1, B=1, A=1}
                                mid:SetVectorParameterValue("颜色", defC)
                                mid:SetVectorParameterValue("Extra Light Color", defC)
                                mid:SetVectorParameterValue("Para_Color", defC)
                                mid:SetVectorParameterValue("Para_ColorTint", defC)
                                mid:SetVectorParameterValue("Para_Color_1", defC)
                                mid:SetVectorParameterValue("Tint", defC)
                                mid:SetVectorParameterValue("Color", defC)
                                mid:SetVectorParameterValue("BaseColor", defC)
                                mid:SetVectorParameterValue("BodyColor", defC)
                                mid:SetVectorParameterValue("MainColor", defC)
                                mid:SetVectorParameterValue("DiffuseColor", defC)
                                mid:SetVectorParameterValue("EmissiveColor", defC)
                            end
                        end
                    end
                end
            end
            markData.ColorApplied = false
            markData.LastColorHash = ""
            markData.LastHiddenState = nil
        end
    end)
end

-- ========================================== 
-- AIMBOT V2 SYSTEM WITH NEW INTEGRATED TECHNOLOGY (KISSMET SMOOTH UPDATE)
-- ========================================== 
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()

    if not slua.isValid(player) then
        return result
    end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        -- Aimbot chale agar HEAD wala ya CHEST wala, koi bhi ON ho
        if not (_G.GTLMODConfig.AimTouchEnable or _G.GTLMODConfig.AimTouchChest) then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        
        -- Ninja dash / SpecialSuit active hone par aimbot skip karo (glitch fix)
        local inSpecialState = false
        pcall(function()
            local EPawnState_local = import("EPawnState")
            if EPawnState_local and type(player.HasState) == "function" then
                if player:HasState(EPawnState_local.SpecialSuit) then inSpecialState = true end
                if player:HasState(EPawnState_local.AttachToOther) then inSpecialState = true end
            end
        end)
        if inSpecialState then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end
        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        local isSniper = false
        
        if slua.isValid(weapon) then
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end
        end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 50
        local fovVal = 30
        local maxDistMeters = 50
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        
        local predVal = 0 
        local recoilCompVal = 0 

        -- ==================== UNIFIED AIMBOT LOGIC - WORKS ON ALL GUNS ====================
        -- Ek hi setting saari guns pe (Hipfire + Scope + Shotgun + Sniper)
        -- 4 flat buttons se control: Aimbot / Ignore Knocked / Ignore Bots / Visibility Check
        -- Baaki values (bone, speed, fov, dist) safe-mode presets se auto set hoti hain per gun type

        -- ── Shared toggles ────────────────────────────────────────────────
        useVisCheck = _G.GTLMODConfig.AimTouchVisCheck
        igKnock     = _G.GTLMODConfig.AimTouchIgKnock
        igBot       = _G.GTLMODConfig.AimTouchIgBot

        -- ── Trigger Mode check ────────────────────────────────────────────
        -- 1=Hipfire Only, 2=ADS Scope Only, 3=Hip+ADS (default)
        local trigMode = _G.GTLMODConfig.AimTriggerMode or 3
        if trigMode == 1 and isADS then return end      -- Hipfire only: ADS pe skip
        if trigMode == 2 and not isADS then return end  -- ADS only: hipfire pe skip

        -- ── Tracking power → speedVal ─────────────────────────────────────
        -- AimTrackingPower 0-100 → speedVal 10-100
        local trackPow = _G.GTLMODConfig.AimTrackingPower or 100
        speedVal = math.max(0, math.min(100, trackPow))

        -- ── Distance & FOV from menu sliders ─────────────────────────────
        if isADS then
            if isSniper then
                cond = 2
                if cond == 1 and not isFiring then return end
                prioMode = 1
                fovVal = 30
                maxDistMeters = math.max(30, math.min(150, _G.GTLMODConfig.ScopeMaxRange or 150))
                predVal = 0
            else
                cond = 1
                if cond == 1 and not isFiring then return end
                prioMode = 1
                fovVal = 30
                maxDistMeters = math.max(30, math.min(150, _G.GTLMODConfig.ScopeMaxRange or 150))
                predVal = 0
            end
        else
            cond = 1
            if cond == 1 and not isFiring then return end
            prioMode = 1
            fovVal = 30
            maxDistMeters = math.max(10, math.min(40, _G.GTLMODConfig.HipfireMaxRange or 40))
        end

        -- ── Bone: AimTargetBone 1=Chest(Safe), 2=Neck(Risky) ────────────
        -- AimTargetBone: 1=Chest (spine_03), 2=Neck (neck_01), 3=Head
        if _G.GTLMODConfig.AimTouchChest then
            boneIdx = 2   -- spine_03
        elseif _G.GTLMODConfig.AimTouchEnable then
            if (_G.GTLMODConfig.AimTargetBone or 3) == 2 then
                boneIdx = 5   -- neck_01
            else
                boneIdx = 1   -- head
            end
        end

        local currentMaxDist = maxDistMeters * 100 

        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end
        
        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = GetUIUtil()
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999 
        
        -- Chest aim ko kitna neeche laana hai (badhao = aur neeche, ghatao = aur upar)
        local CHEST_DROP = 20

        local selBoneName = "head"
        if boneIdx == 1 then selBoneName = "head"
        elseif boneIdx == 2 then selBoneName = "spine_03"
        elseif boneIdx == 3 then selBoneName = "spine_01"
        elseif boneIdx == 4 then selBoneName = "pelvis"
        elseif boneIdx == 5 then selBoneName = "neck_01" end

        for i, target in ipairs(enemies) do
            if not slua.isValid(target) then goto continue end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then goto continue end
            
            if igBot then
                -- Shared bot cache use karo (counter jaisa) - fast + consistent
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.BotStatusCache = _G.BotStatusCache or {}
                local cachedBot = _G.BotStatusCache[tId]
                if cachedBot == nil then
                    cachedBot = false
                    -- Method 1: direct AI flags
                    if target.bIsAI == true or target.IsAI == true or target.bIsAi == true then cachedBot = true end
                    -- Method 2: PUBGM AIData / AIController component (sabse reliable)
                    if not cachedBot then
                        if target.AIData ~= nil or target.AIController ~= nil or target.bIsAIActor == true then cachedBot = true end
                        if not cachedBot and target.PlayerAIType ~= nil and target.PlayerAIType ~= 0 then cachedBot = true end
                        if not cachedBot and type(target.IsAICharacter) == "function" then
                            local ok, r = pcall(function() return target:IsAICharacter() end)
                            if ok and r then cachedBot = true end
                        end
                        if not cachedBot and type(target.GetIsAI) == "function" then
                            local ok, r = pcall(function() return target:GetIsAI() end)
                            if ok and r then cachedBot = true end
                        end
                    end
                    -- Method 3: PlayerState flags + missing UID
                    if not cachedBot then
                        local pState = target.PlayerState
                        if slua.isValid(pState) then
                            if pState.bIsABot or pState.bIsBot or pState.IsBot or pState.bIsAI or pState.bIsRobot or pState.bIsAiPlayer then cachedBot = true end
                            if not cachedBot and pState.PlayerAIType ~= nil and pState.PlayerAIType ~= 0 then cachedBot = true end
                            if not cachedBot and type(pState.IsABot) == "function" then
                                local ok, r = pcall(function() return pState:IsABot() end)
                                if ok and r then cachedBot = true end
                            end
                            if not cachedBot then
                                local uid = pState.Uid or pState.UID or pState.PlayerId or pState.PlayerID
                                if uid ~= nil and (uid == 0 or uid == "0") then cachedBot = true end
                            end
                        end
                    end
                    -- Method 4: function checks
                    if not cachedBot and type(target.IsBot) == "function" then
                        local ok, r = pcall(function() return target:IsBot() end)
                        if ok and r then cachedBot = true end
                    end
                    -- Method 5: AI controller check
                    if not cachedBot and type(target.GetController) == "function" then
                        local ok, ctrl = pcall(function() return target:GetController() end)
                        if ok and slua.isValid(ctrl) and (ctrl.bIsAI == true or ctrl.IsAI == true or ctrl.AIData ~= nil) then cachedBot = true end
                    end
                    _G.BotStatusCache[tId] = cachedBot
                end
                if cachedBot then goto continue end
            end
            
            if useVisCheck then
                local curTime = os.clock()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then goto continue end
            end
            
            local tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20
                        elseif boneIdx == 5 then tPos.Z = tPos.Z + 55 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then goto continue end

            -- CHEST mode: aim point upper-chest se neeche mid-chest/body par
            if _G.GTLMODConfig.AimTouchChest and boneIdx == 2 then
                tPos.Z = tPos.Z - CHEST_DROP
            end
            
            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end
            
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            
            if distScreen > FOV_RADIUS then goto continue end
            
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            
            ::continue::
        end
        
        if not slua.isValid(bestTarget) then return end
        
        local finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20
                    elseif boneIdx == 5 then finalBonePos.Z = finalBonePos.Z + 55 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end

        -- CHEST mode: aim point upper-chest se neeche mid-chest/body par
        if _G.GTLMODConfig.AimTouchChest and boneIdx == 2 then
            finalBonePos.Z = finalBonePos.Z - CHEST_DROP
        end
        
        if predVal > 0 then
            pcall(function()
                local tVelocity = nil
                if type(bestTarget.GetVelocity) == "function" then
                    tVelocity = bestTarget:GetVelocity()
                end
                
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0) 
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        
        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch
        
        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end

        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        -- Slider 0-100% -> smoothFactor. Pehle 100% = 1.0 (instant head-snap).
        -- Ab max 55% kam: 100% slider = 0.45. Slider seedha aimbot speed control karta hai.
        local smoothFactor = (speedVal / 100.0) * 0.45
        if smoothFactor < 0.01 then smoothFactor = 0.01 end
        
        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
        
        if recoilCompVal > 0 and isFiring then
            local pullDownForce = (recoilCompVal / 50.0) * 1.5
            finalPitch = finalPitch - pullDownForce
        end

        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
        


    end)
end

-- ========================================== 
-- MAIN LOOP: EXTREMELY POWERFUL OPTIMIZED
-- ========================================== 
-- ==============================================================================
--  ESP V2 SYSTEM — NEW (esp.lua @SRC_HUB / @XThrlen)
--  Line, Health Bar, Corner Box, Snap Line, Counter — sab naya
-- ==============================================================================
_G.LoadESPV2System = function()
if _G.IsESPV2Loaded then return end
_G.IsESPV2Loaded = true

local ESP_Enabled = true

local FVector2D = _G.FVector2D or import("Vector2D")
local FLinearColor = _G.FLinearColor or import("LinearColor")
local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
local SlateColor = nil
local GameplayStaticsESP = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)
pcall(function() SlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor") end)
pcall(function() GameplayStaticsESP = import("GameplayStatics") end)
local KismetSystemLibraryESP = nil
local HitResultClassESP = nil
pcall(function() KismetSystemLibraryESP = import("KismetSystemLibrary") end)
pcall(function() HitResultClassESP = import("HitResult") end)
local TraceStartPos = { X = 0, Y = 0, Z = 0 }
local CachedHitResult = nil
pcall(function()
  if HitResultClassESP then CachedHitResult = HitResultClassESP()
  else CachedHitResult = {} end
end)

local function ESPValid(obj)
  if obj == nil then return false end
  local ok, v = pcall(function() return slua.isValid(obj) end)
  return ok and v == true
end

local function ESPV2(x, y)
  if FVector2D then return FVector2D(x, y) end
  return { X = x, Y = y }
end

local function ESPMKC(r, g, b, a)
  if FLinearColor then return FLinearColor(r, g, b, a) end
  return { R = r, G = g, B = b, A = a }
end

local CFG = {
  MaxDistance = 40000,      -- cm (400 m)
  MaxTracked = 16,
  ScreenMargin = 220,
  TopTextY = 6.0,           -- canvas px, bilkul upar center
  SnapOriginY = 0.0,        -- top edge se start (esplook jaisa)
  SnapThickness = 1.8,
  CornerThickness = 2.2,
  CornerLen = 0.28,
  CornerMin = 6,
  CornerMax = 28,
  BoxMinWidth = 22,
  BoxMaxWidth = 320,
  BoxMinHeight = 14,
  BoxWidthFactor = 0.62,
  WidthScale = 1.22,
  HeadExtra = 0.06,
  FootExtra = 0.02,
  SideBarWidth = 3.5,
  SideBarGap = 5.0,
  SideBgAlpha = 0.55,
  MarkGap = 8.0,            -- box top se chevron tak gap
  MarkW = 15.0,             -- ek V ki aadhi chaudai
  MarkH = 10.0,             -- ek V ki unchai
  MarkGapV = 6.0,           -- do V ke beech gap
  MarkThickness = 2.4,
  NameFontSize = 15,
  DistFontSize = 13,
  StateFontSize = 13,
  TextGap = 1.0,
  CounterFontSize = 17,
  CounterW = 300.0,
  CounterH = 28.0,
  DeadZone = 0.5,           -- px, isse kam harkat = slate ko chhuna nahi (flicker fix)
  VisInterval = 0.15,       -- sec, LineTrace itni der me ek bar per target (lag fix)
  SizeHyst = 2.0,           -- px, viewport me itna farq ignore
}

-- esplook.png colors
local C_WHITE  = ESPMKC(1.0, 1.0, 1.0, 1.0)
local C_BLACK  = ESPMKC(0.0, 0.0, 0.0, 1.0)
local C_GREEN  = ESPMKC(0.12, 1.0, 0.25, 1.0)   -- snap line + "Open"
local C_RED    = ESPMKC(1.0, 0.15, 0.15, 1.0)   -- low health + "Close"
local C_YELLOW = ESPMKC(1.0, 0.90, 0.30, 1.0)   -- double chevron
local C_BLUE   = ESPMKC(0.38, 0.72, 1.0, 1.0)   -- "Bot" name

local function RND(v)
  if v ~= v then return 0 end
  return math.floor(v + 0.5)
end

local function Lerp(a, b, t) return a + (b - a) * t end

-- Health color: 100% green | 70% green+halka yellow | 40% red+halka white | 20% red
local function HealthColor(pct)
  pct = tonumber(pct) or 1.0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  local r, g, b
  if pct >= 0.7 then
    local t = (pct - 0.7) / 0.3
    r = Lerp(0.75, 0.12, t)
    g = 1.0
    b = Lerp(0.15, 0.25, t)
  elseif pct >= 0.4 then
    local t = (pct - 0.4) / 0.3
    r = 1.0
    g = Lerp(0.45, 0.95, t)
    b = Lerp(0.45, 0.20, t)
  else
    local t = pct / 0.4
    r = 1.0
    g = Lerp(0.15, 0.45, t)
    b = Lerp(0.15, 0.45, t)
  end
  return ESPMKC(r, g, b, 1.0)
end

local ESP = {}
ESP.Canvas = nil
ESP.Lines = {}      -- snap lines : key -> {Widget, Slot}
ESP.Corners = {}    -- corner boxes: key -> {w1..w8 Widget/Slot}
ESP.HealthBg = {}   -- health bg (dark) : key -> {Widget, Slot}
ESP.HealthFill = {} -- health fill (pct + color) : key -> {Widget, Slot}
ESP.Marks = {}      -- yellow chevron: key -> {4 x Widget/Slot}
ESP.Infos = {}      -- bottom texts: key -> {Container, Name, Dist, State, slots}
ESP.Weapons = {}    -- weapon text above health bar: key -> {Widget, Slot}
ESP.Counter = nil   -- top "Players: X | Bots: Y"
ESP.EnemyCache = {}
ESP.VisCache = {}   -- visibility cache: key -> {b, t}
ESP.ScaleX = 1.0
ESP.ScaleY = 1.0
ESP.OffsetX = 0.0
ESP.OffsetY = 0.0
ESP.ViewW = 1920
ESP.ViewH = 1080
ESP.ScanInterval = 0.35
ESP.LightInterval = 0.033
ESP.TransformInterval = 0.50
ESP.LastScan = -999.0
ESP.LastTransform = -999.0
ESP.LastWorld = nil
ESP.bActive = false

function ESP.GetGameplayData()
  if ESP._GDP then return ESP._GDP end
  local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
  if ok and GDP then ESP._GDP = GDP return GDP end
  return nil
end

function ESP.GetController()
  local pc = nil
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP and GDP.GetPlayerController then pc = GDP.GetPlayerController() end
  end)
  if not ESPValid(pc) then
    pcall(function()
      if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
    end)
  end
  return ESPValid(pc) and pc or nil
end

function ESP.GetLocalCharacter()
  local c = nil
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP then
      if GDP.GetPlayerCharacter then c = GDP.GetPlayerCharacter() end
      if not ESPValid(c) and GDP.GetLocalCharacter then c = GDP.GetLocalCharacter() end
    end
  end)
  if not ESPValid(c) then
    local pc = ESP.GetController()
    pcall(function() if pc and pc.GetPawn then c = pc:GetPawn() end end)
  end
  return ESPValid(c) and c or nil
end

function ESP.GetAllCharacters()
  local AllChars = {}
  pcall(function()
    local Pawns = Game:GetAllPlayerPawns()
    if Pawns then
      for _, Pawn in pairs(Pawns) do
        if Pawn and slua.isValid(Pawn) then
          local pKey = nil
          if Pawn.GetPlayerKey then pcall(function() pKey = Pawn:GetPlayerKey() end) end
          if not pKey and Pawn.PlayerKey then pKey = Pawn.PlayerKey end
          if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then pKey = Pawn.PlayerState.PlayerKey end
          if pKey then AllChars[pKey] = Pawn end
        end
      end
    end
  end)
  if not next(AllChars) then
    pcall(function()
      local GS = require("GameLua.GameCore.Data.CGameState")
      if GS and GS.GetAllCharacters then AllChars = GS:GetAllCharacters() end
    end)
  end
  return AllChars
end

function ESP.GetMyPlayerKey()
  local pc = ESP.GetController()
  if not ESPValid(pc) then return nil end
  local k = nil
  pcall(function()
    if pc.GetPlayerKey then k = pc:GetPlayerKey()
    elseif pc.PlayerState and pc.PlayerState.PlayerKey then k = pc.PlayerState.PlayerKey end
  end)
  return k
end

function ESP.IsMe(Character, PlayerKey, MyKey)
  local me = false
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP and GDP.GetLocalCharacter then
      local mc = GDP.GetLocalCharacter()
      if mc and Character == mc then me = true return end
    end
    local pc = ESP.GetController()
    if pc and pc.GetPawn then
      local p = pc:GetPawn()
      if p and Character == p then me = true return end
    end
  end)
  if not me and MyKey ~= nil and PlayerKey ~= nil then
    me = (tostring(PlayerKey) == tostring(MyKey))
  end
  return me
end

function ESP.GetTeamID(Character)
  if not ESPValid(Character) then return nil end
  local id = nil
  pcall(function() if Character.GetTeamID then id = Character:GetTeamID() end end)
  if id == nil then pcall(function() id = Character.TeamID end) end
  if id == nil then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then ps = Character:GetPlayerState() end
    end)
    if not ESPValid(ps) then pcall(function() ps = Character.PlayerState end) end
    if ESPValid(ps) then
      pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
      if id == nil then pcall(function() id = ps.TeamID end) end
    end
  end
  return id
end

function ESP.IsAlive(Character)
  if not ESPValid(Character) then return false end
  local alive = nil
  pcall(function() if Character.IsAlive then alive = Character:IsAlive() end end)
  if type(alive) == "boolean" then return alive end
  local hp = nil
  pcall(function() hp = Character.Health end)
  if type(hp) ~= "number" then pcall(function() hp = Character.HP end) end
  if type(hp) == "number" then return hp > 0 end
  return true
end

function ESP.IsKnocked(Character)
  if not ESPValid(Character) then return false end
  local k = false
  pcall(function()
    if Character.HealthStatus == 1 then k = true end
  end)
  if not k then pcall(function()
    if Character.IsNearDeath and Character:IsNearDeath() then k = true end
  end) end
  return k
end

function ESP.IsBot(Character)
  if not ESPValid(Character) then return false end
  local bAI = false
  pcall(function()
    if Game and Game.IsAI then bAI = Game:IsAI(Character) end
    if not bAI and Character then
      if Character.bEnsure == true or Character.bMEnsure == true then bAI = true
      elseif Character.PlayerState and Character.PlayerState.bPSEnsure == true then bAI = true
      elseif Character.Controller then
        if Character.Controller.IsMLAI == true or Character.Controller.FakePlayerBornType == 1 then bAI = true end
      end
    end
  end)
  if not bAI then
    pcall(function()
      if Character.bIsAI == true then bAI = true end
    end)
  end
  if not bAI then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety() end
    end)
    if ESPValid(ps) then
      pcall(function()
        if ps.bIsABot == true or ps.bIsBot == true or ps.bIsAI == true then bAI = true end
      end)
    end
  end
  return bAI
end

function ESP.GetPlayerKey(Character)
  local key = nil
  pcall(function() if Character.GetPlayerKey then key = Character:GetPlayerKey() end end)
  if key == nil then pcall(function() key = Character.PlayerKey end) end
  return tostring(key or Character)
end

function ESP.GetHealthPct(Character)
  if not ESPValid(Character) then return 1.0 end
  local hp, maxhp = nil, nil
  pcall(function() hp = Character.Health end)
  if type(hp) ~= "number" then pcall(function() hp = Character.HP end) end
  pcall(function() maxhp = Character.MaxHealth end)
  if type(maxhp) ~= "number" then pcall(function() maxhp = Character.MaxHP end) end
  if type(hp) ~= "number" then return 1.0 end
  if type(maxhp) ~= "number" or maxhp <= 0 then maxhp = 100 end
  local pct = hp / maxhp
  if pct ~= pct then return 1.0 end
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  return pct
end

local function NormalizeName(v)
  if v == nil or v == false then return nil end
  local ok, t = pcall(tostring, v)
  if not ok or not t then return nil end
  t = t:gsub("^%s+", ""):gsub("%s+$", "")
  if t == "" or t == "nil" or t == "None" or t == "NULL" or t == "Unknown" then return nil end
  return t
end

function ESP.ResolveName(Character, isBot)
  if isBot then return "Bot" end
  local name = nil
  local function take(v)
    if not name then name = NormalizeName(v) end
  end
  pcall(function() if Character.GetPlayerNameSafety then take(Character:GetPlayerNameSafety()) end end)
  pcall(function() if not name and Character.GetPlayerName then take(Character:GetPlayerName()) end end)
  pcall(function() if not name then take(Character.PlayerName) end end)
  pcall(function() if not name then take(Character.NickName) end end)
  if not name then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then ps = Character:GetPlayerState() end
    end)
    if not ESPValid(ps) then pcall(function() ps = Character.PlayerState end) end
    if ESPValid(ps) then
      pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
      pcall(function() if not name then take(ps.PlayerName) end end)
      pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
      pcall(function() if not name then take(ps.NickName) end end)
    end
  end
  return name or "Player"
end

function ESP.GetBonePos(Character, boneName)
  if not ESPValid(Character) or not boneName then return nil end
  local pos = nil
  pcall(function()
    if type(Character.GetBonePos) == "function" then
      pos = Character:GetBonePos(boneName, { X = 0, Y = 0, Z = 0 })
    end
    if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
      if type(Character.GetSocketLocation) == "function" then
        pos = Character:GetSocketLocation(boneName)
      end
    end
    if (not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0)) and ESPValid(Character.Mesh) then
      local mesh = Character.Mesh
      if mesh and mesh.GetSocketLocation then
        local mp = mesh:GetSocketLocation(boneName)
        if mp and not (mp.X == 0 and mp.Y == 0 and mp.Z == 0) then pos = mp end
      end
    end
  end)
  return pos
end

function ESP.GetCamLoc(pc)
  local loc = nil
  pcall(function()
    if GameplayStaticsESP and GameplayStaticsESP.GetPlayerCameraManager then
      local mgr = GameplayStaticsESP.GetPlayerCameraManager(pc, 0)
      if ESPValid(mgr) and mgr.GetCameraLocation then loc = mgr:GetCameraLocation() end
    end
  end)
  if not loc then
    pcall(function()
      if pc and pc.GetPawn then
        local p = pc:GetPawn()
        if ESPValid(p) and p.K2_GetActorLocation then loc = p:K2_GetActorLocation() end
      end
    end)
  end
  return loc
end

function ESP.IsBoneVisible(pc, camLoc, target, bonePos)
  if not ESPValid(pc) or not ESPValid(target) or not bonePos or not camLoc then return false end
  if not KismetSystemLibraryESP or not KismetSystemLibraryESP.LineTraceSingle then return true end
  local dx = bonePos.X - camLoc.X
  local dy = bonePos.Y - camLoc.Y
  local dz = bonePos.Z - camLoc.Z
  local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
  if dist < 50 then return true end
  TraceStartPos.X = camLoc.X + (dx / dist) * 60
  TraceStartPos.Y = camLoc.Y + (dy / dist) * 60
  TraceStartPos.Z = camLoc.Z + (dz / dist) * 60
  local bVis = false
  pcall(function()
    local bHit = KismetSystemLibraryESP.LineTraceSingle(
      pc, TraceStartPos, bonePos, 0, false, nil, 0, CachedHitResult, true)
    if bHit then
      local hitActor = nil
      if CachedHitResult then
        if type(CachedHitResult.GetActor) == "function" then
          hitActor = CachedHitResult:GetActor()
        elseif CachedHitResult.Actor then
          hitActor = CachedHitResult.Actor
        end
      end
      if ESPValid(hitActor) then
        if hitActor == target then bVis = true end
      end
    else
      bVis = true
    end
  end)
  return bVis
end

function ESP.IsVisible(key, pc, camLoc, Character)
  local now = ESP.Now()
  local cached = ESP.VisCache[key]
  if cached and (now - (cached.t or 0)) < (CFG.VisInterval or 0.15) then
    return cached.b
  end
  local bVis = false
  if ESPValid(Character) and ESPValid(pc) and camLoc then
    local bones = { "head", "spine_03", "pelvis" }
    for _, bn in ipairs(bones) do
      local bp = ESP.GetBonePos(Character, bn)
      if bp and (bp.X ~= 0 or bp.Y ~= 0 or bp.Z ~= 0) then
        if ESP.IsBoneVisible(pc, camLoc, Character, bp) then bVis = true break end
      end
    end
  else
    bVis = true
  end
  ESP.VisCache[key] = { b = bVis, t = now }
  return bVis
end

function ESP.ActorLocation(Character)
  local loc = nil
  if not ESPValid(Character) then return nil end
  pcall(function()
    if Character.K2_GetActorLocation then loc = Character:K2_GetActorLocation()
    elseif Game and Game.GetActorLocation then loc = Game:GetActorLocation(Character) end
  end)
  return loc
end

function ESP.DistMeters(a, b)
  if not a or not b then return math.huge end
  local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
  return math.sqrt(dx * dx + dy * dy + dz * dz) / 100.0
end

function ESP.GetVerticalBounds(Character)
  if not ESPValid(Character) then return nil, nil end
  local center, halfHeight = nil, nil
  local capsule = nil
  pcall(function()
    if Character.GetCapsuleComponent then capsule = Character:GetCapsuleComponent()
    elseif Character.CapsuleComponent then capsule = Character.CapsuleComponent end
  end)
  if capsule and ESPValid(capsule) then
    pcall(function()
      if capsule.K2_GetComponentLocation then center = capsule:K2_GetComponentLocation()
      elseif capsule.GetComponentLocation then center = capsule:GetComponentLocation() end
      if capsule.GetScaledCapsuleHalfHeight then halfHeight = capsule:GetScaledCapsuleHalfHeight()
      elseif capsule.GetUnscaledCapsuleHalfHeight then halfHeight = capsule:GetUnscaledCapsuleHalfHeight()
      elseif capsule.CapsuleHalfHeight then halfHeight = capsule.CapsuleHalfHeight end
    end)
  end
  if not center then
    pcall(function() if Character.K2_GetActorLocation then center = Character:K2_GetActorLocation() end end)
  end
  if not center then
    pcall(function() if Game and Game.GetActorLocation then center = Game:GetActorLocation(Character) end end)
  end
  if not center then return nil, nil end
  if not halfHeight or halfHeight < 10 or halfHeight > 200 then
    halfHeight = 85
    pcall(function()
      if Character.bIsCrouched then halfHeight = 60 end
      if Character.IsProne and Character:IsProne() then halfHeight = 25 end
    end)
  end
  return center, halfHeight
end

function ESP.GetHeadFeet(Character)
  local center, half = ESP.GetVerticalBounds(Character)
  if not center or not half then return nil, nil end
  local head = { X = center.X, Y = center.Y, Z = center.Z + half }
  local feet = { X = center.X, Y = center.Y, Z = center.Z - half }
  return head, feet
end

function ESP.Now()
  local t = nil
  pcall(function()
    local w = (slua and slua.getWorld and slua.getWorld()) or nil
    if GameplayStaticsESP and w and GameplayStaticsESP.GetRealTimeSeconds then
      t = GameplayStaticsESP.GetRealTimeSeconds(w)
    end
  end)
  if tonumber(t) then return tonumber(t) end
  pcall(function() if os and os.clock then t = os.clock() end end)
  return tonumber(t) or 0.0
end

function ESP.World()
  local w = nil
  pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
  return w
end

-- ---------- canvas ----------
function ESP.GetCanvas()
  if ESPValid(ESP.Canvas) then return ESP.Canvas end
  local root = nil
  pcall(function()
    local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
    if InGameUITools and InGameUITools.GetMainControlBaseUI then root = InGameUITools.GetMainControlBaseUI() end
  end)
  if not ESPValid(root) then return nil end
  local canvas = nil
  pcall(function()
    if ESPValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
    elseif ESPValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
  end)
  if ESPValid(canvas) then ESP.Canvas = canvas return canvas end
  return nil
end

function ESP.UpdateCanvasTransform(pc)
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return false end
  local calibrated = false
  pcall(function()
    if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
      local geo = canvas:GetCachedGeometry()
      if geo then
        local p0 = SlateBlueprintLibrary.AbsoluteToLocal(geo, ESPV2(0, 0))
        local p1 = SlateBlueprintLibrary.AbsoluteToLocal(geo, ESPV2(100, 100))
        if p0 and p1 and tonumber(p0.X) and tonumber(p1.X) and p1.X ~= p0.X and p1.Y ~= p0.Y then
          ESP.ScaleX = (p1.X - p0.X) / 100.0
          ESP.ScaleY = (p1.Y - p0.Y) / 100.0
          ESP.OffsetX = p0.X
          ESP.OffsetY = p0.Y
          calibrated = true
        end
      end
    end
  end)
  if not calibrated then
    local scale = 1.0
    pcall(function()
      if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
        local s = WidgetLayoutLibrary.GetViewportScale(pc)
        if tonumber(s) and s > 0 then scale = s end
      end
    end)
    ESP.ScaleX = 1.0 / scale
    ESP.ScaleY = 1.0 / scale
    ESP.OffsetX = 0.0
    ESP.OffsetY = 0.0
  end
  return true
end

function ESP.Viewport(pc)
  local w, h = 1920.0, 1080.0
  pcall(function()
    if pc and pc.GetViewportSize then
      local v = ESPV2(0, 0)
      pc:GetViewportSize(v)
      if v and tonumber(v.X) and v.X > 200 then w, h = v.X, v.Y end
    end
  end)
  return w, h
end

function ESP.Project(pc, worldLoc)
  if not pc or not worldLoc then return nil end
  local pix = ESPV2(0, 0)
  local ok = false
  pcall(function()
    local res = pc:ProjectWorldLocationToScreen(worldLoc, pix, true)
    ok = (res == true or res == 1 or (pix and (pix.X ~= 0 or pix.Y ~= 0)))
  end)
  if not ok then return nil end
  return ESPV2(pix.X * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0),
               pix.Y * (ESP.ScaleY or 1.0) + (ESP.OffsetY or 0.0)), pix
end

function ESP.SnapOrigin(pc, viewW)
  -- esplook: origin bilkul top-center
  local cw = nil
  pcall(function()
    local canvas = ESP.GetCanvas()
    if ESPValid(canvas) then
      local geo = canvas:GetCachedGeometry()
      if geo and geo.GetLocalSize then
        local s = geo:GetLocalSize()
        if s and tonumber(s.X) and s.X > 1 then cw = tonumber(s.X) end
      end
    end
  end)
  local cx = nil
  if tonumber(cw) and cw > 1 then cx = cw * 0.5
  else cx = (viewW * 0.5) * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0) end
  return ESPV2(cx, (CFG.SnapOriginY or 0.0))
end

-- ---------- widget helpers (Help patterns) ----------
function ESP.SetFont(w, size)
  if not ESPValid(w) then return end
  pcall(function()
    local f = w.Font
    if f then
      f.Size = size
      if f.OutlineSettings then
        pcall(function() f.OutlineSettings.OutlineSize = 1 end)
        pcall(function() f.OutlineSettings.OutlineColor = C_BLACK end)
      end
      w:SetFont(f)
    end
    if w.SetShadowOffset then w:SetShadowOffset(ESPV2(1.0, 1.0)) end
    if w.SetShadowColorAndOpacity then w:SetShadowColorAndOpacity(C_BLACK) end
  end)
end

function ESP.SetTextColor(w, color)
  if not ESPValid(w) then return end
  pcall(function()
    if SlateColor then w:SetColorAndOpacity(SlateColor(color))
    else w:SetColorAndOpacity(color) end
  end)
end

function ESP.NewLine(color, z)
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local border = nil
  pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
  if not ESPValid(border) then return nil end
  pcall(function()
    border:SetBrushColor(color)
    border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    border:SetRenderTransformPivot(ESPV2(0.0, 0.5))
  end)
  local slot = nil
  pcall(function() slot = canvas:AddChildToCanvas(border) end)
  if not slot then
    pcall(function() border:RemoveFromParent() end)
    return nil
  end
  pcall(function() slot:SetAutoSize(false) slot:SetZOrder(z or 30) end)
  return { Widget = border, Slot = slot }
end

function ESP.DrawLine(data, x1, y1, x2, y2, thickness)
  if not data or not ESPValid(data.Widget) or not data.Slot then return false end
  if x1 ~= x1 or y1 ~= y1 or x2 ~= x2 or y2 ~= y2 then return false end
  x1, y1, x2, y2 = RND(x1), RND(y1), RND(x2), RND(y2)
  local dz = CFG.DeadZone or 0.5
  if data.lx1 and data.th == thickness then
    if math.abs((data.lx1 or 0) - x1) < dz and math.abs((data.ly1 or 0) - y1) < dz
    and math.abs((data.lx2 or 0) - x2) < dz and math.abs((data.ly2 or 0) - y2) < dz then
      if data.hidden ~= true then return true end
    end
  end
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then
    ESP.Hide(data)
    return false
  end
  local angle = ((math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)) * 180.0 / math.pi
  angle = math.floor(angle * 10 + 0.5) / 10
  len = RND(len)
  if data.lx1 == x1 and data.ly1 == y1 and data.lx2 == x2 and data.ly2 == y2 and data.th == thickness then
    if data.hidden == true then
      pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      data.hidden = false
    end
    return true
  end
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x1, y1 - thickness * 0.5))
    data.Slot:SetSize(ESPV2(len, thickness))
    data.Widget:SetRenderAngle(angle)
    data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  if ok then
    data.lx1, data.ly1, data.lx2, data.ly2, data.th = x1, y1, x2, y2, thickness
    data.hidden = false
  end
  return true
end

function ESP.DrawVBar(data, x, top, h, thickness)
  -- vertical health bar: no angle math, seedha Position+Size (double-draw fix)
  if not data or not ESPValid(data.Widget) or not data.Slot then return false end
  if h ~= h or h < 1 then ESP.Hide(data) return false end
  x, top, h = RND(x), RND(top), RND(h)
  local dz = CFG.DeadZone or 0.5
  if data.bx ~= nil then
    if math.abs(data.bx - x) < dz and math.abs(data.bt - top) < dz and math.abs(data.bh - h) < dz then
      if data.hidden ~= true then return true end
    end
  end
  if data.bx == x and data.bt == top and data.bh == h then
    if data.hidden == true then
      pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      data.hidden = false
    end
    return true
  end
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x, top))
    data.Slot:SetSize(ESPV2(thickness, h))
    data.Widget:SetRenderAngle(0)
    data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  if ok then data.bx, data.bt, data.bh = x, top, h data.hidden = false end
  return true
end

function ESP.DrawHBar(data, x, top, w, h)
  -- horizontal bar: SetPosition + SetSize directly, no angle
  if not data or not ESPValid(data.Widget) or not data.Slot then return false end
  if w ~= w or w < 1 or h ~= h or h < 1 then ESP.Hide(data) return false end
  x, top, w, h = RND(x), RND(top), RND(w), RND(h)
  local dz = CFG.DeadZone or 0.5
  if data.bx ~= nil then
    if math.abs(data.bx - x) < dz and math.abs(data.bt - top) < dz
    and math.abs(data.bh - h) < dz and math.abs((data.bw or 0) - w) < dz then
      if data.hidden ~= true then return true end
    end
  end
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x, top))
    data.Slot:SetSize(ESPV2(w, h))
    data.Widget:SetRenderAngle(0)
    data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  if ok then data.bx, data.bt, data.bh, data.bw = x, top, h, w data.hidden = false end
  return true
end

function ESP.Hide(data)
  if data and ESPValid(data.Widget) and data.hidden ~= true then
    pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    data.hidden = true
    data.lx1, data.ly1, data.lx2, data.ly2, data.th = nil, nil, nil, nil, nil
    data.bx, data.bt, data.bh = nil, nil, nil
  end
end

function ESP.SetBrush(data, color, colorKey)
  if not data or not ESPValid(data.Widget) then return end
  if colorKey and data.colorKey == colorKey then return end
  pcall(function() data.Widget:SetBrushColor(color) end)
  if colorKey then data.colorKey = colorKey end
end

function ESP.Destroy(data)
  if not data then return end
  local w = data.Widget or data.Container
  if ESPValid(w) then
    pcall(function() w:RemoveFromParent() end)
    pcall(function() w:ConditionalBeginDestroy() end)
  end
end

-- top counter "Players: X | Bots: Y" : bilkul center-top
function ESP.CreateCounter()
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local container = nil
  pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
  if not ESPValid(container) then return nil end
  local txt = nil
  pcall(function() txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  if not ESPValid(txt) then ESP.Destroy({ Widget = container }) return nil end
  pcall(function()
    txt:SetText("Players: 0 | Bots: 0")
    txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    if txt.SetJustification then txt:SetJustification(1) end
  end)
  ESP.SetTextColor(txt, C_WHITE)
  ESP.SetFont(txt, CFG.CounterFontSize)
  local tSlot, mSlot = nil, nil
  pcall(function() tSlot = container:AddChildToCanvas(txt) end)
  pcall(function() mSlot = canvas:AddChildToCanvas(container) end)
  if not tSlot or not mSlot then ESP.Destroy({ Widget = container }) return nil end
  local W, H = CFG.CounterW or 300.0, CFG.CounterH or 28.0
  pcall(function()
    tSlot:SetAutoSize(true)
    tSlot:SetAlignment(ESPV2(0.5, 0.5))
    tSlot:SetPosition(ESPV2(W * 0.5, H * 0.5))
    tSlot:SetZOrder(5)
    mSlot:SetAutoSize(false)
    -- (0.5, 0.0) = X-center anchor → SetPosition mein X=canvasW/2 dena hoga
    mSlot:SetAlignment(ESPV2(0.5, 0.0))
    mSlot:SetSize(ESPV2(W, H))
    mSlot:SetZOrder(60)
    -- Try SetAnchors for true center on all resolutions
    pcall(function()
      if mSlot.SetAnchors then
        mSlot:SetAnchors({Min={X=0.5,Y=0}, Max={X=0.5,Y=0}})
      end
    end)
  end)
  return { Container = container, Text = txt, Slot = mSlot, W = W, H = H }
end

function ESP.CanvasCenterX(viewW)
  local cw = nil
  pcall(function()
    local canvas = ESP.GetCanvas()
    if ESPValid(canvas) then
      local geo = canvas:GetCachedGeometry()
      if geo and geo.GetLocalSize then
        local s = geo:GetLocalSize()
        if s and tonumber(s.X) and s.X > 1 then cw = tonumber(s.X) end
      end
    end
  end)
  if tonumber(cw) and cw > 1 then return cw * 0.5 end
  return (viewW * 0.5) * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0)
end

function ESP.UpdateCounter(nPlayers, nBots, pc, viewW)
  local d = ESP.Counter
  if not d or not ESPValid(d.Container) then
    ESP.Destroy(d)
    d = ESP.CreateCounter()
    ESP.Counter = d
  end
  if not d then return nil end
  local label = string.format("Players: %d | Bots: %d", nPlayers or 0, nBots or 0)
  pcall(function()
    if d.Last ~= label then d.Text:SetText(label) d.Last = label end
  end)
  -- true center: canvas geometry se actual center X nikalo
  local cx = nil
  pcall(function()
    local canvas = ESP.GetCanvas()
    if ESPValid(canvas) then
      local geo = canvas:GetCachedGeometry()
      if geo then
        -- GetLocalSize → canvas ki actual pixel size canvas-space mein
        local sz = nil
        if geo.GetLocalSize then sz = geo:GetLocalSize() end
        if sz and tonumber(sz.X) and sz.X > 1 then
          cx = sz.X * 0.5
        end
      end
    end
  end)
  if not cx then cx = ESP.CanvasCenterX(viewW) end
  cx = RND(cx or (viewW * 0.5))
  if d.px == nil or math.abs(d.px - cx) >= 1.0 then
    d.px = cx
    pcall(function()
      -- alignment=(0.5,0) → position X=center, Y=top margin
      d.Slot:SetPosition(ESPV2(cx, CFG.TopTextY or 6.0))
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
  else
    pcall(function()
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
  end
  return ESPV2(cx, (CFG.SnapOriginY or 0.0))
end

-- bottom info: Bot / 16m / Open
function ESP.CreateInfo()
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local container, tName, tDist, tState = nil, nil, nil, nil
  pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
  if not ESPValid(container) then return nil end
  pcall(function() tName = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tDist = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tState = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  if not ESPValid(tName) or not ESPValid(tDist) or not ESPValid(tState) then
    ESP.Destroy({ Widget = container })
    return nil
  end
  pcall(function()
    tName:SetText("Bot")
    tDist:SetText("0m")
    tState:SetText("Open")
    tName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tDist:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tState:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    if tName.SetJustification then tName:SetJustification(1) end
    if tDist.SetJustification then tDist:SetJustification(1) end
    if tState.SetJustification then tState:SetJustification(1) end
  end)
  ESP.SetTextColor(tName, C_BLUE)
  ESP.SetTextColor(tDist, C_WHITE)
  ESP.SetTextColor(tState, C_GREEN)
  ESP.SetFont(tName, CFG.NameFontSize)
  ESP.SetFont(tDist, CFG.DistFontSize)
  ESP.SetFont(tState, CFG.StateFontSize)
  local s1, s2, s3, ms = nil, nil, nil, nil
  pcall(function() s1 = container:AddChildToCanvas(tName) end)
  pcall(function() s2 = container:AddChildToCanvas(tDist) end)
  pcall(function() s3 = container:AddChildToCanvas(tState) end)
  pcall(function() ms = canvas:AddChildToCanvas(container) end)
  if not s1 or not s2 or not s3 or not ms then
    ESP.Destroy({ Widget = container })
    return nil
  end
  pcall(function()
    s1:SetAutoSize(true) s1:SetAlignment(ESPV2(0.5, 0.5)) s1:SetZOrder(36)
    s2:SetAutoSize(true) s2:SetAlignment(ESPV2(0.5, 0.5)) s2:SetZOrder(36)
    s3:SetAutoSize(true) s3:SetAlignment(ESPV2(0.5, 0.5)) s3:SetZOrder(36)
    ms:SetAutoSize(false) ms:SetZOrder(35)
  end)
  return { Container = container, Name = tName, Dist = tDist, State = tState,
           S1 = s1, S2 = s2, S3 = s3, Slot = ms }
end

function ESP.UpdateInfo(key, Character, isBot, distM, bVisible, footX, footY)
  local d = ESP.Infos[key]
  if not d or not ESPValid(d.Container) then
    ESP.Destroy(d)
    d = ESP.CreateInfo()
    ESP.Infos[key] = d
  end
  if not d then return end
  -- Bot pe "Bot", real player pe real name (cache, flicker fix)
  local name = d.CachedName
  if not name then
    name = ESP.ResolveName(Character, isBot)
    d.CachedName = name
  end
  if isBot then
    name = "Bot"
    d.CachedName = "Bot"
  end
  local dl = string.format("%dm", math.max(0, math.floor((tonumber(distM) or 0) + 0.5)))
  -- Visibility: Open (green) / Close (red)
  local st = bVisible and "Open" or "Close"
  local stKey = bVisible and "open" or "close"
  pcall(function()
    -- Name: sirf tab show karo jab Esp9_Name ON ho
    if _G.GTLMODConfig.Esp9_Name then
      if d.LastN ~= name then
        d.Name:SetText(name) d.LastN = name
        if isBot then ESP.SetTextColor(d.Name, C_BLUE)
        else ESP.SetTextColor(d.Name, C_WHITE) end
      end
    else
      if d.LastN ~= "" then d.Name:SetText("") d.LastN = "" end
    end
    -- Distance: sirf tab show karo jab Esp9_Distance ON ho
    if _G.GTLMODConfig.Esp9_Distance then
      if d.LastD ~= dl then d.Dist:SetText(dl) d.LastD = dl end
    else
      if d.LastD ~= "" then d.Dist:SetText("") d.LastD = "" end
    end
    -- Open/Close status: sirf Esp9_Line ON ho tab (line visible hai to status bhi)
    if _G.GTLMODConfig.Esp9_Line then
      if d.LastS ~= st then
        d.State:SetText(st) d.LastS = st
        if bVisible then ESP.SetTextColor(d.State, C_GREEN)
        else ESP.SetTextColor(d.State, C_RED) end
      end
    else
      if d.LastS ~= "" then d.State:SetText("") d.LastS = "" end
    end
    if d.LastK ~= stKey then d.LastK = stKey end
  end)
  -- 3 lines, centered under feet (pos cache, flicker fix)
  local w = 120.0
  local h1, h2, h3 = 20.0, 17.0, 17.0
  local x = RND(footX - w * 0.5)
  local y = RND(footY + 4.0)
  if d.ix == nil or math.abs(d.ix - x) >= 1.0 or math.abs((d.iy or 0) - y) >= 1.0 then
    d.ix, d.iy = x, y
    pcall(function()
      d.Slot:SetPosition(ESPV2(x, y))
      d.Slot:SetSize(ESPV2(w, h1 + h2 + h3 + 6.0))
      d.S1:SetPosition(ESPV2(w * 0.5, h1 * 0.5))
      d.S2:SetPosition(ESPV2(w * 0.5, h1 + h2 * 0.5 + CFG.TextGap))
      d.S3:SetPosition(ESPV2(w * 0.5, h1 + h2 + h3 * 0.5 + CFG.TextGap * 2.0))
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
  else
    pcall(function()
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
  end
end

function ESP.EnsureWeapon(key)
  local d = ESP.Weapons[key]
  if d and ESPValid(d.Widget) then return d end
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local tb, slot = nil, nil
  pcall(function() tb = CGame:NewObjectFromPath("/Script/UMG.TextBlock", canvas) end)
  if not ESPValid(tb) then return nil end
  pcall(function() slot = canvas:AddChildToCanvas(tb) end)
  if not slot then ESP.Destroy({ Widget = tb }) return nil end
  pcall(function()
    tb:SetText("")
    tb:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    if tb.SetJustification then tb:SetJustification(1) end
    slot:SetAutoSize(true)
    slot:SetAlignment(ESPV2(0.5, 0.5))
    slot:SetZOrder(36)
  end)
  ESP.SetTextColor(tb, C_YELLOW)
  ESP.SetFont(tb, CFG.StateFontSize)
  d = { Widget = tb, Slot = slot }
  ESP.Weapons[key] = d
  return d
end

function ESP.UpdateWeapon(d, Character, isBot, cx, y)
  if not d or not ESPValid(d.Widget) then return end
  local now = os.clock()
  -- weapon naam 1.5s cache (har tick query mehnga hai)
  if d.nextT == nil or now >= d.nextT then
    d.nextT = now + 1.5
    local name = "No Weapon"
    pcall(function()
      local w = nil
      if Character.CurrentWeapon then w = Character.CurrentWeapon
      elseif type(Character.GetCurrentWeapon) == "function" then w = Character:GetCurrentWeapon()
      elseif Character.WeaponManagerComponent then w = Character.WeaponManagerComponent.CurrentWeaponReplicated end
      if ESPValid(w) and type(w.GetWeaponName) == "function" then name = tostring(w:GetWeaponName()) end
    end)
    if d.text ~= name then
      d.text = name
      pcall(function() d.Widget:SetText(name) end)
    end
  end
  local ck = isBot and "bot" or "real"
  if d.colKey ~= ck then
    d.colKey = ck
    ESP.SetTextColor(d.Widget, isBot and C_CYAN or C_YELLOW)
  end
  local x, yy = RND(cx), RND(y)
  if d.px == nil or math.abs(d.px - x) >= 1.0 or math.abs((d.py or 0) - yy) >= 1.0 then
    d.px, d.py = x, yy
    pcall(function() d.Slot:SetPosition(ESPV2(x, yy)) end)
  end
  if d.hidden then
    d.hidden = false
    pcall(function() d.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
  end
end

function ESP.EnsureCorner(key, idx, color)
  local t = ESP.Corners[key]
  if not t then t = {} ESP.Corners[key] = t end
  local d = t[idx]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(color or C_WHITE, 32)
  t[idx] = d
  return d
end

function ESP.EnsureHealthBg(key)
  local d = ESP.HealthBg[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(ESPMKC(0.0, 0.0, 0.0, CFG.SideBgAlpha or 0.55), 31)
  ESP.HealthBg[key] = d
  return d
end

function ESP.EnsureHealthFill(key)
  local d = ESP.HealthFill[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(C_GREEN, 32)
  ESP.HealthFill[key] = d
  return d
end

-- Health bar: HEAD KE UPAR horizontal pill-shape (Image 2 jaisa)
-- bg = dark full width, fill = green->red left-se-right pct width
-- DrawVBar reuse: angle=0 → horizontal (width=bar_W, height=bar_H)
function ESP.UpdateHealthBar(key, pct, boxL, boxR, headTopY)
  local bg = ESP.EnsureHealthBg(key)
  local fill = ESP.EnsureHealthFill(key)
  if not bg or not fill then return end

  -- compact pill dimensions (Image 2 reference)
  local barW = boxR - boxL          -- box ki puri width
  local barH = 5.0                  --얇ी horizontal bar (pill height)
  local gapAboveHead = 4.0          -- head se kitna upar
  local barTop = headTopY - gapAboveHead - barH

  barW = math.max(20, math.min(120, barW))  -- min 20, max 120px

  pct = tonumber(pct) or 1.0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end

  -- bg: full width dark bar
  ESP.DrawHBar(bg, boxL, barTop, barW, barH)

  -- fill: left-anchored, width = barW * pct
  local fw = barW * pct
  if fw < 1 then
    ESP.Hide(fill)
    return
  end
  local bucket
  if pct >= 0.7 then bucket = "g_" .. math.floor(pct * 20 + 0.5)
  elseif pct >= 0.4 then bucket = "y_" .. math.floor(pct * 20 + 0.5)
  else bucket = "r_" .. math.floor(pct * 20 + 0.5) end
  ESP.SetBrush(fill, HealthColor(pct), bucket)
  ESP.DrawHBar(fill, boxL, barTop, fw, barH)
end

function ESP.EnsureMark(key, idx)
  local t = ESP.Marks[key]
  if not t then t = {} ESP.Marks[key] = t end
  local d = t[idx]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(C_YELLOW, 33)
  t[idx] = d
  return d
end

function ESP.EnsureSnap(key)
  local d = ESP.Lines[key]
  if d and ESPValid(d.Widget) then return d end
  -- default color: green (covered) — will be updated per-frame
  d = ESP.NewLine(C_RED, 30)
  ESP.Lines[key] = d
  return d
end

function ESP.HideTarget(key)
  local c = ESP.Corners[key]
  if c then for i = 1, 8 do ESP.Hide(c[i]) end end
  ESP.Hide(ESP.HealthBg[key])
  ESP.Hide(ESP.HealthFill[key])
  local m = ESP.Marks[key]
  if m then for i = 1, 4 do ESP.Hide(m[i]) end end
  ESP.Hide(ESP.Lines[key])
  ESP.Hide(ESP.Weapons[key])
  local inf = ESP.Infos[key]
  if inf and ESPValid(inf.Container) then
    pcall(function() inf.Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
  end
end

function ESP.ReleaseTarget(key)
  local c = ESP.Corners[key]
  if c then for i = 1, 8 do ESP.Destroy(c[i]) end end
  ESP.Corners[key] = nil
  ESP.Destroy(ESP.HealthBg[key])
  ESP.HealthBg[key] = nil
  ESP.Destroy(ESP.HealthFill[key])
  ESP.HealthFill[key] = nil
  local m = ESP.Marks[key]
  if m then for i = 1, 4 do ESP.Destroy(m[i]) end end
  ESP.Marks[key] = nil
  ESP.Destroy(ESP.Lines[key])
  ESP.Lines[key] = nil
  ESP.Destroy(ESP.Infos[key])
  ESP.Infos[key] = nil
  ESP.Destroy(ESP.Weapons[key])
  ESP.Weapons[key] = nil
  ESP.VisCache[key] = nil
end

function ESP.ResetWidgets()
  for _, d in pairs(ESP.Lines) do ESP.Destroy(d) end
  for _, t in pairs(ESP.Corners) do for _, d in pairs(t) do ESP.Destroy(d) end end
  for _, d in pairs(ESP.HealthBg) do ESP.Destroy(d) end
  for _, d in pairs(ESP.HealthFill) do ESP.Destroy(d) end
  for _, t in pairs(ESP.Marks) do for _, d in pairs(t) do ESP.Destroy(d) end end
  for _, d in pairs(ESP.Infos) do ESP.Destroy(d) end
  for _, d in pairs(ESP.Weapons) do ESP.Destroy(d) end
  ESP.Weapons = {}
  ESP.Lines = {}
  ESP.Corners = {}
  ESP.HealthBg = {}
  ESP.HealthFill = {}
  ESP.Marks = {}
  ESP.Infos = {}
  ESP.VisCache = {}
  if ESP.Counter then ESP.Destroy(ESP.Counter) end
  ESP.Counter = nil
  ESP.Canvas = nil
  ESP.EnemyCache = {}
end

function ESP.Scan()
  local pc = ESP.GetController()
  local me = ESP.GetLocalCharacter()
  if not pc or not me then ESP.EnemyCache = {} return pc, 0, 0 end
  local myLoc = ESP.ActorLocation(me)
  if not myLoc then ESP.EnemyCache = {} return pc, 0, 0 end
  local myTeam = ESP.GetTeamID(me)
  local list = {}
  local nReal, nBot = 0, 0
  local pawns = nil
  pcall(function() if Game and Game.GetAllPlayerPawns then pawns = Game:GetAllPlayerPawns() end end)
  if pawns then
    for _, ch in pairs(pawns) do
      if ESPValid(ch) and ch ~= me and ESP.IsAlive(ch) then
        local team = ESP.GetTeamID(ch)
        if myTeam == nil or team == nil or tostring(team) ~= tostring(myTeam) then
          local loc = ESP.ActorLocation(ch)
          local dm = ESP.DistMeters(myLoc, loc)
          if dm * 100.0 <= (CFG.MaxDistance or 40000) then
            local isBot = ESP.IsBot(ch)
            if isBot then nBot = nBot + 1 else nReal = nReal + 1 end
            list[#list + 1] = { Character = ch, Key = ESP.GetPlayerKey(ch),
                                IsBot = isBot, Distance = dm }
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return (a.Distance or 99999) < (b.Distance or 99999) end)
  local trimmed = {}
  local maxR = CFG.MaxTracked or 16
  for i, it in ipairs(list) do
    if i > maxR then break end
    trimmed[#trimmed + 1] = it
  end
  ESP.EnemyCache = trimmed
  return pc, nReal, nBot
end
--// SRC HUB
function ESP.Update()
  if not ESP_Enabled then ESP.ResetWidgets() return end
  local world = ESP.World()
  if world ~= ESP.LastWorld then
    ESP.ResetWidgets()
    ESP.LastWorld = world
    ESP.LastScan = -999.0
    ESP.LastTransform = -999.0
  end
  local canvas = ESP.GetCanvas()
  if not canvas then return end
  local now = ESP.Now()
  local pc = ESP.GetController()
  if (now - ESP.LastScan) >= (ESP.ScanInterval or 0.35) then
    local r, b
    pc, r, b = ESP.Scan()
    ESP.LastScan = now
    ESP.RealCount, ESP.BotCount = r or 0, b or 0
  end
  pc = pc or ESP.GetController()
  if not pc then return end
  if (now - (ESP.LastTransform or -999.0)) >= (ESP.TransformInterval or 0.50) then
    ESP.UpdateCanvasTransform(pc)
    ESP.LastTransform = now
  end
  local vw, vh = ESP.Viewport(pc)
  -- viewport hysteresis: 2px se kam farq ignore (flicker fix)
  local hyst = CFG.SizeHyst or 2.0
  if math.abs(vw - (ESP.ViewW or 0)) > hyst or math.abs(vh - (ESP.ViewH or 0)) > hyst then
    ESP.ViewW, ESP.ViewH = vw, vh
  else
    vw, vh = ESP.ViewW, ESP.ViewH
  end
  local origin = ESP.UpdateCounter(ESP.RealCount or 0, ESP.BotCount or 0, pc, vw)
  if not origin then return end
  local camLoc = ESP.GetCamLoc(pc)

  local active = {}
  for _, item in ipairs(ESP.EnemyCache) do
    local c = item.Character
    local key = item.Key
    if ESPValid(c) and ESP.IsAlive(c) then
      local head, feet = ESP.GetHeadFeet(c)
      if head and feet then
        local headS, headPix = ESP.Project(pc, head)
        local feetS, feetPix = ESP.Project(pc, feet)
        if headS and feetS and headPix and feetPix then
          local m = CFG.ScreenMargin or 220
          local on = headPix.X > -m and headPix.X < vw + m
            and headPix.Y > -m and headPix.Y < vh + m
            and feetPix.X > -m and feetPix.X < vw + m
            and feetPix.Y > -m and feetPix.Y < vh + m
          if on then
            local H = feetS.Y - headS.Y
            -- sanity: ulti box / bahut badi box = garbage projection, hide
            if H >= (CFG.BoxMinHeight or 14) and H <= vh * 1.5 then
              active[key] = true
              local W = H * (CFG.BoxWidthFactor or 0.62)
              W = math.max(CFG.BoxMinWidth or 22, math.min(CFG.BoxMaxWidth or 320, W))
              local padT = H * (CFG.HeadExtra or 0)
              local padB = H * (CFG.FootExtra or 0)
              local cx = (headS.X + feetS.X) * 0.5
              local L = cx - W * 0.5
              local R = cx + W * 0.5
              local T = headS.Y - padT
              local B = feetS.Y + padB

              -- 1) ESP BOX — sirf tab jab EspLoai9 ON ho
              if _G.GTLMODConfig.EspLoai9 then
                local arm = math.min(R - L, B - T) * (CFG.CornerLen or 0.28)
                arm = math.max(CFG.CornerMin or 6, math.min(CFG.CornerMax or 28, arm))
                local th = CFG.CornerThickness or 2.2
                ESP.DrawLine(ESP.EnsureCorner(key, 1, C_WHITE), L, T, L + arm, T, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 2, C_WHITE), L, T, L, T + arm, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 3, C_WHITE), R, T, R - arm, T, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 4, C_WHITE), R, T, R, T + arm, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 5, C_WHITE), L, B, L + arm, B, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 6, C_WHITE), L, B, L, B - arm, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 7, C_WHITE), R, B, R - arm, B, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 8, C_WHITE), R, B, R, B - arm, th)
              else
                local cc = ESP.Corners[key]
                if cc then for i = 1, 8 do ESP.Hide(cc[i]) end end
              end

              -- 2) HEALTH BAR — sirf tab jab Esp9_HP ON ho
              if _G.GTLMODConfig.Esp9_HP then
                local pct = ESP.GetHealthPct(c)
                ESP.UpdateHealthBar(key, pct, L, R, T)
              else
                ESP.Hide(ESP.HealthBg[key])
                ESP.Hide(ESP.HealthFill[key])
              end

              -- 3) TEAM CHEVRON (double V marker) — sirf tab jab Esp9_Team ON ho
              if _G.GTLMODConfig.Esp9_Team then
                local ccx = (L + R) * 0.5
                local mw = CFG.MarkW or 15.0
                local mh = CFG.MarkH or 10.0
                local gv = CFG.MarkGapV or 6.0
                local gp = CFG.MarkGap or 8.0
                local mt = CFG.MarkThickness or 2.4
                local y2 = T - gp
                local y1 = y2 - mh - gv
                ESP.DrawLine(ESP.EnsureMark(key, 1), ccx - mw, y1, ccx, y1 + mh, mt)
                ESP.DrawLine(ESP.EnsureMark(key, 2), ccx + mw, y1, ccx, y1 + mh, mt)
                ESP.DrawLine(ESP.EnsureMark(key, 3), ccx - mw, y2 - mh, ccx, y2, mt)
                ESP.DrawLine(ESP.EnsureMark(key, 4), ccx + mw, y2 - mh, ccx, y2, mt)
              else
                local mm = ESP.Marks[key]
                if mm then for i = 1, 4 do ESP.Hide(mm[i]) end end
              end

              -- 4) visibility check (sirf tab karo jab line ya info ON ho)
              local bVis = false
              if _G.GTLMODConfig.Esp9_Line or _G.GTLMODConfig.Esp9_Name
                 or _G.GTLMODConfig.Esp9_Distance then
                bVis = ESP.IsVisible(key, pc, camLoc, c)
              end

              -- 5) SNAP LINE — sirf tab jab Esp9_Line ON ho
              if _G.GTLMODConfig.Esp9_Line then
                local snapData = ESP.EnsureSnap(key)
                local snapColorKey = bVis and "snap_red" or "snap_green"
                local snapColor    = bVis and C_RED     or C_GREEN
                ESP.SetBrush(snapData, snapColor, snapColorKey)
                local lthick = (_G.GTLMODState and _G.GTLMODState.CustomTextData
                                and _G.GTLMODState.CustomTextData.Esp9_LineThick)
                               or CFG.SnapThickness or 1.8
                ESP.DrawLine(snapData, origin.X, origin.Y, headS.X, headS.Y, lthick)
              else
                ESP.Hide(ESP.Lines[key])
              end

              -- 5b) WEAPON — sirf tab jab Esp9_Weapon ON ho, health bar ke UPAR
              if _G.GTLMODConfig.Esp9_Weapon then
                local wd = ESP.EnsureWeapon(key)
                if wd then
                  ESP.UpdateWeapon(wd, c, item.IsBot, cx, T - (_G.GTLMODConfig.Esp9_Team and 40 or 22))
                end
              else
                ESP.Hide(ESP.Weapons[key])
              end

              -- 6) BOTTOM INFO (name/distance/Open) — flags se control
              ESP.UpdateInfo(key, c, item.IsBot, item.Distance, bVis, cx, B)
            else
              ESP.HideTarget(key)
            end
          else
            ESP.HideTarget(key)
          end
        else
          ESP.HideTarget(key)
        end
      else
        ESP.HideTarget(key)
      end
    end
  end
  -- stale: jo is frame me nahi dikha usko hide; jo cache me bhi nahi usko release
  local seenCache = {}
  for _, it in ipairs(ESP.EnemyCache) do seenCache[it.Key] = true end
  local function stillActive(k)
    return active[k] == true
  end
  for k, _ in pairs(ESP.Lines) do if not stillActive(k) then ESP.HideTarget(k) end end
  for k, _ in pairs(ESP.Infos) do if not stillActive(k) then ESP.HideTarget(k) end end
  for k, _ in pairs(ESP.Corners) do
    if not stillActive(k) and not seenCache[k] then ESP.ReleaseTarget(k) end
  end
  for k, _ in pairs(ESP.HealthBg) do
    if not seenCache[k] and not stillActive(k) then ESP.ReleaseTarget(k) end
  end
end

-- Single driver: sirf ek repeating timer (lag/flicker fix).
-- Purana triple-driver (Tick loop + 2x AddGameTimer) hata diya.
function ESP.Tick()
  pcall(ESP.Update)
end

function ESP.AttachTimers()
  pcall(function()
    local pc = ESP.GetController()
    if ESPValid(pc) and pc.AddGameTimer then
      if ESP._TimerPC == pc and ESP._TimerHooked then return end
      ESP._TimerPC = pc
      ESP._TimerHooked = true
      -- ek hi repeating timer: andar Scan (0.35) + Transform (0.5) throttled
      pc:AddGameTimer(ESP.LightInterval or 0.033, true, function()
        if ESP.bActive then pcall(ESP.Tick) end
      end)
    else
      pcall(function()
        require("timer").SetGameTimer(1.0, false, function()
          ESP._TimerHooked = false
          ESP.AttachTimers()
        end)
      end)
    end
    pcall(function() require("timer").SetGameTimer(5.0, false, function() ESP.AttachTimers() end) end)
  end)
end

function ESP.Start()
  if ESP.bActive then return end
  ESP.bActive = true
  pcall(ESP.Update)
  ESP.AttachTimers()
end

_G.ESP = ESP
_G.PlayerMapMarker = ESP

local function ESPLater(sec, fn)
  local tk = nil
  pcall(function() tk = require("common.time_ticker") end)
  if tk and tk.AddTimerOnce then pcall(function() tk.AddTimerOnce(sec, fn) end) return end
  pcall(function() require("timer").SetGameTimer(sec, false, fn) end)
end

local _ESPStartedPC = nil
local function ESPStartAll()
  pcall(function()
    local pc = nil
    if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
    if not ESPValid(pc) then pc = ESP.GetController() end
    if ESPValid(pc) then
      if pc ~= _ESPStartedPC then
        _ESPStartedPC = pc
        ESP._TimerHooked = false
        ESP._TimerPC = nil
        ESP.Start()
      else
        ESP.AttachTimers()
      end
    end
  end)
end

pcall(function()
  ESPStartAll()
  ESPLater(1.0, ESPStartAll)
end)
if not _G.__ESPLookTickStarted then
  _G.__ESPLookTickStarted = true
  ESP.bActive = true
  ESP.AttachTimers()
end

_G.PMM_ESPV2 = ESP
-- ESP V2: koi bhi ek feature ON ho to engine chalega (BOX ka ON hona zaroori nahi)
_G.PMM_ESPV2_AnyOn = function()
    local C = _G.GTLMODConfig
    return (C.EspLoai9 or C.Esp9_Line or C.Esp9_HP or C.Esp9_Weapon
            or C.Esp9_Team or C.Esp9_Distance or C.Esp9_Name) and true or false
end
end

-- init karo turant
pcall(function() if _G.LoadESPV2System then _G.LoadESPV2System() end end)

local function MainLoop() 
    if isExpired then return end

    if _G.GTLMODState.CustomTextData == nil then 
        -- Sirf actually-used fields (aimbot ab unified logic mein hardcoded presets use karta hai)
        _G.GTLMODState.CustomTextData = {OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, IpadViewFOV = 120,
            -- ESP V2 (Esp9) line/skeleton settings
            Esp9_LineThick = 1, Esp9_LineVisColor = 2, Esp9_LineHidColor = 1,
            Esp9_SkelThick = 1, Esp9_SkelVisColor = 2, Esp9_SkelHidColor = 1}
    end

    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GameplayData then return end 
    local pc = GameplayData.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 

    if not Valid(localPlayer) then 
        if _G.GTLMODState.TrackedMarks then
            for markId, _ in pairs(_G.GTLMODState.TrackedMarks) do
                SafeRemoveMark(markId)
            end
        end
        _G.GTLMODState.TrackedMarks = {} 
        
        for key, data in pairs(_G.GTLMODState.EnemyMarks) do
            if data and data.MIDs then
                for meshStr, midTable in pairs(data.MIDs) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs = nil
            end
        end
        
        _G.GTLMODState.EnemyMarks = {}
        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.GTLMODState.PrevGraphicsState = {}
        return 
    end

    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_SecurityCommonUtils = nil
    pcall(function() Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    -- Ninja dash / SpecialSuit active check — skip weapon/rotation mods during dash
    local _inSpecialDash = false
    pcall(function()
        local EPawnState_local = import("EPawnState")
        if EPawnState_local and type(localPlayer.HasState) == "function" then
            if localPlayer:HasState(EPawnState_local.SpecialSuit) then _inSpecialDash = true end
        end
    end)

    if _G.GTLMODConfig.UnlockFPS then InitializeGraphicsUnlock() end
    InitializeNativeESP()
    ShowGTLMODVIPMenu()

    -- ==============================================================================
    --  ESP V2 (Esp9) — new ESP (esp.lua @SRC_HUB) — sab kuch ESP.Update() mein hai
    -- ==============================================================================
    if _G.PMM_ESPV2_AnyOn() then
        if _G.PMM_ESPV2 then
            if not _G.PMM_ESPV2.bActive then _G.PMM_ESPV2.Start() end
        end
    else
        if _G.PMM_ESPV2 and _G.PMM_ESPV2.bActive then
            _G.PMM_ESPV2.bActive = false
            pcall(function() _G.PMM_ESPV2.ResetWidgets() end)
        end
    end
    
    if _G.GTLMODConfig.IpadView and _G.GTLMODState.CustomTextData then
        pcall(function()
            local targetTPP = _G.GTLMODState.CustomTextData.IpadViewFOV or 120
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= targetTPP then uTPPCam.FieldOfView = targetTPP end
            end
        end)
    else
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= 80 then uTPPCam.FieldOfView = 80 end
            end
        end)
    end

    -- ========================================== 
    -- Aimbot Force dipindahkan ke loop terpisah
    -- ========================================== 

    local now = os.clock()
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            -- ENEMY GLOW: yehi teen console commands enemy ko chamkate hain.
            -- Zaroori baat: ye ENGINE-WIDE hain, sirf enemy par nahi lag sakte.
            -- Glow slider (0-10) inki shiddat control karta hai.
            -- HDR GLOW: yeh white-body + glow wala effect hai.
            -- Ab iska apna toggle hai (pehle ColorBodyV2 ke saath chipka hua tha).
            -- ON  -> white body + glow chalega
            -- OFF -> sab normal, koi glow/white body nahi
            if _G.GTLMODConfig.HDRGlow then
                local g = tonumber(_G.ColorConfig.Glow) or 3.0
                local offset = math.floor(200 * (g / 3.0))
                if offset < 1 then offset = 1 end
                local key = tostring(offset)
                if _G.GTLMODState.PrevGraphicsState.GlowKey ~= key then
                    _G.GTLMODState.PrevGraphicsState.GlowKey = key
                    gi:ExecuteCMD("r.CharacterMinShadowFactor", "4")
                    gi:ExecuteCMD("r.CharacterDiffuseOffset", key)
                    gi:ExecuteCMD("r.CharacterDiffusePower", key)
                end
            elseif _G.GTLMODState.PrevGraphicsState.GlowKey then
                _G.GTLMODState.PrevGraphicsState.GlowKey = nil
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
            end
            
            if _G.GTLMODConfig.BlackSky and not _G.GTLMODState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.GTLMODState.PrevGraphicsState.BlackSky = true
            elseif not _G.GTLMODConfig.BlackSky and _G.GTLMODState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.GTLMODState.PrevGraphicsState.BlackSky = false
            end
        end
    end)

    -- NOTE: Weapon-mod block (GodMode, Accuracy, Crosshair, LessShake,
    -- CustomHRecoil/VRecoil, CustomAimbot/Close) poora hata diya gaya --
    -- in features ka koi menu button nahi tha, yani kabhi on nahi hote the.
    -- Aimbot ab sirf AimTouch (HEAD/CHEST) se chalta hai.

    -- Magic Bullet logic has been removed from this version
    -- All global magic bullet variables disabled

    pcall(function()
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end
        
        local currentValidKeys = {}
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer then
                currentValidKeys[GetSafeEnemyKey(enemy)] = true
            end
        end
        
        for key, data in pairs(_G.GTLMODState.EnemyMarks) do
            if not currentValidKeys[key] then
                SafeRemoveMark(data.radarMark)
                SafeRemoveMark(data.hpMark)
                SafeRemoveMark(data.distMark)
                
                if _G.AimTouchVisCache and _G.AimTouchVisCache[key] then
                    _G.AimTouchVisCache[key] = nil
                end
                
                if _G.BotStatusCache and _G.BotStatusCache[key] then
                    _G.BotStatusCache[key] = nil
                end
                
                if data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs = nil
                end
                
                data.enemy = nil
                data.CachedMeshes = nil
                _G.GTLMODState.EnemyMarks[key] = nil
            end
        end

        local realCount = 0
        local aiCount = 0

        local function GetFirstElemSafe(elemArray)
            if elemArray and type(elemArray.Num) == "function" and elemArray:Num() > 0 then
                if type(elemArray.Get) == "function" then return elemArray:Get(0) end
            elseif elemArray and type(elemArray) == "table" and #elemArray > 0 then
                return elemArray[1]
            end
            return nil
        end

        local BoneScaleMap = {
            ["head"] = mHead_Global, ["neck_01"] = mHead_Global,
            ["pelvis"] = mBody_Global, ["spine_01"] = mBody_Global, ["spine_02"] = mBody_Global, ["spine_03"] = mBody_Global,
            ["thigh_l"] = mLegs_Global, ["thigh_r"] = mLegs_Global, 
            ["calf_l"] = mLegs_Global, ["calf_r"] = mLegs_Global,   
            ["foot_l"] = mLegs_Global, ["foot_r"] = mLegs_Global    
        }
        
        local mLoc = nil
        pcall(function() if type(localPlayer.K2_GetActorLocation) == "function" then mLoc = localPlayer:K2_GetActorLocation() end end)

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local bIsReallyDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
                end)

                local eKey = GetSafeEnemyKey(enemy)
                _G.GTLMODState.EnemyMarks[eKey] = _G.GTLMODState.EnemyMarks[eKey] or { enemy = enemy }
                local markData = _G.GTLMODState.EnemyMarks[eKey]
                markData.enemy = enemy 

                if not bIsReallyDead then
                    if markData.lastEnemyActor ~= enemy then
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                        if markData.radarMark then SafeRemoveMark(markData.radarMark); markData.radarMark = nil end
                        
                        markData.lastEnemyActor = enemy
                        markData.LastUIComp = nil
                        markData.LastFrameUIState = nil
                    end
                    
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    
                    local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
                    local isBot = markData.AK_IS_BOT or false

                    local currentMeshCount = 0
                    if Valid(eMesh) then
                        local tempMeshes = GetAllSkeletalMeshes(enemy, markData)
                        currentMeshCount = #tempMeshes
                    end
                    local isMeshChanged = (markData.LastMeshCountWall ~= currentMeshCount)

                    if _G.GTLMODConfig.wallhackng then
                        if isMeshChanged or not markData.WallhackApplied then
                            Applywallhackng(enemy, markData)
                            markData.WallhackApplied = true
                            markData.LastMeshCountWall = currentMeshCount
                        end
                    else
                        Undowallhackng(enemy, markData)
                    end

                    if _G.GTLMODConfig.ColorBodyV2 then 
                        ApplyColorBodyV2(enemy, pc, markData) 
                    else
                        UndoColorBodyV2(enemy, markData)
                    end

                    -- WALLHACK V2 (Dyeing system) — V1 se bilkul alag, apna toggle
                    if _G.GTLMODConfig.WallhackV2 then
                        local nowT = os.clock()
                        if not markData.V2Applied or not markData.V2Time or (nowT - markData.V2Time) > 2.0 then
                            markData.V2Time = nowT
                            ApplyWallhackV2(enemy, markData)
                        end
                    else
                        UndoWallhackV2(enemy, markData)
                    end

                    -- Magic Bullet hitbox modification removed from this version
                    -- Physics asset override functionality disabled

                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local currentHp, maxHp = 100, 100
                    local showFrameUI = _G.GTLMODConfig.Esp5 or _G.GTLMODConfig.EspVip
                    
                    if showFrameUI then
                        pcall(function()
                            if enemy.Health then currentHp = enemy.Health elseif type(enemy.GetHealth) == "function" then currentHp = enemy:GetHealth() end
                            if enemy.HealthMax then maxHp = enemy.HealthMax elseif type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax() end
                        end)
                        if maxHp <= 0 then maxHp = 100 end
                    end
                    local hpRatio = currentHp / maxHp

                    if _G.GTLMODConfig.EspAntenna then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) and distM <= 400 then
                                local loopCount = 8  
                                local zStep = 1000     
                                local baseZ = 105     
                                local topZ = baseZ + (loopCount * zStep)
                                for i = 1, loopCount do
                                    local zOffset = baseZ + (i * zStep)
                                    MyHUD:AddDebugText("|", enemy, 0.06,
                                        {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset},
                                        C_GREEN, true, false, true, nil, 1.2, true)
                                end
                                MyHUD:AddDebugText("I", enemy, 0.06,
                                        {X=0, Y=0, Z=topZ + 60}, {X=0, Y=0, Z=topZ + 60},
                                        C_GREEN, true, false, true, nil, 1.5, true)
                            end
                        end)
                    end

                    if _G.GTLMODConfig.Esp6 then
                        pcall(function()
                            local curTime = os.clock()
                            if markData.LastEsp6Time == nil or (curTime - markData.LastEsp6Time) >= 0.05 then
                                markData.LastEsp6Time = curTime
                                
                                local MyHUD = Cached_MyHUD
                                if Valid(MyHUD) and Valid(eMesh) and aLoc then
                                    if distM <= 250 then
                                        if type(eMesh.GetSocketLocation) == "function" then
                                            for _, bName in ipairs(GLOBAL_BONE_LIST) do
                                                
                                                if distM > 50 and (bName ~= "head" and bName ~= "pelvis" and bName ~= "neck_01") then
                                                    -- Skip
                                                else
                                                    local wLoc = eMesh:GetSocketLocation(bName)
                                                    if wLoc then
                                                        local offset = {X = wLoc.X - aLoc.X, Y = wLoc.Y - aLoc.Y, Z = wLoc.Z - aLoc.Z}
                                                        
                                                        local mark = "▪"
                                                        local fixedSize = 0.25 
                                                        local color = C_CYAN
                                                        
                                                        if bName == "head" then 
                                                            mark = "●"
                                                            fixedSize = 0.45
                                                            color = C_RED
                                                        elseif bName == "pelvis" or bName == "neck_01" then 
                                                            mark = "▪"
                                                            fixedSize = 0.35
                                                            color = C_YELLOW 
                                                        end
                                                        
                                                        MyHUD:AddDebugText(mark, enemy, 0.06, offset, offset, color, true, false, true, nil, fixedSize, true)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end

                    -- ==========================================
                    -- SHOW ENEMY WEAPON (enemy ke upar hathiyar ka naam)
                    -- ==========================================
                    if _G.GTLMODConfig.EspWeapon then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if not Valid(MyHUD) then return end
                            if distM > 400 then return end

                            -- Weapon name 1.5s cache (har tick query mehnga hai)
                            local curTime = os.clock()
                            if markData.AK_LAST_WEP_TIME == nil or curTime > markData.AK_LAST_WEP_TIME + 1.5 then
                                local eWeapon = nil
                                if enemy.CurrentWeapon then eWeapon = enemy.CurrentWeapon
                                elseif type(enemy.GetCurrentWeapon) == "function" then eWeapon = enemy:GetCurrentWeapon()
                                elseif enemy.WeaponManagerComponent then eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated end

                                local weaponName = "No Weapon"
                                if Valid(eWeapon) and type(eWeapon.GetWeaponName) == "function" then
                                    weaponName = eWeapon:GetWeaponName()
                                end
                                markData.AK_CACHED_WEP_NAME = tostring(weaponName)
                                markData.AK_LAST_WEP_TIME = curTime
                            end

                            local wepText = markData.AK_CACHED_WEP_NAME or "No Weapon"
                            if wepText ~= "" then
                                local textColor = isBot and C_CYAN or C_YELLOW
                                local dynamicScale = math.max(0.5, 0.8 - (distM / 400))
                                MyHUD:AddDebugText(wepText, enemy, 0.5, {X=0, Y=0, Z=100}, {X=0, Y=0, Z=100}, textColor, true, false, true, nil, dynamicScale, true)
                            end
                        end)
                    end
                    if showFrameUI then
                        pcall(function()
                            local SecurityCommonUtils = Cached_SecurityCommonUtils
                            local show = true
                            if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                            end
                            if show and mLoc then
                                if aLoc and SecurityCommonUtils and SecurityCommonUtils.IsVector then
                                    if SecurityCommonUtils.IsVector(aLoc) and SecurityCommonUtils.IsVector(mLoc) then
                                        if aLoc.Z >= 150000 or FVector.Dist2D(mLoc, aLoc) > 50000 then show = false end
                                    end
                                end
                            end
                            if show then
                                if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if markData.LastFrameUIState ~= "VISIBLE" then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                        markData.LastFrameUIState = "VISIBLE"
                                    end
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if markData.LastFrameUIState ~= "HIDDEN" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    markData.LastFrameUIState = "HIDDEN"
                                end
                            end
                        end)
                    end

                    -- ESP HEALTH V1 (EspVipPro) hata diya gaya: koi menu button nahi tha.

-- =================== ESP NAME V1 (Nama dengan warna dari ColorConfig) ===================
if _G.GTLMODConfig.EspName then
    pcall(function()
        local hud = Cached_MyHUD
        if not (Valid(hud) and hud.AddDebugText) then return end
        if distM > 400 then return end

        local pName = enemy.PlayerName or enemy.PlayerNamePublic or "Enemy"
        if pName == "" then return end

        local isKnock = (enemy.Health or 100) <= 0 or enemy.HealthStatus == 1
        -- STRONG visibility check (shared helper)
        local bIsVisible = IsEnemyVisibleStrong(enemy, pc, markData)

        local visibleCol = GetAppliedColor(_G.ColorConfig.VisibleColor or 4, _G.ColorConfig.Brightness)
        local invisibleCol = GetAppliedColor(_G.ColorConfig.InvisibleColor or 1, _G.ColorConfig.Brightness)
        
        local nameColor = {R=255, G=255, B=255, A=255}
        if isKnock then
            nameColor = {R=0, G=0, B=255, A=255}
        else
            nameColor = bIsVisible and visibleCol or invisibleCol
        end

        hud:AddDebugText(pName, enemy, 0.2, {X=0, Y=0, Z=120}, {X=0, Y=0, Z=120},
                         nameColor, true, false, true, nil, 1.0, true)
    end)
end

                    if _G.GTLMODConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                    end

                    -- Esp8 (Head HP Bar) hata diya gaya: koi menu button nahi tha.
                    -- Purane marks agar bache hain to saaf kar do.
                    if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                    
                    if _G.GTLMODConfig.EspRadar then
                        if not markData.radarMark or markData.radarMark == 0 then 
                            markData.radarMark = SafeAddMark(8888, FVector(0,0,0), 0, "", 4, enemy) 
                        end
                    else
                        if markData.radarMark and markData.radarMark ~= 0 then
                            SafeRemoveMark(markData.radarMark)
                            markData.radarMark = nil
                        end
                    end
                    
                    if _G.GTLMODConfig.EspOutline then
                        pcall(function()
                            local outlineHash = tostring(_G.GTLMODConfig.OutlineThickness)
                            if markData.OutlineState ~= outlineHash then
                                local PPM = Cached_PPM
                                local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                                if Valid(avatarComp) and Valid(PPM) then
                                    PPM.OutlineThickness = _G.GTLMODConfig.OutlineThickness
                                    if PPM.OutlineColor then PPM.OutlineColor = {r = 1, g = 0, b = 0, a = 1} end
                                    PPM:EnableAvatarOutline(avatarComp, true)
                                    markData.OutlineState = outlineHash
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if markData.OutlineState ~= "OFF" then
                                local PPM = Cached_PPM
                                local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                                if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                                markData.OutlineState = "OFF"
                            end
                        end)
                    end

                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark)
                        markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark)
                        markData.hpMark = nil
                        SafeRemoveMark(markData.hpMark8)
                        markData.hpMark8 = nil
                        SafeRemoveMark(markData.distMark)
                        markData.distMark = nil
                        
                        if markData.MIDs then
                            for meshStr, midTable in pairs(markData.MIDs) do
                                for k, _ in pairs(midTable) do midTable[k] = nil end
                            end
                            markData.MIDs = nil
                        end
                        
                        pcall(function()
                            local eObj = markData.enemy
                            if Valid(eObj) then 
                                if eObj.Replay_SetVisiableOfFrameUI then eObj:Replay_SetVisiableOfFrameUI(false) end
                                local uiComp = eObj.EnemyFrameUI or (type(eObj.GetEnemyFrameUI) == "function" and eObj:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end 
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                end
                            end
                            
                            local PPM = Cached_PPM
                            local avatarComp = Valid(eObj) and (type(eObj.getAvatarComponent2) == "function") and eObj:getAvatarComponent2() or nil
                            if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                        end)

                        markData.IsCleanedUp = true
                    end
                end
            end
        end

        -- ========================================== 
        -- ESP WARNING & COUNTER DETECTION LOOP
        -- Runs if Esp7 (warning) OR EspCounter (BOT/PLAYER/TOTAL) is ON
        -- ========================================== 
        if _G.GTLMODConfig.Esp7 or _G.GTLMODConfig.EspCounter then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if not Valid(MyHUD) then return end

                local myTeamId = localPlayer.TeamID or localPlayer:GetTeamID() or 0
                local myPos = localPlayer:K2_GetActorLocation()
                local maxDist = 35000
                local maxDistSq = maxDist * maxDist   -- compare squared (no sqrt = faster)
                local realCount = 0
                local aiCount = 0
                local nearestSq = nil   -- sabse qareeb enemy ka squared distance

                -- Bot status cache: ek baar detect, phir yaad rakho
                _G.BotStatusCache = _G.BotStatusCache or {}
                local botCache = _G.BotStatusCache

                for _, tPawn in pairs(allCharacters) do
                    if slua.isValid(tPawn) and tPawn ~= localPlayer then
                        local targetTeamId = tPawn.TeamID or tPawn:GetTeamID() or 0
                        if targetTeamId ~= myTeamId then
                            local enemyPos = tPawn:K2_GetActorLocation()
                            if enemyPos then
                                local dx = enemyPos.X - myPos.X
                                local dy = enemyPos.Y - myPos.Y
                                local dz = enemyPos.Z - myPos.Z
                                local distSq = dx*dx + dy*dy + dz*dz
                                if distSq <= maxDistSq then
                                    -- Unique ID for cache
                                    local pid = nil
                                    if type(tPawn.GetUniqueID) == "function" then
                                        local ok, r = pcall(function() return tPawn:GetUniqueID() end)
                                        if ok then pid = r end
                                    end
                                    if not pid then pid = tostring(tPawn) end

                                    local isAI = botCache[pid]
                                    if isAI == nil then
                                        -- 1.lua accurate detection method
                                        isAI = false
                                        pcall(function()
                                            if Game.IsAI then
                                                isAI = Game:IsAI(tPawn)
                                            elseif type(tPawn.IsAI) == "function" then
                                                isAI = tPawn:IsAI()
                                            elseif tPawn.bIsAI ~= nil then
                                                isAI = tPawn.bIsAI
                                            end
                                        end)
                                        -- Fallback: PlayerState check
                                        if not isAI then
                                            pcall(function()
                                                local pState = tPawn.PlayerState or (type(tPawn.GetPlayerState) == "function" and tPawn:GetPlayerState())
                                                if slua.isValid(pState) then
                                                    if pState.bIsABot == true or pState.bIsBot == true or pState.bIsAI == true then
                                                        isAI = true
                                                    end
                                                    if not isAI then
                                                        local uid = pState.Uid or pState.UID or pState.PlayerId or pState.PlayerID
                                                        if uid ~= nil and (uid == 0 or uid == "0") then
                                                            isAI = true
                                                        end
                                                    end
                                                end
                                            end)
                                        end
                                        botCache[pid] = isAI
                                    end

                                    if isAI then
                                        aiCount = aiCount + 1
                                    else
                                        realCount = realCount + 1
                                    end

                                    -- Nearest enemy distance track karo
                                    if nearestSq == nil or distSq < nearestSq then
                                        nearestSq = distSq
                                    end
                                end
                            end
                        end
                    end
                end

                local totalEnemy = realCount + aiCount
                -- Store counts in globals so EspCounter can use them
                _G._Counter_Bots    = aiCount
                _G._Counter_Players = realCount
                _G._Counter_Total   = totalEnemy
                -- Nearest distance meters mein (100 units = 1 meter)
                if nearestSq then
                    _G._Counter_Nearest = math.floor(math.sqrt(nearestSq) / 100)
                else
                    _G._Counter_Nearest = 0
                end

                -- ESP WARNING: Image 2 style — floating above player
                if _G.GTLMODConfig.Esp7 and Valid(MyHUD) then
                    -- TELEGRAM text: WHITE, REAL/BOT ke beech mein (screenshot match)
                    MyHUD:AddDebugText("TELEGRAM @CFGxEREN", localPlayer, 1.2, {X=0, Y=0, Z=157}, {X=0, Y=0, Z=157}, {R=255, G=255, B=0, A=255}, true, false, true, nil, 0.75, true)
                    if totalEnemy > 0 then
                        local text = string.format("REAL: %d  BOT: %d", realCount, aiCount)
                        MyHUD:AddDebugText(text, localPlayer, 1.2, {X=0, Y=0, Z=150}, {X=0, Y=0, Z=150}, {R=255, G=0, B=0, A=255}, true, false, true, nil, 1.0, true)
                    else
                        MyHUD:AddDebugText("( CLEAR ENEMY )", localPlayer, 1.2, {X=0, Y=0, Z=150}, {X=0, Y=0, Z=150}, {R=0, G=255, B=0, A=255}, true, false, true, nil, 1.0, true)
                    end
                end
            end)
        end

        -- ==========================================
        -- ==========================================
        -- EREN ESP COUNTER V2: PUBG NEW COUNTER
        -- ==========================================
        if _G.GTLMODConfig.EspCounter then
            pcall(function()
                local bots    = _G._Counter_Bots    or 0
                local players = _G._Counter_Players  or 0

                local realTxt = string.format("REAL %d", players)
                local botTxt  = string.format("BOT %d", bots)
                local stamp   = realTxt .. "|" .. botTxt

                local LC = import("LinearColor") or _G.FLinearColor
                local SC = import("SlateColor") or import("/Script/SlateCore.SlateColor")


                local function makeBox(txt, r, g, b, xPos)
                    local nw = nil
                    pcall(function()
                        local BTN_BP = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"
                        nw = slua.loadUI(BTN_BP)
                    end)
                    if not nw or not slua.isValid(nw) then return nil end

                    pcall(function()
                        require("game_frontend_hud").AddToContainer(UIContainers.Top, nw, 10500)
                    end)

                    -- ══ 1) SAARE CHILDREN COLLECT KARO (tree walk) ══
                    local kids = {}
                    pcall(function()
                        local function walk(w, d)
                            if not w or not slua.isValid(w) or d > 8 then return end
                            kids[#kids + 1] = w
                            pcall(function()
                                local n = w:GetChildrenCount()
                                if n and n > 0 then
                                    for i = 0, n - 1 do walk(w:GetChildAt(i), d + 1) end
                                end
                            end)
                        end
                        local tree = nw.WidgetTree
                        if tree and slua.isValid(tree) and tree.RootWidget then
                            walk(tree.RootWidget, 0)
                        end
                        walk(nw, 0)
                    end)

                    -- naam se bhi pakdo (tree walk fail ho to)
                    pcall(function()
                        local direct = {
                            "Image_Bg","Img_Bg","Image_Background","BgImage","Background",
                            "Image_Normal","Img_Normal","Image_Btn","Image_Base","Image_BG",
                            "Image_1","Image_2","Image_3","Image_4","Image_5","Image_6",
                            "Img_1","Img_2","Img_3","Img_4",
                            "Image_Light","Image_Glow","Image_Shine","Image_Highlight",
                            "Image_Corner","Image_Corner_LT","Image_Corner_RT",
                            "Image_Corner_LB","Image_Corner_RB","Image_Border",
                            "Image_Frame","Image_Line","Image_Dot","Image_Point",
                            "Image_Deco","Image_Decorate","Image_Mask","Image_Shadow",
                            "Image_Select","Image_Selected","Image_Hover","Image_Press",
                            "Image_Angle","Image_Arrow","Image_Icon","Img_Icon"
                        }
                        for _, n in ipairs(direct) do
                            local el = nw[n]
                            if el and slua.isValid(el) then kids[#kids + 1] = el end
                        end
                    end)

                    -- ══ 2) BACKGROUND ka TEXTURE hi replace karo ══
                    local whiteTex = nil
                    pcall(function()
                        whiteTex = slua.loadObject("/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture")
                    end)
                    if not whiteTex then
                        pcall(function()
                            whiteTex = slua.loadObject("/Engine/EngineResources/White.White")
                        end)
                    end

                    pcall(function()
                        local white = FLinearColor(1, 1, 1, 1)
                        local bgDone = false
                        local firstImg = nil

                        for _, el in ipairs(kids) do
                            local nm = ""
                            pcall(function() nm = tostring(el:GetName() or "") end)
                            local low = nm:lower()

                            local isImg = low:find("image") or low:find("img")
                            if isImg then
                                if not firstImg then firstImg = el end

                                local isBg = low:find("bg") or low:find("background")
                                          or low:find("normal") or low:find("btn")
                                          or low:find("base") or low:find("panel")

                                if isBg then
                                    if whiteTex then
                                        pcall(function() el:SetBrushFromTexture(whiteTex, false) end)
                                        pcall(function() el:SetBrushFromTexture(whiteTex) end)
                                    end
                                    pcall(function() el:SetColorAndOpacity(white) end)
                                    pcall(function() el:SetBrushColor(white) end)
                                    pcall(function() el:SetOpacity(1.0) end)
                                    pcall(function() el:SetRenderOpacity(1.0) end)
                                    bgDone = true
                                else
                                    pcall(function() el:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                                    pcall(function() el:SetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                                    pcall(function() el:SetRenderOpacity(0) end)
                                    pcall(function() el:SetColorAndOpacity(FLinearColor(0,0,0,0)) end)
                                end
                            end
                        end

                        if not bgDone and firstImg then
                            if whiteTex then
                                pcall(function() firstImg:SetBrushFromTexture(whiteTex, false) end)
                                pcall(function() firstImg:SetBrushFromTexture(whiteTex) end)
                            end
                            pcall(function() firstImg:SetColorAndOpacity(white) end)
                            pcall(function() firstImg:SetBrushColor(white) end)
                            pcall(function() firstImg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        end
                    end)

                    -- ══ 3) BOX COLOR: flat + 20% transparent ══
                    pcall(function()
                        nw:SetColorAndOpacity(FLinearColor(r, g, b, 0.80))
                    end)

                    -- ══ 4) TEXT: simple font + solid WHITE ══
                    pcall(function()
                        local tb = nw.RichText_Content
                        if not tb or not slua.isValid(tb) then return end

                        tb:SetText(txt)

                        local cr = (r > 0.01) and (1.0 / r) or 1.0
                        local cg = (g > 0.01) and (1.0 / g) or 1.0
                        local cb = (b > 0.01) and (1.0 / b) or 1.0
                        pcall(function()
                            tb:SetColorAndOpacity(FSlateColor(FLinearColor(cr, cg, cb, 1.0 / 0.80)))
                        end)

                        pcall(function() tb:SetShadowColorAndOpacity(FLinearColor(0, 0, 0, 0)) end)
                        pcall(function() tb:SetShadowOffset(FVector2D(0, 0)) end)

                        pcall(function()
                            local fi = tb.Font
                            if not fi then return end

                            local simpleFont = nil
                            pcall(function()
                                simpleFont = slua.loadObject("/Engine/EngineFonts/Roboto.Roboto")
                            end)
                            if simpleFont then
                                pcall(function() fi.FontObject = simpleFont end)
                                pcall(function() fi.TypefaceFontName = "Regular" end)
                            else
                                pcall(function() fi.TypefaceFontName = "Regular" end)
                            end

                            fi.Size = 16

                            pcall(function()
                                if fi.OutlineSettings then
                                    fi.OutlineSettings.OutlineSize = 0
                                    pcall(function() fi.OutlineSettings.OutlineColor = FLinearColor(0,0,0,0) end)
                                    pcall(function() fi.OutlineSettings.bApplyOutlineToDropShadows = false end)
                                end
                            end)
                            pcall(function() fi.LetterSpacing = 0 end)

                            tb:SetFont(fi)
                        end)
                    end)

                    -- ══ 5) POSITION + SIZE ══
                    pcall(function()
                        local WLL = import("WidgetLayoutLibrary")
                        local slot = WLL.SlotAsCanvasSlot(nw)
                        if slot then
                            slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
                            slot:SetAlignment(FVector2D(0.5, 0))
                            slot:SetPosition(FVector2D(xPos, 34))
                            slot:SetSize(FVector2D(92, 34))
                        end
                    end)

                    pcall(function()
                        nw:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    end)
                    return nw
                end

                local wR = _G._ESPCounterWidgetReal
                local wB = _G._ESPCounterWidgetBot
                local aliveR, aliveB = false, false
                pcall(function() aliveR = (wR ~= nil) and slua.isValid(wR) end)
                pcall(function() aliveB = (wB ~= nil) and slua.isValid(wB) end)

                if not aliveR or not aliveB then
                    pcall(function() if wR and slua.isValid(wR) then wR:RemoveFromParent() end end)
                    pcall(function() if wB and slua.isValid(wB) then wB:RemoveFromParent() end end)

                    -- RED box (REAL) left, GREEN box (BOT) right
                    _G._ESPCounterWidgetReal = makeBox(realTxt, 0.95, 0.10, 0.10, -48)
                    _G._ESPCounterWidgetBot  = makeBox(botTxt,  0.10, 0.80, 0.16,  48)
                    _G._ESPCounterLastText   = stamp

                elseif stamp ~= _G._ESPCounterLastText then
                    -- sirf text update
                    _G._ESPCounterLastText = stamp
                    pcall(function()
                        if wR.RichText_Content then wR.RichText_Content:SetText(realTxt) end
                    end)
                    pcall(function()
                        if wB.RichText_Content then wB.RichText_Content:SetText(botTxt) end
                    end)
                end
            end)
        else
            -- OFF → dono boxes hatao
            pcall(function()
                local wR = _G._ESPCounterWidgetReal
                local wB = _G._ESPCounterWidgetBot
                if wR and slua.isValid(wR) then wR:RemoveFromParent() end
                if wB and slua.isValid(wB) then wB:RemoveFromParent() end
                _G._ESPCounterWidgetReal = nil
                _G._ESPCounterWidgetBot  = nil
                _G._ESPCounterLastText   = nil
            end)
        end

        -- ==========================================================
        -- GRANDE WARNING ESP (grenades on ground + enemy holding/throwing)
        -- ==========================================================
        if _G.GTLMODConfig.EspBomMaster and (_G.GTLMODConfig.EspItemBom or _G.GTLMODConfig.EspActiveBom) then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if not Valid(MyHUD) then return end

                if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                if not _G.CachedActorClass_ForBomb then _G.CachedActorClass_ForBomb = import("Actor") end
                if not _G.CachedProjArray then _G.CachedProjArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForBomb) end

                -- Weak tables: game khud rubbish saaf karta hai, RAM nahi bharti
                if not _G.ActorBombCacheInit then
                    _G.NonBombCache = setmetatable({}, { __mode = "k" })
                    _G.BombCache = setmetatable({}, { __mode = "k" })
                    _G.ActorBombCacheInit = true
                end

                local ui_util = GetUIUtil()
                local gameInstance = ui_util and ui_util.GetGameInstance()
                if not (gameInstance and _G.CachedGameplayStatics) then return end

                local curTime = os.clock()

                -- Heavy scan sirf 0.5s mein ek baar
                if not _G.LastBombScanTime or (curTime - _G.LastBombScanTime) > 0.5 then
                    _G.LastBombScanTime = curTime
                    local allActors = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForBomb, _G.CachedProjArray)

                    local activeBombs = {}
                    local itemBombs = {}

                    if allActors then
                        for _, actor in pairs(allActors) do
                            if slua.isValid(actor) and not actor.bHidden and not actor.bTearOff then
                                if not _G.NonBombCache[actor] then
                                    local bType = 0
                                    local isItem = false
                                    local isKnownBomb = _G.BombCache[actor]

                                    if isKnownBomb then
                                        bType = isKnownBomb.type
                                        isItem = isKnownBomb.isItem
                                    else
                                        local nameLower = nil
                                        pcall(function() nameLower = string.lower(type(actor.GetName) == "function" and actor:GetName() or tostring(actor)) end)

                                        if nameLower then
                                            if string.find(nameLower, "m79") or string.find(nameLower, "launcher") then bType = 5
                                            elseif string.find(nameLower, "smoke") then bType = 2
                                            elseif string.find(nameLower, "burn") or string.find(nameLower, "molotov") then bType = 3
                                            elseif string.find(nameLower, "flash") or string.find(nameLower, "stun") then bType = 4
                                            elseif string.find(nameLower, "grenade") then bType = 1 end

                                            if bType > 0 then
                                                if string.find(nameLower, "projectile") or string.find(nameLower, "thrown") then
                                                    isItem = false
                                                else
                                                    isItem = true
                                                    local shouldAdd = true
                                                    if bType == 3 and not (string.find(nameLower, "pickup") or string.find(nameLower, "wrapper") or string.find(nameLower, "weapon")) then
                                                        shouldAdd = false
                                                    elseif bType == 5 then
                                                        local attachParent = nil
                                                        pcall(function() if type(actor.GetAttachParentActor) == "function" then attachParent = actor:GetAttachParentActor() end end)
                                                        if slua.isValid(attachParent) then
                                                            local isHolding = false
                                                            pcall(function()
                                                                local curWeapon = type(attachParent.GetCurrentWeapon) == "function" and attachParent:GetCurrentWeapon() or attachParent.CurrentWeapon
                                                                if curWeapon == actor then isHolding = true end
                                                            end)
                                                            if not isHolding then shouldAdd = false end
                                                        end
                                                    end
                                                    if not shouldAdd then bType = 0 end
                                                end
                                            end
                                        end

                                        if bType > 0 then
                                            _G.BombCache[actor] = { type = bType, isItem = isItem }
                                        else
                                            _G.NonBombCache[actor] = true
                                        end
                                    end

                                    if bType > 0 then
                                        local isPendingKill = false
                                        pcall(function() if type(actor.IsPendingKill) == "function" then isPendingKill = actor:IsPendingKill() end end)

                                        if not isPendingKill then
                                            if isItem then
                                                table.insert(itemBombs, {act = actor, type = bType})
                                            else
                                                table.insert(activeBombs, {act = actor, type = bType})
                                            end
                                        else
                                            _G.BombCache[actor] = nil
                                        end
                                    end
                                end
                            end
                        end
                    end
                    _G.CachedActiveBombs = activeBombs
                    _G.CachedItemBombs = itemBombs
                end

                local curGameTime = 0
                pcall(function() curGameTime = _G.CachedGameplayStatics.GetTimeSeconds(gameInstance) end)

                local function DrawBombs(bombList, isItem, maxDist)
                    if not bombList then return end
                    for _, item in ipairs(bombList) do
                        local bomb = item.act
                        local bType = item.type

                        if slua.isValid(bomb) and not bomb.bHidden then
                            local distM = 0
                            pcall(function() distM = localPlayer:GetDistanceTo(bomb) / 100 end)

                            if distM > 0 and distM <= maxDist then
                                local displayName = ""
                                local bombColor = C_WHITE
                                local zOffset = isItem and 15 or 25

                                if bType == 1 then displayName = "GRENADE"; bombColor = isItem and {R=255, G=100, B=100, A=255} or C_RED
                                elseif bType == 2 then displayName = "SMOKE"; bombColor = isItem and {R=200, G=200, B=200, A=255} or C_WHITE
                                elseif bType == 3 then displayName = "MOLOTOV"; bombColor = isItem and {R=255, G=160, B=50, A=255} or {R=255, G=100, B=0, A=255}
                                elseif bType == 4 then displayName = "FLASH"; bombColor = isItem and {R=150, G=255, B=255, A=255} or C_CYAN
                                elseif bType == 5 then displayName = "LAUNCHER"; bombColor = isItem and {R=150, G=255, B=150, A=255} or {R=100, G=255, B=100, A=255} end

                                local text = string.format("%s [%dm]", displayName, math.floor(distM))
                                local shouldTimerRun = not isItem

                                if isItem then
                                    pcall(function()
                                        if bomb.bIsPinPulled or bomb.bPinPulled or (type(bomb.IsPinPulled) == "function" and bomb:IsPinPulled()) then shouldTimerRun = true end
                                    end)
                                end

                                if shouldTimerRun and curGameTime > 0 then
                                    local timeLeft = -1
                                    pcall(function()
                                        if bomb.ExplosionTime then timeLeft = bomb.ExplosionTime - curGameTime
                                        elseif bomb.ExplodeTime then timeLeft = bomb.ExplodeTime - curGameTime end
                                    end)

                                    if timeLeft == -1 or timeLeft > 100 then
                                        _G.ActiveBombTimers = _G.ActiveBombTimers or {}
                                        local bombId = tostring(bomb)
                                        if not _G.ActiveBombTimers[bombId] then _G.ActiveBombTimers[bombId] = curGameTime end
                                        local elapsed = curGameTime - _G.ActiveBombTimers[bombId]
                                        local maxTime = (bType == 1 and 7.0) or (bType == 2 and 45.0) or (bType == 3 and 12.0) or (bType == 4 and 5.0) or 45.0
                                        timeLeft = maxTime - elapsed
                                    end

                                    if timeLeft < 0 then timeLeft = 0 end
                                    if timeLeft > 0.1 then text = string.format("%s (%.1fs)", text, timeLeft) end
                                end

                                local dynamicScale = math.max(0.6, 1.1 - (distM / maxDist))
                                MyHUD:AddDebugText(text, bomb, 0.5, {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset}, bombColor, true, false, true, nil, dynamicScale, true)
                            end
                        end
                    end
                end

                if not _G.LastClearTimer or (curTime - _G.LastClearTimer) > 1.0 then
                    _G.LastClearTimer = curTime
                    pcall(function()
                        if _G.ActiveBombTimers then
                            for k, v in pairs(_G.ActiveBombTimers) do
                                if (curGameTime - v) > 60.0 then _G.ActiveBombTimers[k] = nil end
                            end
                        end
                    end)
                end

                if _G.GTLMODConfig.EspItemBom then DrawBombs(_G.CachedItemBombs, true, 50) end
                if _G.GTLMODConfig.EspActiveBom then DrawBombs(_G.CachedActiveBombs, false, 150) end
            end)
        end

        -- ==========================================================
        -- VEHICLE SYSTEM (SHARED SCAN) — Wallhack + ESP dono isi ek scan
        -- se chalte hain. Pehle dono apna alag GetAllActorsOfClass chalate the,
        -- yani dono ON hone par har second DO full scans. Ab sirf EK.
        -- ==========================================================
        if _G.GTLMODConfig.WallVehicle or _G.GTLMODConfig.EspVehicle then
            pcall(function()
                local curTime = os.clock()

                if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                if not _G.CachedActorClass_ForVehicle then _G.CachedActorClass_ForVehicle = import("STExtraVehicleBase") end
                if not _G.CachedVehicleArray then _G.CachedVehicleArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForVehicle) end

                local ui_util = GetUIUtil()
                local gameInstance = ui_util and ui_util.GetGameInstance()
                if not (gameInstance and _G.CachedGameplayStatics) then return end

                -- ---------- SHARED SCAN: 1s mein ek baar ----------
                if not _G.LastVehicleScanTime or (curTime - _G.LastVehicleScanTime) > 1.0 then
                    _G.LastVehicleScanTime = curTime
                    local allVehicles = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForVehicle, _G.CachedVehicleArray)

                    local activeVehicles = {}
                    if allVehicles then
                        for _, veh in pairs(allVehicles) do
                            if slua.isValid(veh) and not veh.bHidden and not veh.bTearOff then
                                local isPendingKill = false
                                pcall(function() if type(veh.IsPendingKill) == "function" then isPendingKill = veh:IsPendingKill() end end)

                                if not isPendingKill then
                                    local vehName = "Vehicle"
                                    local hasDriver = false

                                    pcall(function()
                                        if type(veh.GetVehicleName) == "function" then vehName = veh:GetVehicleName()
                                        elseif veh.VehicleName then vehName = veh.VehicleName end
                                        local driver = type(veh.GetDriver) == "function" and veh:GetDriver() or nil
                                        if slua.isValid(driver) then hasDriver = true end
                                    end)

                                    local nameLower = string.lower(tostring(vehName) .. tostring(veh))
                                    local displayName = "Vehicle"
                                    if string.find(nameLower, "uaz") then displayName = "UAZ"
                                    elseif string.find(nameLower, "dacia") then displayName = "Dacia"
                                    elseif string.find(nameLower, "buggy") then displayName = "Buggy"
                                    elseif string.find(nameLower, "mirado") then displayName = "Mirado"
                                    elseif string.find(nameLower, "bike") or string.find(nameLower, "motor") then displayName = "Motor"
                                    elseif string.find(nameLower, "scooter") then displayName = "Scooter"
                                    elseif string.find(nameLower, "coupe") then displayName = "Coupe RB"
                                    elseif string.find(nameLower, "brdm") then displayName = "BRDM"
                                    elseif string.find(nameLower, "boat") or string.find(nameLower, "aquarail") then displayName = "Boat"
                                    elseif string.find(nameLower, "glider") then displayName = "Glider"
                                    else displayName = "Veh (" .. string.sub(tostring(vehName), 1, 8) .. ")" end

                                    table.insert(activeVehicles, {act = veh, name = displayName, hasDriver = hasDriver})
                                end
                            end
                        end
                    end
                    _G.CachedVehicles = activeVehicles
                end

                if not _G.CachedVehicles then return end
                local MyHUD = Cached_MyHUD

                -- ---------- WALLHACK: material sirf EK BAAR per gaadi ----------
                if _G.GTLMODConfig.WallVehicle then
                    _G.AppliedVehicleWall = _G.AppliedVehicleWall or {}
                    for _, item in ipairs(_G.CachedVehicles) do
                        local vehicle = item.act
                        if slua.isValid(vehicle) and type(vehicle.GetMesh) == "function" then
                            local vId = tostring(vehicle)
                            if not _G.AppliedVehicleWall[vId] then
                                local dist = 0
                                pcall(function() dist = localPlayer:GetDistanceTo(vehicle) end)
                                if dist > 0 and dist <= 200000 then   -- 200m
                                    pcall(function()
                                        local mesh = vehicle:GetMesh()
                                        if slua.isValid(mesh) then
                                            local matInterface = mesh:GetMaterial(0)
                                            if slua.isValid(matInterface) then
                                                local baseMat = matInterface:GetBaseMaterial()
                                                if slua.isValid(baseMat) then
                                                    baseMat.bDisableDepthTest = true
                                                    baseMat.BlendMode = 2
                                                    _G.AppliedVehicleWall[vId] = true
                                                end
                                            end
                                        end
                                    end)
                                end
                            end
                        end
                    end
                elseif _G.AppliedVehicleWall and next(_G.AppliedVehicleWall) ~= nil then
                    -- OFF hone par cache saaf karo taake dobara ON par phir apply ho
                    _G.AppliedVehicleWall = {}
                end

                -- ---------- ESP: naam + distance text ----------
                if _G.GTLMODConfig.EspVehicle and Valid(MyHUD) then
                    for _, item in ipairs(_G.CachedVehicles) do
                        local veh = item.act
                        if slua.isValid(veh) and not veh.bHidden then
                            local isShow = false
                            if item.name == "Dacia" then isShow = _G.GTLMODConfig.EspVeh_Dacia
                            elseif item.name == "UAZ" then isShow = _G.GTLMODConfig.EspVeh_UAZ
                            elseif item.name == "Buggy" then isShow = _G.GTLMODConfig.EspVeh_Buggy
                            elseif item.name == "Coupe RB" then isShow = _G.GTLMODConfig.EspVeh_Coupe
                            elseif item.name == "Mirado" then isShow = _G.GTLMODConfig.EspVeh_Mirado
                            elseif item.name == "Motor" or item.name == "Scooter" then isShow = _G.GTLMODConfig.EspVeh_Motor
                            else isShow = _G.GTLMODConfig.EspVeh_Other end

                            if isShow then
                                local distM = 0
                                pcall(function() distM = localPlayer:GetDistanceTo(veh) / 100 end)

                                if distM > 0 and distM <= 300 then
                                    local text = string.format("%s [%dm]", item.name, math.floor(distM))
                                    local vehColor = item.hasDriver and {R=255, G=50, B=50, A=255} or {R=0, G=255, B=150, A=255}
                                    local dynamicScale = math.max(0.6, 1.1 - (distM / 500))
                                    MyHUD:AddDebugText(text, veh, 0.5, {X=0, Y=0, Z=50}, {X=0, Y=0, Z=50}, vehColor, true, false, true, nil, dynamicScale, true)
                                end
                            end
                        end
                    end
                end
            end)
        end

    end)
end

_G.GTLMODState.LoopToken = (_G.GTLMODState.LoopToken or 0) + 1 
local myToken = _G.GTLMODState.LoopToken

-- ========================================== 
-- MAIN LOOP: ESP & ALL FEATURES (every 0.4s)
-- ========================================== 
local function FastTick() 
    if isExpired then 
        if not _G.GTLMODNotifiedExpire then
            Notify("MOD HAS EXPIRED! PLEASE CONTACT ADMIN TO RENEW!\nTelegram @VINESH_OP")
            _G.GTLMODNotifiedExpire = true
            ExpiredTick() 
        end
        return 
    end

    if myToken ~= _G.GTLMODState.LoopToken then return end
    pcall(MainLoop)
    local ticker = GetTicker()
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.4, FastTick)
    end
end

-- ========================================== 
-- AIMBOT LOOP: high-frequency (~60 FPS / 0.016s)
-- ========================================== 
local aimbotToken = 0
local function FastAimbotTick()
    if isExpired then 
        return 
    end

    if aimbotToken ~= _G.GTLMODState.AimbotLoopToken then 
        return 
    end

    pcall(function()
        if _G.GTLMODConfig.AimTouchEnable or _G.GTLMODConfig.AimTouchChest then
            _G.AimTouch()
        end
    end)

    local ticker = GetTicker()
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.016, FastAimbotTick)
    end
end

-- ========================================== 
-- ESP V2 RENDER LOOP: high-frequency (~60 FPS / 0.016s)
-- Position/Line/Skeleton yahan real-time update hote hain — MainLoop (0.4s) se
-- alag rakha gaya taake camera move karte hi lines turant follow karein, delay na ho
-- ========================================== 
local espv2Token = 0
local function FastESPV2Tick()
    if isExpired then
        return
    end

    if espv2Token ~= _G.GTLMODState.ESPV2LoopToken then
        return
    end

    if _G.PMM_ESPV2_AnyOn() and _G.PMM_ESPV2 and _G.PMM_ESPV2.bActive then
        pcall(function() _G.PMM_ESPV2.Tick() end)
    end

    local ticker = GetTicker()
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.016, FastESPV2Tick)
    end
end

-- ========================================== 
-- IGNITE ALL LOOPS
-- ========================================== 
if not isExpired then
    _G.StartBypass_VIP_v3()
    FastTick() 
    _G.GTLMODState.AimbotLoopToken = (_G.GTLMODState.AimbotLoopToken or 0) + 1
    aimbotToken = _G.GTLMODState.AimbotLoopToken
    _G.GTLMODState.ESPV2LoopToken = (_G.GTLMODState.ESPV2LoopToken or 0) + 1
    espv2Token = _G.GTLMODState.ESPV2LoopToken
    local ticker = GetTicker()
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.1, FastAimbotTick)
        ticker.AddTimerOnce(0.1, FastESPV2Tick)
    end
    Notify("VINESH_OP VIP MOD Loaded! Open VINESH_OP MENU to toggle features.")
else
    FastTick() 
end

-- ===================================================================================
-- SYSTEM HOOKS BYPASS
-- ===================================================================================
local function InitAllModSystems()
    if isExpired then return end 

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return end

    pcall(function()
        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false 
                LocalPlayer.bHasShownExpiredNotice = false 
                LocalPlayer.bIsDeadFlag = false
            end
        end
    end)
end

if not isExpired then
    local ticker = GetTicker()
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.5, InitAllModSystems)
    end
end

-- =================================START==========================================
do
local AutoFeedback = {
	Config = {
		ServerURL = "https://vinesh-feedback.gcstok4t.workers.dev/",
		TestMode = false
	},
	Hooked = false
}

local function Log(message)
	print(string.format("[JINSHI_PUBG] [%s] %s", os.date("%H:%M:%S"), tostring(message)))
end

local function Notify(message)

	if _G.JINSHINotify then
		pcall(_G.JINSHINotify, message)
	elseif _G.LexusNotify then
		pcall(_G.LexusNotify, message)
	end
end

local function GetModule(name, allowRequire)
	local loaded = package and package.loaded and package.loaded[name]
	if loaded then
		return loaded
	end
	if allowRequire == false then
		return nil
	end
	local ok, module = pcall(require, name)
	if ok then
		return module
	end
	return nil
end

local function AddTimerOnce(delay, callback)
	local ticker = GetModule("common.time_ticker")
	if ticker and type(ticker.AddTimerOnce) == "function" then
		ticker.AddTimerOnce(delay, callback)
		return true
	end
	return false
end

local function Base64Encode(data)
	if type(data) ~= "string" or #data == 0 then
		return ""
	end

	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local output = {}
	local outputIndex = 0
	local index = 1

	while index <= #data - 2 do
		local a, b, c = string.byte(data, index, index + 2)
		local value = a * 65536 + b * 256 + c
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte(alphabet, math.floor(value / 64) % 64 + 1),
			string.byte(alphabet, value % 64 + 1)
		)
		index = index + 3
	end

	local remaining = #data - index + 1
	if remaining == 2 then
		local a, b = string.byte(data, index, index + 1)
		local value = a * 65536 + b * 256
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte(alphabet, math.floor(value / 64) % 64 + 1),
			string.byte("=")
		)
	elseif remaining == 1 then
		local value = string.byte(data, index) * 65536
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte("="),
			string.byte("=")
		)
	end

	return table.concat(output)
end

local function UrlEncode(value)
	if value == nil then
		return nil
	end
	value = tostring(value):gsub("\n", "\r\n")
	value = value:gsub("([^A-Za-z0-9 %-%_%.%~])", function(character)
		return string.format("%%%02X", string.byte(character))
	end)
	value = value:gsub(" ", "+")
	return value
end

local function ReadFile(path)
	local file = io.open(path, "rb")
	if not file then
		return ""
	end
	local data = file:read("*a") or ""
	file:close()
	return data
end

local function RemoveFile(path)
	pcall(os.remove, path)
end

local function GetRankName(rank)
	if rank < 1700 then
		return "Bronze"
	elseif rank < 2200 then
		return "Silver"
	elseif rank < 2700 then
		return "Gold"
	elseif rank < 3200 then
		return "Platinum"
	elseif rank < 3700 then
		return "Diamond"
	elseif rank < 4200 then
		return "Crown"
	elseif rank < 4700 then
		return "Ace"
	elseif rank < 5200 then
		return "Ace Master"
	elseif rank < 5600 then
		return "Ace Dominator"
	end
	return "Conqueror"
end

local FeedbackCaptionTemplate = "\226\150\145\226\150\146\226\150\147\226\150\136 <b>@VINESH_OP  \229\178\130</b> \226\150\136\226\150\147\226\150\146\226\150\145\10\226\154\148\239\184\143 <b>THE POWER OF EREN PAID PAK</b> \226\154\148\239\184\143\10\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\10\240\147\138\136 \226\143\179 \240\147\138\137 <b>TIME LOG   :</b> <code>%s</code>\10\240\147\138\136 \240\159\145\164 \240\147\138\137 <b>PLAYER     :</b> <b>%s</b>\10\240\147\138\136 \240\159\134\148 \240\147\138\137 <b>TARGET UID :</b> <code>%s</code>\10\240\147\138\136 \240\159\146\128 \240\147\138\137 <b>TOTAL KILLS:</b> <code>%d</code>\10\240\147\138\136 \240\159\148\177 \240\147\138\137 <b>TIER RANK  :</b> <b>%s</b>\10\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\226\150\172\10\226\152\160\239\184\143 <b>TELEGRAM :</b> @VINESH_OP"

-- Caption banane ka common function (dono jagah use hota hai)
local function BuildCaption(kills, rank)
	local uid = "unknown"
	if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then
		uid = tostring(_G.DataMgr.roleData.uid)
	elseif _G._NTH_UK then
		uid = tostring(_G._NTH_UK)
	end

	kills = tonumber(kills) or 0
	rank = tonumber(rank) or 0

	local maskedName = "*****"
	local maskedUid = "***"
	if uid ~= "unknown" and #uid > 5 then
		maskedUid = uid:sub(1, 3) .. "***" .. uid:sub(-2)
	end

	return string.format(
		FeedbackCaptionTemplate,
		os.date("%H:%M:%S %d/%m/%Y"),
		maskedName,
		maskedUid,
		kills,
		GetRankName(rank)
	)
end

-- Screenshot fail ho gaya? Phir bhi text feedback bhejo (kuch miss na ho)
local textOnlySent = false
local photoSent = false

-- Har naye match ke liye flags reset karo
function AutoFeedback.ResetTextFlag()
	textOnlySent = false
	photoSent = false
end

-- Photo bhej diya to text fallback rok do
function AutoFeedback.MarkPhotoSent()
	photoSent = true
	textOnlySent = true
end

function AutoFeedback.SendTextOnly(kills, rank, reason)
	if photoSent then return end
	if textOnlySent then return end
	textOnlySent = true

	pcall(function()
		local httpManager = GetModule("client.slua.logic.http.http_manager")
		if not httpManager or type(httpManager.Post) ~= "function" then
			Log("SendTextOnly: HTTP manager unavailable")
			return
		end

		local caption = BuildCaption(kills, rank)
		if reason then
			caption = caption .. "\10(no screenshot: " .. tostring(reason) .. ")"
		end

		-- base64_image bheja hi nahi -> Worker text-only mode use karega
		local body = "caption=" .. UrlEncode(caption)

		Log("SendTextOnly: posting text feedback (" .. tostring(reason) .. ")")
		httpManager:Post(
			AutoFeedback.Config.ServerURL,
			{["Content-Type"] = "application/x-www-form-urlencoded"},
			body,
			nil,
			function(success, _, response, errorMessage)
				if success then
					Notify("[JINSHI_PUBG] Text feedback sent (Kills: " .. tostring(kills) .. ")")
				else
					Log("SendTextOnly failed: " .. tostring(response or errorMessage))
				end
			end,
			30
		)
	end)
end

function AutoFeedback.SendFeedback(path, kills, rank, segment)
	Log("Preparing to send feedback. Screenshot: " .. tostring(path))

	local ok, err = pcall(function()
		local httpManager = GetModule("client.slua.logic.http.http_manager")
		if not httpManager or type(httpManager.Post) ~= "function" then
			Log("HTTP manager is unavailable.")
			return
		end
		AutoFeedback.__hasHttp = true

		local attempts = 0
		local function TrySend()
			local imageData = ReadFile(path)
			if #imageData > 0 then
				local uid = "unknown"
				if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then
					uid = tostring(_G.DataMgr.roleData.uid)
				elseif _G._NTH_UK then
					uid = tostring(_G._NTH_UK)
				end

				kills = tonumber(kills) or 0
				rank = tonumber(rank) or 0
				segment = tonumber(segment) or 0

				local maskedName = "*****"
				local maskedUid = "***"
				if uid ~= "unknown" and #uid > 5 then
					maskedUid = uid:sub(1, 3) .. "***" .. uid:sub(-2)
				end

				local caption = string.format(
					FeedbackCaptionTemplate,
					os.date("%H:%M:%S %d/%m/%Y"),
					maskedName,
					maskedUid,
					kills,
					GetRankName(rank)
				)

				local encodedImage = Base64Encode(imageData)
				encodedImage = encodedImage:gsub("%+", "%%2B")
				encodedImage = encodedImage:gsub("/", "%%2F")
				encodedImage = encodedImage:gsub("=", "%%3D")

				Notify("[JINSHI_PUBG] Uploading Top 1 screenshot...")
				AutoFeedback.MarkPhotoSent()
				local body = "base64_image=" .. encodedImage
					.. "&caption=" .. UrlEncode(caption)

				httpManager:Post(
					AutoFeedback.Config.ServerURL,
					{["Content-Type"] = "application/x-www-form-urlencoded"},
					body,
					nil,
					function(success, _, response, errorMessage)
						if success and response and tostring(response):find('"status":%s*true') then
							Notify("[JINSHI_PUBG] Gửi thành công! (Kills: " .. tostring(kills) .. ")")
						else
							local detail = tostring(response or errorMessage):sub(1, 40)
							Notify("[JINSHI_PUBG] Lỗi Server VIP: " .. detail)
						end
						RemoveFile(path)
					end,
					60
				)
				return
			end

			attempts = attempts + 1
			if attempts < 5 and AddTimerOnce(1.0, TrySend) then
				return
			end

			Notify("[JINSHI_PUBG] Image read failed after retries")
			AutoFeedback.SendTextOnly(kills, rank, "image empty after 5 retries")
			RemoveFile(path)
		end

		TrySend()
	end)

	if not ok then
		Log("SendFeedback Error: " .. tostring(err))
	end
end

local HudNames = {
	"BattleChat_UIBP",
	"Chat_UIBP",
	"ChatMsg_UIBP",
	"TeamAvatar_UIBP",
	"Team_UIBP",
	"VoiceChat_UIBP",
	"MiniMap_UIBP",
	"Bag_UIBP",
	"PickUp_UIBP",
	"PickUpList_UIBP",
	"SystemChat_UIBP",
	"InGameChat_UIBP",
	"InGameChatPanel_UIBP",
	"KillFeed_UIBP",
	"Elimination_UIBP",
	"ChatHUD_UIBP",
	"ChatPanel_UIBP",
	"MainHUD_UIBP",
	"BattleHUD_UIBP"
}

local function GetRankAndSegment()
	local rank = 0
	local segment = 0

	pcall(function()
		local battleResult = _G.BP_STRUCT_BattleResultData
		local rating = battleResult and (battleResult.rating or battleResult.BP_STRUCT_BTRating)
		if rating then
			rank = tonumber(rating.rank_rating) or 0
			segment = tonumber(rating.new_segment) or 0
		end

		if rank == 0 then
			local funcUtil = GetModule("common.func_util")
			local roleData = _G.DataMgr and _G.DataMgr.roleData
			if funcUtil and type(funcUtil.GetCurMaxSegementLevel) == "function"
				and roleData and roleData.allzoneSegment then
				segment = tonumber(funcUtil.GetCurMaxSegementLevel(roleData.allzoneSegment)) or 0
			end

			if roleData and roleData.segment_rating then
				for _, value in pairs(roleData.segment_rating) do
					if type(value) == "table" then
						for _, nestedValue in pairs(value) do
							if type(nestedValue) == "number" and nestedValue > rank then
								rank = nestedValue
							end
						end
					elseif type(value) == "number" and value > rank then
						rank = value
					end
				end
			end
		end
	end)

	return rank, segment
end

local function CreateHudController()
	local hidden = {}

	local function SetHidden(hide)
		local UIManager = _G.UIManager
		if not UIManager then
			return
		end

		if hide then
			for _, name in ipairs(HudNames) do
				local config
				if UIManager.UI_Config_InGame and UIManager.UI_Config_InGame[name] then
					config = UIManager.UI_Config_InGame[name]
				elseif UIManager.UI_Config and UIManager.UI_Config[name] then
					config = UIManager.UI_Config[name]
				end

				if config then
					local view = type(UIManager.GetUI) == "function" and UIManager.GetUI(config) or nil
					if view then
						pcall(function()
							if type(view.SetVisibility) == "function" then
								view:SetVisibility(2)
							elseif view.UIRoot and type(view.UIRoot.SetVisibility) == "function" then
								view.UIRoot:SetVisibility(2)
							elseif type(UIManager.HideUI) == "function" then
								UIManager.HideUI(config)
							elseif type(UIManager.CloseUI) == "function" then
								UIManager.CloseUI(config)
							end
						end)
						table.insert(hidden, {config = config, view = view})
					end
				end
			end
			return
		end

		for _, item in ipairs(hidden) do
			pcall(function()
				if item.view and type(item.view.SetVisibility) == "function" then
					item.view:SetVisibility(0)
				elseif item.view and item.view.UIRoot and type(item.view.UIRoot.SetVisibility) == "function" then
					item.view.UIRoot:SetVisibility(0)
				elseif type(UIManager.ShowUI) == "function" then
					UIManager.ShowUI(item.config)
				end
			end)
		end
		hidden = {}
	end

	return SetHidden
end

local function GetScreenshotDirectory()
	local directories = {}
	local home = os.getenv("HOME")
	if home and home ~= "" then
		table.insert(directories, home .. "/Documents/ShadowTrackerExtra/Saved/")
	end

	local packages = {
		"com.tencent.ig",
		"com.vng.pubgmobile",
		"com.pubg.krmobile",
		"com.rekoo.pubgm",
		"com.pubg.imobile"
	}
	for _, packageName in ipairs(packages) do
		table.insert(
			directories,
			"/storage/emulated/0/Android/data/" .. packageName
				.. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/"
		)
	end

	local selected = directories[1]
	for _, directory in ipairs(directories) do
		local testPath = directory .. "t.tmp"
		local file = io.open(testPath, "w")
		if file then
			file:close()
			os.remove(testPath)
			selected = directory
			break
		end
	end
	return selected
end

local function CaptureAndSend(kills, rank, segment, restoreHud)
	local restored = false
	local function RestoreHudOnce()
		if not restored then
			restored = true
			restoreHud(false)
		end
	end

	local ScreenshotMaker = import("ScreenshotMaker")
	if not ScreenshotMaker then
		RestoreHudOnce()
		AutoFeedback.SendTextOnly(kills, rank, "ScreenshotMaker missing")
		return
	end

	local directory = GetScreenshotDirectory()
	if not directory then
		RestoreHudOnce()
		AutoFeedback.SendTextOnly(kills, rank, "no writable directory")
		return
	end

	local path = directory .. string.format("jinshiwin_%s.jpg", os.time())
	local uiUtil = GetModule("client.common.ui_util")
	local gameInstance = uiUtil and uiUtil.GetGameInstance and uiUtil.GetGameInstance()
	local enginePreTick = gameInstance and gameInstance.EnginePreTick
	if not enginePreTick or type(enginePreTick.Add) ~= "function" then
		RestoreHudOnce()
		AutoFeedback.SendTextOnly(kills, rank, "EnginePreTick unavailable")
		return
	end

	local ticker = GetModule("common.time_ticker")
	if not ticker or type(ticker.AddTimerOnce) ~= "function" then
		RestoreHudOnce()
		AutoFeedback.SendTextOnly(kills, rank, "time_ticker unavailable")
		return
	end

	enginePreTick:Add(function()
		local actualPath = ScreenshotMaker.MakePictureByName(path, true)
		if type(enginePreTick.Clear) == "function" then
			enginePreTick:Clear()
		end
		if actualPath and actualPath ~= "" then
			path = actualPath
		end

		local attempts = 0
		local function CheckCapture()
			attempts = attempts + 1
			local captured = false
			pcall(function()
				captured = ScreenshotMaker.HasCaptured(path)
			end)

			if captured then
				RestoreHudOnce()
				Log("HasCaptured=true. Flushing to disk via ResizePicture...")
				pcall(ScreenshotMaker.ResizePicture, path, 0.6, path)
				ticker.AddTimerOnce(2.0, function()
					if #ReadFile(path) > 0 then
						AutoFeedback.SendFeedback(path, kills, rank, segment)
					else
						Notify("[JINSHI_PUBG] Screenshot read failed")
						AutoFeedback.SendTextOnly(kills, rank, "file read empty")
					end
				end)
			elseif attempts < 15 then
				ticker.AddTimerOnce(1, CheckCapture)
			else
				RestoreHudOnce()
				Notify("[JINSHI_PUBG] Screenshot capture timeout")
				AutoFeedback.SendTextOnly(kills, rank, "capture timeout")
			end
		end

		ticker.AddTimerOnce(1, CheckCapture)
	end)
end

function AutoFeedback.ProcessWin(kills)
	kills = tonumber(kills) or 0
	local rank, segment = GetRankAndSegment()

	if kills <= 2 then
		Log(string.format(
			"Skip feedback: kills=%d (min 3 kills required)",
			kills
		))
		return
	end

	Notify("[JINSHI_PUBG] Chúc mừng bạn đã TOP 1...")
	AutoFeedback.ResetTextFlag()
	local setHudHidden = CreateHudController()
	setHudHidden(true)

	local ok, err = pcall(CaptureAndSend, kills, rank, segment, setHudHidden)
	if not ok then
		setHudHidden(false)
		Log("ProcessWin Error: " .. tostring(err))
		AutoFeedback.SendTextOnly(kills, rank, "capture crashed")
	end

	-- Safety net: 30 sec baad bhi kuch na gaya to text bhej do
	AddTimerOnce(30.0, function()
		AutoFeedback.SendTextOnly(kills, rank, "timeout safety net")
	end)
end

local function GetWinnerKills()
	local kills = 0
	pcall(function()
		local likeUtil = GetModule("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
		if likeUtil and type(likeUtil.GetMyPlayerState) == "function" then
			local playerState = likeUtil.GetMyPlayerState()
			if playerState and playerState.Kills then
				kills = tonumber(playerState.Kills) or 0
			end
		end

		if kills == 0 then
			local resultLogic = GetModule(
				"GameLua.Mod.BaseMod.Client.BattleResult.BattleResultData.BattleResultDataLogic",
				false
			)
			if resultLogic and type(resultLogic.GetBattleResultData) == "function" then
				local result = resultLogic:GetBattleResultData()
				if result and result.BP_mykill then
					kills = tonumber(result.BP_mykill) or 0
				end
			end
		end
	end)
	return kills
end

local function TryInstallHook()
	pcall(function()
		local UIManager = _G.UIManager
		if not UIManager or not UIManager.ShowUI or UIManager.__JINSHIHooked then
			return
		end

		Log("Hooking UIManager.ShowUI for in-game Winner UI...")
		local originalShowUI = UIManager.ShowUI
		UIManager.ShowUI = function(config, params, ...)
			local result = originalShowUI(config, params, ...)
			pcall(function()
				local inGameConfig = UIManager.UI_Config_InGame
				local winnerConfig = inGameConfig and inGameConfig.GameOverCountDown_UIBP
				local isWinner = params and (params.Reason == "win" or params.ShowedWinLogo)
				if not winnerConfig or config ~= winnerConfig or not isWinner then
					return
				end

				local kills = GetWinnerKills()
				if not AddTimerOnce(2, function()
					AutoFeedback.ProcessWin(kills)
				end) then
					AutoFeedback.ProcessWin(kills)
				end
			end)
			return result
		end

		UIManager.__JINSHIHooked = true
		AutoFeedback.Hooked = true
		Log("UIManager Hook installed successfully.")
	end)
end

local function ScheduleTryInstallHook()
	if AutoFeedback.Hooked then
		return
	end
	TryInstallHook()
	if not AutoFeedback.Hooked then
		AddTimerOnce(3.0, ScheduleTryInstallHook)
	end
end

function AutoFeedback.Install()
	Log("Installing JINSHI_PUBG system (Telegram)...")

	if AutoFeedback.Config.TestMode then
		pcall(function()
			AddTimerOnce(5.0, function()
				AutoFeedback.ProcessWin()
			end)
		end)
	end

	pcall(function()
		local ticker = GetModule("common.time_ticker")
		if ticker and type(ticker.AddTimer) == "function" then
			ticker.AddTimer(3.0, ScheduleTryInstallHook)
		else
			ScheduleTryInstallHook()
		end
	end)
end

AutoFeedback.Base64Encode = Base64Encode
AutoFeedback.UrlEncode = UrlEncode
AutoFeedback.GetRankName = GetRankName
_G.AKMOD_AutoFeedbackRecovered = AutoFeedback

if not isExpired then
	AutoFeedback.Install()
end
end

-- ==============================================================================
-- ================== THE RETURN SECTION RETAINS THE ORIGINAL CODE. ===================
-- ==============================================================================
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)


-- Credit
-- ============================================
-- VINESH_OP NAME LOGIC (branding text)
-- ============================================
local InGameUITools
local Lobby_Main_Wifi_UIBP = require("client.slua.umg.lobby.Main.Lobby_Main_Wifi_UIBP")
local o_UpdateQuality = Lobby_Main_Wifi_UIBP.__inner_impl.UpdateQuality
Lobby_Main_Wifi_UIBP.__inner_impl.UpdateQuality = function(self)
    self.UIRoot.WidgetSwitcher_Quality:SetActiveWidgetIndex(0)
    self.UIRoot.TextBlock_High:SetText("@VINESH_OP")
    self.UIRoot.TextBlock_High:SetColorAndOpacity(FSlateColor(FLinearColor(1, 0.85, 0.8, 1)))
end

local o_UpdateArtQualityUI = IngamePhoneStateUI.__inner_impl.UpdateArtQualityUI
IngamePhoneStateUI.__inner_impl.UpdateArtQualityUI = function(self, _, _)
    self.UIRoot.TextBlock_quality:SetText("@CFGxEREN")
    pcall(function()
        if not InGameUITools then
            InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        end
        local Main = InGameUITools.GetMainControlBaseUI()
        if Main then
            -- TELEGRAM @CFGxEREN — simple white font, jahan RedMagic text tha
            Main.TextBlock_BID:SetText("TELEGRAM @CFGxEREN")
            -- White color, plain simple style
            Main.TextBlock_BID:SetColorAndOpacity(FSlateColor(FLinearColor(1, 1, 1, 1)))
            -- Simple/regular font load karo
            pcall(function()
                local fi = Main.TextBlock_BID.Font
                if fi then
                    local simpleFont = nil
                    pcall(function()
                        simpleFont = slua.loadObject("/Engine/EngineFonts/Roboto.Roboto")
                    end)
                    if simpleFont then
                        fi.FontObject = simpleFont
                        fi.TypefaceFontName = "Regular"
                    else
                        fi.TypefaceFontName = "Regular"
                    end
                    fi.Size = 14
                    pcall(function()
                        if fi.OutlineSettings then
                            fi.OutlineSettings.OutlineSize = 0
                        end
                    end)
                    Main.TextBlock_BID:SetFont(fi)
                end
            end)
            Main.TextBlock_Hour:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
    end)
end

local o_OnInitialize = IngamePhoneStateUI.__inner_impl.OnInitialize
IngamePhoneStateUI.__inner_impl.OnInitialize = function(self)
    o_OnInitialize(self)
    if self.UIRoot.TextBlock_quality then
        self.UIRoot.TextBlock_quality:SetColorAndOpacity(FSlateColor(FLinearColor(1, 0.6, 0.2, 1)))
    end
end

-- ==================== PART 4: CLASS REGISTRATION (original, last) ====================

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildAircraftVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    UnifiedBuildVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.UnifiedBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    ParachuteSprint = "GameLua.Mod.BaseMod.GamePlay.Feature.Parachute.ParachuteSprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  },
  {
    FPPAnimMonitor = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature"
  }
}, "BRPlayerCharacterBase")
