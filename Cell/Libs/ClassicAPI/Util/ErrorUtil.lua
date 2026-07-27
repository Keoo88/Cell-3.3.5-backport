--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).

local _, Private = ...

-- Forward-declared as locals: the definitions below now fill these locals, not
-- globals. Publishing happens at the bottom of the file through Private.Provide,
-- which only writes a global when nobody else owns that name.
local CallErrorHandler, assertsafe

local Type = type
local PCall = pcall
local Error = error
local Select = select
local Format = string.format
local GetErrorHandler = geterrorhandler

function CallErrorHandler(...)
	return GetErrorHandler()(...)
end

function assertsafe(Cond, MsgStringOrFunction, ...)
	if ( not Cond ) then
		local ErrorMessage = MsgStringOrFunction or "non-fatal assertion failed"

		if ( Type(MsgStringOrFunction) == "string" and Select("#", ...) > 0 ) then
			ErrorMessage = Format(MsgStringOrFunction, ...)
		elseif ( Type(MsgStringOrFunction) == "function" ) then
			ErrorMessage = MsgStringOrFunction(...)
		end

		local _, Message = PCall(Error, ErrorMessage, 3) -- report error from the previous function
		GetErrorHandler()(Message or ErrorMessage)
	end

	-- Parity with regular 'assert' which returns the input.
	return Cond
end

-- Publish: gap-fill only, ours stays reachable via CellClassicAPI.<name>
Private.Provide("CallErrorHandler", CallErrorHandler)
Private.Provide("assertsafe", assertsafe)
