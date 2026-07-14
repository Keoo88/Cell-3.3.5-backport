local _, Private = ...

local _G = _G
local Type = type
local PCall = pcall
local Pairs = pairs
local Error = error
local Deg = math.deg
local Select = select
local Sqrt = math.sqrt
local GetTime = GetTime
local Atan2 = math.atan2
local Gsub = string.gsub
local Format = string.format
local CreateFrame = CreateFrame
local GetMetaTable = getmetatable
local HookSecureFunc = hooksecurefunc

local EventHandler = Private.EventHandler
local UIObject, UIObjectLine

--[[

	WidgetAPI is a system to automatically add or modify the methods/functions on an object.
	You can define custom methods within the "UIObject" table.

	This code implements inheritance. All child objects receive the methods of the parent object.
	Therefore, you only need to add methods to root objects.

	Information:
		-- https://warcraft.wiki.gg/wiki/Widget_API
		-- https://warcraft.wiki.gg/wiki/Widget_API?oldid=348056 (3.3.5)
		-- https://warcraft.wiki.gg/wiki/Widget_API#/media/File:Widget_Hierarchy.png

	Example:
		The SetShown method is listed in the "ScriptRegion" section.
		So we define it in the "ScriptRegion" table.
		This method will be automatically inherited by all child objects.

		Thus, the SetShown method will be inherited by the Region, FontString, Frame, QuestPOIFrame,
		Model, PlayerModel, DressUpModel, TabardModel, Button, CheckButton, EditBox, MessageFrame,
		ScrollingMessageFrame, SimpleHTML, ColorSelect, Cooldown, GameTooltip, ScrollFrame, Slider,
		StatusBar, Minimap, WorldFrame, MovieFrame

		If method(s) already exist define a "Prehook" or "Posthook" table within the object class:
			FrameScriptObject = {
				Posthook = {
					GetName = function()end
					...
				}
				...
			}

		To avoid collision/errors with other addons (eg. self.duration), we prefix object stored data with "_".

]]

UIObject = {
	FrameScriptObject = {
		IsForbidden = function(Self) return Self._Forbidden or false end,
		SetForbidden = function(Self) Self._Forbidden = true end,
	},

	Object = {
		ClearParentKey = function(Self)
			local Parent = Self:GetParent()
			if ( Parent ) then
				for ParentKey, Reference in Pairs(Parent) do
					if ( ParentKey == Self ) then
						Parent[ParentKey] = nil
					end
				end
			end
		end,

		GetDebugName = function(Self)
			-- In the original method, for anonymous frames (those without a name),
			-- a memory address is returned, but the game, of course, does not have access to memory,
			-- so in the current implementation, for anonymous frames, it will make a hexadecimal dump of the object return.
			local Name = Self:GetName()
			if ( Name ) then
				return Name
			end

			local Parent = Self:GetParent()
			if ( not Parent ) then
				return ""
			end

			-- Resolve parent identification (Name or Hex)
			-- Resolve child identification (ParentKey or Hex)
			local ParentRef = Parent:GetName() or Gsub(tostring(Parent), "table: ", "")
			local ChildRef = Self:GetParentKey() or Gsub(tostring(Self), "table: ", "")

			return ParentRef .. "." .. ChildRef
		end,

		GetParentKey = function(Self)
			local Parent = Self:GetParent()
			if ( Parent ) then
				for ParentKey, Reference in Pairs(Parent) do
					if ( Reference == Self ) then
						return ParentKey
					end
				end
			end
		end,

		SetParentKey = function(Self, ParentKey, ClearOtherKeys)
			local Parent = Self:GetParent()
			if ( Parent ) then
				if ( ClearOtherKeys ) then
					Self:ClearParentKey()
				end
				Parent[ParentKey] = Self
			end
		end,
	},

	ScriptRegion = {
		GetScaledRect = function(Self)
			local Left, Bottom, Width, Height = Self:GetRect()
			if ( Left ) then
				local Scale = Self:GetEffectiveScale()
				return Left*Scale, Bottom*Scale, Width*Scale, Height*Scale
			end
		end,

		IsRectValid = function(Self)
			local Left = Self:GetLeft()
			local Right = Self:GetRight()
			local Top = Self:GetTop()
			local Bottom = Self:GetBottom()

			if ( not (Left and Right and Top and Bottom) ) then
				return false
			end

			if ( Left > Right or Bottom > Top ) then
				return false
			end

			if ( (Right - Left) <= 0 or (Top - Bottom) <= 0 ) then
				return false
			end

			return true
		end,

		SetShown = function(Self, State)
			if ( State ) then Self:Show() else Self:Hide() end
		end,

		AdjustPointsOffset = function(Self, AdjustX, AdjustY)
			if ( not AdjustX and not AdjustY ) then
				Error(Format('Usage: %s:AdjustPointsOffset(adjustX, adjustY)', Self:GetName() or '<unnamed>'), 2)
			end

			AdjustX = AdjustX or 0
			AdjustY = AdjustY or 0

			for i=1, Self:GetNumPoints() do
				local Point, RelativeTo, RelativePoint, OffsetX, OffsetY = Self:GetPoint(i)
				Self:SetPoint(Point, RelativeTo, RelativePoint, OffsetX+AdjustX, OffsetY+AdjustY)
			end
		end,

		ClearPointsOffset = function(Self)
			for i=1, Self:GetNumPoints() do
				local Point, RelativeTo, RelativePoint = Self:GetPoint(i)
				Self:SetPoint(Point, RelativeTo, RelativePoint, 0, 0)
			end
		end,

		GetPointByName = function(Self, Point)
			for i=1, Self:GetNumPoints() do
				local PointName, RelativeTo, RelativePoint, OffsetX, OffsetY = Self:GetPoint(i)
				if ( Point == PointName ) then
					return Point, RelativeTo, RelativePoint, OffsetX, OffsetY
				end
			end
		end,

		SetPointsOffset = function(Self, X, Y)
			for i=1, Self:GetNumPoints() do
				local Point, RelativeTo, RelativePoint = Self:GetPoint(i)
				Self:SetPoint(Point, RelativeTo, RelativePoint, X, Y)
			end
		end,

		IsIgnoringParentAlpha = function(Self) return Self._IgnoreParentAlpha or false end,
		IsIgnoringParentScale = function(Self) return Self._IgnoreParentScale or false end,

		SetIgnoreParentAlpha = function(Self, Ignore)
			-- Incomplete, placeholder, potentially impossible to implement
			Self._IgnoreParentAlpha = Ignore
		end,

		SetIgnoreParentScale = function(Self, Ignore)
			-- Incomplete, placeholder, potentially impossible to implement
			Self._IgnoreParentScale = Ignore
		end,
	},

	Region = {
		GetEffectiveScale = function(Self)
			return Self:GetParent():GetEffectiveScale()
		end,
	},

	TextureBase = {
		GetAtlas = function(Self)
			return Self._Atlas
		end,

		GetDesaturation = function(Self)
			return Self._Desaturation
		end,

		GetRotation = function(Self)
			return Self._Angle or 0, Self._Cx or 0, Self._Cy or 0
		end,

		GetTexelSnappingBias = function(Self)
			return Self._SnappingBias or 0
		end,

		GetTextureFilePath = function(Self)
			return Self:GetTexture()
		end,

		IsSnappingToPixelGrid = function(Self)
			return Self._SnappingToPixelGrid
		end,

		SetAtlas = function(Self, AtlasName, UseAtlasSize, FilterMode, ResetTexCoords)
			if ( not AtlasName ) then
				Error(Format('Usage: %s:SetAtlas("atlasName"[, useAtlasSize, filterMode, resetTexCoords])', Self:GetName() or '<unnamed>'), 2)
			end

			local AtlasInfo = C_Texture.AtlasData[AtlasName] -- C_Texture.GetAtlasInfo(AtlasName)
			if ( AtlasInfo ) then
				-- Unpack(AtlasInfo)
				local Width             = AtlasInfo[1]
				local Height            = AtlasInfo[2]
				local LeftTexCoord      = AtlasInfo[3]
				local RightTexCoord     = AtlasInfo[4]
				local TopTexCoord       = AtlasInfo[5]
				local BottomTexCoord    = AtlasInfo[6]
				local TilesHorizontally = AtlasInfo[7]
				local TilesVertically   = AtlasInfo[8]
				local Path              = AtlasInfo[9]

				Self:SetTexture(Path or "")
				Self:SetTexCoord(LeftTexCoord, RightTexCoord, TopTexCoord, BottomTexCoord)
				Self:SetVertTile(TilesVertically)
				Self:SetHorizTile(TilesHorizontally)

				if ( UseAtlasSize ) then
					Self:SetSize(Width, Height)
				end

				Self._Atlas = AtlasName
			end
		end,

		SetColorTexture = function(Self, R, G, B, A)
			if ( not R and not G and not B ) then
				Error(Format('Usage: %s:SetColorTexture(red, green, blue[, alpha])', Self:GetName() or '<unnamed>'), 2)
			end
			Self:SetTexture(R, G, B, A or 1)
		end,

		SetDesaturation = function(Self, Desaturation)
			Self:SetDesaturated(Desaturation)
			Self._Desaturation = Desaturation
		end,

		SetMask = Private.Void, -- Incomplete, placeholder, potentially impossible to implement

		SetSnapToPixelGrid = function(Self, Snap)
			-- Incomplete, placeholder, potentially impossible to implement
			Self._SnappingToPixelGrid = Snap
		end,

		SetTexelSnappingBias = function(Self, Bias)
			-- Incomplete, placeholder, potentially impossible to implement
			Self._SnappingBias = Bias
		end,

		PostHook = {
			SetRotation = function(Self, Angle)
				Self._Angle = Angle
				Self._Cx = 0.5
				Self._Cy = 0.5
				return Self._Angle, Self._Cx, Self._Cy
			end
		},
	},

	Texture = {
		AddMaskTexture = Private.Void,
		GetMaskTexture = Private.Void,
		GetNumMaskTextures = Private.Zero,
		RemoveMaskTexture = Private.Void,
	},

	FontString = {
		ClearText = function(Self)
			Self:SetText("")
		end,

		GetFontHeight = function(Self)
			local _, FontHeight = Self:GetFont()
			return Round(FontHeight) -- equivalent GetLineHeight
		end,

		GetLineHeight = function(Self)
			local _, FontSize = Self:GetFont()
			return Round(FontSize) -- equivalent GetFontHeight
		end,

		GetMaxLines = function(Self)
			return Round(Self:GetHeight() / (Self:GetLineHeight() + Self:GetSpacing()))
		end,

		GetNumLines = function(Self)
			local HeightMultiplier = 1.05445
			return Round((Self:GetStringHeight() * HeightMultiplier) / Self:GetLineHeight())
		end,

		GetTextScale = function(Self, Text)
			return Self._TextScale or 1
		end,

		GetUnboundedStringWidth = function(Self)
			local OldWidth = Self:GetWidth()
			Self:SetWidth(0)
			local Width = Self:GetStringWidth()
			Self:SetWidth(OldWidth)
			return Width
		end,

		IsTruncated = function(Self)
			local OldWidth = Self:GetWidth()
			if ( not OldWidth or OldWidth == 0 ) then return false end
			Self:SetWidth(0)
			local NaturalWidth = Self:GetStringWidth()
			Self:SetWidth(OldWidth)
			return (NaturalWidth > (OldWidth + 0.1))
		end,

		SetFontHeight = function(Self, Height)
			local File = Self:GetFont()
			Self:SetFont(File, Height)
		end,

		SetTextScale = function(Self, TextScale)
			if ( Self._TextScale == TextScale ) then return end

			local FontFile, FontHeight, FontFlags = Self:GetFont()
			local OrigFontHeight = Self._OrigFontHeight or FontHeight

			Self:SetFont(FontFile, OrigFontHeight * TextScale, FontFlags)
			Self._OrigFontHeight = FontHeight
			Self._TextScale = TextScale
		end,

		SetTextToFit = function(Self, Text)
			Self:SetWidth(0)
			if ( Text ) then
				Self:SetText(text)
			end
		end,

		PostHook = {
			SetFont = function(Self, Font, Height)
				Self._OrigFontHeight = Height
			end
		},
	},

	AnimationGroup = {
		Restart = function(Self)
			Self:Stop()
			Self:Play()
		end,

		SetPlaying = function(Self, Play)
			if ( Play ) then Self:Play() else Self:Stop() end
		end,
	},

	Animation = {
		Restart = function(Self)
			Self:Stop()
			Self:Play()
		end,

		SetPlaying = function(Self, Play)
			if ( Play ) then Self:Play() else Self:Stop() end
		end,
	},

	Alpha = {
		GetFromAlpha = function(Self)
			return Self._FromAlpha or 0
		end,

		GetToAlpha = function(Self)
			return Self._ToAlpha or 0
		end,

		SetFromAlpha = function(Self, From)
			if ( Type(From) ~= "number" ) then
				Error(Format('Usage: %s:SetFromAlpha(from)', Self:GetName() or '<unnamed>'), 2)
			end

			Self._FromAlpha = From

			if ( Self._ToAlpha ) then
				Self:SetChange(Self._ToAlpha - From)
			end
		end,

		SetToAlpha = function(Self, To)
			if ( Type(To) ~= "number" ) then
				Error(Format('Usage: %s:SetToAlpha(to)', Self:GetName() or '<unnamed>'), 2)
			end

			Self._ToAlpha = To

			if ( Self._FromAlpha ) then
				Self:SetChange(To - Self._FromAlpha)
			end
		end,
	},

	Scale = {
		GetScaleFrom = function(Self)
			return Self._ScaleFromX or 0, Self._ScaleFromY or 0
		end,

		GetScaleTo = function(Self)
			return Self._ScaleToX or 0, Self._ScaleToY or 0
		end,

		SetScaleFrom = function(Self, ScaleX, ScaleY)
			if ( Type(ScaleX) ~= "number" or Type(ScaleY) ~= "number" ) then
				Error(Format('Usage: %s:SetScaleFrom(scaleX, scaleY)', Self:GetName() or '<unnamed>'), 2)
			end

			Self._ScaleFromX = ScaleX
			Self._ScaleFromY = ScaleY

			if ( Self._ScaleToX and Self._ScaleToY ) then
				Self:SetScale(Self._ScaleToX - ScaleX, Self._ScaleToY - ScaleY)
			end
		end,

		SetScaleTo = function(Self, ScaleX, ScaleY)
			if ( Type(ScaleX) ~= "number" or Type(ScaleY) ~= "number" ) then
				Error(Format('Usage: %s:SetScaleTo(scaleX, scaleY)', Self:GetName() or '<unnamed>'), 2)
			end

			Self._ScaleToX = ScaleX
			Self._ScaleToY = ScaleY

			if ( Self._ScaleFromX and Self._ScaleFromY ) then
				Self:SetScale(ScaleX - Self._ScaleFromX, ScaleY - Self._ScaleFromY)
			end
		end,
	},

	Frame = {
		CreateMaskTexture = Private.Void, -- Incomplete, placeholder, potentially impossible to implement

		DesaturateHierarchy = function(Self, Desaturation, ExcludeRoot)
			local ScanRegions, ScanChildren

			ScanRegions = function(Region, ...)
				if ( not Region ) then return end

				if ( Region:IsObjectType("Texture") ) then
					Region:SetDesaturation(Desaturation)
				end

				return ScanRegions(...)
			end

			ScanChildren = function(Child, ...)
				if ( not Child ) then return end

				ScanRegions(Child:GetRegions())
				ScanChildren(Child:GetChildren())

				return ScanChildren(...)
			end

			if ( not ExcludeRoot ) then
				ScanRegions(Self:GetRegions())
			end

			ScanChildren(Self:GetChildren())
		end,

		DoesClipChildren = function(Self)
			return (Self._ClipsChildren and Self._ClipsChildren:IsShown())
		end,

		GetResizeBounds = function(Self)
			local MinWidth, MinHeight = Self:GetMinResize()
			local MaxWidth, MaxHeight = Self:GetMaxResize()
			return MinWidth, MinHeight, MaxWidth, MaxHeight
		end,

		IsUsingParentLevel = function(Self)
			return Self._UsingParentLevel or false
		end,

		SetClipsChildren = function(Self, ClipsChildren)
			local Mask = Self._ClipsChildren

			if ( ClipsChildren ) then
				if ( not Mask or not Mask:IsShown() ) then
					if ( not Mask ) then
						Mask = CreateFrame("ScrollFrame", nil, Self:GetParent())
						Self._ClipsChildren = Mask
					end

					Mask:SetSize(Self:GetSize())
					for i = 1, Self:GetNumPoints() do
						Mask:SetPoint(Self:GetPoint(i))
					end

					Self:SetParent(Mask)
					Mask:SetScrollChild(Self)

					Mask:Show()
				end
			elseif ( Mask and Mask:IsShown() ) then
				Mask:SetScrollChild(nil)
				Self:SetParent(Mask:GetParent())

				Self:ClearAllPoints()
				for i = 1, Mask:GetNumPoints() do
					Self:SetPoint(Mask:GetPoint(i))
				end

				Mask:Hide()
			end
		end,

		RegisterEventCallback = EventHandler.RegisterEventCallback,
		RegisterUnitEvent = EventHandler.RegisterUnitEvent,
		RegisterUnitEventCallback = EventHandler.RegisterUnitEventCallback,
		UnregisterEventCallback = EventHandler.UnregisterEventCallback,
		UnregisterUnitEventCallback = EventHandler.UnregisterUnitEventCallback,

		SetResizeBounds = function(Self, MinWidth, MinHeight, MaxWidth, MaxHeight)
			Self:SetMinResize(MinWidth, MinHeight)
			if ( MaxWidth and MaxHeight ) then
				Self:SetMaxResize(MaxWidth, MaxHeight)
			end
		end,

		SetUsingParentLevel = function(Self, UsingParentLevel)
			if ( Self._UsingParentLevel ~= UsingParentLevel ) then
				if ( UsingParentLevel ) then
					Self._OrigFrameLevel = Self:GetFrameLevel()
					Self:SetFrameLevel(Self:GetParent():GetFrameLevel())
				elseif ( Self._OrigFrameLevel ) then
					Self:SetFrameLevel(Self._OrigFrameLevel)
					Self._OrigFrameLevel = nil
				end

				Self._UsingParentLevel = UsingParentLevel
			end
		end,

		CreateLine = function(Self, Name, Layer, Template, SubLevel)
			local Line = Self:CreateTexture(Name, Layer, Template, SubLevel)

			-- Lazy-load "Line" methods to reduce resources/GC.
			UIObjectLine = UIObjectLine or {
				SetThickness = function(Self, Thickness)
					Self._Thickness = Thickness
					Self:UpdateTransform()
				end,

				GetThickness = function(Self)
					return Self._Thickness or 4
				end,

				SetStartPoint = function(Self, Point, RelativeTo, OffsetX, OffsetY)
					if ( Type(RelativeTo) == "number" ) then
						OffsetY = OffsetX
						OffsetX = RelativeTo
						RelativeTo = nil
					end

					Self._StartAnchor = Point or "CENTER"
					Self._StartRelative = RelativeTo
					Self._StartX = OffsetX or 0
					Self._StartY = OffsetY or 0

					Self:UpdateTransform()
				end,

				GetStartPoint = function(Self)
					return Self._StartAnchor, Self._StartRelative, Self._StartX, Self._StartY
				end,

				SetEndPoint = function(Self, Point, RelativeTo, OffsetX, OffsetY)
					if ( Type(RelativeTo) == "number" ) then
						OffsetY = OffsetX
						OffsetX = RelativeTo
						RelativeTo = nil
					end

					Self._EndAnchor = Point or "CENTER"
					Self._EndRelative = RelativeTo
					Self._EndX = OffsetX or 0
					Self._EndY = OffsetY or 0

					Self:UpdateTransform()
				end,

				GetEndPoint = function(Self)
					return Self._EndAnchor, Self._EndRelative, Self._EndX, Self._EndY
				end,

				UpdateTransform = function(Self)
					local Parent = Self:GetParent()
					if ( not Parent ) then return end

					local ParentLeft, ParentBottom, ParentWidth, ParentHeight = Parent:GetRect()
					if ( not ParentLeft ) then return end

					local ParentScale = Parent:GetEffectiveScale()
					local IsUIParent = (Parent == _G.UIParent)

					local function GetLocalCoordinates(Anchor, RelativeObject, OffsetX, OffsetY)
						local Target = RelativeObject or Parent
						local TargetLeft, TargetBottom, TargetWidth, TargetHeight = Target:GetRect()

						if ( not TargetLeft ) then return 0, 0 end

						Anchor = Anchor or "CENTER"

						-- Get Target in Scaled Screen Space
						local TargetX, TargetY = TargetLeft, TargetBottom
						if ( Anchor:find("RIGHT") ) then TargetX = TargetX + TargetWidth end
						if ( Anchor:find("TOP") ) then TargetY = TargetY + TargetHeight end
						if ( Anchor:find("CENTER") ) then
							TargetX = TargetX + (TargetWidth / 2)
							TargetY = TargetY + (TargetHeight / 2)
						end

						-- Normalize based on Anchor Type
						if ( IsUIParent ) then
							-- Calculate distance from SCREEN CENTER in UI Units
							local ScreenCenterX = ParentLeft + (ParentWidth / 2)
							local ScreenCenterY = ParentBottom + (ParentHeight / 2)
							return (TargetX - ScreenCenterX) / ParentScale + (OffsetX or 0),
							       (TargetY - ScreenCenterY) / ParentScale + (OffsetY or 0)
						else
							-- Standard relative offset for local frames
							return (TargetX - ParentLeft) / ParentScale + (OffsetX or 0),
							       (TargetY - ParentBottom) / ParentScale + (OffsetY or 0)
						end
					end

					local StartX, StartY = GetLocalCoordinates(Self._StartAnchor, Self._StartRelative, Self._StartX, Self._StartY)
					local EndX, EndY = GetLocalCoordinates(Self._EndAnchor, Self._EndRelative, Self._EndX, Self._EndY)

					-- Geometry Logic
					local DeltaX, DeltaY = EndX - StartX, EndY - StartY
					local Distance = Sqrt(DeltaX * DeltaX + DeltaY * DeltaY)
					local Angle = Atan2(DeltaY, DeltaX)

					Self:SetSize(Distance > 0 and Distance or 0.001, Self._Thickness or 4)
					Self:ClearAllPoints()

					local MidX, MidY = (StartX + EndX) / 2, (StartY + EndY) / 2

					if ( IsUIParent ) then
						Self:SetPoint("CENTER", Parent, "CENTER", MidX, MidY)
					else
						Self:SetPoint("CENTER", Parent, "BOTTOMLEFT", MidX, MidY)
					end

					-- Rotation
					if ( not Self._AnimationGroup ) then
						Self._AnimationGroup = Self:CreateAnimationGroup()
						Self._Rotation = Self._AnimationGroup:CreateAnimation("Rotation")
						Self._Rotation:SetDuration(0)
						Self._Rotation:SetEndDelay(2)
					end

					Self._Rotation:SetDegrees(Deg(Angle))
					Self._AnimationGroup:Play()

					C_Timer.After(0, function() Self._AnimationGroup:Pause() end)
				end,
			}

			-- Inject line-specific methods.
			for MethodName, Function in Pairs(UIObjectLine) do
				Line[MethodName] = Function
			end

			Line._Thickness = 4
			return Line
		end,

		PostHook = {
			RegisterEvent = EventHandler.RegisterEvent,
			UnregisterEvent = EventHandler.UnregisterEvent,
			RegisterAllEvents = EventHandler.RegisterAllEvents,
			UnregisterAllEvents = EventHandler.UnregisterAllEvents,
		},
	},

	Button = {
		ClearDisabledTexture = function(Self)
			local Texture = Self:GetDisabledTexture()
			if ( Texture ) then
				Self:SetDisabledTexture("")
			end
		end,

		ClearHighlightTexture = function(Self)
			local Texture = Self:GetHighlightTexture()
			if ( Texture ) then
				Self:SetHighlightTexture("")
			end
		end,

		ClearNormalTexture = function(Self)
			local Texture = Self:GetNormalTexture()
			if ( Texture ) then
				Self:SetNormalTexture("")
			end
		end,

		ClearPushedTexture = function(Self)
			local Texture = Self:GetPushedTexture()
			if ( Texture ) then
				Self:SetPushedTexture("")
			end
		end,

		SetDisabledAtlas = function(Self, AtlasName)
			if ( not AtlasName ) then
				Error(Format('Usage: %s:SetDisabledAtlas("atlasName")', Self:GetName() or '<unnamed>'), 2)
			end
			local Texture = Self:GetDisabledTexture()
			if ( not Texture ) then
				Self:SetDisabledTexture("")
				Texture = Self:GetDisabledTexture()
			end
			Texture:SetAtlas(AtlasName)
		end,

		SetHighlightAtlas = function(Self, AtlasName)
			if ( not AtlasName ) then
				Error(Format('Usage: %s:SetHighlightAtlas("atlasName")', Self:GetName() or '<unnamed>'), 2)
			end
			local Texture = Self:GetHighlightTexture()
			if ( not Texture ) then
				Self:SetHighlightTexture("")
				Texture = Self:GetHighlightTexture()
			end
			Texture:SetAtlas(AtlasName)
		end,

		SetNormalAtlas = function(Self, AtlasName)
			if ( not AtlasName ) then
				Error(Format('Usage: %s:SetNormalAtlas("atlasName")', Self:GetName() or '<unnamed>'), 2)
			end
			local Texture = Self:GetNormalTexture()
			if ( not Texture ) then
				Self:SetNormalTexture("")
				Texture = Self:GetNormalTexture()
			end
			Texture:SetAtlas(AtlasName)
		end,

		SetPushedAtlas = function(Self, AtlasName)
			if ( not AtlasName ) then
				Error(Format('Usage: %s:SetPushedAtlas("atlasName")', Self:GetName() or '<unnamed>'), 2)
			end
			local Texture = Self:GetPushedTexture()
			if ( not Texture ) then
				Self:SetPushedTexture("")
				Texture = Self:GetPushedTexture()
			end
			Texture:SetAtlas(AtlasName)
		end,

		SetEnabled = function(Self, Enabled)
			if ( Enabled ) then Self:Enable() else Self:Disable() end
		end,
	},

	Model = {
		SetTransform = function(Self, X, Y, Z, Rotation, Scale)
			-- TODO: Vector3D/Vector2D
			Self:SetPosition(X or 0, Y or 0, Z or 0)

			if ( Rotation ) then
				Self:SetFacing(Rotation)
			end

			if ( Scale ) then
				Self:SetModelScale(Scale)
			end
		end,

		ClearTransform = function(Self)
			Self:SetModelScale(1)
			Self:SetPosition(0, 0, 0)
			Self:SetFacing(0)

			if ( Self.RefreshUnit ) then
				Self:RefreshUnit()
			end
		end,
	},

	PlayerModel = {
		SetPortraitZoom = function(Self, ZoomLevel)
			local X, Y, Z = Self:GetPosition()
			Self:SetPosition(ZoomLevel * (Self.portraitZoomMultiplier or 1) * Self:GetModelScale(), Y, Z)
		end,
	},

	EditBox = {
		Enable = function(Self)
			Self._Enabled = true
			Self:SetFontObject("GameFontWhite")
			Self:EnableMouse(true)
			Self:ClearFocus()
			local Script = Self:GetScript("OnEnable")
			if ( Script ) then
				Script(Self)
			end
		end,

		Disable = function(Self)
			Self._Enabled = nil
			Self:SetFontObject("GameFontDisable")
			Self:EnableMouse(false)
			Self:ClearFocus()
			local Script = Self:GetScript("OnDisable")
			if ( Script ) then
				Script(Self)
			end
		end,

		SetEnabled = function(Self, State)
			if ( State ) then
				Self:Enable()
			else
				Self:Disable()
			end
		end,

		IsEnabled = function(Self)
			return Self._Enabled or false
		end,
	},

	SimpleHTML = {
		GetContentHeight = function(Self)
			-- Get all regions, this also includes <img> generated images.
			-- Note: More object validation is required if external regions are attached.

			local Top = Self:GetTop()
			if ( not Top ) then return 0 end

			local function GetBottom(Bottom, Region, ...)
				if ( not Region ) then return Bottom end
				if ( Region:GetDrawLayer() == "ARTWORK" ) then
					Bottom = Region
				end
				return GetBottom(Bottom, ...)
			end

			local Bottom = GetBottom(nil, Self:GetRegions())
			return (Bottom) and (Top - Bottom:GetBottom()) or 0
		end,

		GetText = function(Self)
			return Self._HTMLText
		end,

		PostHook = {
			SetText = function(Self, Text)
				Self._HTMLText = Text
			end
		}
	},

	GameTooltip = {
		SetItemByID = function(Self, ItemID)
			if ( not ItemID ) then
				Error(Format('Usage: %s:SetItemByID(itemID)', Self:GetName() or '<unnamed>'), 2)
			end
			Self:SetHyperlink("item:"..ItemID)
		end,

		GetLeftLine = function(Self, Line)
			return _G[Self:GetName().."TextLeft"..Line]
		end,

		GetRightLine = function(Self, Line)
			return _G[Self:GetName().."TextRight"..Line]
		end,
	},

	Cooldown = {
		Clear = _G.UIParent.Hide,

		GetCooldownDuration = function(Self)
			if ( Self._PauseDuration ) then return Self._PauseDuration end

			local Start, Duration = Self._Start or 0, Self._Duration or 0
			if ( Duration > 0 and (Duration - (GetTime() - Start) <= 0) ) then
				Self._Start, Self._Duration = 0, 0
				return 0
			end

			return Duration
		end,

		GetCooldownTimes = function(Self)
			-- If paused, reconstruct the "True" start time
			if ( Self._PauseDuration ) then
				return GetTime() - (Self._PauseElapsed or 0), Self._PauseDuration
			end

			local Start, Duration = Self._Start or 0, Self._Duration or 0
			if ( Duration > 0 and (Duration - (GetTime() - Start) <= 0) ) then
				Self._Start, Self._Duration = 0, 0
				return 0, 0
			end

			return Start, Duration
		end,

		GetDrawBling = Private.True, -- Incompatible (3.3.5)

		GetDrawSwipe = function(Self)
			return Self:GetAlpha() > 0.0001
		end,

		GetEdgeScale = function(Self)
			return 1
		end,

		GetRotation = function(Self)
			local Start, Duration = Self:GetCooldownTimes()
			if ( Start > 0 ) then
				return ((GetTime() - Start) / Duration) * 6.28318530718
			end
			return 0
		end,

		IsPaused = function(Self)
			return Self._PauseElapsed and true or false
		end,

		Pause = function(Self)
			if ( not Self._PauseElapsed ) then
				local Start, Duration = Self:GetCooldownTimes()

				if ( Start > 0 and Duration > 0 ) then
					local Now = GetTime()
					local Elapsed = Now - Start

					Self._PauseElapsed = Elapsed
					Self._PauseDuration = Duration

					local FrozenDuration = 1000000 -- ~11 days is enough to look frozen
					local Ratio = Elapsed / Duration
					Self:SetCooldown(Now - (FrozenDuration * Ratio), FrozenDuration)
				end
			end
		end,

		Resume = function(Self)
			local PauseDuration = Self._PauseDuration
			if ( PauseDuration ) then
				local Start, Duration = Self._Start or 0, Self._Duration or 0
				local Now = GetTime()
				local Ratio = (Now - Start) / Duration
				Self:SetCooldown(Now - (PauseDuration * Ratio), PauseDuration)
			end
		end,

		SetBlingTexture = Private.Void, -- Incompatible (3.3.5)

		SetCooldownDuration = function(Self, Duration)
			Self:SetCooldown(GetTime(), Duration)
		end,

		SetCooldownFromDurationObject = function(Self, Duration, ClearIfZero)
			-- See https://warcraft.wiki.gg/wiki/ScriptObject_DurationObject
			local Remaining = Duration:GetEndTime() - GetTime()
			if ( Remaining > 0 ) then
				Self:SetCooldownDuration(Remaining)
			elseif ( ClearIfZero ) then
				Self:SetCooldown(0, 0)
			end
		end,

		SetDrawBling = Private.Void, -- Incompatible (3.3.5),

		SetDrawSwipe = function(Self, DrawSwipe)
			Self:SetAlpha(DrawSwipe and 1 or 0.0001)
		end,

		SetEdgeColor = Private.Void, -- Incompatible (3.3.5),
		SetEdgeScale = Private.Void, -- Incompatible (3.3.5),
		SetEdgeTexture = Private.Void, -- Incompatible (3.3.5),

		SetHideCountdownNumbers = function(Self, HideNumbers)
			Self.noCooldownCount = (HideNumbers) and true or nil -- OmniCC
		end,

		SetPaused = function(Self, Paused)
			if ( Paused ) then Self:Pause() else Self:Resume() end
		end,

		SetRotation = function(Self, RotationRadians)
			local Start, Duration = Self._Start or 0, Self._Duration or 0
			if ( Duration > 0 ) then
				Self:SetCooldown(Start - (Duration * RotationRadians * 0.15915494309), Duration)
			end
		end,

		SetSwipeColor = function(Self, R, G, B, A)
			if ( Self._SetSwipeTextureR == R and Self._SetSwipeTextureG == G and
				Self._SetSwipeTextureB == B and Self._SetSwipeTextureA == A ) then
					return
			end

			Self._SetSwipeTextureR = R
			Self._SetSwipeTextureG = G
			Self._SetSwipeTextureB = B
			Self._SetSwipeTextureA = A

			local Swipe = Self._Swipe
			if ( Swipe and Swipe.Parent ) then
				if ( not (R and G and B and A) ) then
					Error(Format('Usage: %s:SetSwipeColor(r, g, b, a)', Self:GetName() or '<unnamed>'), 2)
				end

				for i=1, 5 do -- Quadrants, Wedge
					local SwipeTexture = Swipe[i].Texture

					if ( not Self._SetSwipeTexture ) then
						SwipeTexture:SetTexture(R, G, B, A)
						SwipeTexture:SetVertexColor(1, 1, 1, 1)
					else
						SwipeTexture:SetVertexColor(R, G, B, A)
					end
				end
			elseif ( A ) then
				Self:SetAlpha(A)
			end
		end,

		SetUseCircularEdge = function(Self, UseCircularEdge)
			if ( Self._SetUseCircularEdge == UseCircularEdge ) then return end

			Self._SetUseCircularEdge = UseCircularEdge or nil

			local Swipe = Self._Swipe
			if ( Swipe and Swipe.Parent ) then
				local Edge = Swipe[6]

				if ( Edge ) then
					local Texture = Edge.Texture

					Texture:ClearAllPoints()
					if ( UseCircularEdge ) then
						Texture:SetAllPoints(Edge)
					else
						Texture:SetPoint("TOPLEFT", Edge, -12, 12)
						Texture:SetPoint("BOTTOMRIGHT", Edge, 12, -12)
					end
				end
			end
		end,

		SetSwipeTexture = function(Self, Texture, R, G, B, A)
			local EffectiveTexture = (Texture ~= "") and Texture or nil

			if ( Self._SetSwipeTexture == EffectiveTexture and
				Self._SetSwipeTextureR == R and Self._SetSwipeTextureG == G and
				Self._SetSwipeTextureB == B and Self._SetSwipeTextureA == A ) then
					return
			end

			if ( not EffectiveTexture and not (R or G or B) ) then
				Self._SetSwipeTexture = nil
				Self._SetSwipeTextureR = nil
				Self._SetSwipeTextureG = nil
				Self._SetSwipeTextureB = nil
				Self._SetSwipeTextureA = nil
				return Private.CooldownCapture(Self, false)
			end

			Self._SetSwipeTexture = EffectiveTexture
			Self._SetSwipeTextureR = R
			Self._SetSwipeTextureG = G
			Self._SetSwipeTextureB = B
			Self._SetSwipeTextureA = A

			local Swipe = Self._Swipe
			if ( not Swipe or not Swipe.Parent ) then
				Swipe = Private.CooldownCapture(Self, true)
			end

			for i = 1, 5 do -- Quadrants, Wedge
				local SwipeTexture = Swipe[i].Texture

				if ( Texture == "" ) then
					SwipeTexture:SetTexture(R, G, B, A)
					SwipeTexture:SetVertexColor(1, 1, 1, 1)
				else
					SwipeTexture:SetTexture(Texture)
					SwipeTexture:SetVertexColor(0, 0, 0, .65)
				end
			end
		end,

		PostHook = {
			SetCooldown = function(Self, Start, Duration)
				Self._Start = Start
				Self._Duration = Duration

				if ( Duration < 100000 and Self._PauseDuration ) then
					Self._PauseElapsed, Self._PauseDuration = nil, nil
				end
			end,
		},
	},

	Slider = {
		SetEnabled = function(Self, State)
			if ( State ) then Self:Enable() else Self:Disable() end
		end,

		SetObeyStepOnDrag = function(Self, ObeyStepOnDrag)
			Self._ObeyStep = true -- before 5.4.8, it was always true by default and could not be disabled.
		end,

		GetObeyStepOnDrag = function(Self)
			return Self._ObeyStep or false
		end,

		SetStepsPerPage = function(Self, StepsPerPage)
			-- Incomplete, placeholder, potentially impossible to implement
			Self._StepsPerPage = StepsPerPage
		end,

		GetStepsPerPage = function(Self)
			return Self._StepsPerPage or 1
		end,
	},

	StatusBar = {
		SetStatusBarAtlas = function(Self, AtlasName)
			-- Custom
			if ( not AtlasName ) then
				Error(Format('Usage: %s:SetStatusBarAtlas("atlasName")', Self:GetName() or '<unnamed>'), 2)
			end

			local Texture = Self:GetStatusBarTexture()
			if ( not Texture ) then
				Self:SetStatusBarTexture("")
				Texture = Self:GetStatusBarTexture()
			end

			Texture:SetAtlas(AtlasName)
		end,

		GetStatusBarAtlas = function(Self)
			-- Custom
			return Self:GetStatusBarTexture():GetAtlas()
		end,
	},

	-- Currently no methods.
	FontInstance = true,
	Font = true,
	Path = true,
	ControlPoint = true,
	Rotation = true,
	CheckButton = true,
	Translation = true,
	DressUpModel = true,
	TabardModel = true,
	MessageFrame = true,
	ScrollingMessageFrame = true,
	ColorSelect = true,
	Minimap = true,
	MovieFrame = true,
	ScrollFrame = true,
	QuestPOIFrame = true,
}

local function ObjectSignature(Class, Meta)
	-- Identify objects by checking their intrinsic API...

	if Class == "FrameScriptObject" then return Meta.GetName
	elseif Class == "Object" then return Meta.GetParent -- ScriptObject
	elseif Class == "ScriptRegion" then return Meta.SetAllPoints -- ScriptRegionResizing, AnimatableObject
	elseif Class == "Region" then return Meta.GetDrawLayer

	-- Frame
	elseif Class == "Frame" then return Meta.GetFrameLevel

	-- Button
	elseif Class == "Button" then return Meta.Click
	elseif Class == "CheckButton" then return Meta.SetChecked

	-- Model
	elseif Class == "Model" then return Meta.ClearModel
	elseif Class == "PlayerModel" then return Meta.RefreshUnit
	elseif Class == "DressUpModel" then return Meta.Dress
	elseif Class == "TabardModel" then return Meta.CanSaveTabardNow

	-- Blob
	elseif Class == "QuestPOIFrame" then return Meta.DrawQuestBlob

	-- Misc Frame
	elseif Class == "Cooldown" then return Meta.SetCooldown
	elseif Class == "GameTooltip" then return Meta.AddLine
	elseif Class == "ScrollFrame" then return Meta.GetScrollChild
	elseif Class == "StatusBar" then return Meta.SetStatusBarTexture
	elseif Class == "Slider" then return Meta.GetThumbTexture
	elseif Class == "ColorSelect" then return Meta.GetColorRGB

	elseif Class == "Minimap" then return Meta.PingLocation
	elseif Class == "MovieFrame" then return Meta.StartMovie
	--elseif Class == "WorldFrame" then return

	elseif Class == "EditBox" then return Meta.HighlightText
	elseif Class == "MessageFrame" then return Meta.GetInsertMode and not Meta.AtBottom
	elseif Class == "ScrollingMessageFrame" then return Meta.AtBottom
	elseif Class == "SimpleHTML" then return Meta.SetHyperlinkFormat

	-- Texture
	elseif Class == "TextureBase" then return Meta.SetTexture
	elseif Class == "Texture" then return Meta.SetGradient

	-- Font
	elseif Class == "Font" then return Meta.SetFontObject
	elseif Class == "FontInstance" then return Meta.GetFontObject and not Meta.SetHyperlinkFormat
	elseif Class == "FontString" then return Meta.GetStringWidth

	-- Animation
	elseif Class == "AnimationGroup" then return Meta.CreateAnimation
	elseif Class == "Animation" then return Meta.Play and Meta.GetRegionParent
	elseif Class == "Alpha" then return Meta.Play and Meta.SetChange
	elseif Class == "Scale" then return Meta.Play and Meta.SetScale
	elseif Class == "Rotation" then return Meta.Play and Meta.SetRadians
	elseif Class == "Translation" then return Meta.Play and Meta.SetOffset
	elseif Class == "Path" then return Meta.CreateControlPoint
	elseif Class == "ControlPoint" then return Meta.SetOrder and not Meta.Play
	end
end

local GetObjectCache = {}
local function GetObject(Class)
	local Object = GetObjectCache[Class]

	if ( not Object ) then
		if ( Class == "Font" ) then
			Object = CreateFont("__")
			_G["__"] = nil
		elseif ( Class == "Texture" ) then
			Object = GetObject("Frame"):CreateTexture()
		elseif ( Class == "FontString" ) then
			Object = GetObject("Frame"):CreateFontString()
		elseif ( Class == "ControlPoint" ) then
			Object = GetObject("Path"):CreateControlPoint()
		elseif ( Class == "AnimationGroup" ) then
			Object = GetObject("Frame"):CreateAnimationGroup()
		elseif ( Class == "Animation" ) then
			Object = GetObject("AnimationGroup"):CreateAnimation()
		elseif ( Class == "Translation" or Class == "Rotation" or Class == "Scale" or Class == "Alpha" or Class == "Path" ) then
			Object = GetObject("AnimationGroup"):CreateAnimation(Class)
		elseif ( Class == "WorldFrame" or Class == "Minimap" or Class == "MovieFrame" ) then
			Object = true
		else
			-- Exception handling for "Frame", "Button", etc.
			-- It will safely fail for abstract classes "ScriptRegion", "FrameScriptObject", etc.
			local Success
			Success, Object = PCall(CreateFrame, Class)
			if ( not Success ) then return end
		end

		if ( Object ~= true and Object.Hide ) then
			Object:Hide() -- REQUIRED! Otherwise, the keyboard input will cease to work if EditBox is created, as it captures input.
		end

		GetObjectCache[Class] = Object
	end

	return Object
end

-- Process the classes method hooks (if exists).
local function Hook(Type, Metatable, Hooks)
	for Method, Function in Pairs(Hooks) do
		if ( Type == "PreHook" ) then
			local Original = Metatable[Method]
			Metatable[Method] = function(Self, ...)
				Function(Self, ...)
				return Original(Self, ...)
			end
		else
			HookSecureFunc(Metatable, Method, Function)
		end
	end
end

-- Process classes and direct inject our own methods.
local function Process(Metatable)
	for Class, Data in Pairs(UIObject) do
		if ( Data ~= true and ObjectSignature(Class, Metatable) ) then
			for Method, Function in Pairs(Data) do
				if ( Method == "PreHook" or Method == "PostHook" ) then
					Hook(Method, Metatable, Function)
				else
					Metatable[Method] = Function
				end
			end
		end
	end
end

-- Manifest UIObjects, automatically determining if they're abstract, unique, or not.
for Class in Pairs(UIObject) do
	local Object = GetObject(Class)
	if ( Object ) then
		local Metatable = ( Object == true ) and _G[Class] or GetMetaTable(Object).__index
		if ( Metatable ) then
			Process(Metatable)
		end
	end
end