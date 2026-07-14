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
	["FrameGeneral/UIFrameDiamondMetal"] = {
		["UI-Frame-DiamondMetal-CornerBottomLeft"]={32, 32, 0.015625, 0.515625, 0.269531, 0.394531, false, false},
		["UI-Frame-DiamondMetal-CornerBottomRight"]={32, 32, 0.015625, 0.515625, 0.402344, 0.527344, false, false},
		["UI-Frame-DiamondMetal-CornerTopLeft"]={32, 32, 0.015625, 0.515625, 0.535156, 0.660156, false, false},
		["UI-Frame-DiamondMetal-CornerTopRight"]={32, 32, 0.015625, 0.515625, 0.667969, 0.792969, false, false},
		["_UI-Frame-DiamondMetal-EdgeBottom"]={32, 32, 0, 0.5, 0.00390625, 0.128906, false, false},
		["_UI-Frame-DiamondMetal-EdgeTop"]={32, 32, 0, 0.5, 0.136719, 0.261719, false, false},
	},
	["FrameGeneral/UIFrameDiamondMetalVertical"] = {
		["!UI-Frame-DiamondMetal-EdgeLeft"]={32, 32, 0.0078125, 0.257812, 0, 1, false, false},
		["!UI-Frame-DiamondMetal-EdgeRight"]={32, 32, 0.273438, 0.523438, 0, 1, false, false},
	},
	["RaidFrame/RaidFrameSummon"] = {
		["Raid-Icon-SummonAccepted"]={32, 32, 0.0078125, 0.257812, 0.015625, 0.515625, false, false},
		["Raid-Icon-SummonDeclined"]={32, 32, 0.273438, 0.523438, 0.015625, 0.515625, false, false},
		["Raid-Icon-SummonPending"]={32, 32, 0.539062, 0.789062, 0.015625, 0.515625, false, false},
	},
	["ContainerFrame/Bags"] = {
		["bags-newitem"]={44, 44, 0.363281, 0.535156, 0.00390625, 0.175781, false, false},
		["bags-junkcoin"]={20, 18, 0.863281, 0.941406, 0.28125, 0.351562, false, false},
		["bags-innerglow"]={36, 36, 0.164062, 0.304688, 0.539062, 0.679688, false, false},
		["bags-glow-purple"]={39, 39, 0.00390625, 0.15625, 0.539062, 0.691406, false, false},
		["bags-glow-blue"]={39, 39, 0.542969, 0.695312, 0.164062, 0.316406, false, false},
		["bags-glow-orange"]={39, 39, 0.707031, 0.859375, 0.363281, 0.515625, false, false},
		["bags-glow-green"]={39, 39, 0.703125, 0.855469, 0.00390625, 0.15625, false, false},
		["bags-glow-heirloom"]={39, 39, 0.703125, 0.855469, 0.164062, 0.316406, false, false},
		["bags-glow-white"]={39, 39, 0.00390625, 0.15625, 0.699219, 0.851562, false, false},
		["bags-glow-flash"]={90, 90, 0.00390625, 0.355469, 0.00390625, 0.355469, false, false},
		["bags-button-autosort-down"]={28, 26, 0.164062, 0.273438, 0.835938, 0.9375, false, false},
		["bags-button-autosort-up"]={28, 26, 0.3125, 0.421875, 0.539062, 0.640625, false, false},
		["bags-roundhighlight"]={36, 36, 0.164062, 0.304688, 0.6875, 0.828125, false, false},
		["bags-icon-consumables"]={28, 28, 0.863281, 0.972656, 0.00390625, 0.113281, false, false},
		["bags-icon-equipment"]={28, 28, 0.863281, 0.972656, 0.164062, 0.273438, false, false},
		["bags-icon-tradegoods"]={28, 28, 0.867188, 0.976562, 0.363281, 0.472656, false, false},
		["bags-glow-artifact"]={39, 39, 0.542969, 0.695312, 0.00390625, 0.15625, false, false},
		["bags-greenarrow"]={20, 22, 0.3125, 0.390625, 0.648438, 0.734375, false, false},
		["bags-icon-addslots"]={42, 42, 0.363281, 0.527344, 0.183594, 0.347656, false, false},
		["bags-static"]={178, 43, 0.00390625, 0.699219, 0.363281, 0.53125, false, false},
		["bags-icon-scrappable"]={36, 32, 0.00390625, 0.144531, 0.859375, 0.984375, false, false},
	},
}

AtlasInfo.directory = Private.TEXTURE_PATH
C_Texture.RegisterAtlasTable(AtlasInfo)