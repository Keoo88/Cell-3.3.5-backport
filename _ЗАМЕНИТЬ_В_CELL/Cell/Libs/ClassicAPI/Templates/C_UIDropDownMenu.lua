local _G = _G
local type = type
local tonumber = tonumber
local select = select
local wipe = wipe
local strsub = strsub
local gsub = gsub
local issecure = issecure
local securecall = securecall
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local GetScreenWidth = GetScreenWidth
local PlaySound = PlaySound
local GetCVar = GetCVar

local C_UIDROPDOWNMENU_BUTTON_HEIGHT = UIDROPDOWNMENU_BUTTON_HEIGHT
local C_UIDROPDOWNMENU_BORDER_HEIGHT = UIDROPDOWNMENU_BORDER_HEIGHT

C_UIDROPDOWNMENU_MAXLEVELS = 2
C_UIDROPDOWNMENU_MINBUTTONS = 8
C_UIDROPDOWNMENU_MAXBUTTONS = 8
C_UIDROPDOWNMENU_OPEN_MENU = nil
C_UIDROPDOWNMENU_INIT_MENU = nil
C_UIDROPDOWNMENU_MENU_LEVEL = 1
C_UIDROPDOWNMENU_MENU_VALUE = nil
C_UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT = nil
C_OPEN_DROPDOWNMENUS = {}

local C_UIDropDownMenuDelegate = CreateFrame("FRAME")

local listFramePrefix = "C_DropDownList"
local buttonPrefix = "Button"

for i = 1, 2 do
	local listName = listFramePrefix .. i
	local f = CreateFrame("Button", listName, nil, "C_UIDropDownListTemplate")
	f:SetID(i)
	f:SetSize(180, 10)
	f:SetToplevel(true)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:Hide()

	if i == 1 then
		local fontName, fontHeight, fontFlags = _G[listName.."Button1NormalText"]:GetFont()
		C_UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT = fontHeight
	end
	UIMenus[#UIMenus+1] = listName
end

C_UIDropDownMenu_OnUpdate = UIDropDownMenu_OnUpdate
C_UIDropDownMenu_StartCounting = UIDropDownMenu_StartCounting
C_UIDropDownMenu_StopCounting = UIDropDownMenu_StopCounting

function C_UIDropDownMenuDelegate_OnAttributeChanged (self, attribute, value)
	if ( attribute == "createframes" and value == true ) then
		C_UIDropDownMenu_CreateFrames(self:GetAttribute("createframes-level"), self:GetAttribute("createframes-index"))
	elseif ( attribute == "initmenu" ) then
		C_UIDROPDOWNMENU_INIT_MENU = value
	elseif ( attribute == "openmenu" ) then
		C_UIDROPDOWNMENU_OPEN_MENU = value
	end
end

C_UIDropDownMenuDelegate:SetScript("OnAttributeChanged", C_UIDropDownMenuDelegate_OnAttributeChanged)

function C_UIDropDownMenu_InitializeHelper (frame)
	if ( frame ~= C_UIDROPDOWNMENU_OPEN_MENU ) then
		C_UIDROPDOWNMENU_MENU_LEVEL = 1
	end

	C_UIDropDownMenuDelegate:SetAttribute("initmenu", frame)

	local button, dropDownList
	for i = 1, C_UIDROPDOWNMENU_MAXLEVELS, 1 do
		dropDownList = _G[listFramePrefix..i]
		if ( i >= C_UIDROPDOWNMENU_MENU_LEVEL or frame ~= C_UIDROPDOWNMENU_OPEN_MENU ) then
			dropDownList.numButtons = 0
			dropDownList.maxWidth = 0
			for j=1, C_UIDROPDOWNMENU_MAXBUTTONS, 1 do
				_G[listFramePrefix..i..buttonPrefix..j]:Hide()
			end
			dropDownList:Hide()
		end
	end
	frame:SetHeight(C_UIDROPDOWNMENU_BUTTON_HEIGHT * 2)
end

function C_UIDropDownMenu_Initialize(frame, initFunction, displayMode, level, menuList)
	frame.menuList = menuList
	securecall("C_UIDropDownMenu_InitializeHelper", frame)

	if ( initFunction ) then
		frame.initialize = initFunction
		initFunction(frame, level, frame.menuList)
	end

	if ( displayMode == "MENU" ) then
		local name = frame:GetName()
		_G[name.."Left"]:Hide()
		_G[name.."Middle"]:Hide()
		_G[name.."Right"]:Hide()
		local btn = _G[name..buttonPrefix]
		_G[name.."ButtonNormalTexture"]:SetTexture("")
		_G[name.."ButtonDisabledTexture"]:SetTexture("")
		_G[name.."ButtonPushedTexture"]:SetTexture("")
		_G[name.."ButtonHighlightTexture"]:SetTexture("")
		btn:ClearAllPoints()
		btn:SetPoint("LEFT", name.."Text", "LEFT", -9, 0)
		btn:SetPoint("RIGHT", name.."Text", "RIGHT", 6, 0)
		frame.displayMode = "MENU"
	end
end

local UIDropDownMenu_ButtonInfo = {}
local UIDropDownMenu_SecureInfo = {}

function C_UIDropDownMenu_CreateInfo()
	local info = issecure() and UIDropDownMenu_SecureInfo or UIDropDownMenu_ButtonInfo
	wipe(info)
	return info
end

function C_UIDropDownMenu_CreateFrames(level, index)
	while ( level > C_UIDROPDOWNMENU_MAXLEVELS ) do
		C_UIDROPDOWNMENU_MAXLEVELS = C_UIDROPDOWNMENU_MAXLEVELS + 1;
		local newList = CreateFrame("Button", listFramePrefix..C_UIDROPDOWNMENU_MAXLEVELS, nil, "C_UIDropDownListTemplate");
		newList:SetFrameStrata("FULLSCREEN_DIALOG");
		newList:SetToplevel(1);
		newList:Hide();
		newList:SetID(C_UIDROPDOWNMENU_MAXLEVELS);
		newList:SetWidth(180)
		newList:SetHeight(10)
		for i=C_UIDROPDOWNMENU_MINBUTTONS+1, C_UIDROPDOWNMENU_MAXBUTTONS do
			local newButton = CreateFrame("Button", listFramePrefix..C_UIDROPDOWNMENU_MAXLEVELS..buttonPrefix..i, newList, "C_UIDropDownMenuButtonTemplate");
			newButton:SetID(i);
		end
	end

	while ( index > C_UIDROPDOWNMENU_MAXBUTTONS ) do
		C_UIDROPDOWNMENU_MAXBUTTONS = C_UIDROPDOWNMENU_MAXBUTTONS + 1;
		for i=1, C_UIDROPDOWNMENU_MAXLEVELS do
			local newButton = CreateFrame("Button", listFramePrefix..i..buttonPrefix..C_UIDROPDOWNMENU_MAXBUTTONS, _G[listFramePrefix..i], "C_UIDropDownMenuButtonTemplate");
			newButton:SetID(C_UIDROPDOWNMENU_MAXBUTTONS);
		end
	end
end

function C_UIDropDownMenu_AddButton(info, level)
	level = level or 1
	local listFrame = _G[listFramePrefix..level]
	local index = listFrame and (listFrame.numButtons + 1) or 1
	local width

	C_UIDropDownMenuDelegate:SetAttribute("createframes-level", level)
	C_UIDropDownMenuDelegate:SetAttribute("createframes-index", index)
	C_UIDropDownMenuDelegate:SetAttribute("createframes", true)

	listFrame = listFrame or _G[listFramePrefix..level]
	local listFrameName = listFrame:GetName()
	listFrame.numButtons = index

	local buttonName = listFrameName..buttonPrefix..index
	local button = _G[buttonName]
	local normalText = _G[buttonName.."NormalText"]
	local icon = _G[buttonName.."Icon"]
	local invisibleButton = _G[buttonName.."InvisibleButton"]

	button:SetDisabledFontObject(GameFontDisableSmallLeft)
	invisibleButton:Hide()
	button:Enable()

	if ( info.notClickable or info.isTitle ) then
		info.disabled = 1
		button:SetDisabledFontObject(info.isTitle and GameFontNormalSmallLeft or GameFontHighlightSmallLeft)
	end

	if ( info.disabled ) then
		button:Disable()
		invisibleButton:Show()
		info.colorCode = nil
	end

	if ( info.text ) then
		button:SetText(info.colorCode and (info.colorCode..info.text.."|r") or info.text)
		width = normalText:GetWidth() + 40
		if ( info.hasArrow or info.hasColorSwatch ) then width = width + 10 end
		if ( info.notCheckable ) then width = width - 30 end

		if ( info.icon ) then
			icon:SetTexture(info.icon)
			if ( info.tCoordLeft ) then
				icon:SetTexCoord(info.tCoordLeft, info.tCoordRight, info.tCoordTop, info.tCoordBottom)
			else
				icon:SetTexCoord(0, 1, 0, 1)
			end
			icon:Show()
			width = width + 10
		else
			icon:Hide()
		end

		if ( info.padding ) then width = width + info.padding end
		if ( width > listFrame.maxWidth ) then listFrame.maxWidth = width end

		local fontObj = info.fontObject or GameFontHighlightSmallLeft
		button:SetNormalFontObject(fontObj)
		button:SetHighlightFontObject(fontObj)
	else
		button:SetText("")
		icon:Hide()
	end

	-- Bulk attribute assignment
	button.func = info.func
	button.owner = info.owner
	button.hasOpacity = info.hasOpacity
	button.opacity = info.opacity
	button.opacityFunc = info.opacityFunc
	button.cancelFunc = info.cancelFunc
	button.swatchFunc = info.swatchFunc
	button.keepShownOnClick = info.keepShownOnClick
	button.tooltipTitle = info.tooltipTitle
	button.tooltipText = info.tooltipText
	button.arg1 = info.arg1
	button.arg2 = info.arg2
	button.hasArrow = info.hasArrow
	button.hasColorSwatch = info.hasColorSwatch
	button.notCheckable = info.notCheckable
	button.menuList = info.menuList
	button.tooltipWhileDisabled = info.tooltipWhileDisabled
	button.tooltipOnButton = info.tooltipOnButton
	button.noClickSound = info.noClickSound
	button.padding = info.padding
	button.value = info.value or info.text

	local expandArrow = _G[buttonName.."ExpandArrow"]
	if ( info.hasArrow ) then expandArrow:Show() else expandArrow:Hide() end

	local xPos = info.notCheckable and 15 or 17
	local yPos = -((button:GetID() - 1) * C_UIDROPDOWNMENU_BUTTON_HEIGHT) - C_UIDROPDOWNMENU_BORDER_HEIGHT

	normalText:ClearAllPoints()
	if ( info.notCheckable ) then
		if ( info.justifyH == "CENTER" ) then
			normalText:SetPoint("CENTER", button, "CENTER", -7, 0)
		else
			normalText:SetPoint("LEFT", button, "LEFT", 0, 0)
		end
	else
		normalText:SetPoint("LEFT", button, "LEFT", 20, 0)
	end

	local openMenu = C_UIDROPDOWNMENU_OPEN_MENU or C_UIDROPDOWNMENU_INIT_MENU
	if ( openMenu and openMenu.displayMode == "MENU" and not info.notCheckable ) then
		xPos = xPos - 6
	end

	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", xPos, yPos)

	-- Logic for checking if the button is the selected one
	if ( openMenu ) then
		if ( button:GetText() == openMenu.selectedName or button:GetID() == openMenu.selectedID or button.value == openMenu.selectedValue ) then
			info.checked = 1
		end
	end

	local checked = type(info.checked) == "function" and info.checked() or info.checked
	local check = _G[buttonName.."Check"]

	if ( checked ) then
		button:LockHighlight()
		check:Show()
	else
		button:UnlockHighlight()
		check:Hide()
	end
	button.checked = info.checked

	if ( C_UIDROPDOWNMENU_OPEN_MENU and not info.notCheckable ) then
		local isRadio = info.isRadio
		check:SetDesaturated(info.disabled or (isRadio and not checked))
		check:SetAlpha((info.disabled or (isRadio and not checked)) and 0.25 or 1)

		if ( isRadio ) then
			check:SetTexture("Interface\\Buttons\\UI-RadioButton")
			check:Show()
			if ( checked ) then check:SetTexCoord(.25, .5, 0, 1) else check:SetTexCoord(0, .25, 0, 1) end
		else
			check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
			check:SetTexCoord(0, 1, 0, 1)
		end
	end

	if ( info.hasColorSwatch ) then
		_G[buttonName.."ColorSwatchNormalTexture"]:SetVertexColor(info.r, info.g, info.b)
		button.r, button.g, button.b = info.r, info.g, info.b
		_G[buttonName.."ColorSwatch"]:Show()
	else
		_G[buttonName.."ColorSwatch"]:Hide()
	end

	listFrame:SetHeight((index * C_UIDROPDOWNMENU_BUTTON_HEIGHT) + (C_UIDROPDOWNMENU_BORDER_HEIGHT * 2))
	button:Show()
end

function C_UIDropDownMenu_Refresh(frame, useValue, dropdownLevel)
	dropdownLevel = dropdownLevel or C_UIDROPDOWNMENU_MENU_LEVEL
	local maxWidth = 0
	local selName, selID, selValue = frame.selectedName, frame.selectedID, frame.selectedValue

	for i=1, C_UIDROPDOWNMENU_MAXBUTTONS do
		local button = _G[listFramePrefix..dropdownLevel..buttonPrefix..i]
		if not button then break end

		local checked = (selName and button:GetText() == selName) or (selID and button:GetID() == selID) or (selValue and button.value == selValue)
		local checkImage = _G[button:GetName().."Check"]

		if ( checked ) then
			C_UIDropDownMenu_SetText(frame, useValue and button.value or button:GetText())
			button:LockHighlight()
			checkImage:Show()
		else
			button:UnlockHighlight()
			checkImage:Hide()
		end

		if ( button:IsShown() ) then
			local width = _G[button:GetName().."NormalText"]:GetWidth() + 40
			if ( button.hasArrow or button.hasColorSwatch ) then width = width + 10 end
			if ( button.notCheckable ) then width = width - 30 end
			if ( button.padding ) then width = width + button.padding end
			if ( width > maxWidth ) then maxWidth = width end
		end
	end

	local listFrame = _G[listFramePrefix..dropdownLevel]
	for i=1, C_UIDROPDOWNMENU_MAXBUTTONS do
		local btn = _G[listFramePrefix..dropdownLevel..buttonPrefix..i]
		if btn then btn:SetWidth(maxWidth) else break end
	end
	listFrame:SetWidth(maxWidth + 25)
end

function C_ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList, button)
	level = level or 1
	C_UIDropDownMenuDelegate:SetAttribute("createframes-level", level)
	C_UIDropDownMenuDelegate:SetAttribute("createframes-index", 0)
	C_UIDropDownMenuDelegate:SetAttribute("createframes", true)

	C_UIDROPDOWNMENU_MENU_LEVEL = level
	C_UIDROPDOWNMENU_MENU_VALUE = value

	local listFrame = _G[listFramePrefix..level]
	local tempFrame = dropDownFrame or button:GetParent()

	if ( listFrame:IsShown() and (C_UIDROPDOWNMENU_OPEN_MENU == tempFrame) ) then
		listFrame:Hide()
	else
		local uiScale = 1
		local uiParentScale = UIParent:GetScale()
		if ( tempFrame ~= WorldMapContinentDropDown and tempFrame ~= WorldMapZoneDropDown ) then
			if ( GetCVar("useUIScale") == "1" ) then
				uiScale = tonumber(GetCVar("uiscale"))
				if ( uiParentScale < uiScale ) then uiScale = uiParentScale end
			else
				uiScale = uiParentScale
			end
		end
		listFrame:SetScale(uiScale)
		listFrame:Hide()

		local point, relativePoint, relativeTo = "TOPLEFT", "BOTTOMLEFT", nil

		if ( level == 1 ) then
			C_UIDropDownMenuDelegate:SetAttribute("openmenu", dropDownFrame)
			listFrame:ClearAllPoints()
			if ( not anchorName ) then
				xOffset = dropDownFrame.xOffset or 8
				yOffset = dropDownFrame.yOffset or 22
				point = dropDownFrame.point or "TOPLEFT"
				relativeTo = dropDownFrame.relativeTo or (C_UIDROPDOWNMENU_OPEN_MENU:GetName().."Left")
				relativePoint = dropDownFrame.relativePoint or "BOTTOMLEFT"
			elseif ( anchorName == "cursor" ) then
				local cursorX, cursorY = GetCursorPosition()
				xOffset = (cursorX / uiScale) + (xOffset or 0)
				yOffset = (cursorY / uiScale) + (yOffset or 0)
			else
				xOffset, yOffset = dropDownFrame.xOffset or xOffset or 8, dropDownFrame.yOffset or yOffset or 22
				point = dropDownFrame.point or "TOPLEFT"
				relativeTo = dropDownFrame.relativeTo or anchorName
				relativePoint = dropDownFrame.relativePoint or "BOTTOMLEFT"
			end
			listFrame:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset)
		else
			if ( not dropDownFrame ) then dropDownFrame = C_UIDROPDOWNMENU_OPEN_MENU end
			listFrame:ClearAllPoints()
			local anchorFrame = (strsub(button:GetParent():GetName(), 1, 12) == listFramePrefix) and button or button:GetParent()
			listFrame:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 0, 0)
		end

		local listFrameName = listFrame:GetName()
		local isMenu = dropDownFrame and dropDownFrame.displayMode == "MENU"
		_G[listFrameName.."Backdrop"]:SetShown(not isMenu)
		_G[listFrameName.."MenuBackdrop"]:SetShown(isMenu)

		dropDownFrame.menuList = menuList
		C_UIDropDownMenu_Initialize(dropDownFrame, dropDownFrame.initialize, nil, level, menuList)

		if ( listFrame.numButtons == 0 ) then return end

		listFrame:Show()
		local x, y = listFrame:GetCenter()
		if ( not x or not y ) then listFrame:Hide(); return end

		listFrame.onHide = dropDownFrame.onHide
		local offY = (y - listFrame:GetHeight()/2) < 0
		local offX = listFrame:GetRight() > GetScreenWidth()

		-- Simplified screen bounds correction
		if ( offY or offX ) then
			if ( level == 1 ) then
				if ( offY ) then point = gsub(point, "TOP", "BOTTOM"); relativePoint = gsub(relativePoint, "TOP", "BOTTOM") end
				if ( offX ) then point = gsub(point, "LEFT", "RIGHT"); relativePoint = gsub(relativePoint, "LEFT", "RIGHT") end
				listFrame:ClearAllPoints()
				listFrame:SetPoint(point, relativeTo, (anchorName == "cursor" and "BOTTOMLEFT" or relativePoint), xOffset, yOffset)
			else
				-- Sub-menu adjustment
				listFrame:ClearAllPoints()
				listFrame:SetPoint(offY and "BOTTOMRIGHT" or "TOPRIGHT", anchorFrame, offY and "BOTTOMLEFT" or "TOPLEFT", offX and -11 or 0, offY and -14 or 14)
			end
		end
	end
end

-- Remaining setter/getter functions remain unchanged as they are simple and non-looping.

function C_UIDropDownMenu_SetSelectedName(frame, name, useValue)
	frame.selectedName = name
	frame.selectedID = nil
	frame.selectedValue = nil
	C_UIDropDownMenu_Refresh(frame, useValue)
end

function C_UIDropDownMenu_SetSelectedValue(frame, value, useValue)
	-- useValue will set the value as the text, not the name
	frame.selectedName = nil
	frame.selectedID = nil
	frame.selectedValue = value
	C_UIDropDownMenu_Refresh(frame, useValue)
end

function C_UIDropDownMenu_SetSelectedID(frame, id, useValue)
	frame.selectedID = id
	frame.selectedName = nil
	frame.selectedValue = nil
	C_UIDropDownMenu_Refresh(frame, useValue)
end

function C_UIDropDownMenu_GetSelectedName(frame)
	return frame.selectedName
end

function C_UIDropDownMenu_GetSelectedID(frame)
	if ( frame.selectedID ) then
		return frame.selectedID
	else
		-- If no explicit selectedID then try to send the id of a selected value or name
		local button
		for i=1, C_UIDROPDOWNMENU_MAXBUTTONS do
			button = _G[listFramePrefix..C_UIDROPDOWNMENU_MENU_LEVEL..buttonPrefix..i]
			-- See if checked or not
			if ( C_UIDropDownMenu_GetSelectedName(frame) ) then
				if ( button:GetText() == C_UIDropDownMenu_GetSelectedName(frame) ) then
					return i
				end
			elseif ( C_UIDropDownMenu_GetSelectedValue(frame) ) then
				if ( button.value == C_UIDropDownMenu_GetSelectedValue(frame) ) then
					return i
				end
			end
		end
	end
end

function C_UIDropDownMenu_GetSelectedValue(frame)
	return frame.selectedValue
end

function C_UIDropDownMenuButton_OnClick(self)
	local checked = self.checked
	if ( type(checked) == "function" ) then
		checked = checked()
	end

	if ( self.keepShownOnClick ) then
		if ( checked ) then
			_G[self:GetName().."Check"]:Hide()
			checked = false
		else
			_G[self:GetName().."Check"]:Show()
			checked = true
		end
	else
		self:GetParent():Hide()
	end

	if ( type(self.checked) ~= "function" ) then
		self.checked = checked
	end

	-- saving this here because func might use a dropdown, changing this self's attributes
	local playSound = true
	if ( self.noClickSound ) then
		playSound = false
	end

	local func = self.func
	if ( func ) then
		func(self, self.arg1, self.arg2, checked)
	else
		return
	end

	if ( playSound ) then
		PlaySound("UChatScrollButton")
	end
end

function C_HideDropDownMenu(level)
	local listFrame = _G[listFramePrefix..level]
	listFrame:Hide()
end

function C_CloseDropDownMenus(level)
	if ( not level ) then
		level = 1
	end
	for i=level, C_UIDROPDOWNMENU_MAXLEVELS do
		_G[listFramePrefix..i]:Hide()
	end
end

function C_UIDropDownMenu_OnHide(self)
	local id = self:GetID()
	if ( self.onHide ) then
		self.onHide(id+1)
		self.onHide = nil
	end
	C_CloseDropDownMenus(id+1)
	C_OPEN_DROPDOWNMENUS[id] = nil
end

function C_UIDropDownMenu_SetWidth(frame, width, padding)
	_G[frame:GetName().."Middle"]:SetWidth(width)
	local defaultPadding = 25
	if ( padding ) then
		frame:SetWidth(width + padding)
	else
		frame:SetWidth(width + defaultPadding + defaultPadding)
	end
	if ( padding ) then
		_G[frame:GetName().."Text"]:SetWidth(width)
	else
		_G[frame:GetName().."Text"]:SetWidth(width - defaultPadding)
	end
	frame.noResize = 1
end

function C_UIDropDownMenu_SetButtonWidth(frame, width)
	if ( width == "TEXT" ) then
		width = _G[frame:GetName().."Text"]:GetWidth()
	end

	_G[frame:GetName()..buttonPrefix]:SetWidth(width)
	frame.noResize = 1
end

function C_UIDropDownMenu_SetText(frame, text)
	local filterText = _G[frame:GetName().."Text"]
	filterText:SetText(text)
end

function C_UIDropDownMenu_GetText(frame)
	local filterText = _G[frame:GetName().."Text"]
	return filterText:GetText()
end

function C_UIDropDownMenu_ClearAll(frame)
	-- Previous code refreshed the menu quite often and was a performance bottleneck
	frame.selectedID = nil
	frame.selectedName = nil
	frame.selectedValue = nil
	C_UIDropDownMenu_SetText(frame, "")

	local button, checkImage
	for i=1, C_UIDROPDOWNMENU_MAXBUTTONS do
		button = _G[listFramePrefix..C_UIDROPDOWNMENU_MENU_LEVEL..buttonPrefix..i]
		button:UnlockHighlight()

		checkImage = _G[listFramePrefix..C_UIDROPDOWNMENU_MENU_LEVEL..buttonPrefix..i.."Check"]
		checkImage:Hide()
	end
end

function C_UIDropDownMenu_JustifyText(frame, justification)
	local text = _G[frame:GetName().."Text"]
	text:ClearAllPoints()
	if ( justification == "LEFT" ) then
		text:SetPoint("LEFT", frame:GetName().."Left", "LEFT", 27, 2)
		text:SetJustifyH("LEFT")
	elseif ( justification == "RIGHT" ) then
		text:SetPoint("RIGHT", frame:GetName().."Right", "RIGHT", -43, 2)
		text:SetJustifyH("RIGHT")
	elseif ( justification == "CENTER" ) then
		text:SetPoint("CENTER", frame:GetName().."Middle", "CENTER", -5, 2)
		text:SetJustifyH("CENTER")
	end
end

function C_UIDropDownMenu_SetAnchor(dropdown, xOffset, yOffset, point, relativeTo, relativePoint)
	dropdown.xOffset = xOffset
	dropdown.yOffset = yOffset
	dropdown.point = point
	dropdown.relativeTo = relativeTo
	dropdown.relativePoint = relativePoint
end

function C_UIDropDownMenu_GetCurrentDropDown()
	if ( C_UIDROPDOWNMENU_OPEN_MENU ) then
		return C_UIDROPDOWNMENU_OPEN_MENU
	elseif ( C_UIDROPDOWNMENU_INIT_MENU ) then
		return C_UIDROPDOWNMENU_INIT_MENU
	end
end

function C_UIDropDownMenuButton_GetChecked(self)
	return _G[self:GetName().."Check"]:IsShown()
end

function C_UIDropDownMenuButton_GetName(self)
	return _G[self:GetName().."NormalText"]:GetText()
end

function C_UIDropDownMenuButton_C_OpenColorPicker(self, button)
	CloseMenus()
	if ( not button ) then
		button = self
	end
	C_UIDROPDOWNMENU_MENU_VALUE = button.value
	C_OpenColorPicker(button)
end

function C_UIDropDownMenu_DisableButton(level, id)
	_G[listFramePrefix..level..buttonPrefix..id]:Disable()
end

function C_UIDropDownMenu_EnableButton(level, id)
	_G[listFramePrefix..level..buttonPrefix..id]:Enable()
end

function C_UIDropDownMenu_SetButtonText(level, id, text, colorCode)
	local button = _G[listFramePrefix..level..buttonPrefix..id]
	if ( colorCode) then
		button:SetText(colorCode..text.."|r")
	else
		button:SetText(text)
	end
end

function C_UIDropDownMenu_DisableDropDown(dropDown)
	local label = _G[dropDown:GetName().."Label"]
	if ( label ) then
		label:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	end
	_G[dropDown:GetName().."Text"]:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	_G[dropDown:GetName()..buttonPrefix]:Disable()
	dropDown.isDisabled = 1
end

function C_UIDropDownMenu_EnableDropDown(dropDown)
	local label = _G[dropDown:GetName().."Label"]
	if ( label ) then
		label:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end
	_G[dropDown:GetName().."Text"]:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	_G[dropDown:GetName()..buttonPrefix]:Enable()
	dropDown.isDisabled = nil
end

function C_UIDropDownMenu_IsEnabled(dropDown)
	return not dropDown.isDisabled
end

function C_UIDropDownMenu_GetValue(id)
	--Only works if the dropdown has just been initialized, lame, I know =(
	local button = _G["C_DropDownList1Button"..id]
	if ( button ) then
		return _G["C_DropDownList1Button"..id].value
	else
		return nil
	end
end