local _, Cell = ...
_G.Cell = _G.Cell or Cell or {}
Cell = _G.Cell

--! WotLK fix: Cell owns one private timer engine. It does not depend on, merge
--! into, or replace a standalone !!!ClassicAPI addon's global C_Timer table.
--! Handles are never recycled, so stale :Cancel() calls cannot affect a newer
--! timer. Dispatch is split into collection and callback phases, allowing
--! callbacks to create or cancel timers without mutating the active scan.
local Timer = {}
Cell.C_Timer = Timer

local active = {}
local due = {}
local driver = CreateFrame("Frame")
driver:Hide()

--! WotLK fix: the 3.3.5 client may expose no Lua debug library (or a host may
--! disable it). Diagnostics must never make the timer engine itself unusable.
local debugGetInfo = type(debug) == "table" and type(debug.getinfo) == "function" and debug.getinfo

local Handle = {}
Handle.__index = Handle

function Handle:Cancel()
    self._cancelled = true
end

function Handle:IsCancelled()
    return self._cancelled
end

--! WotLK fix: optional private diagnostics label. WoW 3.3.5 may expose no
--! Lua debug library, so debug.getinfo cannot identify timer callbacks in the
--! user's client. The label changes neither scheduling nor cancellation and is
--! copied as plain text by EnumerateActive (live handles remain private).
function Handle:SetDebugLabel(label)
    if label ~= nil and type(label) ~= "string" then
        error("Cell.C_Timer debug label must be a string or nil", 2)
    end
    self._debugLabel = label
    return self
end

local function ReportError(message)
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        handler(message)
    end
end

local function NormalizeDuration(duration)
    if type(duration) ~= "number" then
        error("Cell.C_Timer duration must be a number", 3)
    end
    return duration > 0 and duration or 0.01
end

local function NormalizeCallback(callback)
    if type(callback) ~= "function" then
        error("Cell.C_Timer callback must be a function", 3)
    end
    return callback
end

local function Create(duration, callback, iterations, returnHandle)
    local handle = setmetatable({
        _duration = NormalizeDuration(duration),
        _callback = NormalizeCallback(callback),
        _iterations = iterations,
        _elapsed = 0,
        _cancelled = false,
    }, Handle)

    active[#active + 1] = handle
    driver:Show()
    return returnHandle and handle or nil
end

local function ResolveCall(first, second, third)
    if first == Timer then
        return second, third
    end
    return first, second
end

function Timer.After(duration, callback, methodCallback)
    duration, callback = ResolveCall(duration, callback, methodCallback)
    Create(duration, callback, 1, false)
end

function Timer.NewTimer(duration, callback, methodCallback)
    duration, callback = ResolveCall(duration, callback, methodCallback)
    return Create(duration, callback, 1, true)
end

function Timer.NewTicker(duration, callback, iterations, methodIterations)
    if duration == Timer then
        duration, callback, iterations = callback, iterations, methodIterations
    end
    if type(iterations) ~= "number" or iterations <= 0 then
        iterations = -1
    else
        iterations = math.floor(iterations)
        if iterations < 1 then iterations = 1 end
    end
    return Create(duration, callback, iterations, true)
end

local function CollectDue(elapsed)
    local write = 1
    for read = 1, #active do
        local handle = active[read]
        if not handle._cancelled then
            handle._elapsed = handle._elapsed + elapsed
            if handle._elapsed >= handle._duration then
                handle._elapsed = handle._elapsed - handle._duration
                if handle._elapsed >= handle._duration then
                    handle._elapsed = 0
                end

                due[#due + 1] = handle
            end

            active[write] = handle
            write = write + 1
        end
    end

    for index = write, #active do
        active[index] = nil
    end
end

local function DispatchDue()
    for index = 1, #due do
        local handle = due[index]
        local callback = handle._callback
        due[index] = nil

        if not handle._cancelled then
            if handle._iterations > 0 then
                handle._iterations = handle._iterations - 1
                if handle._iterations == 0 then
                    handle._cancelled = true
                end
            end

            -- A finite timer is marked cancelled before its final callback, but
            -- the callback still belongs to the firing collected this frame.
            local ok, message = pcall(callback, handle)
            if not ok then ReportError(message) end
        end
    end
end

driver:SetScript("OnUpdate", function(self, elapsed)
    CollectDue(elapsed)
    DispatchDue()
    if #active == 0 then self:Hide() end
end)

--! WotLK fix: publish a global fallback only when no addon owns C_Timer.
--! Cell code always binds to Cell.C_Timer, so standalone presence cannot alter
--! Cell's timer semantics.
if not _G.C_Timer then
    _G.C_Timer = Timer
end

--! WotLK fix: debug introspection for /cell debug timers.
--! Returns a count snapshot (cheap) and a SAFE snapshot of active handles
--! (no live Handle references: returned tables are plain copies, so the
--! caller cannot accidentally Cancel() real dispatch entries). The
--! callback info is just the source file - the function value is never
--! leaked, which would have changed dispatch behavior under error path.
function Timer.GetDebugStats()
    return #active, #due, driver:IsShown() and true or false
end

function Timer.EnumerateActive(max)
    max = max and math.floor(max) or 50
    if max < 1 then max = 1 elseif max > 500 then max = 500 end
    local total = #active
    local n = math.min(max, total)
    local out = {}
    for i = 1, n do
        local h = active[i]
        local source = "<debug unavailable>"
        if debugGetInfo then
            local ok, info = pcall(debugGetInfo, h._callback, "S")
            if ok and info and info.source then
                source = info.source
            end
        end
        out[i] = {
            elapsed = h._elapsed,
            duration = h._duration,
            iterations = h._iterations,
            cancelled = h._cancelled and true or false,
            source = source,
            label = h._debugLabel,
        }
    end
    return out, total
end
