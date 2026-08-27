local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local B = Cell.bFuncs
local A = Cell.animations
local P = Cell.pixelPerfectFuncs

local tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY

local petFrame = CreateFrame("Frame", "CellPetFrame", Cell.frames.mainFrame, "SecureHandlerAttributeTemplate")
Cell.frames.petFrame = petFrame

-------------------------------------------------
-- anchor
-------------------------------------------------
local anchorFrame = CreateFrame("Frame", "CellPetAnchorFrame", petFrame, nil)
Cell.frames.petFrameAnchor = anchorFrame
anchorFrame:SetPoint("TOPLEFT", CellParent, "CENTER")
anchorFrame:SetMovable(true)
anchorFrame:SetClampedToScreen(true)
-- Cell.StylizeFrame(anchorFrame, {1, 0, 0, 0.4})

local hoverFrame = CreateFrame("Frame", nil, petFrame)
hoverFrame:SetPoint("TOP", anchorFrame, 0, 1)
hoverFrame:SetPoint("BOTTOM", anchorFrame, 0, -1)
hoverFrame:SetPoint("LEFT", anchorFrame, -1, 0)
hoverFrame:SetPoint("RIGHT", anchorFrame, 1, 0)

A.ApplyFadeInOutToMenu(anchorFrame, hoverFrame)

local dumb = Cell.CreateButton(anchorFrame, nil, "accent", {20, 10}, false, true)
dumb:Hide()
dumb:SetFrameStrata("MEDIUM")
dumb:SetAllPoints(anchorFrame)
dumb:SetScript("OnDragStart", function()
    anchorFrame:StartMoving()
    anchorFrame:SetUserPlaced(false)
end)
dumb:SetScript("OnDragStop", function()
    anchorFrame:StopMovingOrSizing()
    P.SavePosition(anchorFrame, Cell.vars.currentLayoutTable["pet"]["position"])
end)
dumb:HookScript("OnEnter", function()
    hoverFrame:GetScript("OnEnter")(hoverFrame)
    CellTooltip:SetOwner(dumb, "ANCHOR_NONE")
    CellTooltip:SetPoint(tooltipPoint, dumb, tooltipRelativePoint, tooltipX, tooltipY)
    CellTooltip:AddLine(L["Pets"])
    CellTooltip:Show()
end)
dumb:HookScript("OnLeave", function()
    hoverFrame:GetScript("OnLeave")(hoverFrame)
    CellTooltip:Hide()
end)

local CollectButtons

local function UpdateAnchor()
    -- Layout not initialized yet? Turn off mouse + hide dummy and bail.
    if not Cell.vars.currentLayoutTable
       or not Cell.vars.currentLayoutTable["pet"] then
        hoverFrame:EnableMouse(false)
        dumb:Hide()
        return
    end

    local show
    local layoutPet = Cell.vars.currentLayoutTable["pet"]

    --! The detached pet frame is a GROUP-ONLY feature (as upstream): "Detached"
    --! belongs to "Show Party/Arena Pets". A solo player's pet is rendered by
    --! SoloFrame.lua next to the player button ("Show Solo Pet"), so there is no
    --! solo clause here - see PetFrame_UpdateLayout for the full reasoning.
    if layoutPet["raidEnabled"]
       or (layoutPet["partyEnabled"] and layoutPet["partyDetached"]) then
        --! WotLK fix: the button array used to be filled exactly once at load,
        --! when the secure header has usually not created its children yet. When
        --! that happened the array stayed empty forever, pinning show to false,
        --! which is why the menu button vanished for good - hover included,
        --! since hoverFrame:EnableMouse(show) goes with it. Retry here.
        if not Cell.unitButtons.pet[1] then
            CollectButtons()
        end

        local firstPetButton = Cell.unitButtons.pet[1]
        if firstPetButton and firstPetButton:IsShown() then
            show = true
        end
    end

    hoverFrame:EnableMouse(show)
    if show then
        dumb:Show()
        if CellDB["general"]["fadeOut"] then
            if hoverFrame:IsMouseOver() then
                anchorFrame:MenuFadeIn()
            else
                --! WotLK fix: this used to reach into the animation group and
                --! call its OnFinished handler by hand, because playing the fade
                --! here does not reliably reach the end state. The fader now
                --! takes an "instant" flag for exactly that.
                anchorFrame:MenuFadeOut(true)
            end
        end
    else
        dumb:Hide()
    end
end


-------------------------------------------------
-- header
-------------------------------------------------
local header = CreateFrame("Frame", "CellPetFrameHeader", petFrame, "SecureGroupPetHeaderTemplate")
header:SetAllPoints(petFrame)

--! WotLK fix: SecureGroupPetHeader_Update reads
--! header.initialConfigFunction as a regular Lua function on 3.3.5; the retail
--! string attribute above was ignored. The _initialAttribute-* / CallMethod
--! route is not a native WotLK child-initialization mechanism either. Children
--! are configured and indexed from regular Lua when CollectButtons sees them.
local pendingPetConfiguration
local petConfigurationFrame = CreateFrame("Frame")

local function UpdatePetUnitMapping(button, unit)
    local oldUnit = button._cellPetUnit
    if oldUnit and Cell.unitButtons.pet.units[oldUnit] == button then
        Cell.unitButtons.pet.units[oldUnit] = nil
    end

    button._cellPetUnit = type(unit) == "string" and unit or nil
    if button._cellPetUnit then
        Cell.unitButtons.pet.units[button._cellPetUnit] = button
    end
end

local function ConfigurePetButton(button)
    button.isGroupPet = true
    UpdatePetUnitMapping(button, button:GetAttribute("unit"))

    if InCombatLockdown() then
        pendingPetConfiguration = true
        petConfigurationFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        button:SetAttribute("toggleForVehicle", false)
    end
end

header:SetAttribute("template", "CellUnitButtonTemplate")
header:SetAttribute("point", "TOP")
header:SetAttribute("columnAnchorPoint", "LEFT")
header:SetAttribute("unitsPerColumn", 5)
header:SetAttribute("showPlayer", true) -- show player pet while not in a raid

header:SetAttribute("maxColumns", 5)
--! make needButtons == 25
header:SetAttribute("startingIndex", -24)
header:Show()
header:SetAttribute("startingIndex", 1)

--! WotLK fix: on 3.3.5 SecureGroupHeader children are stored ONLY as the
--! "child1".."childN" attributes (header[i] array indexing is a later
--! addition), so "ipairs(header)" iterated nothing: buttons were never
--! sized (stayed 2x2 px - invisible), never got bar orientation/power size,
--! and Cell.unitButtons.pet was left empty. Collect them into the array
--! part of header once, restoring the upstream iteration contract.
--! WotLK fix: made re-runnable, and every collected button now refreshes the
--! mover when it appears or disappears. A pet button only becomes shown after
--! the secure header assigns it a unit, which happens *after* the option toggle
--! that triggered UpdateAnchor, so the old one-shot IsShown() check ran too
--! early and latched the menu button into the hidden state.
function CollectButtons()
    for i = 1, 25 do
        local b = header:GetAttribute("child" .. i) or _G["CellPetFrameHeaderUnitButton" .. i]
        if not b then break end
        header[i] = b
    end

    for i, b in ipairs(header) do
        if not Cell.unitButtons.pet[i] then
            Cell.unitButtons.pet[i] = b
            -- b.type = "pet" -- layout setup
            b:HookScript("OnShow", UpdateAnchor)
            b:HookScript("OnHide", UpdateAnchor)
            b:HookScript("OnAttributeChanged", function(self, name, value)
                if name == "unit" then
                    --! WotLK fix: keep Cell's private unit->pet-button map
                    --! synchronized when the native secure pet header recycles
                    --! a child for a different roster unit.
                    UpdatePetUnitMapping(self, value)
                end
            end)
        end
        ConfigurePetButton(b)
    end
end
CollectButtons()

petConfigurationFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_REGEN_ENABLED" then return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not pendingPetConfiguration then return end
    pendingPetConfiguration = nil

    --! WotLK fix: protected child attributes deferred during combat are
    --! completed once combat lockdown ends.
    CollectButtons()
end)

-- update mover
header:HookScript("OnShow", function()
    UpdateAnchor()
end)
header:HookScript("OnHide", function()
    UpdateAnchor()
end)

--! WotLK fix: native SecureGroupPetHeader_OnLoad (SecureTemplates.lua 3.3.5)
--! registers only PARTY_MEMBERS_CHANGED / UNIT_NAME_UPDATE / UNIT_PET.
--! Raid composition changes fire RAID_ROSTER_UPDATE, so in raids/BGs the
--! header could miss roster changes until some UNIT_PET happened to fire.
--! Route the missing event into the SAME native update path (no parallel
--! scanning) - the template's own OnEvent ignores unknown events, we hook
--! after it and call the native updater directly.
header:RegisterEvent("RAID_ROSTER_UPDATE")
header:HookScript("OnEvent", function(self, event)
    if event == "RAID_ROSTER_UPDATE" and self:IsVisible() and not InCombatLockdown() then
        SecureGroupPetHeader_Update(self)
    end
end)

-------------------------------------------------
-- functions
-------------------------------------------------
local function UpdatePosition()
    petFrame:ClearAllPoints()
    -- NOTE: detach from spotlightPreviewAnchor
    P.LoadPosition(anchorFrame, Cell.vars.currentLayoutTable["pet"]["position"])

    local anchor
    if Cell.vars.currentLayoutTable["pet"]["sameArrangementAsMain"] then
        anchor = Cell.vars.currentLayoutTable["main"]["anchor"]
    else
        anchor = Cell.vars.currentLayoutTable["pet"]["anchor"]
    end

    if CellDB["general"]["menuPosition"] == "top_bottom" then
        P.Size(anchorFrame, 20, 10)
        if anchor == "BOTTOMLEFT" then
            petFrame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 4)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPLEFT", "BOTTOMLEFT", 0, -3
        elseif anchor == "BOTTOMRIGHT" then
            petFrame:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 4)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPRIGHT", "BOTTOMRIGHT", 0, -3
        elseif anchor == "TOPLEFT" then
            petFrame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMLEFT", "TOPLEFT", 0, 3
        elseif anchor == "TOPRIGHT" then
            petFrame:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -4)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMRIGHT", "TOPRIGHT", 0, 3
        end
    else
        P.Size(anchorFrame, 10, 20)
        if anchor == "BOTTOMLEFT" then
            petFrame:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMRIGHT", 4, 0)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMRIGHT", "BOTTOMLEFT", -3, 0
        elseif anchor == "BOTTOMRIGHT" then
            petFrame:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMLEFT", -4, 0)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMLEFT", "BOTTOMRIGHT", 3, 0
        elseif anchor == "TOPLEFT" then
            petFrame:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 4, 0)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPRIGHT", "TOPLEFT", -3, 0
        elseif anchor == "TOPRIGHT" then
            petFrame:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -4, 0)
            tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPLEFT", "TOPRIGHT", 3, 0
        end
    end

    UpdateAnchor()
end

local function UpdateMenu(which)
    if not which or which == "lock" then
        if CellDB["general"]["locked"] then
            dumb:RegisterForDrag()
        else
            dumb:RegisterForDrag("LeftButton")
        end
    end

    if not which or which == "fadeOut" then
        --! WotLK fix: apply at once, see A.ApplyFadeInOutToMenu.
        if CellDB["general"]["fadeOut"] then
            anchorFrame:MenuFadeOut(true)
        else
            anchorFrame:MenuFadeIn(true)
        end
    end

    if which == "position" then
        UpdatePosition()
    end
end
Cell.RegisterCallback("UpdateMenu", "PetFrame_UpdateMenu", UpdateMenu)

local function PetFrame_UpdateLayout(layout, which)
    -- update
    layout = CellDB["layouts"][layout]

    -- visibility
    --! WotLK fix: "[@raid1,exists]" is 4.0+ macro syntax - 3.3.5's
    --! SecureCmdOptionParse only knows "target=unit", so the old driver
    --! always evaluated "hide" and the detached pet frame NEVER showed
    --! anywhere (5-man pets came from the attached party-frame path).
    if Cell.vars.isHidden then
        Cell.UnregisterAttributeDriver(petFrame, "state-visibility")
        petFrame:Hide()
        return
    end
    --! No solo clause on purpose: the driver is secure and wins over any
    --! petFrame:Hide() done from Lua, so a "[target=pet,exists] show" clause put
    --! the detached frame back on screen whenever the player was alone. With the
    --! group checkboxes off there was nothing to fill it and pet buttons carry no
    --! RegisterUnitWatch, which is where the reported empty panel while solo came
    --! from. Group-only, same as upstream.
    Cell.RegisterAttributeDriver(petFrame, "state-visibility", "[target=raid1,exists] show;[target=party1,exists] show;hide")

    if not which or strfind(which, "size$") or strfind(which, "power$") or which == "barOrientation" then
        local width, height, powerSize

        if layout["pet"]["sameSizeAsMain"] then
            width, height = unpack(layout["main"]["size"])
            powerSize = layout["main"]["powerSize"]
        else
            width, height = unpack(layout["pet"]["size"])
            powerSize = layout["pet"]["powerSize"]
        end

        P.Size(petFrame, width, height)

        -- header:SetAttribute("buttonWidth", P.Scale(width))
        -- header:SetAttribute("buttonHeight", P.Scale(height))

        for i, b in ipairs(header) do
            if not which or strfind(which, "size$") then
                P.Size(b, width, height)
            end

            -- NOTE: SetOrientation BEFORE SetPowerSize
            if not which or which == "barOrientation" then
                B.SetOrientation(b, layout["barOrientation"][1], layout["barOrientation"][2])
            end

            if not which or strfind(which, "power$") or which == "barOrientation" or which == "powerFilter" then
                B.SetPowerSize(b, powerSize)
            end
        end
    end

    if not which or strfind(which, "arrangement$") then
        local orientation, anchor, spacingX, spacingY
        if layout["pet"]["sameArrangementAsMain"] then
            orientation = layout["main"]["orientation"]
            anchor = layout["main"]["anchor"]
            spacingX = layout["main"]["spacingX"]
            spacingY = layout["main"]["spacingY"]
        else
            orientation = layout["pet"]["orientation"]
            anchor = layout["pet"]["anchor"]
            spacingX = layout["pet"]["spacingX"]
            spacingY = layout["pet"]["spacingY"]
        end

        local point, anchorPoint, unitSpacing, headerPoint, headerColumnAnchorPoint
        if orientation == "vertical" then
            -- anchor
            if anchor == "BOTTOMLEFT" then
                point, anchorPoint = "BOTTOMLEFT", "TOPLEFT"
                headerPoint, headerColumnAnchorPoint = "BOTTOM", "LEFT"
                unitSpacing = spacingY
            elseif anchor == "BOTTOMRIGHT" then
                point, anchorPoint = "BOTTOMRIGHT", "TOPRIGHT"
                headerPoint, headerColumnAnchorPoint = "BOTTOM", "RIGHT"
                unitSpacing = spacingY
            elseif anchor == "TOPLEFT" then
                point, anchorPoint = "TOPLEFT", "BOTTOMLEFT"
                headerPoint, headerColumnAnchorPoint = "TOP", "LEFT"
                unitSpacing = -spacingY
            elseif anchor == "TOPRIGHT" then
                point, anchorPoint = "TOPRIGHT", "BOTTOMRIGHT"
                headerPoint, headerColumnAnchorPoint = "TOP", "RIGHT"
                unitSpacing = -spacingY
            end

            header:SetAttribute("columnSpacing", P.Scale(spacingX))
            header:SetAttribute("xOffset", 0)
            header:SetAttribute("yOffset", P.Scale(unitSpacing))
        else
            -- anchor
            if anchor == "BOTTOMLEFT" then
                point, anchorPoint = "BOTTOMLEFT", "BOTTOMRIGHT"
                headerPoint, headerColumnAnchorPoint = "LEFT", "BOTTOM"
                unitSpacing = spacingX
            elseif anchor == "BOTTOMRIGHT" then
                point, anchorPoint = "BOTTOMRIGHT", "BOTTOMLEFT"
                headerPoint, headerColumnAnchorPoint = "RIGHT", "BOTTOM"
                unitSpacing = -spacingX
            elseif anchor == "TOPLEFT" then
                point, anchorPoint = "TOPLEFT", "TOPRIGHT"
                headerPoint, headerColumnAnchorPoint = "LEFT", "TOP"
                unitSpacing = spacingX
            elseif anchor == "TOPRIGHT" then
                point, anchorPoint = "TOPRIGHT", "TOPLEFT"
                headerPoint, headerColumnAnchorPoint = "RIGHT", "TOP"
                unitSpacing = -spacingX
            end

            header:SetAttribute("columnSpacing", P.Scale(spacingY))
            header:SetAttribute("xOffset", P.Scale(unitSpacing))
            header:SetAttribute("yOffset", 0)
        end

        -- header:ClearAllPoints()
        -- header:SetPoint(point)
        header:SetAttribute("point", headerPoint)
        header:SetAttribute("columnAnchorPoint", headerColumnAnchorPoint)

        --! force update unitbutton's point
        for i, b in ipairs(header) do
            b:ClearAllPoints()
        end
        header:SetAttribute("unitsPerColumn", 5)
        header:SetAttribute("maxColumns", 8)
    end

    if not which or strfind(which, "arrangement$") then
        UpdatePosition()
    end

    if not which or which == "pet" then
        --! There is deliberately no solo branch (upstream has none either).
        --! "Show Solo Pet" (soloEnabled) is owned by SoloFrame.lua:101, which
        --! anchors the pet button to the player button under a
        --! "[nopet] hide; [vehicleui] hide; show" driver. Driving the detached
        --! header with showSolo=true here duplicated that, and because
        --! "Detached" stays checked in the DB while its checkbox is disabled
        --! (Layouts.lua:2786 only enables it when "Show Party/Arena Pets" is on),
        --! a solo player ended up with an empty detached frame that could not be
        --! turned off from the options at all - the bug reported on 2026-07-26.
        if Cell.vars.groupType == "party" and layout["pet"]["partyEnabled"] and layout["pet"]["partyDetached"] then
            --! WotLK fix: on 3.3.5 an arena team is a PARTY (party1-4/partypet1-4),
            --! never a raid. The retail/Cata branch set showRaid=true here, but
            --! native GetGroupHeaderType (SecureTemplates.lua) requires
            --! GetNumRaidMembers() > 0 for showRaid - always 0 in arena, so the
            --! header resolved no type and showed nothing. Arena must use the
            --! same party path as regular groups.
            header:SetAttribute("showSolo", false)
            header:SetAttribute("showParty", true)
            header:SetAttribute("showRaid", false)
            petFrame:Show()
        elseif Cell.vars.groupType == "raid" and layout["pet"]["raidEnabled"] then
            --! WotLK fix: removed the "inBattleground ~= 5" guard - on 3.3.5
            --! arena is groupType "party" (never reaches this branch), while
            --! the guard's Cata semantics wrongly excluded nothing but risked
            --! hiding raid pets if inBattleground was ever 5 in a real raid.
            --! BGs (inBattleground 15/40) are raids and use this same path.
            header:SetAttribute("showSolo", false)
            header:SetAttribute("showParty", false)
            header:SetAttribute("showRaid", true)
            petFrame:Show()
        else
            header:SetAttribute("showSolo", false)
            header:SetAttribute("showParty", false)
            header:SetAttribute("showRaid", false)
            petFrame:Hide()
        end

        --! WotLK fix: nothing refreshed the mover after a pet option toggle.
        --! UpdateAnchor only ran from UpdatePosition (arrangement changes) and
        --! from the header's OnShow/OnHide, and the header itself is always
        --! shown - only petFrame is toggled - so flipping the party/raid
        --! checkboxes left the menu button in whatever state it last latched.
        UpdateAnchor()
    end
end
Cell.RegisterCallback("UpdateLayout", "PetFrame_UpdateLayout", PetFrame_UpdateLayout)
