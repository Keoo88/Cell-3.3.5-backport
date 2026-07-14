local C_CreatureInfo = C_CreatureInfo or {}

local C_CreatureInfo_RaceData
local C_CreatureInfo_ClassData

function C_CreatureInfo.GetClassInfo(classID)
	if ( not C_CreatureInfo_ClassData ) then
		C_CreatureInfo_ClassData = {
			[1] = "WARRIOR",
			[2] = "PALADIN",
			[3] = "HUNTER",
			[4] = "ROGUE",
			[5] = "PRIEST",
			[6] = "DEATHKNIGHT",
			[7] = "SHAMAN",
			[8] = "MAGE",
			[9] = "WARLOCK",
			--[10] = "MONK",
			[11] = "DRUID",
			--[12] = "DEMONHUNTER",
			--[13] = "EVOKER",
		}
	end

	local classInfo = C_CreatureInfo_ClassData[classID]

	if ( classInfo and not classInfo.className ) then
		classInfo = {
			className = LOCALIZED_CLASS_NAMES_MALE[classInfo],
			classFile = classInfo,
			classID = classID
		}
		C_CreatureInfo_ClassData[classID] = classInfo
	end

	return classInfo
end

function C_CreatureInfo.GetRaceInfo(RaceID, RaceIndex)
	if ( not C_CreatureInfo_RaceData ) then
		C_CreatureInfo_RaceData = { -- enUS, needs localization somehow.
			[1] = {
				raceName = "Human",
				clientFileString = "Human",
			},
			[2] = {
				raceName = "Orc",
				clientFileString = "Orc",
			},
			[3] = {
				raceName = "Dwarf",
				clientFileString = "Dwarf",
			},
			[4] = {
				raceName = "Night Elf",
				clientFileString = "NightElf",
			},
			[5] = {
				raceName = "Undead",
				clientFileString = "Scourge",
			},
			[6] = {
				raceName = "Tauren",
				clientFileString = "Tauren",
			},
			[7] = {
				raceName = "Gnome",
				clientFileString = "Gnome",
			},
			[8] = {
				raceName = "Troll",
				clientFileString = "Troll",
			},
			[9] = {
				raceName = "Goblin",
				clientFileString = "Goblin",
			},
			[10] = {
				raceName = "Blood Elf",
				clientFileString = "BloodElf",
			},
			[11] = {
				raceName = "Draenei",
				clientFileString = "Draenei",
			}
		}
	end

	local RaceData = C_CreatureInfo_RaceData[RaceID]

	if ( RaceIndex ) then
		if ( not RaceData ) then
			for i=1,#C_CreatureInfo_RaceData do
				C_CreatureInfo_RaceData[C_CreatureInfo_RaceData[i].clientFileString] = i
			end
			RaceData = C_CreatureInfo_RaceData[RaceID]
		end
	elseif ( RaceData.raceName and not RaceData.RaceID ) then
		RaceData.RaceID = RaceID
	end

	return RaceData
end

-- Global
_G.C_CreatureInfo = C_CreatureInfo
_G.GetClassInfo = C_CreatureInfo.GetClassInfo