local _, Cell = ...
_G.Cell = _G.Cell or Cell or {}
Cell = _G.Cell

local match = string.match
local tonumber = tonumber
local floor = math.floor
local ceil = math.ceil
local GetScreenResolutions = GetScreenResolutions
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight

--! WotLK fix: Cell owns its pixel math privately. Standalone !!!ClassicAPI may
--! publish a global PixelUtil whose resolution lookup is unsafe in windowed
--! mode; Cell must keep identical layout semantics regardless of load order.
local PixelUtil = {}
Cell.PixelUtil = PixelUtil

local physicalWidth
local physicalHeight
local pixelToUIUnitFactor

local function Round(value)
    if value >= 0 then
        return floor(value + 0.5)
    end
    return ceil(value - 0.5)
end

local function ReadPhysicalScreenSize()
    if physicalWidth and physicalHeight then
        return physicalWidth, physicalHeight
    end

    local resolution = GetCVar and GetCVar("gxResolution")
    if resolution then
        local width, height = match(resolution, "(%d+)x(%d+)")
        if width and height then
            physicalWidth = tonumber(width)
            physicalHeight = tonumber(height)
        end
    end

    if not physicalHeight then
        local index = GetCurrentResolution and GetCurrentResolution()
        if index and index > 0 then
            local width, height = match((({GetScreenResolutions()})[index] or ""), "(%d+).-(%d+)")
            if width and height then
                physicalWidth = tonumber(width)
                physicalHeight = tonumber(height)
            end
        end
    end

    if not physicalHeight then
        physicalWidth = GetScreenWidth()
        physicalHeight = GetScreenHeight()
    end

    return physicalWidth, physicalHeight
end

function PixelUtil.GetPhysicalScreenSize()
    return ReadPhysicalScreenSize()
end

function PixelUtil.GetPixelToUIUnitFactor()
    if not pixelToUIUnitFactor then
        local _, height = ReadPhysicalScreenSize()
        pixelToUIUnitFactor = height and height > 0 and 768 / height or 1
    end
    return pixelToUIUnitFactor
end

function PixelUtil.GetNearestPixelSize(uiUnitSize, layoutScale, minPixels)
    if uiUnitSize == 0 and (not minPixels or minPixels == 0) then
        return 0
    end

    if not layoutScale or layoutScale == 0 then
        layoutScale = 1
    end

    local uiUnitFactor = PixelUtil.GetPixelToUIUnitFactor()
    local numPixels = Round((uiUnitSize * layoutScale) / uiUnitFactor)
    if minPixels then
        if uiUnitSize < 0 then
            if numPixels > -minPixels then numPixels = -minPixels end
        elseif numPixels < minPixels then
            numPixels = minPixels
        end
    end

    return numPixels * uiUnitFactor / layoutScale
end

--! WotLK fix: из ретейльного PixelUtil здесь остались только те три функции,
--! которые Cell реально зовёт: GetPhysicalScreenSize и GetNearestPixelSize
--! (Libs/PixelPerfect.lua) и SetPoint (8 точек - MainFrame, NPCFrame,
--! SpotlightFrame, OptionsFrame, Marks, ReadyAndPull, BuffTracker).
--! SetWidth/SetHeight/SetSize/SetStatusBarValue не звал никто: размеры Cell
--! считает через свой P.Size/P.Scale в PixelPerfect.lua, а значения баров -
--! через SmoothStatusBarMixin. Пустые обёртки только висели в таблице.
function PixelUtil.SetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY, minOffsetXPixels, minOffsetYPixels)
    local scale = region:GetEffectiveScale()
    region:SetPoint(
        point,
        relativeTo,
        relativePoint,
        PixelUtil.GetNearestPixelSize(offsetX, scale, minOffsetXPixels),
        PixelUtil.GetNearestPixelSize(offsetY, scale, minOffsetYPixels)
    )
end

local eventFrame = CreateFrame("Frame")
--! WotLK fix: CVAR_UPDATE arg1 is the NAME of a global string on 3.3.5
--! ("ENABLEBGSOUND" for the SoundEnableSoundWhenGameIsInBG CVar), not the CVar
--! name itself, so comparing it with "gxResolution" never forms a reliable
--! invalidation path. DISPLAY_SIZE_CHANGED is the native resolution signal.
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:SetScript("OnEvent", function()
    physicalWidth = nil
    physicalHeight = nil
    pixelToUIUnitFactor = nil
end)

--! WotLK fix: Cell.PixelUtil is the only embedded owner. Do not publish
--! GetPhysicalScreenSize or PixelUtil globals; stock 3.3.5a has neither, and a
--! standalone !!!ClassicAPI/custom-core implementation must remain untouched.
