local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs
---@type PixelPerfectFuncs
local P = Cell.pixelPerfectFuncs
--! WotLK fix: realm normalization is private to Cell.
local GetNormalizedRealmName = Cell.GetNormalizedRealmName

--! WotLK fix: incoming resurrection state belongs to Cell's embedded
--! LibResComm consumer. Do not depend on a global retail polyfill or a
--! synthetic INCOMING_RESURRECT_CHANGED frame event, because standalone
--! !!!ClassicAPI may own different globals and WotLK has no native event.
local ResComm =
    LibStub
    and LibStub("LibResComm-1.0", true)

CELL_SUMMON_ICONS_ENABLED = false

-------------------------------------------------
-- event
-------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, id)
    --! WotLK fix: PARTY_MEMBER_ENABLE/DISABLE carry a numeric party index on
    --! 3.3.5, not the retail unit token. Refresh the matching party button;
    --! player has no numeric PARTY_MEMBER_* slot and receives other updates.
    local unit = type(id) == "number" and "party"..id or id
    if unit then
        F.HandleUnitButton("unit", unit, I.UpdateStatusIcon)
    end
end)

--! WotLK fix: LibResComm callbacks use different payload layouts:
--! ResStart(event, sender, endTime, targetName) and
--! ResEnd(event, sender, targetName, succeeded). Normalize the target here and
--! refresh matching Cell buttons directly instead of emulating a retail event.
local function UnitHasCellIncomingResurrection(unit)
    if not (ResComm and unit) then return false end

    local name = UnitName(unit)
    if not name then return false end

    return ResComm:IsUnitBeingRessed(name) and true or false
end

local statusIconEnabled

local function ResComm_TargetChanged(event, sender, arg2, arg3)
    if not statusIconEnabled then return end

    local target =
        event == "ResComm_ResStart"
        and arg3
        or arg2

    if not target then return end

    local handled = F.HandleUnitButton(
        "name",
        target,
        I.UpdateStatusIcon
    )

    --! WotLK fix: LibResComm communicates short names while Cell normally maps
    --! realm-qualified names. Try the opposite representation before using a
    --! controlled button scan as a last resort for stale/not-yet-seeded maps.
    if not handled then
        local alternate
        if strfind(target, "-", 1, true) then
            alternate = F.ToShortName(target)
        elseif GetNormalizedRealmName then
            local realm = GetNormalizedRealmName()
            if realm and realm ~= "" then
                alternate = target.."-"..realm
            end
        end

        if alternate then
            handled = F.HandleUnitButton(
                "name",
                alternate,
                I.UpdateStatusIcon
            )
        end
    end

    if not handled then
        local shortTarget = F.ToShortName(target)
        F.IterateAllUnitButtons(function(button)
            local unit = button.states and button.states.unit
            local unitName = unit and UnitName(unit)
            if unitName and F.ToShortName(unitName) == shortTarget then
                I.UpdateStatusIcon(button)
            end
        end)
    end
end

local resCallbackOwner = {}
if ResComm then
    ResComm.RegisterCallback(
        resCallbackOwner,
        "ResComm_ResStart",
        ResComm_TargetChanged
    )
    ResComm.RegisterCallback(
        resCallbackOwner,
        "ResComm_ResEnd",
        ResComm_TargetChanged
    )
end

local function DiedWithSoulstone(b)
    b.states.hasSoulstone = true
    I.UpdateStatusIcon(b)
end

local rez = {}
local soulstones = {}
local SOULSTONE = F.GetSpellInfo(20707)
--! WotLK fix: заклинание 160029 ("Resurrecting" - служебный дебафф ретейла, который
--! висит на игроке, пока он не ответил на воскрешение) на 3.3.5a не существует.
--! Проверено прямо в игре: print(GetSpellInfo(160029)) не вывел ничего.
--! Значит RESURRECTING всегда был nil, ветка сравнения с ним никогда не срабатывала,
--! а поиск ауры по этому id (см. I.UpdateStatusIcon_Resurrection ниже) был холостым
--! обходом всех 40 слотов. Обе мёртвые ветки убраны. Живой путь на 3.3.5 -
--! суб-событие боевого лога SPELL_RESURRECT, оно есть и обрабатывается ниже.

local cleuFrame = CreateFrame("Frame")
--! WotLK perf: named parameters instead of `...` plus a ten-slot vararg unpack. In
--! Lua 5.1 a function declaring `...` is a vararg function, so every call pays
--! adjust_varargs and then a VARARG copy back into registers - and this frame is
--! registered for COMBAT_LOG_EVENT_UNFILTERED, the most frequent event in the game.
--! Named parameters are already where the C caller left them.
cleuFrame:SetScript("OnEvent", function(_, event,
    timestamp, subEvent, sourceGUID, sourceName, sourceFlags,
    destGUID, destName, destFlags, spellId, spellName)

    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end
    --! WotLK fix: consume native 3.3.5 CLEU varargs directly. Cell's soulstone
    --! and resurrection state must not depend on a foreign ClassicAPI global
    --! translator or its retail-shaped synthetic slots.

    if subEvent == "SPELL_AURA_REMOVED" then
        if spellName == SOULSTONE then
            -- print("soulstone removed", timestamp, destName)
            soulstones[destGUID] = timestamp
            C_Timer.After(0.1, function()
                soulstones[destGUID] = nil
            end)
        end
    elseif subEvent == "UNIT_DIED" then
        -- print("died", timestamp, destName)
        if soulstones[destGUID] then
            F.HandleUnitButton("guid", destGUID, DiedWithSoulstone)
        end
        soulstones[destGUID] = nil
    elseif subEvent == "SPELL_RESURRECT" then
        local start, duration = GetTime(), 60
        --! WotLK fix (B11-D7): у rez[] не было надёжной очистки. Запись идёт по любому
        --! destGUID из боевого лога - в BG это чужие команды и соседние группы, для
        --! которых F.HandleUnitButton ниже выходит сразу (нет в Cell.vars.guids), и
        --! таймер очистки в I.UpdateStatusIcon_Resurrection не заводится никогда.
        --! Для своих запись тоже могла зависнуть: тот таймер живёт на иконке, а её
        --! OnHide (:254) его отменяет - хватает скрыть рамку или выключить индикатор.
        --! Поэтому срок жизни записи задаётся здесь же, при записи, и ни от чего больше
        --! не зависит. Сверка по идентичности таблицы: если за минуту пришло новое
        --! воскрешение того же игрока, старый таймер не должен стирать свежие данные.
        --! Гейт по Cell.vars.guids намеренно НЕ ставится: игрок мог быть поднят за
        --! секунду до входа в группу, и тогда его иконка должна ожить вместе с кнопкой.
        local entry = {start, duration}
        rez[destGUID] = entry
        C_Timer.After(duration, function()
            if rez[destGUID] == entry then
                rez[destGUID] = nil
            end
        end)

        F.HandleUnitButton("guid", destGUID, I.UpdateStatusIcon_Resurrection, start, duration)
    end
end)

-------------------------------------------------
-- create
-------------------------------------------------
function I.CreateStatusIcon(parent)
    local statusIcon = CreateFrame("Frame", parent:GetName().."StatusIcon", parent.widgets.indicatorFrame)
    parent.indicators.statusIcon = statusIcon
    statusIcon:Hide()

    --! WotLK fix: parent-alpha isolation is unavailable on 3.3.5.

    statusIcon.tex = statusIcon:CreateTexture(nil, "OVERLAY")
    statusIcon.tex:SetAllPoints(statusIcon)

    function statusIcon:SetTexture(tex)
        statusIcon.tex:SetTexture(tex)
    end

    function statusIcon:SetTexCoord(...)
        statusIcon.tex:SetTexCoord(...)
    end

    --! WotLK fix: обёртка statusIcon:SetAtlas удалена. Её никто не звал (все ветки
    --! I.UpdateStatusIcon ниже работают через SetTexture + SetTexCoord), а сам шим
    --! Texture:SetAtlas на 3.3.5 удалён за бесполезностью.

    function statusIcon:SetVertexColor(...)
        statusIcon.tex:SetVertexColor(...)
    end

    -- resurrection icon ----------------------------------
    local resurrectionIcon = CreateFrame("Frame", parent:GetName().."ResurrectionIcon", parent.widgets.indicatorFrame)
    parent.indicators.resurrectionIcon = resurrectionIcon
    resurrectionIcon:SetAllPoints(statusIcon)
    resurrectionIcon:Hide()

    resurrectionIcon.tex = resurrectionIcon:CreateTexture(nil, "ARTWORK")
    resurrectionIcon.tex:SetAllPoints(resurrectionIcon)
    -- 3.3.5: SetTexture resets desaturation state (see WeakAuras-WotLK
    -- FixTextureDesaturation), so SetTexture must come BEFORE SetDesaturated
    resurrectionIcon.tex:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
    resurrectionIcon.tex:SetDesaturated(true)
    resurrectionIcon.tex:SetVertexColor(0.4, 0.4, 0.4, 0.5)

    local bar = CreateFrame("StatusBar", nil, resurrectionIcon)
    bar:SetAllPoints(resurrectionIcon)
    bar:SetOrientation("VERTICAL")
    --! WotLK fix: the visible resurrection icon is timer-driven without a
    --! native reverse-fill surface; do not rely on a fake shared no-op method.
    bar:SetStatusBarTexture(Cell.vars.whiteTexture)
    --! WotLK fix: guard the texture on this Cell-owned bar locally instead of
    --! replacing native StatusBar methods for the entire client.
    local barTexture = bar:GetStatusBarTexture()
    if not barTexture then
        barTexture = bar:CreateTexture(nil, "ARTWORK")
        barTexture:SetTexture(Cell.vars.whiteTexture)
        bar:SetStatusBarTexture(barTexture)
    end
    barTexture:SetAlpha(0)
    --! WotLK perf: накопитель троттлинга переехал из поля кадра в локал
    --! замыкания. Поле `bar.elapsedTime` стоило четыре хеш-лукапа в таблице за
    --! кадр, а драйвер крутится на полном фреймрейте всё время, пока висит
    --! иконка воскрешения. Снаружи поле никто не читал - проверено грепом по
    --! Cell/, все обращения были в этих шести строках. Семантика прежняя:
    --! накопление по-прежнему идёт после проверки, то есть первый тик приходит
    --! кадром позже - так было и до правки.
    local elapsedTime = 0
    bar:SetScript("OnUpdate", function(self, elapsed)
        if elapsedTime >= 0.25 then
            self:SetValue(self:GetValue() + elapsedTime)
            elapsedTime = 0
        end
        elapsedTime = elapsedTime + elapsed
    end)

    --! WotLK 3.3.5a: CreateMaskTexture (8.0+) does not exist (проверено codex),
    --! маска и её применение к иконке воскрешения вырезаны вместе с ретейл-веткой.
    local maskIcon = bar:CreateTexture(nil, "ARTWORK")
    maskIcon:SetAllPoints(resurrectionIcon)
    maskIcon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")

    function resurrectionIcon:SetTimer(start, duration)
        resurrectionIcon:Hide() -- pause OnUpdate
        bar:SetMinMaxValues(0, duration + 13) -- NOTE: texture gap (texcoord 0,1,0,1)
        bar:SetValue(GetTime()-start)
        resurrectionIcon:Show()
    end

    resurrectionIcon:SetScript("OnHide", function()
        if resurrectionIcon.timer then
            resurrectionIcon.timer:Cancel()
            resurrectionIcon.timer = nil
        end
    end)
    -------------------------------------------------------

    statusIcon._SetFrameLevel = statusIcon.SetFrameLevel
    function statusIcon:SetFrameLevel(level)
        statusIcon:_SetFrameLevel(level)
        resurrectionIcon:SetFrameLevel(level)
    end
end

-------------------------------------------------
-- resurrection
-------------------------------------------------
function I.UpdateStatusIcon_Resurrection(button, start, duration)
    --! WotLK fix: resurrectionIcon - часть того же индикатора statusIcon: он
    --! создаётся, гасится и получает frame level вместе с ним, и в опциях это
    --! одна запись. Значит и гейт у него тот же. Зависшие записи rez[] поднять
    --! иконку при выключенном индикаторе больше не могут; сами они истекают по
    --! своему 60-секундному таймеру, который заводится в обработчике CLEU выше.
    if statusIconEnabled == false then return end

    local guid = button.states.guid
    local unit = button.states.unit
    local resurrectionIcon = button.indicators.resurrectionIcon

    if not (guid and unit) then
        resurrectionIcon:Hide()
        return
    end

    if not start then
        --! WotLK fix: проверка ауры по id 160029 убрана - этого заклинания нет на 3.3.5a,
        --! F.FindAuraById обходил бы все 40 слотов вхолостую. Единственный источник данных
        --! здесь - таблица rez[], которую заполняет SPELL_RESURRECT в обработчике CLEU выше.
        if rez[guid] then --! check saved data (unit button changed)
            start = rez[guid][1]
            duration = rez[guid][2]
        else
            resurrectionIcon:Hide()
            return
        end
    end

    --! alive or expired
    if not UnitIsDeadOrGhost(unit) or start + duration <= GetTime() then
        rez[guid] = nil
        resurrectionIcon:Hide()
        return
    end

    resurrectionIcon:SetTimer(start, duration)
    -- timer
    if resurrectionIcon.timer then resurrectionIcon.timer:Cancel() end
    resurrectionIcon.timer = C_Timer.NewTimer(start + duration - GetTime(), function()
        rez[guid] = nil
        resurrectionIcon:Hide()
    end)
end

-------------------------------------------------
-- update (UnitButton_UpdateAuras)
-------------------------------------------------
    function I.UpdateStatusIcon(button)
        local unit = button.states.unit
        if not unit then return end

        --! WotLK fix + perf: этот путь никогда не проверял, включён ли индикатор.
        --! Выключение гасило иконку только до следующего обновления аур, а
        --! UnitButton_UpdateBuffs выставляет states.BGFlag прямо перед вызовом
        --! сюда - поэтому на БГ иконка флага возвращалась при выключенном
        --! statusIcon. Гейт по тому же флагу, которым владеет I.EnableStatusIcon.
        --! Он же экономит пять ветвей условий на каждое обновление аур каждой
        --! кнопки (там ResComm-лукап по имени, UnitIsPlayer, UnitIsConnected,
        --! Cell.UnitInPhase) у всех, кто индикатор не использует.
        --! Hide() здесь не нужен: в выключенное состояние попадают только через
        --! I.EnableStatusIcon(false), а он гасит обе иконки на всех кнопках, и
        --! показать их больше некому - других потребителей этих фреймов нет.
        --! Сравнение именно с false, а не с nil: лейаут без записи statusIcon до
        --! I.EnableStatusIcon не доходит, и такой профиль должен сохранить прежнее
        --! поведение, а не потерять индикатор молча.
        if statusIconEnabled == false then return end

        local icon = button.indicators.statusIcon

        --! WotLK fix + perf: ветка LFG-глаза снята вместе с Cell.UnitInOtherParty.
        --! Она пришла из ретейльного CompactUnitFrame_UpdateCenterStatusIcon, но
        --! файла Interface\FrameXML\CompactUnitFrame.lua на 3.3.5 нет вовсе - он
        --! появился в 4.x. Самой UnitInOtherParty на этом клиенте тоже нет ни в
        --! C-API, ни во FrameXML, поэтому адаптер отдавал литеральный false и
        --! ветка была недостижима на любом клиенте. Её условие при этом стояло
        --! первым в цепочке, то есть вызов шёл на каждое обновление аур каждой
        --! кнопки у всех, кто индикатор включил.
        if UnitHasCellIncomingResurrection(unit) then
            icon:SetVertexColor(1, 1, 1, 1)
            icon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
            icon:SetTexCoord(0, 1, 0, 1)
            icon:Show()
        elseif button.states.hasRezDebuff or button.states.hasSoulstone then
            icon:SetVertexColor(0.6, 1, 0.6, 1)
            icon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
            icon:SetTexCoord(0, 1, 0, 1)
            icon:Show()
        elseif UnitIsPlayer(unit) and UnitIsConnected(unit) and not Cell.UnitInPhase(unit) and not button.states.inVehicle then
            icon:SetTexture("Interface\\TargetingFrame\\UI-PhasingIcon")
            icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
            icon:Show()
        -- elseif UnitIsDeadOrGhost(unit) then
        --     icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        --     icon:SetTexCoord(0, 1, 0, 1)
        --     icon:Show()
        elseif button.states.BGFlag then
            --! WotLK fix: 3.3.5 has no retail atlas escape names such as
            --! "horde_icon_and_flag-dynamicIcon". Use the native PvP flag
            --! textures shipped by the client instead of a silent empty atlas.
            icon:SetVertexColor(1, 1, 1, 1)
            icon:SetTexture(
                button.states.BGFlag == "horde"
                and "Interface\\WorldStateFrame\\HordeFlag"
                or "Interface\\WorldStateFrame\\AllianceFlag"
            )
            icon:SetTexCoord(0, 1, 0, 1)
            icon:Show()
        else
            icon:Hide()
        end
    end

-------------------------------------------------
-- enable
-------------------------------------------------
function I.EnableStatusIcon(enabled)
    --! WotLK fix: false, а не nil - это состояние теперь читают гейты в
    --! I.UpdateStatusIcon / I.UpdateStatusIcon_Resurrection, и им надо отличать
    --! "индикатор выключен" от "ещё ни разу не инициализирован". Для проверки
    --! ResComm выше (`if not statusIconEnabled`) разницы между false и nil нет.
    statusIconEnabled = enabled and true or false

    if enabled then
        --! WotLK fix: LibResComm callbacks above replace the non-native
        --! INCOMING_RESURRECT_CHANGED event.
        -- eventFrame:RegisterEvent("UNIT_PHASE") --! WotLK: event does not exist on 3.3.5 (added 4.x) - registration was silently inert, the phase icon never triggered this way
        eventFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
        eventFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
        -- resurrection
        cleuFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        eventFrame:UnregisterAllEvents()
        cleuFrame:UnregisterAllEvents()
        F.IterateAllUnitButtons(function(b)
            b.indicators.statusIcon:Hide()
            b.indicators.resurrectionIcon:Hide()
        end)
    end
end
