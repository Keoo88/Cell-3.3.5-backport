local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local L = Cell.L
local F = Cell.funcs
--! WotLK fix: consume Cell-private group adapters.
local IsInGroup = Cell.IsInGroup
local IsInRaid = Cell.IsInRaid
local GetNumGroupMembers = Cell.GetNumGroupMembers
--! WotLK fix: realm normalization is private to Cell.
local GetNormalizedRealmName = Cell.GetNormalizedRealmName

local LibDeflate = LibStub:GetLibrary("LibDeflate")
local Serializer = LibStub:GetLibrary("LibSerialize")
local Comm = LibStub:GetLibrary("AceComm-3.0")

local function Serialize(data)
    local serialized = Serializer:Serialize(data) -- serialize
    --! WotLK fix: уровень сжатия больше не задаётся вручную. Здесь стоял
    --! {level = 9} - максимум, самый дорогой режим поиска совпадений. Если конфиг не
    --! передан, LibDeflate выбирает уровень сам по размеру данных
    --! (Libs/LibDeflate/LibDeflate.lua:1782-1790): 7 для строк меньше 2 КБ, 5 до
    --! 64 КБ, 3 для больших. Это ровно те пороги, под которые библиотеку и
    --! настраивали. На 3.3.5 Lua 5.1 без JIT, а сжимаются здесь целые лэйауты и
    --! списки рейд-дебаффов - разница во времени заметная, выигрыш в размере от 9-го
    --! уровня против выбранного библиотекой - единицы процентов, и всё равно
    --! отправка идёт кусками через AceComm с троттлингом.
    local compressed = LibDeflate:CompressDeflate(serialized) -- compress
    return LibDeflate:EncodeForWoWAddonChannel(compressed) -- encode
end

local function Deserialize(encoded)
    local decoded = LibDeflate:DecodeForWoWAddonChannel(encoded) -- decode
    --! WotLK fix: DecodeForWoWAddonChannel returns nil on a malformed payload, and
    --! DecompressDeflate then errors on a nil argument instead of returning nil -
    --! a garbled addon message from any sender would throw inside the AceComm
    --! callback. Checked before use now.
    if not decoded then
        F.Debug("Error decoding addon message")
        return
    end
    local decompressed = LibDeflate:DecompressDeflate(decoded) -- decompress
    if not decompressed then
        --! WotLK fix: errorMsg was never declared anywhere in this file, so this
        --! branch - the one that reports the failure - raised "attempt to
        --! concatenate global 'errorMsg' (a nil value)" itself. DecompressDeflate
        --! returns only nil on failure, it has no second error return, so there is
        --! nothing to print but the fact of the failure.
        F.Debug("Error decompressing addon message")
        return
    end
    local success, data = Serializer:Deserialize(decompressed) -- deserialize
    if not success then
        F.Debug("Error deserializing: " .. data)
        return
    end
    return data
end

-----------------------------------------
-- for WA
-----------------------------------------
function F.Notify(type, ...)
    if WeakAuras then
        WeakAuras.ScanEvents("CELL_NOTIFY", type, ...)
    end
end

-----------------------------------------
-- shared
-----------------------------------------
local sendChannel
local function UpdateSendChannel()
    --! WotLK fix: 3.3.5a has no instance-group category or INSTANCE_CHAT addon channel.
    sendChannel = IsInRaid() and "RAID" or "PARTY"
end

-----------------------------------------
-- Check Version
-----------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)

--! WotLK fix: consume Core_Wrath's private roster callback instead of the
--! non-native GROUP_ROSTER_UPDATE frame event.
local function GroupRosterUpdate()
    if IsInGroup() then
        Cell.UnregisterCallback(
            "GroupRosterUpdate",
            "Comm_GroupRosterUpdate"
        )
        UpdateSendChannel()
        Comm:SendCommMessage("CELL_VERSION", Cell.version, sendChannel, nil, "NORMAL")
    end
end
Cell.RegisterCallback(
    "GroupRosterUpdate",
    "Comm_GroupRosterUpdate",
    GroupRosterUpdate
)

eventFrame:RegisterEvent("PLAYER_LOGIN")
function eventFrame:PLAYER_LOGIN()
    if IsInGuild() then
        Comm:SendCommMessage("CELL_VERSION", Cell.version, "GUILD", nil, "NORMAL")
    end
end

Comm:RegisterComm("CELL_VERSION", function(prefix, message, channel, sender)
    if sender == UnitName("player") then return end
    local version = tonumber(string.match(message, "%d+"))
    local myVersion = tonumber(string.match(Cell.version, "%d+"))
    if (not CellDB["lastVersionCheck"] or time()-CellDB["lastVersionCheck"]>=25200) and version and myVersion and myVersion < version then
        CellDB["lastVersionCheck"] = time()
        F.Print(L["New version found (%s). Please visit %s to get the latest version."]:format(message, "|cFF00CCFFhttps://www.curseforge.com/wow/addons/cell|r"))
    end
end)

-----------------------------------------
-- Notify Marks
-----------------------------------------
Comm:RegisterComm("CELL_MARKS", function(prefix, message, channel, sender)
    if sender == UnitName("player") then return end
    local data = Deserialize(message)
    --! WotLK fix: половина ИЛИ с "^both" вырезана вместе с веткой world-меток -
    --! режимов осталось два, оба target_*. См. audit/STUDY_GAPS.md §2.23.
    if Cell.vars.hasPartyMarkPermission and CellDB["tools"]["marks"][1] and strfind(CellDB["tools"]["marks"][3], "^target") and data then
        sender = F.GetClassColorStr(select(2, UnitClass(sender)))..sender.."|r"

        if data[1] then -- lock
            F.Print(L["%s lock %s on %s."]:format(sender, F.GetMarkEscapeSequence(data[2]), data[3]))
        else
            F.Print(L["%s unlock %s from %s."]:format(sender, F.GetMarkEscapeSequence(data[2]), data[3]))
        end
    end
end)

function F.NotifyMarkLock(mark, name, class)
    name = F.GetClassColorStr(class)..name.."|r"
    F.Print(L["%s lock %s on %s."]:format(L["You"], F.GetMarkEscapeSequence(mark), name))

    UpdateSendChannel()
    Comm:SendCommMessage("CELL_MARKS", Serialize({true, mark, name}), sendChannel, nil, "ALERT")
end

function F.NotifyMarkUnlock(mark, name, class)
    name = F.GetClassColorStr(class)..name.."|r"
    F.Print(L["%s unlock %s from %s."]:format(L["You"], F.GetMarkEscapeSequence(mark), name))

    UpdateSendChannel()
    Comm:SendCommMessage("CELL_MARKS", Serialize({false, mark, name}), sendChannel, nil, "ALERT")
end

-----------------------------------------
-- Priority Check
-----------------------------------------
local myPriority
local highestPriority = 99
Cell.hasHighestPriority = false

--! WotLK fix: keep the legacy UnitName tuple private to Cell instead of loading
--! ClassicAPI/Unit.lua solely to publish a retail-style global UnitFullName.
local function GetUnitNameParts(unit)
    local name, realm = UnitName(unit)
    if UnitIsUnit(unit, "player") and not realm then
        realm = GetNormalizedRealmName()
    end
    return name, realm
end

local function UpdatePriority()
    myPriority = 99
    if Cell.UnitIsGroupLeader("player") then
        myPriority = 0
    else
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                if UnitIsUnit("player", "raid"..i) then
                    myPriority = i
                    break
                end
            end
        elseif IsInGroup() then -- party
            local players = {}
            local pName, pRealm = GetUnitNameParts("player")
            pRealm = pRealm or GetRealmName()
            pName = pName.."-"..pRealm
            tinsert(players, pName)

            for i = 1, GetNumGroupMembers()-1 do
                local name, realm = GetUnitNameParts("party"..i)
                tinsert(players, name.."-"..(realm or pRealm))
            end
            table.sort(players)

            for i, p in pairs(players) do
                if p == pName then
                    myPriority = i
                    break
                end
            end
        end
    end

end

local t_check, t_send, t_update
function F.CheckPriority()
    UpdatePriority()
    -- NOTE: needs time to calc myPriority
    C_Timer.After(1, function()
        UpdateSendChannel()
        Comm:SendCommMessage("CELL_CPRIO", "chk", sendChannel, nil, "ALERT")
    end)
    -- if t_check then t_check:Cancel() end
    -- t_check = C_Timer.NewTimer(2, function()
    --     UpdateSendChannel()
    --     Comm:SendCommMessage("CELL_CPRIO", "chk", sendChannel, nil, "BULK")
    -- end)
end

Comm:RegisterComm("CELL_CPRIO", function(prefix, message, channel, sender)
    if not myPriority then return end -- receive CELL_CPRIO just after GOURP_JOINED
    highestPriority = 99

    -- NOTE: wait for check requests
    if t_send then t_send:Cancel() end
    t_send = C_Timer.NewTimer(2, function()
        UpdateSendChannel()
        Comm:SendCommMessage("CELL_PRIO", tostring(myPriority), sendChannel, nil, "ALERT")
    end)
end)

Comm:RegisterComm("CELL_PRIO", function(prefix, message, channel, sender)
    if not myPriority then return end -- receive CELL_PRIO just after GOURP_JOINED

    local p = tonumber(message)
    if p then
        highestPriority = highestPriority < p and highestPriority or p

        if t_update then t_update:Cancel() end
        t_update = C_Timer.NewTimer(2, function()
            Cell.hasHighestPriority = myPriority <= highestPriority
            Cell.Fire("UpdatePriority", Cell.hasHighestPriority)
            F.Debug("|cff00ff00UpdatePriority:|r", Cell.hasHighestPriority)
        end)
    end
end)

-----------------------------------------
-- cross realm send
-----------------------------------------
local function CrossRealmSendCommMessage(prefix, message, playerName, priority, callbackFn)
    -- NOTE: unit needs to be in your group, or it will always return true
    if UnitIsSameServer(playerName) then
        Comm:SendCommMessage(prefix, message, "WHISPER", playerName, priority, callbackFn)
    else
        if UnitInParty(playerName) then
            Comm:SendCommMessage(prefix, playerName..":"..message, "PARTY", nil, priority, callbackFn)
        elseif UnitInRaid(playerName) then
            Comm:SendCommMessage(prefix, playerName..":"..message, "RAID", nil, priority, callbackFn)
        end
    end
end

-----------------------------------------
-- Send / Receive Raid Debuffs and Layouts
-----------------------------------------
local function filterFunc(self, event, msg, player, arg1, arg2, arg3, flag, channelId, ...)
    local newMsg = ""

    --! WotLK fix: the separator was a colon here while every sender writes a dot -
    --! "[Cell.Layout: ...]" (Modules/Layouts/Layouts.lua:1588) and "[Cell.Debuffs:
    --! ...]" (Modules/RaidDebuffs/RaidDebuffs_Classic.lua:577, :688, :691). So no
    --! share string Cell itself produces ever matched, and the clickable link the
    --! receiver is supposed to get never appeared - they saw the raw bracket text.
    --! Inherited from upstream, where the same mismatch exists. The class [%.:]
    --! accepts both spellings so a message from any Cell build is recognised.
    local type = msg:match("%[Cell[%.:](.+): .+]")
    if type == "Debuffs" then
        local bossName, instanceName, playerName = msg:match("%[Cell[%.:]Debuffs: (.+) %((.+)%) %- ([^%s]+%-[^%s]+)%]")
        if bossName and instanceName and playerName then
            newMsg = "|Hgarrmission:cell-debuffs|h|cFFFF0066["..L[type]..": "..bossName.." ("..instanceName..") - "..playerName.."]|h|r"
        else
            instanceName, playerName = msg:match("%[Cell[%.:]Debuffs: (.+) %- ([^%s]+%-[^%s]+)%]")
            if instanceName and playerName then
                newMsg = "|Hgarrmission:cell-debuffs|h|cFFFF0066["..L[type]..": "..instanceName.." - "..playerName.."]|h|r"
            end
        end
    elseif type == "Layout" then
        local layoutName, playerName = msg:match("%[Cell[%.:]Layout: (.+) %- ([^%s]+%-[^%s]+)%]")
        if layoutName and playerName then
            if layoutName == "default" then
                -- NOTE: convert "default"
                layoutName = _G.DEFAULT
            end
            newMsg = "|Hgarrmission:cell-layout|h|cFFFF0066["..L[type]..": "..layoutName.." - "..playerName.."]|h|r"
        end
    end

    if newMsg ~= "" then
        return false, newMsg, player, arg1, arg2, arg3, flag, channelId, ...
    end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", filterFunc)
--! WotLK fix: CHAT_MSG_INSTANCE_CHAT / _LEADER do not exist on 3.3.5 - the
--! instance chat channel arrived with Cataclysm; on this client the same traffic
--! comes through CHAT_MSG_BATTLEGROUND / _LEADER (FrameXML ChatFrame.lua:148,
--! ChatTypeGroup["BATTLEGROUND"]). Registering the retail names was not an error,
--! ChatFrame_AddMessageEventFilter just files them under a key nothing ever emits
--! (ChatFrame.lua:2962-2977), so a share string pasted into battleground chat was
--! never turned into a link. Swapped for the events this client actually fires.
--! BN_WHISPER above stays: Real ID shipped in 3.3.5 and both events are real here
--! (ChatFrame.lua:246-249) even though codex.py answers НЕТ for them.
ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND_LEADER", filterFunc)

local isRequesting

-- NOTE: received
Comm:RegisterComm("CELL_SEND", function(prefix, message, channel, sender)
    if not isRequesting then return end
    if channel ~= "WHISPER" then
        local target
        target, message = strsplit(":", message, 2)
        if target ~= Cell.vars.playerNameFull then
            return
        end
    end

    local receivedData = Deserialize(message)

    if Cell.frames.receivingFrame then
        if receivedData then
            Cell.frames.receivingFrame:ShowImport(true, receivedData, function()
                isRequesting = false
            end)
        else
            Cell.frames.receivingFrame:ShowImport(false, nil, function()
                isRequesting = false
            end)
        end
    end
end)

-- NOTE: progress received
Comm:RegisterComm("CELL_SEND_PROG", function(prefix, message, channel, sender)
    if not isRequesting then return end
    if channel ~= "WHISPER" then
        local target
        target, message = strsplit(":", message, 2)
        if target ~= Cell.vars.playerNameFull then
            return
        end
    end

    local done, total = strsplit("|", message)
    done, total = tonumber(done), tonumber(total)

    if Cell.frames.receivingFrame then
        Cell.frames.receivingFrame:ShowProgress(done, total)
    end
end)

-- NOTE: request received
Comm:RegisterComm("CELL_REQ", function(prefix, message, channel, requester)
    if channel ~= "WHISPER" then
        local target
        target, message = strsplit(":", message, 2)
        if target ~= Cell.vars.playerNameFull then
            return
        end
    end

    -- check request
    local type, name1, name2 = strsplit(":", message)
    local requestData

    -- print(type, name1, name2)
    if type == "Debuffs" then
        local instanceId, bossId = F.GetInstanceAndBossId(name1, name2)
        if not instanceId then return end -- invalid instanceName

        requestData = {
            ["type"] = "Debuffs",
            ["instanceId"] = instanceId,
            ["bossId"] = bossId,
            ["version"] = Cell.versionNum
        }

        -- check db
        if not bossId then -- all bosses
            if CellDB["raidDebuffs"][instanceId] then
                requestData["data"] = CellDB["raidDebuffs"][instanceId]
            end
        else
            if CellDB["raidDebuffs"][instanceId] and CellDB["raidDebuffs"][instanceId][bossId] then
                requestData["data"] = CellDB["raidDebuffs"][instanceId][bossId]
            end
        end
    elseif type == "Layout" then
        if name1 == _G.DEFAULT then
            -- NOTE: convert "DEFAULT"
            name1 = "default"
        end
        if name1 and CellDB["layouts"][name1] then
            requestData = {
                ["type"] = "Layout",
                ["name"] = name1,
                ["version"] = Cell.versionNum,
                ["data"] = CellDB["layouts"][name1]
            }
        end
    end

    -- texplore(requestData)

    if not requestData then return end
    CrossRealmSendCommMessage("CELL_SEND", Serialize(requestData), requester, "BULK", function(arg, done, total)
        -- send progress
        CrossRealmSendCommMessage("CELL_SEND_PROG", done.."|"..total, requester, "ALERT")
    end)
end)

local function ShowReceivingFrame(type, playerName, name1, name2)
    if not Cell.frames.receivingFrame then
        Cell.frames.receivingFrame = Cell.CreateReceivingFrame(Cell.frames.mainFrame)
        Cell.frames.receivingFrame:SetOnCancel(function(b)
            isRequesting = false
        end)
    end

    Cell.frames.receivingFrame:SetOnRequest(function(b)
        isRequesting = true
        --! send request
        CrossRealmSendCommMessage("CELL_REQ", type..":"..name1..":"..(name2 or ""), playerName, "ALERT")
    end)

    Cell.frames.receivingFrame:ShowFrame(type, playerName, name1, name2)
end

--! WotLK fix: SetItemRef on 3.3.5 knows only the player / channel / GMChat schemes
--! and falls through for everything else to ShowUIPanel(ItemRefTooltip) +
--! ItemRefTooltip:SetHyperlink(link) (FrameXML ItemRef.lua:174-183). "garrmission"
--! is a retail scheme this client has never heard of, so clicking a Cell share link
--! popped an empty ItemRefTooltip window next to Cell's own dialog. The scheme name
--! itself is kept - an arbitrary |H tag does render and route as a link here, ElvUI
--! ships |Hurl: and |Helvmoji: on this same client - so only the stray window is
--! cleaned up, and only on links we recognise as ours. This runs as a post-hook,
--! after the panel was shown, which is exactly when it can be taken back.
hooksecurefunc("SetItemRef", function(link, text)
    if isRequesting then return end
    if link == "garrmission:cell-debuffs" or link == "garrmission:cell-layout" then
        if ItemRefTooltip and ItemRefTooltip:IsShown() then
            ItemRefTooltip:Hide()
        end
    end
    if link == "garrmission:cell-debuffs" then
        local bossName, instanceName, playerName = text:match("|Hgarrmission:cell%-debuffs|h|cFFFF0066%[.+: (.+) %((.+)%) %- ([^%s]+%-[^%s]+)%]|h|r")
        if bossName and instanceName and playerName then
            ShowReceivingFrame("Debuffs", playerName, instanceName, bossName)
        else
            instanceName, playerName = text:match("|Hgarrmission:cell%-debuffs|h|cFFFF0066%[.+: (.+) %- ([^%s]+%-[^%s]+)%]|h|r")
            ShowReceivingFrame("Debuffs", playerName, instanceName)
        end
    elseif link == "garrmission:cell-layout" then
        local layoutName, playerName = text:match("|Hgarrmission:cell%-layout|h|cFFFF0066%[.+: (.+) %- ([^%s]+%-[^%s]+)%]|h|r")
        ShowReceivingFrame("Layout", playerName, layoutName)
    end
end)
