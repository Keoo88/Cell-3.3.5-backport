local _, Private = ...

local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsEnemy = UnitIsEnemy
local UnitIsPlayer = UnitIsPlayer
local NewTicker = C_Timer.NewTicker
local DemoteAssistant = DemoteAssistant
local UnitIsConnected = UnitIsConnected
local UnitIsRaidOfficer = UnitIsRaidOfficer
local GetNumRaidMembers = GetNumRaidMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local PromoteToAssistant = PromoteToAssistant
local GetNumPartyMembers = GetNumPartyMembers
local GetPartyLeaderIndex = GetPartyLeaderIndex
local GetRealNumRaidMembers = GetRealNumRaidMembers
local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE

local EventHandler = Private.EventHandler
local EventHandler_Define = EventHandler.Define

function IsInGroup(LE_CATEGORY)
	if ( LE_CATEGORY and LE_CATEGORY == LE_PARTY_CATEGORY_INSTANCE ) then
		return false
	end
	return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

function IsInRaid(LE_CATEGORY)
	if ( LE_CATEGORY and LE_CATEGORY == LE_PARTY_CATEGORY_INSTANCE ) then
		return false
	end
	return GetNumRaidMembers() > 0
end

function GetNumSubgroupMembers()
	return GetNumPartyMembers()
end

function GetNumGroupMembers()
	local Total = GetNumRaidMembers()

	-- If in a raid, GetNumRaidMembers() is always the total count.
	if ( Total > 0 ) then
		return Total
	end

	-- If not in a raid, check the party.
	-- GetNumPartyMembers() returns 1-4 (excluding player).
	-- If it's 0, we are solo (return 0).
	-- If it's > 0, we add 1 for the player.
	local Total = GetNumPartyMembers()
	return (Total > 0) and (Total + 1) or 0
end

function UnitIsGroupLeader(Unit)
	local NumRaid = GetNumRaidMembers()
	local NumParty = GetNumPartyMembers()

	if ( Unit == "player" ) then
		if ( NumRaid > 0 ) then
			return IsRaidLeader()
		elseif ( NumParty > 0 ) then
			return IsPartyLeader()
		end
		return false
	end

	if ( NumRaid > 0 ) then
		for i = 1, NumRaid do
			local _, Rank = GetRaidRosterInfo(i)
			if ( Rank == 2 and UnitIsUnit(Unit, "raid"..i) ) then
				return true
			end
		end
	elseif ( NumParty > 0 ) then
		return UnitIsPartyLeader(Unit)
	end

	return false
end

function UnitIsGroupAssistant(Unit)
	local NumRaid = GetNumRaidMembers()

	if ( NumRaid == 0 ) then
		return false
	end

	for i = 1, NumRaid do
		local _, Rank = GetRaidRosterInfo(i)
		if ( Rank == 1 and UnitIsUnit(Unit, "raid"..i) ) then
			return true
		end
	end

	return false
end

local IsAllAssistant, AssistantTicker
function SetEveryoneIsAssistant(Enable)
	local NumMembers = GetNumRaidMembers()

	if ( NumMembers <= 0 ) then return end

	if ( AssistantTicker ) then
		AssistantTicker:Cancel()
		AssistantTicker = nil
	end

	IsAllAssistant = Enable

	AssistantTicker = NewTicker(0.2, function(Self)
		local Unit = "raid"..Self.Index

		-- Skip checking the player (you cannot demote yourself)
		if ( not UnitIsUnit(Unit, "player") ) then
			if ( IsAllAssistant ) then
				-- Only promote if they aren't already an assistant/leader
				local _, Rank = GetRaidRosterInfo(Self.Index)
				if ( Rank == 0 ) then
					PromoteToAssistant(Unit)
				end
			else
				-- Only demote if they are currently an assistant
				local _, Rank = GetRaidRosterInfo(Self.Index)
				if ( Rank == 1 ) then
					DemoteAssistant(Unit)
				end
			end
		end

		Self.Index = Self.Index + 1
	end, NumMembers)

	AssistantTicker.Index = 1
end

function IsEveryoneAssistant()
	return IsAllAssistant
end

function CanBeRaidTarget(Unit)
	if ( not Unit or not UnitExists(Unit) or not UnitIsConnected(Unit) ) then
		return false
	end

	if ( UnitIsPlayer(Unit) and UnitIsEnemy("player", Unit) ) then
		return false
	end

	return true
end

_G.UnitInOtherParty = Private.False
_G.GetDisplayedAllyFrames = Private.Void

--[[
	EventHandler: GROUP_ROSTER_UPDATE / GROUP_JOINED / GROUP_LEFT
]]

EventHandler_Define("Event", "GROUP_ROSTER_UPDATE", {"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE"})
EventHandler_Define("OnEvent", "GROUP_ROSTER_UPDATE", function(_, Event)
	if ( Event == "PARTY_MEMBERS_CHANGED" and GetNumRaidMembers() > 0 ) then
		return false
	end
end)