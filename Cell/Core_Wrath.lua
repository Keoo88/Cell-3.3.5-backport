---@class Cell
local Cell = select(2, ...)
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
_G.Cell = Cell

--! WotLK fix: this backport targets Interface 30300 whatever retail-style project
--! constants a custom core exposes. Keep the decision private to Cell: rewriting
--! WOW_PROJECT_ID or the Blizzard expansion constants changes code paths in every
--! foreign addon.
Cell.flavor = "wrath"
Cell.isRetail = false
Cell.isWrath = true
Cell.isVanilla = false
Cell.isCata = false
Cell.isMists = false
Cell.isTWW = false

---@class Cell
---@field defaults table
---@field frames table
---@field vars table
---@field snippetVars table
---@field funcs CellFuncs
---@field iFuncs CellIndicatorFuncs
---@field bFuncs CellUnitButtonFuncs
---@field uFuncs CellUtilityFuncs
---@field animations CellAnimations

Cell.defaults = {}
Cell.frames = {}
Cell.vars = {}
Cell.snippetVars = {}
Cell.funcs = {}
Cell.iFuncs = {}
Cell.bFuncs = {}
Cell.uFuncs = {}
Cell.animations = {}

local F = Cell.funcs
local I = Cell.iFuncs
local P = Cell.pixelPerfectFuncs
local L = Cell.L

-- sharing version check
--! WotLK fix: these floors used to equal this build's own version (277), which made
--! the accepted window exactly one version wide, so every import string exported by
--! any other Cell build (e.g. anything from wago.io) was rejected as "Incompatible
--! Version". The floor is now the last schema-changing revision in Revise.lua (269).
--! Anything older than that relies on Revise.lua migrations, and those only ever run
--! against the local saved DB - never against imported data - so importing an older
--! payload would inject an outdated shape and error out later at runtime.
--! WotLK fix: MIN_VERSION is ALSO the "unsupported saved DB" floor (Revise.lua:17/:32),
--! so raising it to 269 made every local DB at revise 246..268 offer a full settings reset
--! instead of migrating - Revise.lua:3317/3322/3335/3374/3391/3400 became unreachable.
--! The DB floor is back to upstream's 246; the import floor keeps 269 as MIN_IMPORT_VERSION.
Cell.MIN_VERSION = 246          -- unsupported-DB floor, used by Revise.lua
Cell.MIN_IMPORT_VERSION = 269   -- floor for accepted import strings
Cell.MIN_CLICKCASTINGS_VERSION = 269
Cell.MIN_LAYOUTS_VERSION = 269
Cell.MIN_INDICATORS_VERSION = 269
Cell.MIN_DEBUFFS_VERSION = 269

--[==[@debug@
--@end-debug@]==]
--! WotLK fix: было `-- local debugMode = true` - объявление закомментировано, а чтение
--! на следующих строках осталось, то есть F.Debug читала ГЛОБАЛ _G.debugMode. Cell не
--! владеет глобалами (CLAUDE.md §3) и тем более не должен верить, что прочитанное имя -
--! его собственное: любой аддон с `debugMode = true` (имя настолько общее, что это лишь
--! вопрос времени) включил бы игроку спам отладки Cell в чат. Локал объявлен явно и
--! выключен; чтобы включить отладку, достаточно поменять false на true. В апстриме тут
--! настоящий локал (Cell-retail/Core_Wrath.lua:39).
local debugMode = false
function F.Debug(arg, ...)
    if debugMode then
        if type(arg) == "string" or type(arg) == "number" then
            print(arg, ...)
        elseif type(arg) == "table" then
            DevTools_Dump(arg)
        elseif type(arg) == "function" then
            arg(...)
        elseif arg == nil then
            return true
        end
    end
end

function F.Print(msg)
    print("|cFFFF3030[Cell]|r " .. msg)
end

--------------------------------------------------
-- CellParent
--------------------------------------------------
local CellParent = CreateFrame("Frame", "CellParent", UIParent)
CellParent:SetAllPoints(UIParent)
CellParent:SetFrameLevel(0)

-------------------------------------------------
-- layout
-------------------------------------------------
local delayedLayoutGroupType
--! WotLK fix: generation counter for the 50 ms window between PLAYER_REGEN_ENABLED
--! and the timer below. The slot was never cleared when consumed, so a fresh
--! F.UpdateLayout arriving out of combat inside that window ran immediately and was
--! then overwritten by the deferred replay of the stale group type. Latch a copy,
--! clear the slot, and compare generations before replaying. ElvUI clears its own
--! deferred slot the same way (ActionBars.lua:305-307).
local layoutGeneration = 0
local delayedFrame = CreateFrame("Frame")
delayedFrame:SetScript("OnEvent", function()
    delayedFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    --! Freeze fix: leaving combat is when every deferred job wakes up at once - the
    --! layout rebuild here, role sorting in RaidFrame/PartyFrame, the buff tracker,
    --! marks and any pending button updates - so the end of a boss fight lands them
    --! all in one frame. This one is the heaviest (it broadcasts UpdateLayout,
    --! UpdateIndicators, UpdateAppearance, UpdateRaidDebuffs and more), so move it off
    --! that frame. The two sort jobs already debounce themselves by 0.2s.
    local groupType = delayedLayoutGroupType
    local generation = layoutGeneration
    delayedLayoutGroupType = nil
    C_Timer.After(0.05, function()
        --! WotLK fix: nil guard - F.UpdateLayout(nil) would index the layout table
        --! with a nil key and leave Cell.vars.currentLayoutTable nil.
        if groupType and generation == layoutGeneration then
            F.UpdateLayout(groupType)
        end
    end)
end)

--! WotLK fix: resolves which auto-switch table is in force, same rule retail uses
--! (Cell-retail/Core.lua:87-92): if a per-talent-group table exists, that wins; otherwise
--! fall back to the shared per-role table. Presence IS the mode flag - no separate boolean
--! to keep in sync with the data, and no migration, because every existing character
--! already has both talent-group tables and therefore stays in Spec mode exactly as before.
--! The Role|Spec switch in the Layouts pane creates or deletes
--! CellCharacterDB["layoutAutoSwitch"][activeTalentGroup] to flip the mode.
--! The role table lives in CellDB (account-wide, so one Healer profile serves every healer
--! the player has); the spec tables stay in CellCharacterDB, where they were. Name is
--! "layoutAutoSwitchRole" and not "layoutAutoSwitch": the latter is already taken -
--! ImportExport.lua:130 reads imported["layoutAutoSwitch"] as the retail account-level key
--! and writes it into CellCharacterDB at :182.
--! Separate from F.UpdateLayout on purpose: that one refuses to do anything in combat, but
--! this touches nothing protected - only table references and two strings - so the Layouts
--! pane can flip the mode mid-combat and still show the right table. The frames themselves
--! are rebuilt later, by the deferred UpdateLayout.
function F.UpdateLayoutAutoSwitchVars()
    local switchTable = CellCharacterDB["layoutAutoSwitch"][Cell.vars.activeTalentGroup]
    if switchTable then
        Cell.vars.layoutAutoSwitchBy = "spec"
    else
        Cell.vars.layoutAutoSwitchBy = "role"
        --! WotLK fix: playerTalentRole can still be unknown here - the talent tree is
        --! unreadable for the first second after login (see CheckDivineAegis below).
        --! DAMAGER is the fallback, and UpdateTalentRole re-keys as soon as the tree
        --! answers, so the wrong profile can only be on screen for that first second
        --! of the very first login on a character; afterwards the cached role in
        --! CellCharacterDB["talentRoles"] makes even that correct.
        switchTable = CellDB["layoutAutoSwitchRole"][Cell.vars.playerTalentRole or "DAMAGER"]
    end
    Cell.vars.layoutAutoSwitch = switchTable
end

function F.UpdateLayout(layoutGroupType)
    if InCombatLockdown() then
        delayedLayoutGroupType = layoutGroupType
        delayedFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        --! WotLK fix: bump the generation so a deferred replay scheduled before this
        --! call knows it is stale and skips itself.
        layoutGeneration = layoutGeneration + 1

        F.UpdateLayoutAutoSwitchVars()

        local layout = Cell.vars.layoutAutoSwitch[layoutGroupType]
        Cell.vars.layoutGroupType = layoutGroupType

        if layout == "hide" then
            Cell.vars.isHidden = true
            Cell.vars.currentLayout = "default"
            Cell.vars.currentLayoutTable = CellDB["layouts"]["default"]
        else
            Cell.vars.isHidden = false
            Cell.vars.currentLayout = layout
            Cell.vars.currentLayoutTable = CellDB["layouts"][layout]
        end

        --! WotLK fix: removed the leftover force-disable of combineGroups here. Commit
        --! 4c4cb05 restored the Combine Groups option in the Layouts UI and removed the
        --! same force-disable from LoadLayoutDB, but missed this one - it silently reset
        --! combineGroups=false in the ACTIVE layout on every login/group change, so the
        --! option kept turning itself off.

        F.IterateAllUnitButtons(function(b)
            b._indicatorsReady = nil
        end, true)

        Cell.Fire("UpdateLayout", layout)
        Cell.Fire("UpdateIndicators")
    end
end

-- layout auto switch
local instanceType

--! WotLK fix: build 12340 has neither GetInstanceInfo's later map ID nor the
--! extended GetBattlegroundInfo tuple, and the maxPlayers it does return is not
--! trustworthy inside a battleground -- ElvUI 6.09 on this same client overrides
--! it the same way (Modules/UnitFrames/Groups/Raid.lua:74-79). The previous call
--! here went to the global C_GetInstanceInfo() from Libs/ClassicAPI/Util/API.lua,
--! a file that is no longer loaded, so it was a nil call on every battleground
--! entry. The capacity is derived privately instead, and never from a shared
--! global: Cell does not own C_GetInstanceInfo and must not read it as its own.
--!
--! Key is the GetMapInfo() map file name -- a texture folder name, identical in
--! every locale, unlike GetRealZoneText/GetBattlefieldStatus which return
--! localized strings. It needs the world map to point at the current zone;
--! FrameXML does that itself (WatchFrame.lua:237 calls SetMapToCurrentZone on
--! PLAYER_ENTERING_WORLD), and Cell must not call SetMapToCurrentZone on its own
--! because that mutates global map state other addons read.
--! Two fallbacks cover the case where the player has the map open elsewhere:
--! a raid of more than 15 can only be a 40-man battleground, and below that the
--! native maxPlayers is still better than nothing. Cell only needs "40-man or
--! not" here, so an unknown map degrades to battleground15, not to an error.
local BATTLEGROUND_SIZE = {
    AlteracValley = 40,
    IsleofConquest = 40,
    LakeWintergrasp = 40,
    WarsongGulch = 10,
    ArathiBasin = 15,
    NetherstormArena = 15, -- Eye of the Storm
    StrandoftheAncients = 15,
}

local function GetBattlegroundSize()
    local map = GetMapInfo()
    local size = map and BATTLEGROUND_SIZE[map]
    if size then return size end

    if GetNumRaidMembers() > 15 then return 40 end

    local _, _, _, _, maxPlayers = GetInstanceInfo()
    return maxPlayers
end

local function PreUpdateLayout()
    if instanceType == "pvp" then
        local size = GetBattlegroundSize()
        if size and size > 15 then
            Cell.vars.inBattleground = 40
            F.UpdateLayout("battleground40", true)
        else
            Cell.vars.inBattleground = 15
            F.UpdateLayout("battleground15", true)
        end
    elseif instanceType == "arena" then
        Cell.vars.inBattleground = 5 -- treat as bg 5
        F.UpdateLayout("arena", true)
    else
        Cell.vars.inBattleground = false
        if Cell.vars.groupType == "solo" then

            F.UpdateLayout("solo", true)
        elseif Cell.vars.groupType == "party" then
            F.UpdateLayout("party", true)
        else -- raid
            if Cell.vars.raidType then
                F.UpdateLayout(Cell.vars.raidType, true)
            else
                F.UpdateLayout("raid_outdoor", true)
            end
        end
    end
end
Cell.RegisterCallback("GroupTypeChanged", "Core_GroupTypeChanged", PreUpdateLayout)
Cell.RegisterCallback("ActiveTalentGroupChanged", "Core_ActiveTalentGroupChanged", PreUpdateLayout)

-------------------------------------------------
-- group
-------------------------------------------------
--! WotLK fix: modern group helpers do not exist in stock 3.3.5a. Keep Cell's
--! contract private and derive it only from verified native roster APIs.
do
    function Cell.IsInRaid()
        return GetNumRaidMembers() > 0
    end

    function Cell.IsInGroup()
        return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
    end

    function Cell.GetNumGroupMembers()
        local raidMembers = GetNumRaidMembers()
        if raidMembers > 0 then
            return raidMembers
        end
        local partyMembers = GetNumPartyMembers()
        return partyMembers > 0 and partyMembers + 1 or 0
    end

    --! WotLK perf: both questions have one-value natives on 3.3.5a, so ask them
    --! directly instead of GetRaidRosterInfo, which returns eleven values including
    --! five fresh strings just to read the rank. UnitButton_UpdateLeader calls these
    --! once per button on every roster change - a 25-man threw away 100+ strings per
    --! event on Lua 5.1 without a JIT.
    --! Shape from the two implementations known to work here: Blizzard's
    --! TargetFrame.lua pairs UnitIsPartyLeader with UnitInRaid (proof that "party"
    --! covers raids), and oUF under ElvUI 6.09 writes assistant as
    --! `UnitIsRaidOfficer(unit) and not UnitIsPartyLeader(unit)`. That second half
    --! keeps the states mutually exclusive: on 3.3.5a the raid leader also answers
    --! yes to UnitIsRaidOfficer. The group guard stops a solo player from being
    --! called leader. Both natives are 1/nil; normalised because states.isLeader is
    --! stored and read back elsewhere.
    local UnitIsPartyLeader = UnitIsPartyLeader
    local UnitIsRaidOfficer = UnitIsRaidOfficer

    function Cell.UnitIsGroupLeader(unit)
        return (Cell.IsInGroup() and UnitIsPartyLeader(unit)) and true or false
    end

    function Cell.UnitIsGroupAssistant(unit)
        return (UnitIsRaidOfficer(unit) and not UnitIsPartyLeader(unit)) and true or false
    end

    local everyoneAssistant, assistantTicker
    function Cell.SetEveryoneIsAssistant(enable)
        local numMembers = GetNumRaidMembers()
        if numMembers <= 0 then return end

        if assistantTicker then
            assistantTicker:Cancel()
            assistantTicker = nil
        end

        everyoneAssistant = not not enable
        assistantTicker = C_Timer.NewTicker(0.2, function(ticker)
            local unit = "raid"..ticker.Index
            if not UnitIsUnit(unit, "player") then
                local _, rank = GetRaidRosterInfo(ticker.Index)
                if everyoneAssistant and rank == 0 then
                    PromoteToAssistant(unit)
                elseif not everyoneAssistant and rank == 1 then
                    DemoteAssistant(unit)
                end
            end
            ticker.Index = ticker.Index + 1
        end, numMembers)
        assistantTicker.Index = 1
    end

    function Cell.IsEveryoneAssistant()
        return everyoneAssistant
    end
end

-------------------------------------------------
-- events
-------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

function eventFrame:VARIABLES_LOADED()
    SetCVar("predictedHealth", 1)
end

--! WotLK fix: consume Cell-private group adapters; do not depend on shared compatibility globals.
local IsInRaid = Cell.IsInRaid
local IsInGroup = Cell.IsInGroup
local GetNumGroupMembers = Cell.GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitGUID = UnitGUID
-- local IsInBattleGround = C_PvP.IsBattleground -- NOTE: can't get valid value immediately after PLAYER_ENTERING_WORLD
--! WotLK fix: C_AddOns is a shim whose GetAddOnMetadata is a bare alias of the
--! native function (Libs/ClassicAPI/Util/C_AddOns.lua:72)
local GetAddOnMetadata = GetAddOnMetadata

-- local cellLoaded, omnicdLoaded
function eventFrame:ADDON_LOADED(arg1)
    if arg1 == "Cell" then
        -- cellLoaded = true
        eventFrame:UnregisterEvent("ADDON_LOADED")

        if type(CellDB) ~= "table" then CellDB = {} end
        if type(CellCharacterDB) ~= "table" then CellCharacterDB = {} end
        if type(CellDBBackup) ~= "table" then CellDBBackup = {} end

        if type(CellDB["optionsFramePosition"]) ~= "table" then CellDB["optionsFramePosition"] = {} end

        if type(CellDB["indicatorPreview"]) ~= "table" then
            CellDB["indicatorPreview"] = {
                ["scale"] = 2,
                ["showAll"] = false,
            }
        end

        if type(CellDB["customTextures"]) ~= "table" then CellDB["customTextures"] = {} end

        if type(CellDB["snippets"]) ~= "table" then CellDB["snippets"] = {} end
        if not CellDB["snippets"][0] then CellDB["snippets"][0] = F.GetDefaultSnippet() end

        -- general --------------------------------------------------------------------------------
        if type(CellDB["general"]) ~= "table" then
            CellDB["general"] = {
                ["enableTooltips"] = false,
                ["hideTooltipsInCombat"] = true,
                ["tooltipsPosition"] = {"BOTTOMLEFT", "Default", "TOPLEFT", 0, 15},
                ["hideBlizzardParty"] = true,
                ["hideBlizzardRaid"] = true,
                ["hideBlizzardRaidManager"] = true,
                ["locked"] = false,
                ["fadeOut"] = false,
                ["menuPosition"] = "top_bottom",
                ["alwaysUpdateAuras"] = false,
                ["framePriority"] = {
                    {"Main", true},
                    {"Spotlight", false},
                    {"Quick Assist", false},
                },
                ["useCleuHealthUpdater"] = false,
                ["translit"] = false,
            }
        end
    
    -- Load user-selected locale (delayed until CellDB is available)
    if Cell.LoadUserLocale then
        Cell.LoadUserLocale()
    end
        -- Initialize locale setting if missing (for backward compatibility)
        if CellDB["general"]["locale"] == nil then
            CellDB["general"]["locale"] = nil -- nil means "Auto (Client)"
        end

        -- nicknames ------------------------------------------------------------------------------
        if type(CellDB["nicknames"]) ~= "table" then
            CellDB["nicknames"] = {
                ["mine"] = "",
                ["sync"] = false,
                ["custom"] = false,
                ["list"] = {},
                ["blacklist"] = {},
            }
        end

        -- tools ----------------------------------------------------------------------------------
        if type(CellDB["tools"]) ~= "table" then
            CellDB["tools"] = {
                --! WotLK fix: ключа battleResTimer больше нет - галки "Battle Res Timer"
                --! и "Detached" убраны из Рейдовых инструментов 2026-08-19, читать его
                --! стало некому (см. Cell/Utilities/RaidTools.lua).
                --! WotLK fix: шестой элемент - подсветка иконки, когда баффа нет на самом
                --! игроке. Раньше глоу был вшит наглухо; для существующих баз ключ
                --! добирает Revise (ищи buffTracker[6]).
                --! WotLK feature: седьмой элемент - следить только за бафами своего класса
                --! (по образцу VuhDo). Для существующих баз тоже добирает Revise.
                --! WotLK feature: eighth element - "hide in combat" (off by default, so
                --! an update changes nothing silently). See UpdateHideInCombat in
                --! Utilities/BuffTracker_Classic.lua; Revise back-fills existing DBs.
                ["buffTracker"] = {false, "left-to-right", 27, {}, {}, true, true, false},
                ["deathReport"] = {false, 10},
                ["readyAndPull"] = {false, "text_button", {"default", 7}, {}},
                ["marks"] = {false, false, "target_h", {}},
                ["fadeOut"] = false,
            }
        end

        -- spellRequest ---------------------------------------------------------------------------
        if type(CellDB["spellRequest"]) ~= "table" then
            local POWER_INFUSION, POWER_INFUSION_ICON = F.GetSpellInfo(10060)
            local INNERVATE, INNERVATE_ICON = F.GetSpellInfo(29166)

            CellDB["spellRequest"] = {
                ["enabled"] = false,
                ["checkIfExists"] = true,
                ["knownSpellsOnly"] = true,
                ["freeCooldownOnly"] = true,
                ["replyCooldown"] = true,
                ["responseType"] = "me",
                ["timeout"] = 10,
                -- ["replyAfterCast"] = nil,
                ["sharedIconOptions"] = {
                    "beat", -- [1] animation
                    27, -- [2] size
                    "BOTTOMRIGHT", -- [3] anchor
                    "BOTTOMRIGHT", -- [4] anchorTo
                    0, -- [5] x
                    0, -- [6] y
                },
                ["spells"] = {
                    {
                        ["spellId"] = 10060,
                        ["buffId"] = 10060,
                        ["keywords"] = POWER_INFUSION,
                        ["icon"] = POWER_INFUSION_ICON,
                        ["type"] = "icon",
                        ["iconColor"] = {1, 1, 0, 1},
                        ["glowOptions"] = {
                            "pixel", -- [1] glow type
                            {
                                {1,1,0,1}, -- [1] color
                                0, -- [2] x
                                0, -- [3] y
                                9, -- [4] N
                                0.25, -- [5] frequency
                                8, -- [6] length
                                2 -- [7] thickness
                            } -- [2] glowOptions
                        },
                        ["isBuiltIn"] = true
                    },
                    {
                        ["spellId"] = 29166,
                        ["buffId"] = 29166,
                        ["keywords"] = INNERVATE,
                        ["icon"] = INNERVATE_ICON,
                        ["type"] = "icon",
                        ["iconColor"] = {0, 1, 1, 1},
                        ["glowOptions"] = {
                            "pixel", -- [1] glow type
                            {
                                {0, 1, 1, 1}, -- [1] color
                                0, -- [2] x
                                0, -- [3] y
                                9, -- [4] N
                                0.25, -- [5] frequency
                                8, -- [6] length
                                2 -- [7] thickness
                            } -- [2] glowOptions
                        },
                        ["isBuiltIn"] = true
                    },
                },
            }
        end

        -- dispelRequest --------------------------------------------------------------------------
        if type(CellDB["dispelRequest"]) ~= "table" then
            CellDB["dispelRequest"] = {
                ["enabled"] = false,
                ["dispellableByMe"] = true,
                ["responseType"] = "all",
                ["timeout"] = 10,
                ["debuffs"] = {},
                ["type"] = "text",
                ["textOptions"] = {
                    "A",
                    {1, 1, 1, 1}, -- [1] color
                    32, -- [2] size
                    "TOPLEFT", -- [3] anchor
                    "TOPLEFT", -- [4] anchorTo
                    -1, -- [5] x
                    5, -- [6] y
                },
                ["glowOptions"] = {
                    "shine", -- [1] glow type
                    {
                        {1, 0, 0.4, 1}, -- [1] color
                        0, -- [2] x
                        0, -- [3] y
                        9, -- [4] N
                        0.5, -- [5] frequency
                        2, -- [6] scale
                    } -- [2] glowOptions
                }
            }
        end

        -- appearance -----------------------------------------------------------------------------
        if type(CellDB["appearance"]) ~= "table" then
            CellDB["appearance"] = F.Copy(Cell.defaults.appearance)
        end

        -- color ---------------------------------------------------------------------------------
        if CellDB["appearance"]["accentColor"] then -- version < r103
            if CellDB["appearance"]["accentColor"][1] == "custom" then
                Cell.OverrideAccentColor(CellDB["appearance"]["accentColor"][2])
            end
        end

        -- click-casting --------------------------------------------------------------------------
        local _, classFile, classID = UnitClass("player")
        Cell.vars.playerClass = classFile
        -- NOTE: on 3.3.5a UnitClass may not return classID (3rd return added in 4.0), derive from classFile
        Cell.vars.playerClassID = classID or F.GetClassID(classFile)

        if type(CellCharacterDB["clickCastings"]) ~= "table" then
            CellCharacterDB["clickCastings"] = {
                ["class"] = Cell.vars.playerClass, -- NOTE: validate on import
                ["useCommon"] = true,
                ["smartResurrection"] = "disabled",
                ["alwaysTargeting"] = {
                    ["common"] = "disabled",
                    [1] = "disabled",
                    [2] = "disabled",
                },
                ["common"] = {
                    {"type1", "target"},
                    {"type2", "togglemenu"},
                },
                [1] = {
                    {"type1", "target"},
                    {"type2", "togglemenu"},
                },
                [2] = {
                    {"type1", "target"},
                    {"type2", "togglemenu"},
                },
            }

            -- add resurrections
            for _, t in pairs(F.GetResurrectionClickCastings(Cell.vars.playerClass)) do
                tinsert(CellCharacterDB["clickCastings"]["common"], t)
                for i = 1, 2 do
                    tinsert(CellCharacterDB["clickCastings"][i], t)
                end
            end
        end
        Cell.vars.clickCastings = CellCharacterDB["clickCastings"]

        -- layouts --------------------------------------------------------------------------------
        if type(CellDB["layouts"]) ~= "table" then
            CellDB["layouts"] = {
                ["default"] = F.Copy(Cell.defaults.layout)
            }
        end

        -- layoutAutoSwitch -----------------------------------------------------------------------
        if type(CellCharacterDB["layoutAutoSwitch"]) ~= "table" then
            CellCharacterDB["layoutAutoSwitch"] = {
                [1] = F.Copy(Cell.defaults.layoutAutoSwitch),
                [2] = F.Copy(Cell.defaults.layoutAutoSwitch),
            }
        end

        --! WotLK fix: the per-role half of Layout Auto Switch, account-wide on purpose -
        --! a player with three healers wants one Healer profile, not three copies. The
        --! per-spec half above stays per-character. Both tables always exist; which one is
        --! in force is decided by F.UpdateLayout (see the comment there).
        if type(CellDB["layoutAutoSwitchRole"]) ~= "table" then
            CellDB["layoutAutoSwitchRole"] = {}
        end
        for _, role in pairs({"TANK", "HEALER", "DAMAGER"}) do
            if type(CellDB["layoutAutoSwitchRole"][role]) ~= "table" then
                CellDB["layoutAutoSwitchRole"][role] = F.Copy(Cell.defaults.layoutAutoSwitch)
            end
        end

        --! WotLK fix: remember the role of each talent group. There is no GetSpecialization
        --! and no GetPrimaryTalentTree on build 12340 (both verified absent from the codex),
        --! so the role has to be read off the talent trees - and those are unreadable for
        --! about a second after login. Without this cache the first layout of every login
        --! would be built under the fallback role and then rebuilt, which is a visible
        --! flicker; with it, only the very first login on a character can be wrong.
        if type(CellCharacterDB["talentRoles"]) ~= "table" then
            CellCharacterDB["talentRoles"] = {}
        end

        -- dispelBlacklist ------------------------------------------------------------------------
        if type(CellDB["dispelBlacklist"]) ~= "table" then
            CellDB["dispelBlacklist"] = I.GetDefaultDispelBlacklist()
        end
        Cell.vars.dispelBlacklist = F.ConvertTable(CellDB["dispelBlacklist"])

        -- debuffBlacklist ------------------------------------------------------------------------
        if type(CellDB["debuffBlacklist"]) ~= "table" then
            CellDB["debuffBlacklist"] = I.GetDefaultDebuffBlacklist()
        end
        Cell.vars.debuffBlacklist = F.ConvertTable(CellDB["debuffBlacklist"])

        -- bigDebuffs -----------------------------------------------------------------------------
        if type(CellDB["bigDebuffs"]) ~= "table" then
            CellDB["bigDebuffs"] = I.GetDefaultBigDebuffs()
        end
        Cell.vars.bigDebuffs = F.ConvertTable(CellDB["bigDebuffs"])
        Cell.vars.bigDebuffNames = F.GetSpellNames(CellDB["bigDebuffs"])

        -- debuffTypeColor ------------------------------------------------------------------------
        if type(CellDB["debuffTypeColor"]) ~= "table" then
            I.ResetDebuffTypeColor()
        end

        -- aoeHealings ----------------------------------------------------------------------------
        if type(CellDB["aoeHealings"]) ~= "table" then CellDB["aoeHealings"] = {["disabled"]={}, ["custom"]={}} end

        -- defensives/externals -------------------------------------------------------------------
        if type(CellDB["defensives"]) ~= "table" then CellDB["defensives"] = {["disabled"]={}, ["custom"]={}} end
        if type(CellDB["externals"]) ~= "table" then CellDB["externals"] = {["disabled"]={}, ["custom"]={}} end

        -- crowdControls --------------------------------------------------------------------------
        if type(CellDB["crowdControls"]) ~= "table" then CellDB["crowdControls"] = {["disabled"]={}, ["custom"]={}} end

        -- raid debuffs ---------------------------------------------------------------------------
        if type(CellDB["raidDebuffs"]) ~= "table" then CellDB["raidDebuffs"] = {} end
        -- CellDB["raidDebuffs"] = {
        --     [instanceId] = {
        --         ["general"] = {
        --             [spellId] = {order, glowType, glowColor},
        --         },
        --         [bossId] = {
        --             [spellId] = {order, glowType, glowColor},
        --         },
        --     }
        -- }

        -- targetedSpells -------------------------------------------------------------------------
        if type(CellDB["targetedSpellsList"]) ~= "table" then
            CellDB["targetedSpellsList"] = I.GetDefaultTargetedSpellsList()
        end
        Cell.vars.targetedSpellsList = F.ConvertTable(CellDB["targetedSpellsList"])

        if type(CellDB["targetedSpellsGlow"]) ~= "table" then
            CellDB["targetedSpellsGlow"] = I.GetDefaultTargetedSpellsGlow()
        end
        Cell.vars.targetedSpellsGlow = CellDB["targetedSpellsGlow"]

        -- actions --------------------------------------------------------------------------------
        if type(CellDB["actions"]) ~= "table" then
            CellDB["actions"] = I.GetDefaultActions()
        end
        Cell.vars.actions = I.ConvertActions(CellDB["actions"])

        -- misc -----------------------------------------------------------------------------------
        -- NOTE: "## Version:" in Cell.toc is frozen at "r277-release" on purpose and is never
        -- bumped on this backport. It is parsed with "%d+" right below and stored into
        -- CellDB["revise"] (Revise.lua), so dbRevision is always 277: a new migration guarded by
        -- "dbRevision < 278" would therefore fire on EVERY login. Repair saved data in place
        -- instead (see RepairAgainstDefaults in Revise.lua), not through a revision threshold.
        -- If the version ever does change, keep the "rNNN" shape -- "1.0" parses to 1, which is
        -- below MIN_VERSION and pops the settings-reset dialog for every existing user.
        Cell.version = GetAddOnMetadata("Cell", "version")
        Cell.versionNum = tonumber(string.match(Cell.version, "%d+"))
        if not CellDB["revise"] then CellDB["firstRun"] = true end
        F.Revise()
        --! WotLK fix: здесь писался CellDB["changelogsViewed"] = Cell.version - ключ,
        --! который в сборке никто не читает: окна «Что нового» нет вообще (файл
        --! Modules/About/Changelogs.lua удалён вместе с авто-попапом F.CheckWhatsNew,
        --! а кнопку «Журнал изменений», которая в upstream стоит в «О Cell»
        --! (Cell-retail/Modules/About/About.lua:23-27), мы не переносили). По решению
        --! владельца удалены и запись ключа, и 130 КБ текста журнала в Locales/enUS.lua
        --! и Locales/zhCN.lua. См. GAP-087.
        F.RunSnippets()

        -- validation -----------------------------------------------------------------------------
        -- validate layout
        for talent, t in pairs(CellCharacterDB["layoutAutoSwitch"]) do
            for groupType, layout in pairs(t) do
                if layout ~= "hide" and not CellDB["layouts"][layout] then
                    t[groupType] = "default"
                end
            end
        end

        --! WotLK fix: the role tables need the same guard. A layout deleted while the
        --! character was offline (layouts are account-wide, so another character can do
        --! that) would otherwise leave a dangling name here, and F.UpdateLayout would set
        --! currentLayoutTable to nil - every indicator then reads fields off nil.
        for _, t in pairs(CellDB["layoutAutoSwitchRole"]) do
            for groupType, layout in pairs(t) do
                if layout ~= "hide" and not CellDB["layouts"][layout] then
                    t[groupType] = "default"
                end
            end
        end

        Cell.loaded = true
        Cell.Fire("AddonLoaded")
    end

    -- omnicd -------------------------------------------------------------------------------------
    -- if arg1 == "OmniCD" then
    --     omnicdLoaded = true

    --     local E = OmniCD[1]
    --     tinsert(E.unitFrameData, 1, {
    --         [1] = "Cell",
    --         [2] = "CellPartyFrameMember",
    --         [3] = "unitid",
    --         [4] = 1,
    --     })

    --     local function UnitFrames()
    --         if not E.customUF.optionTable.Cell then
    --             E.customUF.optionTable.Cell = "Cell"
    --             E.customUF.optionTable.enabled.Cell = {
    --                 ["delay"] = 1,
    --                 ["frame"] = "CellPartyFrameMember",
    --                 ["unit"] = "unitid",
    --             }
    --         end
    --     end
    --     hooksecurefunc(E, "UnitFrames", UnitFrames)
    -- end

    -- if cellLoaded and omnicdLoaded then
    --     eventFrame:UnregisterEvent("ADDON_LOADED")
    -- end
end

Cell.vars.raidSetup = {
    ["TANK"]={["ALL"]=0},
    ["HEALER"]={["ALL"]=0},
    ["DAMAGER"]={["ALL"]=0},
}

--! WotLK fix: вынесено из DoGroupRosterUpdate. Права меняются и без смены
--! состава: повышение в лидеры/ассисты роста не трогает, а на 3.3.5 это
--! отдельное событие PARTY_LEADER_CHANGED (обработчик ниже). Один и тот же
--! пересчёт зовут два источника, чтобы Marks/ReadyAndPull не оставались
--! заблокированными до следующего изменения группы.
local function UpdatePermission()
    if Cell.vars.hasPermission ~= F.HasPermission() or Cell.vars.hasPartyMarkPermission ~= F.HasPermission(true) then
        Cell.vars.hasPermission = F.HasPermission()
        Cell.vars.hasPartyMarkPermission = F.HasPermission(true)
        Cell.Fire("PermissionChanged")
    end
end

local function DoGroupRosterUpdate()
    if IsInRaid() then
        if Cell.vars.groupType ~= "raid" then
            Cell.vars.groupType = "raid"
            Cell.Fire("GroupTypeChanged", "raid")
            -- Layout update will be triggered by GroupTypeChanged callback -> PreUpdateLayout
        end

        -- reset raid setup
        for _, t in pairs(Cell.vars.raidSetup) do
            for class in pairs(t) do
                if class == "ALL" then
                    t["ALL"] = 0
                else
                    t[class] = nil
                end
            end
        end

        -- update guid & raid setup
        for i = 1, GetNumGroupMembers() do
            -- update raid setup
            --! WotLK fix: GetRaidRosterInfo has no 12th return (combatRole) on 3.3.5;
            --! use the same resolver everything else in Cell uses.
            local _, _, _, _, _, class = GetRaidRosterInfo(i)
            local role = Cell.UnitGroupRolesAssigned("raid"..i)
            if not role or role == "NONE" then role = "DAMAGER" end
            -- update ALL
            Cell.vars.raidSetup[role]["ALL"] = Cell.vars.raidSetup[role]["ALL"] + 1
            -- update for each class
            if class then
                if not Cell.vars.raidSetup[role][class] then
                    Cell.vars.raidSetup[role][class] = 1
                else
                    Cell.vars.raidSetup[role][class] = Cell.vars.raidSetup[role][class] + 1
                end
            end
        end

        -- update Cell.unitButtons.raid.units
        for i = GetNumGroupMembers()+1, 40 do
            Cell.unitButtons.raid.units["raid"..i] = nil
            _G["CellRaidFrameMember"..i] = nil
        end
        F.UpdateRaidSetup()

        -- update Cell.unitButtons.party.units
        Cell.unitButtons.party.units["player"] = nil
        Cell.unitButtons.party.units["pet"] = nil
        for i = 1, 4 do
            Cell.unitButtons.party.units["party"..i] = nil
            Cell.unitButtons.party.units["partypet"..i] = nil
        end

    elseif IsInGroup() then
        if Cell.vars.groupType ~= "party" then
            Cell.vars.groupType = "party"
            Cell.Fire("GroupTypeChanged", "party")
            -- Layout update will be triggered by GroupTypeChanged callback -> PreUpdateLayout
        end

        -- update Cell.unitButtons.raid.units
        for i = 1, 40 do
            Cell.unitButtons.raid.units["raid"..i] = nil
            _G["CellRaidFrameMember"..i] = nil
        end

        -- update Cell.unitButtons.party.units
        for i = GetNumGroupMembers(), 4 do
            Cell.unitButtons.party.units["party"..i] = nil
            Cell.unitButtons.party.units["partypet"..i] = nil
        end

    else
        if Cell.vars.groupType ~= "solo" then
            Cell.vars.groupType = "solo"
            Cell.Fire("GroupTypeChanged", "solo")
        end

        -- update Cell.unitButtons.raid.units
        for i = 1, 40 do
            Cell.unitButtons.raid.units["raid"..i] = nil
            _G["CellRaidFrameMember"..i] = nil
        end

        -- update Cell.unitButtons.party.units
        Cell.unitButtons.party.units["player"] = nil
        Cell.unitButtons.party.units["pet"] = nil
        for i = 1, 4 do
            Cell.unitButtons.party.units["party"..i] = nil
            Cell.unitButtons.party.units["partypet"..i] = nil
        end
    end

    UpdatePermission()
end

--! WotLK fix: PARTY_MEMBERS_CHANGED and RAID_ROSTER_UPDATE are the only native
--! 3.3.5a roster signals. Normalize both through one Cell-owned route, coalesce
--! same-frame bursts on the next frame (party-to-raid conversion can emit
--! both), then notify
--! internal consumers once through Cell's callback bus. Never forward the
--! RAID_ROSTER_UPDATE reason string as the truthy `force` argument.
local rosterUpdatePending
local rosterDispatchFrame = CreateFrame("Frame")
rosterDispatchFrame:Hide()
rosterDispatchFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    if not rosterUpdatePending then return end

    rosterUpdatePending = nil
    DoGroupRosterUpdate()
    if Cell.loaded then
        Cell.Fire("GroupRosterUpdate")
    end
end)

local function GroupRosterUpdate(force)
    if force then
        rosterUpdatePending = nil
        rosterDispatchFrame:Hide()
        DoGroupRosterUpdate()
        if Cell.loaded then
            Cell.Fire("GroupRosterUpdate")
        end
        return
    end

    if not rosterUpdatePending then
        rosterUpdatePending = true
        rosterDispatchFrame:Show()
    end
end

local inInstance
function eventFrame:PLAYER_ENTERING_WORLD()
    local isIn, iType = IsInInstance()
    --! WotLK fix: upstream Core.lua sets these two, the Wrath branch lost them;
    --! Layouts.lua:2902 marks the "current layout" star from Cell.vars.inInstance.
    Cell.vars.inInstance = isIn
    Cell.vars.instanceType = iType
    instanceType = iType
    Cell.vars.raidType = nil

    if isIn then
        PreUpdateLayout()
        inInstance = true
        -- notify listeners (TargetedSpells "only in instance" mode depends on this;
        -- upstream Cell fires these from PLAYER_ENTERING_WORLD, was lost in the port)
        Cell.Fire("EnterInstance", iType)

        -- NOTE: delayed raid difficulty check
        if iType == "raid" then
            C_Timer.After(0.5, function()
                --! can't get difficultyID, difficultyName immediately after entering an instance
                local _, _, difficultyID, difficultyName, maxPlayers = GetInstanceInfo()
                -- if difficultyID == 3 or difficultyID == 5 or difficultyID == 175 or difficultyID == 193 then
                --     Cell.vars.raidType = "raid10"
                -- elseif difficultyID == 4 or difficultyID == 6 or difficultyID == 176 or difficultyID == 194 then
                --     Cell.vars.raidType = "raid25"
                -- end
                if maxPlayers == 10 then
                    Cell.vars.raidType = "raid10"
                elseif maxPlayers == 25 then
                    Cell.vars.raidType = "raid25"
                end
                if Cell.vars.raidType then
                    PreUpdateLayout()
                end
            end)
        end

    elseif inInstance then -- left instance
        --! WotLK fix: leaving an instance (e.g. arena) can leave Cell.vars.groupType
        --! stale ("party") for a moment, so layout auto-switch applied the wrong (group)
        --! profile. Recompute the real group type from the live API before applying the
        --! layout, and re-check shortly after in case the arena party is torn down later.
        GroupRosterUpdate(true) --! force: the layout below depends on it
        PreUpdateLayout()
        inInstance = false
        Cell.Fire("LeaveInstance")
        C_Timer.After(0.3, function() GroupRosterUpdate() end)
        C_Timer.After(1, function() GroupRosterUpdate() end)

        --! Freeze fix: collectgarbage("collect") is a synchronous full sweep of the
        --! entire Lua heap (~180MB with a loaded UI). It stops the client dead for a
        --! noticeable fraction of a second at exactly the moment an RDF teleport pulls
        --! you out of the instance. Reclaim the same memory with bounded incremental
        --! steps spread over the next second instead, so no single frame pays for it.
        if not InCombatLockdown() and not UnitAffectingCombat("player") then
            C_Timer.NewTicker(0.1, function()
                collectgarbage("step", 200)
            end, 10)
        end
    end

    --! WotLK fix: merged from a duplicate PLAYER_ENTERING_WORLD handler that used to
    --! silently overwrite this one (Lua keeps only the last definition), which disabled
    --! all instanceType-based layout switching (arena/bg/raid) and the leave-instance
    --! profile refresh. On reload/login force a roster refresh if already grouped so
    --! names/indicators populate.
    if IsInRaid() or IsInGroup() then
        C_Timer.After(0.1, function() GroupRosterUpdate() end)
        C_Timer.After(0.5, function() GroupRosterUpdate() end)
        C_Timer.After(0.6, function()
            if Cell.vars.groupType == "party" or Cell.vars.groupType == "solo" then
                if Cell.frames.partyFrame and Cell.frames.partyFrame:IsShown() then
                    Cell.Fire("GroupTypeChanged", "party")
                end
            end
        end)
    end

    if CellDB["firstRun"] then
        F.FirstRun()
    end
end

--! WotLK fix: at PLAYER_LOGIN the talent tree is not populated yet on build 12340.
--! GetTalentInfo(1, 24) returns nothing at all - no name, no rank - so the rank ladder
--! below matched nothing and the multiplier was left nil. PLAYER_TALENT_UPDATE only
--! fires when points are gained or spent (codex: "Fires when the player gains or spends
--! talent points"), so nothing re-read the tree afterwards. Run 13 (2026-08-10) caught
--! it in the client: the tree was unreadable in the first probe and readable one second
--! later with rank 3, yet divineAegisMultiplier stayed nil for the next 553 seconds -
--! until the loading screen into the dungeon happened to re-fire the event. For those
--! nine minutes the Divine Aegis branch of the CLEU handler
--! (RaidFrames/UnitButton_Cata_Wrath.lua:2884) skipped every shield, because it guards
--! on that very var. Retry until the tree answers instead of reading it once.
local divineAegisRetries, divineAegisRetryPending
local function CheckDivineAegis()
    if Cell.vars.playerClass == "PRIEST" then
        --! WotLK fix: 22 is an unadapted Cata constant - upstream carries the same
        --! index in Core_Cata.lua:675 and Core_Wrath.lua:675 for two DIFFERENT
        --! talent trees. On 3.3.5 Divine Aegis sits at index 24 of the Discipline
        --! tree; that is what AbsorbsMonitor-1.0.lua:1824 read - a library that was
        --! embedded in Cell and written for this client (deleted 2026-08-09 because
        --! LoadLibs_Classic.xml never loaded it; the evidence lives on in git
        --! history, `git show HEAD:Cell/Libs/AbsorbsMonitor-1.0/AbsorbsMonitor-1.0.lua`).
        --! Its full Discipline scan was 1,2 / 1,9 / 1,16 / 1,24 / 1,27. With 22 the
        --! rank of a different talent
        --! was read, so divineAegisMultiplier got a wrong value or stayed nil and
        --! the Divine Aegis branch of the CLEU handler
        --! (RaidFrames/UnitButton_Cata_Wrath.lua:2850) never accumulated a shield.
        local name, _, _, _, rank = GetTalentInfo(1, 24)

        --! WotLK fix: no name means the tree is not loaded yet, not that the talent is
        --! missing - re-ask instead of silently keeping nil. Bounded at 30 tries (~30 s)
        --! so a client that never answers cannot leave a timer running forever, and
        --! single-flighted so the three call sites below cannot stack parallel chains.
        if not name then
            if not divineAegisRetryPending then
                divineAegisRetries = (divineAegisRetries or 0) + 1
                if divineAegisRetries <= 30 then
                    divineAegisRetryPending = true
                    C_Timer.After(1, function()
                        divineAegisRetryPending = false
                        CheckDivineAegis()
                    end)
                end
            end
            return
        end
        divineAegisRetries = nil

        if rank == 1 then
            Cell.vars.divineAegisMultiplier = 0.1
        elseif rank == 2 then
            Cell.vars.divineAegisMultiplier = 0.2
        elseif rank == 3 then
            Cell.vars.divineAegisMultiplier = 0.3
        else
            --! WotLK fix: the ladder had no else branch, so a respec that drops the
            --! talent (or switches to the other talent group without it) kept crediting
            --! shields at the old rank until reload.
            Cell.vars.divineAegisMultiplier = nil
        end
    end
end

local function UpdateSpecVars(skipTalentUpdate)
    -- if not skipTalentUpdate then
        Cell.vars.activeTalentGroup = GetActiveTalentGroup()
        Cell.vars.playerSpecID = Cell.vars.activeTalentGroup
    -- end
end

--! WotLK fix: keeps Cell.vars.playerTalentRole in step with the talent trees, for the Role
--! mode of Layout Auto Switch. Same readiness trap as CheckDivineAegis below: right after
--! login GetTalentTabInfo answers nothing, so a single read would silently produce the
--! wrong role. Falls back to the value cached for this talent group, retries until the
--! trees answer (bounded at 30 tries, single-flighted), and rebuilds the layout only when
--! the role actually turned out different from what is already on screen.
--! skipRekey is for the two call sites that are about to rebuild the layout themselves -
--! it is deliberately NOT passed on to the retry, because by the time the retry fires that
--! rebuild has long happened and a changed role does need a second one.
local talentRoleRetries, talentRoleRetryPending
local function UpdateTalentRole(skipRekey, isRetry)
    local group = Cell.vars.activeTalentGroup
    if not group then return end

    local role = F.GetPlayerTalentRole()

    if role then
        talentRoleRetries = nil
        CellCharacterDB["talentRoles"][group] = role
    else
        --! WotLK fix: the trees are unreadable, which is not the same as "no role" - fall
        --! back to what this talent group resolved to last time and ask again in a second.
        --! Falling through to the comparison below instead of returning matters: switching
        --! talent group lands here too, and the cached role for the new group can differ
        --! from the one on screen.
        role = CellCharacterDB["talentRoles"][group]
        --! WotLK fix: the 30-try bound is per event, not per session. Without this reset the
        --! counter would stay spent forever: one pathological login where the trees never
        --! answered would leave every later ACTIVE_TALENT_GROUP_CHANGED / PLAYER_TALENT_UPDATE
        --! with a single read and no retry at all. A real event is a fresh reason to ask, and
        --! it cannot spin - while the trees are readable the branch above clears the counter,
        --! and while they are not, these events are rare.
        if not talentRoleRetryPending then
            --! Inside the pending guard on purpose: an event arriving while a retry is
            --! already in flight must leave that chain on its own budget, not hand it a
            --! fresh one every time (PLAYER_TALENT_UPDATE fires per point moved).
            if not isRetry then
                talentRoleRetries = nil
            end
            talentRoleRetries = (talentRoleRetries or 0) + 1
            if talentRoleRetries <= 30 then
                talentRoleRetryPending = true
                C_Timer.After(1, function()
                    talentRoleRetryPending = false
                    UpdateTalentRole(nil, true)
                end)
            end
        end
    end

    if Cell.vars.playerTalentRole ~= role then
        Cell.vars.playerTalentRole = role
        --! WotLK fix: re-point the vars before anything reads them. In Role mode the role
        --! IS the key, so it just changed under everyone; PreUpdateLayout below would do
        --! this too, but only out of combat - in combat it merely queues itself, and the
        --! Layouts pane redrawing on the callback would show the old role's table.
        F.UpdateLayoutAutoSwitchVars()
        if not skipRekey and Cell.vars.layoutAutoSwitchBy == "role" then
            PreUpdateLayout()
        end
        Cell.Fire("LayoutAutoSwitchChanged")
    end
end

function eventFrame:PLAYER_LOGIN()
    -- NOTE: Cell no longer registers with LibSharedMedia to avoid triggering callbacks
    -- that interfere with other addons. See Utils.lua for full explanation.
    -- F.RegisterWithLSM()  -- Now a no-op

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    --! WotLK fix: GROUP_ROSTER_UPDATE is not a native 3.3.5a event.
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    --! WotLK fix: эти два апстрим держал закомментированными в
    --! UnitButton_Cata_Wrath.lua (3656-3657) с пометкой "GROUP_ROSTER_UPDATE" -
    --! на ретейле то одно событие покрывает и повышение, и выдачу роли. На
    --! 3.3.5 GROUP_ROSTER_UPDATE нет, а PARTY_MEMBERS_CHANGED /
    --! RAID_ROSTER_UPDATE ни повышение в пати, ни назначение роли через LFD не
    --! ловят: состав группы при этом не меняется. Blizzard на этом клиенте
    --! обрабатывает оба события отдельно от роста (FrameXML
    --! PartyMemberFrame.lua:324 - корона, PlayerFrame.lua:242 - иконка роли).
    --! Регистрируем один раз здесь и раздаём узкими событиями шины: гнать это
    --! через GroupRosterUpdate() дороже - полный проход перезапускает инспекты
    --! LibGroupInfo и рассылку Comm/Nicknames, которым тут обновляться нечего.
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    --! WotLK fix: was UI_SCALE_CHANGED - a retail event that does not exist on 3.3.5
    --! (absent from FrameXML 3.3.5), so the registration was silently inert.
    --! DISPLAY_SIZE_CHANGED is the native 3.3.5 signal for resolution/window size
    --! changes (Blizzard's own ContainerFrame relies on it).
    eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")

    Cell.vars.playerNameShort = GetUnitName("player")
    Cell.vars.playerNameFull = F.UnitFullName("player")

    CheckDivineAegis()

    --! WotLK fix: the extended GetBattlegroundInfo tuple is not available on
    --! build 12340; battleground capacity is derived in GetBattlegroundSize().

    Cell.vars.playerGUID = UnitGUID("player")

    -- update spec vars
    UpdateSpecVars()
    --! WotLK fix: must run before GroupRosterUpdate below - that is what builds the first
    --! layout, and in Role mode the key it uses comes from here. skipRekey: the rebuild is
    --! two lines away, no point asking for a second one.
    UpdateTalentRole(true)

    --! init Cell.vars.currentLayout and Cell.vars.currentLayoutTable
    GroupRosterUpdate()
    -- update click-castings
    Cell.Fire("UpdateClickCastings")
    -- update indicators
    -- Cell.Fire("UpdateIndicators") -- NOTE: already updated through GroupRosterUpdate -> GroupTypeChanged -> F.UpdateLayout
    -- update texture and font
    Cell.Fire("UpdateAppearance")
    Cell.UpdateOptionsFont(CellDB["appearance"]["optionsFontSizeOffset"], CellDB["appearance"]["useGameFont"])
    Cell.UpdateAboutFont(CellDB["appearance"]["optionsFontSizeOffset"])
    -- update tools
    Cell.Fire("UpdateTools")
    -- update requests
    Cell.Fire("UpdateRequests")
    -- update raid debuff list
    Cell.Fire("UpdateRaidDebuffs")
    -- hide blizzard
    if CellDB["general"]["hideBlizzardParty"] then F.HideBlizzardParty() end
    if CellDB["general"]["hideBlizzardRaid"] then F.HideBlizzardRaid() end
    if CellDB["general"]["hideBlizzardRaidManager"] then F.HideBlizzardRaidManager() end
    -- lock & menu
    Cell.Fire("UpdateMenu")
    -- update CLEU
    Cell.Fire("UpdateCLEU")
    -- update builtIns and customs
    I.UpdateAoEHealings(CellDB["aoeHealings"])
    I.UpdateDefensives(CellDB["defensives"])
    I.UpdateExternals(CellDB["externals"])
    I.UpdateCrowdControls(CellDB["crowdControls"])
    -- update pixel perfect
    Cell.Fire("UpdatePixelPerfect")
    -- LibHealComm
    -- F.EnableLibHealComm(CellDB["appearance"]["useLibHealComm"])
    -- update LGF
    F.UpdateFramePriority()
end

local function UpdatePixels()
    if not InCombatLockdown() then
        Cell.Fire("UpdatePixelPerfect")
        Cell.Fire("UpdateAppearance", "scale")
    end
end

local updatePixelsTimer
local function DelayedUpdatePixels()
    if updatePixelsTimer then
        updatePixelsTimer:Cancel()
    end
    updatePixelsTimer = C_Timer.NewTimer(1, UpdatePixels)
end

--! WotLK fix: was 'function eventFrame:UI_SCALE_CHANGED()' - dead on 3.3.5, the event
--! does not exist there. DISPLAY_SIZE_CHANGED covers resolution/window size changes.
function eventFrame:DISPLAY_SIZE_CHANGED()
    DelayedUpdatePixels()
end

hooksecurefunc(UIParent, "SetScale", DelayedUpdatePixels)

--! WotLK fix: on 3.3.5 Blizzard's Video Options apply uiScale/useUiScale NATIVELY in the
--! client - UIParent is rescaled without going through the Lua UIParent:SetScale, so the
--! hook above never fires for them. The options panel does commit the CVars through the
--! global SetCVar (FrameXML OptionsPanelTemplates.lua:198), so hook that instead.
--! CVAR_UPDATE is NOT suitable here: on 3.3.5 its arg1 is a global-string tag (not the
--! CVar name), and the uiscale slider is declared with an empty tag (VideoOptionsPanels.lua:89).
--! Cross-checked with ElvUI-WotLK: its own UI_SCALE_CHANGED registration is inert too,
--! it relies on UPDATE_FLOATING_CHAT_WINDOWS + reload popups instead (Core/PixelPerfect.lua).
hooksecurefunc("SetCVar", function(cvar)
    if type(cvar) == "string" then
        cvar = strlower(cvar)
        if cvar == "uiscale" or cvar == "useuiscale" then
            DelayedUpdatePixels()
        end
    end
end)

--! WotLK fix: normalize native roster events. RAID_ROSTER_UPDATE carries a
--! reason string on 3.3.5a, but the shared route intentionally ignores it.
function eventFrame:PARTY_MEMBERS_CHANGED()
    GroupRosterUpdate()
end

function eventFrame:RAID_ROSTER_UPDATE(reason)
    GroupRosterUpdate()
end

--! WotLK fix: смена лидера/ассиста роста не меняет, поэтому раньше ни права
--! (Marks, ReadyAndPull), ни корона на кнопках не пересчитывались до
--! какого-нибудь постороннего полного обновления. Пересчёт прав - точно тот же,
--! что в конце DoGroupRosterUpdate, короне достаточно узкого события.
function eventFrame:PARTY_LEADER_CHANGED()
    UpdatePermission()
    if Cell.loaded then
        Cell.Fire("LeaderChanged")
    end
end

--! WotLK fix: назначение роли через интерфейс подземелий состава не меняет, так
--! что states.role, иконка роли и фильтры силы TANK/HEALER висели на старом
--! значении. Права от роли не зависят - только раздача.
function eventFrame:PLAYER_ROLES_ASSIGNED()
    if Cell.loaded then
        Cell.Fire("RolesAssigned")
    end
end

function eventFrame:ACTIVE_TALENT_GROUP_CHANGED()
    -- not in combat & spec CHANGED
    if not InCombatLockdown() and (Cell.vars.activeTalentGroup ~= GetActiveTalentGroup()) then
        UpdateSpecVars()
        --! WotLK fix: before the fire below, which is what re-keys the layout - the new
        --! talent group can have a different role. skipRekey because "ActiveTalentGroupChanged"
        --! already lands on PreUpdateLayout (see the registration at the top of this file).
        UpdateTalentRole(true)

        Cell.Fire("UpdateClickCastings")
        Cell.Fire("ActiveTalentGroupChanged", Cell.vars.activeTalentGroup)

        CheckDivineAegis()
    end
end

-- check Divine Aegis
function eventFrame:PLAYER_TALENT_UPDATE()
    CheckDivineAegis()
    --! WotLK fix: no skipRekey here - this is the plain respec case. Moving points inside
    --! the same talent group does not change GetActiveTalentGroup(), so
    --! ACTIVE_TALENT_GROUP_CHANGED never fires and nothing else would notice that a
    --! Holy priest just became Shadow. The re-key inside is conditional on the role
    --! actually changing, so the point-by-point spam of this event costs three
    --! GetTalentTabInfo calls and nothing more.
    UpdateTalentRole()
    -- UpdateSpecVars(true)
    F.UpdateClickCastingProfileLabel()
end

--! WotLK fix: this duplicate PLAYER_ENTERING_WORLD handler was overwriting the real one
--! above (Lua keeps only the last definition assigned to eventFrame.PLAYER_ENTERING_WORLD),
--! which disabled instanceType-based layout switching and the leave-instance profile
--! refresh. Its grouped-roster-refresh logic has been merged into the handler above.

eventFrame:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)

-------------------------------------------------
-- encounter state (DBM bridge)
-------------------------------------------------
-- Cell.IsEncounterInProgress
--! WotLK fix: preserve a real custom-core implementation when present, but keep the
--! stock fallback private - a global that always returns false makes other addons
--! believe encounter state is supported.
--! WotLK feature: ENCOUNTER_START/ENCOUNTER_END arrived in 5.4, so on stock 3.3.5a
--! nothing ever told Cell a boss fight had begun - the flag stayed false forever and
--! three consumers were inert: the death-report cap that keeps a wipe from spamming
--! 25 lines into /raid (DeathReport.lua), the dispel-request glow reset
--! (Request_Show.lua) and the targeted-spells reset (TargetedSpells.lua). DBM is the
--! only source of that state here and already broadcasts DBM_Pull/DBM_Kill/DBM_Wipe
--! through its own callback registry. Read it, never write it (rule 3): this bridge
--! only subscribes and re-fires through Cell's callbacks under the upstream event
--! names. With no DBM installed nothing changes.
do
    local nativeIsEncounterInProgress = IsEncounterInProgress
    local encounterInProgress = false
    local attachedRevision -- nil = not attached

    --! Only DBM_Pull carries "in progress"; both endings clear it.
    local DBM_EVENTS = {
        DBM_Pull = {"EncounterStart", nil, true},
        DBM_Kill = {"EncounterEnd", 1, false},
        DBM_Wipe = {"EncounterEnd", 0, false},
    }

    --! DBM only started exposing mod.encounterId in this revision. Older builds
    --! (every 3.3.5a port) report 0 - no consumer in Cell reads the id, so the bridge
    --! must not refuse to attach over it. Revision may be a string on old ports,
    --! hence tonumber() rather than a type check.
    local ENCOUNTER_ID_REVISION = 20250929200404

    function Cell.IsEncounterInProgress()
        if type(nativeIsEncounterInProgress) == "function" then
            return not not nativeIsEncounterInProgress()
        end
        return encounterInProgress
    end

    --! For /cell debug env: says whether the bridge actually found DBM. A silent
    --! no-op is exactly the failure this project cannot detect from a game run.
    function Cell.GetEncounterBridgeState()
        return attachedRevision ~= nil, attachedRevision
    end

    local function OnDBMEvent(dbmEvent, ...)
        local spec = DBM_EVENTS[dbmEvent]
        if not spec then return end

        --! Do not trust argument order: DBM ports differ on whether the callback
        --! receives (event, mod) or just (mod). Take the first table argument.
        local mod
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            if type(v) == "table" then mod = v break end
        end

        local id = 0
        local name = ""
        if mod then
            if attachedRevision and attachedRevision >= ENCOUNTER_ID_REVISION then
                id = tonumber(mod.encounterId) or 0
            end
            --! combatInfo is absent on some mods; indexing it blind would throw
            --! mid-fight, which is the worst possible moment for an error.
            local info = mod.combatInfo
            if type(info) == "table" and type(info.name) == "string" then
                name = info.name
            end
        end

        local _, _, difficulty, _, maxPlayers = GetInstanceInfo()
        encounterInProgress = spec[3]
        Cell.Fire(spec[1], id, name, difficulty or 0, maxPlayers or 0, spec[2])
    end

    local tracker = CreateFrame("Frame")

    local function Attach()
        if attachedRevision then return true end

        local dbm = DBM
        if type(dbm) ~= "table" or type(dbm.RegisterCallback) ~= "function" then
            return false
        end

        attachedRevision = tonumber(dbm.Revision) or 0
        --! One closure per event: the DBM event name comes from the closure, so a
        --! port that omits the event argument still lands in the right branch.
        for dbmEvent in pairs(DBM_EVENTS) do
            dbm:RegisterCallback(dbmEvent, function(...)
                OnDBMEvent(dbmEvent, ...)
            end)
        end

        tracker:UnregisterEvent("ADDON_LOADED")
        return true
    end

    tracker:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == "DBM-Core" then Attach() end
        elseif encounterInProgress then
            --! Anti-stick guard: leaving the instance (hearthstone, logout, disconnect
            --! mid-pull) means DBM never sends Kill or Wipe, and a stuck flag would cap
            --! death reports and freeze the mouseover status text for the session.
            encounterInProgress = false
            Cell.Fire("EncounterEnd", 0, "", 0, 0, 0)
        end
    end)
    tracker:RegisterEvent("ADDON_LOADED")
    tracker:RegisterEvent("PLAYER_ENTERING_WORLD")

    --! DBM may already be loaded (it sorts before Cell for most managers).
    Attach()
end

-------------------------------------------------
-- slash command
-------------------------------------------------
SLASH_CELL1 = "/cell"


function SlashCmdList.CELL(msg, editbox)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = strlower(command or "")
    --! WotLK fix: keep the original case of the argument tail. The debug extension
    --! takes API function names and event names (/cell debug ret GetRaidRosterInfo,
    --! /cell debug ev READY_CHECK_CONFIRM), and those are case-sensitive lookups.
    local restRaw = rest or ""
    rest = strlower(restRaw)

    if command == "debug" then
        -- Delegate to the debug module if it's loaded
        if Cell.Debug and Cell.Debug.HandleCommand then
            Cell.Debug:HandleCommand(rest, restRaw)
        else
            F.Print("Debug module not loaded.")
        end

    elseif command == "roledebug" or command == "roledbg" then
        -- Toggle role detection debugging
        if Cell.sFuncs and Cell.sFuncs.ToggleRoleDebug then
            Cell.sFuncs.ToggleRoleDebug()
        else
            F.Print("Role debug function not available.")
        end

    elseif command == "options" or command == "opt" then
        F.ShowOptionsFrame()

    --! WotLK fix: тумблер режима мувера снаружи опций. Кнопка Unlock живёт в
    --! Options > Utilities > Raid Tools, а этот пейн в бою целиком закрыт
    --! combat-маской (F.ApplyCombatProtectionToFrame), плюс сам список Utilities
    --! раскрывается только по наведению - тумблер фактически ненаходим. Слэш
    --! работает всегда и в бою тоже: он не трогает protected-состояние, только
    --! показывает/скрывает мувер-рамки инструментов.
    elseif command == "unlock" or command == "lock" or command == "mover" then
        if Cell.uFuncs and Cell.uFuncs.SetMoverShown then
            local show
            if command == "unlock" then
                show = true
            elseif command == "lock" then
                show = false
            end -- "mover" -> nil -> toggle
            Cell.uFuncs.SetMoverShown(show)
        else
            F.Print("Raid Tools module not loaded.")
        end

    elseif command == "minimap" then
        if type(CellDB["minimapButton"]) ~= "table" then
            CellDB["minimapButton"] = {["shown"] = true, ["degree"] = 195}
        end
        CellDB["minimapButton"]["shown"] = not CellDB["minimapButton"]["shown"]
        Cell.Fire("UpdateMinimapButton")
        F.Print(CellDB["minimapButton"]["shown"] and L["Minimap button shown."] or L["Minimap button hidden. Use /cell minimap to show it again."])

    elseif command == "healers" then
        F.FirstRun()

    elseif command == "rescale" then
        CellDB["appearance"]["scale"] = P.GetRecommendedScale()
        ReloadUI()

    elseif command == "reset" then
        if rest == "position" then
            Cell.frames.anchorFrame:ClearAllPoints()
            Cell.frames.anchorFrame:SetPoint("TOPLEFT", CellParent, "CENTER")
            Cell.vars.currentLayoutTable["position"] = {}
            P.ClearPoints(Cell.frames.readyAndPullFrame)
            Cell.frames.readyAndPullFrame:SetPoint("TOPRIGHT", CellParent, "CENTER")
            CellDB["tools"]["readyAndPull"][4] = {}
            P.ClearPoints(Cell.frames.raidMarksFrame)
            Cell.frames.raidMarksFrame:SetPoint("BOTTOMRIGHT", CellParent, "CENTER")
            CellDB["tools"]["marks"][4] = {}
            P.ClearPoints(Cell.frames.buffTrackerFrame)
            Cell.frames.buffTrackerFrame:SetPoint("BOTTOMLEFT", CellParent, "CENTER")
            CellDB["tools"]["buffTracker"][4] = {}

        elseif rest == "all" then
            Cell.frames.anchorFrame:ClearAllPoints()
            Cell.frames.anchorFrame:SetPoint("TOPLEFT", CellParent, "CENTER")
            Cell.frames.readyAndPullFrame:ClearAllPoints()
            Cell.frames.readyAndPullFrame:SetPoint("TOPRIGHT", CellParent, "CENTER")
            Cell.frames.raidMarksFrame:ClearAllPoints()
            Cell.frames.raidMarksFrame:SetPoint("BOTTOMRIGHT", CellParent, "CENTER")
            Cell.frames.buffTrackerFrame:ClearAllPoints()
            Cell.frames.buffTrackerFrame:SetPoint("BOTTOMLEFT", CellParent, "CENTER")
            CellDB = nil
            CellCharacterDB = nil
            ReloadUI()

        elseif rest == "layouts" then
            CellDB["layouts"] = nil
            ReloadUI()

        elseif rest == "clickcastings" then
            CellCharacterDB["clickCastings"] = nil
            ReloadUI()

        elseif rest == "raiddebuffs" then
            CellDB["raidDebuffs"] = nil
            ReloadUI()

        elseif rest == "snippets" then
            CellDB["snippets"] = {}
            CellDB["snippets"][0] = F.GetDefaultSnippet()
            ReloadUI()
        end

    elseif command == "report" then
        --! WotLK fix: the argument tail was fed to string.format as the FORMAT
        --! string (rest:format("%d") means format(rest, "%d")), so any '%' the
        --! player types throws straight out of SlashCmdList: "/cell report 50%"
        --! gives "invalid option '%' to 'format'", "/cell report %d" gives
        --! "bad argument #1 to 'format' (number expected, got string)" — both
        --! verified under Lua 5.1. For a plain number the call returned the
        --! string unchanged, i.e. it never did anything. tonumber is what was meant.
        rest = tonumber(rest)
        if rest and rest >= 0 and rest <= 40 then
            if rest == 0 then
                F.Print(L["Cell will report all deaths during a raid encounter."])
            else
                F.Print(string.format(L["Cell will report first %d deaths during a raid encounter."], rest))
            end
            CellDB["tools"]["deathReport"][2] = rest
            Cell.Fire("UpdateTools", "deathReport")
        else
            F.Print(L["A 0-40 integer is required."])
        end

    -- elseif command == "buff" then
    --     rest = tonumber(rest:format("%d"))
    --     if rest and rest > 0 then
    --         CellDB["tools"]["buffTracker"][3] = rest
    --         F.Print(string.format(L["Buff Tracker icon size is set to %d."], rest))
    --         Cell.Fire("UpdateTools", "buffTracker")
    --     else
    --         F.Print(L["A positive integer is required."])
    --     end

    else
        F.Print(L["Available slash commands"]..":")
        --! WotLK fix: the upstream line advertised only (v, r, c, h), but this
        --! backport added ~15 diagnostic subcommands (dump, shims, env, roles,
        --! movers, threat, readycheck, raiddebuffs, log, ...) that are the whole
        --! point of asking a tester for data. They were unreachable by anyone
        --! who did not already know they exist, so point at the list instead of
        --! repeating a stale four-letter subset here.
        print(" |cFFFFB5C5/cell debug|r: toggle debug mode. |cFFFFB5C5/cell debug h|r: list all debug subcommands.")
        print(" |cFFFFB5C5/cell options|r, |cFFFFB5C5/cell opt|r: "..L["show Cell options frame"]..".")
        print(" |cFFFFB5C5/cell unlock|r, |cFFFFB5C5/cell lock|r, |cFFFFB5C5/cell mover|r: "..L["show or hide the movers of Marks Bar, Buff Tracker and ReadyCheck/PullTimer buttons"]..".")
        print(" |cFFFFB5C5/cell minimap|r: "..L["toggle the minimap button"]..".")
        print(" |cFFFFB5C5/cell healers|r: "..L["create a \"Healers\" indicator"]..".")
        print(" |cFFFFB5C5/cell rescale|r: "..strlower(L["Apply Recommended Scale"])..".")
        print(" |cFFFF7777"..L["These \"reset\" commands below affect all your characters in this account"]..".|r")
        print(" |cFFFFB5C5/cell reset position|r: "..L["reset Cell position"]..".")
        print(" |cFFFFB5C5/cell reset layouts|r: "..L["reset all Layouts and Indicators"]..".")
        print(" |cFFFFB5C5/cell reset clickcastings|r: "..L["reset all Click-Castings"]..".")
        print(" |cFFFFB5C5/cell reset raiddebuffs|r: "..L["reset all Raid Debuffs"]..".")
        print(" |cFFFFB5C5/cell reset snippets|r: "..L["reset all Code Snippets"]..".")
        print(" |cFFFFB5C5/cell reset all|r: "..L["reset all Cell settings"]..".")
    end
end

StaticPopupDialogs["CELL_RELOAD_UI"] = {
    text = "%s",
    button1 = _G.YES,
    button2 = _G.NO,
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-------------------------------------------------
-- Debug Frame Stack
-------------------------------------------------
local debugFrameStack = CreateFrame("Frame")
local debugFrameStackEnabled = false

debugFrameStack:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer < 0.2 then return end
    self.timer = 0
    
    local f = GetMouseFocus()
    if f then
        local name = f:GetName() or tostring(f)
        if name ~= self.lastFrame then
            self.lastFrame = name
            print("|cFFFF3030[Debug]|r Frame under mouse:", name)
            if f.GetFrameLevel then
                print("  Level:", f:GetFrameLevel(), "Strata:", f:GetFrameStrata())
            end
        end
    end
end)
debugFrameStack:Hide()

SLASH_CELLDEBUGFRAMES1 = "/celldebugframes"
SlashCmdList["CELLDEBUGFRAMES"] = function()
    debugFrameStackEnabled = not debugFrameStackEnabled
    if debugFrameStackEnabled then
        debugFrameStack:Show()
        print("|cFFFF3030[Cell]|r Debug Frames: ENABLED. Hover over the unclickable area.")
    else
        debugFrameStack:Hide()
        print("|cFFFF3030[Cell]|r Debug Frames: DISABLED.")
    end
end

-- print("Cell Core Loaded")
