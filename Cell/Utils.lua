---@class Cell
local Cell = select(2, ...)
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local L = Cell.L
---@class CellFuncs
local F = Cell.funcs
---@type CellIndicatorFuncs
local I = Cell.iFuncs
--! WotLK fix: realm normalization is private to Cell.
local GetNormalizedRealmName = Cell.GetNormalizedRealmName

Cell.vars.playerFaction = UnitFactionGroup("player")

-------------------------------------------------
-- game version
-------------------------------------------------
Cell.isAsian = LOCALE_zhCN or LOCALE_zhTW or LOCALE_koKR

--! WotLK fix: Polyfills.lua establishes private flavor state from this addon's
--! fixed Interface 30300 target. Do not recompute it from optional project
--! globals supplied by a custom core or standalone compatibility addon.
Cell.flavor = "wrath"
Cell.isRetail = false
Cell.isVanilla = false
Cell.isWrath = true
Cell.isCata = false
Cell.isMists = false
Cell.isTWW = false

-------------------------------------------------
-- class
-------------------------------------------------
local localizedClass = {}
FillLocalizedClassList(localizedClass)

local sortedClasses = {}
local classFileToID = {}
local classIDToFile = {}

do
    -- WARRIOR = 1,
    -- PALADIN = 2,
    -- HUNTER = 3,
    -- ROGUE = 4,
    -- PRIEST = 5,
    -- DEATHKNIGHT = 6,
    -- SHAMAN = 7,
    -- MAGE = 8,
    -- WARLOCK = 9,
    -- MONK = 10,
    -- DRUID = 11,
    -- DEMONHUNTER = 12,
    -- EVOKER = 13,
    --! WotLK: Cap at 11 (DRUID is highest class in WotLK)
    local highestClassID = 11
    for i = 1, highestClassID do
        local classFile, classID = select(2, Cell.GetClassInfoTuple(i))
        if classFile and classID == i then
            tinsert(sortedClasses, classFile)
            classFileToID[classFile] = i
            classIDToFile[i] = classFile
        end
    end
    sort(sortedClasses)
end

function F.GetClassID(classFile)
    return classFileToID[classFile]
end

function F.GetLocalizedClassName(classFileOrID)
    if type(classFileOrID) == "string" then
        return localizedClass[classFileOrID] or classFileOrID
    elseif type(classFileOrID) == "number" and classIDToFile[classFileOrID] then
        return localizedClass[classIDToFile[classFileOrID]] or classFileOrID
    end
    return ""
end

function F.IterateClasses()
    local i = 0
    return function()
        i = i + 1
        --! WotLK fix: iterate the private list actually discovered from the
        --! active class-info provider instead of publishing/reading a hard-coded
        --! retail GetNumClasses compatibility global.
        if i <= #sortedClasses then
            return sortedClasses[i], classFileToID[sortedClasses[i]], i
        end
    end
end

function F.GetSortedClasses()
    return F.Copy(sortedClasses)
end

-------------------------------------------------
-- Classic
-------------------------------------------------
    --! WotLK fix: there is no GetSpecialization on build 12340, so "spec" has to be
    --! derived from the talent trees. Returns the dominant tab index, or nil when the
    --! trees are unreadable (right after login) or when no point is spent at all -
    --! callers must be able to tell "not known yet" from "tab 1", which is why the
    --! index is a separate return value and not folded into a default.
    function F.GetDominantTalentTab()
        local maxPoints, maxTab, tabName, tabIcon = 0, nil, nil, nil

        for i = 1, GetNumTalentTabs() do
            --! WotLK fix: build 12340 returns name, icon, pointsSpent,
            --! background, previewPointsSpent; the later id-first tuple does not
            --! apply here (verified against 3.3.5a FrameXML).
            local name, icon, pointsSpent = GetTalentTabInfo(i)
            --! WotLK fix: pointsSpent is nil while the tree is still loading; the old
            --! bare `pointsSpent > maxPoints` threw "attempt to compare nil with
            --! number" there. Same readiness trap that left divineAegisMultiplier nil
            --! for nine minutes in run 13 (Core_Wrath.lua:847).
            if pointsSpent and pointsSpent > maxPoints then
                maxPoints = pointsSpent
                maxTab = i
                tabIcon = icon
                tabName = name
            end
        end

        return maxTab, tabName, tabIcon
    end

    function F.GetActiveTalentInfo()
        local which = GetActiveTalentGroup() == 1 and L["Primary Talents"] or L["Secondary Talents"]

        local _, specName, specIcon = F.GetDominantTalentTab()

        --! WotLK fix: fileID textures are unsupported on build 12340.
        return which, specIcon or "Interface\\Icons\\INV_Misc_QuestionMark", specName or L["No Spec"]
    end

-- local specRoles = {
--     ["DeathKnightBlood"] = "DAMAGER",
--     ["DeathKnightFrost"] = "TANK",
--     ["DeathKnightUnholy"] = "DAMAGER",

--     ["DruidRestoration"] = "HEALER",
--     ["DruidBalance"] = "DAMAGER",
--     -- ["DruidFeralCombat"] = nil,

--     ["HunterBeastMastery"] = "DAMAGER",
--     ["HunterSurvival"] = "DAMAGER",
--     ["HunterMarksmanship"] = "DAMAGER",

--     ["MageFrost"] = "DAMAGER",
--     ["MageArcane"] = "DAMAGER",
--     ["MageFire"] = "DAMAGER",

--     ["PaladinHoly"] = "HEALER",
--     ["PaladinCombat"] = "DAMAGER",
--     ["PaladinProtection"] = "TANK",

--     ["PriestShadow"] = "DAMAGER",
--     ["PriestHoly"] = "HEALER",
--     ["PriestDiscipline"] = "HEALER",

--     ["RogueCombat"] = "DAMAGER",
--     ["RogueSubtlety"] = "DAMAGER",
--     ["RogueAssassination"] = "DAMAGER",

--     ["ShamanElementalCombat"] = "DAMAGER",
--     ["ShamanEnhancement"] = "DAMAGER",
--     ["ShamanRestoration"] = "HEALER",

--     ["WarlockSummoning"] = "DAMAGER",
--     ["WarlockDestruction"] = "DAMAGER",
--     ["WarlockCurses"] = "DAMAGER",

--     ["WarriorArms"] = "DAMAGER",
--     ["WarriorFury"] = "DAMAGER",
--     ["WarriorProtection"] = "TANK",
-- }

-- function F.GetPlayerRole()

-- end

-------------------------------------------------
-- color
-------------------------------------------------
function F.ConvertRGB(r, g, b, desaturation)
    if not desaturation then desaturation = 1 end
    r = r / 255 * desaturation
    g = g / 255 * desaturation
    b = b / 255 * desaturation
    return r, g, b
end

function F.ConvertRGB_256(r, g, b)
    return floor(r * 255), floor(g * 255), floor(b * 255)
end

function F.ConvertRGBToHEX(r, g, b)
    local result = ""

    for key, value in pairs({r, g, b}) do
        local hex = ""

        while(value > 0)do
            local index = math.fmod(value, 16) + 1
            value = math.floor(value / 16)
            hex = string.sub("0123456789ABCDEF", index, index) .. hex
        end

        if(string.len(hex) == 0)then
            hex = "00"

        elseif(string.len(hex) == 1)then
            hex = "0" .. hex
        end

        result = result .. hex
    end

    return result
end

function F.ConvertHEXToRGB(hex)
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

-- https://wowpedia.fandom.com/wiki/ColorGradient
-- function F.ColorGradient(perc, r1,g1,b1, r2,g2,b2, r3,g3,b3)
--     perc = perc or 1
--     if perc >= 1 then
--         return r3, g3, b3
--     elseif perc <= 0 then
--         return r1, g1, b1
--     end

--     local segment, relperc = math.modf(perc * 2)
--     local rr1, rg1, rb1, rr2, rg2, rb2 = select((segment * 3) + 1, r1,g1,b1, r2,g2,b2, r3,g3,b3)

--     return rr1 + (rr2 - rr1) * relperc, rg1 + (rg2 - rg1) * relperc, rb1 + (rb2 - rb1) * relperc
-- end

function F.ColorGradient(perc, c1, c2, c3, lowBound, highBound)
    local r1, g1, b1 = c1[1], c1[2], c1[3]
    local r2, g2, b2 = c2[1], c2[2], c2[3]
    local r3, g3, b3 = c3[1], c3[2], c3[3]

    lowBound = lowBound or 0
    highBound = highBound or 1
    perc = perc or 1

    if perc >= highBound then
        return r3, g3, b3
    elseif perc <= lowBound then
        return r1, g1, b1
    end

    perc = (perc - lowBound) / (highBound - lowBound)

    local segment, relperc = math.modf(perc * 2)
    local rr1, rg1, rb1, rr2, rg2, rb2 = select((segment * 3) + 1, r1,g1,b1, r2,g2,b2, r3,g3,b3)

    return rr1 + (rr2 - rr1) * relperc, rg1 + (rg2 - rg1) * relperc, rb1 + (rb2 - rb1) * relperc
end

function F.ColorThreshold(perc, c1, c2, c3, lowBound, highBound, useThresholdColor)
    if useThresholdColor then
        return F.ColorGradient(perc, c1, c2, c3, lowBound, highBound)
    end

    lowBound = lowBound or 0
    highBound = highBound or 1
    perc = perc or 1

    if perc >= highBound then
        return c3[1], c3[2], c3[3]
    elseif perc >= lowBound then
        return c2[1], c2[2], c2[3]
    else
        return c1[1], c1[2], c1[3]
    end
end

--! From ColorPickerAdvanced by Feyawen-Llane
--[[ Convert RGB to HSV ---------------------------------------------------
    Inputs:
        r = Red [0, 1]
        g = Green [0, 1]
        b = Blue [0, 1]
    Outputs:
        H = Hue [0, 360]
        S = Saturation [0, 1]
        B = Brightness [0, 1]
]]--
function F.ConvertRGBToHSB(r, g, b)
    local colorMax = max(max(r, g), b)
    local colorMin = min(min(r, g), b)
    local delta = colorMax - colorMin
    local H, S, B

    -- WoW's LUA doesn't handle floating point numbers very well (Somehow 1.000000 != 1.000000   WTF?)
    -- So we do this weird conversion of, Number to String back to Number, to make the IF..THEN work correctly!
    colorMax = tonumber(format("%f", colorMax))
    r = tonumber(format("%f", r))
    g = tonumber(format("%f", g))
    b = tonumber(format("%f", b))

    if (delta > 0) then
        if (colorMax == r) then
            H = 60 * (((g - b) / delta) % 6)
        elseif (colorMax == g) then
            H = 60 * (((b - r) / delta) + 2)
        elseif (colorMax == b) then
            H = 60 * (((r - g) / delta) + 4)
        end

        if (colorMax > 0) then
            S = delta / colorMax
        else
            S = 0
        end

        B = colorMax
    else
        H = 0
        S = 0
        B = colorMax
    end

    if (H < 0) then
        H = H + 360
    end

    return H, S, B
end

--[[ Convert HSB to RGB ---------------------------------------------------
    Inputs:
        h = Hue [0, 360]
        s = Saturation [0, 1]
        b = Brightness [0, 1]
    Outputs:
        R = Red [0,1]
        G = Green [0,1]
        B = Blue [0,1]
]]--
function F.ConvertHSBToRGB(h, s, b)
    local chroma = b * s
    local prime = (h / 60) % 6
    local X = chroma * (1 - abs((prime % 2) - 1))
    local M = b - chroma
    local R, G, B

    if (0 <= prime) and (prime < 1) then
        R = chroma
        G = X
        B = 0
    elseif (1 <= prime) and (prime < 2) then
        R = X
        G = chroma
        B = 0
    elseif (2 <= prime) and (prime < 3) then
        R = 0
        G = chroma
        B = X
    elseif (3 <= prime) and (prime < 4) then
        R = 0
        G = X
        B = chroma
    elseif (4 <= prime) and (prime < 5) then
        R = X
        G = 0
        B = chroma
    elseif (5 <= prime) and (prime < 6) then
        R = chroma
        G = 0
        B = X
    else
        R = 0
        G = 0
        B = 0
    end

    R = R + M
    G = G + M
    B =  B + M

    return R, G, B
end

function F.InvertColor(r, g, b)
    return 1 - r, 1 - g, 1 - b
end

-------------------------------------------------
-- number
-------------------------------------------------
function F.Round(num, numDecimalPlaces)
    if numDecimalPlaces and numDecimalPlaces >= 0 then
        local mult = 10 ^ numDecimalPlaces
        num = num * mult
        if num >= 0 then
            return floor(num + 0.5) / mult
        else
            return ceil(num - 0.5) / mult
        end
    end

    if num >= 0 then
        return floor(num + 0.5)
    else
        return ceil(num - 0.5)
    end
end

local symbol_1K, symbol_10K, symbol_1B
if LOCALE_zhCN then
    symbol_1K, symbol_10K, symbol_1B = "千", "万", "亿"
elseif LOCALE_zhTW then
    symbol_1K, symbol_10K, symbol_1B = "千", "萬", "億"
elseif LOCALE_koKR then
    symbol_1K, symbol_10K, symbol_1B = "천", "만", "억"
end

local abs = math.abs

if Cell.isAsian then
    function F.FormatNumber(n)
        if abs(n) >= 100000000 then
            return F.Round(n / 100000000, 2) .. symbol_1B
        elseif abs(n) >= 10000 then
            return F.Round(n / 10000, 1) .. symbol_10K
        else
            return n
        end
    end
else
    function F.FormatNumber(n)
        if abs(n) >= 1000000000 then
            return F.Round(n / 1000000000, 2) .. "B"
        elseif abs(n) >= 1000000 then
            return F.Round(n / 1000000, 2) .. "M"
        elseif abs(n) >= 1000 then
            return F.Round(n / 1000, 1) .. "K"
        else
            return n
        end
    end
end

-------------------------------------------------
-- string
-------------------------------------------------
function F.UpperFirst(str, lowerOthers)
    -- WotLK Fix: Handle nil string
    if not str then return "" end

    if lowerOthers then
        str = strlower(str)
    end
    return (str:gsub("^%l", string.upper))
end

function F.SplitToNumber(sep, str)
    if not str then return end

    local ret = {strsplit(sep, str)}
    for i, v in ipairs(ret) do
        ret[i] = tonumber(v) or ret[i] -- keep non number
    end
    return unpack(ret)
end

local function Chsize(char)
    if not char then
        return 0
    elseif char > 240 then
        return 4
    elseif char > 225 then
        return 3
    elseif char > 192 then
        return 2
    else
        return 1
    end
end

function F.Utf8sub(str, startChar, numChars)
    if not str then return "" end
    local startIndex = 1
    while startChar > 1 do
        local char = string.byte(str, startIndex)
        startIndex = startIndex + Chsize(char)
        startChar = startChar - 1
    end

    local currentIndex = startIndex

    while numChars > 0 and currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        currentIndex = currentIndex + Chsize(char)
        numChars = numChars -1
    end
    return str:sub(startIndex, currentIndex - 1)
end

function F.FitWidth(fs, text, alignment)
    fs:SetText(text)

    if fs:IsTruncated() then
        --! WotLK fix: strlenutf8 is native on 3.3.5 (codex: API function), while
        --! string.utf8len is the byte-by-byte Lua loop from Libs/utf8.lua - see the
        --! same substitution in F.SetFont at :1060. string.utf8sub below stays: this
        --! client has no native substring-by-code-point, so Libs/utf8.lua is loaded
        --! either way and only the length call is worth reclaiming.
        --! The end index is passed explicitly for the same reason: utf8sub defaults
        --! j to -1 (Libs/utf8.lua:187) and a negative index makes it re-walk the whole
        --! string with utf8len on every call (:205), so the loop was quadratic. With
        --! both indices >= 0 that inner walk is skipped; j = len means end-of-string,
        --! exactly what -1 meant.
        local len = strlenutf8(text)
        for i = 1, len do
            if strlower(alignment) == "right" then
                fs:SetText("..."..string.utf8sub(text, i, len))
            else
                fs:SetText(string.utf8sub(text, i, len).."...")
            end

            if not fs:IsTruncated() then
                break
            end
        end
    end
end

-------------------------------------------------
-- table
-------------------------------------------------
function F.Getn(t)
    local count = 0
    for _ in next, t do
        count = count + 1
    end
    return count
end

function F.GetIndex(t, e)
    for i, v in pairs(t) do
        if e == v then
            return i
        end
    end
    return nil
end

function F.GetKeys(t)
    local keys = {}
    for k in pairs(t) do
        tinsert(keys, k)
    end
    return keys
end

function F.Copy(t)
    local newTbl = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            newTbl[k] = F.Copy(v)
        else
            newTbl[k] = v
        end
    end
    return newTbl
end

function F.TContains(t, v)
    for _, value in pairs(t) do
        if value == v then return true end
    end
    return false
end

function F.TInsert(t, v)
    local i, done = 1
    repeat
        if not t[i] then
            t[i] = v
            done = true
        end
        i = i + 1
    until done
end

function F.TInsertIfNotExists(t, ...)
    local n = select("#", ...)
    if n == 0 then return end

    if n == 1 then
        local v = ...
        if not F.TContains(t, v) then
            tinsert(t, v)
        end
    else
        local values = F.ConvertTable(t, true)
        for i = 1, n do
            local v = select(i, ...)
            if not values[v] then
                tinsert(t, v)
            end
        end
        values = nil
    end

end

function F.TRemove(t, v)
    for i = #t, 1, -1 do
        if t[i] == v then
            table.remove(t, i)
        end
    end
end

function F.TMergeOverwrite(...)
    local n = select("#", ...)
    if n == 0 then return {} end

    local temp = F.Copy(...)
    for i = 2, n do
        local t = select(i, ...)
        for k, v in pairs(t) do
            temp[k] = v
        end
    end
    return temp
end

function F.RemoveElementsExceptKeys(tbl, ...)
    local keys = {}

    for i = 1, select("#", ...) do
        local k = select(i, ...)
        keys[k] = true
    end

    for k in pairs(tbl) do
        if not keys[k] then
            tbl[k] = nil
        end
    end
end

function F.RemoveElementsByKeys(tbl, ...)
    for i = 1, select("#", ...) do
        local k = select(i, ...)
        tbl[k] = nil
    end
end

function F.Sort(t, k1, order1, k2, order2, k3, order3)
    table.sort(t, function(a, b)
        if a[k1] ~= b[k1] then
            if order1 == "ascending" then
                return a[k1] < b[k1]
            else -- "descending"
                return a[k1] > b[k1]
            end
        elseif k2 and order2 and a[k2] ~= b[k2] then
            if order2 == "ascending" then
                return a[k2] < b[k2]
            else -- "descending"
                return a[k2] > b[k2]
            end
        elseif k3 and order3 and a[k3] ~= b[k3] then
            if order3 == "ascending" then
                return a[k3] < b[k3]
            else -- "descending"
                return a[k3] > b[k3]
            end
        end
    end)
end

function F.StringToTable(s, sep, convertToNum)
    local t = {}
    for i, v in pairs({string.split(sep, s)}) do
        v = strtrim(v)
        if v ~= "" then
            if convertToNum then
                v = tonumber(v)
                if v then tinsert(t, v) end
            else
                tinsert(t, v)
            end
        end
    end
    return t
end

function F.TableToString(t, sep)
    return table.concat(t, sep)
end

function F.GetSpellNames(t)
    local names = {}
    for _, id in pairs(t) do
        local name = GetSpellInfo(id)
        if name then
            names[name] = true
        end
    end
    return names
end

function F.ConvertTable(t, value)
    local temp = {}
    for k, v in ipairs(t) do
        temp[v] = value or k
    end
    return temp
end

function F.ConvertSpellTable(t, convertIdToName)
    if not convertIdToName then
        return F.ConvertTable(t)
    end

    local temp = {}
    for k, v in ipairs(t) do
        local name = F.GetSpellInfo(v)
        if name then
            temp[name] = k
        end
    end
    return temp
end

function F.ConvertSpellTable_WithColor(t, convertIdToName)
    local temp = {}
    for k, st in ipairs(t) do
        local index

        if convertIdToName then
            index = F.GetSpellInfo(st[1])
        else
            index = st[1]
        end

        if index then
            temp[index] = {k, st[2]}
        end
    end
    return temp
end

function F.ConvertSpellTable_WithClass(t)
    local temp = {}
    for class, ct in pairs(t) do
        for _, id in ipairs(ct) do
            local name = F.GetSpellInfo(id)
            if name then
                temp[id] = true
            end
        end
    end
    return temp
end

function F.ConvertSpellDurationTable(t, convertIdToName)
    local temp = {}
    for _, v in ipairs(t) do
        local id, duration = strsplit(":", v)
        local name = F.GetSpellInfo(id)
        if name then
            if convertIdToName then
                temp[name] = tonumber(duration)
            else
                temp[tonumber(id)] = tonumber(duration)
            end
        end
    end
    return temp
end

function F.ConvertSpellDurationTable_WithClass(t)
    local temp = {}
    for class, ct in pairs(t) do
        for k, v in ipairs(ct) do
            local id, duration = strsplit(":", v)
            local name, icon = F.GetSpellInfo(id)
            if name then
                temp[tonumber(id)] = {tonumber(duration), icon}
            end
        end
    end
    return temp
end

function F.CheckTableRemoved(previous, after)
    local aa = {}
    local ret = {}

    for k,v in pairs(previous) do aa[v] = true end
    for k,v in pairs(after) do aa[v] = nil end

    for k,v in pairs(previous) do
        if aa[v] then
            tinsert(ret, v)
        end
    end
    return ret
end

function F.FilterInvalidSpells(t)
    if not t then return end
    for i = #t, 1, -1 do
        local spellId
        if type(t[i]) == "number" then
            spellId = t[i]
        else -- table
            spellId = t[i][1]
        end
        if not F.GetSpellInfo(spellId) then
            tremove(t, i)
        end
    end
end

-------------------------------------------------
-- general
-------------------------------------------------
-- function F.GetRealmName()
--     return string.gsub(GetRealmName(), " ", "")
-- end

function F.UnitFullName(unit)
    if not unit or not UnitIsPlayer(unit) then return end

    local name = GetUnitName(unit, true)

    --? name might be nil in some cases?
    if name and not string.find(name, "-") then
        local server = GetNormalizedRealmName()
        --? server might be nil in some cases?
        if server then
            name = name.."-"..server
        end
    end

    return name
end

function F.ToShortName(fullName)
    if not fullName then return "" end
    local shortName = strsplit("-", fullName)
    return shortName
end

function F.FormatTime(s)
    if s >= 3600 then
        return "%dh", ceil(s / 3600)
    elseif s >= 60 then
        return "%dm", ceil(s / 60)
    end
    return "%ds", floor(s)
end

-- function F.SecondsToTime(seconds)
--     local m = seconds / 60
--     local s = seconds % 60
--     return format("%d:%02d", m, s)
-- end

local SEC = _G.SPELL_DURATION_SEC
local MIN = _G.SPELL_DURATION_MIN

local PATTERN_SEC
local PATTERN_MIN
if strfind(SEC, "1f") then
    PATTERN_SEC = "%.0"
elseif strfind(SEC, "2f") then
    PATTERN_SEC = "%.00"
end
if strfind(MIN, "1f") then
    PATTERN_MIN = "%.0"
elseif strfind(MIN, "2f") then
    PATTERN_MIN = "%.00"
end

function F.SecondsToTime(seconds)
    if seconds > 60 then
        return gsub(format(MIN, seconds / 60), PATTERN_MIN, "")
    else
        return gsub(format(SEC, seconds), PATTERN_SEC, "")
    end
end

-------------------------------------------------
-- unit buttons
-------------------------------------------------
local combinedHeader = "CellRaidFrameHeader0"
local separatedHeaders = {"CellRaidFrameHeader1", "CellRaidFrameHeader2", "CellRaidFrameHeader3", "CellRaidFrameHeader4", "CellRaidFrameHeader5", "CellRaidFrameHeader6", "CellRaidFrameHeader7", "CellRaidFrameHeader8"}

--! WotLK fix: remove the dormant retail click-casting frame queue. No live
--! RegisterFrame/UnregisterFrame producer exists in this backport; active secure
--! buttons are enumerated directly by F.IterateAllUnitButtons instead.

function F.IterateAllUnitButtons(func, updateCurrentGroupOnly, updateQuickAssists, skipShared)
    -- solo
    if not updateCurrentGroupOnly or (updateCurrentGroupOnly and Cell.vars.groupType == "solo") then
        for _, b in pairs(Cell.unitButtons.solo) do
            func(b)
        end
    end

    -- party
    if not updateCurrentGroupOnly or (updateCurrentGroupOnly and Cell.vars.groupType == "party") then
        for index, b in pairs(Cell.unitButtons.party) do
            if index ~= "units" then
                func(b)
            end
        end
    end

    -- raid
    if not updateCurrentGroupOnly or (updateCurrentGroupOnly and Cell.vars.groupType == "raid") then
        if not updateCurrentGroupOnly or Cell.vars.currentLayoutTable.main.combineGroups then
            for _, b in ipairs(Cell.unitButtons.raid[combinedHeader]) do
                func(b)
            end
        end

        if not updateCurrentGroupOnly or not Cell.vars.currentLayoutTable.main.combineGroups then
            for _, header in ipairs(separatedHeaders) do
                for _, b in ipairs(Cell.unitButtons.raid[header]) do
                    func(b)
                end
            end
        end

        -- arena pet
        for _, b in pairs(Cell.unitButtons.arena) do
            func(b)
        end
    end

    -- group pet
    if not updateCurrentGroupOnly or (updateCurrentGroupOnly and Cell.vars.groupType == "raid") or (updateCurrentGroupOnly and Cell.vars.groupType == "party") then
        for index, b in pairs(Cell.unitButtons.pet) do
            if index ~= "units" then
                func(b)
            end
        end
    end

    if not skipShared then
        -- npc
        for _, b in ipairs(Cell.unitButtons.npc) do
            func(b)
        end

        -- spotlight
        for _, b in pairs(Cell.unitButtons.spotlight) do
            func(b)
        end
    end

end

function F.IterateSharedUnitButtons(func)
    -- npc
    for _, b in ipairs(Cell.unitButtons.npc) do
        func(b)
    end

    -- spotlight
    for _, b in pairs(Cell.unitButtons.spotlight) do
        func(b)
    end
end

function F.GetUnitButtonByUnit(unit, getSpotlights, getQuickAssist)
    if not unit then return end

    local normal, spotlights, quickAssist

    if Cell.vars.groupType == "raid" then
        if Cell.vars.inBattleground == 5 then
            normal = Cell.unitButtons.raid.units[unit] or Cell.unitButtons.npc.units[unit] or Cell.unitButtons.arena[unit]
        else
            normal = Cell.unitButtons.raid.units[unit] or Cell.unitButtons.npc.units[unit] or Cell.unitButtons.pet.units[unit]
        end
    elseif Cell.vars.groupType == "party" then
        normal = Cell.unitButtons.party.units[unit] or Cell.unitButtons.npc.units[unit]
    else -- solo
        normal = Cell.unitButtons.solo[unit] or Cell.unitButtons.npc.units[unit]
    end

    if getSpotlights then
        spotlights = {}
        for _, b in pairs(Cell.unitButtons.spotlight) do
            if b.unit and UnitIsUnit(b.unit, unit) then
                tinsert(spotlights, b)
            end
        end
    end

    if getQuickAssist then
        quickAssist = Cell.unitButtons.quickAssist.units[unit]
    end

    return normal, spotlights, quickAssist
end

function F.GetUnitButtonByGUID(guid, getSpotlights, getQuickAssist)
    return F.GetUnitButtonByUnit(Cell.vars.guids[guid], getSpotlights, getQuickAssist)
end

function F.GetUnitButtonByName(name, getSpotlights, getQuickAssist)
    return F.GetUnitButtonByUnit(Cell.vars.names[name], getSpotlights, getQuickAssist)
end

function F.HandleUnitButton(type, unit, func, ...)
    if not unit then return end

    --! WotLK perf: Cell.vars и Cell.unitButtons - глобал плюс хеш-лукап на каждое
    --! обращение, а их тут было по три-четыре штуки. Функция вызывается из CLEU-
    --! обработчиков (AoEHealing, TargetedSpells, StatusIcon, Request_Show, диффы
    --! здоровья и щитов в UnitButton_Cata_Wrath), то есть сотни раз в секунду в рейде.
    local vars = Cell.vars
    if type == "guid" then
        unit = vars.guids[unit]
    elseif type == "name" then
        unit = vars.names[unit]
    end

    if not unit then return end

    local buttons = Cell.unitButtons
    local handled, normal

    local groupType = vars.groupType
    if groupType == "raid" then
        if vars.inBattleground == 5 then
            normal = buttons.raid.units[unit] or buttons.npc.units[unit] or buttons.arena[unit]
        else
            normal = buttons.raid.units[unit] or buttons.npc.units[unit] or buttons.pet.units[unit]
        end
    elseif groupType == "party" then
        normal = buttons.party.units[unit] or buttons.npc.units[unit]
    else -- solo
        normal = buttons.solo[unit] or buttons.npc.units[unit]
    end

    if normal then
        func(normal, ...)
        handled = true
    end

    --! WotLK perf: числовой for вместо pairs. Cell.unitButtons.spotlight - плотный
    --! массив 1..15: SpotlightFrame.lua создаёт все пятнадцать кнопок при загрузке
    --! безусловно и никогда не вынимает элементы (проверено grep'ом), поэтому обход
    --! эквивалентен. Разница в цене: pairs - это C-вызов плюс по C-вызову next на
    --! каждый элемент, то есть семнадцать переходов Lua->C на КАЖДЫЙ вызов
    --! HandleUnitButton, даже когда spotlight вообще не используется и states.unit
    --! пуст у всех пятнадцати. Числовой for не делает ни одного.
    local spotlight = buttons.spotlight
    for i = 1, #spotlight do
        local b = spotlight[i]
        --! WotLK perf: states.unit читается один раз, а не два на попадании.
        local spotlightUnit = b.states.unit
        if spotlightUnit and UnitIsUnit(spotlightUnit, unit) then
            func(b, ...)
            handled = true
        end
    end

    return handled
end

function F.UpdateTextWidth(fs, text, width, relativeTo)
    if not text or not width then return end

    if width == "unlimited" then
        fs:SetText(text)
    elseif width[1] == "percentage" then
        local percent = width[2] or 0.75
        local width = relativeTo:GetWidth() - 2
        --! WotLK fix: strlenutf8 is native on 3.3.5; string.utf8len is a byte-by-byte
        --! Lua loop from Libs/utf8.lua and this runs per name on every roster update.
        for i = strlenutf8(text), 0, -1 do
            fs:SetText(string.utf8sub(text, 1, i))
            if fs:GetWidth() / width <= percent then
                break
            end
        end
    elseif width[1] == "length" then
        if string.len(text) == strlenutf8(text) then -- en
            fs:SetText(string.utf8sub(text, 1, width[2]))
        else -- non-en
            fs:SetText(string.utf8sub(text, 1, width[3]))
        end
    end
end

function F.GetMarkEscapeSequence(index)
    index = index - 1
    local left, right, top, bottom
    local coordIncrement = 64 / 256
    left = mod(index , 4) * coordIncrement
    right = left + coordIncrement
    top = floor(index / 4) * coordIncrement
    bottom = top + coordIncrement
    return string.format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:0:0:0:0:64:64:%d:%d:%d:%d|t", left*64, right*64, top*64, bottom*64)
end

-- local scriptObjects = {}
-- local frame = CreateFrame("Frame")
-- frame:RegisterEvent("PLAYER_REGEN_DISABLED")
-- frame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- frame:SetScript("OnEvent", function(self, event)
--     if event == "PLAYER_REGEN_ENABLED" then
--         for _, obj in pairs(scriptObjects) do
--             obj:Show()
--         end
--     else
--         for _, obj in pairs(scriptObjects) do
--             obj:Hide()
--         end
--     end
-- end)
-- function F.SetHideInCombat(obj)
--     tinsert(scriptObjects, obj)
-- end

-------------------------------------------------
-- global functions
-------------------------------------------------
local UnitGUID = UnitGUID
--! WotLK fix: consume Cell-private group adapters; do not depend on shared compatibility globals.
local GetNumGroupMembers = Cell.GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local IsInRaid = Cell.IsInRaid
local IsInGroup = Cell.IsInGroup
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitPlayerOrPetInParty = UnitPlayerOrPetInParty
local UnitPlayerOrPetInRaid = UnitPlayerOrPetInRaid
local UnitClass = UnitClass
--! WotLK fix: use Cell's private class-token normalizer; keep native UnitClassBase untouched.
local UnitClassBase = Cell.GetUnitClassToken
local UnitName = UnitName
local UnitIsGroupLeader = Cell.UnitIsGroupLeader
local UnitIsGroupAssistant = Cell.UnitIsGroupAssistant
local UnitInPartyIsAI = UnitInPartyIsAI or function() end

-------------------------------------------------
-- frame colors
-------------------------------------------------
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- fallback maps for private/older clients where UnitClass may return localized names or ids
local CLASS_ID_TO_TOKEN = {
    [1] = "WARRIOR",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [6] = "DEATHKNIGHT",
    [7] = "SHAMAN",
    [8] = "MAGE",
    [9] = "WARLOCK",
    [11] = "DRUID",
}

local CLASS_NAME_TO_TOKEN = {}
for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
    CLASS_NAME_TO_TOKEN[name] = token
end
for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
    CLASS_NAME_TO_TOKEN[name] = token
end

local function NormalizeClassToken(class)
    if not class or class == "" then return end
    if RAID_CLASS_COLORS[class] then return class end
    if type(class) == "number" then return CLASS_ID_TO_TOKEN[class] end
    if CLASS_NAME_TO_TOKEN[class] then return CLASS_NAME_TO_TOKEN[class] end
end

function F.GetClassColor(class)
    local token = NormalizeClassToken(class)
    if token and RAID_CLASS_COLORS[token] then
        if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[token] then
            return CUSTOM_CLASS_COLORS[token].r, CUSTOM_CLASS_COLORS[token].g, CUSTOM_CLASS_COLORS[token].b
        else
            --! WotLK fix: :GetRGB() is a polyfilled ColorMixin method (no such method
            --! on 3.3.5); the table itself already carries r/g/b natively.
            local c = RAID_CLASS_COLORS[token]
            return c.r, c.g, c.b
        end
    else
        return 1, 1, 1
    end
end

local function GetColorCode(color)
    if not color then return "|cffffffff" end
    return string.format("|cFF%02X%02X%02X",
        math.floor(color.r * 255 + 0.5),
        math.floor(color.g * 255 + 0.5),
        math.floor(color.b * 255 + 0.5))
end

function F.GetClassColorStr(class)
    local token = NormalizeClassToken(class)
    if token and RAID_CLASS_COLORS[token] then
        --! WotLK fix: compute Cell's color escape privately. Do not require or
        --! inject retail colorStr fields into Blizzard/foreign shared tables.
        local color = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[token] or RAID_CLASS_COLORS[token]
        return GetColorCode(color)
    else
        return "|cffffffff"
    end
end

function F.GetUnitClassColor(unit, class, guid)
    class = class or select(2, UnitClass(unit))
    guid = guid or UnitGUID(unit)

    if UnitIsPlayer(unit) or UnitInPartyIsAI(unit) then -- player
        return F.GetClassColor(class)
    elseif F.IsPet(guid, unit) then -- pet
        return 0.5, 0.5, 1
    else -- npc / vehicle
        return 0, 1, 0.2
    end
end


--! WotLK fix: these were allocated fresh on every UNIT_POWER / UNIT_DISPLAYPOWER for
--! every unit - and on 3.3.5 almost every unit is a mana user.
local MANA_COLOR = {r=0, g=0.5, b=1} -- default mana color is too dark!
local INSANITY_COLOR = {r=0.6, g=0.2, b=1}

function F.GetPowerColor(unit)
    local r, g, b, t
    -- https://wow.gamepedia.com/API_UnitPowerType
    local powerType, powerToken, altR, altG, altB = UnitPowerType(unit)
    t = powerType

    local info = PowerBarColor[powerToken]
    if powerType == 0 then -- MANA
        info = MANA_COLOR
    elseif powerType == 13 then -- INSANITY
        info = INSANITY_COLOR
    end

    if info then
        --The PowerBarColor takes priority
        r, g, b = info.r, info.g, info.b
    else
        if not altR then
            -- Couldn't find a power token entry. Default to indexing by power type or just mana if  we don't have that either.
            info = PowerBarColor[powerType] or PowerBarColor["MANA"]
            r, g, b = info.r, info.g, info.b
        else
            r, g, b = altR, altG, altB
        end
    end
    return r, g, b, t
end

function F.GetPowerBarColor(unit, class)
    local r, g, b, lossR, lossG, lossB, t
    r, g, b, t = F.GetPowerColor(unit)

    if not Cell.loaded then
        return r, g, b, r*0.2, g*0.2, b*0.2, t
    end

    if CellDB["appearance"]["powerColor"][1] == "power_color_dark" then
        lossR, lossG, lossB = r, g, b
        r, g, b = r*0.2, g*0.2, b*0.2
    elseif CellDB["appearance"]["powerColor"][1] == "class_color" then
        r, g, b = F.GetClassColor(class)
        lossR, lossG, lossB = r*0.2, g*0.2, b*0.2
    elseif CellDB["appearance"]["powerColor"][1] == "custom" then
        r, g, b = unpack(CellDB["appearance"]["powerColor"][2])
        lossR, lossG, lossB = r*0.2, g*0.2, b*0.2
    else
        lossR, lossG, lossB = r*0.2, g*0.2, b*0.2
    end
    return r, g, b, lossR, lossG, lossB, t
end

function F.GetHealthBarColor(percent, isDeadOrGhost, r, g, b)
    if not Cell.loaded then
        return r, g, b, r*0.2, g*0.2, b*0.2
    end

    local barR, barG, barB, lossR, lossG, lossB
    percent = percent or 1

    -- bar
    if percent == 1 and Cell.vars.useFullColor then
        barR = CellDB["appearance"]["fullColor"][2][1]
        barG = CellDB["appearance"]["fullColor"][2][2]
        barB = CellDB["appearance"]["fullColor"][2][3]
    else
        if CellDB["appearance"]["barColor"][1] == "class_color" then
            barR, barG, barB = r, g, b
        elseif CellDB["appearance"]["barColor"][1] == "class_color_dark" then
            barR, barG, barB = r*0.2, g*0.2, b*0.2
        elseif CellDB["appearance"]["barColor"][1] == "threshold1" then
            local c = CellDB["appearance"]["colorThresholds"]
            barR, barG, barB = F.ColorThreshold(percent, c[1], c[2], c[3], c[4], c[5], c[6])
        elseif CellDB["appearance"]["barColor"][1] == "threshold2" then
            local c = CellDB["appearance"]["colorThresholds"]
            if percent >= c[5] then
                barR, barG, barB = r, g, b -- full: class color
            else
                barR, barG, barB = F.ColorThreshold(percent, c[1], c[2], {r, g, b}, c[4], c[5], c[6])
            end
        elseif CellDB["appearance"]["barColor"][1] == "threshold3" then
            local c = CellDB["appearance"]["colorThresholds"]
            if percent >= c[5] then
                barR, barG, barB = r*0.2, g*0.2, b*0.2 -- full: class color
            else
                barR, barG, barB = F.ColorThreshold(percent, c[1], c[2], {r*0.2, g*0.2, b*0.2}, c[4], c[5], c[6])
            end
        else
            barR = CellDB["appearance"]["barColor"][2][1]
            barG = CellDB["appearance"]["barColor"][2][2]
            barB = CellDB["appearance"]["barColor"][2][3]
        end
    end

    -- loss
    if isDeadOrGhost and Cell.vars.useDeathColor then
        lossR = CellDB["appearance"]["deathColor"][2][1]
        lossG = CellDB["appearance"]["deathColor"][2][2]
        lossB = CellDB["appearance"]["deathColor"][2][3]
    else
        if CellDB["appearance"]["lossColor"][1] == "class_color" then
            lossR, lossG, lossB = r, g, b
        elseif CellDB["appearance"]["lossColor"][1] == "class_color_dark" then
            lossR, lossG, lossB = r*0.2, g*0.2, b*0.2
        elseif CellDB["appearance"]["lossColor"][1] == "threshold1" then
            local c = CellDB["appearance"]["colorThresholdsLoss"]
            lossR, lossG, lossB = F.ColorThreshold(percent, c[1], c[2], c[3], c[4], c[5], c[6])
        elseif CellDB["appearance"]["lossColor"][1] == "threshold2" then
            local c = CellDB["appearance"]["colorThresholdsLoss"]
            if isDeadOrGhost or percent <= c[4] then
                lossR, lossG, lossB = r, g, b  -- dead: class color
            else
                lossR, lossG, lossB = F.ColorThreshold(percent, {r, g, b}, c[2], c[3], c[4], c[5], c[6])
            end
        elseif CellDB["appearance"]["lossColor"][1] == "threshold3" then
            local c = CellDB["appearance"]["colorThresholdsLoss"]
            if isDeadOrGhost or percent <= c[4] then
                lossR, lossG, lossB = r*0.2, g*0.2, b*0.2  -- dead: class color
            else
                lossR, lossG, lossB = F.ColorThreshold(percent, {r*0.2, g*0.2, b*0.2}, c[2], c[3], c[4], c[5], c[6])
            end
        else
            lossR = CellDB["appearance"]["lossColor"][2][1]
            lossG = CellDB["appearance"]["lossColor"][2][2]
            lossB = CellDB["appearance"]["lossColor"][2][3]
        end
    end

    return barR, barG, barB, lossR, lossG, lossB
end

-------------------------------------------------
-- units
-------------------------------------------------
function F.GetNumSubgroupMembers(group)
    local n = 0
    for i = 1, GetNumGroupMembers() do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if subgroup == group then
            n = n + 1
        end
    end
    return n
end

function F.GetUnitsInSubGroup(group)
    local units = {}
    for i = 1, GetNumGroupMembers() do
        -- name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(raidIndex)
        local name, _, subgroup = GetRaidRosterInfo(i)
        if subgroup == group then
            tinsert(units, "raid"..i)
        end
    end
    return units
end

function F.GetRaidInfoByName(fullName)
    for i = 1, GetNumGroupMembers() do
        -- rank: Returns 2 if the raid member is the leader of the raid, 1 if the raid member is promoted to assistant, and 0 otherwise.
        local name, rank, subgroup = GetRaidRosterInfo(i)
        if name == fullName then
            return i, subgroup, rank
        end
    end
end

function F.GetRaidInfoBySubgroupIndex(group, index)
    local currentIndex = 0
    for i = 1, GetNumGroupMembers() do
        local name, rank, subgroup = GetRaidRosterInfo(i)
        if subgroup == group then
            currentIndex = currentIndex + 1
            if currentIndex == index then
                return i, name, rank -- found
            end
        elseif subgroup > group and currentIndex ~= 0 then
            return -- nil if not found
        end
    end
end

function F.GetPetUnit(playerUnit)
    if Cell.vars.groupType == "party" then
        if playerUnit == "player" then
            return "pet"
        else
            return "partypet"..select(3, strfind(playerUnit, "^party(%d+)$"))
        end
    elseif Cell.vars.groupType == "raid" then
        return "raidpet"..select(3, strfind(playerUnit, "^raid(%d+)$"))
    else
        return "pet"
    end
end

function F.GetPlayerUnit(petUnit)
    if petUnit == "pet" then
        return "player"
    else
        return petUnit:gsub("pet", "")
    end
end

function F.IterateGroupMembers()
    local groupType = IsInRaid() and "raid" or "party"
    local numGroupMembers = GetNumGroupMembers()
    local i

    if groupType == "party" then
        i = 0
        numGroupMembers = numGroupMembers - 1
    else
        i = 1
    end

    return function()
        local ret
        if i == 0 then
            ret = "player"
        elseif i <= numGroupMembers and i > 0 then
            ret = groupType .. i
        end
        i = i + 1
        return ret
    end
end

function F.IterateGroupPets()
    local groupType = IsInRaid() and "raid" or "party"
    local numGroupMembers = GetNumGroupMembers()
    local i = groupType == "party" and 0 or 1

    return function()
        local ret
        if i == 0 and groupType == "party" then
            ret = "pet"
        elseif i <= numGroupMembers and i > 0 then
            ret = groupType .. "pet" .. i
        end
        i = i + 1
        return ret
    end
end

function F.GetGroupType()
    if IsInRaid() then
        return "raid"
    elseif IsInGroup() then
        return "party"
    else
        return "solo"
    end
end

function F.UnitInGroup(unit, ignorePets)
    if ignorePets then
        return UnitIsUnit(unit, "player") or UnitInParty(unit) or UnitInRaid(unit) or UnitInPartyIsAI(unit)
    else
        return UnitIsUnit(unit, "player") or UnitIsUnit(unit, "pet") or UnitPlayerOrPetInParty(unit) or UnitPlayerOrPetInRaid(unit) or UnitInPartyIsAI(unit)
    end
end

-- UnitTokenFromGUID
function F.GetTargetUnitID(target)
    if UnitIsUnit(target, "player") then
        return "player"
    elseif UnitIsUnit(target, "pet") then
        return "pet"
    end

    if not F.UnitInGroup(target) then return end

    if UnitIsPlayer(target) or UnitInPartyIsAI(target) then
        for unit in F.IterateGroupMembers() do
            if UnitIsUnit(target, unit) then
                return unit
            end
        end
    else
        for unit in F.IterateGroupPets() do
            if UnitIsUnit(target, unit) then
                return unit
            end
        end
    end
end

function F.GetTargetPetID(target)
    if UnitIsUnit(target, "player") then
        return "pet"
    end

    if not F.UnitInGroup(target) then return end

    if UnitIsPlayer(target) or UnitInPartyIsAI(target) then
        for unit in F.IterateGroupMembers() do
            if UnitIsUnit(target, unit) then
                return F.GetPetUnit(unit)
            end
        end
    end
end

-- https://wowpedia.fandom.com/wiki/UnitFlag
local OBJECT_AFFILIATION_MINE = 0x00000001
local OBJECT_AFFILIATION_PARTY = 0x00000002
local OBJECT_AFFILIATION_RAID = 0x00000004

--! WotLK perf: three bit.band calls collapsed into one, and `bit.band` is resolved
--! once at load instead of on every call. Testing each affiliation bit separately
--! and OR-ing the results answers the same question as masking all three at once -
--! "is any of these bits set" - so the mask is precomputed here. This runs on the
--! combat log: the cleu health updater calls it on EVERY
--! COMBAT_LOG_EVENT_UNFILTERED, hundreds a second in a 25-man raid, and each old
--! call was a global read of `bit`, a table index for `band` and a C call, done up
--! to three times. `bit` is provided by the client itself on 3.3.5 (codex: bit
--! library), so caching the reference here is not a foreign-global assumption -
--! it is a read, and Cell keeps it privately in a file local.
local OBJECT_AFFILIATION_FRIENDLY = OBJECT_AFFILIATION_MINE + OBJECT_AFFILIATION_PARTY + OBJECT_AFFILIATION_RAID
--! The alias also serves GetGUIDType below, which had its own identical copy.
local band = bit.band

function F.IsFriend(unitFlags)
    if not unitFlags then return false end
    return band(unitFlags, OBJECT_AFFILIATION_FRIENDLY) ~= 0
end

--! WotLK fix: these helpers matched retail string GUIDs ("Player-1-...",
--! "Pet-...", "Creature-..."), but 3.3.5 GUIDs are hex strings like
--! "0x0000000000012345". Every check silently returned nil, so callers
--! (ShouldShowPowerBar, ShouldShowPowerText, etc.) could never classify a
--! unit - e.g. power bar filters were ignored for every group member.
--! On 3.3.5 the unit type lives in hex digits 3-5 of the GUID:
--! 0x000 = player; otherwise the low nibble is 3 = NPC, 4 = pet,
--! 5 = vehicle. Retail-style prefixes are kept as a fallback for servers
--! with custom GUID formats.
local function GetGUIDType(guid)
    -- returns "player" | "npc" | "pet" | "vehicle" | nil
    if strfind(guid, "^0x") then
        local high = tonumber(strsub(guid, 3, 5), 16)
        if not high then return end
        local masked = band(high, 0x00F)
        if masked == 0 or masked == 1 then
            return "player"
        elseif masked == 3 then
            return "npc"
        elseif masked == 4 then
            return "pet"
        elseif masked == 5 then
            return "vehicle"
        end
        return
    end
    -- retail-style fallback
    if strfind(guid, "^Player") then return "player" end
    if strfind(guid, "^Pet") then return "pet" end
    if strfind(guid, "^Vehicle") then return "vehicle" end
    if strfind(guid, "^Creature") then return "npc" end
end

function F.IsPlayer(guid)
    if guid then
        return GetGUIDType(guid) == "player"
    end
end

function F.IsPet(guid, unit)
    if unit then
        return strfind(unit, "pet%d*$")
    end
    if guid then
        return GetGUIDType(guid) == "pet"
    end
end

function F.IsNPC(guid)
    if guid then
        return GetGUIDType(guid) == "npc"
    end
end

function F.IsVehicle(guid)
    if guid then
        return GetGUIDType(guid) == "vehicle"
    end
end

function F.GetTargetUnitInfo()
    if UnitIsUnit("target", "player") then
        return "player", UnitName("player"), UnitClassBase("player")
    elseif UnitIsUnit("target", "pet") then
        return "pet", UnitName("pet")
    end
    if not F.UnitInGroup("target") then return end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitIsUnit("target", "raid"..i) then
                return "raid"..i, UnitName("raid"..i), UnitClassBase("raid"..i)
            end
            if UnitIsUnit("target", "raidpet"..i) then
                return "raidpet"..i, UnitName("raidpet"..i)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers()-1 do
            if UnitIsUnit("target", "party"..i) then
                return "party"..i, UnitName("party"..i), UnitClassBase("party"..i)
            end
            if UnitIsUnit("target", "partypet"..i) then
                return "partypet"..i, UnitName("partypet"..i)
            end
        end
    end
end

function F.HasPermission(isPartyMarkPermission)
    if isPartyMarkPermission and IsInGroup() and not IsInRaid() then return true end
    return Cell.UnitIsGroupLeader("player") or (IsInRaid() and Cell.UnitIsGroupAssistant("player"))
end

-------------------------------------------------
-- LibSharedMedia
-------------------------------------------------
Cell.vars.texture = "Interface\\AddOns\\Cell\\Media\\statusbar.tga"
Cell.vars.emptyTexture = "Interface\\AddOns\\Cell\\Media\\empty.tga"
Cell.vars.whiteTexture = "Interface\\AddOns\\Cell\\Media\\white.tga"
--! WotLK fix: иконка воскрешения. Ретейл и Cata берут "Interface\RaidFrame\Raid-Icon-Rez"
--! из клиента, но на 3.3.5a этого ассета нет вовсе (он появился в 4.x compact-raidframe).
--! SetTexture на несуществующий путь молча гасит текстуру: :Show() проходит, ошибки в
--! BugGrabber нет, на экране пусто - ровно поэтому иконка Revive у друида не появлялась.
--! Возим собственную копию файла в Cell/Media (тот же приём, что у ElvUI-WotLK:
--! ElvUI\media\textures\Raid-Icon-Rez.blp). Путь - один владелец, отсюда его читают оба
--! потребителя (Indicators\StatusIcon.lua и Modules\Indicators\Indicators.lua). Зависеть
--! от копии в стороннем !!!ClassicAPI нельзя (правило 3: Cell не владеет чужими файлами).
Cell.vars.resurrectionTexture = "Interface\\AddOns\\Cell\\Media\\Raid-Icon-Rez"

--! WotLK fix: Cell embeds a WotLK-safe LSM fallback but remains fetch-only.
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true) or nil

-- REMOVED: Cell-owned LSM registration.
-- Cell operates in FETCH-ONLY mode with LibSharedMedia.
-- This prevents triggering LSM callbacks that affect other addons (Quartz, NotPlater, XPerl).
--
-- Cell can still FETCH textures/fonts from other addons, but won't REGISTER its own.
-- Tradeoff: Other addons can't use Cell's "Cell DEFAULT" texture or "Visitor" font through LSM.
--
-- Why this fixes the problem:
-- - When ANY addon calls LSM:Register(), it fires callbacks to ALL addons using LSM
-- - These callbacks can trigger before some addons (like Quartz) are fully initialized
-- - By not registering, Cell won't trigger any callbacks or interfere with other addons
-- - Cell's resources remain available through direct paths for Cell's internal use

-- No-op function for compatibility (called from Core_Wrath.lua)
function F.RegisterWithLSM()
    -- Intentionally empty - Cell no longer registers with LSM
end

function F.GetBarTexture()
    --! update Cell.vars.texture for further use in UnitButton_OnLoad
    if LSM and LSM:IsValid("statusbar", CellDB["appearance"]["texture"]) then
        Cell.vars.texture = LSM:Fetch("statusbar", CellDB["appearance"]["texture"])
    else
        Cell.vars.texture = "Interface\\AddOns\\Cell\\Media\\statusbar.tga"
    end
    return Cell.vars.texture
end

function F.GetBarTextureByName(name)
    if LSM and LSM:IsValid("statusbar", name) then
        return LSM:Fetch("statusbar", name)
    end
    return "Interface\\AddOns\\Cell\\Media\\statusbar.tga"
end

function F.GetFont(font)
    if font and LSM and LSM:IsValid("font", font) then
        return LSM:Fetch("font", font)
    elseif type(font) == "string" and strfind(strlower(font), ".ttf$") then
        return font
    else
        if CellDB["appearance"]["useGameFont"] then
            return GameFontNormal:GetFont()
        else
            return "Interface\\AddOns\\Cell\\Media\\Fonts\\Accidental_Presidency.ttf"
        end
    end
end

local defaultFontName = "Cell ".._G.DEFAULT
local defaultFont
function F.GetFontItems()
    if CellDB["appearance"]["useGameFont"] then
        defaultFont = GameFontNormal:GetFont()
    else
        defaultFont = "Interface\\AddOns\\Cell\\Media\\Fonts\\Accidental_Presidency.ttf"
    end

    local items = {}
    local fonts, fontNames

    if LSM then
        fonts, fontNames = F.Copy(LSM:HashTable("font")), F.Copy(LSM:List("font"))
        -- insert default font
        tinsert(fontNames, 1, defaultFontName)
        fonts[defaultFontName] = defaultFont

        for _, name in pairs(fontNames) do
            tinsert(items, {
                ["text"] = name,
                ["font"] = fonts[name],
                -- ["onClick"] = function()
                --     CellDB["appearance"]["font"] = name
                --     Cell.Fire("UpdateAppearance", "font")
                -- end,
            })
        end
    else
        -- LSM not available, show only default font
        fontNames = {defaultFontName}
        fonts = {[defaultFontName] = defaultFont}

        tinsert(items, {
            ["text"] = defaultFontName,
            ["font"] = defaultFont,
        })
    end
    return items, fonts, defaultFontName, defaultFont
end

-------------------------------------------------
-- texture
-------------------------------------------------
function F.GetTexCoord(width, height)
    -- ULx,ULy, LLx,LLy, URx,URy, LRx,LRy
    local texCoord = {0.12, 0.12, 0.12, 0.88, 0.88, 0.12, 0.88, 0.88}
    local aspectRatio = width / height

    local xRatio = aspectRatio < 1 and aspectRatio or 1
    local yRatio = aspectRatio > 1 and 1 / aspectRatio or 1

    for i, coord in ipairs(texCoord) do
        local aspectRatio = (i % 2 == 1) and xRatio or yRatio
        texCoord[i] = (coord - 0.5) * aspectRatio + 0.5
    end

    return texCoord
end

-- function F.RotateTexture(tex, degrees)
--     local angle = math.rad(degrees)
--     local cos, sin = math.cos(angle), math.sin(angle)
--     tex:SetTexCoord((sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
-- end

-- https://wowpedia.fandom.com/wiki/Applying_affine_transformations_using_SetTexCoord
local s2 = sqrt(2)
local function CalculateCorner(degrees)
    local r = math.rad(degrees)
    return 0.5 + math.cos(r) / s2, 0.5 + math.sin(r) / s2
end
function F.RotateTexture(texture, degrees)
    local LRx, LRy = CalculateCorner(degrees + 45)
    local LLx, LLy = CalculateCorner(degrees + 135)
    local ULx, ULy = CalculateCorner(degrees + 225)
    local URx, URy = CalculateCorner(degrees - 45)

    texture:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

--! WotLK fix: no "wow atlases" list here - 3.3.5 has no atlas system; SetAtlas is a
--! shim that silently no-ops for unregistered names, so all 15 retail atlases upstream
--! offered rendered as empty tiles in the texture selector.

-- wow textures
local wowTextures = {

}

-- shapes
local shapes = {
    "circle_blurred",
    "circle_filled",
    "circle_thin",
    "circle",
    "heart_filled",
    "heart",
    "rhombus",
    "rhombus_filled",
    "square_filled",
    "square",
    "star_filled",
    "star",
    "starburst_filled",
    "starburst",
    "triangle_filled",
    "triangle",
}

-- weakauras
local powaTextures = {
    9, 10, 12, 13, 14, 15, 21, 22, 25, 27, 29,
    37, 38, 39, 40, 41, 42, 43, 44,
    49, 51, 52, 53, 58, 78, 118, 84,
    96, 97, 98, 99, 100, 114, 115, 116, 132, 138, 143
}

function F.GetTextures()
    local builtIns = #wowTextures + #shapes

    local t = {}

    -- wow textures
    for _, wt in pairs(wowTextures) do
        tinsert(t, wt)
    end

    -- built-ins
    for _, s in pairs(shapes) do
        tinsert(t, "Interface\\AddOns\\Cell\\Media\\Shapes\\"..s..".tga")
    end

    -- add weakauras textures
    if WeakAuras then
        builtIns = builtIns + #powaTextures
        for _, powa in pairs(powaTextures) do
            tinsert(t, "Interface\\AddOns\\WeakAuras\\PowerAurasMedia\\Auras\\Aura"..powa..".tga")
        end
    end

    -- customs
    for _, path in pairs(CellDB["customTextures"]) do
        tinsert(t, path)
    end

    return builtIns, t
end

function F.GetDefaultRoleIcon(role)
    if not role or role == "NONE" then return "" end
    return "Interface\\AddOns\\Cell\\Media\\Roles\\Default_" .. role
end

function F.GetDefaultRoleIconEscapeSequence(role, size)
    if not role or role == "NONE" then return "" end
    return "|TInterface\\AddOns\\Cell\\Media\\Roles\\Default_" .. role .. ":" .. (size or 0) .. "|t"
end

--! WotLK fix: class + dominant talent tab -> role, for the Role mode of Layout Auto
--! Switch. This deliberately does NOT go through Cell.UnitGroupRolesAssigned: that one
--! prefers the role out of GetRaidRosterInfo, which the raid leader can change at any
--! moment, so a storage key built on it would silently repoint the player's saved
--! profile mid-raid. The talent tree is intrinsic - it only changes when the player
--! respecs or switches talent group, which is exactly when the profile should change.
--! Tab order is fixed per class on 3.3.5a, so the index is a stable key.
--! Known limit: bear and cat share the Feral tab and are indistinguishable from
--! talents alone, so a feral druid resolves to DAMAGER. Spec mode keys on the tab
--! itself and is unaffected. Same table as LibGroupInfo.lua:251, kept private here so
--! Cell does not depend on a library's internals for its own config key.
local WRATH_TREE_ROLES = {
    WARRIOR     = {"DAMAGER", "DAMAGER", "TANK"},
    PALADIN     = {"HEALER", "TANK", "DAMAGER"},
    HUNTER      = {"DAMAGER", "DAMAGER", "DAMAGER"},
    ROGUE       = {"DAMAGER", "DAMAGER", "DAMAGER"},
    PRIEST      = {"HEALER", "HEALER", "DAMAGER"},
    DEATHKNIGHT = {"TANK", "DAMAGER", "DAMAGER"},
    SHAMAN      = {"DAMAGER", "DAMAGER", "HEALER"},
    MAGE        = {"DAMAGER", "DAMAGER", "DAMAGER"},
    WARLOCK     = {"DAMAGER", "DAMAGER", "DAMAGER"},
    DRUID       = {"DAMAGER", "DAMAGER", "HEALER"},
}

--! Returns TANK / HEALER / DAMAGER, or nil while the trees are still unreadable.
--! nil means "not known yet", never "no role": callers must skip rather than guess,
--! or a fresh character with no points spent would be written under the wrong key.
function F.GetPlayerTalentRole()
    local class = Cell.vars.playerClass
    local roles = class and WRATH_TREE_ROLES[class]
    if not roles then return nil end

    local tab = F.GetDominantTalentTab()
    if not tab then return nil end

    return roles[tab]
end

-------------------------------------------------
-- frame
-------------------------------------------------
--! WotLK fix: здесь была обёртка F.GetMouseFocus, которая сначала пробовала
--! ретейловый GetMouseFoci() и индексировала его результат как [1], а лишь потом
--! падала на нативный GetMouseFocus(). На 3.3.5 ретейлового имени нет ни в C-API
--! (кодекс), ни в 383 файлах FrameXML, поэтому ответить на пробу мог только ЧУЖОЙ
--! аддон, опубликовавший ретейл-имя, - и Cell поверил бы его ФОРМЕ возврата, взяв
--! [1] у чего угодно (правило 3: прочитанный глобал никогда не считается своей
--! реализацией; вернись форма не таблицей - "attempt to index"). Нативный
--! GetMouseFocus() отдаёт фрейм под курсором или nil (кодекс: 3.3.5a, не protected) -
--! именно это и нужно всем семи местам, и Core_Wrath.lua уже звал его напрямую.
--! Обёртка убрана, все вызовы идут в нативную функцию.

--! WotLK fix: у Marks Bar и ReadyCheck/PullTimer в режиме мувера единственная зона
--! хвата - узкая полоса под moverText: сами фреймы 40 и 55 юнитов высотой, а кнопки
--! занимают всё, кроме верхних 20/18. При пиксель-перфект масштабе ~0.7 это ~14
--! экранных пикселей прозрачного воздуха, попасть в который вслепую почти нельзя,
--! а вокруг - живые кнопки, которые ставят метки и запускают ready check.
--! На 3.3.5 нет SetPropagateMouseClicks, поэтому мышь у верхнего фрейма событие
--! съедает и до parent-а drag не доходит - оверлей обязан тащить сам.
--! Оверлей: mouse-enabled фрейм на всю площадь, поверх кнопок (frame level +10),
--! видим только в режиме мувера. Кнопки при этом не трогаем - ни EnableMouse, ни
--! Hide: они secure (SecureActionButtonTemplate), а ShowMover может прийти в бою.
---@param frame table фрейм инструмента, который двигаем
---@param getPositionTable function геттер таблицы позиции - именно функция, а не сама
---! таблица: /cell reset position подменяет CellDB[...][4] новой таблицей, ссылка,
---! захваченная при загрузке, после сброса писала бы в осиротевшую копию.
function F.CreateMoverOverlay(frame, getPositionTable)
    local P = Cell.pixelPerfectFuncs

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:EnableMouse(true)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    overlay:RegisterForDrag("LeftButton")
    overlay:SetScript("OnDragStart", function()
        frame:StartMoving()
        frame:SetUserPlaced(false)
    end)
    overlay:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        P.SavePosition(frame, getPositionTable())
    end)
    overlay:Hide()

    return overlay
end

-------------------------------------------------
-- instance
-------------------------------------------------
function F.GetInstanceName()
    if IsInInstance() then
        local name = GetInstanceInfo()
        if not name then name = GetRealZoneText() end
        return name
    end

    --! WotLK fix: 3.3.5 has no retail C_Map/MapUtil hierarchy. Raid-debuff
    --! lookup outside instances needs only the current localized zone name, so
    --! use the native legacy APIs and avoid mutating the global map selection.
    local name = GetRealZoneText()
    if not name or name == "" then
        name = GetZoneText()
    end
    return name or ""
end

-------------------------------------------------
-- spell
-------------------------------------------------
-- https://wow.gamepedia.com/UIOBJECT_GameTooltip
-- local function EnumerateTooltipLines_helper(...)
--     for i = 1, select("#", ...) do
--        local region = select(i, ...)
--        if region and region:GetObjectType() == "FontString" then
--           local text = region:GetText() -- string or nil
--           print(region:GetName(), text)
--        end
--     end
-- end

--! WotLK fix: the unused retail tooltip-data helper was removed. Publishing a
--! fake C_TooltipInfo.GetSpellByID that always returned no lines hid unsupported
--! behavior without providing a usable contract.

    local GetSpellInfo = GetSpellInfo
    function F.GetSpellInfo(spellId)
        if not spellId then return end
        local rank
        spellId, rank = strsplit(":", spellId)
        local name, _, icon = GetSpellInfo(spellId)
        return name, icon, tonumber(rank)
    end

--! WotLK fix: guard `if Cell.isWrath or Cell.isVanilla` вырезан - на 3.3.5 он
--! всегда истина. Блок объявлял F.GetRankSuffix и F.GetMaxSpellRank плюс свои
--! файловые локалы; тело поднято на верхний уровень как есть.
local GetSpellInfo = GetSpellInfo
local GetNumSpellTabs = GetNumSpellTabs
local GetSpellTabInfo = GetSpellTabInfo
--! WotLK fix: GetSpellName is the native 3.3.5 spellbook API and preserves
--! both localized name and rank/subtext. Do not depend on a global modern alias.
local GetSpellBookItemName = GetSpellName

local MATCH_PATTERN, FORMAT_PATTERN = "Rank (%d+)", "Rank %d"
if LOCALE_deDE or LOCALE_frFR then
    MATCH_PATTERN = "Rang (%d+)"
    FORMAT_PATTERN = "Rang %d"
elseif LOCALE_esES or LOCALE_esMX then
    MATCH_PATTERN = "Rango (%d+)"
    FORMAT_PATTERN = "Rango %d"
elseif LOCALE_ruRU then
    MATCH_PATTERN = "Уровень (%d+)"
    FORMAT_PATTERN = "Уровень %d"
elseif LOCALE_zhCN then
    MATCH_PATTERN = "等级 (%d+)"
    FORMAT_PATTERN = "等级 %d"
elseif LOCALE_zhTW then
    MATCH_PATTERN = "等級 (%d+)"
    FORMAT_PATTERN = "等級 %d"
end

FORMAT_PATTERN = "(" .. FORMAT_PATTERN .. ")"

function F.GetRankSuffix(rank)
    return FORMAT_PATTERN:format(rank)
end

function F.GetMaxSpellRank(spellId)
    local spellName = select(1, GetSpellInfo(spellId))
    if not spellName then return end

    local maxRank = 0
    local bookType = BOOKTYPE_SPELL

    local totalSpells = 0
    for tab = 1, GetNumSpellTabs() do
        local name, texture, offset, numSpells = GetSpellTabInfo(tab)
        totalSpells = totalSpells + numSpells
    end

    -- local spellSubText
    for i = 1, totalSpells do
        local name, subText = GetSpellBookItemName(i, bookType)
        if name == spellName and subText then
            local rank = tonumber(subText:match(MATCH_PATTERN))
            -- spellSubText = subText
            if rank and rank > maxRank then
                maxRank = rank
            end
        end
    end

    -- if spellSubText then
    --     print("----------------------------------------------")
    --     print(spellSubText, MATCH_PATTERN, tonumber(spellSubText:match(MATCH_PATTERN)))
    --     print("Max Rank of " .. spellName .. ": " .. maxRank)
    --     print("----------------------------------------------")
    -- else
    --     print("Rank info not found: " .. spellName)
    -- end

    return maxRank
end

--! WotLK fix: C_Spell.GetSpellCooldown is a ClassicAPI shim that wraps the native
--! tuple into a throw-away table; call the native function directly.
do
    local GetSpellCooldown = GetSpellCooldown
    F.GetSpellCooldown = function(spellId)
        local start, duration = GetSpellCooldown(spellId)
        return start, duration
    end
end

function F.IsSpellReady(spellId)
    local start, duration = F.GetSpellCooldown(spellId)
    if start == 0 or duration == 0 then
        return true
    else
        local _, gcd = F.GetSpellCooldown(61304) --! check gcd
        if duration == gcd then -- spell ready
            return true
        else
            local cdLeft = start + duration - GetTime()
            return false, cdLeft
        end
    end
end

-------------------------------------------------
-- macro
-------------------------------------------------
local mc = CreateFrame("Frame")
mc:RegisterEvent("UPDATE_MACROS")

local macroIndices = {}
mc:SetScript("OnEvent", function()
    wipe(macroIndices)

    local global, perChar = GetNumMacros()
    for i = 1, global do
        tinsert(macroIndices, i)
    end
    for i = 1, perChar do
        --! WotLK fix: 120 is the retail MAX_ACCOUNT_MACROS; on 3.3.5 it is 36, and
        --! Blizzard_MacroUI is load-on-demand, so the constant may not exist yet.
        tinsert(macroIndices, (MAX_ACCOUNT_MACROS or 36) + i)
    end
end)

function F.GetMacroIndices()
    return macroIndices
end

-------------------------------------------------
-- auras
-------------------------------------------------
--! WotLK fix: scan the native 3.3.5 aura tuple directly. The embedded
--! AuraUtil implementation recursively rebuilt every tuple and also advertised
--! a broken ForEachAura contract backed by nonexistent UnitAuraSlots APIs.
function F.FindAuraById(unit, type, spellId)
    local filter = type == "BUFF" and "HELPFUL" or "HARMFUL"
    for i = 1, 40 do
        local name, rank, icon, count, debuffType, duration, expirationTime,
            source, isStealable, shouldConsolidate, id = UnitAura(unit, i, filter)
        if not name then return end
        if id == spellId then
            return name, icon, count, debuffType, duration, expirationTime,
                source, isStealable, shouldConsolidate, id
        end
    end
end

    function F.FindDebuffByIds(unit, spellIds)
        local debuffs = {}
        for i = 1, 40 do
            --! WotLK perf: native UnitDebuff (rank at position 2, spellId at 11)
            local name, _, _, _, debuffType, _, _, _, _, _, spellId = UnitDebuff(unit, i)
            if not name then
                break
            end

            if spellIds[spellId] then
                debuffs[spellId] = I.CheckDebuffType(debuffType, spellId)
            end
        end
        return debuffs
    end

    function F.FindAuraByDebuffTypes(unit, types)
        local debuffs = {}
        for i = 1, 40 do
            --! WotLK perf: native UnitDebuff (rank at position 2, spellId at 11)
            local name, _, _, _, debuffType, _, _, _, _, _, spellId = UnitDebuff(unit, i)
            if not name then
                break
            end

            if types == "all" or types[debuffType] then
                --! WotLK fix: was CheckDebuffType(s, spellId) with undefined
                --! global `s` (always nil) - pass the actual debuffType
                debuffs[spellId] = I.CheckDebuffType(debuffType, spellId)
            end
        end
        return debuffs
    end

-------------------------------------------------
-- OmniCD
-------------------------------------------------
function F.UpdateOmniCDPosition(frame)
    --! WotLK fix: guard был асимметричным - проверял сам глобал `OmniCD` и поле `.db`,
    --! но индексы `[1]`, `.position` и `.Party` брал без проверки. Правило 3: Cell не
    --! владеет глобалом `OmniCD` и не имеет права верить его ФОРМЕ. Любой аддон,
    --! опубликовавший это имя иначе (не таблица с [1], или [1] без .position/.Party),
    --! ронял хук `OnAttributeChanged` каждой spotlight-кнопки в "attempt to index".
    --! Заодно глобал читается один раз в локальную E вместо трёх GETGLOBAL + трёх
    --! индексов, и та же E уходит в замыкание - предсказуемее, чем перечитывать
    --! чужой глобал через 0.5 c. Поведение при живом OmniCD не меняется.
    local E = OmniCD and OmniCD[1]
    if E and E.db and E.db.position and E.db.position.uf == frame then
        C_Timer.After(0.5, function()
            if E.Party then
                E.Party:UpdatePosition()
            end
        end)
    end
end

-------------------------------------------------
-- LibGetFrame
-------------------------------------------------
local frame_priorities = {}
local inited_priorities = {}
local modified_priorities = {}
local spotlightPriorityEnabled
local quickAssistPriorityEnabled

function F.UpdateFramePriority()
    wipe(frame_priorities)
    wipe(modified_priorities)
    spotlightPriorityEnabled = nil
    quickAssistPriorityEnabled = nil

    for i, t  in pairs(CellDB["general"]["framePriority"]) do
        if t[2] then
            if t[1] == "Main" then
                tinsert(frame_priorities, i, "^CellNormalUnitFrame$")
            elseif t[1] == "Spotlight" then
                tinsert(frame_priorities, i, "^CellSpotlightUnitFrame$")
                spotlightPriorityEnabled = true
            else
                tinsert(frame_priorities, i, "^CellQuickAssistUnitFrame$")
                quickAssistPriorityEnabled = true
            end
        else
            tinsert(frame_priorities, i, "^CellPlaceholder$")
        end
    end

    F.Debug(frame_priorities)
end

function Cell.GetUnitFramesForLGF(unit, frames, priorities)
    frames = frames or {}

    local normal, spotlights, quickAssist = F.GetUnitButtonByUnit(unit, spotlightPriorityEnabled, quickAssistPriorityEnabled)

    if normal then
        frames[normal.widgets.highLevelFrame] = "CellNormalUnitFrame"
    end

    if spotlights then
        -- for _, spotlight in pairs(spotlights) do
        --     if not strfind(spotlight.unit, "target$") and spotlight.widgets and spotlight.widgets.highLevelFrame then
        --         frames[spotlight.widgets.highLevelFrame] = "CellSpotlightUnitFrame"
        --         break
        --     end
        -- end
        --! just use the first (can be "XXtarget", whatever)
        if spotlights[1] then
            frames[spotlights[1].widgets.highLevelFrame] = "CellSpotlightUnitFrame"
        end
    end

    if quickAssist then
        frames[quickAssist] = "CellQuickAssistUnitFrame"
    end

    if not inited_priorities[priorities] then
        inited_priorities[priorities] = true
        for i = 1, 3 do
            tinsert(priorities, i, "^CellPlaceholder$")
        end
    end

    if not modified_priorities[priorities] then
        modified_priorities[priorities] = true
        for i, p in ipairs(frame_priorities) do
            priorities[i] = p
        end
    end

    return frames
end

-------------------------------------------------
-- range check
-------------------------------------------------
local UnitIsVisible = UnitIsVisible
local UnitInRange = UnitInRange
local UnitCanAssist = UnitCanAssist
local UnitCanAttack = UnitCanAttack
local UnitCanCooperate = UnitCanCooperate
--! WotLK fix: critical range checks bind directly to native 3.3.5 APIs.
--! Standalone !!!ClassicAPI may expose C_Spell/C_Item wrappers with a retail
--! boolean contract, while embedded ClassicAPI aliases the native 1/0/nil
--! contract. Normalizing the native results locally makes both load modes
--! identical and avoids foreign namespace ownership entirely.
local IsSpellInRange = IsSpellInRange
local IsItemInRange = IsItemInRange
local CheckInteractDistance = CheckInteractDistance
local UnitIsDead = UnitIsDead
--! WotLK perf: последний голый глобал в горячем пути F.IsInRange - он звался
--! на каждый дружественный юнит каждого тика 0.25s (40 юнитов x 4/s), а GETGLOBAL
--! это хеш-лукап по таблице глобалов против прямого чтения upvalue.
local UnitIsConnected = UnitIsConnected
-- upstream r273 switched to IsSpellKnown; on 3.3.5 IsSpellKnownOrOverridesKnown
-- doesn't exist at all (MoP+ API), so without this fallback the local is nil
-- and SPELLS_CHANGED errors on every spellbook update
local IsSpellKnownOrOverridesKnown = IsSpellKnownOrOverridesKnown or IsSpellKnown
-- local GetSpellTabInfo = GetSpellTabInfo
-- local GetNumSpellTabs = GetNumSpellTabs
-- local GetSpellBookItemName = GetSpellBookItemName
-- local BOOKTYPE_SPELL = BOOKTYPE_SPELL

--! WotLK fix: UnitInPhase на 3.3.5 не существует (кодекс: НЕТ), а вызов
--! UnitInSamePhase("target") в GetResult1 ниже безусловный. На голом клиенте
--! локал захватывал nil, и отладочный вид `/cellrc` падал в "attempt to call
--! a nil value" каждый кадр, пока был открыт. Работало это только потому, что
--! имя давал внешний !!!ClassicAPI - ровно класс GAP-015. Cell.UnitInPhase
--! (Polyfills.lua) - приватная nil-безопасная версия: зовёт натив, если ядро
--! сервера его всё-таки добавило, иначе true (фазинга на 3.3.5 нет).
local UnitInSamePhase = Cell.UnitInPhase

local playerClass = UnitClassBase("player")

local friendSpells = {
    -- ["DEATHKNIGHT"] = 47541,
    -- ["DEMONHUNTER"] = ,
    --! WotLK fix: тернарники по Cell.isWrath/isRetail свёрнуты в константы 3.3.5 -
    --! флаги заданы литералами выше (строки 24-28), ветка выбиралась статически.
    ["DRUID"] = 5185, -- 治疗之触 (Healing Touch)
    -- FIXME: [361469 活化烈焰] 会被英雄天赋 [431443 时序烈焰] 替代，但它而且有问题
    -- IsSpellInRange 始终返回 nil
    ["EVOKER"] = 355913, -- 翡翠之花
    -- ["HUNTER"] = 136,
    ["MAGE"] = 1459, -- 奥术智慧 / 奥术光辉
    ["MONK"] = 116670, -- 活血术
    ["PALADIN"] = 635, -- 圣光术 (Holy Light)
    ["PRIEST"] = 2050, -- 次级治疗术 (Lesser Heal)
    -- ["ROGUE"] = Cell.isWrath and 57934,
    ["SHAMAN"] = 331, -- 治疗波 (Healing Wave)
    ["WARLOCK"] = 5697, -- 无尽呼吸
    -- ["WARRIOR"] = 3411,
}

local deadSpells = {
    ["EVOKER"] = 361227, -- resurrection range, need separately for evoker
}

local petSpells = {
    ["HUNTER"] = 136,
}

local harmSpells = {
    ["DEATHKNIGHT"] = 47541, -- 凋零缠绕
    ["DEMONHUNTER"] = 185123, -- 投掷利刃
    ["DRUID"] = 5176, -- 愤怒
    -- FIXME: [361469 活化烈焰] 会被英雄天赋 [431443 时序烈焰] 替代，但它而且有问题
    -- IsSpellInRange 始终返回 nil
    ["EVOKER"] = 362969, -- 碧蓝打击
    ["HUNTER"] = 75, -- 自动射击
    ["MAGE"] = 133, -- 火球术 (Fireball)
    ["MONK"] = 117952, -- 碎玉闪电
    ["PALADIN"] = 20271, -- 审判
    ["PRIEST"] = 585, -- 惩击 (Smite)
    ["ROGUE"] = 1752, -- 影袭
    ["SHAMAN"] = 403, -- 闪电箭 (Lightning Bolt)
    --! WotLK fix: 234153 is the retail Drain Life ID; on 3.3.5 it is 689 (rank 1),
    --! so IsSpellKnown() never matched and warlocks fell back to the item check.
    ["WARLOCK"] = 689, -- 吸取生命 (Drain Life, rank 1)
    ["WARRIOR"] = 355, -- 嘲讽
}

-- local friendItems = {
--     ["DEATHKNIGHT"] = 34471,
--     ["DEMONHUNTER"] = 34471,
--     ["DRUID"] = 34471,
--     ["EVOKER"] = 1180, -- 30y
--     ["HUNTER"] = 34471,
--     ["MAGE"] = 34471,
--     ["MONK"] = 34471,
--     ["PALADIN"] = 34471,
--     ["PRIEST"] = 34471,
--     ["ROGUE"] = 34471,
--     ["SHAMAN"] = 34471,
--     ["WARLOCK"] = 34471,
--     ["WARRIOR"] = 34471,
-- }

local harmItems = {
    ["DEATHKNIGHT"] = 28767, -- 40y
    ["DEMONHUNTER"] = 28767, -- 40y
    ["DRUID"] = 28767, -- 40y
    ["EVOKER"] = 24268, -- 25y
    ["HUNTER"] = 28767, -- 40y
    ["MAGE"] = 28767, -- 40y
    ["MONK"] = 28767, -- 40y
    ["PALADIN"] = 835, -- 30y
    ["PRIEST"] = 28767, -- 40y
    ["ROGUE"] = 28767, -- 40y
    ["SHAMAN"] = 28767, -- 40y
    ["WARLOCK"] = 28767, -- 40y
    ["WARRIOR"] = 28767, -- 40y
}

-- local FindSpellIndex
-- if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
--     FindSpellIndex = function(spellName)
--         if not spellName or spellName == "" then return end
--         return C_SpellBook.FindSpellBookSlotForSpell(spellName)
--     end
-- else
--     local function GetNumSpells()
--         local _, _, offset, numSpells = GetSpellTabInfo(GetNumSpellTabs())
--         return offset + numSpells
--     end

--     FindSpellIndex = function(spellName)
--         if not spellName or spellName == "" then return end
--         for i = 1, GetNumSpells() do
--             local spell = GetSpellBookItemName(i, BOOKTYPE_SPELL)
--             if spell == spellName then
--                 return i
--             end
--         end
--     end
-- end

--! WotLK 3.3.5a only: native IsSpellInRange -- and the ClassicAPI alias
--! C_Spell.IsSpellInRange = IsSpellInRange -- returns 1/0/nil, NOT a boolean.
--! The old C_Spell branch returned the raw value, and 0 (out of range) is
--! truthy in Lua, so range checks treated every unit as in-range. Always == 1.
local UnitInSpellRange = function(spellName, unit)
    return IsSpellInRange(spellName, unit) == 1
end

local rc = CreateFrame("Frame")
rc:RegisterEvent("SPELLS_CHANGED")

local spell_friend, spell_pet, spell_harm, spell_dead
CELL_RANGE_CHECK_FRIENDLY = {}
CELL_RANGE_CHECK_HOSTILE = {}
CELL_RANGE_CHECK_DEAD = {}
CELL_RANGE_CHECK_PET = {}

local function SPELLS_CHANGED()
    spell_friend = CELL_RANGE_CHECK_FRIENDLY[playerClass] or friendSpells[playerClass]
    spell_harm = CELL_RANGE_CHECK_HOSTILE[playerClass] or harmSpells[playerClass]
    spell_dead = CELL_RANGE_CHECK_DEAD[playerClass] or deadSpells[playerClass]
    spell_pet = CELL_RANGE_CHECK_PET[playerClass] or petSpells[playerClass]

    if spell_friend and IsSpellKnownOrOverridesKnown(spell_friend) then
        spell_friend = F.GetSpellInfo(spell_friend)
    else
        spell_friend = nil
    end
    if spell_harm and IsSpellKnownOrOverridesKnown(spell_harm) then
        spell_harm = F.GetSpellInfo(spell_harm)
    else
        spell_harm = nil
    end
    if spell_dead and IsSpellKnownOrOverridesKnown(spell_dead) then
        spell_dead = F.GetSpellInfo(spell_dead)
    else
        spell_dead = nil
    end
    if spell_pet and IsSpellKnownOrOverridesKnown(spell_pet) then
        spell_pet = F.GetSpellInfo(spell_pet)
    else
        spell_pet = nil
    end

    -- F.Debug(
    --     "[RANGE CHECK]",
    --     "\nfriend:", spell_friend or "nil",
    --     "\npet:", spell_pet or "nil",
    --     "\nharm:", spell_harm or "nil",
    --     "\ndead:", spell_dead or "nil"
    -- )
end

local timer
local function DELAYED_SPELLS_CHANGED()
    if timer then timer:Cancel() end
    timer = C_Timer.NewTimer(1, SPELLS_CHANGED)
end

rc:SetScript("OnEvent", DELAYED_SPELLS_CHANGED)

function F.IsInRange(unit, check)
    if not UnitIsVisible(unit) then
        return false
    end

    if UnitIsUnit("player", unit) then
        return true

    else
        if UnitCanAssist("player", unit) then -- or UnitCanCooperate("player", unit)
            --! WotLK fix: there is no phasing on 3.3.5 - UnitInPhase is a ClassicAPI
            --! shim hardwired to true (Private.True), so this was a pure Lua call per
            --! friendly unit per range tick.
            if not UnitIsConnected(unit) then
                return false
            end

            if UnitIsDead(unit) then
                if spell_dead then
                    return UnitInSpellRange(spell_dead, unit)
                end
            elseif spell_friend then
                return UnitInSpellRange(spell_friend, unit)
            end

            --! WotLK fix: the second return (checkedRange) was added in 4.0; on 3.3.5
            --! UnitInRange returns 1/nil only, so this branch never fired and classes
            --! without a friendly spell collapsed to CheckInteractDistance's 28 yards.
            --! nil here also means "not a group member" (or a solo pet), so keep
            --! falling through instead of returning false.
            if UnitInRange(unit) == 1 then
                return true
            end

            if UnitIsUnit(unit, "pet") and spell_pet then
                -- no spell_friend, use spell_pet
                return UnitInSpellRange(spell_pet, unit)
            end

        elseif UnitCanAttack("player", unit) then
            if UnitIsDead(unit) then
                return CheckInteractDistance(unit, 4) -- 28 yards
            elseif spell_harm then
                return UnitInSpellRange(spell_harm, unit)
            end
            --! WotLK fix: native IsItemInRange returns 1/0/nil, and 0 is TRUTHY in Lua,
            --! so an out-of-range enemy used to read as "in range" and never faded.
            return IsItemInRange(harmItems[playerClass], unit) == 1
        end

        return CheckInteractDistance(unit, 4) -- 28 yards
    end
end

-------------------------------------------------
-- RangeCheck debug
-------------------------------------------------
local debug = CreateFrame("Frame", "CellRangeCheckDebug", CellParent, nil)
debug:SetBackdrop({bgFile = Cell.vars.whiteTexture})
debug:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
debug:SetBackdropBorderColor(0, 0, 0, 1)
debug:SetPoint("LEFT", 300, 0)
debug:Hide()

debug.text = debug:CreateFontString(nil, "OVERLAY")
debug.text:SetFont(GameFontNormal:GetFont(), 13, "")
debug.text:SetShadowColor(0, 0, 0)
debug.text:SetShadowOffset(1, -1)
debug.text:SetJustifyH("LEFT")
debug.text:SetSpacing(5)
debug.text:SetPoint("LEFT", 5, 0)

local function GetResult1()
    --! WotLK fix: the second return (checkedRange) appeared in 4.0; on 3.3.5
    --! UnitInRange gives 1/nil only (кодекс: inRange = UnitInRange("unit")), so
    --! `checked` was always nil and this window permanently printed a red
    --! "unchecked" about a concept the client does not have - a diagnostic lying
    --! about the API it exists to explain. Print the raw value: nil means either
    --! "out of range" or "not a group member", and F.IsInRange above deliberately
    --! keeps falling through in that case instead of returning false.
    local inRange = UnitInRange("target")

    return "UnitID: " .. (F.GetTargetUnitID("target") or "target") ..
        "\n|cffffff00F.IsInRange:|r " .. (F.IsInRange("target") and "true" or "false") ..
        "\nUnitInRange: " .. (inRange == 1 and "true" or "nil (out of range or not in group)") ..
        "\nUnitIsVisible: " .. (UnitIsVisible("target") and "true" or "false") ..
        "\n\nUnitCanAssist: " .. (UnitCanAssist("player", "target") and "true" or "false") ..
        "\nUnitCanCooperate: " .. (UnitCanCooperate("player", "target") and "true" or "false") ..
        "\nUnitCanAttack: " .. (UnitCanAttack("player", "target") and "true" or "false") ..
        "\n\nUnitIsConnected: " .. (UnitIsConnected("target") and "true" or "false") ..
        "\nUnitInSamePhase: " .. (UnitInSamePhase("target") and "true" or "false") ..
        "\nUnitIsDead: " .. (UnitIsDead("target") and "true" or "false") ..
        "\n\nspell_friend: " .. (spell_friend and (spell_friend .. " " .. (UnitInSpellRange(spell_friend, "target") and "true" or "false")) or "none") ..
        "\nspell_dead: " .. (spell_dead and (spell_dead .. " " .. (UnitInSpellRange(spell_dead, "target") and "true" or "false")) or "none") ..
        "\nspell_pet: " .. (spell_pet and (spell_pet .. " " .. (UnitInSpellRange(spell_pet, "target") and "true" or "false")) or "none") ..
        "\nspell_harm: " .. (spell_harm and (spell_harm .. " " .. (UnitInSpellRange(spell_harm, "target") and "true" or "false")) or "none")
end

local function GetResult2()
    if UnitCanAttack("player", "target") then
        --! WotLK fix: the debug view must normalize native 1/0/nil too; Lua
        --! treats 0 as true and otherwise reported an out-of-range target as true.
        return "IsItemInRange: " .. (IsItemInRange(harmItems[playerClass], "target") == 1 and "true" or "false") ..
            "\nCheckInteractDistance(28y): " .. (CheckInteractDistance("target", 4) and "true" or "false")
    else
        return "IsItemInRange: " .. (InCombatLockdown() and "notAvailable" or (IsItemInRange(harmItems[playerClass], "target") == 1 and "true" or "false")) ..
            "\nCheckInteractDistance(28y): " .. (InCombatLockdown() and "notAvailable" or (CheckInteractDistance("target", 4) and "true" or "false"))
    end
end

debug:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= 0.25 then
        self.elapsed = 0
        local result = GetResult1() .. "\n\n" .. GetResult2()
        result = string.gsub(result, "none", "|cffabababnone|r")
        result = string.gsub(result, "true", "|cff00ff00true|r")
        result = string.gsub(result, "false", "|cffff0000false|r")
        --! WotLK fix: the "checked"/"unchecked" colouring is gone with the word
        --! itself - two gsub passes per 0.25s tick over a string that can never
        --! contain it.

        debug.text:SetText("|cffff0066Cell Range Check (Target)|r\n\n" .. result)

        debug:SetSize(debug.text:GetStringWidth() + 10, debug.text:GetStringHeight() + 20)
    end
end)

debug:SetScript("OnEvent", function()
    if not UnitExists("target") then
        debug:Hide()
        return
    end

    debug:Show()
end)

SLASH_CELLRC1 = "/cellrc"
function SlashCmdList.CELLRC()
    if debug:IsEventRegistered("PLAYER_TARGET_CHANGED") then
        debug:UnregisterEvent("PLAYER_TARGET_CHANGED")
        debug:Hide()
    else
        debug:RegisterEvent("PLAYER_TARGET_CHANGED")
        if UnitExists("target") then
            debug:Show()
        end
    end
end

---------------------------------------------------------------------
-- spec data
---------------------------------------------------------------------
