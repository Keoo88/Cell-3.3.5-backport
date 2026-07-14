local C_Texture = C_Texture or {}

local _G = _G
local Type = type
local Error = error
local Pairs = pairs
local Print = print
local Gsub = string.gsub
local Match = string.match
local Format = string.format

--[[
	API C_Texture.RegisterAtlasTable
	--------------------
	This API allows external addons to register atlas information tables.

	Inputs:
		atlasTable [table]
	Returns:
		none

	Required structure for atlasTable:
		atlasTable = {
			[<texturePath>] = {
				<width>,
				<height>,
				<leftTexCoord>,
				<rightTexCoord>,
				<topTexCoord>,
				<bottomTexCoord>,
				<tilesHorizontally>,
				<tilesVertically>,
			},
			...
		},

	Details:
		<texturePath> - path to texture, excluding addon directory

	Usage Example:
		For example MyAddon has directories:
			Interface/AddOns/MyAddon/
				/assets/redbutton2x.blp
				/assets2/CommonSearch.blp

		1: Create Atlas info table:
			local atlasTable = {
				["assets/redbutton2x"] = {
					["RedButton-Exit"] = {36, 38, 0.15234375, 0.29296875, 0.0078125, 0.3046875, false, false},
				},
				["assets2/CommonSearch"] = {
					["common-search-clearbutton"]={20, 20, 0.175781, 0.253906, 0.664062, 0.820312, false, false},
				},
			}

		2: Set root directory:
			atlasTable.rootDirectory = "Interface/AddOns/MyAddon"
			or
			atlasTable.directory = "Interface/AddOns/MyAddon"

		3: Register table:
			C_Texture.RegisterAtlasTable(atlasTable)

		4: Enjoy usage of all atlas methods, such as SetAtlas, GetAtlas and more.
]]

C_Texture.AtlasData = {}

C_Texture.RegisterAtlas = function(AtlasName, Info, Path, SilenceMode)
	if ( Type(AtlasName) ~= "string" ) then
		Error(Format('bad argument #1 to "C_Texture.RegisterAtlas" (string expected, got %s)', Type(AtlasName)), 2)
	elseif ( Type(Info) ~= "table" ) then
		Error(Format('bad argument #2 to "C_Texture.RegisterAtlas" (table expected, got %s)', Type(Info)), 2)
	elseif ( Type(Path) ~= "string" ) then
		Error(Format('bad argument #3 to "C_Texture.RegisterAtlas" (string expected, got %s)', Type(Path)), 2)
	end

	if ( C_Texture.AtlasData[AtlasName] ) then
		if ( not SilenceMode ) then
			Print(Format("'C_Texture.RegisterAtlas': atlas %s already registered.", AtlasName))
		end
		return false
	end

	local Width             = Info[1]
	local Height            = Info[2]
	local LeftTexCoord      = Info[3]
	local RightTexCoord     = Info[4]
	local TopTexCoord       = Info[5]
	local BottomTexCoord    = Info[6]
	local TilesHorizontally = Info[7]
	local TilesVertically   = Info[8]

	if ( Type(Width) ~= "number" ) then
		Error(Format('C_Texture.RegisterAtlas: bad value #1 (width) to atlas "%s" data (number expected, got %s)', AtlasName, Type(Width)), 2)
	elseif ( Type(Height) ~= "number" ) then
		Error(Format('C_Texture.RegisterAtlas: bad value #2 (height) to atlas "%s" data (number expected, got %s)', AtlasName, Type(Height)), 2)
	elseif ( Type(LeftTexCoord) ~= "number" or Type(RightTexCoord) ~= "number" or Type(TopTexCoord) ~= "number" or Type(BottomTexCoord) ~= "number" ) then
		Error(Format('C_Texture.RegisterAtlas: bad value (texCoords) to atlas "%s" data (number expected)', AtlasName), 2)
	elseif ( Type(TilesHorizontally) ~= "boolean" or Type(TilesVertically) ~= "boolean" ) then
		Error(Format('C_Texture.RegisterAtlas: bad value (tiling) to atlas "%s" data (boolean expected)', AtlasName), 2)
	end

	-- Path normalization
	Info[9] = Gsub(Path, "/", "\\")
	C_Texture.AtlasData[AtlasName] = Info

	return true
end

C_Texture.RegisterAtlasTable = function(AtlasTable)
	if ( Type(AtlasTable) ~= "table" ) then
		Error(Format('bad argument #1 to "C_Texture.RegisterAtlasTable" (table expected, got %s)', Type(AtlasTable)), 2)
	end

	local Root = AtlasTable.directory or AtlasTable.rootDirectory or ""

	for Path, Atlases in Pairs(AtlasTable) do
		if ( Path ~= "directory" and Path ~= "rootDirectory" ) then
			local FullPath = Root .. Path
			for AtlasName, Info in Pairs(Atlases) do
				C_Texture.RegisterAtlas(AtlasName, Info, FullPath, true)
			end
		end
	end
end

C_Texture.GetAtlasExists = function(AtlasName)
	return C_Texture.AtlasData[AtlasName] ~= nil
end

C_Texture.GetAtlasInfo = function(AtlasName)
	local Data = C_Texture.AtlasData[AtlasName]
	if ( not Data ) then return end

	local Filename = Data[9]

	return {
		width             = Data[1],
		height            = Data[2],
		leftTexCoord      = Data[3],
		rightTexCoord     = Data[4],
		topTexCoord       = Data[5],
		bottomTexCoord    = Data[6],
		tilesHorizontally = Data[7],
		tilesVertically   = Data[8],
		filename          = Filename,
		elementName       = Match(Filename, "([^\\]+)$") or Filename,
	}
end

_G.C_Texture = C_Texture