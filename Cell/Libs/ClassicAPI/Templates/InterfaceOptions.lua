local IOF = InterfaceOptionsFrame
local IOFA = InterfaceOptionsFrameAddOns

local W, H = 858, 660

IOF:SetToplevel(true)
IOF:SetSize(W, H)
IOF:SetPoint("CENTER", UIParent, "CENTER")
InterfaceOptionsFrameCategories:SetPoint("BOTTOMLEFT", IOF, "BOTTOMLEFT", 22, 50)
IOFA:SetPoint("BOTTOMLEFT", IOF, "BOTTOMLEFT", 22, 50)

for i=#IOFA.buttons+1,((IOFA:GetTop() - IOFA:GetBottom() - 8) / IOFA.buttonHeight) do
	local Button = CreateFrame("BUTTON", IOFA:GetName().."Button"..i, IOFA, "InterfaceOptionsListButtonTemplate")
	Button:SetPoint("TOPLEFT", IOFA.buttons[i-1], "BOTTOMLEFT")
	IOFA.buttons[i] = Button
end

IOF:HookScript("OnShow", function()
	IOF:SetSize(W, H)
end)