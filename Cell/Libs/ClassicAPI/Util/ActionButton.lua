local _, Private = ...

local _G = _G
local CreateFrame = CreateFrame

local unusedOverlayGlows
local numOverlays = 0

if ( _G.ActionButton_ShowOverlayGlow ) then return end

local function ActionButton_GetOverlayGlow()
	if ( not unusedOverlayGlows ) then
		unusedOverlayGlows = {}
	end

	local overlayIndex = #unusedOverlayGlows
	local overlay = unusedOverlayGlows[overlayIndex]
	if ( overlay ) then
		unusedOverlayGlows[overlayIndex] = nil
	else
		numOverlays = numOverlays + 1
		overlay = CreateFrame("Frame", "ActionButtonOverlay"..numOverlays, UIParent, "ActionBarButtonSpellActivationAlert")
	end

	return overlay
end

local function ActionButton_ShowOverlayGlow(self)
	if ( self.overlay ) then
		if ( self.overlay.animOut:IsPlaying() ) then
			self.overlay.animOut:Stop()
			self.overlay.animIn:Play()
		end
	else
		self.overlay = ActionButton_GetOverlayGlow()
		local frameWidth, frameHeight = self:GetSize()
		self.overlay:SetParent(self)
		self.overlay:ClearAllPoints()
		--Make the height/width available before the next frame:
		self.overlay:SetSize(frameWidth * 1.4, frameHeight * 1.4)
		self.overlay:SetPoint("TOPLEFT", self, "TOPLEFT", -frameWidth * 0.2, frameHeight * 0.2)
		self.overlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", frameWidth * 0.2, -frameHeight * 0.2)
		self.overlay.animIn:Play()
	end
end

local function ActionButton_OverlayGlowAnimOutFinished(animGroup)
	local overlay = animGroup:GetParent()
	local actionButton = overlay:GetParent()

	if ( unusedOverlayGlows ) then
		unusedOverlayGlows[#unusedOverlayGlows + 1] = overlay
		actionButton.overlay = nil
	end

	overlay:Hide()
end

local function ActionButton_HideOverlayGlow(self)
	if ( self.overlay ) then
		if ( self.overlay.animIn:IsPlaying() ) then
			self.overlay.animIn:Stop()
		end
		if ( self:IsVisible() ) then
			self.overlay.animOut:Play()
		else
			ActionButton_OverlayGlowAnimOutFinished(self.overlay.animOut)	--We aren't shown anyway, so we'll instantly hide it.
		end
	end
end

local function ActionButton_OverlayGlowOnUpdate(self, elapsed)
	AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, 0.01)

	--[[ Tsoukie: This doesn't exist on 3.3.5.
	local cooldown = self:GetParent().cooldown 
	-- we need some threshold to avoid dimming the glow during the gcd
	-- (using 1500 exactly seems risky, what if casting speed is slowed or something?)
	if(cooldown and cooldown:IsShown() and cooldown:GetCooldownDuration() > 3000) then
		self:SetAlpha(0.5)
	else
		self:SetAlpha(1.0)
	end]]
end

local function ActionButton_OverlayGlowAnimInFinished(self)
	local frame = self:GetParent()
	local frameWidth, frameHeight = frame:GetSize()
	frame.innerGlow:SetSize(frameWidth, frameHeight)
	frame.outerGlow:SetSize(frameWidth, frameHeight)
	frame.outerGlowOver:SetSize(frameWidth, frameHeight)

	frame.spark.animIn:Stop()
	frame.innerGlow.animIn:Stop()
	frame.innerGlowOver.animIn:Stop()
	frame.outerGlow.animIn:Stop()
	frame.outerGlowOver.animIn:Stop()
	frame.ants.animIn:Stop()
end

-- Global
_G.ActionButton_GetOverlayGlow = ActionButton_GetOverlayGlow
_G.ActionButton_ShowOverlayGlow = ActionButton_ShowOverlayGlow
_G.ActionButton_HideOverlayGlow = ActionButton_HideOverlayGlow
_G.ActionButton_OverlayGlowOnUpdate = ActionButton_OverlayGlowOnUpdate
_G.ActionButton_OverlayGlowAnimInFinished = ActionButton_OverlayGlowAnimInFinished
_G.ActionButton_OverlayGlowAnimOutFinished = ActionButton_OverlayGlowAnimOutFinished