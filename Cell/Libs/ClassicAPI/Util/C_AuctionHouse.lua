local _, Private = ...

local C_AuctionHouse = C_AuctionHouse or {}

function C_AuctionHouse.GetAuctionItemSubClasses(ClassID)
	local ClassInfo = Private.EnumItemClassInfo[ClassID]
	if ( not ClassInfo ) then return {} end

	local Results = {}

	for Index = 1, #ClassInfo do
		Results[Index] = Index
	end

	return Results
end

-- Global
_G.C_AuctionHouse = C_AuctionHouse

-- Deprecated
_G.PostAuction = _G.StartAuction