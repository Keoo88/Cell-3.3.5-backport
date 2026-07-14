local _, Private = ...

-- Texture Path
Private.TEXTURE_PATH = "Interface\\AddOns\\Cell\\Libs\\ClassicAPI\\Texture\\"

-- Scan Tooltip
local Tooltip = CreateFrame("GameTooltip", "CAPI_ScanTooltip")
Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
Tooltip:AddFontStrings(Tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"), Tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText"))
Private.Tooltip = Tooltip

-- General Event
Tooltip:SetScript("OnEvent", function(Self, Event)
	-- [Unit.lua:C_UnitInRange] Force client to cache Vial of the Sunwell
	if ( WOW_PROJECT_ID_RCE ~= WOW_PROJECT_CLASSIC ) then
		C_Item.RequestLoadItemDataByID(34471)
	end

	Private.AsyncCallbackSystemReady()
	Self:UnregisterEvent(Event)
	Self:SetScript("OnEvent", nil)
end)
Tooltip:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Common Functions
function Private.Void()
	-- To the nether!
end

function Private.True()
	return true
end

function Private.False()
	return false
end

function Private.Zero()
	return 0
end

--[[ MISCELLANEOUS ]]

-- [LFD_ERROR_FIX] Workaround long-standing client/server error.
local LFDCooldown = LFDQueueFrameCooldownFrame
if ( LFDCooldown ) then
	LFDCooldown:UnregisterEvent("UNIT_AURA")
	LFDCooldown:UnregisterEvent("PARTY_MEMBERS_CHANGED")
	LFDQueueFrame:HookScript("OnShow", LFDQueueFrameRandomCooldownFrame_Update)
end
