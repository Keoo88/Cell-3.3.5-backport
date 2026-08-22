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
--! WotLK fix: registration/fire instrumentation is opt-in with debug mode.
--! Keeping registration tracking enabled at startup allocated one table and
--! called time() for every static Cell.RegisterCallback even when debugging was off.
Cell.Debug.trackRegistrations = false
Cell.Debug.trackFires = false

-- Storage for tracking
Cell.Debug.registrations = {}
Cell.Debug.fires = {}
Cell.Debug.stats = {
    totalRegistrations = 0,
    totalFires = 0,
    missedCallbacks = {}
}

--! WotLK fix: in-memory ring buffer for /cell debug log.
--! Kept independent of Cell.Debug.enabled so the user can run with debug OFF
--! and still capture the last N interesting events; toggle it explicitly
--! with /cell debug log on. The buffer survives across the same session
--! (Lua state) but is not persisted.
Cell.Debug.Ring = {
    enabled = false,
    max = 500,
    buffer = {},
}

--! WotLK fix: cheap push for the ring. Skip when disabled, otherwise
--! append with a timestamp and trim from the head if the buffer is full.
--! O(1) amortized; called from TrackFire/Print/Animation stop queue.
function Cell.Debug.RingPush(category, msg)
    if not Cell.Debug.Ring.enabled then return end
    local buf = Cell.Debug.Ring.buffer
    local n = #buf
    local entry = string.format("%s [%s] %s", date("%H:%M:%S"), tostring(category), tostring(msg))
    if n >= Cell.Debug.Ring.max then
        -- bulk-shift by 10% when full: cheaper than per-push table.remove
        local drop = math.floor(Cell.Debug.Ring.max / 10) + 1
        for i = drop + 1, n do
            buf[i - drop] = buf[i]
        end
        for i = n - drop + 1, n do buf[i] = nil end
        buf[#buf + 1] = entry
    else
        buf[n + 1] = entry
    end
end

-- Color codes for output
local COLOR_INFO = "|cff00ff00"    -- Green
local COLOR_WARN = "|cffffff00"    -- Yellow
local COLOR_ERROR = "|cffff0000"   -- Red
local COLOR_DEBUG = "|cff00ffff"   -- Cyan
local COLOR_RESET = "|r"

-- Debug print function
function Cell.Debug:Print(category, message, color)
    --! WotLK fix: capture the event into the ring even when chat printing
    --! is disabled - the whole point of /cell debug log is to keep evidence
    --! from a session where debug mode was off and the bug already fired.
    if self.Ring.enabled then
        self.RingPush(category, message)
    end
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
    if not self.trackFires then return end

    --! WotLK fix: ring capture runs before the enabled gate so a session
    --! without /cell debug still keeps the last N fires (e.g. for a
    --! RAID_ROSTER_UPDATE spike that the user noticed only in retrospect).
    if self.Ring.enabled then
        self.RingPush("FIRE", event)
    end
    if not self.enabled then return end

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
    --! WotLK fix: also wipe the in-memory ring buffer so /cell debug c
    --! gives the user a clean slate before a fresh reproduction.
    self.Ring.buffer = {}
    self:Print("SYSTEM", "Debug data cleared (incl. ring buffer)", COLOR_INFO)
end

--! WotLK fix: hooks for backport-specific dump sections.
--! Debug_Wrath.lua appends closures that emit env / timers / glow / anim /
--! ring-buffer lines into the table. Plain ordered list; no need to
--! key by name since the order in the dump is fixed by registration order.
Cell.Debug.DumpSections = {}

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
        --! WotLK fix: make the normal debug toggle own the expensive callback
        --! instrumentation flags too. They are disabled by default so a normal
        --! session does not allocate registration records or count fires.
        self.trackRegistrations = self.enabled
        --! WotLK fix: ring logging may remain enabled while chat/debug mode is
        --! disabled, so keep the cheap fire route alive for ring capture only.
        self.trackFires = self.enabled or self.Ring.enabled
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
    local role = Cell.UnitGroupRolesAssigned and Cell.UnitGroupRolesAssigned(unit) or "?" --! WotLK fix: Cell-private role adapter (global stays native).
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
    local function add(s) lines[#lines + 1] = s end

    add("=== Cell Debug Dump ===")
    add("generated: " .. date("%Y-%m-%d %H:%M:%S"))

    local version, build = GetBuildInfo()
    add(string.format("client: %s (build %s)", tostring(version), tostring(build)))
    local cellVer = GetAddOnMetadata and GetAddOnMetadata("Cell", "Version")
    add("Cell version: " .. tostring(cellVer))

    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
        add(string.format("memory: %.0f KB", GetAddOnMemoryUsage("Cell")))
    end

    -- own talents: name(backgroundFileName)=points per tab
    if GetNumTalentTabs and GetTalentTabInfo then
        local tabs = {}
        for i = 1, GetNumTalentTabs() do
            --! WotLK fix: native build 12340 tuple is
            --! name, icon, pointsSpent, background, previewPointsSpent.
            local tname, _, points, background = GetTalentTabInfo(i)
            table.insert(tabs, string.format("%s(%s)=%d",
                tostring(tname), tostring(background), points or 0))
        end
        add("player talents: " .. table.concat(tabs, ", "))
    end

    local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    add("")
    add(string.format("group: raid=%d party=%d", numRaid, numParty))
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

    add("")
    add(string.format("callbacks: registrations=%d fires=%d (fires counted only while debug mode is ON)",
        self.stats.totalRegistrations, self.stats.totalFires))
    for event, registrations in pairs(self.registrations) do
        add(string.format("  reg %s: %d", event, #registrations))
    end
    for event, count in pairs(self.fires) do
        local listeners = Cell.GetEventListenersCount and Cell.GetEventListenersCount(event) or -1
        add(string.format("  fired %s: %d (listeners now: %d)", event, count, listeners))
    end
    if next(self.stats.missedCallbacks) then
        add("  MISSED (fired with 0 listeners):")
        for event, count in pairs(self.stats.missedCallbacks) do
            add(string.format("    %s: %d", event, count))
        end
    end

    --! WotLK fix: invoke the registered dump-section builders (env / timers /
    --! glow / anim / ring buffer). Each builder appends plain lines into the
    --! shared table and may add its own blank-line separator.
    for _, builder in ipairs(self.DumpSections) do
        local ok, err = pcall(builder, lines, self)
        if not ok then
            add("  [dump section error: " .. tostring(err) .. "]")
        end
    end

    add("=== end of dump ===")
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
