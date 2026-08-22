---------------------------------------------------------------------
-- File: Cell\Libs\LibGroupInfo.lua
-- Author: enderneko (enderneko-dev@outlook.com)
-- Created : 2022-07-29 15:04 +08:00
-- Modified: 2025-07-07 08:59 +08:00
---------------------------------------------------------------------

local MAJOR, MINOR = "LibGroupInfo", 7
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end -- already loaded

--! WotLK fix: this embedded library uses Cell's private timer contract rather
--! than whichever global C_Timer standalone !!!ClassicAPI published first.
local C_Timer = _G.Cell and _G.Cell.C_Timer
assert(C_Timer, MAJOR.." requires Cell.C_Timer")

lib.callbacks = LibStub("CallbackHandler-1.0"):New(lib)
if not lib.callbacks then error(MAJOR.." requires CallbackHandler") end

local UPDATE_EVENT = "GroupInfo_Update" -- guid, unit, cache[guid]
local UPDATE_BASE_EVENT = "GroupInfo_UpdateBase" -- guid, unit, cache[guid]
local QUEUE_EVENT = "GroupInfo_QueueStatus"

local PLAYER_GUID
local RETRY_INTERVAL = 1.5
local MAX_ATTEMPTS = 3

--! WotLK fix: this embedded library belongs to the Interface 30300 backport.
--! Do not derive its path from optional global project constants owned by a
--! custom core or standalone compatibility addon.
local IS_WRATH = true

local debugMode = false
local function Print(...)
    if debugMode then
        print(...)
    end
end

-- store inspect data
local cache = {
    -- [guid] = {
    --     unit = (string),
    --     name = (string),
    --     realm = (string),
    --     class = (string, EN uppercase),
    --     level = (number),
    --     race = (string, EN),
    --     gender = ("unknown", "male", "female"),
    --     faction = ("Alliance", "Horde", "Neutral", nil),
    --     assignedRole = ("TANK", "HEALER", "DAMAGER", "NONE"),
    --     specId = (number),
    --     specName = (string),
    --     specRole = ("TANK", "MELEE", "RANGED", "DAMAGER", "HEALER"),
    --     specIcon = (number),
    --     inspected = (boolean),
    -- }
}
lib.cache = cache

function lib:GetCachedInfo(guid)
    return guid and cache[guid]
end

function lib:GuidToUnit(guid)
    if cache[guid] then
        return cache[guid].unit
    end
end

-- static data
local genders = {"unknown", "male", "female"}
local specData = {}
local specRoles = {
    -- Death Knight
    [250] = "TANK", -- Blood
    [251] = "MELEE", -- Frost
    [252] = "MELEE", -- Unholy
    [1455] = "DAMAGER",
    -- Demon Hunter
    [577] = "MELEE", -- Havoc
    [581] = "TANK", -- Vengeance
    [1456] = "DAMAGER",
    -- Druid
    [102] = "RANGED", -- Balance
    [103] = "MELEE", -- Feral
    [104] = "TANK", -- Guardian
    [105] = "HEALER", -- Restoration
    [1447] = "DAMAGER",
    -- Evoker
    [1467] = "RANGED", -- Devastation
    [1468] = "HEALER", -- Preservation
    [1473] = "RANGED", -- Augmentation
    [1465] = "DAMAGER",
    -- Hunter
    [253] = "RANGED", -- Beast Mastery
    [254] = "RANGED", -- Marksmanship
    [255] = "MELEE", -- Survival
    [1448] = "DAMAGER",
    -- Mage
    [62] = "RANGED", -- Arcane
    [63] = "RANGED", -- Fire
    [64] = "RANGED", -- Frost
    [1449] = "DAMAGER",
    -- Monk
    [268] = "TANK", -- Brewmaster
    [269] = "MELEE", -- Windwalker
    [270] = "HEALER", -- Mistweaver
    [1450] = "DAMAGER",
    -- Paladin
    [65] = "HEALER", -- Holy
    [66] = "TANK", -- Protection
    [70] = "MELEE", -- Retribution
    [1451] = "DAMAGER",
    -- Priest
    [256] = "HEALER", -- Discipline
    [257] = "HEALER", -- Holy
    [258] = "RANGED", -- Shadow
    [1452] = "DAMAGER",
    -- Rogue
    [259] = "MELEE", -- Assassination
    [260] = "MELEE", -- Combat
    [261] = "MELEE", -- Subtlety
    [1453] = "DAMAGER",
    -- Shaman
    [262] = "RANGED", -- Elemental
    [263] = "MELEE", -- Enhancement
    [264] = "HEALER", -- Restoration
    [1444] = "DAMAGER",
    -- Warlock
    [265] = "RANGED", -- Affliction
    [266] = "RANGED", -- Demonology
    [267] = "RANGED", -- Destruction
    [1454] = "DAMAGER",
    -- Warrior
    [71] = "MELEE", -- Arms
    [72] = "MELEE", -- Fury
    [73] = "TANK", -- Protection
    [1446] = "DAMAGER",
}

lib.specData = specData
lib.specRoles = specRoles

-- functions
local NotifyInspect = NotifyInspect
local UnitGUID = UnitGUID
--! WotLK fix: use Cell's private class-token normalizer; keep native UnitClassBase untouched.
local UnitClassBase = _G.Cell and _G.Cell.GetUnitClassToken
assert(UnitClassBase, MAJOR.." requires Cell.GetUnitClassToken")
local UnitIsUnit = UnitIsUnit
local UnitIsDead = UnitIsDead
local UnitIsConnected = UnitIsConnected
local UnitIsVisible = UnitIsVisible
local CanInspect = CanInspect

-- Polyfill for UnitNameUnmodified (doesn't exist in WotLK 3.3.5a) 
if not UnitNameUnmodified then
    UnitNameUnmodified = UnitName
end
local UnitNameUnmodified = UnitNameUnmodified

--! WotLK fix: consume Cell's private realm normalizer. Do not publish or depend
--! on a shared global; standalone !!!ClassicAPI/custom cores keep their owners.
local GetNormalizedRealmName = Cell.GetNormalizedRealmName
assert(GetNormalizedRealmName, MAJOR.." requires Cell.GetNormalizedRealmName")
local UnitLevel = UnitLevel
local UnitRace = UnitRace
local UnitSex = UnitSex
local UnitFactionGroup = UnitFactionGroup
local IsInInstance = IsInInstance
--! WotLK fix: consume Cell-private group adapters; shared compatibility globals may belong to another addon.
local IsInRaid = Cell.IsInRaid
local IsInGroup = Cell.IsInGroup
local GetNumGroupMembers = Cell.GetNumGroupMembers
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitGroupRolesAssigned = Cell.UnitGroupRolesAssigned --! WotLK fix: Cell-private retail-contract adapter; the bare global remains native (3 booleans).

local GetNumTalentTabs = GetNumTalentTabs
local GetTalentTabInfo = GetTalentTabInfo

-- event frame
local frame = CreateFrame("Frame", MAJOR.."Frame")
frame:Hide()
frame:RegisterEvent("PLAYER_LOGIN")
-- frame:RegisterEvent("PLAYER_LOGOUT")
--! WotLK fix: держать закомментированным. PLAYER_LOGOUT на 3.3.5 есть, но
--! обработчика frame:PLAYER_LOGOUT в библиотеке нет ни одного, а диспетчер ниже
--! зовёт self[event] без проверки - раскомментировать значит получить
--! "attempt to call field 'PLAYER_LOGOUT' (a nil value)" при выходе из игры.
frame:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)

-- prepare spec data (name, icon, role)
-- local function CacheSpecData()
--     for classId = 1, GetNumClasses() do
--         for specIndex = 1, GetNumSpecializationsForClassID(classId) do
--             local id, name, description, icon, role = GetSpecializationInfoForClassID(classId, specIndex)
--             if id then
--                 specData[id] = {
--                     ["name"] = name,
--                     ["icon"] = icon,
--                     ["role"] = specRoles[id],
--                 }
--             end
--         end
--         -- initials
--         if IS_RETAIL then
--             local id, name, description, icon, role = GetSpecializationInfoForClassID(classId, 5)
--             specData[id] = {
--                 ["name"] = name,
--                 ["icon"] = icon,
--                 ["role"] = specRoles[id],
--             }
--         end
--     end
-- end

local function UpdateBaseInfo(unit, guid)
    if not guid then return end

    if not cache[guid] then cache[guid] = {} end
    --! WotLK fix: always create the talents table - BuildAndNotify_Wrath is
    --! the only build path here and it indexes cache[guid]["talents"]
    --! unconditionally (used to crash with "attempt to index field ? a nil
    --! value" when the table was missing).
    if not cache[guid]["talents"] then
        cache[guid]["talents"] = {}
    end

    -- general
    cache[guid].unit = unit
    cache[guid].name, cache[guid].realm = UnitNameUnmodified(unit)
    if not cache[guid].realm then
        cache[guid].realm = GetNormalizedRealmName()
    end
    cache[guid].class = UnitClassBase(unit)
    cache[guid].level = UnitLevel(unit)
    cache[guid].race = select(2, UnitRace(unit))
    cache[guid].gender = genders[UnitSex(unit)]
    cache[guid].faction = UnitFactionGroup(unit)
    cache[guid].assignedRole = UnitGroupRolesAssigned(unit)

    --! fire
    lib.callbacks:Fire(UPDATE_BASE_EVENT, guid, unit, cache[guid])

    return guid
end

-- 3.3.5: role by class + dominant talent tree (tab index order is fixed).
-- Feral druids are mapped to DAMAGER (bear/cat is indistinguishable from
-- talents alone); bear tanks are covered by raid main tank assignment.
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

--! WotLK fix: locale-independent talent tab background prefixes per class,
--! used to validate that inspect data actually belongs to the inspected
--! unit (e.g. "ShamanElementalCombat" -> SHAMAN). Same idea as
--! LibTalentQuery's validateTrees, but fileNames need no LibBabble.
local CLASS_TALENT_FILE_PREFIX = {
    WARRIOR = "Warrior",
    PALADIN = "Paladin",
    HUNTER = "Hunter",
    ROGUE = "Rogue",
    PRIEST = "Priest",
    DEATHKNIGHT = "DeathKnight",
    SHAMAN = "Shaman",
    MAGE = "Mage",
    WARLOCK = "Warlock",
    DRUID = "Druid",
}

local function BuildAndNotify_Wrath(unit)
    Print("|cffff7777LGI:BuildAndNotify_Wrath|r", unit)

    local guid = UnitGUID(unit)
    --! WotLK fix: the retail BuildAndNotify bails on a nil guid, but this Wrath
    --! path never did. When UnitGUID(unit) is nil (e.g. PLAYER_TALENT_UPDATE
    --! firing before the unit is available), UpdateBaseInfo returns early without
    --! creating cache[guid], so cache[guid]["talents"] crashed at line 398
    --! (attempt to index field '?' a nil value). Guard the same way.
    if not guid then return end
    UpdateBaseInfo(unit, guid)

    -- spec
    local isInspect = not UnitIsUnit(unit, "player")
    local maxPoints = 0
    local maxTab

    if isInspect then
        --! WotLK fix: on 3.3.5 the inspect talent storage can hold STALE or
        --! FOREIGN data: our own talents (own respec, silently failed
        --! NotifyInspect) or a previously inspected unit's. Symptom: a party
        --! warrior's role followed the PLAYER's spec changes (resto = tab 3
        --! -> WARRIOR[3] = TANK). Validate like LibTalentQuery does: the tab
        --! background fileName is class-determined and locale-independent,
        --! so it must match the inspected unit's class, and total points
        --! must be > 0. On bad data, bail out (return false) so the queue
        --! re-requests the unit instead of caching garbage.
        local numTabs = GetNumTalentTabs(true)
        local activeGroup = GetActiveTalentGroup and GetActiveTalentGroup(true) or nil
        local expectedPrefix = CLASS_TALENT_FILE_PREFIX[cache[guid].class]
        local totalPoints = 0
        local tabs = {}

        for i = 1, numTabs do
            local name, texture, pointsSpent, fileName = GetTalentTabInfo(i, true, false, activeGroup)
            if expectedPrefix and not (fileName and strfind(fileName, expectedPrefix, 1, true) == 1) then
                Print("|cffff7777LGI:INSPECT_DATA_MISMATCH|r", unit, fileName)
                return false
            end
            totalPoints = totalPoints + (pointsSpent or 0)
            tabs[i] = {name = name, texture = texture, points = pointsSpent or 0, fileName = fileName}
        end

        if numTabs == 0 or totalPoints == 0 then
            Print("|cffff7777LGI:INSPECT_DATA_EMPTY|r", unit)
            return false
        end

        for i = 1, numTabs do
            local tab = tabs[i]
            cache[guid]["talents"][tab.fileName] = {
                ["points"] = tab.points,
                ["name"] = tab.name,
                ["icon"] = tab.texture,
            }

            if tab.points > maxPoints then
                maxPoints = tab.points
                maxTab = i
                cache[guid].specName = tab.name
                cache[guid].specIcon = tab.texture
            end
        end

        --! WotLK fix: mark as inspected (the retail path sets this, the
        --! wrath path never did) - otherwise every roster event/rescan
        --! re-queued EVERY member forever, keeping the inspect queue
        --! churning and massively raising the odds of misattributed
        --! INSPECT_TALENT_READY data.
        cache[guid].inspected = true
    else
        --! defensive: ensure talents table exists even if UpdateBaseInfo
        --! ran with IS_WRATH=false (3.3.5 Alpha WOW_PROJECT_ID mismatch)
        if not cache[guid]["talents"] then cache[guid]["talents"] = {} end
        for i = 1, GetNumTalentTabs() do
            local name, texture, pointsSpent, fileName = GetTalentTabInfo(i)
            cache[guid]["talents"][fileName] = {
                ["points"] = pointsSpent,
                ["name"] = name,
                ["icon"] = texture,
            }

            if pointsSpent > maxPoints then
                maxPoints = pointsSpent
                maxTab = i
                cache[guid].specName = name
                cache[guid].specIcon = texture
            end
        end

        --! WotLK fix: very early during login the client can still report
        --! 0/0/0 for our OWN talents (same quirk LibTalentQuery documents
        --! for inspects). Don't accept that as the final answer - retry
        --! once shortly after. Level < 10 characters legitimately have 0
        --! points; the single retry is harmless for them.
        if not maxTab and not lib.playerRetryScheduled then
            lib.playerRetryScheduled = true
            C_Timer.After(5, function()
                lib.playerRetryScheduled = nil
                BuildAndNotify_Wrath("player")
            end)
        end
    end

    -- derive role from class + dominant tree (was never set in the wrath
    -- path, leaving specRole nil and breaking role detection downstream)
    if maxTab and cache[guid].class and WRATH_TREE_ROLES[cache[guid].class] then
        cache[guid].specRole = WRATH_TREE_ROLES[cache[guid].class][maxTab]
    else
        cache[guid].specRole = nil
    end

    --! fire
    lib.callbacks:Fire(UPDATE_EVENT, guid, unit, cache[guid])
    return true
end

local function Query(unit)
    -- if InCombatLockdown() then return end
    if UnitIsDead("player") then return end

    if IsInGroup() and not (UnitInParty(unit) or UnitInRaid(unit)) then return end

    -- returns false when the inspect data was rejected as stale/foreign
    return BuildAndNotify_Wrath(unit)
end

---------------------------------------------------------------------
-- login & reload & enter/leave instance
---------------------------------------------------------------------
function frame:PLAYER_LOGIN()
    PLAYER_GUID = UnitGUID("player")

    cache[PLAYER_GUID] = {["talents"]={}}
    -- frame:RegisterEvent("UNIT_AURA")

    --! WotLK fix: PLAYER_SPECIALIZATION_CHANGED doesn't exist on 3.3.5,
    --! so the player's cached spec was built once at login and never
    --! refreshed - the role stuck to whatever spec you logged in with.
    --! Own spec changes arrive as ACTIVE_TALENT_GROUP_CHANGED (dual
    --! spec swap) and PLAYER_TALENT_UPDATE (learning/resetting talents);
    --! other players' dual-spec swaps are visible as a successful cast
    --! of a talent-activation spell (same trick as LibGroupTalents).
    frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    if IS_WRATH then
        -- 3.3.5: INSPECT_READY doesn't exist (added in 4.0); the WotLK
        -- equivalent is INSPECT_TALENT_READY (fires with no guid argument)
        frame:RegisterEvent("INSPECT_TALENT_READY")
    else
        frame:RegisterEvent("INSPECT_READY")
    end
    --! WotLK fix: Cell normalizes the native roster events and broadcasts one
    --! private callback; GROUP_ROSTER_UPDATE is not native on 3.3.5a.
    if _G.Cell and _G.Cell.RegisterCallback then
        _G.Cell.RegisterCallback(
            "GroupRosterUpdate",
            "LibGroupInfo_GroupRosterUpdate",
            function()
                frame:GroupRosterUpdate()
            end
        )
    end
    frame:RegisterEvent("UNIT_LEVEL")
    frame:RegisterEvent("UNIT_NAME_UPDATE")
    -- frame:RegisterEvent("UNIT_PHASE")
    -- frame:RegisterEvent("PARTY_MEMBER_ENABLE")
end

local inInstance
function frame:PLAYER_ENTERING_WORLD(isLogin, isReload)
    local isIn, iType = IsInInstance()

    local shouldUpdate

    if isIn then -- enter
        inInstance = true
        shouldUpdate = true
    elseif inInstance then -- leave
        inInstance = nil
        shouldUpdate = true
    elseif isLogin or isReload then -- login/reload
        shouldUpdate = true
    end

    --! WotLK fix: the isLogin/isReload payload was added in Legion (7.0).
    --! On 3.3.5 PLAYER_ENTERING_WORLD fires with NO arguments, so logging
    --! in while in the open world (not an instance) never set shouldUpdate
    --! and Query("player") never ran: the player's own specRole stayed nil
    --! and the role chain fell through to the DAMAGER default (solo 0/0/41
    --! resto shaman showed as DPS). Loading screens are rare on 3.3.5 -
    --! just always refresh.
    shouldUpdate = true

    if shouldUpdate then
        frame:Hide()
        wipe(lib.queue)
        wipe(lib.queueGUIDs)

        for _, t in pairs(cache) do
            t.inspected = nil
        end

        -- update self
        Query("player")

        -- update group
        frame:GroupRosterUpdate(true)
    end
end

---------------------------------------------------------------------
-- inspection queue
---------------------------------------------------------------------
local queue = {}
lib.queue = queue
local queueGUIDs = {}
lib.queueGUIDs = queueGUIDs

local elapsedTime = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    elapsedTime = elapsedTime + elapsed
    if elapsedTime >= 0.25 then
        elapsedTime = 0
        local guid = queue[1]
        if guid then
            if queueGUIDs[guid] then
                if queueGUIDs[guid].status == "waiting" then
                    queueGUIDs[guid].status = "requesting"
                    queueGUIDs[guid].attempts = queueGUIDs[guid].attempts + 1
                    queueGUIDs[guid].lastRequest = GetTime()
                    Print("|cffffff33LGI:INSPECT_REQUESTING|r", guid, queueGUIDs[guid].unit)
                    lib.callbacks:Fire(QUEUE_EVENT, guid, queueGUIDs[guid].unit, "INSPECT_REQUESTING")
                    NotifyInspect(queueGUIDs[guid].unit)
                elseif queueGUIDs[guid].status == "requesting" then -- give it another shot
                    if queueGUIDs[guid].attempts < MAX_ATTEMPTS then
                        if GetTime() - queueGUIDs[guid].lastRequest >= RETRY_INTERVAL then
                            queueGUIDs[guid].attempts = queueGUIDs[guid].attempts + 1
                            queueGUIDs[guid].lastRequest = GetTime()
                            Print("|cffffff33LGI:INSPECT_RETRYING|r", guid, queueGUIDs[guid].unit)
                            lib.callbacks:Fire(QUEUE_EVENT, guid, queueGUIDs[guid].unit, "INSPECT_RETRYING")
                            NotifyInspect(queueGUIDs[guid].unit)
                        end
                    else -- reach max attempts
                        Print("|cffffff33LGI:INSPECT_FAILED|r", guid, queueGUIDs[guid].unit)
                        lib.callbacks:Fire(QUEUE_EVENT, guid, queueGUIDs[guid].unit, "INSPECT_FAILED")
                        tremove(queue, 1)
                        queueGUIDs[guid] = nil
                    end
                end
            else -- INSPECT_READY
                tremove(queue, 1)
            end
        else -- none left
            frame:Hide()
            wipe(queue)
            wipe(queueGUIDs)
        end
    end
end)

local function AddToQueue(unit, guid)
    if IS_WRATH then
        if not UnitIsConnected(unit) or not CheckInteractDistance(unit, 1) or not CanInspect(unit) then
            UpdateBaseInfo(unit, guid)
            return
        end
    else
        if not UnitIsConnected(unit) or not CanInspect(unit) then
            UpdateBaseInfo(unit, guid)
            return
        end
    end

    Print("|cffffff33LGI:AddToQueue|r", guid, unit)
    lib.callbacks:Fire(QUEUE_EVENT, guid, unit, "INSPECT_WAITING")

    queueGUIDs[guid] = {
        ["unit"] = unit,
        ["attempts"] = 0,
        ["status"] = "waiting",
    }
    tinsert(queue, guid)

    if not InCombatLockdown() then
        frame:Show()
    end
end

---------------------------------------------------------------------
-- INSPECT_READY: ready to query
---------------------------------------------------------------------
function frame:INSPECT_READY(guid)
    if queueGUIDs[guid] then
        Print("|cffffff33LGI:INSPECT_READY|r", guid, queueGUIDs[guid].unit)
        lib.callbacks:Fire(QUEUE_EVENT, guid, queueGUIDs[guid].unit, "INSPECT_READY")
        --! WotLK fix: only dequeue the unit when valid talent data was
        --! actually cached. Query returns false when the inspect storage
        --! held stale/foreign talents (see BuildAndNotify_Wrath) - put the
        --! unit back into "waiting" so the queue re-requests it (attempts
        --! are still capped by MAX_ATTEMPTS).
        if Query(queueGUIDs[guid].unit) == false and queueGUIDs[guid].attempts < MAX_ATTEMPTS then
            queueGUIDs[guid].status = "waiting"
        else
            queueGUIDs[guid] = nil
        end
    end
end

-- 3.3.5: INSPECT_TALENT_READY carries no guid. The queue inspects strictly
-- one unit at a time (only queue[1] can be in "requesting" state), so the
-- head of the queue is the unit whose talents just arrived.
function frame:INSPECT_TALENT_READY()
    local guid = queue[1]
    if guid and queueGUIDs[guid] and queueGUIDs[guid].status == "requesting" then
        self:INSPECT_READY(guid)
    end
end

---------------------------------------------------------------------
--! WotLK fix: private GroupRosterUpdate callback updates the queue
---------------------------------------------------------------------
--! WotLK fix: members outside inspect range need periodic retries while
--! grouped, but the old login-owned ticker stayed alive forever in solo and
--! kept Cell.C_Timer's driver shown. Own it by the actual group lifecycle.
local function StopRescanTicker()
    if lib.rescanTicker then
        lib.rescanTicker:Cancel()
        lib.rescanTicker = nil
    end
end

local function StartRescanTicker()
    if lib.rescanTicker then return end

    lib.rescanTicker = C_Timer.NewTicker(15, function()
        if not IsInGroup() then
            StopRescanTicker()
        elseif PLAYER_GUID then
            frame:GroupRosterUpdate(true)
        end
    end)
    --! WotLK fix: identify the expected group-owned ticker in diagnostics even
    --! when this client exposes no Lua debug library.
    if lib.rescanTicker.SetDebugLabel then
        lib.rescanTicker:SetDebugLabel("LibGroupInfo: grouped roster rescan (15s)")
    end
end

local wasInGroup
local function IterateAllUnits()
    cache[PLAYER_GUID].unit = "player"

    local currentMembers = {[PLAYER_GUID] = true}
    if IsInGroup() then
        StartRescanTicker()
    else
        StopRescanTicker()
    end

    if IsInRaid() then
        wasInGroup = true
        for i = 1, GetNumGroupMembers() do
            local unit = "raid"..i
            local guid = UnitGUID(unit)
            --! WotLK soloq fix: sparse/unavailable raid slots return a nil GUID
            --! (solo-queue arena raid groups), which crashed currentMembers[guid]
            --! with "table index is nil". Skip slots without a resolvable GUID.
            if guid then
                currentMembers[guid] = true
                if not (UnitIsUnit(unit, "player") or (cache[guid] and cache[guid].inspected) or queueGUIDs[guid]) then
                    AddToQueue(unit, guid)
                end
            end
        end
        local pRaidIndex = UnitInRaid("player")
        --! WotLK fix: UnitInRaid is 0-based on 3.3.5 (raid1 -> 0), so the token
        --! needs +1. Without it the first raid slot cached a non-existent "raid0"
        --! and everyone else got the previous player's unit token.
        if pRaidIndex then cache[PLAYER_GUID].unit = "raid"..(pRaidIndex + 1) end

    elseif IsInGroup() then
        wasInGroup = true
        for i = 1, GetNumGroupMembers()-1 do
            local unit = "party"..i
            local guid = UnitGUID(unit)
            if guid then
                currentMembers[guid] = true
                if not ((cache[guid] and cache[guid].inspected) or queueGUIDs[guid]) then
                    AddToQueue(unit, guid)
                end
            end
        end

    elseif wasInGroup then
        wasInGroup = nil
        for guid in pairs(cache) do
            if guid ~= PLAYER_GUID then
                cache[guid] = nil
            end
        end
        frame:Hide()
        wipe(queueGUIDs)
        wipe(queue)
    end

    -- remove not in group
    if wasInGroup then
        for guid in pairs(cache) do
            if not currentMembers[guid] then
                cache[guid] = nil
                queueGUIDs[guid] = nil
            end
        end
    end
end

local timer
function frame:GroupRosterUpdate(immediate)
    if timer then timer:Cancel() end

    if immediate then
        IterateAllUnits()
    else
        timer = C_Timer.NewTimer(1, IterateAllUnits)
    end
end

local forceUpdateAvailable = true
function lib:ForceUpdate()
    if not forceUpdateAvailable then return end

    forceUpdateAvailable = false
    C_Timer.After(10, function()
        forceUpdateAvailable = true
    end)

    frame:PLAYER_ENTERING_WORLD(true)
end

---------------------------------------------------------------------
-- other events: update
---------------------------------------------------------------------
function frame:PLAYER_SPECIALIZATION_CHANGED(unit)
    if not UnitIsPlayer(unit) then return end
    if strfind(unit, "target") or strfind(unit, "nameplate") then return end

    if UnitIsUnit(unit, "player") then
        Query(unit)
    else
        local guid = UnitGUID(unit)
        if cache[guid] then
            cache[guid].inspected = nil
        end
        if queueGUIDs[guid] then
            queueGUIDs[guid].attempts = 0 -- reset attempts if exists in queue
        else
            AddToQueue(unit, guid)
        end
    end
end

function frame:UNIT_NAME_UPDATE(unit)
    frame:PLAYER_SPECIALIZATION_CHANGED(unit)
end

--! WotLK fix: 3.3.5 equivalents of PLAYER_SPECIALIZATION_CHANGED (see
--! PLAYER_LOGIN). Both may fire on a dual-spec swap - Query is cheap and
--! idempotent, the duplicate just refires the update callback.
function frame:ACTIVE_TALENT_GROUP_CHANGED()
    Query("player")
end

function frame:PLAYER_TALENT_UPDATE()
    Query("player")
end

-- Other players' dual-spec swaps: a successful cast of a talent-activation
-- spell (TALENT_ACTIVATION_SPELLS = 63645 primary / 63644 secondary, same
-- detection LibGroupTalents uses). Invalidate and re-inspect that unit.
local specChangeSpells = {}
do
    local activationSpells = _G.TALENT_ACTIVATION_SPELLS or {63645, 63644}
    for _, spellId in ipairs(activationSpells) do
        local spellName = GetSpellInfo(spellId)
        if spellName then
            specChangeSpells[spellName] = true
        end
    end
end

function frame:UNIT_SPELLCAST_SUCCEEDED(unit, spellName)
    if not spellName or not specChangeSpells[spellName] then return end
    if UnitIsUnit(unit, "player") then return end -- covered by ACTIVE_TALENT_GROUP_CHANGED
    if not (strfind(unit, "^party%d") or strfind(unit, "^raid%d")) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    if cache[guid] then
        cache[guid].inspected = nil
    end
    if queueGUIDs[guid] then
        queueGUIDs[guid].attempts = 0 -- reset attempts if already queued
    else
        AddToQueue(unit, guid)
    end
end

-- function frame:UNIT_PHASE(unit)
--     frame:PLAYER_SPECIALIZATION_CHANGED(unit)
-- end

-- function frame:PARTY_MEMBER_ENABLE(unit)
--     frame:PLAYER_SPECIALIZATION_CHANGED(unit)
-- end

function frame:UNIT_LEVEL(unit)
    local guid = UnitGUID(unit)
    if cache[guid] then
        cache[guid].level = UnitLevel(unit)
    end
end

-- local lastUpdate = {}
-- function frame:UNIT_AURA(unit)
--     print(unit)
--     if InCombatLockdown() then return end
--     if not (strfind(unit, "^party") or strfind(unit, "^raid")) then return end
--     if not UnitIsPlayer(unit) then return end

--     local guid = UnitGUID(unit)
--     if not lastUpdate[guid] or GetTime() - lastUpdate[guid] > 600 then
--         lastUpdate[guid] = GetTime()
--         AddToQueue(unit, guid)
--     end
-- end

---------------------------------------------------------------------
-- combat check
---------------------------------------------------------------------
function frame:PLAYER_REGEN_ENABLED()
    if #queue ~= 0 then
        frame:Show()
    end
end

function frame:PLAYER_REGEN_DISABLED()
    frame:Hide()
end
