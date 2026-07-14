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