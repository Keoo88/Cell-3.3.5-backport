BACKDROP_ACHIEVEMENTS_0_64 = {
	edgeFile = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder",
	edgeSize = 64,
	tileEdge = true,
}

BACKDROP_ARENA_32_32 = {
	bgFile = "Interface\\CharacterFrame\\UI-Party-Background",
	edgeFile = "Interface\\ArenaEnemyFrame\\UI-Arena-Border",
	tile = true,
	tileEdge = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 32, right = 32, top = 32, bottom = 32 },
}

BACKDROP_DIALOG_32_32 = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileEdge = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

BACKDROP_DARK_DIALOG_32_32 = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileEdge = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

BACKDROP_DIALOG_EDGE_32  = {
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tileEdge = true,
	edgeSize = 32,
}

BACKDROP_GOLD_DIALOG_32_32 = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tile = true,
	tileEdge = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

BACKDROP_WATERMARK_DIALOG_0_16 = {
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-TestWatermark-Border",
	tileEdge = true,
	edgeSize = 16,
}

BACKDROP_SLIDER_8_8 = {
	bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
	edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
	tile = true,
	tileEdge = true,
	tileSize = 8,
	edgeSize = 8,
	insets = { left = 3, right = 3, top = 6, bottom = 6 },
}

BACKDROP_PARTY_32_32 = {
	bgFile = "Interface\\CharacterFrame\\UI-Party-Background",
	edgeFile = "Interface\\CharacterFrame\\UI-Party-Border",
	tile = true,
	tileEdge = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 32, right = 32, top = 32, bottom = 32 },
}

BACKDROP_TOAST_12_12 = {
	bgFile = "Interface\\FriendsFrame\\UI-Toast-Background",
	edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border",
	tile = true,
	tileEdge = true,
	tileSize = 12,
	edgeSize = 12,
	insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

BACKDROP_CALLOUT_GLOW_0_16 = {
	edgeFile = "Interface\\TutorialFrame\\UI-TutorialFrame-CalloutGlow",
	edgeSize = 16,
	tileEdge = true,
}

BACKDROP_CALLOUT_GLOW_0_20 = {
	edgeFile = "Interface\\TutorialFrame\\UI-TutorialFrame-CalloutGlow",
	edgeSize = 20,
	tileEdge = true,
}

BACKDROP_TEXT_PANEL_0_16 = {
	edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
	tileEdge = true,
	edgeSize = 16,
}

BACKDROP_CHARACTER_CREATE_TOOLTIP_32_32 = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
	tile = true,
	tileEdge = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 8, right = 4, top = 4, bottom = 8 },
}

BACKDROP_WRATH_CHARACTER_CREATE_TOOLTIP_32_32 = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	tile = true,
	tileSize = 32,
	insets = { left = 10, right = 0, top = 10, bottom = 6 },
}

BACKDROP_MISTS_CHARACTER_CREATE_TOOLTIP_32_32 = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	tile = true,
	tileSize = 32,
	insets = { left = 10, right = 10, top = 10, bottom = 6 },
}


BACKDROP_TUTORIAL_16_16 = {
	bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 3, right = 5, top = 3, bottom = 5 },
}

BACKDROP_TOOLTIP_8_12_1111 = { -- Removed, forced to support.
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

BackdropTemplateMixin = BackdropTemplateMixin or {}

local max = math.max
local NineSliceUtil = NineSliceUtil

local coordStart = 0.0625
local coordEnd = 1 - coordStart
local defaultEdgeSize = 39

-- List of backdrop piece names
local PIECE_NAMES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge"
}

-- UV coordinate data for edges and corners
local UV_DATA = {
    TopLeftCorner     = { 1, 1, 0.5078125, coordStart, 0.5078125, coordEnd, 0.6171875, coordStart, 0.6171875, coordEnd },
    TopRightCorner    = { 1, 1, 0.6328125, coordStart, 0.6328125, coordEnd, 0.7421875, coordStart, 0.7421875, coordEnd },
    BottomLeftCorner  = { 1, 1, 0.7578125, coordStart, 0.7578125, coordEnd, 0.8671875, coordStart, 0.8671875, coordEnd },
    BottomRightCorner = { 1, 1, 0.8828125, coordStart, 0.8828125, coordEnd, 0.9921875, coordStart, 0.9921875, coordEnd },
    TopEdge           = { 0, 1, 0.2578125, -1,         0.3671875, -1,         0.2578125, coordStart, 0.3671875, coordStart },
    BottomEdge        = { 0, 1, 0.3828125, -1,         0.4921875, -1,         0.3828125, coordStart, 0.4921875, coordStart },
    LeftEdge          = { 1, 0, 0.0078125, coordStart, 0.0078125, -2,         0.1171875, coordStart, 0.1171875, -2 },
    RightEdge         = { 1, 0, 0.1328125, coordStart, 0.1328125, -2,         0.2421875, coordStart, 0.2421875, -2 },
}

-- UV coordinate data for the center background
local CENTER_UV = { 0, 0, 0, -2, -1, 0, -1, -2 }

-- Reusable layout definition for NineSlice
local SHARED_LAYOUT = {
    TopLeftCorner = {}, TopRightCorner = {}, BottomLeftCorner = {}, BottomRightCorner = {},
    TopEdge = {}, BottomEdge = {}, LeftEdge = {}, RightEdge = {},
    Center = { layer = "BACKGROUND" },
    setupPieceVisualsFunction = nil,
}

-- Helper to resolve texture coordinates
local function GetCoord(val, rX, rY)
    if val == -1 then return rX end
    if val == -2 then return rY end
    return val
end

-- Initialize backdrop when the frame is loaded
function BackdropTemplateMixin:OnBackdropLoaded()
    local info = self.backdropInfo
    if info then
        if not info.edgeFile and not info.bgFile then
            self.backdropInfo = nil
            return
        end
        self:ApplyBackdrop()
        if self.backdropColor then
            local r, g, b = self.backdropColor:GetRGB()
            self:SetBackdropColor(r, g, b, self.backdropColorAlpha or 1)
        end
        if self.backdropBorderColor then
            local r, g, b = self.backdropBorderColor:GetRGB()
            self:SetBackdropBorderColor(r, g, b, self.backdropBorderColorAlpha or 1)
        end
        if self.backdropBorderBlendMode then
            self:SetBorderBlendMode(self.backdropBorderBlendMode)
        end
    end
end

-- Update coordinates when the frame size changes
function BackdropTemplateMixin:OnBackdropSizeChanged()
    if self.backdropInfo then self:SetupTextureCoordinates() end
end

-- Get current backdrop edge size
function BackdropTemplateMixin:GetEdgeSize()
    local edgeSize = self.backdropInfo.edgeSize
    return (edgeSize and edgeSize > 0) and edgeSize or defaultEdgeSize
end

-- Calculate and apply texture coordinates for all pieces
function BackdropTemplateMixin:SetupTextureCoordinates()
    local info = self.backdropInfo
    local w, h = self:GetSize()
    local scale = self:GetEffectiveScale()
    local edgeSize = self:GetEdgeSize()

    local edgeRepeatX = max(0, (w / edgeSize) * scale - 2 - coordStart)
    local edgeRepeatY = max(0, (h / edgeSize) * scale - 2 - coordStart)

    local center = self.Center
    if center then
        local rX, rY = 1, 1
        if info.tile then
            local div = (info.tileSize and info.tileSize > 0) and info.tileSize or edgeSize
            rX, rY = (w / div) * scale, (h / div) * scale
        end
        center:SetTexCoord(
            GetCoord(CENTER_UV[1], rX, rY), GetCoord(CENTER_UV[2], rX, rY),
            GetCoord(CENTER_UV[3], rX, rY), GetCoord(CENTER_UV[4], rX, rY),
            GetCoord(CENTER_UV[5], rX, rY), GetCoord(CENTER_UV[6], rX, rY),
            GetCoord(CENTER_UV[7], rX, rY), GetCoord(CENTER_UV[8], rX, rY)
        )
    end

    for i = 1, #PIECE_NAMES do
        local name = PIECE_NAMES[i]
        local region = self[name]
        if region then
            local d = UV_DATA[name]
            region:SetTexCoord(
                GetCoord(d[3], edgeRepeatX, edgeRepeatY), GetCoord(d[4], edgeRepeatX, edgeRepeatY),
                GetCoord(d[5], edgeRepeatX, edgeRepeatY), GetCoord(d[6], edgeRepeatX, edgeRepeatY),
                GetCoord(d[7], edgeRepeatX, edgeRepeatY), GetCoord(d[8], edgeRepeatX, edgeRepeatY),
                GetCoord(d[9], edgeRepeatX, edgeRepeatY), GetCoord(d[10], edgeRepeatX, edgeRepeatY)
            )
        end
    end
end

-- NineSlice callback to set texture and size for each piece
function BackdropTemplateMixin:SetupPieceVisuals(piece, setupInfo, pieceLayout)
    local name = setupInfo.pieceName
    local info = self.backdropInfo
    local edgeSize = self:GetEdgeSize()

    if name == "Center" then
        piece:SetTexture(info.bgFile, info.tile, info.tile)
        piece:SetSize(0, 0)
    else
        local uv = UV_DATA[name]
        local tileEdge = (info.tileEdge ~= false)
        piece:SetTexture(info.edgeFile, tileEdge, tileEdge)
        piece:SetSize(uv[1] == 1 and edgeSize or 0, uv[2] == 1 and edgeSize or 0)
    end
end

-- Set the blend mode for the border textures
function BackdropTemplateMixin:SetBorderBlendMode(blendMode)
    if not self.backdropInfo then return end
    for i = 1, #PIECE_NAMES do
        local region = self[PIECE_NAMES[i]]
        if region then region:SetBlendMode(blendMode) end
    end
end

-- Check if a specific backdrop info is already set
function BackdropTemplateMixin:HasBackdropInfo(info)
    return self.backdropInfo == info
end

-- Remove backdrop textures and clear info
function BackdropTemplateMixin:ClearBackdrop()
    if self.backdropInfo then
        if self.Center then self.Center:SetTexture(nil) end
        for i = 1, #PIECE_NAMES do
            local region = self[PIECE_NAMES[i]]
            if region then region:SetTexture(nil) end
        end
        self.backdropInfo = nil
    end
end

-- Set up NineSlice layout and apply backdrop
function BackdropTemplateMixin:ApplyBackdrop()
    local info = self.backdropInfo
    local center = SHARED_LAYOUT.Center
    if info.bgFile then
        local edgeSize = self:GetEdgeSize()
        local insets = info.insets
        center.x  = -edgeSize + (insets and insets.left or 0)
        center.y  =  edgeSize - (insets and insets.top or 0)
        center.x1 =  edgeSize - (insets and insets.right or 0)
        center.y1 = -edgeSize + (insets and insets.bottom or 0)
    else
        center.x, center.y, center.x1, center.y1 = 0, 0, 0, 0
    end
    SHARED_LAYOUT.setupPieceVisualsFunction = self.SetupPieceVisuals
    NineSliceUtil.ApplyLayout(self, SHARED_LAYOUT)
    self:SetupTextureCoordinates()
end

-- Public API to set a new backdrop
function BackdropTemplateMixin:SetBackdrop(info)
    if info then
        if self:HasBackdropInfo(info) then return end
        if not info.edgeFile and not info.bgFile then
            self:ClearBackdrop()
            return
        end
        self.backdropInfo = info
        self:ApplyBackdrop()
    else
        self:ClearBackdrop()
    end
end

-- Public API to get the current backdrop definition
function BackdropTemplateMixin:GetBackdrop()
    local info = self.backdropInfo
    if not info then return nil end
    local ins = info.insets or {}
    return {
        bgFile = info.bgFile or "",
        edgeFile = info.edgeFile or "",
        tile = (info.tile ~= nil) and info.tile or false,
        tileSize = info.tileSize or 0,
        tileEdge = (info.tileEdge ~= nil) and info.tileEdge or true,
        edgeSize = info.edgeSize or self:GetEdgeSize(),
        insets = { left = ins.left or 0, right = ins.right or 0, top = ins.top or 0, bottom = ins.bottom or 0 }
    }
end

-- Get current backdrop background color
function BackdropTemplateMixin:GetBackdropColor()
    return self.Center and self.Center:GetVertexColor()
end

-- Set backdrop background color
function BackdropTemplateMixin:SetBackdropColor(r, g, b, a)
    if self.Center then self.Center:SetVertexColor(r, g, b, a or 1) end
end

-- Get current backdrop border color
function BackdropTemplateMixin:GetBackdropBorderColor()
    if not self.backdropInfo then return end
    local region = self.TopLeftCorner or self.TopEdge
    return region and region:GetVertexColor()
end

-- Set backdrop border color
function BackdropTemplateMixin:SetBackdropBorderColor(r, g, b, a)
    if not self.backdropInfo then return end
    a = a or 1
    for i = 1, #PIECE_NAMES do
        local region = self[PIECE_NAMES[i]]
        if region then region:SetVertexColor(r, g, b, a) end
    end
end