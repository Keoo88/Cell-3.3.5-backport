local _, Cell = ...
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs
local A = Cell.animations

local orientation, speed

-------------------------------------------------
-- events
-------------------------------------------------
-- CLEU: subevent, source, target, spellId, spellName
-- [15:10] SPELL_HEAL 秋静葉 秋静葉 6262 治疗石
-- [15:10] SPELL_CAST_SUCCESS 秋静葉 nil 6262 治疗石
-- [15:13] SPELL_HEAL 秋静葉 秋静葉 307192 灵魂治疗药水
-- [15:13] SPELL_CAST_SUCCESS 秋静葉 nil 307192 灵魂治疗药水

-- UNIT_SPELLCAST_SUCCEEDED
-- unit, castGUID, spellID

local function Display(b, ...)
    b.indicators.actions:Display(...)
end

--! WotLK perf: 3.3.5 gives UNIT_SPELLCAST_SUCCEEDED a spell NAME, not an id, so the
--! configured actions have to be searched by name. Doing that as a linear scan meant
--! one GetSpellInfo() call per configured action on every successful cast of every
--! group member - GetSpellInfo returns seven values including two strings, so a 25-man
--! raid turned it into constant string churn on Lua 5.1 without JIT. Resolve through a
--! name -> id map built once instead. I.ConvertActions() returns a brand-new table on
--! every call and the three assignment sites (Core_Wrath, Indicators, Import) never
--! mutate it in place, so table identity is an exact invalidation key. First id wins,
--! matching the previous "break on first pairs() hit" for spells whose ranks share a
--! name.
local actionNameToID, actionNameSource
local function ResolveActionSpellID(spellName)
    local actions = Cell.vars.actions
    if not actions or not spellName then return nil end
    if actionNameSource ~= actions then
        actionNameToID = {}
        for id in pairs(actions) do
            local name = GetSpellInfo(id)
            if name and actionNameToID[name] == nil then
                actionNameToID[name] = id
            end
        end
        actionNameSource = actions
    end
    return actionNameToID[spellName]
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, unit, arg2, arg3)
    -- filter out players not in your group
    if not (UnitInRaid(unit) or UnitInParty(unit) or unit == "player" or unit == "pet") then return end

    -- WotLK/Cata/Vanilla: unit, spellName, rank
    local spellName = arg2
    local spellID = ResolveActionSpellID(spellName)

    if Cell.vars.actionsDebugModeEnabled then
        print("|cFFFF3030[Cell]|r |cFFB2B2B2" .. event .. ":|r", unit, "|cFF00FF00" .. (spellName or "nil") .. "|r", "-> ID:", spellID or "Not Found")
    end

    if spellID and Cell.vars.actions[spellID] then
        F.HandleUnitButton("unit", unit, Display, unpack(Cell.vars.actions[spellID]))
    end
end)

--! WotLK note: if this debug block is ever revived, parse native 3.3.5 CLEU
--! varargs directly; do not bind it to a global ClassicAPI translator.
-- eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
-- eventFrame:SetScript("OnEvent", function(_, _, ...)
--     local timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName = ...
--     print(subevent, sourceName, destName, spellId, spellName)
-- end)

-------------------------------------------------
-- pool
-------------------------------------------------
local animationPool = {}

--! WotLK fix: Actions owns the only object-pool contract it needs. Do not bind
--! Cell's animation hot path to the global CreateObjectPool supplied either by
--! embedded ClassicAPI or by a standalone !!!ClassicAPI loaded for Gladdy.
local function CreateCellObjectPool(creationFunc, resetterFunc)
    local pool = {
        activeObjects = {},
        inactiveObjects = {},
    }

    function pool:Acquire()
        local index = #self.inactiveObjects
        local object
        local isNew

        if index > 0 then
            object = self.inactiveObjects[index]
            self.inactiveObjects[index] = nil
            isNew = false
        else
            object = creationFunc(self)
            isNew = true
            if resetterFunc then
                resetterFunc(self, object)
            end
        end

        self.activeObjects[object] = true
        return object, isNew
    end

    function pool:Release(object)
        if not self.activeObjects[object] then return false end

        self.activeObjects[object] = nil
        if resetterFunc then
            resetterFunc(self, object)
        end
        self.inactiveObjects[#self.inactiveObjects + 1] = object
        return true
    end

    return pool
end

local function ResetterFunc(_, canvas)
    canvas:Hide()
end

-------------------------------------------------
-- animation: A
-------------------------------------------------
local function CreateAnimationGroup_TypeA()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexture(Cell.vars.whiteTexture)

    --! WotLK fix: native 3.3.5 has no mask regions. Keep the animated texture
    --! on its Cell-owned canvas instead of relying on a fake shared mask API.
    canvas:EnableMouse(false)
    f:EnableMouse(false)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.6
    --! WotLK fix: use Cell's private absolute-alpha driver; do not modify shared Alpha methods.
    A.SetAbsoluteAlpha(a1, 0, 1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local t1 = ag:CreateAnimation("Translation")
    t1.duration = 0.6
    t1:SetOrder(1)
    t1:SetSmoothing("OUT")
    t1:SetDuration(t1.duration)

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    A.SetAbsoluteAlpha(a2, 1, 0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    -- a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.A:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        if parent.orientation == "horizontal" then
            f:SetPoint("TOPRIGHT", canvas, "TOPLEFT")
            f:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT")
            f:SetWidth(15)

            t1:SetOffset(canvas:GetWidth(), 0)
            -- tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
            -- tex:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, 1)
            tex:SetVertexColor(r, g, b, 1)
        else
            f:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT")
            f:SetPoint("TOPRIGHT", canvas, "BOTTOMRIGHT")
            f:SetHeight(15)

            t1:SetOffset(0, canvas:GetHeight())
            -- tex:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
            -- tex:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 1)
            tex:SetVertexColor(r, g, b, 1)
        end

        a1:SetDuration(a1.duration / parent.speed)
        t1:SetDuration(t1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        if ag:IsPlaying() then
            --! WotLK fix: AnimationGroup:Restart is not native on 3.3.5; keep
            --! the restart behavior private to this Cell-owned animation.
            ag:Stop()
        end
        ag:Play()
    end

    return canvas
end

animationPool.A = CreateCellObjectPool(CreateAnimationGroup_TypeA, ResetterFunc)

-------------------------------------------------
-- animation: B
-------------------------------------------------
local function CreateAnimationGroup_TypeB()
    local WIDTH = 20

    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetPoint("TOPRIGHT", canvas, "TOPLEFT")
    f:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT")
    f:SetWidth(WIDTH)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("BOTTOMRIGHT")
    tex:SetWidth(WIDTH)
    -- tex:SetRotation(45 * math.pi / 180, CreateVector2D(1, 0))
    if tex.SetRotation then
        tex:SetRotation(45 * math.pi / 180) -- WotLK SetRotation takes radians, no pivot vector
    end

    --! WotLK fix: native 3.3.5 has no mask regions. Keep the animated texture
    --! on its Cell-owned canvas instead of relying on a fake shared mask API.
    canvas:EnableMouse(false)
    f:EnableMouse(false)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.35
    --! WotLK fix: use Cell's private absolute-alpha driver; do not modify shared Alpha methods.
    A.SetAbsoluteAlpha(a1, 0, 0.7)
    a1:SetDuration(a1.duration)
    -- a1:SetSmoothing("IN")

    local t1 = ag:CreateAnimation("Translation")
    t1.duration = 0.7
    t1:SetSmoothing("IN_OUT")
    t1:SetDuration(t1.duration)

    -- local a2 = ag:CreateAnimation("Alpha")
    -- a2.duration = 0.3
    -- a2:SetFromAlpha(0.7)
    -- a2:SetToAlpha(0)
    -- a2:SetDuration(a2.duration)
    -- a2:SetStartDelay(t1.duration - a2.duration)

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.B:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        a1:SetDuration(a1.duration / parent.speed)
        t1:SetDuration(t1.duration / parent.speed)

        t1:SetOffset(canvas:GetWidth() + math.tan(math.pi / 4) * canvas:GetHeight() + WIDTH / math.cos(math.pi / 4), 0)
        tex:SetHeight(canvas:GetHeight() / math.sin(math.pi / 4) + WIDTH)
        -- tex:SetTexture(r, g, b)
        tex:SetTexture(Cell.vars.whiteTexture)
        tex:SetVertexColor(r, g, b, 1)

        if ag:IsPlaying() then
            --! WotLK fix: AnimationGroup:Restart is not native on 3.3.5; keep
            --! the restart behavior private to this Cell-owned animation.
            ag:Stop()
        end
        ag:Play()
    end

    return canvas
end

animationPool.B = CreateCellObjectPool(CreateAnimationGroup_TypeB, ResetterFunc)

-------------------------------------------------
-- animation: C
-------------------------------------------------
local function CreateAnimationGroup_TypeC()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\upgrade.tga")

    canvas:EnableMouse(false)
    f:EnableMouse(false)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.5
    --! WotLK fix: use Cell's private absolute-alpha driver; do not modify shared Alpha methods.
    A.SetAbsoluteAlpha(a1, 0, 1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local t1 = ag:CreateAnimation("Translation")
    t1.duration = 0.5
    t1:SetOrder(1)
    t1:SetSmoothing("OUT")
    t1:SetDuration(t1.duration)

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    A.SetAbsoluteAlpha(a2, 1, 0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.C:Release(canvas)
    end)

    function ag:Display(parent, subType, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        f:ClearAllPoints()
        if subType == "1" then
            f:SetPoint("BOTTOMLEFT")
            f:SetPoint("TOPLEFT", canvas, "LEFT")
        elseif subType == "2" then
            f:SetPoint("BOTTOM")
            f:SetPoint("TOP", canvas, "CENTER")
        else
            f:SetPoint("BOTTOMRIGHT")
            f:SetPoint("TOPRIGHT", canvas, "RIGHT")
        end

        a1:SetDuration(a1.duration / parent.speed)
        t1:SetDuration(t1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        f:SetWidth(canvas:GetHeight() / 2)
        t1:SetOffset(0, canvas:GetHeight() / 2)
        -- tex:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
        -- tex:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 1)
        tex:SetVertexColor(r, g, b, 1)

        if ag:IsPlaying() then
            --! WotLK fix: AnimationGroup:Restart is not native on 3.3.5; keep
            --! the restart behavior private to this Cell-owned animation.
            ag:Stop()
        end
        ag:Play()
    end

    return canvas
end

animationPool.C = CreateCellObjectPool(CreateAnimationGroup_TypeC, ResetterFunc)

-------------------------------------------------
-- animation: D
-------------------------------------------------
local function CreateAnimationGroup_TypeD()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetAllPoints(canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("CENTER")

    --! WotLK fix: Texture masks are unavailable on 3.3.5. The circular source
    --! art already supplies the required shape; the canvas owns its clipping.
    tex:SetTexture("Interface/AddOns/Cell/Media/Shapes/circle_filled_256")

    canvas:EnableMouse(false)
    f:EnableMouse(false)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.3
    --! WotLK fix: use Cell's private absolute-alpha driver; do not modify shared Alpha methods.
    A.SetAbsoluteAlpha(a1, 0, 1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local s1 = ag:CreateAnimation("Scale")
    s1.duration = 0.5
    --! WotLK fix: WotLK Scale is relative; drive Cell's absolute 0 -> 1 scale privately.
    A.SetAbsoluteScale(s1, 0, 1)
    s1:SetOrder(1)
    s1:SetDuration(s1.duration)

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    A.SetAbsoluteAlpha(a2, 1, 0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.D:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        a1:SetDuration(a1.duration / parent.speed)
        s1:SetDuration(s1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        local l = math.sqrt((parent:GetParent():GetHeight() / 2) ^ 2 + (parent:GetParent():GetWidth() / 2) ^ 2) * 2
        tex:SetSize(l, l)
        tex:SetTexture("Interface/AddOns/Cell/Media/Shapes/circle_filled_256")
        tex:SetVertexColor(r, g, b, 0.6)

        if ag:IsPlaying() then
            --! WotLK fix: AnimationGroup:Restart is not native on 3.3.5; keep
            --! the restart behavior private to this Cell-owned animation.
            ag:Stop()
        end
        ag:Play()
    end

    return canvas
end

animationPool.D = CreateCellObjectPool(CreateAnimationGroup_TypeD, ResetterFunc)

-------------------------------------------------
-- animation: E
-------------------------------------------------
local function CreateAnimationGroup_TypeE()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetPoint("TOPRIGHT", canvas, "TOPLEFT")
    f:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT")

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexture("Interface/AddOns/Cell/Media/Icons/arrow.tga")

    --! WotLK fix: the translated arrow uses its own alpha channel and does not
    --! require a fake mask region on 3.3.5.
    canvas:EnableMouse(false)
    f:EnableMouse(false)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    -- local a1 = ag:CreateAnimation("Alpha")
    -- a1:SetFromAlpha(0)
    -- a1:SetToAlpha(0.7)
    -- a1:SetDuration(0.3)
    -- a1:SetSmoothing("OUT")

    local t1 = ag:CreateAnimation("Translation")
    t1.duration = 0.8
    t1:SetSmoothing("IN_OUT")
    t1:SetDuration(t1.duration)

    -- local a2 = ag:CreateAnimation("Alpha")
    -- a2:SetFromAlpha(0.7)
    -- a2:SetToAlpha(0)
    -- a2:SetDuration(0.3)
    -- a2:SetStartDelay(0.5)
    -- a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.E:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        t1:SetDuration(t1.duration / parent.speed)

        local l = canvas:GetHeight() * 2
        f:SetWidth(l)
        t1:SetOffset(l + canvas:GetWidth(), 0)

        tex:SetVertexColor(r, g, b, 0.6)

        if ag:IsPlaying() then
            --! WotLK fix: AnimationGroup:Restart is not native on 3.3.5; keep
            --! the restart behavior private to this Cell-owned animation.
            ag:Stop()
        end
        ag:Play()
    end

    return canvas
end

animationPool.E = CreateCellObjectPool(CreateAnimationGroup_TypeE, ResetterFunc)

-------------------------------------------------
-- animation: F
-------------------------------------------------
local function CreateAnimationGroup_TypeF()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetAllPoints(canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("CENTER")

    --! WotLK fix: use the heart art directly; its alpha channel replaces the
    --! retail mask while the Cell-owned canvas provides the animation bounds.
    tex:SetTexture("Interface/AddOns/Cell/Media/Shapes/heart_filled_256")

    canvas:EnableMouse(false)
    f:EnableMouse(false)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.3
    --! WotLK fix: use Cell's private absolute-alpha driver; do not modify shared Alpha methods.
    A.SetAbsoluteAlpha(a1, 0, 1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local s1 = ag:CreateAnimation("Scale")
    s1.duration = 0.5
    --! WotLK fix: WotLK Scale is relative; drive Cell's absolute 0 -> 1 scale privately.
    A.SetAbsoluteScale(s1, 0, 1)
    s1:SetOrder(1)
    s1:SetDuration(s1.duration)

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    A.SetAbsoluteAlpha(a2, 1, 0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.F:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        a1:SetDuration(a1.duration / parent.speed)
        s1:SetDuration(s1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        local l = max(parent:GetParent():GetWidth(), parent:GetParent():GetHeight()) * 2
        tex:SetSize(l, l)
        tex:SetTexture("Interface/AddOns/Cell/Media/Shapes/heart_filled_256")
        tex:SetVertexColor(r, g, b, 0.6)

        if ag:IsPlaying() then
            --! WotLK fix: AnimationGroup:Restart is not native on 3.3.5; keep
            --! the restart behavior private to this Cell-owned animation.
            ag:Stop()
        end
        ag:Play()
    end

    return canvas
end

animationPool.F = CreateCellObjectPool(CreateAnimationGroup_TypeF, ResetterFunc)

-------------------------------------------------
-- animation: G
-------------------------------------------------
local function CreateAnimationGroup_TypeG()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetPoint("TOPLEFT", canvas)
    f:SetPoint("TOPRIGHT", canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexture(Cell.vars.whiteTexture)

    canvas:EnableMouse(false)
    f:EnableMouse(false)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.5
    --! WotLK fix: use Cell's private absolute-alpha driver; do not modify shared Alpha methods.
    A.SetAbsoluteAlpha(a1, 0, 1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    A.SetAbsoluteAlpha(a2, 1, 0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.G:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        f:SetHeight(canvas:GetHeight() / 2)
        
        -- tex:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
        -- tex:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 1)
        tex:SetVertexColor(r, g, b, 1)

        a1:SetDuration(a1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        if ag:IsPlaying() then
            --! WotLK fix: AnimationGroup:Restart is not native on 3.3.5; keep
            --! the restart behavior private to this Cell-owned animation.
            ag:Stop()
        end
        ag:Play()
    end

    return canvas
end

animationPool.G = CreateCellObjectPool(CreateAnimationGroup_TypeG, ResetterFunc)

-------------------------------------------------
-- indicator
-------------------------------------------------
local previews = {}
local previewOrientation

local function Actions_SetSpeed(self, speed)
    self.speed = speed
end

local function Actions_Display(self, animationType, color)
    -- animations[animationType]:Display(unpack(color))
    -- if Cell.vars.actionsDebugModeEnabled then
    --    print("Actions_Display:", animationType, color[1], color[2], color[3])
    -- end

    if strfind(animationType, "^C") then
        local subType = strmatch(animationType, "%d")
        local canvas = animationPool.C:Acquire()
        canvas.ag:Display(self, subType, color[1], color[2], color[3])
    else
        local canvas = animationPool[animationType]:Acquire()
        canvas.ag:Display(self, color[1], color[2], color[3])
    end
end

function I.CreateActions(parent, isPreview)
    local actions = CreateFrame("Frame", parent:GetName() .. "ActionsParent", isPreview and parent or parent.widgets.indicatorFrame)

    if isPreview then
        parent.actions = actions
        tinsert(previews, parent)
        actions:SetPoint("TOPLEFT", 1, -1)
        actions:SetPoint("BOTTOMRIGHT", -1, 1)
        actions.orientation = previewOrientation
    else
        parent.indicators.actions = actions
        actions:SetAllPoints(parent.widgets.healthBar)
    end
    
    actions:EnableMouse(false)

    actions.speed = 1
    actions.SetSpeed = Actions_SetSpeed
    actions.Display = Actions_Display
end

function I.UpdateActionsOrientation(button, barOrientation)
    button.indicators.actions.orientation = barOrientation

    if previewOrientation ~= barOrientation then
        previewOrientation = barOrientation
        for _, p in pairs(previews) do
            p.actions.orientation = barOrientation
        end
    end
end

function I.EnableActions(enabled)
    if enabled then
        eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    else
        eventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end
end