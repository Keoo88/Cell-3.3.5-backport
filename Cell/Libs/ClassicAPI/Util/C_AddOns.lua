--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).

local _, Private = ...

-- Own table: filling a foreign C_AddOns in place would overwrite its methods.
local C_AddOns = {}

local _G = _G
local Type = type
local GetCVar = GetCVar
local GetAddOnInfo = GetAddOnInfo
local IsAddOnLoaded = IsAddOnLoaded
local IsAddOnLoadOnDemand = IsAddOnLoadOnDemand

function C_AddOns.IsAddOnLoaded(Name)
	if ( IsAddOnLoaded(Name) ) then
		return true, true
	end

	return false, false
end

function C_AddOns.GetAddOnInfo(Index)
	local Name, Title, Notes, _, Loadable, Reason, Security = GetAddOnInfo(Index)

	-- (3.3.5) Missing "Reason" values: "BANNED", "CORRUPT", "DEMAND_LOADED", "INCOMPATIBLE"
	if ( Loadable and not IsAddOnLoaded(Index) and IsAddOnLoadOnDemand(Index) ) then
		Reason = "DEMAND_LOADED"
		Loadable = false
	else
		Loadable = Loadable and true or false
	end

	local NewVersion = nil
	return Name, Title, Notes, Loadable, Reason, Security, NewVersion
end

function C_AddOns.GetAddOnEnableState(Arg1, Arg2)
	local AddOn

	if ( Type(Arg1) == "number" or Arg2 == nil ) then
		AddOn = Arg1
	elseif ( Type(Arg2) == "number" ) then
		AddOn = Arg2
	else -- Ambiguous Args
		local _, _, _, Enabled, _, Reason = GetAddOnInfo(Arg1)

		if ( Reason == "MISSING" ) then
			AddOn = Arg2
		else
			return Enabled and 2 or 0
		end
	end

	if ( AddOn == nil or AddOn == "" ) then
		return 0
	end

	local _, _, _, Enabled = GetAddOnInfo(AddOn)
	return Enabled and 2 or 0
end

function C_AddOns.IsAddonVersionCheckEnabled()
	return GetCVar("checkAddonVersion") == "1"
end

C_AddOns.LoadAddOn = LoadAddOn
C_AddOns.EnableAddOn = EnableAddOn
C_AddOns.DisableAddOn = DisableAddOn
C_AddOns.GetAddOnMetadata = GetAddOnMetadata
C_AddOns.GetAddOnDependencies = GetAddOnDependencies
C_AddOns.IsAddOnLoadOnDemand = IsAddOnLoadOnDemand
C_AddOns.GetNumAddOns = GetNumAddOns

C_AddOns.GetAddOnOptionalDependencies = Private.Void

-- Global
Private.Merge("C_AddOns", C_AddOns)

-- Deprecated
Private.Provide("C_GetAddOnInfo", C_AddOns.GetAddOnInfo)
Private.Provide("GetAddOnEnableState", C_AddOns.GetAddOnEnableState)
Private.Provide("IsAddonVersionCheckEnabled", C_AddOns.IsAddonVersionCheckEnabled)
