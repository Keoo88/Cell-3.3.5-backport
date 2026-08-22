local _, Cell = ...
--! WotLK fix: bind Cell pixel math privately so standalone !!!ClassicAPI cannot change layout semantics.
local PixelUtil = Cell.PixelUtil
local L = Cell.L
local F = Cell.funcs
local B = Cell.bFuncs
local A = Cell.animations
local P = Cell.pixelPerfectFuncs

local npcFrame = CreateFrame("Frame", "CellNPCFrame", Cell.frames.mainFrame, "SecureHandlerStateTemplate")
Cell.frames.npcFrame = npcFrame
-- Cell.StylizeFrame(npcFrame, {1, 0.5, 0.5})

--! WotLK fix: SecureStateDriver evaluates every registered condition 5 times per
--! second. Keep the two CellNPCFrame drivers alive only while NPC frames are
--! enabled and attached to the group frames; separate/disabled/hidden layouts do
--! not consume their state and must not leave the pollers running.
local npcStateDriversEnabled
local function SetNPCStateDriversEnabled(enabled)
    enabled = enabled and true or false
    if npcStateDriversEnabled == enabled then return end
    npcStateDriversEnabled = enabled

    if enabled then
        RegisterStateDriver(npcFrame, "groupstate", "[@raid1,exists] raid;[@party1,exists] party;solo")
        RegisterStateDriver(npcFrame, "petstate", "[@pet,exists] pet; [@partypet1,exists] pet1; [@partypet2,exists] pet2; [@partypet3,exists] pet3; [@partypet4,exists] pet4; nopet")
    else
        UnregisterStateDriver(npcFrame, "groupstate")
        UnregisterStateDriver(npcFrame, "petstate")
    end
end

--! WotLK fix: PartyFrame.lua creates fixed manual buttons named
--! CellPartyFrameMember1/CellPartyFrameMember1Pet. The retail header-child
--! globals never exist in this backport, leaving the NPC party frame reference
--! nil and breaking attached NPC positioning. Resolve Cell-owned buttons after
--! PartyFrame has loaded and keep the secure reference in sync out of combat.
local anchors = {
    ["solo"] = CellSoloFramePlayer,
    ["party"] = Cell.unitButtons.party["pet1"],
    ["raid"] = CellNPCFrameAnchor,
}

for k, v in pairs(anchors) do
    if v then
        npcFrame:SetFrameRef(k, v)
    end
end

local pendingPartyAnchor
local partyAnchorFrame = CreateFrame("Frame")
local function UpdatePartyAnchor(layout)
    local party = Cell.unitButtons.party["player1"]
    local petParty = Cell.unitButtons.party["pet1"]
    local usePet = layout["pet"]["partyEnabled"]
        and not layout["pet"]["partyDetached"]
    local anchor = usePet and petParty or party

    if not anchor then return end
    anchors["party"] = anchor

    if InCombatLockdown() then
        pendingPartyAnchor = anchor
        partyAnchorFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        pendingPartyAnchor = nil
        npcFrame:SetFrameRef("party", anchor)
    end
end

partyAnchorFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_REGEN_ENABLED" then return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pendingPartyAnchor then
        --! WotLK fix: secure frame references cannot be changed during combat;
        --! apply the most recent party/pet anchor as soon as lockdown ends.
        npcFrame:SetFrameRef("party", pendingPartyAnchor)
        pendingPartyAnchor = nil
    end
end)


-------------------------------------------------
-- separateAnchor
-------------------------------------------------
local tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY

local separateAnchor = CreateFrame("Frame", "CellSeparateNPCFrameAnchor", Cell.frames.mainFrame, nil)
Cell.frames.separateNpcFrameAnchor = separateAnchor
separateAnchor:SetMovable(true)
separateAnchor:SetClampedToScreen(true)
P.Size(separateAnchor, 20, 10)
PixelUtil.SetPoint(separateAnchor, "TOPLEFT", CellParent, "CENTER", 1, -1)
-- Cell.StylizeFrame(separateAnchor, {0, 1, 0, 0.4})

local hoverFrame = CreateFrame("Frame", nil, npcFrame)
hoverFrame:SetPoint("TOP", separateAnchor, 0, 1)
hoverFrame:SetPoint("BOTTOM", separateAnchor, 0, -1)
hoverFrame:SetPoint("LEFT", separateAnchor, -1, 0)
hoverFrame:SetPoint("RIGHT", separateAnchor, 1, 0)

A.ApplyFadeInOutToMenu(separateAnchor, hoverFrame)

local dumb = Cell.CreateButton(separateAnchor, nil, "accent", {20, 10}, false, true)
dumb:Hide()
dumb:SetFrameStrata("MEDIUM")
dumb:SetAllPoints(separateAnchor)
dumb:SetScript("OnDragStart", function()
    separateAnchor:StartMoving()
    separateAnchor:SetUserPlaced(false)
end)
dumb:SetScript("OnDragStop", function()
    separateAnchor:StopMovingOrSizing()
    P.SavePosition(separateAnchor, Cell.vars.currentLayoutTable["npc"]["position"])
end)
dumb:HookScript("OnEnter", function()
    hoverFrame:GetScript("OnEnter")(hoverFrame)
    CellTooltip:SetOwner(dumb, "ANCHOR_NONE")
    CellTooltip:SetPoint(tooltipPoint, dumb, tooltipRelativePoint, tooltipX, tooltipY)
    CellTooltip:AddLine(L["Friendly NPC Frame"])
    CellTooltip:Show()
end)
dumb:HookScript("OnLeave", function()
    hoverFrame:GetScript("OnLeave")(hoverFrame)
    CellTooltip:Hide()
end)

function npcFrame:UpdateSeparateAnchor()
    local show
    if Cell.vars.currentLayoutTable["npc"]["separate"] then
        for _, b in ipairs(Cell.unitButtons.npc) do
            show = b:IsShown()
            if show then break end
        end
    end

    hoverFrame:EnableMouse(show)
    if show then
        dumb:Show()
        if CellDB["general"]["fadeOut"] then
            if hoverFrame:IsMouseOver() then
                separateAnchor.fadeIn:Play()
            else
                separateAnchor.fadeOut:GetScript("OnFinished")(separateAnchor.fadeOut)
            end
        end
    else
        dumb:Hide()
    end
end

-------------------------------------------------
-- NOTE: update each npc unit button
-------------------------------------------------
local pointUpdater = [[
    local orientation, point, anchorPoint, unitSpacing = ...
    -- print(orientation, point, anchorPoint, unitSpacing)
    local last
    for i = 1, 8 do
        local button = self:GetFrameRef("button"..i)
        button:ClearAllPoints()
        if button:IsVisible() then
            if last then
                -- NOTE: anchor to last
                if orientation == "vertical" then
                    button:SetPoint(point, last, anchorPoint, 0, unitSpacing)
                else
                    button:SetPoint(point, last, anchorPoint, unitSpacing, 0)
                end
            else
                button:SetPoint("TOPLEFT", self)
            end
            last = button
        end
    end

    --! WotLK fix: control:CallMethod exists on 3.3.5, but this shared snippet
    --! only owns secure re-anchoring; UpdateSeparateAnchor stays in regular Lua.
]]
npcFrame:SetAttribute("pointUpdater", pointUpdater)

-------------------------------------------------
-- create buttons
-------------------------------------------------
for i = 1, 8 do
    local button = CreateFrame("Button", npcFrame:GetName().."Button"..i, npcFrame, "CellUnitButtonTemplate")
    tinsert(Cell.unitButtons.npc, button)
    -- button.type = "npc" -- layout setup

    -- upstream r274: register boss units only while their button is shown,
    -- otherwise npc.units permanently lists all 8 boss buttons and consumers
    -- (LibGetFrame, glows) resolve frames for non-existent bosses
    button:HookScript("OnShow", function()
        Cell.unitButtons.npc.units["boss"..i] = button
    end)
    button:HookScript("OnHide", function()
        Cell.unitButtons.npc.units["boss"..i] = nil
    end)

    button:SetAttribute("unit", "boss"..i)
    -- button:SetAttribute("unit", "player")
    -- for testing ------------------------------
    -- if i == 1 then
    --     button:SetAttribute("unit", "target")
    --     RegisterUnitWatch(button)
    -- end
    -- if i == 7 then
    --     button:SetAttribute("unit", "player")
    --     RegisterUnitWatch(button)
    -- elseif i == 2 then
    --     button:SetAttribute("unit", "target")
    --     Cell.RegisterAttributeDriver(button, "state-visibility", "[@target, exists] show; hide")
    -- elseif i == 4 then
    --     button:SetAttribute("unit", "target")
    --     Cell.RegisterAttributeDriver(button, "state-visibility", "[@target, help] show; hide")
    -- elseif i == 6 then
    --     button:SetAttribute("unit", "target")
    --     Cell.RegisterAttributeDriver(button, "state-visibility", "[@target, harm] show; hide")
    -- end

    -- if i >= 6 then
    --     Cell.UnregisterAttributeDriver(button, "state-visibility")
    --     button:SetAttribute("unit", "target")
    --     RegisterUnitWatch(button)

    --     local bar = Cell.CreateStatusBar(nil, button, 10, 5, 1, false, nil, nil, Cell.vars.whiteTexture, {1, 1, 1, 1})
    --     bar:SetFrameLevel(button.widgets.healthBar:GetFrameLevel() + 1)
    --     bar.border:Hide()

    --     bar:SetPoint("BOTTOMLEFT", button.widgets.healthBar)
    --     bar:SetPoint("BOTTOMRIGHT", button.widgets.healthBar)
    --     bar:SetScript("OnUpdate", function()
    --         local health = UnitHealth("boss"..i)
    --         local healthMax = UnitHealthMax("boss"..i)
    --         bar:SetValue(health / healthMax)
    --     end)
    -- end
    ---------------------------------------------

    -- NOTE: save reference for re-point
    npcFrame:SetFrameRef("button"..i, button)

    -- NOTE: update each npc unitbutton's point on show/hide
    button.helper = CreateFrame("Frame", nil, button, "SecureHandlerShowHideTemplate")
    button.helper:SetFrameRef("npcFrame", npcFrame)
    button.helper:SetAttribute("pointUpdater", [[
        local orientation = self:GetAttribute("orientation")
        local point = self:GetAttribute("point")
        local anchorPoint = self:GetAttribute("anchorPoint")
        local unitSpacing = self:GetAttribute("unitSpacing")

        local npcFrame = self:GetFrameRef("npcFrame")
        local last
        for i = 1, 8 do
            local button = npcFrame:GetFrameRef("button"..i)
            if button then
                button:ClearAllPoints()
                if button:IsVisible() then
                    if last then
                        if orientation == "vertical" then
                            button:SetPoint(point, last, anchorPoint, 0, unitSpacing)
                        else
                            button:SetPoint(point, last, anchorPoint, unitSpacing, 0)
                        end
                    else
                        button:SetPoint("TOPLEFT", npcFrame)
                    end
                    last = button
                end
            end
        end
    ]])
    --! WotLK fix: RunAttribute is a native 3.3.5 control-handle method.
    --! Keep one restricted re-anchor body instead of compiling two duplicate
    --! loops per boss button for _onshow and _onhide.
    button.helper:SetAttribute("_onshow", [[
        control:RunAttribute("pointUpdater")
    ]])
    button.helper:SetAttribute("_onhide", [[
        control:RunAttribute("pointUpdater")
    ]])
end

-------------------------------------------------
-- FIXME: fix health updating boss678
-- ! BLIZZARD, FIX IT!
-------------------------------------------------
local boss678_guidToButton = {}
local boss678_buttonToGuid = {}

local cleu = CreateFrame("Frame")
--! WotLK perf: named parameters instead of `...` plus an eight-slot vararg unpack -
--! in Lua 5.1 a vararg function pays adjust_varargs and a VARARG copy on every
--! call, and this frame is registered for COMBAT_LOG_EVENT_UNFILTERED while any
--! boss-678 frame is visible. The GUID-gate lookup now also runs before the
--! subEvent chain, which is the cheapest possible rejection.
cleu:SetScript("OnEvent", function(self, event,
    timestamp, subEvent, sourceGUID, sourceName, sourceFlags,
    destGUID, destName, destFlags)

    --! WotLK fix: native 3.3.5 CLEU has no hideCaster or raid-flag slots.
    --! Parse it directly so boss health/aura updates are independent of the
    --! global ClassicAPI translator selected by addon load order.
    if boss678_guidToButton[destGUID] then
        if subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" or subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
            -- print("UpdateHealth:", boss678_guidToButton[destGUID]:GetName())
            B.UpdateHealth(boss678_guidToButton[destGUID])
        elseif subEvent == "SPELL_AURA_REFRESH" or subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REMOVED" or subEvent == "SPELL_AURA_APPLIED_DOSE" or subEvent == "SPELL_AURA_REMOVED_DOSE" then
            B.UpdateAuras(boss678_guidToButton[destGUID])
        end
    end
end)

for i = 6, 8 do
    local button = Cell.unitButtons.npc[i]
    button.helper:HookScript("OnShow", function()
        local guid = UnitGUID(button.states.unit)
        if not guid then return end

        boss678_buttonToGuid[i] = guid
        boss678_guidToButton[guid] = button

        -- update now
        B.UpdateAll(button)
    end)

    button.helper:HookScript("OnHide", function()
        boss678_guidToButton[boss678_buttonToGuid[i] or ""] = nil
        boss678_buttonToGuid[i] = nil

        button.helper.elapsed = nil
        button.helper.elapsed2 = nil
        button.helper.elapsed3 = nil

        if F.Getn(boss678_buttonToGuid) == 0 then
            cleu:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        end
    end)

    button.helper:HookScript("OnUpdate", function(self, elapsed)
        button.helper.elapsed = (button.helper.elapsed or 0) + elapsed
        button.helper.elapsed2 = (button.helper.elapsed2 or 0) + elapsed
        button.helper.elapsed3 = (button.helper.elapsed3 or 0) + elapsed

        if button.helper.elapsed >= 0.25 then
            local guid = UnitGUID(button.states.unit)
            -- check old guid
            if guid and boss678_buttonToGuid[i] ~= guid then --! unit changed
                -- remove old
                boss678_guidToButton[boss678_buttonToGuid[i] or ""] = nil
                -- add new
                boss678_buttonToGuid[i] = guid
                boss678_guidToButton[guid] = button
                -- update now
                B.UpdateAll(button)
            end
            button.helper.elapsed = 0
        end

        if button.helper.elapsed2 >= 1 then
            if not cleu:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED") then
                cleu:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            end
            button.helper.elapsed2 = 0
        end

        if button.helper.elapsed3 >= 5 then
            --! WotLK fix/perf: max-health refresh already snapshots current health;
            --! repaint from that snapshot instead of querying both values twice.
            B.UpdateHealthMax(button)
            B.UpdateHealth(button, nil, true)
            button.helper.elapsed3 = 0
        end
    end)
end

-------------------------------------------------
-- update point when group type changed
-------------------------------------------------
npcFrame:SetAttribute("_onstate-groupstate", [[
    -- print("groupstate", newstate)
    self:SetAttribute("group", newstate)

    local petstate = self:GetAttribute("pet")
    local anchor = self:GetFrameRef(newstate)
    local orientation = self:GetAttribute("orientation")
    local point = self:GetAttribute("point")
    local anchorPoint = self:GetAttribute("anchorPoint")
    local groupAnchorPoint = self:GetAttribute("groupAnchorPoint")
    local unitSpacing = self:GetAttribute("unitSpacing")
    local groupSpacing = self:GetAttribute("groupSpacing")

    self:ClearAllPoints()

    if orientation == "vertical" then
        if newstate == "raid" then
            self:SetPoint(point, anchor)

        elseif newstate == "party" then
            -- NOTE: at first time petstate == nil
            if petstate == "nopet" then
                self:SetPoint(point, self:GetFrameRef("solo"), groupAnchorPoint, groupSpacing, 0)
            else
                self:SetPoint(point, self:GetFrameRef("party"), groupAnchorPoint, groupSpacing, 0)
            end

        else -- solo
            self:SetPoint(point, anchor, groupAnchorPoint, groupSpacing, 0)
        end
    else
        if newstate == "raid" then
            self:SetPoint(point, anchor)

        elseif newstate == "party" then
            -- NOTE: at first time petstate == nil
            if petstate == "nopet" then
                self:SetPoint(point, self:GetFrameRef("solo"), groupAnchorPoint, 0, groupSpacing)
            else
                self:SetPoint(point, self:GetFrameRef("party"), groupAnchorPoint, 0, groupSpacing)
            end

        else -- solo
            self:SetPoint(point, anchor, groupAnchorPoint, 0, groupSpacing)
        end
    end

    -- NOTE: update each npc button
    --! WotLK fix: RunAttribute exists on 3.3.5's control handle, but this state
    --! snippet already owns the required values locally, so keep one direct pass.
    local last
    for i = 1, 8 do
        local button = self:GetFrameRef("button"..i)
        button:ClearAllPoints()
        if button:IsVisible() then
            if last then
                -- NOTE: anchor to last
                if orientation == "vertical" then
                    button:SetPoint(point, last, anchorPoint, 0, unitSpacing)
                else
                    button:SetPoint(point, last, anchorPoint, unitSpacing, 0)
                end
            else
                button:SetPoint("TOPLEFT", self)
            end
            last = button
        end
    end

    --! WotLK fix: control:CallMethod exists on 3.3.5, but this shared snippet
    --! only owns secure re-anchoring; UpdateSeparateAnchor stays in regular Lua.
]])

-------------------------------------------------
-- update point when pet state changed
-------------------------------------------------
npcFrame:SetAttribute("_onstate-petstate", [[
    -- print("petstate", newstate)
    self:SetAttribute("pet", newstate)

    if self:GetAttribute("group") == "party" then
        local orientation = self:GetAttribute("orientation")
        local point = self:GetAttribute("point")
        local anchorPoint = self:GetAttribute("anchorPoint")
        local groupAnchorPoint = self:GetAttribute("groupAnchorPoint")
        local unitSpacing = self:GetAttribute("unitSpacing")
        local groupSpacing = self:GetAttribute("groupSpacing")

        self:ClearAllPoints()

        if orientation == "vertical" then
            if newstate == "nopet" then
                self:SetPoint(point, self:GetFrameRef("solo"), groupAnchorPoint, groupSpacing, 0)
            else
                self:SetPoint(point, self:GetFrameRef("party"), groupAnchorPoint, groupSpacing, 0)
            end
        else
            if newstate == "nopet" then
                self:SetPoint(point, self:GetFrameRef("solo"), groupAnchorPoint, 0, groupSpacing)
            else
                self:SetPoint(point, self:GetFrameRef("party"), groupAnchorPoint, 0, groupSpacing)
            end
        end
    end
]])
-- RegisterStateDriver(npcFrame, "petstate", "[@pet,exists] pet; [@partypet1,exists] pet1; [@partypet2,exists] pet2; [@partypet3,exists] pet3; [@partypet4,exists] pet4; nopet")

-------------------------------------------------
-- functions
-------------------------------------------------
local function UpdatePosition()
    local layout = Cell.vars.currentLayoutTable

    -- update npcFrame anchor if separate from main
    if layout["npc"]["separate"] then
        npcFrame:ClearAllPoints()
        P.LoadPosition(separateAnchor, layout["npc"]["position"])

        local anchor
        if layout["pet"]["sameArrangementAsMain"] then
            anchor = layout["main"]["anchor"]
        else
            anchor = layout["npc"]["anchor"]
        end

        if CellDB["general"]["menuPosition"] == "top_bottom" then
            P.Size(separateAnchor, 20, 10)
            if anchor == "BOTTOMLEFT" then
                npcFrame:SetPoint("BOTTOMLEFT", separateAnchor, "TOPLEFT", 0, 4)
                tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPLEFT", "BOTTOMLEFT", 0, -3
            elseif anchor == "BOTTOMRIGHT" then
                npcFrame:SetPoint("BOTTOMRIGHT", separateAnchor, "TOPRIGHT", 0, 4)
                tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPRIGHT", "BOTTOMRIGHT", 0, -3
            elseif anchor == "TOPLEFT" then
                npcFrame:SetPoint("TOPLEFT", separateAnchor, "BOTTOMLEFT", 0, -4)
                tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMLEFT", "TOPLEFT", 0, 3
            elseif anchor == "TOPRIGHT" then
                npcFrame:SetPoint("TOPRIGHT", separateAnchor, "BOTTOMRIGHT", 0, -4)
                tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMRIGHT", "TOPRIGHT", 0, 3
            end
        else
            P.Size(separateAnchor, 10, 20)
            if anchor == "BOTTOMLEFT" then
                npcFrame:SetPoint("BOTTOMLEFT", separateAnchor, "BOTTOMRIGHT", 4, 0)
                tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMRIGHT", "BOTTOMLEFT", -3, 0
            elseif anchor == "BOTTOMRIGHT" then
                npcFrame:SetPoint("BOTTOMRIGHT", separateAnchor, "BOTTOMLEFT", -4, 0)
                tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "BOTTOMLEFT", "BOTTOMRIGHT", 3, 0
            elseif anchor == "TOPLEFT" then
                npcFrame:SetPoint("TOPLEFT", separateAnchor, "TOPRIGHT", 4, 0)
                tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPRIGHT", "TOPLEFT", -3, 0
            elseif anchor == "TOPRIGHT" then
                npcFrame:SetPoint("TOPRIGHT", separateAnchor, "TOPLEFT", -4, 0)
                tooltipPoint, tooltipRelativePoint, tooltipX, tooltipY = "TOPLEFT", "TOPRIGHT", 3, 0
            end
        end
    end

    npcFrame:UpdateSeparateAnchor()
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
        if CellDB["general"]["fadeOut"] then
            separateAnchor.fadeOut:Play()
        else
            separateAnchor.fadeIn:Play()
        end
    end

    if which == "position" then
        UpdatePosition()
    end
end
Cell.RegisterCallback("UpdateMenu", "NPCFrame_UpdateMenu", UpdateMenu)

local function NPCFrame_UpdateLayout(layout, which)
    -- visibility
    if Cell.vars.isHidden then
        Cell.UnregisterAttributeDriver(npcFrame, "state-visibility")
        SetNPCStateDriversEnabled(false)
        npcFrame:Hide()
        return
    end
    --! WotLK fix: the old condition ended in unconditional "show", so the
    --! 3.3.5 state driver only reparsed a constant result every 0.2 seconds.
    --! Layout updates are already deferred out of combat; show directly.
    Cell.UnregisterAttributeDriver(npcFrame, "state-visibility")
    npcFrame:Show()

    -- update
    layout = Cell.vars.currentLayoutTable

    if not which or strfind(which, "size$") then
        local width, height
        if layout["npc"]["sameSizeAsMain"] then
            width, height = unpack(layout["main"]["size"])
        else
            width, height = unpack(layout["npc"]["size"])
        end

        P.Size(npcFrame, width, height)

        for _, b in ipairs(Cell.unitButtons.npc) do
            P.Size(b, width, height)
        end
    end

    -- NOTE: SetOrientation BEFORE SetPowerSize
    if not which or which == "barOrientation" then
        for _, b in ipairs(Cell.unitButtons.npc) do
            B.SetOrientation(b, layout["barOrientation"][1], layout["barOrientation"][2])
        end
    end

    if not which or strfind(which, "power$") or which == "barOrientation" or which == "powerFilter" then
        for _, b in ipairs(Cell.unitButtons.npc) do
            if layout["npc"]["sameSizeAsMain"] then
                B.SetPowerSize(b, layout["main"]["powerSize"])
            else
                B.SetPowerSize(b, layout["npc"]["powerSize"])
            end
        end
    end

    if not which or which == "pet" then
        UpdatePartyAnchor(layout)
    end


    if not which or strfind(which, "arrangement$") or which == "npc" or which == "pet" then
        local groupType = F.GetGroupType()
        npcFrame:ClearAllPoints()

        local orientation, anchor, spacingX, spacingY
        if layout["npc"]["sameArrangementAsMain"] then
            orientation = layout["main"]["orientation"]
            anchor = layout["main"]["anchor"]
            spacingX = layout["main"]["spacingX"]
            spacingY = layout["main"]["spacingY"]
        else
            orientation = layout["npc"]["orientation"]
            anchor = layout["npc"]["anchor"]
            spacingX = layout["npc"]["spacingX"]
            spacingY = layout["npc"]["spacingY"]
        end

        local point, anchorPoint, groupAnchorPoint, unitSpacing, groupSpacing
        if orientation == "vertical" then
            if anchor == "BOTTOMLEFT" then
                point, anchorPoint, groupAnchorPoint = "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT"
                unitSpacing = spacingY
                groupSpacing = spacingX
            elseif anchor == "BOTTOMRIGHT" then
                point, anchorPoint, groupAnchorPoint = "BOTTOMRIGHT", "TOPRIGHT", "BOTTOMLEFT"
                unitSpacing = spacingY
                groupSpacing = -spacingX
            elseif anchor == "TOPLEFT" then
                point, anchorPoint, groupAnchorPoint = "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT"
                unitSpacing = -spacingY
                groupSpacing = spacingX
            elseif anchor == "TOPRIGHT" then
                point, anchorPoint, groupAnchorPoint = "TOPRIGHT", "BOTTOMRIGHT", "TOPLEFT"
                unitSpacing = -spacingY
                groupSpacing = -spacingX
            end

            if not layout["npc"]["separate"] then
                -- update whole NPCFrame point
                if groupType == "raid" then
                    npcFrame:SetPoint(point, anchors["raid"])

                elseif groupType == "party" then
                    if npcFrame:GetAttribute("pet") == "nopet" then
                        npcFrame:SetPoint(point, anchors["solo"], groupAnchorPoint, P.Scale(groupSpacing), 0)
                    else
                        npcFrame:SetPoint(point, anchors["party"], groupAnchorPoint, P.Scale(groupSpacing), 0)
                    end

                else -- solo
                    npcFrame:SetPoint(point, anchors["solo"], groupAnchorPoint, P.Scale(groupSpacing), 0)
                end
            end
        else
            if anchor == "BOTTOMLEFT" then
                point, anchorPoint, groupAnchorPoint = "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT"
                unitSpacing = spacingX
                groupSpacing = spacingY
            elseif anchor == "BOTTOMRIGHT" then
                point, anchorPoint, groupAnchorPoint = "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT"
                unitSpacing = -spacingX
                groupSpacing = spacingY
            elseif anchor == "TOPLEFT" then
                point, anchorPoint, groupAnchorPoint = "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT"
                unitSpacing = spacingX
                groupSpacing = -spacingY
            elseif anchor == "TOPRIGHT" then
                point, anchorPoint, groupAnchorPoint = "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT"
                unitSpacing = -spacingX
                groupSpacing = -spacingY
            end

            if not layout["npc"]["separate"] then
                -- update whole NPCFrame point
                if groupType == "raid" then
                    npcFrame:SetPoint(point, anchors["raid"])

                elseif groupType == "party" then
                    if npcFrame:GetAttribute("pet") == "nopet" then
                        npcFrame:SetPoint(point, anchors["solo"], groupAnchorPoint, 0, P.Scale(groupSpacing))
                    else
                        npcFrame:SetPoint(point, anchors["party"], groupAnchorPoint, 0, P.Scale(groupSpacing))
                    end

                else -- solo
                    npcFrame:SetPoint(point, anchors["solo"], groupAnchorPoint, 0, P.Scale(groupSpacing))
                end
            end
        end

        -- save point data
        npcFrame:SetAttribute("orientation", orientation)
        npcFrame:SetAttribute("point", point)
        npcFrame:SetAttribute("anchorPoint", anchorPoint)
        npcFrame:SetAttribute("groupAnchorPoint", groupAnchorPoint)
        npcFrame:SetAttribute("unitSpacing", P.Scale(unitSpacing))
        npcFrame:SetAttribute("groupSpacing", P.Scale(groupSpacing))

        local last
        for i = 1, 8 do
            local button = Cell.unitButtons.npc[i]
            button.helper:SetAttribute("orientation", orientation)
            button.helper:SetAttribute("point", point)
            button.helper:SetAttribute("anchorPoint", anchorPoint)
            button.helper:SetAttribute("unitSpacing", P.Scale(unitSpacing))

            -- update each npc button now
            if button:IsVisible() then
                button:ClearAllPoints()
                if last then
                    if orientation == "vertical" then
                        button:SetPoint(point, last, anchorPoint, 0, P.Scale(unitSpacing))
                    else
                        button:SetPoint(point, last, anchorPoint, P.Scale(unitSpacing), 0)
                    end
                else
                    button:SetPoint("TOPLEFT", npcFrame)
                end
                last = button
            end
        end
    end

    if not which or strfind(which, "arrangement$") or which == "npc" then
        UpdatePosition()
    end

    if not which or which == "npc" then
        if layout["npc"]["enabled"] then
            -- NOTE: Cell.RegisterAttributeDriver
            for i, b in ipairs(Cell.unitButtons.npc) do
                --! WotLK fix: 3.3.5 only has boss1-boss4 (FrameXML TargetFrame.xml
                --! creates exactly four BossTargetFrames). Drivers for boss5-boss8
                --! can never resolve to "show", yet SecureStateDriver still parses
                --! them 5 times per second forever. Register only the first four.
                if i <= 4 then
                    Cell.RegisterAttributeDriver(b, "state-visibility", "[@boss"..i..", help] show; hide")
                    -- Cell.RegisterAttributeDriver(b, "state-visibility", "[@player, help] show; hide")
                else
                    Cell.UnregisterAttributeDriver(b, "state-visibility")
                    b:Hide()
                end
            end
            if layout["npc"]["separate"] then
                SetNPCStateDriversEnabled(false)
                -- load separate npc frame position
                P.LoadPosition(separateAnchor, layout["npc"]["position"])
            else
                SetNPCStateDriversEnabled(true)
            end
        else
            SetNPCStateDriversEnabled(false)
            -- NOTE: Cell.RegisterAttributeDriver
            for _, b in ipairs(Cell.unitButtons.npc) do
                Cell.UnregisterAttributeDriver(b, "state-visibility")
                b:Hide()
            end
        end
    end
end
Cell.RegisterCallback("UpdateLayout", "NPCFrame_UpdateLayout", NPCFrame_UpdateLayout)

-- local function NPCFrame_UpdateVisibility(which)
--     if not which or which == "solo" or which == "party" then
--         local showSolo = CellDB["general"]["showSolo"] and "show" or "hide"
--         local showParty = CellDB["general"]["showParty"] and "show" or "hide"
--         -- Cell.RegisterAttributeDriver(npcFrame, "state-visibility", "[group:raid] show; [group:party] "..showParty.."; "..showSolo)
--         Cell.RegisterAttributeDriver(npcFrame, "state-visibility", "[@raid1,exists] show;[@party1,exists] "..showParty..";"..showSolo)
--     end
-- end
-- Cell.RegisterCallback("UpdateVisibility", "NPCFrame_UpdateVisibility", NPCFrame_UpdateVisibility)
