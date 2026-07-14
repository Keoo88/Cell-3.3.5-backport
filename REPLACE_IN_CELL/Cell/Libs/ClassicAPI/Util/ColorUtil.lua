local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CreateColor = CreateColor
local ColorMixin = ColorMixin
local UnitClass = UnitClass
local Mixin = Mixin

for _, classColor in pairs(RAID_CLASS_COLORS) do
	Mixin(classColor, ColorMixin);
	classColor.colorStr = classColor:GenerateHexColor();
end

function ExtractColorValueFromHex(str, index)
	return tonumber(str:sub(index, index + 1), 16) / 255;
end

function CreateColorFromHexString(hexColor)
	if #hexColor == 8 then
		local a, r, g, b = ExtractColorValueFromHex(hexColor, 1), ExtractColorValueFromHex(hexColor, 3), ExtractColorValueFromHex(hexColor, 5), ExtractColorValueFromHex(hexColor, 7);
		return CreateColor(r, g, b, a);
	else
		error("CreateColorFromHexString input must be hexadecimal digits in this format: AARRGGBB.", 2);
	end
end

function CreateColorFromBytes(r, g, b, a)
	return CreateColor(r / 255, g / 255, b / 255, a / 255);
end

function AreColorsEqual(left, right)
	if left and right then
		return left:IsEqualTo(right);
	end
	return left == right;
end

function GetClassColor(classFilename)
	local color = RAID_CLASS_COLORS[classFilename];
	if color then
		return color.r, color.g, color.b, color.colorStr;
	end
	return 1, 1, 1, "ffffffff";
end

function GetClassColorObj(classFilename)
	return RAID_CLASS_COLORS[classFilename];
end

function GetClassColoredTextForUnit(unit, text)
	local _, classFilename = UnitClass(unit);
	local color = GetClassColorObj(classFilename);
	if (color) then 
		return color:WrapTextInColorCode(text);
	end
end

function GetFactionColor(factionGroupTag)
	return PLAYER_FACTION_COLORS[PLAYER_FACTION_GROUP[factionGroupTag]];
end