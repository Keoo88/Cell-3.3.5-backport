--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).

local _, Private = ...

local IsInInstance = IsInInstance

-- Own table: filling a foreign C_PvP in place would overwrite its methods.
local C_PvP = {}

function C_PvP.IsPvPMap()
	local Active, Type = IsInInstance()
	if ( Active ) then
		return Type == "pvp" or Type == "arena"
	end
end

C_PvP.IsRatedBattleground = Private.False
C_PvP.IsWarModeDesired = Private.False

-- Global
Private.Merge("C_PvP", C_PvP)
