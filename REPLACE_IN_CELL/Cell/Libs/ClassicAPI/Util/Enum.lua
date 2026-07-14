local _, Private = ...

local Enum = Enum or {}

--[[
	DEFAULT CLIENT (3.3.5) ITEMCLASS
]]

Enum.ItemClass = {
	Quiver = 8,
	Questitem = 12,
	Projectile = 7,
	Miscellaneous = 11,
	Recipe = 9,
	Consumable = 4,
	Gem = 10,
	Tradegoods = 6,
	Armor = 2,
	Container = 3,
	Glyph = 5,
	Weapon = 1,
}

Enum.ItemClassMeta = {
	MinValue = 1,
	NumValues = 12,
	MaxValue = 12,
}

Enum.ItemGemSubclass = {
	Simple = 8,
	Blue = 2,
	Meta = 7,
	Prismatic = 9,
	Purple = 4,
	Green = 5,
	Yellow = 3,
	Orange = 6,
	Red = 1,
}

Enum.ItemGemSubclassMeta = {
	MinValue = 1,
	NumValues = 9,
	MaxValue = 9,
}

Enum.ItemRecipeSubclass = {
	Tailoring = 3,
	Blacksmithing = 5,
	FirstAid = 8,
	Alchemy = 7,
	Book = 1,
	Cooking = 6,
	Inscription = 12,
	Jewelcrafting = 11,
	Engineering = 4,
	Leatherworking = 2,
	Fishing = 10,
	Enchanting = 9,
}

Enum.ItemRecipeSubclassMeta = {
	MinValue = 1,
	NumValues = 12,
	MaxValue = 12,
}

Enum.ItemConsumableSubclass = {
	Other = 8,
	Elixir = 3,
	Potion = 2,
	Scroll = 7,
	Itemenhancement = 6,
	Fooddrink = 1,
	Bandage = 5,
	Flask = 4,
}

Enum.ItemConsumableSubclassMeta = {
	MinValue = 1,
	NumValues = 8,
	MaxValue = 8,
}

Enum.ItemMiscellaneousSubclass = {
	Other = 5,
	Reagent = 2,
	Mount = 6,
	Holiday = 4,
	Pet = 3,
	Junk = 1,
}

Enum.ItemMiscellaneousSubclassMeta = {
	MinValue = 1,
	NumValues = 6,
	MaxValue = 6,
}

Enum.ItemArmorSubclass = {
	Totem = 9,
	Shield = 6,
	Libram = 7,
	Miscellaneous = 1,
	Leather = 3,
	Idol = 8,
	Mail = 4,
	Plate = 5,
	Sigil = 10,
	Cloth = 2,
}

Enum.ItemArmorSubclassMeta = {
	MinValue = 1,
	NumValues = 10,
	MaxValue = 10,
}

Enum.ItemWeaponSubclass = {
	Axe2H = 2,
	Axe1H = 1,
	Staff = 10,
	Crossbow = 15,
	Unarmed = 11,
	Sword1H = 8,
	Polearm = 7,
	Mace1H = 5,
	Bows = 3,
	Miscellaneous = 12,
	Fishingpole = 17,
	Guns = 4,
	Dagger = 13,
	Thrown = 14,
	Wand = 16,
	Sword2H = 9,
	Mace2H = 6,
}

Enum.ItemWeaponSubclassMeta = {
	MinValue = 1,
	NumValues = 17,
	MaxValue = 17,
}

Enum.ItemQuality = {
	Poor = 0,
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Artifact = 6,
	Heirloom = 7,
}

Enum.ItemQualityMeta = {
	MinValue = 1,
	NumValues = 7,
	MaxValue = 7,
}

--[[
	ADDITIONAL ENUM (IMPORTED FROM CLASSIC CLIENT)
]]

Enum.Profession = {
	Tailoring = 7,
	Blacksmithing = 1,
	FirstAid = 0,
	Herbalism = 4,
	Mining = 6,
	Skinning = 11,
	Alchemy = 3,
	Cooking = 5,
	Jewelcrafting = 12,
	Fishing = 10,
	Engineering = 8,
	Leatherworking = 2,
	Inscription = 13,
	Enchanting = 9,
}

Enum.ProfessionMeta = {
	MinValue = 0,
	NumValues = 14,
	MaxValue = 13,
}

Enum.BagIndex = {
	Backpack  = 0,
	Bag_1     = 1,
	Bag_2     = 2,
	Bag_3     = 3,
	Bag_4     = 4,
	Keyring   = -2,
	Bank      = -1,
	BankBag_1 = 5,
	BankBag_2 = 6,
	BankBag_3 = 7,
	BankBag_4 = 8,
	BankBag_5 = 9,
	BankBag_6 = 10,
	BankBag_7 = 11,
}

Enum.BagIndexMeta = {
	MinValue = -2,
	NumValues = 14,
	MaxValue = 11,
}

Enum.BankType = {
	Character = 0,
	Guild = 1,
}

Enum.BankTypeMeta = {
	MinValue = 0,
	NumValues = 2,
	MaxValue = 1,
}

Enum.InventoryType = {
	IndexNonEquipType = 0,
	IndexHeadType = 1,
	IndexNeckType = 2,
	IndexShoulderType = 3,
	IndexBodyType = 4,
	IndexChestType = 5,
	IndexWaistType = 6,
	IndexLegsType = 7,
	IndexFeetType = 8,
	IndexWristType = 9,
	IndexHandType = 10,
	IndexFingerType = 11,
	IndexTrinketType = 12,
	IndexWeaponType = 13,
	IndexShieldType = 14,
	IndexRangedType = 15,
	IndexCloakType = 16,
	Index2HweaponType = 17,
	IndexBagType = 18,
	IndexTabardType = 19,
	IndexRobeType = 20,
	IndexWeaponmainhandType = 21,
	IndexWeaponoffhandType = 22,
	IndexHoldableType = 23,
	IndexAmmoType = 24,
	IndexThrownType = 25,
	IndexRangedrightType = 26,
	IndexQuiverType = 27,
	IndexRelicType = 28,
}

Enum.InventoryTypeMeta = {
	MinValue = 0,
	NumValues = 29,
	MaxValue = 28,
}

Enum.PlayerInteractionType = {
	None = 0,
	TradePartner = 1,
	Item = 2,
	Gossip = 3,
	QuestGiver = 4,
	Merchant = 5,
	TaxiNode = 6,
	Trainer = 7,
	Banker = 8,
	GuildBanker = 10,
	Registrar = 11,
	Vendor = 12,
	PetitionVendor = 13,
	GuildTabardVendor = 14,
	TalentMaster = 15,
	SpecializationMaster = 16,
	MailInfo = 17,
	SpiritHealer = 18,
	AreaSpiritHealer = 19,
	Binder = 20,
	Auctioneer = 21,
	StableMaster = 22,
	BattleMaster = 23,
	LFGDungeon = 25,
}

Enum.PlayerInteractionTypeMeta = {
	MinValue = 0,
	NumValues = 26,
	MaxValue = 25,
}

Enum.LFGRole = {
	Tank = 0,
	Healer = 1,
	Damage = 2,
}

Enum.LFGRoleMeta = {
	MinValue = 0,
	NumValues = 3,
	MaxValue = 2,
}

--[[
	INTERNAL SUPPORT
]]

Private.EnumInventoryType = {
	-- Integer -> String (ID to String)
	[Enum.InventoryType.IndexNonEquipType] = INVTYPE_NON_EQUIP,
	[Enum.InventoryType.IndexHeadType] = INVTYPE_HEAD,
	[Enum.InventoryType.IndexNeckType] = INVTYPE_NECK,
	[Enum.InventoryType.IndexShoulderType] = INVTYPE_SHOULDER,
	[Enum.InventoryType.IndexBodyType] = INVTYPE_BODY,
	[Enum.InventoryType.IndexChestType] = INVTYPE_CHEST,
	[Enum.InventoryType.IndexWaistType] = INVTYPE_WAIST,
	[Enum.InventoryType.IndexLegsType] = INVTYPE_LEGS,
	[Enum.InventoryType.IndexFeetType] = INVTYPE_FEET,
	[Enum.InventoryType.IndexWristType] = INVTYPE_WRIST,
	[Enum.InventoryType.IndexHandType] = INVTYPE_HAND,
	[Enum.InventoryType.IndexFingerType] = INVTYPE_FINGER,
	[Enum.InventoryType.IndexTrinketType] = INVTYPE_TRINKET,
	[Enum.InventoryType.IndexWeaponType] = INVTYPE_WEAPON,
	[Enum.InventoryType.IndexShieldType] = INVTYPE_SHIELD,
	[Enum.InventoryType.IndexRangedType] = INVTYPE_RANGED,
	[Enum.InventoryType.IndexCloakType] = INVTYPE_CLOAK,
	[Enum.InventoryType.Index2HweaponType] = INVTYPE_2HWEAPON,
	[Enum.InventoryType.IndexBagType] = INVTYPE_BAG,
	[Enum.InventoryType.IndexTabardType] = INVTYPE_TABARD,
	[Enum.InventoryType.IndexRobeType] = INVTYPE_ROBE,
	[Enum.InventoryType.IndexWeaponmainhandType] = INVTYPE_WEAPONMAINHAND,
	[Enum.InventoryType.IndexWeaponoffhandType] = INVTYPE_WEAPONOFFHAND,
	[Enum.InventoryType.IndexHoldableType] = INVTYPE_HOLDABLE,
	[Enum.InventoryType.IndexAmmoType] = INVTYPE_AMMO,
	[Enum.InventoryType.IndexThrownType] = INVTYPE_THROWN,
	[Enum.InventoryType.IndexRangedrightType] = INVTYPE_RANGEDRIGHT,
	[Enum.InventoryType.IndexQuiverType] = INVTYPE_QUIVER,
	[Enum.InventoryType.IndexRelicType] = INVTYPE_RELIC,

	-- String -> Integer (Token to ID)
	INVTYPE_NON_EQUIP = Enum.InventoryType.IndexNonEquipType,
	INVTYPE_HEAD = Enum.InventoryType.IndexHeadType,
	INVTYPE_NECK = Enum.InventoryType.IndexNeckType,
	INVTYPE_SHOULDER = Enum.InventoryType.IndexShoulderType,
	INVTYPE_BODY = Enum.InventoryType.IndexBodyType,
	INVTYPE_CHEST = Enum.InventoryType.IndexChestType,
	INVTYPE_WAIST = Enum.InventoryType.IndexWaistType,
	INVTYPE_LEGS = Enum.InventoryType.IndexLegsType,
	INVTYPE_FEET = Enum.InventoryType.IndexFeetType,
	INVTYPE_WRIST = Enum.InventoryType.IndexWristType,
	INVTYPE_HAND = Enum.InventoryType.IndexHandType,
	INVTYPE_FINGER = Enum.InventoryType.IndexFingerType,
	INVTYPE_TRINKET = Enum.InventoryType.IndexTrinketType,
	INVTYPE_WEAPON = Enum.InventoryType.IndexWeaponType,
	INVTYPE_SHIELD = Enum.InventoryType.IndexShieldType,
	INVTYPE_RANGED = Enum.InventoryType.IndexRangedType,
	INVTYPE_CLOAK = Enum.InventoryType.IndexCloakType,
	INVTYPE_2HWEAPON = Enum.InventoryType.Index2HweaponType,
	INVTYPE_BAG = Enum.InventoryType.IndexBagType,
	INVTYPE_TABARD = Enum.InventoryType.IndexTabardType,
	INVTYPE_ROBE = Enum.InventoryType.IndexRobeType,
	INVTYPE_WEAPONMAINHAND = Enum.InventoryType.IndexWeaponmainhandType,
	INVTYPE_WEAPONOFFHAND = Enum.InventoryType.IndexWeaponoffhandType,
	INVTYPE_HOLDABLE = Enum.InventoryType.IndexHoldableType,
	INVTYPE_AMMO = Enum.InventoryType.IndexAmmoType,
	INVTYPE_THROWN = Enum.InventoryType.IndexThrownType,
	INVTYPE_RANGEDRIGHT = Enum.InventoryType.IndexRangedrightType,
	INVTYPE_QUIVER = Enum.InventoryType.IndexQuiverType,
	INVTYPE_RELIC = Enum.InventoryType.IndexRelicType,
}

local Select = select
local GetAuctionItemClasses = GetAuctionItemClasses
local GetAuctionItemSubClasses = GetAuctionItemSubClasses

-- ["ClassName"] = Cache, [ClassID] = Cache
-- Cache = {[0] = ClassIndex, [-1] = ClassName, ["SubClassName"] = SubClassID, [SubClassID] = SubClassName}
Private.EnumItemClassInfo = {}

local function ParseSubClasses(Cache, ...)
	local SubClassIndex = 1
	while true do
		local SubClassName = Select(SubClassIndex, ...)
		if ( not SubClassName ) then break end

		Cache[SubClassName] = SubClassIndex
		Cache[SubClassIndex] = SubClassName

		SubClassIndex = SubClassIndex + 1
	end
end

local ClassIndex = 1
while true do
	local ClassName = Select(ClassIndex, GetAuctionItemClasses())
	if ( not ClassName ) then break end

	local Cache = {[0] = ClassIndex, [-1] = ClassName}
	Private.EnumItemClassInfo[ClassName] = Cache
	Private.EnumItemClassInfo[ClassIndex] = Cache

	ParseSubClasses(Cache, GetAuctionItemSubClasses(ClassIndex))
	ClassIndex = ClassIndex + 1
end

-- Global
_G.Enum = Enum