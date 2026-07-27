--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out, never overwrite a
--! global somebody else owns, keep our own copy in CellClassicAPI.
--! Neither PixelUtil nor GetPhysicalScreenSize is native to 3.3.5a (milkyway-codex),
--! so both are built unconditionally: the globals are only gap-filled, while Cell
--! reads CellClassicAPI.PixelUtil / CellClassicAPI.GetPhysicalScreenSize, whose
--! pixel math is the fixed one (a foreign version may return UI units instead of
--! physical pixels and collapse every pixel-perfect calculation to scale 1).
local _, Private = ...

local match = string.match
local tonumber = tonumber
local GetScreenResolutions = GetScreenResolutions
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight

local PixelUtil = {};

--! WotLK fix: was 'return GetScreenWidth(), GetScreenHeight()' - those return UI UNITS
--! (height is always ~768 regardless of resolution), so P.GetPixelPerfectScale() was
--! always 1 and all pixel-perfect math degenerated to identity. Real physical pixels
--! come from the gxResolution CVar (ElvUI-WotLK technique, Core/Core.lua:65), then from
--! the resolution list, and only then degrade to UI units as a last resort.
local function GetPhysicalScreenSize()
	local resolution = GetCVar and GetCVar("gxResolution")
	if resolution then
		local w, h = match(resolution, "(%d+)x(%d+)")
		if w and h then
			return tonumber(w), tonumber(h)
		end
	end
	local index = GetCurrentResolution and GetCurrentResolution()
	if index and index > 0 then
		local w, h = match((({GetScreenResolutions()})[index] or ""), "(%d+).-(%d+)")
		if w and h then
			return tonumber(w), tonumber(h)
		end
	end
	return GetScreenWidth(), GetScreenHeight()
end

--! WotLK fix: was reading GetScreenResolutions()[GetCurrentResolution()] directly and
--! crashed with '768.0 / nil' whenever the lookup failed (GetCurrentResolution can
--! return 0/nil in windowed mode). Call OUR GetPhysicalScreenSize (the local above,
--! never the possibly foreign global) and guard the division.
function PixelUtil.GetPixelToUIUnitFactor()
    local _, physicalHeight = GetPhysicalScreenSize();
    if physicalHeight and physicalHeight > 0 then
        return 768.0 / physicalHeight;
    end
    return 1;
end

function PixelUtil.GetNearestPixelSize(uiUnitSize, layoutScale, minPixels)
    if uiUnitSize == 0 and (not minPixels or minPixels == 0) then
        return 0;
    end

    local uiUnitFactor = PixelUtil.GetPixelToUIUnitFactor();
    local numPixels = Round((uiUnitSize * layoutScale) / uiUnitFactor);
    if minPixels then
        if uiUnitSize < 0.0 then
            if numPixels > -minPixels then
                numPixels = -minPixels;
            end
        else
            if numPixels < minPixels then
                numPixels = minPixels;
            end
        end
    end

    return numPixels * uiUnitFactor / layoutScale;
end

function PixelUtil.SetWidth(region, width, minPixels)
    region:SetWidth(PixelUtil.GetNearestPixelSize(width, region:GetEffectiveScale(), minPixels));
end

function PixelUtil.SetHeight(region, height, minPixels)
    region:SetHeight(PixelUtil.GetNearestPixelSize(height, region:GetEffectiveScale(), minPixels));
end

function PixelUtil.SetSize(region, width, height, minWidthPixels, minHeightPixels)
    PixelUtil.SetWidth(region, width, minWidthPixels);
    PixelUtil.SetHeight(region, height, minHeightPixels);
end

function PixelUtil.SetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY, minOffsetXPixels, minOffsetYPixels)
    region:SetPoint(point, relativeTo, relativePoint,
        PixelUtil.GetNearestPixelSize(offsetX, region:GetEffectiveScale(), minOffsetXPixels),
        PixelUtil.GetNearestPixelSize(offsetY, region:GetEffectiveScale(), minOffsetYPixels)
    );
end

function PixelUtil.SetStatusBarValue(statusBar, value)
    local width = statusBar:GetWidth();
    if width and width > 0.0 then
        local min, max = statusBar:GetMinMaxValues();
        local percent = ClampedPercentageBetween(value, min, max);
        if percent == 0.0 or percent == 1.0 then
            statusBar:SetValue(value);
        else
            local numPixels = PixelUtil.GetNearestPixelSize(statusBar:GetWidth() * percent, statusBar:GetEffectiveScale());
            local roundedValue = Lerp(min, max, numPixels / width);
            statusBar:SetValue(roundedValue);
        end
    else
        statusBar:SetValue(value);
    end
end

Private.Provide("GetPhysicalScreenSize", GetPhysicalScreenSize)
Private.Merge("PixelUtil", PixelUtil)
