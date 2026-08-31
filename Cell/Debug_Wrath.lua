--! WotLK fix: расширение отладки под 3.3.5a.
--!
--! Отдельный файл, а не правка Debug.lua — чтобы диф с upstream оставался чистым.
--! Грузится ПОСЛЕ Debug.lua и после Polyfills.lua.
--!
--! Команды закрывают те классы ошибок, которые аудит нашёл в этом бэкпорте:
--!   shims  — что слой совместимости переопределил поверх нативного API
--!   ret    — сколько значений РЕАЛЬНО возвращает функция на этом клиенте
--!   ev     — какие аргументы РЕАЛЬНО приходят в событии
--!   aura   — контракт UnitAura (в 3.3.5 ровно 11 возвратов, в ретейле 16+)
--!   perf   — перепись OnUpdate-обработчиков и прирост мусора
--!   err    — перехват ошибок Lua с трейсом, когда BugSack не стоит

local addonName, ns = ...
_G.Cell = _G.Cell or ns or {}
local Cell = _G.Cell

if not Cell.Debug then return end

local D = Cell.Debug
local format, tostring, type, select = string.format, tostring, type, select
local tinsert, tconcat = table.insert, table.concat

local C_HEAD = "|cFF00FF98"
local C_KEY = "|cFFFFB5C5"
local C_WARN = "|cFFFF6B6B"
local C_OK = "|cFF7FFF7F"
local C_OFF = "|r"

local function Say(msg)
    print("|cFF00CCFFCell|r " .. msg)
end

-- Считает возвраты ЗА ОДИН вызов, сохраняя хвостовые nil:
-- конструктор {...} их теряет, а select("#", ...) — нет.
local function Capture(ok, ...)
    return ok, select("#", ...), { ... }
end

local function Val(v)
    local t = type(v)
    if t == "string" then return format("%q", v)
    elseif t == "table" then return "table"
    elseif t == "function" then return "function"
    elseif v == nil then return C_WARN .. "nil" .. C_OFF
    end
    return tostring(v)
end

-------------------------------------------------
-- shims: что переопределено поверх нативного
-------------------------------------------------
-- Сравнивает текущее состояние с Cell.nativeSnapshot (снят до слоя совместимости).
-- ADDED      — метода/глобала в 3.3.5 не было, слой совместимости добавил его.
-- REMOVED    — существовавшее имя исчезло.
-- TYPE       — значение заменено значением другого типа.
-- OVERRIDDEN — значение заменено другим объектом того же типа. Для функций это
--              и есть невидимая ранее подмена function -> function.
local shimLiveWidgets

local function BuildShimLiveWidgets()
    if shimLiveWidgets then return shimLiveWidgets end

    --! WotLK fix: повторяем все категории зондов из DebugSnapshot.lua, а не только
    --! Frame/Texture/FontString. Объекты создаются лениво и один раз, чтобы каждая
    --! команда /cell debug shims не оставляла новую пачку неудаляемых Frame-объектов.
    local parent = CreateFrame("Frame")
    parent:Hide()
    parent:SetScript("OnShow", parent.Hide)

    local function Probe(frameType)
        local ok, obj = pcall(CreateFrame, frameType, nil, parent)
        if not ok or not obj then return nil end
        if obj.SetAutoFocus then obj:SetAutoFocus(false) end
        if obj.ClearFocus then obj:ClearFocus() end
        if obj.Hide then obj:Hide() end
        return obj
    end

    local frame = Probe("Frame")
    local live = {
        Frame = frame,
        Button = Probe("Button"),
        CheckButton = Probe("CheckButton"),
        EditBox = Probe("EditBox"),
        Slider = Probe("Slider"),
        StatusBar = Probe("StatusBar"),
        ScrollFrame = Probe("ScrollFrame"),
        Cooldown = Probe("Cooldown"),
        ColorSelect = Probe("ColorSelect"),
        MessageFrame = Probe("MessageFrame"),
        ScrollingMessageFrame = Probe("ScrollingMessageFrame"),
        SimpleHTML = Probe("SimpleHTML"),
        PlayerModel = Probe("PlayerModel"),
        GameTooltip = Probe("GameTooltip"),
    }

    if frame then
        live.Texture = frame:CreateTexture()
        live.FontString = frame:CreateFontString()
        if frame.CreateAnimationGroup then
            local ok, group = pcall(frame.CreateAnimationGroup, frame)
            if ok and group then
                live.AnimationGroup = group
                local ok2, animation = pcall(group.CreateAnimation, group, "Alpha")
                if ok2 then live.Animation = animation end
            end
        end
    end

    shimLiveWidgets = live
    return live
end

local function CmdShims(pattern)
    local snap = Cell.nativeSnapshot
    if not snap or not snap.ready then
        Say(C_WARN .. "снимок нативного API не снят" .. C_OFF ..
            " — DebugSnapshot.lua должен грузиться первым в Cell.toc")
        return
    end
    pattern = pattern ~= "" and pattern:lower() or nil

    local addedN, removedN, typeN, overN = 0, 0, 0, 0
    local out = {}

    for i = 1, #(snap.watched or {}) do
        local name = snap.watched[i]
        local before = snap.globals[name]
        local now = _G[name]
        if not pattern or name:lower():find(pattern, 1, true) then
            if before == nil and now ~= nil then
                tinsert(out, format("  %sADDED%s      %-34s (%s) — полифилл, в 3.3.5 не было",
                    C_OK, C_OFF, name, type(now)))
                addedN = addedN + 1
            elseif before ~= nil and now == nil then
                tinsert(out, format("  %sREMOVED%s    %-34s (%s -> nil)",
                    C_WARN, C_OFF, name, type(before)))
                removedN = removedN + 1
            elseif before ~= nil and type(before) ~= type(now) then
                tinsert(out, format("  %sTYPE%s       %-34s %s -> %s",
                    C_WARN, C_OFF, name, type(before), type(now)))
                typeN = typeN + 1
            elseif before ~= nil and before ~= now then
                tinsert(out, format("  %sOVERRIDDEN%s %-34s (%s -> другой %s)",
                    C_WARN, C_OFF, name, type(before), type(now)))
                overN = overN + 1
            end
        end
    end

    --! WotLK fix: сравниваем точные ссылки всех методов всех снятых категорий.
    --! Второй проход по старому снимку нужен, чтобы увидеть удалённый метод.
    local live = BuildShimLiveWidgets()
    for label, was in pairs(snap.widgets or {}) do
        local obj = live[label]
        local mt = obj and getmetatable(obj)
        local index = mt and mt.__index
        if type(index) == "table" then
            for name, now in pairs(index) do
                if type(name) == "string" and type(now) == "function" and
                   (not pattern or name:lower():find(pattern, 1, true)) then
                    local before = was[name]
                    if before == nil then
                        tinsert(out, format("  %sADDED%s      %s:%s()", C_OK, C_OFF, label, name))
                        addedN = addedN + 1
                    elseif before ~= now then
                        tinsert(out, format("  %sOVERRIDDEN%s %s:%s()", C_WARN, C_OFF, label, name))
                        overN = overN + 1
                    end
                end
            end
            for name, before in pairs(was) do
                if type(before) == "function" and type(index[name]) ~= "function" and
                   (not pattern or name:lower():find(pattern, 1, true)) then
                    tinsert(out, format("  %sREMOVED%s    %s:%s()", C_WARN, C_OFF, label, name))
                    removedN = removedN + 1
                end
            end
        end
    end

    -- Чужая территория: глобалы, уже существовавшие в момент загрузки Cell.
    -- На этом клиенте раньше Cell грузится отдельный !!!ClassicAPI, и всё, что он
    -- занял, Cell своим полифиллом уже не создаст — значит работает ЧУЖАЯ версия.
    local foreign, nativeN, seenName = {}, 0, {}
    local native = snap.native or {}
    for i = 1, #(snap.watched or {}) do
        local name = snap.watched[i]
        if snap.globals[name] ~= nil and not seenName[name] then
            seenName[name] = true
            if native[name] then
                nativeN = nativeN + 1          -- норма: оно и должно там быть
            elseif not pattern or name:lower():find(pattern, 1, true) then
                tinsert(foreign, format("  %sЧУЖОЕ%s      %-34s (%s)",
                    C_WARN, C_OFF, name, type(snap.globals[name])))
            end
        end
    end

    Say(format("%sслой совместимости%s: добавлено %d, удалено %d, сменило тип %d, переопределено %d, занято чужим аддоном %d (нативных %d)",
        C_HEAD, C_OFF, addedN, removedN, typeN, overN, #foreign, nativeN))
    if #foreign > 0 then
        Say("этого в 3.3.5 нет, но оно уже было до загрузки Cell —")
        Say("значит работает реализация ЧУЖОГО аддона, а наш полифилл пропущен:")
        for i = 1, #foreign do print(foreign[i]) end
    end
    if #out == 0 then
        Say("  ничего не подходит под фильтр")
    else
        for i = 1, #out do print(out[i]) end
    end
    Say("добавление отсутствовавшего метода — ожидаемый полифилл;")
    Say("REMOVED, TYPE и OVERRIDDEN требуют проверки владельца и контракта.")
end

-------------------------------------------------
-- ret: сколько значений реально возвращает функция
-------------------------------------------------
-- Главный инструмент бэкпорта: в ретейле у функции 12 возвратов, в 3.3.5 — 11,
-- и код молча читает nil. `/cell debug ret GetRaidRosterInfo 1` показывает правду.
local function ParseArg(s)
    if s == "nil" then return nil, true end
    if s == "true" then return true, true end
    if s == "false" then return false, true end
    local n = tonumber(s)
    if n then return n, true end
    return s, true
end

local function CmdRet(rest)
    local name, argstr = rest:match("^(%S+)%s*(.-)$")
    if not name or name == "" then
        Say("использование: /cell debug ret <ИмяФункции> [арг1 арг2 ...]")
        return
    end
    local f = _G[name]
    if type(f) ~= "function" then
        Say(format("%s%s%s — не функция (%s)", C_WARN, name, C_OFF, type(f)))
        return
    end

    local args, n = {}, 0
    for word in argstr:gmatch("%S+") do
        n = n + 1
        args[n] = ParseArg(word)
    end

    -- один вызов: select("#") считает и хвостовые nil, которые {...} теряет
    local ok, count, vals = Capture(pcall(f, unpack(args, 1, n)))
    if not ok then
        Say(format("%s%s%s упала: %s", C_WARN, name, C_OFF, tostring(vals[1])))
        return
    end

    Say(format("%s%s(%s)%s -> %d значени%s", C_HEAD, name, argstr, C_OFF,
        count, (count == 1 and "е") or "й"))
    for i = 1, count do
        print(format("  %s[%d]%s %s", C_KEY, i, C_OFF, Val(vals[i])))
    end
    Say("сверь с кодексом: python audit/tools/codex.py fn " .. name)
end

-------------------------------------------------
-- ev: какие аргументы реально приходит в событии
-------------------------------------------------
-- Ловит класс багов вида «на 3.3.5 arg1 — число, а код ждёт unitID».
local evFrame
local evWatch = {}

local function EnsureEvFrame()
    if evFrame then return evFrame end
    evFrame = CreateFrame("Frame")
    evFrame:SetScript("OnEvent", function(_, event, ...)
        local n = select("#", ...)
        local parts = {}
        for i = 1, n do
            local v = select(i, ...)
            tinsert(parts, format("%s[%d]%s %s=%s", C_KEY, i, C_OFF, type(v), Val(v)))
        end
        Say(format("%s%s%s (%d арг.) %s", C_HEAD, event, C_OFF, n,
            (n > 0 and tconcat(parts, "  ")) or "— без аргументов"))
    end)
    return evFrame
end

local function CmdEv(rest)
    local arg = rest:match("^(%S*)")
    if arg == "" or arg == "list" then
        local names = {}
        for e in pairs(evWatch) do tinsert(names, e) end
        if #names == 0 then
            Say("событий под наблюдением нет. /cell debug ev <ИМЯ_СОБЫТИЯ>")
        else
            table.sort(names)
            Say("под наблюдением: " .. tconcat(names, ", "))
        end
        return
    end
    if arg == "off" then
        local f = EnsureEvFrame()
        for e in pairs(evWatch) do f:UnregisterEvent(e) end
        evWatch = {}
        Say("наблюдение за событиями снято")
        return
    end

    local event = arg:upper()
    local f = EnsureEvFrame()
    if evWatch[event] then
        f:UnregisterEvent(event)
        evWatch[event] = nil
        Say(format("%s — наблюдение снято", event))
    else
        local ok = pcall(f.RegisterEvent, f, event)
        if not ok then
            Say(format("%s%s%s — клиент отверг регистрацию", C_WARN, event, C_OFF))
            return
        end
        evWatch[event] = true
        Say(format("%s%s%s — под наблюдением. Сверь payload: python audit/tools/codex.py ev %s",
            C_OK, event, C_OFF, event))
    end
end

-------------------------------------------------
-- aura: контракт UnitAura на этом клиенте
-------------------------------------------------
local AURA_FIELDS = {
    "name", "rank", "icon", "count", "dispelType",
    "duration", "expires", "caster", "isStealable", "shouldConsolidate", "spellID",
}

local function CmdAura(rest)
    local unit, filter = rest:match("^(%S*)%s*(%S*)")
    if unit == "" then unit = "target" end
    if filter == "" then filter = "HELPFUL" end
    filter = filter:upper()

    if not UnitExists(unit) then
        Say(format("%s%s%s не существует", C_WARN, unit, C_OFF))
        return
    end

    Say(format("%s%s%s, фильтр %s — контракт 3.3.5: 11 возвратов", C_HEAD, unit, C_OFF, filter))
    local shown = 0
    for i = 1, 40 do
        local _, count, vals = Capture(true, UnitAura(unit, i, filter))
        if vals[1] == nil then break end
        shown = shown + 1
        print(format("  %s#%d%s %s  (возвратов: %d)", C_KEY, i, C_OFF, tostring(vals[1]), count))
        for j = 1, count do
            local label = AURA_FIELDS[j] or format("<поле %d — в 3.3.5 не документировано>", j)
            print(format("      [%d] %-18s %s", j, label, Val(vals[j])))
        end
        if count > #AURA_FIELDS then
            Say(format("  %sвнимание%s: клиент отдал %d значений вместо %d — кастомное ядро",
                C_WARN, C_OFF, count, #AURA_FIELDS))
        end
    end
    if shown == 0 then Say("  аур нет") end
end

-------------------------------------------------
-- perf: перепись OnUpdate и прирост мусора
-------------------------------------------------
local perfFrame

local function CountOnUpdate()
    local total, withScript, visible = 0, 0, 0
    local f = EnumerateFrames()
    while f do
        total = total + 1
        if f.GetScript then
            local ok, s = pcall(f.GetScript, f, "OnUpdate")
            if ok and s then
                withScript = withScript + 1
                if f:IsVisible() then visible = visible + 1 end
            end
        end
        f = EnumerateFrames(f)
    end
    return total, withScript, visible
end

local function CmdPerf(rest)
    local secs = tonumber(rest:match("%S+") or "") or 5

    local total, withScript, visible = CountOnUpdate()
    Say(format("%sframes%s %d, with OnUpdate %d (visible %d)",
        C_HEAD, C_OFF, total, withScript, visible))
    if withScript > 40 then
        Say(format("  %smany OnUpdate handlers%s - every visible handler runs each frame", C_WARN, C_OFF))
    end

    collectgarbage("collect")
    local before = collectgarbage("count")
    local t0 = GetTime()
    local fps0 = GetFramerate()

    perfFrame = perfFrame or CreateFrame("Frame")
    perfFrame:Show()
    perfFrame:SetScript("OnUpdate", function(self)
        if GetTime() - t0 < secs then return end
        self:SetScript("OnUpdate", nil)
        self:Hide()
        local beforeFinalGC = collectgarbage("count")
        local allocated = beforeFinalGC - before
        --! WotLK fix: sample the ending FPS before the explicit diagnostic GC.
        --! Reading it after a stop-the-world collection made the GC pause look
        --! like a gameplay FPS regression (for example 178 -> 77 while idle).
        local fpsEnd = GetFramerate()
        --! WotLK fix: the old diagnostic reported only the pre-GC heap delta,
        --! which made temporary garbage look like a leak. This command is an
        --! explicit diagnostic, so a final full GC is acceptable and lets us
        --! report both allocation pressure and memory retained after collection.
        collectgarbage("collect")
        local retained = collectgarbage("count") - before
        Say(format("%sover %d s%s: heap before GC %+.0f KB (%.1f KB/s), retained after GC %+.0f KB, FPS %.0f -> %.0f",
            C_HEAD, secs, C_OFF, allocated, allocated / secs, retained,
            fps0, fpsEnd))
        if retained / secs > 100 then
            Say(format("  %sretained >100 KB/s%s - repeat in an idle baseline",
                C_WARN, C_OFF))
        end
    end)
    Say(format("measuring %d s - do not interact with the UI", secs))
end

-------------------------------------------------
-- err: перехват ошибок Lua с трейсом
-------------------------------------------------
local errOn, errPrev, errSeen = false, nil, {}

local function CmdErr()
    if errOn then
        if errPrev then seterrorhandler(errPrev) end
        errOn = false
        Say("перехват ошибок выключен")
        return
    end
    errPrev = geterrorhandler()
    seterrorhandler(function(msg)
        msg = tostring(msg)
        local n = (errSeen[msg] or 0) + 1
        errSeen[msg] = n
        if n <= 3 then       -- не заспамить чат повторами одной ошибки
            Say(format("%sLUA%s %s", C_WARN, C_OFF, msg))
            print(debugstack(2, 6, 0))
        elseif n == 4 then
            Say(format("%sLUA%s (эта ошибка повторяется, дальше молчу)", C_WARN, C_OFF))
        end
        if errPrev then errPrev(msg) end
    end)
    errOn = true
    Say("перехват ошибок включён — каждая уникальная ошибка печатается 3 раза с трейсом")
end

-------------------------------------------------
-- env: окружение и владельцы API
-------------------------------------------------
-- Помогает понять, кто чем владеет в текущей сессии:
--   - Cell vs standalone !!!ClassicAPI (нативный _G.C_Timer / _G.PixelUtil
--     уже занят? тогда работает ЧУЖАЯ реализация, а полифилл Cell пропущен)
--   - какие C_* / Lib* библиотеки реально подгружены и какой minor
--   - флаги Cell.flavor / isWrath / isRetail (могут «поплыть» на кастомных ядрах)
--   - счётчик загруженных аддонов и размеры CellDB на диске
--! WotLK fix: the minor lives in LibStub.minors[major], NOT on the library table -
--! LibStub:NewLibrary() writes `self.minors[major], self.libs[major] = minor, ...` and
--! never touches the returned table. Reading lib.minor/lib.version therefore missed on
--! every LibStub library, and the whole block printed "?" ten times out of ten (dump
--! from the tester's client, 2026-08-31). GetLibrary already hands the minor back as
--! its second return value; the field reads stay as a fallback for libraries that
--! publish a version of their own (LibDeflate, LibSerialize).
local function GetLibMinor(major)
    if not LibStub or not LibStub.GetLibrary then return nil end
    local ok, lib, minor = pcall(LibStub.GetLibrary, LibStub, major, true)
    if ok and lib then
        return tostring(minor or lib.minor or lib.version or "?")
    end
    return nil
end

local function BuildEnvLines(lines)
    local add = function(s) lines[#lines + 1] = s end

    add("")
    add("[ENV]")

    local client, build = GetBuildInfo()
    add(string.format("  client      : %s (build %s)", tostring(client), tostring(build)))
    add(string.format("  Cell.flavor : %s   isWrath=%s isRetail=%s isTWW=%s",
        tostring(Cell.flavor), tostring(Cell.isWrath),
        tostring(Cell.isRetail), tostring(Cell.isTWW)))
    add(string.format("  WOW_PROJECT_ID : %s   LE_EXPANSION_LEVEL_CURRENT : %s",
        tostring(WOW_PROJECT_ID), tostring(LE_EXPANSION_LEVEL_CURRENT)))

    -- native snapshot readiness
    local snap = Cell.nativeSnapshot
    add(string.format("  nativeSnapshot : %s%s",
        snap and snap.ready and "ready" or "MISSING",
        snap and snap.ready and (" ("..#(snap.watched or {}).." keys, "..(snap.native and #snap.native or 0).." native)") or ""))

    -- private contract: does _G.C_Timer / _G.PixelUtil equal Cell's own?
    local ownTimer = Cell.C_Timer and _G.C_Timer == Cell.C_Timer
    local ownPixel = Cell.PixelUtil and _G.PixelUtil == Cell.PixelUtil
    add(string.format("  C_Timer     : _G.C_Timer %s Cell.C_Timer  (%s) — %s",
        ownTimer and "==" or "~=",
        tostring(_G.C_Timer),
        ownTimer and "наш приватный" or ("ЧУЖОЙ — " .. tostring(_G.C_Timer))))
    add(string.format("  PixelUtil   : _G.PixelUtil %s Cell.PixelUtil  (%s) — %s",
        ownPixel and "==" or "~=",
        tostring(_G.PixelUtil),
        ownPixel and "наш приватный" or ("ЧУЖОЙ — " .. tostring(_G.PixelUtil))))

    --! WotLK fix: encounter state has no native source on 3.3.5a (ENCOUNTER_START/END
    --! arrived in 5.4). Polyfills.lua bridges DBM instead, and a bridge that quietly
    --! failed to attach would look exactly like the old always-false behaviour - so
    --! report it here, where it also lands in the harness dump.
    if Cell.GetEncounterBridgeState then
        local attached, revision = Cell.GetEncounterBridgeState()
        add(string.format("  encounter   : %s   IsEncounterInProgress()=%s",
            attached and ("мост DBM подключён (Revision " .. tostring(revision) .. ")")
                or "DBM не найден — состояние боя всегда false",
            tostring(Cell.IsEncounterInProgress())))
    end

    -- LCG (Cell fork)
    local lcg = LibStub and LibStub("LibCustomGlow-1.0-Cell", true)    if lcg then
        add(string.format("  LCG         : LibCustomGlow-1.0-Cell minor=%s  GlowFramePool=%d ButtonGlowPool=%d ProcGlowPool=%d",
            tostring(lcg.minor or lcg.version or "?"),
            lcg.GlowFramePool and lcg.GlowFramePool.count or -1,
            lcg.ButtonGlowPool and lcg.ButtonGlowPool.count or -1,
            lcg.ProcGlowPool and lcg.ProcGlowPool.count or -1))
    end

    -- other libs Cell uses
    --! WotLK fix: dropped "AceSerializer-3.0" and "AbsorbsMonitor-1.0" from this
    --! probe list on 2026-08-09. Both folders were deleted: neither is listed in
    --! Libs/LoadLibs_Classic.xml, so neither ever loaded. Serialization runs on
    --! LibSerialize + LibDeflate (Comm.lua:13-31). GetLibMinor would have kept
    --! returning nil for them, but a name in a diagnostic list reads as a claim
    --! that the addon ships it.
    local libs = {
        "LibHealComm-4.0", "LibResComm-1.0", "LibGroupInfo",
        "LibStub", "CallbackHandler-1.0", "AceComm-3.0",
        "LibSharedMedia-3.0", "LibCustomGlow-1.0-Cell",
        "LibSerialize", "LibDeflate", "LibTranslit-1.0",
    }
    for i = 1, #libs do
        local m = GetLibMinor(libs[i])
        if m then
            add(string.format("  %-12s : %s", libs[i], m))
        end
    end

    -- loaded addons count and CellDB size
    if GetNumAddOns then
        local loaded, total = 0, GetNumAddOns()
        for i = 1, total do
            local name = GetAddOnInfo and GetAddOnInfo(i)
            if name and IsAddOnLoaded(name) then loaded = loaded + 1 end
        end
        add(string.format("  addons      : %d loaded of %d total", loaded, total))
    end
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
        --! WotLK fix: GetAddOnMemoryUsage on 3.3.5 requires an addon name or
        --! numeric index; unlike later clients, calling it with no argument errors.
        local totalMemory = 0
        local totalAddons = GetNumAddOns and GetNumAddOns() or 0
        for i = 1, totalAddons do
            totalMemory = totalMemory + (GetAddOnMemoryUsage(i) or 0)
        end
        add(string.format("  memory      : Cell=%.0f KB, total=%.0f KB",
            GetAddOnMemoryUsage("Cell") or 0, totalMemory))
    end
end

local function CmdEnv()
    local lines = {}
    BuildEnvLines(lines)
    Say(C_HEAD .. "environment:" .. C_OFF)
    for i = 1, #lines do print(lines[i]) end
end

-------------------------------------------------
-- timers: состояние Cell.C_Timer
-------------------------------------------------
local function BuildTimerLines(lines)
    local add = function(s) lines[#lines + 1] = s end
    local timer = Cell.C_Timer
    add("")
    add("[TIMERS]")

    if not timer or not timer.GetDebugStats then
        add("  Cell.C_Timer или GetDebugStats недоступны")
        return
    end

    local activeN, dueN, driverShown = timer.GetDebugStats()
    add(string.format("  Cell.C_Timer: active=%d  due=%d  driver=%s",
        activeN, dueN, driverShown and "shown" or "hidden"))

    local snap, total = timer.EnumerateActive(20)
    add(string.format("  top %d (of %d active):", #snap, total))
    for i = 1, #snap do
        local h = snap[i]
        local remain = (h.duration or 0) - (h.elapsed or 0)
        add(string.format("    #%02d  remain=%.2fs  iter=%s  cancelled=%s  label=%s  src=%s",
            i, remain > 0 and remain or 0,
            tostring(h.iterations), tostring(h.cancelled),
            tostring(h.label or "<unlabeled>"),
            tostring(h.source):gsub("^@", "")))
    end
end

local function CmdTimers()
    local lines = {}
    BuildTimerLines(lines)
    Say(C_HEAD .. "Cell.C_Timer:" .. C_OFF)
    for i = 1, #lines do print(lines[i]) end
end

-------------------------------------------------
-- glow: LCG pools
-------------------------------------------------
local function BuildGlowPoolLines(lines, label, pool)
    local add = function(s) lines[#lines + 1] = s end
    if not pool then
        add(string.format("  %-15s : <not loaded>", label))
        return
    end
    local active, inactive = 0, 0
    for _ in pairs(pool.active or {}) do active = active + 1 end
    if type(pool.inactive) == "table" then
        inactive = #pool.inactive
    end
    add(string.format("  %-15s : created=%d  active=%d  inactive=%d",
        label, pool.count or 0, active, inactive))
    if active > 0 and active <= 12 then
        for frame in pairs(pool.active) do
            local parent = frame.GetParent and frame:GetParent()
            local pname = parent and parent.GetName and parent:GetName() or "?"
            add(string.format("    gen=%s  parent=%s  visible=%s",
                tostring(frame._cellGlowGeneration),
                tostring(pname),
                frame.IsVisible and frame:IsVisible() and "yes" or "no"))
        end
    end
end

local function BuildGlowLines(lines)
    local add = function(s) lines[#lines + 1] = s end
    add("")
    add("[GLOW]")
    local lcg = LibStub and LibStub("LibCustomGlow-1.0-Cell", true)
    if not lcg then
        add("  LibCustomGlow-1.0-Cell не загружен")
        return
    end
    BuildGlowPoolLines(lines, "GlowFramePool", lcg.GlowFramePool)
    BuildGlowPoolLines(lines, "ButtonGlowPool", lcg.ButtonGlowPool)
    BuildGlowPoolLines(lines, "ProcGlowPool", lcg.ProcGlowPool)
    BuildGlowPoolLines(lines, "GlowTexPool", lcg.GlowTexPool)
    BuildGlowPoolLines(lines, "GlowMaskPool", lcg.GlowMaskPool)
end

local function CmdGlow()
    local lines = {}
    BuildGlowLines(lines)
    Say(C_HEAD .. "LCG pools:" .. C_OFF)
    for i = 1, #lines do print(lines[i]) end
end

-------------------------------------------------
-- anim: pendingStops в Animation.lua
-------------------------------------------------
local function BuildAnimLines(lines)
    local add = function(s) lines[#lines + 1] = s end
    add("")
    add("[ANIM]")
    local anim = Cell.animations
    if not anim or not anim.GetDebugInfo then
        add("  Cell.animations.GetDebugInfo недоступен")
        return
    end
    local pending = anim.GetDebugInfo()
    add(string.format("  pendingStops (reentrancy defers): %d", pending))
    if pending > 5 then
        add("  > 5 — проверь, не падает ли Stop() в OnUpdate/OnFinished/OnHide")
    end
end

local function CmdAnim()
    local lines = {}
    BuildAnimLines(lines)
    Say(C_HEAD .. "Animation:" .. C_OFF)
    for i = 1, #lines do print(lines[i]) end
end

-------------------------------------------------
-- log: кольцевой буфер последних N событий
-------------------------------------------------
local function BuildRingLines(lines)
    local add = function(s) lines[#lines + 1] = s end
    local ring = Cell.Debug.Ring
    add("")
    add("[RING]")
    add(string.format("  enabled=%s  used=%d / max=%d",
        tostring(ring.enabled), #ring.buffer, ring.max))
    if not ring.enabled then
        add("  /cell debug log on — чтобы начать писать в буфер")
    end
    for i = 1, #ring.buffer do
        add("  " .. ring.buffer[i])
    end
end

local function CmdLog(rest)
    rest = rest or ""
    local sub = rest:match("^(%S*)") or ""
    sub = sub:lower()

    if sub == "" then
        local ring = Cell.Debug.Ring
        Say(format("%sring буфер%s: enabled=%s used=%d/%d",
            C_HEAD, C_OFF, tostring(ring.enabled), #ring.buffer, ring.max))
        Say("/cell debug log on|off|show [N]|clear")
        return
    end

    if sub == "on" then
        Cell.Debug.Ring.enabled = true
        --! WotLK fix: TrackFire has an early trackFires gate. Keep that route
        --! active while the ring is enabled even if normal debug mode is off.
        Cell.Debug.trackFires = true
        Say(format("%sring включён%s (max=%d)", C_OK, C_OFF, Cell.Debug.Ring.max))
        return
    end
    if sub == "off" then
        Cell.Debug.Ring.enabled = false
        Cell.Debug.trackFires = Cell.Debug.enabled
        Say(format("%sring выключён%s (буфер сохранён, %d записей)",
            C_WARN, C_OFF, #Cell.Debug.Ring.buffer))
        return
    end
    if sub == "clear" then
        local n = #Cell.Debug.Ring.buffer
        Cell.Debug.Ring.buffer = {}
        Say(format("ring очищен, удалено %d записей", n))
        return
    end
    if sub == "show" then
        local n = tonumber(rest:match("^%S+%s+(%d+)")) or 100
        if n < 1 then n = 1 elseif n > 1000 then n = 1000 end
        local buf = Cell.Debug.Ring.buffer
        local total = #buf
        local from = total - n + 1
        if from < 1 then from = 1 end
        Say(format("%sring%s: показываю %d (из %d), enabled=%s",
            C_HEAD, C_OFF, total - from + 1, total, tostring(Cell.Debug.Ring.enabled)))
        for i = from, total do
            print("  " .. buf[i])
        end
        if total == 0 then
            Say("  (пусто)")
        end
        return
    end

    Say("/cell debug log on|off|show [N]|clear")
end

-------------------------------------------------
-- count: компактный однострочный дашборд
-------------------------------------------------
local function CmdRoles()
    if not Cell.GetUnitRoleDebugInfo then
        Say(C_WARN .. "Cell.GetUnitRoleDebugInfo недоступен" .. C_OFF)
        return
    end

    local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    local units = {}
    if numRaid > 0 then
        for i = 1, numRaid do units[#units + 1] = "raid" .. i end
    else
        units[#units + 1] = "player"
        for i = 1, numParty do units[#units + 1] = "party" .. i end
    end

    Say(format("%srole resolution%s: %d units", C_HEAD, C_OFF, #units))
    Say("unit name class | native | roster MT/MA | LGI | LGT | final/source")
    for i = 1, #units do
        local unit = units[i]
        if UnitExists(unit) then
            local info = Cell.GetUnitRoleDebugInfo(unit) or {}
            local name = UnitName(unit) or "?"
            local _, class = UnitClass(unit)
            local native = format("%s/%s/%s",
                tostring(info.native1), tostring(info.native2), tostring(info.native3))
            local assignments = format("%s/%s/%s",
                tostring(info.raidRosterRole),
                info.mainTank and "MT" or "-",
                info.mainAssist and "MA" or "-")
            local lgi = format("spec=%s assigned=%s inspected=%s name=%s",
                tostring(info.lgiSpecRole), tostring(info.lgiAssignedRole),
                tostring(info.lgiInspected), tostring(info.lgiSpecName))
            --! WotLK fix: LibGroupTalents is the source that covers units Cell
            --! could never inspect - show it, otherwise "default fallback" is
            --! indistinguishable from "library absent".
            print(format("  %s %s %s | native=%s | roster/flags=%s | %s | LGT=%s | %s (%s)",
                unit, name, tostring(class), native, assignments, lgi,
                tostring(info.lgtRole),
                tostring(info.finalRole), tostring(info.source)))
        end
    end
end

local function CmdCount()
    local timer = Cell.C_Timer
    local activeN, dueN, driverShown
    if timer and timer.GetDebugStats then
        activeN, dueN, driverShown = timer.GetDebugStats()
    end

    local lcg = LibStub and LibStub("LibCustomGlow-1.0-Cell", true)
    local glowActive = 0
    if lcg then
        for _, p in pairs({lcg.GlowFramePool, lcg.ButtonGlowPool, lcg.ProcGlowPool}) do
            if p and p.active then
                for _ in pairs(p.active) do glowActive = glowActive + 1 end
            end
        end
    end

    local anim = Cell.animations
    local animPending = (anim and anim.GetDebugInfo) and anim.GetDebugInfo() or -1

    local ring = Cell.Debug.Ring
    Say(format(
        "%sdashboard%s: timers(active=%d due=%d driver=%s)  glowActive=%d  animPending=%d  ring=%d/%d %s",
        C_HEAD, C_OFF,
        activeN or -1, dueN or -1, (driverShown and "on") or "off",
        glowActive, animPending,
        #ring.buffer, ring.max,
        ring.enabled and "(on)" or "(off)"))
end

-------------------------------------------------
-- movers: почему мувер инструментов не хватается
-------------------------------------------------
--! Кто и почему тут: заказчик не смог передвинуть Marks Bar, а в SavedVariables
--! CellDB.tools.marks[4] пустой при заполненном buffTracker[4] - значит бар ни разу
--! не двигали. Догадки по коду закончились, нужен рантайм-снимок: показан ли фрейм,
--! включена ли мышь, какого он размера и где, и - для SECURE-008 (тащить в бою) -
--! кто из предков protected и можно ли менять состояние сейчас.
local function ProtStr(f)
    if not f.IsProtected then return "n/a" end
    local ok, isProt, explicit = pcall(f.IsProtected, f)
    if not ok then return "err" end
    local canChange = "n/a"
    if f.CanChangeProtectedState then
        local ok2, cc = pcall(f.CanChangeProtectedState, f)
        if ok2 then canChange = cc and "yes" or "no" end
    end
    return format("%s%s canChange=%s",
        isProt and "protected" or "plain",
        explicit and "(explicit)" or "",
        canChange)
end

local function PointStr(f)
    if not f.GetNumPoints or f:GetNumPoints() == 0 then return "no points" end
    local p, rel, rp, x, y = f:GetPoint(1)
    return format("%s -> %s.%s (%.1f, %.1f)%s",
        tostring(p),
        rel and (rel:GetName() or "<anon>") or "nil",
        tostring(rp), x or 0, y or 0,
        (f:GetNumPoints() > 1) and format(" +%d more", f:GetNumPoints() - 1) or "")
end

local function SavedPosStr(t)
    if type(t) ~= "table" then return "n/a" end
    if #t == 0 then return C_WARN .. "empty (never moved)" .. C_OFF end
    local parts = {}
    for i = 1, #t do parts[i] = tostring(t[i]) end
    return tconcat(parts, ", ")
end

local function CmdMovers()
    local cf = Cell.frames or {}
    local db = CellDB and CellDB["tools"] or {}

    Say(format("%smovers%s: showMover=%s  inCombat=%s  fadeOut=%s",
        C_HEAD, C_OFF,
        tostring(Cell.vars and Cell.vars.showMover),
        tostring(InCombatLockdown()),
        tostring(db["fadeOut"])))

    local targets = {
        {"CellParent", _G.CellParent, nil},
        {"mainFrame", cf.mainFrame, nil},
        {"anchorFrame", cf.anchorFrame, nil},
        {"menuFrame", cf.menuFrame, nil},
        {"raidMarksFrame", cf.raidMarksFrame, db["marks"]},
        {"readyAndPullFrame", cf.readyAndPullFrame, db["readyAndPull"]},
        {"buffTrackerFrame", cf.buffTrackerFrame, db["buffTracker"]},
    }

    for i = 1, #targets do
        local label, f, toolDB = targets[i][1], targets[i][2], targets[i][3]
        if not f then
            print(format("  %s%s%s: %smissing%s", C_KEY, label, C_OFF, C_WARN, C_OFF))
        else
            local w, h = f:GetWidth(), f:GetHeight()
            print(format("  %s%s%s (%s)", C_KEY, label, C_OFF, f:GetName() or "<anon>"))
            print(format("      shown=%s visible=%s alpha=%.2f mouse=%s movable=%s userPlaced=%s level=%d",
                tostring(f:IsShown()), tostring(f:IsVisible()), f:GetAlpha(),
                f.IsMouseEnabled and tostring(f:IsMouseEnabled()) or "n/a",
                f.IsMovable and tostring(f:IsMovable()) or "n/a",
                f.IsUserPlaced and tostring(f:IsUserPlaced()) or "n/a",
                f:GetFrameLevel()))
            print(format("      size=%.1fx%.1f  point=%s", w or 0, h or 0, PointStr(f)))
            print(format("      %s", ProtStr(f)))
            if toolDB then
                print(format("      enabled=%s  savedPos=%s",
                    tostring(toolDB[1]), SavedPosStr(toolDB[4])))
            end
            if f.moverText then
                print(format("      moverText shown=%s", tostring(f.moverText:IsShown())))
            end
        end
    end

    Say(format("  %s/cell unlock%s включает мувер без опций; %s/cell lock%s выключает",
        C_KEY, C_OFF, C_KEY, C_OFF))
end

-------------------------------------------------
-- threat: кто и почему мигает индикатором аггро
-------------------------------------------------
--! Заказчик: "иконка аггро как будто бы не правильно считает и мигает просто весь
--! рейд". UnitThreatSituation(unit) БЕЗ второго аргумента отдаёт максимум по любому
--! NPC, у которого юнит в листе угрозы, а Cell мигает при status >= 1, где 1 = "сырая
--! угроза >= 100%, но не главная цель". На адах это законно верно почти для всех.
--! Команда показывает оба варианта рядом и считает частоту threat-событий: на 3.3.5
--! нет RegisterUnitEvent, поэтому каждое UNIT_THREAT_LIST_UPDATE прилетает во все
--! кнопки сразу - число в секунду надо умножать на размер рейда.
local threatFrame
local threatCounts = {}
local threatT0 = 0

local function GroupUnits()
    local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    local units = {}
    if numRaid > 0 then
        for i = 1, numRaid do units[#units + 1] = "raid" .. i end
    else
        units[#units + 1] = "player"
        for i = 1, numParty do units[#units + 1] = "party" .. i end
    end
    return units
end

local function ThreatSnapshot()
    local units = GroupUnits()
    local blinking, tanks, oldRule = 0, 0, 0

    --! WotLK fix: правило мигания теперь живёт в UnitButton_UpdateThreat и настраивается
    --! (порог + "не показывать танкам"). Снимок обязан печатать ТО ЖЕ решение, что и
    --! рамки, иначе он врёт: моба берём у самого аддона (B.GetThreatMobUnit), настройки -
    --! из активного лейаута. Ищем индикатор по имени, а не по индексу 13: порядок
    --! массива в чужой базе гарантировать нельзя.
    local mob = Cell.bFuncs and Cell.bFuncs.GetThreatMobUnit and Cell.bFuncs.GetThreatMobUnit()
    local threshold, hideTanks = 100, false
    local indicators = Cell.vars.currentLayoutTable and Cell.vars.currentLayoutTable["indicators"]
    if indicators then
        for _, t in pairs(indicators) do
            if type(t) == "table" and t["indicatorName"] == "aggroBlink" then
                threshold = tonumber(t["threatThreshold"]) or 100
                hideTanks = t["hideForTanks"] and true or false
                break
            end
        end
    end

    Say(format("%sthreat snapshot%s: %d units, playerTarget=%s, mobUnit=%s",
        C_HEAD, C_OFF, #units,
        UnitExists("target") and (UnitName("target") or "?") or "none",
        mob and format("%s (%s)", mob, UnitName(mob) or "?")
            or format("%snone - откат на старое глобальное правило%s", C_WARN, C_OFF)))
    Say(format("aggroBlink: %s, танки - %s",
        threshold >= 130 and "верх ползунка (130) - только когда моба уже бьёт этот юнит"
            or format("порог %d%%", threshold),
        hideTanks and "скрыты" or "показываем"))
    Say("unit name | anyMob | vsMob | detailed(isTanking/status/scaled/raw) | role | вердикт")

    for i = 1, #units do
        local unit = units[i]
        if UnitExists(unit) then
            local any = UnitThreatSituation(unit)
            local vsMob = mob and UnitThreatSituation(unit, mob) or nil
            local isTanking, status, scaled, raw
            if mob then
                isTanking, status, scaled, raw = UnitDetailedThreatSituation(unit, mob)
            end
            local role = Cell.UnitGroupRolesAssigned and Cell.UnitGroupRolesAssigned(unit) or "?"

            --! ровно та же арифметика, что в UnitButton_UpdateThreat
            local percent
            if mob then
                percent = raw or 0
            else
                percent = (any and any >= 1) and 100 or 0
            end
            --! WotLK fix: mirror the top-of-slider rule from UnitButton_UpdateThreat.
            --! At 130 the verdict is "the mob is already hitting this unit" (isTanking,
            --! or status >= 2 without a hostile target), not a percentage comparison.
            local show
            if threshold >= 130 then
                local hit
                if mob then
                    hit = isTanking and true or false
                else
                    hit = (any and any >= 2) and true or false
                end
                show = hit and not (hideTanks and role == "TANK")
            else
                show = percent > 0 and percent >= threshold and not (hideTanks and role == "TANK")
            end

            if show then
                blinking = blinking + 1
                if role == "TANK" then tanks = tanks + 1 end
            end
            if any and any >= 1 then oldRule = oldRule + 1 end

            print(format("  %s %s | any=%s | vsMob=%s | %s/%s/%s/%s | %s%s | %s",
                unit, UnitName(unit) or "?",
                tostring(any), tostring(vsMob),
                tostring(isTanking), tostring(status),
                scaled and format("%.0f%%", scaled) or "nil",
                raw and format("%.0f%%", raw) or "nil",
                tostring(role),
                UnitIsCharmed(unit) and " CHARMED" or "",
                show and "|cffff2727МИГАЕТ|r" or "-"))
        end
    end

    Say(format("  мигает %d/%d (из них танков %d); по старому правилу (status >= 1 против любого моба) мигало бы %d",
        blinking, #units, tanks, oldRule))
    if blinking > #units / 2 then
        Say(format("  %sмигает больше половины рейда%s - правило всё ещё слишком широкое, поднимай порог",
            C_WARN, C_OFF))
    end
end

local function CmdThreat(rest)
    local arg = (rest or ""):match("%S+")
    arg = arg and arg:lower() or nil

    if arg == "off" then
        if threatFrame then
            threatFrame:UnregisterAllEvents()
            threatFrame:SetScript("OnEvent", nil)
        end
        local elapsed = GetTime() - threatT0
        Say(format("%sthreat counters%s: %.1f s", C_HEAD, C_OFF, elapsed))
        local units = #GroupUnits()
        for ev, n in pairs(threatCounts) do
            print(format("  %s: %d (%.1f/s) -> %.0f button iterations/s at %d units",
                ev, n, n / math.max(elapsed, 0.001), n / math.max(elapsed, 0.001) * units, units))
        end
        wipe(threatCounts)
        return
    end

    if arg == "on" then
        threatFrame = threatFrame or CreateFrame("Frame")
        wipe(threatCounts)
        threatT0 = GetTime()
        threatFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
        threatFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
        threatFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        threatFrame:RegisterEvent("UNIT_FACTION")
        threatFrame:SetScript("OnEvent", function(_, event)
            threatCounts[event] = (threatCounts[event] or 0) + 1
        end)
        Say(format("%sthreat counters armed%s - воспроизводи бой, потом %s/cell debug threat off%s",
            C_HEAD, C_OFF, C_KEY, C_OFF))
        return
    end

    ThreatSnapshot()
end

-------------------------------------------------
-- readycheck: сырой контракт READY_CHECK_* против того, что показывает Cell
-------------------------------------------------
--! WotLK fix: GAP-005 («счётчик ready check, возможный N+1»). Кодекс задаёт arg1 у
--! READY_CHECK_CONFIRM как "the unitid without raid or party prefix", то есть ЧИСЛО;
--! то же говорит и собственная API-документация WeakAuras-WotLK (id: number).
--! Какой номер приходит на собственное подтверждение игрока в ПАРТИИ - из контракта
--! не следует: токена partyN у игрока нет. Поэтому 19.08.2026 счётчик в
--! ReadyAndPull.lua перестал зависеть от arg1 и считает перебором ростера через
--! GetReadyCheckStatus - как это делает штатный FrameXML. Канал остался и печатает
--! обе картины рядом: сырые аргументы и ключ по старой схеме (это исследование
--! семантики arg1, а не то, что делает Cell) плюс независимый перебор через
--! GetReadyCheckStatus - он же и подтверждает, что новый счётчик доходит до
--! знаменателя. GetReadyCheckStatus отдаёт nil всем, кроме лидера и ассистента -
--! это тоже печатаем, чтобы nil не приняли за дефект.
local rcFrame
local rcSeen = {}
local rcCount = 0

local function RCSweep()
    local units = GroupUnits()
    local ready, notready, waiting, none = 0, 0, 0, 0
    for i = 1, #units do
        local st = GetReadyCheckStatus and GetReadyCheckStatus(units[i])
        if st == "ready" then ready = ready + 1
        elseif st == "notready" then notready = notready + 1
        elseif st == "waiting" then waiting = waiting + 1
        else none = none + 1 end
    end
    return format("GetReadyCheckStatus: ready=%d notready=%d waiting=%d nil=%d из %d",
        ready, notready, waiting, none, #units)
end

--! Текст кнопки читаем через детей фрейма: readyBtn - файловый локал ReadyAndPull.lua,
--! и выставлять его наружу ради отладки нельзя (правило 3: приватное - приватно).
local function RCButtonText()
    local f = Cell.frames and Cell.frames.readyAndPullFrame
    if not f then return "readyAndPullFrame не создан" end
    local parts = {}
    local children = {f:GetChildren()}
    for i = 1, #children do
        local child = children[i]
        if child.GetText then
            parts[#parts + 1] = format("%q", tostring(child:GetText()))
        end
    end
    return #parts > 0 and ("кнопки: " .. tconcat(parts, " ")) or "кнопок с текстом нет"
end

local function RCPlayerToken()
    if Cell.IsInRaid() then
        local idx = UnitInRaid("player")
        --! UnitInRaid отдаёт индекс на единицу меньше номера в токене (кодекс: 0 для raid1).
        return idx and ("raid" .. (idx + 1)) or "?"
    end
    if Cell.IsInGroup() then
        return "player (в партии токена partyN у игрока нет)"
    end
    return "player (не в группе)"
end

local function RCOnEvent(_, event, arg1, arg2)
    if event == "READY_CHECK" then
        wipe(rcSeen)
        rcCount = 0
        Say(format("%sREADY_CHECK%s инициатор=%s, arg2=%s (на 3.3.5 ожидается nil: readyCheckTimeLeft появился в 4.0)",
            C_HEAD, C_OFF, Val(arg1), Val(arg2)))
        Say(format("  знаменатель Cell.GetNumGroupMembers()=%d (raid=%d party=%d), токен игрока=%s, права=%s",
            Cell.GetNumGroupMembers(), GetNumRaidMembers(), GetNumPartyMembers(),
            RCPlayerToken(), tostring(Cell.funcs and Cell.funcs.HasPermission and Cell.funcs.HasPermission())))
        Say(format("  GetReadyCheckTimeLeft()=%s; %s", Val(GetReadyCheckTimeLeft and GetReadyCheckTimeLeft()), RCSweep()))
    elseif event == "READY_CHECK_CONFIRM" then
        --! Старая схема ключа - её Cell больше не использует; считаем её здесь, чтобы
        --! увидеть, какой номер приходит на самом деле и совпал бы он со схемой.
        local key = (Cell.IsInRaid() and "raid" or "party") .. tostring(arg1)
        local isNew = not rcSeen[key]
        if isNew and arg2 then
            rcSeen[key] = true
            rcCount = rcCount + 1
        end
        local exists = UnitExists(key)
        Say(format("%sCONFIRM%s arg1=%s (%s) arg2=%s -> ключ %q: юнит %s%s, повтор=%s | счёт по arg1=%d",
            C_HEAD, C_OFF, Val(arg1), type(arg1), Val(arg2), key,
            exists and (UnitName(key) or "?") or (C_WARN .. "НЕ СУЩЕСТВУЕТ" .. C_OFF),
            (exists and UnitIsUnit(key, "player")) and " = игрок" or "",
            tostring(not isNew), rcCount))
        Say("  " .. RCSweep() .. " | " .. RCButtonText())
    elseif event == "READY_CHECK_FINISHED" then
        Say(format("%sREADY_CHECK_FINISHED%s: по старой схеме различных ключей %d, знаменатель %d -> %s",
            C_HEAD, C_OFF, rcCount, Cell.GetNumGroupMembers(),
            rcCount > Cell.GetNumGroupMembers()
                and (C_WARN .. "N+1 ВОСПРОИЗВЁЛСЯ" .. C_OFF)
                or (C_OK .. "перебора нет" .. C_OFF)))
        Say("  " .. RCSweep() .. " (после окончания проверки nil у всех - норма) | " .. RCButtonText())
    end
end

local function CmdReadyCheck(rest)
    local arg = (rest or ""):match("%S+")
    arg = arg and arg:lower() or nil

    if arg == "off" then
        if rcFrame then
            rcFrame:UnregisterAllEvents()
            rcFrame:SetScript("OnEvent", nil)
        end
        wipe(rcSeen)
        rcCount = 0
        Say(format("%sreadycheck%s: слежение снято", C_HEAD, C_OFF))
        return
    end

    rcFrame = rcFrame or CreateFrame("Frame")
    rcFrame:RegisterEvent("READY_CHECK")
    rcFrame:RegisterEvent("READY_CHECK_CONFIRM")
    rcFrame:RegisterEvent("READY_CHECK_FINISHED")
    rcFrame:SetScript("OnEvent", RCOnEvent)
    wipe(rcSeen)
    rcCount = 0
    Say(format("%sreadycheck armed%s - запускай проверку готовности (и в рейде, и в партии, "
        .. "и своей кнопкой, и чужой), потом %s/cell debug readycheck off%s",
        C_HEAD, C_OFF, C_KEY, C_OFF))
    Say(format("  сейчас: знаменатель %d, токен игрока %s, %s",
        Cell.GetNumGroupMembers(), RCPlayerToken(), RCButtonText()))
end

-------------------------------------------------
-- raiddebuffs: живы ли встроенные id на этом клиенте и чего не хватает
-------------------------------------------------
--! WotLK fix: данные Raid Debuffs собраны на ретейл-клиенте, где GetSpellInfo знает
--! id всех эпох. На 3.3.5 незнакомый id выпадает МОЛЧА: F.GetDebuffList проверяет
--! `if spellName then`, поэтому мёртвая запись не ломает аддон, но и не работает,
--! и в списке опций её не видно.
--!
--! ПЕРВЫЙ вопрос канала - живы ли id - с 2026-08-24 решён статически и здесь больше
--! не главный: база заклинаний лежит в самом клиенте, `DBFilesClient\Spell.dbc`
--! внутри MPQ, и её читает `audit/tools/dbc_probe.py --sweep` (1499 сайтов за 1,6 с,
--! входит в gates.py). Ответ на 3.3.5a: в данных WotLK мёртвых нет ни одного, все
--! 662 id живы; мёртвыми были 5 записей в Смертельных копях версии Cataclysm и 35
--! кастомных id сервера Ascension в данных TBC - последние 35 удалены 2026-08-24 с
--! разрешения владельца, пять катаклизменных он оставил. Прежняя фраза «статически это
--! не проверить, базы заклинаний нет ни в кодексе, ни в FrameXML» была верна лишь про
--! кодекс и FrameXML - про клиент она была неверна.
--!
--! Канал оставлен, потому что отвечает на ТРЕТИЙ вопрос, который статикой не берётся, -
--! жив ли АКТИВНЫЙ список текущей зоны. Он строится в рантайме из имени зоны, которое
--! приходит от клиента, поэтому проверяется только в игре (см. ниже про
--! GetCurrentAreaDebuffs и instanceNameAliases). Первые два вопроса - живы ли id и
--! чего в данных нет вовсе - с 2026-08-24 решены статически.
--!
--! ВТОРОЙ вопрос - ПОЛНОТА. Опорных списков два, оба обкатаны на 3.3.5a:
--!   [E] ElvUI 6.09, reference/ElvUI-master/ElvUI/Settings/Filters/UnitFrame.lua,
--!       G.unitframe.aurafilters.RaidDebuffs - 97 записей, только рейды;
--!       58 из них лежат в данных Cell тем же id, 39 - нет.
--!   [H] HealBot 3.3.5.4 (Interface 30300), reference/HealBot: имена дебаффов там
--!       объявлены как GetSpellInfo(<id>) в Locale/HealBot_Localization.en.lua, а
--!       раскладка по боссам - в HealBot_Data.lua. По WotLK у него 58 записей,
--!       29 совпадают с Cell по id, 29 - нет. Ценность этого эталона в том, что
--!       его id заведомо существуют на данном клиенте: аддон под него и написан.
--! Объединение расхождений - RD_PROBE (61 запись). Разница по id сама по себе ничего
--! не доказывала: Cell по умолчанию ищет дебафф ПО ИМЕНИ, а у одного дебаффа WotLK свой
--! id на каждую сложность, так что «у Cell нет 71218» ещё не значит «не поймает Vile
--! Gas». Раньше это упиралось в имя, а имя давал только GetSpellInfo в игре - теперь
--! его даёт Spell.dbc, и `dbc_probe.py --coverage` повторяет разбор F.GetDebuffList
--! один в один. Ответ на 3.3.5a: из 61 эталонной записи 42 покрыты по имени (ложная
--! тревога) и 19 - настоящие дыры в данных. Их список печатает сам инструмент.
--!
--! Сверка по именам-комментариям статически по-прежнему невозможна - в данных Cell
--! WotLK часть комментариев китайские, - но она больше и не нужна: имена берутся не
--! из комментариев, а из клиента.
local RD_LISTS = {"enabled", "disabled"}

local RD_PROBE = {
    -- Naxxramas
    {54121, "Necrotic Poison", 754, "E"},
    {28679, "Harvest Soul", 754, "E"},
    {29213, "Curse of the Plaguebringer", 754, "E"},
    {29214, "Wrath of the Plaguebringer", 754, "E"},
    {29998, "Decrepit Fever", 754, "E"},
    -- Ulduar
    {63024, "Gravity Bomb", 759, "E"},
    --! WotLK fix: у ElvUI эта запись подписана «Light Bomb» - так дебафф зовут игроки,
    --! но клиент 3.3.5a называет 63018 Searing Light, а «Light Bomb» носит совсем другой
    --! id (65598). Метка тут не украшение: канал печатает её оператору, и он пошёл бы
    --! искать в игре имя, которого нет. Расхождение нашёл `dbc_probe.py --coverage`,
    --! он же теперь краснеет на любую такую подпись.
    {63018, "Searing Light", 759, "EH"},
    {61903, "Fusion Punch", 759, "E"},
    {61912, "Static Disruption", 759, "E"},
    {64290, "Stone Grip", 759, "E"},
    {64292, "Stone Grip", 759, "H"},
    {63477, "Slag Pot", 759, "H"},
    {63666, "Napalm Shell", 759, "H"},
    {62283, "Iron Roots", 759, "H"},
    -- Trial of the Crusader
    {67618, "Paralytic Toxin", 757, "EH"},
    {65812, "Unstable Affliction", 757, "E"},
    {67309, "Twin Spike", 757, "E"},
    {67847, "Expose Weakness", 757, "EH"},
    {67478, "Impale", 757, "H"},
    {67475, "Fire Bomb", 757, "H"},
    {67049, "Incinerate Flesh", 757, "H"},
    {68123, "Legion Flame", 757, "H"},
    {67078, "Mistress' Kiss", 757, "H"},
    {67297, "Touch of Light", 757, "H"},
    {67861, "Acid-Drenched Mandibles", 757, "H"},
    -- Icecrown Citadel
    {72109, "Death and Decay", 758, "E"},
    {72442, "Boiling Blood", 758, "E"},
    {72449, "Rune of Blood", 758, "E"},
    {72409, "Rune of Blood", 758, "H"},
    {71218, "Vile Gas", 758, "E"},
    {72273, "Vile Gas", 758, "H"},
    {69279, "Gas Spore", 758, "E"},
    {72103, "Inoculated", 758, "H"},
    {71224, "Mutated Infection", 758, "EH"},
    {70215, "Gaseous Bloat", 758, "E"},
    {72455, "Gaseous Bloat", 758, "H"},
    {72549, "Malleable Goo", 758, "E"},
    {70953, "Plague Sickness", 758, "E"},
    {72856, "Unbound Plague", 758, "E"},
    {72745, "Mutated Plague", 758, "H"},
    {72796, "Glittering Sparks", 758, "EH"},
    {72999, "Shadow Prison", 758, "H"},
    {72638, "Swarming Shadows", 758, "H"},
    {72265, "Delirious Slash", 758, "E"},
    {71624, "Delirious Slash", 758, "H"},
    {71473, "Essence of the Blood Queen", 758, "E"},
    {71474, "Frenzied Bloodthirst", 758, "E"},
    {71340, "Pact of the Darkfallen", 758, "EH"},
    {71733, "Acid Burst", 758, "E"},
    {71738, "Corrosion", 758, "E"},
    {70873, "Emerald Vigor", 758, "E"},
    {71283, "Gut Spray", 758, "E"},
    {70633, "Gut Spray", 758, "H"},
    {70126, "Frost Beacon", 758, "EH"},
    {72762, "Defile", 758, "E"},
    {70337, "Necrotic Plague", 758, "E"},
    {72149, "Shockwave", 758, "E"},
    {68980, "Harvest Soul", 758, "H"},
    -- Utgarde Keep
    {25168, "Frost Tomb", 285, "H"},
    -- The Ruby Sanctum
    {75887, "Blazing Aura", 761, "E"},
    {74502, "Enervating Brand", 761, "E"},
}

--! Имена инстансов берём из публичной F.GetExpansionData, а не из файловых
--! локалов модуля Raid Debuffs (правило 3: приватное остаётся приватным).
local function RDInstanceNames()
    local F = Cell.funcs
    local map = {}
    local data = F and F.GetExpansionData and F.GetExpansionData()
    for _, instances in pairs(data or {}) do
        for _, iTable in pairs(instances) do
            if iTable.id and not map[iTable.id] then map[iTable.id] = iTable.name end
        end
    end
    return map
end

--! Разбор ровно тот же, что у F.GetDebuffList: запись без trackByID матчится по
--! имени, с trackByID - по числовому id. Иначе «покрыто» будет врать.
local function RDCollect()
    local F = Cell.funcs
    local loaded = Cell.snippetVars and Cell.snippetVars.loadedDebuffs
    local total, alive = 0, 0
    local dead, byName, byId = {}, {}, {}

    for instanceId, iTable in pairs(loaded or {}) do
        byName[instanceId] = byName[instanceId] or {}
        byId[instanceId] = byId[instanceId] or {}
        for bossId, bTable in pairs(iTable) do
            for _, listName in ipairs(RD_LISTS) do
                for _, t in pairs(bTable[listName] or {}) do
                    total = total + 1
                    local name = F.GetSpellInfo(t.id)
                    if name then
                        alive = alive + 1
                        if t.trackByID then
                            byId[instanceId][t.id] = true
                        else
                            byName[instanceId][name] = true
                        end
                    else
                        tinsert(dead, {
                            id = t.id, instanceId = instanceId, bossId = bossId,
                            trackByID = t.trackByID, enabled = listName == "enabled",
                        })
                    end
                end
            end
        end
    end
    return total, alive, dead, byName, byId
end

local function RDSortDead(a, b)
    if a.instanceId ~= b.instanceId then return a.instanceId < b.instanceId end
    return a.id < b.id
end

local function CmdRaidDebuffs(rest)
    local arg = (rest or ""):match("%S+")
    arg = arg and arg:lower() or nil

    local F = Cell.funcs
    if not (F and F.GetSpellInfo) or not (Cell.snippetVars and Cell.snippetVars.loadedDebuffs) then
        Say(C_WARN .. "raiddebuffs: модуль Raid Debuffs ещё не загрузился" .. C_OFF)
        return
    end

    local names = RDInstanceNames()
    local total, alive, dead, byName, byId = RDCollect()

    Say(format("%sraiddebuffs%s: записей %d, живых %d, %sмёртвых %d%s",
        C_HEAD, C_OFF, total, alive, #dead > 0 and C_WARN or C_OK, #dead, C_OFF))

    --! WotLK fix: главный вопрос - жив ли АКТИВНЫЙ список текущей зоны, а не только
    --! база loadedDebuffs. До фикса UpdateDebuffsForCurrentZone (Indicators/Built-in.lua)
    --! любое событие RaidDebuffsChanged про ЧУЖОЙ инстанс обнуляло активный список, и в
    --! игре это выглядело просто как «индикатор перестал работать» - изнутри аддона
    --! проверить было нечем, currentAreaDebuffs это file-local. Проверка: дамп -> правка
    --! дебаффа в Options для другого инстанса -> дамп снова, число не должно измениться.
    local I = Cell.iFuncs
    local zone = (F.GetInstanceName and F.GetInstanceName()) or "?"
    if I and I.GetCurrentAreaDebuffs then
        local area = I.GetCurrentAreaDebuffs()
        local nAll, nId, nName = 0, 0, 0
        for k in pairs(area or {}) do
            nAll = nAll + 1
            if type(k) == "number" then nId = nId + 1 else nName = nName + 1 end
        end
        Say(format("  зона %q: активных записей %s%d%s (по имени %d, по id %d)",
            zone, nAll > 0 and C_OK or C_WARN, nAll, C_OFF, nName, nId))
        if nAll == 0 then
            Say(format("  %sактивный список пуст%s - вне инстанса это норма, но если стоишь"
                .. " в рейде из списка выше, это и есть обнуление", C_WARN, C_OFF))
        end
    else
        Say("  " .. C_WARN .. "I.GetCurrentAreaDebuffs нет" .. C_OFF
            .. " - Indicators/Built-in.lua без фикса обнуления")
    end

    --! WotLK fix: пустой активный список сам по себе не говорит, ПОЧЕМУ он пуст. Ключ
    --! instanceNameMapping[имя зоны] точный, а имя приходит от клиента (GetInstanceInfo),
    --! то есть локализованное или просто написанное иначе, чем в дампе Encounter Journal
    --! ("Hyjal Summit" против "The Battle for Mount Hyjal", "Atal'Hakkar" против
    --! "Atal'hakkar"). Тогда список пуст молча и снаружи это не отличить от "в этой зоне
    --! дебаффов нет". Печатаем, во что имя свелось: строка ниже - прямой вердикт по карте
    --! псевдонимов (GAP-004), а не по её следствию.
    if F.GetInstanceAndBossId and zone ~= "" and zone ~= "?" then
        local iId = F.GetInstanceAndBossId(zone)
        if iId then
            local iName = F.GetInstanceAndBossName and F.GetInstanceAndBossName(iId)
            Say(format("  имя зоны свелось к инстансу %s%q%s (id %d)",
                C_OK, iName or "?", C_OFF, iId))
        else
            Say(format("  %sимя зоны %q ни к одному инстансу не свелось%s - вне инстанса это"
                .. " норма; внутри означает, что нужен псевдоним в instanceNameAliases",
                C_WARN, zone, C_OFF))
        end
    end

    if total == 0 then
        --! Подсказка была неверной: она советовала «открой Options -> Raid Debuffs один раз».
        --! Панель тут ни при чём. Файлы данных отдают таблицы в F.LoadBuiltInDebuffs, а тот
        --! наполняет только unsortedDebuffs (RaidDebuffs_Classic.lua:109); loadedDebuffs строит
        --! LoadDebuffs (:230) на колбэке UpdateRaidDebuffs из eventFrame:PLAYER_LOGIN()
        --! (Core_Wrath.lua:1129). То есть после входа таблица полна без всякого участия
        --! оператора, и пустота означает либо «ещё не вошли/идёт загрузка», либо настоящий сбой.
        Say("  loadedDebuffs пуст - LoadDebuffs собирает его на PLAYER_LOGIN;"
            .. " если это уже после входа, данные не загрузились - смотреть LoadRaidDebuffs_Wrath.xml")
        return
    end

    table.sort(dead, RDSortDead)
    local limit = (arg == "full") and #dead or (#dead > 30 and 30 or #dead)
    for i = 1, limit do
        local d = dead[i]
        Say(format("  %sмёртв%s id=%s  %s(%s) boss=%s%s%s",
            C_WARN, C_OFF, tostring(d.id), names[d.instanceId] or "?", tostring(d.instanceId),
            tostring(d.bossId), d.trackByID and " [по id]" or "",
            d.enabled and "" or " [выключен по умолчанию]"))
    end
    if #dead > limit then
        Say(format("  ... и ещё %d, весь список: %s/cell debug raiddebuffs full%s",
            #dead - limit, C_KEY, C_OFF))
    end

    local covered, missing, absent = 0, 0, 0
    for i = 1, #RD_PROBE do
        local id, label, instanceId, src =
            RD_PROBE[i][1], RD_PROBE[i][2], RD_PROBE[i][3], RD_PROBE[i][4]
        local name = F.GetSpellInfo(id)
        if not name then
            absent = absent + 1
            Say(format("  %sнет в клиенте%s id=%d %s [%s] - значит эта запись мёртвая и у эталона",
                C_WARN, C_OFF, id, label, src))
        elseif (byId[instanceId] and byId[instanceId][id])
            or (byName[instanceId] and byName[instanceId][name]) then
            covered = covered + 1
        else
            missing = missing + 1
            Say(format("  %sНЕ ПОКРЫТО%s id=%d [%s] %s = %q (%s)",
                C_WARN, C_OFF, id, src, label, name, names[instanceId] or tostring(instanceId)))
        end
    end
    Say(format("сверка с эталонами E=ElvUI 6.09, H=HealBot 3.3.5.4 (%d id, которых "
        .. "у Cell нет): покрыто по имени %s%d%s, не покрыто %s%d%s, отсутствует в клиенте %d",
        #RD_PROBE, C_OK, covered, C_OFF, missing > 0 and C_WARN or C_OK, missing, C_OFF, absent))
end

-------------------------------------------------
-- indicators: чей набор индикаторов показывает профиль
-------------------------------------------------
--! Why this exists: the owner reported that a custom indicator group keeps its
--! on/off state when he switches profiles. Every write path in the options is a
--! deep copy, so the only way two profiles can share one Enabled flag is by
--! sharing the indicator TABLE itself - and that sharing is invisible: "Sync With"
--! reads None on both sides once the key is cleared, while the tables stay welded
--! (see the fixes in Indicators.lua and Revise.lua). Nothing on screen can tell
--! the two states apart, hence a dump that compares table identity.
local function CmdIndicators()
    if type(CellDB) ~= "table" or type(CellDB["layouts"]) ~= "table" then
        Say(C_WARN .. "CellDB.layouts недоступен" .. C_OFF)
        return
    end

    local builtIns = (Cell.defaults and Cell.defaults.builtIns) or 0
    local live = Cell.snippetVars and Cell.snippetVars.enabledIndicators

    local names = {}
    for name in pairs(CellDB["layouts"]) do
        if type(name) == "string" then tinsert(names, name) end
    end
    table.sort(names)

    Say(format("%sпрофили индикаторов%s: %d, активный = %s%s%s (%s)",
        C_HEAD, C_OFF, #names,
        C_KEY, tostring(Cell.vars and Cell.vars.currentLayout), C_OFF,
        tostring(Cell.vars and Cell.vars.groupType)))

    local claimedBy, welds = {}, 0
    for _, name in ipairs(names) do
        local layout = CellDB["layouts"][name]
        local indicators = type(layout) == "table" and layout["indicators"]

        if type(indicators) ~= "table" then
            print(format("  %s%s%s: %sнет таблицы индикаторов%s", C_KEY, name, C_OFF, C_WARN, C_OFF))
        else
            local sharedWith = claimedBy[indicators]
            if not sharedWith then claimedBy[indicators] = name end

            local syncWith = layout["syncWith"]
            local declared = sharedWith and (syncWith == sharedWith
                or (type(CellDB["layouts"][sharedWith]) == "table"
                    and CellDB["layouts"][sharedWith]["syncWith"] == name))

            local shareStr = "своя таблица"
            if sharedWith then
                if declared then
                    shareStr = format("общая с %s (синхронизация)", sharedWith)
                else
                    welds = welds + 1
                    shareStr = format("%sОБЩАЯ с %s БЕЗ синхронизации%s", C_WARN, sharedWith, C_OFF)
                end
            end

            local customN = #indicators - builtIns
            print(format("  %s%s%s%s  %s  синхр.: %s  своих групп: %d",
                C_KEY, name, C_OFF,
                name == (Cell.vars and Cell.vars.currentLayout) and " (АКТИВНЫЙ)" or "",
                shareStr,
                syncWith and tostring(syncWith) or "Нет",
                customN > 0 and customN or 0))

            for i = builtIns + 1, #indicators do
                local t = indicators[i]
                if type(t) == "table" then
                    local on = t["enabled"] and (C_OK .. "ВКЛ" .. C_OFF) or "выкл"
                    local mismatch = ""
                    if name == (Cell.vars and Cell.vars.currentLayout) and type(live) == "table" then
                        local liveOn = live[t["indicatorName"]] and true or false
                        if liveOn ~= (t["enabled"] and true or false) then
                            mismatch = format("  %sна кнопках: %s%s", C_WARN, liveOn and "ВКЛ" or "выкл", C_OFF)
                        end
                    end
                    print(format("      %s [%s] %s = %s%s",
                        tostring(t["name"]), tostring(t["type"]),
                        tostring(t["indicatorName"]), on, mismatch))
                end
            end
        end
    end

    if welds > 0 then
        Say(format("%sнайдено сварок: %d%s - у этих профилей вкл/выкл индикаторов физически "
            .. "не может отличаться. Расцепляются сами при следующем входе в игру.",
            C_WARN, welds, C_OFF))
    else
        Say(C_OK .. "сварок без синхронизации нет: у каждого профиля свой набор" .. C_OFF)
    end
end

-------------------------------------------------
-- Debug.lua вызывает наши билдеры ПОСЛЕ блока callbacks, чтобы
-- /cell debug dump одной копипастой выдавал полный снимок сессии.
if D.DumpSections then
    table.insert(D.DumpSections, BuildEnvLines)
    table.insert(D.DumpSections, BuildTimerLines)
    table.insert(D.DumpSections, BuildGlowLines)
    table.insert(D.DumpSections, BuildAnimLines)
    table.insert(D.DumpSections, BuildRingLines)
end

-------------------------------------------------
-- врезка в /cell debug
-------------------------------------------------
local EXTRA = {
    shims = CmdShims,
    ret = CmdRet,
    ev = CmdEv,
    aura = CmdAura,
    perf = CmdPerf,
    err = CmdErr,
    env = CmdEnv,
    timers = CmdTimers,
    glow = CmdGlow,
    anim = CmdAnim,
    log = CmdLog,
    roles = CmdRoles,
    count = CmdCount,
    movers = CmdMovers,
    threat = CmdThreat,
    readycheck = CmdReadyCheck,
    raiddebuffs = CmdRaidDebuffs,
    indicators = CmdIndicators,
}

local origHandle = D.HandleCommand

function D:HandleCommand(option, raw)
    -- raw сохраняет регистр: имена функций и событий регистрозависимы,
    -- а Core_Wrath приводит команду к нижнему регистру.
    local line = raw or option or ""
    local sub, rest = line:match("^(%S*)%s*(.-)$")
    --! WotLK fix: chat macros and copied command lists are commonly terminated
    --! with semicolons. WoW passes that punctuation to the slash handler, so
    --! "timers;" did not match EXTRA.timers and fell through to debug toggle.
    --! Strip only trailing command separators; preserve punctuation inside
    --! case-sensitive API/event names and the rest of the argument line.
    sub = (sub or ""):gsub("[;,]+$", "")
    rest = (rest or ""):gsub("%s*[;,]+%s*$", "")
    local subLower = sub:lower()
    local handler = EXTRA[subLower]
    if handler then
        handler(rest)
        return
    end
    if subLower == "help" or subLower == "h" then
        origHandle(self, "help")
        print(C_HEAD .. "Расширение 3.3.5a:" .. C_OFF)
        print("  /cell debug shims [фильтр] - что слой совместимости добавил и переопределил")
        print("  /cell debug ret <Функция> [аргументы] - сколько значений реально возвращает")
        print("  /cell debug ev <СОБЫТИЕ>|off|list - логировать реальные аргументы события")
        print("  /cell debug aura <юнит> [HELPFUL|HARMFUL] - контракт UnitAura (11 полей)")
        print("  /cell debug perf [секунды] - перепись OnUpdate и прирост мусора")
        print("  /cell debug err - перехват ошибок Lua с трейсом")
        print(C_HEAD .. "Диагностические дампы:" .. C_OFF)
        print("  /cell debug env - владельцы API: C_Timer, PixelUtil, LCG, libs, память")
        print("  /cell debug timers - активные Cell.C_Timer-таймеры (top 20)")
        print("  /cell debug glow - LCG pools (GlowFramePool, ButtonGlowPool, ProcGlowPool)")
        print("  /cell debug anim - очередь pendingStops (реентрантные Stop)")
        print("  /cell debug log on|off|show [N]|clear - кольцевой буфер последних N событий")
        print("  /cell debug roles - источник роли каждого участника группы/рейда")
        print("  /cell debug movers - состояние мувер-фреймов: мышь, размер, protected, сохранённая позиция")
        print("  /cell debug threat [on|off] - снимок угрозы по группе; on/off считает частоту threat-событий")
        print("  /cell debug readycheck [off] - сырые аргументы READY_CHECK_* и перебор ростера рядом (GAP-005)")
        print("  /cell debug raiddebuffs [full] - какие встроенные raid-debuff id мёртвы на 3.3.5 + сверка с ElvUI")
        print("  /cell debug indicators - чей набор индикаторов у каждого профиля: свой или общий, и вкл/выкл своих групп")
        print("  /cell debug count - one-line dashboard")
        return
    end
    return origHandle(self, option)
end
