local _, Private = ...

local _G = _G
local Type = type
local Enum = Enum
local pairs = pairs
local ShowUIPanel = ShowUIPanel
local HideUIPanel = HideUIPanel

local InteractionManagerFrameInfo

local function InteractionManagerFrameInfoCreate()
	--[[
		frame = [REQUIRED][FRAME] - The frame that is intended to open
		showFunc = [OPTIONAL][FUNCTION] - This will happen when we recieve the event with this type.. If none is specified ShowUIPanel will be called by default.
		hideFunc = [OPTIONAL][FUNCTION] - This happens on PLAYER_INTERACTION_FRAME_HIDE. If nothing is specified, HideUIPanel will be called. 
		loadFunc = [OPTIONAL][FUNCTION] - Only need to specify if the frame requires to be loaded before used. 
	]]

	InteractionManagerFrameInfo = {
		[Enum.PlayerInteractionType.Merchant] = {
			frame = "MerchantFrame",
			showFunc = "MerchantFrame_MerchantShow",
			hideFunc = "MerchantFrame_MerchantClosed",
			showEvent = "MERCHANT_SHOW",
			hideEvent = "MERCHANT_CLOSED"
		},

		[Enum.PlayerInteractionType.Banker] = {
			frame = "BankFrame",
			showFunc = "BankFrame_Open",
			showEvent = "BANKFRAME_OPENED",
			hideEvent = "BANKFRAME_CLOSED"
		},

		[Enum.PlayerInteractionType.Trainer] = {
			frame = "ClassTrainerFrame",
			showFunc = "ClassTrainerFrame_Show",
			hideFunc = "ClassTrainerFrame_Hide",
			loadFunc = ClassTrainerFrame_LoadUI,
			showEvent = "TRAINER_SHOW",
			hideEvent = "TRAINER_CLOSED"
		},

		[Enum.PlayerInteractionType.GuildBanker] = {
			frame = "GuildBankFrame",
			loadFunc = GuildBankFrame_LoadUI,
			showEvent = "GUILDBANKFRAME_OPENED",
			hideEvent = "GUILDBANKFRAME_CLOSED"
		},

		[Enum.PlayerInteractionType.Registrar] = {
			frame = "GuildRegistrarFrame"
		},

		[Enum.PlayerInteractionType.GuildTabardVendor] = {
			frame = "TabardFrame",
			showFunc = "TabardFrame_Open"
		},

		[Enum.PlayerInteractionType.MailInfo] = {
			frame = "MailFrame",
			showFunc = "MailFrame_Show",
			hideFunc = "MailFrame_Hide",
			showEvent = "MAIL_SHOW",
			hideEvent = "MAIL_CLOSED"
		},

		[Enum.PlayerInteractionType.Auctioneer] = {
			frame = "AuctionHouseFrame",
			showEvent = "AUCTION_HOUSE_SHOW",
			hideEvent = "AUCTION_HOUSE_CLOSED"
		}
	}
end

local PlayerInteractionFrameManagerMixin = PlayerInteractionFrameManagerMixin or {}

function PlayerInteractionFrameManagerMixin:ShowFrame(interactionType)
	if ( not InteractionManagerFrameInfo ) then
		InteractionManagerFrameInfoCreate()
	end

	local frameInfo = InteractionManagerFrameInfo[interactionType]
	if not frameInfo then
		return
	end 

	if frameInfo.loadFunc and not _G[frameInfo.frame] then
		frameInfo.loadFunc()
	end

	if frameInfo.showFunc then
		if Type(frameInfo.showFunc) == "string" then
			frameInfo.showFunc = _G[frameInfo.showFunc]
		end
		if frameInfo.showFunc then
			frameInfo.showFunc()
		end
	else
		ShowUIPanel(_G[frameInfo.frame], frameInfo.forceShow)
	end
end

function PlayerInteractionFrameManagerMixin:HideFrame(interactionType)
	if ( not InteractionManagerFrameInfo ) then
		InteractionManagerFrameInfoCreate()
	end

	local frameInfo = InteractionManagerFrameInfo[interactionType]
	if not frameInfo then
		return
	end

	-- The frame isn't loaded, so nothing to hide.
	if not _G[frameInfo.frame] then
		return
	end

	if frameInfo.hideFunc then
		if Type(frameInfo.hideFunc) == "string" then
			frameInfo.hideFunc = _G[frameInfo.hideFunc]
		end
		if frameInfo.hideFunc then
			frameInfo.hideFunc()
		end
	else
		HideUIPanel(_G[frameInfo.frame])
	end
end

function PlayerInteractionFrameManagerMixin:OnLoad()
	self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
	self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
end

function PlayerInteractionFrameManagerMixin:OnEvent(event, type) 
	if (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW") then
		self:ShowFrame(type)
	elseif (event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE") then
		self:HideFrame(type)
	end
end

-- [[ EventHandler: PLAYER_INTERACTION_MANAGER_FRAME_X ]]

local EventHandler = Private.EventHandler
local EventHandler_Fire = EventHandler.Fire
local EventHandler_Define = EventHandler.Define

local PlayerInteractionFrameManager = PlayerInteractionFrameManager or CreateFrame("Frame")
PlayerInteractionFrameManager.ShowFrame = PlayerInteractionFrameManagerMixin.ShowFrame
PlayerInteractionFrameManager.HideFrame = PlayerInteractionFrameManagerMixin.HideFrame

PlayerInteractionFrameManager:SetScript("OnEvent", function(Self, Event)
	local Show = Self.__Show
	local Type = Show and Show[Event]
	if ( Type ) then
		EventHandler_Fire(nil, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Type)
	else
		local Hide = Self.__Hide
		local Type = Hide and Hide[Event]
		if ( Type ) then
			EventHandler_Fire(nil, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Type)
		end
	end
end)

local function PLAYER_INTERACTION_MANAGER_FRAME_EH(Trigger, Event)
	local EventMapType = Event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and "__Show" or "__Hide"
	local EventMap = PlayerInteractionFrameManager[EventMapType]

	if ( Trigger == "OnRegister" ) then
		if ( EventMap ) then
			return
		else
			EventMap = {}
			PlayerInteractionFrameManager[EventMapType] = EventMap

			if ( not InteractionManagerFrameInfo ) then
				InteractionManagerFrameInfoCreate()
			end
		end
	end

	local EventIndex = EventMapType == "__Show" and "showEvent" or "hideEvent"

	for Enum, Meta in pairs(InteractionManagerFrameInfo) do
		local Event = Meta[EventIndex]
		if ( Event ) then
			if ( Trigger == "OnRegister" ) then
				PlayerInteractionFrameManager:RegisterEvent(Event)
				EventMap[Event] = Enum
			else
				PlayerInteractionFrameManager:UnregisterEvent(Event)
			end
		end
	end

	if ( Trigger == "OnUnregister" ) then
		PlayerInteractionFrameManager[EventMapType] = nil
	end
end

EventHandler_Define("Event", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
EventHandler_Define("Event", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
EventHandler_Define("OnRegister", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", PLAYER_INTERACTION_MANAGER_FRAME_EH)
EventHandler_Define("OnUnregister", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", PLAYER_INTERACTION_MANAGER_FRAME_EH)
EventHandler_Define("OnRegister", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", PLAYER_INTERACTION_MANAGER_FRAME_EH)
EventHandler_Define("OnUnregister", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", PLAYER_INTERACTION_MANAGER_FRAME_EH)

-- Global
_G.PlayerInteractionFrameManagerMixin = PlayerInteractionFrameManagerMixin
_G.PlayerInteractionFrameManager = PlayerInteractionFrameManager