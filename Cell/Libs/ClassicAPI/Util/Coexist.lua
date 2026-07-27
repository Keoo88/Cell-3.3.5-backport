--! WotLK fix (coexistence): Cell must behave identically in clients WITH and
--! WITHOUT the standalone !!!ClassicAPI addon (Gladdy pulls that one in).
--! Rules for every file of this embedded fork:
--!   * never bail out of a file - our private implementation must always exist;
--!   * never overwrite a global somebody else owns - fill gaps only;
--!   * keep Cell's own (fixed) implementation in the private CellClassicAPI
--!     namespace and call it directly wherever semantics matter.
--! Verified against milkyway-codex 3.3.5a: IsAddOnLoaded/rawget/pairs are native,
--! every name published through here is NOT native and therefore unowned.

local _, Private = ...

CellClassicAPI = CellClassicAPI or {}
local Own = CellClassicAPI
Private.Own = Own

local _G = _G
local RawGet = rawget
local Type = type
local Pairs = pairs

-- Bookkeeping lives under __meta so it can never collide with a global name.
Own.__meta = Own.__meta or { published = {}, foreign = {}, filled = {}, duplicate = {} }
local Meta = Own.__meta

-- Diagnostics only (/cell debug shims): is a foreign ClassicAPI in the client?
Meta.standalone = (IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI")) and true or false

--- Store OUR implementation privately, publish it only if the name is free.
function Private.Provide(Name, Value)
	Own[Name] = Value

	if ( RawGet(_G, Name) == nil ) then
		_G[Name] = Value
		Meta.published[Name] = true
	elseif ( Meta.published[Name] ) then
		-- We published it ourselves earlier (library first, Cell/Polyfills.lua second):
		-- not a foreign addon, just two of our own layers defining the same name.
		Meta.duplicate[Name] = true
	else
		Meta.foreign[Name] = true
	end

	return Value
end

--- Namespace tables (C_Timer, C_Item, Enum, ...): ours is kept whole in the
--- private namespace, the global gets only the keys nobody defined yet.
function Private.Merge(Name, Source)
	Own[Name] = Source

	local Current = RawGet(_G, Name)

	if ( Type(Current) ~= "table" ) then
		_G[Name] = Source
		Meta.published[Name] = true
		return Source
	end

	if ( Meta.published[Name] ) then
		Meta.duplicate[Name] = true
	else
		Meta.foreign[Name] = true
	end

	for Key, Value in Pairs(Source) do
		if ( Current[Key] == nil ) then
			Current[Key] = Value
			Meta.filled[Name] = (Meta.filled[Name] or 0) + 1
		end
	end

	return Current
end

--- Cell's own files (Cell/Polyfills.lua and friends) load after this library and
--- need the same three rules, so the helpers are reachable from the namespace too.
Own.__Provide = Private.Provide
Own.__Merge = Private.Merge

--- Take ownership of a name that is free or that one of OUR OWN layers published
--- earlier (library first, Cell/Polyfills.lua second). Used to collapse a duplicate
--- into a single implementation: a foreign owner is still never touched.
function Private.Adopt(Name, Value)
	Own[Name] = Value

	local Current = RawGet(_G, Name)

	if ( Current == nil or Meta.published[Name] ) then
		_G[Name] = Value
		Meta.published[Name] = true
		Meta.duplicate[Name] = nil
	else
		Meta.foreign[Name] = true
	end

	return Value
end

Own.__Adopt = Private.Adopt

--- Methods on widget metatables/mixins: add what is missing, never replace.
function Private.ProvideMethod(Target, Name, Value)
	if ( Target and Target[Name] == nil ) then
		Target[Name] = Value
		return true
	end

	return false
end

Own.__ProvideMethod = Private.ProvideMethod
