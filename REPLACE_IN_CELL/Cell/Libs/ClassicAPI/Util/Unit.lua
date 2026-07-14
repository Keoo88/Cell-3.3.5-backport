local _, Private = ...

local _G = _G
local UnitName = UnitName
local UnitRace = UnitRace
local UnitClass = UnitClass
local UnitInRange = UnitInRange
local UnitIsTapped = UnitIsTapped
local IsItemInRange = IsItemInRange
local UnitIsConnected = UnitIsConnected
local UnitIsTappedByPlayer = UnitIsTappedByPlayer
local GetPlayerMapPosition = GetPlayerMapPosition
local CheckInteractDistance = CheckInteractDistance
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitIsTappedByAllThreatList = UnitIsTappedByAllThreatList

local EventHandler = Private.EventHandler
local EventHandler_Fire = EventHandler.Fire
local EventHandler_Define = EventHandler.Define

local GTCOMM
local UNIT_RANGE_ITEM = (WOW_PROJECT_ID_RCE ~= WOW_PROJECT_CLASSIC) and 34471

function C_UnitInRange(Unit)
	-- 1. CheckInteractDistance(Unit, 4) is ~28 yards and very cheap.
	-- 2. UnitInRange(Unit) handles party/raid members (~36 yards).
	-- 3. IsItemInRange uses a specific item (34471 - Vial of Sunwell) (40 yards).
	-- Force a boolean true/false if the result is 1/nil

	return not not (
		CheckInteractDistance(Unit, 4) or
		UnitInRange(Unit) or
		(UNIT_RANGE_ITEM and IsItemInRange(UNIT_RANGE_ITEM, Unit) == 1)
	), true
end

function UnitDistanceSquared(Unit)
	if ( UnitIsConnected(Unit) ) then
		local Px, Py = GetPlayerMapPosition("player")
		local Ux, Uy = GetPlayerMapPosition(Unit)

		-- Inline the distance squared calculation: (x2-x1)^2 + (y2-y1)^2
		local Dx = Ux - Px
		local Dy = Uy - Py

		local DistanceSq = (Dx * Dx + Dy * Dy) * 100000
		return DistanceSq, true
	end

	return 0, false
end

function UnitIsTapDenied(Unit)
	return UnitIsTapped(Unit) and not UnitIsTappedByPlayer(Unit) and not UnitIsTappedByAllThreatList(Unit)
end

function C_UnitCastingInfo(Unit)
	local Name, Rank, Text, Texture, StartTime, EndTime, IsTradeskill, Cast, Interruptable, SpellID = UnitCastingInfo(Unit)
	return Name, Text, Texture, StartTime, EndTime, IsTradeskill, Cast, Interruptable, SpellID
end

function C_UnitChannelInfo(Unit)
	local Name, Rank, Text, Texture, StartTime, EndTime, IsTradeskill, Interruptable, SpellID = UnitChannelInfo(Unit)
	return Name, Text, Texture, StartTime, EndTime, IsTradeskill, Interruptable, SpellID
end

function C_UnitRace(Unit)
	local Name, File = UnitRace(Unit)
	return Name, File, C_CreatureInfo.GetRaceInfo(File, true)
end

function UnitFullName(Unit)
	local Name, Realm = UnitName(Unit)

	if ( Unit == "player" ) then
		Realm = GetNormalizedRealmName()
	end

	return Name, Realm
end

function C_UnitGroupRolesAssigned(Unit)
	local _, Class = UnitClass(Unit)

	if ( Class == "HUNTER" or Class == "ROGUE" or Class == "MAGE" or Class == "WARLOCK" ) then
		return "DAMAGER"
	end

	local Tank, Heal, Damage, Role = UnitGroupRolesAssigned(Unit)

	if ( not (Tank or Heal or Damage) ) then
		if ( GTCOMM == nil and LibStub ) then
			GTCOMM = LibStub:GetLibrary("LibGroupTalents-1.0", true) or false
		end

		Role = (GTCOMM) and GTCOMM:GetUnitRole(Unit)
	end

	if ( Tank or Role == "tank" ) then
		return "TANK"
	elseif ( Heal or Role == "healer" ) then
		return "HEALER"
	elseif ( Damage or Role == "caster" or Role == "melee" ) then
		return "DAMAGER"
	else
		return "NONE"
	end
end

_G.UnitShouldDisplayName = Private.True
_G.UnitPhaseReason = Private.Void
_G.UnitInPhase = Private.True

--[[ EventHandler: PLAYER_ROLES_ASSIGNED ]]

local function LibGroupTalents_RoleChange(_, _, _, Unit)
	EventHandler_Fire(nil, "PLAYER_ROLES_ASSIGNED", Unit) -- This shouldn't have a payload, but we add it.
end

local function PLAYER_ROLES_ASSIGNED_EH(Trigger)
	if ( Trigger == "OnRegister" ) then
		if ( GTCOMM == nil and LibStub ) then
			GTCOMM = LibStub:GetLibrary("LibGroupTalents-1.0", true) or false
		end

		if ( GTCOMM and not EventHandler.LibGroupTalents_RoleChange ) then
			EventHandler.LibGroupTalents_RoleChange = LibGroupTalents_RoleChange

			GTCOMM.RegisterCallback(EventHandler, "LibGroupTalents_RoleChange")
		end
	else
		if ( GTCOMM and EventHandler.LibGroupTalents_RoleChange ) then
			GTCOMM.UnregisterCallback(EventHandler, "HealComm_HealStarted")

			EventHandler.LibGroupTalents_RoleChange = nil
		end
	end
end

EventHandler_Define("Event", "PLAYER_ROLES_ASSIGNED")
EventHandler_Define("OnRegister", "PLAYER_ROLES_ASSIGNED", PLAYER_ROLES_ASSIGNED_EH)
EventHandler_Define("OnUnregister", "PLAYER_ROLES_ASSIGNED", PLAYER_ROLES_ASSIGNED_EH)

--[[ EventHandler: UNIT_CONNECTION ]]

--[[local UNIT_CONNECTION_STATUS
local function UNIT_CONNECTION_EH(Trigger, Event, UnitID, Connected)
	if ( Trigger == "OnEvent" ) then
		if ( not Connected ) then -- HACK: Prevent continuation within Handler, only callback after we add "Connected" to payload.
			local Connected = UnitIsConnected(UnitID) and true or false

			if ( Connected ~= UNIT_CONNECTION_STATUS[UnitID] ) then
				EventHandler_Fire(nil, "UNIT_CONNECTION", UnitID, Connected)
				UNIT_CONNECTION_STATUS[UnitID] = Connected or nil
			end

			return false
		end
	elseif ( Trigger == "OnRegister" ) then
		if ( not UNIT_CONNECTION_STATUS ) then
			UNIT_CONNECTION_STATUS = {}
		end
	else
		UNIT_CONNECTION_STATUS = nil
	end
end

EventHandler_Define("Event", "UNIT_CONNECTION", "UNIT_FACTION")
EventHandler_Define("OnEvent", "UNIT_CONNECTION", UNIT_CONNECTION_EH)
EventHandler_Define("OnRegister", "UNIT_CONNECTION", UNIT_CONNECTION_EH)
EventHandler_Define("OnUnregister", "UNIT_CONNECTION", UNIT_CONNECTION_EH)
]]