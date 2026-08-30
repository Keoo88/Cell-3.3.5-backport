local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs
---@type CellAnimations
local A = Cell.animations
---@type PixelPerfectFuncs
local P = Cell.pixelPerfectFuncs

local LCG = LibStub("LibCustomGlow-1.0-Cell")
local LibTranslit = LibStub("LibTranslit-1.0")
--! WotLK fix: use Cell's private class-token normalizer; keep native UnitClassBase untouched.
local UnitClassBase = Cell.GetUnitClassToken
--! WotLK fix: consume Cell-private group state.
local IsInRaid = Cell.IsInRaid

--! WotLK perf: sin зовётся из драйвера aggro-пульса, а тот работает на полном
--! фреймрейте на каждом юните с аггро. Файловый локал убирает из каждого кадра
--! GETGLOBAL math (хеш-лукап в _G) плюс хеш-лукап поля .sin.
local sin = math.sin

local function noop() end

-------------------------------------------------
-- shared functions
-------------------------------------------------
function I.Cooldowns_SetSize(self, width, height)
    self.width = width
    self.height = height

    for i = 1, #self do
        self[i]:SetSize(width, height)
    end

    self:UpdateSize()
end

function I.Cooldowns_UpdateSize(self, iconsShown)
    if not (self.width and self.height and self.orientation) then return end -- not init

    if iconsShown then -- call from I.UnitButton_UpdateBuffs or preview
        for i = iconsShown + 1, #self do
            self[i]:Hide()
        end
        if iconsShown ~= 0 then
            if self.orientation == "horizontal" then
                self:_SetSize(self.width*iconsShown-P.Scale(iconsShown-1), self.height)
            else
                self:_SetSize(self.width, self.height*iconsShown-P.Scale(iconsShown-1))
            end
        end
    else
        for i = 1, #self do
            if self[i]:IsShown() then
                if self.orientation == "horizontal" then
                    self:_SetSize(self.width*i-P.Scale(i-1), self.height)
                else
                    self:_SetSize(self.width, self.height*i-P.Scale(i-1))
                end
            end
        end
    end
end

function I.Cooldowns_UpdateSize_WithSpacing(self, iconsShown)
    if not (self.width and self.height and self.orientation) then return end -- not init

    if iconsShown then -- call from I.UnitButton_UpdateBuffs or preview
        for i = iconsShown + 1, #self do
            self[i]:Hide()
        end
        if iconsShown ~= 0 then
            if self.orientation == "horizontal" then
                self:_SetSize(self.width * iconsShown + P.Scale(iconsShown - 1), self.height)
            else
                self:_SetSize(self.width, self.height * iconsShown + P.Scale(iconsShown - 1))
            end
        end
    else
        for i = 1, #self do
            if self[i]:IsShown() then
                if self.orientation == "horizontal" then
                    self:_SetSize(self.width * i + P.Scale(i - 1), self.height)
                else
                    self:_SetSize(self.width, self.height * i + P.Scale(i - 1))
                end
            end
        end
    end
end

function I.Cooldowns_SetBorder(self, border)
    for i = 1, #self do
        self[i]:SetBorder(border)
    end
end

function I.Cooldowns_SetFont(self, ...)
    for i = 1, #self do
        self[i]:SetFont(...)
    end
end

function I.Cooldowns_ShowDuration(self, show)
    for i = 1, #self do
        self[i]:ShowDuration(show)
    end
end

function I.Cooldowns_ShowAnimation(self, show)
    for i = 1, #self do
        self[i]:ShowAnimation(show)
    end
end

function I.Cooldowns_UpdatePixelPerfect(self)
    P.Repoint(self)
    for i = 1, #self do
        self[i]:UpdatePixelPerfect()
    end
end

function I.Cooldowns_SetOrientation(self, orientation)
    local point1, point2, x, y

    if orientation == "left-to-right" then
        point1 = "TOPLEFT"
        point2 = "TOPRIGHT"
        self.orientation = "horizontal"
        x = -1
        y = 0
    elseif orientation == "right-to-left" then
        point1 = "TOPRIGHT"
        point2 = "TOPLEFT"
        self.orientation = "horizontal"
        x = 1
        y = 0
    elseif orientation == "top-to-bottom" then
        point1 = "TOPLEFT"
        point2 = "BOTTOMLEFT"
        self.orientation = "vertical"
        x = 0
        y = 1
    elseif orientation == "bottom-to-top" then
        point1 = "BOTTOMLEFT"
        point2 = "TOPLEFT"
        self.orientation = "vertical"
        x = 0
        y = -1
    end

    for i = 1, #self do
        P.ClearPoints(self[i])
        if i == 1 then
            P.Point(self[i], point1)
        else
            P.Point(self[i], point1, self[i-1], point2, x, y)
        end
    end

    self:UpdateSize()
end

function I.Cooldowns_SetOrientation_WithSpacing(self, orientation)
    local point1, point2, x, y

    if orientation == "left-to-right" then
        point1 = "TOPLEFT"
        point2 = "TOPRIGHT"
        self.orientation = "horizontal"
        x = 1
        y = 0
    elseif orientation == "right-to-left" then
        point1 = "TOPRIGHT"
        point2 = "TOPLEFT"
        self.orientation = "horizontal"
        x = -1
        y = 0
    elseif orientation == "top-to-bottom" then
        point1 = "TOPLEFT"
        point2 = "BOTTOMLEFT"
        self.orientation = "vertical"
        x = 0
        y = -1
    elseif orientation == "bottom-to-top" then
        point1 = "BOTTOMLEFT"
        point2 = "TOPLEFT"
        self.orientation = "vertical"
        x = 0
        y = 1
    end

    for i = 1, #self do
        P.ClearPoints(self[i])
        if i == 1 then
            P.Point(self[i], point1)
        else
            P.Point(self[i], point1, self[i-1], point2, x, y)
        end
    end

    self:UpdateSize()
end

-------------------------------------------------
-- CreateDefensiveCooldowns
-------------------------------------------------
function I.CreateDefensiveCooldowns(parent)
    local defensiveCooldowns = CreateFrame("Frame", parent:GetName().."DefensiveCooldownParent", parent.widgets.indicatorFrame)
    parent.indicators.defensiveCooldowns = defensiveCooldowns
    -- defensiveCooldowns:SetSize(20, 10)
    defensiveCooldowns:Hide()

    defensiveCooldowns._SetSize = defensiveCooldowns.SetSize
    defensiveCooldowns.SetSize = I.Cooldowns_SetSize
    defensiveCooldowns.UpdateSize = I.Cooldowns_UpdateSize
    defensiveCooldowns.SetFont = I.Cooldowns_SetFont
    defensiveCooldowns.SetOrientation = I.Cooldowns_SetOrientation
    defensiveCooldowns.ShowDuration = I.Cooldowns_ShowDuration
    defensiveCooldowns.ShowAnimation = I.Cooldowns_ShowAnimation
    defensiveCooldowns.SetupGlow = I.Glow_SetupForChildren
    defensiveCooldowns.UpdatePixelPerfect = I.Cooldowns_UpdatePixelPerfect

    for i = 1, 5 do
        local name = parent:GetName().."DefensiveCooldown"..i
        local frame = I.CreateAura_BarIcon(name, defensiveCooldowns)
        tinsert(defensiveCooldowns, frame)
    end
end

-------------------------------------------------
-- CreateExternalCooldowns
-------------------------------------------------
function I.CreateExternalCooldowns(parent)
    local externalCooldowns = CreateFrame("Frame", parent:GetName().."ExternalCooldownParent", parent.widgets.indicatorFrame)
    parent.indicators.externalCooldowns = externalCooldowns
    externalCooldowns:Hide()

    externalCooldowns._SetSize = externalCooldowns.SetSize
    externalCooldowns.SetSize = I.Cooldowns_SetSize
    externalCooldowns.UpdateSize = I.Cooldowns_UpdateSize
    externalCooldowns.SetFont = I.Cooldowns_SetFont
    externalCooldowns.SetOrientation = I.Cooldowns_SetOrientation
    externalCooldowns.ShowDuration = I.Cooldowns_ShowDuration
    externalCooldowns.ShowAnimation = I.Cooldowns_ShowAnimation
    externalCooldowns.SetupGlow = I.Glow_SetupForChildren
    externalCooldowns.UpdatePixelPerfect = I.Cooldowns_UpdatePixelPerfect

    for i = 1, 5 do
        local name = parent:GetName().."ExternalCooldown"..i
        local frame = I.CreateAura_BarIcon(name, externalCooldowns)
        tinsert(externalCooldowns, frame)
    end
end

-------------------------------------------------
-- CreateAllCooldowns
-------------------------------------------------
function I.CreateAllCooldowns(parent)
    local allCooldowns = CreateFrame("Frame", parent:GetName().."AllCooldownParent", parent.widgets.indicatorFrame)
    parent.indicators.allCooldowns = allCooldowns
    allCooldowns:Hide()

    allCooldowns._SetSize = allCooldowns.SetSize
    allCooldowns.SetSize = I.Cooldowns_SetSize
    allCooldowns.UpdateSize = I.Cooldowns_UpdateSize
    allCooldowns.SetFont = I.Cooldowns_SetFont
    allCooldowns.SetOrientation = I.Cooldowns_SetOrientation
    allCooldowns.ShowDuration = I.Cooldowns_ShowDuration
    allCooldowns.ShowAnimation = I.Cooldowns_ShowAnimation
    allCooldowns.SetupGlow = I.Glow_SetupForChildren
    allCooldowns.UpdatePixelPerfect = I.Cooldowns_UpdatePixelPerfect

    for i = 1, 5 do
        local name = parent:GetName().."ExternalCooldown"..i
        local frame = I.CreateAura_BarIcon(name, allCooldowns)
        tinsert(allCooldowns, frame)
    end
end

-------------------------------------------------
-- CreateTankActiveMitigation
-------------------------------------------------
function I.CreateTankActiveMitigation(parent)
    local bar = Cell.CreateStatusBar(parent:GetName().."TanckActiveMitigation", parent.widgets.indicatorFrame, 20, 6, 100)
    parent.indicators.tankActiveMitigation = bar
    bar:Hide()

    bar:SetStatusBarTexture(Cell.vars.whiteTexture)
    --! WotLK fix: keep the fallback private to this Cell-owned bar.
    local barTexture = bar:GetStatusBarTexture()
    if not barTexture then
        barTexture = bar:CreateTexture(nil, "ARTWORK")
        barTexture:SetTexture(Cell.vars.whiteTexture)
        bar:SetStatusBarTexture(barTexture)
    end
    barTexture:SetAlpha(0)
    --! WotLK fix: the visible mitigation texture is anchored to the native bar
    --! texture; no fake shared StatusBar:SetReverseFill contract is required.

    local tex = bar:CreateTexture(nil, "BORDER", nil, -1)
    bar.tex = tex
    --! WotLK fix: SetColorTexture на 3.3.5 нет - это нативная числовая форма
    --! SetTexture(r, g, b[, a]); шим TextureBase в WidgetAPI удалён.
    tex:SetTexture(F.GetClassColor(Cell.vars.playerClass))
    tex:SetPoint("TOPLEFT")
    tex:SetPoint("BOTTOMRIGHT", barTexture, "BOTTOMLEFT")

    local elapsedTime = 0
    bar:SetScript("OnUpdate", function(self, elapsed)
        if elapsedTime >= 0.1 then
            --! WotLK perf: работаем через self, а не через апвалью bar - это тот
            --! же фрейм (скрипт висит на нём), но локал дешевле апвалью.
            self:SetValue(self:GetValue() + elapsedTime)
            elapsedTime = 0
        end
        elapsedTime = elapsedTime + elapsed
    end)

    function bar:SetCooldown(start, duration)
        if bar.cType == "class_color" then
            if not parent.states.class then parent.states.class = UnitClassBase(parent.states.unit) end --? why sometimes parent.states.class == nil ???
            tex:SetTexture(F.GetClassColor(parent.states.class))
        else
            tex:SetTexture(bar.cTable[1], bar.cTable[2], bar.cTable[3])
        end
        bar:SetMinMaxValues(0, duration)
        bar:SetValue(GetTime()-start)
        bar:Show()
    end

    function bar:SetColor(cType, cTable)
        bar.cType = cType
        bar.cTable = cTable
    end
end

-------------------------------------------------
-- CreateDebuffs
-------------------------------------------------
local function Debuffs_SetSize(self, normalSize, bigSize)
    for i = 1, 10 do
        P.Size(self[i], normalSize[1], normalSize[2])
    end
    -- store sizes for SetCooldown
    self.normalSize = normalSize
    self.bigSize = bigSize
    -- remove wrong data from PixelPerfect
    self.width = nil
    self.height = nil

    self:UpdateSize()
end

local function Debuffs_UpdateSize(self, iconsShown)
    if not (self.normalSize and self.bigSize and self.orientation) then return end -- not init

    if iconsShown then
        for i = iconsShown + 1, 10 do
            self[i]:Hide()
        end
    end

    local size = 0
    for i = 1, 10 do
        if self[i]:IsShown() then
            size = size + self[i].width
        end
    end
    if self.orientation == "left-to-right" or self.orientation == "right-to-left"  then
        self:_SetSize(P.Scale(size), P.Scale(self.normalSize[2]))
    else
        self:_SetSize(P.Scale(self.normalSize[1]), P.Scale(size))
    end
end

local function Debuffs_SetFont(self, ...)
    for i = 1, 10 do
        self[i]:SetFont(...)
    end
end

local function Debuffs_SetPoint(self, point, relativeTo, relativePoint, x, y)
    self:_SetPoint(point, relativeTo, relativePoint, x, y)

    if string.find(point, "LEFT$") then
        self.hAlignment = "LEFT"
    elseif string.find(point, "RIGHT$") then
        self.hAlignment = "RIGHT"
    else
        self.hAlignment = ""
    end

    if string.find(point, "^TOP") then
        self.vAlignment = "TOP"
    elseif string.find(point, "^BOTTOM") then
        self.vAlignment = "BOTTOM"
    else
        self.vAlignment = ""
    end

    if self.hAlignment == "" and self.vAlignment == "" then
        self.vAlignment = "CENTER"
    end

    -- self[1]:ClearAllPoints()
    -- self[1]:SetPoint(self.vAlignment..self.hAlignment)
    -- --! update icons
    self:SetOrientation(self.orientation or "left-to-right")
end

--! NOTE: SetPoint must be invoked before SetOrientation
local function Debuffs_SetOrientation(self, orientation)
    self.orientation = orientation
    local point1, point2, v, h
    v = self.vAlignment == "CENTER" and "" or self.vAlignment
    h = self.hAlignment
    if orientation == "left-to-right" then
        point1 = v.."LEFT"
        point2 = v.."RIGHT"
    elseif orientation == "right-to-left" then
        point1 = v.."RIGHT"
        point2 = v.."LEFT"
    elseif orientation == "top-to-bottom" then
        point1 = "TOP"..h
        point2 = "BOTTOM"..h
    elseif orientation == "bottom-to-top" then
        point1 = "BOTTOM"..h
        point2 = "TOP"..h
    end

    for i = 1, 10 do
        P.ClearPoints(self[i])
        if i == 1 then
            P.Point(self[i], point1)
        else
            P.Point(self[i], point1, self[i-1], point2)
        end
    end

    self:UpdateSize()
end

local function Debuffs_ShowTooltip(debuffs, show)
    debuffs.showTooltip = show

    for i = 1, 10 do
        if show then
            debuffs[i]:SetScript("OnEnter", function(self)
                --! WotLK fix: the second branch was "elseif self.auraInstanceID" ->
                --! F.ShowTooltips(..., "aura", ...), i.e. retail's aura-instance
                --! tooltip. Nothing on 3.3.5 ever sets .auraInstanceID on an icon
                --! (UnitButton_Cata_Wrath.lua stores the aura INDEX in .index, see
                --! "NOTE: for tooltip"), so it was two dead field lookups per hover
                --! guarding a call into methods this client does not have.
                if self.index then
                    F.ShowTooltips(debuffs.parent, "spell", debuffs.parent.states.displayedUnit, self.index, "HARMFUL")
                end
            end)

            debuffs[i]:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            -- https://warcraft.wiki.gg/wiki/API_ScriptRegion_EnableMouse
            if not debuffs.enableBlacklistShortcut then
                debuffs[i]:EnableMouse(true)
            end
        else
            debuffs[i]:SetScript("OnEnter", nil)
            debuffs[i]:SetScript("OnLeave", nil)
            if debuffs.enableBlacklistShortcut then
                debuffs[i]:EnableMouse(false)
            else
                debuffs[i]:EnableMouse(false)
            end
        end
    end
end

local function Debuffs_EnableBlacklistShortcut(debuffs, enabled)
    debuffs.enableBlacklistShortcut = enabled

    for i = 1, 10 do
        if enabled then
            debuffs[i]:SetScript("OnMouseUp", function(self, button, isInside)
                if button == "RightButton" and isInside and IsLeftAltKeyDown() and IsLeftControlKeyDown()
                    and self.spellId and not F.TContains(CellDB["debuffBlacklist"], self.spellId) then
                    -- print msg
                    local name, icon = F.GetSpellInfo(self.spellId)
                    if name and icon then
                        F.Print(L["Added |T%d:0|t|cFFFF3030%s(%d)|r into debuff blacklist."]:format(icon, name, self.spellId))
                    end
                    -- update db
                    tinsert(CellDB["debuffBlacklist"], self.spellId)
                    Cell.vars.debuffBlacklist = F.ConvertTable(CellDB["debuffBlacklist"])
                    Cell.Fire("UpdateIndicators", Cell.vars.currentLayout, "", "debuffBlacklist")
                    -- refresh
                    F.ReloadIndicatorOptions(Cell.defaults.indicatorIndices.debuffs)
                end
            end)
        else
            debuffs[i]:SetScript("OnMouseUp", nil)
            if debuffs.showTooltip then
                --! WotLK fix: 3.3.5 cannot separate click and hover ownership;
                --! keep mouse enabled on this Cell-owned debuff so OnEnter tooltip
                --! still fires, and leave the unsupported shared retail API absent.
                debuffs[i]:EnableMouse(true)
            else
                debuffs[i]:EnableMouse(false)
            end
        end
    end
end

function I.CreateDebuffs(parent)
    local debuffs = CreateFrame("Frame", parent:GetName().."DebuffParent", parent.widgets.indicatorFrame)
    parent.indicators.debuffs = debuffs
    debuffs:Hide()
    debuffs.parent = parent

    debuffs._SetSize = debuffs.SetSize
    debuffs.SetSize = Debuffs_SetSize
    debuffs.UpdateSize = Debuffs_UpdateSize
    debuffs.SetFont = Debuffs_SetFont

    debuffs.hAlignment = ""
    debuffs.vAlignment = ""
    debuffs._SetPoint = debuffs.SetPoint
    debuffs.SetPoint = Debuffs_SetPoint
    debuffs.SetOrientation = Debuffs_SetOrientation

    debuffs.ShowDuration = I.Cooldowns_ShowDuration
    debuffs.ShowAnimation = I.Cooldowns_ShowAnimation
    debuffs.UpdatePixelPerfect = I.Cooldowns_UpdatePixelPerfect

    debuffs.ShowTooltip = Debuffs_ShowTooltip
    debuffs.EnableBlacklistShortcut = Debuffs_EnableBlacklistShortcut

    for i = 1, 10 do
        local name = parent:GetName().."Debuff"..i
        local frame = I.CreateAura_BarIcon(name, debuffs)
        tinsert(debuffs, frame)

        frame._SetCooldown = frame.SetCooldown
        function frame:SetCooldown(start, duration, debuffType, texture, count, refreshing, isBigDebuff)
            frame:_SetCooldown(start, duration, debuffType, texture, count, refreshing)
            if isBigDebuff then
                P.Size(frame, debuffs.bigSize[1], debuffs.bigSize[2])
            else
                P.Size(frame, debuffs.normalSize[1], debuffs.normalSize[2])
            end
        end
    end
end

-------------------------------------------------
-- CreateDispels
-------------------------------------------------
local function Dispels_SetSize(self, width, height)
    self.width = width
    self.height = height

    self:_SetSize(width, height)
    for i = 1, 5 do
        self[i]:SetSize(width, height)
    end

    if self._orientation then
        self:SetOrientation(self._orientation)
    else
        self:UpdateSize()
    end
end

local function Dispels_UpdateSize(self, iconsShown)
    if not (self.orientation and self.width and self.height) then return end

    local width, height = self.width, self.height
    if iconsShown then -- SetDispels
        if self.orientation == "horizontal"  then
            width = self.width + (iconsShown - 1) * floor(self.width / 2)
            height = self.height
        else
            width = self.width
            height = self.height + (iconsShown - 1) * floor(self.height / 2)
        end
    else
        for i = 1, 5 do
            if self[i]:IsShown() then
                if self.orientation == "horizontal"  then
                    width = self.width + (i - 1) * floor(self.width / 2)
                    height = self.height
                else
                    width = self.width
                    height = self.height + (i - 1) * floor(self.height / 2)
                end
            else
                break
            end
        end
    end

    self:_SetSize(width, height)
end

local dispelOrder = {"Magic", "Curse", "Disease", "Poison", "Bleed"}
local function Dispels_SetDispels(self, dispelTypes)
    local r, g, b = 0, 0, 0
    local found

    self.highlight:Hide()

    local i = 0
    for _, dispelType in ipairs(dispelOrder) do
        local showHighlight = dispelTypes[dispelType]
        if type(showHighlight) == "boolean" then
            -- highlight
            if not found and self.highlightType ~= "none" and dispelType and showHighlight then
                found = true
                local r, g, b = I.GetDebuffTypeColor(dispelType)
                if self.highlightType == "entire" then
                    self.highlight:SetTexture(Cell.vars.whiteTexture)
                    self.highlight:SetVertexColor(r, g, b, 0.5)
                elseif self.highlightType == "current" or self.highlightType == "current+" then
                    self.highlight:SetTexture(Cell.vars.texture)
                    self.highlight:SetVertexColor(r, g, b, 1)
                elseif self.highlightType == "gradient" or self.highlightType == "gradient-half" then
                    self.highlight:SetTexture(Cell.vars.whiteTexture)
                    --! WotLK fix: native SetGradientAlpha instead of the shimmed retail
                    --! two-colour SetGradient. This runs from UnitButton_UpdateDebuffs on
                    --! every UNIT_AURA, so two CreateColor tables per frame add up fast.
                    self.highlight:SetGradientAlpha("VERTICAL", r, g, b, 1, r, g, b, 0)
                end
                self.highlight:Show()
            end
            -- icons
            if self.showIcons then
                i = i + 1
                self[i]:SetDispel(dispelType)
            end
        end
    end

    self:UpdateSize(i)

    -- hide unused
    for j = i+1, 5 do
        self[j]:Hide()
    end
end

local function Dispels_SetDispel_Blizzard(self, dispelType)
    self:SetTexture("Interface\\AddOns\\Cell\\Media\\Debuffs\\"..dispelType)
    self:Show()
end

local function Dispels_SetDispel_Rhombus(self, dispelType)
    self:SetTexture("Interface\\AddOns\\Cell\\Media\\Debuffs\\Rhombus")
    self:SetVertexColor(I.GetDebuffTypeColor(dispelType))
    self:Show()
end

local function Dispels_SetIconStyle(self, style)
    self.showIcons = style ~= "none"
    for i = 1, 5 do
        if style == "rhombus" then
            self[i].SetDispel = Dispels_SetDispel_Rhombus
        else -- blizzard
            self[i].SetDispel = Dispels_SetDispel_Blizzard
            self[i]:SetVertexColor(1, 1, 1, 1)
        end
    end
end

--! SetSize must be invoked before this
local function Dispels_SetOrientation(self, orientation)
    self._orientation = orientation
    local point, x, y
    if orientation == "left-to-right" then
        point = "TOPLEFT"
        x = floor(self.width / 2)
        y = 0
        self.orientation = "horizontal"
    elseif orientation == "right-to-left" then
        point = "TOPRIGHT"
        x = -floor(self.width / 2)
        y = 0
        self.orientation = "horizontal"
    elseif orientation == "top-to-bottom" then
        point = "TOPLEFT"
        x = 0
        y = -floor(self.height / 2)
        self.orientation = "vertical"
    elseif orientation == "bottom-to-top" then
        point = "BOTTOMLEFT"
        x = 0
        y = floor(self.height / 2)
        self.orientation = "vertical"
    end

    for i = 1, 5 do
        self[i]:ClearAllPoints()
        if i == 1 then
            self[i]:SetPoint(point)
        else
            self[i]:SetPoint(point, self[i-1], point, x, y)
        end
    end

    self:UpdateSize()
end

local function Dispels_UpdateHighlight(self, highlightType)
    self.highlightType = highlightType
    self.highlight:SetBlendMode("BLEND")

    --! WotLK fix: upstream separates this highlight from the shield overlays with
    --! ARTWORK sublevels on midLevelFrame - 0 for the whole-bar modes (above the
    --! shield hatch at -5 and the over-shield glow at -4), -7 for the two modes that
    --! only cover current health (below both). The highlight is created later than
    --! the shield textures, so with sublevels ignored it always landed on top and
    --! "current"/"current+" painted over the shield hatch instead of under it -
    --! "current+" blends ADD, so it washed the hatch out. Real layers say the same
    --! thing without depending on sublevel support: ARTWORK keeps it above the
    --! shields by creation order, BORDER puts it strictly below them.
    if highlightType == "none" then
        self.highlight:Hide()
    elseif highlightType == "gradient" then
        -- self.highlight:SetParent(self.parent.widgets.indicatorFrame)
        self.highlight:ClearAllPoints()
        self.highlight:SetAllPoints(self.parent.widgets.healthBar)
        self.highlight:SetTexture(Cell.vars.whiteTexture)
        self.highlight:SetDrawLayer("ARTWORK")
    elseif highlightType == "gradient-half" then
        -- self.highlight:SetParent(self.parent.widgets.indicatorFrame)
        self.highlight:ClearAllPoints()
        self.highlight:SetPoint("BOTTOMLEFT", self.parent.widgets.healthBar)
        self.highlight:SetPoint("TOPRIGHT", self.parent.widgets.healthBar, "RIGHT")
        self.highlight:SetTexture(Cell.vars.whiteTexture)
        self.highlight:SetDrawLayer("ARTWORK")
    elseif highlightType == "entire" then
        -- self.highlight:SetParent(self.parent.widgets.indicatorFrame)
        self.highlight:ClearAllPoints()
        self.highlight:SetAllPoints(self.parent.widgets.healthBar)
        self.highlight:SetTexture(Cell.vars.whiteTexture)
        self.highlight:SetDrawLayer("ARTWORK")
    elseif highlightType == "current" then
        -- self.highlight:SetParent(self.parent.widgets.healthBar)
        self.highlight:ClearAllPoints()
        self.highlight:SetAllPoints(self.parent.widgets.healthBar:GetStatusBarTexture())
        self.highlight:SetTexture(Cell.vars.texture)
        self.highlight:SetDrawLayer("BORDER")
    elseif highlightType == "current+" then
        -- self.highlight:SetParent(self.parent.widgets.healthBar)
        self.highlight:ClearAllPoints()
        self.highlight:SetAllPoints(self.parent.widgets.healthBar:GetStatusBarTexture())
        self.highlight:SetTexture(Cell.vars.texture)
        self.highlight:SetDrawLayer("BORDER")
        self.highlight:SetBlendMode("ADD")
    end
end

function I.CreateDispels(parent)
    local dispels = CreateFrame("Frame", parent:GetName().."DispelParent", parent.widgets.indicatorFrame)
    parent.indicators.dispels = dispels
    dispels.parent = parent
    dispels:SetAllPoints(parent.widgets.healthBar)
    dispels:Hide()

    dispels:SetScript("OnHide", function()
        dispels.highlight:Hide()
    end)

    dispels.highlight = parent.widgets.midLevelFrame:CreateTexture(parent:GetName().."DispelHighlight")
    dispels.highlight:Hide()

    dispels._SetSize = dispels.SetSize
    dispels.SetSize = Dispels_SetSize
    dispels.UpdateSize = Dispels_UpdateSize
    dispels.SetDispels = Dispels_SetDispels
    dispels.UpdateHighlight = Dispels_UpdateHighlight
    dispels.SetIconStyle = Dispels_SetIconStyle
    dispels.SetOrientation = Dispels_SetOrientation

    --! WotLK fix: created back to front, 5 down to 1. The icons overlap each other by
    --! half (see Dispels_SetOrientation / Dispels_UpdateSize), and upstream orders them
    --! with ARTWORK sublevels 6-i, so the first dispel type - Magic, then Curse, see
    --! dispelOrder above - is meant to lie on top and the rest to peek out behind it.
    --! With sublevels ignored the draw order is the creation order, which put the LAST
    --! icon on top and left the most important one half covered. Building them in
    --! reverse makes the creation order carry the same intent; the SetDrawLayer call
    --! stays, so the order is right whether or not this client honours sublevels.
    --! The table itself is filled by index, so dispels[1..5] and # are unchanged.
    for i = 5, 1, -1 do
        local icon = dispels:CreateTexture(parent:GetName().."Dispel"..i, "ARTWORK")
        dispels[i] = icon
        icon:Hide()

        icon:SetDrawLayer("ARTWORK", 6-i)
        icon.SetDispel = Dispels_SetDispel_Blizzard
    end
end

-------------------------------------------------
-- CreateRaidDebuffs
-------------------------------------------------
local currentAreaDebuffs = {}
--! WotLK fix: имя зоны, под которое собран currentAreaDebuffs. Нужно затем, чтобы
--! ZONE_CHANGED_NEW_AREA (см. ниже) стоил одно сравнение строк, а не пересборку списка.
local currentAreaDebuffsZone
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
--! WotLK fix: PLAYER_ENTERING_WORLD в одиночку держит список ТОЛЬКО на входе. На выходе
--! из подземелья он приходит раньше, чем клиент забывает подземелье: измерено в прогоне
--! 2026-08-23 (audit/raw/run19.json, канал raiddebuffs) - PLAYER_LEAVING_WORLD 16:20:03,
--! PLAYER_ENTERING_WORLD 16:20:04, ZONE_CHANGED_NEW_AREA 16:20:05, и снимок в 16:20:06
--! показал в Даларане все 26 дебаффов Гундрака: пересборка была, но со старым именем, а
--! другого повода обновиться до следующей загрузочной ширмы у списка нет. Поэтому
--! подписываемся и на смену зоны. Событие не частое - кодекс 3.3.5a: "major zone change",
--! то есть вход/выход из инстанса и переход между большими зонами, подзоны идут отдельным
--! ZONE_CHANGED. Плюс мемо ниже: если зона та же, чем была, обработчик выходит сразу.
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

local function UpdateDebuffsForCurrentZone(instanceName)
    local iName = F.GetInstanceName()

    --! WotLK fix: upstream wipes the list BEFORE checking whose instance changed
    --! (Cell-retail/Indicators/Built-in.lua:765), so a RaidDebuffsChanged about any
    --! OTHER instance blanked the list for the zone you are standing in, and nothing
    --! rebuilds it until the next PLAYER_ENTERING_WORLD - the only other refresh point.
    --! Easy to hit: opening Options -> Raid Debuffs selects the FIRST instance of the
    --! expansion, not the one you are in (ShowInstances ends with instanceButtons[1]:Click()),
    --! so one click on a debuff there killed the whole RaidDebuffs indicator mid-raid:
    --! with an empty list I.GetDebuffOrder returns nil for every aura, so nothing is
    --! inserted into debuffsRaid at all. Same for an imported/shared list from another
    --! player. Ignore events about other instances; nil still means "refresh anyway".
    if instanceName ~= nil and instanceName ~= iName then
        --! WotLK fix: the two names come from different sources and need not be equal
        --! even for the SAME instance. The event carries instanceIdToName, i.e. the name
        --! from the ExpansionData payload, while F.GetInstanceName returns whatever the
        --! CLIENT calls the zone. On esMX there is no localized payload at all (only
        --! ExpansionData_esMX aliases), so the event says "Icecrown Citadel" while the
        --! zone says "Ciudadela de la Corona de Hielo"; on the locales that do replace
        --! the payload it is a retail Encounter Journal name against a 3.3.5 zone name.
        --! A raw string compare would ignore every edit for the instance you stand in.
        --! Resolve both through instanceNameMapping instead - F.GetInstanceAndBossId is
        --! the public, alias-aware way to do it - and compare instance ids.
        local eventId = F.GetInstanceAndBossId and F.GetInstanceAndBossId(instanceName)
        local zoneId = F.GetInstanceAndBossId and F.GetInstanceAndBossId(iName)
        --! Both nil means neither name is known to the module: the rebuild below yields
        --! an empty list, which is exactly right for a zone without built-in debuffs.
        if eventId ~= zoneId then return end
    end

    if iName == "" then
        wipe(currentAreaDebuffs)
        currentAreaDebuffsZone = iName
        return
    end

    currentAreaDebuffs = F.GetDebuffList(iName)
    currentAreaDebuffsZone = iName
    F.Debug("|cffff77AARaidDebuffsChanged:|r", iName)
end
Cell.RegisterCallback("RaidDebuffsChanged", "UpdateDebuffsForCurrentZone", UpdateDebuffsForCurrentZone)
eventFrame:SetScript("OnEvent", function(_, event)
    --! WotLK fix: на PLAYER_ENTERING_WORLD пересобираем всегда - это загрузочная ширма,
    --! и данные за ней могли поменяться. На смене зоны сначала сравниваем имя: в открытом
    --! мире список почти всегда пустой и уже собран под эту зону, так что обычная цена
    --! события - два C-вызова внутри F.GetInstanceName и одно сравнение строк. Мемо не
    --! мешает правкам из настроек: путь RaidDebuffsChanged идёт мимо этой проверки.
    if event == "ZONE_CHANGED_NEW_AREA" and F.GetInstanceName() == currentAreaDebuffsZone then
        return
    end
    UpdateDebuffsForCurrentZone()
end)

--! WotLK fix: currentAreaDebuffs is a file local, so nothing outside could tell whether
--! the ACTIVE list survived an options edit - the bug above was invisible in game except
--! as "the indicator just stopped". Expose it read-only for /cell debug raiddebuffs.
function I.GetCurrentAreaDebuffs()
    return currentAreaDebuffs
end

local function CheckCondition(operator, checkedValue, currentValue)
    if operator == "=" then
        if currentValue == checkedValue then return true end
    elseif operator == ">" then
        if currentValue > checkedValue then return true end
    elseif operator == ">=" then
        if currentValue >= checkedValue then return true end
    elseif operator == "<" then
        if currentValue < checkedValue then return true end
    elseif operator == "<=" then
        if currentValue <= checkedValue then return true end
    else -- ~=
        if currentValue ~= checkedValue then return true end
    end
end

function I.GetDebuffOrder(spellName, spellId, count)
    local t = currentAreaDebuffs[spellId] or currentAreaDebuffs[spellName]
    if not t then return end

    -- check condition
    local show
    if t["condition"][1] == "Stack" then
        show = CheckCondition(t["condition"][2], t["condition"][3], count)
    else -- no condition
        show = true
    end

    if show then return t["order"] end
end

function I.GetDebuffGlow(spellName, spellId, count)
    local t = currentAreaDebuffs[spellId] or currentAreaDebuffs[spellName]
    if not t then return end

    local showGlow
    if t["glowCondition"] then
        if t["glowCondition"][1] == "Stack" then
            showGlow = CheckCondition(t["glowCondition"][2], t["glowCondition"][3], count)
        end
    else
        showGlow = true
    end

    if showGlow then
        return t["glowType"], t["glowOptions"]
    else
        return "None", nil
    end
end

function I.IsDebuffUseElapsedTime(spellName, spellId)
    local t = currentAreaDebuffs[spellId] or currentAreaDebuffs[spellName]
    if not t then return end

    return t["useElapsedTime"]
end

local function RaidDebuffs_ShowGlow(self, glowType, glowOptions, noHiding)
    if glowType == "Normal" then
        if not noHiding then
            LCG.PixelGlow_Stop(self.parent)
            LCG.AutoCastGlow_Stop(self.parent)
            LCG.ProcGlow_Stop(self.parent)
        end
        LCG.ButtonGlow_Start(self.parent, glowOptions[1])
    elseif glowType == "Pixel" then
        if not noHiding then
            LCG.ButtonGlow_Stop(self.parent)
            LCG.AutoCastGlow_Stop(self.parent)
            LCG.ProcGlow_Stop(self.parent)
        end
        -- color, N, frequency, length, thickness
        LCG.PixelGlow_Start(self.parent, glowOptions[1], glowOptions[2], glowOptions[3], glowOptions[4], glowOptions[5])
    elseif glowType == "Shine" then
        if not noHiding then
            LCG.ButtonGlow_Stop(self.parent)
            LCG.PixelGlow_Stop(self.parent)
            LCG.ProcGlow_Stop(self.parent)
        end
        -- color, N, frequency, scale
        LCG.AutoCastGlow_Start(self.parent, glowOptions[1], glowOptions[2], glowOptions[3], glowOptions[4])
    elseif glowType == "Proc" then
        if not noHiding then
            LCG.ButtonGlow_Stop(self.parent)
            LCG.PixelGlow_Stop(self.parent)
            LCG.AutoCastGlow_Stop(self.parent)
        end
        -- color, duration
        LCG.ProcGlow_Start(self.parent, {color=glowOptions[1], duration=glowOptions[2], startAnim=false})
    else
        LCG.ButtonGlow_Stop(self.parent)
        LCG.PixelGlow_Stop(self.parent)
        LCG.AutoCastGlow_Stop(self.parent)
        LCG.ProcGlow_Stop(self.parent)
    end
end

local hiders = {
    ["Normal"] = LCG.ButtonGlow_Stop,
    ["Pixel"] = LCG.PixelGlow_Stop,
    ["Shine"] = LCG.AutoCastGlow_Stop,
    ["Proc"] = LCG.ProcGlow_Stop,
}

local function RaidDebuffs_HideGlow(self, glowType)
    if not glowType then
        for _, stop in pairs(hiders) do
            stop(self.parent)
        end
    else
        hiders[glowType](self.parent)
    end
end

local function RaidDebuffs_ShowTooltip(raidDebuffs, show)
    for i = 1, 3 do
        if show then
            raidDebuffs[i]:SetScript("OnEnter", function(self)
                --! WotLK fix: same dead retail branch as in Debuffs_ShowTooltip -
                --! .auraInstanceID is never set on 3.3.5, the icon carries .index.
                if self.index then
                    F.ShowTooltips(raidDebuffs.parent, "spell", raidDebuffs.parent.states.displayedUnit, self.index, "HARMFUL")
                end
            end)
            raidDebuffs[i]:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            raidDebuffs[i]:SetScript("OnEnter", nil)
            raidDebuffs[i]:SetScript("OnLeave", nil)
            raidDebuffs[i]:EnableMouse(false)
        end
    end
end

function I.CreateRaidDebuffs(parent)
    local raidDebuffs = CreateFrame("Frame", parent:GetName().."RaidDebuffParent", parent.widgets.indicatorFrame)
    parent.indicators.raidDebuffs = raidDebuffs
    raidDebuffs:Hide()
    raidDebuffs.parent = parent

    hooksecurefunc(raidDebuffs, "Hide", RaidDebuffs_HideGlow)
    -- raidDebuffs:SetScript("OnHide", RaidDebuffs_HideGlow)

    raidDebuffs._SetSize = raidDebuffs.SetSize
    raidDebuffs.SetSize = I.Cooldowns_SetSize
    raidDebuffs.SetBorder = I.Cooldowns_SetBorder
    raidDebuffs.UpdateSize = I.Cooldowns_UpdateSize_WithSpacing
    raidDebuffs.ShowDuration = I.Cooldowns_ShowDuration
    raidDebuffs.SetOrientation = I.Cooldowns_SetOrientation_WithSpacing
    raidDebuffs.SetFont = I.Cooldowns_SetFont
    raidDebuffs.ShowGlow = RaidDebuffs_ShowGlow
    raidDebuffs.HideGlow = RaidDebuffs_HideGlow
    raidDebuffs.UpdatePixelPerfect = I.Cooldowns_UpdatePixelPerfect

    raidDebuffs.ShowTooltip = RaidDebuffs_ShowTooltip

    for i = 1, 3 do
        local frame = I.CreateAura_BorderIcon(parent:GetName().."RaidDebuff"..i, raidDebuffs, 2)
        tinsert(raidDebuffs, frame)
        -- frame:SetScript("OnShow", raidDebuffs.UpdateSize)
        -- frame:SetScript("OnHide", raidDebuffs.UpdateSize)
    end
end

-------------------------------------------------
-- player raid icon
-------------------------------------------------
function I.CreatePlayerRaidIcon(parent)
    -- local playerRaidIcon = parent.widgets.indicatorFrame:CreateTexture(parent:GetName().."PlayerRaidIcon", "ARTWORK", nil, -7)
    -- parent.indicators.playerRaidIcon = playerRaidIcon
    -- playerRaidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    local playerRaidIcon = CreateFrame("Frame", parent:GetName().."PlayerRaidIcon", parent.widgets.indicatorFrame)
    parent.indicators.playerRaidIcon = playerRaidIcon
    playerRaidIcon.tex = playerRaidIcon:CreateTexture(nil, "ARTWORK")
    playerRaidIcon.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    playerRaidIcon.tex:SetAllPoints(playerRaidIcon)
    playerRaidIcon:Hide()
end

-------------------------------------------------
-- target raid icon
-------------------------------------------------
function I.CreateTargetRaidIcon(parent)
    local targetRaidIcon = CreateFrame("Frame", parent:GetName().."TargetRaidIcon", parent.widgets.indicatorFrame)
    parent.indicators.targetRaidIcon = targetRaidIcon
    targetRaidIcon.tex = targetRaidIcon:CreateTexture(nil, "ARTWORK")
    targetRaidIcon.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    targetRaidIcon.tex:SetAllPoints(targetRaidIcon)
    targetRaidIcon:Hide()
end

-------------------------------------------------
-- name text
-------------------------------------------------
local font_name = CreateFont("CELL_FONT_NAME")
font_name:SetFont(GameFontNormal:GetFont(), 13, "")
--! NOTE: VERY IMPORTANT, if not set, shadows will DISAPPER when wow window size changed
font_name:SetTextColor(1, 1, 1, 1)
font_name:SetShadowColor(0, 0, 0)
font_name:SetShadowOffset(1, -1)

local font_status = CreateFont("CELL_FONT_STATUS")
font_status:SetFont(GameFontNormal:GetFont(), 11, "")
--! NOTE: VERY IMPORTANT, if not set, shadows will DISAPPER when wow window size changed
font_status:SetTextColor(1, 1, 1, 1)
font_status:SetShadowColor(0, 0, 0)
font_status:SetShadowOffset(1, -1)

function I.CreateNameText(parent)
    local nameText = CreateFrame("Frame", parent:GetName().."NameText", parent.widgets.indicatorFrame)
    parent.indicators.nameText = nameText
    nameText:Hide()

    nameText.name = nameText:CreateFontString(parent:GetName().."NameText_Name", "OVERLAY", "CELL_FONT_NAME")

    nameText.vehicle = nameText:CreateFontString(parent:GetName().."NameText_Vehicle", "OVERLAY", "CELL_FONT_STATUS")
    nameText.vehicle:SetTextColor(0.8, 0.8, 0.8, 1)
    nameText.vehicle:Hide()

    nameText:SetScript("OnShow", function()
        if nameText.vehicleEnabled then
            nameText.vehicle:Show()
        end
    end)
    nameText:SetScript("OnHide", function()
        nameText.vehicle:Hide()
    end)

    function nameText:SetFont(font, size, outline, shadow)
        font = F.GetFont(font)

        local flags
        if outline == "None" then
            flags = ""
        elseif outline == "Outline" then
            flags = "OUTLINE"
        else
            flags = "OUTLINE,MONOCHROME"
        end

        nameText.name:SetFont(font, size, flags)
        nameText.vehicle:SetFont(font, size-2, flags)

        if shadow then
            nameText.name:SetShadowOffset(1, -1)
            nameText.name:SetShadowColor(0, 0, 0, 1)
            nameText.vehicle:SetShadowOffset(1, -1)
            nameText.vehicle:SetShadowColor(0, 0, 0, 1)
        else
            nameText.name:SetShadowOffset(0, 0)
            nameText.name:SetShadowColor(0, 0, 0, 0)
            nameText.vehicle:SetShadowOffset(0, 0)
            nameText.vehicle:SetShadowColor(0, 0, 0, 0)
        end
        nameText.shadow = shadow

        nameText:UpdateName()
        if parent.states.inVehicle or nameText.isPreview then
            nameText:UpdateVehicleName()
        end
    end

    nameText._SetPoint = nameText.SetPoint
    function nameText:SetPoint(point, relativeTo, relativePoint, x, y)
        -- override relativeTo
        nameText:_SetPoint(point, relativeTo, relativePoint, x, y)

        -- update name
        nameText.name:ClearAllPoints()
        nameText.name:SetPoint(point)

        -- update vehicle
        local vp, _, vrp, _, vy = nameText.vehicle:GetPoint(1)
        if vp and vrp and vy then
            if string.find(vp, "TOP") then
                vp, vrp = "TOP", "BOTTOM"
            else -- BOTTOM
                vp, vrp = "BOTTOM", "TOP"
            end

            nameText.vehicle:ClearAllPoints()
            if string.find(point, "LEFT") then
                nameText.vehicle:SetPoint(vp.."LEFT", nameText.name, vrp.."LEFT", 0, vy)
            elseif string.find(point, "RIGHT") then
                nameText.vehicle:SetPoint(vp.."RIGHT", nameText.name, vrp.."RIGHT", 0, vy)
            else -- "CENTER"
                nameText.vehicle:SetPoint(vp, nameText.name, vrp, 0, vy)
            end
        end
    end

    function nameText:UpdateName()
        local name

        -- supporter rainbow
        -- if nameText.name.rainbow then
        --     nameText.name.updater:SetScript("OnUpdate", nil)
        --     if nameText.name.timer then
        --         nameText.name.timer:Cancel()
        --         nameText.name.timer = nil
        --     end
        -- end

        -- only check nickname for players
        if parent.states.isPlayer then
            if CELL_NICKTAG_ENABLED and Cell.NickTag then
                name = Cell.NickTag:GetNickname(parent.states.name, nil, true)
            end
            name = name or F.GetNickname(parent.states.name, parent.states.fullName)
        else
            name = parent.states.name
        end

        if Cell.loaded and CellDB["general"]["translit"] then
            name = LibTranslit:Transliterate(name)
        end

        F.UpdateTextWidth(nameText.name, name, nameText.width, parent.widgets.healthBar)

        if CELL_SHOW_GROUP_PET_OWNER_NAME and parent.isGroupPet then
            local owner = F.GetPlayerUnit(parent.states.unit)
            owner = UnitName(owner)
            if CELL_SHOW_GROUP_PET_OWNER_NAME == "VEHICLE" then
                F.UpdateTextWidth(nameText.vehicle, owner, nameText.width, parent.widgets.healthBar)
            elseif CELL_SHOW_GROUP_PET_OWNER_NAME == "NAME" then
                F.UpdateTextWidth(nameText.name, owner, nameText.width, parent.widgets.healthBar)
            end
        end

        if nameText.name:GetText() then
            if nameText.isPreview then
                if nameText.showGroupNumber then
                    nameText.name:SetText("|cffbbbbbb7-|r"..nameText.name:GetText())
                end
            else
                if IsInRaid() and nameText.showGroupNumber then
                    local raidIndex = UnitInRaid(parent.states.unit)
                    if raidIndex then
                        --! WotLK fix: UnitInRaid is 0-based on 3.3.5 (raid1 -> 0), so
                        --! GetRaidRosterInfo needs +1. Without it raid1 returned nil
                        --! (error on concat) and everyone else got the previous
                        --! player's subgroup number.
                        local subgroup = select(3, GetRaidRosterInfo(raidIndex + 1))
                        if subgroup then
                            nameText.name:SetText("|cffbbbbbb"..subgroup.."-|r"..nameText.name:GetText())
                        end
                    end
                end
            end
        end

        nameText:SetSize(nameText.name:GetWidth(), nameText.name:GetHeight())
    end

    function nameText:UpdateVehicleName()
        F.UpdateTextWidth(nameText.vehicle, nameText.isPreview and L["vehicle name"] or UnitName(parent.states.displayedUnit), nameText.width, parent.widgets.healthBar)
    end

    function nameText:UpdateVehicleNamePosition(pTable)
        local p = nameText:GetPoint(1) or ""
        if string.find(p, "LEFT") then
            p = "LEFT"
        elseif string.find(p, "RIGHT") then
            p = "RIGHT"
        else -- "CENTER"
            p = ""
        end

        nameText.vehicle:ClearAllPoints()
        if pTable[1] == "TOP" then
            nameText.vehicle:Show()
            nameText.vehicle:SetPoint("BOTTOM"..p, nameText.name, "TOP"..p, 0, pTable[2])
            nameText.vehicleEnabled = true
        elseif pTable[1] == "BOTTOM" then
            nameText.vehicle:Show()
            nameText.vehicle:SetPoint("TOP"..p, nameText.name, "BOTTOM"..p, 0, pTable[2])
            nameText.vehicleEnabled = true
        else -- Hide
            nameText.vehicle:Hide()
            nameText.vehicleEnabled = false
        end
    end

    function nameText:UpdateTextWidth(width)
        nameText.width = width

        nameText:UpdateName()

        if parent.states.inVehicle or nameText.isPreview then
            --! WotLK fix: та же заглушка предпросмотра, что и в UpdateVehicleName выше,
            --! но ключ был другой ("Vehicle Name" вместо "vehicle name"). Переведён
            --! в локалях только строчный вариант, поэтому в режиме предпросмотра
            --! одна и та же подпись показывалась то по-русски, то по-английски —
            --! в зависимости от того, какая из двух функций обновила ширину последней.
            --! Апстрим-баг (Cell-retail/Indicators/Built-in.lua:1231).
            F.UpdateTextWidth(nameText.vehicle, nameText.isPreview and L["vehicle name"] or UnitName(parent.states.displayedUnit), width, parent.widgets.healthBar)
        end
    end

    function nameText:UpdatePreviewColor(color)
        if color[1] == "class_color" then
            nameText.name:SetTextColor(F.GetClassColor(Cell.vars.playerClass))
        else
            nameText.name:SetTextColor(unpack(color[2]))
        end
    end

    function nameText:SetColor(r, g, b)
        nameText.name:SetTextColor(r, g, b)
    end

    function nameText:ShowGroupNumber(show)
        nameText.showGroupNumber = show
        nameText:UpdateName()
    end

    parent.widgets.healthBar:SetScript("OnSizeChanged", function()
        if parent.states.name then
            nameText:UpdateName()

            if parent.states.inVehicle or nameText.isPreview then
                nameText:UpdateVehicleName()
            end
        end
    end)
end

-------------------------------------------------
-- status text
-------------------------------------------------
local function StatusText_SetFont(self, font, size, outline, shadow)
    font = F.GetFont(font)

    local flags
    if outline == "None" then
        flags = ""
    elseif outline == "Outline" then
        flags = "OUTLINE"
    else
        flags = "OUTLINE,MONOCHROME"
    end

    self.text:SetFont(font, size, flags)
    self.timer:SetFont(font, size, flags)

    if shadow then
        self.text:SetShadowOffset(1, -1)
        self.text:SetShadowColor(0, 0, 0, 1)
        self.timer:SetShadowOffset(1, -1)
        self.timer:SetShadowColor(0, 0, 0, 1)
    else
        self.text:SetShadowOffset(0, 0)
        self.text:SetShadowColor(0, 0, 0, 0)
        self.timer:SetShadowOffset(0, 0)
        self.timer:SetShadowColor(0, 0, 0, 0)
    end
    self.shadow = shadow

    self:SetHeight(self.text:GetHeight()+P.Scale(1)*2)
end

local function StatusText_GetStatus(self)
    return self.status
end

local function StatusText_SetStatus(self, status)
    -- print("status: " .. (status or "nil"))
    self.status = status
    if status and self.colors then
        self.text:SetText(L[status])
        self.text:SetTextColor(unpack(self.colors[status]))
        self.timer:SetTextColor(unpack(self.colors[status]))
        self:SetHeight(self.text:GetHeight()+P.Scale(1)*2)
    else
        self:Hide()
    end
end

local function StatusText_SetColors(self, colors)
    self.colors = colors
end

local function StatusText_SetShowTimer(self, show)
    self.showTimer = show
end

local function StatusText_ShowBackground(self, show)
    if show then
        self.bg:Show()
    else
        self.bg:Hide()
    end
end

local function StatusText_SetPosition(self, point, yOffset, justify)
    self:ClearAllPoints()
    self:SetPoint("LEFT", self.parent.widgets.healthBar)
    self:SetPoint("RIGHT", self.parent.widgets.healthBar)
    self:SetPoint(point, self.parent.widgets.healthBar, 0, P.Scale(yOffset))

    self.text:ClearAllPoints()
    self.timer:ClearAllPoints()
    if justify == "justify" then
        self.text:SetPoint("LEFT")
        self.text:SetJustifyH("LEFT")
        self.timer:SetPoint("RIGHT")
        self.timer:SetJustifyH("RIGHT")
        --! WotLK fix: native Texture:SetGradientAlpha - the retail color-object form
        --! SetGradient(orientation, color, color) does not exist on 3.3.5.
        self.bg:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0.777, 0, 0, 0, 0)
    elseif justify == "left" then
        self.text:SetPoint("LEFT")
        self.text:SetJustifyH("LEFT")
        self.timer:SetPoint("LEFT", self.text, "RIGHT", 2, 0)
        self.timer:SetJustifyH("LEFT")
        self.bg:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0.777, 0, 0, 0, 0)
    else
        self.text:SetPoint("RIGHT")
        self.text:SetJustifyH("RIGHT")
        self.timer:SetPoint("RIGHT", self.text, "LEFT", -2, 0)
        self.timer:SetJustifyH("RIGHT")
        self.bg:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.777)
    end

    self:SetHeight(self.text:GetHeight()+P.Scale(1)*2)
end

local startTimeCache = {}
local function StatusText_ShowTimer(self)
    if not self.showTimer then
        self:HideTimer(true)
        return
    end

    self.timer:Show()

    if not startTimeCache[self.parent.states.guid] then startTimeCache[self.parent.states.guid] = GetTime() end

    self.ticker = C_Timer.NewTicker(1, function()
        if not self.parent.states.guid and self.parent.states.unit then -- ElvUI AFK mode
            self.parent.states.guid = UnitGUID(self.parent.states.unit)
        end
        if self.parent.states.guid and startTimeCache[self.parent.states.guid] then
            self.timer:SetFormattedText(F.FormatTime(GetTime() - startTimeCache[self.parent.states.guid]))
        else
            self.timer:SetText("")
        end
    end)
end

local function StatusText_HideTimer(self, reset)
    self.timer:Hide()
    self.timer:SetText("")
    if reset then
        if self.ticker then self.ticker:Cancel() end
        startTimeCache[self.parent.states.guid] = nil
    end
end

function I.CreateStatusText(parent)
    local statusText = CreateFrame("Frame", parent:GetName().."StatusText", parent.widgets.indicatorFrame)
    parent.indicators.statusText = statusText
    --! WotLK fix: parent-alpha isolation is unavailable on 3.3.5; do not call
    --! a state-only shared compatibility method that cannot affect rendering.
    statusText:Hide()

    statusText.parent = parent

    statusText.bg = statusText:CreateTexture(nil, "ARTWORK")
    statusText.bg:SetTexture(Cell.vars.whiteTexture)
    -- statusText.bg:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.777), CreateColor(0, 0, 0, 0))
    statusText.bg:SetAllPoints(statusText)

    local text = statusText:CreateFontString(nil, "ARTWORK", "CELL_FONT_STATUS")
    statusText.text = text

    local timer = statusText:CreateFontString(nil, "ARTWORK", "CELL_FONT_STATUS")
    statusText.timer = timer

    statusText.GetStatus = StatusText_GetStatus
    statusText.SetStatus = StatusText_SetStatus
    statusText.SetColors = StatusText_SetColors
    statusText.SetPosition = StatusText_SetPosition
    statusText.SetFont = StatusText_SetFont
    statusText.SetShowTimer = StatusText_SetShowTimer
    statusText.ShowBackground = StatusText_ShowBackground
    statusText.ShowTimer = StatusText_ShowTimer
    statusText.HideTimer = StatusText_HideTimer
end

-------------------------------------------------
-- health text
-------------------------------------------------
local sub = string.sub
local gsub = string.gsub
local find = string.find
local format = string.format
local tinsert = table.insert

local formatter = {
    ["none"] = function()
        return ""
    end,

    -- health
    ["health"] = function(pattern, hideIfEmptyOrFull, health, maxHealth, absorbs, healAbsorbs)
        if hideIfEmptyOrFull and (health == 0 or health == maxHealth) then return "" end
        return pattern:format(health)
    end,
    ["health_short"] = function(pattern, hideIfEmptyOrFull, health, maxHealth, absorbs, healAbsorbs)
        if hideIfEmptyOrFull and (health == 0 or health == maxHealth) then return "" end
        return pattern:format(F.FormatNumber(health))
    end,
    ["health_percent"] = function(pattern, hideIfEmptyOrFull, health, maxHealth, absorbs, healAbsorbs)
        if hideIfEmptyOrFull and (health == 0 or health == maxHealth) then return "" end
        return pattern:format(F.Round(health / maxHealth * 100))
    end,
    ["deficit"] = function(pattern, hideIfEmptyOrFull, health, maxHealth, absorbs, healAbsorbs)
        if hideIfEmptyOrFull and (health == 0 or health == maxHealth) then return "" end
        return pattern:format(health - maxHealth)
    end,
    ["deficit_short"] = function(pattern, hideIfEmptyOrFull, health, maxHealth, absorbs, healAbsorbs)
        if hideIfEmptyOrFull and (health == 0 or health == maxHealth) then return "" end
        return pattern:format(F.FormatNumber(health - maxHealth))
    end,
    ["deficit_percent"] = function(pattern, hideIfEmptyOrFull, health, maxHealth, absorbs, healAbsorbs)
        if hideIfEmptyOrFull and (health == 0 or health == maxHealth) then return "" end
        return pattern:format(F.Round((health - maxHealth) / maxHealth * 100))
    end,

    -- effective health
    ["effective"] = function(pattern, hideIfEmptyOrFull, health, maxHealth, absorbs, healAbsorbs)
        if hideIfEmptyOrFull and (health == 0 or health == maxHealth) and absorbs == 0 and healAbsorbs == 0 then return "" end
        return pattern:format(health + absorbs - healAbsorbs)
    end,
    ["effective_short"] = function(pattern, hideIfEmptyOrFull, health, maxHealth, absorbs, healAbsorbs)
        if hideIfEmptyOrFull and (health == 0 or health == maxHealth) and absorbs == 0 and healAbsorbs == 0 then return "" end
        return pattern:format(F.FormatNumber(health + absorbs - healAbsorbs))
    end,
    ["effective_percent"] = function(pattern, hideIfEmptyOrFull, health, maxHealth, absorbs, healAbsorbs)
        if hideIfEmptyOrFull and (health == 0 or health == maxHealth) and absorbs == 0 and healAbsorbs == 0 then return "" end
        return pattern:format(F.Round((health + absorbs - healAbsorbs) / maxHealth * 100))
    end,

    -- shields
    ["shields"] = function(pattern, health, maxHealth, absorbs, healAbsorbs)
        if absorbs == 0 then return "" end
        return pattern:format(absorbs)
    end,
    ["shields_short"] = function(pattern, health, maxHealth, absorbs, healAbsorbs)
        if absorbs == 0 then return "" end
        return pattern:format(F.FormatNumber(absorbs))
    end,
    ["shields_percent"] = function(pattern, health, maxHealth, absorbs, healAbsorbs)
        if absorbs == 0 then return "" end
        return pattern:format(F.Round(absorbs / maxHealth * 100))
    end,

    -- heal absorbs
    ["healabsorbs"] = function(pattern, health, maxHealth, absorbs, healAbsorbs)
        if healAbsorbs == 0 then return "" end
        return pattern:format(healAbsorbs)
    end,
    ["healabsorbs_short"] = function(pattern, health, maxHealth, absorbs, healAbsorbs)
        if healAbsorbs == 0 then return "" end
        return pattern:format(F.FormatNumber(healAbsorbs))
    end,
    ["healabsorbs_percent"] = function(pattern, health, maxHealth, absorbs, healAbsorbs)
        if healAbsorbs == 0 then return "" end
        return pattern:format(F.Round(healAbsorbs / maxHealth * 100))
    end,
}

local function BuildPattern(config)
    if config.format == "none" then
        return ""
    end

    local prefix
    if config.delimiter == nil then
        prefix = ""
    else
        --! WotLK fix: the delimiter is free text from an EditBox
        --! (Widgets_IndicatorSettings.lua:1261/1328/1390 take GetText() with no
        --! filtering, only SetMaxLetters(5)) and it is concatenated straight into
        --! the pattern that the formatter functions below feed to string.format
        --! with exactly ONE argument. Any '%' the player types therefore lands in
        --! the format string: "50%" gives "invalid option '%|' to 'format'" (the
        --! '|r' that follows becomes the conversion), "%s" and "%d" give
        --! "bad argument #3 to 'format' (no value)" - all three verified under
        --! Lua 5.1. Unlike the /cell report case in Core_Wrath.lua this fires from
        --! HealthText_SetValue, i.e. on every health update of every visible unit,
        --! so the health text dies and the error repeats without end. Escaping is
        --! what the suffix below already does; the player still sees the exact
        --! character typed, because "%%" formats as a literal '%'.
        prefix = "|cffababab" .. gsub(config.delimiter, "%%", "%%%%") .. "|r"
    end

    local suffix = config.format:find("percent$") and "%%" or ""

    if config.color[1] == "class_color" then
        return prefix .. "%s" .. suffix
    else
        return prefix .. "|cff" .. F.ConvertRGBToHEX(F.ConvertRGB_256(unpack(config.color[2]))) .. "%s" .. suffix .. "|r"
    end
end

local function HealthText_SetFormat(self, format)
    self.GetHealth1 = formatter[format.health1.format:gsub("_no_sign$", "")]
    self.GetHealth2 = formatter[format.health2.format:gsub("_no_sign$", "")]
    self.GetShields = formatter[format.shields.format:gsub("_no_sign$", "")]
    self.GetHealAbsorbs = formatter[format.healAbsorbs.format:gsub("_no_sign$", "")]

    self.health1 = BuildPattern(format.health1)
    self.health1_hideIfEmptyOrFull = format.health1.hideIfEmptyOrFull
    self.health2 = BuildPattern(format.health2)
    self.health2_hideIfEmptyOrFull = format.health2.hideIfEmptyOrFull
    self.shields = BuildPattern(format.shields)
    self.healAbsorbs = BuildPattern(format.healAbsorbs)
end

local function HealthText_SetValue(self, health, maxHealth, shields, healAbsorbs)
    maxHealth = maxHealth == 0 and 1 or maxHealth

    self.text:SetFormattedText("%s%s%s%s",
        self.GetHealth1(self.health1, self.health1_hideIfEmptyOrFull, health, maxHealth, shields, healAbsorbs),
        self.GetHealth2(self.health2, self.health2_hideIfEmptyOrFull, health, maxHealth, shields, healAbsorbs),
        self.GetShields(self.shields, health, maxHealth, shields, healAbsorbs),
        self.GetHealAbsorbs(self.healAbsorbs, health, maxHealth, shields, healAbsorbs))
    self:SetWidth(self.text:GetStringWidth())
end

local function HealthText_SetFont(self, font, size, outline, shadow)
    font = F.GetFont(font)

    local flags
    if outline == "None" then
        flags = ""
    elseif outline == "Outline" then
        flags = "OUTLINE"
    else
        flags = "OUTLINE,MONOCHROME"
    end

    self.text:SetFont(font, size, flags)

    if shadow then
        self.text:SetShadowOffset(1, -1)
        self.text:SetShadowColor(0, 0, 0, 1)
    else
        self.text:SetShadowOffset(0, 0)
        self.text:SetShadowColor(0, 0, 0, 0)
    end

    self:SetSize(self.text:GetStringWidth(), size)
end

local function HealthText_SetPoint(self, point, relativeTo, relativePoint, x, y)
    self.text:ClearAllPoints()
    if string.find(point, "LEFT$") then
        self.text:SetPoint("LEFT")
    elseif string.find(point, "RIGHT$") then
        self.text:SetPoint("RIGHT")
    else
        self.text:SetPoint("CENTER")
    end
    self:_SetPoint(point, relativeTo, relativePoint, x, y)
    I.JustifyText(self.text, point)
end

local function HealthText_SetColor(self, r, g, b)
    self.text:SetTextColor(r, g, b)
end

local function HealthText_UpdatePreviewColor(self, color)
    -- if color[1] == "class_color" then
        self.text:SetTextColor(F.GetClassColor(Cell.vars.playerClass))
    -- else
    --     self.text:SetTextColor(unpack(color[2]))
    -- end
end

function I.CreateHealthText(parent)
    local healthText = CreateFrame("Frame", parent:GetName().."HealthText", parent.widgets.indicatorFrame)
    parent.indicators.healthText = healthText
    healthText:Hide()

    local text = healthText:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    healthText.text = text

    healthText.GetHealth1 = formatter.none
    healthText.GetHealth2 = formatter.none
    healthText.GetShields = formatter.none
    healthText.GetHealAbsorbs = formatter.none

    healthText.SetFont = HealthText_SetFont
    healthText._SetPoint = healthText.SetPoint
    healthText.SetPoint = HealthText_SetPoint
    healthText.SetFormat = HealthText_SetFormat
    healthText.SetValue = HealthText_SetValue
    healthText.SetColor = HealthText_SetColor
    healthText.UpdatePreviewColor = HealthText_UpdatePreviewColor
end

-------------------------------------------------
-- power text
-------------------------------------------------
local function SetPower_Percentage(self, current, max)
    if self.hideIfEmptyOrFull and (current == 0 or current == max) then
        self:Hide()
    else
        self.text:SetFormattedText("%d%%", current/max*100)
        self:SetWidth(self.text:GetStringWidth())
        self:Show()
    end
end

local function SetPower_Number(self, current, max)
    if self.hideIfEmptyOrFull and (current == 0 or current == max) then
        self:Hide()
    else
        self.text:SetText(current)
        self:SetWidth(self.text:GetStringWidth())
        self:Show()
    end
end

local function SetPower_Number_Short(self, current, max)
    if self.hideIfEmptyOrFull and (current == 0 or current == max) then
        self:Hide()
    else
        self.text:SetText(F.FormatNumber(current))
        self:SetWidth(self.text:GetStringWidth())
        self:Show()
    end
end

local function PowerText_SetFont(self, font, size, outline, shadow)
    font = F.GetFont(font)

    local flags
    if outline == "None" then
        flags = ""
    elseif outline == "Outline" then
        flags = "OUTLINE"
    else
        flags = "OUTLINE,MONOCHROME"
    end

    self.text:SetFont(font, size, flags)

    if shadow then
        self.text:SetShadowOffset(1, -1)
        self.text:SetShadowColor(0, 0, 0, 1)
    else
        self.text:SetShadowOffset(0, 0)
        self.text:SetShadowColor(0, 0, 0, 0)
    end

    self:SetSize(self.text:GetStringWidth(), size)
end

local function PowerText_SetPoint(self, point, relativeTo, relativePoint, x, y)
    self.text:ClearAllPoints()
    if string.find(point, "LEFT$") then
        self.text:SetPoint("LEFT")
    elseif string.find(point, "RIGHT$") then
        self.text:SetPoint("RIGHT")
    else
        self.text:SetPoint("CENTER")
    end
    self:_SetPoint(point, relativeTo, relativePoint, x, y)
end

local function PowerText_SetFormat(self, format)
    if format == "percentage" then
        self.SetValue = SetPower_Percentage
    elseif format == "number" then
        self.SetValue = SetPower_Number
    elseif format == "number-short" then
        self.SetValue = SetPower_Number_Short
    end
end

local function PowerText_SetColor(self, r, g, b)
    self.text:SetTextColor(r, g, b)
end

local function PowerText_SetHideIfEmptyOrFull(self, hideIfEmptyOrFull)
    self.hideIfEmptyOrFull = hideIfEmptyOrFull
end

local function PowerText_UpdatePreviewColor(self, color)
    local r, g, b
    if color[1] == "power_color" then
        r, g, b = F.GetPowerColor("player")
    elseif color[1] == "class_color" then
        r, g, b = F.GetClassColor(Cell.vars.playerClass)
    else
        r, g, b = unpack(color[2])
    end
    self.text:SetTextColor(r, g, b)
end

function I.CreatePowerText(parent)
    local powerText = CreateFrame("Frame", parent:GetName().."PowerText", parent.widgets.indicatorFrame)
    parent.indicators.powerText = powerText
    powerText:Hide()

    local text = powerText:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    powerText.text = text

    powerText.SetFont = PowerText_SetFont
    powerText._SetPoint = powerText.SetPoint
    powerText.SetPoint = PowerText_SetPoint
    powerText.SetFormat = PowerText_SetFormat
    powerText.SetColor = PowerText_SetColor
    powerText.SetHideIfEmptyOrFull = PowerText_SetHideIfEmptyOrFull
    powerText.UpdatePreviewColor = PowerText_UpdatePreviewColor
    powerText.SetValue = noop
end

-------------------------------------------------
-- role icon
-------------------------------------------------
local ICON_PATH = "Interface\\AddOns\\Cell\\Media\\Roles\\"

local function GetTexCoordsForRole(role)
    if role == "TANK" then
        return 0, 67/256, 67/256, 134/256
    elseif role == "HEALER" then
        return 67/256, 134/256, 0, 67/256
    elseif role == "DAMAGER" then
        return 67/256, 134/256, 67/256, 134/256
    end
end

local function GetTexCoordsForRoleSmall(role)
    if role == "TANK" then
        return 0, 19/64, 22/64, 41/64
    elseif role == "HEALER" then
        return 20/64, 39/64, 1/64, 20/64
    elseif role == "DAMAGER" then
        return 20/64, 39/64, 22/64, 41/64
    end
end

local function RoleIcon_SetRole(self, role)
    self.tex:SetTexCoord(0, 1, 0, 1)
    self.tex:SetVertexColor(1, 1, 1)

    if role == "TANK" or role == "HEALER" or (not self.hideDamager and role == "DAMAGER") then
        if self.texture == "default" then
            self.tex:SetTexture(ICON_PATH .. "Default_" .. role)
        elseif self.texture == "default2" then
            self.tex:SetTexture(ICON_PATH .. "Default2_ROLES")
            self.tex:SetTexCoord(GetTexCoordsForRole(role))
        elseif self.texture == "blizzard" then
            self.tex:SetTexture(ICON_PATH .. "Blizzard_ROLES")
            self.tex:SetTexCoord(GetTexCoordsForRoleSmall(role))
        elseif self.texture == "blizzard2" then
            self.tex:SetTexture(ICON_PATH .. "Blizzard2_ROLES")
            self.tex:SetTexCoord(GetTexCoordsForRole(role))
        elseif self.texture == "blizzard3" then
            self.tex:SetTexture(ICON_PATH .. "Blizzard3_" .. role)
        elseif self.texture == "blizzard4" then
            self.tex:SetTexture(ICON_PATH .. "Blizzard4_" .. role)
        elseif self.texture == "ffxiv" then
            self.tex:SetTexture(ICON_PATH .. "FFXIV_" .. role)
        elseif self.texture == "miirgui" then
            self.tex:SetTexture(ICON_PATH .. "MiirGui_" .. role)
        elseif self.texture == "mattui" then
            self.tex:SetTexture(ICON_PATH .. "MattUI_ROLES")
            self.tex:SetTexCoord(GetTexCoordsForRoleSmall(role))
        elseif self.texture == "custom" then
            self.tex:SetTexture(self[role])
        end
        self:Show()
    elseif role == "VEHICLE-ROOT" then
        self.tex:SetTexture(ICON_PATH .. "VEHICLE")
        self:Show()
    elseif role == "VEHICLE" then
        self.tex:SetTexture(ICON_PATH .. "VEHICLE")
        self.tex:SetVertexColor(0.6, 0.6, 1)
        self:Show()
    else
        self:Hide()
    end
end

local function RoleIcon_SetRoleTexture(self, t)
    self.texture = t[1]
    self.TANK = t[2]
    self.HEALER = t[3]
    self.DAMAGER = t[4]
end

local function RoleIcon_HideDamager(self, hide)
    self.hideDamager = hide
end

local function RoleIcon_UpdatePixelPerfect(self)
    P.Resize(self)
    P.Repoint(self)
end

function I.CreateRoleIcon(parent)
    local roleIcon = CreateFrame("Frame", parent:GetName().."RoleIcon", parent.widgets.indicatorFrame)
    parent.indicators.roleIcon = roleIcon
    -- roleIcon:SetPoint("TOPLEFT", indicatorFrame)
    -- roleIcon:SetSize(11, 11)

    roleIcon.tex = roleIcon:CreateTexture(nil, "ARTWORK")
    roleIcon.tex:SetAllPoints()

    roleIcon.SetRole = RoleIcon_SetRole
    roleIcon.SetRoleTexture = RoleIcon_SetRoleTexture
    roleIcon.HideDamager = RoleIcon_HideDamager
    roleIcon.UpdatePixelPerfect = RoleIcon_UpdatePixelPerfect
end

-------------------------------------------------
-- party assignment icon
-------------------------------------------------
function I.CreatePartyAssignmentIcon(parent)
    local partyAssignmentIcon = parent.widgets.indicatorFrame:CreateTexture(parent:GetName().."PartyAssignmentIcon", "ARTWORK", nil, -7)
    parent.indicators.partyAssignmentIcon = partyAssignmentIcon
    partyAssignmentIcon:Hide()

    function partyAssignmentIcon:UpdateAssignment(unit)
        if GetPartyAssignment("MAINTANK", unit) then
            partyAssignmentIcon:SetTexture("Interface\\GroupFrame\\UI-Group-MainTankIcon")
            partyAssignmentIcon:Show()
        elseif GetPartyAssignment("MAINASSIST", unit) then
            partyAssignmentIcon:SetTexture("Interface\\GroupFrame\\UI-Group-MainAssistIcon")
            partyAssignmentIcon:Show()
        else
            partyAssignmentIcon:Hide()
        end
    end

    function partyAssignmentIcon:UpdatePixelPerfect()
        P.Resize(partyAssignmentIcon)
        P.Repoint(partyAssignmentIcon)
    end
end

-------------------------------------------------
-- leader icon
-------------------------------------------------
function I.CreateLeaderIcon(parent)
    local leaderIcon = parent.widgets.indicatorFrame:CreateTexture(parent:GetName().."LeaderIcon", "ARTWORK", nil, -7)
    parent.indicators.leaderIcon = leaderIcon
    -- leaderIcon:SetPoint("TOPLEFT", roleIcon, "BOTTOM")
    -- leaderIcon:SetPoint("TOPLEFT", 0, -11)
    -- leaderIcon:SetSize(11, 11)
    leaderIcon:Hide()

    function leaderIcon:SetIcon(isLeader, isAssistant)
        if isLeader then
            leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            leaderIcon:Show()
        elseif isAssistant then
            leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
            leaderIcon:Show()
        else
            leaderIcon:Hide()
        end
    end

    function leaderIcon:UpdatePixelPerfect()
        P.Resize(leaderIcon)
        P.Repoint(leaderIcon)
    end
end

-------------------------------------------------
-- ready check icon
-------------------------------------------------
-- READY_CHECK_WAITING_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Waiting"
-- READY_CHECK_READY_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"
-- READY_CHECK_NOT_READY_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-NotReady"
-- READY_CHECK_AFK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-NotReady"
-- ↓↓↓ since 10.1.5
-- READY_CHECK_WAITING_TEXTURE = "UI-LFG-PendingMark"
-- READY_CHECK_READY_TEXTURE = "UI-LFG-ReadyMark"
-- READY_CHECK_NOT_READY_TEXTURE = "UI-LFG-DeclineMark"
-- READY_CHECK_AFK_TEXTURE = "UI-LFG-DeclineMark"

local READY_CHECK_STATUS = {
    ready = {t = "Interface\\AddOns\\Cell\\Media\\Icons\\readycheck-ready", c = {0, 1, 0, 1}},
    waiting = {t = "Interface\\AddOns\\Cell\\Media\\Icons\\readycheck-waiting", c = {1, 1, 0, 1}},
    notready = {t = "Interface\\AddOns\\Cell\\Media\\Icons\\readycheck-notready", c = {1, 0, 0, 1}},
}

function I.CreateReadyCheckIcon(parent)
    local readyCheckIcon = CreateFrame("Frame", parent:GetName().."ReadyCheckIcon", parent.widgets.indicatorFrame)
    parent.indicators.readyCheckIcon = readyCheckIcon
    readyCheckIcon:Hide()
    --! WotLK fix: parent-alpha isolation is unavailable on 3.3.5.

    readyCheckIcon.tex = readyCheckIcon:CreateTexture(nil, "ARTWORK")
    readyCheckIcon.tex:SetAllPoints(readyCheckIcon)

    function readyCheckIcon:SetStatus(status)
        readyCheckIcon.tex:SetTexture(READY_CHECK_STATUS[status].t)
        -- readyCheckIcon.tex:SetAtlas(READY_CHECK_STATUS[status].t)
        readyCheckIcon:Show()

    end
end

-------------------------------------------------
-- aggro border
-------------------------------------------------
function I.CreateAggroBorder(parent)
    local aggroBorder = CreateFrame("Frame", parent:GetName().."AggroBorder", parent, nil)
    parent.indicators.aggroBorder = aggroBorder
    P.Point(aggroBorder, "TOPLEFT", parent, "TOPLEFT", 1, -1)
    P.Point(aggroBorder, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 1)
    aggroBorder:Hide()

    local top = aggroBorder:CreateTexture(nil, "BORDER")
    local bottom = aggroBorder:CreateTexture(nil, "BORDER")
    local left = aggroBorder:CreateTexture(nil, "BORDER")
    local right = aggroBorder:CreateTexture(nil, "BORDER")

    top:SetTexture(Cell.vars.whiteTexture)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(5)

    bottom:SetTexture(Cell.vars.whiteTexture)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(5)

    left:SetTexture(Cell.vars.whiteTexture)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(5)

    right:SetTexture(Cell.vars.whiteTexture)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(5)

    --! WotLK fix: Texture:SetGradientAlpha(orientation, r,g,b,a, r,g,b,a) is the native
    --! 3.3.5 call. The retail two-colour SetGradient form only works through a shim and
    --! needs a CreateColor table per stop, both of which are polyfills here.
    top:SetGradientAlpha("VERTICAL", 1, 0.1, 0.1, 0.2, 1, 0.1, 0.1, 1)
    bottom:SetGradientAlpha("VERTICAL", 1, 0.1, 0.1, 1, 1, 0.1, 0.1, 0.2)
    left:SetGradientAlpha("HORIZONTAL", 1, 0.1, 0.1, 1, 1, 0.1, 0.1, 0.2)
    right:SetGradientAlpha("HORIZONTAL", 1, 0.1, 0.1, 0.2, 1, 0.1, 0.1, 1)

    function aggroBorder:ShowAggro(r, g, b)
        --! WotLK fix: native SetGradientAlpha here too, plus a colour guard --
        --! ShowAggro fires on every UNIT_THREAT_SITUATION_UPDATE, and the gradient
        --! survives Hide/Show, so re-setting it for an unchanged colour is pure waste.
        if aggroBorder._r ~= r or aggroBorder._g ~= g or aggroBorder._b ~= b then
            aggroBorder._r, aggroBorder._g, aggroBorder._b = r, g, b
            top:SetGradientAlpha("VERTICAL", r, g, b, 0.2, r, g, b, 1)
            bottom:SetGradientAlpha("VERTICAL", r, g, b, 1, r, g, b, 0.2)
            left:SetGradientAlpha("HORIZONTAL", r, g, b, 1, r, g, b, 0.2)
            right:SetGradientAlpha("HORIZONTAL", r, g, b, 0.2, r, g, b, 1)
        end
        aggroBorder:Show()
    end

    function aggroBorder:SetThickness(n)
        top:SetHeight(n)
        bottom:SetHeight(n)
        left:SetWidth(n)
        right:SetWidth(n)
    end

    function aggroBorder:UpdatePixelPerfect()
        P.Repoint(aggroBorder)
    end
end

-------------------------------------------------
-- aggro blink
-------------------------------------------------
-- smooth alpha pulse via OnUpdate.
-- The Animation API is only partial on this 3.3.5 client (eased looping is
-- unreliable, FlipBook absent), so drive the blink manually: safe + smooth.
local PULSE_MIN, PULSE_MAX, PULSE_SPEED = 0.1, 1, 12.5 -- period = 2*pi/SPEED ~ 0.5s (matches original tempo)
--! WotLK perf: середина и амплитуда считаются один раз при загрузке, а не
--! заново в каждом кадре. Тождество: MIN + (MAX-MIN)*(sin*0.5+0.5) =
--! (MIN + (MAX-MIN)*0.5) + (MAX-MIN)*0.5*sin. Порядок сложения плавающей точки
--! чуть другой, расхождение - единицы ulp на альфе, глазом не видно.
local PULSE_AMP = (PULSE_MAX - PULSE_MIN) * 0.5
local PULSE_MID = PULSE_MIN + PULSE_AMP

--! WotLK perf: три обработчика вынесены из тела CreateAggroBlink на уровень
--! файла. Раньше на каждую кнопку рейда создавалось по три замыкания (40 юнитов
--! = 120 объектов), хотя ни одно из них не захватывало ничего от конкретной
--! кнопки - только константы и self.
local function AggroBlink_OnShow(self)
    self.pulseElapsed = 0
    self:SetAlpha(PULSE_MAX)
end

local function AggroBlink_OnUpdate(self, elapsed)
    --! WotLK perf: накопитель держится в локале на время кадра. Поле
    --! pulseElapsed читалось из таблицы дважды за вызов, а драйвер работает на
    --! полном фреймрейте на каждом юните с аггро. Запись в поле сохранена: его
    --! обнуляет OnShow. Возврата между чтением и записью в драйвере нет.
    local t = self.pulseElapsed + elapsed
    self.pulseElapsed = t
    self:SetAlpha(PULSE_MID + PULSE_AMP * sin(t * PULSE_SPEED))
end

local function AggroBlink_OnHide(self)
    self:SetAlpha(1)
end

function I.CreateAggroBlink(parent)
    local aggroBlink = CreateFrame("Frame", parent:GetName().."AggroBlink", parent.widgets.indicatorFrame, nil)
    parent.indicators.aggroBlink = aggroBlink
    -- aggroBlink:SetPoint("TOPLEFT")
    -- aggroBlink:SetSize(10, 10)
    aggroBlink:SetBackdrop({bgFile = Cell.vars.whiteTexture, edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
    aggroBlink:SetBackdropColor(1, 0, 0, 1)
    aggroBlink:SetBackdropBorderColor(0, 0, 0, 1)
    aggroBlink:Hide()

    --! WotLK fix: поле заводится сразу, чтобы драйвер читал число, а не nil.
    --! Фрейм создан скрытым, так что OnShow всё равно отработает первым, но
    --! завязываться на порядок скриптов ради одного присваивания не стоит.
    aggroBlink.pulseElapsed = 0

    aggroBlink:SetScript("OnShow", AggroBlink_OnShow)
    aggroBlink:SetScript("OnUpdate", AggroBlink_OnUpdate)
    aggroBlink:SetScript("OnHide", AggroBlink_OnHide)

    function aggroBlink:ShowAggro(r, g, b)
        aggroBlink:SetBackdropColor(r, g, b)
        aggroBlink:Show()
    end

    function aggroBlink:UpdatePixelPerfect()
        P.Resize(aggroBlink)
        P.Repoint(aggroBlink)
        aggroBlink:SetBackdrop({bgFile = Cell.vars.whiteTexture, edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
        aggroBlink:SetBackdropColor(1, 0, 0, 1)
        aggroBlink:SetBackdropBorderColor(0, 0, 0, 1)
    end
end

-------------------------------------------------
-- shield bar
-------------------------------------------------
local function ShieldBar_SetHorizontalValue(bar, percent)
    local maxWidth = bar.parentHealthBar:GetWidth()
    local barWidth
    if percent >= 1 then
        barWidth = maxWidth
    else
        barWidth = maxWidth * percent
    end
    bar:SetWidth(max(barWidth, 3))
end

local function ShieldBar_SetVerticalValue(bar, percent)
    local maxHeight = bar.parentHealthBar:GetHeight()
    local barHeight
    if percent >= 1 then
        barHeight = maxHeight
    else
        barHeight = maxHeight * percent
    end
    bar:SetHeight(max(barHeight, 3))
end

local function ShieldBar_SetPoint(bar, point, anchorTo, anchorPoint, x, y)
    -- if point == "HEALTH_BAR_HORIZONTAL" then
    --     bar:_SetPoint("TOPLEFT", b.widgets.healthBar)
    --     bar:_SetPoint("BOTTOMLEFT", b.widgets.healthBar)
    --     bar.SetValue = ShieldBar_SetHorizontalValue
    -- elseif point == "HEALTH_BAR_VERTICAL" then
    --     bar:_SetPoint("TOPLEFT", b.widgets.healthBar)
    --     bar:_SetPoint("BOTTOMLEFT", b.widgets.healthBar)
    --     bar.SetValue = ShieldBar_SetVerticalValue
    if point == "HEALTH_BAR" then
        bar:_SetPoint("TOPLEFT", bar.parentHealthBar, P.Scale(-1), P.Scale(1))
        bar:_SetPoint("BOTTOMLEFT", bar.parentHealthBar, P.Scale(-1), P.Scale(-1))
        bar.SetValue = ShieldBar_SetHorizontalValue
    else
        bar:_SetPoint(point, anchorTo, anchorPoint, x, y)
        bar.SetValue = ShieldBar_SetHorizontalValue
    end
end

function I.CreateShieldBar(parent)
    local shieldBar = CreateFrame("Frame", parent:GetName().."ShieldBar", parent.widgets.indicatorFrame, nil)
    parent.indicators.shieldBar = shieldBar
    -- shieldBar:SetSize(4, 4)
    shieldBar:Hide()
    shieldBar:SetBackdrop({edgeFile=Cell.vars.whiteTexture, edgeSize=P.Scale(1)})
    shieldBar:SetBackdropBorderColor(0, 0, 0, 1)

    local tex = shieldBar:CreateTexture(nil, "BORDER", nil, -7)
    tex:SetAllPoints()

    shieldBar._SetPoint = shieldBar.SetPoint
    shieldBar.SetPoint = ShieldBar_SetPoint
    shieldBar.SetValue = ShieldBar_SetHorizontalValue

    shieldBar.parentHealthBar = parent.widgets.healthBar

    function shieldBar:SetColor(r, g, b, a)
        tex:SetTexture(r, g, b, a)
    end

    function shieldBar:UpdatePixelPerfect()
        P.Resize(shieldBar)
        P.Repoint(shieldBar)
        P.Reborder(shieldBar)
    end
end

-------------------------------------------------
-- health threshold
-------------------------------------------------
function I.CreateHealthThresholds(parent)
    local healthThresholds = CreateFrame("Frame", parent:GetName().."HealthThresholds", parent.widgets.highLevelFrame)
    parent.indicators.healthThresholds = healthThresholds
    healthThresholds:SetAllPoints(parent.widgets.healthBar)

    healthThresholds.tex = healthThresholds:CreateTexture(nil, "ARTWORK")

    function healthThresholds:SetThickness(thickness)
        healthThresholds.thickness = thickness
        P.Size(healthThresholds.tex, thickness, thickness)
    end

    function healthThresholds:SetOrientation(orientation)
        healthThresholds.orientation = orientation
        healthThresholds.tex:ClearAllPoints()
        if orientation == "horizontal" then
            healthThresholds.tex:SetPoint("TOP")
            healthThresholds.tex:SetPoint("BOTTOM")
        else
            healthThresholds.tex:SetPoint("LEFT")
            healthThresholds.tex:SetPoint("RIGHT")
        end
    end

    function healthThresholds:CheckThreshold(percent)
        local found
        for i, t in ipairs(Cell.vars.healthThresholds) do
            if percent < t[1] then
                found = i
                break
            end
        end
        if found then
            if healthThresholds.orientation == "horizontal" then
                healthThresholds.tex:SetPoint("LEFT", Cell.vars.healthThresholds[found][1] * parent.widgets.healthBar:GetWidth(), 0)
            else
                healthThresholds.tex:SetPoint("BOTTOM", 0, Cell.vars.healthThresholds[found][1] * parent.widgets.healthBar:GetHeight())
            end
            healthThresholds.tex:SetTexture(unpack(Cell.vars.healthThresholds[found][2]))
            healthThresholds:Show()
        else
            healthThresholds:Hide()
        end
    end

    if parent == CellIndicatorsPreviewButton then
        healthThresholds.tex:Hide()

        function healthThresholds:UpdateThresholdsPreview()
            for i, t in ipairs(Cell.vars.healthThresholds) do
                healthThresholds[i] = healthThresholds[i] or healthThresholds:CreateTexture(nil, "ARTWORK")
                P.Size(healthThresholds[i], healthThresholds.thickness, healthThresholds.thickness)
                healthThresholds[i]:SetTexture(unpack(t[2]))
                -- healthThresholds[i]:SetBlendMode("ADD")

                healthThresholds[i]:ClearAllPoints()
                if healthThresholds.orientation == "horizontal" then
                    healthThresholds[i]:SetPoint("TOP")
                    healthThresholds[i]:SetPoint("BOTTOM")
                    healthThresholds[i]:SetPoint("LEFT", t[1] * parent.widgets.healthBar:GetWidth(), 0)
                else
                    healthThresholds[i]:SetPoint("LEFT")
                    healthThresholds[i]:SetPoint("RIGHT")
                    healthThresholds[i]:SetPoint("BOTTOM", 0, t[1] * parent.widgets.healthBar:GetHeight())
                end
                healthThresholds[i]:Show()
            end
            -- hide unused
            for i = #Cell.vars.healthThresholds+1, #healthThresholds do
                if healthThresholds[i] then
                    healthThresholds[i]:Hide()
                end
            end
        end
    end
end

-- sort and save
function I.UpdateHealthThresholds()
    Cell.vars.healthThresholds = Cell.vars.currentLayoutTable.indicators[Cell.defaults.indicatorIndices.healthThresholds].thresholds
    F.Sort(Cell.vars.healthThresholds, 1, "ascending")
end

-------------------------------------------------
-- power word : shield bar (Wrath custom bars for PW:S + WS)
-------------------------------------------------
function I.CreatePowerWordShield(parent)
    local powerWordShield = CreateFrame("Frame", parent:GetName().."PowerWordShield", parent.widgets.indicatorFrame)
    parent.indicators.powerWordShield = powerWordShield
    powerWordShield:Hide()

    -- simple vertical bars beside the unit button: yellow = PW:S duration, red = Weakened Soul
    local shieldBar = powerWordShield:CreateTexture(nil, "OVERLAY", nil, 0)
    shieldBar:SetTexture(1, 1, 0, 0.9)
    shieldBar:Hide()

    local wsBar = powerWordShield:CreateTexture(nil, "OVERLAY", nil, 1)
    wsBar:SetTexture(1, 0.2, 0.2, 0.9)
    wsBar:Hide()

    powerWordShield.shieldBar = shieldBar
    powerWordShield.wsBar = wsBar

    powerWordShield.shieldDuration = 0
    powerWordShield.shieldExpires = 0
    powerWordShield.wsDuration = 0
    powerWordShield.wsExpires = 0

    local function UpdateVisibility()
        if (powerWordShield.shieldExpires > GetTime()) or (powerWordShield.wsExpires > GetTime()) then
            powerWordShield:Show()
        else
            powerWordShield:Hide()
        end
    end

    --! WotLK fix: the manual duration bars do not need layout mutations every
    --! rendered frame. Their anchors are static; update only heights at 10 Hz.
    shieldBar:SetPoint("BOTTOMRIGHT", powerWordShield, "BOTTOMRIGHT")
    wsBar:SetPoint("BOTTOMRIGHT", powerWordShield, "BOTTOMRIGHT")

    --! WotLK perf: накопитель троттлинга переехал из поля кадра в локал
    --! замыкания. Поле `_elapsed` стоило три хеш-лукапа в таблице кадра за кадр
    --! (чтение, запись, чтение на гейте), и всё это на полном фреймрейте на
    --! каждом юните со щитом. Снаружи его никто не читал - проверено грепом по
    --! Cell/. `or 0` не нужен: локал инициализирован здесь же. Накопленное время
    --! пишется до раннего возврата, так что тик не залипает.
    local elapsedTime = 0

    powerWordShield:SetScript("OnUpdate", function(self, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime < 0.1 then return end
        elapsedTime = 0

        local now = GetTime()
        local configuredWidth = self.barWidth or 2
        local width = P.Scale(configuredWidth > 0 and configuredWidth or 4)
        local height = parent:GetHeight() or 0
        if height <= 0 then height = P.Scale(20) end

        if self:GetWidth() ~= width or self:GetHeight() ~= height then
            self:_SetSize(width, height)
            shieldBar:SetWidth(width)
            wsBar:SetWidth(width)
        end

        --! WotLK perf: сроки и длительности сняты в локалы - каждое поле
        --! читалось из таблицы кадра по три раза за проход. И вместо двух
        --! вызовов IsShown() в конце видимость считается тем же проходом:
        --! показать или скрыть решено здесь же, парой строк выше, а других
        --! писателей между этими точками нет - обе текстуры приватны замыканию.
        local shown = false

        -- PW:S (bottom-to-top on the right edge)
        local expires, duration = self.shieldExpires, self.shieldDuration
        if expires > now and duration > 0 then
            local pct = (expires - now) / duration
            shieldBar:SetHeight(height * pct)
            shieldBar:Show()
            shown = true
        else
            shieldBar:Hide()
        end

        -- Weakened Soul (bottom-to-top, overlaid on top of PW:S)
        expires, duration = self.wsExpires, self.wsDuration
        if expires > now and duration > 0 then
            local pct = (expires - now) / duration
            wsBar:SetHeight(height * pct)
            wsBar:Show()
            shown = true
        else
            wsBar:Hide()
        end

        if not shown then
            self:Hide()
        end
    end)

    powerWordShield._SetSize = powerWordShield.SetSize
    function powerWordShield:SetSize(width, height)
        powerWordShield.barWidth = width
        powerWordShield:UpdatePixelPerfect()
    end

    function powerWordShield:UpdatePixelPerfect()
        local configuredWidth = self.barWidth or 2
        local bw = P.Scale(configuredWidth > 0 and configuredWidth or 4)
        local bh = parent:GetHeight() or 0
        if bh <= 0 then bh = P.Scale(20) end
        self:_SetSize(bw, bh)
        shieldBar:SetWidth(bw)
        wsBar:SetWidth(bw)
    end

    --! WotLK fix: заглушка SetShape убрана — после перевода индикатора на полосы
    --! форму никто не задаёт: ни таблица настроек, ни UnitButton, ни панель опций.
    function powerWordShield:SetColors()
        -- colors no longer configurable; keep stub to avoid errors
    end

    function powerWordShield:UpdateShield(value, max, resetMax)
        if resetMax then
            self.max = nil
        elseif max then
            self.max = max
        end
    end

    function powerWordShield:SetShieldCooldown(start, duration)
        if start and duration then
            self.shieldDuration = duration
            self.shieldExpires = start + duration
            self:Show()
        else
            self.shieldDuration = 0
            self.shieldExpires = 0
        end
    end

    function powerWordShield:SetWeakenedSoulCooldown(start, duration, isMine)
        if start and duration then
            self.wsDuration = duration
            self.wsExpires = start + duration
            self:Show()
        else
            self.wsDuration = 0
            self.wsExpires = 0
        end
    end
end

-------------------------------------------------
-- crowd controls
-------------------------------------------------
function I.CreateCrowdControls(parent)
    local crowdControls = CreateFrame("Frame", parent:GetName().."CrowdControlsParent", parent.widgets.indicatorFrame)
    parent.indicators.crowdControls = crowdControls
    crowdControls:Hide()

    crowdControls._SetSize = crowdControls.SetSize
    crowdControls.SetSize = I.Cooldowns_SetSize
    crowdControls.SetBorder = I.Cooldowns_SetBorder
    crowdControls.UpdateSize = I.Cooldowns_UpdateSize_WithSpacing
    crowdControls.ShowDuration = I.Cooldowns_ShowDuration
    crowdControls.SetOrientation = I.Cooldowns_SetOrientation_WithSpacing
    crowdControls.SetFont = I.Cooldowns_SetFont
    crowdControls.UpdatePixelPerfect = I.Cooldowns_UpdatePixelPerfect

    for i = 1, 3 do
        local frame = I.CreateAura_BorderIcon(parent:GetName().."CrowdControl"..i, crowdControls, 2)
        tinsert(crowdControls, frame)
        -- frame:SetScript("OnShow", crowdControls.UpdateSize)
        -- frame:SetScript("OnHide", crowdControls.UpdateSize)
    end
end

--------------------------------------------------
-- Combat Icon
--------------------------------------------------
local function CombatIcon_UpdatePixelPerfect(self)
    P.Resize(self)
    P.Repoint(self)
end

function I.CreateCombatIcon(parent)
    local combatIcon = CreateFrame("Frame", parent:GetName() .. "CombatIcon", parent.widgets.indicatorFrame)
    parent.indicators.combatIcon = combatIcon
    combatIcon.root = parent
    combatIcon:Hide()

    --! WotLK fix: CreateTexture takes (name, layer, inherits) on 3.3.5a - there is no
    --! fourth "sublevel" argument, so upstream's 0 / -5 pair was dropped silently and
    --! both textures ended up on the same ARTWORK sublevel. Draw order then fell back
    --! to creation order, which is the reverse of what is wanted here: flashTex was
    --! created second and rendered ON TOP of the swords, so the ADD-blended glow lit up
    --! the icon art instead of haloing behind it. Put the glow on a real lower layer
    --! (BORDER < ARTWORK) - that holds whether or not this client honours sublevels.
    combatIcon.tex = combatIcon:CreateTexture(nil, "ARTWORK")
    combatIcon.tex:SetAllPoints()
    combatIcon.tex:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\combat", nil, nil, "TRILINEAR")
    -- combatIcon.tex:SetAtlas("combat_swords-dynamicIcon")

    combatIcon.flashTex = combatIcon:CreateTexture(nil, "BORDER")
    combatIcon.flashTex:SetAllPoints()
    combatIcon.flashTex:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\combat_glow", nil, nil, "TRILINEAR")
    -- combatIcon.flashTex:SetAtlas("combat_swords-flash")
    combatIcon.flashTex:SetBlendMode("ADD")

    A.CreateBlinkAnimation(combatIcon.flashTex, nil, true)

    --! WotLK fix: убрана строка `combatIcon:SetScript("OnEvent", CombatIcon_OnEvent)`.
    --! Функции CombatIcon_OnEvent нет нигде - ни здесь, ни в апстриме (Cell-retail
    --! :2389, та же строка), так что имя читалось из _G и давало nil, то есть вызов
    --! сводился к SetScript("OnEvent", nil). Событий на этот фрейм никто не регистрирует:
    --! иконка обновляется опросом из UnitButton_OnUpdate (UnitButton_Cata_Wrath:3717),
    --! поэтому обработчик и не нужен. Оставлять чтение чужого глобала нельзя (CLAUDE.md
    --! §3): аддон с собственной CombatIcon_OnEvent превратил бы это в установку чужой
    --! функции обработчиком нашего фрейма.
    combatIcon.UpdatePixelPerfect = CombatIcon_UpdatePixelPerfect

    return combatIcon
end

-------------------------------------------------
-- missing buffs
-------------------------------------------------
--! WotLK fix: подсветка (ButtonGlow) иконок "нехватающих баффов" стала отдельной
--! настройкой индикатора - showGlow. Тестер (Mr.Mole, 25ппл на прогрессивном
--! заполнении рейда): иконки мигают пачкой и мешают читать рамки, а выключать
--! индикатор целиком не хочется - сами иконки полезны. Флаг модульный, а не на
--! кнопку: настройка одна на индикатор, значит и читать её надо один раз, а не
--! по 40 таблиц на каждом проходе аур. Объявлен до CreateMissingBuffs: замыкание
--! OnSizeChanged ниже иначе увидело бы не этот local, а глобал (nil) - в Lua 5.1
--! upvalue связывается по месту компиляции, а не по месту вызова.
local missingBuffsGlow = true

function I.CreateMissingBuffs(parent)
    local missingBuffs = CreateFrame("Frame", parent:GetName().."MissingBuffParent", parent.widgets.indicatorFrame)
    parent.indicators.missingBuffs = missingBuffs
    missingBuffs:Hide()

    missingBuffs._SetSize = missingBuffs.SetSize
    missingBuffs.SetSize = I.Cooldowns_SetSize
    missingBuffs.UpdateSize = I.Cooldowns_UpdateSize
    missingBuffs.SetOrientation = I.Cooldowns_SetOrientation
    missingBuffs.UpdatePixelPerfect = I.Cooldowns_UpdatePixelPerfect

    for i = 1, 3 do
        local name = parent:GetName().."MissingBuff"..i
        local frame = I.CreateAura_BarIcon(name, missingBuffs)
        tinsert(missingBuffs, frame)
        frame:HookScript("OnSizeChanged", function()
            --! WotLK fix: пересчёт подсветки под новый размер - только если она включена.
            if missingBuffsGlow then
                LCG.ButtonGlow_Start(frame)
            else
                LCG.ButtonGlow_Stop(frame)
            end
        end)
    end
end

--! WotLK fix: применение настройки showGlow, см. объявление missingBuffsGlow выше.
function I.SetMissingBuffsGlow(enabled)
    missingBuffsGlow = enabled and true or false
    --! Пройти по уже нарисованным иконкам: LCG держит анимацию на самом фрейме,
    --! а иконка после смены настройки своей перерисовки не получит - только на
    --! следующем UNIT_AURA, то есть галка выглядела бы неработающей.
    F.IterateAllUnitButtons(function(b)
        local t = b.indicators and b.indicators.missingBuffs
        if not t then return end
        for i = 1, 3 do
            if missingBuffsGlow and t[i]:IsShown() then
                LCG.ButtonGlow_Start(t[i])
            else
                LCG.ButtonGlow_Stop(t[i])
            end
        end
    end, true)
end

local missingBuffsEnabled = false
function I.EnableMissingBuffs(enabled)
    missingBuffsEnabled = enabled

    if enabled and CellDB["tools"]["buffTracker"][1] then
        CellBuffTrackerFrame:GroupRosterUpdate(true)
    end
end

--! WotLK fix: было без local - запись в глобал _G.missingBuffsFilters. Cell не владеет
--! глобалами, а имя ничем не защищено. Читателя у этого значения нет ни здесь, ни в
--! апстриме (Cell-retail/Indicators/Built-in.lua:2430 - та же строка, тоже без чтения):
--! фильтры до BuffTracker доходят через CellDB["tools"]["buffTracker"], а сама
--! I.UpdateMissingBuffsFilters в бэкпорте вообще ни разу не вызывается. Оставлено
--! локальным, а не вырезано: контракт функции не меняется, а глобал больше не течёт.
local missingBuffsFilters
function I.UpdateMissingBuffsFilters(filters, noUpdate)
    if filters then missingBuffsFilters = filters end

    if not noUpdate and missingBuffsEnabled and CellDB["tools"]["buffTracker"][1] then
        CellBuffTrackerFrame:GroupRosterUpdate(true)
    end
end

local function HideMissingBuffs(b)
    for i = 1, 3 do
        b.indicators.missingBuffs[i]:Hide()
    end
end

local missingBuffsCounter = {}
function I.HideMissingBuffs(unit, force)
    if not (missingBuffsEnabled or force) then return end
    missingBuffsCounter[unit] = nil
    F.HandleUnitButton("unit", unit, HideMissingBuffs)
end

local function ShowMissingBuff(b, index, icon)
    b.indicators.missingBuffs:UpdateSize(index)

    local f = b.indicators.missingBuffs[index]
    f:SetCooldown(0, 0, nil, icon, 0)
    --! WotLK fix: подсветка по настройке showGlow, см. I.SetMissingBuffsGlow.
    if missingBuffsGlow then
        LCG.ButtonGlow_Start(f)
    else
        LCG.ButtonGlow_Stop(f)
    end
end

function I.ShowMissingBuff(unit, icon)
    if not missingBuffsEnabled then return end

    missingBuffsCounter[unit] = (missingBuffsCounter[unit] or 0) + 1
    if missingBuffsCounter[unit] > 3 then return end

    F.HandleUnitButton("unit", unit, ShowMissingBuff, missingBuffsCounter[unit], icon)
end
