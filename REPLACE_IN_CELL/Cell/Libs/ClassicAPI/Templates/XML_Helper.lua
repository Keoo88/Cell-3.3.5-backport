function XML_NineSlice(Self, Layout)
	Self.layoutType = Layout
	Mixin(Self, NineSlicePanelMixin)
	Self:OnLoad()
end

function XML_UseParentLevel(Self)
	Self:SetFrameLevel(Self:GetParent():GetFrameLevel())
end