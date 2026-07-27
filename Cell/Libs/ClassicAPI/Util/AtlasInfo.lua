--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).

local _, Private = ...

--[[
	Usage:
		AtlasInfo = {
			[<path to texture WITHOUT path to addon>] = {
				[<atlas name>] = {width, height, left, right, top, bottom, tilesHoriz, tilesVert}
			},
			...
		}
		AtlasInfo.directory = "<path to addon>"
		C_Texture.RegisterAtlasTable(AtlasInfo)

	Example:
		local atlasTable = {
			directory = "Interface/AddOns/MyAddon"
			["assets/redbutton2x"] = {
				["RedButton-Exit"] = {36, 38, 0.15234375, 0.29296875, 0.0078125, 0.3046875, false, false},
			},
			...
		}
		C_Texture.RegisterAtlasTable(atlasTable)

	Futher Atlas Information:
		Build: 3.4.5.62256:
			https://www.townlong-yak.com/framexml/3.4.5/Helix/AtlasInfo.lua
			https://github.com/Gethe/wow-ui-textures

		Manual Calc: X/WIDTH || Y/HEIGHT
]]

local AtlasInfo = {
	["RaidFrame/RaidFrameSummon"] = {
		["Raid-Icon-SummonAccepted"]={32, 32, 0.0078125, 0.257812, 0.015625, 0.515625, false, false},
		["Raid-Icon-SummonDeclined"]={32, 32, 0.273438, 0.523438, 0.015625, 0.515625, false, false},
		["Raid-Icon-SummonPending"]={32, 32, 0.539062, 0.789062, 0.015625, 0.515625, false, false},
	},
}

AtlasInfo.directory = Private.TEXTURE_PATH
Private.Own.AtlasInfo = AtlasInfo

--! WotLK fix (coexistence): the atlas entries have to reach whichever C_Texture the
--! rest of the UI reads, so register them in BOTH tables - the global one (possibly
--! owned by the standalone !!!ClassicAPI) and our private copy. Registration only
--! adds entries, so this never clobbers anyone.
do
	local Seen = {}
	for _, Namespace in ipairs({ _G.C_Texture, Private.Own.C_Texture }) do
		if ( Namespace and not Seen[Namespace] and Namespace.RegisterAtlasTable ) then
			Seen[Namespace] = true
			Namespace.RegisterAtlasTable(AtlasInfo)
		end
	end
end
