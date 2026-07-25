--! Cell: this is a private, trimmed fork of Tsoukie's ClassicAPI.
--! If the standalone !!!ClassicAPI addon is installed (Gladdy requires it), it
--! loads first and owns these globals. Overwriting them with this older subset
--! mixes two incompatible halves of the same library, so bail out instead.
if IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI") then return end

local Select = select
local Pairs = pairs

if ( not Mixin ) then
	function Mixin(Object, ...)
		for i = 1, Select("#", ...) do
			local Mixin = Select(i, ...)
			if ( Mixin ) then
				for k, v in Pairs(Mixin) do
					Object[k] = v
				end
			end
		end
		return Object
	end
end

function CreateFromMixins(...)
	return Mixin({}, ...)
end

function CreateAndInitFromMixin(Mixin, ...)
	local Object = CreateFromMixins(Mixin)
	Object:Init(...)
	return Object
end