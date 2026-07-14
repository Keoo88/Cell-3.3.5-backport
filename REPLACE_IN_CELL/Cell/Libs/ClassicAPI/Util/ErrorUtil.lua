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