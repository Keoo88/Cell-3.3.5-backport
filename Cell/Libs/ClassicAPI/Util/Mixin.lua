--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Mixin exists natively in later clients only;
--! 3.3.5a has none of these three (verified against milkyway-codex).

local _, Private = ...

local Select = select
local Pairs = pairs

local Mixin, CreateFromMixins, CreateAndInitFromMixin

function Mixin(Object, ...)
	for i = 1, Select("#", ...) do
		local Source = Select(i, ...)
		if ( Source ) then
			for k, v in Pairs(Source) do
				Object[k] = v
			end
		end
	end
	return Object
end

function CreateFromMixins(...)
	return Mixin({}, ...)
end

function CreateAndInitFromMixin(Source, ...)
	local Object = CreateFromMixins(Source)
	Object:Init(...)
	return Object
end

-- Publish: gap-fill only, ours stays reachable via CellClassicAPI.<name>
Private.Provide("Mixin", Mixin)
Private.Provide("CreateFromMixins", CreateFromMixins)
Private.Provide("CreateAndInitFromMixin", CreateAndInitFromMixin)
