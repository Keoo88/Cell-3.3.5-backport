local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local PixelUtil = Cell.PixelUtil
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs
local A = Cell.animations

--! WotLK fix: ветка world-меток («маячки» на землю, /wm) вырезана целиком - фича
--! появилась в 4.0, а на 3.3.5 её нет ни в API (кодекс: НЕТ на PlaceRaidMarker,
--! ClearRaidMarker, IsRaidMarkerActive), ни в secure-шаблонах (SECURE_ACTIONS в
--! FrameXML 3.3.5a SecureTemplates.lua держит ровно 16 типов, "worldmarker" среди
--! них нет, а неизвестный тип молча ничего не делает). Убраны: фрейм worldMarks,
--! девять кнопок SecureActionButtonTemplate, worldMarkIndices, worldMarksTimer,
--! оба скрипта фрейма и все ветки ^world / else -- both в ShowMover,
--! CheckPermission и Rearrange. Метки по цели (SetRaidTarget) - другая система,
--! она работает и осталась нетронутой. Подробности - audit/STUDY_GAPS.md §2.23.
local marks

local marksFrame = CreateFrame("Frame", "CellRaidMarksFrame", Cell.frames.mainFrame, "SecureFrameTemplate")
Cell.frames.raidMarksFrame = marksFrame
marksFrame:SetSize(196, 40)
PixelUtil.SetPoint(marksFrame, "BOTTOMRIGHT", CellParent, "CENTER", -1, 1)
marksFrame:SetClampedToScreen(true)
marksFrame:SetMovable(true)
marksFrame:RegisterForDrag("LeftButton")
marksFrame:SetScript("OnDragStart", function()
    marksFrame:StartMoving()
    marksFrame:SetUserPlaced(false)
end)
marksFrame:SetScript("OnDragStop", function()
    marksFrame:StopMovingOrSizing()
    P.SavePosition(marksFrame, CellDB["tools"]["marks"][4])
end)

-------------------------------------------------
-- mover
-------------------------------------------------
marksFrame.moverText = marksFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
marksFrame.moverText:SetPoint("TOP", 0, -3)
--! WotLK fix: label set in ShowMover - at load time L still returns the English key
--! (ns.LoadUserLocale runs on ADDON_LOADED, after every file), and a FontString keeps
--! whatever string it was handed.
marksFrame.moverText:Hide()

--! WotLK fix: хват за всю площадь бара в режиме мувера, см. F.CreateMoverOverlay.
--! Раньше тащить можно было только за полосу 20 юнитов над кнопками меток (~14
--! экранных пикселей при масштабе 0.7), а промах по ней ставил метку на цель.
local moverOverlay = F.CreateMoverOverlay(marksFrame, function()
    return CellDB["tools"]["marks"][4]
end)

--! WotLK fix: world markers do not exist on 3.3.5 (added in 4.0) and the whole
--! branch is now deleted (see the header note), so this coercion is the ONLY
--! thing standing between a SavedVariables file migrated from a newer client and
--! a broken marks bar: "world_*"/"both_*" would no longer match any branch, the
--! bar would keep target-mark geometry for a mode that has no widgets left.
--! Keep it, and keep calling it from BOTH readers (ShowMover, CheckPermission)
--! before the mode string is used. Orientation is preserved.
--! Guard `Cell.isVanilla or Cell.isWrath` вырезан - на 3.3.5 он всегда истина.
local function NormalizeMarksMode()
    local mode = CellDB["tools"]["marks"][3]
    if strfind(mode, "^world") or strfind(mode, "^both") then
        CellDB["tools"]["marks"][3] = strfind(mode, "_v$") and "target_v" or "target_h"
    end
end

local function ShowMover(show)
    if show then
        if not CellDB["tools"]["marks"][1] then return end
        NormalizeMarksMode() --! WotLK fix
        marksFrame:EnableMouse(true)
        marksFrame.moverText:SetText(L["Mover"]) --! WotLK fix: см. выше
        marksFrame.moverText:Show()
        Cell.StylizeFrame(marksFrame, {0, 1, 0, 0.4}, {0, 0, 0, 0})
        if not F.HasPermission(true) then -- button not shown
            --! WotLK fix: только метки по цели - ветки ^world / both вырезаны.
            marks:Show()
        end
        marksFrame:SetAlpha(1)
        moverOverlay:Show()
    else
        marksFrame:EnableMouse(false)
        marksFrame.moverText:Hide()
        Cell.StylizeFrame(marksFrame, {0, 0, 0, 0}, {0, 0, 0, 0})
        if not F.HasPermission(true) then -- button should not shown
            if not (Cell.vars.groupType == "solo" and CellDB["tools"]["marks"][2]) then
                marks:Hide()
            end
        end
        marksFrame:SetAlpha(CellDB["tools"]["fadeOut"] and 0 or 1)
        moverOverlay:Hide()
    end
end
Cell.RegisterCallback("ShowMover", "RaidMarks_ShowMover", ShowMover)

-------------------------------------------------
-- colors
-------------------------------------------------
local markColors = {
    {1, 1, 0}, -- star
    {1, 0.5, 0}, -- circle
    {0.5, 0, 1}, -- diamond
    {0, 1, 0.2}, -- triangle
    {0.5, 0.5, 0.5}, -- moon
    {0, 0.5, 1}, -- square
    {1, 0, 0}, -- cross
    {1, 1, 1}, -- skull
    {1, 0.19, 0.19}, -- clear
}

-------------------------------------------------
-- marks
-------------------------------------------------
marks = Cell.CreateFrame("CellRaidMarksFrame_Marks", marksFrame, 196, 20, true)
marks:SetPoint("BOTTOMLEFT")
marks:Hide()

local function RemoveRaidTargets()
    -- Always try to clear specific units that might be marked
    SetRaidTarget("player", 0)
    if UnitExists("target") then SetRaidTarget("target", 0) end

    if GetNumRaidMembers() > 0 then
        for i = 1, 40 do
            SetRaidTarget("raid"..i, 0)
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, 4 do
            SetRaidTarget("party"..i, 0)
        end
    end
end

local ticker
local markButtons = {}
for i = 1, 9 do
    markButtons[i] = Cell.CreateButton(marks, "", "accent-hover", {20, 20})
    markButtons[i].texture = markButtons[i]:CreateTexture(nil, "ARTWORK")
    P.Point(markButtons[i].texture, "TOPLEFT", markButtons[i], "TOPLEFT", 2, -2)
    P.Point(markButtons[i].texture, "BOTTOMRIGHT", markButtons[i], "BOTTOMRIGHT", -2, 2)

    if i == 9 then
        -- clear all marks
        markButtons[i].texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        markButtons[i]:SetScript("OnClick", function()
            RemoveRaidTargets()
            -- markButtons[i]:SetEnabled(false)
            -- markButtons[i].texture:SetDesaturated(true)
            -- for j = 1, 8 do
            --     SetRaidTarget("player", j)
            -- end
            -- C_Timer.After(0.5, function()
            --     SetRaidTarget("player", 0)
            --     markButtons[i]:SetEnabled(true)
            --     markButtons[i].texture:SetDesaturated(false)
            -- end)
        end)
    else
        markButtons[i].texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        SetRaidTargetIconTexture(markButtons[i].texture, i)
        markButtons[i]:RegisterForClicks("LeftButtonDown", "RightButtonDown")
        markButtons[i]:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                -- set raid target icon
                if GetRaidTargetIndex("target") == i then
                    SetRaidTarget("target", 0)
                else
                    SetRaidTarget("target", i)
                end
            elseif button == "RightButton" then
                -- lock raid target icon
                local unit, name, class = F.GetTargetUnitInfo()
                if unit and name then
                    if markButtons[i].locked then
                        F.NotifyMarkUnlock(i, name, class)
                        SetRaidTarget(markButtons[i].locked, 0)
                        markButtons[i]:SetBackdropBorderColor(0, 0, 0, 1)
                        markButtons[i].locked = nil
                        if markButtons[i].ticker then
                            markButtons[i].ticker:Cancel()
                            markButtons[i].ticker = nil
                        end
                    else
                        F.NotifyMarkLock(i, name, class)
                        SetRaidTarget(unit, i)
                        markButtons[i]:SetBackdropBorderColor(markColors[i][1], markColors[i][2], markColors[i][3], 1)
                        markButtons[i].locked = unit
                        markButtons[i].ticker = C_Timer.NewTicker(1.5, function()
                            if UnitName(unit) == name then
                                if GetRaidTargetIndex(unit) ~= i then
                                    SetRaidTarget(unit, i)
                                end
                            else
                                markButtons[i].locked = nil
                                markButtons[i].ticker:Cancel()
                                markButtons[i].ticker = nil
                                markButtons[i]:SetBackdropBorderColor(0, 0, 0, 1)
                            end
                        end)
                    end
                end
            end
        end)
    end

    --! WotLK fix: SetColorTexture на 3.3.5 нет - это нативная числовая форма
    --! SetTexture(r, g, b[, a]); шим TextureBase в WidgetAPI удалён.
    markButtons[i].bg:SetTexture(0.1, 0.1, 0.1, 0.7)
    markButtons[i]:SetBackdropColor(0, 0, 0, 0)
    markButtons[i].color = {0, 0, 0, 0}
    markButtons[i].hoverColor = {markColors[i][1], markColors[i][2], markColors[i][3], 0.35}

    -- if i == 1 then
    --     P.Point(markButtons[i], "TOPLEFT")
    -- else
    --     P.Point(markButtons[i], "LEFT", markButtons[i-1], "RIGHT", 2, 0)
    -- end
end

marks:SetScript("OnHide", function()
    for i = 1, 8 do
        markButtons[i].locked = nil
        if markButtons[i].ticker then
            markButtons[i].ticker:Cancel()
            markButtons[i].ticker = nil
        end
        markButtons[i]:SetBackdropBorderColor(0, 0, 0, 1)
    end
end)

-------------------------------------------------
-- fade out
-------------------------------------------------
local buttons = {}
for _, b in pairs(markButtons) do
    tinsert(buttons, b)
end
A.ApplyFadeInOutToParent(marksFrame, function()
    return CellDB["tools"]["fadeOut"] and not marksFrame.moverText:IsShown()
end, unpack(buttons))

-------------------------------------------------
-- functions
-------------------------------------------------
local function Rearrange(marksConfig)
    local scaled20 = P.Scale(20)

    --! WotLK fix: остался только режим "по цели" - ветки ^world и both вырезаны
    --! вместе с фреймом. Строка режима по-прежнему несёт ориентацию (_h/_v),
    --! поэтому разбор по суффиксу сохранён как был.
    if strfind(marksConfig, "_h$") then
        local width = scaled20 * 9 + P.Scale(2) * 8

        marks:SetSize(width, scaled20)
        marksFrame:SetSize(width, P.Scale(40))
        P.ClearPoints(marks)
        P.Point(marks, "BOTTOMLEFT")

        -- repoint each button
        for i = 1, 9 do
            P.ClearPoints(markButtons[i])
            if i == 1 then
                P.Point(markButtons[i], "TOPLEFT")
            else
                P.Point(markButtons[i], "TOPLEFT", markButtons[i-1], "TOPRIGHT", 2, 0)
            end
        end
    elseif strfind(marksConfig, "_v$") then
        local height = scaled20 * 9 + P.Scale(2) * 8

        marks:SetSize(scaled20, height)
        marksFrame:SetSize(scaled20, height + scaled20)
        P.ClearPoints(marks)
        P.Point(marks, "BOTTOMLEFT")

        -- repoint each button
        for i = 1, 9 do
            P.ClearPoints(markButtons[i])
            if i == 1 then
                P.Point(markButtons[i], "TOPLEFT")
            else
                P.Point(markButtons[i], "TOPLEFT", markButtons[i-1], "BOTTOMLEFT", 0, -2)
            end
        end
    end
end

local function CheckPermission()
    if InCombatLockdown() then
        marksFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        marksFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        NormalizeMarksMode() --! WotLK fix
        if CellDB["tools"]["marks"][1] then
            --! WotLK fix: единственный оставшийся режим - метки по цели.
            if marksFrame.moverText:IsShown() or Cell.vars.hasPartyMarkPermission then
                marks:Show()
            else
                marks:Hide()
            end

            -- override
            if Cell.vars.groupType == "solo" and CellDB["tools"]["marks"][2] then
                marks:Show()
            end

            Rearrange(CellDB["tools"]["marks"][3])
        else
            marks:Hide()
        end
    end
end

marksFrame:SetScript("OnEvent", function()
    CheckPermission()
end)

Cell.RegisterCallback("PermissionChanged", "RaidMarks_PermissionChanged", CheckPermission)

local function UpdateTools(which)
    F.Debug("|cffBBFFFFUpdateTools:|r", which)
    if not which or which == "marks" then
        CheckPermission()
        ShowMover(Cell.vars.showMover and CellDB["tools"]["marks"][1])
    end

    if not which or which == "fadeOut" then
        if CellDB["tools"]["fadeOut"] and not marksFrame.moverText:IsShown() then
            marksFrame:SetAlpha(0)
        else
            marksFrame:SetAlpha(1)
        end
    end

    if not which then -- position
        P.LoadPosition(marksFrame, CellDB["tools"]["marks"][4])
    end
end
Cell.RegisterCallback("UpdateTools", "RaidMarks_UpdateTools", UpdateTools)

local function UpdatePixelPerfect()
    -- P.Resize(marksFrame)
    -- P.Resize(marks)
    P.Repoint(marks) -- only marks needs to repoint

    for i = 1, 9 do
        markButtons[i]:UpdatePixelPerfect()
        P.Repoint(markButtons[i].texture)
    end
end
Cell.RegisterCallback("UpdatePixelPerfect", "Marks_UpdatePixelPerfect", UpdatePixelPerfect)
