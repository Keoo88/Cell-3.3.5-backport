local _, Cell = ...
--! WotLK feature: incoming-heal counter. Ported from the "IHC text" WeakAura: the
--! number of DIFFERENT healers who currently have a heal landing on this unit, and
--! whether the heal landing FIRST is the player's own one.
--!
--! Cell already draws incoming heals as a bar on the health bar, which answers "how
--! much". This answers a different question, the one that decides whether to cast at
--! all: "am I the third healer aimed at this target, and will I get there first or
--! land on top of somebody else's cast?". Same data source as the heal prediction -
--! LibHealComm-4.0 - so nothing new goes on the wire.
--!
--! The WeakAura kept its own copy of every pending heal, rebuilt from six library
--! callbacks, and had to expire, delete and garbage-collect that copy by hand. Here
--! the library's own tables are read directly: they are already keyed by caster, so
--! ONE sweep answers the question for every unit in the raid at the cost of a single
--! per-unit query, and there is nothing to keep in sync, nothing to leak and no
--! stale record to expire.

--! WotLK fix: bind Cell timers privately so a standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs

--! WotLK perf: the sweep walks every pending heal of every caster on a timer, so the
--! API surface is bound to locals once instead of being resolved out of the global
--! table on every record.
local UnitGUID, GetTime = UnitGUID, GetTime
local pairs = pairs
local band = bit.band

--! The library is vendored in Cell/Libs, but LibStub hands out whichever copy won -
--! another addon may carry an older one. Everything below is guarded on the two
--! tables actually read, so a copy without them just leaves the indicator empty
--! instead of throwing on every tick.
local HealComm = LibStub and LibStub:GetLibrary("LibHealComm-4.0", true)
local OVERTIME = HealComm and bit.bor(HealComm.HOT_HEALS, HealComm.CHANNEL_HEALS)

--! Lifebloom is permanently rolling on tanks, so counting it would add a constant +1
--! to a frame that nobody is actually healing right now - the WeakAura blocks the
--! three ranks for the same reason.
local BLOCKED = {
    [33763] = true,
    [48450] = true,
    [48451] = true,
}

local INTERVAL = 0.2

-------------------------------------------------
-- state
-------------------------------------------------
local countHoTs = false
local colorMine, colorOther = {0.4, 1, 0.4}, {1, 0.6, 0.2}

--! All four are keyed by target GUID and all four are validated by "stamp": a GUID
--! whose markStamp is not the current one was not seen by the last sweep, which is
--! how a finished heal disappears without wiping anything.
local counts, mine, bestEnd = {}, {}, {}
local markStamp, markCaster = {}, {}
local stamp = 0

local playerGUID
local dirty, hadPending = true, false

-------------------------------------------------
-- sweep
-------------------------------------------------
--! Layout of a pending record, as read by the library's own filterData(): a flat
--! array in strides of five - targetGUID, amount, stack, endTime, ticksLeft - with
--! bitType, spellID and tickInterval hanging off the same table. endTime 0 means
--! "the whole record ends at pending.endTime".
local function SweepCaster(casterGUID, spells, now)
    for _, pending in pairs(spells) do
        local bitType = pending.bitType
        if bitType and not BLOCKED[pending.spellID] then
            local overTime = band(bitType, OVERTIME) > 0
            if countHoTs or not overTime then
                local isMine = casterGUID == playerGUID
                local tickInterval = pending.tickInterval
                local recordEnd = pending.endTime
                for i = 1, #pending, 5 do
                    local guid = pending[i]
                    local endTime = pending[i + 3]
                    if endTime == 0 then endTime = recordEnd end
                    if guid and endTime and endTime > now then
                        --! A HoT does not "land" at its end time, it lands on its next
                        --! tick - the same arithmetic the library uses in
                        --! GetNextHealAmount, so both agree on who heals first.
                        local landing = endTime
                        if overTime and tickInterval and tickInterval > 0 then
                            landing = now + ((endTime - now) % tickInterval)
                        end

                        if markStamp[guid] ~= stamp then
                            markStamp[guid] = stamp
                            markCaster[guid] = casterGUID
                            counts[guid] = 1
                            bestEnd[guid] = landing
                            mine[guid] = isMine
                        else
                            --! Distinct CASTERS, not records: two Rejuvenations from
                            --! the same druid are one healer. All of a caster's records
                            --! are swept in a row, so remembering the last one is
                            --! enough to tell a repeat from a new healer.
                            if markCaster[guid] ~= casterGUID then
                                markCaster[guid] = casterGUID
                                counts[guid] = counts[guid] + 1
                            end
                            --! Ties go to the player: two heals landing on the very
                            --! same millisecond are not a snipe, and pairs() order is
                            --! not stable enough to decide it any other way without
                            --! making the colour flicker.
                            local best = bestEnd[guid]
                            if landing < best or (landing == best and isMine) then
                                bestEnd[guid] = landing
                                mine[guid] = isMine
                            end
                        end
                        hadPending = true
                    end
                end
            end
        end
    end
end

local function Rebuild()
    stamp = stamp + 1
    hadPending = false

    local pendingHeals = HealComm.pendingHeals
    local pendingHots = HealComm.pendingHots
    if not pendingHeals or not pendingHots then return end

    playerGUID = playerGUID or UnitGUID("player")
    local now = GetTime()

    --! Both tables are keyed by caster, and a caster can stand in both at once, so
    --! its records are visited together - that keeps the "same healer again?" test
    --! down to one comparison instead of a per-target set.
    for casterGUID, spells in pairs(pendingHeals) do
        SweepCaster(casterGUID, spells, now)
        local hots = pendingHots[casterGUID]
        if hots then SweepCaster(casterGUID, hots, now) end
    end
    for casterGUID, spells in pairs(pendingHots) do
        if not pendingHeals[casterGUID] then
            SweepCaster(casterGUID, spells, now)
        end
    end
end

-------------------------------------------------
-- display
-------------------------------------------------
local function Apply(b)
    local indicator = b.indicators.incomingHealers
    if not indicator then return end

    local guid = b.states.guid
    local value = (guid and markStamp[guid] == stamp) and counts[guid] or nil
    if value and value > 0 then
        local isMine = mine[guid]
        --! WotLK perf: five times a second across 40 frames, so an unchanged number
        --! must not cost a SetText, a string measurement and a resize.
        if indicator.value ~= value or indicator.isMine ~= isMine or not indicator:IsShown() then
            indicator.value, indicator.isMine = value, isMine
            indicator:SetValue(value, isMine)
        end
    elseif indicator.value then
        indicator.value, indicator.isMine = nil, nil
        indicator:Hide()
    end
end

local function Refresh()
    Rebuild()
    F.IterateAllUnitButtons(Apply, true)
end

local function OnTick()
    --! Callbacks only raise a flag: during raid healing they arrive in bursts of a
    --! dozen, and every one of them would ask for the same sweep. "hadPending" keeps
    --! the sweep running while heals are in the air even with no callback at all,
    --! because a HoT's next tick and a cast's expiry both move on their own.
    if dirty or hadPending then
        dirty = false
        Refresh()
    end
end

-------------------------------------------------
-- indicator frame
-------------------------------------------------
local function IncomingHealers_SetValue(self, value, isMine)
    local color = isMine and colorMine or colorOther
    self.text:SetTextColor(color[1], color[2], color[3])
    self.text:SetText(value)
    self:SetWidth(self.text:GetStringWidth())
    self:Show()
end

local function IncomingHealers_SetFont(self, font, size, outline, shadow)
    font = F.GetFont(font)

    local flags
    if outline == "None" then
        flags = ""
    elseif outline == "Outline" then
        flags = "OUTLINE"
    else
        flags = "OUTLINE,MONOCHROME"
    end

    self.text:SetFont(font, size, flags)

    if shadow then
        self.text:SetShadowOffset(1, -1)
        self.text:SetShadowColor(0, 0, 0, 1)
    else
        self.text:SetShadowOffset(0, 0)
        self.text:SetShadowColor(0, 0, 0, 0)
    end

    self:SetSize(self.text:GetStringWidth(), size)
end

local function IncomingHealers_SetPoint(self, point, relativeTo, relativePoint, x, y)
    self.text:ClearAllPoints()
    if string.find(point, "LEFT$") then
        self.text:SetPoint("LEFT")
    elseif string.find(point, "RIGHT$") then
        self.text:SetPoint("RIGHT")
    else
        self.text:SetPoint("CENTER")
    end
    self:_SetPoint(point, relativeTo, relativePoint, x, y)
end

function I.CreateIncomingHealers(parent)
    local incomingHealers = CreateFrame("Frame", parent:GetName().."IncomingHealers", parent.widgets.indicatorFrame)
    parent.indicators.incomingHealers = incomingHealers
    incomingHealers:Hide()

    local text = incomingHealers:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    incomingHealers.text = text

    incomingHealers.SetFont = IncomingHealers_SetFont
    incomingHealers._SetPoint = incomingHealers.SetPoint
    incomingHealers.SetPoint = IncomingHealers_SetPoint
    incomingHealers.SetValue = IncomingHealers_SetValue
end

-------------------------------------------------
-- enable
-------------------------------------------------
local ticker
local callbackOwner = {}

--! Six callbacks, exactly the set the WeakAura listens to. None of them carries
--! anything worth reading here: they only mean "the library's tables changed".
local EVENTS = {
    "HealComm_HealStarted",
    "HealComm_HealUpdated",
    "HealComm_HealDelayed",
    "HealComm_HealStopped",
    "HealComm_ModifierChanged",
    "HealComm_GUIDDisappeared",
}

local function MarkDirty()
    dirty = true
end

function I.SetIncomingHealersColors(colors)
    if type(colors) ~= "table" then return end
    colorMine = colors[1] or colorMine
    colorOther = colors[2] or colorOther
    --! Repaint at once: outside combat no callback is coming, and a colour picker
    --! that changes nothing until the next pull looks broken.
    F.IterateAllUnitButtons(function(b)
        local indicator = b.indicators.incomingHealers
        if indicator and indicator.value then
            indicator:SetValue(indicator.value, indicator.isMine)
        end
    end, true)
end

function I.SetIncomingHealersCountHoTs(count)
    countHoTs = count and true or false
    dirty = true
end

function I.SetIncomingHealersOptions(colors, count)
    I.SetIncomingHealersCountHoTs(count)
    I.SetIncomingHealersColors(colors)
end

function I.EnableIncomingHealers(enabled)
    if enabled and HealComm then
        for i = 1, #EVENTS do
            HealComm.RegisterCallback(callbackOwner, EVENTS[i], MarkDirty)
        end
        if not ticker then
            ticker = C_Timer.NewTicker(INTERVAL, OnTick)
        end
        dirty = true
        Refresh()
    else
        if HealComm then
            for i = 1, #EVENTS do
                HealComm.UnregisterCallback(callbackOwner, EVENTS[i])
            end
        end
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
        --! Bump the stamp first, then push: every GUID is now stale, so the same
        --! Apply that draws the numbers also clears them.
        stamp = stamp + 1
        hadPending = false
        F.IterateAllUnitButtons(Apply, true)
    end
end
