--[[
    Locale Loader for Cell_Wrath
    
    This module manages locale selection, allowing users to override
    the game client's locale via saved variables.
]]

-- Use the addon namespace table which becomes _G.Cell in Core_Wrath.lua
local addonName, ns = ...

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

-- Cache the current locale to avoid repeated lookups
local currentLocale = nil

-- Get the current locale (user-selected or client default)
function ns.GetCurrentLocale()
    if currentLocale then
        return currentLocale
    end
    
    -- Try to get from saved variables (CellDB may not be loaded yet during initial load)
    if CellDB and CellDB["general"] and CellDB["general"]["locale"] then
        currentLocale = CellDB["general"]["locale"]
    else
        -- Fall back to client locale
        currentLocale = GetLocale()
    end
    
    return currentLocale
end

-- Set the locale (called from UI, requires reload to take effect)
function ns.SetLocale(locale)
    if CellDB and CellDB["general"] then
        CellDB["general"]["locale"] = locale
        -- Clear the cache so next load picks up the new value
        currentLocale = nil
    end
end

-- Get display name for a locale code
function ns.GetLocaleDisplayName(localeCode)
    for _, loc in ipairs(ns.availableLocales) do
        if loc.code == localeCode then
            return loc.name
        end
    end
    return localeCode or "Auto (Client)"
end
