--! Cell: private smoothing fork derived from Tsoukie's ClassicAPI.
--! It intentionally remains active beside standalone !!!ClassicAPI because it
--! publishes only Cell.SmoothStatusBarMixin and no shared compatibility global.
local _, Cell = ...
_G.Cell = _G.Cell or Cell or {}
Cell = _G.Cell

-- https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/SharedXML/SmoothStatusBar.lua
--! WotLK fix: Cell owns smoothing privately. Do not reuse or publish a global
--! SmoothStatusBarMixin supplied by a custom core or foreign compatibility addon;
--! that would make Cell's behavior depend on addon load order and retain MathUtil
--! globals solely for two Cell-owned status-bar consumers.
do
	local Pairs = pairs

	local Bars = CreateFrame("Frame")
	local BarsActive

	--! WotLK perf: Clamp, FrameDeltaLerp и IsCloseEnough были тремя отдельными
	--! функциями, и все три звались из тела цикла - то есть три вызова Lua на бар
	--! на кадр отрисовки. Драйвер идёт на полном фреймрейте, а в очередь попадают
	--! оверлеи аур (Base.lua, I.CreateAura_Overlay) и аггро-бары - по одному на
	--! каждую рейдовую кнопку, то есть до 80 баров в кадре. Тела вставлены сюда
	--! как есть, других вызовов у этих трёх функций не было (греп по файлу), так
	--! что сами функции удалены, а вместе с ними и локал Abs - модуль строки 43
	--! заменён на ветку по знаку. Тот же приём и по той же причине уже применён к
	--! ProcessCellSmoothBars в UnitButton_Cata_Wrath.lua и к
	--! AbsoluteAnimation_OnUpdate в Widgets/Animation.lua.
	local function ProcessSmoothStatusBars(Self, Elapsed)
		BarsActive = 0

		--! WotLK perf: доля перехода зависит только от Elapsed, а Elapsed один на
		--! весь кадр - значит она инвариант цикла и считается один раз, а не на
		--! каждый бар. Amount тут всегда .25 (единственная точка вызова ниже),
		--! поэтому .25 * Elapsed * 60 свёрнуто в Elapsed * 15: умножение на .25 в
		--! двоичной плавающей точке точное, так что оба выражения дают один и тот
		--! же округлённый результат, а не просто близкий.
		local Progress = Elapsed * 15
		if Progress < 0 then
			Progress = 0
		elseif Progress > 1 then
			Progress = 1
		end
		local InvProgress = 1 - Progress

		for Bar, TargetValue in Pairs(Bars) do
			if ( Bar ~= 0 ) then
				--! WotLK perf: границы бара спрашивались дважды за кадр - в Clamp и
				--! ещё раз внутри IsCloseEnough. Между этими двумя чтениями бар
				--! ничего не менял, кроме значения, так что один вызов эквивалентен.
				local Min, Max = Bar:GetMinMaxValues()

				local EffectiveTargetValue = TargetValue
				if EffectiveTargetValue > Max then
					EffectiveTargetValue = Max
				elseif EffectiveTargetValue < Min then
					EffectiveTargetValue = Min
				end

				local NewValue = InvProgress * Bar:GetValue() + Progress * EffectiveTargetValue

				local CloseEnough = true
				local Range = Max - Min
				if ( Range > 0 ) then
					local Delta = (NewValue - EffectiveTargetValue) / Range
					if ( Delta < 0 ) then Delta = -Delta end
					CloseEnough = Delta < .00001
				end

				if ( CloseEnough ) then
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

	Cell.SmoothStatusBarMixin = SmoothStatusBarMixin
end