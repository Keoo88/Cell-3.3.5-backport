local _, Private = ...

local Type = type
local Next = next
local Pairs = pairs
local PCall = pcall
local Remove = table.remove
local CallErrorHandler = CallErrorHandler

local EventHandler = CreateFrame("Frame")
local NativeRegister = EventHandler.RegisterEvent
local NativeUnregister = EventHandler.UnregisterEvent

local ObjectMap = {} -- Event -> {Frame1, Frame2, ...}
local FilterMap = {} -- Object -> Event -> {Filter1, Filter2, ...}
local ParentMap = {} -- Object -> {Object1, Object2, ...}
local EventRegistry = {} -- Event -> { Native = {Names}, OnEvent, OnRegister, OnUnregister }
local NativeEventMap = {} -- Native -> Modern

local function Dispatcher(_, NativeEvent, ...)
	local Event = NativeEventMap[NativeEvent] or NativeEvent
	local Objects = ObjectMap[Event]

	if ( Objects ) then
		local Registry = EventRegistry[Event]
		if ( Registry and Registry.OnEvent and Registry.OnEvent("OnEvent", NativeEvent, ...) == false ) then return end

		local Arg1 = ...
		local WriteIndex = 1

		for ReadIndex = 1, #Objects do
			local Object = Objects[ReadIndex]

			if ( Object ) then
				local Filter = FilterMap[Object] and FilterMap[Object][Event]

				if ( Filter and Arg1 ~= Filter[1] and Arg1 ~= Filter[2] and Arg1 ~= Filter[3] and Arg1 ~= Filter[4] ) then
					-- Doesn't match the objects filter, halt.
				else
					if ( Type(Object) == "function" ) then
						local Success, Err = PCall(Object, ...)
						if ( not Success ) then
							CallErrorHandler(Err)
						end
					else
						local OnEvent = Object:GetScript("OnEvent")
						if ( OnEvent ) then
							local Success, Err = PCall(OnEvent, Object, Event, ...)
							if ( not Success ) then
								CallErrorHandler(Err)
							end
						end
					end
				end

				-- Lazy shuffle, move objects up to fill gaps left by unregistered frames.
				if ( ReadIndex ~= WriteIndex ) then
					Objects[WriteIndex] = Object
					Objects[ReadIndex] = nil
				end

				WriteIndex = WriteIndex + 1
			else
				Objects[ReadIndex] = nil -- Explicitly clear dead indexes.
			end
		end
	end
end

local function DispatcherRegister(Object, Event)
	local Objects = ObjectMap[Event]

	if ( not Objects ) then
		local Registry = EventRegistry[Event]

		if ( Registry and Registry.OnRegister and Registry.OnRegister("OnRegister", Event) == false ) then return end

		Objects = {}
		ObjectMap[Event] = Objects

		-- Register native event(s) tied to the modern event, otherwise just register normally.
		local Native = (Registry and Registry.Native) or Event
		if ( Type(Native) == "table" ) then
			for i = 1, #Native do NativeRegister(EventHandler, Native[i]) end
		else
			NativeRegister(EventHandler, Native)
		end
	else
		-- Prevent duplicate registrations
		for i = 1, #Objects do
			if ( Objects[i] == Object ) then return end
		end
	end

	Objects[#Objects + 1] = Object
end

local function DispatcherUnregister(Object, Event)
	local Objects = ObjectMap[Event]

	if ( Objects ) then
		local ObjectsTotal = #Objects
		local ObjectIndex

		for i = 1, ObjectsTotal do
			if ( Objects[i] == Object ) then
				ObjectIndex = i
				break
			end
		end

		-- Handle child object(s)
		local ObjectChild = ParentMap[Object]
		if ( ObjectChild ) then
			for Child in Pairs(ObjectChild) do
				DispatcherUnregister(Child, Event)
			end
			ParentMap[Object] = nil
		end

		if ( ObjectIndex ) then
			-- Handle unregistration(s)
			if ( ObjectsTotal == 1 ) then
				local Registry = EventRegistry[Event]

				if ( Registry and Registry.OnUnregister and Registry.OnUnregister("OnUnregister", Event) == false ) then return end

				-- Unregister native event(s) tied to the modern event, otherwise just unregister normally.
				local Native = (Registry and Registry.Native) or Event
				if ( Type(Native) == "table" ) then
					for i = 1, #Native do NativeUnregister(EventHandler, Native[i]) end
				else
					NativeUnregister(EventHandler, Native)
				end

				ObjectMap[Event] = nil
			else
				-- Mark false for compression next dispatch.
				Objects[ObjectIndex] = false
			end

			-- Handle filter(s)
			local Filter = FilterMap[Object]
			if ( Filter ) then
				Filter[Event] = nil
				if ( not Next(Filter) ) then FilterMap[Object] = nil end
			end
		end
	end
end

local function Define(Action, Event, Value)
	EventRegistry[Event] = EventRegistry[Event] or {}

	if ( Action == "Event" ) then
		EventRegistry[Event].Native = Value

		if ( Value ) then
			if ( Type(Value) == "table" ) then
				for i = 1, #Value do NativeEventMap[Value[i]] = Event end
			else
				NativeEventMap[Value] = Event
			end
		end
	else
		EventRegistry[Event][Action] = Value
	end
end

-- Wrappers

local function RegisterEvent(Object, Event)
	if ( EventRegistry[Event] ) then
		DispatcherRegister(Object, Event)
	end
end

local function RegisterEventCallback(Object, Event, Callback)
	if ( Type(Callback) == "function" ) then
		-- Link the callback to the parent object
		ParentMap[Object] = ParentMap[Object] or {}
		ParentMap[Object][Callback] = true

		DispatcherRegister(Callback, Event)
	end
end

local function RegisterUnitEvent(Object, Event, ...)
	if ( ... ) then
		FilterMap[Object] = FilterMap[Object] or {}
		FilterMap[Object][Event] = {...}
	end

	DispatcherRegister(Object, Event)
end

local function RegisterUnitEventCallback(Object, Event, Callback, ...)
	if ( Type(Callback) == "function" ) then
		-- Link the callback to the parent object
		ParentMap[Object] = ParentMap[Object] or {}
		ParentMap[Object][Callback] = true

		RegisterUnitEvent(Callback, Event, ...)
	end
end

local function UnregisterEventCallback(Object, Event, Callback)
	if ( Type(Callback) == "function" ) then
		-- Unlink the callback from the parent object
		local Parent = ParentMap[Object]
		if ( Parent and Parent[Callback] ) then
			Parent[Callback] = nil
			if ( not Next(Parent) ) then ParentMap[Object] = nil end
		end

		DispatcherUnregister(Callback, Event)
	end
end

local function UnregisterUnitEventCallback(Object, Event, Callback, Unit)
	if ( Type(Callback) == "function" ) then
		if ( Unit ) then
			local ObjectFilter = FilterMap[Callback]
			local EventFilter = ObjectFilter and ObjectFilter[Event]

			if ( EventFilter ) then
				local Removed
				local Total = #EventFilter

				for i = Total, 1, -1 do
					if ( EventFilter[i] == Unit ) then
						Removed = Remove(EventFilter, i)
						Total = Total - 1
					end
				end

				if ( not Removed or Total > 0 ) then return end
			else
				return
			end
		end

		-- Unlink the callback from the parent object
		local Parent = ParentMap[Object]
		if ( Parent and Parent[Callback] ) then
			Parent[Callback] = nil
			if ( not Next(Parent) ) then ParentMap[Object] = nil end
		end

		DispatcherUnregister(Callback, Event)
	end
end

local function UnregisterAllEvents(Object)
	for Event in Pairs(ObjectMap) do DispatcherUnregister(Object, Event) end
end

local function RegisterAllEvents(Object)
	for Event in Pairs(EventRegistry) do RegisterEvent(Object, Event) end
end

-- Dispatcher
EventHandler:SetScript("OnEvent", Dispatcher)

-- Module
EventHandler.Define = Define
EventHandler.Fire = Dispatcher
EventHandler.RegisterEvent = RegisterEvent
EventHandler.RegisterUnitEvent = RegisterUnitEvent
EventHandler.RegisterAllEvents = RegisterAllEvents
EventHandler.UnregisterEvent = DispatcherUnregister
EventHandler.UnregisterAllEvents = UnregisterAllEvents
EventHandler.RegisterEventCallback = RegisterEventCallback
EventHandler.UnregisterEventCallback = UnregisterEventCallback
EventHandler.RegisterUnitEventCallback = RegisterUnitEventCallback
EventHandler.UnregisterUnitEventCallback = UnregisterUnitEventCallback

-- Private Namespace
Private.EventHandler = EventHandler