local _, Private = ...

local Select = select
local Floor = math.floor
local SetMapZoom = SetMapZoom
local GetMapZones = GetMapZones
local GetMapContinents = GetMapContinents
local GetCurrentMapZone = GetCurrentMapZone
local SetMapToCurrentZone = SetMapToCurrentZone
local GetCurrentMapAreaID = GetCurrentMapAreaID
local GetPlayerMapPosition = GetPlayerMapPosition
local GetCurrentMapContinent = GetCurrentMapContinent

local C_Map = C_Map or {}

--[[

	To prevent garbage churn and minimize memory overhead, this completely avoids
	creating individual nested sub-tables (e.g., { name = X, parent = Y, type = Z })
	for every map record.

	Instead, it splits structural data across three flat, one-dimensional lookups:

		MapCache:
			Maps a true game engine [AreaID] directly to a localized
			string "Zone Name" value.

		ContinentIDs:
			Maps the basic client index [1 to 4] to that continent's
			true engine WorldMapAreaID (e.g., [4] = 486 for Northrend).

		ZoneMetadata:
			Maps a true [AreaID] to a compressed integer containing both the Continent
			and Zone indices (Formula: ContinentIndex * 100 + ZoneIndex).
			Example: Borean Tundra maps to 412 (Continent 4, Zone 12).

]]

local MapCache
local ContinentIDs
local ZoneMetadata

local function MapCacheAdd(ContinentIndex, IsZone, ...)
	local ItemCount = Select("#", ...)

	for ItemIndex = 1, ItemCount do
		local ItemName = Select(ItemIndex, ...)

		local TargetContinent = IsZone and ContinentIndex or ItemIndex
		local TargetZoneIndex = IsZone and ItemIndex or 0

		SetMapZoom(TargetContinent, TargetZoneIndex)
		local TrueAreaID = GetCurrentMapAreaID()

		if ( TrueAreaID and TrueAreaID > 0 ) then
			MapCache[TrueAreaID] = ItemName

			if ( not IsZone ) then
				ContinentIDs[TargetContinent] = TrueAreaID
			else
				ZoneMetadata[TrueAreaID] = (TargetContinent * 100) + TargetZoneIndex
			end
		end
	end
end

local function MapCacheInitialize()
	MapCache = {}
	ContinentIDs = {}
	ZoneMetadata = {}

	local SavedContinent = GetCurrentMapContinent()
	local SavedZone = GetCurrentMapZone()
	SetMapToCurrentZone()

	MapCacheAdd(0, false, GetMapContinents())

	for ContinentIndex = 1, 4 do
		MapCacheAdd(ContinentIndex, true, GetMapZones(ContinentIndex))
	end

	if ( SavedContinent and SavedContinent > 0 ) then
		SetMapZoom(SavedContinent, SavedZone)
	else
		SetMapToCurrentZone()
	end
end

function C_Map.IsWorldMap(UIMapID)
	if ( not MapCache ) then
		MapCacheInitialize()
	end

	return MapCache[UIMapID] ~= nil
end

function C_Map.GetBestMapForUnit(Unit)
	if ( Unit ~= "player" ) then return end

	local SavedContinent = GetCurrentMapContinent()
	local SavedZone = GetCurrentMapZone()

	SetMapToCurrentZone()
	local AreaID = GetCurrentMapAreaID()

	if ( SavedContinent and SavedContinent > 0 ) then
		SetMapZoom(SavedContinent, SavedZone)
	end

	if ( AreaID and AreaID > 0 ) then
		return AreaID
	end
end

function C_Map.GetMapInfo(UIMapID)
	if ( not MapCache ) then
		MapCacheInitialize()
	end

	local Name = MapCache[UIMapID]
	if ( not Name ) then return end

	local PackedData = ZoneMetadata[UIMapID]
	local IsZone = (PackedData ~= nil)

	local ParentMapID = 0
	if ( IsZone ) then
		local ContinentIndex = Floor(PackedData / 100)
		ParentMapID = ContinentIDs[ContinentIndex] or 0
	end

	return {
		mapID = UIMapID,
		name = Name,
		mapType = IsZone and 3 or 2, -- (3 = Zone, 2 = Continent)
		parentMapID = ParentMapID
	}
end

function C_Map.GetPlayerMapPosition(UIMapID, Unit)
	if ( Unit ~= "player" ) then return end

	local CurrentMap = C_Map.GetBestMapForUnit("player")
	if ( CurrentMap ~= UIMapID ) then
		return
	end

	local X, Y = GetPlayerMapPosition("player")
	if ( X == 0 and Y == 0 ) then return end

	return X, Y -- TODO: Vector2D
end

C_Map.GetMapRectOnMap = Private.Void

-- Global
_G.C_Map = C_Map