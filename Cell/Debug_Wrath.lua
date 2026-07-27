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
-- ADDED     — метода/глобала в 3.3.5 не было, слой совместимости добавил (полифилл).
-- OVERRIDDEN — метод/глобал БЫЛ нативным, слой совместимости заменил его обёрткой.
--              Это и есть перф-налог: обёртка вызывается из всего UI.
local function CmdShims(pattern)
    local snap = Cell.nativeSnapshot
    if not snap or not snap.ready then
        Say(C_WARN .. "снимок нативного API не снят" .. C_OFF ..
            " — DebugSnapshot.lua должен грузиться первым в Cell.toc")
        return
    end
    pattern = (pattern ~= "" and pattern) or nil

    local addedN, overN = 0, 0
    local out = {}

    for i = 1, #(snap.watched or {}) do
        local name = snap.watched[i]
        local before = snap.globals[name]
        local nowT = type(_G[name])
        if not pattern or name:lower():find(pattern, 1, true) then
            if before == nil and nowT ~= "nil" then
                tinsert(out, format("  %sADDED%s      %-34s (%s) — полифилл, в 3.3.5 не было",
                    C_OK, C_OFF, name, nowT))
                addedN = addedN + 1
            elseif before ~= nil and nowT ~= before then
                tinsert(out, format("  %sTYPE%s       %-34s %s -> %s",
                    C_WARN, C_OFF, name, before, nowT))
                overN = overN + 1
            end
        end
    end

    -- методы виджетов
    local probe = CreateFrame("Frame")
    probe:Hide()
    local live = {
        Frame = probe,
        Texture = probe:CreateTexture(),
        FontString = probe:CreateFontString(),
    }
    for label, obj in pairs(live) do
        local was = snap.widgets[label]
        local mt = getmetatable(obj)
        local index = mt and mt.__index
        if was and type(index) == "table" then
            for k, v in pairs(index) do
                if type(k) == "string" and type(v) == "function" then
                    if not pattern or k:lower():find(pattern, 1, true) then
                        if not was[k] then
                            tinsert(out, format("  %sADDED%s      %s:%s()", C_OK, C_OFF, label, k))
                            addedN = addedN + 1
                        end
                    end
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
                    C_WARN, C_OFF, name, snap.globals[name]))
            end
        end
    end

    Say(format("%sслой совместимости%s: добавлено %d, переопределено %d, занято чужим аддоном %d (нативных %d)",
        C_HEAD, C_OFF, addedN, overN, #foreign, nativeN))
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
    Say("нативные методы, которых в 3.3.5 нет и без полифилла быть не может — норма;")
    Say("подозрительно обратное: обёртка ПОВЕРХ существующего нативного метода.")

    --! WotLK fix (coexistence): учёт самого слоя совместимости.
    --! CellClassicAPI.__meta заполняется Provide/Merge/ProvideMethod, то есть
    --! показывает не догадку по снимку, а факт: какое имя мы опубликовали, какое
    --! уже принадлежало другому аддону (работает ЧУЖАЯ реализация, наша осталась
    --! приватной в CellClassicAPI) и в какую таблицу мы долили отсутствующие ключи.
    local capi = _G.CellClassicAPI
    local meta = capi and capi.__meta
    if not meta then
        Say(C_WARN .. "CellClassicAPI не загружен" .. C_OFF ..
            " — Libs\\ClassicAPI\\Load.xml должен грузиться до Polyfills.lua")
        return
    end

    local function Collect(tbl, formatter)
        local list = {}
        for name, value in pairs(tbl or {}) do
            if not pattern or name:lower():find(pattern, 1, true) then
                tinsert(list, formatter(name, value))
            end
        end
        table.sort(list)
        return list
    end

    local published = Collect(meta.published, function(name) return name end)
    local foreignOwned = Collect(meta.foreign, function(name) return name end)
    local filled = Collect(meta.filled, function(name, count)
        return format("%s (+%d ключей)", name, count)
    end)

    Say(format("%sсосуществование%s: сторонний !!!ClassicAPI %s; опубликовано нами %d, занято другим аддоном %d, дозаполнено таблиц %d",
        C_HEAD, C_OFF,
        meta.standalone and (C_WARN .. "ЕСТЬ" .. C_OFF) or (C_OK .. "нет" .. C_OFF),
        #published, #foreignOwned, #filled))

    if meta.widgetMethodsInjected then
        Say(format("методы виджетов: добавлено %d, оставлено чужими/нативными %d",
            meta.widgetMethodsInjected, meta.widgetMethodsLeftAlone or 0))
    end

    local duplicated = Collect(meta.duplicate, function(name) return name end)
    if #duplicated > 0 then
        Say(C_WARN .. "одно имя определяют два НАШИХ слоя" .. C_OFF ..
            " (либа и Polyfills.lua) — работает тот, кто загрузился раньше:")
        print("  " .. tconcat(duplicated, ", "))
    end

    if #foreignOwned > 0 then
        Say("глобал принадлежит другому аддону, наша версия доступна как CellClassicAPI.<имя>:")
        print("  " .. C_KEY .. tconcat(foreignOwned, ", ") .. C_OFF)
    end
    if #filled > 0 then
        Say("в чужие таблицы долиты отсутствующие ключи:")
        print("  " .. tconcat(filled, ", "))
    end
    if #published > 0 then
        Say(format("опубликовано нами (%d): %s", #published, tconcat(published, ", ")))
    end
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
    Say(format("%sфреймов всего%s %d, с OnUpdate %d (видимых %d)",
        C_HEAD, C_OFF, total, withScript, visible))
    if withScript > 40 then
        Say(format("  %sмного OnUpdate%s — каждый тикает каждый кадр", C_WARN, C_OFF))
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
        local after = collectgarbage("count")
        local grew = after - before
        Say(format("%sза %d с%s: мусора +%.0f КБ (%.1f КБ/с), FPS %.0f -> %.0f",
            C_HEAD, secs, C_OFF, grew, grew / secs, fps0, GetFramerate()))
        if grew / secs > 100 then
            Say(format("  %s>100 КБ/с%s — сборщик будет дёргать клиент в рейде",
                C_WARN, C_OFF))
        end
    end)
    Say(format("замер %d с — не трогай интерфейс", secs))
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
-- врезка в /cell debug
-------------------------------------------------
local EXTRA = {
    shims = CmdShims,
    ret = CmdRet,
    ev = CmdEv,
    aura = CmdAura,
    perf = CmdPerf,
    err = CmdErr,
}

local origHandle = D.HandleCommand

function D:HandleCommand(option, raw)
    -- raw сохраняет регистр: имена функций и событий регистрозависимы,
    -- а Core_Wrath приводит команду к нижнему регистру.
    local line = raw or option or ""
    local sub, rest = line:match("^(%S*)%s*(.-)$")
    local handler = EXTRA[(sub or ""):lower()]
    if handler then
        handler(rest or "")
        return
    end
    if (sub or ""):lower() == "help" or (sub or ""):lower() == "h" then
        origHandle(self, "help")
        print(C_HEAD .. "Расширение 3.3.5a:" .. C_OFF)
        print("  /cell debug shims [фильтр] - что слой совместимости добавил и переопределил")
        print("  /cell debug ret <Функция> [аргументы] - сколько значений реально возвращает")
        print("  /cell debug ev <СОБЫТИЕ>|off|list - логировать реальные аргументы события")
        print("  /cell debug aura <юнит> [HELPFUL|HARMFUL] - контракт UnitAura (11 полей)")
        print("  /cell debug perf [секунды] - перепись OnUpdate и прирост мусора")
        print("  /cell debug err - перехват ошибок Lua с трейсом")
        return
    end
    return origHandle(self, option)
end
