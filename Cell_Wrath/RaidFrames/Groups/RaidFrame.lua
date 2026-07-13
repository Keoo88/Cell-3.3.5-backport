local _, Cell = ...
---@class CellFuncs
local F = Cell.funcs
local B = Cell.bFuncs
local P = Cell.pixelPerfectFuncs

local raidFrame = CreateFrame("Frame", "CellRaidFrame", Cell.frames.mainFrame, "SecureHandlerAttributeTemplate")
Cell.frames.raidFrame = raidFrame
raidFrame:SetAllPoints(Cell.frames.mainFrame)

local npcFrameAnchor = CreateFrame("Frame", "CellNPCFrameAnchor", raidFrame, "SecureFrameTemplate,BackDropTemplate")
raidFrame:SetFrameRef("npcAnchor", npcFrameAnchor)
-- npcFrameAnchor:Hide()
-- Cell.StylizeFrame(npcFrameAnchor)

raidFrame:SetAttribute("_onattributechanged", [[
    if not (name == "combinegroups" or name == "visibility") then
        return
    end

    local header
    local combineGroups = self:GetAttribute("combineGroups")

    if combineGroups then
        header = self:GetFrameRef("combinedHeader")
    else
        local maxGroup
        for i = 1, 8 do
            if self:GetFrameRef("visibilityHelper"..i):IsVisible() then
                maxGroup = i
            end
        end
        if not maxGroup then return end -- NOTE: empty subgroup will cause maxGroup == nil
        header = self:GetFrameRef("subgroup"..maxGroup)
    end

    local npcFrameAnchor = self:GetFrameRef("npcAnchor")
    local spacing = self:GetAttribute("spacing") or 0
    local orientation = self:GetAttribute("orientation") or "vertical"
    local anchor = self:GetAttribute("anchor") or "TOPLEFT"

    npcFrameAnchor:ClearAllPoints()
    local point, anchorPoint
    if orientation == "vertical" then
        if anchor == "BOTTOMLEFT" then
            point, anchorPoint = "BOTTOMLEFT", "BOTTOMRIGHT"
        elseif anchor == "BOTTOMRIGHT" then
            point, anchorPoint = "BOTTOMRIGHT", "BOTTOMLEFT"
        elseif anchor == "TOPLEFT" then
            point, anchorPoint = "TOPLEFT", "TOPRIGHT"
        elseif anchor == "TOPRIGHT" then
            point, anchorPoint = "TOPRIGHT", "TOPLEFT"
        end

        npcFrameAnchor:SetPoint(point, header, anchorPoint, spacing, 0)
    else
        if anchor == "BOTTOMLEFT" then
            point, anchorPoint = "BOTTOMLEFT", "TOPLEFT"
        elseif anchor == "BOTTOMRIGHT" then
            point, anchorPoint = "BOTTOMRIGHT", "TOPRIGHT"
        elseif anchor == "TOPLEFT" then
            point, anchorPoint = "TOPLEFT", "BOTTOMLEFT"
        elseif anchor == "TOPRIGHT" then
            point, anchorPoint = "TOPRIGHT", "BOTTOMRIGHT"
        end

        npcFrameAnchor:SetPoint(point, header, anchorPoint, 0, spacing)
    end
]])

--[[ Interface\FrameXML\SecureGroupHeaders.lua
List of the various configuration attributes
======================================================
showRaid = [BOOLEAN] -- true if the header should be shown while in a raid
showParty = [BOOLEAN] -- true if the header should be shown while in a party and not in a raid
showPlayer = [BOOLEAN] -- true if the header should show the player when not in a raid
showSolo = [BOOLEAN] -- true if the header should be shown while not in a group (implies showPlayer)
nameList = [STRING] -- a comma separated list of player names (not used if 'groupFilter' is set)
groupFilter = [1-8, STRING] -- a comma seperated list of raid group numbers and/or uppercase class names and/or uppercase roles
roleFilter = [STRING] -- a comma seperated list of MT/MA/Tank/Healer/DPS role strings
strictFiltering = [BOOLEAN]
-- if true, then
---- if only groupFilter is specified then characters must match both a group and a class from the groupFilter list
---- if only roleFilter is specified then characters must match at least one of the specified roles
---- if both groupFilter and roleFilters are specified then characters must match a group and a class from the groupFilter list and a role from the roleFilter list
point = [STRING] -- a valid XML anchoring point (Default: "TOP")
xOffset = [NUMBER] -- the x-Offset to use when anchoring the unit buttons (Default: 0)
yOffset = [NUMBER] -- the y-Offset to use when anchoring the unit buttons (Default: 0)
sortMethod = ["INDEX", "NAME", "NAMELIST"] -- defines how the group is sorted (Default: "INDEX")
sortDir = ["ASC", "DESC"] -- defines the sort order (Default: "ASC")
template = [STRING] -- the XML template to use for the unit buttons
templateType = [STRING] - specifies the frame type of the managed subframes (Default: "Button")
groupBy = [nil, "GROUP", "CLASS", "ROLE", "ASSIGNEDROLE"] - specifies a "grouping" type to apply before regular sorting (Default: nil)
groupingOrder = [STRING] - specifies the order of the groupings (ie. "1,2,3,4,5,6,7,8")
maxColumns = [NUMBER] - maximum number of columns the header will create (Default: 1)
unitsPerColumn = [NUMBER or nil] - maximum units that will be displayed in a singe column, nil is infinite (Default: nil)
startingIndex = [NUMBER] - the index in the final sorted unit list at which to start displaying units (Default: 1)
columnSpacing = [NUMBER] - the amount of space between the rows/columns (Default: 0)
columnAnchorPoint = [STRING] - the anchor point of each new column (ie. use LEFT for the columns to grow to the right)
--]]

-------------------------------------------------
-- combinedHeader
-------------------------------------------------
local combinedHeader
do
    local headerName = "CellRaidFrameHeader0"
    combinedHeader = CreateFrame("Frame", headerName, raidFrame, "SecureGroupHeaderTemplate")
    Cell.unitButtons.raid[headerName] = combinedHeader

    combinedHeader:SetAttribute("template", "CellUnitButtonTemplate")
    combinedHeader:SetAttribute("columnAnchorPoint", "LEFT")
    combinedHeader:SetAttribute("point", "TOP")
    combinedHeader:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    -- combinedHeader:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
    -- combinedHeader:SetAttribute("groupBy", "ASSIGNEDROLE")
    combinedHeader:SetAttribute("xOffset", 0)
    combinedHeader:SetAttribute("yOffset", -1)
    combinedHeader:SetAttribute("unitsPerColumn", 5)
    combinedHeader:SetAttribute("maxColumns", 8)
    -- combinedHeader:SetAttribute("showRaid", true)

    combinedHeader:SetAttribute("startingIndex", -39)
    combinedHeader:Show()
    combinedHeader:SetAttribute("startingIndex", 1)

    --! WotLK 3.3.5a: SecureGroupHeaderTemplate creates buttons automatically via attributes
    --! We force creation using the startingIndex trick above
    --! Buttons will be registered in CellUnitButton_OnLoad


    -- for npcFrame's point
    raidFrame:SetFrameRef("combinedHeader", combinedHeader)
end

-------------------------------------------------
-- separatedHeaders
-------------------------------------------------
local separatedHeaders = {}
local function CreateGroupHeader(group)
    local headerName = "CellRaidFrameHeader"..group
    local header = CreateFrame("Frame", headerName, raidFrame, "SecureGroupHeaderTemplate")
    separatedHeaders[group] = header
    Cell.unitButtons.raid[headerName] = header

    -- header:SetAttribute("initialConfigFunction", [[
    --     RegisterUnitWatch(self)

    --     local header = self:GetParent()
    --     self:SetWidth(header:GetAttribute("buttonWidth") or 66)
    --     self:SetHeight(header:GetAttribute("buttonHeight") or 46)
    -- ]])

    -- header:SetAttribute("_initialAttributeNames", "refreshUnitChange")

    header:SetAttribute("template", "CellUnitButtonTemplate")
    header:SetAttribute("columnAnchorPoint", "LEFT")
    header:SetAttribute("point", "TOP")
    header:SetAttribute("groupFilter", group)
    header:SetAttribute("xOffset", 0)
    header:SetAttribute("yOffset", -1)
    header:SetAttribute("unitsPerColumn", 5)
    header:SetAttribute("columnSpacing", 1)
    header:SetAttribute("maxColumns", 1)
    -- header:SetAttribute("startingIndex", 1)
    header:SetAttribute("showRaid", true)

    --[[ Interface\FrameXML\SecureGroupHeaders.lua line 150
        local loopStart = startingIndex;
        local loopFinish = min((startingIndex - 1) + unitsPerColumn * numColumns, unitCount)
        -- ensure there are enough buttons
        numDisplayed = loopFinish - (loopStart - 1)
        local needButtons = max(1, numDisplayed); --! to make needButtons == 5
    ]]

    --! to make needButtons == 5 cheat configureChildren in SecureGroupHeaders.lua
    header:SetAttribute("startingIndex", -4)
    header:Show()
    header:SetAttribute("startingIndex", 1)

    --! WotLK 3.3.5a: SecureGroupHeaderTemplate creates buttons automatically via attributes
    --! We force creation using the cheat above
    --! Buttons will be registered in CellUnitButton_OnLoad


    -- for npcFrame's point
    raidFrame:SetFrameRef("subgroup"..group, header)

    local helper = CreateFrame("Frame", nil, header[1], "SecureHandlerShowHideTemplate")
    helper:SetFrameRef("raidframe", raidFrame)
    raidFrame:SetFrameRef("visibilityHelper"..group, helper)
    helper:SetAttribute("_onshow", [[ self:GetFrameRef("raidframe"):SetAttribute("visibility", 1) ]])
    helper:SetAttribute("_onhide", [[ self:GetFrameRef("raidframe"):SetAttribute("visibility", 0) ]])
end

for i = 1, 8 do
    CreateGroupHeader(i)
end

--! WotLK 3.3.5a: Trigger layout update after raid button creation
-- NOTE: This ensures buttons are sized correctly after initial load
C_Timer.After(0.5, function()
    if Cell and F and F.UpdateLayout and Cell.vars.groupType == "raid" then
        -- Determine which raid layout type to use
        if Cell.vars.raidType then
            F.UpdateLayout(Cell.vars.raidType)
        else
            F.UpdateLayout("raid_outdoor")
        end
    end
end)

-- arena pet
local arenaPetButtons = {}
for i = 1, (Cell.isRetail and 3 or 5) do
    arenaPetButtons[i] = CreateFrame("Button", "CellArenaPet"..i, raidFrame, "CellUnitButtonTemplate")
    arenaPetButtons[i]:SetAttribute("unit", "raidpet"..i)

    Cell.unitButtons.arena["raidpet"..i] = arenaPetButtons[i]
end

-------------------------------------------------
-- update
-------------------------------------------------
function F.GetRaidFramePoints(layout)
    local orientation = layout["orientation"]
    local anchor = layout["anchor"]
    local spacingX = layout["spacingX"]
    local spacingY = layout["spacingY"]
    local width, height = unpack(layout["size"])

    local point, anchorPoint, groupAnchorPoint, unitSpacing, groupSpacing, unitSpacingX, unitSpacingY, verticalSpacing, horizontalSpacing, headerPoint, headerColumnAnchorPoint

    if orientation == "vertical" then
        if anchor == "BOTTOMLEFT" then
            point, anchorPoint, groupAnchorPoint = "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT"
            headerPoint, headerColumnAnchorPoint = "BOTTOM", "LEFT"
            unitSpacing = spacingY
            groupSpacing = spacingX
            unitSpacingX, unitSpacingY = spacingX, spacingY
            verticalSpacing = P.Scale(spacingY) + P.Scale(layout["groupSpacing"]) + P.Scale(height) * 5 + P.Scale(spacingY) * 4
        elseif anchor == "BOTTOMRIGHT" then
            point, anchorPoint, groupAnchorPoint = "BOTTOMRIGHT", "TOPRIGHT", "BOTTOMLEFT"
            headerPoint, headerColumnAnchorPoint = "BOTTOM", "RIGHT"
            unitSpacing = spacingY
            groupSpacing = -spacingX
            unitSpacingX, unitSpacingY = spacingX, spacingY
            verticalSpacing = P.Scale(spacingY) + P.Scale(layout["groupSpacing"]) + P.Scale(height) * 5 + P.Scale(spacingY) * 4
        elseif anchor == "TOPLEFT" then
            point, anchorPoint, groupAnchorPoint = "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT"
            headerPoint, headerColumnAnchorPoint = "TOP", "LEFT"
            unitSpacing = -spacingY
            groupSpacing = spacingX
            unitSpacingX, unitSpacingY = spacingX, -spacingY
            verticalSpacing = P.Scale(-layout["groupSpacing"]) + P.Scale(-height) * 5 + P.Scale(-spacingY) * 5
        elseif anchor == "TOPRIGHT" then
            point, anchorPoint, groupAnchorPoint = "TOPRIGHT", "BOTTOMRIGHT", "TOPLEFT"
            headerPoint, headerColumnAnchorPoint = "TOP", "RIGHT"
            unitSpacing = -spacingY
            groupSpacing = -spacingX
            unitSpacingX, unitSpacingY = spacingX, -spacingY
            verticalSpacing = P.Scale(-spacingY) + P.Scale(-layout["groupSpacing"]) + P.Scale(-height) * 5 + P.Scale(-spacingY) * 4
        end
    else
        if anchor == "BOTTOMLEFT" then
            point, anchorPoint, groupAnchorPoint = "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT"
            headerPoint, headerColumnAnchorPoint = "LEFT", "BOTTOM"
            unitSpacing = spacingX
            groupSpacing = spacingY
            unitSpacingX, unitSpacingY = spacingX, spacingY
            horizontalSpacing = P.Scale(spacingX) + P.Scale(layout["groupSpacing"]) + P.Scale(width) * 5 + P.Scale(spacingX) * 4
        elseif anchor == "BOTTOMRIGHT" then
            point, anchorPoint, groupAnchorPoint = "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT"
            headerPoint, headerColumnAnchorPoint = "RIGHT", "BOTTOM"
            unitSpacing = -spacingX
            groupSpacing = spacingY
            unitSpacingX, unitSpacingY = -spacingX, spacingY
            horizontalSpacing = P.Scale(-spacingX) + P.Scale(-layout["groupSpacing"]) + P.Scale(-width) * 5 + P.Scale(-spacingX) * 4
        elseif anchor == "TOPLEFT" then
            point, anchorPoint, groupAnchorPoint = "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT"
            headerPoint, headerColumnAnchorPoint = "LEFT", "TOP"
            unitSpacing = spacingX
            groupSpacing = -spacingY
            unitSpacingX, unitSpacingY = spacingX, spacingY
            horizontalSpacing = P.Scale(spacingX) + P.Scale(layout["groupSpacing"]) + P.Scale(width) * 5 + P.Scale(spacingX) * 4
        elseif anchor == "TOPRIGHT" then
            point, anchorPoint, groupAnchorPoint = "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT"
            headerPoint, headerColumnAnchorPoint = "RIGHT", "TOP"
            unitSpacing = -spacingX
            groupSpacing = -spacingY
            unitSpacingX, unitSpacingY = -spacingX, spacingY
            horizontalSpacing = P.Scale(-spacingX) + P.Scale(-layout["groupSpacing"]) + P.Scale(-width) * 5 + P.Scale(-spacingX) * 4
        end
    end

    return point, anchorPoint, groupAnchorPoint, P.Scale(unitSpacing), P.Scale(groupSpacing), P.Scale(unitSpacingX), P.Scale(unitSpacingY), verticalSpacing, horizontalSpacing, headerPoint, headerColumnAnchorPoint
end

local function UpdateHeadersShowRaidAttribute()
    if Cell.vars.currentLayoutTable["main"]["combineGroups"] then
        combinedHeader:SetAttribute("showRaid", true)
        combinedHeader:Show()
        for _, header in ipairs(separatedHeaders) do
            header:SetAttribute("showRaid", nil)
            header:Hide()
        end
    else
        combinedHeader:SetAttribute("showRaid", nil)
        combinedHeader:Hide()
        for _, header in ipairs(separatedHeaders) do
            header:SetAttribute("showRaid", true)
            header:Show()
        end
    end
end

local function UpdateHeader(header, layout, which)
    --! WotLK 3.3.5a: Re-register buttons with unit watch when layout updates
    if not which then
        for _, b in ipairs(header) do
            local unit = b:GetAttribute("unit")
            if unit then
                RegisterUnitWatch(b)
            end
        end
    end

    if not which or which == "header" or which == "main-size" or which == "main-power" or which == "groupFilter" or which == "barOrientation" or which == "powerFilter" then
        local width, height = unpack(layout["main"]["size"])

        for _, b in ipairs(header) do
            if not which or which == "header" or which == "main-size" or which == "groupFilter" then
                P.Size(b, width, height)
                b:ClearAllPoints()
            end
            -- NOTE: SetOrientation BEFORE SetPowerSize
            if not which or which == "header" or which == "barOrientation" then
                B.SetOrientation(b, layout["barOrientation"][1], layout["barOrientation"][2])
            end
            if not which or which == "header" or which == "main-power" or which == "groupFilter" or which == "barOrientation" or which == "powerFilter" then
                B.SetPowerSize(b, layout["main"]["powerSize"])
            end
        end

        if not which or which == "header" or which == "main-size" or which == "groupFilter" then
            -- 确保按钮在“一定程度上”对齐
            header:SetAttribute("minWidth", P.Scale(width))
            header:SetAttribute("minHeight", P.Scale(height))

            P.Size(npcFrameAnchor, width, height) -- REVIEW: check same as main
        end
    end

    -- REVIEW: fix name width
    if which == "header" or which == "groupFilter" then
        for j, b in ipairs(header) do
            b.widgets.healthBar:GetScript("OnSizeChanged")(b.widgets.healthBar)
        end
        for k, arenaPet in ipairs(arenaPetButtons) do
            arenaPet.widgets.healthBar:GetScript("OnSizeChanged")(arenaPet.widgets.healthBar)
        end
    end
end

-- local function RemoveInitialAttribute(header)
--     header:SetAttribute("_initialAttribute-refreshUnitChange", nil)
-- end

-- local function SetInitialAttribute(header, relativeTo)
--     header:SetAttribute("_initialAttribute-refreshUnitChange", [[

--     ]])
-- end

local function RaidFrame_UpdateLayout(layout, which)
    -- visibility
    if Cell.vars.groupType ~= "raid" or Cell.vars.isHidden then
        UnregisterAttributeDriver(raidFrame, "state-visibility")
        raidFrame:Hide()
        return
    else
        RegisterAttributeDriver(raidFrame, "state-visibility", "show")
        raidFrame:Show()  --! WotLK 3.3.5a: Must explicitly call Show()
    end

    --! WotLK 3.3.5a: Safety check for layout
    if not layout or not CellDB or not CellDB["layouts"] or not CellDB["layouts"][layout] then
        -- Layout not ready yet, retry later
        C_Timer.After(0.5, function()
            local layoutName = CellDB["general"] and CellDB["general"]["layout"] or "default"
            Cell.Fire("UpdateLayout", layoutName, which)
        end)
        return
    end

    -- update
    layout = CellDB["layouts"][layout]

    -- arena pets
    if Cell.vars.inBattleground == 5 and layout["pet"]["partyEnabled"] and not layout["pet"]["partyDetached"] then
        for i, arenaPet in ipairs(arenaPetButtons) do
            RegisterAttributeDriver(arenaPet, "state-visibility", "[@raidpet"..i..", exists] show;hide")
        end
    else
        for i, arenaPet in ipairs(arenaPetButtons) do
            UnregisterAttributeDriver(arenaPet, "state-visibility")
            arenaPet:Hide()
        end
    end

    local point, anchorPoint, groupAnchorPoint, unitSpacing, groupSpacing, unitSpacingX, unitSpacingY, verticalSpacing, horizontalSpacing, headerPoint, headerColumnAnchorPoint = F.GetRaidFramePoints(layout["main"])

    if not which or which == "main-arrangement" or which == "pet-arrangement" or which == "rows_columns" or which == "groupSpacing" or which == "groupFilter" then
        local petSpacingX = layout["pet"]["sameArrangementAsMain"] and unitSpacingX or P.Scale(layout["pet"]["spacingX"])
        local petSpacingY = layout["pet"]["sameArrangementAsMain"] and unitSpacingY or P.Scale(layout["pet"]["spacingY"])

        -- arena pets
        for k in ipairs(arenaPetButtons) do
            arenaPetButtons[k]:ClearAllPoints()
            if k == 1 then
                arenaPetButtons[k]:SetPoint(point, npcFrameAnchor)
            else
                if layout["main"]["orientation"] == "vertical" then
                    arenaPetButtons[k]:SetPoint(point, arenaPetButtons[k-1], anchorPoint, 0, petSpacingY)
                else
                    arenaPetButtons[k]:SetPoint(point, arenaPetButtons[k-1], anchorPoint, petSpacingX, 0)
                end
            end
        end
    end

    local shownGroups = {}
    for i, isShown in ipairs(layout["groupFilter"]) do
        if isShown then
            UpdateHeader(separatedHeaders[i], layout, which)
            tinsert(shownGroups, i)
        end
    end

    if not which or which == "header" then
        UpdateHeadersShowRaidAttribute()
    end

    if layout["main"]["combineGroups"] then
        UpdateHeader(combinedHeader, layout, which)

        if not which or which == "header" or which == "main-arrangement" or which == "rows_columns" or which == "groupSpacing" or which == "unitsPerColumn" then
            combinedHeader:ClearAllPoints()

            if layout["main"]["orientation"] == "vertical" then
                combinedHeader:SetAttribute("columnAnchorPoint", headerColumnAnchorPoint)
                combinedHeader:SetAttribute("point", headerPoint)
                combinedHeader:SetAttribute("xOffset", 0)
                combinedHeader:SetAttribute("yOffset", unitSpacingY)
                combinedHeader:SetAttribute("columnSpacing", unitSpacingX)
                combinedHeader:SetAttribute("maxColumns", layout["main"]["maxColumns"])
            else
                combinedHeader:SetAttribute("columnAnchorPoint", headerColumnAnchorPoint)
                combinedHeader:SetAttribute("point", headerPoint)
                combinedHeader:SetAttribute("xOffset", unitSpacingX)
                combinedHeader:SetAttribute("yOffset", 0)
                combinedHeader:SetAttribute("columnSpacing", unitSpacingY)
                combinedHeader:SetAttribute("maxColumns", layout["main"]["maxColumns"])
            end

            --! force update unitbutton's point
            for _, b in ipairs(combinedHeader) do
                b:ClearAllPoints()
            end

            combinedHeader:SetAttribute("unitsPerColumn", layout["main"]["unitsPerColumn"])
            combinedHeader:SetPoint(point)

            raidFrame:SetAttribute("spacing", groupSpacing)
            raidFrame:SetAttribute("orientation", layout["main"]["orientation"])
            raidFrame:SetAttribute("anchor", layout["main"]["anchor"])
            raidFrame:SetAttribute("combineGroups", true) -- NOTE: trigger _onattributechanged to set npcFrameAnchor point!
        end

        if not which or which == "header" or which == "sort" then
            if layout["main"]["sortByRole"] then
                combinedHeader:SetAttribute("sortMethod", "NAME")
                local order = table.concat(layout["main"]["roleOrder"], ",")..",NONE"
                combinedHeader:SetAttribute("groupingOrder", order)
                combinedHeader:SetAttribute("groupBy", "ASSIGNEDROLE")
            else
                combinedHeader:SetAttribute("sortMethod", "INDEX")
                combinedHeader:SetAttribute("groupingOrder", "")
                combinedHeader:SetAttribute("groupBy", nil)
            end
        end

        if not which or which == "header" or which == "groupFilter" then
            combinedHeader:SetAttribute("groupFilter", F.TableToString(shownGroups, ","))
        end

    else
        if not which or which == "header" or which == "main-arrangement" or which == "main-size" or which == "rows_columns" or which == "groupSpacing" or which == "groupFilter" then
            for i, group in ipairs(shownGroups) do
                local header = separatedHeaders[group]
                header:ClearAllPoints()

                if layout["main"]["orientation"] == "vertical" then
                    header:SetAttribute("columnAnchorPoint", headerColumnAnchorPoint)
                    header:SetAttribute("point", headerPoint)
                    header:SetAttribute("xOffset", 0)
                    header:SetAttribute("yOffset", unitSpacing)

                    --! WotLK 3.3.5a: Manually position each button within header
                    for j = 1, 5 do
                        header[j]:ClearAllPoints()
                        if j == 1 then
                            -- First button anchors to header at same corner
                            header[j]:SetPoint(point, header, point, 0, 0)
                        else
                            -- Subsequent buttons anchor to previous button
                            header[j]:SetPoint(point, header[j-1], anchorPoint, 0, unitSpacing)
                        end
                    end
                    header:SetAttribute("unitsPerColumn", 5)

                    --! WotLK 3.3.5a: Explicitly size the header to contain all buttons
                    local width, height = unpack(layout["main"]["size"])
                    local spacingY = layout["main"]["spacingY"] or 0
                    local headerWidth = width
                    local headerHeight = height * 5 + spacingY * 4
                    P.Size(header, headerWidth, headerHeight)

                    if i == 1 then
                        header:SetPoint(point)
                    else
                        local headersPerRow = layout["main"]["maxColumns"]
                        local headerCol = i % headersPerRow
                        headerCol = headerCol == 0 and headersPerRow or headerCol

                        if headerCol == 1 then -- first column on each row
                            -- Anchor to previous row's first header
                            local prevRowHeader = separatedHeaders[shownGroups[i-headersPerRow]]
                            -- Get the last button (button 5) from that header to anchor below it
                            local lastButton = prevRowHeader[5]
                            if lastButton then
                                header:SetPoint(point, lastButton, anchorPoint, 0, unitSpacing)
                            else
                                header:SetPoint(point, prevRowHeader, 0, verticalSpacing)
                            end
                        else
                            --! WotLK 3.3.5a: Anchor to previous group's FIRST BUTTON (not header)
                            --! because headers have wrong size, but buttons have correct size
                            local prevHeader = separatedHeaders[shownGroups[i-1]]
                            local firstButton = prevHeader[1]
                            if firstButton then
                                header:SetPoint(point, firstButton, groupAnchorPoint, groupSpacing, 0)
                            else
                                header:SetPoint(point, prevHeader, groupAnchorPoint, groupSpacing, 0)
                            end
                        end
                    end
                else
                    header:SetAttribute("columnAnchorPoint", headerColumnAnchorPoint)
                    header:SetAttribute("point", headerPoint)
                    header:SetAttribute("xOffset", unitSpacing)
                    header:SetAttribute("yOffset", 0)

                    --! WotLK 3.3.5a: Manually position each button within header
                    for j = 1, 5 do
                        header[j]:ClearAllPoints()
                        if j == 1 then
                            -- First button anchors to header at same corner
                            header[j]:SetPoint(point, header, point, 0, 0)
                        else
                            -- Subsequent buttons anchor to previous button
                            header[j]:SetPoint(point, header[j-1], anchorPoint, unitSpacing, 0)
                        end
                    end
                    header:SetAttribute("unitsPerColumn", 5)

                    --! WotLK 3.3.5a: Explicitly size the header to contain all buttons (horizontal)
                    local width, height = unpack(layout["main"]["size"])
                    local spacingX = layout["main"]["spacingX"] or 0
                    local headerWidth = width * 5 + spacingX * 4
                    local headerHeight = height
                    P.Size(header, headerWidth, headerHeight)

                    if i == 1 then
                        header:SetPoint(point)
                    else
                        local headersPerCol = layout["main"]["maxColumns"]
                        local headerRow = i % headersPerCol
                        headerRow = headerRow == 0 and headersPerCol or headerRow

                        if headerRow == 1 then -- first row on each column
                            -- Anchor to previous column's first header's last button
                            local prevColHeader = separatedHeaders[shownGroups[i-headersPerCol]]
                            local lastButton = prevColHeader[5]
                            if lastButton then
                                header:SetPoint(point, lastButton, anchorPoint, unitSpacing, 0)
                            else
                                header:SetPoint(point, prevColHeader, point, horizontalSpacing, 0)
                            end
                        else
                            --! WotLK 3.3.5a: Anchor to previous group's FIRST BUTTON (not header)
                            local prevHeader = separatedHeaders[shownGroups[i-1]]
                            local firstButton = prevHeader[1]
                            if firstButton then
                                header:SetPoint(point, firstButton, groupAnchorPoint, 0, groupSpacing)
                            else
                                header:SetPoint(point, prevHeader, groupAnchorPoint, 0, groupSpacing)
                            end
                        end
                    end
                end
            end

            raidFrame:SetAttribute("spacing", groupSpacing)
            raidFrame:SetAttribute("orientation", layout["main"]["orientation"])
            raidFrame:SetAttribute("anchor", layout["main"]["anchor"])
            raidFrame:SetAttribute("combineGroups", false) -- NOTE: trigger _onattributechanged to set npcFrameAnchor point!
        end

        if not which or which == "header" or which == "sort" then
            if layout["main"]["sortByRole"] then
                for i = 1, 8 do
                    separatedHeaders[i]:SetAttribute("sortMethod", "NAME")
                    local order = table.concat(layout["main"]["roleOrder"], ",")..",NONE"
                    separatedHeaders[i]:SetAttribute("groupingOrder", order)
                    separatedHeaders[i]:SetAttribute("groupBy", "ASSIGNEDROLE")
                end
            else
                for i = 1, 8 do
                    separatedHeaders[i]:SetAttribute("sortMethod", "INDEX")
                    separatedHeaders[i]:SetAttribute("groupingOrder", "")
                    separatedHeaders[i]:SetAttribute("groupBy", nil)
                end
            end
        end

        -- show/hide groups
        if not which or which == "header" or which == "groupFilter" then
            for i = 1, 8 do
                if layout["groupFilter"][i] then
                    separatedHeaders[i]:Show()
                else
                    separatedHeaders[i]:Hide()
                end
            end
        end
    end

    -- raid pets
    if not which or strfind(which, "size$") or strfind(which, "power$") or which == "barOrientation" or which == "powerFilter" then
        local width, height = unpack(layout["main"]["size"])

        for i, arenaPet in ipairs(arenaPetButtons) do
            -- NOTE: SetOrientation BEFORE SetPowerSize
            B.SetOrientation(arenaPet, layout["barOrientation"][1], layout["barOrientation"][2])

            if layout["pet"]["sameSizeAsMain"] then
                P.Size(arenaPet, width, height)
                B.SetPowerSize(arenaPet, layout["main"]["powerSize"])
            else
                P.Size(arenaPet, layout["pet"]["size"][1], layout["pet"]["size"][2])
                B.SetPowerSize(arenaPet, layout["pet"]["powerSize"])
            end
        end
    end

    -- Debug final raid button states
    -- F.Debug("|cffff00ff=== RaidFrame Final Status ===")
    -- F.Debug("|cffff00ffRaidFrame IsVisible:|r", raidFrame:IsVisible())
    -- F.Debug("|cffff00ffCombineGroups:|r", layout["main"]["combineGroups"])

    -- if layout["main"]["combineGroups"] then
    --     F.Debug("|cffff00ffCombined Header NumButtons:|r", #combinedHeader, "|cffff00ffIsVisible:|r", combinedHeader:IsVisible())
    --     for i, b in ipairs(combinedHeader) do
    --         local unit = b:GetAttribute("unit")
    --         local isVisible = b:IsVisible()
    --         local width, height = b:GetSize()
    --         if i <= 5 then -- Only show first 5 to avoid spam
    --             F.Debug("|cffff00ffButton"..i..":|r", b:GetName(), "Unit:", unit or "NONE", "Visible:", isVisible, "Size:", width.."x"..height)
    --         end
    --     end
    -- else
    --     for groupNum = 1, 8 do
    --         local header = separatedHeaders[groupNum]
    --         if header:IsVisible() then
    --             F.Debug("|cffff00ffGroup"..groupNum.." Header NumButtons:|r", #header, "|cffff00ffIsVisible:|r", header:IsVisible())
    --             for i, b in ipairs(header) do
    --                 local unit = b:GetAttribute("unit")
    --                 local isVisible = b:IsVisible()
    --                 local width, height = b:GetSize()
    --                 F.Debug("|cffff00ffG"..groupNum.." Button"..i..":|r Unit:", unit or "NONE", "Visible:", isVisible, "Size:", width.."x"..height)
    --             end
    --         end
    --     end
    -- end
    -- F.Debug("|cffff00ff=== RaidFrame_UpdateLayout END ===")
end
Cell.RegisterCallback("UpdateLayout", "RaidFrame_UpdateLayout", RaidFrame_UpdateLayout)

-- local function RaidFrame_UpdateVisibility(which)
--     if not which or which == "raid" then
--         UpdateHeadersShowRaidAttribute()

--         if CellDB["general"]["showRaid"] then
--             RegisterAttributeDriver(raidFrame, "state-visibility", "show")
--         else
--             UnregisterAttributeDriver(raidFrame, "state-visibility")
--             raidFrame:Hide()
--         end
--     end
-- end
-- Cell.RegisterCallback("UpdateVisibility", "RaidFrame_UpdateVisibility", RaidFrame_UpdateVisibility)

-- WotLK Fix: Force update raid buttons when entering raid group type
-- The RegisterAttributeDriver visibility state doesn't always sync properly after leaving BG/raid
local function RaidFrame_GroupTypeChanged(groupType)
    if groupType == "raid" then
        -- Force update after a delay to ensure frame is visible
        C_Timer.After(1, function()
            if Cell.vars.groupType == "raid" then
                -- Force show the frame if not visible
                if not raidFrame:IsVisible() then
                    raidFrame:Show()
                end
                -- Force update all raid buttons
                for i = 1, 8 do
                    local header = separatedHeaders[i]
                    if header then
                        for j = 1, 5 do
                            local button = header[j]
                            if button and button:IsVisible() then
                                button._updateRequired = 1
                                button._powerUpdateRequired = 1
                                if button._indicatorsReady and Cell.bFuncs and Cell.bFuncs.UpdateAll then
                                    Cell.bFuncs.UpdateAll(button)
                                end
                            end
                        end
                    end
                end
                -- Also update combined header buttons
                if combinedHeader then
                    for i = 1, 40 do
                        local button = combinedHeader[i]
                        if button and button:IsVisible() then
                            button._updateRequired = 1
                            button._powerUpdateRequired = 1
                            if button._indicatorsReady and Cell.bFuncs and Cell.bFuncs.UpdateAll then
                                Cell.bFuncs.UpdateAll(button)
                            end
                        end
                    end
                end
            end
        end)
    end
end
Cell.RegisterCallback("GroupTypeChanged", "RaidFrame_GroupTypeChanged", RaidFrame_GroupTypeChanged)