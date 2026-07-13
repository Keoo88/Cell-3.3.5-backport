local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local B = Cell.bFuncs
local P = Cell.pixelPerfectFuncs

Cell.unitButtons = {
    ["solo"] = {},
    ["party"] = {
        ["units"] = {}, -- NOTE: update in PartyFrame _initialAttribute-refreshUnitChange
    },
    ["raid"] = {
        ["units"] = {}, -- NOTE: update in UnitButton_OnAttributeChanged
    },
    ["pet"] = {
        ["units"] = {}, -- NOTE: update in _initialAttribute-refreshUnitChange
    },
    ["npc"] = {
        ["units"] = {}, -- NOTE: update on creation
    },
    ["arena"] = {},
    ["spotlight"] = {},
    ["quickAssist"] = {
        ["units"] = {},
    },
}

-- local hoverTop, hoverBottom, hoverLeft, hoverRight
local tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY
-------------------------------------------------
-- CellMainFrame
-------------------------------------------------
local cellMainFrame = CreateFrame("Frame", "CellMainFrame", CellParent, "SecureFrameTemplate")
Cell.frames.mainFrame = cellMainFrame
-- WotLK Fix: Explicitly show the frame (in WotLK, SecureFrameTemplate frames may start hidden)
cellMainFrame:Show()

local hoverFrame = CreateFrame("Frame", "CellMenuHoverDetector", cellMainFrame)
-- Cell.StylizeFrame(hoverFrame, {1,0,0,0.3}, {0,0,0,0})

local anchorFrame = CreateFrame("Frame", "CellAnchorFrame", cellMainFrame)
Cell.frames.anchorFrame = anchorFrame
PixelUtil.SetPoint(anchorFrame, "TOPLEFT", CellParent, "CENTER", 1, -1)
P.Size(anchorFrame, 20, 10)
anchorFrame:SetMovable(true)
anchorFrame:SetClampedToScreen(true)

local function RegisterButtonEvents(frame)
    -- frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        anchorFrame:StartMoving()
        anchorFrame:SetUserPlaced(false)
    end)
    frame:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        anchorFrame:StopMovingOrSizing()
        P.SavePosition(anchorFrame, Cell.vars.currentLayoutTable["main"]["position"])
    end)

    frame:HookScript("OnEnter", function()
        hoverFrame:GetScript("OnEnter")(hoverFrame)
        -- Cell.frames.menuFrame:SetFrameStrata("HIGH")
        -- Cell.frames.menuFrame:SetToplevel(true)
    end)
    frame:HookScript("OnLeave", function()
        hoverFrame:GetScript("OnLeave")(hoverFrame)
        -- Cell.frames.menuFrame:SetFrameStrata(CellDB["appearance"]["strata"])
        -- Cell.frames.menuFrame:SetToplevel(false)
    end)
end

-------------------------------------------------
-- buttons
-------------------------------------------------
local menuFrame = CreateFrame("Frame", "CellMenuFrame", cellMainFrame)
Cell.frames.menuFrame = menuFrame
menuFrame:SetAllPoints(anchorFrame)
menuFrame:SetFrameLevel(27)



local options = Cell.CreateButton(menuFrame, "", "red", {20, 10}, false, true)
P.Point(options, "TOPLEFT", menuFrame)
RegisterButtonEvents(options)
options:RegisterForClicks("LeftButtonUp", "RightButtonUp")
options:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        F.ShowOptionsFrame()
    elseif button == "RightButton" then
        F.IterateAllUnitButtons(B.UpdateAll, true)
        F.Print(L["Unit buttons refreshed (%s)."]:format(F.UpperFirst(L["all"])))
    end
end)
options:HookScript("OnEnter", function()
    CellTooltip:SetOwner(options, "ANCHOR_NONE")
    CellTooltip:SetPoint(tooltipPoint, options, tooltipRelativePoint, tooltipX, tooltipY)
    CellTooltip:AddLine(L["Options"])
    CellTooltip:AddLine("|cffffb5c5"..L["Right-Click"]..": |cffffffff"..L["refresh unit buttons"])
    CellTooltip:Show()
end)
options:HookScript("OnLeave", function()
    CellTooltip:Hide()
end)

local raid = Cell.CreateButton(menuFrame, "", "blue", {20, 10}, false, true)
P.Point(raid, "LEFT", options, "RIGHT", 1, 0)
RegisterButtonEvents(raid)
raid:SetScript("OnClick", function()
    F.ShowRaidRosterFrame()
end)

-- local tools = Cell.CreateButton(menuFrame, "", "chartreuse", {20, 10}, false, true, nil, nil, "SecureHandlerAttributeTemplate,SecureHandlerClickTemplate")
-- tools:SetSize(20, 10)
-- tools:EnableMouse(true)
-- P.Point(tools, "LEFT", raid, "RIGHT", 1, 0)
-- RegisterButtonEvents(tools)
-- tools:SetAttribute("_onclick", [[
--     print(self:GetFrameRef("main"))
--     print(self:GetAttribute("main"))
-- ]])
-- SecureHandlerSetFrameRef(tools, "main", cellMainFrame)

-- REVIEW: raid tool button
--[===[
local frame = CreateFrame("Frame", nil, cellMainFrame, nil)
Cell.StylizeFrame(frame)
frame:SetSize(100, 100)
frame:SetPoint("BOTTOMLEFT", cellMainFrame, "TOPLEFT", 0, 30)
frame:Hide()

local mark = Cell.CreateButton(frame, "", "accent-hover", {20, 20}, false, false, nil, nil, "SecureActionButtonTemplate")
mark:SetPoint("CENTER")
mark:SetSize(20, 20)
mark.texture = mark:CreateTexture(nil, "ARTWORK")
mark.texture:SetColorTexture(1, 0, 0, 0.4)
mark.texture:SetAllPoints(mark)
mark:SetAttribute("type", "worldmarker")
mark:SetAttribute("marker", 1)

-- local tools = Cell.CreateButton(menuFrame, "", "chartreuse", {20, 10}, false, true, nil, nil, "SecureHandlerAttributeTemplate,SecureHandlerClickTemplate")
local tools = CreateFrame("Frame", nil, menuFrame, "SecureHandlerMouseUpDownTemplate")
Cell.StylizeFrame(tools)
tools:SetSize(20, 10)
tools:EnableMouse(true)
P.Point(tools, "LEFT", raid, "RIGHT", 1, 0)
tools:SetFrameStrata("MEDIUM")
RegisterButtonEvents(tools)
-- tools:SetScript("_onclick", function()
--     print(frame:IsShown())
-- end)
tools:SetFrameRef("frame", frame)

tools:SetAttribute("_onmousedown", [=[
    -- self, button
    local frame = self:GetFrameRef("frame")
    local raidMarksFrame = self:GetFrameRef("raidMarksFrame")
    if frame:IsShown() then
        frame:Hide()
        raidMarksFrame:Hide()
    else
        frame:Show()
        raidMarksFrame:Show()
    end
]=])
]===]

-------------------------------------------------
-- LoadingBar
-------------------------------------------------
local loadingBar = CreateFrame("StatusBar", "CellLoadingBar", options)
loadingBar:Hide()
loadingBar:SetStatusBarTexture(Cell.vars.whiteTexture)
loadingBar:SetStatusBarColor(0.5, 1, 0)
P.Height(loadingBar, 1)
P.Point(loadingBar, "BOTTOMLEFT", options, 1, 1)
P.Point(loadingBar, "BOTTOMRIGHT", options, -1, 1)

-------------------------------------------------
-- MemoryUsage
-------------------------------------------------
--[==[@debug@
-- local memUsage = CreateFrame("Frame", nil, cellMainFrame)
-- memUsage:SetSize(10, 10)
-- memUsage:SetPoint("LEFT", raid, "RIGHT", 5, 0)
-- memUsage.text = memUsage:CreateFontString(nil, "OVERLAY", "CELL_WRATH_FONT_WIDGET")
-- memUsage.text:SetPoint("LEFT")
-- memUsage:SetScript("OnUpdate", function(self, elapsed)
--     self.elapsed = (self.elapsed or 0) + elapsed
--     if self.elapsed > 1 then
--         UpdateAddOnMemoryUsage()
--         memUsage.text:SetFormattedText("%.2fMB", GetAddOnMemoryUsage("Cell")/1024)
--         self.elapsed = 0
--     end
-- end)
--@end-debug@]==]
-------------------------------------------------
-- fade out
-------------------------------------------------
local fadeTimer
local function FadeOnUpdate(self, elapsed)
    local currentAlpha = self:GetAlpha()
    local targetAlpha = self.targetAlpha or 1
    local change = (elapsed / 0.25) -- Fade duration 0.25s

    if currentAlpha < targetAlpha then
        currentAlpha = currentAlpha + change
        if currentAlpha >= targetAlpha then
            currentAlpha = targetAlpha
            self:SetScript("OnUpdate", nil)
        end
    elseif currentAlpha > targetAlpha then
        currentAlpha = currentAlpha - change
        if currentAlpha <= targetAlpha then
            currentAlpha = targetAlpha
            self:SetScript("OnUpdate", nil)
        end
    else
        self:SetScript("OnUpdate", nil)
    end

    self:SetAlpha(currentAlpha)
end

local function SmartFadeIn()
    if menuFrame:GetAlpha() == 1 then return end
    menuFrame.targetAlpha = 1
    menuFrame:SetScript("OnUpdate", FadeOnUpdate)
end

local function SmartFadeOut()
    if menuFrame:GetAlpha() == 0 then return end
    menuFrame.targetAlpha = 0
    menuFrame:SetScript("OnUpdate", FadeOnUpdate)
end

local fadeOutTimer

hoverFrame:SetScript("OnEnter", function()
    if fadeOutTimer then
        fadeOutTimer:Cancel()
        fadeOutTimer = nil
    end

    if not CellDB["general"]["fadeOut"] then return end
    SmartFadeIn()
end)

hoverFrame:SetScript("OnLeave", function()
    if not CellDB["general"]["fadeOut"] then return end

    if fadeOutTimer then fadeOutTimer:Cancel() end
    fadeOutTimer = C_Timer.NewTimer(0.1, function()
        fadeOutTimer = nil
        if not CellDB["general"]["fadeOut"] then return end
        if hoverFrame:IsMouseOver() then return end
        
        SmartFadeOut()
    end)
end)

local function UpdateHoverFrame()
    -- WotLK: Safety check - currentLayoutTable may not be initialized yet
    if not Cell.vars.currentLayoutTable then return end
    local anchor = Cell.vars.currentLayoutTable["main"]["anchor"]
    local top, bottom, left, right

    if CellDB["general"]["menuPosition"] == "top_bottom" then
        top, bottom = anchorFrame, anchorFrame
        if strfind(anchor, "LEFT$") then
            left = anchorFrame
            right = anchorFrame
            if raid:IsShown() then right = raid end
        else -- RIGHT$
            left = anchorFrame
            if raid:IsShown() then left = raid end
            right = anchorFrame
        end
    else -- left_right
        left, right = anchorFrame, anchorFrame
        if strfind(anchor, "^TOP") then
            top = anchorFrame
            bottom = anchorFrame
            if raid:IsShown() then bottom = raid end
        else -- ^BOTTOM
            top = anchorFrame
            if raid:IsShown() then top = raid end
            bottom = anchorFrame
        end
    end

    hoverFrame:ClearAllPoints()
    -- hoverFrame:SetPoint("TOP", top, 0, hoverTop)
    -- hoverFrame:SetPoint("BOTTOM", bottom, 0, hoverBottom)
    -- hoverFrame:SetPoint("LEFT", left, hoverLeft, 0)
    -- hoverFrame:SetPoint("RIGHT", right, hoverRight, 0)
    hoverFrame:SetPoint("TOP", top, 0, 1)
    hoverFrame:SetPoint("BOTTOM", bottom, 0, -1)
    hoverFrame:SetPoint("LEFT", left, -1, 0)
    hoverFrame:SetPoint("RIGHT", right, 1, 0)
end

-------------------------------------------------
-- raid setup
-------------------------------------------------
local tankIcon = F.GetDefaultRoleIconEscapeSequence("TANK")
local healerIcon = F.GetDefaultRoleIconEscapeSequence("HEALER")
local damagerIcon = F.GetDefaultRoleIconEscapeSequence("DAMAGER")

-- local GetGroupMemberCountsForDisplay = GetGroupMemberCountsForDisplay
-- if not GetGroupMemberCountsForDisplay then
--     GetGroupMemberCountsForDispla = function()
--         local data = GetGroupMemberCounts()
--         data.DAMAGER = data.DAMAGER + data.NOROLE --People without a role count as damager
--         data.NOROLE = 0
--         return data
--     end
-- end

local function GetRaidSetupDetail(role)
    local line = "  "

    for class in F.IterateClasses() do
        if Cell.vars.raidSetup[role][class] then
            local r, g, b = F.ConvertRGB_256(F.GetClassColor(class))

            for i = 1, Cell.vars.raidSetup[role][class] do
                if line ~= "  " then
                    line = line .. "|TInterface\\AddOns\\Cell_Wrath\\Media\\white:10:1:0:0:1:10:1:1:1:10:0:0:0|t"
                end

                line = line .. "|TInterface\\AddOns\\Cell_Wrath\\Media\\white:10:2:0:0:2:10:1:2:1:10:"..r..":"..g..":"..b.."|t"
            end
        end
    end

    return line
end

local function UpdateRaidSetupTooltip()
    CellTooltip:ClearLines()
    CellTooltip:AddLine(L["Raid"])

    if CELL_TOOLTIP_REMOVE_RAID_SETUP_DETAILS then
        CellTooltip:AddLine(tankIcon.." |cffffffff"..Cell.vars.raidSetup.TANK.ALL)
        CellTooltip:AddLine(healerIcon.." |cffffffff"..Cell.vars.raidSetup.HEALER.ALL)
        CellTooltip:AddLine(damagerIcon.." |cffffffff"..Cell.vars.raidSetup.DAMAGER.ALL)
    else
        CellTooltip:AddLine(tankIcon.." |cffffffff"..Cell.vars.raidSetup.TANK.ALL.."|r"..GetRaidSetupDetail("TANK"))
        CellTooltip:AddLine(healerIcon.." |cffffffff"..Cell.vars.raidSetup.HEALER.ALL.."|r"..GetRaidSetupDetail("HEALER"))
        CellTooltip:AddLine(damagerIcon.." |cffffffff"..Cell.vars.raidSetup.DAMAGER.ALL.."|r"..GetRaidSetupDetail("DAMAGER"))
    end

    CellTooltip:Show()
end

raid:HookScript("OnEnter", function()
    CellTooltip:SetOwner(raid, "ANCHOR_NONE")
    CellTooltip:SetPoint(tooltipPoint, raid, tooltipRelativePoint, tooltipX, tooltipY)
    UpdateRaidSetupTooltip()
end)

raid:HookScript("OnLeave", function()
    CellTooltip:Hide()
end)

function F.UpdateRaidSetup()
    if CellTooltip:GetOwner() == raid then
        UpdateRaidSetupTooltip()
    end
end

-------------------------------------------------
-- group type changed
-------------------------------------------------
local function MainFrame_GroupTypeChanged(groupType)
    if groupType == "raid" then
        raid:Show()
    else
        raid:Hide()
    end
    UpdateHoverFrame()
end
Cell.RegisterCallback("GroupTypeChanged", "MainFrame_GroupTypeChanged", MainFrame_GroupTypeChanged)

-------------------------------------------------
-- event
-------------------------------------------------
-- cellMainFrame:RegisterEvent("PET_BATTLE_OPENING_START")
-- cellMainFrame:RegisterEvent("PET_BATTLE_OVER")
-- cellMainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- cellMainFrame:SetScript("OnEvent", function(self, event, ...)
--     if event == "PET_BATTLE_OPENING_START" then
--         cellMainFrame:Hide()
--     elseif event == "PET_BATTLE_OVER" then
--         cellMainFrame:Show()
--     -- elseif event == "PLAYER_ENTERING_WORLD" then
--     --     tools:SetFrameRef("raidMarksFrame", Cell.frames.raidMarksFrame)
--     end
-- end)

-------------------------------------------------
-- load & update
-------------------------------------------------
local function UpdatePosition()
    local anchor = Cell.vars.currentLayoutTable["main"]["anchor"]

    cellMainFrame:ClearAllPoints()
    P.ClearPoints(raid)

    if CellDB["general"]["menuPosition"] == "top_bottom" then
        P.Size(anchorFrame, 20, 10)
        P.Size(options, 20, 10)
        P.Size(raid, 20, 10)


        if anchor == "BOTTOMLEFT" then
            cellMainFrame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 4)
            P.Point(raid, "BOTTOMLEFT", options, "BOTTOMRIGHT", 1, 0)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPLEFT", "BOTTOMLEFT", 0, -3
            -- hoverTop, hoverBottom, hoverLeft, hoverRight = 5, -20, -20, 20

        elseif anchor == "BOTTOMRIGHT" then
            cellMainFrame:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 4)
            P.Point(raid, "BOTTOMRIGHT", options, "BOTTOMLEFT", -1, 0)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPRIGHT", "BOTTOMRIGHT", 0, -3
            -- hoverTop, hoverBottom, hoverLeft, hoverRight = 5, -20, -20, 20

        elseif anchor == "TOPLEFT" then
            cellMainFrame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
            P.Point(raid, "TOPLEFT", options, "TOPRIGHT", 1, 0)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMLEFT", "TOPLEFT", 0, 3
            -- hoverTop, hoverBottom, hoverLeft, hoverRight = 20, -5, -20, 20

        elseif anchor == "TOPRIGHT" then
            cellMainFrame:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -4)
            P.Point(raid, "TOPRIGHT", options, "TOPLEFT", -1, 0)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMRIGHT", "TOPRIGHT", 0, 3
            -- hoverTop, hoverBottom, hoverLeft, hoverRight = 20, -5, -20, 20
        end
    else -- left_right
        P.Size(anchorFrame, 10, 20)
        P.Size(options, 10, 20)
        P.Size(raid, 10, 20)

        if anchor == "BOTTOMLEFT" then
            cellMainFrame:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMRIGHT", 4, 0)
            P.Point(raid, "BOTTOMLEFT", options, "TOPLEFT", 0, 1)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMRIGHT", "BOTTOMLEFT", -3, 0
            -- hoverTop, hoverBottom, hoverLeft, hoverRight = 20, -20, -20, 5

        elseif anchor == "BOTTOMRIGHT" then
            cellMainFrame:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMLEFT", -4, 0)
            P.Point(raid, "BOTTOMRIGHT", options, "TOPRIGHT", 0, 1)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMLEFT", "BOTTOMRIGHT", 3, 0
            -- hoverTop, hoverBottom, hoverLeft, hoverRight = 20, -20, -5, 20

        elseif anchor == "TOPLEFT" then
            cellMainFrame:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 4, 0)
            P.Point(raid, "TOPLEFT", options, "BOTTOMLEFT", 0, -1)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPRIGHT", "TOPLEFT", -3, 0
            -- hoverTop, hoverBottom, hoverLeft, hoverRight = 20, -20, -20, 5

        elseif anchor == "TOPRIGHT" then
            cellMainFrame:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -4, 0)
            P.Point(raid, "TOPRIGHT", options, "BOTTOMRIGHT", 0, -1)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPLEFT", "TOPRIGHT", 3, 0
            -- hoverTop, hoverBottom, hoverLeft, hoverRight = 20, -20, -5, 20
        end
    end

    UpdateHoverFrame()
end

local function UpdateMenu(which)
    F.Debug("|cff00bfffUpdateMenu:|r", which)

    if not which or which == "lock" then
        if CellDB["general"]["locked"] then
            options:RegisterForDrag()
            raid:RegisterForDrag()
            -- tools:RegisterForDrag()
        else
            options:RegisterForDrag("LeftButton")
            raid:RegisterForDrag("LeftButton")
            -- tools:RegisterForDrag("LeftButton")
        end
    end

    if not which or which == "fadeOut" then
        -- Clean up timer if verifying settings
        if fadeOutTimer then
            fadeOutTimer:Cancel()
            fadeOutTimer = nil
        end
        
        -- Stop any fade script
        menuFrame:SetScript("OnUpdate", nil)

        if CellDB["general"]["fadeOut"] then
            if hoverFrame:IsMouseOver() then
                menuFrame:SetAlpha(1)
            else
                menuFrame:SetAlpha(0)
            end
        else
            menuFrame:SetAlpha(1)
        end
    end

    if which == "position" then
        UpdatePosition()
    end
end
Cell.RegisterCallback("UpdateMenu", "MainFrame_UpdateMenu", UpdateMenu)

local init
local function MainFrame_UpdateLayout(layout, which)
    F.Debug("|cffff0066UpdateLayout:|r layout:", layout, " which:", which)

    -- visibility
    if Cell.vars.isHidden then
        anchorFrame:Hide()
        menuFrame:Hide()
        hoverFrame:Hide()
        return
    else
        anchorFrame:Show()
        menuFrame:Show()
        hoverFrame:Show()
    end

    if not init then
        --! NOTE: a reload during pet battle prevents HEADER from CREATING CHILDs (unit buttons), this hide delay is a MUST
        -- WotLK Fix: Pet battles don't exist in WotLK, so just keep frame visible
        RegisterStateDriver(cellMainFrame, "visibility", "show")
        init = true
    end

    layout = Cell.vars.currentLayoutTable

    if not which or which == "main-size" then
        P.Size(cellMainFrame, unpack(layout["main"]["size"]))
    end

    if not which or which == "main-arrangement" then
        UpdatePosition()
    end

    -- load position
    if not which then
        if not P.LoadPosition(anchorFrame, layout["main"]["position"]) then
            P.ClearPoints(anchorFrame)
            -- no position, use default
            PixelUtil.SetPoint(anchorFrame, "TOPLEFT", CellParent, "CENTER", 1, -1)
        end
    end
end
Cell.RegisterCallback("UpdateLayout", "MainFrame_UpdateLayout", MainFrame_UpdateLayout)

local function UpdatePixelPerfect()
    F.Debug("|cffffff7fUpdatePixelPerfect")
    P.Resize(cellMainFrame)
    -- P.Repoint(cellMainFrame)
    P.Resize(anchorFrame)
    options:UpdatePixelPerfect()
    raid:UpdatePixelPerfect()
    P.Repoint(loadingBar)
    P.Resize(loadingBar)

    F.IterateAllUnitButtons(function(b)
        B.UpdatePixelPerfect(b, true)
    end, true)
end
Cell.RegisterCallback("UpdatePixelPerfect", "MainFrame_UpdatePixelPerfect", UpdatePixelPerfect)