--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).

local _, Private = ...

-- Forward-declared as locals: the definitions below now fill these locals, not
-- globals. Publishing happens at the bottom of the file through Private.Provide,
-- which only writes a global when nobody else owns that name.
local Lerp, Clamp, Saturate, Wrap, ClampDegrees, ClampMod, NegateIf, PercentageBetween,
      ClampedPercentageBetween, DeltaLerp, FrameDeltaLerp, RandomFloatInRange, Round, Square,
      CalculateDistanceSq, CalculateDistance, CalculateAngleBetween, CreateCounter

local ceil = math.ceil
local floor = math.floor
local random = math.random
local atan2 = math.atan2
local sqrt = math.sqrt

function Lerp(startValue, endValue, amount)
    return (1 - amount) * startValue + amount * endValue;
end

function Clamp(value, min, max)
    if value > max then
        return max;
    elseif value < min then
        return min;
    end
    return value;
end

function Saturate(value)
    return Clamp(value, 0.0, 1.0);
end

function Wrap(value, max)
    return (value - 1) % max + 1;
end

function ClampDegrees(value)
    return ClampMod(value, 360);
end

function ClampMod(value, mod)
    return ((value % mod) + mod) % mod;
end

function NegateIf(value, condition)
    return condition and -value or value;
end

function PercentageBetween(value, startValue, endValue)
    if startValue == endValue then
        return 0.0;
    end
    return (value - startValue) / (endValue - startValue);
end

function ClampedPercentageBetween(value, startValue, endValue)
    return Saturate(PercentageBetween(value, startValue, endValue));
end

local TARGET_FRAME_PER_SEC = 60.0;
function DeltaLerp(startValue, endValue, amount, timeSec)
    return Lerp(startValue, endValue, Saturate(amount * timeSec * TARGET_FRAME_PER_SEC));
end

function FrameDeltaLerp(startValue, endValue, amount, elapsed)
    return DeltaLerp(startValue, endValue, amount, elapsed);
end

function RandomFloatInRange(minValue, maxValue)
    return Lerp(minValue, maxValue, random());
end

function Round(value)
    if value < 0.0 then
        return ceil(value - .5);
    end
    return floor(value + .5);
end

function Square(value)
    return value * value;
end

function CalculateDistanceSq(x1, y1, x2, y2)
    local dx = x2 - x1;
    local dy = y2 - y1;
    return (dx * dx) + (dy * dy);
end

function CalculateDistance(x1, y1, x2, y2)
    return sqrt(CalculateDistanceSq(x1, y1, x2, y2));
end

function CalculateAngleBetween(x1, y1, x2, y2)
    return atan2(y2 - y1, x2 - x1);
end

function CreateCounter(initialCount)
	local count = initialCount or 0;
	local counter = function()
		count = count + 1;
		return count;
	end;
    return function()
        return securecallfunction(counter);
    end;
end

-- Publish: gap-fill only, ours stays reachable via CellClassicAPI.<name>
Private.Provide("Lerp", Lerp)
Private.Provide("Clamp", Clamp)
Private.Provide("Saturate", Saturate)
Private.Provide("Wrap", Wrap)
Private.Provide("ClampDegrees", ClampDegrees)
Private.Provide("ClampMod", ClampMod)
Private.Provide("NegateIf", NegateIf)
Private.Provide("PercentageBetween", PercentageBetween)
Private.Provide("ClampedPercentageBetween", ClampedPercentageBetween)
Private.Provide("DeltaLerp", DeltaLerp)
Private.Provide("FrameDeltaLerp", FrameDeltaLerp)
Private.Provide("RandomFloatInRange", RandomFloatInRange)
Private.Provide("Round", Round)
Private.Provide("Square", Square)
Private.Provide("CalculateDistanceSq", CalculateDistanceSq)
Private.Provide("CalculateDistance", CalculateDistance)
Private.Provide("CalculateAngleBetween", CalculateAngleBetween)
Private.Provide("CreateCounter", CreateCounter)
