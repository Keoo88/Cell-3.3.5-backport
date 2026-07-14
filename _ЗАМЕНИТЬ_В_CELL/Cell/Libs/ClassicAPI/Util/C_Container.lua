local _, Private = ...

local _G = _G
local ITEM_SOULBOUND = ITEM_SOULBOUND
local GetContainerItemInfo = GetContainerItemInfo

local C_Container = C_Container or {}

local Tooltip = Private.Tooltip

function C_Container.GetContainerItemInfo(ContainerIndex, SlotIndex)
	local Icon, Stack, Locked, Quality, Readable = GetContainerItemInfo(ContainerIndex, SlotIndex)

	if ( Icon ) then
		Tooltip:ClearLines()
		Tooltip:SetBagItem(ContainerIndex, SlotIndex)
		local Line = _G["CAPI_ScanTooltipTextLeft2"]

		return {
			iconFileID = Icon,
			stackCount = Stack,
			isLocked = Locked,
			quality = Quality,
			isReadable = Readable,
			hasLoot = false,
			hyperlink = C_Container.GetContainerItemLink(ContainerIndex, SlotIndex),
			isFiltered = false,
			hasNoValue = false,
			itemID = C_Container.GetContainerItemID(ContainerIndex, SlotIndex),
			isBound = Line and Line:GetText() == ITEM_SOULBOUND
		}
	end
end

function C_Container.GetMaxArenaCurrency()
	return 10000 -- Note: This could differ on servers.
end

function C_Container.PlayerHasHearthstone()
	for ContainerIndex=0,4 do
		local Total = C_Container.GetContainerNumSlots(ContainerIndex)
		if ( Total > 0 ) then
			for SlotIndex=1,Total do
				local ID = C_Container.GetContainerItemID(ContainerIndex, SlotIndex)
				if ( ID == 6948 ) then
					return ID
				end
			end
		end
	end
end

C_Container.GetBagName = GetBagName
C_Container.GetItemCooldown = GetItemCooldown
C_Container.UseContainerItem = UseContainerItem
C_Container.GetContainerItemID = GetContainerItemID
C_Container.SplitContainerItem = SplitContainerItem
C_Container.PickupContainerItem = PickupContainerItem
C_Container.GetContainerItemLink = GetContainerItemLink
C_Container.GetContainerNumSlots = GetContainerNumSlots
C_Container.SetBagPortraitTexture = SetBagPortraitTexture
C_Container.GetContainerNumFreeSlots = GetContainerNumFreeSlots
C_Container.ContainerIDToInventoryID = ContainerIDToInventoryID
C_Container.GetContainerItemDurability = GetContainerItemDurability

C_Container.UseHearthstone = Private.Void
C_Container.IsBattlePayItem = Private.False
C_Container.IsContainerFiltered = Private.False
C_Container.SetBackpackAutosortDisabled = Private.False

-- INCOMPLETE
--[[
C_Container.SortBags
C_Container.SortBankBags
C_Container.SetItemSearch
C_Container.GetBagSlotFlag
C_Container.SetBagSlotFlag
C_Container.SocketContainerItem
C_Container.SortReagentBankBags
C_Container.GetSortBagsRightToLeft
C_Container.SetSortBagsRightToLeft
C_Container.GetBankAutosortDisabled
C_Container.ShowContainerSellCursor
C_Container.SetBankAutosortDisabled
C_Container.GetContainerItemCooldown
C_Container.SetInsertItemsLeftToRight
C_Container.GetContainerItemQuestInfo
C_Container.GetInsertItemsLeftToRight
C_Container.ContainerRefundItemPurchase
C_Container.GetBackpackAutosortDisabled
C_Container.GetContainerItemPurchaseInfo
C_Container.GetContainerItemPurchaseItem
C_Container.GetContainerItemEquipmentSetInfo
C_Container.GetContainerItemPurchaseCurrency
]]

-- Global
_G.C_Container = C_Container
_G.C_GetContainerItemInfo = C_Container.GetContainerItemInfo