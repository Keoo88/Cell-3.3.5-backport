--[[
	Queries some data retrieval API (specifically where the data may not be currently available) and when it becomes available
	calls a user-supplied function.  The callback can be canceled if necessary (e.g. the frame that would use the data becomes
	hidden before the data arrives).

	The API is managed so that arbitrary query functions cannot be executed.
--]]

local _, Private = ...

local Next = next
local Pairs = pairs
local Mixin = Mixin
local XPCall = xpcall
local Format = string.format
local CallErrorHandler = CallErrorHandler

local Tooltip = Private.Tooltip
local EventHandler = Private.EventHandler
local EventHandler_Fire = EventHandler.Fire

local AsyncCallbackAPIType = {
	--ASYNC_QUEST = 1,
	ASYNC_ITEM = 2,
	ASYNC_SPELL = 3,
}

local PermittedAPI =
{
	[AsyncCallbackAPIType.ASYNC_ITEM] = { event = "ITEM_DATA_LOAD_RESULT", hyperlinkFormat = "item:%d:0:0:0:0:0:0:0" },
	--[AsyncCallbackAPIType.ASYNC_QUEST] = { event = "QUEST_DATA_LOAD_RESULT", hyperlinkFormat = "quest:%d" },
	--[AsyncCallbackAPIType.ASYNC_SPELL] = { event = "SPELL_DATA_LOAD_RESULT", hyperlinkFormat = "spell:%d" },
}

local AsyncCallbackSystemMixin = {}

local CANCELED_SENTINEL = -1
local TIMEOUT_SENTINEL = 7

local CALL_PENDING = -1
local CALL_ELAPSED = 0

local function ProcessCallbacks(Self, Elapsed)
	local TotalQueued = 0
	local CallbackRegistry = Self.callbacks

	for ID in Pairs(CallbackRegistry) do
		TotalQueued = TotalQueued + 1
		Self[TotalQueued] = ID
	end

	if ( TotalQueued == 0 ) then
		return Self:SetScript("OnUpdate", nil)
	end

	for i = 1, TotalQueued do
		local ID = Self[i]
		local Callbacks = CallbackRegistry[ID]

		if ( Callbacks ) then
			local AssetLink
			if ( Self.apiType == AsyncCallbackAPIType.ASYNC_ITEM ) then
				_, AssetLink = C_Item.GetItemInfo(ID)
			--elseif ( Self.apiType == AsyncCallbackAPIType.ASYNC_QUEST ) then
			--elseif ( Self.apiType == AsyncCallbackAPIType.ASYNC_SPELL ) then
			end

			if ( AssetLink ) then
				if ( Callbacks[CALL_PENDING] ) then
					EventHandler_Fire(nil, Self.api.event, ID, true)
				end
				Self:FireCallbacks(ID)
			else
				local Timeout = Callbacks[CALL_ELAPSED]

				if ( Timeout == TIMEOUT_SENTINEL ) then
					Tooltip:SetHyperlink(Format(Self.api.hyperlinkFormat, ID))
					Callbacks[CALL_PENDING] = true
				elseif ( Timeout <= 0 ) then
					EventHandler_Fire(nil, Self.api.event, ID, false)
					Self:ClearCallbacks(ID)
				end

				Callbacks[CALL_ELAPSED] = Timeout - Elapsed
			end
		end

		Self[i] = nil
	end
end

function AsyncCallbackSystemMixin:Init(APIType)
	if ( not APIType and self.apiType ) then
		if ( not Private.AsyncCallbackSystemReady and Next(self.callbacks) ) then
			self:SetScript("OnUpdate", ProcessCallbacks)
		end
		return
	end

	self.callbacks = {}

	-- API Type should be set up from key value pairs before OnLoad.
	self.api = PermittedAPI[APIType]
	self.apiType = APIType
end

function AsyncCallbackSystemMixin:AddCallback(ID, CallbackFunction)
	if ( self.apiType == AsyncCallbackAPIType.ASYNC_QUEST or
		self.apiType == AsyncCallbackAPIType.ASYNC_SPELL or
		(self.apiType == AsyncCallbackAPIType.ASYNC_ITEM and C_Item.IsItemDataCachedByID(ID)) ) then
		XPCall(CallbackFunction, CallErrorHandler)
		return 0, nil
	end

	local Callbacks = self:GetOrCreateCallbacks(ID)
	local CallbackTotal = #Callbacks+1

	if ( not Callbacks[CALL_ELAPSED] ) then
		Callbacks[CALL_ELAPSED] = TIMEOUT_SENTINEL
	end
	Callbacks[CallbackTotal] = CallbackFunction

	self:Init()

	return CallbackTotal, Callbacks
end

function AsyncCallbackSystemMixin:AddCancelableCallback(ID, CallbackFunction)
	-- NOTE: If the data is currently availble then the callback will be executed and callbacks cleared, so there will be nothing to cancel.
	local Index, Callbacks = self:AddCallback(ID, CallbackFunction)
	if ( Index == 0 ) then
		return Private.False
	end

	return function()
		if ( Index > 0 and Callbacks[Index] ~= CANCELED_SENTINEL ) then
			Callbacks[Index] = CANCELED_SENTINEL
			return true
		end
		return false
	end
end

function AsyncCallbackSystemMixin:FireCallbacks(ID)
	local Callbacks = self:GetCallbacks(ID)
	if ( Callbacks ) then
		local CallbackTotal = #Callbacks
		self:ClearCallbacks(ID)

		for i = 1, CallbackTotal do
			local Callback = Callbacks[i]
			if ( Callback and Callback ~= CANCELED_SENTINEL ) then
				XPCall(Callback, CallErrorHandler)
			end
		end

		-- The cancel functions have a reference to this table, so ensure that it's cleared out.
		for i = CallbackTotal, 1, -1 do
			Callbacks[i] = nil
		end
	end
end

function AsyncCallbackSystemMixin:ClearCallbacks(ID)
	self.callbacks[ID] = nil
end

function AsyncCallbackSystemMixin:GetCallbacks(ID)
	return self.callbacks[ID]
end

function AsyncCallbackSystemMixin:GetOrCreateCallbacks(ID)
	local Callbacks = self.callbacks[ID]
	if ( not Callbacks ) then
		Callbacks = {}
		self.callbacks[ID] = Callbacks
	end
	return Callbacks
end

local function CreateListener(APIType)
	local Listener = Mixin(CreateFrame("Frame"), AsyncCallbackSystemMixin)
	Listener:Init(APIType)
	return Listener
end

ItemEventListener = CreateListener(AsyncCallbackAPIType.ASYNC_ITEM)
SpellEventListener = CreateListener(AsyncCallbackAPIType.ASYNC_SPELL)
--QuestEventListener = CreateListener(AsyncCallbackAPIType.ASYNC_QUEST)

EventHandler.Define("Event", "ITEM_DATA_LOAD_RESULT")
--EventHandler.Define("Event", "QUEST_DATA_LOAD_RESULT")
--EventHandler.Define("Event", "SPELL_DATA_LOAD_RESULT")

-- [ClassicAPI.lua:PLAYER_ENTERING_WORLD] A switch to delay processing until in the world.
function Private.AsyncCallbackSystemReady()
	Private.AsyncCallbackSystemReady = nil

	ItemEventListener:Init()
	--QuestEventListener.Init()
	--SpellEventListener.Init()
end

-- Global
_G.AsyncCallbackAPIType = AsyncCallbackAPIType
_G.AsyncCallbackSystemMixin = AsyncCallbackSystemMixin