--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).

local _, Private = ...

-- Forward-declared as locals: the definitions below now fill these locals, not
-- globals. Publishing happens at the bottom of the file through Private.Provide,
-- which only writes a global when nobody else owns that name.
local CreateColor, WrapTextInColorCode

-- Own table: reusing a foreign ColorMixin would overwrite its methods.
local ColorMixin = {}

-- Our own Mixin helpers (Util/Mixin.lua ran first); a foreign ClassicAPI may own the globals.
local CreateFromMixins = Private.Own.CreateFromMixins or CreateFromMixins

function CreateColor(r, g, b, a)
    local color = CreateFromMixins(ColorMixin)
    color:OnLoad(r, g, b, a)
    return color
end

function ColorMixin:OnLoad(r, g, b, a)
    self:SetRGBA(r, g, b, a)
end

function ColorMixin:IsEqualTo(otherColor)
    return self.r == otherColor.r
        and self.g == otherColor.g
        and self.b == otherColor.b
        and self.a == otherColor.a
end

function ColorMixin:GetRGB()
    return self.r, self.g, self.b
end

function ColorMixin:GetRGBAsBytes()
    return self.r * 255, self.g * 255, self.b * 255
end

function ColorMixin:GetRGBA()
    return self.r, self.g, self.b, self.a
end

function ColorMixin:GetRGBAAsBytes()
    return self.r * 255, self.g * 255, self.b * 255, (self.a or 1) * 255
end

function ColorMixin:SetRGBA(r, g, b, a)
    self.r = r
    self.g = g
    self.b = b
    self.a = a
end

function ColorMixin:SetRGB(r, g, b)
    self:SetRGBA(r, g, b, nil)
end

function ColorMixin:GenerateHexColor()
    return ("ff%.2x%.2x%.2x"):format(self:GetRGBAsBytes())
end

function ColorMixin:GenerateHexColorMarkup()
    return "|c"..self:GenerateHexColor()
end

function ColorMixin:WrapTextInColorCode(text)
    return WrapTextInColorCode(text, self:GenerateHexColor())
end

function WrapTextInColorCode(text, colorHexString)
    return ("|c%s%s|r"):format(colorHexString, text)
end

if ( CharacterFrame_Collapse and not ColorMixin.WrapTextInColorTableCode ) then -- UI Patch Compat
	function ColorMixin:WrapTextInColorTableCode(text)
	    return WrapTextInColorCode(text, self:GenerateHexColor())
	end
end

-- Global
Private.Merge("ColorMixin", ColorMixin)

-- Publish: gap-fill only, ours stays reachable via CellClassicAPI.<name>
Private.Provide("CreateColor", CreateColor)
Private.Provide("WrapTextInColorCode", WrapTextInColorCode)
