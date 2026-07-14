local addonName, Cell = ...

local callbacks = {}

function Cell.RegisterCallback(eventName, onEventFuncName, onEventFunc)
    if not callbacks[eventName] then callbacks[eventName] = {} end
    callbacks[eventName][onEventFuncName] = onEventFunc
    
    -- Track callback registration if debug module is loaded
    if Cell.Debug and Cell.Debug.TrackRegistration then
        Cell.Debug:TrackRegistration(eventName, onEventFuncName, onEventFunc)
    end
end

function Cell.UnregisterCallback(eventName, onEventFuncName)
    if not callbacks[eventName] then return end
    callbacks[eventName][onEventFuncName] = nil
end

function Cell.UnregisterAllCallbacks(eventName)
    if not callbacks[eventName] then return end
    callbacks[eventName] = nil
end

-- Helper function to get the count of registered listeners for an event
-- Used by the debug system to detect missed callbacks
-- Note: This is attached to Cell directly (not Cell.funcs) because Cell.funcs
-- doesn't exist yet when this file loads
function Cell.GetEventListenersCount(eventName)
    if not callbacks[eventName] then return 0 end
    
    local count = 0
    for _ in pairs(callbacks[eventName]) do
        count = count + 1
    end
    return count
end

function Cell.Fire(eventName, ...)
    -- Track event fire if debug module is loaded
    if Cell.Debug and Cell.Debug.TrackFire then
        Cell.Debug:TrackFire(eventName, ...)
    end
    
    if not callbacks[eventName] then return end

    for onEventFuncName, onEventFunc in pairs(callbacks[eventName]) do
        onEventFunc(...)
    end
end