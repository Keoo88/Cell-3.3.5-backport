--! Cell: this is a private, trimmed fork of Tsoukie's ClassicAPI.
--! If the standalone !!!ClassicAPI addon is installed (Gladdy requires it), it
--! loads first and owns these globals. Overwriting them with this older subset
--! mixes two incompatible halves of the same library, so bail out instead.
if IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI") then return end

function XML_NineSlice(Self, Layout)
	Self.layoutType = Layout
	Mixin(Self, NineSlicePanelMixin)
	Self:OnLoad()
end

function XML_UseParentLevel(Self)
	Self:SetFrameLevel(Self:GetParent():GetFrameLevel())
end