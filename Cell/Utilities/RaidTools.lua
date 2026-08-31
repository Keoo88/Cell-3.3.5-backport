local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local U = Cell.uFuncs
local P = Cell.pixelPerfectFuncs
local LCG = LibStub("LibCustomGlow-1.0-Cell")

-------------------------------------------------
-- raid tools
-------------------------------------------------
local rtPane, unlockBtn
local reportCB, buffCB, buffDropdown, buffGlowCB, buffMineOnlyCB, buffHideInCombatCB, sizeEditBox, buffButtons, readyPullCB, styleDropdown, pullDropdown, secEditBox, marksBarCB, marksDropdown, marksShowSoloCB, fadeOutToolsCB

-------------------------------------------------
-- mover toggle
-------------------------------------------------
--! WotLK fix: раньше режим мувера жил только внутри OnClick кнопки Unlock, а сама
--! кнопка лежит в rtPane - Options > наведение на Utilities > Raid Tools. В бою этот
--! пейн целиком закрыт combat-маской (F.ApplyCombatProtectionToFrame ниже), то есть
--! добраться до тумблера нельзя вообще. Плюс кнопка создаётся лениво, при первом
--! показе пейна, поэтому внешний код не мог её дёрнуть. Вынесено в U.SetMoverShown:
--! один вход для кнопки и для /cell unlock, состояние кнопки подтягивается, когда
--! пейн наконец создан, - текст и глоу больше не расходятся со реальным состоянием.
local function UpdateUnlockButton()
    if not unlockBtn then return end
    if Cell.vars.showMover then
        unlockBtn:SetText(L["Lock"])
        unlockBtn.locked = false
        LCG.PixelGlow_Start(unlockBtn, {0,1,0,1}, 9, 0.25, 8, 1)
    else
        unlockBtn:SetText(L["Unlock"])
        unlockBtn.locked = true
        LCG.PixelGlow_Stop(unlockBtn)
    end
end

function U.SetMoverShown(show, silent)
    if show == nil then show = not Cell.vars.showMover end
    show = show and true or false

    Cell.vars.showMover = show
    UpdateUnlockButton()
    Cell.Fire("ShowMover", show)

    if not silent then
        if show then
            local names = {}
            if CellDB["tools"]["marks"][1] then table.insert(names, L["Marks Bar"]) end
            if CellDB["tools"]["readyAndPull"][1] then table.insert(names, L["ReadyCheck and PullTimer buttons"]) end
            if CellDB["tools"]["buffTracker"][1] then table.insert(names, L["Buff Tracker"]) end
            if #names == 0 then
                F.Print(L["Mover is on, but no tool is enabled - turn one on in Raid Tools first."])
            else
                F.Print(L["Mover is on: %s. Drag the green frame, then /cell lock."]:format(table.concat(names, ", ")))
            end
        else
            F.Print(L["Mover is off."])
        end
    end

    return show
end

local function CreateRTPane()
    rtPane = Cell.CreateTitledPane(Cell.frames.utilitiesTab, L["Raid Tools"].." |cFF777777"..L["only in group"], 422, 167)
    rtPane:SetPoint("TOPLEFT", 5, -5)
    rtPane:SetPoint("BOTTOMRIGHT", -5, 5)

    unlockBtn = Cell.CreateButton(rtPane, L["Unlock"], "accent", {77, 17})
    unlockBtn:SetPoint("TOPRIGHT", rtPane)
    unlockBtn.locked = true
    unlockBtn:SetScript("OnClick", function(self)
        U.SetMoverShown(self.locked)
    end)
    unlockBtn:HookScript("OnEnter", function()
        CellTooltip:SetOwner(unlockBtn, "ANCHOR_TOPRIGHT", 0, 2)
        CellTooltip:AddLine(L["Unlock"])
        --! WotLK fix: подсказка про слэш - в бою этот пейн под combat-маской,
        --! и кнопка недостижима; /cell unlock работает всегда.
        CellTooltip:AddLine("|cffffffff"..L["Also available as |cFFFFB5C5/cell unlock|r - works in combat too"])
        CellTooltip:Show()
    end)
    unlockBtn:HookScript("OnLeave", function()
        CellTooltip:Hide()
    end)
    UpdateUnlockButton()

    --! WotLK fix: галки "Battle Res Timer" и под ней "Detached" убраны с экрана
    --! (разрешение заказчика от 2026-08-19). Боевое воскрешение с зарядами и таймером -
    --! механика ретейла, на 3.3.5 её нет вообще: чекбокс и так стоял намертво выключенным
    --! (resCB:SetEnabled(false)), а его Cell.Fire("UpdateTools", "battleResTimer") не имел
    --! ни одного подписчика - настройка писалась в базу и не делала ничего. Вместе с ними
    --! ушёл дефолт CellDB["tools"]["battleResTimer"] из Core_Wrath.lua и его зеркало в
    --! Revise.lua. Death Report занял верхнюю строку пейна, весь остальной столбец
    --! привязан к нему цепочкой и поднялся сам.

    -- death report
    reportCB = Cell.CreateCheckButton(rtPane, L["Death Report"], function(checked, self)
        CellDB["tools"]["deathReport"][1] = checked
        Cell.Fire("UpdateTools", "deathReport")
    end)
    reportCB:SetPoint("TOPLEFT", rtPane, "TOPLEFT", 5, -27)
    reportCB:HookScript("OnEnter", function()
        CellTooltip:SetOwner(reportCB, "ANCHOR_TOPLEFT", 0, 2)
        CellTooltip:AddLine(L["Death Report"].." |cffff2727"..L["HIGH CPU USAGE"])
        CellTooltip:AddLine("|cffff2727" .. L["Disabled in battlegrounds and arenas"])
        CellTooltip:AddLine("|cffffffff" .. L["Report deaths to group"])
        CellTooltip:AddLine("|cffffffff" .. L["Use |cFFFFB5C5/cell report X|r to set the number of reports during a raid encounter"])
        CellTooltip:AddLine("|cffffffff" .. L["Current"]..": |cFFFFB5C5"..(CellDB["tools"]["deathReport"][2]==0 and L["all"] or string.format(L["first %d"], CellDB["tools"]["deathReport"][2])))
        CellTooltip:Show()
    end)
    reportCB:HookScript("OnLeave", function()
        CellTooltip:Hide()
    end)

    -- buff tracker
    buffCB = Cell.CreateCheckButton(rtPane, L["Buff Tracker"], function(checked, self)
        CellDB["tools"]["buffTracker"][1] = checked
        buffDropdown:SetEnabled(checked)
        sizeEditBox:SetEnabled(checked)
        buffGlowCB:SetEnabled(checked) --! WotLK fix
        buffMineOnlyCB:SetEnabled(checked) --! WotLK feature
        buffHideInCombatCB:SetEnabled(checked) --! WotLK feature
        if buffButtons then
            for buff, b in pairs(buffButtons) do
                b:SetEnabled(checked)
            end
        end
        Cell.Fire("UpdateTools", "buffTracker")
    end, L["Buff Tracker"].." |cffff7727"..L["MODERATE CPU USAGE"], L["Check if your group members need some raid buffs"],
    --! Ретейл-ветка подсказки вырезана: на 3.3.5 всегда вариант с Shift.
    "|cffffb5c5(Shift)|r "..L["|cffffb5c5Left-Click:|r cast the spell"],
    L["|cffffb5c5Right-Click:|r report unaffected"])
    -- L["Use |cFFFFB5C5/cell buff X|r to set icon size"],
    -- "|cffffffff" .. L["Current"]..": |cFFFFB5C5"..CellDB["tools"]["buffTracker"][3])
    buffCB:SetPoint("TOPLEFT", reportCB, "BOTTOMLEFT", 0, -15)

    buffDropdown = Cell.CreateDropdown(rtPane, 120)
    buffDropdown:SetPoint("TOPLEFT", buffCB, "BOTTOMRIGHT", 5, -5)
    buffDropdown:SetItems({
        {
            ["text"] = L["left-to-right"],
            ["value"] = "left-to-right",
            ["onClick"] = function()
                CellDB["tools"]["buffTracker"][2] = "left-to-right"
                Cell.Fire("UpdateTools", "buffTracker")
            end,
        },
        {
            ["text"] = L["right-to-left"],
            ["value"] = "right-to-left",
            ["onClick"] = function()
                CellDB["tools"]["buffTracker"][2] = "right-to-left"
                Cell.Fire("UpdateTools", "buffTracker")
            end,
        },
        {
            ["text"] = L["top-to-bottom"],
            ["value"] = "top-to-bottom",
            ["onClick"] = function()
                CellDB["tools"]["buffTracker"][2] = "top-to-bottom"
                Cell.Fire("UpdateTools", "buffTracker")
            end,
        },
        {
            ["text"] = L["bottom-to-top"],
            ["value"] = "bottom-to-top",
            ["onClick"] = function()
                CellDB["tools"]["buffTracker"][2] = "bottom-to-top"
                Cell.Fire("UpdateTools", "buffTracker")
            end,
        },
    })

    sizeEditBox = Cell.CreateEditBox(rtPane, 38, 20, false, false, true)
    sizeEditBox:SetPoint("TOPLEFT", buffDropdown, "TOPRIGHT", 5, 0)
    sizeEditBox:SetMaxLetters(3)

    sizeEditBox.confirmBtn = Cell.CreateButton(rtPane, "OK", "accent", {27, 20})
    sizeEditBox.confirmBtn:SetPoint("TOPLEFT", sizeEditBox, "TOPRIGHT", P.Scale(-1), 0)
    sizeEditBox.confirmBtn:Hide()
    sizeEditBox.confirmBtn:SetScript("OnHide", function()
        sizeEditBox.confirmBtn:Hide()
    end)
    sizeEditBox.confirmBtn:SetScript("OnClick", function()
        CellDB["tools"]["buffTracker"][3] = tonumber(sizeEditBox:GetText())
        Cell.Fire("UpdateTools", "buffTracker")
        sizeEditBox.confirmBtn:Hide()
        sizeEditBox:ClearFocus()
    end)

    sizeEditBox:SetScript("OnTextChanged", function(self, userChanged)
        if userChanged then
            local newSize = tonumber(self:GetText())
            if newSize and newSize > 0 and newSize ~= CellDB["tools"]["buffTracker"][3] then
                sizeEditBox.confirmBtn:Show()
            else
                sizeEditBox.confirmBtn:Hide()
            end
        end
    end)

    --! Guard по флейворам вырезан - на 3.3.5 (isWrath=true) он всегда истина.
    buffButtons = {}

    local buffOrder, buffs = U.GetBuffTrackerInfo()

    local last
    for i, buff in ipairs(buffOrder) do
        local b = Cell.CreateButton(rtPane, "", "accent-hover", {20, 20})
        buffButtons[buff] = b

        local tex = b:CreateTexture(nil, "ARTWORK")
        P.Point(tex, "TOPLEFT", b, "TOPLEFT", 1, -1)
        P.Point(tex, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        tex:SetTexture(buffs[buff]["buff1"]["icon"])
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        b:SetScript("OnEnable", function()
            tex:SetDesaturated(false)
        end)
        b:SetScript("OnDisable", function()
            tex:SetDesaturated(true)
        end)

        b:SetScript("OnClick", function()
            CellDB["tools"]["buffTracker"][5][buff] = not CellDB["tools"]["buffTracker"][5][buff]
            Cell.Fire("UpdateTools", "buffTracker")
            if CellDB["tools"]["buffTracker"][5][buff] then
                b:SetAlpha(1)
            else
                b:SetAlpha(0.25)
            end
        end)

        if last then
            b:SetPoint("TOPLEFT", last, "TOPRIGHT", 2, 0)
        else
            b:SetPoint("TOPLEFT", sizeEditBox.confirmBtn, "TOPRIGHT", 5, 0)
        end

        last = b
    end

    --! WotLK fix: тумблер мигающей рамки на иконке Buff Tracker-а.
    --! Раньше глоу включался жёстко, когда баффа нет на самом игроке, и погасить его
    --! можно было только выключив Buff Tracker целиком - то есть потеряв и счётчик,
    --! и кнопки каста. Теперь это отдельная настройка (buffTracker[6]): иконка,
    --! счётчик и затемнение остаются, уходит только мигание.
    buffGlowCB = Cell.CreateCheckButton(rtPane, L["Glow when you are missing the buff"], function(checked, self)
        CellDB["tools"]["buffTracker"][6] = checked
        Cell.Fire("UpdateTools", "buffTracker")
    end, L["Glow when you are missing the buff"], L["The icon and the counter stay either way"])
    buffGlowCB:SetPoint("TOPLEFT", buffCB, "BOTTOMRIGHT", 5, -28)

    --! WotLK feature: следить только за бафами своего класса (buffTracker[7]) - так же,
    --! как это делает VuhDo. На присте в трекере остаются выносливость и дух, на маге -
    --! интеллект, а благословения паладина уходят: кликом их всё равно не наложить.
    --! Класс, который из этого списка не даёт ничего (шаман, разбойник, воин, охотник,
    --! рыцарь смерти, чернокнижник), фильтр не трогает - иначе полоса стала бы пустой.
    buffMineOnlyCB = Cell.CreateCheckButton(rtPane, L["Only track buffs of your class"], function(checked, self)
        CellDB["tools"]["buffTracker"][7] = checked
        Cell.Fire("UpdateTools", "buffTracker")
    end, L["Only track buffs of your class"],
    L["A priest tracks Fortitude and Spirit, a mage tracks Intellect"],
    L["Classes that provide none of these keep the whole list"])
    buffMineOnlyCB:SetPoint("TOPLEFT", buffCB, "BOTTOMRIGHT", 5, -46)

    --! WotLK feature: "hide in combat" (buffTracker[8]), asked for by the tester, who
    --! keeps RaidBuffStatus alongside Cell. Buffs are handed out before the pull, so
    --! during the fight the bar and the Missing Buffs icons only cover the raid frames.
    --! The UNIT_AURA subscription goes away with the picture - see UpdateHideInCombat
    --! in Utilities/BuffTracker_Classic.lua.
    --! The label reuses the existing "hideInCombat" key, translated in all 11 locales.
    buffHideInCombatCB = Cell.CreateCheckButton(rtPane, L["hideInCombat"], function(checked, self)
        CellDB["tools"]["buffTracker"][8] = checked
        Cell.Fire("UpdateTools", "buffTracker")
    end, L["hideInCombat"],
    L["The bar and the Missing Buffs icons come back when the fight ends"],
    L["Aura scanning stops as well, so this also saves CPU during a fight"])
    buffHideInCombatCB:SetPoint("TOPLEFT", buffCB, "BOTTOMRIGHT", 5, -64)

    -- ready & pull
    readyPullCB = Cell.CreateCheckButton(rtPane, L["ReadyCheck and PullTimer buttons"], function(checked, self)
        CellDB["tools"]["readyAndPull"][1] = checked
        styleDropdown:SetEnabled(checked)
        pullDropdown:SetEnabled(checked)
        secEditBox:SetEnabled(checked)
        Cell.Fire("UpdateTools", "buttons")
    end, L["ReadyCheck and PullTimer buttons"], L["Only show when you have permission to do this"], L["readyCheckTips"], L["pullTimerTips"])
    --! WotLK fix: было -43, освободили строку под buffGlowCB (см. выше).
    --! WotLK feature: и ещё строку под buffMineOnlyCB, поэтому -63 стало -68.
    --! WotLK feature: и третью строку под buffHideInCombatCB, поэтому -68 стало -86.
    readyPullCB:SetPoint("TOPLEFT", buffCB, "BOTTOMLEFT", 0, -86)
    Cell.RegisterForCloseDropdown(readyPullCB)

    styleDropdown = Cell.CreateDropdown(rtPane, 120)
    styleDropdown:SetPoint("TOPLEFT", readyPullCB, "BOTTOMRIGHT", 5, -5)
    styleDropdown:SetItems({
        {
            ["text"] = L["Ready"].." / "..L["Pull"],
            ["value"] = "text_button",
            ["onClick"] = function()
                CellDB["tools"]["readyAndPull"][2] = "text_button"
                Cell.Fire("UpdateTools", "readyAndPull")
            end,
        },
        {
            ["text"] = "|TInterface\\AddOns\\Cell\\Media\\Icons\\ready:14|t / |TInterface\\AddOns\\Cell\\Media\\Icons\\pull:14|t A",
            ["value"] = "icon_button_h",
            ["onClick"] = function()
                CellDB["tools"]["readyAndPull"][2] = "icon_button_h"
                Cell.Fire("UpdateTools", "readyAndPull")
            end,
        },
        {
            ["text"] = "|TInterface\\AddOns\\Cell\\Media\\Icons\\ready:14|t / |TInterface\\AddOns\\Cell\\Media\\Icons\\pull:14|t B",
            ["value"] = "icon_button_v",
            ["onClick"] = function()
                CellDB["tools"]["readyAndPull"][2] = "icon_button_v"
                Cell.Fire("UpdateTools", "readyAndPull")
            end,
        },
    })

    pullDropdown = Cell.CreateDropdown(rtPane, 109)
    pullDropdown:SetPoint("TOPLEFT", styleDropdown, "TOPRIGHT", 5, 0)
    pullDropdown:SetItems({
        {
            ["text"] = L["Default"],
            ["value"] = "default",
            ["onClick"] = function()
                CellDB["tools"]["readyAndPull"][3][1] = "default"
                Cell.Fire("UpdateTools", "readyAndPull")
            end,
        },
        {
            ["text"] = "MRT",
            ["value"] = "mrt",
            ["onClick"] = function()
                CellDB["tools"]["readyAndPull"][3][1] = "mrt"
                Cell.Fire("UpdateTools", "readyAndPull")
            end,
        },
        {
            ["text"] = "DBM",
            ["value"] = "dbm",
            ["onClick"] = function()
                CellDB["tools"]["readyAndPull"][3][1] = "dbm"
                Cell.Fire("UpdateTools", "readyAndPull")
            end,
        },
        {
            ["text"] = "BigWigs",
            ["value"] = "bw",
            ["onClick"] = function()
                CellDB["tools"]["readyAndPull"][3][1] = "bw"
                Cell.Fire("UpdateTools", "readyAndPull")
            end,
        },
    })

    secEditBox = Cell.CreateEditBox(rtPane, 38, 20, false, false, true)
    secEditBox:SetPoint("TOPLEFT", pullDropdown, "TOPRIGHT", 5, 0)
    secEditBox:SetMaxLetters(3)

    secEditBox.confirmBtn = Cell.CreateButton(rtPane, "OK", "accent", {27, 20})
    secEditBox.confirmBtn:SetPoint("TOPLEFT", secEditBox, "TOPRIGHT", P.Scale(-1), 0)
    secEditBox.confirmBtn:Hide()
    secEditBox.confirmBtn:SetScript("OnHide", function()
        secEditBox.confirmBtn:Hide()
    end)
    secEditBox.confirmBtn:SetScript("OnClick", function()
        CellDB["tools"]["readyAndPull"][3][2] = tonumber(secEditBox:GetText())
        Cell.Fire("UpdateTools", "readyAndPull")
        secEditBox.confirmBtn:Hide()
    end)

    secEditBox:SetScript("OnTextChanged", function(self, userChanged)
        if userChanged then
            local newSec = tonumber(self:GetText())
            if newSec and newSec > 0 and newSec ~= CellDB["tools"]["readyAndPull"][3][2] then
                secEditBox.confirmBtn:Show()
            else
                secEditBox.confirmBtn:Hide()
            end
        end
    end)

    -- marks bar
    marksBarCB = Cell.CreateCheckButton(rtPane, L["Marks Bar"], function(checked, self)
        CellDB["tools"]["marks"][1] = checked
        marksDropdown:SetEnabled(checked)
        marksShowSoloCB:SetEnabled(checked)
        Cell.Fire("UpdateTools", "marks")
    end, L["Marks Bar"], L["Only show when you have permission to do this"], L["marksTips"])
    marksBarCB:SetPoint("TOPLEFT", readyPullCB, "BOTTOMLEFT", 0, -43)
    Cell.RegisterForCloseDropdown(marksBarCB)

    marksDropdown = Cell.CreateDropdown(rtPane, 217)
    marksDropdown:SetPoint("TOPLEFT", marksBarCB, "BOTTOMRIGHT", 5, -5)
    --! WotLK fix: четыре пункта World Marks (H/V) и Both (H/V) вырезаны вместе с
    --! самой веткой world-меток - на 3.3.5 её нет ни в API, ни в secure-типах,
    --! и раньше они висели в списке серыми (["disabled"] = true). Осталось два
    --! рабочих режима. Подробности - audit/STUDY_GAPS.md §2.23.
    marksDropdown:SetItems({
        {
            ["text"] = L["Target Marks"].." ("..L["Horizontal"]..")",
            ["value"] = "target_h",
            ["onClick"] = function()
                CellDB["tools"]["marks"][3] = "target_h"
                Cell.Fire("UpdateTools", "marks")
            end,
        },
        {
            ["text"] = L["Target Marks"].." ("..L["Vertical"]..")",
            ["value"] = "target_v",
            ["onClick"] = function()
                CellDB["tools"]["marks"][3] = "target_v"
                Cell.Fire("UpdateTools", "marks")
            end,
        }
    })

    marksShowSoloCB = Cell.CreateCheckButton(rtPane, L["Show Solo"], function(checked, self)
        CellDB["tools"]["marks"][2] = checked
        Cell.Fire("UpdateTools", "marks")
    end)
    marksShowSoloCB:SetPoint("TOPLEFT", marksDropdown, "BOTTOMLEFT", 0, -8)

    -- fadeOut
    fadeOutToolsCB = Cell.CreateCheckButton(rtPane, L["Fade Out These Buttons"], function(checked, self)
        CellDB["tools"]["fadeOut"] = checked
        Cell.Fire("UpdateTools", "fadeOut")
    end)
    fadeOutToolsCB:SetPoint("TOPLEFT", marksBarCB, "BOTTOMLEFT", 0, -70)

    local region = CreateFrame("Frame", nil, rtPane)
    region:SetPoint("TOPLEFT", buffCB, -5, 5)
    region:SetPoint("BOTTOM", marksShowSoloCB, 0, -5)
    region:SetPoint("RIGHT", -5, 0)

    fadeOutToolsCB:HookScript("OnEnter", function()
        LCG.PixelGlow_Start(region, Cell.GetAccentColorTable(1), 27, 0.1, 17, 1)
    end)
    fadeOutToolsCB:HookScript("OnLeave", function()
        LCG.PixelGlow_Stop(region)
    end)
end

-------------------------------------------------
-- show
-------------------------------------------------
local init
local function ShowUtilitySettings(which)
    if which == "raidTools" then
        if not init then
            CreateRTPane()
            F.ApplyCombatProtectionToFrame(rtPane, -4, 4, 4, -4)
        end

        rtPane:Show()

        -- if init then return end
        init = true

        -- raid tools
        reportCB:SetChecked(CellDB["tools"]["deathReport"][1])

        buffCB:SetChecked(CellDB["tools"]["buffTracker"][1])
        buffDropdown:SetSelectedValue(CellDB["tools"]["buffTracker"][2])
        sizeEditBox:SetText(CellDB["tools"]["buffTracker"][3])
        buffGlowCB:SetChecked(CellDB["tools"]["buffTracker"][6]) --! WotLK fix
        buffMineOnlyCB:SetChecked(CellDB["tools"]["buffTracker"][7]) --! WotLK feature
        buffHideInCombatCB:SetChecked(CellDB["tools"]["buffTracker"][8]) --! WotLK feature
        Cell.SetEnabled(CellDB["tools"]["buffTracker"][1], buffDropdown, sizeEditBox, buffGlowCB, buffMineOnlyCB, buffHideInCombatCB)
        if buffButtons then
            for buff, b in pairs(buffButtons) do
                b:SetEnabled(CellDB["tools"]["buffTracker"][1])
                b:SetAlpha(CellDB["tools"]["buffTracker"][5][buff] and 1 or 0.25)
            end
        end

        readyPullCB:SetChecked(CellDB["tools"]["readyAndPull"][1])
        styleDropdown:SetSelectedValue(CellDB["tools"]["readyAndPull"][2])
        pullDropdown:SetSelectedValue(CellDB["tools"]["readyAndPull"][3][1])
        secEditBox:SetText(CellDB["tools"]["readyAndPull"][3][2])
        Cell.SetEnabled(CellDB["tools"]["readyAndPull"][1], styleDropdown, pullDropdown, secEditBox)

        marksDropdown:SetEnabled(CellDB["tools"]["marks"][1])
        marksBarCB:SetChecked(CellDB["tools"]["marks"][1])
        marksDropdown:SetSelectedValue(CellDB["tools"]["marks"][3])
        marksShowSoloCB:SetChecked(CellDB["tools"]["marks"][2])

        fadeOutToolsCB:SetChecked(CellDB["tools"]["fadeOut"])

    elseif init then
        rtPane:Hide()
    end
end
Cell.RegisterCallback("ShowUtilitySettings", "RaidTools_ShowUtilitySettings", ShowUtilitySettings)
