--! Cell: this is a private, trimmed fork of Tsoukie's ClassicAPI.
--! If the standalone !!!ClassicAPI addon is installed (Gladdy requires it), it
--! loads first and owns these globals. Overwriting them with this older subset
--! mixes two incompatible halves of the same library, so bail out instead.
if IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI") then return end

-- https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/SharedXML/SmoothStatusBar.lua
if ( not SmoothStatusBarMixin ) then
	local Pairs = pairs
	local Abs = math.abs
	local Clamp = Clamp
	local FrameDeltaLerp = FrameDeltaLerp

	local Bars = CreateFrame("Frame")
	local BarsActive

	local function IsCloseEnough(Bar, NewValue, TargetValue)
		local Min, Max = Bar:GetMinMaxValues()
		local Range = Max - Min
		if ( Range > 0 ) then
			return Abs((NewValue - TargetValue) / Range) < .00001
		end

		return true
	end

	local function ProcessSmoothStatusBars(Self, Elapsed)
		BarsActive = 0

		for Bar, TargetValue in Pairs(Bars) do
			if ( Bar ~= 0 ) then
				local EffectiveTargetValue = Clamp(TargetValue, Bar:GetMinMaxValues())
				local NewValue = FrameDeltaLerp(Bar:GetValue(), EffectiveTargetValue, .25, Elapsed)

				if ( IsCloseEnough(Bar, NewValue, EffectiveTargetValue) ) then
					Bars[Bar] = nil
					Bar:SetValue(EffectiveTargetValue)
				else
					Bar:SetValue(NewValue)
				end

				BarsActive = BarsActive + 1
			end
		end

		if ( BarsActive == 0 ) then
			Self:SetScript("OnUpdate", nil)
			BarsActive = nil
		end
	end

	local SmoothStatusBarMixin = {}

	function SmoothStatusBarMixin:ResetSmoothedValue(Value) --If nil, tries to set to the last target Value
		local TargetValue = Bars[self]
		if ( TargetValue ) then
			Bars[self] = nil
			self:SetValue(Value or TargetValue)
		elseif ( Value ) then
			self:SetValue(Value)
		end
	end

	function SmoothStatusBarMixin:SetSmoothedValue(Value)
		Bars[self] = Value

		if ( not BarsActive ) then
			Bars:SetScript("OnUpdate", ProcessSmoothStatusBars)
		end
	end

	function SmoothStatusBarMixin:SetMinMaxSmoothedValue(Min, Max)
		self:SetMinMaxValues(Min, Max)

		local TargetValue = Bars[self]
		if ( TargetValue ) then
			local Ratio = 1
			if ( Max ~= 0 and self.lastSmoothedMax and self.lastSmoothedMax ~= 0 ) then
				Ratio = Max / self.lastSmoothedMax
			end

			Bars[self] = TargetValue * Ratio
		end

		self.lastSmoothedMin = Min
		self.lastSmoothedMax = Max
	end

	_G.SmoothStatusBarMixin = SmoothStatusBarMixin
end