local AddonName = ...

local _G = _G
local Type = type
local Select = select
local Number = tonumber
local Find = string.find
local Match = string.match
local GetAddOnInfo = GetAddOnInfo
local GetAddOnMetadata = GetAddOnMetadata
local IsAddOnLoadOnDemand = IsAddOnLoadOnDemand
local GetAddOnDependencies = GetAddOnDependencies

local Engine, GlobalRegistry, InterceptRegistry, DepsRegistry

local MODE_RESTORE_GLOBALS = 1
local MODE_ALERT_INCOMPATIBLE = 2
local MODE_INTERCEPT_PRELOAD = 3
local MODE_INTERCEPT_SCHEDULED = 4

local function GetVersionValue(VersionStr)
	if ( not VersionStr ) then return 0 end
	local Major, Minor, Patch = Match(VersionStr, "(%d+)%.?(%d*)%.?(%d*)")
	Major = Number(Major) or 0
	Minor = Number(Minor) or 0
	Patch = Number(Patch) or 0
	return (Major * 10000) + (Minor * 100) + Patch
end

local function Process(Self, Event, AddOn)
	if ( Event == "ADDON_LOADED" ) then
		-- Intercept
		local Intercept = InterceptRegistry and InterceptRegistry[AddOn]
		if ( Intercept ) then
			for i = 1, #Intercept do _G[Intercept[i]] = nil end
			InterceptRegistry[AddOn] = nil
		end

		-- Global
		if ( GlobalRegistry ) then
			local TargetParent = DepsRegistry and DepsRegistry[AddOn]
			local LookupName = TargetParent or AddOn

			local Global = GlobalRegistry[LookupName]
			if ( Global ) then
				Global.__Deps = Global.__Deps - 1
				if ( Global.__Deps <= 0 ) then
					for i = 1, #Global do
						local Key = Global[i]
						_G[Key] = Global[Key]
					end
					GlobalRegistry[LookupName] = nil
				end
			end
		end
	else
		GlobalRegistry = nil
		InterceptRegistry = nil
		DepsRegistry = nil
		Self:UnregisterEvent(Event)
		Self:UnregisterEvent("ADDON_LOADED")
		Self:SetScript("OnEvent", nil)
	end
end

local function Register(AddOn, Mode, VersionReq, ...)
	local _, _, _, Enabled = GetAddOnInfo(AddOn)

	if ( Enabled ) then
		if ( Type(VersionReq) == "string" ) then
			local Version = GetAddOnMetadata(AddOn, "Version")

			if ( Version ) then
				local Operator, Target = Match(VersionReq, "^([<>=]+)(.-)$")

				if ( Operator and Target ) then
					local CurrentVal = GetVersionValue(Version)
					local TargetVal = GetVersionValue(Target)

					if     ( Operator == "<"   and not (CurrentVal < TargetVal) )  then return
					elseif ( Operator == "<="  and not (CurrentVal <= TargetVal) ) then return
					elseif ( Operator == ">"   and not (CurrentVal > TargetVal) )  then return
					elseif ( Operator == ">="  and not (CurrentVal >= TargetVal) ) then return
					elseif ( Operator == "=="  and not (CurrentVal == TargetVal) ) then return
					end
				elseif ( not Find(Version, VersionReq) ) then
					return
				end
			end
		end

		if ( Mode == MODE_ALERT_INCOMPATIBLE ) then
			local PopupID = "CAPI_ADDONCOMPAT_" .. AddOn
			local URL = "https://gitlab.com/Tsoukie/projects"
			local Width, Height = 540, 250

			StaticPopupDialogs[PopupID] = {
				text = "|cfffc4447ClassicAPI: Incompatible AddOn Found!|r\n\n[ |cffFFA500%s|r ]\n\nTo avoid issues please use a compatible version at:",
				button1 = IGNORE,
				timeout = 0,
				whileDead = true,
				showAlert = true,
				hasEditBox = 1,
				hasWideEditBox = 1,
				OnUpdate = function(S)
					S:SetSize(Width, Height)

					local E = S.wideEditBox
					if ( E:GetText() ~= URL ) then
						E:SetText(URL)
						E:HighlightText(0)
					end
				end,
			}

			StaticPopup_Show(PopupID, AddOn)
		else
			if ( not Engine ) then
				Engine = CreateFrame("Frame")
				Engine:SetScript("OnEvent", Process)
				Engine:RegisterEvent("ADDON_LOADED")
				Engine:RegisterEvent("PLAYER_LOGIN")
			end

			local IsPreload = (Mode == MODE_INTERCEPT_PRELOAD)

			if ( IsPreload or Mode == MODE_INTERCEPT_SCHEDULED ) then
				if ( not InterceptRegistry ) then InterceptRegistry = {} end

				local Config = InterceptRegistry[AddOn]
				if ( not Config ) then
					Config = {}
					InterceptRegistry[AddOn] = Config
				end

				local Offset = #Config
				for i = 1, Select("#", ...) do
					Config[Offset + i] = Select(i, ...)
				end

				if ( IsPreload ) then InterceptRegistry[Config] = AddOn end
			end

			if ( Mode == MODE_RESTORE_GLOBALS or IsPreload ) then
				if ( not GlobalRegistry ) then GlobalRegistry = {} end

				local Config = GlobalRegistry[AddOn]
				if ( not Config ) then
					Config = { __Deps = 1 }
					GlobalRegistry[AddOn] = Config
				end

				local Offset = #Config
				for i = 1, Select("#", ...) do
					local Object = Select(i, ...)
					Config[Offset + i] = Object
					Config[Object] = _G[Object]
				end
			end
		end
	end
end

local function Initialize()
	if ( not GlobalRegistry and not InterceptRegistry ) then return end

	local LastEnabledAddon = nil
	if ( GlobalRegistry ) then DepsRegistry = {} end

	for i = 1, GetNumAddOns() do
		local Name, _, _, Enabled = GetAddOnInfo(i)

		if ( Enabled and not IsAddOnLoadOnDemand(i) ) then
			if ( InterceptRegistry ) then
				local InterceptEntry = InterceptRegistry[Name]

				if ( InterceptEntry and InterceptRegistry[InterceptEntry] == Name ) then
					if ( LastEnabledAddon and InterceptEntry[1] ) then
						Register(LastEnabledAddon, MODE_INTERCEPT_SCHEDULED, nil, nil, InterceptEntry[1]) -- Unpack(InterceptEntry)
					end

					InterceptRegistry[InterceptEntry] = nil
					InterceptRegistry[Name] = nil
				end
			end

			if ( GlobalRegistry ) then
				for j = 1, Select("#", GetAddOnDependencies(i)) do
					local DepName = Select(j, GetAddOnDependencies(i))

					if ( DepName and GlobalRegistry[DepName] and DepName ~= Name ) then
						local GlobalEntry = GlobalRegistry[DepName]
						if ( GlobalEntry ) then
							GlobalEntry.__Deps = GlobalEntry.__Deps + 1
							DepsRegistry[Name] = DepName
						end

						break
					end
				end
			end

			LastEnabledAddon = Name
		end
	end
end

Register("Details", MODE_RESTORE_GLOBALS, nil, "IsInGroup", "IsInRaid", "GetNumGroupMembers")
Register("WeakAuras", MODE_RESTORE_GLOBALS, "<5.21.3", "IsInGroup", "IsInRaid", "GetNumGroupMembers")
Register("aux-addon", MODE_RESTORE_GLOBALS, nil, "C_Container", "SOUNDKIT")

Register("TrinketCDs", MODE_INTERCEPT_PRELOAD, nil, "AuraUtil")
Register("AI_VoiceOver", MODE_INTERCEPT_PRELOAD, nil, "WOW_PROJECT_ID")
Register("Outfitter", MODE_INTERCEPT_PRELOAD, nil, "UnitGetIncomingHeals")

Register("CompactRaidFrame", MODE_ALERT_INCOMPATIBLE, "1.2.2")

Initialize()