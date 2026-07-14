local _, Private = ...

local Cos = cos
local Sin = sin
local GetTime = GetTime
local Floor = math.floor
local CreateFrame = CreateFrame

function CooldownFrame_Set(Self, Start, Duration, Enable, ForceShowDrawEdge, ModRate)
	if ( Enable and Enable ~= 0 and Start > 0 and Duration > 0 ) then
		--self:Show()
		Self:SetDrawEdge(ForceShowDrawEdge)
		Self:SetCooldown(Start, Duration, ModRate)
	else
		Self:Hide()
	end
end

function CooldownFrame_Clear(Self)
	Self:Hide()
end

function CooldownFrame_SetDisplayAsPercentage(Self, Percentage)
	local Seconds = 100
	--Self:Pause()
	Self:SetCooldown(GetTime() - Seconds * Percentage, Seconds)
end

--------------------------------------------------
-- COOLDOWN CAPTURE HELPER
--------------------------------------------------

local SetCooldownAlpha

local function CooldownCaptureSetAlpha(Self, Value)
	SetCooldownAlpha(Self._Swipe, Value)
end

local function CooldownCaptureEdge(Swipe, Enabled)
	local Edge = Swipe[6]

	if ( Enabled ) then
		if ( not Edge ) then
			local Parent = Swipe.Parent

			-- Edge (Swipe[6])
			Edge = CreateFrame("ScrollFrame", nil, Swipe)
			Edge:SetPoint("TOPLEFT", Parent)
			Edge:SetPoint("BOTTOMRIGHT")
			Edge:SetFrameLevel(Swipe:GetFrameLevel())

				local Anchor = CreateFrame("Frame", nil, Edge)
				Edge:SetScrollChild(Anchor)

					local Texture = Anchor:CreateTexture(nil, "ARTWORK")
					Texture:SetTexture("Interface\\Cooldown\\edge")
					if ( Parent._SetUseCircularEdge ) then
						Texture:SetAllPoints(Edge)
					else
						Texture:SetPoint("TOPLEFT", Edge, -12, 12)
						Texture:SetPoint("BOTTOMRIGHT", Edge, 12, -12)
					end

					local Anim = Texture:CreateAnimationGroup()
					Anim:SetLooping("REPEAT")

						local Rotation = Anim:CreateAnimation("Rotation")
						Rotation:SetOrigin("CENTER", 0, 0)
						Rotation:SetDuration(0)
						Rotation:SetEndDelay(15)
						Anim:Play()

			Edge.Texture, Edge.Rotation = Texture, Rotation
			Swipe[6] = Edge
		end

		Edge:Show()
	elseif ( Edge ) then
		Edge:Hide()
	end
end

local function CooldownCaptureQuadrant(Point, Swipe, Point2, Coord1, Coord2, Coord3, Coord4)
	local Quadrant = CreateFrame("ScrollFrame", nil, Swipe)
	Quadrant:SetPoint(Point2, Swipe, "CENTER")
	Quadrant:SetPoint(Point)
	Quadrant:SetFrameLevel(0)

		local Anchor = CreateFrame("Frame", nil, Quadrant)
		Quadrant:SetScrollChild(Anchor)

			local Texture = Anchor:CreateTexture(nil, "ARTWORK")
			Texture:SetPoint("TOPLEFT", Quadrant, -0.5, 0.5)
			Texture:SetPoint("BOTTOMRIGHT", Quadrant, 0.5, -0.5)
			Texture:SetTexCoord(Coord1, Coord2, Coord3, Coord4)

	Quadrant.Anchor, Quadrant.Texture = Anchor, Texture

	return Quadrant
end

local function CooldownCaptureTransform(Texture, Angle, Aspect)
	local C, S = Cos(Angle), Sin(Angle)

	-- Calculate the initial relative offset (Upper Left)
	-- Normalizes the Y-axis based on the icon's Aspect ratio
	local Dx = -1.0
	local Dy = (-0.5 / Aspect) - 0.5

	-- Calculate the Anchor Vertex (Upper Left)
	local ULx = 0.5 + Dx * C - Dy * S
	local ULy = 0.5 + (Dy * C + Dx * S) * Aspect

	-- Pre-calculate Step Vectors
	-- These represent moving 1 unit Right and 1 unit Down in rotated space
	local StepRightX = C
	local StepRightY = S * Aspect
	local StepDownX = -S
	local StepDownY = C * Aspect

	Texture:SetTexCoord(
		ULx,							ULy,							-- Upper Left
		ULx + StepDownX,				ULy + StepDownY,				-- Lower Left
		ULx + StepRightX,				ULy + StepRightY,				-- Upper Right
		ULx + StepDownX + StepRightX,	ULy + StepDownY + StepRightY	-- Lower Right
	)
end

local function CooldownCaptureProgress(Swipe, Progress)
	local Parent = Swipe.Parent
	local Reverse = Swipe.Reverse -- "Inverted"

	if ( Reverse ) then Progress = 1 - Progress end

	local Degree = 360 * Progress
	local ActiveIndex = (Reverse) and (Floor(Degree / 90) + 1) or (4 - Floor(Degree / 90))
	local Wedge = Swipe[5]

	if ( ActiveIndex ~= Swipe.Index ) then
		for i = 1, 4 do
			local Quadrant = Swipe[i]

			if ( (Reverse and i < ActiveIndex) or (not Reverse and i > ActiveIndex) ) then
				Quadrant.Texture:Show()
			else
				if ( i == ActiveIndex ) then
					Wedge:SetParent(Quadrant.Anchor)
				end
				Quadrant.Texture:Hide()
			end
		end

		Swipe.Index = ActiveIndex
	end

	local Angle = (Reverse) and Degree or (90 - Degree)
	Wedge.Rotation:SetDegrees(-Angle)

	-- NOTE: re-validate the cached aspect; if the frame was 0x0 on OnShow, retry
	-- now that it may have been sized (NaN/inf/0 all fail the "> 0 and < huge" test)
	local Aspect = Swipe.Aspect
	if ( not (Aspect > 0 and Aspect < math.huge) ) then
		local Width, Height = Swipe:GetSize()
		if ( Width > 0 and Height > 0 ) then
			Aspect = Width/Height
			Swipe[5].Texture:SetSize(Width, Height)
		else
			Aspect = 1
		end
		Swipe.Aspect = Aspect
	end

	CooldownCaptureTransform(Wedge.Texture, Angle, Aspect)

	if ( Swipe.DrawEdge ) then
		Swipe[6].Rotation:SetDegrees(Reverse and -Degree or Degree)
	end
end

local function CooldownCaptureTimer(Swipe)
	local Parent = Swipe.Parent
	local Duration = Parent._Duration

	if ( Duration and Duration > 0 ) then
		if ( Duration > 100000 ) then return end

		local Progress = ((Parent._Start + Duration + 0.2) - GetTime()) / (Duration + 0.2)
		if ( Progress > 0 ) then
			return CooldownCaptureProgress(Swipe, Progress)
		end
	end

	-- Bling
	if ( Swipe.Reverse ) then
		Parent:Hide()
	else
		SetCooldownAlpha(Parent, 1)
		Swipe:Hide()
	end
end

local function CooldownCaptureHide(Self)
	local Swipe = Self._Swipe

	if ( Swipe and Swipe.Parent ) then
		Swipe:Hide()
	end
end

local function CooldownCaptureShow(Self)
	local Swipe = Self._Swipe

	if ( Swipe and Swipe.Parent ) then
		local Reverse = Self:GetReverse() or nil
		if ( Reverse ~= Swipe.Reverse ) then
			Swipe.Reverse = Reverse
		end

		local Edge = Self:GetDrawEdge() or nil
		if ( Edge ~= Swipe.DrawEdge ) then
			Swipe.DrawEdge = Edge
			CooldownCaptureEdge(Swipe, Edge)
		end

		-- NOTE: the frame may not be laid out yet (0x0), which makes Width/Height
		-- produce NaN (0/0) or inf (W/0) and poisons SetTexCoord with invalid values.
		local Width, Height = Swipe:GetSize()
		if ( Width > 0 and Height > 0 ) then
			Swipe.Aspect = Width/Height
			Swipe[5].Texture:SetSize(Width, Height) -- Wedge
		else
			Swipe.Aspect = 1
		end

		SetCooldownAlpha(Self, 0)
		Swipe:Show()
	end
end

local function CooldownCapture(Self, Enabled)
	local Swipe = Self._Swipe

	if ( Enabled ) then
		if ( not Swipe ) then
			if ( not SetCooldownAlpha ) then SetCooldownAlpha = Self.SetAlpha end

			Swipe = CreateFrame("Frame")
			Swipe.Aspect = 1

			-- Quadrants
			Swipe[1] = CooldownCaptureQuadrant("TOPRIGHT", Swipe, "BOTTOMLEFT", 0.5, 1, 0, 0.5)
			Swipe[2] = CooldownCaptureQuadrant("BOTTOMRIGHT", Swipe, "TOPLEFT", 0.5, 1, 0.5, 1)
			Swipe[3] = CooldownCaptureQuadrant("BOTTOMLEFT", Swipe, "TOPRIGHT", 0, 0.5, 0.5, 1)
			Swipe[4] = CooldownCaptureQuadrant("TOPLEFT", Swipe, "BOTTOMRIGHT", 0, 0.5, 0, 0.5)

			-- Wedge (Swipe[5])
			local Wedge = CreateFrame("Frame", nil, Swipe[1].Anchor)

				local Texture = Wedge:CreateTexture(nil, "ARTWORK")
				Texture:SetPoint("BOTTOMRIGHT", Swipe, "CENTER", -0.3, 0.5)

					local Anim = Texture:CreateAnimationGroup()
					Anim:SetLooping("REPEAT")

						local Rotation = Anim:CreateAnimation("Rotation")
						Rotation:SetOrigin("BOTTOMRIGHT", 0, 0)
						Rotation:SetDuration(0)
						Rotation:SetEndDelay(15)
						Anim:Play()

			Wedge.Texture, Wedge.Rotation = Texture, Rotation
			Swipe[5] = Wedge

			-- Ownership
			local Attach = Self:GetParent() or Self
			Swipe:SetParent(Attach)
			Swipe:SetAllPoints(Attach)
			Swipe:SetFrameLevel(Attach:GetFrameLevel())

			-- Hooks
			Self:HookScript("OnShow", CooldownCaptureShow)
			Self:HookScript("OnHide", CooldownCaptureHide)

			Self._Swipe = Swipe
		end

		if ( Swipe.Parent ~= Self ) then
			Swipe.Parent = Self

			SetCooldownAlpha(Swipe, Self:GetAlpha())
			Self.SetAlpha = CooldownCaptureSetAlpha

			Swipe:SetScript("OnUpdate", CooldownCaptureTimer)
		end

		return Swipe
	elseif ( Swipe and Swipe.Parent == Self ) then
		Swipe:SetScript("OnUpdate", nil)
		Swipe.Parent = nil
		Swipe:Hide()
		Self.SetAlpha = nil
		SetCooldownAlpha(Self, Swipe:GetAlpha())
	end
end

Private.CooldownCapture = CooldownCapture