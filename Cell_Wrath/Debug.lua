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
    elseif option == "help" or option == "h" then
        print(COLOR_INFO .. "Cell Debug Commands:" .. COLOR_RESET)
        print("  /cell debug - Toggle debug mode")
        print("  /cell debug v|verbose - Toggle verbose logging")
        print("  /cell debug r|report - Show debug report")
        print("  /cell debug c|clear - Clear debug data")
        print("  /cell debug h|help - Show this help")
    else
        self.enabled = not self.enabled
        print(string.format("Cell Debug: %s", 
            self.enabled and "enabled" or "disabled"))
    end
end
