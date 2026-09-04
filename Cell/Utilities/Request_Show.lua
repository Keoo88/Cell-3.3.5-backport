-- /script SetAllowDangerousScripts(true)
local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local L = Cell.L
local F = Cell.funcs
local I = Cell.iFuncs
local P = Cell.pixelPerfectFuncs

local LCG = LibStub("LibCustomGlow-1.0-Cell")
local Comm = LibStub:GetLibrary("AceComm-3.0")

-------------------------------------------------
-- glow
-------------------------------------------------
local function HideGlow(glowFrame)
    LCG.ButtonGlow_Stop(glowFrame)
    LCG.PixelGlow_Stop(glowFrame)
    LCG.AutoCastGlow_Stop(glowFrame)
    LCG.ProcGlow_Stop(glowFrame)

    if glowFrame.timer then
        glowFrame.timer:Cancel()
        glowFrame.timer = nil
    end
end

local function ShowGlow(glowFrame, glowType, glowOptions, timeout, callback)
    F.Debug("|cffa2d2ffSHOW_GLOW:|r", glowFrame:GetName())

    if glowType == "normal" then
        LCG.PixelGlow_Stop(glowFrame)
        LCG.AutoCastGlow_Stop(glowFrame)
        LCG.ProcGlow_Stop(glowFrame)
        LCG.ButtonGlow_Start(glowFrame, glowOptions[1])
    elseif glowType == "pixel" then
        LCG.ButtonGlow_Stop(glowFrame)
        LCG.AutoCastGlow_Stop(glowFrame)
        LCG.ProcGlow_Stop(glowFrame)
        -- color, N, frequency, length, thickness, x, y
        LCG.PixelGlow_Start(glowFrame, glowOptions[1], glowOptions[4], glowOptions[5], glowOptions[6], glowOptions[7], glowOptions[2], glowOptions[3])
    elseif glowType == "shine" then
        LCG.ButtonGlow_Stop(glowFrame)
        LCG.PixelGlow_Stop(glowFrame)
        LCG.ProcGlow_Stop(glowFrame)
        -- color, N, frequency, scale, x, y
        LCG.AutoCastGlow_Start(glowFrame, glowOptions[1], glowOptions[4], glowOptions[5], glowOptions[6], glowOptions[2], glowOptions[3])
    elseif glowType == "proc" then
        LCG.ButtonGlow_Stop(glowFrame)
        LCG.PixelGlow_Stop(glowFrame)
        LCG.AutoCastGlow_Stop(glowFrame)
        -- color, duration
        LCG.ProcGlow_Start(glowFrame, {color=glowOptions[1], xOffset=glowOptions[2], yOffset=glowOptions[3], duration=glowOptions[4], startAnim=false})
    end

    if glowFrame.timer then
        glowFrame.timer:Cancel()
    end
    glowFrame.timer = C_Timer.NewTimer(timeout, function()
        glowFrame.timer = nil
        HideGlow(glowFrame)
        if callback then
            callback()
        end
    end)
end

-------------------------------------------------
-- icon
-------------------------------------------------
local function HideIcon(icon)
    icon:Hide()

    if icon.timer then
        icon.timer:Cancel()
        icon.timer = nil
    end
end

local function ShowIcon(icon, tex, iconColor, timeout, callback)
    F.Debug("|cffa2d2ffSHOW_ICON:|r", icon:GetName())

    icon:Display(tex, iconColor)

    if icon.timer then
        icon.timer:Cancel()
    end
    icon.timer = C_Timer.NewTimer(timeout, function()
        icon.timer = nil
        HideIcon(icon)
        if callback then
            callback()
        end
    end)
end

-------------------------------------------------
-- text
-------------------------------------------------
local function HideText(text)
    text:Hide()

    if text.timer then
        text.timer:Cancel()
        text.timer = nil
    end
end

local function ShowText(text, timeout, callback)
    F.Debug("|cffa2d2ffSHOW_TEXT:|r", text:GetName())

    text:Display()

    if text.timer then
        text.timer:Cancel()
    end
    text.timer = C_Timer.NewTimer(timeout, function()
        text.timer = nil
        HideText(text)
        if callback then
            callback()
        end
    end)
end

-------------------------------------------------
-- spell request
-------------------------------------------------
local srEnabled, srExists, srKnown, srFreeCD, srReplyCD, srResponseType, srTimeout, srCastMsg
local srSpells = {
    -- [spellId] = {type, buffId, keywords, glowOptions} / {type, buffId, keywords, icon, iconColor}
}
local srUnits = {
    -- [unit] = buffId
}

local SR = CreateFrame("Frame")
local COOLDOWN_TIME = _G.ITEM_COOLDOWN_TIME
local IsSpellReady = F.IsSpellReady

--! WotLK fix: bind the native 3.3.5 spell-link API directly; do not require a
--! partial global C_Spell namespace from Cell's compatibility layer.
local GetSpellLink = GetSpellLink

local function CheckSRConditions(spellId, unit, sender)
    F.Debug("|cffcdb4dbCheckSRConditions:|r", spellId, unit, sender)

    if not srSpells[spellId] then return end

    -- can't find unit
    if not unit or not UnitIsVisible(unit) then return end

    -- already has this buff
    if srExists and F.FindAuraById(unit, "BUFF", srSpells[spellId][2]) then return end

    if srKnown then
        if IsSpellKnown(spellId) then
            -- if srDeadMsg and UnitIsDeadOrGhost("player") then
            --     SendChatMessage(srDeadMsg, "WHISPER", nil, sender)
            -- end

            local isReady, cdLeft = IsSpellReady(spellId)

            if srFreeCD then -- NOTE: require free cd
                if isReady then
                    return true
                else
                    if srReplyCD then -- reply cooldown
                        SendChatMessage(GetSpellLink(spellId).." "..format(COOLDOWN_TIME, F.SecondsToTime(cdLeft)), "WHISPER", nil, sender)
                    end
                    return false
                end
            else -- NOTE: no require free cd
                if srReplyCD and not isReady then -- reply cd if cd
                    SendChatMessage(GetSpellLink(spellId).." "..format(COOLDOWN_TIME, F.SecondsToTime(cdLeft)), "WHISPER", nil, sender)
                end
                return true
            end
        else
            return false
        end
    else
        return true
    end
end

local function ShowSpellRequest(button, spellId)
    if button then
        local unit = button.states.unit

        --! save requesterUnit and buffId
        srUnits[unit] = srSpells[spellId][2]

        if srSpells[spellId][1] == "icon" then
            ShowIcon(button.widgets.srIcon, srSpells[spellId][4], srSpells[spellId][5], srTimeout, function()
                srUnits[unit] = nil
            end)
        else
            ShowGlow(button.widgets.srGlowFrame, srSpells[spellId][4][1], srSpells[spellId][4][2], srTimeout, function()
                srUnits[unit] = nil
            end)
        end
    end
end

local function HideSpellRequest(button)
    HideGlow(button.widgets.srGlowFrame)
    HideIcon(button.widgets.srIcon)
end

--! glow on addon message
Comm:RegisterComm("CELL_REQ_S", function(prefix, message, channel, sender)
    if srEnabled and srResponseType ~= "whisper" then
        local spellId, target = strsplit(":", message)
        spellId = tonumber(spellId)

        if spellId and CheckSRConditions(spellId, Cell.vars.names[sender], sender) then
            local me = GetUnitName("player")
            -- NOTE: to all provider / to me
            -- if (srResponseType == "all" and (not target or target == me)) or (srResponseType == "me" and target == me) then
            if srResponseType == "all" or (srResponseType == "me" and (target == me or target == Cell.vars.playerNickname)) then
                F.HandleUnitButton("name", sender, ShowSpellRequest, spellId)
                -- notify WA
                F.Notify("SPELL_REQ_RECEIVED", Cell.vars.names[sender], srSpells[spellId][2], srTimeout)
            end
        end
    end
end)

--! glow on whisper
local COOLDOWN_TIME_TEXT = string.gsub(ITEM_COOLDOWN_TIME, "%%s", "")
-- NOTE: playerName always contains SERVER name!
--! WotLK fix: CHAT_MSG_WHISPER на 3.3.5a отдаёт ровно 12 значений, guid - двенадцатое
--! (кодекс, payload события). Хвост ретейла (bnSenderID, isMobile, isSubtitle,
--! hideSenderInLetterbox, supressRaidIcons) всегда nil - убран, чтобы позиция guid
--! читалась глазами и совпадала с числом слотов в диспетчере ниже.
function SR:CHAT_MSG_WHISPER(text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid)
    -- NOTE: filter cd reply
    if strfind(text, "^|c.+|H.+|h%[.+%]|h|r "..COOLDOWN_TIME_TEXT..".+") then return end

    for spellId, t in pairs(srSpells) do
        --! WotLK fix: t[3] - это keywords, свободный текст, который игрок сам вписывает
        --! в поле с подписью L["Contains"] ("Содержит", Request_Spell.lua:58). Он уходил
        --! в strfind как Lua-паттерн, хотя подпись обещает поиск подстроки. Замерено под
        --! настоящим Lua 5.1: обработчик CHAT_MSG_WHISPER падает целиком, но не на любом
        --! шёпоте - Lua доходит до сломанного места в паттерне только когда в тексте
        --! встретилась буквальная голова ключа. Ключ "50%" (malformed pattern (ends with
        --! '%')) молчит на "bop" и падает на "мне 50% хп", то есть ровно на том шёпоте,
        --! которым просили заклинание; ключ "[pi" (malformed pattern (missing ']'))
        --! открывает класс на первом же символе и потому роняет ЛЮБОЙ входящий шёпот,
        --! включая пустой. "bop (please)" не срабатывает никогда (скобки съедаются как
        --! capture); "pi." и "^pi" дают ложные срабатывания на чужих шёпотах.
        --! Четвёртый аргумент plain=true документирован для strfind на 3.3.5a
        --! (кодекс: strfind("s","pattern"[,init[,plain]])) и делает ровно то, что обещает
        --! подпись. Апстрим-баг (Cell-retail/Utilities/Request_Show.lua:234).
        if strfind(strlower(text), strlower(t[3]), 1, true) then
            if CheckSRConditions(spellId, Cell.vars.guids[guid], playerName) then
                F.HandleUnitButton("guid", guid, ShowSpellRequest, spellId)
                -- notify WA
                F.Notify("SPELL_REQ_RECEIVED", Cell.vars.guids[guid], t[2], srTimeout)
            end
            break
        end
    end
end

--! WotLK perf: SR слушает ровно два события, и обоим хватает двенадцати слотов
--! (CLEU до spellID - девять, CHAT_MSG_WHISPER на 3.3.5a отдаёт двенадцать, кодекс).
--! Поэтому скрипт объявлен именованными параметрами и вообще не является vararg-
--! функцией: в Lua 5.1 каждое объявление ... стоит adjust_varargs при входе плюс
--! опкод VARARG на распаковку, а CLEU - самое частое событие в игре.
SR:SetScript("OnEvent", function(self, event,
    a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12)

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        --! WotLK fix: the handler consumes the native 3.3.5 payload directly;
        --! do not route Cell behavior through a foreign retail-layout translator.
        --! Нативный порядок: timestamp, subEvent, sourceGUID, sourceName,
        --! sourceFlags, destGUID, destName, destFlags, spellId (без hideCaster и
        --! без raid-flag слотов ретейла).
        local subEvent, sourceGUID, destGUID, buffId = a2, a3, a6, a9
        if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
            local unit = Cell.vars.guids[destGUID]
            if unit and srUnits[unit] == buffId then
                -- hide
                F.HandleUnitButton("unit", unit, HideSpellRequest)
                -- notify APPLIED
                F.Notify("SPELL_REQ_APPLIED", unit, buffId, 0, Cell.vars.guids[sourceGUID])
                F.Debug("|cffdda15eSR_HIDE [|cffbc6c25CLEU:"..subEvent.."|r]:|r", unit, buffId, Cell.vars.guids[sourceGUID])
                -- cast msg (if castByMe)
                if sourceGUID == Cell.vars.playerGUID and srCastMsg then
                    SendChatMessage(srCastMsg, "WHISPER", nil, GetUnitName(unit, true))
                end
                -- clear
                srUnits[unit] = nil
            end
        end
    else
        self[event](self, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12)
    end
end)

local function SR_UpdateRequests(which)
    F.Debug("|cffBBFFFFUpdateRequests:|r", which)

    if not which or which == "spellRequest" then
        -- NOTE: hide all
        for unit in pairs(srUnits) do
            F.HandleUnitButton("unit", unit, HideSpellRequest)
        end
        wipe(srUnits)
        -- texplore(srUnits)

        srEnabled = CellDB["spellRequest"]["enabled"]

        if srEnabled then
            srExists = CellDB["spellRequest"]["checkIfExists"]
            srKnown = CellDB["spellRequest"]["knownSpellsOnly"]
            srFreeCD = CellDB["spellRequest"]["freeCooldownOnly"]
            srResponseType = CellDB["spellRequest"]["responseType"]
            srReplyCD = CellDB["spellRequest"]["replyCooldown"] and srResponseType ~= "all"
            srTimeout = CellDB["spellRequest"]["timeout"]
            srCastMsg = CellDB["spellRequest"]["replyAfterCast"]

            if srResponseType == "whisper" then
                SR:RegisterEvent("CHAT_MSG_WHISPER")
            else
                SR:UnregisterEvent("CHAT_MSG_WHISPER")
            end

            SR:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        else
            SR:UnregisterAllEvents()
        end
    end

    if not which or which == "spellRequest_icon" then
        F.IterateAllUnitButtons(function(b)
            local setting = CellDB["spellRequest"]["sharedIconOptions"]
            b.widgets.srIcon:SetAnimationType(setting[1])
            P.Size(b.widgets.srIcon, setting[2], setting[2])
            P.ClearPoints(b.widgets.srIcon)
            P.Point(b.widgets.srIcon, setting[3], b.widgets.srGlowFrame, setting[4], setting[5], setting[6])
        end)
    end

    if not which or which == "spellRequest_spells" then
        wipe(srSpells)
        if srEnabled then
            for _, t in pairs(CellDB["spellRequest"]["spells"]) do
                if t["type"] == "icon" then
                    srSpells[t["spellId"]] = {t["type"], t["buffId"], t["keywords"], t["icon"], t["iconColor"]} -- [spellId] = {buffId, keywords, icon, iconColor}
                else
                    srSpells[t["spellId"]] = {t["type"], t["buffId"], t["keywords"], t["glowOptions"]} -- [spellId] = {buffId, keywords, glowOptions}
                end
            end
        end
    end
end
Cell.RegisterCallback("UpdateRequests", "SR_UpdateRequests", SR_UpdateRequests)

-------------------------------------------------
-- dispel request
-------------------------------------------------
local drEnabled, drDispellable, drResponseType, drTimeout, drDebuffs, drDisplayType
local drUnits = {}
local DR = CreateFrame("Frame")

--! WotLK fix: одна функция вместо двух одинаковых замыканий ниже - они создавались
--! заново на каждом вызове, а в HideAllDRGlows ещё и на каждой итерации.
local function HideDRRequest(b)
    HideGlow(b.widgets.drGlowFrame)
    HideText(b.widgets.drText)
end

-- hide all
local function HideAllDRGlows()
    -- NOTE: hide all
    for unit in pairs(drUnits) do
        --! WotLK fix: было F.HandleUnitButton("guid", destGUID) - destGUID здесь не
        --! существует ни как локал, ни как параметр, читался глобал (nil), и функция
        --! молча выходила на первой же проверке `if not unit then return end`.
        --! То есть свечение/таймер запроса диспела не гасились никогда: wipe(drUnits)
        --! ниже стирал состояние, а на рамке оставалась висеть подсветка до тех пор,
        --! пока её не перерисует что-то другое. Ключ drUnits - юнит-токен
        --! (см. Cell.vars.names[sender] и Cell.vars.guids[destGUID] ниже), поэтому "unit".
        --! В апстриме та же ошибка (Cell-retail/Utilities/Request_Show.lua:343).
        F.HandleUnitButton("unit", unit, HideDRRequest)
    end
    wipe(drUnits)
end

-- hide glow if removed
--! WotLK perf: DR слушает только CLEU (регистрация ниже), и дальше девятого слота
--! обработчик не смотрит - объявлено девять именованных параметров, поэтому
--! функция вообще не vararg. В Lua 5.1 объявление ... стоит adjust_varargs при
--! входе плюс опкод VARARG на распаковку, а CLEU в рейде идёт сотнями в секунду.
DR:SetScript("OnEvent", function(self, event,
    _, subEvent, _, _, _, destGUID, _, _, spellID)

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        --! WotLK fix: native 3.3.5 CLEU has no hideCaster/raidFlags. Direct
        --! parsing keeps dispel requests independent of standalone ClassicAPI.
        if subEvent == "SPELL_AURA_REMOVED" then
            local unit = Cell.vars.guids[destGUID]
            if unit and drUnits[unit] and drUnits[unit][spellID] then
                -- NOTE: one of debuffs removed, hide glow
                drUnits[unit] = nil
                --! WotLK fix: здесь destGUID настоящий (распакован из CLEU выше), правка
                --! только про замыкание - оно создавалось на каждое снятие дебаффа.
                F.HandleUnitButton("guid", destGUID, HideDRRequest)
            end
        end
    else
        HideAllDRGlows()
    end
end)

-- glow on addon message
Comm:RegisterComm("CELL_REQ_D", function(prefix, message, channel, sender)
    if drEnabled then
        local unit = Cell.vars.names[sender]
        if not unit or not UnitIsVisible(unit) then return end

        if drResponseType == "all" then
            -- NOTE: get all dispellable debuffs on unit
            drUnits[unit] = F.FindAuraByDebuffTypes(unit, "all")
        else -- specific debuff
            -- NOTE: get specific dispellable debuffs on unit
            drUnits[unit] = F.FindDebuffByIds(unit, drDebuffs)
        end

        -- NOTE: filter dispellable by me
        if drDispellable then
            for spellId, debuffType in pairs(drUnits[unit]) do
                if not I.CanDispel(debuffType) then
                    drUnits[unit][spellId] = nil
                end
            end
        end

        if F.Getn(drUnits[unit]) ~= 0 then -- found
            F.HandleUnitButton("name", sender, function(b)
                if drDisplayType == "text" then
                    ShowText(b.widgets.drText, drTimeout, function()
                        drUnits[unit] = nil
                    end)
                else
                    ShowGlow(b.widgets.drGlowFrame, CellDB["dispelRequest"]["glowOptions"][1], CellDB["dispelRequest"]["glowOptions"][2], drTimeout, function()
                        drUnits[unit] = nil
                    end)
                end
            end)
        else
            drUnits[unit] = nil
        end
    end
end)

local function DR_UpdateRequests(which)
    if not which or which == "dispelRequest" then
        HideAllDRGlows()

        drEnabled = CellDB["dispelRequest"]["enabled"]

        if drEnabled then
            drDispellable = CellDB["dispelRequest"]["dispellableByMe"]
            drResponseType = CellDB["dispelRequest"]["responseType"]
            drTimeout = CellDB["dispelRequest"]["timeout"]
            drDebuffs = F.ConvertTable(CellDB["dispelRequest"]["debuffs"])
            drDisplayType = CellDB["dispelRequest"]["type"]

            DR:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            --! WotLK fix: ENCOUNTER_START/END do not exist on 3.3.5 (added 5.4), so
            --! these registrations were silently inert and a dispel-request glow left
            --! over from the previous attempt survived the next pull and the wipe.
            --! Core_Wrath.lua bridges DBM's pull/kill/wipe into Cell's own
            --! EncounterStart/EncounterEnd callbacks - subscribe to those instead.
            Cell.RegisterCallback("EncounterStart", "DispelRequest_EncounterStart", HideAllDRGlows)
            Cell.RegisterCallback("EncounterEnd", "DispelRequest_EncounterEnd", HideAllDRGlows)
        else
            DR:UnregisterAllEvents()
            Cell.UnregisterCallback("EncounterStart", "DispelRequest_EncounterStart")
            Cell.UnregisterCallback("EncounterEnd", "DispelRequest_EncounterEnd")
        end
        -- texplore(drUnits)
        -- texplore(drDebuffs)

    end

    if not which or which == "dispelRequest_text" then
        F.IterateAllUnitButtons(function(b)
            local setting = CellDB["dispelRequest"]["textOptions"]
            b.widgets.drText:SetType(setting[1])
            b.widgets.drText:SetColor(setting[2])
            P.Size(b.widgets.drText, setting[3] * 2, setting[3])
            P.ClearPoints(b.widgets.drText)
            P.Point(b.widgets.drText, setting[4], b.widgets.srGlowFrame, setting[5], setting[6], setting[7])
        end)
    end
end
Cell.RegisterCallback("UpdateRequests", "DR_UpdateRequests", DR_UpdateRequests)