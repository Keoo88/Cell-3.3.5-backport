-- Debug module for tracking callback registrations and executions
-- Note: Cell is set as a global in Core_Wrath.lua which loads before this file

-- Wait for Cell to be available (it's created in Core_Wrath.lua)
if not _G.Cell then
    print("[Cell Debug] WARNING: Cell global not found during load. This should load after Core_Wrath.lua")
    return
end

local Cell = _G.Cell
Cell.Debug = {}

-- Debug flags (can be toggled via /cell debug)
Cell.Debug.enabled = false
Cell.Debug.verboseCallbacks = false
Cell.Debug.trackRegistrations = true
Cell.Debug.trackFires = true

-- Storage for tracking
Cell.Debug.registrations = {}
Cell.Debug.fires = {}
Cell.Debug.stats = {
    totalRegistrations = 0,
    totalFires = 0,
    missedCallbacks = {}
}

-- Color codes for output
local COLOR_INFO = "|cff00ff00"    -- Green
local COLOR_WARN = "|cffffff00"    -- Yellow
local COLOR_ERROR = "|cffff0000"   -- Red
local COLOR_DEBUG = "|cff00ffff"   -- Cyan
local COLOR_RESET = "|r"

-- Debug print function
function Cell.Debug:Print(category, message, color)
    if not self.enabled then return end
    
    color = color or COLOR_INFO
    local timestamp = date("%H:%M:%S")
    
    print(string.format("[Cell Debug][%s][%s] %s%s%s", 
        timestamp, 
        category, 
        color, 
        message, 
        COLOR_RESET))
end

-- Track callback registration
function Cell.Debug:TrackRegistration(event, identifier, func)
    if not self.trackRegistrations then return end
    
    if not self.registrations[event] then
        self.registrations[event] = {}
    end
    
    table.insert(self.registrations[event], {
        identifier = identifier,
        hasFunc = func ~= nil,
        timestamp = time()
    })
    
    self.stats.totalRegistrations = self.stats.totalRegistrations + 1
    
    if self.verboseCallbacks then
        self:Print("REGISTER", 
            string.format("Event: %s, ID: %s, HasFunc: %s", 
                event, identifier, tostring(func ~= nil)),
            COLOR_DEBUG)
    end
end

-- Track callback fire
function Cell.Debug:TrackFire(event, ...)
    if not self.enabled or not self.trackFires then return end
    
    -- Count fires
    self.fires[event] = (self.fires[event] or 0) + 1
    self.stats.totalFires = self.stats.totalFires + 1
    
    -- Check if there are any listeners
    local listenerCount = Cell.GetEventListenersCount and Cell.GetEventListenersCount(event) or 0
    
    if self.verboseCallbacks then
        self:Print("FIRE", string.format("%s | listeners: %d", event, listenerCount), COLOR_INFO)
    end
    
    -- Track as potentially missed if no listeners
    if listenerCount == 0 then
        if not self.stats.missedCallbacks[event] then
            self.stats.missedCallbacks[event] = 0
        end
        self.stats.missedCallbacks[event] = self.stats.missedCallbacks[event] + 1
    end
end

-- Report statistics
function Cell.Debug:Report()
    print(COLOR_INFO .. "=== Cell Debug Report ===" .. COLOR_RESET)
    print(string.format("Total Registrations: %d", self.stats.totalRegistrations))
    print(string.format("Total Fires: %d", self.stats.totalFires))
    
    print(COLOR_DEBUG .. "\nRegistered Events:" .. COLOR_RESET)
    for event, registrations in pairs(self.registrations) do
        print(string.format("  %s: %d registration(s)", event, #registrations))
        if self.verboseCallbacks then
            for i, reg in ipairs(registrations) do
                print(string.format("    - %s (func: %s)", reg.identifier, tostring(reg.hasFunc)))
            end
        end
    end
    
    print(COLOR_DEBUG .. "\nFired Events:" .. COLOR_RESET)
    for event, count in pairs(self.fires) do
        local regCount = self.registrations[event] and #self.registrations[event] or 0
        local color = regCount > 0 and COLOR_INFO or COLOR_WARN
        print(string.format("  %s%s: %d time(s) (listeners: %d)%s", 
            color, event, count, regCount, COLOR_RESET))
    end
    
    if next(self.stats.missedCallbacks) then
        print(COLOR_WARN .. "\nPotentially Missed Callbacks:" .. COLOR_RESET)
        for event, count in pairs(self.stats.missedCallbacks) do
            print(string.format("  %s: %d time(s)", event, count))
        end
    end
    
    print(COLOR_INFO .. "======================" .. COLOR_RESET)
end

-- Clear all tracking data
function Cell.Debug:Clear()
    self.registrations = {}
    self.fires = {}
    self.stats = {
        totalRegistrations = 0,
        totalFires = 0,
        missedCallbacks = {}
    }
    self:Print("SYSTEM", "Debug data cleared", COLOR_INFO)
end

-- Handle debug commands
function Cell.Debug:HandleCommand(option)
    if option == "verbose" or option == "v" then
        self.verboseCallbacks = not self.verboseCallbacks
        print(string.format("Cell Debug: Verbose mode %s", 
            self.verboseCallbacks and "enabled" or "disabled"))
    elseif option == "report" or option == "r" then
        self:Report()
    elseif option == "clear" or option == "c" then
        self:Clear()
    elseif option == "dump" or option == "d" then
        self:Dump()
    elseif option == "help" or option == "h" then
        print(COLOR_INFO .. "Cell Debug Commands:" .. COLOR_RESET)
        print("  /cell debug - Toggle debug mode")
        print("  /cell debug v|verbose - Toggle verbose logging")
        print("  /cell debug r|report - Show debug report")
        print("  /cell debug c|clear - Clear debug data")
        print("  /cell debug d|dump - Open a copyable diagnostic dump (for bug reports)")
        print("  /cell debug h|help - Show this help")
    else
        self.enabled = not self.enabled
        print(string.format("Cell Debug: %s", 
            self.enabled and "enabled" or "disabled"))
    end
end

-------------------------------------------------
-- Diagnostic dump (/cell debug dump)
-- Builds a full state report and shows it in a window with an EditBox so
-- testers can copy it (Ctrl+A, Ctrl+C) and paste it into a bug report.
-- Works even when debug mode is disabled; fire counters are only collected
-- while debug mode is enabled, so toggle /cell debug before reproducing.
-------------------------------------------------

local dumpFrame

local function GetDumpFrame()
    if dumpFrame then return dumpFrame end

    local f = CreateFrame("Frame", "CellDebugDumpFrame", UIParent)
    f:SetSize(560, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText("Cell Debug Dump - Ctrl+A, Ctrl+C")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local scroll = CreateFrame("ScrollFrame", "CellDebugDumpScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -28)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)

    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetMultiLine(true)
    eb:SetMaxLetters(0)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(510)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)
    -- the box exists only for copying: restore the text if the user types
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(f.reportText or "")
            self:HighlightText()
        end
    end)
    scroll:SetScrollChild(eb)
    f.editBox = eb

    table.insert(UISpecialFrames, "CellDebugDumpFrame") -- close on ESC

    dumpFrame = f
    return f
end

local function AddUnitLines(lines, unit)
    if not UnitExists(unit) then return end

    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    local level = UnitLevel(unit)
    local role = Cell_UnitGroupRolesAssigned and Cell_UnitGroupRolesAssigned(unit) or "?" --! WotLK fix: Cell-private role polyfill (global stays native)
    table.insert(lines, string.format("%s: %s (%s, lvl %s) role=%s",
        unit, tostring(name), tostring(class), tostring(level), tostring(role)))

    local LGI = LibStub and LibStub:GetLibrary("LibGroupInfo", true)
    local guid = UnitGUID(unit)
    if LGI and guid and LGI.GetCachedInfo then
        local info = LGI:GetCachedInfo(guid)
        if info then
            -- shallow-dump scalar fields, whatever the cache structure is
            local parts = {}
            for k, v in pairs(info) do
                local t = type(v)
                if t == "string" or t == "number" or t == "boolean" then
                    table.insert(parts, tostring(k) .. "=" .. tostring(v))
                end
            end
            table.sort(parts)
            table.insert(lines, "    LGI: " .. table.concat(parts, ", "))
        else
            table.insert(lines, "    LGI: no cached info")
        end
    end
end

function Cell.Debug:BuildDumpText()
    local lines = {}
    table.insert(lines, "=== Cell Debug Dump ===")
    table.insert(lines, date("%Y-%m-%d %H:%M:%S"))

    local version, build = GetBuildInfo()
    table.insert(lines, string.format("client: %s (build %s)", tostring(version), tostring(build)))
    local cellVer = GetAddOnMetadata and GetAddOnMetadata("Cell", "Version")
    table.insert(lines, "Cell version: " .. tostring(cellVer))

    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
        table.insert(lines, string.format("memory: %.0f KB", GetAddOnMemoryUsage("Cell")))
    end

    -- own talents: name(backgroundFileName)=points per tab
    if GetNumTalentTabs and GetTalentTabInfo then
        local tabs = {}
        for i = 1, GetNumTalentTabs() do
            local tname, _, points, background = GetTalentTabInfo(i)
            table.insert(tabs, string.format("%s(%s)=%d",
                tostring(tname), tostring(background), points or 0))
        end
        table.insert(lines, "player talents: " .. table.concat(tabs, ", "))
    end

    local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    table.insert(lines, "")
    table.insert(lines, string.format("group: raid=%d party=%d", numRaid, numParty))
    if numRaid > 0 then
        for i = 1, numRaid do
            AddUnitLines(lines, "raid" .. i)
        end
    else
        AddUnitLines(lines, "player")
        for i = 1, numParty do
            AddUnitLines(lines, "party" .. i)
        end
    end

    table.insert(lines, "")
    table.insert(lines, string.format("callbacks: registrations=%d fires=%d (fires counted only while debug mode is ON)",
        self.stats.totalRegistrations, self.stats.totalFires))
    for event, registrations in pairs(self.registrations) do
        table.insert(lines, string.format("  reg %s: %d", event, #registrations))
    end
    for event, count in pairs(self.fires) do
        local listeners = Cell.GetEventListenersCount and Cell.GetEventListenersCount(event) or -1
        table.insert(lines, string.format("  fired %s: %d (listeners now: %d)", event, count, listeners))
    end
    if next(self.stats.missedCallbacks) then
        table.insert(lines, "  MISSED (fired with 0 listeners):")
        for event, count in pairs(self.stats.missedCallbacks) do
            table.insert(lines, string.format("    %s: %d", event, count))
        end
    end

    table.insert(lines, "=== end of dump ===")
    return table.concat(lines, "\n")
end

function Cell.Debug:Dump()
    local f = GetDumpFrame()
    f.reportText = self:BuildDumpText()
    f.editBox:SetText(f.reportText)
    f:Show()
    f.editBox:HighlightText()
    f.editBox:SetFocus()
end
