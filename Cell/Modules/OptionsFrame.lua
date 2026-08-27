local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local PixelUtil = Cell.PixelUtil
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

local lastShownTab

local optionsFrame = Cell.CreateFrame("CellOptionsFrame", Cell.frames.mainFrame, 432, 401)
Cell.frames.optionsFrame = optionsFrame
PixelUtil.SetPoint(optionsFrame, "CENTER", CellParent, "CENTER", 1, -1)
optionsFrame:SetFrameStrata("DIALOG")
-- 3.3.5: frame level is capped at 128 (retail allows huge values like 520).
-- Values above the cap get clamped, collapsing ALL children/masks/popups into
-- one level and breaking draw order (backgrounds render on top of content).
-- Keep the base low so relative offsets (+30 mask, +50 popups, +60 combat
-- mask, +70/+75 confirm/notification popups) stay within the cap.
optionsFrame:SetFrameLevel(20)
optionsFrame:SetClampedToScreen(true)
optionsFrame:SetClampRectInsets(0, 0, 40, 0)
optionsFrame:SetMovable(true)

local function RegisterDragForOptionsFrame(frame)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        optionsFrame:StartMoving()
        optionsFrame:SetUserPlaced(false)
    end)
    frame:SetScript("OnDragStop", function()
        optionsFrame:StopMovingOrSizing()
        P.PixelPerfectPoint(optionsFrame)
        P.SavePosition(optionsFrame, CellDB["optionsFramePosition"])
    end)
end

-------------------------------------------------
-- button group
-------------------------------------------------
local generalBtn, appearanceBtn, clickCastingsBtn, aboutBtn, layoutsBtn, indicatorsBtn, debuffsBtn, utilitiesBtn, closeBtn
--! WotLK fix: все девять кнопок заголовка одним списком - его обходит колбэк смены
--! масштаба (см. UpdatePixelPerfect ниже). В группу переключения идут только восемь:
--! closeBtn ничего не выбирает, но рамку пересчитывать ему надо так же.
local tabButtons

local function CreateTabButtons()
    generalBtn = Cell.CreateButton(optionsFrame, L["General"], "accent-hover", {105, 20}, false, false, "CELL_FONT_WIDGET_TITLE", "CELL_FONT_WIDGET_TITLE_DISABLE")
    appearanceBtn = Cell.CreateButton(optionsFrame, L["Appearance"], "accent-hover", {105, 20}, false, false, "CELL_FONT_WIDGET_TITLE", "CELL_FONT_WIDGET_TITLE_DISABLE")
    layoutsBtn = Cell.CreateButton(optionsFrame, L["Layouts"], "accent-hover", {105, 20}, false, false, "CELL_FONT_WIDGET_TITLE", "CELL_FONT_WIDGET_TITLE_DISABLE")
    clickCastingsBtn = Cell.CreateButton(optionsFrame, L["Click-Castings"], "accent-hover", {120, 20}, false, false, "CELL_FONT_WIDGET_TITLE", "CELL_FONT_WIDGET_TITLE_DISABLE")
    indicatorsBtn = Cell.CreateButton(optionsFrame, L["Indicators"], "accent-hover", {105, 20}, false, false, "CELL_FONT_WIDGET_TITLE", "CELL_FONT_WIDGET_TITLE_DISABLE")
    debuffsBtn = Cell.CreateButton(optionsFrame, L["Raid Debuffs"], "accent-hover", {120, 20}, false, false, "CELL_FONT_WIDGET_TITLE", "CELL_FONT_WIDGET_TITLE_DISABLE")
    utilitiesBtn = Cell.CreateButton(optionsFrame, L["Utilities"], "accent-hover", {105, 20}, false, false, "CELL_FONT_WIDGET_TITLE", "CELL_FONT_WIDGET_TITLE_DISABLE")
    aboutBtn = Cell.CreateButton(optionsFrame, L["About"], "accent-hover", {86, 20}, false, false, "CELL_FONT_WIDGET_TITLE", "CELL_FONT_WIDGET_TITLE_DISABLE")
    -- Use ASCII X so localization/fonts on 3.3.5a don't swap the glyph (e.g., ruRU showing "ч").
    -- Use CELL_FONT_WIDGET_TITLE (GameFontNormal-based) instead of FONT_SPECIAL (symbol font) for ASCII support
    closeBtn = Cell.CreateButton(optionsFrame, "X", "red", {20, 20}, false, false, "CELL_FONT_WIDGET_TITLE", "CELL_FONT_WIDGET_TITLE_DISABLE")
    closeBtn:SetScript("OnClick", function()
        optionsFrame:Hide()
    end)

    -- line 1
    layoutsBtn:SetPoint("BOTTOMLEFT", optionsFrame, "TOPLEFT", 0, P.Scale(-1))
    indicatorsBtn:SetPoint("BOTTOMLEFT", layoutsBtn, "BOTTOMRIGHT", P.Scale(-1), 0)
    debuffsBtn:SetPoint("BOTTOMLEFT", indicatorsBtn, "BOTTOMRIGHT", P.Scale(-1), 0)
    utilitiesBtn:SetPoint("BOTTOMLEFT", debuffsBtn, "BOTTOMRIGHT", P.Scale(-1), 0)
    utilitiesBtn:SetPoint("BOTTOMRIGHT", optionsFrame, "TOPRIGHT", 0, P.Scale(-1))
    -- line 2
    generalBtn:SetPoint("BOTTOMLEFT", layoutsBtn, "TOPLEFT", 0, P.Scale(-1))
    appearanceBtn:SetPoint("BOTTOMLEFT", generalBtn, "BOTTOMRIGHT", P.Scale(-1), 0)
    clickCastingsBtn:SetPoint("BOTTOMLEFT", appearanceBtn, "BOTTOMRIGHT", P.Scale(-1), 0)
    aboutBtn:SetPoint("BOTTOMLEFT", clickCastingsBtn, "BOTTOMRIGHT", P.Scale(-1), 0)
    closeBtn:SetPoint("BOTTOMLEFT", aboutBtn, "BOTTOMRIGHT", P.Scale(-1), 0)
    closeBtn:SetPoint("BOTTOMRIGHT", utilitiesBtn, "TOPRIGHT", 0, P.Scale(-1))

    RegisterDragForOptionsFrame(generalBtn)
    RegisterDragForOptionsFrame(appearanceBtn)
    RegisterDragForOptionsFrame(layoutsBtn)
    RegisterDragForOptionsFrame(clickCastingsBtn)
    RegisterDragForOptionsFrame(indicatorsBtn)
    RegisterDragForOptionsFrame(debuffsBtn)
    RegisterDragForOptionsFrame(utilitiesBtn)
    RegisterDragForOptionsFrame(aboutBtn)

    generalBtn.id = "general"
    appearanceBtn.id = "appearance"
    layoutsBtn.id = "layouts"
    clickCastingsBtn.id = "clickCastings"
    indicatorsBtn.id = "indicators"
    debuffsBtn.id = "debuffs"
    utilitiesBtn.id = "utilities"
    aboutBtn.id = "about"

    local tabHeight = {
        ["general"] = 535,
        ["appearance"] = 665,
        ["layouts"] = 550,
        ["clickCastings"] = 592,
        ["indicators"] = 607,
        ["debuffs"] = 521,
        ["utilities"] = 400,
        ["about"] = 445,
    }

    local function ShowTab(tab)
        if lastShownTab ~= tab then
            P.Height(optionsFrame, tabHeight[tab])
            Cell.Fire("ShowOptionsTab", tab)
            lastShownTab = tab
        end
    end

    local function OnEnter(b)
        if b.id == utilitiesBtn.id then
            F.ShowUtilityList(b)
        else
            F.HideUtilityList()
        end
        if utilitiesBtn.timer then
            utilitiesBtn.timer:Cancel()
            utilitiesBtn.timer = nil
        end
    end

    local function OnLeave(b)
        if b.id == utilitiesBtn.id then
            utilitiesBtn.timer = C_Timer.NewTicker(0.5, function()
                if not F.IsUtilityListMouseover() then
                    F.HideUtilityList()
                    utilitiesBtn.timer:Cancel()
                    utilitiesBtn.timer = nil
                end
            end)
        end
    end

    tabButtons = {generalBtn, appearanceBtn, layoutsBtn, clickCastingsBtn, indicatorsBtn, debuffsBtn, utilitiesBtn, aboutBtn, closeBtn}
    Cell.CreateButtonGroup({generalBtn, appearanceBtn, layoutsBtn, clickCastingsBtn, indicatorsBtn, debuffsBtn, utilitiesBtn, aboutBtn}, ShowTab, nil, nil, OnEnter, OnLeave)
end

-------------------------------------------------
-- show & hide
-------------------------------------------------
local init
local function Init()
    if not init then
        init = true
        P.Resize(optionsFrame)
        P.Reborder(optionsFrame, true)
        CreateTabButtons()
        F.CreateUtilityList(utilitiesBtn)
    end
end

function F.ShowOptionsFrame()
    Init()

    if optionsFrame:IsShown() then
        optionsFrame:Hide()
        return
    end

    if not lastShownTab then
        generalBtn:Click()
    end

    optionsFrame:Show()
end

optionsFrame:SetScript("OnShow", function()
    if not P.LoadPosition(optionsFrame, CellDB["optionsFramePosition"]) then
        P.PixelPerfectPoint(optionsFrame)
    end
end)

--! WotLK fix: do not force a synchronous full-heap collection when the
--! options window closes. The normal incremental collector reclaims temporary
--! option data without turning one UI action into a frame stall.

-- optionsFrame:SetScript("OnShow", function()
--     P.PixelPerfectPoint(optionsFrame)
-- end)

-- for Raid Debuffs import
function F.ShowRaidDebuffsTab()
    Init()
    optionsFrame:Show()
    debuffsBtn:Click()
end

-- for layout import
function F.ShowLayousTab()
    Init()
    optionsFrame:Show()
    layoutsBtn:Click()
end

function F.ShowUtilitiesTab()
    Init()
    optionsFrame:Show()
    utilitiesBtn:Click()
end

-------------------------------------------------
-- InCombatLockdown
-------------------------------------------------
local protectedFrames = {}
function F.ApplyCombatProtectionToFrame(f, x1, y1, x2, y2)
    tinsert(protectedFrames, f)
    Cell.CreateCombatMask(f, x1, y1, x2, y2)

    if InCombatLockdown() then
        f.combatMask:Show()
    end

    f:HookScript("OnShow", function()
        if InCombatLockdown() then
            f.combatMask:Show()
        end
    end)
end

local protectedWidgets = {}
function F.ApplyCombatProtectionToWidget(widget)
    tinsert(protectedWidgets, widget)

    if InCombatLockdown() then
        widget:SetEnabled(false)
    end
end

optionsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
optionsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
optionsFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        for _, f in pairs(protectedFrames) do
            f.combatMask:Show()
        end
        for _, w in pairs(protectedWidgets) do
            w:SetEnabled(false)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        for _, f in pairs(protectedFrames) do
            f.combatMask:Hide()
        end
        for _, w in pairs(protectedWidgets) do
            w:SetEnabled(true)
        end
    end
end)

-------------------------------------------------
-- callbacks
-------------------------------------------------
local function UpdatePixelPerfect()
    P.Resize(optionsFrame)
    --! WotLK fix: размер тут пересчитывался, а рамка - нет. Толщина рамки это P.Scale(1),
    --! записанный Cell.StylizeFrame при СОЗДАНИИ кадра, когда у CellParent масштаба ещё нет
    --! (effective 1 -> 768/1080 = 0.7111); свой масштаб Cell ставит позже, в PLAYER_LOGIN
    --! (Core_Wrath.lua:1130 -> Appearance.lua:1867), а этот колбэк идёт следующей строкой
    --! (Core_Wrath.lua:1153) - то есть масштаб на этот момент уже верный и одного P.Reborder
    --! хватает. Дальше сюда же приходят все три триггера смены масштаба: ползунок Cell
    --! (Appearance.lua:31), ползунок масштаба в настройках видео Blizzard
    --! (hooksecurefunc("SetCVar"), Core_Wrath.lua:1191) и смена разрешения или размера окна
    --! (DISPLAY_SIZE_CHANGED, Core_Wrath.lua:1177). Единственный P.Reborder этого окна стоял
    --! в Init(), а тот за флагом `init` срабатывает один раз за сеанс. На экране: рамка окна
    --! настроек не совпадает по толщине с остальными рамками аддона и остаётся такой до
    --! /reload. Замерено прибором 1.9.16 в прогоне 2026-08-24: из шести осмотренных кадров
    --! дрейфовал ровно один, это окно - edgeSize 0.7111 против 0.8466 при масштабе 0.84
    --! (снимки zone_enter и stable, до первого открытия окна). В пикселях: edgeSize V даёт
    --! V * effectiveScale / (768/высота экрана) физических пикселей, то есть 0.7111 при
    --! масштабе 0.84 рисуется в 0.84 пикселя вместо ровно одного - линия тусклая и рваная.
    --! Вторая половина GAP-053: там починена сама P.Reborder, здесь - её отсутствующий вызов.
    --! Аргумент true такой же, как в Init(): снипет CELL_BORDER_SIZE правит рамки юнит-кнопок,
    --! а не это окно. Метод самого кадра (optionsFrame:UpdatePixelPerfect из Cell.CreateFrame)
    --! не годится - он зовёт Cell.StylizeFrame, а тот сбрасывает цвета фона и рамки в
    --! умолчания; P.Reborder снимает и возвращает оба цвета.
    P.Reborder(optionsFrame, true)

    --! WotLK fix: кнопок заголовка это касается ровно так же. Cell.CreateButton кладёт
    --! каждой кнопке бэкдроп с `edgeSize = P.Scale(1)` и такими же insets
    --! (Widgets.lua:643) и метод `b:UpdatePixelPerfect` (Widgets.lua:733), который
    --! пересобирает бэкдроп под текущий масштаб и возвращает оба цвета. Метод есть у
    --! каждой кнопки аддона, а звать его для этих девяти было некому - смену масштаба
    --! ловит только этот колбэк. На экране: рамка окна сходится (строка выше), а
    --! восемь вкладок и крестик остаются в прежней толщине - шов вдоль всего заголовка,
    --! заметнее, чем сама рамка. Обход детей, а не только родителя, - та же форма, что
    --! в RaidFrames/Groups/SpotlightFrame.lua:1152 и RaidFrames/MainFrame.lua:673.
    --! Список пуст до Init(): кнопки создаются при первом открытии окна, а до него
    --! пересчитывать нечего - родившись позже, они возьмут уже верный P.Scale(1).
    if tabButtons then
        for _, b in pairs(tabButtons) do
            b:UpdatePixelPerfect()
        end
    end
end
Cell.RegisterCallback("UpdatePixelPerfect", "OptionsFrame_UpdatePixelPerfect", UpdatePixelPerfect)
