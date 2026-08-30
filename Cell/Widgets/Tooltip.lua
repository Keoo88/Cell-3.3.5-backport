local _, Cell = ...
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

-----------------------------------------
-- Tooltip
-----------------------------------------
local function CreateTooltip(name, hasIcon)
    local tooltip = CreateFrame("GameTooltip", name, CellParent, "CellTooltipTemplate")
    tooltip:SetBackdrop({bgFile = Cell.vars.whiteTexture, edgeFile = Cell.vars.whiteTexture, edgeSize = 1})
    tooltip:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    tooltip:SetBackdropBorderColor(Cell.GetAccentColorRGB())
    tooltip:SetOwner(CellParent, "ANCHOR_NONE")

    if hasIcon then
        local iconBG = tooltip:CreateTexture(nil, "BACKGROUND")
        tooltip.iconBG = iconBG
        iconBG:SetSize(35, 35)
        iconBG:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -1, 0)
        --! WotLK fix: SetColorTexture на 3.3.5 нет - это нативная числовая форма
        --! SetTexture(r, g, b[, a]); шим TextureBase в WidgetAPI удалён.
        iconBG:SetTexture(Cell.GetAccentColorRGB())
        iconBG:Hide()

        local icon = tooltip:CreateTexture(nil, "ARTWORK")
        tooltip.icon = icon
        P.Point(icon, "TOPLEFT", iconBG, 1, -1)
        P.Point(icon, "BOTTOMRIGHT", iconBG, -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Hide()

        --! WotLK fix: the signature on 3.3.5 is SetSpellByID(id, isPet, showSubtext),
        --! so a texture path passed in slot 2 is truthy and makes the client look the
        --! spell up in the PET book. Set the icon through a separate method instead of
        --! smuggling it through the tooltip call.
        function tooltip:SetSpellIcon(tex)
            if tex then
                iconBG:Show()
                icon:SetTexture(tex)
                icon:Show()
            else
                iconBG:Hide()
                icon:Hide()
            end
        end
    end

    tooltip:SetScript("OnTooltipCleared", function()
        -- reset border color
        tooltip:SetBackdropBorderColor(Cell.GetAccentColorRGB())
    end)

    -- tooltip:SetScript("OnTooltipSetItem", function()
    --     -- color border with item quality color
    --     tooltip:SetBackdropBorderColor(_G[name.."TextLeft1"]:GetTextColor())
    -- end)

    tooltip:SetScript("OnHide", function()
        -- SetX with invalid data may or may not clear the tooltip's contents.
        tooltip:ClearLines()

        if hasIcon then
            tooltip.iconBG:Hide()
            tooltip.icon:Hide()
        end
    end)

    function tooltip:UpdatePixelPerfect()
        tooltip:SetBackdrop({bgFile = Cell.vars.whiteTexture, edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
        tooltip:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        tooltip:SetBackdropBorderColor(Cell.GetAccentColorRGB())
        if hasIcon then
            P.Repoint(tooltip.icon)
            tooltip.iconBG:SetTexture(Cell.GetAccentColorRGB())
        end
    end
end

CreateTooltip("CellTooltip")
CreateTooltip("CellSpellTooltip", true)
-- CreateTooltip("CellScanningTooltip")

--! WotLK fix: "ANCHOR_CURSOR_LEFT" на 3.3.5a не существует. В строковой таблице
--! клиента лежат ровно 12 типов привязки подсказки (ANCHOR_TOP/BOTTOM/LEFT/RIGHT и
--! их углы, ANCHOR_NONE, ANCHOR_PRESERVE, ANCHOR_CURSOR, ANCHOR_CURSOR_RIGHT) -
--! варианта с _LEFT среди них нет, тогда как ANCHOR_CURSOR_RIGHT Blizzard зовёт сама
--! (FrameXML 3.3.5a WorldMapFrame.lua:1868). То есть пункт "Курсор: слева" в
--! «Опции» → «Подсказки» → «Привязать к» не давал обещанного места вообще.
--! Эмулируем его невидимой рамкой 1x1 в точке курсора и цепляем подсказку правым
--! краем к её левому. Только этот пункт: "Курсор" и "Курсор: справа" остаются на
--! родной привязке клиента - она следит за курсором в C и не стоит ничего.
--! OnUpdate живёт лишь пока подсказка на экране: рамка сама прячется, когда
--! GameTooltip скрыт (тот же приём самоочистки, что у CellCooldown_OnUpdate
--! в Indicators/Base.lua).
local cursorAnchor = CreateFrame("Frame", nil, UIParent)
cursorAnchor:SetSize(1, 1)
cursorAnchor:EnableMouse(false)
cursorAnchor:Hide()

local function PositionCursorAnchor(self)
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

cursorAnchor:SetScript("OnUpdate", function(self)
    if GameTooltip:IsShown() then
        PositionCursorAnchor(self)
    else
        self:Hide()
    end
end)

--! WotLK fix: a unit tooltip on 3.3.5 does not stay up by itself. GameTooltip:SetUnit
--! returns whether the tooltip needs refreshing, and the client starts its native
--! GameTooltip:FadeOut() unless someone keeps it alive: FrameXML's GameTooltip_OnUpdate
--! (GameTooltip.lua:183-196) counts down TOOLTIP_UPDATE_TIME and calls
--! owner:UpdateTooltip() if the owner defines one, which is exactly what Blizzard's own
--! unit frames install (UnitFrame.lua:144-150 UnitFrame_UpdateTooltip). Cell set the
--! owner and the content but never that method, so hovering a raid button showed the
--! tooltip for a moment and then let it fade out under a motionless cursor.
--! The owner is a foreign frame as far as this file is concerned (rule 3), so the
--! previous UpdateTooltip is saved and put back when the tooltip hides, and the restore
--! only fires if the field is still ours. Refreshing via GameTooltip:Show() rather than
--! re-running SetUnit keeps Cell's custom anchor points untouched - the stale content of
--! a 0.2s window is not worth re-positioning the tooltip every tick.
local tooltipOwner, previousTooltipUpdater

local function UpdateCellTooltip()
    GameTooltip:Show()
end

local function ClearTooltipUpdater()
    if tooltipOwner and tooltipOwner.UpdateTooltip == UpdateCellTooltip then
        tooltipOwner.UpdateTooltip = previousTooltipUpdater
    end
    tooltipOwner = nil
    previousTooltipUpdater = nil
end

GameTooltip:HookScript("OnHide", ClearTooltipUpdater)

function F.ShowSpellTooltips(tooltip, spellID)
    --! WotLK fix: CreateBaseTooltipInfo/ProcessInfo are retail 10.x tooltip-data
    --! API and do not exist on 3.3.5. The function is currently unreferenced,
    --! but guard it so a future caller degrades to a no-op instead of crashing.
    if not CreateBaseTooltipInfo then return end
    local tooltipInfo = CreateBaseTooltipInfo("GetSpellByID", spellID)
    tooltip:ProcessInfo(tooltipInfo)
    tooltip:Show()
end

function F.ShowTooltips(anchor, tooltipType, unit, aura, filter)
    if not CellDB["general"]["enableTooltips"] or (tooltipType == "unit" and CellDB["general"]["hideTooltipsInCombat"] and InCombatLockdown()) then return end

    --! WotLK fix: снять рамку курсора, если игрок сменил пункт привязки, пока
    --! подсказка была на экране - иначе её OnUpdate остался бы висеть.
    cursorAnchor:Hide()

    if CellDB["general"]["tooltipsPosition"][2] == "Default" then
        GameTooltip_SetDefaultAnchor(GameTooltip, anchor)
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cell" then
        GameTooltip:SetOwner(Cell.frames.mainFrame, "ANCHOR_NONE")
        GameTooltip:SetPoint(CellDB["general"]["tooltipsPosition"][1], Cell.frames.mainFrame, CellDB["general"]["tooltipsPosition"][3], CellDB["general"]["tooltipsPosition"][4], CellDB["general"]["tooltipsPosition"][5])
    elseif CellDB["general"]["tooltipsPosition"][2] == "Unit Button" then
        GameTooltip:SetOwner(anchor, "ANCHOR_NONE")
        GameTooltip:SetPoint(CellDB["general"]["tooltipsPosition"][1], anchor, CellDB["general"]["tooltipsPosition"][3], CellDB["general"]["tooltipsPosition"][4], CellDB["general"]["tooltipsPosition"][5])
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cursor" then
        GameTooltip:SetOwner(anchor, "ANCHOR_CURSOR")
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cursor Left" then
        PositionCursorAnchor(cursorAnchor)
        cursorAnchor:Show()
        GameTooltip:SetOwner(anchor, "ANCHOR_NONE")
        GameTooltip:SetPoint("BOTTOMRIGHT", cursorAnchor, "BOTTOMLEFT", CellDB["general"]["tooltipsPosition"][4], CellDB["general"]["tooltipsPosition"][5])
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cursor Right" then
        GameTooltip:SetOwner(anchor, "ANCHOR_CURSOR_RIGHT", CellDB["general"]["tooltipsPosition"][4], CellDB["general"]["tooltipsPosition"][5])
    end

    if tooltipType == "unit" then
        GameTooltip:SetUnit(unit)
    elseif tooltipType == "spell" and unit and aura then
        -- GameTooltip:SetSpellByID(aura)
        GameTooltip:SetUnitAura(unit, aura, filter)
    else
        return
    end
    --! WotLK fix: the "aura" branch called SetUnitDebuffByAuraInstanceID /
    --! SetUnitBuffByAuraInstanceID - retail 10.x tooltip methods that do not exist
    --! on 3.3.5 (кодекс знает только GameTooltip:SetUnitAura(unit, index, filter)),
    --! so reaching it would have been "attempt to call method (a nil value)".
    --! Unreachable here in the first place: an aura instance id is a retail concept,
    --! and the only two callers (Built-in.lua debuffs / raidDebuffs) hand over the
    --! aura INDEX that UnitButton_Cata_Wrath.lua stores as ind.index, which the
    --! "spell" branch above resolves natively. Cut with its callers' dead elseif.
    --! The else above only ends up unreachable together with them: all three live
    --! callers pass one of the two types with full arguments.

    --! WotLK fix: keep the tooltip alive, see ClearTooltipUpdater above.
    tooltipOwner = GameTooltip:GetOwner()
    if tooltipOwner then
        previousTooltipUpdater = tooltipOwner.UpdateTooltip
        tooltipOwner.UpdateTooltip = UpdateCellTooltip
    end
end