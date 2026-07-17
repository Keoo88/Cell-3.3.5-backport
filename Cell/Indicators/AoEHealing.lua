local _, Cell = ...
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs

-------------------------------------------------
-- CreateAoEHealing -- not support for npc
-------------------------------------------------
-- Retail has CombatLogGetCurrentEventInfo; Wrath passes the values directly.
-- NOTE: pass varargs through — the ClassicAPI shim of CombatLogGetCurrentEventInfo
-- is a passthrough that normalizes the 3.3.5a payload and returns nothing without args.
-- Retail ignores extra args, so this is safe everywhere.
local function GetCLEUInfo(...)
    if CombatLogGetCurrentEventInfo then
        return CombatLogGetCurrentEventInfo(...)
    end
    return ...
end

local function Display(b)
    b.indicators.aoeHealing:Display()
end

local playerSummoned = {}
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end

    -- WotLK 3.3.5a: sourceRaidFlags and destRaidFlags don't exist (added in 4.2.0)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName
    if CombatLogGetCurrentEventInfo then
        -- Retail/Cata+ has sourceRaidFlags and destRaidFlags
        local sourceRaidFlags, destRaidFlags
        timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName = GetCLEUInfo(...)
    else
        -- WotLK 3.3.5a: No sourceRaidFlags/destRaidFlags
        timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName = GetCLEUInfo(...)
    end
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
    end
    -- if (subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL") then print(subevent, sourceName, sourceGUID, destName, spellId, spellName) end
    if subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
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
        elseif tex.SetGradient then
            tex:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.77))
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
