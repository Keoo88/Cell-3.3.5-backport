local addonName, ns = ...
-- Use a single global Cell table for everything
_G.Cell = _G.Cell or ns or {}
local Cell = _G.Cell

-------------------------------------------------
-- Private class-info contract
-------------------------------------------------
--! WotLK fix: stock 3.3.5a has no native C_CreatureInfo/GetClassInfo contract.
--! Preserve a custom-core or standalone !!!ClassicAPI owner when it exists, but
--! keep Cell's stock Wrath fallback private instead of publishing a broad modern
--! namespace and an unused, non-localized race table to every addon.
local wrathClassFiles = {
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

function Cell.GetClassInfoTuple(classID)
    local info
    if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        info = C_CreatureInfo.GetClassInfo(classID)
    end
    if type(info) == "table" then
        return info.className, info.classFile, info.classID
    end
    if GetClassInfo then
        local a, b, c = GetClassInfo(classID)
        if type(a) == "table" then
            return a.className, a.classFile, a.classID
        elseif a ~= nil then
            return a, b, c
        end
    end

    local classFile = wrathClassFiles[classID]
    if classFile then
        local localized = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]
        return localized or classFile, classFile, classID
    end
end

-------------------------------------------------
-- securecallfunction compatibility
-------------------------------------------------
--! WotLK fix: stock 3.3.5a exposes native securecall but not the later
--! securecallfunction alias consumed by embedded CallbackHandler. Delegate
--! directly so return count, error handling, and secure execution semantics stay
--! native; never approximate this contract with pcall or a fixed return count.
if type(securecallfunction) ~= "function" and type(securecall) == "function" then
    function securecallfunction(func, ...)
        return securecall(func, ...)
    end
end


-------------------------------------------------
-- PRIVATE PROJECT / FLAVOR STATE FOR 3.3.5a
-------------------------------------------------
--! WotLK fix: this backport targets Interface 30300 regardless of retail-style
--! project constants exposed by a custom core. Keep the decision private to Cell:
--! rewriting WOW_PROJECT_ID or Blizzard expansion constants changes code paths in
--! every foreign addon and can make them select an unsupported compatibility mode.
Cell.flavor = "wrath"
Cell.isRetail = false
Cell.isWrath = true
Cell.isVanilla = false
Cell.isCata = false
Cell.isMists = false
Cell.isTWW = false

-------------------------------------------------

--! WotLK fix: IsMetaKeyDown is not a stock 3.3.5a API and has one Cell consumer.
--! Widgets.lua binds a private false fallback instead of advertising this global
--! input capability to every addon.

--! WotLK fix: CreateVector2D has no active Cell consumer. Do not publish a
--! partial retail vector object solely for a commented-out rotation experiment.

--! WotLK fix: пустые Cell.supporters1/supporters2 были заглушкой под панель
--! спонсоров, которой в бэкпорте больше нет: Supporters.lua и
--! Indicators/Supporter.lua удалены, CreateSupportersPane() в Modules/About
--! закомментирован. Читателей у таблиц не осталось ни одного, а сами они на
--! старте создавали два лишних объекта в Cell.

-------------------------------------------------
-- Polyfills for WotLK 3.3.5a
-------------------------------------------------

--! WotLK fix: LibCustomGlow owns its texture-sheet animator privately. Do not
--! publish AnimateTexCoords solely for one embedded-library consumer.

-------------------------------------------------
-- PixelUtil ownership
-------------------------------------------------
--! WotLK fix: ClassicAPI/Util/PixelUtil.lua creates only Cell.PixelUtil. Stock
--! 3.3.5a has no GetPhysicalScreenSize/PixelUtil globals, so the embedded copy
--! does not publish them or interfere with a standalone/foreign owner.


--! WotLK fix: CreateVector2D has no active Cell consumer and remains absent.


--! WotLK fix: the old CellDropdownList placeholder was a disconnected global
--! frame. The real Cell dropdown list is owned privately by Widgets.lua, which
--! now exposes Cell.HideDropdownList() to the few modules that need to close it.


--! WotLK fix: Cell.SetTextureGradient is gone. Texture:SetGradientAlpha(orientation,
--! r,g,b,a, r,g,b,a) is native on 3.3.5 (codex), and the adapter only existed to
--! translate the retail color-object form SetGradient(orientation, color, color),
--! which this client does not have. All 12 call sites passed the full nine
--! arguments with explicit alphas, so the `a1 or 1` defaults were dead and the
--! helper was a literal pass-through; they now call the native method directly.
--! The native Texture:SetGradient/SetGradientAlpha methods stay untouched - Cell
--! must not replace the shared Texture metatable client-wide.

--! WotLK fix: GetNumLines, IsTruncated и SetEnabled принадлежат активному провайдеру
--! WidgetAPI, который грузится раньше этого файла. Встроенный провайдер ставит только
--! отсутствующие методы; при живом !!!ClassicAPI владельцем остаётся он. Не зондировать
--! общие метатаблицы второй раз и не создавать второго владельца-фолбэка.
--! SetColorTexture из этого списка выпал 2026-08-16: шим удалён из WidgetAPI вместе с
--! конкретным зондом Texture. На 3.3.5 цвет задаёт нативная числовая форма
--! Texture:SetTexture(r, g, b[, a]) (кодекс), шим только звал её же, и все 88 вызовов
--! Cell переведены на неё напрямую. Полифиллу тут ставить нечего: имени SetColorTexture
--! в аддоне больше нет ни в одной точке.
--! Существующие реализации Texture:SetAtlas не трогаются вообще: 2026-08-11 шим
--! SetAtlas удалён из WidgetAPI (атласов на 3.3.5 нет как системы, а данные читались
--! из _G.C_Texture, которого Cell не публикует). Полифиллу тем более нечего тут
--! ставить - в Cell не осталось ни одной живой точки вызова SetAtlas или SetShown.


--! WotLK fix: 3.3.5 cannot independently enable mouse clicks and motion. Cell's
--! only consumer now owns its legacy EnableMouse behavior directly; do not add
--! SetMouseClickEnabled/SetMouseMotionEnabled to the shared Frame metatable.


-------------------------------------------------
--! WotLK fix: Cell never rotates FontStrings. Do not advertise unsupported
--! FontString:SetRotation as a successful shared no-op.
-------------------------------------------------

-------------------------------------------------
--! WotLK fix: Cell formats accent/rainbow text privately in Widgets.lua. Do not
--! publish CreateColor/WrapTextInColorCode or add methods to a foreign Color
--! metatable solely for Cell. Standalone !!!ClassicAPI keeps its own color API;
--! the embedded Color modules remain inactive to avoid shared table mutation.
-------------------------------------------------

-------------------------------------------------
--! WotLK fix: do not add retail colorStr fields or methods to entries in
--! Blizzard's shared RAID_CLASS_COLORS/CUSTOM_CLASS_COLORS tables. Cell derives
--! its own color escape strings from native r/g/b values at the call sites.
-------------------------------------------------

-------------------------------------------------
--! WotLK fix: Frame:CreateFontString is native on 3.3.5 and must retain its
--! Blizzard contract. Cell passes a font template or calls SetFont explicitly
--! at its own no-template call sites, so no shared-metatable wrapper is needed.
-------------------------------------------------

--! WotLK fix: Cell.SmoothStatusBarMixin is owned privately by the active
--! ClassicAPI smoothing module. Do not publish or consume a shared global mixin
--! whose behavior and lifetime depend on foreign addon load order.

-------------------------------------------------
--! WotLK fix: SetStatusBarTexture and GetStatusBarTexture are native 3.3.5
--! methods. Do not replace the shared StatusBar metatable or create fallback
--! textures on Blizzard/foreign bars. Cell guards the few client-sensitive
--! texture uses locally after assigning each bar's texture.
-------------------------------------------------

-------------------------------------------------
-- Retail unit API polyfills
-------------------------------------------------

--! WotLK fix: Cell.UnitInOtherParty is gone. 3.3.5 ships no UnitInOtherParty in
--! the C API (codex) and FrameXML never mentions it, so the adapter was a literal
--! `return false` with no probe of a native function - unlike Cell.UnitInPhase
--! below, which still probes for a custom-core implementation. Its only consumer,
--! the LFG-Eye branch in Indicators/StatusIcon.lua, was unreachable on every
--! client and was removed together with it. Cell neither publishes nor reads a
--! global of that name (rule 3): a foreign addon stays free to define its own.

--! WotLK fix: incoming resurrection tracking now consumes LibResComm
--! privately inside Indicators/StatusIcon.lua. The global
--! UnitHasIncomingResurrection polyfill, synthetic
--! INCOMING_RESURRECT_CHANGED dispatch, shared Frame-metatable hooks, and
--! CellIncomingResProxy were removed.

-- UnitInPhase
--! WotLK fix: preserve a real custom-core phase API, but keep the stock fallback
--! private so foreign addons do not mistake an unconditional true for support.
do
    local nativeUnitInPhase = UnitInPhase
    function Cell.UnitInPhase(unit)
        if type(nativeUnitInPhase) == "function" then
            return not not nativeUnitInPhase(unit)
        end
        return true
    end
end

-- UnitGroupRolesAssigned
do
    -- RETAIL CONTRACT: returns ONE string - "TANK" / "HEALER" / "DAMAGER" / "NONE".
    -- Every consumer (UnitButton, SpotlightFrame, LibGroupInfo) relies on this.
    --
    --! WotLK fix: 3.3.5a HAS a native UnitGroupRolesAssigned (added with the
    --! Dungeon Finder, 0x0060C810), but with the OLD contract - it returns
    --! THREE BOOLEANS (isTank, isHealer, isDamage). The previous
    --! `if not UnitGroupRolesAssigned` guard meant this wrapper never
    --! installed on a real 3.3.5 client, so callers received a boolean in
    --! states.role: LFD tanks got `true` (matches no string key), everyone
    --! else got `false` -> GetRole fell back to "DAMAGER". Symptom: the DPS
    --! power filter applied to everybody, TANK/HEALER filters never matched.
    --! Now defined UNCONDITIONALLY: the native three-boolean result is
    --! converted to the retail single-string contract, then the fallback
    --! chain below runs when the native API knows nothing (non-LFD groups).
    --
    -- Sources, in priority order:
    --   1. Native 3.3.5 LFD role (converted from three booleans; also
    --      passes through retail-style strings on custom cores)
    --   2. GetRaidRosterInfo role (LFG / raid assignments)
    --   3. Party MAINTANK / MAINASSIST assignments
    --   4. LibGroupInfo talent-based specRole ONLY (never assignedRole - that
    --      field is written FROM this function, reading it back would create
    --      a circular dependency)

    --
    --! WotLK fix (Blizzard tank-icon bug): this polyfill used to REPLACE the
    --! GLOBAL UnitGroupRolesAssigned. Blizzard's own FrameXML (PlayerFrame /
    --! PartyMemberFrame LFD role icons) and other addons (native ElvUI, oUF,
    --! XPerl) still call it with the NATIVE 3.3.5 contract:
    --!   local isTank, isHealer, isDamage = UnitGroupRolesAssigned(unit)
    --! A retail-style single-string return ("HEALER", "DAMAGER", ...) is
    --! truthy in Lua, so isTank was ALWAYS "true" -> every grouped player got
    --! a TANK shield on the Blizzard player/party frames regardless of the
    --! real role. The resolver is now Cell-private as
    --! Cell.UnitGroupRolesAssigned, while the global keeps its native
    --! three-boolean behavior.

    local orig_UnitGroupRolesAssigned = UnitGroupRolesAssigned

    -- Debug flag for role detection (toggle with /cell debug role)
    local roleDebugEnabled = false

    -- hot path: this polyfill runs for every unit button role/power update,
    -- so cache the LibGroupInfo reference instead of a LibStub lookup per call
    local _cachedLGI

    --! WotLK fix: keep role selection in one resolver and expose a read-only
    --! diagnostic snapshot through Cell.GetUnitRoleDebugInfo(). The public Cell
    --! contract still returns exactly one role string; diagnostics do not duplicate
    --! the fallback chain and therefore cannot silently disagree with live frames.
    local function ResolveCellUnitRole(unit, wantDetails)
        local details = wantDetails and {unit = unit} or nil
        if not unit then
            if details then
                details.finalRole = "NONE"
                details.source = "missing unit"
            end
            return "NONE", "missing unit", details
        end

        local result = nil
        local roleSource = "none"

        -- Native 3.3.5 LFD roles (three booleans), or a retail-style string
        -- on custom cores that already backported the new contract
        if orig_UnitGroupRolesAssigned then
            local r1, r2, r3 = orig_UnitGroupRolesAssigned(unit)
            if details then
                details.native1, details.native2, details.native3 = r1, r2, r3
            end
            if type(r1) == "string" then
                if r1 == "TANK" or r1 == "HEALER" or r1 == "DAMAGER" then
                    result = r1
                    roleSource = "native (string contract)"
                end
                -- "NONE" or anything else: fall through to the chain below
            elseif r1 then
                result = "TANK"
                roleSource = "native LFD (boolean contract)"
            elseif r2 then
                result = "HEALER"
                roleSource = "native LFD (boolean contract)"
            elseif r3 then
                result = "DAMAGER"
                roleSource = "native LFD (boolean contract)"
            end
        end

        --! WotLK fix (chat spam regression): the fallback chain below may
        --! only run for PLAYER units in OUR group. GetPartyAssignment is
        --! server-validated on some cores - calling it for pets / NPCs
        --! ("pet", "raidpetN", "bossN") spams the ERR_NOT_IN_YOUR_PARTY
        --! system message ("X is not in your party.") twice per button on
        --! every roster update / relog. Pets and NPCs can't have roles:
        --! return "NONE" immediately (retail contract does the same).
        if not result then
            local isPlayer = UnitIsPlayer(unit)
            local inOurGroup = isPlayer and
                (UnitIsUnit(unit, "player") or UnitInParty(unit) or UnitInRaid(unit))
            if details then
                details.isPlayer = not not isPlayer
                details.inOurGroup = not not inOurGroup
            end
            if not isPlayer or not inOurGroup then
                if details then
                    details.finalRole = "NONE"
                    details.source = not isPlayer and "non-player unit" or "unit outside group"
                end
                return "NONE", not isPlayer and "non-player unit" or "unit outside group", details
            end
        end

        -- For raid members, get role from GetRaidRosterInfo
        --! WotLK fix: UnitInRaid already RETURNS the roster index (0-based, nil
        --! if not in the raid), so scanning the whole roster with UnitIsUnit and
        --! building "raid"..i strings just to find it again is pure waste - this
        --! runs for every unit button on every roster/role update. Blizzard's own
        --! FrameXML does exactly this: TargetFrame.lua:659-661
        --! (id = UnitInRaid("target"); GetRaidRosterInfo(id + 1)).
        local raidIndex = (not result or details) and UnitInRaid(unit)
        if details then details.raidIndex = raidIndex end
        if raidIndex then
            -- GetRaidRosterInfo returns: name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML
            local _, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(raidIndex + 1)
            if details then details.raidRosterRole = role end
            if not result and role and role ~= "NONE" and role ~= "" then
                roleSource = "GetRaidRosterInfo"
                if role == "MAINTANK" or role == "TANK" then
                    result = "TANK"
                elseif role == "HEALER" then
                    result = "HEALER"
                elseif role == "MAINASSIST" or role == "DAMAGER" or role == "DPS" then
                    result = "DAMAGER"
                end
            end
        end

        -- Fallback: Check party assignments (Main Tank/Main Assist)
        --! WotLK fix: only meaningful while actually in a group. On some
        --! cores GetPartyAssignment("MAINTANK", "player") returns true when
        --! SOLO, painting a tank icon on any ungrouped character (tester:
        --! resto shaman solo in Dalaran showed a tank icon). Retail
        --! assignments only exist in groups; skip to spec-based detection.
        local grouped = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
        if grouped and (not result or details) then
            local isMainTank = GetPartyAssignment("MAINTANK", unit)
            local isMainAssist = GetPartyAssignment("MAINASSIST", unit)
            if details then
                details.mainTank = not not isMainTank
                details.mainAssist = not not isMainAssist
            end
            if not result then
                if isMainTank then
                    result = "TANK"
                    roleSource = "MainTank assignment"
                elseif isMainAssist then
                    result = "DAMAGER"
                    roleSource = "MainAssist assignment"
                end
            end
        end

        -- Fallback: talent-based detection via LibGroupInfo (specRole ONLY)
        if (not result or details) and not _cachedLGI and LibStub then
            _cachedLGI = LibStub:GetLibrary("LibGroupInfo", true)
        end
        local LibGroupInfo = _cachedLGI
        if LibGroupInfo and (not result or details) then
            local guid = UnitGUID(unit)
            if details then details.guid = guid end
            if guid then
                local cachedInfo = LibGroupInfo:GetCachedInfo(guid)
                if details then
                    details.lgiCached = not not cachedInfo
                    if cachedInfo then
                        details.lgiSpecRole = cachedInfo.specRole
                        details.lgiAssignedRole = cachedInfo.assignedRole
                        details.lgiInspected = cachedInfo.inspected
                        details.lgiSpecName = cachedInfo.specName
                    end
                end
                if not result and cachedInfo then
                    local specRole = cachedInfo.specRole
                    if specRole and specRole ~= "NONE" then
                        roleSource = "LibGroupInfo (spec-based)"
                        if specRole == "TANK" then
                            result = "TANK"
                        elseif specRole == "HEALER" then
                            result = "HEALER"
                        elseif specRole == "DAMAGER" or specRole == "MELEE" or specRole == "RANGED" then
                            result = "DAMAGER"
                        end
                    end
                end
            end
        end

        -- Final fallback: Default to DAMAGER if still no role detected
        -- This helps on custom servers like Ascension where spec detection may not work
        if not result then
            result = "DAMAGER"
            roleSource = "default fallback"
        end

        if details then
            details.finalRole = result
            details.source = roleSource
        end
        return result, roleSource, details
    end

    function Cell.UnitGroupRolesAssigned(unit)
        local result, roleSource = ResolveCellUnitRole(unit, false)
        if roleDebugEnabled then
            print(string.format("[Role Debug] %s -> %s (source: %s)",
                UnitName(unit) or unit, result, roleSource))
        end
        return result
    end

    --! WotLK fix: diagnostic-only role snapshot used by /cell debug roles.
    function Cell.GetUnitRoleDebugInfo(unit)
        local _, _, details = ResolveCellUnitRole(unit, true)
        return details
    end

    -- Debug command toggle - create sFuncs table if needed
    if _G.Cell then
        _G.Cell.sFuncs = _G.Cell.sFuncs or {}
        _G.Cell.sFuncs.ToggleRoleDebug = function()
            roleDebugEnabled = not roleDebugEnabled
            print(string.format("[Cell] Role debug: %s", roleDebugEnabled and "enabled" or "disabled"))
        end
    end
end

-- Cell.GetUnitClassToken
--! WotLK fix: keep the native global UnitClassBase completely untouched.
--! Blizzard_RaidUI consumes both of its return values (localized class name
--! and class file token); replacing it with Cell's one-value normalizer makes
--! RaidClassButton_OnEnter index RAID_SUBGROUP_LISTS[nil]. Cell consumers use
--! this private helper instead.
-- WotLK UnitClass returns (localizedName, fileName, classIndex).
--! Normalize the class token because some 3.3.5 servers/addons yield mixed
--! case ("Hunter") or a display name with spaces ("Death Knight"). Cell stores
--! the result in states.class and uses it as a table key (powerFilters,
--! RAID_CLASS_COLORS, click-casting spell lists).
do
    local nativeUnitClass = UnitClass

    local VALID_TOKENS = {
        WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true,
        PRIEST = true, DEATHKNIGHT = true, SHAMAN = true, MAGE = true,
        WARLOCK = true, DRUID = true,
    }

    -- lazy-built reverse map: localized class name -> canonical token
    local localizedToToken
    local function BuildLocalizedMap()
        localizedToToken = {}
        for _, source in pairs({LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE}) do
            if type(source) == "table" then
                for token, localizedName in pairs(source) do
                    if type(localizedName) == "string" and VALID_TOKENS[token] then
                        localizedToToken[string.upper(localizedName)] = token
                    end
                end
            end
        end
    end

    local function NormalizeClassToken(class, localizedName)
        --! perf fast-path: on 3.3.5 UnitClass() already returns a valid
        --! uppercase token ("MAGE", "DEATHKNIGHT") for virtually every call,
        --! so skip the upper/gsub allocations entirely (this runs on every
        --! unit button update - see SESSION_NOTES perf audit)
        if VALID_TOKENS[class] then
            return class
        end
        if type(class) == "string" then
            -- uppercase + strip spaces: "Death Knight"/"DEATH KNIGHT" -> "DEATHKNIGHT"
            local token = string.gsub(string.upper(class), "%s+", "")
            if VALID_TOKENS[token] then
                return token
            end
            -- non-English value (e.g. ruRU display name): try the reverse map
            if not localizedToToken then BuildLocalizedMap() end
            local mapped = localizedToToken[string.upper(class)]
            if mapped then
                return mapped
            end
        end
        -- last resort: reverse-map the localized first return of UnitClass
        if type(localizedName) == "string" then
            if not localizedToToken then BuildLocalizedMap() end
            local mapped = localizedToToken[string.upper(localizedName)]
            if mapped then
                return mapped
            end
        end
        -- give back *something* uppercase rather than a guaranteed-miss value
        if type(class) == "string" then
            return (string.gsub(string.upper(class), "%s+", ""))
        end
        return class
    end

    function Cell.GetUnitClassToken(unit)
        local localizedName, classFileName = nativeUnitClass(unit)
        return NormalizeClassToken(classFileName, localizedName)
    end
end

--! WotLK fix: GetSpellBookItemName and Ambiguate are not stock 3.3.5 APIs.
--! Their only active consumers bind private native-compatible adapters; do not
--! publish approximate global contracts that can redirect foreign addon paths.


-------------------------------------------------
--! WotLK fix: smoothing methods are mixed into Cell-owned status bars from the
--! active SmoothStatusBarMixin provider. Do not publish snap-only methods on the
--! shared StatusBar metatable for Blizzard and foreign addons.
-------------------------------------------------


--! WotLK fix: retail SetFromAlpha/SetToAlpha emulation was removed from the
--! shared Alpha metatable. Cell-owned absolute animations use the private
--! adapter in Widgets/Animation.lua, while foreign addons retain native
--! 3.3.5 SetChange(delta) behavior.

--! WotLK fix: Frame:HookScript is native on stock WoW 3.3.5a. Do not publish
--! a manual GetScript/SetScript wrapper on the shared Frame metatable: it changes
--! native hook ordering/error behavior and permanently retains the prior handler.

--! WotLK fix: Texture regions do not own frame scripts on 3.3.5. Do not add a
--! shared Texture:HookScript method that redirects handlers to the parent frame
--! (changing self/event ownership) or invokes them immediately when no parent
--! script exists. Cell's texture show/hide animation is driven by its owning
--! indicator frame instead.


--! WotLK fix: do not replace any shared secure frame-ref API. Native 3.3.5
--! exposes SecureHandlerSetFrameRef (without an underscore); Cell validates and
--! owns every reference at its call sites, so changing a foreign/global contract
--! merely to swallow invalid refs is both dead here and unsafe for coexistence.


--! WotLK fix: 3.3.5 Cooldown owns only SetCooldown and SetReverse. Do not
--! advertise retail swipe/edge/text methods as successful no-ops and do not wrap
--! Frame:SetScript client-wide for the unsupported OnCooldownDone handler. Cell's
--! cooldown instances own the small compatibility contract they actually use.


--! WotLK fix: 3.3.5 has no StatusBar:SetReverseFill. Do not advertise a
--! successful no-op on the shared StatusBar metatable. Cell's Wrath cooldown
--! bars explicitly render their reverse-fill effect with private overlays.


-------------------------------------------------
--! WotLK fix: Cell's FlipBook consumer uses a private SetTexCoord driver. Do
--! not publish ParentKey/ChildKey/FlipBook methods as successful shared no-ops.
-------------------------------------------------

--! WotLK fix: do not wrap the shared AnimationGroup:CreateAnimation method
--! for FlipBook. Cell's only FlipBook consumer was replaced with a private
--! SetTexCoord driver, so foreign addons keep the native 3.3.5 contract.


--! WotLK fix: 3.3.5 has no mask textures. Do not emulate CreateMaskTexture or
--! AddMaskTexture on shared widget metatables: fake mask objects cannot crop a
--! texture and changed the API seen by Blizzard and every addon. Cell's Wrath
--! consumers use explicit overlays, edge textures, or unmasked animation paths.

--! WotLK fix: true parent-alpha isolation is unavailable on 3.3.5. Do not
--! publish SetIgnoreParentAlpha/IsIgnoringParentAlpha state-only methods on
--! shared widget metatables. Wrath call sites now omit the ineffective request;
--! foreign addons can detect that the capability is genuinely unsupported.

--! WotLK fix: do not replace a foreign Cooldown:SetSwipeColor implementation.
--! Cell normalizes alpha only at its non-Wrath call sites and uses the native
--! 3.3.5 cooldown spiral on Wrath.

--! WotLK fix: the duplicate Polyfills timer engine was removed. Cell owns one
--! private timer namespace from ClassicAPI/Util/C_Timer.lua and never replaces
--! a standalone !!!ClassicAPI addon's global C_Timer implementation.
--! WotLK fix: локал `local C_Timer = Cell.C_Timer` остался от удалённого движка
--! и никем в файле не читался - единственный вызов таймера ниже полностью
--! квалифицирован (Cell.C_Timer.NewTicker). В Lua 5.1 у главного чанка всего 200
--! регистров, и файл занимал один впустую.

--! WotLK fix: active Cell spell-link consumers bind native GetSpellLink
--! directly. Do not create a partial global C_Spell namespace for foreign addons.

--! WotLK fix: Cell's range hot path binds native IsItemInRange directly and has
--! no active C_Item consumer. Do not publish a partial retail C_Item namespace
--! solely for unknown foreign addons; standalone !!!ClassicAPI keeps its owner.

-------------------------------------------------
-- NOTE: the global UnitAura override was removed on purpose.
-- Overriding globals affects every addon and adds overhead to a hot path.
-- Cell code goes through private Cell.UnitBuff/Cell.UnitDebuff adapters below.
-------------------------------------------------

-------------------------------------------------
-- UnitBuff/UnitDebuff wrappers for Cell (NOT global overrides)
-- WotLK returns: name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, shouldConsolidate, spellId
-- Retail returns: name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId, ...
-- We create Cell-specific wrappers instead of modifying the global API
-------------------------------------------------
--! WotLK fix: keep native aura references private. Publishing backup
--! UnitBuff/UnitDebuff references needlessly exposes and permanently roots
--! compatibility state in the shared addon namespace.
local nativeUnitBuff = UnitBuff
local nativeUnitDebuff = UnitDebuff

-- Create Cell namespace wrappers (don't override global)
if Cell then
    Cell.UnitBuff = function(unit, index, filter)
        local name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, shouldConsolidate, spellId = nativeUnitBuff(unit, index, filter)
        if not name then return nil end
        -- Return in retail format: name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId
        return name, icon, count, debuffType, duration, expirationTime, caster, isStealable, nil, spellId, nil, nil, nil, nil, nil, nil
    end

    Cell.UnitDebuff = function(unit, index, filter)
        local name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, shouldConsolidate, spellId = nativeUnitDebuff(unit, index, filter)
        if not name then return nil end
        return name, icon, count, debuffType, duration, expirationTime, caster, isStealable, nil, spellId, nil, nil, nil, nil, nil, nil
    end
end

--! WotLK fix: no active Cell path consumes C_UnitAuras. Do not publish a partial
--! retail namespace, allocate aura tables/slot lists, or advertise unsupported
--! private-aura anchors as successful no-ops.

--! WotLK fix: F.GetInstanceName reads native legacy zone APIs directly. The
--! embedded broad C_Map provider is inactive, so do not publish a duplicate
--! fallback that exposes the current global map selection as the player's zone.

--! WotLK fix: addon-message prefix registration is implicit on the pre-4.1
--! protocol. AceComm owns a private compatibility result and Cell macros call
--! native SendAddonMessage, so do not publish C_ChatInfo or a registration global.

--! WotLK fix: Cell has no Battle.net game-data consumer on 3.3.5. Do not
--! advertise a successful global BNSendGameData no-op to foreign libraries.

--! WotLK fix: Cell uses native addon-management APIs directly. Do not publish
--! a C_AddOns namespace or infer enable state from loaded state for foreign addons.

--! WotLK fix: LoadAddOn is native on stock 3.3.5a. Never replace a missing or
--! corrupted global with a fake success surface: foreign addons must retain the
--! client's real load-on-demand contract and failure reasons.

--! WotLK fix: do not publish an empty C_TooltipInfo data contract. Cell uses
--! native GameTooltip methods and no active code consumes retail tooltip data.

--! WotLK fix: GameTooltip:SetSpellByID is native on stock 3.3.5a. Do not create
--! a probe tooltip or add a second shared widget owner for this native method.

-- SOUNDKIT
--! WotLK fix: MERGE the defaults instead of the old all-or-nothing `if not SOUNDKIT`.
--! The standalone !!!ClassicAPI addon (Util/SoundKit.lua) creates SOUNDKIT before Cell
--! loads, but ships its own smaller set (10 keys in the copy checked here) with NO
--! U_CHAT_SCROLL_BUTTON - it spells that sound as GS_LOGIN_CHANGE_REALM_OK, and the
--! exact set differs per client. With the old guard Cell skipped its own table
--! entirely, so every button/checkbox PostClick called PlaySound(nil) and threw
--! "Usage: PlaySound(\"sound\")", which aborted the whole click chain: option
--! dropdowns appeared to accept a choice but never applied it.
--! Filling only the missing keys keeps whatever another addon already defined.
do
    local soundkitDefaults = {
        U_CHAT_SCROLL_BUTTON = "UChatScrollButton",
        IG_MAINMENU_OPTION_CHECKBOX_ON = "igMainMenuOptionCheckBoxOn",
        IG_MAINMENU_OPTION_CHECKBOX_OFF = "igMainMenuOptionCheckBoxOff",
        IG_MAINMENU_OPEN = "igMainMenuOpen",
        IG_MAINMENU_CLOSE = "igMainMenuClose",
        IG_ABILITY_PAGE_TURN = "igAbilityPageTurn",
        IG_CHARACTER_INFO_TAB = "igCharacterInfoTab",
        IG_BACKPACK_OPEN = "igBackPackOpen",
        IG_BACKPACK_CLOSE = "igBackPackClose",
    }
    if type(SOUNDKIT) ~= "table" then SOUNDKIT = {} end
    for k, v in pairs(soundkitDefaults) do
        if SOUNDKIT[k] == nil then SOUNDKIT[k] = v end
    end
end

--! WotLK fix: Cell has no active C_ClassTalents, C_Traits, or
--! C_SpecializationInfo consumer. Do not publish partial modern talent/spec
--! namespaces that can make foreign addons choose unsupported retail paths.

--! WotLK fix: the unsupported TargetCounter engine is already disabled on
--! Wrath and has no active C_NamePlate consumer. Do not publish an empty modern
--! namespace or allocate a fresh table on every foreign GetNamePlates call.

--! WotLK fix: SecureHandlerStateTemplate already owns native SetFrameRef.
--! Do not replace the shared secure-handler method table; Cell call sites pass
--! valid Cell-owned frames and foreign addons must retain Blizzard's contract.




--! WotLK fix: RegisterAttributeDriver is a later shared API with a different
--! attribute-name contract. Cell uses private adapters that strip "state-"
--! before delegating to native 3.3.5 RegisterStateDriver/UnregisterStateDriver;
--! never publish or replace the foreign-facing globals.
do
    local function ToStateName(attribute)
        if type(attribute) == "string" then
            return string.match(attribute, "^state%-(.+)$") or attribute
        end
        return attribute
    end

    function Cell.RegisterAttributeDriver(frame, attribute, state)
        return RegisterStateDriver(frame, ToStateName(attribute), state)
    end

    function Cell.UnregisterAttributeDriver(frame, attribute)
        return UnregisterStateDriver(frame, ToStateName(attribute))
    end
end

--! WotLK fix: F.IterateClasses uses the private sortedClasses list built through
--! Cell.GetClassInfoTuple. Do not publish a hard-coded GetNumClasses global
--! whose value can disagree with custom cores or foreign compatibility owners.

--! WotLK fix: the options UI binds its Chinese-font fallback privately. Do not
--! publish modern UNIT_NAME_FONT_* globals solely for Cell-owned font objects.

--! WotLK fix: Cell uses F.GetClassColor and private color-string helpers. Do not
--! publish a global GetClassColor contract solely for foreign addons.

--! WotLK fix: keep RAID_CLASS_COLORS entries as native plain tables. Cell and
--! its active backdrop adapter read r/g/b directly instead of publishing
--! GetRGB/GetRGBA methods through shared Blizzard objects.

--! WotLK fix: no active Cell code consumes the retail PLAYER_DIFFICULTY6
--! string. Do not publish a Mythic-era global on a 3.3.5 client.

--! WotLK fix: F.GetInstanceName reads native legacy zone APIs directly. Do not
--! publish partial MapUtil or Enum.UIMapType retail contracts to foreign addons.

--! WotLK fix: Cell leader/assistant ownership is private above. The shared
--! ClassicAPI group globals remain available to their own foreign consumers.

--! WotLK fix: removed the global PlaySound wrapper that used to live here.
--! It replaced the native C function with a Lua closure + pcall for the WHOLE
--! UI (FrameXML bags, spellbook, chat, auction house), silently dropped the
--! channel argument and swallowed errors. Cell only ever passes valid 3.3.5
--! string names from its own SOUNDKIT table above, so no wrapper is needed.

--! WotLK fix: GetNormalizedRealmName is not native on 3.3.5a. Keep Cell's
--! dash/space normalization private instead of publishing a shared global;
--! standalone !!!ClassicAPI and custom cores retain their own owners untouched.
function Cell.GetNormalizedRealmName()
    local realm = GetRealmName()
    if not realm then return "" end
    return (string.gsub(realm, "[-%s]", ""))
end

-- IsEncounterInProgress (doesn't exist in stock WotLK 3.3.5a)
--! WotLK fix: preserve a real custom-core/foreign implementation when present,
--! but keep stock fallback semantics private to Cell. Publishing a global that
--! always returns false makes other addons believe encounter state is supported.
do
    local nativeIsEncounterInProgress = IsEncounterInProgress
    function Cell.IsEncounterInProgress()
        if type(nativeIsEncounterInProgress) == "function" then
            return not not nativeIsEncounterInProgress()
        end
        return false
    end
end

--! WotLK fix: modern group helpers do not exist in stock 3.3.5a. Keep Cell's
--! contract private and derive it only from verified native roster APIs. Do not
--! depend on or replace standalone !!!ClassicAPI/custom-core global owners.
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

    local function GetUnitRaidRank(unit)
        local raidIndex = UnitInRaid(unit)
        if raidIndex then
            local _, rank = GetRaidRosterInfo(raidIndex + 1)
            return rank
        end
    end

    function Cell.UnitIsGroupLeader(unit)
        if Cell.IsInRaid() then
            return GetUnitRaidRank(unit) == 2
        end
        if GetNumPartyMembers() <= 0 then return false end
        if UnitIsUnit(unit, "player") then
            return IsPartyLeader("player") and true or false
        end
        local leaderIndex = GetPartyLeaderIndex()
        return leaderIndex > 0 and UnitIsUnit(unit, "party"..leaderIndex) or false
    end

    function Cell.UnitIsGroupAssistant(unit)
        return GetUnitRaidRank(unit) == 1
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
        assistantTicker = Cell.C_Timer.NewTicker(0.2, function(ticker)
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
--! WotLK fix: the global GROUP_ROSTER_UPDATE compatibility proxy was removed.
--! Core_Wrath.lua owns PARTY_MEMBERS_CHANGED / RAID_ROSTER_UPDATE and emits one
--! private Cell "GroupRosterUpdate" callback. Cell no longer hooks shared Frame
--! metatables or synthesizes a non-native event for itself or other addons.
-------------------------------------------------

-------------------------------------------------
--! WotLK fix: Cell heal prediction now consumes LibHealComm privately inside
--! UnitButton_Cata_Wrath.lua. The former global UnitGetIncomingHeals override,
--! synthetic UNIT_HEAL_PREDICTION bridge, and repaint clock were removed.
--! Shield absorbs are likewise tracked privately in that unit-button module;
--! Cell no longer publishes UnitGetTotalAbsorbs or runs a second monitor.
-------------------------------------------------

--! WotLK fix: Cell uses native FillLocalizedClassList and its private
--! Cell.GetClassInfoTuple adapter. Do not publish an unused LocalizedClassList
--! global solely for foreign retail-style callers.

--! WotLK fix: Cell no longer needs global Mixin/CreateFromMixins helpers. Its
--! smoothing consumers copy Cell.SmoothStatusBarMixin privately; any standalone
--! !!!ClassicAPI/custom-core owner remains completely untouched.

-------------------------------------------------
--! WotLK fix: Button/EditBox/Slider SetEnabled adapters are owned by WidgetAPI.
--! Do not probe the generic Frame metatable here: plain Frames have no enable
--! contract on 3.3.5.
--! 2026-08-08: the previous note claimed "inherited Button behavior already
--! covers CheckButton". That was false. Each 3.3.5 widget type owns a separate
--! __index table, and WidgetAPI's manifest loop only instantiates the classes
--! listed in its UIObject table (Frame/Texture/FontString/Button/EditBox/Slider),
--! so the CheckButton metatable was never processed. Without an external
--! !!!ClassicAPI every options pane aborted on its first checkbox (P0-B2 run,
--! session 51). Cell.CreateCheckButton in Widgets.lua now owns the adapter on
--! its own instances; the shared CheckButton metatable stays untouched.
-------------------------------------------------

-------------------------------------------------
--! WotLK fix: Cell has no SimpleHTML:GetContentHeight consumer. Do not publish
--! a frame-height approximation as rendered content height on the shared widget.
-------------------------------------------------

-------------------------------------------------
--! WotLK fix: do not replace the shared native Slider:SetValue/SetScript methods
--! to synthesize retail's OnValueChanged userChanged argument. Cell's own sliders
--! track programmatic SetValue calls on their instances in Widgets.lua and
--! ColorPicker.lua; Blizzard and foreign addon sliders keep the native contract.
-------------------------------------------------

-------------------------------------------------
-- REMOVED: All global font polyfills and hooks
-- They were masking the root cause, not fixing it
-------------------------------------------------

-------------------------------------------------
--! WotLK fix: removed the leftover SetFont/SetFontObject debug hooks (and the
--! /celldebug slash command) that used to live here. SetFont/SetFontObject are
--! native FontInstance methods on 3.3.5, and the hooks sat on the SHARED
--! FontString metatable: every font change in FrameXML and in every other addon
--! paid a Lua frame + GetParent + 2x GetName + debugstack(2,3,0) + 6 string.match.
-------------------------------------------------

-- Fonts
-- NOTE: Font objects are created in Widgets/Widgets.lua and Indicators/Built-in.lua
-- No need to pre-create them here since no code uses them before those files load
-- Removed redundant font creation that was causing conflicts with STANDARD_TEXT_FONT vs GameFontNormal

--! WotLK fix: plain Frame:Run is not a secure execution primitive on 3.3.5.
--! Cell uses native secure control-handle methods (RunFor/RunAttribute) instead;
--! publishing a loadstring-based method through the shared Frame metatable would
--! provide the wrong contract to Cell and every foreign addon.

--! WotLK fix: CellMainFrame visibility is owned by MainFrame.lua and the minimap
--! toggle. Do not keep an ADDON_LOADED listener or delayed callbacks that force a
--! protected frame shown and undo an explicit user hide.

-------------------------------------------------
--! WotLK fix: do not add delayed wrappers around Cell-owned PixelPerfect or
--! RotateTexture functions. Their active callers pass concrete Cell widgets;
--! masking a nil input would hide the real caller defect while retaining nine
--! wrapper closures, an ADDON_LOADED frame, and three startup timers.
-------------------------------------------------

-------------------------------------------------
--! WotLK fix: removed delayed wrappers around Cell.bFuncs.SetOrientation and
--! SetPowerSize. They were installed four times after ADDON_LOADED, built nested
--! call chains, and silently skipped valid Cell unit buttons. These functions are
--! Cell-owned and receive complete CellUnitButtonTemplate widgets at their callers.
-------------------------------------------------

--! WotLK fix: do not wrap shared AnimationGroup:CreateAnimation merely to
--! repair another addon's nil argument. Cell now always passes its own native
--! animation type explicitly and leaves foreign widget contracts untouched.

-------------------------------------------------
--! WotLK fix: removed the late AutoCastGlow_Start replacement. The Cell fork of
--! LibCustomGlow initializes and validates its own animation state before use;
--! replacing the library field after consumers captured it created two contracts.
-------------------------------------------------

-------------------------------------------------
-- Click-Castings Fixes
-------------------------------------------------
do


    -- Fix 1: ScrollFrame eats clicks
    --! WotLK fix: these two patch helpers were global. On 3.3.5 every addon
    --! shares one _G, so unprefixed names like PatchCreateScrollFrame /
    --! PatchBindingListButton can be clobbered by any other addon. Both are
    --! only called at the bottom of this same do-block, so make them local.
    local function PatchCreateScrollFrame()
        if not Cell or not Cell.CreateScrollFrame then return end
        if Cell._ScrollFramePatchedForBindings then return end
        Cell._ScrollFramePatchedForBindings = true

        local orig_CreateScrollFrame = Cell.CreateScrollFrame
        Cell.CreateScrollFrame = function(parent, top, bottom, color, border)
            local ret = orig_CreateScrollFrame(parent, top, bottom, color, border)

            if parent:GetName() == "ClickCastingsTab_BindingsFrame" then
                local scroll = parent.scrollFrame
                if scroll then
                    if scroll.EnableMouse then scroll:EnableMouse(false) end
                    if scroll.content and scroll.content.EnableMouse then scroll.content:EnableMouse(true) end
                end
            end
            
            return ret
        end
    end

    -- Fix 2: BindingListButton grids have too low frame level (6 vs 530+)
    local function PatchBindingListButton()
        if not Cell or not Cell.CreateBindingListButton then return end
        if Cell._BindingListButtonPatched then return end
        Cell._BindingListButtonPatched = true

        local orig_CreateBindingListButton = Cell.CreateBindingListButton
        Cell.CreateBindingListButton = function(parent, modifier, bindKey, bindType, bindAction)
            local b = orig_CreateBindingListButton(parent, modifier, bindKey, bindType, bindAction)
            
            -- Fix frame levels of grids
            local level = b:GetFrameLevel() + 1
            if b.keyGrid then b.keyGrid:SetFrameLevel(level) end
            if b.typeGrid then b.typeGrid:SetFrameLevel(level) end
            if b.actionGrid then b.actionGrid:SetFrameLevel(level) end
            
            return b
        end
    end

    -- Fix 3: GetClickCastingSpellList fails with mixed-case class names
    -- + PRIEST list is missing Binding Heal (base id 32546; the list uses
    --   rank-1 ids and F.GetMaxSpellRank resolves the top rank, 48120 on 3.3.5)
    local missingSpells = {
        ["PRIEST"] = {
            { id = 32546, after = 2060 }, -- Binding Heal, after Greater Heal
        },
    }

    local function PatchGetClickCastingSpellList()
        if not Cell or not Cell.funcs or not Cell.funcs.GetClickCastingSpellList then return end
        if Cell._GetClickCastingSpellListPatched then return end
        Cell._GetClickCastingSpellListPatched = true

        local orig_GetClickCastingSpellList = Cell.funcs.GetClickCastingSpellList
        Cell.funcs.GetClickCastingSpellList = function(class, ...)
            if class and type(class) == "string" then
                class = string.upper(class)
            end
            local spells = orig_GetClickCastingSpellList(class, ...)

            local missing = spells and missingSpells[class]
            if missing then
                local F = Cell.funcs
                for _, m in ipairs(missing) do
                    local present, insertAt
                    for i, t in ipairs(spells) do
                        if t[4] == m.id then
                            present = true
                            break
                        end
                        if t[4] == m.after then
                            insertAt = i + 1
                        end
                    end
                    if not present then
                        local name, icon = F.GetSpellInfo(m.id)
                        if name then -- spell known to the client
                            -- same entry shape as the original builder:
                            -- {icon, name, spellType, spellId, maxRank}
                            local rank = F.GetMaxSpellRank and F.GetMaxSpellRank(m.id) or nil
                            tinsert(spells, insertAt or (#spells + 1), {icon, name, nil, m.id, rank})
                        end
                    end
                end
            end

            return spells
        end
    end

    --! WotLK fix: the old PatchAnimationSystem replaced the shared native
    --! AnimationGroup:Play/CreateAnimation methods for the entire client.
    --! Cell now owns absolute Alpha/Scale animation behavior privately.

    --! WotLK fix: LibCustomGlow is corrected in its own source. Do not replace
    --! AutoCastGlow_Start later from Polyfills.lua; local consumers may already
    --! hold the original function and would otherwise observe another contract.

    -- Add to the event handler
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Cell" then
            PatchCreateScrollFrame()
            PatchBindingListButton()
            PatchGetClickCastingSpellList()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)

end

--! WotLK fix: assistant batching and state are owned privately by Cell above.
--! Cell has no BackdropTemplate consumer; live backdrop calls stay on native
--! 3.3.5 Frame methods and no retail template fallback is published here.

-------------------------------------------------
-- WotLK 3.3.5a: Button creation and positioning now handled inline in PartyFrame.lua and RaidFrame.lua
-------------------------------------------------

-------------------------------------------------
--! WotLK fix: do not replace Blizzard's global SecureGroupHeader_Update.
--! Native 3.3.5 FrameXML calls that global from protected header event and
--! attribute paths, including during combat; replacing it taints the entire
--! secure update route even when forwarding to the original function. Cell's
--! assigned-role ordering is supplied through the native nameList attribute in
--! RaidFrame.lua instead.
-------------------------------------------------
