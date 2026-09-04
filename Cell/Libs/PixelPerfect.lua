--------------------------------------------
-- http://wow.gamepedia.com/UI_Scale
-- http://www.wowinterface.com/forums/showthread.php?t=31813
--------------------------------------------
local _, addon = ...
addon.pixelPerfectFuncs = {}
--! WotLK fix: use Cell's private pixel contract, not a standalone
--! !!!ClassicAPI owner's global PixelUtil implementation.
local PixelUtil = addon.PixelUtil

local function Round(num, numDecimalPlaces)
    if numDecimalPlaces and numDecimalPlaces >= 0 then
        local mult = 10 ^ numDecimalPlaces
        num = num * mult
        if num >= 0 then
            return floor(num + 0.5) / mult
        else
            return ceil(num - 0.5) / mult
        end
    end

    if num >= 0 then
        return floor(num + 0.5)
    else
        return ceil(num - 0.5)
    end
end

--! WotLK fix: PixelPerfect needs only a local clamp; do not load/publish the
--! ClassicAPI MathUtil global family solely for this calculation.
local function Clamp(value, minValue, maxValue)
    if value > maxValue then
        return maxValue
    elseif value < minValue then
        return minValue
    end
    return value
end

---@class PixelPerfectFuncs
local P = addon.pixelPerfectFuncs

function P.GetResolution()
    -- return string.match(({GetScreenResolutions()})[GetCurrentResolution()], "(%d+)x(%d+)")
    --! Read the real physical resolution ourselves instead of trusting the global.
    --! GetPhysicalScreenSize may be owned by the standalone !!!ClassicAPI addon,
    --! whose version returns UI units (~1024x768) rather than pixels, which
    --! collapses every pixel-perfect calculation in Cell to scale 1.
    local resolution = GetCVar and GetCVar("gxResolution")
    if resolution then
        local w, h = string.match(resolution, "(%d+)x(%d+)")
        if w and h then
            return tonumber(w), tonumber(h)
        end
    end
    --! WotLK fix: use Cell's private physical-size source. A standalone
    --! !!!ClassicAPI owner may expose incompatible UI-unit semantics globally.
    return PixelUtil.GetPhysicalScreenSize()
end

-- The UI P.Scale goes from 1 to 0.64.
-- At 768y we see pixel-per-pixel accurate representation of our texture,
-- and again at 1200y if at 0.64 scale.
function P.GetPixelPerfectScale()
    local hRes, vRes = P.GetResolution()
    if vRes then
        return 768 / vRes
    else -- windowed mode before 8.0, or maybe something goes wrong?
        return 1
    end
end

function P.GetRecommendedScale()
    local pScale = P.GetPixelPerfectScale()
    local mult
    if pScale >= 0.71 then -- 1080
        mult = 1
    elseif pScale >= 0.53 then -- 1440
        mult = 1.2
    else -- 2160
        mult = 1.7
    end
    return Clamp(Round(pScale / UIParent:GetScale() * mult, 2), 0.5, 2)
end

-- scale perfect!
function P.PixelPerfectScale(frame)
    frame:SetScale(P.GetPixelPerfectScale())
end

-- position perfect!
function P.PixelPerfectPoint(frame)
    local left = frame:GetLeft()
    local top = frame:GetTop()

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", CellParent, "BOTTOMLEFT", math.floor(left + 0.5), math.floor(top + 0.5))
end

--------------------------------------------
-- PixelUtil
--------------------------------------------
-- local effectiveScale = 1
-- function P.SetRelativeScale(scale)
--     effectiveScale = scale
-- end

-- function P.GetEffectiveScale()
--     return effectiveScale
-- end

-- function P.SetEffectiveScale(frame)
--     frame:SetScale(effectiveScale)
-- end

-- function P.Scale(uiUnitSize)
--     if uiUnitSize == 0 then
--         return 0
--     end

--     local uiUnitFactor = PixelUtil.GetPixelToUIUnitFactor()
--     local numPixels = Round((uiUnitSize * effectiveScale) / uiUnitFactor)
--     if uiUnitSize < 0.0 then
--         if numPixels > -1 then
--             numPixels = -1
--         end
--     else
--         if numPixels < 1 then
--             numPixels = 1
--         end
--     end

--     return numPixels * uiUnitFactor / effectiveScale
-- end

--------------------------------------------
-- some are stolen from ElvUI
--------------------------------------------
-- local function GetUIParentScale()
--     local scale = UIParent:GetScale()
--     return scale - scale % 0.1 ^ 2
-- end

local scale = 1
local mult = 1
---@deprecated
function P.SetRelativeScale(s)
    mult = 1 / s
    scale = s
end

---@deprecated
function P.GetEffectiveScale()
    return P.GetPixelPerfectScale() / mult
end

---@deprecated
function P.SetEffectiveScale(frame)
    frame:SetScale(P.GetEffectiveScale())
end

--[[
local trunc = function(s) return s >= 0 and s-s%01 or s-s%-1 end
local round = function(s) return s >= 0 and s-s%-1 or s-s%01 end
function P.Scale(n)
    return (mult == 1 or n == 0) and n or ((mult < 1 and trunc(n/mult) or round(n/mult)) * mult)
end
]]
-- function P.Scale(n)
--     if mult == 1 or n == 0 then
--         return n
--     else
--         local x = mult > 1 and mult or -mult
--         return n - n % (n < 0 and x or -x)
--     end
-- end

local GetPixelToUIUnitFactor = PixelUtil.GetPixelToUIUnitFactor
local mfloor, mceil = math.floor, math.ceil

--! WotLK fix: P.Scale is the hottest leaf of the whole addon. Run 41 measured 82,276 calls
--! in a single 0.59 s layout rebuild (entering an instance flips the group type, which
--! re-applies geometry over every widget and every indicator of every unit button), and
--! that burst is the freeze the tester reported. The old body was one line but four calls:
--! CellParent:GetEffectiveScale() across the C boundary, GetNearestPixelSize, and inside it
--! GetPixelToUIUnitFactor plus Round. On Lua 5.1 without a JIT those calls, not the
--! arithmetic, are the price, so only the pixel-to-UI factor is cached and the rest is
--! inlined. The basis is still read every call and compared, so the cache invalidates itself
--! and no hook can go stale (UIParent scale, uiscale CVar, resolution change and
--! CellParent:SetScale in Appearance are all covered by that comparison alone).
--! The expression is GetNearestPixelSize's own, kept character for character:
--! Round((size * scale) / factor) * factor / scale, no minPixels clamp because P.Scale never
--! passed one. Folding the two divisions into premultiplied constants was tried first and
--! rejected: (s * sc) / f and s * (sc / f) are not the same double, and 3,646 of 17,080
--! probed size/scale pairs crossed a Round() boundary because of it - up to 1.33 UI units,
--! i.e. a visibly misplaced border.
local scaleBasis, scaleFactor = false, 1

function P.Scale(desiredPixels)
    if desiredPixels == 0 then return 0 end

    local scale = CellParent:GetEffectiveScale()
    if scale ~= scaleBasis then
        --! Same guard as GetNearestPixelSize: a zero scale would divide by zero.
        scaleBasis = (scale and scale ~= 0) and scale or 1
        scaleFactor = GetPixelToUIUnitFactor()
    end

    local numPixels = (desiredPixels * scaleBasis) / scaleFactor
    if numPixels >= 0 then
        numPixels = mfloor(numPixels + 0.5)
    else
        numPixels = mceil(numPixels - 0.5)
    end
    return numPixels * scaleFactor / scaleBasis
end

--! WotLK perf: file-local alias for the hottest leaf. `P` is addon.pixelPerfectFuncs,
--! a table this file creates, so no foreign owner can swap Scale out from under it
--! (rule 3) - and every call below saves one hash lookup on P.
local Scale = P.Scale

--! WotLK perf: the stamp callers compare to decide whether geometry they stored earlier
--! still matches the screen. GetPixelToUIUnitFactor above is memoised for the session,
--! so the effective scale is the only variable Scale() has.
function P.GetScale()
    return CellParent:GetEffectiveScale()
end

function P.Size(frame, width, height)
    frame.width = width
    frame.height = height
    frame:SetSize(P.Scale(width), P.Scale(height))
end

function P.Width(frame, width)
    frame.width = width
    frame:SetWidth(P.Scale(width))
end

function P.Height(frame, height)
    frame.height = height
    frame:SetHeight(P.Scale(height))
end

function P.SetGridSize(region, gridWidth, gridHeight, gridSpacingH, gridSpacingV, columns, rows)
    region._size_grid = true
    region._gridWidth = gridWidth
    region._gridHeight = gridHeight
    region._gridSpacingH = gridSpacingH
    region._gridSpacingV = gridSpacingV
    region._rows = rows
    region._columns = columns

    if columns == 0 then
        region:SetWidth(0.001)
    else
        region:SetWidth(P.Scale(gridWidth) * columns + P.Scale(gridSpacingH) * (columns - 1))
    end

    if rows == 0 then
        region:SetHeight(0.001)
    else
        region:SetHeight(P.Scale(gridHeight) * rows + P.Scale(gridSpacingV) * (rows - 1))
    end
end

--! WotLK perf: 44339 calls in one 5-man run, and each one allocated a fresh 5-slot
--! table that ClearPoints then threw away - pure GC pressure on Lua 5.1. `frame.points`
--! is private to Point/ClearPoints/Repoint (nothing else in Cell reads it), so it is now
--! a pooled counted array: `.n` is the live count, the slot tables are reused, and wipe
--! and tinsert are gone. The arity dispatch is kept as-is on purpose: 20+ call sites
--! pass a trailing offset that can be nil at runtime, and named slots cannot tell
--! "5 args, last one nil" from "4 args".
function P.Point(frame, ...)
    local pts = frame.points
    if not pts then
        pts = {n = 0}
        frame.points = pts
    end
    local point, anchorTo, anchorPoint, x, y

    local n = select("#", ...)
    if n == 1 then
        point = ...
    elseif n == 3 and type(select(2, ...)) == "number" then
        point, x, y = ...
    elseif n == 4 then
        point, anchorTo, x, y = ...
    else
        point, anchorTo, anchorPoint, x, y = ...
    end

    n = (pts.n or #pts) + 1
    pts.n = n

    local p = pts[n]
    if p then
        p[1], p[2], p[3], p[4], p[5] = point, anchorTo or frame:GetParent(), anchorPoint or point, x or 0, y or 0
    else
        p = {point, anchorTo or frame:GetParent(), anchorPoint or point, x or 0, y or 0}
        pts[n] = p
    end

    frame:SetPoint(p[1], p[2], p[3], Scale(p[4]), Scale(p[5]))
end

function P.ClearPoints(frame)
    frame:ClearAllPoints()
    --! WotLK perf: drop the count, keep the slot tables for P.Point to refill.
    if frame.points then frame.points.n = 0 end
end

--------------------------------------------
-- scale changed
--------------------------------------------
function P.Resize(frame)
    if frame._size_grid then
        P.SetGridSize(frame, frame._gridWidth, frame._gridHeight, frame._gridSpacingH, frame._gridSpacingV, frame._columns, frame._rows)
    else
        if frame.width then
            frame:SetWidth(P.Scale(frame.width))
        end
        if frame.height then
            frame:SetHeight(P.Scale(frame.height))
        end
    end
end

function P.Reborder(frame, ignoreSnippetVar)
    --! WotLK fix: было `if not frame.backdropInfo then return end` + `frame:ApplyBackdrop()`.
    --! Оба - ретейл: `backdropInfo` кладёт себе BackdropTemplate, а `ApplyBackdrop` это его
    --! метод (кодекс 3.3.5a на него отвечает НЕТ). В бэкпорте `backdropInfo` не выставляет
    --! никто - поиск по Cell/ находит его только в этой функции, - поэтому вся функция
    --! молча выходила первой же строкой. Замерено прибором 1.9.13 в прогонах 22 и 23.08:
    --! `backdropInfo` нет ни у одного из шести осмотренных кадров, `ApplyBackdrop` тоже,
    --! `reborderIsNoOp = true`. Наружу это выходило так: сменил масштаб интерфейса - рамка
    --! окна настроек Cell осталась прежней толщины (1.0667 вместо нужных 1.3333 при
    --! масштабе 0.8) до перезахода в игру; подсказка Cell и кнопки NPC считаются другим
    --! путём и отставали не они.
    --! Нативная замена обоим: `GetBackdrop()` отдаёт таблицу описания, `SetBackdrop(tbl)`
    --! применяет её заново. Круг проверен тем же прибором на живом кадре - файл фона, файл
    --! края, толщина края и отступы переживают его целиком.
    local backdrop = frame:GetBackdrop()
    if not backdrop then return end

    local _r, _g, _b, _a = frame:GetBackdropColor()
    local r, g, b, a = frame:GetBackdropBorderColor()

    if ignoreSnippetVar then
        backdrop.edgeSize = P.Scale(1)
    else
        if CELL_BORDER_SIZE == 0 then
            --! WotLK fix: раньше сюда не доходило (функция выходила первой строкой), а
            --! теперь доходит - и обнулённый edgeFile был бы дверью в одну сторону: сниппет
            --! CELL_BORDER_SIZE можно запустить повторно без перезахода, и рамка после
            --! 0 -> 1 уже не вернулась бы. Поэтому файл края запоминается на кадре. Кадрам,
            --! созданным вообще без края (их в Cell хватает - только bgFile), запоминать
            --! нечего, так что рамку они не отрастят.
            frame._cellBorderEdgeFile = frame._cellBorderEdgeFile or backdrop.edgeFile
            backdrop.edgeFile = nil
            backdrop.edgeSize = nil
        else
            backdrop.edgeFile = backdrop.edgeFile or frame._cellBorderEdgeFile
            backdrop.edgeSize = P.Scale(CELL_BORDER_SIZE or 1)
        end
    end
    --! SetBackdrop сбрасывает цвета в белый, поэтому снятые выше возвращаются ниже -
    --! ровно та же последовательность, что была вокруг ApplyBackdrop.
    frame:SetBackdrop(backdrop)

    if _r then frame:SetBackdropColor(_r, _g, _b, _a) end
    if r then frame:SetBackdropBorderColor(r, g, b, a) end
end

--! WotLK perf: 33840 calls in one 5-man run. `pairs` over an array cost one `next`
--! C-call per slot plus the iterator setup; the count is now known, so a numeric for
--! does the same walk with no C-calls, and Scale is the file-local.
function P.Repoint(frame)
    local pts = frame.points
    if not pts then return end
    local n = pts.n or #pts
    if n == 0 then return end

    frame:ClearAllPoints()
    for i = 1, n do
        local t = pts[i]
        frame:SetPoint(t[1], t[2], t[3], Scale(t[4]), Scale(t[5]))
    end
end

-- local frames = {}
-- function P.SetPixelPerfect(frame)
--     tinsert(frames, frame)
-- end

-- function P.UpdatePixelPerfectFrames()
--     for _, f in pairs(frames) do
--         f:UpdatePixelPerfect()
--     end
-- end

--------------------------------------------
-- save & load position
--------------------------------------------
function P.SavePosition(frame, positionTable)
    wipe(positionTable)
    positionTable[1], positionTable[2], positionTable[3] = P.CalcPoint(frame)
    -- local left = math.floor(frame:GetLeft() + 0.5)
    -- local top = math.floor(frame:GetTop() + 0.5)
    -- positionTable[1], positionTable[2] = left, top
end

function P.LoadPosition(frame, positionTable)
    if type(positionTable) ~= "table" then return end

    if #positionTable == 2 then
        P.ClearPoints(frame)
        P.Point(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", positionTable[1], positionTable[2])
        return true
    elseif #positionTable == 3 then
        P.ClearPoints(frame)
        frame:SetPoint(positionTable[1], CellParent, positionTable[2], positionTable[3])
        return true
    end
end

function P.CalcPoint(frame)
    local point, x, y
    local centerX, centerY = CellParent:GetCenter()
    local width = CellParent:GetRight()
    x, y = frame:GetCenter()

    if y >= centerY then
        point = "TOP"
            y = -(CellParent:GetTop() - frame:GetTop())
    else
        point = "BOTTOM"
            y = frame:GetBottom()
    end

    if x >= (width * 2 / 3) then
        point = point.."RIGHT"
            x = frame:GetRight() - width
    elseif x <= (width / 3) then
        point = point.."LEFT"
            x = frame:GetLeft()
    else
        x = x - centerX
    end

    -- x = tonumber(string.format("%.2f", x))
    -- y = tonumber(string.format("%.2f", y))
    x = Round(x, 1)
    y = Round(y, 1)

    return point, x, y
end

---------------------------------------------------------------------
-- pixel perfect (ElvUI)
---------------------------------------------------------------------
--! WotLK fix: native 3.3.5 has no SetSnapToPixelGrid or SetTexelSnappingBias.
--! ClassicAPI only supplies state/no-op shims for those retail methods, so the
--! upstream ElvUI block cannot disable real client-side snapping here. Do not
--! hook shared Texture/StatusBar methods (SetTexture, SetTexCoord, CreateTexture,
--! SetVertexColor, etc.): those hooks affect Blizzard and foreign unit-frame
--! addons such as X-Perl while providing no visual benefit on this client.
--! Cell's own pixel sizing/anchoring functions above remain active.