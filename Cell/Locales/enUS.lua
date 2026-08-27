-- self == L
-- rawset(t, key, value)
-- Sets the value associated with a key in a table without invoking any metamethods
-- t - A table (table)
-- key - A key in the table (cannot be nil) (value)
-- value - New value to set for the key (value)
select(2, ...).L = setmetatable({
    ["target"] = "Target",
    ["focus"] = "Focus",
    ["assist"] = "Assist",
    ["togglemenu"] = "Menu",
    ["togglemenu_nocombat"] = "Menu (not in combat)",
    ["T"] = "Talent",
    ["C"] = "Class",
    ["S"] = "Spec",
    ["H"] = "Hero",
    ["P"] = "PvP",
    ["notBound"] = "|cff777777".._G.NOT_BOUND,

    ["PET"] = "Pet",
    ["VEHICLE"] = "Vehicle",

    ["showGroupNumber"] = "Show group number",
    ["showTimer"] = "Show timer",
    ["showBackground"] = "Show background",
    ["dispellableByMe"] = "Only show debuffs dispellable by me",
    ["showDispelTypeIcons"] = "Show dispel type icons",
    ["castByMe"] = "Only show buffs cast by me",
    ["buffByMe"] = "Only show buffs I can apply",
    ["trackByName"] = "Track by name",
    ["showDuration"] = "Show duration text",
    ["showAnimation"] = "Show animation",
    ["showStack"] = "Show stack text",
    ["showTooltip"] = "Show aura tooltip",
    ["enableHighlight"] = "Highlight unit button",
    ["hideIfEmptyOrFull"] = "Hide if empty/full",
    ["onlyShowTopGlow"] = "Only show glow for the first debuff",
    --! WotLK fix: собственные настройки бэкпорта. Без строки здесь метатаблица
    --! enUS вернула бы сам ключ, и в панели стояло бы "showGlow"/"hideForTanks".
    ["showGlow"] = "Blinking glow",
    ["hideForTanks"] = "Do not show for tanks",
    --! WotLK fix: showJump раньше дописывался врезкой в Modules/Indicators/Indicators.lua
    --! по GetLocale(). Врезка знала локаль КЛИЕНТА и ничего не знала про собственный
    --! переключатель языка Cell (CellDB.general.locale -> LoadUserLocale), поэтому при
    --! несовпадении этих двух значений подпись оставалась на языке клиента, а вся панель
    --! вокруг - на выбранном. Ключ живёт в файлах локалей, как showGlow и hideForTanks.
    ["showJump"] = "Show refresh (jump) animation",
    ["hideDamager"] = "Hide Damager",
    ["hideInCombat"] = "Hide in combat",
    ["stackFont"] = "Stack Font",
    ["durationFont"] = "Duration Font",
    ["fadeOut"] = "Fade out over time",
    ["shieldByMe"] = "Only show PW:S cast by me",
    ["onlyShowOvershields"] = "Only show overshields",
    ["showAllSpells"] = "Show all spells",
    ["enableBlacklistShortcut"] = "Blacklist: Alt+Ctrl+RightClick",
    ["smooth"] = "Smooth",
    ["onlyEnableNotInCombat"] = "Only when I'm not in combat",

    ["BOTTOM"] = "Bottom",
    ["BOTTOMLEFT"] = "Bottom Left",
    ["BOTTOMRIGHT"] = "Bottom Right",
    ["CENTER"] = "Center",
    ["LEFT"] = "Left",
    ["RIGHT"] = "Right",
    ["TOP"] = "Top",
    ["TOPLEFT"] = "Top Left",
    ["TOPRIGHT"] = "Top Right",

    ["left-to-right"] = "Left to Right",
    ["right-to-left"] = "Right to Left",
    ["top-to-bottom"] = "Top to Bottom",
    ["bottom-to-top"] = "Bottom to Top",

    ["ALL"] = "All",
    ["INVERT"] = "Invert",
    ["Default"] = _G.DEFAULT,

    ["ABOUT"] = "Cell is a nice raid frame addon inspired by several great addons, such as CompactRaid, Grid2, Aptechka and VuhDo.\nWith a more human-friendly interface, Cell can provide a better user experience, better than ever.",
    ["RESET"] = "Cell requires a full reset after updating from a very old version",
    ["RESET_CHARACTER"] = "Cell requires a character profile reset after updating from a very old version",
    ["RESET_INCLUDES"] = "Only Click-Castings and Layout Auto Switch are included",
    ["RESET_YES_NO"] = "|cff22ff22Yes|r - Reset Cell\n|cffff2222No|r - I'll fix it myself",

    ["syncTips"] = "Set the master layout here\nAll indicators of slave layout are fully in-sync with the master\nIt's a two-way sync, but all indicators of slave layout will be lost when set a master",
    ["readyCheckTips"] = "\n|rReady Check\nLeft-Click: |cffffffffinitiate a ready check|r\nRight-Click: |cffffffffstart a role check|r",
    ["pullTimerTips"] = "\n|rPull Timer\nLeft-Click: |cffffffffstart timer|r\nRight-Click: |cffffffffcancel timer|r",
    ["marksTips"] = "\n|rTarget marker\nLeft-Click: |cffffffffset raid marker on target|r\nRight-Click: |cfffffffflock raid marker on target (in your group)|r",
    ["cleuAurasTips"] = "Check CLEU events for invisible auras",
    ["raidRosterTips"] = "[Right-Click] promote/demote (assistant). [Alt+Right-Click] uninvite.",

    ["RAID_DEBUFFS_TIPS"] = "Tips: [Drag & Drop] to change debuff order. [Double-Click] on instance name to open Encounter Journal. [Shift+Left Click] on instance/boss name to share debuffs. [Alt+Left Click] on instance/boss name to reset debuffs. The priority of General Debuffs is higher than Boss Debuffs.",
    ["SNIPPETS_TIPS"] = "[Double-Click] to rename. [Shift-Click] to delete. All checked snippets will be automatically invoked at the end of Cell initialization process (in ADDON_LOADED event).",
    ["BACKUP_TIPS"] = "Backups are not always reliable, especially when they are too old. It is recommended to backup often. When sharing profiles, backups are not included.",
    ["BACKUP_TIPS2"] = "Note for Classic players: Backups do not include Click-Castings and Layout Auto Switch of other characters",

    --! WotLK fix: тексты ["CHANGELOGS"] и ["OLDER_CHANGELOGS"] удалены по решению
    --! владельца (GAP-087): окна «Что нового» в сборке нет вообще - ни файла
    --! Modules/About/Changelogs.lua, ни кнопки в «О Cell», ни авто-попапа, - а 130 КБ
    --! истории ретейл-версий upstream (вместе с zhCN) грузились в память при каждом
    --! входе впустую. Случайное чтение ключа не упадёт: __index ниже возвращает само
    --! имя ключа.
}, {
    __index = function(self, Key)
        if (Key ~= nil) then
            rawset(self, Key, Key)
            return Key
        end
    end
})

---------------------------------------------------------------------
-- Locale Management (Merged from Loader.lua)
---------------------------------------------------------------------

-- Use the addon namespace table which becomes _G.Cell in Core_Wrath.lua
local addonName, ns = ...

-- Locale Registry
ns.localeLoaders = {}
function ns.RegisterLocale(locale, func)
    ns.localeLoaders[locale] = func
end

function ns.LoadUserLocale()
    local locale = nil
    if CellDB and CellDB["general"] then
        locale = CellDB["general"]["locale"]
    end
    
    -- Default to client locale if not set or nil (Auto)
    locale = locale or GetLocale()

    -- 1. Always run enUS first (base)
    -- enUS is ALREADY loaded immediately by this file (enUS.lua logic runs on load)
    
    -- 2. Run target locale if exists and not enUS (since enUS is base)
    if locale ~= "enUS" and ns.localeLoaders[locale] then
        ns.localeLoaders[locale]()
    end

    --! WotLK fix: changing locale already requires /reload, so keeping every
    --! non-selected locale chunk reachable for the whole session only retains
    --! compiled closures and their constants without a valid later caller.
    ns.localeLoaders = nil
    ns.RegisterLocale = nil
end

-- Available locales with display names
ns.availableLocales = {
    { code = nil,    name = "Auto (Client)" },
    { code = "enUS", name = "English" },
    { code = "deDE", name = "Deutsch (German)" },
    { code = "esES", name = "Español (Spanish)" },
    { code = "esMX", name = "Español Mexicano" },
    { code = "frFR", name = "Français (French)" },
    { code = "itIT", name = "Italiano (Italian)" },
    { code = "koKR", name = "한국어 (Korean)" },
    { code = "ptBR", name = "Português (Brazilian)" },
    { code = "ruRU", name = "Русский (Russian)" },
    { code = "zhCN", name = "简体中文 (Simplified Chinese)" },
    { code = "zhTW", name = "繁體中文 (Traditional Chinese)" },
}

-- UI Helper: Get the current selected locale (for Options dropdown)
function ns.GetCurrentLocale()
    if CellDB and CellDB["general"] and CellDB["general"]["locale"] then
        return CellDB["general"]["locale"]
    end
    return GetLocale()
end

-- UI Helper: Set the locale (requires reload)
function ns.SetLocale(locale)
    if CellDB and CellDB["general"] then
        CellDB["general"]["locale"] = locale
    end
end

-- UI Helper: Get Display Name
function ns.GetLocaleDisplayName(localeCode)
    for _, loc in ipairs(ns.availableLocales) do
        if loc.code == localeCode then
            return loc.name
        end
    end
    return localeCode or "Auto (Client)"
end