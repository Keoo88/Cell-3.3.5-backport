--! Cell: this is a private, trimmed fork of Tsoukie's ClassicAPI.
--! If the standalone !!!ClassicAPI addon is installed (Gladdy requires it), it
--! loads first and owns these globals. Overwriting them with this older subset
--! mixes two incompatible halves of the same library, so bail out instead.
if IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI") then return end

local _, Private = ...

local UnitGUID = UnitGUID
local UnitIsVisible = UnitIsVisible
local HookSecureFunc = hooksecurefunc
local UnitIsConnected = UnitIsConnected
local CheckInteractDistance = CheckInteractDistance

local EventHandler = Private.EventHandler
local EventHandler_Fire = EventHandler.Fire

--[[ EventHandler: INSPECT_READY ]]

local INSPECT_READY = CreateFrame("Frame")

local function InspectNotify(Unit)
	local GUID = UnitGUID(Unit)
	if ( GUID and UnitIsVisible(Unit) and UnitIsConnected(Unit) and CheckInteractDistance(Unit, 1) ) then
		INSPECT_READY.Queued = GUID
	end
end

local function InspectReady(_, Event)
	if ( Event and INSPECT_READY.Queued ) then
		EventHandler_Fire(nil, "INSPECT_READY", INSPECT_READY.Queued)
	end
	INSPECT_READY.Queued = nil
end

EventHandler.Define("Event", "INSPECT_READY")
HookSecureFunc("NotifyInspect", InspectNotify)
HookSecureFunc("ClearInspectPlayer", InspectReady)
INSPECT_READY:SetScript("OnEvent", InspectReady)
INSPECT_READY:RegisterEvent("INSPECT_TALENT_READY")