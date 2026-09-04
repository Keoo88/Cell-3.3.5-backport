local addonName, Cell = ...
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs
---@class CellAnimations
local A = Cell.animations
local C_Timer = Cell.C_Timer

--! WotLK fix: build 12340 can crash when AnimationGroup:Stop() is invoked
--! reentrantly from another native animation/frame callback. Queue cancellation
--! and verify the group is still playing when the private timer dispatches it.
local pendingStops = setmetatable({}, {__mode = "k"})
local function StopAnimationGroupSafely(group)
    if not group or pendingStops[group] then return end

    pendingStops[group] = true
    Cell.Debug.RingPush("ANIM", "queue stop: " .. tostring(group:GetName() or "<anon>"))
    C_Timer.After(0, function()
        pendingStops[group] = nil
        if group:IsPlaying() then
            group:Stop()
        end
    end)
end

--! WotLK fix: debug introspection for /cell debug anim.
--! Returns the size of the pending-stop queue so the user can see if re-entrancy
--! deferrals are piling up. Walks the table once, which is fine: this is a
--! manual /cell debug command, not a hot path.
function A.GetDebugInfo()
    local pending = 0
    for _ in pairs(pendingStops) do pending = pending + 1 end
    return pending
end

--! WotLK fix: Alpha in 3.3.5a only supports relative SetChange(delta), and
--! Scale only supports relative factors. Keep retail-style absolute endpoints
--! private to Cell instead of adding methods to the shared widget metatables.
local function AbsoluteAnimation_GetRegion(info)
    return info.animation:GetRegionParent()
end

local function AbsoluteAnimation_Apply(info, value)
    local region = AbsoluteAnimation_GetRegion(info)
    if not region then return end

    if info.kind == "alpha" then
        region:SetAlpha(value)
    elseif info.kind == "scale" then
        region:SetScale(value)
    end
end

local function AbsoluteAnimation_OnUpdate(animation)
    local info = animation._cellAbsoluteInfo
    if not info then return end

    --! WotLK perf: тело AbsoluteAnimation_Apply и AbsoluteAnimation_GetRegion
    --! вставлено сюда как есть. Драйвер идёт на полном фреймрейте на каждой
    --! играющей анимации, а мигание иконки боя зациклено ("BOUNCE") и висит на
    --! каждой кнопке рейда, пока идёт бой: 40 анимаций x 60 кадров. Три кадра
    --! вызова Lua на кадр отрисовки вместо одного - это чистый налог, при том
    --! что обе функции остаются на месте: их зовёт ApplyBoundary (холодный путь,
    --! только на OnPlay/OnLoop/OnFinished). Тот же приём и по той же причине уже
    --! применён к ClampBarValue в ProcessCellSmoothBars.
    --! `info.animation` тут - это и есть аргумент `animation`: таблица info
    --! строится с полем animation = animation и тут же кладётся в
    --! animation._cellAbsoluteInfo (RegisterAbsoluteAnimation), другого пути к
    --! этому полю нет. Значит поле можно не читать.
    local region = animation:GetRegionParent()
    if not region then return end

    local progress = animation:GetSmoothProgress() or 0
    local from = info.from
    local value = from + (info.to - from) * progress

    if info.kind == "alpha" then
        region:SetAlpha(value)
    elseif info.kind == "scale" then
        region:SetScale(value)
    end
end

local function AbsoluteAnimationGroup_ApplyBoundary(group, useLast)
    local animations = group._cellAbsoluteAnimations
    if not animations then return end

    local boundaryOrder
    for _, info in ipairs(animations) do
        local order = info.animation:GetOrder() or 1
        if not boundaryOrder
            or (useLast and order > boundaryOrder)
            or (not useLast and order < boundaryOrder) then
            boundaryOrder = order
        end
    end

    for _, info in ipairs(animations) do
        if (info.animation:GetOrder() or 1) == boundaryOrder then
            AbsoluteAnimation_Apply(info, useLast and info.to or info.from)
        end
    end
end

local function AbsoluteAnimationGroup_OnPlay(group)
    AbsoluteAnimationGroup_ApplyBoundary(group, false)
end

local function AbsoluteAnimationGroup_OnFinished(group)
    AbsoluteAnimationGroup_ApplyBoundary(group, true)
end

local function AbsoluteAnimationGroup_OnLoop(group, loopState)
    --! WotLK fix: native BOUNCE runs the same child animations in reverse.
    --! GetSmoothProgress() therefore becomes 1 -> 0 on the reverse leg; apply
    --! the matching boundary explicitly so no stale endpoint survives a loop.
    if group:GetLooping() == "BOUNCE" then
        if loopState == "REVERSE" or loopState == "FORWARD" then
            AbsoluteAnimationGroup_ApplyBoundary(group, loopState == "REVERSE")
        else
            -- Private-server builds are not fully consistent about the OnLoop
            -- payload, but GetLoopState() is native and authoritative.
            AbsoluteAnimationGroup_ApplyBoundary(group, group:GetLoopState() == "REVERSE")
        end
    else
        AbsoluteAnimationGroup_ApplyBoundary(group, false)
    end
end

local function RegisterAbsoluteAnimation(animation, kind, from, to)
    local info = animation._cellAbsoluteInfo
    if info then
        info.from, info.to = from, to
        return animation
    end

    info = {
        animation = animation,
        kind = kind,
        from = from,
        to = to,
    }
    animation._cellAbsoluteInfo = info

    local group = animation:GetParent()
    if not group._cellAbsoluteAnimations then
        group._cellAbsoluteAnimations = {}
        group:HookScript("OnPlay", AbsoluteAnimationGroup_OnPlay)
        group:HookScript("OnLoop", AbsoluteAnimationGroup_OnLoop)
        group:HookScript("OnFinished", AbsoluteAnimationGroup_OnFinished)
    end
    table.insert(group._cellAbsoluteAnimations, info)

    animation:SetScript("OnUpdate", AbsoluteAnimation_OnUpdate)
    if kind == "alpha" then
        animation:SetChange(0)
    else
        animation:SetScale(1, 1)
    end

    return animation
end

function A.SetAbsoluteAlpha(animation, fromAlpha, toAlpha)
    return RegisterAbsoluteAnimation(animation, "alpha", fromAlpha, toAlpha)
end

function A.SetAbsoluteScale(animation, fromScale, toScale)
    -- A zero frame scale is invalid or unstable on some 3.3.5 clients.
    if fromScale == 0 then fromScale = 0.001 end
    if toScale == 0 then toScale = 0.001 end
    return RegisterAbsoluteAnimation(animation, "scale", fromScale, toScale)
end

-----------------------------------------
-- forked from ElvUI
-----------------------------------------
local FADEFRAMES, FADEMANAGER = {}, CreateFrame('FRAME')
FADEMANAGER.interval = 0.025

-----------------------------------------
-- fade manager onupdate
-----------------------------------------
local function Fading(_, elapsed)
    FADEMANAGER.timer = (FADEMANAGER.timer or 0) + elapsed

    if FADEMANAGER.timer > FADEMANAGER.interval then
        FADEMANAGER.timer = 0

        for frame, info in next, FADEFRAMES do
            if frame:IsVisible() then
                info.fadeTimer = (info.fadeTimer or 0) + (elapsed + FADEMANAGER.interval)
            else -- faster for hidden frames
                info.fadeTimer = info.timeToFade + 1
            end

            if info.fadeTimer < info.timeToFade then
                if info.mode == 'IN' then
                    frame:SetAlpha((info.fadeTimer / info.timeToFade) * info.diffAlpha + info.startAlpha)
                else
                    frame:SetAlpha(((info.timeToFade - info.fadeTimer) / info.timeToFade) * info.diffAlpha + info.endAlpha)
                end
            else
                frame:SetAlpha(info.endAlpha)
                -- NOTE: remove from FADEFRAMES
                if frame and FADEFRAMES[frame] then
                    if frame.fade then
                        frame.fade.fadeTimer = nil
                    end
                    FADEFRAMES[frame] = nil
                end
            end
        end

        if not next(FADEFRAMES) then
            -- print("FINISHED FADING!")
            FADEMANAGER:SetScript('OnUpdate', nil)
        end
    end
end

-----------------------------------------
-- fade
-----------------------------------------
local function FrameFade(frame, info)
    frame:SetAlpha(info.startAlpha)

    if not frame:IsProtected() then
        frame:Show()
    end

    if not FADEFRAMES[frame] then
        FADEFRAMES[frame] = info
        FADEMANAGER:SetScript('OnUpdate', Fading)
    else
        FADEFRAMES[frame] = info
    end
end

function A.FrameFadeIn(frame, timeToFade, startAlpha, endAlpha)
    if frame.fade then
        frame.fade.fadeTimer = nil
    else
        frame.fade = {}
    end

    frame.fade.mode = 'IN'
    frame.fade.timeToFade = timeToFade
    frame.fade.startAlpha = startAlpha
    frame.fade.endAlpha = endAlpha
    frame.fade.diffAlpha = endAlpha - startAlpha

    FrameFade(frame, frame.fade)
end

function A.FrameFadeOut(frame, timeToFade, startAlpha, endAlpha)
    if frame.fade then
        frame.fade.fadeTimer = nil
    else
        frame.fade = {}
    end

    frame.fade.mode = 'OUT'
    frame.fade.timeToFade = timeToFade
    frame.fade.startAlpha = startAlpha
    frame.fade.endAlpha = endAlpha
    frame.fade.diffAlpha = startAlpha - endAlpha

    FrameFade(frame, frame.fade)
end

-----------------------------------------
-- fade in/out on mouseover/mouseout
-----------------------------------------
function A.ApplyFadeInOutToParent(parent, condition, ...)
    for _, f in pairs({...}) do
        f:SetHitRectInsets(-2, -2, -2, -2)

        f:HookScript("OnEnter", function()
            if condition() then
                A.FrameFadeIn(parent, 0.25, parent:GetAlpha(), 1)
            end
        end)

        f:HookScript("OnLeave", function()
            if condition() then
                A.FrameFadeOut(parent, 0.25, parent:GetAlpha(), 0)
            end
        end)
    end
end

-----------------------------------------
-- add fade in/out
-----------------------------------------
function A.CreateFadeIn(frame, fromAlpha, toAlpha, duration, delay, onFinished)
    local fadeIn = frame:CreateAnimationGroup()
    frame.fadeIn = fadeIn
    fadeIn.alpha = fadeIn:CreateAnimation("Alpha")
    A.SetAbsoluteAlpha(fadeIn.alpha, fromAlpha, toAlpha)
    fadeIn.alpha:SetDuration(duration)
    if delay then fadeIn.alpha:SetStartDelay(delay) end

    fadeIn:SetScript("OnPlay", function()
        StopAnimationGroupSafely(frame.fadeOut)
    end)

    if onFinished then
        fadeIn:SetScript("OnFinished", onFinished)
    end

    function frame:FadeIn()
        frame:Show()
        fadeIn:Play()
    end
end

function A.CreateFadeOut(frame, fromAlpha, toAlpha, duration, delay, onFinished)
    local fadeOut = frame:CreateAnimationGroup()
    frame.fadeOut = fadeOut
    fadeOut.alpha = fadeOut:CreateAnimation("Alpha")
    A.SetAbsoluteAlpha(fadeOut.alpha, fromAlpha, toAlpha)
    fadeOut.alpha:SetDuration(duration)
    if delay then fadeOut.alpha:SetStartDelay(delay) end

    fadeOut:SetScript("OnPlay", function()
        StopAnimationGroupSafely(frame.fadeIn)
    end)

    if onFinished then
        fadeOut:SetScript("OnFinished", onFinished)
    else
        fadeOut:SetScript("OnFinished", function()
            frame:Hide()
        end)
    end

    function frame:FadeOut()
        fadeOut:Play()
    end
end

-----------------------------------------
-- apply fade in/out to menu
-----------------------------------------
--! WotLK fix: the menu fade used to be two AnimationGroups plus four booleans
--! (fadingIn / fadedIn / fadingOut / fadedOut) that decided whether a hover
--! event is allowed to start a fade. Every one of those booleans is a latch: it
--! is cleared only from an OnFinished handler, so if a group is asked to play
--! and never reaches OnFinished, the latch stays set and the anchor is stuck
--! forever - OnLeave keeps seeing `not (fadingOut or fadedOut)` as false and
--! refuses to retry for the rest of the session. On 3.3.5a there are two ways
--! to lose that OnFinished:
--!   * an AnimationGroup attached to a frame that is not visible does not tick,
--!     and Cell.Fire("UpdateMenu") is issued once at login (Core_Wrath.lua),
--!     while the raid frames are still hidden;
--!   * :Finish() called from inside the *other* group's OnPlay re-enters that
--!     group's OnFinished, which may in turn call Play() on the very group the
--!     engine is currently starting.
--! Pet and NPC anchors survive this because their UpdateAnchor/UpdateSeparateAnchor
--! invokes the fade-out OnFinished handler by hand instead of playing it, and the
--! main panel survives because MainFrame.lua drives its own alpha and never used
--! this helper at all. The spotlight anchor has no updater, so it was the one
--! menu button that stayed at full alpha no matter what - reported by testers as
--! "the other buttons hide, this one still does not".
--! Drive the alpha directly instead: the target alpha IS the state, so there is
--! no latch left to get stuck, SetAlpha works on a frame that is not visible,
--! and the absolute-alpha shim above is no longer in the hot path for menus.
--! This mirrors MainFrame.lua's own fader, i.e. the menu button that works.
local MENU_FADE_DURATION = 0.5

local function MenuFade_OnUpdate(self, elapsed)
    local step = elapsed / MENU_FADE_DURATION
    local alpha = self._cellMenuAlphaTarget == 1 and self:GetAlpha() + step
                                                  or self:GetAlpha() - step
    if alpha >= 1 or alpha <= 0 then
        alpha = self._cellMenuAlphaTarget
        self:SetScript("OnUpdate", nil)
    end
    self:SetAlpha(alpha)
end

local function MenuFadeTo(anchorFrame, target, instant)
    anchorFrame._cellMenuAlphaTarget = target
    --! An instant apply is not an optimisation, it is the only thing that works
    --! while the frame is hidden: OnUpdate does not run there either.
    if instant or anchorFrame:GetAlpha() == target then
        anchorFrame:SetScript("OnUpdate", nil)
        anchorFrame:SetAlpha(target)
    else
        anchorFrame:SetScript("OnUpdate", MenuFade_OnUpdate)
    end
end

function A.ApplyFadeInOutToMenu(anchorFrame, hoverFrame)
    anchorFrame._cellMenuAlphaTarget = 1

    --! Kept as methods (not as .fadeIn/.fadeOut animation groups) so that a
    --! caller cannot go behind the state again the way UpdateAnchor used to,
    --! by reaching for :GetScript("OnFinished") and calling it by hand.
    function anchorFrame:MenuFadeIn(instant)
        MenuFadeTo(self, 1, instant)
    end

    function anchorFrame:MenuFadeOut(instant)
        MenuFadeTo(self, 0, instant)
    end

    hoverFrame:SetScript("OnEnter", function()
        if not CellDB["general"]["fadeOut"] then return end
        MenuFadeTo(anchorFrame, 1)
    end)
    hoverFrame:SetScript("OnLeave", function()
        if not CellDB["general"]["fadeOut"] then return end
        if hoverFrame:IsMouseOver() then return end
        MenuFadeTo(anchorFrame, 0)
    end)
end

-----------------------------------------
-- blink
-----------------------------------------
function A.CreateBlinkAnimation(region, duration, enableShowHideHook)
    local blink = region:CreateAnimationGroup()
    region.blink = blink

    local alpha = blink:CreateAnimation("Alpha")
    blink.alpha = alpha
    A.SetAbsoluteAlpha(alpha, 0.25, 1)
    alpha:SetDuration(duration or 0.5)

    blink:SetLooping("BOUNCE")

    if enableShowHideHook then
        --! WotLK fix: Texture regions do not own scripts on 3.3.5. Hook the
        --! Cell-owned parent frame and mirror the texture's visibility instead
        --! of publishing a shared Texture:HookScript parent-delegation shim.
        local owner = region:GetParent()
        if owner and owner.HookScript then
            owner:HookScript("OnShow", function()
                if region:IsShown() then blink:Play() end
            end)
            owner:HookScript("OnHide", function()
                StopAnimationGroupSafely(blink)
            end)
        elseif region:IsShown() then
            blink:Play()
        end
    else
        blink:Play()
    end
end