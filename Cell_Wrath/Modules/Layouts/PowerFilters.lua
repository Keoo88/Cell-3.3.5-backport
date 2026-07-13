local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

local powerFilters = Cell.CreateFrame("CellOptionsFrame_PowerFilters", Cell.frames.layoutsTab, 285, 205)
Cell.frames.powerFilters = powerFilters
powerFilters:SetFrameLevel(Cell.frames.layoutsTab:GetFrameLevel() + 50)
powerFilters:SetPoint("BOTTOMRIGHT", Cell.frames.layoutsTab, "BOTTOMRIGHT", P.Scale(-5), P.Scale(5))

local selectedLayout, selectedLayoutTable

-----------------------------------------
-- power filter
-----------------------------------------
-- WotLK: Only classes available in Wrath of the Lich King
local CLASS_ROLES = {
    ["DEATHKNIGHT"] = {"TANK", "DAMAGER"},
    ["DRUID"] = {"TANK", "HEALER", "DAMAGER"},
    ["HUNTER"] = {"DAMAGER"},
    ["MAGE"] = {"DAMAGER"},
    ["PALADIN"] = {"TANK", "HEALER", "DAMAGER"},
    ["PRIEST"] = {"HEALER", "DAMAGER"},
    ["ROGUE"] = {"DAMAGER"},
    ["SHAMAN"] = {"HEALER", "DAMAGER"},
    ["WARLOCK"] = {"DAMAGER"},
    ["WARRIOR"] = {"TANK", "DAMAGER"},
    ["PET"] = {"DAMAGER"},
    ["VEHICLE"] = {"DAMAGER"},
    ["NPC"] = {"DAMAGER"},
}

local function UpdateButton(b, enabled)
    b.tex:SetDesaturated(not enabled)
    if enabled then
        b:SetBackdropColor(unpack(b.hoverColor))
        b:SetScript("OnEnter", nil)
        b:SetScript("OnLeave", nil)
    else
        b:SetBackdropColor(unpack(b.color))
        b:SetScript("OnEnter", function()
            b:SetBackdropColor(unpack(b.hoverColor))
        end)
        b:SetScript("OnLeave", function()
            b:SetBackdropColor(unpack(b.color))
        end)
    end
end

local function CreatePowerFilter(parent, class, buttons, color, bgColor)
    local filter = CreateFrame("Frame", nil, parent, nil)
    Cell.StylizeFrame(filter, color, bgColor)
    P.Size(filter, 135, 20)

    filter.text = filter:CreateFontString(nil, "OVERLAY", "CELL_WRATH_FONT_WIDGET")
    filter.text:SetPoint("LEFT", 5, 0)
    if class == "VEHICLE" or class == "PET" or class == "NPC" then
        filter.text:SetText("|cff00ff33"..L[class])
    else
        filter.text:SetText(F.GetClassColorStr(class)..F.GetLocalizedClassName(class))
    end

    filter.buttons = {}
    local last
    for i = #buttons, 1, -1 do
        local b = Cell.CreateButton(filter, nil, "accent-hover", {20, 20})
        filter.buttons[buttons[i]] = b
        b:SetTexture(F.GetDefaultRoleIcon(buttons[i]), {16, 16}, {"CENTER", 0, 0})

        if last then
            b:SetPoint("BOTTOMRIGHT", last, "BOTTOMLEFT", P.Scale(1), 0)
        else
            b:SetPoint("BOTTOMRIGHT", filter)
        end
        last = b

        b:SetScript("OnClick", function()
            local selected
            if type(selectedLayoutTable["powerFilters"][class]) == "boolean" then
                selectedLayoutTable["powerFilters"][class] = not selectedLayoutTable["powerFilters"][class]
                selected = selectedLayoutTable["powerFilters"][class]
            else
                selectedLayoutTable["powerFilters"][class][buttons[i]] = not selectedLayoutTable["powerFilters"][class][buttons[i]]
                selected = selectedLayoutTable["powerFilters"][class][buttons[i]]
            end
            UpdateButton(b, selected)
            -- update now, if selectedLayout == currentLayout
            if selectedLayout == Cell.vars.currentLayout then
                Cell.Fire("UpdateLayout", selectedLayout, "powerFilter")
            end
        end)
    end

    function filter:Load()
        if type(selectedLayoutTable["powerFilters"][class]) == "boolean" then
            UpdateButton(filter.buttons["DAMAGER"], selectedLayoutTable["powerFilters"][class])
        else
            for role, b in pairs(filter.buttons) do
                UpdateButton(b, selectedLayoutTable["powerFilters"][class][role])
            end
        end
    end

    return filter
end

-------------------------------------------------
-- filters
-------------------------------------------------
-- WotLK class filters
local dkF, druidF, hunterF, mageF, paladinF, priestF, rogueF, shamanF, warlockF, warriorF, petF, vehicleF, npcF

local function CreateFilters()
    P.Height(powerFilters, 180)

    -- Create all filters
    dkF = CreatePowerFilter(powerFilters, "DEATHKNIGHT", CLASS_ROLES["DEATHKNIGHT"])
    druidF = CreatePowerFilter(powerFilters, "DRUID", CLASS_ROLES["DRUID"])
    hunterF = CreatePowerFilter(powerFilters, "HUNTER", CLASS_ROLES["HUNTER"])
    mageF = CreatePowerFilter(powerFilters, "MAGE", CLASS_ROLES["MAGE"])
    paladinF = CreatePowerFilter(powerFilters, "PALADIN", CLASS_ROLES["PALADIN"])
    priestF = CreatePowerFilter(powerFilters, "PRIEST", CLASS_ROLES["PRIEST"])
    rogueF = CreatePowerFilter(powerFilters, "ROGUE", CLASS_ROLES["ROGUE"])
    shamanF = CreatePowerFilter(powerFilters, "SHAMAN", CLASS_ROLES["SHAMAN"])
    warlockF = CreatePowerFilter(powerFilters, "WARLOCK", CLASS_ROLES["WARLOCK"])
    warriorF = CreatePowerFilter(powerFilters, "WARRIOR", CLASS_ROLES["WARRIOR"])
    petF = CreatePowerFilter(powerFilters, "PET", CLASS_ROLES["PET"])
    vehicleF = CreatePowerFilter(powerFilters, "VEHICLE", CLASS_ROLES["VEHICLE"])
    npcF = CreatePowerFilter(powerFilters, "NPC", CLASS_ROLES["NPC"])

    -- Position filters
    dkF:SetPoint("TOPLEFT", 5, -5)
    druidF:SetPoint("TOPLEFT", 145, -5)
    hunterF:SetPoint("TOPLEFT", dkF, "BOTTOMLEFT", 0, -5)
    mageF:SetPoint("TOPLEFT", druidF, "BOTTOMLEFT", 0, -5)
    paladinF:SetPoint("TOPLEFT", hunterF, "BOTTOMLEFT", 0, -5)
    priestF:SetPoint("TOPLEFT", mageF, "BOTTOMLEFT", 0, -5)
    rogueF:SetPoint("TOPLEFT", paladinF, "BOTTOMLEFT", 0, -5)
    shamanF:SetPoint("TOPLEFT", priestF, "BOTTOMLEFT", 0, -5)
    warlockF:SetPoint("TOPLEFT", rogueF, "BOTTOMLEFT", 0, -5)
    warriorF:SetPoint("TOPLEFT", shamanF, "BOTTOMLEFT", 0, -5)
    petF:SetPoint("TOPLEFT", warlockF, "BOTTOMLEFT", 0, -5)
    vehicleF:SetPoint("TOPLEFT", warriorF, "BOTTOMLEFT", 0, -5)
    npcF:SetPoint("TOPLEFT", petF, "BOTTOMLEFT", 0, -5)
end

-------------------------------------------------
-- scripts
-------------------------------------------------
powerFilters:SetScript("OnHide", function()
    powerFilters:Hide()
    if Cell.frames.layoutsTab.mask then
        Cell.frames.layoutsTab.mask:Hide()
    end

    local powerFilterBtn = Cell.frames.layoutsTab.powerFilterBtn
    if powerFilterBtn then
        powerFilterBtn:SetFrameLevel(Cell.frames.layoutsTab:GetFrameLevel() + 1)
    end
end)

local init
function F.ShowPowerFilters(l, lt)
    selectedLayout, selectedLayoutTable = l, lt

    if not init then
        init = true
        powerFilters:UpdatePixelPerfect()
        powerFilters:SetBackdropBorderColor(unpack(Cell.GetAccentColorTable()))
        CreateFilters()
    end

    local powerFilterBtn = Cell.frames.layoutsTab.powerFilterBtn

    if powerFilters:IsShown() then
        powerFilters:Hide()
        if powerFilterBtn then
            powerFilterBtn:SetFrameLevel(Cell.frames.layoutsTab:GetFrameLevel() + 2)
        end
    else
        powerFilters:Show()
        if powerFilterBtn then
            powerFilterBtn:SetFrameLevel(Cell.frames.layoutsTab:GetFrameLevel() + 50)
        end
        if Cell.frames.layoutsTab.mask then
            Cell.frames.layoutsTab.mask:Show()
        end

        -- load db
        druidF:Load()
        hunterF:Load()
        mageF:Load()
        paladinF:Load()
        priestF:Load()
        rogueF:Load()
        shamanF:Load()
        warlockF:Load()
        warriorF:Load()
        petF:Load()
        vehicleF:Load()
        npcF:Load()

        if Cell.isRetail or Cell.isMists or Cell.isCata or Cell.isWrath then
            dkF:Load()
        end

        if Cell.isRetail or Cell.isMists then
            monkF:Load()
        end

        if Cell.isRetail then
            dhF:Load()
            evokerF:Load()
        end
    end
end

function F.HidePowerFilters()
    powerFilters:Hide()
end
