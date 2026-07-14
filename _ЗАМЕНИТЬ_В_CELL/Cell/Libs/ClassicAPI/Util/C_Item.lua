local _, Private = ...

local _G = _G
local Type = type
local Number = tonumber
local Match = string.match
local GetItemInfo = GetItemInfo
local ITEM_SOULBOUND = ITEM_SOULBOUND
local GetInventoryItemID = GetInventoryItemID
local GetContainerItemID = GetContainerItemID
local GetContainerItemInfo = GetContainerItemInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetContainerItemLink = GetContainerItemLink
local IsInventoryItemLocked = IsInventoryItemLocked
local GetAuctionItemClasses = GetAuctionItemClasses
local GetInventoryItemTexture = GetInventoryItemTexture
local GetInventoryItemQuality = GetInventoryItemQuality
local GetAuctionItemSubClasses = GetAuctionItemSubClasses

local Tooltip = Private.Tooltip

local C_Item = C_Item or {}

function C_Item.IsItemDataCachedByID(ItemInfo)
	local _, Cached = C_Item.GetItemInfo(ItemInfo)
	return Cached ~= nil
end

function C_Item.DoesItemExistByID(ItemID)
	return C_Item.GetItemIconByID(ItemID) ~= nil
end

function C_Item.GetItemNameByID(ItemInfo)
	return (C_Item.GetItemInfo(ItemInfo))
end

function C_Item.RequestLoadItemDataByID(ItemID)
	local _, Cached = C_Item.GetItemInfo(ItemID)
	if ( Cached ) then return end
	ItemEventListener:AddCallback(ItemID, Private.Void)
end

function C_Item.GetItemInfo(ItemInfo)
	local Name, Link, Quality, Level, MinLevel, ItemType, ItemSubType, Count, EquipLoc, Texture, Price = GetItemInfo(ItemInfo)
	if ( not Name ) then return end

	local Class = Private.EnumItemClassInfo[ItemType]
	local ClassID = Class and Class[0] or 0
	local SubClassID = Class and Class[ItemSubType] or 0

	return Name, Link, Quality, Level, MinLevel, ItemType, ItemSubType, Count, EquipLoc, Texture, Price, ClassID, SubClassID
end

function C_Item.GetItemInfoInstant(ItemInfo)
	local Name, Link, _, _, _, ItemType, ItemSubType, _, EquipLoc, Texture, _, ClassID, SubClassID = C_Item.GetItemInfo(ItemInfo)

	local ID = ItemInfo
	if ( Link and Type(ID) == "string" ) then
		ID = Number(Match(Link, "item:(%d+):"))
	end

	return ID, ItemType, ItemSubType, EquipLoc, Texture, ClassID, SubClassID
end

function C_Item.GetItemClassInfo(ClassID)
	local Class = Private.EnumItemClassInfo[ClassID]
	return Class and Class[-1]
end

function C_Item.GetItemSubClassInfo(ClassID, SubClassID)
	local Class = Private.EnumItemClassInfo[ClassID]
	if ( Class ) then
		return Class[SubClassID], ClassID == 2
	end
end

function C_Item.GetItemInventorySlotInfo(InventorySlot)
	return Private.EnumInventoryType[InventorySlot]
end

function C_Item.GetItemInventoryTypeByID(ItemInfo)
	local _, _, _, _, _, _, _, _, EquipLoc = C_Item.GetItemInfo(ItemInfo)
	return Private.EnumInventoryType[EquipLoc or "INVTYPE_NON_EQUIP"]
end

function C_Item.GetItemQualityByID(ItemInfo)
	local _, _, Quality = C_Item.GetItemInfo(ItemInfo)
	return Quality
end

function C_Item.GetItemMaxStackSizeByID(ItemInfo)
	local _, _, _, _, _, _, _, Max = C_Item.GetItemInfo(ItemInfo)
	return Max
end

function C_Item.GetDetailedItemLevelInfo(ItemInfo)
	local _, _, _, Level = C_Item.GetItemInfo(ItemInfo)
	return Level, false, Level
end

function C_Item.GetItemGemID(ItemInfo, Index)
	local _, Link = C_Item.GetItemGem(ItemInfo, Index)
	if ( Link ) then
		return Number(Match(Link, "item:(%d+):"))
	end
end

C_Item.GetItemGem = GetItemGem
C_Item.GetItemIconByID = GetItemIcon
C_Item.GetItemCount = GetItemCount
C_Item.GetItemStats = GetItemStats
C_Item.GetItemCooldown = GetItemCooldown
C_Item.GetItemSpell = GetItemSpell
C_Item.GetItemFamily = GetItemFamily
C_Item.GetItemStatDelta = GetItemStatDelta
C_Item.GetItemUniqueness = GetItemUniqueness
C_Item.IsConsumableItem = IsConsumableItem
C_Item.IsCurrentItem = IsCurrentItem
C_Item.IsDressableItem = IsDressableItem
C_Item.IsEquippableItem = IsEquippableItem
C_Item.IsEquippedItem = IsEquippedItem
C_Item.IsEquippedItemType = IsEquippedItemType
C_Item.IsHarmfulItem = IsHarmfulItem
C_Item.IsHelpfulItem = IsHelpfulItem
C_Item.IsItemInRange = IsItemInRange
C_Item.IsUsableItem = IsUsableItem
C_Item.ItemHasRange = ItemHasRange

-- ITEMLOCATIONMIXIN RELIANT
function C_Item.GetItemName(ItemLocation)
	return C_Item.GetItemNameByID(C_Item.GetItemID(ItemLocation))
end

function C_Item.IsLocked(ItemLocation)
	local EquipmentSlotIndex, Locked, _ = ItemLocation.equipmentSlotIndex

	if ( EquipmentSlotIndex ) then
		Locked = IsInventoryItemLocked(EquipmentSlotIndex) ~= nil
	else
		_, _, Locked = GetContainerItemInfo(ItemLocation.bagID, ItemLocation.slotIndex)
	end

	return Locked ~= nil
end

function C_Item.GetItemID(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	if ( EquipmentSlotIndex ) then
		return GetInventoryItemID("player", EquipmentSlotIndex)
	else
		return GetContainerItemID(ItemLocation.bagID, ItemLocation.slotIndex)
	end
end

function C_Item.GetItemIcon(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	if ( EquipmentSlotIndex ) then
		return GetInventoryItemTexture("player", EquipmentSlotIndex)
	else
		local Icon = GetContainerItemInfo(ItemLocation.bagID, ItemLocation.slotIndex)
		return Icon
	end
end

function C_Item.GetItemLink(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	if ( EquipmentSlotIndex ) then
		return GetInventoryItemLink("player", EquipmentSlotIndex)
	else
		return GetContainerItemLink(ItemLocation.bagID, ItemLocation.slotIndex)
	end
end

function C_Item.GetItemQuality(ItemLocation)
	local _, _, Quality = C_Item.GetItemInfo(C_Item.GetItemID(ItemLocation))
	return Quality
end

function C_Item.GetItemInventoryType(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	return EquipmentSlotIndex and Private.EnumInventoryType[EquipmentSlotIndex or 0]
end

function C_Item.GetCurrentItemLevel(ItemLocation)
	local _, _, _, Level = C_Item.GetItemInfo(C_Item.GetItemID(ItemLocation))
	return Level
end

function C_Item.IsItemDataCached(ItemLocation)
	return C_Item.GetItemLink(ItemLocation) ~= nil
end

function C_Item.IsBound(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex

	Tooltip:ClearLines()

	if ( EquipmentSlotIndex ) then
		Tooltip:SetInventoryItem("player", EquipmentSlotIndex)
	else
		Tooltip:SetBagItem(ItemLocation.bagID, ItemLocation.slotIndex)
	end

	local Line = _G["CAPI_ScanTooltipTextLeft2"]
	if ( Line ) then
		return Line:GetText() == ITEM_SOULBOUND
	end
end

function C_Item.GetItemMaxStackSize(ItemLocation)
	local _, _, _, _, _, _, _, Max = C_Item.GetItemInfo(C_Item.GetItemID(ItemLocation))
	return Max
end

C_Item.DoesItemExist = C_Item.GetItemID

C_Item.LockItem = Private.Void
C_Item.UnlockItem = Private.Void
C_Item.GetItemGUID = Private.Void
C_Item.LockItemByGUID = Private.Void
C_Item.UnlockItemByGUID = Private.Void

-- Global
_G.C_Item = C_Item