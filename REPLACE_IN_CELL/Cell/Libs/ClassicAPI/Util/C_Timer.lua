if ( not C_Timer ) then
	local _G = _G
	local Type = type
	local SetMetaTable = setmetatable

	local C_Timer = TimerFrame or CreateFrame("Frame", "TimerFrame")
	local Registry = SetMetaTable({}, { __mode = "k" }) -- Registry maps the "Public" proxy table to the "Internal" Animation object
	local Pool = {}

	local function Release(Timer)
		Timer.Proxy = nil
		Timer.Callback = nil
		Timer.Iteration = nil
		Pool[#Pool + 1] = Timer
	end

	local function Cancel(Proxy)
		local Timer = Registry[Proxy]
		if ( Timer ) then
			Timer:Stop()
			Release(Timer)
			Registry[Proxy] = nil
		end
	end

	local TimerMethods = { -- Methods attached to timer object.
		Cancel = Cancel,
		IsCancelled = function(Proxy) return Registry[Proxy] == nil end
	} TimerMethods.__index = TimerMethods

	local function OnFinished(Timer)
		Timer.Callback(Timer.Proxy)

		if ( Timer.Callback ) then
			local Iteration = Timer.Iteration

			if ( Iteration ) then
				if ( Iteration == 1 ) then
					Cancel(Timer.Proxy)
				else
					Timer.Iteration = Iteration - 1
				end
			elseif ( not Timer.Proxy ) then
				Release(Timer)
			end
		end
	end

	local function New()
		local TimerIndex = #Pool

		if ( TimerIndex > 0 ) then
			local Timer = Pool[TimerIndex]
			Pool[TimerIndex] = nil
			return Timer
		end

		local A = C_Timer:CreateAnimationGroup()
		Timer = A:CreateAnimation("Animation")
		Timer:SetScript("OnFinished", OnFinished)
		return Timer
	end

	local function Create(Duration, Callback, Iteration, Ticker)
		local Timer = New()

		if ( Ticker ) then
			local Proxy = SetMetaTable({}, TimerMethods)
			Registry[Proxy] = Timer
			Timer.Proxy = Proxy
			Timer.Iteration = Iteration
		end

		Timer.Callback = Callback
		Timer:GetParent():SetLooping((Ticker and (not Iteration or Iteration > 1)) and "REPEAT" or "NONE")
		Timer:SetDuration(Duration > 0 and Duration or .01)
		Timer:Play()

		return Timer.Proxy
	end

	function C_Timer.After(Duration, Callback, _)
		if ( Type(Duration) ~= "number" ) then
			Duration, Callback = Callback, _
		end

		Create(Duration, Callback)
	end

	function C_Timer.NewTimer(Duration, Callback, _)
		if ( Type(Duration) ~= "number" ) then
			Duration, Callback = Callback, _
		end

		return Create(Duration, Callback, 1, true)
	end

	function C_Timer.NewTicker(Duration, Callback, Iteration, _)
		if ( Type(Duration) ~= "number" ) then
			Duration, Callback, Iteration = Callback, Iteration, _
		end

		return Create(Duration, Callback, Iteration, true)
	end

	-- Global
	_G.C_Timer = C_Timer
	C_Timer._version = 2
end