--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).
--! The C-1/C-2 fixes (leader/assistant without the O(N) roster walk) live here.

local _, Private = ...

local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsEnemy = UnitIsEnemy
local UnitIsPlayer = UnitIsPlayer
--! Use OUR timer implementation: a foreign C_Timer may ship a different NewTicker.
local NewTicker = Private.Own.C_Timer.NewTicker
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

local function IsInGroup(LE_CATEGORY)
	if ( LE_CATEGORY and LE_CATEGORY == LE_PARTY_CATEGORY_INSTANCE ) then
		return false
	end
	return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

local function IsInRaid(LE_CATEGORY)
	if ( LE_CATEGORY and LE_CATEGORY == LE_PARTY_CATEGORY_INSTANCE ) then
		return false
	end
	return GetNumRaidMembers() > 0
end

local function GetNumSubgroupMembers()
	return GetNumPartyMembers()
end

local function GetNumGroupMembers()
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

local function UnitIsGroupLeader(Unit)
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
		--! WotLK fix: UnitInRaid hands back the roster index directly (0-based on 3.3.5,
		--! see FrameXML TargetFrame.lua: "id = UnitInRaid('target'); GetRaidRosterInfo(id + 1)"),
		--! so one lookup replaces the whole roster walk that ran per unit button.
		local Index = UnitInRaid(Unit)
		if ( Index ) then
			local _, Rank = GetRaidRosterInfo(Index + 1)
			return Rank == 2
		end
		return false
	elseif ( NumParty > 0 ) then
		return UnitIsPartyLeader(Unit)
	end

	return false
end

local function UnitIsGroupAssistant(Unit)
	--! WotLK fix: 3.3.5 answers this in O(1) natively, so drop the full roster scan
	--! (40 GetRaidRosterInfo + 40 UnitIsUnit + 40 temp strings per call, once per unit
	--! button on every roster/leader update). UnitIsRaidOfficer is truthy for the raid
	--! LEADER too on this client (FrameXML UnitPopup.lua RAID_DEMOTE and ElvUI's
	--! oUF assistantindicator both filter the leader out separately), so keep the old
	--! "rank == 1" semantics by excluding the leader; UnitInRaid keeps party/solo false.
	if ( UnitInRaid(Unit) and UnitIsRaidOfficer(Unit) and not UnitIsPartyLeader(Unit) ) then
		return true
	end

	return false
end

local IsAllAssistant, AssistantTicker
local function SetEveryoneIsAssistant(Enable)
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

local function IsEveryoneAssistant()
	return IsAllAssistant
end

local function CanBeRaidTarget(Unit)
	if ( not Unit or not UnitExists(Unit) or not UnitIsConnected(Unit) ) then
		return false
	end

	if ( UnitIsPlayer(Unit) and UnitIsEnemy("player", Unit) ) then
		return false
	end

	return true
end

Private.Provide("UnitInOtherParty", Private.False)
Private.Provide("GetDisplayedAllyFrames", Private.Void)

--[[
	EventHandler: GROUP_ROSTER_UPDATE / GROUP_JOINED / GROUP_LEFT
]]

EventHandler_Define("Event", "GROUP_ROSTER_UPDATE", {"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE"})
EventHandler_Define("OnEvent", "GROUP_ROSTER_UPDATE", function(_, Event)
	if ( Event == "PARTY_MEMBERS_CHANGED" and GetNumRaidMembers() > 0 ) then
		return false
	end
end)

-- Publish: gap-fill only, ours stays reachable via CellClassicAPI.<name>
local Provide = Private.Provide
Provide("IsInGroup", IsInGroup)
Provide("IsInRaid", IsInRaid)
Provide("GetNumSubgroupMembers", GetNumSubgroupMembers)
Provide("GetNumGroupMembers", GetNumGroupMembers)
Provide("UnitIsGroupLeader", UnitIsGroupLeader)
Provide("UnitIsGroupAssistant", UnitIsGroupAssistant)
Provide("SetEveryoneIsAssistant", SetEveryoneIsAssistant)
Provide("IsEveryoneAssistant", IsEveryoneAssistant)
Provide("CanBeRaidTarget", CanBeRaidTarget)
