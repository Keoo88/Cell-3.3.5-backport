local _, Cell = ...
local F = Cell.funcs
local B = Cell.bFuncs
local P = Cell.pixelPerfectFuncs

local partyFrame = CreateFrame("Frame", "CellPartyFrame", Cell.frames.mainFrame, "SecureFrameTemplate")
Cell.frames.partyFrame = partyFrame
partyFrame:SetAllPoints(Cell.frames.mainFrame)

local header = CreateFrame("Frame", "CellPartyFrameHeader", partyFrame, "SecureGroupHeaderTemplate")
header:SetAttribute("template", "CellUnitButtonTemplate")

function header:UpdateButtonUnit(bName, unit)
    if not unit then
        return
    end

    _G[bName].unit = unit -- OmniCD

    local petUnit
    if unit == "player" then
        petUnit = "pet"
    else
        petUnit = string.gsub(unit, "party", "partypet")
    end

    Cell.unitButtons.party.units[unit] = _G[bName]
    Cell.unitButtons.party.units[petUnit] = _G[bName].petButton
end

-- header:SetAttribute("initialConfigFunction", [[
--     RegisterUnitWatch(self)

--     local header = self:GetParent()
--     self:SetWidth(header:GetAttribute("buttonWidth") or 66)
--     self:SetHeight(header:GetAttribute("buttonHeight") or 46)
-- ]])

header:SetAttribute("_initialAttributeNames", "refreshUnitChange")
header:SetAttribute("_initialAttribute-refreshUnitChange", [[
    local unit = self:GetAttribute("unit")
    local header = self:GetParent()
    local petButton = self:GetFrameRef("petButton")

    -- print(self:GetName(), unit, petButton)

    if petButton and header:GetAttribute("showPartyPets") and not header:GetAttribute("partyDetached") then
        local petUnit
        if unit == "player" then
            petUnit = "pet"
        else
            petUnit = string.gsub(unit, "party", "partypet")
        end
        petButton:SetAttribute("unit", petUnit)
        RegisterUnitWatch(petButton)
    end

    header:CallMethod("UpdateButtonUnit", self:GetName(), unit)
]])

header:SetAttribute("point", "TOP")
header:SetAttribute("xOffset", 0)
header:SetAttribute("yOffset", -1)
header:SetAttribute("maxColumns", 1)
header:SetAttribute("unitsPerColumn", 5)
--! WotLK 3.3.5a: DON'T set showPlayer/showParty - they trigger auto button creation!
--! We create buttons manually below, so these must be commented out to avoid duplicate buttons
-- header:SetAttribute("showPlayer", true)
-- header:SetAttribute("showParty", true)

--! WotLK 3.3.5a: SecureGroupHeaderTemplate doesn't create buttons automatically in WotLK
--! Manually create 5 buttons for party members (player + 4 party members)
--! Store them in a separate array to prevent auto-created buttons from overwriting
local manualButtons = {}
for i = 1, 5 do
    local buttonName = "CellPartyFrameMember" .. i
    local playerButton = CreateFrame("Button", buttonName, header, "CellUnitButtonTemplate,SecureUnitButtonTemplate")
    playerButton:SetID(i)
    manualButtons[i] = playerButton  -- Store in our own array
    -- DO NOT set header[i] here - it gets overwritten by auto-created buttons!

    local unit
    if i == 1 then
        unit = "player"
    else
        unit = "party" .. (i - 1)
    end

    playerButton:SetAttribute("unit", unit)
    RegisterUnitWatch(playerButton)

    -- Create pet button
    local petButton = CreateFrame("Button", buttonName.."Pet", playerButton, "CellUnitButtonTemplate")
    petButton:SetIgnoreParentAlpha(true)
    petButton:SetAttribute("toggleForVehicle", false)

    local petUnit
    if i == 1 then
        petUnit = "pet"
    else
        petUnit = "partypet" .. (i - 1)
    end
    petButton:SetAttribute("unit", petUnit)

    playerButton.petButton = petButton
    SecureHandlerSetFrameRef(playerButton, "petButton", petButton)

    -- for IterateAllUnitButtons
    Cell.unitButtons.party["player"..i] = playerButton
    Cell.unitButtons.party["pet"..i] = petButton

    -- OmniCD
    _G[buttonName] = playerButton
end

header:SetAttribute("startingIndex", 1)
header:Show()

-- Ensure buttons know their unit attributes (OnAttributeChanged only fires on changes)
local function ForceSyncPartyButtons()
    for i = 1, 5 do
        local button = manualButtons[i]
        if button then
            local unit = button:GetAttribute("unit")
            if unit and button:GetScript("OnAttributeChanged") then
                button:GetScript("OnAttributeChanged")(button, "unit", unit)
            end

            if button.petButton then
                local petUnit = button.petButton:GetAttribute("unit")
                if petUnit and button.petButton:GetScript("OnAttributeChanged") then
                    button.petButton:GetScript("OnAttributeChanged")(button.petButton, "unit", petUnit)
                end
            end

            -- kick indicator refresh if ready
            button._updateRequired = 1
            button._powerUpdateRequired = 1
            if Cell.bFuncs and Cell.bFuncs.UpdateAll then
                Cell.bFuncs.UpdateAll(button)
            end
        end
    end
end

-- Manually trigger UpdateButtonUnit for each button to populate Cell.unitButtons.party.units
C_Timer.After(0.1, function()
    if not header.UpdateButtonUnit then return end
    for i = 1, 5 do
        local button = manualButtons[i]
        if button then
            local unit = button:GetAttribute("unit")
            if unit then
                header:UpdateButtonUnit(button:GetName(), unit)
            end
        end
    end
    ForceSyncPartyButtons()
end)

-- Trigger layout update after button creation
-- NOTE: This ensures buttons are sized correctly after initial load
C_Timer.After(0.5, function()
    if Cell and F and F.UpdateLayout and (Cell.vars.groupType == "party" or Cell.vars.groupType == "solo") then
        F.UpdateLayout(Cell.vars.groupType)
    end
end)

local function PartyFrame_UpdateLayout(layout, which)
    -- visibility
    if Cell.vars.groupType ~= "party" or Cell.vars.isHidden then
        UnregisterAttributeDriver(partyFrame, "state-visibility")
        partyFrame:Hide()
        return
    else
        --! WotLK 3.3.5a: Simplified visibility driver - just show when groupType is party
        RegisterAttributeDriver(partyFrame, "state-visibility", "show")
        partyFrame:Show()  --! WotLK 3.3.5a: Must explicitly call Show()
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

    --! WotLK 3.3.5a: Re-register buttons with unit watch when layout updates
    if not which then
        for i = 1, 5 do
            if manualButtons[i] then
                local unit = manualButtons[i]:GetAttribute("unit")
                if unit then
                    -- Re-register unit watch to ensure button visibility
                    RegisterUnitWatch(manualButtons[i])
                    -- Update button unit registration
                    if header.UpdateButtonUnit then
                        header:UpdateButtonUnit(manualButtons[i]:GetName(), unit)
                    end
                end
            end
        end
        ForceSyncPartyButtons()
    end

    -- anchor
    if not which or which == "main-arrangement" or which == "pet-arrangement" then
        local orientation = layout["main"]["orientation"]
        local anchor = layout["main"]["anchor"]
        local spacingX = layout["main"]["spacingX"]
        local spacingY = layout["main"]["spacingY"]
        local petSpacingX = layout["pet"]["sameArrangementAsMain"] and spacingX or layout["pet"]["spacingX"]
        local petSpacingY = layout["pet"]["sameArrangementAsMain"] and spacingY or layout["pet"]["spacingY"]

        local point, playerAnchorPoint, petAnchorPoint, playerSpacing, petSpacing, headerPoint
        if orientation == "vertical" then
            if anchor == "BOTTOMLEFT" then
                point, playerAnchorPoint, petAnchorPoint = "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT"
                headerPoint = "BOTTOM"
                playerSpacing = spacingY
                petSpacing = petSpacingX
            elseif anchor == "BOTTOMRIGHT" then
                point, playerAnchorPoint, petAnchorPoint = "BOTTOMRIGHT", "TOPRIGHT", "BOTTOMLEFT"
                headerPoint = "BOTTOM"
                playerSpacing = spacingY
                petSpacing = -petSpacingX
            elseif anchor == "TOPLEFT" then
                point, playerAnchorPoint, petAnchorPoint = "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT"
                headerPoint = "TOP"
                playerSpacing = -spacingY
                petSpacing = petSpacingX
            elseif anchor == "TOPRIGHT" then
                point, playerAnchorPoint, petAnchorPoint = "TOPRIGHT", "BOTTOMRIGHT", "TOPLEFT"
                headerPoint = "TOP"
                playerSpacing = -spacingY
                petSpacing = -petSpacingX
            end

            header:SetAttribute("xOffset", 0)
            header:SetAttribute("yOffset", P.Scale(playerSpacing))
        else
            -- anchor
            if anchor == "BOTTOMLEFT" then
                point, playerAnchorPoint, petAnchorPoint = "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT"
                headerPoint = "LEFT"
                playerSpacing = spacingX
                petSpacing = petSpacingY
            elseif anchor == "BOTTOMRIGHT" then
                point, playerAnchorPoint, petAnchorPoint = "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT"
                headerPoint = "RIGHT"
                playerSpacing = -spacingX
                petSpacing = petSpacingY
            elseif anchor == "TOPLEFT" then
                point, playerAnchorPoint, petAnchorPoint = "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT"
                headerPoint = "LEFT"
                playerSpacing = spacingX
                petSpacing = -petSpacingY
            elseif anchor == "TOPRIGHT" then
                point, playerAnchorPoint, petAnchorPoint = "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT"
                headerPoint = "RIGHT"
                playerSpacing = -spacingX
                petSpacing = -petSpacingY
            end

            header:SetAttribute("xOffset", P.Scale(playerSpacing))
            header:SetAttribute("yOffset", 0)
        end

        header:ClearAllPoints()
        header:SetPoint(point)
        header:SetAttribute("point", headerPoint)

        --! WotLK 3.3.5a: SecureGroupHeaderTemplate doesn't position buttons automatically in WotLK
        --! Manually position each button
        for j = 1, 5 do
            if manualButtons[j] then
                manualButtons[j]:ClearAllPoints()

                if j == 1 then
                    -- First button anchors its corner to header
                    manualButtons[j]:SetPoint(point, header, headerPoint, 0, 0)
                else
                    -- Subsequent buttons anchor to previous button
                    if orientation == "vertical" then
                        manualButtons[j]:SetPoint(point, manualButtons[j-1], playerAnchorPoint, 0, P.Scale(playerSpacing))
                    else
                        manualButtons[j]:SetPoint(point, manualButtons[j-1], playerAnchorPoint, P.Scale(playerSpacing), 0)
                    end
                end

                -- Position pet button
                if manualButtons[j].petButton then
                    manualButtons[j].petButton:ClearAllPoints()
                    if orientation == "vertical" then
                        manualButtons[j].petButton:SetPoint(point, manualButtons[j], petAnchorPoint, P.Scale(petSpacing), 0)
                    else
                        manualButtons[j].petButton:SetPoint(point, manualButtons[j], petAnchorPoint, 0, P.Scale(petSpacing))
                    end
                end
            end
        end

        header:SetAttribute("unitsPerColumn", 5)
    end

    if not which or strfind(which, "size$") or strfind(which, "power$") or which == "barOrientation" or which == "powerFilter" then
        for i, playerButton in ipairs(manualButtons) do
            local petButton = playerButton.petButton

            if not which or strfind(which, "size$") then
                local width, height = unpack(layout["main"]["size"])
                P.Size(playerButton, width, height)
                header:SetAttribute("buttonWidth", P.Scale(width))
                header:SetAttribute("buttonHeight", P.Scale(height))

                -- Debug actual button size
                -- local actualWidth, actualHeight = playerButton:GetSize()
                -- F.Debug("|cffff8800Button"..i.." - Actual size after P.Size:|r", actualWidth, "x", actualHeight)

                if layout["pet"]["sameSizeAsMain"] then
                    P.Size(petButton, width, height)
                else
                    P.Size(petButton, layout["pet"]["size"][1], layout["pet"]["size"][2])
                end
            end

            -- NOTE: SetOrientation BEFORE SetPowerSize
            if not which or which == "barOrientation" then
                B.SetOrientation(playerButton, layout["barOrientation"][1], layout["barOrientation"][2])
                B.SetOrientation(petButton, layout["barOrientation"][1], layout["barOrientation"][2])
            end

            if not which or strfind(which, "power$") or which == "barOrientation" or which == "powerFilter" then
                B.SetPowerSize(playerButton, layout["main"]["powerSize"])
                if layout["pet"]["sameSizeAsMain"] then
                    B.SetPowerSize(petButton, layout["main"]["powerSize"])
                else
                    B.SetPowerSize(petButton, layout["pet"]["powerSize"])
                end
            end
        end
    end

    if not which or which == "pet" then
        header:SetAttribute("showPartyPets", layout["pet"]["partyEnabled"])
        header:SetAttribute("partyDetached", layout["pet"]["partyDetached"])
        if layout["pet"]["partyEnabled"] and not layout["pet"]["partyDetached"] then
            for i, playerButton in ipairs(manualButtons) do
                RegisterUnitWatch(playerButton.petButton)
            end
        else
            for i, playerButton in ipairs(manualButtons) do
                UnregisterUnitWatch(playerButton.petButton)
                playerButton.petButton:Hide()
            end
        end
    end

    if not which or which == "sort" then
        if layout["main"]["sortByRole"] then
            header:SetAttribute("sortMethod", "NAME")
            local order = table.concat(layout["main"]["roleOrder"], ",")..",NONE"
            header:SetAttribute("groupingOrder", order)
            header:SetAttribute("groupBy", "ASSIGNEDROLE")
        else
            header:SetAttribute("sortMethod", "INDEX")
            header:SetAttribute("groupingOrder", "")
            header:SetAttribute("groupBy", nil)
        end
    end

    if not which or which == "hideSelf" then
        --! WotLK 3.3.5a: Don't use showPlayer attribute - it triggers auto button creation
        --! Instead, manually show/hide the first button (player button)
        if layout["main"]["hideSelf"] then
            manualButtons[1]:Hide()
        else
            manualButtons[1]:Show()
        end
    end

    -- Debug final button states
    -- F.Debug("|cffff8800=== PartyFrame Button Status ===")
    -- F.Debug("|cffff8800Header IsVisible:|r", header:IsVisible(), "|cffff8800PartyFrame IsVisible:|r", partyFrame:IsVisible())
    -- for i, playerButton in ipairs(header) do
    --     local unit = playerButton:GetAttribute("unit")
    --     local isVisible = playerButton:IsVisible()
    --     local isShown = playerButton:IsShown()
    --     local width, height = playerButton:GetSize()
    --     F.Debug("|cffff8800Button"..i..":|r Unit:", unit or "NONE", "IsVisible:", isVisible, "IsShown:", isShown, "Size:", width.."x"..height)
    -- end
    -- F.Debug("|cffff8800=== PartyFrame_UpdateLayout END ===")
end
Cell.RegisterCallback("UpdateLayout", "PartyFrame_UpdateLayout", PartyFrame_UpdateLayout)

-- local function PartyFrame_UpdateVisibility(which)
--     if not which or which == "party" then
--         header:SetAttribute("showParty", CellDB["general"]["showParty"])
--         if CellDB["general"]["showParty"] then
--             --! [group] won't fire during combat
--             -- RegisterAttributeDriver(partyFrame, "state-visibility", "[group:raid] hide; [group:party] show; hide")
--             -- NOTE: [group:party] show: fix for premade, only player in party, but party1 not exists
--             RegisterAttributeDriver(partyFrame, "state-visibility", "[@raid1,exists] hide;[@party1,exists] show;[group:party] show;hide")
--         else
--             UnregisterAttributeDriver(partyFrame, "state-visibility")
--             partyFrame:Hide()
--         end
--     end
-- end
-- Cell.RegisterCallback("UpdateVisibility", "PartyFrame_UpdateVisibility", PartyFrame_UpdateVisibility)

-- local f = CreateFrame("Frame", nil, CellParent, "SecureFrameTemplate")
-- RegisterAttributeDriver(f, "state-group", "[@raid1,exists] raid;[@party1,exists] party; solo")
-- SecureHandlerWrapScript(f, "OnAttributeChanged", f, [[
--     print(name, value)
--     if name ~= "state-group" then return end
-- ]])

-- RegisterStateDriver(f, "groupstate", "[group:raid] raid; [group:party] party; solo")
-- f:SetAttribute("_onstate-groupstate", [[
--     print(stateid, newstate)
-- ]])

-- WotLK Fix: Force update party buttons when entering party group type
-- The RegisterAttributeDriver visibility state doesn't always sync properly after leaving BG/raid
local function PartyFrame_GroupTypeChanged(groupType)
    if groupType == "party" then
        -- Force update after a delay to ensure frame is visible
        C_Timer.After(0.5, function()
            if Cell.vars.groupType == "party" then
                -- Force show the frame if not visible
                if not partyFrame:IsVisible() then
                    partyFrame:Show()
                end
                -- Force update all party buttons
                for i = 1, 5 do
                    local button = manualButtons[i]
                    if button then
                        if button:IsVisible() then
                            button._updateRequired = 1
                            button._powerUpdateRequired = 1
                            if button._indicatorsReady and Cell.bFuncs and Cell.bFuncs.UpdateAll then
                                Cell.bFuncs.UpdateAll(button)
                            end
                        end
                        -- Also update pet button
                        if button.petButton and button.petButton:IsVisible() then
                            button.petButton._updateRequired = 1
                            button.petButton._powerUpdateRequired = 1
                            if button.petButton._indicatorsReady and Cell.bFuncs and Cell.bFuncs.UpdateAll then
                                Cell.bFuncs.UpdateAll(button.petButton)
                            end
                        end
                    end
                end
                -- Ensure unit attributes are synced and buttons refresh even if they never received OnAttributeChanged
                ForceSyncPartyButtons()
            end
        end)
    end
end
Cell.RegisterCallback("GroupTypeChanged", "PartyFrame_GroupTypeChanged", PartyFrame_GroupTypeChanged)
