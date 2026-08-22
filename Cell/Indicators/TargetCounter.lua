local _, Cell = ...
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs

-------------------------------------------------
-- events
-------------------------------------------------
--! WotLK: the whole counting engine is removed. It was driven by
--! NAME_PLATE_UNIT_ADDED / NAME_PLATE_UNIT_REMOVED and C_NamePlate.GetNamePlates(),
--! none of which exist on 3.3.5 (codex: all four report НЕТ - nameplates only
--! became addressable units in 7.0). Cell publishes no C_NamePlate stub either:
--! Polyfills.lua:691 states why an empty modern namespace is worse than none.
--! The nameplate table could never be populated, so the 0.25s ticker only burned
--! CPU iterating the whole group 4x/sec while always reporting 0.
--! Only the no-op entry points remain - they are still called from
--! UnitButton_Cata_Wrath.lua. The indicator itself is created hidden below.
function I.EnableTargetCounter(enabled)
end

function I.UpdateTargetCounterFilters(filters, noUpdate)
end

-------------------------------------------------
-- CreateTargetCounter
-------------------------------------------------
function I.CreateTargetCounter(parent)
    local targetCounter = CreateFrame("Frame", parent:GetName().."TargetCounter", parent)
    parent.indicators.targetCounter = targetCounter
    targetCounter:Hide()

    local text = targetCounter:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    targetCounter.text = text
    -- stack:SetJustifyH("RIGHT")
    text:SetPoint("CENTER", 1, 0)

    function targetCounter:SetFont(font, size, outline, shadow)
        font = F.GetFont(font)

        local flags
        if outline == "None" then
            flags = ""
        elseif outline == "Outline" then
            flags = "OUTLINE"
        else
            flags = "OUTLINE,MONOCHROME"
        end

        text:SetFont(font, size, flags)

        if shadow then
            text:SetShadowOffset(1, -1)
            text:SetShadowColor(0, 0, 0, 1)
        else
            text:SetShadowOffset(0, 0)
            text:SetShadowColor(0, 0, 0, 0)
        end

        local point = targetCounter:GetPoint(1)
        text:ClearAllPoints()
        if string.find(point, "LEFT") then
            text:SetPoint("LEFT")
        elseif string.find(point, "RIGHT") then
            text:SetPoint("RIGHT")
        else
            text:SetPoint("CENTER")
        end
        targetCounter:SetSize(size+3, size+3)
    end

    targetCounter._SetPoint = targetCounter.SetPoint
    function targetCounter:SetPoint(point, relativeTo, relativePoint, x, y)
        text:ClearAllPoints()
        if string.find(point, "LEFT") then
            text:SetPoint("LEFT")
        elseif string.find(point, "RIGHT") then
            text:SetPoint("RIGHT")
        else
            text:SetPoint("CENTER")
        end
        targetCounter:_SetPoint(point, relativeTo, relativePoint, x, y)
    end

    function targetCounter:SetCount(n)
        if n == 0 then
            targetCounter:Hide()
        else
            targetCounter:Show()
        end
        text:SetText(n)
    end

    function targetCounter:SetColor(r, g, b)
        text:SetTextColor(r, g, b)
    end
end
