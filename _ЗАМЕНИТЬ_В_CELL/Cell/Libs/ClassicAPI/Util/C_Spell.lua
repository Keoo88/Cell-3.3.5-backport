local _, Private = ...

local _G = _G
local Type = type
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture

local Tooltip = Private.Tooltip
local EventHandler = Private.EventHandler
local EventHandler_Fire = EventHandler.Fire

local C_Spell = C_Spell or {}

function C_Spell.IsSpellDataCached(ID)
	return GetSpellInfo(ID) ~= nil
end

function C_Spell.GetSpellDescription(ID)
	Tooltip:ClearLines()
	Tooltip:SetHyperlink("spell:"..ID)

	local Num = Tooltip:NumLines()
	if ( Num > 0 ) then
		return _G["CAPI_ScanTooltipTextLeft"..Num]:GetText()
	end
end

function C_Spell.GetSpellTexture(ID, BookType)
	local _, Icon
	if ( BookType ) then
		Icon = GetSpellTexture(ID, BookType)
	else
		_, _, Icon = GetSpellInfo(ID)
	end
	return Icon, Icon
end

function C_Spell.GetSpellInfo(ID)
	local Name, Rank, Icon, _, _, _, CastTime, RangeMin, RangeMax = GetSpellInfo(ID)
	if ( not Name ) then return end

	return {
		name = Name,
		rank = Rank,
		iconID = Icon,
		originalIconID = Icon,
		castTime = CastTime,
		minRange = RangeMin,
		maxRange = RangeMax,
		spellID = ID
	}
end

function C_Spell.GetSpellCooldown(ID)
	local Start, Duration, Enabled = GetSpellCooldown(ID)
	if ( not Start ) then return end

	return {
		startTime = Start,
		duration = Duration,
		isEnabled = Enabled,
		modRate = 1
	}
end

function C_Spell.GetSpellSubtext(ID)
	if ( ID ) then
		local _, Rank = GetSpellInfo(ID)
		return Rank
	end
end

function C_Spell.GetSchoolString(SchoolMask)
	return _G.UNKNOWN -- TODO
end

function C_Spell.DoesSpellExist(ID)
	return GetSpellInfo(ID) ~= nil
end

function C_Spell.GetSpellIDForSpellIdentifier(ID, BookType)
	if ( BookType or Type(ID) == "string" ) then
		Tooltip:ClearLines()
		if ( BookType ) then
			Tooltip:SetSpell(ID, BookType)
		else
			local Link, _ = GetSpellLink(ID) or ID
			Tooltip:SetHyperlink(Link)
		end
		_, _, ID = Tooltip:GetSpell()
	end

	return ID
end

function C_Spell.SpellHasRange(ID)
	local _, _, _, _, _, _, _, RangeMin, RangeMax = GetSpellInfo(ID)
	if ( RangeMin > 0 or RangeMax > 0 ) then
		return true
	end
end

function C_Spell.GetSpellName(ID)
	return (GetSpellInfo(ID))
end

C_Spell.PickupSpell = PickupSpell
C_Spell.GetSpellLink = GetSpellLink
C_Spell.IsSpellInRange = IsSpellInRange

C_Spell.RequestLoadSpellData = Private.Void
C_Spell.GetSpellLevelLearned = Private.Zero
C_Spell.GetSpellCastCount = Private.Zero
C_Spell.GetSpellCharges = Private.Void

-- Global
_G.C_Spell = C_Spell

-- Global Deprecated (Compatibility)
_G.C_GetSpellTexture = C_Spell.GetSpellTexture
_G.GetSpellSubtext = C_Spell.GetSpellSubtext
_G.DoesSpellExist = C_Spell.DoesSpellExist
_G.GetSpellDescription = C_Spell.GetSpellDescription
_G.C_GetSpellInfo = function(ID, BookType)
	local _, Name, Rank, Icon, CastTime, RangeMin, RangeMax

	if ( ID ) then
		if ( BookType ) then
			Name, Rank, Icon, _, _, _, CastTime, RangeMin, RangeMax = GetSpellInfo(ID, BookType)
			if ( Name ) then ID = C_Spell.GetSpellIDForSpellIdentifier(ID, BookType) end
		else
			Name, Rank, Icon, _, _, _, CastTime, RangeMin, RangeMax = GetSpellInfo(ID)
		end
	end

	return Name, Rank, Icon, CastTime, RangeMin, RangeMax, ID
end