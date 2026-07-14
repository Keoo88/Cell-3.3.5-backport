local _, Private = ...

local IsInInstance = IsInInstance

local C_PvP = C_PvP or {}

function C_PvP.IsPvPMap()
	local Active, Type = IsInInstance()
	if ( Active ) then
		return Type == "pvp" or Type == "arena"
	end
end

C_PvP.IsRatedBattleground = Private.False
C_PvP.IsWarModeDesired = Private.False

-- Global
_G.C_PvP = C_PvP