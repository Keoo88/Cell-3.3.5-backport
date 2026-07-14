local SecureCall = securecall
local GameTooltip = GameTooltip
local GetMouseFocus = GetMouseFocus

local IsMouseOver = UIParent.IsMouseOver
local GetOwner = GameTooltip.GetOwner

local CURSOR_OBJECT
local LeaveHandler, EnterHandler, MouseFrame

local _, _, _, Clique = GetAddOnInfo("Clique")

local function Handler(Self, Shown)
	if ( not Shown or not IsMouseOver(CURSOR_OBJECT) ) then
		Self:EnableMouse(true)
		Self:SetScript("OnUpdate", nil)
		Self:SetScript("OnHide", nil)

		LeaveHandler = Self:GetScript("OnLeave")
		if ( LeaveHandler ) then
			SecureCall(LeaveHandler, Self)
		end

		MouseFrame = GetMouseFocus()
		if ( MouseFrame ) then
			EnterHandler = MouseFrame:GetScript("OnEnter")
			if ( EnterHandler ) then
				SecureCall(EnterHandler, MouseFrame)
			end
		end

		return
	end

	if ( Self == CURSOR_OBJECT and GetOwner(GameTooltip) ~= CURSOR_OBJECT ) then
		SecureCall(CURSOR_OBJECT:GetScript("OnEnter"), CURSOR_OBJECT)
	end
end

local function Event(Self)
	CURSOR_OBJECT = Self
	Self:EnableMouse(false)

	Self:SetScript("OnUpdate", Handler)
	Self:SetScript("OnHide", Handler)
end

-- Requirement: Must be set within OnLoad script.
function PropagateTooltipMouseClicks(Self)
	if ( Clique ) then
		Self:EnableMouse(false)
		return
	end

	Self:HookScript("OnEnter", Event)
end