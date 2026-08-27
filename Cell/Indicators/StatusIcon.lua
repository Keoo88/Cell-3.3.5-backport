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
    --! WotLK fix: путь к иконке воскрешения - у владельца Cell.vars.resurrectionTexture
    --! (Utils.lua). Прежний "Interface\RaidFrame\Raid-Icon-Rez" на 3.3.5 не существует,
    --! и текстура молча гасла - иконка Revive не появлялась.
    resurrectionIcon.tex:SetTexture(Cell.vars.resurrectionTexture)
    resurrectionIcon.tex:SetDesaturated(true)
    resurrectionIcon.tex:SetVertexColor(0.4, 0.4, 0.4, 0.5)

    --! WotLK fix: обратный отсчёт на иконке воскрешения не рисовался вообще.
    --! В ретейле яркая копия значка обрезается маской (CreateMaskTexture, 8.0+),
    --! а StatusBar под ней невидима (alpha 0) и служит только геометрией: заливка
    --! вертикальная и reverse, то есть идёт сверху вниз, а маска берёт полосу от
    --! низа заливки до низа значка - ярким показан ОСТАТОК времени, и он утекает
    --! вниз. На 3.3.5a нет ни CreateMaskTexture, ни SetReverseFill (проверено
    --! codex), поэтому от всей конструкции оставалась одна невидимая полоса:
    --! игрок видел ровный притушенный значок без отсчёта, а её OnUpdate крутился
    --! всё время показа и двигал значение, которое никто не рисует.
    --! Вырезан заодно и источник маски maskIcon: он висел на той полосе, то есть
    --! на дочернем фрейме, и его ARTWORK рисовался ПОВЕРХ resurrectionIcon.tex -
    --! живая текстура без маски дала бы значок в полную яркость поверх задуманного
    --! притушенного (0.4, 0.4, 0.4, 0.5). Обрезанная копия ниже такого не делает.
    --! Тот же кадр даёт нативная 8-аргументная форма SetTexCoord (ULx, ULy, LLx,
    --! LLy, URx, URy, LRx, LRy - есть на 3.3.5a): из текстуры вырезается нижняя
    --! полоса высотой в долю остатка, и такой же долей задаётся высота самой
    --! текстуры, поэтому её пиксели ложатся ровно на притушенный значок под ними.
    local fillIcon = resurrectionIcon:CreateTexture(nil, "ARTWORK")
    --! WotLK fix: внутри слоя порядок отрисовки задаётся sublevel'ом, а уже потом
    --! порядком создания. Четвёртого аргумента (sublevel) у CreateTexture на 3.3.5a
    --! нет - только (name, layer, inherits), - зато SetDrawLayer его принимает
    --! (проверено codex). Ставим явно: яркая копия обязана лежать ПОВЕРХ притушенного
    --! значка, и держать это на порядке создания текстур не надо.
    fillIcon:SetDrawLayer("ARTWORK", 1)
    fillIcon:SetTexture(Cell.vars.resurrectionTexture)
    fillIcon:SetPoint("BOTTOMLEFT")
    fillIcon:SetPoint("BOTTOMRIGHT")
    fillIcon:Hide()

    local fillStart, fillDuration

    local function UpdateFill()
        local height = resurrectionIcon:GetHeight()
        local progress = 1 - (GetTime() - fillStart) / fillDuration
        if progress <= 0 or not height or height == 0 then
            fillIcon:Hide()
            return
        end
        if progress > 1 then progress = 1 end
        fillIcon:SetHeight(height * progress)
        --! v текстуры растёт вниз, поэтому верхняя граница полосы - 1 - progress
        fillIcon:SetTexCoord(0, 1 - progress, 0, 1, 1, 1 - progress, 1, 1)
        fillIcon:Show()
    end

    --! WotLK perf: троттлинг 0.25 с и накопитель в локале замыкания - как было у
    --! убранной полосы (поле кадра стоило четыре хеш-лукапа за кадр, а драйвер
    --! крутится на полном фреймрейте всё время показа). Отдельный дочерний фрейм
    --! под OnUpdate не нужен: он живёт на самой иконке и останавливается вместе с
    --! ней, потому что скрытый фрейм OnUpdate не получает.
    local elapsedTime = 0
    resurrectionIcon:SetScript("OnUpdate", function(self, elapsed)
        if elapsedTime >= 0.25 then
            elapsedTime = 0
            if fillStart then UpdateFill() end
        end
        elapsedTime = elapsedTime + elapsed
    end)

    function resurrectionIcon:SetTimer(start, duration)
        resurrectionIcon:Hide() -- pause OnUpdate
        fillStart = start
        fillDuration = duration + 13 -- NOTE: texture gap (texcoord 0,1,0,1)
        elapsedTime = 0
        UpdateFill()
        resurrectionIcon:Show()
    end

    resurrectionIcon:SetScript("OnHide", function()
        fillIcon:Hide()
        fillStart, fillDuration = nil, nil
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
            --! WotLK fix: собственная копия иконки вместо клиентского
            --! Raid-Icon-Rez, которого на 3.3.5 нет (владелец пути - Utils.lua).
            icon:SetTexture(Cell.vars.resurrectionTexture)
            icon:SetTexCoord(0, 1, 0, 1)
            icon:Show()
        elseif button.states.hasRezDebuff or button.states.hasSoulstone then
            icon:SetVertexColor(0.6, 1, 0.6, 1)
            --! WotLK fix: то же, что веткой выше.
            icon:SetTexture(Cell.vars.resurrectionTexture)
            icon:SetTexCoord(0, 1, 0, 1)
            icon:Show()
        elseif button.states.BGFlag then
            --! WotLK fix: здесь была ветка фазировки - иконка
            --! "Interface\TargetingFrame\UI-PhasingIcon" для игрока не в твоей фазе.
            --! Снята целиком, два независимых основания.
            --! 1) Ассета в клиенте нет: audit/tools/mpq_probe.py даёт ABSENT по всем
            --!    23 архивам 3.3.5a (иконка появилась в 4.x вместе с самим фазингом).
            --!    SetTexture молча гасил бы текстуру - тот же класс, что GAP-063.
            --! 2) Условие всё равно недостижимо: фазировки на 3.3.5 не существует,
            --!    UnitInPhase нет ни в C-API (кодекс: НЕТ), ни во FrameXML, а приватная
            --!    Cell.UnitInPhase (Polyfills.lua) на голом клиенте возвращает true,
            --!    поэтому `not Cell.UnitInPhase(unit)` - всегда false.
            --! Условие стояло третьим в цепочке, то есть три вызова API на каждое
            --! обновление аур каждой кнопки ради заведомо пустого результата.
            --! Cell.UnitInPhase не трогаем: её зовёт проверка дальности в Utils.lua,
            --! и на кастомном ядре сервера натив может существовать.
            --! Вместе с веткой убран закомментированный черновик upstream с черепом
            --! UI-TargetingFrame-Skull: мёртвые состояния кнопка рисует сама.
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
