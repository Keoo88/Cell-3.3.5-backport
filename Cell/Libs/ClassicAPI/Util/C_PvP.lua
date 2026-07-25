--! Cell: this is a private, trimmed fork of Tsoukie's ClassicAPI.
--! If the standalone !!!ClassicAPI addon is installed (Gladdy requires it), it
--! loads first and owns these globals. Overwriting them with this older subset
--! mixes two incompatible halves of the same library, so bail out instead.
if IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI") then return end

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