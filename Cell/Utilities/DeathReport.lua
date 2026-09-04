local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local L = Cell.L
local F = Cell.funcs

local UnitIsFeignDeath = UnitIsFeignDeath
--! WotLK fix: consume Cell-private group adapters.
local IsInGroup = Cell.IsInGroup
local IsInRaid = Cell.IsInRaid
--! WotLK fix: убран `local IsEncounterInProgress = IsEncounterInProgress`. Функции на
--! 3.3.5 нет (добавлена в 5.0), так что локал всегда был nil, и оба места в файле
--! (Report и GroupRosterUpdate) и без него зовут приватный Cell.IsEncounterInProgress
--! из Core_Wrath.lua, который теперь получает состояние боя от DBM.
--! Мёртвая привязка опасна тем, что читает чужой глобал: аддон, объявивший своё
--! IsEncounterInProgress, подсунул бы Cell чужую реализацию (CLAUDE.md §3).
--! WotLK fix: bind the native 3.3.5 spell-link API directly; do not require a
--! partial global C_Spell namespace from Cell's compatibility layer.
local GetSpellLink = GetSpellLink

----------------------------------------------------
-- vars
----------------------------------------------------
local init, instanceType, inInstance
local deathLogs = {
    -- time, type, name, ability, school, amount, overkill, resisted, blocked, absorbed, critical, sourceName
}
local limit, count
local blacklist = {
    [124255] = true
}

local overkillFormat, resistedFormat, blockedFormat, absorbedFormat, criticalText
if Cell.isAsian then
    overkillFormat = string.sub(_G.TEXT_MODE_A_STRING_RESULT_OVERKILLING, 4, string.len(_G.TEXT_MODE_A_STRING_RESULT_OVERKILLING)-3)
    resistedFormat = string.sub(_G.TEXT_MODE_A_STRING_RESULT_RESIST, 4, string.len(_G.TEXT_MODE_A_STRING_RESULT_RESIST)-3)
    blockedFormat = string.sub(_G.TEXT_MODE_A_STRING_RESULT_BLOCK, 4, string.len(_G.TEXT_MODE_A_STRING_RESULT_BLOCK)-3)
    absorbedFormat = string.sub(_G.TEXT_MODE_A_STRING_RESULT_ABSORB, 4, string.len(_G.TEXT_MODE_A_STRING_RESULT_ABSORB)-3)
    criticalText = string.sub(_G.TEXT_MODE_A_STRING_RESULT_CRITICAL, 4, string.len(_G.TEXT_MODE_A_STRING_RESULT_CRITICAL)-3)
else
    overkillFormat = strlower(string.gsub(_G.TEXT_MODE_A_STRING_RESULT_OVERKILLING, "[()]", ""))
    resistedFormat = strlower(string.gsub(_G.TEXT_MODE_A_STRING_RESULT_RESIST, "[()]", ""))
    blockedFormat = strlower(string.gsub(_G.TEXT_MODE_A_STRING_RESULT_BLOCK, "[()]", ""))
    absorbedFormat = strlower(string.gsub(_G.TEXT_MODE_A_STRING_RESULT_ABSORB, "[()]", ""))
    criticalText = strlower(string.gsub(_G.TEXT_MODE_A_STRING_RESULT_CRITICAL, "[()]", ""))
end

--! WotLK fix: on 3.3.5a these combat-text globals carry %d, not %s -- the client
--! ships TEXT_MODE_A_STRING_RESULT_OVERKILLING = "(%d Overkill)" (read out of
--! patch-enUS-3.MPQ, Interface\FrameXML\GlobalStrings.lua; likewise ABSORB, BLOCK
--! and RESIST). But the only caller feeds F.FormatNumber(), which returns a NUMBER
--! below 1000 and a STRING above it ("12.4K", "1.2M" -- Utils.lua:439).
--! string.format("%d overkill", "12.4K") is a hard error under Lua 5.1, "bad
--! argument #2 to 'format' (number expected, got string)", verified on lupa.lua51;
--! "999" coerces fine, which is exactly why the defect hides outside raids. In a
--! raid overkill above 1000 is the norm (Icehowl's charge, Blood Boil, Soul
--! Reaper), so the death report dies on the first real death and keeps dying.
--! Widening %d to %s is safe in both directions: %s prints the number just as %d
--! did. The positional form is covered too, because %1$d is native GlobalStrings
--! syntax on 3.3.5a and this client's locale MPQ cannot be assumed to be enUS --
--! the capture keeps the index, so %1$d becomes %1$s rather than being mangled.
--! Only overkillFormat has a live call site today (the resisted/blocked/absorbed
--! lines are commented out upstream), but all four are widened so that re-enabling
--! one cannot resurrect the crash. criticalText carries no placeholder at all.
local function WidenToString(fmt)
    return (string.gsub(fmt, "(%%%d*%$?)d", "%1s"))
end
overkillFormat = WidenToString(overkillFormat)
resistedFormat = WidenToString(resistedFormat)
blockedFormat = WidenToString(blockedFormat)
absorbedFormat = WidenToString(absorbedFormat)

----------------------------------------------------
-- functions
----------------------------------------------------
local function UpdateDeathLog(guid, ...)
    if not deathLogs[guid] then
        deathLogs[guid] = {}
    end

    deathLogs[guid]["time"], deathLogs[guid]["type"], deathLogs[guid]["name"], deathLogs[guid]["ability"],
    deathLogs[guid]["school"], deathLogs[guid]["amount"], deathLogs[guid]["overkill"], deathLogs[guid]["resisted"],
    deathLogs[guid]["blocked"], deathLogs[guid]["absorbed"], deathLogs[guid]["critical"], deathLogs[guid]["sourceName"] = ...

    deathLogs[guid]["reported"] = false
end

local function Send(msg)
    -- F.Print(strupper(ACTION_UNIT_DIED)..": "..msg)
    if Cell.hasHighestPriority then
        --! WotLK fix: stock 3.3.5a has no INSTANCE_CHAT channel.
        SendChatMessage(strupper(ACTION_UNIT_DIED)..": "..msg, IsInRaid() and "RAID" or "PARTY")
    end
end

local function Report(guid)
    if not deathLogs[guid] or deathLogs[guid]["reported"] then return end
    deathLogs[guid]["reported"] = true

    if instanceType == "raid" and Cell.IsEncounterInProgress() then
        count = count + 1
        if count > limit then
            return
        end
    end

    if not deathLogs[guid]["type"] or time()-deathLogs[guid]["time"]>=1 then -- unkown
        -- Send(deathLogs[guid]["name"].." > "..strlower(_G.UNKNOWN))
        Send(deathLogs[guid]["name"])

    elseif deathLogs[guid]["type"] == "INSTAKILL" then
        Send(deathLogs[guid]["name"].." > "..L["instakill"])

    elseif deathLogs[guid]["type"] == "ENVIRONMENTAL" then
        Send(deathLogs[guid]["name"].." > "..F.FormatNumber(deathLogs[guid]["amount"]).." ("..deathLogs[guid]["ability"]..")")

    else -- SPELL & RANGE & SWING
        -- local damageDetails = {}
        local damageDetails = ""

        if deathLogs[guid]["overkill"] > 0 then
            -- tinsert(damageDetails, string.format(overkillFormat, F.FormatNumber(deathLogs[guid]["overkill"])))
            damageDetails = " ("..string.format(overkillFormat, F.FormatNumber(deathLogs[guid]["overkill"]))..") "
        end
        -- if deathLogs[guid]["critical"] == 1 then
        --     tinsert(damageDetails, criticalText)
        -- end
        -- if deathLogs[guid]["resisted"] then
        --     tinsert(damageDetails, string.format(resistedFormat, F.FormatNumber(deathLogs[guid]["resisted"])))
        -- end
        -- if deathLogs[guid]["blocked"] then
        --     tinsert(damageDetails, string.format(blockedFormat, F.FormatNumber(deathLogs[guid]["blocked"])))
        -- end
        -- if deathLogs[guid]["absorbed"] then
        --     tinsert(damageDetails, string.format(absorbedFormat, F.FormatNumber(deathLogs[guid]["absorbed"])))
        -- end

        -- damageDetails = table.concat(damageDetails, ", ")

        local sourceName = (deathLogs[guid]["sourceName"] and deathLogs[guid]["name"]~=deathLogs[guid]["sourceName"]) and (" ["..deathLogs[guid]["sourceName"].."]") or ""
        local ability

        if deathLogs[guid]["type"] == "SPELL" then -- including RANGE
            -- tinsert(damageDetails, strlower(CombatLog_String_SchoolString(deathLogs[guid]["school"])))
            ability = deathLogs[guid]["ability"]
        else -- SWING
            ability = strlower(_G.MELEE)
        end

        -- damageDetails = table.concat(damageDetails, ", ")
        -- if damageDetails ~= "" then damageDetails = " ("..damageDetails..") " end
        Send(deathLogs[guid]["name"].." > "..ability.." "..F.FormatNumber(deathLogs[guid]["amount"])..damageDetails..sourceName)
    end

    -- wipe(deathLogs[guid])
end

----------------------------------------------------
-- event
----------------------------------------------------
local frame = CreateFrame("Frame")
-- frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

--! WotLK fix: ENCOUNTER_START/END do not exist on 3.3.5 (added 5.4), so these two
--! handlers used to be unreachable and the report cap below never engaged - every
--! death of a 25-man wipe went to /raid. Core_Wrath.lua now bridges DBM's
--! DBM_Pull/DBM_Kill/DBM_Wipe into Cell's own EncounterStart/EncounterEnd
--! callbacks, so subscribe to those instead of to the missing frame events.
local function EncounterStart()
    count = 0
end

local function EncounterEnd()
    frame:GroupRosterUpdate()
end

local function RegisterEncounterCallbacks()
    Cell.RegisterCallback("EncounterStart", "DeathReport_EncounterStart", EncounterStart)
    Cell.RegisterCallback("EncounterEnd", "DeathReport_EncounterEnd", EncounterEnd)
end

local function UnregisterEncounterCallbacks()
    Cell.UnregisterCallback("EncounterStart", "DeathReport_EncounterStart")
    Cell.UnregisterCallback("EncounterEnd", "DeathReport_EncounterEnd")
end

function frame:PLAYER_ENTERING_WORLD()
    local isIn, iType = IsInInstance()
    instanceType = iType

    if instanceType == "pvp" or instanceType == "arena" then
        UnregisterEncounterCallbacks()
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        return
    end

    if not init then frame:GroupRosterUpdate() end
    if isIn then
        inInstance = true
        if instanceType == "raid" then
            RegisterEncounterCallbacks()
            count = 0
        else
            UnregisterEncounterCallbacks()
        end
    elseif inInstance then -- left insntance
        inInstance = false
        wipe(deathLogs)
        UnregisterEncounterCallbacks()
    end
    -- texplore(deathLogs)
end

local timer
--! WotLK fix: consume Core_Wrath's private roster callback instead of the
--! non-native GROUP_ROSTER_UPDATE frame event.
function frame:GroupRosterUpdate()
    if IsInGroup() then
        --! During a boss fight the priority re-check simply waits: EncounterEnd
        --! above runs this same function once the fight is over.
        if not Cell.IsEncounterInProgress() then
            if timer then timer:Cancel() end
            timer = C_Timer.NewTimer(7, function()
                F.CheckPriority()
            end)
        end
    else
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
    init = true
end

--! WotLK fix: consume native 3.3.5 CLEU directly. The common payload is
--! timestamp, event, sourceGUID/name/flags, destGUID/name/flags; event data
--! starts at slot 9. This removes ownership of death reporting from the
--! global ClassicAPI retail-layout translator.
--! WotLK perf: слоты объявлены параметрами вместо ... . В Lua 5.1 vararg-функция
--! платит adjust_varargs на входе и опкод VARARG на каждую распаковку, а сверх
--! этого здесь было до трёх C-вызовов select() на каждое событие урона. Самый
--! длинный вариант - SPELL_DAMAGE (суффикс с 12-го слота, critical на 18-м),
--! поэтому объявлено ровно восемнадцать. Незаполненные слоты в рантайме бесплатны.
function frame:COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, sourceGUID, sourceName,
    sourceFlags, destGUID, destName, destFlags,
    arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18)

    local amount, overkill, school, resisted, blocked, absorbed, critical -- glancing, crushing

    -- arg9, arg10, arg11:
    -- UNIT_DIED: event-specific data, if any
    -- ENVIRONMENTAL: environmentalType, then damage suffix
    -- SPELL/RANGE: spellId, spellName, spellSchool

    -- if string.find(destGUID, "^Player") then -- debug
    --! WotLK fix: 3.3.5 combat-log GUIDs are hex ("0x0000000000012345"), the
    --! "Player-realm-id" format arrived in 6.0. F.IsPlayer handles both.
    if F.IsPlayer(destGUID) and F.IsFriend(destFlags) then
        --! WotLK perf: one chain instead of six independent ifs. `event` cannot be
        --! two things at once, so every test after the matching one was dead work -
        --! and this runs on the combat log, where the overwhelming majority of lines
        --! match none of them and used to pay all six comparisons.
        if event == "SPELL_INSTAKILL" then
            UpdateDeathLog(destGUID, timestamp, "INSTAKILL", destName)

        elseif event == "ENVIRONMENTAL_DAMAGE" then
            --! WotLK perf: суффикс лежит по фиксированным позициям (кодекс,
            --! ENVIRONMENTAL_DAMAGE): 9 - environmentalType, дальше amount.
            --! Раньше здесь был C-вызов select(10, ...) на каждое такое событие.
            amount, overkill, school, resisted, blocked, absorbed, critical = arg10, arg11, arg12, arg13, arg14, arg15, arg16
            amount = amount == 0 and absorbed or amount
            -- _G.ENVIRONMENTAL_DAMAGE.." "..
            UpdateDeathLog(destGUID, timestamp, "ENVIRONMENTAL", destName, strlower(_G["ACTION_ENVIRONMENTAL_DAMAGE_" .. strupper(arg9)]), nil, amount)

        elseif event == "SWING_DAMAGE" then
            --! WotLK perf: у SWING нет префиксных аргументов - суффикс начинается
            --! с девятого слота (кодекс, SWING_DAMAGE). select(9, ...) не нужен.
            amount, overkill, school, resisted, blocked, absorbed, critical = arg9, arg10, arg11, arg12, arg13, arg14, arg15
            UpdateDeathLog(destGUID, timestamp, "SWING", destName, nil, school, amount, overkill or -1, resisted, blocked, absorbed, critical, sourceName)

        elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" then
            if not blacklist[arg9] then
                --! WotLK perf: префикс SPELL/RANGE занимает слоты 9-11
                --! (spellId, spellName, spellSchool), суффикс идёт с двенадцатого.
                amount, overkill, school, resisted, blocked, absorbed, critical = arg12, arg13, arg14, arg15, arg16, arg17, arg18
                local spellLink = GetSpellLink(arg9)
                UpdateDeathLog(destGUID, timestamp, "SPELL", destName, spellLink, school, amount, overkill or -1, resisted, blocked, absorbed, critical, sourceName)
            end

        elseif event == "SPELL_AURA_APPLIED" then
            -- print(arg9, arg10, arg11)
            if arg9 == 27827 or arg9 == 358164 then -- 救赎之魂 or 灵魂疲惫
                C_Timer.After(0.25, function()
                    Report(destGUID)
                end)
            end

        elseif event == "UNIT_DIED" and not UnitIsFeignDeath(destName) then
            C_Timer.After(0.5, function()
                if not deathLogs[destGUID] then deathLogs[destGUID] = {["name"]=destName} end
                Report(destGUID)
            end)
        end
    end
end

--! WotLK perf: frame слушает ровно два события - CLEU и PLAYER_ENTERING_WORLD
--! (у второго payload из одного значения, кодекс). Восемнадцати слотов хватает
--! обоим, поэтому диспетчер объявлен именованными параметрами и не является
--! vararg-функцией: в Lua 5.1 объявление ... стоит adjust_varargs при входе и
--! опкод VARARG на каждую распаковку, а CLEU в рейде - сотни вызовов в секунду.
frame:SetScript("OnEvent", function(self, event,
    a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18)

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        --! WotLK fix: the death-report handler owns native CLEU parsing and no
        --! longer depends on the global CombatLogGetCurrentEventInfo translator.
        self:COMBAT_LOG_EVENT_UNFILTERED(a1, a2, a3, a4, a5, a6, a7, a8,
            a9, a10, a11, a12, a13, a14, a15, a16, a17, a18)
    else
        self[event](self, a1, a2, a3, a4, a5, a6, a7, a8,
            a9, a10, a11, a12, a13, a14, a15, a16, a17, a18)
    end
end)

----------------------------------------------------
-- priority
----------------------------------------------------
local function UpdatePriority(hasHighestPriority)
    if hasHighestPriority and CellDB["tools"]["deathReport"][1] then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end
Cell.RegisterCallback("UpdatePriority", "DeathReport_UpdatePriority", UpdatePriority)

----------------------------------------------------
-- UpdateTools
----------------------------------------------------
local enabled
local function UpdateTools(which)
    if not which or which == "deathReport" then
        if CellDB["tools"]["deathReport"][1] then
            frame:RegisterEvent("PLAYER_ENTERING_WORLD")
            Cell.RegisterCallback(
                "GroupRosterUpdate",
                "DeathReport_GroupRosterUpdate",
                frame.GroupRosterUpdate
            )

            limit = CellDB["tools"]["deathReport"][2]
            count = 0
            if not enabled and which == "deathReport" then -- already in world, manually enabled
                frame:PLAYER_ENTERING_WORLD()
            end
            enabled = true
        else
            frame:UnregisterAllEvents()
            Cell.UnregisterCallback(
                "GroupRosterUpdate",
                "DeathReport_GroupRosterUpdate"
            )
            wipe(deathLogs)
            enabled = false
        end
    end
end
Cell.RegisterCallback("UpdateTools", "DeathReport_UpdateTools", UpdateTools)