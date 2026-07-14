local UnitAura = UnitAura
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local GetSpellInfo = GetSpellInfo
local UnitAffectingCombat = UnitAffectingCombat

local AuraRegistry = {}

local CAN_APPLY		= 1
local SELF_ONLY		= 2
local MINE_IN		= 3
local MINE_OUT		= 4
local SPEC_IN		= 5
local SPEC_OUT		= 6

local _, CLASS_PLAYER = UnitClass("player")

function SpellIsPriorityAura(SpellID)
	return false
end

function SpellCanApplyAura(SpellName)
	local Info = SpellName and AuraRegistry[SpellName]
	return (Info and Info[CAN_APPLY]) or false
end

function SpellAppliesOnlyYourself(SpellName)
	local Info = SpellName and AuraRegistry[SpellName]
	return (Info and Info[SELF_ONLY]) or false
end

function SpellIsSelfBuff(SpellID)
	if ( SpellID ) then
		local SpellName = GetSpellInfo(SpellID)
		local Info = SpellName and AuraRegistry[SpellName]

		if ( Info ) then
			return Info[SELF_ONLY] or false, Info[CAN_APPLY] or false
		end
	end

	return false, false
end

function SpellGetVisibilityInfo(SpellID, Type)
	if ( SpellID and Type ) then
		if ( SpellID == 58597 ) then return true, false, false end -- Special: Sacred Shield (Proc)

		local SpellName = GetSpellInfo(SpellID)
		local Info = SpellName and AuraRegistry[SpellName]

		if ( Info ) then
			local ShowMine, ShowSpec

			if ( Type == "RAID_INCOMBAT" ) then
				ShowMine, ShowSpec = Info[MINE_IN], Info[SPEC_IN]
			elseif ( Type == "RAID_OUTOFCOMBAT" ) then
				ShowMine, ShowSpec = Info[MINE_OUT], Info[SPEC_OUT]
			end

			return (ShowMine ~= nil or ShowSpec ~= nil), ShowMine or false, ShowSpec or false
		end
	end
end

function C_UnitAura(...)
	local Name, Rank, Icon, Count, Type, Duration, Expire, Caster, Steal, Consolidate, ID = UnitAura(...)

	local Info = AuraRegistry[Name]
	return Name, Icon, Count, Type, Duration, Expire, Caster, Steal, Consolidate, ID, (Info and Info[CAN_APPLY])
end

function C_UnitBuff(...)
	local Name, Rank, Icon, Count, Type, Duration, Expire, Caster, Steal, Consolidate, ID = UnitBuff(...)

	local Info = AuraRegistry[Name]
	return Name, Icon, Count, Type, Duration, Expire, Caster, Steal, Consolidate, ID, (Info and Info[CAN_APPLY])
end

function C_UnitDebuff(...)
	local Name, Rank, Icon, Count, Type, Duration, Expire, Caster, Steal, Consolidate, ID = UnitDebuff(...)
	return Name, Icon, Count, Type, Duration, Expire, Caster, Steal, Consolidate, ID
end

local SpellGetVisibilityInfo = SpellGetVisibilityInfo
function CompactUnitFrame_UtilShouldDisplayDebuff(...)
	local _, _, _, _, _, _, _, Caster, _, _, SpellID = UnitDebuff(...)

	if ( SpellID ) then
		local HasCustom, AlwaysShowMine, ShowForMySpec = SpellGetVisibilityInfo(SpellID, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT")

		if ( HasCustom ) then
			return ShowForMySpec or (AlwaysShowMine and (Caster == "player" or Caster == "pet" or Caster == "vehicle"))
		end

		return true
	end
end

local function Register(SpellID, CanApply, SelfOnly, MineIn, MineOut, SpecIn, SpecOut)
	if ( CanApply == false ) then return end

	local SpellName = GetSpellInfo(SpellID)
	if ( not SpellName ) then return end

	local Config = AuraRegistry[SpellName] or {}

	if ( CanApply ) then Config[CAN_APPLY] = CanApply end -- Boolean: True if the player can cast/apply this aura.
	if ( SelfOnly ) then Config[SELF_ONLY] = SelfOnly end -- Boolean: True if the aura can only ever exist on the player self.

	--[[
		Visibility Filter
		------------------------------------------------------------------------
		Variables accept explicit true/false values. If a parameter is omitted (nil),
		the code skips assignment to preserve memory, falling back to default UI filters.

		MINE Filters: Controls visibility for auras originating from player/pet/vehicle.
		SPEC Filters: Controls class/spec/overwrite visibility. Dominates other filters if set.

		State Matrix:
					|  In-Combat (IN)  |  Out-of-Combat (OUT)  |
		------------+------------------+-----------------------+
		Player-Cast |  MineIn          |  MineOut              |
		Class-Spec  |  SpecIn          |  SpecOut              |
		------------+------------------+-----------------------+
	]]

	if ( MineIn   ~= nil ) then Config[MINE_IN]   = MineIn   end
	if ( MineOut  ~= nil ) then Config[MINE_OUT]  = MineOut  end
	if ( SpecIn   ~= nil ) then Config[SPEC_IN]   = SpecIn   end
	if ( SpecOut  ~= nil ) then Config[SPEC_OUT]  = SpecOut  end

	AuraRegistry[SpellName] = Config
end

if ( CLASS_PLAYER == "DEATHKNIGHT" ) then
	Register(48265, true, true) -- Unholy Presence
	Register(48263, true, true) -- Frost Presence
	Register(48266, true, true) -- Blood Presence
	Register(45529, true, true) -- Blood Tap
	Register(49016, true, false) -- Hysteria
	Register(57330, true, false) -- Horn of Winter
	Register(49028, true, false) -- Dancing Rune Weapon

	Register(3714, true, false, false, true) -- Path of Frost
elseif ( CLASS_PLAYER == "DRUID" ) then
	Register(29166, true, false) -- Innervate
	Register(9634, true, true) -- Dire Bear Form
	Register(768, true, true) -- Cat Form
	Register(48451, true, false) -- Lifebloom
	Register(48441, true, false) -- Rejuvenation
	Register(48443, true, false) -- Regrowth
	Register(53251, true, false) -- Wild Growth
	Register(61336, true, true) -- Survival Instincts
	Register(50334, true, true) -- Berserk
	Register(5229, true, true) -- Enrage
	Register(22812, true, true) -- Barkskin
	Register(53312, true, true) -- Nature's Grasp
	Register(22842, true, true) -- Frenzied Regeneration
	Register(2893, true, false) -- Abolish Poison

	Register(467, true, false, false, true) -- Thorns
	Register(1126, true, false, false, true) -- Mark of the Wild
	Register(21849, true, false, false, true) -- Gift of the Wild
elseif ( CLASS_PLAYER == "HUNTER" ) then
	Register(5384, true, true) -- Feign Death
	Register(3045, true, true) -- Rapid Fire
	Register(53480, true, false) -- Roar of Sacrifice
	Register(53271, true, false) -- Master's Call
	Register(53476, true, false) -- Intervene

	Register(19506, true, false, false, true) -- Trueshot Aura
elseif ( CLASS_PLAYER == "MAGE" ) then
	Register(43039, true, true) -- Ice Barrier
	Register(45438, true, true) -- Ice Block
	Register(43012, true, true) -- Frost Ward
	Register(43008, true, true) -- Ice Armor
	Register(7301, true, true) -- Frost Armor
	Register(12472, true, true) -- Icy Veins
	Register(43010, true, true) -- Fire Ward
	Register(43046, true, true) -- Molten Armor
	Register(43020, true, true) -- Mana Shield
	Register(43024, true, true) -- Mage Armor
	Register(66, true, true) -- Invisibility
	Register(130, true, false) -- Slow Fall
	Register(11213, true, true) -- Arcane Concentration
	Register(12043, true, true) -- Presence of Mind
	Register(12042, true, true) -- Arcane Power
	Register(31579, true, true) -- Arcane Empowerment

	Register(61024, true, false, false, true) -- Dalaran Intellect
	Register(61316, true, false, false, true) -- Dalaran Brilliance
	Register(42995, true, false, false, true) -- Arcane Intellect
	Register(43002, true, false, false, true) -- Arcane Brilliance
	Register(43015, true, false, false, true) -- Dampen Magic
	Register(54646, true, false, false, true) -- Focus Magic
elseif ( CLASS_PLAYER == "PALADIN" ) then
	Register(53601, true, false) -- Sacred Shield
	Register(53563, true, false) -- Beacon of Light
	Register(6940, true, false) -- Hand of Sacrifice
	Register(64205, true, false) -- Divine Sacrifice
	Register(31821, true, true) -- Aura Mastery
	Register(642, true, true) -- Divine Shield
	Register(1022, true, false) -- Hand of Protection
	Register(1044, true, false) -- Hand of Freedom
	Register(54428, true, true) -- Divine Plea
	Register(48952, true, true) -- Holy Shield
	Register(31884, true, true) -- Avenging Wrath
	Register(54203, true, false) -- Sheath of Light
	Register(20053, true, true) -- Vengeance
	Register(59578, true, true) -- The Art of War

	Register(48942, true, true) -- Devotion Aura
	Register(54043, true, true) -- Retribution Aura
	Register(19746, true, true) -- Concentration Aura
	Register(48943, true, true) -- Shadow Resistance Aura
	Register(48945, true, true) -- Frost Resistance Aura
	Register(48947, true, true) -- Fire Resistance Aura
	Register(32223, true, true) -- Crusader Aura

	Register(20217, true, false, false, true) -- Blessing of Kings
	Register(25898, true, false, false, true) -- Greater Blessing of Kings
	Register(48936, true, false, false, true) -- Blessing of Wisdom
	Register(48938, true, false, false, true) -- Greater Blessing of Wisdom
	Register(48932, true, false, false, true) -- Blessing of Might
	Register(48934, true, false, false, true) -- Greater Blessing of Might
	Register(25899, true, false, false, true) -- Greater Blessing of Sanctuary
	Register(20911, true, false, false, true) -- Blessing of Sanctuary
elseif ( CLASS_PLAYER == "PRIEST" ) then
	Register(48111, true, false) -- Prayer of Mending
	Register(33206, true, false) -- Pain Suppression
	Register(48068, true, false) -- Renew
	Register(48066, true, false) -- Power Word: Shield
	Register(72418, true, true) -- Chilling Knowledge
	Register(47930, false, false) -- Grace
	Register(10060, true, false) -- Power Infusion
	Register(586, true, true) -- Fade
	Register(48168, true, true) -- Inner Fire
	Register(14751, true, true) -- Inner Focus
	Register(6346, true, false) -- Fear Ward
	Register(64901, true, false) -- Hymn of Hope
	Register(1706, true, false) -- Levitate
	Register(64843, false, false) -- Divine Hymn
	Register(59891, false, false) -- Borrowed Time
	Register(552, true, false) -- Abolish Disease
	Register(15473, true, true) -- Shadowform
	Register(15286, true, true) -- Vampiric Embrace
	Register(49694, true, true) -- Improved Spirit Tap
	Register(47788, true, false) -- Guardian Spirit
	Register(33151, true, true) -- Surge of Light
	Register(33151, true, true) -- Inspiration
	Register(7001, true, false) -- Lightwell Renew
	Register(27827, true, true) -- Spirit of Redemption
	Register(63734, true, true) -- Serendipity
	Register(65081, true, false) -- Body and Soul
	Register(63944, false, false) -- Renewed Hope

	Register(48073, true, false, false, true) -- Divine Spirit
	Register(48074, true, false, false, true) -- Prayer of Spirit
	Register(48169, true, false, false, true) -- Shadow Protection
	Register(48170, true, false, false, true) -- Prayer of Shadow Protection
	Register(48162, true, false, false, true) -- Prayer of Fortitude
	Register(48161, true, false, false, true) -- Power Word: Fortitude
elseif ( CLASS_PLAYER == "ROGUE" ) then
	Register(1784, true, true) -- Stealth
	Register(31665, true, true) -- Master of Subtlety
	Register(26669, true, true) -- Evasion
	Register(11305, true, true) -- Sprint
	Register(26888, true, true) -- Vanish
	Register(36554, true, true) -- Shadowstep
	Register(48659, true, true) -- Feint
	Register(31224, true, true) -- Clock of Shadow
	Register(51713, true, true) -- Shadow dance
	Register(14177, true, true) -- Cold Blood
	Register(57934, true, false) -- Tricks of the Trade
elseif ( CLASS_PLAYER == "SHAMAN" ) then
	Register(49284, true, false) -- Earth Shield
	Register(8515, false, false) -- Windfury Totem
	Register(8178, true, false) -- Grounding Totem
	Register(32182, true, false) -- Heroism
	Register(2825, true, false) -- Bloodlust
	Register(61301, true, false) -- Riptide
	Register(51466, true, false) -- Elemental Oath
elseif ( CLASS_PLAYER == "WARLOCK" ) then
	Register(2947, true, false) -- Fire Shield
	Register(132, true, false) -- Detect Invisibility
	Register(19028, true, false) -- Soul Link
	Register(54424, true, false) -- Fel Intelligence
elseif ( CLASS_PLAYER == "WARRIOR" ) then
	Register(2687, true, true) -- Bloodrage
	Register(18499, true, true) -- Berserker Rage
	Register(12328, true, true) -- Sweeping Strikes
	Register(23920, true, true) -- Spell Reflection
	Register(871, true, true) -- Shield Wall
	Register(2565, true, true) -- Shield Block
	Register(55694, true, true) -- Enraged Regeneration
	Register(1719, true, true) -- Recklessness
	Register(57522, true, true) -- Enrage
	Register(20230, true, true) -- Retaliation
	Register(46924, true, true) -- Bladestorm
	Register(47440, true, false) -- Commanding Shout
	Register(47436, true, false) -- Battle Shout
	Register(46913, true, true) -- Bloodsurge
	Register(12292, true, true) -- Death Wish
	Register(16492, true, true) -- Blood Craze
	Register(65156, true, true) -- Juggernaut
	Register(3411, true, false) -- Intervene
end

--[[ Global Auras ]]

Register(69127, nil, nil, nil, nil, false, true) -- Chill of the Throne
Register(26013, nil, nil, nil, nil, false, true) -- Deserter
Register(71041, nil, nil, nil, nil, false, true) -- Dungeon Deserter
Register(31694, nil, nil, nil, nil, false, false) -- Strange Feeling
Register(70013, nil, nil, nil, nil, false, false) -- Quel'Delar's Compulsion

--[[ TODO: Needs to be implemented.
function UnitAuraBySlot(unit, slot)end
function UnitAuraSlots(unit, filter, maxCount, continuationToken)end
]]