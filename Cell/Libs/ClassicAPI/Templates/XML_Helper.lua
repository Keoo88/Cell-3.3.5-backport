--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).

local _, Private = ...

-- Forward-declared as locals: the definitions below fill these locals, not globals.
-- Publishing happens at the bottom through Private.Provide / Private.Merge, which
-- only write a global when nobody else owns that name.
local XML_NineSlice, XML_UseParentLevel

function XML_NineSlice(Self, Layout)
	Self.layoutType = Layout
	Mixin(Self, NineSlicePanelMixin)
	Self:OnLoad()
end

function XML_UseParentLevel(Self)
	Self:SetFrameLevel(Self:GetParent():GetFrameLevel())
end

-- Publish: gap-fill only, ours stays reachable via CellClassicAPI.<name>
Private.Provide("XML_NineSlice", XML_NineSlice)
Private.Provide("XML_UseParentLevel", XML_UseParentLevel)
