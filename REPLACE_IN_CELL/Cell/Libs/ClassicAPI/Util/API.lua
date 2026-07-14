local _, Private = ...

local _G = _G
local Mod = mod
local Type = type
local Next = next
local PCall = pcall
local StrLen = strlen
local Sub = string.sub
local GetTime = GetTime
local Floor = math.floor
local GSub = string.gsub
local SecureCall = securecall
local GetMapInfo = GetMapInfo
local Reverse = string.reverse
local GetRealmName = GetRealmName
local GetInstanceInfo = GetInstanceInfo

local FIRST_NUMBER_CAP = FIRST_NUMBER_CAP
local SECOND_NUMBER_CAP = SECOND_NUMBER_CAP
local LARGE_NUMBER_SEPERATOR = LARGE_NUMBER_SEPERATOR

function AnimateTexCoords(Self, Width, Height, FrameW, FrameH, NumFrames, Elapsed, Throttle)
	-- This exists, we just optimize it.
	Throttle = Throttle or 0.1

	if ( not Self.frame ) then
		Self.frame = 0
		Self.throttleTimer = 0
		Self.maxFrames = NumFrames

		Self.numColumns = Floor(Width / FrameW)
		Self.columnWidth = FrameW / Width
		Self.rowHeight = FrameH / Height
	end

	Self.throttleTimer = Self.throttleTimer + Elapsed

	if ( Self.throttleTimer >= Throttle ) then
		local NewFrame = (Self.frame + 1) % Self.maxFrames
		Self.frame = NewFrame
		Self.throttleTimer = 0

		local Column = NewFrame % Self.numColumns
		local Row = Floor(NewFrame / Self.numColumns)

		local Left = Column * Self.columnWidth
		local Right = Left + Self.columnWidth
		local Top = Row * Self.rowHeight
		local Bottom = Top + Self.rowHeight

		Self:SetTexCoord(Left, Right, Top, Bottom)
	end
end

function GetTexCoordsForRoleSmallCircle(Role)
	if ( Role == "TANK" ) then
		return 0, 19/64, 22/64, 41/64
	elseif ( Role == "HEALER" ) then
		return 20/64, 39/64, 1/64, 20/64
	else -- DAMAGER
		return 20/64, 39/64, 22/64, 41/64
	end
end

local function secureexecutenext(Table, Prev, Func, ...)
	local Key, Value = Next(Table, Prev)
	if ( Key ~= nil ) then
		PCall(Func, Key, Value, ...)  -- Errors are silently discarded!
	end
	return Key
end

function secureexecuterange(Table, Func, ...)
	local Key = nil
	repeat
		Key = SecureCall(secureexecutenext, Table, Key, Func, ...)
	until Key == nil
end

function securecallfunction(Func, ...)
	return SecureCall(Func, ...)
end

function HasOverrideActionBar()
	-- Move to C_ActionBar
	return IsPossessBarVisible()
end

function HasVehicleActionBar()
	-- Move to C_ActionBar
	return UnitHasVehicleUI("player")
end

function C_GetInstanceInfo()
	local InstanceName, InstanceType, DifficultyIndex, DifficultyName, MaxPlayers, DynamicDifficulty, IsDynamic = GetInstanceInfo()

	if ( InstanceType == "pvp"  ) then
		local Map = GetMapInfo() -- This relies on WatchFrame calling SetMapToCurrentZone() on zone changes.
		if ( Map == "AlteracValley" or Map == "IsleofConquest" or Map == "LakeWintergrasp" ) then
			MaxPlayers = 40
		elseif ( Map == "ArathiBasin" or Map == "NetherstormArena" or Map == "StrandoftheAncients" ) then
			MaxPlayers = 15
		elseif ( Map == "WarsongGulch" ) then
			MaxPlayers = 10
		end
	end

	return InstanceName, InstanceType, DifficultyIndex, DifficultyName, MaxPlayers, DynamicDifficulty, IsDynamic
end

function GetServerTime()
	return GetTime() -- Sadly, we have to still use client time.
end

function GetNormalizedRealmName()
	return (GSub(GetRealmName(), "[-%s]", ""))
end

function Ambiguate(FullName, Context)
	if ( Type(FullName) ~= "string" or not FullName:find("-") ) then
		return FullName
	end

	if ( Context == "short" or Context == "none" or Context == "guild" ) then
		return FullName:match("^([^-]+)")
	end

	local Name, Realm = FullName:match("^([^-]+)-(.*)$")
	if ( not Name ) then
		return FullName
	end

	local CleanRealm = GSub(Realm, "[-%s]", "")
	if ( CleanRealm == GetNormalizedRealmName() ) then
		return Name
	end

	return FullName
end

function CombatLogGetCurrentEventInfo(Timestamp, SubEvent, SrcGUID, SrcName, SrcFlag, DstGUID, DstName, DstFlag, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12)
	if ( not Timestamp ) then return end

	-- Modern payload (Missing)
	local HideCaster, SrcRaidFlag, DstRaidFlag = false, nil, nil

	-- Note: Blizzard could have changed order of payload from 9th onwards.
	return Timestamp, SubEvent, HideCaster, SrcGUID, SrcName, SrcFlag, SrcRaidFlag, DstGUID, DstName, DstFlag, DstRaidFlag, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12
end

function FormatLargeNumber(Amount)
	if ( Amount < 1000 ) then
		return Amount
	end

	local Formatted = Floor(Amount)
	local K
	while ( true ) do
		Formatted, K = GSub(Formatted, "^(-?%d+)(%d%d%d)", "%1" .. LARGE_NUMBER_SEPERATOR .. "%2")
		if ( K == 0 ) then
			break
		end
	end
	return Formatted
end

function BreakUpLargeNumbers(Value, Breakup)
	if ( Value < 1000 ) then
		if ( Value % 1 == 0 ) then
			return Value
		end

		local Decimal = Floor(Value * 100)
		return Sub(Decimal, 1, -3) .. DECIMAL_SEPERATOR .. Sub(Decimal, -2)
	end

	if ( Breakup ) then
		return FormatLargeNumber(Value)
	else
		return Floor(Value)
	end
end

function AbbreviateLargeNumbers(Value, Breakup)
	if ( Value >= 100000000 ) then
		return Floor(Value / 1000000) .. SECOND_NUMBER_CAP
	elseif ( Value >= 100000 ) then
		return Floor(Value / 1000) .. FIRST_NUMBER_CAP
	elseif ( Value > 1000 ) then
		return BreakUpLargeNumbers(Value, Breakup)
	end

	return Value
end

local InitialGTPSCall
function GetTimePreciseSec()
	local Time = debugprofilestop() / 1000
	if ( InitialGTPSCall == nil ) then
		InitialGTPSCall = Time
	end
	return Time - InitialGTPSCall
end

function BankFrame_Open()
	BankFrame_OnEvent(_G["BankFrame"], "BANKFRAME_OPENED")
end

function MerchantFrame_MerchantShow()
	MerchantFrame_OnEvent(_G["MerchantFrame"], "MERCHANT_SHOW")
end

function MerchantFrame_MerchantClosed()
	MerchantFrame_OnEvent(_G["MerchantFrame"], "MERCHANT_CLOSED")
end

function TabardFrame_Open()
	TabardFrame_OnEvent(_G["TabardFrame"], "OPEN_TABARD_FRAME")
end

function MailFrame_Show()
	MailFrame_OnEvent(_G["MailFrame"], "MAIL_SHOW")
end

function MailFrame_Hide()
	MailFrame_OnEvent(_G["MailFrame"], "MAIL_CLOSED")
end

InGlue = Private.False
PassClickToParent = Private.Void
GetDifficultyInfo = Private.Void -- "Normal", "party", false, false, false, false, nil