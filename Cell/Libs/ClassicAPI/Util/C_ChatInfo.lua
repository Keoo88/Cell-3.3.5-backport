--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).

local _, Private = ...

local _G = _G
local Pairs = pairs
local Select = select
local ChatTypeInfo = ChatTypeInfo
local SendChatMessage = SendChatMessage
local GetNumLanguages = GetNumLanguages
local SendAddonMessage = SendAddonMessage
local GetLanguageByIndex = GetLanguageByIndex

-- Own table: filling a foreign C_ChatInfo in place would overwrite its methods.
local C_ChatInfo = {}
local LanguageIDList

function C_ChatInfo.CanPlayerSpeakLanguage(LanguageID)
	if ( not LanguageIDList ) then
		LanguageIDList = { -- https://warcraft.wiki.gg/wiki/LanguageID
			[1] = "Orcish",
			[2] = "Darnassian",
			[3] = "Taurahe",
			[6] = "Dwarvish",
			[7] = "Common",
			[8] = "Demonic",
			[9] = "Titan",
			[10] = "Thalassian",
			[11] = "Draconic",
			[12] = "Kalimag",
			[13] = "Gnomish",
			[14] = "Zandali",
			[33] = "Forsaken",
			[35] = "Draenei",
			[36] = "Zombie",
			[37] = "Gnomish Binary",
			[38] = "Goblin Binary" 
		}
	end

	local Index = LanguageIDList[LanguageID]
	for i=1, GetNumLanguages() do
		if ( Index == GetLanguageByIndex(i) ) then
			return true
		end
	end
end

function C_ChatInfo.SendAddonMessage(Prefix, Message, ChatType, Target)
	if ( ChatType == "PARTY" or ChatType == "RAID" or ChatType == "GUILD" or ChatType == "BATTLEGROUND" or ChatType == "WHISPER" ) then
		return SendAddonMessage(Prefix, Message, ChatType, Target)
	end
end

function C_ChatInfo.SendChatMessage(Message, ChatType, LanguageID, Target)
	if ( ChatType == "PARTY" or ChatType == "RAID" or ChatType == "GUILD" or ChatType == "BATTLEGROUND" or ChatType == "WHISPER" ) then
		return SendChatMessage(Message, ChatType, LanguageID, Target)
	end
end

function C_ChatInfo.GetColorForChatType(ChatType)
	local ChatInfo = ChatTypeInfo[ChatType]
	return CreateColor(ChatInfo.r, ChatInfo.g, ChatInfo.b, 1)
end

function C_ChatInfo.GetChatTypeName(TypeID)
	local Index = 1
	for Name, Data in Pairs(ChatTypeInfo) do
		if ( TypeID == Index ) then
			return Name
		end
		Index = Index + 1
	end
end

C_ChatInfo.GetChannelRosterInfo = GetChannelRosterInfo
C_ChatInfo.GetNumActiveChannels = GetNumDisplayChannels

C_ChatInfo.IsAddonMessagePrefixRegistered = Private.True
C_ChatInfo.RegisterAddonMessagePrefix = Private.True
C_ChatInfo.GetRegisteredAddonMessagePrefixes = Private.Void

-- INCOMPLETE
--[[
C_ChatInfo.GetChannelInfoFromIdentifier
C_ChatInfo.GetChannelRuleset
C_ChatInfo.GetChannelShortcut
C_ChatInfo.GetChatLineSenderGUID
C_ChatInfo.GetChatLineSenderName
C_ChatInfo.GetChatLineText
C_ChatInfo.GetClubStreamIDs
C_ChatInfo.GetGeneralChannelID
C_ChatInfo.GetGeneralChannelLocalID
C_ChatInfo.GetMentorChannelID
C_ChatInfo.GetNumReservedChatWindows
C_ChatInfo.IsChannelRegional
C_ChatInfo.IsChatLineCensored
C_ChatInfo.IsPartyChannelType
C_ChatInfo.IsRegionalServiceAvailable
C_ChatInfo.IsValidChatLine
C_ChatInfo.ReplaceIconAndGroupExpressions
C_ChatInfo.RequestCanLocalWhisperTarget
C_ChatInfo.ResetDefaultZoneChannels
C_ChatInfo.SwapChatChannelsByChannelIndex
C_ChatInfo.UncensorChatLine
]]

-- Global
Private.Merge("C_ChatInfo", C_ChatInfo)

--[[
	CHATTHROTTLELIB OVERRIDE
]]

--! WotLK fix (coexistence): only one ClassicAPI may wrap ChatThrottleLib. When the
--! standalone !!!ClassicAPI is installed it already did this, and wrapping the wrapper
--! would send every addon message through two throttles. Also guard against CTL being
--! absent, which used to be a nil index right here.
local CTL = _G.ChatThrottleLib
if ( CTL and not Private.Own.__meta.standalone and CTL.version ~= 50 ) then
local CTL_SendAddonMessage = CTL.SendAddonMessage
CTL.version = 50 -- Force ClassicAPI CTL.
CTL.SendAddonMessage = function(...)
	local ChatType = Select(5, ...)
	if ( ChatType == "PARTY" or ChatType == "RAID" or ChatType == "GUILD" or ChatType == "BATTLEGROUND" or ChatType == "WHISPER" ) then
		return CTL_SendAddonMessage(...)
	end
end
end --! WotLK fix: closes the coexistence guard above.
