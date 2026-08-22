local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs

-------------------------------------------------
-- CreateAoEHealing -- not support for npc
-------------------------------------------------

local function Display(b)
    b.indicators.aoeHealing:Display()
end

local playerSummoned = {}
local eventFrame = CreateFrame("Frame")
--! WotLK perf: named parameters instead of `...` plus a ten-slot vararg unpack. A
--! Lua 5.1 function that declares `...` is a vararg function - every call pays
--! adjust_varargs plus a VARARG copy back into registers - and this frame is fed
--! COMBAT_LOG_EVENT_UNFILTERED, the most frequent event in the game. The two
--! interesting sub-events are also tested as one chain now instead of two
--! independent ifs, so a line of the log that is neither (the overwhelming
--! majority) leaves after a single comparison.
eventFrame:SetScript("OnEvent", function(_, event,
    timestamp, subevent, sourceGUID, sourceName, sourceFlags,
    destGUID, destName, destFlags, spellId, spellName)

    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end

    --! WotLK fix: parse the native 3.3.5 CLEU payload directly. Depending on
    --! global CombatLogGetCurrentEventInfo made this hot path use whichever
    --! translator standalone !!!ClassicAPI published first.
    -- if subevent == "SPELL_SUMMON" then print(subevent, sourceName, sourceGUID, destName, destGUID, spellName) end
    if subevent == "SPELL_SUMMON" then
        -- print(sourceGUID == Cell.vars.playerGUID, destGUID, spellName, spellId)
        if sourceGUID == Cell.vars.playerGUID and destGUID and I.IsAoEHealing(spellName, spellId) then
            local duration = I.GetSummonDuration(spellName)
            if duration then
                playerSummoned[destGUID] = GetTime() + duration -- expirationTime
                C_Timer.After(duration, function()
                    playerSummoned[destGUID] = nil
                end)
            end
        end
        -- texplore(playerSummoned)
    -- if (subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL") then print(subevent, sourceName, sourceGUID, destName, spellId, spellName) end
    elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
        if destGUID then
            -- print(sourceGUID == Cell.vars.playerGUID, sourceGUID, playerSummoned[sourceGUID])
            if (sourceGUID == Cell.vars.playerGUID and I.IsAoEHealing(spellName, spellId)) or playerSummoned[sourceGUID] then
                F.HandleUnitButton("guid", destGUID, Display)
            end
        end
    end
end)

function I.CreateAoEHealing(parent)
    local aoeHealing = CreateFrame("Frame", parent:GetName().."AoEHealing", parent.widgets.indicatorFrame)
    parent.indicators.aoeHealing = aoeHealing
    aoeHealing:SetPoint("TOPLEFT", parent.widgets.healthBar)
    aoeHealing:SetPoint("TOPRIGHT", parent.widgets.healthBar)
    aoeHealing:Hide()

    aoeHealing.tex = aoeHealing:CreateTexture(nil, "ARTWORK")
    aoeHealing.tex:SetAllPoints(aoeHealing)
    aoeHealing.tex:SetTexture(Cell.vars.whiteTexture)

    -- 3.3.5a: do NOT use a native AnimationGroup here. Playing a native
    -- Alpha animation (what the Fix-4 shim translates SetFromAlpha/SetToAlpha
    -- into via SetChange) makes the client render the animated texture
    -- WITHOUT its vertex color / gradient state: the bar shows as a flat
    -- white rectangle no matter what SetColor applied. A plain color fill
    -- (SetTexture(r,g,b,a)) survives the animation, which is how the tester
    -- probes pinned it down. Drive the flash fade manually via
    -- OnUpdate + SetAlpha instead: with no native animation playing, the
    -- gradient and color render correctly (same as the static options preview).
    local FADE_IN, FADE_OUT = 0.5, 0.5

    local function Fade_OnUpdate(self, elapsed)
        local t = (self._elapsed or 0) + elapsed
        self._elapsed = t
        if t < FADE_IN then
            local p = t / FADE_IN
            self:SetAlpha(1 - (1 - p) * (1 - p)) -- ease-out, like SetSmoothing("OUT")
        elseif t < FADE_IN + FADE_OUT then
            local p = (t - FADE_IN) / FADE_OUT
            self:SetAlpha(1 - p * p) -- ease-in, like SetSmoothing("IN")
        else
            self:SetScript("OnUpdate", nil)
            self._elapsed = nil
            self:SetAlpha(1)
            self:Hide()
        end
    end

    -- 3.3.5a: the retail path (SetGradient + CreateColor tables) goes through
    -- the shared-metatable polyfill and proved unreliable in the field. Call
    -- the native numeric SetGradientAlpha directly and keep SetVertexColor as
    -- a base tint so the bar is colored even if gradients misbehave.
    function aoeHealing:ApplyColor()
        local r = aoeHealing.r or 1
        local g = aoeHealing.g or 1
        local b = aoeHealing.b or 0
        local tex = aoeHealing.tex
        tex:SetVertexColor(r, g, b, 0.77)
        if tex.SetGradientAlpha then
            -- native wrath signature: orientation, bottom RGBA, top RGBA
            tex:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 0.77)
        end
    end

    function aoeHealing:SetColor(r, g, b)
        aoeHealing.r, aoeHealing.g, aoeHealing.b = r, g, b
        aoeHealing:ApplyColor()
    end

    function aoeHealing:Display()
        aoeHealing:ApplyColor()
        aoeHealing._elapsed = 0
        aoeHealing:SetAlpha(0)
        aoeHealing:Show()
        aoeHealing:SetScript("OnUpdate", Fade_OnUpdate)
    end
end

function I.EnableAoEHealing(enabled)
    if enabled then
        eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end
