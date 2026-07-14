local _G = _G
local Floor = math.floor
local AtlasData = C_Texture.AtlasData

--------------------------------------------------
-- STATIC SETUP DATA
--------------------------------------------------
local NineSliceSetup = {
	{ pieceName = "TopLeftCorner", point = "TOPLEFT", pType = "Corner" },
	{ pieceName = "TopRightCorner", point = "TOPRIGHT", pType = "Corner", mirrorH = true },
	{ pieceName = "BottomLeftCorner", point = "BOTTOMLEFT", pType = "Corner", mirrorV = true },
	{ pieceName = "BottomRightCorner", point = "BOTTOMRIGHT", pType = "Corner", mirrorH = true, mirrorV = true },
	{ pieceName = "TopEdge", point = "TOPLEFT", relPoint = "TOPRIGHT", relA = "TopLeftCorner", relB = "TopRightCorner", pType = "Edge" },
	{ pieceName = "BottomEdge", point = "BOTTOMLEFT", relPoint = "BOTTOMRIGHT", relA = "BottomLeftCorner", relB = "BottomRightCorner", pType = "Edge", mirrorV = true },
	{ pieceName = "LeftEdge", point = "TOPLEFT", relPoint = "BOTTOMLEFT", relA = "TopLeftCorner", relB = "BottomLeftCorner", pType = "Edge" },
	{ pieceName = "RightEdge", point = "TOPRIGHT", relPoint = "BOTTOMRIGHT", relA = "TopRightCorner", relB = "BottomRightCorner", pType = "Edge", mirrorH = true },
	{ pieceName = "Center", pType = "Center" },
}

--------------------------------------------------
-- NINE SLICE UTILS & LAYOUTS TABLE
--------------------------------------------------
local NineSliceUtil = {}

local NineSliceLayouts = {
	SimplePanelTemplate = {
		mirrorLayout = true,
		TopLeftCorner =	{ atlas = "UI-Frame-SimpleMetal-CornerTopLeft", x = -5, y = 0, },
		TopRightCorner = { atlas = "UI-Frame-SimpleMetal-CornerTopLeft", x = 2, y = 0, },
		BottomLeftCorner = { atlas = "UI-Frame-SimpleMetal-CornerTopLeft", x = -5, y = -3, },
		BottomRightCorner =	{ atlas = "UI-Frame-SimpleMetal-CornerTopLeft", x = 2, y = -3, },
		TopEdge = { atlas = "_UI-Frame-SimpleMetal-EdgeTop", },
		BottomEdge = { atlas = "_UI-Frame-SimpleMetal-EdgeTop", },
		LeftEdge = { atlas = "!UI-Frame-SimpleMetal-EdgeLeft", },
		RightEdge = { atlas = "!UI-Frame-SimpleMetal-EdgeLeft", },
	},

	PortraitFrameTemplate = {
		TopLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-PortraitMetal-CornerTopLeft", x = -13, y = 16, },
		TopRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 4, y = 16, },
		BottomLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -13, y = -3, },
		BottomRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3, },
		TopEdge = { layer="OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", x = 0, y = 0, x1 = 0, y1 = 0, },
		BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0, },
		LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0 },
		RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0, },
	},

	PortraitFrameTemplateMinimizable = {
		TopLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-PortraitMetal-CornerTopLeft", x = -13, y = 16, },
		TopRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRightDouble", x = 4, y = 16, },
		BottomLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -13, y = -3, },
		BottomRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3, },
		TopEdge = { layer="OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", x = 0, y = 0, x1 = 0, y1 = 0, },
		BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0, },
		LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0 },
		RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0, },
	},

	ButtonFrameTemplateNoPortrait = {
		TopLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopLeft", x = -12, y = 16, },
		TopRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 4, y = 16, },
		BottomLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -12, y = -3, },
		BottomRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3, },
		TopEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", },
		BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", },
		LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", },
		RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", },
	},

	ButtonFrameTemplateNoPortraitMinimizable = {
		TopLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopLeft", x = -12, y = 16, },
		TopRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRightDouble", x = 4, y = 16, },
		BottomLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -12, y = -3, },
		BottomRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3, },
		TopEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", },
		BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", },
		LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", },
		RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", },
	},

	InsetFrameTemplate = {
		TopLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerTopLeft", },
		TopRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerTopRight", },
		BottomLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerBotLeftCorner", x = 0, y = -1, },
		BottomRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerBotRight", x = 0, y = -1, },
		TopEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-InnerTopTile", },
		BottomEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-InnerBotTile", },
		LeftEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-InnerLeftTile", },
		RightEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-InnerRightTile", },
	},

	BFAMissionHorde = {
		mirrorLayout = true,
		TopLeftCorner =	{ atlas = "HordeFrame-Corner-TopLeft", x = -6, y = 6, },
		TopRightCorner =	{ atlas = "HordeFrame-Corner-TopLeft", x = 6, y = 6, },
		BottomLeftCorner =	{ atlas = "HordeFrame-Corner-TopLeft", x = -6, y = -6, },
		BottomRightCorner =	{ atlas = "HordeFrame-Corner-TopLeft", x = 6, y = -6, },
		TopEdge = { atlas = "_HordeFrameTile-Top", },
		BottomEdge = { atlas = "_HordeFrameTile-Top", },
		LeftEdge = { atlas = "!HordeFrameTile-Left", },
		RightEdge = { atlas = "!HordeFrameTile-Left", },
	},

	BFAMissionAlliance = {
		mirrorLayout = true,
		TopLeftCorner =	{ atlas = "AllianceFrameCorner-TopLeft", x = -6, y = 6, },
		TopRightCorner =	{ atlas = "AllianceFrameCorner-TopLeft", x = 6, y = 6, },
		BottomLeftCorner =	{ atlas = "AllianceFrameCorner-TopLeft", x = -6, y = -6, },
		BottomRightCorner =	{ atlas = "AllianceFrameCorner-TopLeft", x = 6, y = -6, },
		TopEdge = { atlas = "_AllianceFrameTile-Top", },
		BottomEdge = { atlas = "_AllianceFrameTile-Top", },
		LeftEdge = { atlas = "!AllianceFrameTile-Left", },
		RightEdge = { atlas = "!AllianceFrameTile-Left", },
	},

	CovenantMissionFrame = {
		mirrorLayout = true,
		TopLeftCorner =	{ atlas = "Oribos-NineSlice-CornerTopLeft", x = -6, y = 6, },
		TopRightCorner =	{ atlas = "Oribos-NineSlice-CornerTopLeft", x = 6, y = 6, },
		BottomLeftCorner =	{ atlas = "Oribos-NineSlice-CornerTopLeft", x = -6, y = -6, },
		BottomRightCorner =	{ atlas = "Oribos-NineSlice-CornerTopLeft", x = 6, y = -6, },
		TopEdge = { atlas = "_Oribos-NineSlice-EdgeTop", },
		BottomEdge = { atlas = "_Oribos-NineSlice-EdgeTop", },
		LeftEdge = { atlas = "!Oribos-NineSlice-EdgeLeft", },
		RightEdge = { atlas = "!Oribos-NineSlice-EdgeLeft", },
	},

	GenericMetal = {
		TopLeftCorner =	{ atlas = "UI-Frame-GenericMetal-Corner", x = -6, y = 6, mirrorLayout = true, },
		TopRightCorner =	{ atlas = "UI-Frame-GenericMetal-Corner", x = 6, y = 6, mirrorLayout = true, },
		BottomLeftCorner =	{ atlas = "UI-Frame-GenericMetal-Corner", x = -6, y = -6, mirrorLayout = true, },
		BottomRightCorner =	{ atlas = "UI-Frame-GenericMetal-Corner", x = 6, y = -6, mirrorLayout = true, },
		TopEdge = { atlas = "_UI-Frame-GenericMetal-EdgeTop", },
		BottomEdge = { atlas = "_UI-Frame-GenericMetal-EdgeBottom", },
		LeftEdge = { atlas = "!UI-Frame-GenericMetal-EdgeLeft", },
		RightEdge = { atlas = "!UI-Frame-GenericMetal-EdgeRight", },
	},

	Dialog = {
		TopLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopLeft", },
		TopRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopRight", },
		BottomLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomLeft", },
		BottomRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomRight", },
		TopEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeTop", },
		BottomEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom", },
		LeftEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft", },
		RightEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeRight", },
	},

	WoodenNeutralFrameTemplate = {
		mirrorLayout = true,
		TopLeftCorner =	{ atlas = "Neutral-NineSlice-Corner", x = -6, y = 6, },
		TopRightCorner =	{ atlas = "Neutral-NineSlice-Corner", x = 6, y = 6, },
		BottomLeftCorner =	{ atlas = "Neutral-NineSlice-Corner", x = -6, y = -6, },
		BottomRightCorner =	{ atlas = "Neutral-NineSlice-Corner", x = 6, y = -6, },
		TopEdge = { atlas = "_Neutral-NineSlice-EdgeTop", },
		BottomEdge = { atlas = "_Neutral-NineSlice-EdgeBottom", mirrorLayout = false, },
		LeftEdge = { atlas = "!Neutral-NineSlice-EdgeLeft", },
		RightEdge = { atlas = "!Neutral-NineSlice-EdgeRight", mirrorLayout = false, },
	},

	Runeforge = {
		TopLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopLeft", },
		TopRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopRight", },
		BottomLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomLeft", },
		BottomRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomRight", },
		TopEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeTop", },
		BottomEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom", },
		LeftEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft", },
		RightEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeRight", },
	},

	AdventuresMissionComplete = {
		TopLeftCorner =	{ atlas = "AdventuresFrame-Corner-Small-TopLeft", mirrorLayout = true, },
		TopRightCorner =	{ atlas = "AdventuresFrame-Corner-Small-TopLeft", mirrorLayout = true, },
		BottomLeftCorner =	{ atlas = "AdventuresFrame-Corner-Small-TopLeft", mirrorLayout = true, },
		BottomRightCorner =	{ atlas = "AdventuresFrame-Corner-Small-TopLeft", mirrorLayout = true, },
		TopEdge = { layer = "BACKGROUND", atlas = "_AdventuresFrame-Small-Top", x = -10, y = 3, x1 = 10, y1 = 3, },
		BottomEdge = { layer = "BACKGROUND", atlas = "_AdventuresFrame-Small-Top", x = -10, y = -3, x1 = 10, y1 = -3, mirrorLayout = true, },
		LeftEdge = { layer = "BACKGROUND", atlas = "!AdventuresFrame-Right", x = -3, y = 10, x1 = -3, y1 = -10,},
		RightEdge = { layer = "BACKGROUND", atlas = "!AdventuresFrame-Left", x = 3, y = 10, x1 = 3, y1 = -10,},
	},

	CharacterCreateDropdown = {
		TopLeftCorner =	{ atlas = "CharacterCreateDropdown-NineSlice-CornerTopLeft", x=-30, y=20 },
		TopRightCorner =	{ atlas = "CharacterCreateDropdown-NineSlice-CornerTopRight", x=30, y=20 },
		BottomLeftCorner =	{ atlas = "CharacterCreateDropdown-NineSlice-CornerBottomLeft", x=-30, y=-20 },
		BottomRightCorner =	{ atlas = "CharacterCreateDropdown-NineSlice-CornerBottomRight", x=30, y=-20 },
		TopEdge = { atlas = "_CharacterCreateDropdown-NineSlice-EdgeTop", },
		BottomEdge = { atlas = "_CharacterCreateDropdown-NineSlice-EdgeBottom", },
		LeftEdge = { atlas = "!CharacterCreateDropdown-NineSlice-EdgeLeft", },
		RightEdge = { atlas = "!CharacterCreateDropdown-NineSlice-EdgeRight", },
		Center = { atlas = "CharacterCreateDropdown-NineSlice-Center", },
	},

	ChatBubble = {
		TopLeftCorner =	{ atlas = "ChatBubble-NineSlice-CornerTopLeft", },
		TopRightCorner =	{ atlas = "ChatBubble-NineSlice-CornerTopRight", },
		BottomLeftCorner =	{ atlas = "ChatBubble-NineSlice-CornerBottomLeft", },
		BottomRightCorner =	{ atlas = "ChatBubble-NineSlice-CornerBottomRight", },
		TopEdge = { atlas = "_ChatBubble-NineSlice-EdgeTop", },
		BottomEdge = { atlas = "_ChatBubble-NineSlice-EdgeBottom", },
		LeftEdge = { atlas = "!ChatBubble-NineSlice-EdgeLeft", },
		RightEdge = { atlas = "!ChatBubble-NineSlice-EdgeRight", },
		Center = { atlas = "ChatBubble-NineSlice-Center", },
	},

	UniqueCornersLayout = {
		TopRightCorner = { atlas = "%s-NineSlice-CornerTopRight" },
		TopLeftCorner = { atlas = "%s-NineSlice-CornerTopLeft" },
		BottomLeftCorner = { atlas = "%s-NineSlice-CornerBottomLeft" },
		BottomRightCorner = { atlas = "%s-NineSlice-CornerBottomRight" },
		TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
		BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
		LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
		RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
		Center = { atlas = "%s-NineSlice-Center" },
	},

	IdenticalCornersLayout = {
		TopRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, },
		TopLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true,},
		BottomLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, },
		BottomRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true,},
		TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
		BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
		LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
		RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
		Center = { atlas = "%s-NineSlice-Center" },
	}
}

--------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------
local function SetupPieceVisuals(piece, setupInfo, pieceLayout, textureKit)
	local atlasName = pieceLayout.atlas
	if not atlasName then return end

	if textureKit and atlasName:find("%%s") then
		atlasName = atlasName:format(textureKit)
	end

	local info = AtlasData[atlasName]
	if info then
		piece:SetAtlas(atlasName, true)

		-- Mirroring
		if pieceLayout.mirrorLayout and (setupInfo.mirrorH or setupInfo.mirrorV) then
			local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = piece:GetTexCoord()

			if setupInfo.mirrorH then
				ULx, URx = URx, ULx
				ULy, URy = URy, ULy
				LLx, LRx = LRx, LLx
				LLy, LRy = LRy, LLy
			end

			if setupInfo.mirrorV then
				ULx, LLx = LLx, ULx
				ULy, LLy = LLy, ULy
				URx, LRx = LRx, URx
				URy, LRy = LRy, URy
			end

			piece:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
		end
	else
		piece:SetTexture(nil)
	end
end

--------------------------------------------------
-- PUBLIC API
--------------------------------------------------
function NineSliceUtil.GetLayout(layoutName)
	return NineSliceLayouts[layoutName]
end

function NineSliceUtil.AddLayout(layoutName, layout)
	NineSliceLayouts[layoutName] = layout
end

function NineSliceUtil.ApplyLayout(container, userLayout, textureKit)
	if not container or not userLayout then return end

	for i = 1, #NineSliceSetup do
		local setup = NineSliceSetup[i]
		local pieceName = setup.pieceName
		local pieceLayout = userLayout[pieceName]

		if pieceLayout then
			-- Inherit mirrorLayout from parent if not specified
			if pieceLayout.mirrorLayout == nil then
				pieceLayout.mirrorLayout = userLayout.mirrorLayout
			end

			local piece = container[pieceName]
			if not piece then
				piece = container:CreateTexture(nil, pieceLayout.layer or "BORDER", pieceLayout.subLevel or 0)
				container[pieceName] = piece
			end

			piece:ClearAllPoints()
			local pType = setup.pType

			if pType == "Corner" then
				piece:SetPoint(pieceLayout.point or setup.point, container, pieceLayout.relativePoint or setup.point, pieceLayout.x or 0, pieceLayout.y or 0)
			elseif pType == "Edge" then
				local relA, relB = container[setup.relA], container[setup.relB]
				if relA and relB then
					piece:SetPoint(setup.point, relA, setup.relPoint, pieceLayout.x or 0, pieceLayout.y or 0)
					piece:SetPoint(setup.relPoint, relB, setup.point, pieceLayout.x1 or 0, pieceLayout.y1 or 0)
				end
			elseif pType == "Center" then
				local tl, br = container.TopLeftCorner, container.BottomRightCorner
				if tl and br then
					piece:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT", pieceLayout.x or 0, pieceLayout.y or 0)
					piece:SetPoint("BOTTOMRIGHT", br, "TOPLEFT", pieceLayout.x1 or 0, pieceLayout.y1 or 0)
				end
			end

			if userLayout.setupPieceVisualsFunction then
				userLayout.setupPieceVisualsFunction(container, piece, setup, pieceLayout, textureKit)
			else
				SetupPieceVisuals(piece, setup, pieceLayout, textureKit)
			end
		end
	end
end

function NineSliceUtil.ApplyLayoutByName(container, layoutName, textureKit)
	return NineSliceUtil.ApplyLayout(container, NineSliceLayouts[layoutName], textureKit)
end

function NineSliceUtil.ApplyUniqueCornersLayout(container, textureKit)
	return NineSliceUtil.ApplyLayout(container, NineSliceLayouts.UniqueCornersLayout, textureKit)
end

function NineSliceUtil.ApplyIdenticalCornersLayout(container, textureKit)
	return NineSliceUtil.ApplyLayout(container, NineSliceLayouts.IdenticalCornersLayout, textureKit)
end

function NineSliceUtil.DisableSharpening(container)
	for i = 1, #NineSliceSetup do
		local piece = container[NineSliceSetup[i].pieceName]
		if piece then
			if piece.SetTexelSnappingBias then piece:SetTexelSnappingBias(0) end
			if piece.SetSnapToPixelGrid then piece:SetSnapToPixelGrid(false) end
		end
	end
end

--------------------------------------------------
-- MIXIN & GLOBAL EXPOSURE
--------------------------------------------------
local NineSlicePanelMixin = {}

function NineSlicePanelMixin:GetFrameLayoutType()
	return self.layoutType or (self:GetParent() and self:GetParent().layoutType)
end

function NineSlicePanelMixin:OnLoad()
	local layoutType = self:GetFrameLayoutType()
	if layoutType then
		local layout = NineSliceUtil.GetLayout(layoutType)
		if layout then
			NineSliceUtil.ApplyLayout(self, layout, self.layoutTextureKit)
		end
	end
end

_G.NineSliceUtil = NineSliceUtil
_G.NineSlicePanelMixin = NineSlicePanelMixin