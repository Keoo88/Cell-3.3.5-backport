local addonName, ns = ...
-- Use a single global Cell table for everything
_G.Cell = _G.Cell or ns or {}
local Cell = _G.Cell

-------------------------------------------------
-- securecallfunction polyfill
-- Some 3.3.5 builds lack this helper; Ace libraries expect it.
-------------------------------------------------
if type(securecallfunction) ~= "function" then
    function securecallfunction(func, ...)
        if type(func) ~= "function" then return end
        local ok, r1, r2, r3, r4, r5 = pcall(func, ...)
        if ok then
            return r1, r2, r3, r4, r5
        end
        -- Swallow errors to mimic securecallfunction behavior in newer clients
    end
end


-------------------------------------------------
-- PROJECT / FLAVOR SHIM FOR 3.3.5a
-------------------------------------------------
-- On real Retail/Classic, WOW_PROJECT_ID is a number.
-- On 3.3.5a private clients, it's usually nil, which breaks addons
-- that rely on it. So we fake the constants and pretend to be Wrath Classic.
if type(WOW_PROJECT_ID) ~= "number" then
    -- Fake Blizzard project constants
    WOW_PROJECT_MAINLINE          = 1
    WOW_PROJECT_CLASSIC           = 2
    WOW_PROJECT_WRATH_CLASSIC     = 11
    WOW_PROJECT_CATACLYSM_CLASSIC = 12
    WOW_PROJECT_MISTS_CLASSIC     = 13

    -- Tell the addon we're Wrath Classic
    WOW_PROJECT_ID = WOW_PROJECT_WRATH_CLASSIC
end

-- Initialize flavor + flags once based on WOW_PROJECT_ID
if not Cell.flavor then
    if WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then
        Cell.flavor = "wrath"
    elseif WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        Cell.flavor = "retail"
    elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        Cell.flavor = "vanilla"
    elseif WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC then
        Cell.flavor = "cata"
    elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
        Cell.flavor = "mists"
    else
        Cell.flavor = "retail"
    end
end

Cell.isRetail  = (Cell.flavor == "retail")
Cell.isWrath   = (Cell.flavor == "wrath")
Cell.isVanilla = (Cell.flavor == "vanilla")
Cell.isCata    = (Cell.flavor == "cata")
Cell.isMists   = (Cell.flavor == "mists")
Cell.isTWW     = false -- definitely not TWW on 3.3.5a

-------------------------------------------------

if not IsMetaKeyDown then
    function IsMetaKeyDown() return false end
end

if not CreateVector2D then
    function CreateVector2D(x, y)
        return {
            x = x or 0,
            y = y or 0,
            GetXY = function(self) return self.x, self.y end,
            SetXY = function(self, x, y) self.x = x; self.y = y end
        }
    end
end

-- Initialize supporters tables if not present
Cell.supporters1 = Cell.supporters1 or {}
Cell.supporters2 = Cell.supporters2 or {}

-------------------------------------------------
-- Polyfills for WotLK 3.3.5a
-------------------------------------------------

-------------------------------------------------
-- Screen size polyfill for WotLK
-------------------------------------------------
if not GetPhysicalScreenSize then
    -- WotLK uses GetScreenWidth() and GetScreenHeight() instead
    function GetPhysicalScreenSize()
        return GetScreenWidth(), GetScreenHeight()
    end
end

-------------------------------------------------
-- PixelUtil polyfill (doesn't exist in WotLK)
-------------------------------------------------
if not PixelUtil then
    PixelUtil = {}

    -- Polyfill for GetNearestPixelSize
    -- Returns a pixel-perfect size based on the desired size and scale
    function PixelUtil.GetNearestPixelSize(desiredSize, scale)
        if not desiredSize or desiredSize == 0 then
            return 0
        end

        -- Handle nil or zero scale
        if not scale or scale == 0 then
            scale = 1
        end

        -- Round to nearest pixel
        local pixelSize = desiredSize * scale
        if pixelSize >= 0 then
            pixelSize = math.floor(pixelSize + 0.5)
        else
            pixelSize = math.ceil(pixelSize - 0.5)
        end

        -- Ensure minimum size of 1 pixel
        if desiredSize > 0 and pixelSize < 1 then
            pixelSize = 1
        elseif desiredSize < 0 and pixelSize > -1 then
            pixelSize = -1
        end

        return pixelSize / scale
    end

    -- Polyfill for SetPoint
    -- Just wraps the standard SetPoint method
    function PixelUtil.SetPoint(frame, ...)
        if frame and frame.SetPoint then
            frame:SetPoint(...)
        end
    end

    -- Polyfill for GetPixelToUIUnitFactor (used in some addons)
    function PixelUtil.GetPixelToUIUnitFactor()
        local scale = UIParent:GetEffectiveScale()
        return 1 / (768 / GetScreenHeight()) / scale
    end
end


if not CreateVector2D then
    function CreateVector2D(x, y)
        return {
            x = x or 0,
            y = y or 0,
            GetXY = function(self) return self.x, self.y end,
            SetXY = function(self, x, y) self.x = x; self.y = y end
        }
    end
end


-------------------------------------------------
-- CellDropdownList shim
-- Retail has a shared dropdown list frame; Wrath port just needs a dummy to hide.
-------------------------------------------------
if not CellDropdownList then
    local f = CreateFrame("Frame", "CellDropdownList", UIParent)
    f:Hide()
    _G.CellDropdownList = f
end



-- Texture:SetGradient polyfill to support CreateColor tables on 3.3.5a
do
    local tex = UIParent:CreateTexture()
    local mt = getmetatable(tex)

    if mt and mt.__index then
        local origSetGradient = mt.__index.SetGradient
        local origSetGradientAlpha = mt.__index.SetGradientAlpha

        local function unpackColor(c)
            if type(c) ~= "table" then return end
            if c.GetRGBA then
                return c:GetRGBA()
            end
            return c.r, c.g, c.b, c.a or 1
        end

        -- accept either (orientation, color1, color2) or the classic numeric signature
        if origSetGradient and not mt.__index._CellSetGradientPolyfill then
            function mt.__index:SetGradient(orientation, ...)
                local c1, c2 = ...
                if type(c1) == "table" and type(c2) == "table" then
                    local r1, g1, b1, a1 = unpackColor(c1)
                    local r2, g2, b2, a2 = unpackColor(c2)
                    if origSetGradientAlpha then
                        return origSetGradientAlpha(self, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
                    end
                end
                return origSetGradient(self, orientation, ...)
            end
            mt.__index._CellSetGradientPolyfill = true
        end

        if origSetGradientAlpha and not mt.__index._CellSetGradientAlphaPolyfill then
            function mt.__index:SetGradientAlpha(orientation, ...)
                local args = {...}
                if #args == 2 and type(args[1]) == "table" and type(args[2]) == "table" then
                    local r1, g1, b1, a1 = unpackColor(args[1])
                    local r2, g2, b2, a2 = unpackColor(args[2])
                    return origSetGradientAlpha(self, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
                end
                return origSetGradientAlpha(self, orientation, ...)
            end
            mt.__index._CellSetGradientAlphaPolyfill = true
        end

        -- Texture:SetColorTexture polyfill for WotLK 3.3.5
        -- In retail, SetColorTexture(r, g, b, a) creates a solid color texture
        -- In WotLK, we use SetTexture with the RGBA values directly
        if not mt.__index.SetColorTexture then
            function mt.__index:SetColorTexture(r, g, b, a)
                -- In WotLK, SetTexture with 4 numeric args creates a solid color
                self:SetTexture(r or 1, g or 1, b or 1, a or 1)
            end
        end

        -- Wrap Texture:SetAtlas to handle missing atlases in WotLK 3.3.5
        -- WotLK has fewer atlases than retail, so we need to gracefully handle missing ones
        if mt.__index.SetAtlas and not mt.__index._CellSetAtlasWrapped then
            local originalSetAtlas = mt.__index.SetAtlas
            function mt.__index:SetAtlas(atlasName, useAtlasSize, filterMode)
                -- Try to call the original SetAtlas
                local success = pcall(originalSetAtlas, self, atlasName, useAtlasSize, filterMode)
                if not success then
                    -- Atlas doesn't exist in WotLK, use a fallback
                    -- Set to a blank/transparent texture to avoid errors
                    self:SetTexture(nil)
                end
            end
            mt.__index._CellSetAtlasWrapped = true
        end
    end
end


-- Mouse click / motion polyfill for Wrath
do
    local region = CreateFrame("Frame")
    local mt = getmetatable(region)
    if not mt or not mt.__index then return end

    local idx = mt.__index

    -- Retail: ScriptRegion:SetMouseClickEnabled(bool)
    if not idx.SetMouseClickEnabled then
        function idx:SetMouseClickEnabled(enabled)
            -- Wrath only has EnableMouse(bool) for both hover+click
            if self.EnableMouse then
                self:EnableMouse(not not enabled)
            end
        end
    end

    -- Retail: ScriptRegion:SetMouseMotionEnabled(bool)
    if not idx.SetMouseMotionEnabled then
        function idx:SetMouseMotionEnabled(enabled)
            if self.EnableMouse then
                self:EnableMouse(not not enabled)
            end
        end
    end
end




-- FontString IsTruncated polyfill for WotLK
do
    local fs = UIParent:CreateFontString()
    local mt = getmetatable(fs)

    if mt and mt.__index and not mt.__index.IsTruncated then
        function mt.__index:IsTruncated()
            -- Check if text width exceeds the font string's width
            local stringWidth = self:GetStringWidth()
            local frameWidth = self:GetWidth()

            -- If width is 0, assume not truncated
            if frameWidth == 0 then
                return false
            end

            -- Check if string width exceeds available width
            return stringWidth > frameWidth
        end
    end
end

-------------------------------------------------
-- FontString SetRotation polyfill for WotLK
-- Text rotation doesn't exist in WotLK, so this is a no-op
-------------------------------------------------
do
    local fs = UIParent:CreateFontString()
    local mt = getmetatable(fs)

    if mt and mt.__index and not mt.__index.SetRotation then
        function mt.__index:SetRotation(angle)
            -- WotLK doesn't support text rotation, no-op to prevent errors
            -- Alternative: use vertical text with newlines at the call site
        end
    end
end

-------------------------------------------------
-- CreateColor polyfill for WotLK
-- In retail, CreateColor creates a Color object with helper methods
-- In WotLK, we need to create a table with the same interface
-------------------------------------------------
if not CreateColor then
    function CreateColor(r, g, b, a)
        local color = {r = r or 1, g = g or 1, b = b or 1, a = a or 1}

        function color:GetRGB()
            return self.r, self.g, self.b
        end

        function color:GetRGBA()
            return self.r, self.g, self.b, self.a
        end

        function color:WrapTextInColorCode(text)
            -- Format: |cAARRGGBB + text + |r
            -- AA = alpha (255 for opaque), RR = red, GG = green, BB = blue
            local a = math.floor((self.a or 1) * 255)
            local r = math.floor(self.r * 255)
            local g = math.floor(self.g * 255)
            local b = math.floor(self.b * 255)
            return string.format("|c%02x%02x%02x%02x%s|r", a, r, g, b, text)
        end

        return color
    end
else
    -- CreateColor exists, but WrapTextInColorCode might not
    -- Add WrapTextInColorCode to existing Color objects if missing
    local testColor = CreateColor(1, 1, 1, 1)
    if testColor and not testColor.WrapTextInColorCode then
        local mt = getmetatable(testColor)
        if mt and mt.__index then
            function mt.__index:WrapTextInColorCode(text)
                local a = math.floor((self.a or 1) * 255)
                local r = math.floor(self.r * 255)
                local g = math.floor(self.g * 255)
                local b = math.floor(self.b * 255)
                return string.format("|c%02x%02x%02x%02x%s|r", a, r, g, b, text)
            end
        end
    end
end

-------------------------------------------------
-- Frame CreateFontString polyfill for WotLK
-- Ensures all created font strings have a default font set
-- This prevents "Font not set" errors when calling SetText
-------------------------------------------------
do
    local frame = CreateFrame("Frame")
    local mt = getmetatable(frame)

    if mt and mt.__index and not mt.__index._CellFontStringCreationPolyfill then
        local origCreateFontString = mt.__index.CreateFontString

        if origCreateFontString then
            function mt.__index:CreateFontString(name, layer, inheritsFrom)
                local fontString = origCreateFontString(self, name, layer, inheritsFrom)

                -- WotLK Fix: If no font object was inherited, set a default font to prevent errors
                -- Check if font is already set (from inheritsFrom)
                local currentFont, currentSize, currentFlags = fontString:GetFont()
                if not currentFont then
                    -- Set a safe default font
                    fontString:SetFont(STANDARD_TEXT_FONT, 12, "")
                end

                return fontString
            end

            mt.__index._CellFontStringCreationPolyfill = true
        end
    end
end

-- SmoothStatusBarMixin polyfill for WotLK
if not SmoothStatusBarMixin then
    SmoothStatusBarMixin = {}

    function SmoothStatusBarMixin:OnLoad()
        -- no-op on 3.3.5
    end

    function SmoothStatusBarMixin:SetSmoothedValue(value)
        if self.SetValue then
            self:SetValue(value)
        end
    end

    function SmoothStatusBarMixin:SetMinMaxSmoothedValue(minVal, maxVal)
        if self.SetMinMaxValues then
            self:SetMinMaxValues(minVal, maxVal)
        end
    end

    -- Retail uses this to reset the smoothing state; on 3.3.5 we just snap to current value.
    function SmoothStatusBarMixin:ResetSmoothedValue()
        if self.GetValue and self.SetValue then
            self:SetValue(self:GetValue())
        end
    end
end

-------------------------------------------------
-- StatusBar GetStatusBarTexture polyfill for WotLK
-- In WotLK, GetStatusBarTexture() can return nil immediately after SetStatusBarTexture
-- We wrap it to ensure it always returns a valid texture
-------------------------------------------------
do
    local sb = CreateFrame("StatusBar")
    local mt = getmetatable(sb)

    if mt and mt.__index then
        local origGetStatusBarTexture = mt.__index.GetStatusBarTexture
        local origSetStatusBarTexture = mt.__index.SetStatusBarTexture

        -- Wrap SetStatusBarTexture to cache the texture path
        if origSetStatusBarTexture then
            function mt.__index:SetStatusBarTexture(texture, layer, sublayer)
                self._cellCachedTexturePath = texture
                return origSetStatusBarTexture(self, texture, layer, sublayer)
            end
        end

        -- Wrap GetStatusBarTexture to ensure it returns a texture
        if origGetStatusBarTexture then
            function mt.__index:GetStatusBarTexture()
                local tex = origGetStatusBarTexture(self)
                -- If texture is nil but we have a cached path, try setting it again
                if not tex and self._cellCachedTexturePath then
                    origSetStatusBarTexture(self, self._cellCachedTexturePath)
                    tex = origGetStatusBarTexture(self)
                end
                return tex
            end
        end
    end
end

-------------------------------------------------
-- Retail unit API polyfills
-------------------------------------------------

if not UnitInOtherParty then
    -- Retail API: returns true if unit is in a different party/instance group.
    -- WotLK/Ascension doesn't have that concept, so just say "no".
    function UnitInOtherParty(unit)
        return false
    end
end

-- UnitHasIncomingResurrection
if not UnitHasIncomingResurrection then
    -- Retail API: returns true if unit has an incoming resurrection (like Battle Res)
    -- WotLK doesn't have this API, always return false
    function UnitHasIncomingResurrection(unit)
        return false
    end
end

-- UnitInPhase
if not UnitInPhase then
    -- Retail API: returns true if unit is in the same phase as player
    -- WotLK doesn't have this API or handles phasing differently, assume always in phase
    function UnitInPhase(unit)
        return true
    end
end

-- UnitGroupRolesAssigned
if not UnitGroupRolesAssigned then
    -- WotLK 3.3.5a NATIVE API: returns THREE BOOLEANS (isTank, isHealer, isDamage)
    -- This is DIFFERENT from Retail which returns a single string
    -- WotLK has role detection through GetRaidRosterInfo and LFG system
    
    -- Debug flag for role detection (toggle with /cell debug role)
    local roleDebugEnabled = false
    
    function UnitGroupRolesAssigned(unit)
        if not unit then return false, false, false end
        
        local isTank, isHealer, isDamage = false, false, false
        local roleSource = "none"

        -- For raid members, get role from GetRaidRosterInfo
        if UnitInRaid(unit) then
            for i = 1, GetNumRaidMembers() do
                -- GetRaidRosterInfo returns: name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole
                local name, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(i)
                local raidUnit = "raid" .. i

                if UnitIsUnit(unit, raidUnit) then
                    -- role is returned from GetRaidRosterInfo (from LFG/Dungeon Finder system or raid assignments)
                    if role and role ~= "NONE" and role ~= "" then
                        roleSource = "GetRaidRosterInfo"
                        -- Convert WotLK role format to booleans
                        if role == "MAINTANK" or role == "TANK" then
                            isTank = true
                        elseif role == "HEALER" then
                            isHealer = true
                        elseif role == "MAINASSIST" or role == "DAMAGER" or role == "DPS" then
                            isDamage = true
                        end
                    end
                    break
                end
            end
        end

        -- Fallback: Check party assignments (Main Tank/Main Assist)
        if not isTank and not isHealer and not isDamage then
            if GetPartyAssignment("MAINTANK", unit) then
                isTank = true
                roleSource = "MainTank assignment"
            elseif GetPartyAssignment("MAINASSIST", unit) then
                isDamage = true
                roleSource = "MainAssist assignment"
            end
        end
        
        -- Fallback: Use spec-based detection via LibGroupInfo
        if not isTank and not isHealer and not isDamage then
            local LibGroupInfo = LibStub and LibStub:GetLibrary("LibGroupInfo", true)
            if LibGroupInfo then
                local guid = UnitGUID(unit)
                if guid then
                    local cachedInfo = LibGroupInfo:GetCachedInfo(guid)
                    if cachedInfo then
                        -- GetCachedInfo returns a table with assignedRole and specRole fields
                        local specRole = cachedInfo.assignedRole or cachedInfo.specRole
                        if specRole and specRole ~= "NONE" then
                            roleSource = "LibGroupInfo (spec-based)"
                            if specRole == "TANK" then
                                isTank = true
                            elseif specRole == "HEALER" then
                                isHealer = true
                            elseif specRole == "DAMAGER" or specRole == "MELEE" or specRole == "RANGED" then
                                isDamage = true
                            end
                        end
                    end
                end
            end
        end
        
        -- Final fallback: Default to DAMAGER if still no role detected
        -- This helps on custom servers like Ascension where spec detection may not work
        if not isTank and not isHealer and not isDamage then
            isDamage = true
            roleSource = "default fallback"
        end
        
        -- Debug output
        if roleDebugEnabled then
            local roleName = isTank and "TANK" or isHealer and "HEALER" or "DAMAGER"
            print(string.format("[Role Debug] %s -> %s (source: %s)", 
                UnitName(unit) or unit, roleName, roleSource))
        end

        return isTank, isHealer, isDamage
    end
    
    -- Debug command toggle - create sFuncs table if needed
    if _G.Cell then
        _G.Cell.sFuncs = _G.Cell.sFuncs or {}
        _G.Cell.sFuncs.ToggleRoleDebug = function()
            roleDebugEnabled = not roleDebugEnabled
            print(string.format("[Cell] Role debug: %s", roleDebugEnabled and "enabled" or "disabled"))
        end
    end
end

-- UnitClassBase
if not UnitClassBase then
    -- Retail API: returns the class filename (e.g. "WARRIOR")
    -- WotLK: UnitClass returns (localizedName, fileName, classIndex)
    function UnitClassBase(unit)
        return select(2, UnitClass(unit))
    end
end

-- GetSpellBookItemName (doesn't exist in WotLK 3.3.5)
-- In WotLK, use GetSpellInfo(index, bookType) which returns name as first value
if not GetSpellBookItemName then
    function GetSpellBookItemName(index, bookType)
        local spellName = GetSpellInfo(index, bookType)
        return spellName
    end
end

-- Ambiguate (doesn't exist in WotLK 3.3.5)
-- In retail, Ambiguate formats player names by removing/keeping realm suffixes
-- In WotLK, we implement a simple version
if not Ambiguate then
    function Ambiguate(fullName, context)
        if not fullName then return "" end

        -- context values: "none", "short", "mail", "guild"
        -- For WotLK, we'll implement basic realm removal
        if context == "none" or context == "short" or context == "mail" then
            -- Remove realm suffix (everything after the hyphen)
            local name = string.match(fullName, "^([^%-]+)")
            return name or fullName
        end

        -- Default: return full name with realm
        return fullName
    end
end


-------------------------------------------------
-- StatusBar smoothing helpers polyfill
-------------------------------------------------
do
    local sb = CreateFrame("StatusBar")
    local mt = getmetatable(sb)

    if mt and mt.__index then
        if not mt.__index.SetSmoothedValue then
            function mt.__index:SetSmoothedValue(value)
                if self.SetValue then
                    self:SetValue(value)
                end
            end
        end

        if not mt.__index.SetMinMaxSmoothedValue then
            function mt.__index:SetMinMaxSmoothedValue(minVal, maxVal)
                if self.SetMinMaxValues then
                    self:SetMinMaxValues(minVal, maxVal)
                end
            end
        end

        if not mt.__index.ResetSmoothedValue then
            function mt.__index:ResetSmoothedValue()
                if self.GetValue and self.SetValue then
                    self:SetValue(self:GetValue())
                end
            end
        end
    end
end



-- Alpha animation SetFromAlpha / SetToAlpha polyfill for 3.3.5a
do
    -- create a sample alpha animation to grab its metatable
    local f  = CreateFrame("Frame")
    local ag = f:CreateAnimationGroup()
    local a  = ag:CreateAnimation("Alpha")
    local mt = getmetatable(a)

    if mt and mt.__index and not mt.__index.SetFromAlpha then
        -- weak tables to remember from/to per animation
        local alphaFrom = setmetatable({}, { __mode = "k" })
        local alphaTo   = setmetatable({}, { __mode = "k" })

        function mt.__index:SetFromAlpha(value)
            alphaFrom[self] = value
            local to = alphaTo[self]
            -- On WotLK, Alpha uses SetChange; approximate from/to with delta
            if to ~= nil and self.SetChange then
                self:SetChange(to - value)
            end
        end

        function mt.__index:SetToAlpha(value)
            alphaTo[self] = value
            local from = alphaFrom[self]
            if from ~= nil and self.SetChange then
                self:SetChange(value - from)
            end
        end
    end
end

-- HookScript polyfill for 3.3.5a

-- 1) Real hook for Frames (they have GetScript/SetScript)
do
    local f  = CreateFrame("Frame")
    local mt = getmetatable(f)

    if mt and mt.__index and not mt.__index.HookScript then
        function mt.__index:HookScript(scriptType, handler)
            if not self or type(scriptType) ~= "string" or type(handler) ~= "function" then
                return
            end

            -- Only makes sense if this object actually supports scripts
            local getScript = self.GetScript
            local setScript = self.SetScript
            if type(getScript) ~= "function" or type(setScript) ~= "function" then
                return
            end

            local prev = getScript(self, scriptType)
            if prev then
                setScript(self, scriptType, function(...)
                    prev(...)
                    handler(...)
                end)
            else
                setScript(self, scriptType, handler)
            end
        end
    end
end

-- 2) Delegate Texture:HookScript to its parent frame
do
    local tex = UIParent:CreateTexture()
    local mt  = getmetatable(tex)

    if mt and mt.__index and not mt.__index.HookScript then
        function mt.__index:HookScript(scriptType, handler)
            if type(scriptType) ~= "string" or type(handler) ~= "function" then
                return
            end

            local parent = self:GetParent()
            if parent then
                -- If parent already has a proper HookScript (either native or from the frame polyfill), use it
                if type(parent.HookScript) == "function" then
                    parent:HookScript(scriptType, handler)
                    return
                end

                -- If parent only has SetScript/GetScript, hook manually
                local getScript = parent.GetScript
                local setScript = parent.SetScript
                if type(getScript) == "function" and type(setScript) == "function" then
                    local prev = getScript(parent, scriptType)
                    if prev then
                        setScript(parent, scriptType, function(...)
                            prev(...)
                            handler(...)
                        end)
                    else
                        setScript(parent, scriptType, handler)
                    end
                    return
                end
            end

            -- Worst case: no scripts anywhere, just fire once so stuff like blink:Play() runs at least once
            handler(self)
        end
    end
end




-------------------------------------------------
-- SecureHandler_SetFrameRef polyfill
-- Ignore invalid/nil reference frames instead of erroring.
-------------------------------------------------
do
    if type(SecureHandler_SetFrameRef) == "function" and not _G._CellOrigSecureHandlerSetFrameRef then
        _G._CellOrigSecureHandlerSetFrameRef = SecureHandler_SetFrameRef

        function SecureHandler_SetFrameRef(self, refKey, refFrame)
            -- If refFrame is missing or not a frame-like table, just skip.
            if not refFrame or type(refFrame) ~= "table" or type(refFrame.GetName) ~= "function" then
                -- silently ignore bad refs
                return
            end

            return _G._CellOrigSecureHandlerSetFrameRef(self, refKey, refFrame)
        end
    end
end


-- Cooldown swipe API polyfill for 3.3.5a (no-op)
do
    local cd = CreateFrame("Cooldown")
    local mt = getmetatable(cd)

    if mt and mt.__index then
        if not mt.__index.SetSwipeTexture then
            function mt.__index:SetSwipeTexture(texture)
                -- No swipe layer in WotLK, ignore
            end
        end

        if not mt.__index.SetSwipeColor then
            function mt.__index:SetSwipeColor(r, g, b, a)
                -- Ignore
            end
        end

        if not mt.__index.SetDrawEdge then
            function mt.__index:SetDrawEdge(flag)
                -- Ignore
            end
        end

        if not mt.__index.SetDrawBling then
            function mt.__index:SetDrawBling(flag)
                -- Ignore
            end
        end

        if not mt.__index.SetHideCountdownNumbers then
            function mt.__index:SetHideCountdownNumbers(flag)
                -- Just ignore; WotLK cooldown text is separate anyway
            end
        end
    end
end


-- Cooldown OnCooldownDone polyfill for 3.3.5a (ignore unsupported script type)
do
    local cd = CreateFrame("Cooldown")
    local mt = getmetatable(cd)

    if mt and mt.__index and not mt.__index._CellOnCooldownDoneShim then
        local origSetScript = mt.__index.SetScript

        function mt.__index:SetScript(scriptType, handler)
            -- Retail-only script type; WotLK cooldowns don't support it
            if scriptType == "OnCooldownDone" then
                -- No native support in 3.3.5a; safely ignore
                return
            end

            return origSetScript(self, scriptType, handler)
        end

        mt.__index._CellOnCooldownDoneShim = true
    end
end


-- StatusBar:SetReverseFill polyfill for 3.3.5a (no-op)
do
    local f = CreateFrame("StatusBar")
    local mt = getmetatable(f)
    if mt and mt.__index and not mt.__index.SetReverseFill then
        function mt.__index:SetReverseFill(reverse)
            -- 3.3.5 has no reverse fill; ignore request
        end
    end
end


-------------------------------------------------
-- FlipBook / ParentKey / ChildKey polyfills
-------------------------------------------------

-- Textures: SetParentKey is Retail-only
do
    local tex = UIParent:CreateTexture()
    local mt  = getmetatable(tex)

    if mt and mt.__index and not mt.__index.SetParentKey then
        function mt.__index:SetParentKey(key)
            -- Retail uses this to bind the texture to a named child
            -- of a flipbook animation. WotLK has no concept of this,
            -- so just ignore it.
        end
    end
end

-- Animations: ChildKey + FlipBook-specific methods
do
    local f  = CreateFrame("Frame")
    local ag = f:CreateAnimationGroup()
    local a  = ag:CreateAnimation("Alpha")
    local mt = getmetatable(a)

    if mt and mt.__index then
        if not mt.__index.SetChildKey then
            function mt.__index:SetChildKey(key)
                -- No child-key routing in WotLK. Ignore.
            end
        end

        if not mt.__index.SetFlipBookFrames then
            function mt.__index:SetFlipBookFrames(frames)
                -- No flipbook system; ignore.
            end
        end

        if not mt.__index.SetFlipBookFrameWidth then
            function mt.__index:SetFlipBookFrameWidth(width)
                -- Ignore.
            end
        end

        if not mt.__index.SetFlipBookFrameHeight then
            function mt.__index:SetFlipBookFrameHeight(height)
                -- Ignore.
            end
        end

        if not mt.__index.SetFlipBookRows then
            function mt.__index:SetFlipBookRows(rows)
                -- Ignore; 3.3.5 doesn't know rows/columns.
            end
        end

        if not mt.__index.SetFlipBookColumns then
            function mt.__index:SetFlipBookColumns(columns)
                -- Ignore.
            end
        end
    end
end


-- AnimationGroup: map "FlipBook" → "Alpha" so CreateAnimation doesn't explode
do
    local f  = CreateFrame("Frame")
    local ag = f:CreateAnimationGroup()
    local mt = getmetatable(ag)

    if mt and mt.__index and type(mt.__index.CreateAnimation) == "function"
       and not mt.__index._CellFlipBookShim
    then
        local origCreateAnimation = mt.__index.CreateAnimation

        function mt.__index:CreateAnimation(animType, ...)
            if animType == "FlipBook" then
                -- 3.3.5 only knows Alpha/Translation/Scale/Rotation.
                animType = "Alpha"
            end
            return origCreateAnimation(self, animType, ...)
        end

        mt.__index._CellFlipBookShim = true
    end
end


-- CreateMaskTexture polyfill for 3.3.5a (Frame / StatusBar / Cooldown / Texture)
do
    local function addCreateMaskTexture(obj)
        local mt = getmetatable(obj)
        if not mt or type(mt.__index) ~= "table" then
            return
        end

        if not mt.__index.CreateMaskTexture then
            function mt.__index:CreateMaskTexture()
                -- 3.3.5a has no real mask textures; fake it with a hidden Frame (empty)
                -- We use a Frame instead of Texture to avoid the "white box" issue if SetTexture is called.
                local mask = CreateFrame("Frame", nil, self)
                mask:SetAllPoints(self)
                mask:EnableMouse(false) -- Ensure it doesn't block clicks
                
                -- Add dummy methods that Actions.lua expects on a Texture/Mask
                mask.SetTexture = function() end
                mask.SetRotated = function() end
                
                return mask
            end
        end
    end

    -- Patch the types we care about
    addCreateMaskTexture(CreateFrame("Frame"))
    addCreateMaskTexture(CreateFrame("StatusBar"))
    addCreateMaskTexture(CreateFrame("Cooldown"))
    addCreateMaskTexture(UIParent:CreateTexture())
end



-- Texture:AddMaskTexture polyfill for 3.3.5a (no-op)
do
    local t = UIParent:CreateTexture()
    local mt = getmetatable(t)
    if mt and mt.__index and not mt.__index.AddMaskTexture then
        function mt.__index:AddMaskTexture(mask)
            -- Ignore; real masking doesn't exist on 3.3.5
        end
    end
end

-- C_Timer - completely replace with working implementation for WotLK 3.3.5
-- WotLK has a broken C_Timer that causes errors in C_TimerAugment.lua
-- We completely replace it to avoid those errors
do
    local Ticker = {}
    Ticker.__index = Ticker

    function Ticker:Cancel()
        self._cancelled = true
    end

    function Ticker:IsCancelled()
        return self._cancelled
    end

    local function CreateTimer(duration, callback, isTicker)
        -- Validate arguments - use defaults instead of erroring
        if type(duration) ~= "number" then
            duration = 0.01 -- fallback to minimal duration
        end
        if type(callback) ~= "function" then
            callback = function() end -- no-op callback
        end

        local timer = setmetatable({}, Ticker)
        local total = 0
        local frame = CreateFrame("Frame")
        frame:SetScript("OnUpdate", function(self, elapsed)
            if timer:IsCancelled() then
                self:SetScript("OnUpdate", nil)
                return
            end
            total = total + elapsed
            if total >= duration then
                if isTicker then
                    total = 0
                    pcall(callback, timer) -- Protect callback execution
                else
                    self:SetScript("OnUpdate", nil)
                    pcall(callback) -- Protect callback execution
                end
            end
        end)
        return timer
    end

    -- Completely replace C_Timer (don't try to preserve native version)
    C_Timer = {
        After = function(durationOrSelf, callbackOrDuration, maybeCallback)
            -- Handle both C_Timer.After(duration, callback) and C_Timer:After(duration, callback)
            local duration, callback
            if type(durationOrSelf) == "table" and durationOrSelf == C_Timer then
                -- Called with colon syntax: C_Timer:After(duration, callback)
                duration = callbackOrDuration
                callback = maybeCallback
            else
                -- Called with dot syntax: C_Timer.After(duration, callback)
                duration = durationOrSelf
                callback = callbackOrDuration
            end
            CreateTimer(duration, callback, false)
        end,

        NewTimer = function(durationOrSelf, callbackOrDuration, maybeCallback)
            -- Handle both calling conventions
            local duration, callback
            if type(durationOrSelf) == "table" and durationOrSelf == C_Timer then
                duration = callbackOrDuration
                callback = maybeCallback
            else
                duration = durationOrSelf
                callback = callbackOrDuration
            end
            return CreateTimer(duration, callback, false)
        end,

        NewTicker = function(durationOrSelf, callbackOrDuration, iterationsOrCallback, maybeIterations)
            -- Handle both calling conventions
            local duration, callback, iterations
            if type(durationOrSelf) == "table" and durationOrSelf == C_Timer then
                duration = callbackOrDuration
                callback = iterationsOrCallback
                iterations = maybeIterations
            else
                duration = durationOrSelf
                callback = callbackOrDuration
                iterations = iterationsOrCallback
            end
            return CreateTimer(duration, callback, true)
        end
    }
end

-- C_Spell
if not C_Spell then
    C_Spell = {}
end

-- Retail: C_Spell.GetSpellInfo(spellID) → table { name, iconID, ... }
if not C_Spell.GetSpellInfo then
    function C_Spell.GetSpellInfo(spellId)
        local name, _, icon = GetSpellInfo(spellId)
        if not name then
            return nil
        end
        return {
            name   = name,
            iconID = icon,
        }
    end
end

if not C_Spell.GetSpellTexture then
    function C_Spell.GetSpellTexture(spellId)
        local _, _, icon = GetSpellInfo(spellId)
        return icon
    end
end

if not C_Spell.IsSpellInRange then
    function C_Spell.IsSpellInRange(spellId, unit)
        -- Retail uses spellID directly; 3.3.5 IsSpellInRange wants name
        local name = GetSpellInfo(spellId)
        if not name then return nil end
        return IsSpellInRange(name, unit)
    end
end

if not C_Spell.GetSpellCooldown then
    function C_Spell.GetSpellCooldown(spellId)
        -- Old API: start, duration, enabled
        -- Retail C_Spell: start, duration, enabled, modRate
        local start, duration, enabled = GetSpellCooldown(spellId)
        return start, duration, enabled, 1
    end
end

if not C_Spell.GetSpellLink then
    function C_Spell.GetSpellLink(spellId)
        return GetSpellLink(spellId)
    end
end

if not C_Spell.GetSpellCharges then
    function C_Spell.GetSpellCharges(spellId)
        -- 3.3.5 has no real charges → emulate “no charges” behavior
        return nil
    end
end

-- C_Item
if not C_Item then
    C_Item = {}
    function C_Item.IsItemInRange(itemId, unit)
        return IsItemInRange(itemId, unit)
    end
    function C_Item.IsUsableItem(itemId)
        return IsUsableItem(itemId)
    end
elseif not C_Item.IsUsableItem then
    function C_Item.IsUsableItem(itemId)
        return IsUsableItem(itemId)
    end
end

-------------------------------------------------
-- UnitAura safety wrapper for addons that pass bad params
-- WotLK errors on nil/empty unit or nil index/name; retail is lenient.
-------------------------------------------------
if not _G._CellOriginalUnitAura then
    _G._CellOriginalUnitAura = UnitAura
    function UnitAura(unit, indexOrName, ...)
        if not unit or unit == "" or indexOrName == nil then
            return
        end
        return _G._CellOriginalUnitAura(unit, indexOrName, ...)
    end
end

-------------------------------------------------
-- UnitBuff/UnitDebuff wrappers for Cell (NOT global overrides)
-- WotLK returns: name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, shouldConsolidate, spellId
-- Retail returns: name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId, ...
-- We create Cell-specific wrappers instead of modifying the global API
-------------------------------------------------
-- Store original functions for Cell to use
_G._CellOriginalUnitBuff = _G._CellOriginalUnitBuff or UnitBuff
_G._CellOriginalUnitDebuff = _G._CellOriginalUnitDebuff or UnitDebuff

-- Create Cell namespace wrappers (don't override global)
if Cell then
    Cell.UnitBuff = function(unit, index, filter)
        local name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, shouldConsolidate, spellId = _G._CellOriginalUnitBuff(unit, index, filter)
        if not name then return nil end
        -- Return in retail format: name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId
        return name, icon, count, debuffType, duration, expirationTime, caster, isStealable, nil, spellId, nil, nil, nil, nil, nil, nil
    end

    Cell.UnitDebuff = function(unit, index, filter)
        local name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, shouldConsolidate, spellId = _G._CellOriginalUnitDebuff(unit, index, filter)
        if not name then return nil end
        return name, icon, count, debuffType, duration, expirationTime, caster, isStealable, nil, spellId, nil, nil, nil, nil, nil, nil
    end
end

-- C_UnitAuras
if not C_UnitAuras then
    C_UnitAuras = {}
    function C_UnitAuras.GetAuraDataBySlot(unit, slot)
        -- This is a simplified mapping. Real C_UnitAuras returns a table.
        local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitAura(unit, slot)
        if name then
            return {
                name = name,
                icon = icon,
                count = count,
                debuffType = debuffType,
                duration = duration,
                expirationTime = expirationTime,
                sourceUnit = unitCaster,
                isStealable = isStealable,
                spellId = spellId,
                points = {} -- Placeholder
            }
        end
        return nil
    end

    function C_UnitAuras.GetAuraDataBySpellName(unit, spellName, filter)
        for i = 1, 40 do
            local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitAura(unit, i, filter)
            if not name then break end
            if name == spellName then
                return {
                    name = name,
                    icon = icon,
                    count = count,
                    debuffType = debuffType,
                    duration = duration,
                    expirationTime = expirationTime,
                    sourceUnit = unitCaster,
                    isStealable = isStealable,
                    spellId = spellId,
                    points = {} -- Placeholder
                }
            end
        end
        return nil
    end

    function C_UnitAuras.GetAuraSlots(unit, filter, maxSlots)
        -- WotLK polyfill: Iterate through auras and return slot table
        local slots = {}
        local index = 1
        local max = maxSlots or 40 -- Default max auras

        while index <= max do
            local name = UnitAura(unit, index, filter)
            if name then
                table.insert(slots, index)
                index = index + 1
            else
                break
            end
        end

        return slots
    end

    -- Stub functions for private aura anchors (retail feature not in WotLK)
    function C_UnitAuras.AddPrivateAuraAnchor(...)
        -- No-op in WotLK
        return nil
    end

    function C_UnitAuras.RemovePrivateAuraAnchor(...)
        -- No-op in WotLK
        return nil
    end
end

-- C_Map
if not C_Map then
    C_Map = {}
end

if not C_Map.GetBestMapForUnit then
    function C_Map.GetBestMapForUnit(unit)
        -- Very basic fallback - try GetCurrentMapAreaID if it exists
        if GetCurrentMapAreaID then
            return GetCurrentMapAreaID()
        end
        -- Otherwise return a safe default
        return 0
    end
end

-- C_ChatInfo
if not C_ChatInfo then
    C_ChatInfo = {}
    function C_ChatInfo.SendAddonMessage(prefix, text, channel, target)
        -- Avoid hard Lua errors if callers pass bad params (seen on some addons)
        if type(channel) ~= "string" or channel == "" then return end
        if channel == "WHISPER" and (not target or target == "") then return end
        if prefix == nil then prefix = "" end
        if text == nil then text = "" end
        SendAddonMessage(prefix, text, channel, target)
    end
    function C_ChatInfo.RegisterAddonMessagePrefix(prefix)
        -- In WotLK 3.3.5, addon message prefixes are automatically registered
        -- when first used with SendAddonMessage, so this is a no-op
        return true
    end
    function C_ChatInfo.SendAddonMessageLogged(prefix, text, channel, target)
        -- In WotLK 3.3.5, SendAddonMessageLogged doesn't exist
        -- Just use the regular SendAddonMessage
        return C_ChatInfo.SendAddonMessage(prefix, text, channel, target)
    end
end

-- RegisterAddonMessagePrefix polyfill (global function for WotLK)
if not RegisterAddonMessagePrefix then
    function RegisterAddonMessagePrefix(prefix)
        -- In WotLK 3.3.5, addon message prefixes are automatically registered
        -- when first used with SendAddonMessage, so this is a no-op
        return true
    end
end

-- BNSendGameData polyfill (Battle.net doesn't exist in WotLK 3.3.5)
if not BNSendGameData then
    function BNSendGameData(gameAccountID, addonPrefix, addonMessage)
        -- Battle.net game data messaging doesn't exist in WotLK
        -- This is a no-op to prevent errors from libraries that try to hook it
        return
    end
end

C_AddOns = C_AddOns or {}

-- Mirror the modern C_AddOns API to the classic global functions so other addons
-- can safely hook them (e.g. Details! calls hooksecurefunc on LoadAddOn).
if not C_AddOns.GetAddOnMetadata then
    function C_AddOns.GetAddOnMetadata(addon, field)
        if GetAddOnMetadata then
            return GetAddOnMetadata(addon, field)
        end
    end
end

if not C_AddOns.IsAddOnLoaded then
    function C_AddOns.IsAddOnLoaded(addon)
        if IsAddOnLoaded then
            return IsAddOnLoaded(addon)
        end
        return false
    end
end

if not C_AddOns.LoadAddOn then
    function C_AddOns.LoadAddOn(addon)
        if LoadAddOn then
            return LoadAddOn(addon)
        end
        return false, "MISSING"
    end
end

if not C_AddOns.GetNumAddOns then
    function C_AddOns.GetNumAddOns()
        if GetNumAddOns then
            return GetNumAddOns()
        end
        return 0
    end
end

if not C_AddOns.GetAddOnInfo then
    function C_AddOns.GetAddOnInfo(addonIndexOrName)
        if GetAddOnInfo then
            return GetAddOnInfo(addonIndexOrName)
        end
    end
end

if not C_AddOns.GetAddOnDependencies then
    function C_AddOns.GetAddOnDependencies(addonName)
        if GetAddOnDependencies then
            local deps = {GetAddOnDependencies(addonName)}
            if #deps > 0 then
                return deps
            end
        end
        return {}
    end
end

if not C_AddOns.GetAddOnEnableState then
    function C_AddOns.GetAddOnEnableState(character, addonName)
        if GetAddOnEnableState then
            return GetAddOnEnableState(character, addonName)
        end
        local enabled = C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName)
        return enabled and 1 or 0
    end
end

if not C_AddOns.EnableAddOn then
    function C_AddOns.EnableAddOn(addonName, characterName)
        if EnableAddOn then
            return EnableAddOn(addonName, characterName)
        end
        return false
    end
end

if not C_AddOns.DisableAddOn then
    function C_AddOns.DisableAddOn(addonName, characterName)
        if DisableAddOn then
            return DisableAddOn(addonName, characterName)
        end
        return false
    end
end

-- LoadAddOn polyfill (ensure it exists as a global function for other addons to hook)
if not LoadAddOn then
    -- WotLK has LoadAddOn, but it might not be available on all custom servers
    -- Create a basic implementation using the native API if it exists
    function LoadAddOn(addonName)
        -- Try to use native LoadAddOn if it exists (shouldn't happen, but safe)
        if _G._CellOriginalLoadAddOn then
            return _G._CellOriginalLoadAddOn(addonName)
        end
        -- Fallback: return false (addon not loaded)
        return false
    end
elseif type(LoadAddOn) ~= "function" then
    -- LoadAddOn exists but isn't a function (corrupted?), fix it
    local old = LoadAddOn
    function LoadAddOn(addonName)
        return false
    end
end

-- C_PvP
if not C_PvP then
    C_PvP = {}
    function C_PvP.IsBattleground()
        local inInstance, instanceType = IsInInstance()
        return instanceType == "pvp"
    end
end

-- C_TooltipInfo
if not C_TooltipInfo then
    C_TooltipInfo = {}
    function C_TooltipInfo.GetSpellByID(spellId)
        -- Placeholder, returns empty table or minimal info
        return { lines = {} }
    end
end

-- GameTooltip:SetSpellByID polyfill for WotLK 3.3.5a
do
    local tooltip = CreateFrame("GameTooltip")
    local mt = getmetatable(tooltip)
    if mt and mt.__index then
        -- FORCE overwrite to ensure we control it
        mt.__index.SetSpellByID = function(self, spellID)
            if not spellID then return end
            -- Try to get link
            local link = GetSpellLink(spellID)
            if link then
                self:SetHyperlink(link)
            else
                -- Fallback to SetSpell if link usually fails (though link is better)
                -- Or just clear if no link
                self:ClearLines()
            end
        end
    end
end

-- SOUNDKIT
if not SOUNDKIT then
    SOUNDKIT = {
        U_CHAT_SCROLL_BUTTON = "UChatScrollButton",
        IG_MAINMENU_OPTION_CHECKBOX_ON = "igMainMenuOptionCheckBoxOn",
        IG_MAINMENU_OPTION_CHECKBOX_OFF = "igMainMenuOptionCheckBoxOff",
        IG_MAINMENU_OPEN = "igMainMenuOpen",
        IG_MAINMENU_CLOSE = "igMainMenuClose",
        IG_ABILITY_PAGE_TURN = "igAbilityPageTurn",
        IG_CHARACTER_INFO_TAB = "igCharacterInfoTab",
        IG_BACKPACK_OPEN = "igBackPackOpen",
        IG_BACKPACK_CLOSE = "igBackPackClose",
    }
end

-- C_ClassTalents (Retail talent system, not in WotLK)
if not C_ClassTalents then
    C_ClassTalents = {}
    function C_ClassTalents.GetActiveConfigID()
        -- WotLK uses GetActiveTalentGroup() which returns 1 or 2
        return GetActiveTalentGroup()
    end
end

-- C_Traits (Retail talent tree system, not in WotLK)
if not C_Traits then
    C_Traits = {}
    function C_Traits.GetNodeInfo(configID, nodeID)
        -- WotLK doesn't have trait nodes
        -- Return nil to indicate node info not available
        return nil
    end
end

-- C_SpecializationInfo (MoP+ spec system, not in WotLK)
if not C_SpecializationInfo then
    C_SpecializationInfo = {}
    function C_SpecializationInfo.GetSpecialization()
        -- WotLK doesn't have specializations (added in MoP)
        -- Return nil to indicate no spec system
        return nil
    end
    function C_SpecializationInfo.GetSpecializationInfo(specIndex)
        -- Return nil to indicate no spec info available
        return nil
    end
end

-- C_NamePlate (Modern nameplate API, not in WotLK)
if not C_NamePlate then
    C_NamePlate = {}
    function C_NamePlate.GetNamePlates(issecure)
        -- WotLK has no nameplate API
        -- Return empty table
        return {}
    end
end

-------------------------------------------------
-- SecureHandlerStateTemplate:SetFrameRef polyfill
-- Ignore bad / nil reference frames instead of erroring.
-------------------------------------------------
do
    local ok, test = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
    if ok and test then
        local mt = getmetatable(test)
        if mt and mt.__index
           and type(mt.__index.SetFrameRef) == "function"
           and not mt.__index._CellSetFrameRefShim
        then
            local origSetFrameRef = mt.__index.SetFrameRef

            function mt.__index:SetFrameRef(refKey, refFrame)
                -- If the reference is missing or obviously not a frame, just ignore.
                if not refFrame or type(refFrame) ~= "table" or type(refFrame.GetName) ~= "function" then
                    return
                end
                return origSetFrameRef(self, refKey, refFrame)
            end

            mt.__index._CellSetFrameRefShim = true
        end
    end
end




-- Wrath: alias RegisterAttributeDriver/UnregisterAttributeDriver to StateDriver versions
if not RegisterAttributeDriver and RegisterStateDriver then
    function RegisterAttributeDriver(frame, attribute, state)
        return RegisterStateDriver(frame, attribute, state)
    end
end

if not UnregisterAttributeDriver and UnregisterStateDriver then
    function UnregisterAttributeDriver(frame, attribute)
        return UnregisterStateDriver(frame, attribute)
    end
end

-- GetNumClasses (doesn't exist in WotLK 3.3.5a)
if not GetNumClasses then
    function GetNumClasses()
        -- WotLK has 10 classes: Warrior, Paladin, Hunter, Rogue, Priest, Death Knight, Shaman, Mage, Warlock, Druid
        return 10
    end
end

-- Font constants (don't exist in WotLK 3.3.5a)
if not UNIT_NAME_FONT_CHINESE then
    -- Use standard WotLK font as fallback
    UNIT_NAME_FONT_CHINESE = "Fonts\\FRIZQT__.TTF"
end

-- User requested fonts
if not UNIT_NAME_FONT_KOREAN then
    UNIT_NAME_FONT_KOREAN = "Fonts\\FRIZQT__.TTF"
end
if not UNIT_NAME_FONT_ROMAN then
    UNIT_NAME_FONT_ROMAN = "Fonts\\FRIZQT__.TTF"
end

-- GetClassColor (doesn't exist in WotLK 3.3.5a)
if not GetClassColor then
    function GetClassColor(classFile)
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if color then
            return color.r, color.g, color.b, string.format("%02x%02x%02x%02x", 255, color.r * 255, color.g * 255, color.b * 255)
        end
        -- Fallback to white if class not found
        return 1, 1, 1, "ffffffff"
    end
end

-- Add GetRGB and GetRGBA methods to RAID_CLASS_COLORS entries in WotLK
-- In WotLK, these are simple tables without methods
if RAID_CLASS_COLORS then
    for class, color in pairs(RAID_CLASS_COLORS) do
        if type(color) == "table" and not color.GetRGB then
            function color:GetRGB()
                return self.r, self.g, self.b
            end
            function color:GetRGBA()
                return self.r, self.g, self.b, self.a or 1
            end
        end
    end
end

-- Difficulty constants (don't exist in WotLK 3.3.5a)
-- Mythic difficulty was added in later expansions
if not PLAYER_DIFFICULTY6 then
    PLAYER_DIFFICULTY6 = "Mythic"
end

-- MapUtil (doesn't exist in WotLK 3.3.5a)
if not MapUtil then
    MapUtil = {}
    function MapUtil.GetMapParentInfo(mapID, mapType, topMost)
        -- WotLK doesn't have the modern map system
        -- Return basic zone info using legacy API
        local zoneName = GetZoneText()
        if zoneName and zoneName ~= "" then
            return {
                name = zoneName,
                mapID = mapID or 0
            }
        end
        return nil
    end
end

-- Enum (doesn't exist in WotLK 3.3.5a)
if not Enum then
    Enum = {}
end

-- UIMapType enum (retail feature, doesn't exist in WotLK)
if not Enum.UIMapType then
    Enum.UIMapType = {
        Cosmic = 0,
        World = 1,
        Continent = 2,
        Zone = 3,
        Dungeon = 4,
        Micro = 5,
        Orphan = 6
    }
end

-- UnitIsGroupLeader (doesn't exist in WotLK 3.3.5a)
if not UnitIsGroupLeader then
    function UnitIsGroupLeader(unit)
        -- In WotLK, we need to check differently for party vs raid
        if UnitInRaid(unit) then
            -- In raid, check if unit is the raid leader
            if UnitIsUnit(unit, "player") then
                return IsRaidLeader()
            else
                -- For other units in raid, we can't directly check in WotLK
                -- This is a limitation of the WotLK API
                return false
            end
        else
            -- In party, check if unit is the party leader
            return UnitIsPartyLeader(unit)
        end
    end
end

-- UnitIsGroupAssistant (doesn't exist in WotLK 3.3.5a)
if not UnitIsGroupAssistant then
    function UnitIsGroupAssistant(unit)
        -- Only applies to raids in WotLK
        if UnitInRaid(unit) then
            if UnitIsUnit(unit, "player") then
                return IsRaidOfficer()
            else
                -- For other units in raid, we can't directly check in WotLK
                -- This is a limitation of the WotLK API
                return false
            end
        end
        return false
    end
end

-- PlaySound wrapper for WotLK compatibility
-- In WotLK 3.3.5a, PlaySound signature is different from retail
-- Store original PlaySound and wrap it to handle errors gracefully
do
    local _originalPlaySound = PlaySound
    if _originalPlaySound then
        PlaySound = function(soundKit, channel)
            -- In WotLK, PlaySound only takes soundFile/soundName, not soundKitID + channel
            -- Silently fail if sound doesn't work
            pcall(_originalPlaySound, soundKit)
        end
    end
end

-- GetNormalizedRealmName
-- In WotLK 3.3.5a (Ascension), this function exists but might be broken (calls nil 'Sub')
-- We overwrite it to ensure it works correctly
GetNormalizedRealmName = function()
    local realm = GetRealmName()
    if not realm then return "" end
    -- Remove spaces to normalize
    return string.gsub(realm, "%s+", "")
end

-- IsEncounterInProgress (doesn't exist in WotLK 3.3.5a)
-- Always override to ensure it exists
function IsEncounterInProgress()
    -- WotLK doesn't have encounter tracking API
    -- Return false to allow UI updates (no encounter in progress)
    return false
end

-- Group API polyfills
if not IsInRaid then
    function IsInRaid()
        return GetNumRaidMembers() > 0
    end
end

if not IsInGroup then
    function IsInGroup()
        return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
    end
end

-- GetNumGroupMembers polyfill (doesn't exist in WotLK 3.3.5a)
if not GetNumGroupMembers then
    function GetNumGroupMembers()
        if GetNumRaidMembers() > 0 then
            return GetNumRaidMembers()
        elseif GetNumPartyMembers() > 0 then
            return GetNumPartyMembers() + 1 -- +1 for player
        else
            return 1 -- Just player (solo)
        end
    end
end

-------------------------------------------------
-- GROUP_ROSTER_UPDATE Event Compatibility Layer
-- In WotLK 3.3.5a, GROUP_ROSTER_UPDATE doesn't exist.
-- Instead, we have PARTY_MEMBERS_CHANGED and RAID_ROSTER_UPDATE.
--
-- This global proxy provides a fallback for frames that may not
-- have been updated yet.
-------------------------------------------------
do
    -- Track frames that have registered GROUP_ROSTER_UPDATE handlers
    local groupRosterFrames = setmetatable({}, {__mode = "k"}) -- weak keys
    local function ProxyDebug(...)
        if _G.Cell and _G.Cell.funcs and _G.Cell.funcs.Debug then
            _G.Cell.funcs.Debug(...)
        else
            -- Fallback to plain print for early-load cases
            -- print("|cFF33CC33[Cell RosterProxy]|r", ...)
        end
    end

    -- The proxy frame that listens to actual WotLK events
    local proxyFrame = CreateFrame("Frame", "CellGroupRosterProxy")
    proxyFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    proxyFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    proxyFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
    proxyFrame:RegisterEvent("PARTY_MEMBER_DISABLE")

    local lastFireTime = 0
    proxyFrame:SetScript("OnEvent", function(self, event)

        -- Debounce to avoid firing multiple times per frame
        local DEBOUNCE_TIME = 0.1

        local now = GetTime()
        if now - lastFireTime < DEBOUNCE_TIME then
            return
        end
        lastFireTime = now
        local count = 0
        for _ in pairs(groupRosterFrames) do count = count + 1 end
        ProxyDebug("RosterProxy fired from", event, "dispatching to", tostring(count), "frames")

        -- Fire GROUP_ROSTER_UPDATE on all registered frames
        for frame in pairs(groupRosterFrames) do
            if frame then
                local handler = frame:GetScript("OnEvent")
                if handler then
                    -- Use pcall to prevent errors from breaking the loop
                    pcall(handler, frame, "GROUP_ROSTER_UPDATE")
                end
            end
        end
    end)
    
    -- Provide a way to register frames for the proxy
    function Cell_RegisterForGroupRosterProxy(frame)
        if frame then
            groupRosterFrames[frame] = true
            ProxyDebug("Registered frame for roster proxy:", frame:GetName() or tostring(frame))
        end
    end
    
    -- Provide a way to unregister frames from the proxy
    function Cell_UnregisterFromGroupRosterProxy(frame)
        if frame then
            groupRosterFrames[frame] = nil
            ProxyDebug("Unregistered frame from roster proxy:", frame:GetName() or tostring(frame))
        end
    end
    
    -- Provide a way to manually trigger GROUP_ROSTER_UPDATE (for init)
    function Cell_FireGroupRosterUpdate()
        for frame in pairs(groupRosterFrames) do
            if frame then
                local handler = frame:GetScript("OnEvent")
                if handler then
                    pcall(handler, frame, "GROUP_ROSTER_UPDATE")
                end
            end
        end
    end

    -- Automatically register frames that call RegisterEvent("GROUP_ROSTER_UPDATE")
    do
        local sample = CreateFrame("Frame")
        local mt = sample and getmetatable(sample)
        mt = mt and mt.__index
        if mt and mt.RegisterEvent and not mt._CellGroupRosterHook then
            hooksecurefunc(mt, "RegisterEvent", function(self, event)
                if event == "GROUP_ROSTER_UPDATE" then
                    Cell_RegisterForGroupRosterProxy(self)
                end
            end)

            hooksecurefunc(mt, "UnregisterEvent", function(self, event)
                if event == "GROUP_ROSTER_UPDATE" then
                    Cell_UnregisterFromGroupRosterProxy(self)
                end
            end)

            hooksecurefunc(mt, "UnregisterAllEvents", function(self)
                Cell_UnregisterFromGroupRosterProxy(self)
            end)

            mt._CellGroupRosterHook = true
        end
    end
end

-- LocalizedClassList
if not LocalizedClassList then
    function LocalizedClassList(gender)
        local t = {}
        for i = 1, GetNumClasses() do
            local name, tag, id = GetClassInfo(i)
            if tag then
                t[tag] = name
            end
        end
        return t
    end
end

-- Mixin
if not Mixin then
    function Mixin(object, ...)
        for i = 1, select("#", ...) do
            local mixin = select(i, ...)
            for k, v in pairs(mixin) do
                object[k] = v
            end
        end
        return object
    end
end

-------------------------------------------------
-- Frame/Widget SetEnabled polyfill for WotLK
-- In retail, frames/widgets have SetEnabled(bool) to enable/disable
-- In WotLK, use Enable() and Disable() methods instead
-------------------------------------------------
do
    local function addSetEnabled(obj)
        if not obj then return end
        local mt = getmetatable(obj)
        if mt and mt.__index and not mt.__index.SetEnabled then
            function mt.__index:SetEnabled(enabled)
                if enabled then
                    if self.Enable then
                        self:Enable()
                    end
                else
                    if self.Disable then
                        self:Disable()
                    end
                end
            end
        end
    end

    -- Add to various frame types (wrapped in pcall for safety)
    local function safeAdd(frameType)
        local ok, frame = pcall(CreateFrame, frameType)
        if ok and frame then
            addSetEnabled(frame)
        end
    end

    safeAdd("Frame")
    safeAdd("Slider")
    safeAdd("Button")
    safeAdd("CheckButton")
end

-------------------------------------------------
-- SimpleHTML GetContentHeight polyfill for WotLK
-- In retail, SimpleHTML frames have GetContentHeight() to get rendered height
-- In WotLK, we approximate this with GetHeight()
-------------------------------------------------
do
    -- Create a test SimpleHTML frame to get its metatable
    local testHTML = CreateFrame("SimpleHTML")
    local mt = getmetatable(testHTML)

    if mt and mt.__index and not mt.__index.GetContentHeight then
        function mt.__index:GetContentHeight()
            -- WotLK: SimpleHTML doesn't have GetContentHeight
            -- Fall back to GetHeight() which should give us the frame height
            return self:GetHeight() or 0
        end
    end
end

-------------------------------------------------
-- Slider OnValueChanged userChanged parameter polyfill for WotLK
-- In WotLK 3.3.5a, the userChanged parameter in OnValueChanged is always nil
-- We wrap SetValue to flag programmatic changes so callbacks can distinguish
-------------------------------------------------
do
    local slider = CreateFrame("Slider")
    local mt = getmetatable(slider)

    if mt and mt.__index and not mt.__index._CellSliderPolyfillApplied then
        local origSetValue = mt.__index.SetValue
        local origSetScript = mt.__index.SetScript

        -- Wrap SetValue to flag programmatic changes
        function mt.__index:SetValue(value)
            self._isProgrammaticChange = true
            origSetValue(self, value)
            self._isProgrammaticChange = false
        end

        -- Wrap SetScript to intercept OnValueChanged and fix userChanged parameter
        function mt.__index:SetScript(scriptType, handler)
            if scriptType == "OnValueChanged" and handler then
                local wrappedHandler = function(self, value, userChanged)
                    -- WRATH FIX: userChanged is nil in 3.3.5
                    if userChanged == nil then
                        userChanged = not self._isProgrammaticChange
                    end
                    return handler(self, value, userChanged)
                end
                return origSetScript(self, scriptType, wrappedHandler)
            end
            return origSetScript(self, scriptType, handler)
        end

        mt.__index._CellSliderPolyfillApplied = true
    end
end

-------------------------------------------------
-- REMOVED: All global font polyfills and hooks
-- They were masking the root cause, not fixing it
-------------------------------------------------

-------------------------------------------------
-- DEBUG: Track font modifications to find root cause
-------------------------------------------------
do
    local debugLog = {}
    local fs = UIParent:CreateFontString()
    local mt = getmetatable(fs)

    if mt and mt.__index and not mt.__index._CellDebugHooked then
        local origSetFont = mt.__index.SetFont
        local origSetFontObject = mt.__index.SetFontObject

        -- Hook SetFont to track who's modifying fonts
        mt.__index.SetFont = function(self, path, size, flags)
            local parent = self:GetParent()
            local parentName = parent and parent:GetName() or ""
            local selfName = self:GetName() or ""
            local caller = debugstack(2, 3, 0)

            -- ONLY alert if Cell is modifying NotPlater/Quartz/XPerl frames
            local isTargetAddon = parentName:match("Quartz") or parentName:match("NotPlater") or
                                 parentName:match("XPerl") or selfName:match("Quartz") or
                                 selfName:match("NotPlater") or selfName:match("XPerl")

            if isTargetAddon and caller:match("Cell_Wrath") then
                print(string.format("|cFFFF0000[Cell Debug]|r Cell modifying %s addon!",
                    parentName:match("Quartz") and "Quartz" or parentName:match("NotPlater") and "NotPlater" or "XPerl"))
                print("  Parent: " .. (parentName ~= "" and parentName or "nil"))
                print("  Self: " .. (selfName ~= "" and selfName or "nil"))
                print("  Size: " .. tostring(size))
                print("  Stack:\n" .. caller)

                table.insert(debugLog, {
                    time = GetTime(),
                    parent = parentName,
                    self = selfName,
                    path = path,
                    size = size,
                    flags = flags or "none",
                    caller = caller
                })
            end

            return origSetFont(self, path, size, flags)
        end

        -- Hook SetFontObject
        mt.__index.SetFontObject = function(self, fontObj)
            local parent = self:GetParent()
            local parentName = parent and parent:GetName() or ""
            local selfName = self:GetName() or ""
            local caller = debugstack(2, 3, 0)

            -- ONLY alert if Cell is modifying NotPlater/Quartz/XPerl frames
            local isTargetAddon = parentName:match("Quartz") or parentName:match("NotPlater") or
                                 parentName:match("XPerl") or selfName:match("Quartz") or
                                 selfName:match("NotPlater") or selfName:match("XPerl")

            if isTargetAddon and caller:match("Cell_Wrath") then
                print(string.format("|cFFFF0000[Cell Debug]|r Cell SetFontObject on %s addon!",
                    parentName:match("Quartz") and "Quartz" or parentName:match("NotPlater") and "NotPlater" or "XPerl"))
                print("  Parent: " .. (parentName ~= "" and parentName or "nil"))
                print("  Self: " .. (selfName ~= "" and selfName or "nil"))
                print("  FontObj: " .. tostring(fontObj))
                print("  Stack:\n" .. caller)
            end

            return origSetFontObject(self, fontObj)
        end

        mt.__index._CellDebugHooked = true

        -- Export debug log
        _G.CellDebugFontLog = debugLog

        -- Slash command
        SLASH_CELLDEBUG1 = "/celldebug"
        SlashCmdList["CELLDEBUG"] = function(msg)
            if msg == "fonts" then
                print("=== Cell Font Debug Log (" .. #debugLog .. " entries) ===")
                for i = math.max(1, #debugLog - 20), #debugLog do
                    local e = debugLog[i]
                    print(string.format("[%.2f] %s.%s size=%s",
                        e.time, e.parent, e.self, tostring(e.size)))
                    if e.caller:match("Cell_Wrath") then
                        print("  |cFFFF0000FROM CELL:|r " .. e.caller:match("[^\n]+"))
                    end
                end
            elseif msg == "clear" then
                wipe(debugLog)
                print("Debug log cleared")
            else
                print("Cell Debug: /celldebug fonts | clear")
            end
        end

        -- print("|cFF00FF00[Cell]|r Debug logging active. Use /celldebug fonts")
    end
end

-- Fonts
-- NOTE: Font objects are created in Widgets/Widgets.lua and Indicators/Built-in.lua
-- No need to pre-create them here since no code uses them before those files load
-- Removed redundant font creation that was causing conflicts with STANDARD_TEXT_FONT vs GameFontNormal

-------------------------------------------------
-- Frame :Run() polyfill for WotLK
-- In retail, frames in restricted execution have :Run() to execute Lua snippets
-- In WotLK, this doesn't exist, so we polyfill it
-------------------------------------------------
do
    local frame = CreateFrame("Frame")
    local mt = getmetatable(frame)

    if mt and mt.__index and not mt.__index.Run then
        function mt.__index:Run(snippet)
            if not snippet then return end

            -- In restricted execution, we need to execute the snippet
            -- Using loadstring with the restricted environment
            local func, err = loadstring(snippet)
            if func then
                -- Set the environment to use 'self' as the frame
                setfenv(func, setmetatable({self = self}, {__index = _G}))
                local success, execErr = pcall(func)
                if not success then
                    -- Silently fail in restricted context, just like retail
                    return
                end
            end
        end
    end
end

-------------------------------------------------
-- Ensure CellMainFrame is always shown
-- In WotLK, child frames won't show if parent is hidden
-------------------------------------------------
local function EnsureCellMainFrameShown()
    if CellMainFrame and not CellMainFrame:IsShown() then
        CellMainFrame:Show()
    end
end

-- Check immediately when addon loads and on events
local checkFrame = CreateFrame("Frame")
checkFrame:RegisterEvent("ADDON_LOADED")
checkFrame:RegisterEvent("PLAYER_LOGIN")
checkFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "Cell_Wrath" then
        -- Check after Cell loads
        C_Timer.After(0.1, EnsureCellMainFrameShown)
    elseif event == "PLAYER_LOGIN" then
        -- Check after login
        C_Timer.After(0.1, EnsureCellMainFrameShown)
    end
end)

-- Also check immediately
C_Timer.After(0.5, EnsureCellMainFrameShown)

-------------------------------------------------
-- Wrap PixelPerfect functions to handle nil frames gracefully
-- Some widgets may not exist in WotLK that exist in retail
-------------------------------------------------
-- Hook immediately when Cell.pixelPerfectFuncs is created
local function WrapPixelPerfectFunctions()
    if Cell and Cell.pixelPerfectFuncs and not Cell.pixelPerfectFuncs._CellWrapped then
        local P = Cell.pixelPerfectFuncs
        Cell.pixelPerfectFuncs._CellWrapped = true

        -- List of functions that take a frame as first parameter
        local frameFunctions = {
            "Repoint", "Resize", "ClearPoints", "Size", "Point",
            "Reborder", "Width", "Height", "PixelPerfectPoint"
        }

        for _, funcName in ipairs(frameFunctions) do
            if P[funcName] then
                local originalFunc = P[funcName]
                P[funcName] = function(frame, ...)
                    if not frame then
                        -- Silently ignore nil frames instead of erroring
                        return
                    end
                    return originalFunc(frame, ...)
                end
            end
        end
    end
end

-- Create event frame to wrap after addon loads
local pixelPerfectWrapperFrame = CreateFrame("Frame")
pixelPerfectWrapperFrame:RegisterEvent("ADDON_LOADED")
pixelPerfectWrapperFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Cell_Wrath" then
        -- Wrap immediately after addon loads
        WrapPixelPerfectFunctions()
        -- Also try with small delays
        C_Timer.After(0.1, WrapPixelPerfectFunctions)
        C_Timer.After(0.5, WrapPixelPerfectFunctions)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-------------------------------------------------
-- Wrap Cell.funcs.RotateTexture to handle nil textures
-- Some widgets may not exist in WotLK that exist in retail
-------------------------------------------------
C_Timer.After(0.1, function()
    if Cell and Cell.funcs and Cell.funcs.RotateTexture then
        local originalRotateTexture = Cell.funcs.RotateTexture
        Cell.funcs.RotateTexture = function(texture, angle)
            if not texture then return end
            return originalRotateTexture(texture, angle)
        end
    end
end)

-------------------------------------------------
-- Wrap Cell.bFuncs.SetOrientation to handle nil widgets
-- SpotlightFrame and other special frames may not have all widgets
-------------------------------------------------
local function WrapSetOrientation()
    if Cell and Cell.bFuncs and Cell.bFuncs.SetOrientation then
        local originalSetOrientation = Cell.bFuncs.SetOrientation
        Cell.bFuncs.SetOrientation = function(button, orientation, rotateTexture)
            -- Check if button is nil first
            if not button then
                -- Silently return if button is nil
                return
            end

            -- Get all the widgets (some may be nil)
            local widgets = button.widgets
            if not widgets then return end

            local healthBar = widgets.healthBar
            local powerBar = widgets.powerBar
            local gapTexture = widgets.gapTexture

            -- Check if this button has the minimum required widgets
            -- SpotlightFrame buttons don't have powerBar or gapTexture
            if not healthBar or not powerBar or not gapTexture then
                -- Skip SetOrientation for buttons without basic widgets
                return
            end

            -- Call original function
            return originalSetOrientation(button, orientation, rotateTexture)
        end
    else
        C_Timer.After(0.5, WrapSetOrientation)
    end
end

-- Wrap Cell.bFuncs.SetPowerSize to handle nil buttons
local function WrapSetPowerSize()
    if Cell and Cell.bFuncs and Cell.bFuncs.SetPowerSize then
        local originalSetPowerSize = Cell.bFuncs.SetPowerSize
        Cell.bFuncs.SetPowerSize = function(button, size)
            -- Check if button is nil first
            if not button then
                -- Silently return if button is nil (pet buttons might not exist)
                return
            end
            -- Call original function
            return originalSetPowerSize(button, size)
        end
    else
        C_Timer.After(0.5, WrapSetPowerSize)
    end
end

-- Create event frame to wrap after addon loads
local buttonFunctionsWrapperFrame = CreateFrame("Frame")
buttonFunctionsWrapperFrame:RegisterEvent("ADDON_LOADED")
buttonFunctionsWrapperFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Cell_Wrath" then
        -- Wrap SetOrientation
        WrapSetOrientation()
        C_Timer.After(0.1, WrapSetOrientation)
        C_Timer.After(0.5, WrapSetOrientation)
        C_Timer.After(1, WrapSetOrientation)

        -- Wrap SetPowerSize
        WrapSetPowerSize()
        C_Timer.After(0.1, WrapSetPowerSize)
        C_Timer.After(0.5, WrapSetPowerSize)
        C_Timer.After(1, WrapSetPowerSize)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-------------------------------------------------
-- AnimationGroup CreateAnimation compatibility wrapper
-- Ensures compatibility with DetailsWotlkPort and other addons
-- This prevents conflicts when other addons expect animation type to be a string
-------------------------------------------------
do
    local ag = UIParent:CreateAnimationGroup()
    local mt = getmetatable(ag)

    if mt and mt.__index and not mt.__index._CellAnimationPolyfillApplied then
        local origCreateAnimation = mt.__index.CreateAnimation

        if origCreateAnimation then
            function mt.__index:CreateAnimation(animationType, ...)
                -- Ensure animationType is always a string to prevent conflicts with other addon polyfills
                -- Some addons (like DetailsWotlkPort) expect this to never be nil
                animationType = animationType or "Animation"

                return origCreateAnimation(self, animationType, ...)
            end

            mt.__index._CellAnimationPolyfillApplied = true
        end
    end
end

-------------------------------------------------
-- Fix LibCustomGlow AutoCastGlow info initialization
-- Ensure info table is properly initialized before use
-------------------------------------------------
C_Timer.After(0.5, function()
    if LibStub then
        local LCG = LibStub("LibCustomGlow-1.0-Cell", true)
        if LCG and LCG.AutoCastGlow_Start then
            local origStart = LCG.AutoCastGlow_Start
            LCG.AutoCastGlow_Start = function(r, color, N, frequency, scale, xOffset, yOffset, key, frameLevel)
                -- Call original function
                origStart(r, color, N, frequency, scale, xOffset, yOffset, key, frameLevel)

                -- Ensure info fields are initialized
                key = key or ""
                local f = r["_AutoCastGlow"..key]
                if f and f.info then
                    -- Force initial size calculation
                    local width, height = f:GetSize()
                    if width and height and width > 0 and height > 0 then
                        f.info.width = width
                        f.info.height = height
                        f.info.perimeter = 2 * (width + height)
                        f.info.bottomlim = height * 2 + width
                        f.info.rightlim = height + width
                        f.info.space = f.info.perimeter / f.info.N
                    else
                        -- Frame not sized yet, set safe defaults to prevent nil errors
                        f.info.width = 0
                        f.info.height = 0
                        f.info.perimeter = 0
                        f.info.bottomlim = 0
                        f.info.rightlim = 0
                        f.info.space = 0
                    end
                end
            end
        end
    end
end)

-------------------------------------------------
-- Click-Castings Fixes
-------------------------------------------------
do


    -- Fix 1: ScrollFrame eats clicks
    function PatchCreateScrollFrame()
        if not Cell or not Cell.CreateScrollFrame then return end
        if Cell._ScrollFramePatchedForBindings then return end
        Cell._ScrollFramePatchedForBindings = true

        local orig_CreateScrollFrame = Cell.CreateScrollFrame
        Cell.CreateScrollFrame = function(parent, top, bottom, color, border)
            local ret = orig_CreateScrollFrame(parent, top, bottom, color, border)

            if parent:GetName() == "ClickCastingsTab_BindingsFrame" then
                local scroll = parent.scrollFrame
                if scroll then
                    if scroll.EnableMouse then scroll:EnableMouse(false) end
                    if scroll.content and scroll.content.EnableMouse then scroll.content:EnableMouse(true) end
                end
            end
            
            return ret
        end
    end

    -- Fix 2: BindingListButton grids have too low frame level (6 vs 530+)
    function PatchBindingListButton()
        if not Cell or not Cell.CreateBindingListButton then return end
        if Cell._BindingListButtonPatched then return end
        Cell._BindingListButtonPatched = true

        local orig_CreateBindingListButton = Cell.CreateBindingListButton
        Cell.CreateBindingListButton = function(parent, modifier, bindKey, bindType, bindAction)
            local b = orig_CreateBindingListButton(parent, modifier, bindKey, bindType, bindAction)
            
            -- Fix frame levels of grids
            local level = b:GetFrameLevel() + 1
            if b.keyGrid then b.keyGrid:SetFrameLevel(level) end
            if b.typeGrid then b.typeGrid:SetFrameLevel(level) end
            if b.actionGrid then b.actionGrid:SetFrameLevel(level) end
            
            return b
        end
    end

    -- Fix 3: GetClickCastingSpellList fails with mixed-case class names
    local function PatchGetClickCastingSpellList()
        if not Cell or not Cell.funcs or not Cell.funcs.GetClickCastingSpellList then return end
        if Cell._GetClickCastingSpellListPatched then return end
        Cell._GetClickCastingSpellListPatched = true

        local orig_GetClickCastingSpellList = Cell.funcs.GetClickCastingSpellList
        Cell.funcs.GetClickCastingSpellList = function(class)
            if class and type(class) == "string" then
                class = string.upper(class)
            end
            return orig_GetClickCastingSpellList(class)
        end
    end

    -- Fix 4: Animation system missing SetScaleFrom/To, SetFromAlpha/ToAlpha
    local function PatchAnimationSystem()
        if Cell._AnimationSystemPatched then return end
        Cell._AnimationSystemPatched = true

        local f = CreateFrame("Frame")
        local ag = f:CreateAnimationGroup()
        local mt = getmetatable(ag)
        local orig_CreateAnimation = mt.__index.CreateAnimation

        -- Hook AnimationGroup:Play to ensure "From" values are applied
        if not mt.__index._CellPlayHook then
            local orig_Play = mt.__index.Play
            mt.__index.Play = function(self)
                -- Apply "From" state for all custom-tracked animations
                if self._cellAnimations then
                    for _, anim in ipairs(self._cellAnimations) do
                        if anim._ApplyFromState then
                            anim:_ApplyFromState()
                        end
                    end
                end
                
                if orig_Play then 
                    orig_Play(self) 
                end
            end
            mt.__index._CellPlayHook = true
        end

        mt.__index.CreateAnimation = function(self, type, name, inherits)
            -- DetailsWotlkPort crashes if name is nil, so we must provide a default
            if not name then name = type end
            
            local anim = orig_CreateAnimation(self, type, name, inherits)
            
            -- Track animation in the group
            if not self._cellAnimations then self._cellAnimations = {} end
            table.insert(self._cellAnimations, anim)

            if type == "Alpha" then
                anim.SetFromAlpha = function(self, from)
                    self._fromAlpha = from
                    self:_UpdateAlpha()
                end
                anim.SetToAlpha = function(self, to)
                    self._toAlpha = to
                    self:_UpdateAlpha()
                end
                anim._UpdateAlpha = function(self)
                    local from = self._fromAlpha or 1
                    local to = self._toAlpha or 1
                    -- Calculate change for WotLK
                    if self.SetChange then
                        self:SetChange(to - from)
                    end
                end
                anim._ApplyFromState = function(self)
                    if self._fromAlpha then
                        local region = self:GetParent():GetParent()
                        if region and region.SetAlpha then
                            region:SetAlpha(self._fromAlpha)
                        end
                    end
                    -- Re-apply change in case it was lost
                    self:_UpdateAlpha()
                end
                
                anim:HookScript("OnPlay", function()
                    anim:_ApplyFromState()
                end)

            elseif type == "Scale" then
                anim.SetScaleFrom = function(self, x, y)
                    self._fromX = x
                    self._fromY = y
                    self:_UpdateScale()
                end
                anim.SetScaleTo = function(self, x, y)
                    self._toX = x
                    self._toY = y
                    self:_UpdateScale()
                end
                anim._UpdateScale = function(self)
                    local fromX = self._fromX or 1
                    local fromY = self._fromY or 1
                    local toX = self._toX or 1
                    local toY = self._toY or 1
                    
                    if fromX == 0 then fromX = 0.001 end
                    if fromY == 0 then fromY = 0.001 end
                    
                    if self.SetScale then
                        self:SetScale(toX / fromX, toY / fromY)
                    end
                end
                anim._ApplyFromState = function(self)
                     -- Apply initial scale to the target region
                    if self._fromX or self._fromY then
                        local region = self:GetParent():GetParent()
                        if region and region.SetScale then
                            local startScale = math.max(self._fromX or 0, self._fromY or 0)
                            if startScale <= 0.001 then startScale = 0.001 end -- Prevent 0 scale issues
                            region:SetScale(startScale)
                        end
                    end
                    -- Re-apply change
                    self:_UpdateScale()
                end
                
                anim:HookScript("OnPlay", function()
                    anim:_ApplyFromState()
                end)
            end
            
            return anim
        end
    end

    -- Fix 5: LibCustomGlow acUpdate crash (attempt to perform arithmetic on field 'space' (a nil value))
    local function PatchLibCustomGlow()
        local lib = LibStub and LibStub("LibCustomGlow-1.0-Cell", true)
        if not lib then return end
        if Cell._LibCustomGlowPatched then return end
        Cell._LibCustomGlowPatched = true

        local function SafeAcUpdate(self, elapsed)
            local width, height = self:GetSize()
            if width ~= self.info.width or height ~= self.info.height or not self.info.space then
                if width * height == 0 then return end -- Avoid division by zero
                self.info.width = width
                self.info.height = height
                self.info.perimeter = 2 * (width + height)
                self.info.bottomlim = height * 2 + width
                self.info.rightlim = height + width
                self.info.space = self.info.perimeter / self.info.N
            end
        
            local texIndex = 0
            for k = 1, 4 do
                self.timer[k] = self.timer[k] + elapsed / (self.info.period * k)
                if self.timer[k] > 1 or self.timer[k] < -1 then
                    self.timer[k] = self.timer[k] % 1
                end
                for i = 1, self.info.N do
                    texIndex = texIndex + 1
                    if self.textures[texIndex] then
                        local position = (self.info.space * i + self.info.perimeter * self.timer[k]) % self.info.perimeter
                        if position > self.info.bottomlim then
                            self.textures[texIndex]:SetPoint("CENTER", self, "BOTTOMRIGHT", -position + self.info.bottomlim, 0)
                        elseif position > self.info.rightlim then
                            self.textures[texIndex]:SetPoint("CENTER", self, "TOPRIGHT", 0, -position + self.info.rightlim)
                        elseif position > self.info.height then
                            self.textures[texIndex]:SetPoint("CENTER", self, "TOPLEFT", position - self.info.height, 0)
                        else
                            self.textures[texIndex]:SetPoint("CENTER", self, "BOTTOMLEFT", 0, position)
                        end
                    end
                end
            end
        end

        local orig_AutoCastGlow_Start = lib.AutoCastGlow_Start
        lib.AutoCastGlow_Start = function(r, color, N, frequency, scale, xOffset, yOffset, key, frameLevel)
            orig_AutoCastGlow_Start(r, color, N, frequency, scale, xOffset, yOffset, key, frameLevel)
            
            key = key or ""
            local f = r["_AutoCastGlow" .. key]
            if f then
                f:SetScript("OnUpdate", SafeAcUpdate)
            end
        end
        
        -- Also update the startList entry
        if lib.startList then
            lib.startList["Autocast Shine"] = lib.AutoCastGlow_Start
        end
    end

    -- Add to the event handler
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Cell_Wrath" then
            PatchCreateScrollFrame()
            PatchBindingListButton()
            PatchGetClickCastingSpellList()
            PatchAnimationSystem()
            PatchLibCustomGlow()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)

end

-------------------------------------------------
-- WotLK 3.3.5a: IsEveryoneAssistant doesn't exist
-------------------------------------------------
if not IsEveryoneAssistant then
    _G.IsEveryoneAssistant = function()
        return GetNumGroupMembers() > 0 and GetRaidRosterInfo(1) == nil
    end
end

-------------------------------------------------
-- WotLK 3.3.5a: Button creation and positioning now handled inline in PartyFrame.lua and RaidFrame.lua
-------------------------------------------------

-------------------------------------------------
-- BackdropTemplate polyfill for WotLK 3.3.5a
-- In Wrath, backdrop functions (SetBackdrop, SetBackdropColor, etc.) are natively
-- available on all frames. However, the BackdropTemplate itself doesn't exist.
-- In retail 9.0.1+, Blizzard moved these functions into BackdropTemplate.
-- We create an empty template here so CreateFrame(..., "BackdropTemplate") doesn't error.
-------------------------------------------------
if not BackdropTemplateMixin then
    -- Create an empty mixin (backdrop functions already exist natively in Wrath)
    BackdropTemplateMixin = {}
end
