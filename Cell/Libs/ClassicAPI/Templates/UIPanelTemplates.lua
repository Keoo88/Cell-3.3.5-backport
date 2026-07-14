if ( not SearchBoxTemplate_OnLoad ) then
	function SearchBoxTemplate_OnLoad(self)
		self:SetText(SEARCH);
		self:SetFontObject("GameFontDisable");
		self.searchIcon:SetVertexColor(0.6, 0.6, 0.6);
		self:SetTextInsets(16, 20, 0, 0);
	end

	function SearchBoxTemplate_OnEditFocusLost(self)
		self:HighlightText(0, 0);
		self:SetFontObject("GameFontDisable");
		self.searchIcon:SetVertexColor(0.6, 0.6, 0.6);
		if ( self:GetText() == "" or self:GetText() == SEARCH ) then
			self:SetText(SEARCH);
			self.clearButton:Hide();
		end
	end

	function SerachBoxTemplate_OnEditFocusGained(self)
		self:HighlightText();
		self:SetFontObject("ChatFontSmall");
		self.searchIcon:SetVertexColor(1.0, 1.0, 1.0);
		if ( self:GetText() == SEARCH ) then
			self:SetText("")
		end
		self.clearButton:Show();
	end
end

ITEM_SEARCHBAR_LIST = {
	"BagItemSearchBox",
	"GuildItemSearchBox",
	"VoidItemSearchBox",
	"BankItemSearchBox",
};

function BagSearch_OnHide(self)
	local allClosed = true;
	for _,barName in pairs(ITEM_SEARCHBAR_LIST) do
		local bar = _G[barName];
		if bar and bar ~= self and bar:IsVisible() then
			allClosed = false;
		end
	end
	if ( allClosed ) then
		self.clearButton:Click();
		BagSearch_OnTextChanged(self);
	end
end

function BagSearch_OnTextChanged(self, userChanged)
	local text = self:GetText();
	if ( text == SEARCH ) then
		text = "";
	end
	SetItemSearch(text);
	if (text ~= "") then
		self.clearButton:Show();
	else
		self.clearButton:Hide();
	end
end

function BagSearch_OnChar(self, text)
	-- clear focus if the player is repeating keys (ie - trying to move)
	-- TODO: move into base editbox code?
	local MIN_REPEAT_CHARACTERS = 3
	local searchString = self:GetText();
	if (string.len(searchString) > MIN_REPEAT_CHARACTERS) then
		local repeatChar = true;
		for i=1, MIN_REPEAT_CHARACTERS, 1 do 
			if ( string.sub(searchString,(0-i), (0-i)) ~= string.sub(searchString,(-1-i),(-1-i)) ) then
				repeatChar = false;
				break;
			end
		end
		if ( repeatChar ) then
			self:ClearFocus();
		end
	end
end

function BagSearch_OnEditFocusGained(self)
	SerachBoxTemplate_OnEditFocusGained(self);

	for _,barName in pairs(ITEM_SEARCHBAR_LIST) do
		local bar = _G[barName];
		if bar and bar ~= self then
			bar:SetText(SEARCH);
		end
	end
end

function BagSearch_OnEditFocusLost(self)
	SerachBoxTemplate_OnEditFocusGained(self);

	local search = self:GetText();
	for _,barName in pairs(ITEM_SEARCHBAR_LIST) do
		local bar = _G[barName];
		if bar and bar ~= self then
			bar:SetText(search);
		end
	end
end

-- Scrollframe functions
function ScrollBar_AdjustAnchors(scrollBar, topAdj, bottomAdj, xAdj)
	-- assumes default anchoring of topleft-topright, bottomleft-bottomright
	local topY = 0;
	local bottomY = 0;
	local point, parent, refPoint, x, y;
	for i = 1, 2 do
		point, parent, refPoint, x, y = scrollBar:GetPoint(i);
		if ( point == "TOPLEFT" ) then
			topY = y;
		elseif ( point == "BOTTOMLEFT" ) then
			bottomY = y;
		end
	end
	xAdj = xAdj or 0;
	topAdj = topAdj or 0;
	bottomAdj = bottomAdj or 0;
	scrollBar:SetPoint("TOPLEFT", parent, "TOPRIGHT", x + xAdj, topY + topAdj);
	scrollBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", x + xAdj, bottomY + bottomAdj);
end

-- Truncated Button code

function TruncatedButton_OnEnter(self)
	local text = _G[self:GetName().."Text"];
	if ( text:IsTruncated() ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(text:GetText());
		GameTooltip:Show();
	end
end

function TruncatedButton_OnLeave(self)
	if ( GameTooltip:GetOwner() == self ) then
		GameTooltip:Hide();
	end
end

-- Magic Button code
function MagicButton_OnLoad(self)
	local leftHandled = false;
	local rightHandled = false;
	
	-- Find out where this button is anchored and adjust positions/separators as necessary
	for i=1, self:GetNumPoints() do
		local point, relativeTo, relativePoint, offsetX, offsetY = self:GetPoint(i);
		
		if (relativeTo:GetObjectType() == "Button" and (point == "TOPLEFT" or point == "LEFT")) then
			
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 1, 0);
			end	
			
			if (relativeTo.RightSeparator) then
				-- Modify separator to make it a Middle
				self.LeftSeparator = relativeTo.RightSeparator;
			else
				-- Add a Middle separator
				self.LeftSeparator = self:CreateTexture(self:GetName().."_LeftSeparator", "BORDER");
				relativeTo.RightSeparator = self.LeftSeparator;
			end
			
			self.LeftSeparator:SetTexture("Interface\\AddOns\\Cell\\Libs\\ClassicAPI\\Texture\\FrameGeneral\\UI-Frame");
			self.LeftSeparator:SetTexCoord("0.00781250", "0.10937500", "0.75781250", "0.95312500");
			self.LeftSeparator:SetWidth(13);
			self.LeftSeparator:SetHeight(25);
			self.LeftSeparator:SetPoint("TOPRIGHT", self, "TOPLEFT", 5, 1);
			
			leftHandled = true;	
			
		elseif (relativeTo:GetObjectType() == "Button" and (point == "TOPRIGHT" or point == "RIGHT")) then
		
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, -1, 0);
			end	
			
			if (relativeTo.LeftSeparator) then
				-- Modify separator to make it a Middle
				self.RightSeparator = relativeTo.LeftSeparator;
			else
				-- Add a Middle separator
				self.RightSeparator = self:CreateTexture(self:GetName().."_RightSeparator", "BORDER");
				relativeTo.LeftSeparator = self.RightSeparator;
			end
			
			self.RightSeparator:SetTexture("Interface\\AddOns\\Cell\\Libs\\ClassicAPI\\Texture\\FrameGeneral\\UI-Frame");
			self.RightSeparator:SetTexCoord("0.00781250", "0.10937500", "0.75781250", "0.95312500");
			self.RightSeparator:SetWidth(13);
			self.RightSeparator:SetHeight(25);
			self.RightSeparator:SetPoint("TOPLEFT", self, "TOPRIGHT", -5, 1);
			
			rightHandled = true;
			
		elseif (point == "BOTTOMLEFT") then
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 4, 4);
			end	
			leftHandled = true;
		elseif (point == "BOTTOMRIGHT") then
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, -6, 4);
			end
			rightHandled = true;
		elseif (point == "BOTTOM") then
			if (offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 0, 4);
			end
		end	
	end	
	
	-- If this button didn't have a left anchor, add the left border texture
	if (not leftHandled) then
		if (not self.LeftSeparator) then
			-- Add a Left border
			self.LeftSeparator = self:CreateTexture(self:GetName().."_LeftSeparator", "BORDER");
			self.LeftSeparator:SetTexture("Interface\\AddOns\\Cell\\Libs\\ClassicAPI\\Texture\\FrameGeneral\\UI-Frame");
			self.LeftSeparator:SetTexCoord("0.24218750", "0.32812500", "0.63281250", "0.82812500");
			self.LeftSeparator:SetWidth(11);
			self.LeftSeparator:SetHeight(25);
			self.LeftSeparator:SetPoint("TOPRIGHT", self, "TOPLEFT", 6, 1);
		end
	end
	
	-- If this button didn't have a right anchor, add the right border texture
	if (not rightHandled) then
		if (not self.RightSeparator) then
			-- Add a Right border
			self.RightSeparator = self:CreateTexture(self:GetName().."_RightSeparator", "BORDER");
			self.RightSeparator:SetTexture("Interface\\AddOns\\Cell\\Libs\\ClassicAPI\\Texture\\FrameGeneral\\UI-Frame");
			self.RightSeparator:SetTexCoord("0.90625000", "0.99218750", "0.00781250", "0.20312500");
			self.RightSeparator:SetWidth(11);
			self.RightSeparator:SetHeight(25);
			self.RightSeparator:SetPoint("TOPLEFT", self, "TOPRIGHT", -6, 1);
		end
	end
end

-- ButtonFrameTemplate code
local ButtonFrameTemplate_HideButtonBar_UIPatch = ButtonFrameTemplate_HideButtonBar
local ButtonFrameTemplate_ShowButtonBar_UIPatch = ButtonFrameTemplate_ShowButtonBar

function ButtonFrameTemplate_HideButtonBar(self)
	local name = self:GetName()
	local BtnCornerLeft = _G[name .. "BtnCornerLeft"]

	if ( ButtonFrameTemplate_HideButtonBar_UIPatch and not BtnCornerLeft ) then
		ButtonFrameTemplate_HideButtonBar_UIPatch(self) -- UI Patch Compat
	else
		if self.bottomInset then 
			self.bottomInset:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET);
		else
			_G[name .. "Inset"]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET);
		end
		BtnCornerLeft:Hide();
		_G[name .. "BtnCornerRight"]:Hide();
		_G[name .. "ButtonBottomBorder"]:Hide();
	end
end

function ButtonFrameTemplate_ShowButtonBar(self)
	local name = self:GetName()
	local BtnCornerLeft = _G[name .. "BtnCornerLeft"]

	if ( ButtonFrameTemplate_ShowButtonBar_UIPatch and not BtnCornerLeft ) then
		ButtonFrameTemplate_ShowButtonBar_UIPatch(self) -- UI Patch Compat
	else
		if self.topInset then 
			self.topInset:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_BUTTON_OFFSET);
		else
			_G[name .. "Inset"]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_BUTTON_OFFSET);
		end
		BtnCornerLeft:Show();
		_G[name .. "BtnCornerRight"]:Show();
		_G[name .. "ButtonBottomBorder"]:Show();
	end
end

function ButtonFrameTemplate_HideAttic(self)
	if self.topInset then 
		self.topInset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_TOP_OFFSET);
	else
		self.Inset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_TOP_OFFSET);
	end
	self.TopTileStreaks:Hide();
end

function ButtonFrameTemplate_ShowAttic(self)
	if self.topInset then 
		self.topInset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_ATTIC_OFFSET);
	else
		self.Inset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_ATTIC_OFFSET);
	end
	self.TopTileStreaks:Show();
end


function ButtonFrameTemplate_HidePortrait(self)
	self.portrait:Hide();
	self.portraitFrame:Hide();
	self.topLeftCorner:Show();
	self.topBorderBar:SetPoint("TOPLEFT", self.topLeftCorner, "TOPRIGHT",  0, 0);
	self.leftBorderBar:SetPoint("TOPLEFT", self.topLeftCorner, "BOTTOMLEFT",  0, 0);
end


function ButtonFrameTemplate_ShowPortrait(self)
	self.portrait:Show();
	self.portraitFrame:Show();
	self.topLeftCorner:Hide();
	self.topBorderBar:SetPoint("TOPLEFT", self.portraitFrame, "TOPRIGHT",  0, -10);
	self.leftBorderBar:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT",  8, 0);
end


-- SquareButton template code
SQUARE_BUTTON_TEXCOORDS = {
	["UP"] = {     0.45312500,    0.64062500,     0.01562500,     0.20312500};
	["DOWN"] = {   0.45312500,    0.64062500,     0.20312500,     0.01562500};
	["LEFT"] = {   0.23437500,    0.42187500,     0.01562500,     0.20312500};
	["RIGHT"] = {  0.42187500,    0.23437500,     0.01562500,     0.20312500};
	["DELETE"] = { 0.01562500,    0.20312500,     0.01562500,     0.20312500};
};

function SquareButton_SetIcon(self, name)
	local coords = SQUARE_BUTTON_TEXCOORDS[strupper(name)];
	if (coords) then
		self.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
	end
end


-- Cap progress bar
function CapProgressBar_SetNotches(capBar, count)
	local barWidth = capBar:GetWidth();
	local barName = capBar:GetName();
	
	if ( capBar.notchCount and capBar.notchCount > count ) then
		for i = count + 1, capBar.notchCount do
			_G[barName.."Divider"..i]:Hide();
		end
	end
	
	local notchWidth = barWidth / count;
	
	for i=1, count - 1 do
		local notch = _G[barName.."Divider"..i];
		if ( not notch ) then
			notch = capBar:CreateTexture(barName.."Divider"..i, "BORDER", "CapProgressBarDividerTemplate", -1);
		end
		notch:ClearAllPoints();
		notch:SetPoint("LEFT", capBar, "LEFT", notchWidth * i - 2, 0);
	end
	capBar.notchCount = count;
end

function CapProgressBar_Update(capBar, cap1Quantity, cap1Limit, cap2Quantity, cap2Limit, totalQuantity, totalLimit, hasNoSharedStats)
	if ( totalLimit == 0) then
		return;
	end
	
	local barWidth = capBar:GetWidth();
	local sizePerPoint = barWidth / totalLimit;
	local progressWidth = totalQuantity * sizePerPoint;
	
	local cap1Width, cap2Width;
	if ( cap2Quantity and cap2Limit ) then
		cap1Width = min(cap1Limit - cap1Quantity, cap2Limit - cap2Quantity) * sizePerPoint;	--cap1 can't go past the cap2 LFG limit either.
		cap2Width = (cap2Limit - cap2Quantity) * sizePerPoint - cap1Width;
	else
		cap1Width = (cap1Limit - cap1Quantity) * sizePerPoint;
		cap2Width = 0;
	end
	
	--Don't let it go past the end.
	progressWidth = min(progressWidth, barWidth);
	cap1Width = min(cap1Width, barWidth - progressWidth);
	cap2Width = min(cap2Width, barWidth - progressWidth - cap1Width);
	capBar.progress:SetWidth(progressWidth);
	
	capBar.cap1:SetWidth(cap1Width);
	capBar.cap2:SetWidth(cap2Width);
	
	local lastFrame, lastRelativePoint = capBar, "LEFT";
	
	if ( progressWidth > 0 ) then
		capBar.progress:Show();
		capBar.progress:SetPoint("LEFT", lastFrame, lastRelativePoint, 0, 0);
		lastFrame, lastRelativePoint = capBar.progress, "RIGHT";
	else
		capBar.progress:Hide();
	end
	
	if ( cap1Width > 0 and not hasNoSharedStats) then
		capBar.cap1:Show();
		capBar.cap1Marker:Show();
		capBar.cap1:SetPoint("LEFT", lastFrame, lastRelativePoint, 0, 0);
		lastFrame, lastRelativePoint = capBar.cap1, "RIGHT";
	else
		capBar.cap1:Hide();
		capBar.cap1Marker:Hide();
	end
	
	if ( cap2Width > 0 and not hasNoSharedStats) then
		capBar.cap2:Show();
		capBar.cap2Marker:Show();
		capBar.cap2:SetPoint("LEFT", lastFrame, lastRelativePoint, 0, 0);
		lastFrame, lastRelativePoint = capBar.cap2, "RIGHT";
	else
		capBar.cap2:Hide();
		capBar.cap2Marker:Hide();
	end
end
