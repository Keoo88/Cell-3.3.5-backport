local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local PixelUtil = Cell.PixelUtil
local L = Cell.L
local F = Cell.funcs
local I = Cell.iFuncs
local U = Cell.uFuncs
local P = Cell.pixelPerfectFuncs
local LCG = LibStub("LibCustomGlow-1.0-Cell")
local A = Cell.animations

local UnitIsConnected = UnitIsConnected
local UnitIsVisible = UnitIsVisible
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitGUID = UnitGUID
local UnitClass = UnitClass
--! WotLK fix: use Cell's private class-token normalizer; keep native UnitClassBase untouched.
local UnitClassBase = Cell.GetUnitClassToken
local UnitLevel = UnitLevel
--! WotLK fix: consume Cell-private group adapters.
local IsInGroup = Cell.IsInGroup
local IsInRaid = Cell.IsInRaid

local sort, tinsert, tconcat = table.sort, table.insert, table.concat
--! WotLK perf: strfind локально - UNIT_AURA дёргает его на каждое обновление аур
--! каждого юнита группы, а форма unit:find() платит поиском метода в метатаблице
--! строкового типа на каждый вызов.
local strfind = string.find

---------------------------------------------------------------------
-- data
---------------------------------------------------------------------
local buffs = {}
local requiredBuffs = {}
local available = {}
local unaffected = {}

    buffs = {
        -- 1243: Power Word: Fortitude
        -- 21562: Prayer of Fortitude
        ["PWF"] = {buff1 = 1243, buff2 = 21562, provider = "PRIEST", order = 1},

        -- 14752: Divine Spirit
        -- 27681: Prayer of Spirit
        ["DS"] = {buff1 = 14752, buff2 = 27681, provider = "PRIEST", order = 8},

        -- 976: Shadow Protection
        -- 27683: Prayer of Shadow Protection
        ["SP"] = {buff1 = 976, buff2 = 27683, provider = "PRIEST", order = 9},

        -- 1459: Arcane Intellect
        -- 23028: Arcane Brilliance
        --! WotLK feature: 61024 Dalaran Intellect / 61316 Dalaran Brilliance are the
        --! level-80 versions of the same two spells (verified in the client's Spell.dbc).
        --! They carry their OWN aura name, so a raid buffed with Dalaran Brilliance looked
        --! completely unbuffed to a name-based tracker. alt1/alt2 are counted as this buff
        --! (see buffNames) and, if the player knows them, cast by the button instead of
        --! the Arcane ones (see UpdateSpellVariants) - they are strictly stronger.
        ["AB"] = {buff1 = 1459, buff2 = 23028, alt1 = 61024, alt2 = 61316, provider = "MAGE", order = 2},

        -- 6673: Battle Shout
        -- ["BS"] = {buff1 = 6673, provider="WARRIOR"},

        -- 469: Commanding Shout
        -- ["CS"] = {buff1 = 469, provider="WARRIOR"},

        -- 1126: Mark of the Wild
        -- 21849: Gift of the Wild
        ["MotW"] = {buff1 = 1126, buff2 = 21849, provider = "DRUID", order = 3},

        -- 20217: Blessing of Kings
        -- 25898: Greater Blessing of Kings
        ["BoK"] = {buff1 = 20217, buff2 = 25898, provider = "PALADIN", order = 4},

        -- 19740: Blessing of Might
        -- 25782: Greater Blessing of Might
        ["BoM"] = {buff1 = 19740, buff2 = 25782, provider = "PALADIN", order = 5},

        -- 19742: Blessing of Wisdom
        -- 25894: Greater Blessing of Wisdom
        ["BoW"] = {buff1 = 19742, buff2 = 25894, provider = "PALADIN", order = 6},

        -- 20911: Blessing of Sanctuary
        -- 25899: Greater Blessing of Sanctuary
        ["BoS"] = {buff1 = 20911, buff2 = 25899, provider = "PALADIN", order = 7},
    }

    requiredBuffs = {
        ["WARRIOR"] = {["PWF"] = true, ["MotW"] = true, ["BoK"] = true, ["BoM"] = true, ["BoS"] = true, ["SP"] = true},
        ["PALADIN"] = {["PWF"] = true, ["AB"] = true, ["DS"] = true, ["MotW"] = true, ["BoK"] = true, ["BoM"] = true, ["BoW"] = true, ["BoS"] = true, ["SP"] = true},
        ["HUNTER"] = {["PWF"] = true, ["MotW"] = true, ["BoK"] = true, ["BoM"] = true, ["BoS"] = true, ["SP"] = true},
        ["ROGUE"] = {["PWF"] = true, ["MotW"] = true, ["BoK"] = true, ["BoM"] = true, ["BoS"] = true, ["SP"] = true},
        ["PRIEST"] = {["PWF"] = true, ["AB"] = true, ["DS"] = true, ["MotW"] = true, ["BoK"] = true, ["BoW"] = true, ["BoS"] = true, ["SP"] = true},
        ["DEATHKNIGHT"] = {["PWF"] = true, ["MotW"] = true, ["BoK"] = true, ["BoM"] = true, ["BoS"] = true, ["SP"] = true},
        ["SHAMAN"] = {["PWF"] = true, ["AB"] = true, ["DS"] = true, ["MotW"] = true, ["BoK"] = true, ["BoM"] = true, ["BoW"] = true, ["BoS"] = true, ["SP"] = true},
        ["MAGE"] = {["PWF"] = true, ["AB"] = true, ["MotW"] = true, ["BoK"] = true, ["BoW"] = true, ["BoS"] = true, ["SP"] = true},
        ["WARLOCK"] = {["PWF"] = true, ["AB"] = true, ["MotW"] = true, ["BoK"] = true, ["BoW"] = true, ["BoS"] = true, ["SP"] = true},
        ["DRUID"] = {["PWF"] = true, ["AB"] = true, ["DS"] = true, ["MotW"] = true, ["BoK"] = true, ["BoM"] = true, ["BoW"] = true, ["BoS"] = true, ["SP"] = true},
    }

    unaffected = {
        ["PWF"] = {},
        ["AB"] = {},
        ["DS"] = {},
        ["MotW"] = {},
        ["BoK"] = {},
        ["BoM"] = {},
        ["BoW"] = {},
        ["BoS"] = {},
        ["SP"] = {},
    }

---------------------------------------------------------------------
-- prepare
---------------------------------------------------------------------
local classBuffs = {}
local buffOrder = {}
local buffsProvidedByMe = {}
--! WotLK feature: every aura name that satisfies a buff, in scan order (see alt1/alt2
--! above and UnitBuffExists).
local buffNames = {}
--! WotLK feature: blessings are handled apart from the rest - see the blessings section.
local isBlessing = {}
local blessings = {}
--! WotLK feature: true when at least one of my own buffs has an alternative version,
--! i.e. when learning a spell can change what my buttons should cast.
local iProvideVariants = false
local _, myClass = UnitClass("player")
local myName

do
    local function Handle(buff, t, k)
        local name, icon = F.GetSpellInfo(t[k])
        t[k] = {
            ["id"] = t[k],
            ["name"] = name,
            ["icon"] = icon,
        }

        classBuffs[t["provider"]] = classBuffs[t["provider"]] or {}
        classBuffs[t["provider"]][buff] = t.level or true

        if myClass == t["provider"] and not buffsProvidedByMe[buff] then
            buffsProvidedByMe[buff] = {name, icon}
        end
    end

    for k, t in pairs(buffs) do
        if t.buff1 then Handle(k, t, "buff1") end
        if t.buff2 then Handle(k, t, "buff2") end
        --! WotLK feature: alternative versions of the same buff. Handled last so that
        --! buffsProvidedByMe and the bar icon still come from buff1.
        if t.alt1 then Handle(k, t, "alt1") end
        if t.alt2 then Handle(k, t, "alt2") end

        local names = {}
        --! a name is missing only if the id does not exist on this core; skip it instead
        --! of feeding nil into the scan list.
        if t.buff1 and t.buff1.name then tinsert(names, t.buff1.name) end
        if t.buff2 and t.buff2.name then tinsert(names, t.buff2.name) end
        if t.alt1 and t.alt1.name then tinsert(names, t.alt1.name) end
        if t.alt2 and t.alt2.name then tinsert(names, t.alt2.name) end
        buffNames[k] = names

        if t.provider == "PALADIN" then
            isBlessing[k] = true
            tinsert(blessings, k)
        end

        if (t.alt1 or t.alt2) and myClass == t.provider then
            iProvideVariants = true
        end

        tinsert(buffOrder, k)
    end

    local function ByOrder(a, b)
        return buffs[a].order < buffs[b].order
    end

    sort(buffOrder, ByOrder)
    --! WotLK feature: the blessing fallback lights up the first N missing blessings, so
    --! this list has to be stable - pairs() order is not.
    sort(blessings, ByOrder)
end

function U.GetBuffTrackerDefaults()
    local t = {}
    for k in pairs(buffs) do
        t[k] = true
    end
    return t
end

function U.GetBuffTrackerInfo()
    return buffOrder, buffs
end

---------------------------------------------------------------------
-- vars
---------------------------------------------------------------------
local myUnit = ""
local hasBuffProvider

local function Reset(which)
    if not which or which == "available" then
        wipe(available)
        hasBuffProvider = false
    end

    if not which or which == "unaffected" then
        for k, v in pairs(unaffected) do
            wipe(unaffected[k])
        end
    end
end

function F.GetUnaffectedString(spell)
    local list = unaffected[spell]
    local buff = buffs[spell]["buff1"]["name"]

    local players = {}
    for unit in pairs(list) do
        local name = UnitName(unit)
        tinsert(players, name)
    end

    if #players == 0 then
        return
    elseif #players <= 10 then
        return L["Missing Buff"] .. " (" .. buff .. "): " .. tconcat(players, ", ")
    else
        return L["Missing Buff"] .. " (" .. buff .. "): " .. L["many"]
    end
end

---------------------------------------------------------------------
-- frame
---------------------------------------------------------------------
local buffTrackerFrame = CreateFrame("Frame", "CellBuffTrackerFrame", Cell.frames.mainFrame, nil)
Cell.frames.buffTrackerFrame = buffTrackerFrame
P.Size(buffTrackerFrame, 102, 50)
PixelUtil.SetPoint(buffTrackerFrame, "BOTTOMLEFT", CellParent, "CENTER", 1, 1)
buffTrackerFrame:SetClampedToScreen(true)
buffTrackerFrame:SetMovable(true)
buffTrackerFrame:RegisterForDrag("LeftButton")
buffTrackerFrame:SetScript("OnDragStart", function()
    buffTrackerFrame:StartMoving()
    buffTrackerFrame:SetUserPlaced(false)
end)
buffTrackerFrame:SetScript("OnDragStop", function()
    buffTrackerFrame:StopMovingOrSizing()
    P.SavePosition(buffTrackerFrame, CellDB["tools"]["buffTracker"][4])
end)

---------------------------------------------------------------------
-- mover
---------------------------------------------------------------------
buffTrackerFrame.moverText = buffTrackerFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
buffTrackerFrame.moverText:SetPoint("TOP", 0, -3)
--! WotLK fix: label set in ShowMover - at load time L still returns the English key
--! (ns.LoadUserLocale runs on ADDON_LOADED, after every file), and a FontString keeps
--! whatever string it was handed.
buffTrackerFrame.moverText:Hide()

local fakeIconsFrame = CreateFrame("Frame", nil, buffTrackerFrame)
P.Point(fakeIconsFrame, "BOTTOMRIGHT", buffTrackerFrame)
P.Point(fakeIconsFrame, "TOPLEFT", buffTrackerFrame, "TOPLEFT", 0, -18)
fakeIconsFrame:EnableMouse(true)
fakeIconsFrame:SetFrameLevel(buffTrackerFrame:GetFrameLevel() + 10)
--! WotLK fix: fakeIconsFrame перехватывал мышь, чтобы в режиме мувера не кастовать
--! бафы по кнопкам, но сам не тащил - на 3.3.5 нет SetPropagateMouseClicks, поэтому
--! drag до buffTrackerFrame не доходил и зоной хвата оставалась полоса 18 юнитов
--! под moverText (~13 экранных пикселей). Тащим тем же фреймом, который и так
--! накрывает иконки; кнопки не трогаем, они secure.
fakeIconsFrame:RegisterForDrag("LeftButton")
fakeIconsFrame:SetScript("OnDragStart", function()
    buffTrackerFrame:StartMoving()
    buffTrackerFrame:SetUserPlaced(false)
end)
fakeIconsFrame:SetScript("OnDragStop", function()
    buffTrackerFrame:StopMovingOrSizing()
    P.SavePosition(buffTrackerFrame, CellDB["tools"]["buffTracker"][4])
end)
fakeIconsFrame:Hide()

local fakeIcons = {}
local function CreateFakeIcon(spellIcon)
    local bg = fakeIconsFrame:CreateTexture(nil, "BORDER")
    --! WotLK fix: SetColorTexture на 3.3.5 нет - это нативная числовая форма
    --! SetTexture(r, g, b[, a]); шим TextureBase в WidgetAPI удалён.
    bg:SetTexture(0, 0, 0, 1)
    P.Size(bg, 32, 32)

    local icon = fakeIconsFrame:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(spellIcon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    P.Point(icon, "TOPLEFT", bg, "TOPLEFT", 1, -1)
    P.Point(icon, "BOTTOMRIGHT", bg, "BOTTOMRIGHT", -1, 1)

    function bg:UpdatePixelPerfect()
        P.Resize(bg)
        P.Repoint(bg)
        P.Repoint(icon)
    end

    return bg
end

do
    for _, k in ipairs(buffOrder) do
        tinsert(fakeIcons, CreateFakeIcon(buffs[k]["buff1"]["icon"]))
    end
end

local function ShowMover(show)
    if show then
        if not CellDB["tools"]["buffTracker"][1] then return end
        buffTrackerFrame:EnableMouse(true)
        buffTrackerFrame.moverText:SetText(L["Mover"]) --! WotLK fix: см. выше
        buffTrackerFrame.moverText:Show()
        Cell.StylizeFrame(buffTrackerFrame, {0, 1, 0, 0.4}, {0, 0, 0, 0})
        fakeIconsFrame:Show()
        buffTrackerFrame:SetAlpha(1)
    else
        buffTrackerFrame:EnableMouse(false)
        buffTrackerFrame.moverText:Hide()
        Cell.StylizeFrame(buffTrackerFrame, {0, 0, 0, 0}, {0, 0, 0, 0})
        fakeIconsFrame:Hide()
        buffTrackerFrame:SetAlpha(CellDB["tools"]["fadeOut"] and 0 or 1)
    end
end
Cell.RegisterCallback("ShowMover", "BuffTracker_ShowMover", ShowMover)

---------------------------------------------------------------------
-- buttons
---------------------------------------------------------------------
local sendChannel
local function UpdateSendChannel()
    local inInstance, instanceType = IsInInstance()
    if instanceType == "pvp" or instanceType == "arena" then
        sendChannel = "BATTLEGROUND"
    elseif IsInRaid() then
        sendChannel = "RAID"
    else
        sendChannel = "PARTY"
    end
end

local function CreateBuffButton(parent, size, spell1, spell2, icon, index)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    if parent then b:SetFrameLevel(parent:GetFrameLevel() + 1) end
    P.Size(b, size[1], size[2])

    b:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
    b:SetBackdropBorderColor(0, 0, 0, 1)

    --! WotLK fix: on 3.3.5 SecureActionButton_OnClick executes the action on
    --! BOTH down and up (the ActionButtonUseKeyDown cvar gating is a later
    --! addition), so Up+Down registration cast the buff twice per click.
    --! Register down-only; the OnClick hook below must accept down=true now.
    b:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    b:SetAttribute("type1", "spell")
    b:SetAttribute("spell1", spell1)
    b:SetAttribute("type2", "spell")
    b:SetAttribute("spell2", spell2)
    b:HookScript("OnClick", function(self, button, down)
        --! WotLK fix: was "and not down" (upstream fired the announce on the
        --! Up click) - with down-only registration the hook only ever runs
        --! with down=true, so the Up-guard would break shift-announce.
        if button == "LeftButton" and IsShiftKeyDown() then
            local msg = F.GetUnaffectedString(index)
            if msg then
                UpdateSendChannel()
                SendChatMessage(msg, sendChannel)
            end
        end
    end)

    b.texture = b:CreateTexture(nil, "OVERLAY")
    P.Point(b.texture, "TOPLEFT", b, "TOPLEFT", 1, -1)
    P.Point(b.texture, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.texture:SetTexture(icon)
    b.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.count = b:CreateFontString(nil, "OVERLAY")
    P.Point(b.count, "TOPLEFT", b.texture, "TOPLEFT", 2, -2)
    b.count:SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
    b.count:SetShadowColor(0, 0, 0)
    b.count:SetShadowOffset(0, 0)
    b.count:SetTextColor(1, 0, 0)

    b:SetScript("OnLeave", function()
        CellTooltip:Hide()
    end)

    function b:SetTooltips(list)
        b:SetScript("OnEnter", function()
            if F.Getn(list) ~= 0 then
                CellTooltip:SetOwner(b, "ANCHOR_TOPLEFT", 0, 3)
                CellTooltip:AddLine(L["Unaffected"])
                for unit in pairs(list) do
                    local class = UnitClassBase(unit)
                    local name = UnitName(unit)
                    if class and name then
                        CellTooltip:AddLine(F.GetClassColorStr(class) .. name .. "|r")
                    end
                end
                CellTooltip:Show()
            end
        end)
    end

    function b:SetDesaturated(flag)
        b.texture:SetDesaturated(flag)
    end

    function b:StartGlow(glowType, ...)
        LCG.PixelGlow_Start(b, ...)
    end

    function b:StopGlow()
        LCG.PixelGlow_Stop(b)
    end

    function b:Reset()
        b.texture:SetDesaturated(false)
        b.count:SetText("")
        b:SetAlpha(1)
        b:StopGlow()
    end

    function b:UpdatePixelPerfect()
        P.Resize(b)
        P.Repoint(b)
        b:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
        b:SetBackdropBorderColor(0, 0, 0, 1)

        P.Repoint(b.texture)
        P.Repoint(b.count)
    end

    return b
end

local buttons = {}

do
    for _, k in ipairs(buffOrder) do
        buttons[k] = CreateBuffButton(buffTrackerFrame, {32, 32}, buffs[k]["buff1"]["name"], buffs[k]["buff2"] and buffs[k]["buff2"]["name"], buffs[k]["buff1"]["icon"], k)
        buttons[k]:Hide()
        buttons[k]:SetTooltips(unaffected[k])
    end
end

---------------------------------------------------------------------
-- spell variants
---------------------------------------------------------------------
--! WotLK feature: a buff can exist in a second, strictly better version with its own
--! aura name - Dalaran Intellect / Dalaran Brilliance for a level-80 mage. Detection
--! accepts either one (see buffNames), but the button must CAST the one the player
--! actually knows, so the click attributes are picked here instead of being frozen at
--! load time. Spell names, not ids: SecureActionButtonTemplate casts by name and the
--! client picks the highest known rank by itself.
local function KnowsSpell(v)
    if not v or not v.name then return false end
    --! IsSpellKnown is the direct answer; GetSpellInfo(name) is a spellbook lookup and
    --! covers cores where IsSpellKnown does not answer for trainer spells.
    return IsSpellKnown(v.id) or GetSpellInfo(v.name) ~= nil
end

local function UpdateSpellVariants()
    --! the cast buttons are secure: attributes are only ever touched out of combat,
    --! same rule as UpdateButtons and RepointButtons below.
    if InCombatLockdown() then
        buffTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    for code, t in pairs(buffs) do
        if t.alt1 or t.alt2 then
            local single = (KnowsSpell(t.alt1) and t.alt1) or t.buff1
            local group = (KnowsSpell(t.alt2) and t.alt2) or t.buff2
            buttons[code]:SetAttribute("spell1", single and single.name)
            buttons[code]:SetAttribute("spell2", group and group.name)
            --! keep the icon honest about what the left click will cast
            if single and single.icon then
                buttons[code].texture:SetTexture(single.icon)
            end
        end
    end
end

local function UpdateButtons()
    local inCombat = InCombatLockdown()
    for _, buff in ipairs(buffOrder) do
        if available[buff] then
            local n = F.Getn(unaffected[buff])
            if n == 0 then
                buttons[buff].count:SetText("")
                buttons[buff]:SetAlpha(0.5)
                buttons[buff]:StopGlow()
                if not inCombat then
                    buttons[buff]:SetAttribute("unit", nil)
                else
                    buffTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                end
            else
                buttons[buff].count:SetText(n)
                buttons[buff]:SetAlpha(1)

                if not inCombat then
                    local unit = next(unaffected[buff])
                    buttons[buff]:SetAttribute("unit", unit)
                else
                    buffTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                end

                --! WotLK fix: подсветка иконки стала опцией - CellDB.tools.buffTracker[6].
                --! Раньше глоу включался жёстко, когда у меня самого нет баффа, и убрать
                --! его можно было только выключив Buff Tracker целиком. Иконка, счётчик и
                --! альфа остаются на месте, уходит только мигающая рамка.
                if unaffected[buff][myUnit] and CellDB["tools"]["buffTracker"][6] then
                    -- color, N, frequency, length, thickness
                    buttons[buff]:StartGlow("Pixel", {1, 0.19, 0.19, 1}, 8, 0.25, P.Scale(8), P.Scale(2))
                else
                    buttons[buff]:StopGlow()
                end
            end
        end
    end
end

local function RepointButtons()
    if InCombatLockdown() then
        buffTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        local point, relativePoint, offsetX, offsetY, firstX, firstY
        if CellDB["tools"]["buffTracker"][2] == "left-to-right" then
            point, relativePoint = "BOTTOMLEFT", "BOTTOMRIGHT"
            offsetX, offsetY = 3, 0
            firstX, firstY = 0, 0
        elseif CellDB["tools"]["buffTracker"][2] == "right-to-left" then
            point, relativePoint = "BOTTOMRIGHT", "BOTTOMLEFT"
            offsetX, offsetY = -3, 0
            firstX, firstY = 0, 0
        elseif CellDB["tools"]["buffTracker"][2] == "top-to-bottom" then
            point, relativePoint = "TOPLEFT", "BOTTOMLEFT"
            offsetX, offsetY = 0, -3
            firstX, firstY = 0, -18
        elseif CellDB["tools"]["buffTracker"][2] == "bottom-to-top" then
            point, relativePoint = "BOTTOMLEFT", "TOPLEFT"
            offsetX, offsetY = 0, 3
            firstX, firstY = 0, 0
        end

        local last
        for _, k in pairs(buffOrder) do
            P.ClearPoints(buttons[k])
            if available[k] then
                buttons[k]:Show()
                if last then
                    P.Point(buttons[k], point, last, relativePoint, offsetX, offsetY)
                else
                    P.Point(buttons[k], point, firstX, firstY)
                end
                last = buttons[k]
            else
                buttons[k]:Hide()
                buttons[k]:Reset()
            end
        end

        last = nil
        for _, icon in pairs(fakeIcons) do
            P.ClearPoints(icon)
            if last then
                P.Point(icon, point, last, relativePoint, offsetX, offsetY)
            else
                P.Point(icon, point, buffTrackerFrame, point, firstX, firstY)
            end
            last = icon
        end
    end
end

local function ResizeButtons()
    if InCombatLockdown() then
        buffTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        local size = CellDB["tools"]["buffTracker"][3]
        for _, i in pairs(fakeIcons) do
            P.Size(i, size, size)
        end
        for _, b in pairs(buttons) do
            P.Size(b, size, size)
        end

        local n = F.Getn(buttons)
        if strfind(CellDB["tools"]["buffTracker"][2], "left") then
            buffTrackerFrame:SetSize(n * P.Scale(size) + (n - 1) * P.Scale(3), P.Scale(size + 18))
        else
            buffTrackerFrame:SetSize(P.Scale(size), n * P.Scale(size) + (n - 1) * P.Scale(3) + P.Scale(18))
        end
    end
end

---------------------------------------------------------------------
-- fade out
---------------------------------------------------------------------
local fadeOuts = {}
for _, b in pairs(buttons) do
    tinsert(fadeOuts, b)
end
A.ApplyFadeInOutToParent(buffTrackerFrame, function()
    return CellDB["tools"]["fadeOut"] and not buffTrackerFrame.moverText:IsShown()
end, unpack(fadeOuts))

---------------------------------------------------------------------
-- find aura
---------------------------------------------------------------------
local UnitBuff = UnitBuff

--! WotLK feature: the name that matched last time, per buff. A raid is buffed by the
--! same caster with the same version of the spell, so starting the scan at the previous
--! hit means one UnitBuff call per unit instead of walking the whole variant list.
local lastMatch = {}

local function UnitBuffExists(unit, buff)
    --! WotLK fix: native 3.3.5 UnitBuff accepts a spell name directly. Using
    --! C_UnitAuras.GetAuraDataBySpellName invoked a Lua scan of up to 40 aura
    --! slots and allocated a result table for every buff checked on UNIT_AURA.
    local names = buffNames[buff]
    local first = lastMatch[buff]

    if first then
        local found, _, _, _, _, _, _, caster = UnitBuff(unit, names[first])
        if found then
            return true, caster == "player"
        end
    end

    for i = 1, #names do
        if i ~= first then
            local found, _, _, _, _, _, _, caster = UnitBuff(unit, names[i])
            if found then
                lastMatch[buff] = i
                return true, caster == "player"
            end
        end
    end
end

---------------------------------------------------------------------
-- blessings
---------------------------------------------------------------------
--! WotLK feature: a paladin can hold exactly ONE blessing on a target, so the number of
--! blessings a raid member can possibly have equals the number of paladins in the group.
--! The tracker used to ask a different question - "does this class want Kings/Might/
--! Wisdom/Sanctuary" - and with a single paladin present it therefore reported three of
--! the four as missing on everybody, permanently. Two answers, best first:
--!   * PallyPower is the addon the paladins here hand out blessings with, and its
--!     assignment tables are plain globals that EVERY client fills from the raid comm,
--!     non-paladins included (PallyPower registers CHAT_MSG_ADDON without a class gate,
--!     and its ParseMessage writes PallyPower_Assignments / _NormalAssignments). So ask
--!     for the real plan: what is THIS unit supposed to get, from the paladins who are
--!     actually in the group right now. Stale entries for paladins who left are filtered
--!     out by the roster check; individual assignments override that one paladin's class
--!     assignment exactly the way PallyPower:GetSpellID resolves them.
--!   * without PallyPower (not installed, disabled, nothing assigned) fall back to
--!     counting: require at most (paladins - blessings already on the unit) more.
--! Nothing is read unless the tracker is showing blessings at all, nothing is ever
--! written into PallyPower's tables, and no blessing icon disappears from the bar either
--! way - only the "who is missing what" bookkeeping changes.
local numBlessers = 0
local blessingsShown = false
local paladinsInGroup = {}

local ppPrefix
local ppData = false        -- true when PallyPower gave us a usable plan
local ppHasIndividual = false
local ppByClass = {}        -- [classToken] = {[code] = true}, union over paladins present
local ppByName = {}         -- [name] = {[code] = true} for units with an individual assignment
local ppByNameClass = {}    -- [name] = class token that individual assignment was made for
local ppMineByClass = {}    -- [classToken] = the code I am assigned to cast
local ppMineByName = {}     -- [name] = the code I am assigned to cast
local ppCodeByIndex         -- [PallyPower blessing index] = our buff code
local NONE = {}             -- shared read-only empty set: "assigned nothing"

local function BuildPPIndexMap(PP)
    --! blessing index -> our buff code, matched by spell NAME. PallyPower numbers its
    --! blessings differently per expansion (Salvation and Light exist before Wrath), and
    --! both sides take their names from the same GetSpellInfo, so the name is the only
    --! key that cannot silently point at the wrong blessing.
    local map = {}
    for i = 1, 6 do
        local n1, n2 = PP.Spells[i], PP.GSpells[i]
        for code in pairs(isBlessing) do
            local t = buffs[code]
            if (n1 and n1 ~= "" and t.buff1 and t.buff1.name == n1)
                or (n2 and n2 ~= "" and t.buff2 and t.buff2.name == n2) then
                map[i] = code
            end
        end
    end
    return map
end

local function ReadPallyPowerAssignments()
    wipe(ppByClass)
    wipe(ppByName)
    wipe(ppByNameClass)
    wipe(ppMineByClass)
    wipe(ppMineByName)
    ppData = false
    ppHasIndividual = false

    if not blessingsShown or numBlessers == 0 then return end

    --! rule 3: PallyPower is somebody else's addon. Every field is checked before use and
    --! nothing here writes into it.
    local PP = _G.PallyPower
    if type(PP) ~= "table" or type(PP.ClassID) ~= "table"
        or type(PP.Spells) ~= "table" or type(PP.GSpells) ~= "table" then return end

    --! PallyPower keys its saved assignments by expansion; the variable itself is file
    --! local over there, but these three flags are public.
    local flavor = (PP.IsWrath and "Wrath") or (PP.IsTBC and "TBC") or (PP.IsVanilla and "Vanilla")
    if not flavor then return end

    local greater = _G.PallyPower_Assignments
    greater = type(greater) == "table" and greater[flavor] or nil
    local normal = _G.PallyPower_NormalAssignments
    normal = type(normal) == "table" and normal[flavor] or nil
    if type(greater) ~= "table" and type(normal) ~= "table" then return end

    ppCodeByIndex = ppCodeByIndex or BuildPPIndexMap(PP)
    myName = myName or UnitName("player")

    --! what each paladin present hands out to a whole class
    local perPally = {}
    if type(greater) == "table" then
        for pally, byClass in pairs(greater) do
            if paladinsInGroup[pally] and type(byClass) == "table" then
                for idx, classToken in pairs(PP.ClassID) do
                    local code = ppCodeByIndex[byClass[idx] or 0]
                    if code then
                        perPally[pally] = perPally[pally] or {}
                        perPally[pally][idx] = code

                        ppByClass[classToken] = ppByClass[classToken] or {}
                        ppByClass[classToken][code] = true
                        if pally == myName then ppMineByClass[classToken] = code end
                        ppData = true
                    end
                end
            end
        end
    end

    --! an individual assignment replaces THAT paladin's class assignment for THAT player
    --! only - see PallyPower:GetSpellID, where a normal assignment of 0 falls back to the
    --! greater one. Collected first, then merged with the other paladins' plans below.
    local overrides
    if type(normal) == "table" then
        for pally, byClass in pairs(normal) do
            if paladinsInGroup[pally] and type(byClass) == "table" then
                for idx, byTarget in pairs(byClass) do
                    local classToken = PP.ClassID[idx]
                    if classToken and type(byTarget) == "table" then
                        for target, skill in pairs(byTarget) do
                            local code = skill and ppCodeByIndex[skill]
                            if code then
                                ppHasIndividual = true
                                ppData = true
                                ppByNameClass[target] = classToken
                                ppByName[target] = ppByName[target] or {}
                                ppByName[target][code] = true
                                if pally == myName then ppMineByName[target] = code end

                                overrides = overrides or {}
                                --! numeric key: cannot collide with a player name
                                overrides[target] = overrides[target] or {[0] = idx}
                                overrides[target][pally] = true
                            end
                        end
                    end
                end
            end
        end
    end

    if overrides then
        for target, byPally in pairs(overrides) do
            local set = ppByName[target]
            local idx = byPally[0]
            for pally, byIdx in pairs(perPally) do
                if not byPally[pally] then
                    local code = byIdx[idx]
                    if code then set[code] = true end
                end
            end
        end
    end
end

--! WotLK feature: PallyPower broadcasts every assignment change over the raid, so one
--! prefix comparison per addon message is all it takes to know the plan moved.
local ppRefreshTimer
local function RefreshPallyPowerLater(iterate)
    if ppRefreshTimer then return end
    --! one refresh per second at most: assigning a whole raid is a burst of messages, and
    --! the delay also puts our read after PallyPower's own handler, whichever of the two
    --! frames the client happens to dispatch first.
    ppRefreshTimer = C_Timer.NewTimer(1, function()
        ppRefreshTimer = nil
        if not CellDB["tools"]["buffTracker"][1] then return end
        --! in combat the bar refuses to repoint anyway, and PLAYER_REGEN_ENABLED does a
        --! full sweep when the fight ends.
        if InCombatLockdown() then return end
        iterate()
    end)
end

---------------------------------------------------------------------
-- missing buffs
---------------------------------------------------------------------
local missingBuffsFromMe = {}
local hasBuffFromMe = {}

local function UpdateMissingBuffs(unit, buff)
    missingBuffsFromMe[unit] = missingBuffsFromMe[unit] or {}
    tinsert(missingBuffsFromMe[unit], buff)
end

local function ShowMissingBuffs(unit)
    I.HideMissingBuffs(unit)

    if not missingBuffsFromMe[unit] then return end

    local num = #missingBuffsFromMe[unit]
    if num == 0 then return end

    if myClass == "PALADIN" then
        if hasBuffFromMe[unit] then return end
    end

    if num == 1 or myClass == "PRIEST" then
        for _, buff in next, missingBuffsFromMe[unit] do
            I.ShowMissingBuff(unit, buffsProvidedByMe[buff][2])
        end
    else
        I.ShowMissingBuff(unit, 254882)
    end
end

---------------------------------------------------------------------
-- check
---------------------------------------------------------------------
--! WotLK feature: scratch list for the blessing fallback below. Module level on purpose -
--! CheckUnit runs once per unit on every UNIT_AURA, and a fresh table per call would be
--! 40 throwaway tables per sweep. Not reentrant, and neither is CheckUnit.
local missingBlessings = {}

local function CheckUnit(unit, updateBtn)
    -- print("CheckUnit", unit)
    if not hasBuffProvider then return end

    if missingBuffsFromMe[unit] then wipe(missingBuffsFromMe[unit]) end
    hasBuffFromMe[unit] = nil

    if UnitIsConnected(unit) and UnitIsVisible(unit) and not UnitIsDeadOrGhost(unit) then
        local _, class = UnitClass(unit)
        local required = requiredBuffs[class]
        for buff in pairs(available) do
            --! WotLK feature: blessings are decided together, right below - one paladin
            --! cannot put two of them on the same target.
            if required[buff] and not isBlessing[buff] then
                local exists, providedByMe = UnitBuffExists(unit, buff)
                if exists then
                    unaffected[buff][unit] = nil
                    if providedByMe then
                        hasBuffFromMe[unit] = true
                    end
                else
                    unaffected[buff][unit] = true
                    if buffsProvidedByMe[buff] then
                        UpdateMissingBuffs(unit, buff)
                    end
                end
            end
        end

        --! WotLK feature: blessings - see the blessings section above. Walked in a fixed
        --! order because the fallback marks the first N of them.
        if blessingsShown then
            local name, expected, mine
            if ppData then
                expected = ppByClass[class] or NONE
                if ppHasIndividual then
                    name = UnitName(unit)
                    --! the name is only trusted for the class the assignment was made
                    --! for - saved assignments outlive the raid they were made in
                    if name and ppByNameClass[name] == class then
                        expected = ppByName[name]
                    end
                end
                mine = (name and ppMineByName[name]) or ppMineByClass[class]
            end

            local have, num = 0, 0
            for i = 1, #blessings do
                local buff = blessings[i]
                if available[buff] and required[buff] and (not expected or expected[buff]) then
                    local exists, providedByMe = UnitBuffExists(unit, buff)
                    if exists then
                        unaffected[buff][unit] = nil
                        have = have + 1
                        if providedByMe then
                            hasBuffFromMe[unit] = true
                        end
                    elseif expected then
                        --! the plan says this unit gets this blessing: no guessing needed
                        unaffected[buff][unit] = true
                        --! and if the plan names somebody else's blessing, the indicator on
                        --! the unit frame is not mine to light up
                        if buffsProvidedByMe[buff] and (not mine or mine == buff) then
                            UpdateMissingBuffs(unit, buff)
                        end
                    else
                        num = num + 1
                        missingBlessings[num] = buff
                    end
                else
                    --! not wanted, not shown, or not part of the plan - clear it, or the
                    --! counter on the bar keeps a unit from an earlier plan forever
                    unaffected[buff][unit] = nil
                end
            end

            if num > 0 then
                --! no plan to go by: every paladin can still cover one blessing, and the
                --! ones already on the unit have used up that many paladins.
                local slots = numBlessers - have
                for i = 1, num do
                    local buff = missingBlessings[i]
                    if i <= slots then
                        unaffected[buff][unit] = true
                        if buffsProvidedByMe[buff] then
                            UpdateMissingBuffs(unit, buff)
                        end
                    else
                        unaffected[buff][unit] = nil
                    end
                end
            end
        end
    else
        for k, t in pairs(unaffected) do
            t[unit] = nil
        end
    end

    ShowMissingBuffs(unit)

    if updateBtn then UpdateButtons() end
end

local function IterateAllUnits()
    Reset("available")
    myUnit = ""
    --! WotLK feature: blessings - see the blessings section.
    numBlessers = 0
    wipe(paladinsInGroup)

    local class, level
    for unit in F.IterateGroupMembers() do
        -- print("IterateAllUnits checking:", unit)
        if UnitIsConnected(unit) then
            _, class = UnitClass(unit)

            --! WotLK feature: paladins are counted even when they are out of sight.
            --! UnitIsVisible is a range test, not a presence test, and a paladin standing
            --! at the other end of the raid still holds a blessing on people.
            if class == "PALADIN" then
                numBlessers = numBlessers + 1
                local pname = UnitName(unit)
                if pname then paladinsInGroup[pname] = true end
            end

            if UnitIsVisible(unit) then
                level = UnitLevel(unit)
                if classBuffs[class] then
                    for buff, lvl in pairs(classBuffs[class]) do
                        if not available[buff] and (type(lvl) ~= "number" or level >= lvl) then
                            available[buff] = true
                        end
                    end
                end

                if UnitIsUnit("player", unit) then
                    myUnit = unit
                end
            end
        end
    end

    for buff, enabled in pairs(CellDB["tools"]["buffTracker"][5]) do
        if enabled then
            available[buff] = available[buff] and true
        else
            available[buff] = nil
        end
    end

    --! WotLK feature: keep only the buffs my own class can actually cast (buffTracker[7],
    --! on by default). This is the VuhDo model: VUHDO_CLASS_BUFFS is an explicit per-class
    --! list of what that class provides, and its buff watch bar shows nothing else.
    --! Tracking Blessing of Kings on a priest is pure noise - the icon cannot be clicked
    --! to cast it, the missingBuffs indicator never lights up for it either (it only knows
    --! buffsProvidedByMe), so the counter just competes for space with Fortitude/Spirit.
    --! Classes that provide nothing from this list (shaman, rogue, warrior, hunter, death
    --! knight, warlock) keep the whole group overview: filtering there would leave an empty
    --! bar and take away the right-click report instead of cleaning anything up.
    if CellDB["tools"]["buffTracker"][7] and next(buffsProvidedByMe) then
        --! clearing the field being visited is explicitly allowed by the Lua 5.1 manual
        --! ("you may clear existing fields"), unlike adding a new one.
        for buff in pairs(available) do
            if not buffsProvidedByMe[buff] then
                available[buff] = nil
            end
        end
    end

    if next(available) then
        hasBuffProvider = true
    else
        hasBuffProvider = false
    end

    --! WotLK feature: blessings - work out whether any of them is on the bar at all (a
    --! priest with "my class only" on never sees one), then read the plan for the roster
    --! we have just walked. Both are per-sweep state that CheckUnit reads afterwards.
    blessingsShown = false
    for i = 1, #blessings do
        if available[blessings[i]] then
            blessingsShown = true
            break
        end
    end
    ReadPallyPowerAssignments()

    --! WotLK feature: what the buttons cast can change with the spellbook, see
    --! UpdateSpellVariants.
    UpdateSpellVariants()

    RepointButtons()

    Reset("unaffected")

    for unit in F.IterateGroupMembers() do
        CheckUnit(unit)
    end

    UpdateButtons()
end

---------------------------------------------------------------------
-- hide in combat
---------------------------------------------------------------------
--! WotLK feature: "Hide in combat" (CellDB.tools.buffTracker[8], off by default).
--! Asked for by the tester, who runs RaidBuffStatus alongside Cell: buff bookkeeping
--! is a pre-pull job, and during a 25-man fight the bar and the Missing Buffs icons
--! are noise on top of the raid frames. Two halves, and the second one is the point:
--!   * visibility goes through a secure state driver. The bar holds
--!     SecureActionButtonTemplate buttons (see CreateBuffButton), and the code below
--!     already refuses to touch them in combat; "[combat] hide; show" is the
--!     sanctioned way to move a frame like that in and out of sight. FrameXML's own
--!     SecureStateDriverManager does the Show/Hide, so nothing here is tainted.
--!   * UNIT_AURA is dropped for the whole fight. That is the real win: it is by far
--!     the busiest event the tracker listens to (every HoT tick on every raid member
--!     re-checks one unit), and everything it would repaint is hidden anyway.
--! The Missing Buffs icons follow the bar: they are fed from here, so without
--! UNIT_AURA they would just freeze mid-pull showing who was missing what at the
--! moment of the first hit - worse than showing nothing.
local function UpdateHideInCombat()
    if CellDB["tools"]["buffTracker"][1] and CellDB["tools"]["buffTracker"][8] then
        RegisterStateDriver(buffTrackerFrame, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(buffTrackerFrame, "visibility")
        --! tearing the driver down mid-combat would leave the frame hidden, and the
        --! options pane is locked in combat anyway - so defer the reappearance.
        if InCombatLockdown() then
            buffTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            buffTrackerFrame:Show()
        end
    end
end

---------------------------------------------------------------------
-- events
---------------------------------------------------------------------
function buffTrackerFrame:PLAYER_ENTERING_WORLD()
    buffTrackerFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    buffTrackerFrame:GroupRosterUpdate()
end

local timer
function buffTrackerFrame:GroupRosterUpdate(immediate)
    if timer then timer:Cancel() end
    -- if IsInGroup() then
        buffTrackerFrame:RegisterEvent("READY_CHECK")
        buffTrackerFrame:RegisterEvent("UNIT_FLAGS")
        buffTrackerFrame:RegisterEvent("PLAYER_UNGHOST")

        --! WotLK feature: blessings - listen for PallyPower's own traffic so a
        --! re-assignment mid-raid is picked up, but only when PallyPower is actually
        --! loaded. Its prefix is public; the handler compares it and drops everything else.
        ppPrefix = type(_G.PallyPower) == "table" and _G.PallyPower.commPrefix or nil
        if ppPrefix then
            buffTrackerFrame:RegisterEvent("CHAT_MSG_ADDON")
        end

        --! WotLK feature: only meaningful for a class that owns a buff with a second
        --! version - learning it changes what the button has to cast.
        if iProvideVariants then
            buffTrackerFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
        end
        --! WotLK feature: "hide in combat" - see UpdateHideInCombat. This is the one
        --! place where UNIT_AURA is subscribed, so the option is honoured here too:
        --! a roster change mid-fight must not quietly bring the flood back.
        if CellDB["tools"]["buffTracker"][8] then
            buffTrackerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
            if InCombatLockdown() then
                buffTrackerFrame:UnregisterEvent("UNIT_AURA")
                --! nothing to repaint: the bar is hidden and the icons are down.
                return
            end
        else
            buffTrackerFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
        end
        buffTrackerFrame:RegisterEvent("UNIT_AURA")
        -- buffTrackerFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
        -- buffTrackerFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
    -- else
    --     buffTrackerFrame:UnregisterEvent("READY_CHECK")
    --     buffTrackerFrame:UnregisterEvent("UNIT_FLAGS")
    --     buffTrackerFrame:UnregisterEvent("PLAYER_UNGHOST")
    --     buffTrackerFrame:UnregisterEvent("UNIT_AURA")
    --     -- buffTrackerFrame:UnregisterEvent("PARTY_MEMBER_ENABLE")
    --     -- buffTrackerFrame:UnregisterEvent("PARTY_MEMBER_DISABLE")
    --
    --     Reset()
    --     RepointButtons()
    --     return
    -- end

    if immediate then
        IterateAllUnits()
    else
        timer = C_Timer.NewTimer(2, IterateAllUnits)
    end
end

function buffTrackerFrame:READY_CHECK()
    buffTrackerFrame:GroupRosterUpdate(true)
end

function buffTrackerFrame:UNIT_FLAGS()
    buffTrackerFrame:GroupRosterUpdate()
end

function buffTrackerFrame:PLAYER_UNGHOST()
    buffTrackerFrame:GroupRosterUpdate()
end

--! WotLK feature: blessings - PallyPower changed its plan (assign, clear, a paladin
--! announcing what they know). Only the prefix is looked at; the re-read itself is
--! throttled, see RefreshPallyPowerLater.
function buffTrackerFrame:CHAT_MSG_ADDON(prefix)
    if prefix ~= ppPrefix then return end
    RefreshPallyPowerLater(IterateAllUnits)
end

--! WotLK feature: a mage who just learned Dalaran Brilliance should cast it from now on,
--! see UpdateSpellVariants.
function buffTrackerFrame:LEARNED_SPELL_IN_TAB()
    UpdateSpellVariants()
end

-- function buffTrackerFrame:PARTY_MEMBER_ENABLE()
--     buffTrackerFrame:GroupRosterUpdate()
-- end

-- function buffTrackerFrame:PARTY_MEMBER_DISABLE()
--     buffTrackerFrame:GroupRosterUpdate()
-- end

function buffTrackerFrame:UNIT_AURA(unit)
    --! WotLK fix: guard against an argument-less UNIT_AURA. strfind(nil, ...) is a
    --! hard error, and it would come out of the OnEvent dispatcher below - taking the
    --! whole buff tracker down for the rest of the session, which is the failure the
    --! owner already reported once. Custom 3.3.5 cores are known to fire the event
    --! without a unit (the same guard exists in the NoM0Re fork, commit ee3c28c8);
    --! one comparison in front of two strfind calls costs nothing.
    if not unit then return end
    --! WotLK perf: локальный strfind вместо unit:find - см. объявление наверху.
    if IsInRaid() then
        if strfind(unit, "^raid%d+$") then
            CheckUnit(unit, true)
        end
    else
        if strfind(unit, "^party%d$") or unit == "player" then
            CheckUnit(unit, true)
        end
    end
end

function buffTrackerFrame:PLAYER_REGEN_DISABLED()
    --! WotLK feature: "hide in combat" - see UpdateHideInCombat. The state driver
    --! takes the bar off screen by itself; this handler does the half that matters,
    --! dropping UNIT_AURA and taking the Missing Buffs icons down with it.
    if not CellDB["tools"]["buffTracker"][8] then return end

    buffTrackerFrame:UnregisterEvent("UNIT_AURA")
    for unit in F.IterateGroupMembers() do
        I.HideMissingBuffs(unit, true)
    end
    buffTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function buffTrackerFrame:PLAYER_REGEN_ENABLED()
    buffTrackerFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")

    --! WotLK feature: "hide in combat" - the bar is back, so it needs one full sweep:
    --! UNIT_AURA was off for the whole fight and every counter on it is stale.
    if CellDB["tools"]["buffTracker"][1] and CellDB["tools"]["buffTracker"][8] then
        buffTrackerFrame:RegisterEvent("UNIT_AURA")
        RepointButtons()
        ResizeButtons()
        IterateAllUnits()
        return
    end

    --! WotLK feature: the option was switched off while the driver had the frame
    --! hidden - see UpdateHideInCombat, which defers exactly this call.
    if not buffTrackerFrame:IsShown() then
        buffTrackerFrame:Show()
    end

    RepointButtons()
    ResizeButtons()
    --! WotLK feature: this is also where a deferred variant switch lands - the attributes
    --! of the cast buttons cannot be written in combat, see UpdateSpellVariants.
    UpdateSpellVariants()
    UpdateButtons()
end

--! WotLK perf: диспетчер объявлен именованным параметром - в Lua 5.1
--! vararg-функция стоит adjust_varargs на входе и опкод VARARG на распаковку,
--! а UNIT_AURA в рейде идёт потоком. Больше одного слота ни одно из
--! зарегистрированных событий не передаёт (кодекс: UNIT_AURA - unitTarget,
--! READY_CHECK - name, UNIT_FLAGS - unit, остальные с пустым payload),
--! так что одного параметра хватает всем.
--! WotLK feature: CHAT_MSG_ADDON does carry four (prefix, message, channel, sender), but
--! the handler only ever looks at the prefix, so one slot is still enough.
buffTrackerFrame:SetScript("OnEvent", function(self, event, arg1)
    self[event](self, arg1)
end)

---------------------------------------------------------------------
-- functions
---------------------------------------------------------------------
local function UpdateTools(which)
    if not which or which == "buffTracker" then
        if CellDB["tools"]["buffTracker"][1] then
            buffTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            --! WotLK fix: use Cell's private normalized roster callback instead
            --! of registering the non-native GROUP_ROSTER_UPDATE event.
            Cell.RegisterCallback(
                "GroupRosterUpdate",
                "BuffTracker_GroupRosterUpdate",
                buffTrackerFrame.GroupRosterUpdate
            )

            if which == "buffTracker" then -- already in world, manually enabled
                buffTrackerFrame:GroupRosterUpdate(true)
            end
            if Cell.vars.showMover then
                ShowMover(true)
            end
        else
            buffTrackerFrame:UnregisterAllEvents()
            Cell.UnregisterCallback(
                "GroupRosterUpdate",
                "BuffTracker_GroupRosterUpdate"
            )

            Reset()
            myUnit = ""

            ShowMover(false)

            -- missingBuffs indicator
            for unit in F.IterateGroupMembers() do
                I.HideMissingBuffs(unit, true)
            end
        end

        RepointButtons()
        ResizeButtons()
        --! WotLK feature: "hide in combat" - (re)arm or tear down the state driver
        --! after the tracker itself was switched on/off, see UpdateHideInCombat.
        UpdateHideInCombat()
    end

    if not which or which == "fadeOut" then
        if CellDB["tools"]["fadeOut"] and not buffTrackerFrame.moverText:IsShown() then
            buffTrackerFrame:SetAlpha(0)
        else
            buffTrackerFrame:SetAlpha(1)
        end
    end

    if not which then -- position
        P.LoadPosition(buffTrackerFrame, CellDB["tools"]["buffTracker"][4])
    end
end
Cell.RegisterCallback("UpdateTools", "BuffTracker_UpdateTools", UpdateTools)

local function UpdatePixelPerfect()
    -- P.Resize(buffTrackerFrame)

    for _, i in pairs(fakeIcons) do
        i:UpdatePixelPerfect()
    end

    for _, b in pairs(buttons) do
        b:UpdatePixelPerfect()
    end
end
Cell.RegisterCallback("UpdatePixelPerfect", "BuffTracker_UpdatePixelPerfect", UpdatePixelPerfect)
