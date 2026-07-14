if ( C_NewItems ) then return end

local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemID = GetContainerItemID
local CursorHasItem = CursorHasItem
local GetTime = GetTime
local Type = type

local C_NewItems = CreateFrame("Frame")

local INVENTORY, STACK_UI
local MIN, MAX = 0, 4
local Query

local STACK = 1
local ITEM_ID = 2
local TIMESTAMP = 3

local function GetSlotInfo(ContainerIndex, SlotIndex)
	local Container = INVENTORY[ContainerIndex]
	return (Container and SlotIndex) and Container[SlotIndex]
end

local function Bag(Event, ContainerIndex)
	if ( ContainerIndex >= MIN and ContainerIndex <= MAX ) then
		if ( Event == "BAG_CLOSED" ) then
			INVENTORY[ContainerIndex] = nil
		else
			local Size = GetContainerNumSlots(ContainerIndex)
			if ( Size > 0 ) then
				local Container = INVENTORY[ContainerIndex]

				if ( not Container ) then
					-- HACK: The default backpack may not fire.
					if ( ContainerIndex ~= 0 and not INVENTORY[0] ) then
						Query(Event, 0)
					end

					Container = {}
					INVENTORY[ContainerIndex] = Container

					local Time = GetTime()
					for i=1,Size do
						Container[i] = {[TIMESTAMP] = Time}
					end
				end

				return Container
			end
		end
	end
end

function Query(Event, ContainerIndex)
	local Container = Event and Bag(Event, ContainerIndex) or INVENTORY[ContainerIndex]

	if ( Container ) then
		local Time = Event and GetTime()

		for SlotIndex=1, #Container do
			local Slot = Container[SlotIndex]

			if ( Slot ) then
				if ( Event ) then
					local _, StackCurrent = GetContainerItemInfo(ContainerIndex, SlotIndex)
					local Stack = Slot[STACK]

					if ( StackCurrent ~= Stack ) then
						local Buffer = Slot[TIMESTAMP]

						if ( Buffer and (Time - Buffer) > .5 ) then -- Latency?
							Buffer = nil
							Slot[TIMESTAMP] = nil
						end

						if ( Event == "CONSTRUCT" or Buffer or (StackCurrent or -1) < (Stack or 0) ) then
							if ( not (Buffer and Stack == 9998 and not StackCurrent) ) then
								Slot[STACK] = StackCurrent
								Slot[ITEM_ID] = nil

								if ( not StackCurrent and Slot == STACK_UI.split ) then
									STACK_UI.split = nil -- Move unknown, clear.
								end
							end
						else
							local CurrentID = GetContainerItemID(ContainerIndex, SlotIndex)
							local Changed = Slot[ITEM_ID] ~= CurrentID

							Slot[STACK] = StackCurrent
							Slot[ITEM_ID] = (Changed) and nil or CurrentID
						end
					end
				else
					Slot[ITEM_ID] = nil -- .ClearAll()
				end
			end
		end
	end
end

hooksecurefunc("PickupContainerItem", function(ContainerIndex, SlotIndex)
	if ( INVENTORY ) then
		local Slot = GetSlotInfo(ContainerIndex, SlotIndex)

		if ( Slot ) then
			if ( CursorHasItem() ) then
				STACK_UI.split = Slot
			else
				local Origin = STACK_UI.split

				if ( Origin ~= Slot ) then
					local Time, Stack = GetTime()

					if ( Origin ) then
						if ( Type(Origin) == "number" ) then
							Stack = 9998
						else
							Origin[STACK] = 9999
							Origin[TIMESTAMP] = Time
						end
					end

					Slot[STACK] = Stack or 9999
					Slot[TIMESTAMP] = Time
				end

				STACK_UI.split = nil
			end
		else
			STACK_UI.split = nil
		end
	end
end)

local function Processor(Self, Event, ...)
	if ( Self == "CONSTRUCT" ) then
		STACK_UI = StackSplitFrame -- Avoid hook to SplitContainerItem?
		INVENTORY = {}

		for i=MIN,MAX do
			Query(Self, i)
		end

		local BAG_UPDATE = {GetFramesRegisteredForEvent("BAG_UPDATE")}

		C_NewItems:RegisterEvent("BAG_UPDATE")
		C_NewItems:RegisterEvent("BAG_CLOSED")
		C_NewItems:SetScript("OnEvent", Processor)

		for i=1,#BAG_UPDATE do
			local Frame = BAG_UPDATE[i]
			Frame:UnregisterEvent("BAG_UPDATE")
			Frame:RegisterEvent("BAG_UPDATE")
		end
	elseif ( Event == "BAG_CLOSED" ) then
		Bag(Event, ...)
	else
		Query(Event, ...)
	end
end

--[[

	C_NewItems

]]

function C_NewItems.ClearAll()
	if ( not INVENTORY ) then return Processor("CONSTRUCT") end

	for i=MIN,MAX do
		Query(nil, i)
	end
end

function C_NewItems.IsNewItem(ContainerIndex, SlotIndex)
	if ( not INVENTORY ) then return Processor("CONSTRUCT") end

	local Slot = GetSlotInfo(ContainerIndex, SlotIndex)
	return (Slot and Slot[ITEM_ID]) and true
end

function C_NewItems.RemoveNewItem(ContainerIndex, SlotIndex)
	if ( not INVENTORY ) then return Processor("CONSTRUCT") end

	local Slot = GetSlotInfo(ContainerIndex, SlotIndex)
	if ( Slot ) then
		Slot[ITEM_ID] = nil
	end
end

-- Global
_G.C_NewItems = C_NewItems