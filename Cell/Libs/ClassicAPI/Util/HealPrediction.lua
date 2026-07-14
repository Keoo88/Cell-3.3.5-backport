local _, Private = ...

local Select = select
local BitBand = bit.band
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitName = UnitName
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers

local EventHandler = Private.EventHandler
local EventHandler_Fire = EventHandler.Fire
local EventHandler_Define = EventHandler.Define

local RESCOMM
local HEALCOMM
local HEALCOMM_PLAYER_GUID

local UNIT_INDEX = {"player", "pet", "target", "focus"}

for i=1,4 do
	local Index = #UNIT_INDEX+1
	UNIT_INDEX[Index] = "party"..i
	UNIT_INDEX[Index+1] = "partypet"..i
end

for i=1, 40 do
	local Index = #UNIT_INDEX+1
	UNIT_INDEX[Index] = "raid"..i
	UNIT_INDEX[Index+1] = "raidpet"..i
end

--[[ EventHandler: UNIT_HEAL_PREDICTION (LibHealComm-4.0) ]]

function UnitGetIncomingHeals(Unit, Healer, GUID)
	if ( Unit ) then
		if ( HEALCOMM == nil and LibStub ) then
			HEALCOMM = LibStub:GetLibrary("LibHealComm-4.0", true) or false

			if ( HEALCOMM and not HEALCOMM_PLAYER_GUID ) then
				HEALCOMM_PLAYER_GUID = UnitGUID("player")
			end
		end

		if ( HEALCOMM ) then
			if ( not GUID ) then
				Unit = UnitGUID(Unit)
			end

			return HEALCOMM:GetHealAmount(Unit, HEALCOMM.CASTED_HEALS, GetTime() + 5, HEALCOMM_PLAYER_GUID)
		end
	end
end

UnitGetTotalAbsorbs = Private.Zero
UnitGetTotalHealAbsorbs = Private.Zero

local function UNIT_HEAL_PREDICTION(...)
	local UnitTotal = Select("#", ...)

	local Raid = GetNumRaidMembers()
	local Limit = 4 + (Raid > 0 and 8 + (Raid*2) or (GetNumPartyMembers()*2))

	for i = 1, Limit do
		local UnitID = UNIT_INDEX[i]

		if ( UnitID ) then
			local CurrentUnitGUID = UnitGUID(UnitID)

			for j = 1, UnitTotal do
				if ( CurrentUnitGUID == Select(j, ...) ) then
					EventHandler_Fire(nil, "UNIT_HEAL_PREDICTION", UnitID)
					break
				end
			end
		end
	end
end

local function HealComm_HealStarted(_, Event, SrcGUID, SpellID, Type, EndTime, ...)
	if ( SrcGUID == HEALCOMM_PLAYER_GUID and BitBand(Type, HEALCOMM.CASTED_HEALS) > 0 ) then
		UNIT_HEAL_PREDICTION(...)
	end
end

local function HealComm_ModifierChanged(_, _, SrcGUID)
	UNIT_HEAL_PREDICTION(SrcGUID)
end

local function UNIT_HEAL_PREDICTION_EH(Trigger)
	if ( Trigger == "OnRegister" ) then
		if ( HEALCOMM == nil and LibStub ) then
			HEALCOMM = LibStub:GetLibrary("LibHealComm-4.0", true) or false

			if ( HEALCOMM and not HEALCOMM_PLAYER_GUID ) then
				HEALCOMM_PLAYER_GUID = UnitGUID("player")
			end
		end

		if ( HEALCOMM and not EventHandler.HealComm_HealStarted) then
			EventHandler.HealComm_HealStarted = HealComm_HealStarted
			EventHandler.HealComm_ModifierChanged = HealComm_ModifierChanged

			HEALCOMM.RegisterCallback(EventHandler, "HealComm_HealStarted")
			HEALCOMM.RegisterCallback(EventHandler, "HealComm_HealDelayed", "HealComm_HealStarted")
			HEALCOMM.RegisterCallback(EventHandler, "HealComm_HealUpdated", "HealComm_HealStarted")
			HEALCOMM.RegisterCallback(EventHandler, "HealComm_HealStopped", "HealComm_HealStarted")
		end
	else
		if ( HEALCOMM and EventHandler.HealComm_HealStarted ) then
			HEALCOMM.UnregisterCallback(EventHandler, "HealComm_HealStarted")
			HEALCOMM.UnregisterCallback(EventHandler, "HealComm_HealDelayed")
			HEALCOMM.UnregisterCallback(EventHandler, "HealComm_HealUpdated")
			HEALCOMM.UnregisterCallback(EventHandler, "HealComm_HealStopped")

			EventHandler.HealComm_HealStarted = nil
			EventHandler.HealComm_ModifierChanged = nil
		end
	end
end

EventHandler_Define("Event", "UNIT_HEAL_PREDICTION")
EventHandler_Define("OnRegister", "UNIT_HEAL_PREDICTION", UNIT_HEAL_PREDICTION_EH)
EventHandler_Define("OnUnregister", "UNIT_HEAL_PREDICTION", UNIT_HEAL_PREDICTION_EH)

--[[ EventHandler: INCOMING_RESURRECT_CHANGED (LibResComm-1.0) ]]

function UnitHasIncomingResurrection(Unit)
	if ( Unit ) then
		if ( RESCOMM == nil and LibStub ) then
			RESCOMM = LibStub:GetLibrary("LibResComm-1.0", true) or false
		end
		return (RESCOMM) and RESCOMM:IsUnitBeingRessed(UnitName(Unit))
	end
end

local function ResComm_OnStartEnd(_, _, Target, Name)
	if ( Target ~= Name ) then
		local Raid = GetNumRaidMembers()
		local Limit = 4 + (Raid > 0 and 8 + (Raid*2) or (GetNumPartyMembers()*2))

		for i=1, Limit do
			local UnitID = UNIT_INDEX[i]
			local UnitName = UnitName(UnitID)
			if ( Name == UnitName or Target == UnitName ) then
				EventHandler_Fire(nil, "INCOMING_RESURRECT_CHANGED", UnitID)
			end
		end
	end
end

local function INCOMING_RESURRECT_CHANGED_EH(Trigger)
	if ( Trigger == "OnRegister" ) then
		if ( RESCOMM == nil and LibStub ) then
			RESCOMM = LibStub:GetLibrary("LibResComm-1.0", true) or false
		end

		if ( RESCOMM and not EventHandler.ResComm_OnStartEnd ) then
			EventHandler.ResComm_OnStartEnd = true

			RESCOMM.RegisterCallback(EventHandler, "ResComm_ResStart", ResComm_OnStartEnd)
			RESCOMM.RegisterCallback(EventHandler, "ResComm_ResEnd", ResComm_OnStartEnd)
		end
	else
		if ( RESCOMM and EventHandler.ResComm_OnStartEnd ) then
			RESCOMM.UnregisterCallback(EventHandler, "ResComm_ResStart")
			RESCOMM.UnregisterCallback(EventHandler, "ResComm_ResEnd")

			EventHandler.ResComm_OnStartEnd = nil
		end
	end
end

EventHandler_Define("Event", "INCOMING_RESURRECT_CHANGED")
EventHandler_Define("OnRegister", "INCOMING_RESURRECT_CHANGED", INCOMING_RESURRECT_CHANGED_EH)
EventHandler_Define("OnUnregister", "INCOMING_RESURRECT_CHANGED", INCOMING_RESURRECT_CHANGED_EH)