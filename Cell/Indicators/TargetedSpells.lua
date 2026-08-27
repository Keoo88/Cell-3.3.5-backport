local _, Cell = ...
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs
local LCG = LibStub("LibCustomGlow-1.0-Cell")

local UnitIsVisible = UnitIsVisible
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsUnit = UnitIsUnit
local UnitIsEnemy = UnitIsEnemy
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local GetSpellInfo = GetSpellInfo

-- NOTE: on 3.3.5a UnitCastingInfo/UnitChannelInfo return an extra "rank" as the 2nd value
-- and do NOT return spellId (it was added in 8.0). Resolve spellId by spell name instead.
-- Cell.vars.targetedSpellsList is recreated via F.ConvertTable on every change,
-- so the table reference is a reliable cache invalidation key.
local spellNameToId = {}
local cachedListRef

local function ResolveSpellId(name)
    local list = Cell.vars.targetedSpellsList
    if list ~= cachedListRef then
        cachedListRef = list
        wipe(spellNameToId)
        if list then
            for id in pairs(list) do
                local n = GetSpellInfo(id)
                if n then spellNameToId[n] = id end
            end
        end
    end
    return spellNameToId[name]
end

local casts = {}
local castsOnUnit, sortedCastsOnUnit = {}, {}
local recheck = {}
local maxIcons, showAllSpells
--! WotLK fix: собственный флаг включённости. Нужен пересчёту ниже, а спросить у
--! кадра нельзя дёшево: IsEventRegistered есть на 3.3.5 (проверено codex), но это
--! вызов на каждую проверку, а флаг ставится один раз в I.EnableTargetedSpells.
local isEnabled
local eventFrame = CreateFrame("Frame")

local function Reset()
    wipe(recheck)
    wipe(casts)
    wipe(castsOnUnit)
    wipe(sortedCastsOnUnit)
end

-------------------------------------------------
-- show / hide
-------------------------------------------------
local function HideCasts(b)
    b.indicators.targetedSpells:UpdateSize(0)
    b.indicators.targetedSpells:HideGlow()
end

local function ShowCasts(b, showGlow, sortedCasts, num)
    num = min(maxIcons, num)
    for i = 1, num do
        local cast = sortedCasts[i]
        b.indicators.targetedSpells[i].cooldown:SetReverse(not cast.isChanneling)
        b.indicators.targetedSpells[i]:SetCooldown(cast.startTime, cast.endTime-cast.startTime, cast.icon, cast.count)
    end
    b.indicators.targetedSpells:UpdateSize(num)

    if showGlow then
        b.indicators.targetedSpells:ShowGlow(unpack(Cell.vars.targetedSpellsGlow))
    else
        b.indicators.targetedSpells:HideGlow()
    end
end

-------------------------------------------------
-- update casts for guid
-------------------------------------------------
local function GetCastsOnUnit(guid)
    if castsOnUnit[guid] then
        wipe(castsOnUnit[guid])
        wipe(sortedCastsOnUnit[guid])
    else
        castsOnUnit[guid] = {}
        sortedCastsOnUnit[guid] = {}
    end

    local inListFound
    for sourceGUID, castInfo in pairs(casts) do
        if guid == castInfo["targetGUID"] then
            if castInfo["endTime"] > GetTime() then -- not expired
                local spellId = castInfo["spellId"]
                if not castsOnUnit[guid][spellId] then
                    castsOnUnit[guid][spellId] = {["count"] = 0}
                end
                if not castsOnUnit[guid][spellId]["endTime"] or castsOnUnit[guid][spellId]["endTime"] > castInfo["endTime"] then --! shorter duration
                    castsOnUnit[guid][spellId]["startTime"] = castInfo["startTime"]
                    castsOnUnit[guid][spellId]["endTime"] = castInfo["endTime"]
                    castsOnUnit[guid][spellId]["icon"] = castInfo["icon"]
                end
                castsOnUnit[guid][spellId]["count"] = castsOnUnit[guid][spellId]["count"] + 1

                if Cell.vars.targetedSpellsList[spellId] then
                    castsOnUnit[guid][spellId]["inList"] = true
                    inListFound = true
                end
            else
                casts[sourceGUID] = nil
            end
        end
    end

    return castsOnUnit[guid], inListFound
end

local function Comparator(a, b)
    if a.inList ~= b.inList then
        return a.inList
    end
    return a.startTime < b.startTime
end

local function UpdateCastsOnUnit(guid)
    if not guid then return end

    -- local startTime, endTime, spellId, icon, isChanneling
    local t, showGlow = GetCastsOnUnit(guid)

    for spellId, castInfo in pairs(t) do
        tinsert(sortedCastsOnUnit[guid], castInfo)

        -- if not endTime then --! init
        --     startTime, endTime, spellId, icon, isChanneling = castInfo["startTime"], castInfo["endTime"], castInfo["spellId"], castInfo["icon"], castInfo["isChanneling"]
        -- else
        --     spellId = castInfo["spellId"]
        --     if Cell.vars.targetedSpellsList[spellId] then --! [IN LIST]
        --         if not inListFound or endTime > castInfo["endTime"] then --! NOT FOUND BEFORE or SHORTER DURATION
        --             startTime, endTime, icon, isChanneling = castInfo["startTime"], castInfo["endTime"], castInfo["icon"], castInfo["isChanneling"]
        --         end
        --     elseif not inListFound and endTime > castInfo["endTime"] then --! [NOT IN LIST] NOT FOUND BEFORE and SHORTER DURATION
        --         startTime, endTime, icon, isChanneling = castInfo["startTime"], castInfo["endTime"], castInfo["icon"], castInfo["isChanneling"]
        --     end
        -- end

        -- if Cell.vars.targetedSpellsList[spellId] then
        --     inListFound = true
        -- end
    end

    local n = #sortedCastsOnUnit[guid]

    if n == 0 then
        F.HandleUnitButton("guid", guid, HideCasts)
    else
        table.sort(sortedCastsOnUnit[guid], Comparator)
        F.HandleUnitButton("guid", guid, ShowCasts, showGlow, sortedCastsOnUnit[guid], n)
    end
end

-------------------------------------------------
-- check if sourceUnit is casting
-------------------------------------------------
local function CheckUnitCast(sourceUnit, isRecheck)
    if not UnitIsEnemy("player", sourceUnit) then return end

    local sourceGUID = UnitGUID(sourceUnit)
    local targetGUID
    local previousTarget, isChanneling

    if casts[sourceGUID] then
        previousTarget = casts[sourceGUID]["targetGUID"]
        if casts[sourceGUID]["endTime"] <= GetTime() then
            --! expired
            casts[sourceGUID] = nil
            UpdateCastsOnUnit(previousTarget)
            previousTarget = nil
        end
    end

    -- NOTE: 3.3.5a returns: name, rank, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible (no spellId)
    local name, _, _, texture, startTimeMS, endTimeMS = UnitCastingInfo(sourceUnit)
    if not name then
        -- NOTE: 3.3.5a returns: name, rank, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible (no spellId)
        name, _, _, texture, startTimeMS, endTimeMS = UnitChannelInfo(sourceUnit)
        isChanneling = true
    end

    -- resolve spellId by name; for "show all spells" fall back to the name itself as the table key
    local spellId
    if name then
        spellId = ResolveSpellId(name) or (showAllSpells and name) or nil
    end

    -- print(sourceUnit, name, spellId)

    if spellId and (Cell.vars.targetedSpellsList[spellId] or showAllSpells) then
        if casts[sourceGUID] then
            casts[sourceGUID]["startTime"] = startTimeMS/1000
            casts[sourceGUID]["endTime"] = endTimeMS/1000
            casts[sourceGUID]["spellId"] = spellId
            casts[sourceGUID]["icon"] = texture
        else
            casts[sourceGUID] = {
                ["startTime"] = startTimeMS/1000,
                ["endTime"] = endTimeMS/1000,
                ["spellId"] = spellId,
                ["icon"] = texture,
                ["isChanneling"] = isChanneling,
                -- ["targetGUID"] = targetGUID,
                -- ["sourceUnit"] = sourceUnit,
                -- ["targetUnit"] = targetUnit,
                ["recheck"] = 0,
            }
        end

        local targetUnit = sourceUnit.."target"
        targetUnit = F.GetTargetUnitID(targetUnit) -- units in group (players/pets), no npcs
        if targetUnit then targetGUID = UnitGUID(targetUnit) end

        -- update spell target
        casts[sourceGUID]["targetUnit"] = targetUnit
        casts[sourceGUID]["targetGUID"] = targetGUID

        UpdateCastsOnUnit(targetGUID)

        if not isRecheck then
            if not recheck[sourceGUID] or not (strfind(sourceUnit, "target$") or strfind(sourceUnit, "^nameplate")) then
                recheck[sourceGUID] = sourceUnit
            end
            eventFrame:Show()
        end
    end

    if previousTarget and previousTarget ~= targetGUID then
        UpdateCastsOnUnit(previousTarget)
    end
end

-------------------------------------------------
-- list / glow changed
-------------------------------------------------
--! WotLK fix: смена списка заклинаний, настроек свечения или галки "show all spells"
--! раньше только переписывала Cell.vars.* / файловый локал, а экран оставался в
--! старом состоянии (последняя незакрытая часть GAP-029). Причина - casts заполняется
--! уже через фильтр (CheckUnitCast: заклинание в списке ИЛИ showAllSpells), поэтому
--! каст, начавшийся когда заклинания в списке ещё не было, в таблице отсутствует
--! вообще, а каст только что удалённого заклинания продолжает висеть до истечения.
--! Полная пересборка индикатора здесь запрещена, поэтому: выкидываем записи, которые
--! больше не проходят фильтр, перерисовываем затронутые кнопки и - только если фильтр
--! расширился - перечитываем источники, которые на 3.3.5 вообще можно назвать: свою
--! цель, фокус, наведение и цели группы. Кастера, которого никто не держит в цели,
--! взять негде: перечисления нейтлайтов на этом клиенте нет (NAME_PLATE_UNIT_ADDED -
--! это 7.0, см. комментарий в I.EnableTargetedSpells), такой каст подхватится
--! следующим UNIT_SPELLCAST_*.
local dirtyGUIDs = {}
local scanUnits = {"target", "focus", "mouseover"}

function I.RefreshTargetedSpells(rescanSources)
    if not isEnabled then return end

    wipe(dirtyGUIDs)
    local now = GetTime()

    for sourceGUID, castInfo in pairs(casts) do
        if castInfo["targetGUID"] then
            dirtyGUIDs[castInfo["targetGUID"]] = true
        end
        if castInfo["endTime"] <= now or not (showAllSpells or Cell.vars.targetedSpellsList[castInfo["spellId"]]) then
            casts[sourceGUID] = nil
            recheck[sourceGUID] = nil
        end
    end

    if rescanSources then
        --! CheckUnitCast сам отсеивает несуществующие и не враждебные юниты
        --! (UnitIsEnemy первой строкой), отдельная проверка UnitExists была бы
        --! вторым C-вызовом на тот же токен.
        for i = 1, #scanUnits do
            CheckUnitCast(scanUnits[i])
        end
        for unit in F.IterateGroupMembers() do
            CheckUnitCast(unit.."target")
        end
    end

    for guid in pairs(dirtyGUIDs) do
        UpdateCastsOnUnit(guid)
    end
end

-------------------------------------------------
-- recheck
-------------------------------------------------
eventFrame:Hide()

--! WotLK perf: накопитель троттлинга держится в файловом локале, а не в поле
--! кадра. Поле стоило три хеш-лукапа в таблице за кадр, а кадр этот - на полном
--! фреймрейте всё время, пока в очереди перепроверки есть хоть один каст.
--! Фрейм тут один на модуль, снаружи поле никто не читал (греп по Cell/).
local recheckElapsed = 0

eventFrame:SetScript("OnUpdate", function(self, elapsed)
    recheckElapsed = recheckElapsed + elapsed
    if recheckElapsed >= 0.1 then
        recheckElapsed = 0

        local empty = true

        for guid, unit in pairs(recheck) do
            --! WotLK perf: запись каста берётся из таблицы один раз за итерацию.
            --! Было шесть индексаций `casts[guid]` и два чтения `["targetUnit"]`
            --! на каждый элемент очереди. Ссылка живёт до конца итерации:
            --! единственное, что может подменить запись - CheckUnitCast, а он
            --! зовётся последним действием, после всех чтений.
            local cast = casts[guid]
            if cast then
                local tries = cast["recheck"] + 1
                cast["recheck"] = tries
                if tries >= 6 then
                    recheck[guid] = nil
                else
                    empty = false
                    --! WotLK perf: "<unit>target" склеивается один раз. На Lua 5.1
                    --! конкатенация - это интернирование строки, то есть хеш и
                    --! поиск в общей таблице строк, а не дешёвая склейка буфера.
                    local target = unit.."target"
                    local targetUnit = cast["targetUnit"]
                    local recheckRequired = (not targetUnit and UnitExists(target)) or (targetUnit and not UnitIsUnit(target, targetUnit))
                    if recheckRequired then
                        -- print(unit, tries, recheckRequired)
                        CheckUnitCast(unit, true)
                    end
                end
            else
                recheck[guid] = nil
            end
        end

        if empty then
            self:Hide()
        end
    end
end)

-------------------------------------------------
-- events
-------------------------------------------------
eventFrame:SetScript("OnEvent", function(_, event, sourceUnit)
    if sourceUnit and strfind(sourceUnit, "^soft") then return end

    if event == "PLAYER_TARGET_CHANGED" then
        CheckUnitCast("target")

    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        CheckUnitCast(sourceUnit)

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local sourceGUID = UnitGUID(sourceUnit)
        if casts[sourceGUID] then
            --! WotLK fix: было без local. Локальный previousTarget объявлен внутри
            --! CheckUnitCast выше и в этот обработчик не виден, так что запись уходила
            --! в глобал _G.previousTarget - на каждое прерывание каста любого врага.
            --! Cell не владеет глобалами; имя достаточно общее, чтобы им пользовался
            --! чужой аддон. Значение нужно только на следующей строке.
            local previousTarget = casts[sourceGUID]["targetGUID"]
            casts[sourceGUID] = nil
            UpdateCastsOnUnit(previousTarget)
        end
    end
end)

-------------------------------------------------
-- create
-------------------------------------------------
local function SetCooldown(frame, start, duration, icon, count)
    frame.duration:Hide()

    if count ~= 1 then
        frame.stack:Show()
        frame.stack:SetText(count)
    else
        frame.stack:Hide()
    end

    frame.border:Show()
    frame.cooldown:Show()
    --! WotLK fix: native 3.3.5 has no SetSwipeColor (проверено codex). The
    --! configured targeted-spell color remains on Cell's glow; use the native
    --! cooldown spiral here. Ретейл-ветка вырезана - это горячий путь.
    frame.cooldown:_SetCooldown(start, duration)
    frame.icon:SetTexture(icon)
    frame:Show()
end

local function SetFont(frame, ...)
    for i = 1, #frame do
        I.SetFont(frame[i].stack, frame[i], ...)
    end
end

local function ShowGlowPreview(frame)
    frame:ShowGlow(unpack(Cell.vars.targetedSpellsGlow))
end

local function ShowGlow(frame, glowType, color, arg1, arg2, arg3, arg4)
    if glowType == "Normal" then
        LCG.PixelGlow_Stop(frame.tsGlowFrame)
        LCG.AutoCastGlow_Stop(frame.tsGlowFrame)
        LCG.ProcGlow_Stop(frame.tsGlowFrame)
        LCG.ButtonGlow_Start(frame.tsGlowFrame, color)
    elseif glowType == "Pixel" then
        LCG.ButtonGlow_Stop(frame.tsGlowFrame)
        LCG.AutoCastGlow_Stop(frame.tsGlowFrame)
        LCG.ProcGlow_Stop(frame.tsGlowFrame)
        -- color, N, frequency, length, thickness
        LCG.PixelGlow_Start(frame.tsGlowFrame, color, arg1, arg2, arg3, arg4)
    elseif glowType == "Shine" then
        LCG.ButtonGlow_Stop(frame.tsGlowFrame)
        LCG.PixelGlow_Stop(frame.tsGlowFrame)
        LCG.ProcGlow_Stop(frame.tsGlowFrame)
        -- color, N, frequency, scale
        LCG.AutoCastGlow_Start(frame.tsGlowFrame, color, arg1, arg2, arg3)
    elseif glowType == "Proc" then
        LCG.ButtonGlow_Stop(frame.tsGlowFrame)
        LCG.PixelGlow_Stop(frame.tsGlowFrame)
        LCG.AutoCastGlow_Stop(frame.tsGlowFrame)
        -- color, duration
        LCG.ProcGlow_Start(frame.tsGlowFrame, {color=color, duration=arg1, startAnim=false})
    else
        LCG.ButtonGlow_Stop(frame.tsGlowFrame)
        LCG.PixelGlow_Stop(frame.tsGlowFrame)
        LCG.AutoCastGlow_Stop(frame.tsGlowFrame)
        LCG.ProcGlow_Stop(frame.tsGlowFrame)
    end
end

local function HideGlow(frame)
    LCG.ButtonGlow_Stop(frame.tsGlowFrame)
    LCG.PixelGlow_Stop(frame.tsGlowFrame)
    LCG.AutoCastGlow_Stop(frame.tsGlowFrame)
    LCG.ProcGlow_Stop(frame.tsGlowFrame)
end

function I.CreateTargetedSpells(parent)
    local targetedSpells = CreateFrame("Frame", parent:GetName().."TargetedSpellsParent", parent.widgets.indicatorFrame)
    parent.indicators.targetedSpells = targetedSpells
    targetedSpells:Hide()

    targetedSpells.tsGlowFrame = parent.widgets.tsGlowFrame
    targetedSpells._SetSize = targetedSpells.SetSize
    targetedSpells.SetSize = I.Cooldowns_SetSize
    targetedSpells.SetBorder = I.Cooldowns_SetBorder
    targetedSpells.UpdateSize = I.Cooldowns_UpdateSize_WithSpacing
    targetedSpells.SetOrientation = I.Cooldowns_SetOrientation_WithSpacing
    targetedSpells.ShowGlow = ShowGlow
    targetedSpells.HideGlow = HideGlow
    targetedSpells.SetFont = SetFont
    targetedSpells.ShowGlowPreview = ShowGlowPreview
    targetedSpells.HideGlowPreview = HideGlow

    for i = 1, 3 do
        local frame = I.CreateAura_BorderIcon(parent:GetName().."TargetedSpells"..i, targetedSpells, 2)
        tinsert(targetedSpells, frame)
        frame.SetCooldown = SetCooldown
        -- frame:SetScript("OnShow", targetedSpells.UpdateSize)
        -- frame:SetScript("OnHide", targetedSpells.UpdateSize)
        --! WotLK fix: OnCooldownDone is not a native 3.3.5 Cooldown script.
        --! Track completion only on this Cell-owned cooldown instance.
        I.SetCooldownDoneHandler(frame.cooldown, function()
            frame:Hide()
        end)
    end
end

-------------------------------------------------
-- functions
-------------------------------------------------
-- NOTE: in case there's a casting spell, hide!
local function EnterLeaveInstance()
    Reset()
    F.IterateAllUnitButtons(HideCasts, true)
end

function I.EnableTargetedSpells(enabled)
    isEnabled = enabled
    if enabled then
        F.IterateAllUnitButtons(function(b)
            b.indicators.targetedSpells:Show()
        end, true)

        -- UNIT_SPELLCAST_DELAYED UNIT_SPELLCAST_FAILED UNIT_SPELLCAST_INTERRUPTED UNIT_SPELLCAST_START UNIT_SPELLCAST_STOP
        -- UNIT_SPELLCAST_CHANNEL_START UNIT_SPELLCAST_CHANNEL_STOP
        -- PLAYER_TARGET_CHANGED ENCOUNTER_END

        eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")

        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        --! WotLK: NAME_PLATE_UNIT_* (7.0) do not exist on 3.3.5 - these registrations
        --! were silently inert (casts are still picked up via the UNIT_SPELLCAST_*
        --! events above). Kept as documentation of intent.
        -- eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        -- eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

        --! WotLK fix: ENCOUNTER_END does not exist on 3.3.5 either (added 5.4), so the
        --! list of incoming casts was never cleared when a fight ended - icons from the
        --! last attempt lingered until the next cast or instance change. Polyfills.lua
        --! bridges DBM's kill/wipe into Cell's own EncounterEnd callback.
        Cell.RegisterCallback("EncounterEnd", "TargetedSpells_EncounterEnd", EnterLeaveInstance)
        Cell.RegisterCallback("EnterInstance", "TargetedSpells_EnterInstance", EnterLeaveInstance)
        Cell.RegisterCallback("LeaveInstance", "TargetedSpells_LeaveInstance", EnterLeaveInstance)
    else
        Reset()
        eventFrame:Hide()
        eventFrame:UnregisterAllEvents()

        Cell.UnregisterCallback("EncounterEnd", "TargetedSpells_EncounterEnd")
        Cell.UnregisterCallback("EnterInstance", "TargetedSpells_EnterInstance")
        Cell.UnregisterCallback("LeaveInstance", "TargetedSpells_LeaveInstance")

        F.IterateAllUnitButtons(function(b)
            HideCasts(b)
            b.indicators.targetedSpells:Hide()
        end, true)
    end
end

function I.ShowAllTargetedSpells(showAll)
    --! WotLK fix: галка меняет тот же фильтр, что и список, поэтому её переключение
    --! обязано пересчитать экран. Пересчёт только на реальном изменении: эта же
    --! функция вызывается при применении раскладки (UnitButton_Cata_Wrath.lua:347),
    --! где сканировать источники не за чем. Сканируем только при включении - при
    --! выключении новых кастов появиться не может, нужна лишь чистка.
    local changed = isEnabled and showAll ~= showAllSpells
    showAllSpells = showAll
    if changed then
        I.RefreshTargetedSpells(showAll)
    end
end

function I.UpdateTargetedSpellsNum(num)
    --! WotLK fix: ползунок менял только границу maxIcons, а лишние иконки висели на
    --! экране до следующего каст-события (тот же класс, что GAP-029). Перерисовка без
    --! сканирования источников: фильтр не менялся, изменилось только сколько показывать.
    local changed = isEnabled and maxIcons and num ~= maxIcons
    maxIcons = num
    if changed then
        I.RefreshTargetedSpells()
    end
end
