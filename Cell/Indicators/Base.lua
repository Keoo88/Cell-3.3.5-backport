local _, Cell = ...
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs
---@type PixelPerfectFuncs
local P = Cell.pixelPerfectFuncs
--! WotLK fix: copy Cell's private smoothing methods directly; do not depend on
--! or publish shared Mixin/SmoothStatusBarMixin compatibility globals.
local SmoothStatusBarMixin = Cell.SmoothStatusBarMixin
local function ApplySmoothStatusBarMixin(bar)
    for key, value in pairs(SmoothStatusBarMixin) do
        bar[key] = value
    end
    return bar
end

local LCG = LibStub("LibCustomGlow-1.0-Cell")

--! WotLK perf: floor/ceil локально. Оба зовутся из OnUpdate-драйверов ниже, то есть
--! до 60 раз в секунду на каждый видимый индикатор; глобал - это хеш-лукап в
--! _G на каждый вызов, локал - чтение регистра.
local floor, ceil = math.floor, math.ceil

--! WotLK perf: единственная точка печати оставшегося времени для всех
--! OnUpdate-драйверов файла (Icon, Rect, Bar, Bars, Block x2, Blocks).
--! Раньше каждый из них звал SetFormattedText КАЖДЫЙ кадр: на 60 fps это шесть
--! записей в FontString на каждую десятую секунды и шестьдесят на каждую целую,
--! при том что видимая строка меняется в лучшем случае десять раз в секунду.
--! Индикаторов в рейде десятки (сорок юнитов * ауры), каждая запись - переход
--! Lua->C плюс форматирование строки.
--! Теперь считается числовой ключ отображения: пока он не сменился, показанная
--! строка уже верна и запись пропускается. Ключ пересчитывается каждый кадр,
--! поэтому момент смены цифры не сдвигается ни на кадр - меняется только число
--! холостых записей.
--! ИНВАРИАНТ, на котором всё держится: ключ однозначно определяет напечатанную
--! строку. Отсюда следует, что сбрасывать ключ при смене ауры на переиспользованном
--! кадре не нужно - совпавший ключ означает, что на кадре уже написано ровно то,
--! что нужно. Чтобы инвариант выполнялся и между ветками, диапазоны разведены:
--! минуты дают отрицательные ключи, десятые - от 1000, целые секунды - 0..60.
--! Без этого 90 c ("1m", ключ 1) и 1.5 c ("1", тоже ключ 1) не перерисовали бы
--! друг друга. Ветки ceil и floor пересекаются по диапазону, но обе печатают сам
--! ключ, так что инвариант не нарушают.
--! %d в Lua 5.1 усекает дробную часть - floor даёт ровно то, что напечатает формат.
--! Для %.1f ключ округляет вверх от половины, а printf на точной половине округляет
--! к чётному; расхождение возможно только если remain окажется битно ровным 0.25 /
--! 0.75 и стоит одной десятой, показанной на ~0.05 c дольше. На значениях из
--! GetTime() это недостижимо практически, поэтому цена принята сознательно.
local function SetDurationText(frame, remain)
    local key
    if remain > 60 then
        key = -floor(remain / 60)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.duration:SetFormattedText("%dm", remain / 60)
        end
    elseif Cell.vars.iconDurationRoundUp then
        key = ceil(remain)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.duration:SetFormattedText("%d", key)
        end
    elseif remain < Cell.vars.iconDurationDecimal then
        key = 1000 + floor(remain * 10 + 0.5)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.duration:SetFormattedText("%.1f", remain)
        end
    else
        key = floor(remain)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.duration:SetFormattedText("%d", remain)
        end
    end
end

CELL_BORDER_SIZE = 1
CELL_BORDER_COLOR = {0, 0, 0, 1}
CELL_COOLDOWN_STYLE = "VERTICAL"

-------------------------------------------------
-- SetFont
-------------------------------------------------
function I.JustifyText(text, point)
    if strfind(point, "LEFT$") then
        text:SetJustifyH("LEFT")
    elseif strfind(point, "RIGHT$") then
        text:SetJustifyH("RIGHT")
    else
        text:SetJustifyH("CENTER")
    end

    if strfind(point, "^TOP") then
        text:SetJustifyV("TOP")
    elseif strfind(point, "^BOTTOM") then
        text:SetJustifyV("BOTTOM")
    else
        text:SetJustifyV("MIDDLE")
    end
end

function I.SetFont(fs, anchorTo, font, size, outline, shadow, anchor, xOffset, yOffset, color)
    font = F.GetFont(font)

    local flags
    if outline == "None" then
        flags = ""
    elseif outline == "Outline" then
        flags = "OUTLINE"
    else
        flags = "OUTLINE,MONOCHROME"
    end

    fs:SetFont(font, size, flags)

    if shadow then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(0, 0, 0, 0)
    end

    P.ClearPoints(fs)
    P.Point(fs, anchor, anchorTo, anchor, xOffset, yOffset)
    I.JustifyText(fs, anchor)

    if color then
        fs.r = color[1]
        fs.g = color[2]
        fs.b = color[3]
        fs:SetTextColor(fs.r, fs.g, fs.b)
    else
        fs.r, fs.g, fs.b = 1, 1, 1
    end
end

-------------------------------------------------
-- Cell-owned cooldown contract
-------------------------------------------------
--! WotLK fix: native 3.3.5 Cooldown exposes only SetCooldown and SetReverse.
--! Keep the retail-only state used by Cell on Cell-owned cooldown instances
--! instead of publishing methods or hooks on the shared Cooldown metatable.
local function CellCooldown_SetCooldown(self, start, duration)
    start = start or 0
    duration = duration or 0
    self._cellCooldownStart = start
    self._cellCooldownDuration = duration
    if duration > 0 then
        self._cellCooldownEnd = start + duration
    else
        self._cellCooldownEnd = nil
    end
    return self._CellNativeSetCooldown(self, start, duration)
end

local function CellCooldown_GetCooldownDuration(self)
    local duration = self._cellCooldownDuration or 0
    local ending = self._cellCooldownEnd
    if duration > 0 and ending and ending <= GetTime() then
        self._cellCooldownStart = 0
        self._cellCooldownDuration = 0
        self._cellCooldownEnd = nil
        return 0
    end
    return duration
end

local function CellCooldown_OnUpdate(self)
    local ending = self._cellCooldownEnd
    if ending and ending <= GetTime() then
        self._cellCooldownEnd = nil
        self._cellCooldownStart = 0
        self._cellCooldownDuration = 0
        local handler = self._cellCooldownDoneHandler
        if handler then
            handler(self)
        end
    end
end

local function OwnCellCooldown(cooldown)
    cooldown._CellNativeSetCooldown = cooldown.SetCooldown
    cooldown._SetCooldown = CellCooldown_SetCooldown
    cooldown.ShowCooldown = CellCooldown_SetCooldown
    cooldown.GetCooldownDuration = CellCooldown_GetCooldownDuration
    -- Prevent addons that look for an instance-owned SetCooldown from adding
    -- their own text. Cell calls the private aliases above.
    cooldown.SetCooldown = nil
end

function I.SetCooldownDoneHandler(cooldown, handler)
    cooldown._cellCooldownDoneHandler = handler
    cooldown:SetScript("OnUpdate", handler and CellCooldown_OnUpdate or nil)
end

--! WotLK fix: I.SetCooldownSwipeVisible удалена — её единственным вызывающим был
--! мёртвый privateAuraOptions (ретейловый индикатор приватных аур). Для справки:
--! SetDrawSwipe на 3.3.5 не существует (проверено codex), и спрятать спираль
--! Cell-овского Cooldown можно было только альфой — фрейм всё равно нужен иконке.
function I.SetCooldownNumbersHidden(cooldown, hidden)
    --! WotLK fix: countdown text is provided by addons such as OmniCC, not by
    --! the native Cooldown widget. The established noCooldownCount field is the
    --! local interoperability contract; do not add SetHideCountdownNumbers
    --! client-wide.
    --! SetHideCountdownNumbers на 3.3.5 не существует (проверено codex),
    --! ретейл-ветка вырезана.
    cooldown.noCooldownCount = hidden and true or nil
end

-------------------------------------------------
-- Shared
-------------------------------------------------
local function Shared_SetFont(frame, font1, font2)
    I.SetFont(frame.stack, frame, unpack(font1))
    I.SetFont(frame.duration, frame, unpack(font2))
end

--! WotLK fix: SetShown на 3.3.5 не существует (появился в 5.0.4), его давал шим
--! WidgetAPI, который прописывал метод в общие метатаблицы Frame/Texture/
--! FontString/Button/EditBox/Slider - то есть всем фреймам клиента, не только
--! Cell. Точек вызова было четыре на весь аддон, поэтому шим удалён, а здесь и
--! в трёх остальных местах стоит нативная пара Show/Hide.
local function Shared_ShowStack(frame, show)
    if show then frame.stack:Show() else frame.stack:Hide() end
end

local function Shared_ShowDuration(frame, show)
    frame.showDuration = show
    if show then frame.duration:Show() else frame.duration:Hide() end
end

--! custom: toggle for the jump (refresh) animation, see SESSION_NOTES #20
local function Shared_ShowJump(frame, show)
    frame.showJump = show
end

-------------------------------------------------
-- VerticalCooldown
-------------------------------------------------
local function ReCalcTexCoord(self, width, height)
    local texCoord = F.GetTexCoord(width, height)
    self.icon:SetTexCoord(unpack(texCoord))
    if self.cooldown.icon then
        self.cooldown.icon:SetTexCoord(unpack(texCoord))
    end
end

local function VerticalCooldown_OnUpdate(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= 0.1 then
        self:SetValue(self:GetValue() + self.elapsed)
        self.elapsed = 0
        --! WotLK: manual overlay emulates the retail mask - darken the
        --! elapsed (top) portion of the icon, growing downwards
        if self.overlay then
            local _, maxValue = self:GetMinMaxValues()
            local height = self:GetHeight()
            if maxValue and maxValue > 0 and height and height > 0 then
                local fraction = self:GetValue() / maxValue
                if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
                self.overlay:SetHeight(math.max(fraction * height, 0.001))
            end
        end
    end
end

--! WotLK fix: 3.3.5 has neither Texture masks (CreateMaskTexture, 8.0+) nor
--! StatusBar:SetReverseFill (4.2+). The retail vertical cooldown is built
--! on both: an invisible reverse-filled statusbar texture anchors a mask
--! that crops the bright icon copy. Without them the bright copy simply
--! covered the whole icon - toggling "Show animation" changed NOTHING
--! visually. Emulate the effect with a plain black overlay whose height is
--! driven from OnUpdate: the elapsed portion darkens from the top, the
--! spark rides the overlay's bottom edge.
local function VerticalCooldown_CreateOverlay(cooldown, anchor)
    local overlay = cooldown:CreateTexture(nil, "OVERLAY")
    cooldown.overlay = overlay
    overlay:SetTexture(Cell.vars.whiteTexture)
    overlay:SetVertexColor(0, 0, 0, 0.7)
    overlay:SetPoint("TOPLEFT", anchor)
    overlay:SetPoint("TOPRIGHT", anchor)
    overlay:SetHeight(0.001)

    cooldown.spark:ClearAllPoints()
    cooldown.spark:SetPoint("TOPLEFT", overlay, "BOTTOMLEFT")
    cooldown.spark:SetPoint("TOPRIGHT", overlay, "BOTTOMRIGHT")
end

-- for LCG.ButtonGlow_Start
local function VerticalCooldown_GetCooldownDuration()
    return 0
end

local function VerticalCooldown_ShowCooldown(self, start, duration, _, icon, debuffType)
    if debuffType then
        --! WotLK fix: SetColorTexture на 3.3.5 нет - это нативная числовая форма
        --! SetTexture(r, g, b[, a]); шим TextureBase в WidgetAPI удалён.
        self.spark:SetTexture(I.GetDebuffTypeColor(debuffType))
    else
        self.spark:SetTexture(0.5, 0.5, 0.5)
    end

    if self.icon then
        self.icon:SetTexture(icon)
    end

    self.elapsed = 0.1 -- update immediately
    self:SetMinMaxValues(0, duration)
    self:SetValue(GetTime() - start)
    self:Show()
end

local function Shared_CreateCooldown_Vertical(frame)
    local cooldown = CreateFrame("StatusBar", nil, frame)
    frame.cooldown = cooldown
    cooldown:Hide()
    cooldown:EnableMouse(false)

    cooldown.GetCooldownDuration = VerticalCooldown_GetCooldownDuration
    cooldown.ShowCooldown = VerticalCooldown_ShowCooldown
    cooldown:SetScript("OnUpdate", VerticalCooldown_OnUpdate)

    P.Point(cooldown, "TOPLEFT", frame.icon)
    P.Point(cooldown, "BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 0, CELL_BORDER_SIZE)
    cooldown:SetOrientation("VERTICAL")
    --! WotLK fix: reverse fill is rendered by VerticalCooldown_CreateOverlay;
    --! do not depend on a fake shared StatusBar:SetReverseFill method.
    cooldown:SetStatusBarTexture(Cell.vars.whiteTexture)

    --! WotLK fix: native GetStatusBarTexture can be nil on some custom
    --! clients; guard this Cell-owned bar locally instead of replacing the
    --! shared StatusBar metatable.
    local texture = cooldown:GetStatusBarTexture()
    if not texture then
        texture = cooldown:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(Cell.vars.whiteTexture)
        cooldown:SetStatusBarTexture(texture)
    end
    texture:SetAlpha(0)

    local spark = cooldown:CreateTexture(nil, "BORDER")
    cooldown.spark = spark
    P.Height(spark, 1)
    spark:SetBlendMode("ADD")
    spark:SetPoint("TOPLEFT", texture, "BOTTOMLEFT")
    spark:SetPoint("TOPRIGHT", texture, "BOTTOMRIGHT")

    --! CreateMaskTexture и AddMaskTexture на 3.3.5 не существуют (проверено codex),
    --! маска и её применение к иконке вырезаны вместе с ретейл-веткой.
    local icon = cooldown:CreateTexture(nil, "ARTWORK")
    cooldown.icon = icon
    -- icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    icon:SetDesaturated(false)
    icon:SetAllPoints(frame.icon)
    icon:SetVertexColor(1, 1, 1, 1)

    VerticalCooldown_CreateOverlay(cooldown, frame.icon) --! WotLK: no mask API
end

local function Shared_CreateCooldown_Vertical_NoIcon(frame)
    local cooldown = CreateFrame("StatusBar", nil, frame)
    frame.cooldown = cooldown
    cooldown:Hide()

    cooldown.GetCooldownDuration = VerticalCooldown_GetCooldownDuration
    cooldown.ShowCooldown = VerticalCooldown_ShowCooldown
    cooldown:SetScript("OnUpdate", VerticalCooldown_OnUpdate)

    P.Point(cooldown, "TOPLEFT", frame, CELL_BORDER_SIZE, -CELL_BORDER_SIZE)
    P.Point(cooldown, "BOTTOMRIGHT", frame, -CELL_BORDER_SIZE, CELL_BORDER_SIZE + CELL_BORDER_SIZE)
    cooldown:SetOrientation("VERTICAL")
    --! WotLK fix: reverse fill is rendered by VerticalCooldown_CreateOverlay;
    --! do not depend on a fake shared StatusBar:SetReverseFill method.
    cooldown:SetStatusBarTexture(Cell.vars.whiteTexture)

    --! WotLK fix: keep the nil fallback private to this Cell-owned bar.
    local texture = cooldown:GetStatusBarTexture()
    if not texture then
        texture = cooldown:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(Cell.vars.whiteTexture)
        cooldown:SetStatusBarTexture(texture)
    end
    --! WotLK fix: native bottom-up fill would darken the wrong remaining
    --! portion. Hide the bar texture and use the manual top-down overlay instead.
    --! Ретейл-ветка вырезана: там же было SetVertexColor(0,0,0,0.8), которое на
    --! 3.3.5 всё равно тут же перекрывалось нулевой альфой.
    texture:SetVertexColor(0, 0, 0, 0)

    local spark = cooldown:CreateTexture(nil, "BORDER")
    cooldown.spark = spark
    P.Height(spark, 1)
    spark:SetBlendMode("ADD")
    spark:SetPoint("TOPLEFT", texture, "BOTTOMLEFT")
    spark:SetPoint("TOPRIGHT", texture, "BOTTOMRIGHT")

    VerticalCooldown_CreateOverlay(cooldown, cooldown)
end

-------------------------------------------------
-- ClockCooldown
-------------------------------------------------
local function Shared_CreateCooldown_Clock(frame)
    local cooldown = CreateFrame("Cooldown", nil, frame)
    frame.cooldown = cooldown
    cooldown:Hide()

    P.Point(cooldown, "TOPLEFT", frame, CELL_BORDER_SIZE, -CELL_BORDER_SIZE)
    P.Point(cooldown, "BOTTOMRIGHT", frame, -CELL_BORDER_SIZE, CELL_BORDER_SIZE)
    cooldown:SetReverse(true)
    --! WotLK fix: SetDrawEdge, SetSwipeTexture, SetSwipeColor, and
    --! SetHideCountdownNumbers are not native 3.3.5 Cooldown methods (проверено
    --! codex). Ретейл-ветка вырезана: остаётся нативная спираль, Cell владеет
    --! только тем состоянием, которое ему нужно.

    OwnCellCooldown(cooldown)
    I.SetCooldownNumbersHidden(cooldown, true)
end

-------------------------------------------------
-- SetCooldownStyle
-------------------------------------------------
local function Shared_SetCooldownStyle(frame, style, noIcon)
    if frame.style == style then return end

    if frame.cooldown then
        frame.cooldown:SetParent(nil)
        frame.cooldown:Hide()
    end

    frame.style = style

    if style == "CLOCK" then
        Shared_CreateCooldown_Clock(frame)
    else
        if noIcon then
            Shared_CreateCooldown_Vertical_NoIcon(frame)
        else
            Shared_CreateCooldown_Vertical(frame)
        end
    end
end

--------------------------------------------------
-- jump animation child sync (WotLK)
--------------------------------------------------
--! WotLK fix: in 3.3.5 an AnimationGroup only transforms the regions OWNED
--! by its frame - child frames do NOT follow (retail changed this later).
--! The "jump" refresh animation (frame.ag) is created on the indicator
--! frame, but the visible pieces often live on child frames: the vertical
--! cooldown StatusBar carries its own bright copy of the icon
--! (cooldown.icon), and BorderIcon keeps icon/stack/duration on iconFrame.
--! Symptom (tester): with "Show animation" ON only the background jumped;
--! with it OFF (cooldown hidden -> frame.icon region visible) the icon
--! jumped properly. Fix: lazily create identical Translation groups on the
--! child frames and play them in sync via the parent group's OnPlay.
local function CreateJumpAG(region)
    local ag = region:CreateAnimationGroup()
    local t1 = ag:CreateAnimation("Translation")
    t1:SetOffset(0, 5)
    t1:SetDuration(0.1)
    t1:SetOrder(1)
    t1:SetSmoothing("OUT")
    local t2 = ag:CreateAnimation("Translation")
    t2:SetOffset(0, -5)
    t2:SetDuration(0.1)
    t2:SetOrder(2)
    t2:SetSmoothing("IN")
    return ag
end

local function Shared_SyncJumpToChildren(frame)
    frame.ag:SetScript("OnPlay", function()
        -- frame.cooldown is recreated on style change, so resolve and
        -- lazily attach the parallel animation group every play
        local children = {frame.cooldown, frame.iconFrame}
        for i = 1, #children do
            local child = children[i]
            if child and child:IsShown() then
                if not child._jumpAG then
                    child._jumpAG = CreateJumpAG(child)
                end
                child._jumpAG:Play()
            end
        end
    end)
end

--------------------------------------------------
-- glow
--------------------------------------------------
---@type function
local ButtonGlow_Start = LCG.ButtonGlow_Start
---@type function
local ButtonGlow_Stop = LCG.ButtonGlow_Stop
---@type function
local PixelGlow_Start = LCG.PixelGlow_Start
---@type function
local PixelGlow_Stop = LCG.PixelGlow_Stop
---@type function
local AutoCastGlow_Start = LCG.AutoCastGlow_Start
---@type function
local AutoCastGlow_Stop = LCG.AutoCastGlow_Stop
---@type function
local ProcGlow_Start = LCG.ProcGlow_Start
---@type function
local ProcGlow_Stop = LCG.ProcGlow_Stop

local StartGlow = {
    ["none"] = function(frame)
    end,
    ["normal"] = function(frame)
        ButtonGlow_Start(frame, frame.glowOptions.color)
    end,
    ["pixel"] = function(frame)
        PixelGlow_Start(frame, frame.glowOptions.color, frame.glowOptions.N, frame.glowOptions.frequency, frame.glowOptions.length, frame.glowOptions.thickness)
    end,
    ["shine"] = function(frame)
        AutoCastGlow_Start(frame, frame.glowOptions.color, frame.glowOptions.N, frame.glowOptions.frequency, frame.glowOptions.scale)
    end,
    ["proc"] = function(frame)
        ProcGlow_Start(frame, frame.glowOptions)
    end,
}

local StopGlow = {
    ["none"] = function(frame)
    end,
    ["normal"] = ButtonGlow_Stop,
    ["pixel"] = PixelGlow_Stop,
    ["shine"] = AutoCastGlow_Stop,
    ["proc"] = ProcGlow_Stop,
}

local function Shared_SetupGlow(frame, glowOptions)
    frame.glowType = glowOptions[1]
    frame.glowOptions = {}

    ButtonGlow_Stop(frame)
    PixelGlow_Stop(frame)
    AutoCastGlow_Stop(frame)
    ProcGlow_Stop(frame)

    frame.StartGlow = StartGlow[strlower(frame.glowType)]
    frame.StopGlow = StopGlow[strlower(frame.glowType)]

    if frame.glowType == "Normal" then
        frame.glowOptions.color = glowOptions[2]
    elseif frame.glowType == "Pixel" then
        frame.glowOptions.color = glowOptions[2]
        frame.glowOptions.N = glowOptions[3]
        frame.glowOptions.frequency = glowOptions[4]
        frame.glowOptions.length = glowOptions[5]
        frame.glowOptions.thickness = glowOptions[6]
    elseif frame.glowType == "Shine" then
        frame.glowOptions.color = glowOptions[2]
        frame.glowOptions.N = glowOptions[3]
        frame.glowOptions.frequency = glowOptions[4]
        frame.glowOptions.scale = glowOptions[5]
    elseif frame.glowType == "Proc" then
        frame.glowOptions = {color = glowOptions[2], duration = glowOptions[3], startAnim = false}
    end

    if frame.glowType ~= "None" then
        frame:StartGlow()
        if not frame._sizeChangedHooked then
            frame._sizeChangedHooked = true
            frame:HookScript("OnSizeChanged", function()
                frame:StartGlow()
            end)
        end
    end
end

function I.Glow_SetupForChildren(parent, glowOptions)
    for _, child in ipairs(parent) do
        child:SetupGlow(glowOptions)
    end
end

-------------------------------------------------
-- Icon_OnUpdate
-------------------------------------------------
--! WotLK perf: блок выбора цвета был побайтно одинаков в Icon_OnUpdate и
--! Icon_OnUpdate_ElapsedTime и читал `Cell.vars.iconDurationColors` до шести раз за
--! проход: шесть чтений глобала `Cell` (GETGLOBAL - хеш-лукап в _G) плюс по два
--! хеш-лукапа `.vars` и `.iconDurationColors` на каждое. Идёт десять раз в секунду
--! на каждую видимую иконку, а иконок в рейде десятки (40 юнитов x ауры).
--! Теперь таблица берётся один раз и нужный подмассив - один раз.
--! Безопасно: единственный писатель `iconDurationColors` - Appearance.lua:1850/1852,
--! он работает из окна настроек, а не из потока событий, подменить таблицу под
--! драйвером посреди кадра нечем.
local function SetIconDurationColor(frame, remain)
    local colors = Cell.vars.iconDurationColors
    local duration = frame.duration

    if not colors then
        duration:SetTextColor(duration.r, duration.g, duration.b)
        return
    end

    local c = colors[3]
    if remain >= c[4] then
        c = colors[2]
        if remain >= c[4] * frame._duration then
            c = colors[1]
        end
    end
    duration:SetTextColor(c[1], c[2], c[3])
end

local function Icon_OnUpdate(frame, elapsed)
    --! WotLK perf: остаток держится в локале на время кадра. Поле `_remain`
    --! читалось из таблицы кадра четыре раза за вызов (гейт порога, две проверки
    --! цвета, печать), а драйвер работает на полном фреймрейте на каждой видимой
    --! иконке. Запись в поле сохранена: его обнуляют при остановке (:717, :863).
    --! `_elapsed` тоже пишется один раз вместо двух в кадре накопления.
    local remain = frame._duration - (GetTime() - frame._start)
    if remain < 0 then remain = 0 end
    frame._remain = remain

    if remain > frame._threshold then
        --! WotLK fix: avoid repeating the same FontString write every frame
        --! while a long aura is above its configured duration threshold.
        if not frame._durationTextBlank then
            frame.duration:SetText("")
            frame._durationTextBlank = true
            frame._durationKey = nil
        end
        return
    end
    frame._durationTextBlank = nil

    local e = frame._elapsed + elapsed
    if e >= 0.1 then
        e = 0
        -- color
        SetIconDurationColor(frame, remain)
    end
    frame._elapsed = e

    -- format
    SetDurationText(frame, remain)
end

local function Icon_OnUpdate_ElapsedTime(frame, elapsed)
    --! WotLK perf: см. Icon_OnUpdate выше - тот же подъём остатка в локал.
    local remain = frame._duration - (GetTime() - frame._start)
    if remain < 0 then remain = 0 end
    frame._remain = remain

    if remain > frame._threshold then
        --! WotLK fix: elapsed-time icons use the same blank-state guard as
        --! normal duration icons, avoiding a FontString write every frame.
        if not frame._durationTextBlank then
            frame.duration:SetText("")
            frame._durationTextBlank = true
            frame._durationKey = nil
        end
        return
    end
    frame._durationTextBlank = nil

    local e = frame._elapsed + elapsed
    if e >= 0.1 then
        e = 0
        -- color
        SetIconDurationColor(frame, remain)
    end
    frame._elapsed = e

    -- format
    --! WotLK perf: прошедшее время выводится из уже посчитанного остатка, а не
    --! вторым вызовом GetTime(). Тождество точное: remain = _duration - (now -
    --! _start), значит now - _start = _duration - remain. Отдельный кламп по
    --! _duration тоже не нужен - он был зеркалом клампа remain по нулю: остаток
    --! ниже нуля уже прижат, а из remain >= 0 следует elapsedTime <= _duration.
    --! Заодно оба значения кадра теперь берутся из одного отсчёта времени, а не
    --! из двух разных вызовов GetTime() внутри одного кадра.
    local elapsedTime = frame._duration - remain
    frame._elapsedTime = elapsedTime

    --! WotLK perf: тот же ключ отображения, что в Icon_OnUpdate. Здесь обе ветки
    --! печатают целое (%dm и %d), поэтому холостых записей ещё больше: текст
    --! меняется раз в секунду, а вызов был каждый кадр. Минуты - отрицательный
    --! ключ, секунды - неотрицательный, ветки не пересекаются.
    local key
    if elapsedTime > 60 then
        key = -floor(elapsedTime / 60)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.duration:SetFormattedText("%dm", elapsedTime / 60)
        end
    else
        key = floor(elapsedTime)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.duration:SetFormattedText("%d", elapsedTime)
        end
    end
end

-------------------------------------------------
-- CreateAura_BorderIcon
-------------------------------------------------
local function BorderIcon_SetCooldown(frame, start, duration, debuffType, texture, count, refreshing, useElapsedTime)
    local r, g, b
    if debuffType then
        r, g, b = I.GetDebuffTypeColor(debuffType)
    else
        r, g, b = 0, 0, 0
    end

    if duration == 0 then
        frame.border:Show()
        frame.border:SetTexture(r, g, b)
        frame.cooldown:Hide()
        frame.duration:Hide()
        frame:SetScript("OnUpdate", nil)
        frame._start = nil
        frame._duration = nil
        frame._remain = nil
        frame._elapsed = nil
        frame._threshold = nil
        frame._elapsedTime = nil
        frame._durationTextBlank = nil
    else
        frame.border:Hide()
        frame.cooldown:Show()
        --! WotLK fix: native 3.3.5 cannot recolor its cooldown spiral (SetSwipeColor
        --! отсутствует, проверено codex). Debuff coloring живёт в явной отрисовке
        --! рамки/иконки Cell, спираль остаётся нативной. Ретейл-ветка вырезана -
        --! это горячий путь: ShowCooldown зовётся на каждое обновление аур.
        frame.cooldown:_SetCooldown(start, duration)

        if not frame.showDuration then
            frame.duration:Hide()
        else
            if frame.showDuration == true then
                frame._threshold = duration
            elseif frame.showDuration >= 1 then
                frame._threshold = frame.showDuration
            else -- < 1
                frame._threshold = frame.showDuration * duration
            end
            frame.duration:Show()
        end

        if frame.showDuration then
            frame._start = start
            frame._duration = duration
            frame._elapsed = 0.1 -- update immediately
            frame:SetScript("OnUpdate", useElapsedTime and Icon_OnUpdate_ElapsedTime or Icon_OnUpdate)
        end
    end

    frame.icon:SetTexture(texture)
    frame.stack:SetText((count == 0 or count == 1) and "" or count)
    frame:Show()

    --! custom: jump (refresh) animation is now optional; nil = enabled
    --! (upstream plays it unconditionally, see SESSION_NOTES #20)
    if refreshing and frame.showJump ~= false then
        frame.ag:Play()
    end
end

local function BorderIcon_SetBorder(frame, thickness)
    P.ClearPoints(frame.iconFrame)
    P.Point(frame.iconFrame, "TOPLEFT", frame, "TOPLEFT", thickness, -thickness)
    P.Point(frame.iconFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -thickness, thickness)
end

local function BorderIcon_ShowDuration(frame, show)
    frame.showDuration = show
    if show then
        frame.duration:Show()
    else
        frame.duration:Hide()
    end
end

local function BorderIcon_UpdatePixelPerfect(frame)
    P.Resize(frame)
    P.Repoint(frame)
    P.Repoint(frame.iconFrame)
    P.Repoint(frame.stack)
    P.Repoint(frame.duration)
end

function I.CreateAura_BorderIcon(name, parent, borderSize)
    local frame = CreateFrame("Frame", name, parent, nil)
    frame:Hide()
    -- frame:SetSize(11, 11)
    frame:SetBackdrop({bgFile = Cell.vars.whiteTexture})
    frame:SetBackdropColor(0, 0, 0, 0.85)

    local border = frame:CreateTexture(name.."Border", "BORDER")
    frame.border = border
    border:SetAllPoints(frame)
    border:Hide()

    local cooldown = CreateFrame("Cooldown", name.."Cooldown", frame)
    frame.cooldown = cooldown
    cooldown:SetAllPoints(frame)
    --! WotLK fix: SetSwipeTexture/SetSwipeColor на 3.3.5 не существуют (проверено
    --! codex), нативная спираль остаётся как есть. Ретейл-ветка вырезана.
    OwnCellCooldown(cooldown)
    I.SetCooldownNumbersHidden(cooldown, true)

    local iconFrame = CreateFrame("Frame", name.."IconFrame", frame)
    frame.iconFrame = iconFrame
    P.Point(iconFrame, "TOPLEFT", frame, "TOPLEFT", borderSize, -borderSize)
    P.Point(iconFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -borderSize, borderSize)
    iconFrame:SetFrameLevel(cooldown:GetFrameLevel()+1)

    local icon = iconFrame:CreateTexture(name.."Icon", "ARTWORK")
    frame.icon = icon
    icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    icon:SetAllPoints(iconFrame)

    frame.stack = iconFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    frame.duration = iconFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")

    local ag = frame:CreateAnimationGroup()
    frame.ag = ag
    local t1 = ag:CreateAnimation("Translation")
    t1:SetOffset(0, 5)
    t1:SetDuration(0.1)
    t1:SetOrder(1)
    t1:SetSmoothing("OUT")
    local t2 = ag:CreateAnimation("Translation")
    t2:SetOffset(0, -5)
    t2:SetDuration(0.1)
    t2:SetOrder(2)
    t2:SetSmoothing("IN")

    Shared_SyncJumpToChildren(frame) --! WotLK: children don't follow parent AG

    frame.SetFont = Shared_SetFont
    frame.SetBorder = BorderIcon_SetBorder
    frame.SetCooldown = BorderIcon_SetCooldown
    frame.ShowDuration = BorderIcon_ShowDuration
    frame.ShowJump = Shared_ShowJump
    frame.UpdatePixelPerfect = BorderIcon_UpdatePixelPerfect

    return frame
end

-------------------------------------------------
-- CreateAura_BarIcon
-------------------------------------------------
local function BarIcon_SetCooldown(frame, start, duration, debuffType, texture, count, refreshing)
    if duration == 0 then
        frame.cooldown:Hide()
        frame.duration:Hide()
        frame.stack:SetParent(frame)
        frame:SetScript("OnUpdate", nil)
        frame._start = nil
        frame._duration = nil
        frame._threshold = nil
        frame._remain = nil
        frame._elapsed = nil
        frame._durationTextBlank = nil
    else
        if frame.showAnimation then
            frame.cooldown:ShowCooldown(start, duration, nil, texture, debuffType)
            frame.duration:SetParent(frame.cooldown)
            frame.stack:SetParent(frame.cooldown)
        else
            frame.cooldown:Hide()
            frame.duration:SetParent(frame)
            frame.stack:SetParent(frame)
        end

        if not frame.showDuration then
            frame.duration:Hide()
        else
            if frame.showDuration == true then
                frame._threshold = duration
            elseif frame.showDuration >= 1 then
                frame._threshold = frame.showDuration
            else -- < 1
                frame._threshold = frame.showDuration * duration
            end
            frame.duration:Show()
        end

        if frame.showDuration then
            frame._start = start
            frame._duration = duration
            frame._elapsed = 0.1 -- update immediately
            frame:SetScript("OnUpdate", Icon_OnUpdate)
        end
    end

    if debuffType then
        frame:SetBackdropColor(I.GetDebuffTypeColor(debuffType))
    else
        frame:SetBackdropColor(0, 0, 0)
    end

    frame.icon:SetTexture(texture)
    frame.stack:SetText((count == 0 or count == 1) and "" or count)
    frame:Show()

    --! custom: jump (refresh) animation is now optional; nil = enabled
    --! (upstream plays it unconditionally, see SESSION_NOTES #20)
    if refreshing and frame.showJump ~= false then
        frame.ag:Play()
    end
end

local function BarIcon_ShowAnimation(frame, show)
    frame.showAnimation = show
    if show then
        frame.cooldown:Show()
    else
        frame.cooldown:Hide()
    end
end

local function BarIcon_UpdatePixelPerfect(frame)
    P.Resize(frame)
    P.Repoint(frame)
    P.Repoint(frame.icon)
    P.Repoint(frame.stack)
    P.Repoint(frame.duration)
    P.Repoint(frame.cooldown)
    if frame.cooldown.spark then
        P.Resize(frame.cooldown.spark)
    end
end

function I.CreateAura_BarIcon(name, parent)
    local frame = CreateFrame("Frame", name, parent, nil)
    frame:Hide()
    -- frame:SetSize(11, 11)
    frame:SetBackdrop({bgFile = Cell.vars.whiteTexture})
    frame:SetBackdropColor(0, 0, 0, 1)

    local icon = frame:CreateTexture(name and name.."Icon", "ARTWORK")
    frame.icon = icon
    -- icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    P.Point(icon, "TOPLEFT", frame, "TOPLEFT", CELL_BORDER_SIZE, -CELL_BORDER_SIZE)
    P.Point(icon, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CELL_BORDER_SIZE, CELL_BORDER_SIZE)
    -- icon:SetDrawLayer("ARTWORK", 1)

    frame.stack = frame:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    frame.duration = frame:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")

    local ag = frame:CreateAnimationGroup()
    frame.ag = ag
    local t1 = ag:CreateAnimation("Translation")
    t1:SetOffset(0, 5)
    t1:SetDuration(0.1)
    t1:SetOrder(1)
    t1:SetSmoothing("OUT")
    local t2 = ag:CreateAnimation("Translation")
    t2:SetOffset(0, -5)
    t2:SetDuration(0.1)
    t2:SetOrder(2)
    t2:SetSmoothing("IN")

    Shared_SyncJumpToChildren(frame) --! WotLK: children don't follow parent AG

    frame.SetFont = Shared_SetFont
    frame.SetCooldown = BarIcon_SetCooldown
    frame.ShowDuration = Shared_ShowDuration
    frame.ShowStack = Shared_ShowStack
    frame.ShowAnimation = BarIcon_ShowAnimation
    frame.ShowJump = Shared_ShowJump
    frame.SetupGlow = Shared_SetupGlow
    frame.UpdatePixelPerfect = BarIcon_UpdatePixelPerfect

    Shared_SetCooldownStyle(frame, CELL_COOLDOWN_STYLE)

    frame:SetScript("OnSizeChanged", ReCalcTexCoord)

    -- frame:SetScript("OnEnter", function()
        -- local f = frame
        -- repeat
        --     f = f:GetParent()
        -- until f:IsObjectType("button")
        -- f:GetScript("OnEnter")(f)
    -- end)

    return frame
end

-------------------------------------------------
-- CreateAura_Icons
-------------------------------------------------
local function Icons_UpdateSize(icons, numAuras)
    if not (icons.width and icons.orientation) then return end -- not init

    if numAuras then -- call from I.CheckCustomIndicators or preview
        for i = numAuras + 1, icons.maxNum do
            icons[i]:Hide()
        end
    else
        numAuras = 0
        for i = 1, icons.maxNum do
            if icons[i]:IsShown() then
                numAuras = i
            else
                break
            end
        end
    end

    -- set size
    local lines = ceil(numAuras / icons.numPerLine)
    numAuras = min(numAuras, icons.numPerLine)

    if icons.isHorizontal then
        P.SetGridSize(icons, icons.width, icons.height, icons.spacingX, icons.spacingY, numAuras, lines)
    else
        P.SetGridSize(icons, icons.width, icons.height, icons.spacingX, icons.spacingY, lines, numAuras)
    end
end

local function Icons_SetNumPerLine(icons, numPerLine)
    icons.numPerLine = min(numPerLine, icons.maxNum)


    if icons.orientation then
        icons:SetOrientation(icons.orientation)
    -- else
    --     icons:UpdateSize()
    end
end

local function Icons_SetOrientation(icons, orientation)
    icons.orientation = orientation

    local anchor = icons:GetPoint()
    assert(anchor, "[indicator] SetPoint must be called before SetOrientation")

    icons.isHorizontal = not strfind(orientation, "top")

    local point1, point2, x, y
    local newLinePoint2, newLineX, newLineY

    if orientation == "left-to-right" then
        if strfind(anchor, "^BOTTOM") then
            point1 = "BOTTOMLEFT"
            point2 = "BOTTOMRIGHT"
            newLinePoint2 = "TOPLEFT"
            y = 0
            newLineY = icons.spacingY
        else
            point1 = "TOPLEFT"
            point2 = "TOPRIGHT"
            newLinePoint2 = "BOTTOMLEFT"
            y = 0
            newLineY = -icons.spacingY
        end
        x = icons.spacingX
        newLineX = 0

    elseif orientation == "right-to-left" then
        if strfind(anchor, "^BOTTOM") then
            point1 = "BOTTOMRIGHT"
            point2 = "BOTTOMLEFT"
            newLinePoint2 = "TOPRIGHT"
            y = 0
            newLineY = icons.spacingY
        else
            point1 = "TOPRIGHT"
            point2 = "TOPLEFT"
            newLinePoint2 = "BOTTOMRIGHT"
            y = 0
            newLineY = -icons.spacingY
        end
        x = -icons.spacingX
        newLineX = 0

    elseif orientation == "top-to-bottom" then
        if strfind(anchor, "RIGHT$") then
            point1 = "TOPRIGHT"
            point2 = "BOTTOMRIGHT"
            newLinePoint2 = "TOPLEFT"
            x = 0
            newLineX = -icons.spacingX
        else
            point1 = "TOPLEFT"
            point2 = "BOTTOMLEFT"
            newLinePoint2 = "TOPRIGHT"
            x = 0
            newLineX = icons.spacingX
        end
        y = -icons.spacingY
        newLineY = 0

    elseif orientation == "bottom-to-top" then
        if strfind(anchor, "RIGHT$") then
            point1 = "BOTTOMRIGHT"
            point2 = "TOPRIGHT"
            newLinePoint2 = "BOTTOMLEFT"
            x = 0
            newLineX = -icons.spacingX
        else
            point1 = "BOTTOMLEFT"
            point2 = "TOPLEFT"
            newLinePoint2 = "BOTTOMRIGHT"
            x = 0
            newLineX = icons.spacingX
        end
        y = icons.spacingY
        newLineY = 0
    end

    for i = 1, icons.maxNum do
        P.ClearPoints(icons[i])
        if i == 1 then
            P.Point(icons[i], point1)
        elseif i % icons.numPerLine == 1 then
            P.Point(icons[i], point1, icons[i-icons.numPerLine], newLinePoint2, newLineX, newLineY)
        else
            P.Point(icons[i], point1, icons[i-1], point2, x, y)
        end
    end

    icons:UpdateSize()
end

local function Icons_SetSize(icons, width, height)
    icons.width = width
    icons.height = height

    for i = 1, icons.maxNum do
        icons[i]:SetSize(width, height)
        --! width & height P.Scaled
        icons[i].width = nil
        icons[i].height = nil
    end

    icons:UpdateSize()
end

local function Icons_SetSpacing(icons, spacing)
    icons.spacingX = spacing[1]
    icons.spacingY = spacing[2]

    if icons.orientation then
        icons:SetOrientation(icons.orientation)
    end
end

local function Icons_Hide(icons, hideAll)
    icons:_Hide()
    if hideAll then
        for i = 1, icons.maxNum do
            icons[i]:Hide()
        end
    end
end

local function Icons_SetFont(icons, ...)
    for i = 1, icons.maxNum do
        icons[i]:SetFont(...)
    end
end

local function Icons_ShowDuration(icons, show)
    for i = 1, icons.maxNum do
        icons[i]:ShowDuration(show)
    end
end

local function Icons_ShowStack(icons, show)
    for i = 1, icons.maxNum do
        icons[i]:ShowStack(show)
    end
end

local function Icons_ShowAnimation(icons, show)
    for i = 1, icons.maxNum do
        icons[i]:ShowAnimation(show)
    end
end

--! custom: group version of ShowJump, see SESSION_NOTES #20
local function Icons_ShowJump(icons, show)
    for i = 1, icons.maxNum do
        if icons[i].ShowJump then
            icons[i]:ShowJump(show)
        end
    end
end

local function Icons_UpdatePixelPerfect(icons)
    P.Repoint(icons)
    P.Resize(icons)
    for i = 1, icons.maxNum do
        icons[i]:UpdatePixelPerfect()
    end
end

function I.CreateAura_Icons(name, parent, num)
    local icons = CreateFrame("Frame", name, parent)
    icons:Hide()

    icons.indicatorType = "icons"
    icons.maxNum = num
    icons.numPerLine = num
    icons.spacingX = 0
    icons.spacingY = 0

    icons._SetSize = icons.SetSize
    icons.SetSize = Icons_SetSize
    icons._Hide = icons.Hide
    icons.Hide = Icons_Hide
    icons.SetFont = Icons_SetFont
    icons.UpdateSize = Icons_UpdateSize
    icons.SetOrientation = Icons_SetOrientation
    icons.SetSpacing = Icons_SetSpacing
    icons.SetNumPerLine = Icons_SetNumPerLine
    icons.ShowDuration = Icons_ShowDuration
    icons.ShowStack = Icons_ShowStack
    icons.ShowAnimation = Icons_ShowAnimation
    icons.ShowJump = Icons_ShowJump
    icons.SetupGlow = I.Glow_SetupForChildren
    icons.UpdatePixelPerfect = Icons_UpdatePixelPerfect

    for i = 1, num do
        local name = name and name.."Icon"..i
        local frame = I.CreateAura_BarIcon(name, icons)
        icons[i] = frame
    end

    return icons
end

-------------------------------------------------
-- CreateAura_Text
-------------------------------------------------
local function Text_SetFont(frame, font, size, outline, shadow)
    font = F.GetFont(font)

    local flags
    if outline == "None" then
        flags = ""
    elseif outline == "Outline" then
        flags = "OUTLINE"
    else
        flags = "OUTLINE,MONOCHROME"
    end

    frame.text:SetFont(font, size, flags)

    if shadow then
        frame.text:SetShadowOffset(1, -1)
        frame.text:SetShadowColor(0, 0, 0, 1)
    else
        frame.text:SetShadowOffset(0, 0)
        frame.text:SetShadowColor(0, 0, 0, 0)
    end

    frame:SetSize(size, size)
end

local function Text_SetPoint(frame, point, relativeTo, relativePoint, x, y)
    frame.text:ClearAllPoints()
    frame.text:SetPoint(point)
    frame:_SetPoint(point, relativeTo, relativePoint, x, y)
    I.JustifyText(frame.text, point)
end

local function Text_SetDuration(frame, durationTbl)
    frame.durationTbl = durationTbl
end

local function Text_SetStack(frame, stack)
    frame.showStack = stack[1]
    --! WotLK fix: stack[2] - "цифры в кружках" - больше не читается, опция удалена.
    --! Символы ①..㊿ лежат в Unicode-блоке Enclosed Alphanumerics (U+2460+), которого
    --! нет ни в одном шрифте, поставляемом с клиентом 3.3.5a, - на экране получались
    --! пустые прямоугольники. Плюс таблица обрывалась на 50: 51-й стак давал
    --! конкатенацию с nil и ошибку прямо в отрисовке индикатора.
end

local function Text_SetColors(frame, colors)
    frame.state = nil
    frame.colors = colors
end

local function Text_OnUpdateColor(frame)
    if frame.colors[3][1] and frame._remain <= frame.colors[3][2] then
        if frame.state ~= 3 then
            frame.state = 3
            frame.text:SetTextColor(frame.colors[3][3][1], frame.colors[3][3][2], frame.colors[3][3][3], frame.colors[3][3][4])
        end
    elseif frame.colors[2][1] and frame._remain <= frame._duration * frame.colors[2][2] then
        if frame.state ~= 2 then
            frame.state = 2
            frame.text:SetTextColor(frame.colors[2][3][1], frame.colors[2][3][2], frame.colors[2][3][3], frame.colors[2][3][4])
        end
    elseif frame.state ~= 1 then
        frame.state = 1
        frame.text:SetTextColor(frame.colors[1][1], frame.colors[1][2], frame.colors[1][3], frame.colors[1][4])
    end
end

local function Text_OnUpdateDuration(frame, elapsed)
    --! WotLK perf: остаток в локале, `_elapsed` пишется один раз за кадр. Запись в
    --! `_remain` сохранена и стоит до Text_OnUpdateColor: та читает поле, а не аргумент.
    local remain = frame._duration - (GetTime() - frame._start)
    if remain < 0 then remain = 0 end
    frame._remain = remain

    local e = frame._elapsed + elapsed
    if e >= 0.1 then
        e = 0
        -- color
        Text_OnUpdateColor(frame)
    end
    frame._elapsed = e

    -- format
    --! WotLK perf: тот же ключ отображения, что в SetDurationText наверху файла
    --! (там же разбор, почему ключи веток непересекающиеся). Отдельная копия, а не
    --! вызов общей функции: этот индикатор пишет в frame.text, берёт пороги из
    --! frame.durationTbl, а не из Cell.vars, и приклеивает префикс со стаком, так
    --! что общая функция ему не подходит ни по одному из трёх пунктов.
    --! Ключ сбрасывается в Text_SetCooldown вместе с _count - иначе смена стака
    --! ("2 5" -> "3 5") не перерисовала бы строку.
    local key
    if remain > 60 then
        key = -floor(remain / 60)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.text:SetFormattedText(frame._count.."%dm", remain / 60)
        end
    elseif frame.durationTbl[2] then
        key = ceil(remain)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.text:SetFormattedText(frame._count.."%d", key)
        end
    elseif remain < frame.durationTbl[3] then
        key = 1000 + floor(remain * 10 + 0.5)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.text:SetFormattedText(frame._count.."%.1f", remain)
        end
    else
        key = floor(remain)
        if key ~= frame._durationKey then
            frame._durationKey = key
            frame.text:SetFormattedText(frame._count.."%d", remain)
        end
    end
end

local function Text_OnUpdate(frame, elapsed)
    --! WotLK perf: `_elapsed` пишется один раз за кадр вместо двух в кадре накопления.
    --! Остаток здесь в локал не выносится: Text_OnUpdateColor читает поле `_remain`,
    --! а не аргумент, и других чтений в функции нет.
    local e = frame._elapsed + elapsed
    if e >= 0.1 then
        e = 0

        frame._remain = frame._duration - (GetTime() - frame._start)
        -- update color
        Text_OnUpdateColor(frame)
    end
    frame._elapsed = e
end

local function Text_SetCooldown(frame, start, duration, debuffType, texture, count)
    --! WotLK perf: ключ отображения сбрасывается на каждой установке кулдауна.
    --! Text_OnUpdateDuration печатает _count вместе с цифрой, а _count меняется
    --! именно здесь, поэтому без сброса смена стака при том же остатке времени
    --! ("2 5" -> "3 5") не перерисовала бы строку.
    frame._durationKey = nil

    if duration == 0 then
        -- always show stack
        count = count == 0 and 1 or count
        frame.text:SetText(count)
        frame.text:SetTextColor(frame.colors[1][1], frame.colors[1][2], frame.colors[1][3], frame.colors[1][4])
        frame:SetScript("OnUpdate", nil)
        frame._count = nil
        frame._start = nil
        frame._duration = nil
        frame._remain = nil
        frame._elapsed = nil
    else
        frame._start = start
        frame._duration = duration

        if frame.durationTbl[1] then
            if frame.showStack and count ~= 0 then
                frame._count = count.." "
            else
                frame._count = ""
            end

            frame._elapsed = 0.1 -- update immediately
            frame:SetScript("OnUpdate", Text_OnUpdateDuration)
        else
            -- always show stack
            count = count == 0 and 1 or count
            frame.text:SetText(count)

            frame._elapsed = 0.1 -- update immediately
            frame:SetScript("OnUpdate", Text_OnUpdate)
        end
    end

    frame:Show()
end

function I.CreateAura_Text(name, parent)
    local frame = CreateFrame("Frame", name, parent)
    frame:Hide()
    frame.indicatorType = "text"

    local text = frame:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    frame.text = text
    text:SetPoint("CENTER", 1, 0)

    frame.SetFont = Text_SetFont
    frame._SetPoint = frame.SetPoint
    frame.SetPoint = Text_SetPoint
    frame.SetCooldown = Text_SetCooldown
    frame.SetDuration = Text_SetDuration
    frame.SetStack = Text_SetStack
    frame.SetColors = Text_SetColors

    return frame
end

-------------------------------------------------
-- CreateAura_Rect
-------------------------------------------------
local function Rect_SetFont(frame, font1, font2)
    I.SetFont(frame.stack, frame, unpack(font1))
    I.SetFont(frame.duration, frame, unpack(font2))
end

local function Rect_OnUpdateColor(frame)
    if frame.colors[3][1] and frame._remain <= frame.colors[3][2] then
        if frame.state ~= 3 then
            frame.state = 3
            frame.tex:SetTexture(frame.colors[3][3][1], frame.colors[3][3][2], frame.colors[3][3][3], frame.colors[3][3][4])
        end
    elseif frame.colors[2][1] and frame._remain <= frame._duration * frame.colors[2][2] then
        if frame.state ~= 2 then
            frame.state = 2
            frame.tex:SetTexture(frame.colors[2][3][1], frame.colors[2][3][2], frame.colors[2][3][3], frame.colors[2][3][4])
        end
    elseif frame.state ~= 1 then
        frame.state = 1
        frame.tex:SetTexture(frame.colors[1][1], frame.colors[1][2], frame.colors[1][3], frame.colors[1][4])
    end
end

local function Rect_OnUpdate(frame, elapsed)
    --! WotLK perf: остаток в локале, как в Icon_OnUpdate. Поле читалось трижды за
    --! кадр, а драйвер идёт на полном фреймрейте. Запись в `_remain` сохранена и
    --! стоит до вызова Rect_OnUpdateColor: тот читает поле, а не аргумент.
    local remain = frame._duration - (GetTime() - frame._start)
    if remain < 0 then remain = 0 end
    frame._remain = remain

    local e = frame._elapsed + elapsed
    if e >= 0.1 then
        e = 0
        -- update color
        Rect_OnUpdateColor(frame)
    end
    frame._elapsed = e

    if remain > frame._threshold then
        --! WotLK fix: blank the duration only on the state transition.
        if not frame._durationTextBlank then
            frame.duration:SetText("")
            frame._durationTextBlank = true
            frame._durationKey = nil
        end
        return
    end
    frame._durationTextBlank = nil

    SetDurationText(frame, remain)
end

local function Rect_SetCooldown(frame, start, duration, debuffType, texture, count)
    if duration == 0 then
        frame.tex:SetTexture(unpack(frame.colors[1]))
        frame:SetScript("OnUpdate", nil)
        frame.duration:Hide()
        frame._start = nil
        frame._duration = nil
        frame._remain = nil
        frame._elapsed = nil
        frame._threshold = nil
        frame._durationTextBlank = nil
    else
        if not frame.showDuration then
            frame._threshold = -1
            frame.duration:Hide()
        else
            if frame.showDuration == true then
                frame._threshold = duration
            elseif frame.showDuration >= 1 then
                frame._threshold = frame.showDuration
            else -- < 1
                frame._threshold = frame.showDuration * duration
            end
            frame.duration:Show()
        end

        frame._start = start
        frame._duration = duration
        frame._elapsed = 0.1 -- update immediately
        frame:SetScript("OnUpdate", Rect_OnUpdate)
    end

    frame.stack:SetText((count == 0 or count == 1) and "" or count)
    frame:Show()
end

local function Rect_SetColors(frame, colors)
    frame.state = nil
    frame.colors = colors
    frame:SetBackdropBorderColor(colors[4][1], colors[4][2], colors[4][3], colors[4][4])
end

local function Rect_UpdatePixelPerfect(frame)
    P.Resize(frame)
    P.Reborder(frame)
    P.Repoint(frame)
end

function I.CreateAura_Rect(name, parent)
    local frame = CreateFrame("Frame", name, parent, nil)
    frame:Hide()
    frame.indicatorType = "rect"
    frame:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(CELL_BORDER_SIZE)})
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    local tex = frame:CreateTexture(nil, "BORDER", nil, -7)
    frame.tex = tex
    tex:SetAllPoints()

    frame.stack = frame:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    frame.duration = frame:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")

    frame.SetFont = Rect_SetFont
    frame.SetCooldown = Rect_SetCooldown
    frame.SetColors = Rect_SetColors
    frame.ShowStack = Shared_ShowStack
    frame.ShowDuration = Shared_ShowDuration
    frame.SetupGlow = Shared_SetupGlow
    frame.UpdatePixelPerfect = Rect_UpdatePixelPerfect

    return frame
end

-------------------------------------------------
-- CreateAura_Bar
-------------------------------------------------
local function Bar_SetFont(bar, font1, font2)
    I.SetFont(bar.stack, bar, unpack(font1))
    I.SetFont(bar.duration, bar, unpack(font2))
end

local function Bar_OnUpdate(bar, elapsed)
    --! WotLK perf: остаток в локале; было три чтения поля (SetValue, порог, цвет
    --! или печать) на каждый кадр. SetValue обязана видеть текущее значение до
    --! цветового блока, поэтому запись поля стоит первой, до него.
    local remain = bar._duration - (GetTime() - bar._start)
    if remain < 0 then remain = 0 end
    bar._remain = remain
    bar:SetValue(remain)

    local e = bar._elapsed + elapsed
    if e >= 0.1 then
        e = 0
        -- update color
        if bar.colors[3][1] and remain <= bar.colors[3][2] then
            if bar.state ~= 3 then
                bar.state = 3
                bar:SetStatusBarColor(bar.colors[3][3][1], bar.colors[3][3][2], bar.colors[3][3][3], bar.colors[3][3][4])
            end
        elseif bar.colors[2][1] and remain <= bar._duration * bar.colors[2][2] then
            if bar.state ~= 2 then
                bar.state = 2
                bar:SetStatusBarColor(bar.colors[2][3][1], bar.colors[2][3][2], bar.colors[2][3][3], bar.colors[2][3][4])
            end
        elseif bar.state ~= 1 then
            bar.state = 1
            bar:SetStatusBarColor(bar.colors[1][1], bar.colors[1][2], bar.colors[1][3], bar.colors[1][4])
        end
    end
    bar._elapsed = e

    if remain > bar._threshold then
        --! WotLK fix: blank the duration only on the state transition.
        if not bar._durationTextBlank then
            bar.duration:SetText("")
            bar._durationTextBlank = true
            bar._durationKey = nil
        end
        return
    end
    bar._durationTextBlank = nil

    SetDurationText(bar, remain)
end

local function Bar_SetCooldown(bar, start, duration, debuffType, texture, count)
    if duration == 0 then
        bar:SetScript("OnUpdate", nil)
        bar.duration:Hide()
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar._start = nil
        bar._duration = nil
        bar._threshold = nil
        bar._remain = nil
        bar._elapsed = nil
        bar._durationTextBlank = nil
    else
        if not bar.showDuration then
            bar._threshold = -1
            bar.duration:Hide()
        else
            if bar.showDuration == true then
                bar._threshold = duration
            elseif bar.showDuration >= 1 then
                bar._threshold = bar.showDuration
            else -- < 1
                bar._threshold = bar.showDuration * duration
            end
            bar.duration:Show()
        end

        if bar.maxValue then
            bar:SetMinMaxValues(0, bar.allowSmaller and min(bar.maxValue, duration) or bar.maxValue)
        else
            bar:SetMinMaxValues(0, duration)
        end
        bar._start = start
        bar._duration = duration
        bar._elapsed = 0.1 -- update immediately
        bar:SetScript("OnUpdate", Bar_OnUpdate)
    end

    bar.stack:SetText((count == 0 or count == 1) and "" or count)
    bar:Show()
end

local function Bar_SetMaxValue(bar, maxValue)
    if maxValue[1]then
        bar.maxValue = maxValue[2]
        bar.allowSmaller = maxValue[3]
    else
        bar.maxValue = nil
        bar.allowSmaller = nil
    end
end

local function Bar_SetColors(bar, colors)
    bar:SetBackdropBorderColor(colors[4][1], colors[4][2], colors[4][3], colors[4][4])
    bar:SetBackdropColor(colors[5][1], colors[5][2], colors[5][3], colors[5][4])
    bar.state = nil
    bar.colors = colors
end

function I.CreateAura_Bar(name, parent)
    local bar = Cell.CreateStatusBar(name, parent, 18, 4, 100)
    bar:Hide()
    bar.indicatorType = "bar"

    bar.stack = bar:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    bar.duration = bar:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")

    bar.SetFont = Bar_SetFont
    bar.SetCooldown = Bar_SetCooldown
    bar.ShowStack = Shared_ShowStack
    bar.ShowDuration = Shared_ShowDuration
    bar.SetMaxValue = Bar_SetMaxValue
    bar.SetupGlow = Shared_SetupGlow
    bar.SetColors = Bar_SetColors

    return bar
end

-------------------------------------------------
-- CreateAura_Bars
-------------------------------------------------
local function Bars_OnUpdate(bar, elapsed)
    --! WotLK perf: остаток в локале, как в Bar_OnUpdate выше.
    local remain = bar._duration - (GetTime() - bar._start)
    if remain < 0 then remain = 0 end
    bar._remain = remain
    bar:SetValue(remain)

    if remain > bar._threshold then
        --! WotLK fix: blank the duration only on the state transition.
        if not bar._durationTextBlank then
            bar.duration:SetText("")
            bar._durationTextBlank = true
            bar._durationKey = nil
        end
        return
    end
    bar._durationTextBlank = nil

    SetDurationText(bar, remain)
end

local function Bars_SetCooldown(bar, start, duration, debuffType, texture, count, refreshing, color)
    if duration == 0 then
        bar:SetScript("OnUpdate", nil)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar.duration:Hide()
        bar._start = nil
        bar._duration = nil
        bar._remain = nil
        bar._threshold = nil
        bar._durationTextBlank = nil
    else
        if not bar.showDuration then
            bar._threshold = -1
            bar.duration:Hide()
        else
            if bar.showDuration == true then
                bar._threshold = duration
            elseif bar.showDuration >= 1 then
                bar._threshold = bar.showDuration
            else -- < 1
                bar._threshold = bar.showDuration * duration
            end
            bar.duration:Show()
        end

        if bar.maxValue then
            bar:SetMinMaxValues(0, bar.allowSmaller and min(bar.maxValue, duration) or bar.maxValue)
        else
            bar:SetMinMaxValues(0, duration)
        end
        bar._start = start
        bar._duration = duration
        bar:SetScript("OnUpdate", Bars_OnUpdate)
    end

    bar:SetStatusBarColor(color[1], color[2], color[3], color[4])
    bar:SetBackdropColor(color[1] * 0.2, color[2] * 0.2, color[3] * 0.2, color[4])
    bar.stack:SetText((count == 0 or count == 1) and "" or count)
    bar:Show()
end

local function Bars_SetMaxValue(bars, maxValue)
    for _, bar in ipairs(bars) do
        bar:SetMaxValue(maxValue)
    end
end

function I.CreateAura_Bars(name, parent, num)
    local bars = CreateFrame("Frame", name, parent)
    bars:Hide()

    bars.indicatorType = "bars"
    bars.maxNum = num
    bars.numPerLine = num

    bars._SetSize = bars.SetSize
    bars.SetSize = Icons_SetSize
    bars._Hide = bars.Hide
    bars.Hide = Icons_Hide
    bars.SetFont = Icons_SetFont
    bars.UpdateSize = Icons_UpdateSize
    bars.SetOrientation = Icons_SetOrientation
    bars.SetSpacing = Icons_SetSpacing
    bars.SetNumPerLine = Icons_SetNumPerLine
    bars.ShowDuration = Icons_ShowDuration
    bars.ShowStack = Icons_ShowStack
    bars.SetMaxValue = Bars_SetMaxValue
    bars.SetupGlow = I.Glow_SetupForChildren
    bars.UpdatePixelPerfect = Icons_UpdatePixelPerfect

    for i = 1, num do
        local name = name and name.."Icons"..i
        local frame = I.CreateAura_Bar(name, bars)
        bars[i] = frame
        frame.parent = bars
        frame.SetCooldown = Bars_SetCooldown
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end

    return bars
end

-------------------------------------------------
-- CreateAura_Color
-------------------------------------------------
local function Color_OnUpdate(color, elapsed)
    local e = color._elapsed + elapsed
    if e >= 0.1 then
        e = 0

        --! WotLK perf: остаток и длительность в локалях; поля читались четырежды.
        --! Кламп по нулю здесь не добавляю: его в этой функции не было и раньше,
        --! а отрицательный остаток и так попадает в первую ветвь порога.
        local duration = color._duration
        local remain = duration - (GetTime() - color._start)
        color._remain = remain
        -- update color
        if remain <= color.colors[6][1] then
            if color.state ~= 3 then
                color.state = 3
                color.solidTex:SetVertexColor(color.colors[6][2][1], color.colors[6][2][2], color.colors[6][2][3], color.colors[6][2][4])
            end
        elseif remain <= duration * color.colors[5][1] then
            if color.state ~= 2 then
                color.state = 2
                color.solidTex:SetVertexColor(color.colors[5][2][1], color.colors[5][2][2], color.colors[5][2][3], color.colors[5][2][4])
            end
        elseif color.state ~= 1 then
            color.state = 1
            color.solidTex:SetVertexColor(color.colors[4][1], color.colors[4][2], color.colors[4][3], color.colors[4][4])
        end
    end
    color._elapsed = e
end

local function Color_SetCooldown(color, start, duration, debuffType)
    if color.type == "change-over-time" then
        if duration == 0 then
            color.solidTex:SetVertexColor(unpack(color.colors[4]))
            color:SetScript("OnUpdate", nil)
            color._start = nil
            color._duration = nil
            color._remain = nil
            color._elapsed = nil
        else
            color._start = start
            color._duration = duration
            color._elapsed = 0.1 -- update immediately
            color:SetScript("OnUpdate", Color_OnUpdate)
        end
    elseif color.type == "class-color" then
        color.solidTex:SetVertexColor(F.GetClassColor(color.parent.states.class))
    elseif color.type == "debuff-type" and debuffType then
        color.solidTex:SetVertexColor(CellDB["debuffTypeColor"][debuffType]["r"], CellDB["debuffTypeColor"][debuffType]["g"], CellDB["debuffTypeColor"][debuffType]["b"], 1)
    end
    color:Show()
end

-- +6 ~ +55
local function Color_SetFrameLevel(color, frameLevel)
    color:_SetFrameLevel(frameLevel + 5)
end

local function Color_SetAnchor(color, anchorTo)
    color:ClearAllPoints()
    if anchorTo == "healthbar-current" then
        -- current hp texture
        color:SetAllPoints(color.parent.widgets.healthBar:GetStatusBarTexture())
    elseif anchorTo == "healthbar-loss" then
        -- lost texture
        color:SetAllPoints(color.parent.widgets.healthBarLoss)
    elseif anchorTo == "healthbar-entire" then
        -- entire hp bar
        color:SetAllPoints(color.parent.widgets.healthBar)
    else -- unitbutton
        P.Point(color, "TOPLEFT", color.parent, "TOPLEFT", CELL_BORDER_SIZE, -CELL_BORDER_SIZE)
        P.Point(color, "BOTTOMRIGHT", color.parent, "BOTTOMRIGHT", -CELL_BORDER_SIZE, CELL_BORDER_SIZE)
    end

    -- color:SetFrameLevel(color:GetParent():GetFrameLevel() + color.configs.frameLevel)
end

local function Color_SetColors(self, colors)
    self.state = nil
    self.type = colors[1]
    self.colors = colors

    --! WotLK fix: replaces the removed solidTex:SetScript("OnShow", ...) — Texture
    --! has no ScriptObject on 3.3.5, so SetScript is nil. Refreshing here covers
    --! every branch below and keeps the texture in sync with Appearance settings.
    self.solidTex:SetTexture(Cell.vars.texture)

    if colors[1] == "solid" then
        self:SetScript("OnUpdate", nil)
        self.solidTex:SetVertexColor(colors[2][1], colors[2][2], colors[2][3], colors[2][4])
        self.solidTex:Show()
        self.gradientTex:Hide()
    elseif colors[1] == "gradient-vertical" then
        self:SetScript("OnUpdate", nil)
        --! WotLK fix: Texture:SetGradientAlpha(orientation, r,g,b,a, r,g,b,a) is the
        --! native 3.3.5 form, so it is called directly. The retail color-object form
        --! SetGradient(orientation, color, color) does not exist on this client, and
        --! every call site here passes explicit alphas.
        self.gradientTex:SetGradientAlpha(
            "VERTICAL",
            colors[2][1], colors[2][2], colors[2][3], colors[2][4],
            colors[3][1], colors[3][2], colors[3][3], colors[3][4]
        )
        self.gradientTex:Show()
        self.solidTex:Hide()
    elseif colors[1] == "gradient-horizontal" then
        self:SetScript("OnUpdate", nil)
        --! WotLK fix: native SetGradientAlpha, same contract as the vertical branch.
        self.gradientTex:SetGradientAlpha(
            "HORIZONTAL",
            colors[2][1], colors[2][2], colors[2][3], colors[2][4],
            colors[3][1], colors[3][2], colors[3][3], colors[3][4]
        )
        self.gradientTex:Show()
        self.solidTex:Hide()
    elseif colors[1] == "debuff-type" then
        self:SetScript("OnUpdate", nil)
        self.solidTex:SetVertexColor(colors[2][1], colors[2][2], colors[2][3], colors[2][4])
        self.solidTex:Show()
        self.gradientTex:Hide()
    elseif colors[1] == "change-over-time" then
        self.solidTex:SetVertexColor(colors[4][1], colors[4][2], colors[4][3], colors[4][4])
        self.solidTex:Show()
        self.gradientTex:Hide()
    elseif colors[1] == "class-color" then
        self:SetScript("OnUpdate", nil)
        self.solidTex:Show()
        self.gradientTex:Hide()
    end
end

function I.CreateAura_Color(name, parent)
    local color = CreateFrame("Frame", name, parent)
    color:Hide()
    color.indicatorType = "color"
    color.parent = parent

    local solidTex = color:CreateTexture(nil, "ARTWORK")
    color.solidTex = solidTex
    solidTex:SetTexture(Cell.vars.texture)
    solidTex:SetAllPoints(color)
    solidTex:Hide()

    --! WotLK fix: Texture has no ScriptObject in its 3.3.5 inheritance chain, so
    --! Texture:SetScript is nil and this line crashed I.CreateIndicator for every
    --! custom indicator of type "color". The texture is refreshed in
    --! Color_SetColors instead, right before it is shown.

    local gradientTex = color:CreateTexture(nil, "ARTWORK")
    color.gradientTex = gradientTex
    gradientTex:SetTexture(Cell.vars.whiteTexture)
    gradientTex:SetAllPoints(color)
    gradientTex:Hide()

    color.SetCooldown = Color_SetCooldown
    color._SetFrameLevel = color.SetFrameLevel
    color.SetFrameLevel = Color_SetFrameLevel
    color.SetAnchor = Color_SetAnchor
    color.SetColors = Color_SetColors

    return color
end

-------------------------------------------------
-- CreateAura_Texture
-------------------------------------------------
local function Texture_OnUpdate(texture, elapsed)
    local e = texture._elapsed + elapsed
    if e >= 0.1 then
        e = 0

        --! WotLK perf: остаток и длительность в локалях; `_elapsed` пишется один
        --! раз за кадр вместо двух. Было четыре чтения полей на проход.
        local duration = texture._duration
        local remain = duration - (GetTime() - texture._start)
        if remain < 0 then remain = 0 end
        texture._remain = remain
        texture.tex:SetAlpha(remain / duration * 0.9 + 0.1)
    end
    texture._elapsed = e
end

local function Texture_SetCooldown(texture, start, duration)
    if duration ~= 0 and texture.fadeOut then
        texture._start = start
        texture._duration = duration
        texture._elapsed = 0.1 -- update immediately
        texture:SetScript("OnUpdate", Texture_OnUpdate)
    else
        texture:SetScript("OnUpdate", nil)
        texture.tex:SetAlpha(texture.colorAlpha)
        texture._start = nil
        texture._duration = nil
        texture._remain = nil
        texture._elapsed = nil
    end
    texture:Show()
end

local function Texture_SetFadeOut(texture, fadeOut)
    texture.fadeOut = fadeOut
end

local function Texture_SetTexture(texture, texTbl) -- texture, rotation, color
    --! WotLK fix: развилка interface/атлас убрана. На 3.3.5 нет системы атласов,
    --! а шим SetAtlas удалён - для имени, которого нет в чужом реестре, он молча
    --! ничего не делал, то есть индикатор оставался пустым вместо текстуры.
    --! Нативный SetTexture принимает путь; путь без "interface" он просто не
    --! найдёт и вернёт nil - это видимая ошибка вместо тихой.
    texture.tex:SetTexture(texTbl[1])
    texture.tex:SetRotation(texTbl[2] * math.pi / 180)
    texture.tex:SetVertexColor(unpack(texTbl[3]))
    texture.colorAlpha = texTbl[3][4]
end

function I.CreateAura_Texture(name, parent)
    local texture = CreateFrame("Frame", name, parent)
    texture:Hide()
    texture.indicatorType = "texture"

    local tex = texture:CreateTexture(name, "OVERLAY")
    texture.tex = tex
    tex:SetAllPoints(texture)

    texture.SetCooldown = Texture_SetCooldown
    texture.SetFadeOut = Texture_SetFadeOut
    texture.SetTexture = Texture_SetTexture

    return texture
end

-------------------------------------------------
-- CreateAura_Glow
-------------------------------------------------
local function Glow_OnUpdate(glow, elapsed)
    local e = glow._elapsed + elapsed
    if e >= 0.1 then
        e = 0

        --! WotLK perf: остаток и длительность в локалях; `_elapsed` пишется один
        --! раз за кадр вместо двух. Было четыре чтения полей на проход.
        local duration = glow._duration
        local remain = duration - (GetTime() - glow._start)
        if remain < 0 then remain = 0 end
        glow._remain = remain
        glow:SetAlpha(remain / duration * 0.9 + 0.1)
    end
    glow._elapsed = e
end

local function Glow_SetCooldown(glow, start, duration)
    if duration ~= 0 and glow.fadeOut then
        glow._start = start
        glow._duration = duration
        glow._elapsed = 0.1 -- update immediately
        glow:SetScript("OnUpdate", Glow_OnUpdate)
    else
        glow:SetScript("OnUpdate", nil)
        glow:SetAlpha(1)
        glow._start = nil
        glow._duration = nil
        glow._remain = nil
        glow._elapsed = nil
    end

    glow:Show()
end

function I.CreateAura_Glow(name, parent)
    local glow = CreateFrame("Frame", name, parent)
    glow:SetAllPoints(parent)
    glow:Hide()
    glow.indicatorType = "glow"

    glow.SetCooldown = Glow_SetCooldown

    function glow:SetFadeOut(fadeOut)
        glow.fadeOut = fadeOut
    end

    glow.SetupGlow = Shared_SetupGlow

    -- glow:SetScript("OnHide", function()
    --     LCG.ButtonGlow_Stop(glow)
    --     LCG.PixelGlow_Stop(glow)
    --     LCG.AutoCastGlow_Stop(glow)
    --     LCG.ProcGlow_Stop(glow)
    -- end)

    return glow
end

-------------------------------------------------
-- CreateAura_QuickAssistBars
-------------------------------------------------
local function QuickAssistBars_OnUpdate(bar, elapsed)
    --! WotLK perf: остаток в локале - было три чтения поля на кадр.
    local remain = bar._duration - (GetTime() - bar._start)
    if remain < 0 then remain = 0 end
    bar._remain = remain
    bar:SetValue(remain)
end

local function QuickAssistBars_SetCooldown(bar, start, duration, color)
    if duration == 0 then
        bar:SetScript("OnUpdate", nil)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar._start = nil
        bar._duration = nil
        bar._remain = nil
    else
        bar._start = start
        bar._duration = duration
        bar:SetMinMaxValues(0, duration)
        bar:SetScript("OnUpdate", QuickAssistBars_OnUpdate)
    end

    bar:SetStatusBarColor(color[1], color[2], color[3], 1)
    bar:Show()
end

local function QuickAssistBars_UpdateSize(bars, barsShown)
    if not (bars.width and bars.height) then return end -- not init
    --! WotLK fix: комментарий "call from I.CheckCustomIndicators" тут был скопирован от
    --! Icons_UpdateSize и врал: этот вариант нужен только Quick Assist, а модуля Quick
    --! Assist в форке нет (нет файла в Modules/, нет дефолтов, нет панели опций), поэтому
    --! I.CreateAura_QuickAssistBars никто не вызывает - он оставлен как задел и записан
    --! в NS_KNOWN_UNREAD гейта namespace-целостности (GAP-052).
    if barsShown then
        for i = barsShown + 1, bars.num do
            bars[i]:Hide()
        end
        if barsShown ~= 0 then
            bars:_SetSize(bars.width, bars.height*barsShown-P.Scale(1)*(barsShown-1))
        end
    else
        for i = 1, bars.num do
            if bars[i]:IsShown() then
                bars:_SetSize(bars.width, bars.height*i-P.Scale(1)*(i-1))
            else
                break
            end
        end
    end
end

local function QuickAssistBars_SetSize(bars, width, height)
    bars.width = width
    bars.height = height

    for i = 1, bars.num do
        bars[i]:SetSize(width, height)
    end

    bars:UpdateSize()
end

local function QuickAssistBars_SetOrientation(bars, orientation)
    local point1, point2, offset
    if orientation == "top-to-bottom" then
        point1 = "TOPLEFT"
        point2 = "BOTTOMLEFT"
        offset = 1
    elseif orientation == "bottom-to-top" then
        point1 = "BOTTOMLEFT"
        point2 = "TOPLEFT"
        offset = -1
    end

    for i = 1, bars.num do
        P.ClearPoints(bars[i])
        if i == 1 then
            P.Point(bars[i], point1)
        else
            P.Point(bars[i], point1, bars[i-1], point2, 0, offset)
        end
    end

    bars:UpdateSize()
end

local function QuickAssistBars_Hide(bars, hideAll)
    bars:_Hide()
    if hideAll then
        for i = 1, bars.num do
            bars[i]:Hide()
        end
    end
end

local function QuickAssistBars_UpdatePixelPerfect(bars)
    -- P.Resize(bars)
    P.Repoint(bars)
    for i = 1, bars.num do
        bars[i]:UpdatePixelPerfect()
    end
end

function I.CreateAura_QuickAssistBars(name, parent, num)
    local bars = CreateFrame("Frame", name, parent)
    bars:Hide()
    bars.indicatorType = "bars"
    bars.num = num

    bars._SetSize = bars.SetSize
    bars.SetSize = QuickAssistBars_SetSize
    bars.UpdateSize = QuickAssistBars_UpdateSize
    bars.SetOrientation = QuickAssistBars_SetOrientation
    bars._Hide = bars.Hide
    bars.Hide = QuickAssistBars_Hide
    bars.UpdatePixelPerfect = QuickAssistBars_UpdatePixelPerfect

    for i = 1, num do
        local name = name and name.."Bar"..i
        local bar = I.CreateAura_Bar(name, bars)
        bars[i] = bar

        bar.stack:Hide()
        bar.duration:Hide()
        bar.SetCooldown = QuickAssistBars_SetCooldown
    end

    return bars
end

-------------------------------------------------
-- CreateAura_Overlay
-------------------------------------------------
local function Overlay_OnUpdate(overlay, elapsed)
    --! WotLK perf: остаток в локале - было четыре чтения поля за кадр.
    local remain = overlay._duration - (GetTime() - overlay._start)
    if remain < 0 then remain = 0 end
    overlay._remain = remain
    overlay:_SetValue(remain)

    local e = overlay._elapsed + elapsed
    if e >= 0.1 then
        e = 0
        -- update color
        if overlay.colors[3][1] and remain <= overlay.colors[3][2] then
            if overlay.state ~= 3 then
                overlay.state = 3
                overlay:SetStatusBarColor(overlay.colors[3][3][1], overlay.colors[3][3][2], overlay.colors[3][3][3], overlay.colors[3][3][4])
            end
        elseif overlay.colors[2][1] and remain <= overlay._duration * overlay.colors[2][2] then
            if overlay.state ~= 2 then
                overlay.state = 2
                overlay:SetStatusBarColor(overlay.colors[2][3][1], overlay.colors[2][3][2], overlay.colors[2][3][3], overlay.colors[2][3][4])
            end
        elseif overlay.state ~= 1 then
            overlay.state = 1
            overlay:SetStatusBarColor(overlay.colors[1][1], overlay.colors[1][2], overlay.colors[1][3], overlay.colors[1][4])
        end
    end
    overlay._elapsed = e
end

local function Overlay_SetCooldown(overlay, start, duration, debuffType, texture, count)
    if duration == 0 then
        overlay:SetScript("OnUpdate", nil)
        overlay:_SetMinMaxValues(0, 1)
        overlay:_SetValue(1)
        overlay:SetStatusBarColor(unpack(overlay.colors[1]))
        overlay._start = nil
        overlay._duration = nil
        overlay._remain = nil
        overlay._elapsed = nil
    else
        overlay:_SetMinMaxValues(0, duration)
        overlay._start = start
        overlay._duration = duration
        overlay._elapsed = 0.1 -- update immediately
        overlay:SetScript("OnUpdate", Overlay_OnUpdate)
    end

    overlay:Show()
end

local function Overlay_EnableSmooth(overlay, smooth)
    if smooth then
        overlay._SetMinMaxValues = overlay.SetMinMaxSmoothedValue
        overlay._SetValue = overlay.SetSmoothedValue
    else
        overlay._SetMinMaxValues = overlay.SetMinMaxValues
        overlay._SetValue = overlay.SetValue
    end
end

local function Overlay_SetColors(overlay, colors)
    overlay.state = nil
    overlay.colors = colors
end

-- +56 ~ +110
local function Overlay_SetFrameLevel(overlay, frameLevel)
    overlay:_SetFrameLevel(frameLevel + 55)
end

function I.CreateAura_Overlay(name, parent)
    local overlay = CreateFrame("StatusBar", name, parent.widgets.healthBar)
    overlay:SetStatusBarTexture(Cell.vars.whiteTexture)
    overlay:Hide()
    overlay.indicatorType = "overlay"

    ApplySmoothStatusBarMixin(overlay) --! WotLK fix: Cell-private smoothing owner.
    overlay:SetAllPoints()
    -- overlay:SetBackdropColor(0, 0, 0, 0)

    overlay.SetCooldown = Overlay_SetCooldown
    overlay._SetMinMaxValues = overlay.SetMinMaxValues
    overlay._SetValue = overlay.SetValue
    overlay._SetFrameLevel = overlay.SetFrameLevel
    overlay.SetFrameLevel = Overlay_SetFrameLevel
    overlay.EnableSmooth = Overlay_EnableSmooth
    overlay.SetColors = Overlay_SetColors

    return overlay
end

-------------------------------------------------
-- CreateAura_Block
-------------------------------------------------
local function Block_OnUpdate_Duration(frame, elapsed)
    --! WotLK perf: остаток в локале - было четыре чтения поля за кадр.
    local remain = frame._duration - (GetTime() - frame._start)
    if remain < 0 then remain = 0 end
    frame._remain = remain

    local e = frame._elapsed + elapsed
    if e >= 0.1 then
        e = 0
        -- update color
        if frame.colors[4][1] and remain <= frame.colors[4][2] then
            if frame.state ~= 3 then
                frame.state = 3
                frame:SetBackdropColor(frame.colors[4][3][1], frame.colors[4][3][2], frame.colors[4][3][3], frame.colors[4][3][4])
            end
        elseif frame.colors[3][1] and remain <= frame._duration * frame.colors[3][2] then
            if frame.state ~= 2 then
                frame.state = 2
                frame:SetBackdropColor(frame.colors[3][3][1], frame.colors[3][3][2], frame.colors[3][3][3], frame.colors[3][3][4])
            end
        elseif frame.state ~= 1 then
            frame.state = 1
            frame:SetBackdropColor(frame.colors[2][1], frame.colors[2][2], frame.colors[2][3], frame.colors[2][4])
        end
    end
    frame._elapsed = e

    if remain > frame._threshold then
        --! WotLK fix: blank the duration only on the state transition.
        if not frame._durationTextBlank then
            frame.duration:SetText("")
            frame._durationTextBlank = true
            frame._durationKey = nil
        end
        return
    end
    frame._durationTextBlank = nil

    SetDurationText(frame, remain)
end

local function Block_SetCooldown_Duration(frame, start, duration, debuffType, texture, count, refreshing)
    -- local r, g, b
    -- if debuffType then
    --     r, g, b = I.GetDebuffTypeColor(debuffType)
    -- else
    --     r, g, b = 0, 0, 0
    -- end

    if duration == 0 then
        frame.cooldown:Hide()
        frame.duration:Hide()
        frame:SetScript("OnUpdate", nil)
        frame._start = nil
        frame._duration = nil
        frame._remain = nil
        frame._elapsed = nil
        frame._threshold = nil
        frame._durationTextBlank = nil
    else
        -- frame.cooldown:SetSwipeColor(r, g, b)
        frame.cooldown:ShowCooldown(start, duration)

        if not frame.showDuration then
            frame._threshold = -1
            frame.duration:Hide()
        else
            if frame.showDuration == true then
                frame._threshold = duration
            elseif frame.showDuration >= 1 then
                frame._threshold = frame.showDuration
            else -- < 1
                frame._threshold = frame.showDuration * duration
            end
            frame.duration:Show()
        end

        frame._start = start
        frame._duration = duration
        frame._elapsed = 0.1 -- update immediately
        frame:SetScript("OnUpdate", Block_OnUpdate_Duration)
    end

    frame.stack:SetText((count == 0 or count == 1) and "" or count)
    frame:Show()

    --! custom: jump (refresh) animation is now optional; nil = enabled
    --! (upstream plays it unconditionally, see SESSION_NOTES #20)
    if refreshing and frame.showJump ~= false then
        frame.ag:Play()
    end
end

local function Block_OnUpdate_Stack(frame, elapsed)
    --! WotLK perf: остаток в локале, как в Icon_OnUpdate наверху файла.
    local remain = frame._duration - (GetTime() - frame._start)
    if remain < 0 then remain = 0 end
    frame._remain = remain

    if remain > frame._threshold then
        --! WotLK fix: blank the duration only on the state transition.
        if not frame._durationTextBlank then
            frame.duration:SetText("")
            frame._durationTextBlank = true
            frame._durationKey = nil
        end
        return
    end
    frame._durationTextBlank = nil

    SetDurationText(frame, remain)
end

local function Block_SetCooldown_Stack(frame, start, duration, debuffType, texture, count, refreshing)
    if duration == 0 then
        frame.cooldown:Hide()
        frame.duration:Hide()
        frame:SetScript("OnUpdate", nil)
        frame._start = nil
        frame._duration = nil
        frame._remain = nil
        frame._threshold = nil
        frame._durationTextBlank = nil
    else
        -- frame.cooldown:SetSwipeColor(r, g, b)
        frame.cooldown:ShowCooldown(start, duration)

        if not frame.showDuration then
            frame._threshold = -1
            frame.duration:Hide()
        else
            if frame.showDuration == true then
                frame._threshold = duration
            elseif frame.showDuration >= 1 then
                frame._threshold = frame.showDuration
            else -- < 1
                frame._threshold = frame.showDuration * duration
            end
            frame.duration:Show()
        end

        frame._start = start
        frame._duration = duration
        frame:SetScript("OnUpdate", Block_OnUpdate_Stack)
    end

    -- update color
    if frame.colors[4][1] and count >= frame.colors[4][2] then
        frame:SetBackdropColor(frame.colors[4][3][1], frame.colors[4][3][2], frame.colors[4][3][3], frame.colors[4][3][4])
    elseif frame.colors[3][1] and count >= frame.colors[3][2] then
        frame:SetBackdropColor(frame.colors[3][3][1], frame.colors[3][3][2], frame.colors[3][3][3], frame.colors[3][3][4])
    else
        frame:SetBackdropColor(frame.colors[2][1], frame.colors[2][2], frame.colors[2][3], frame.colors[2][4])
    end

    frame.stack:SetText((count == 0 or count == 1) and "" or count)
    frame:Show()

    --! custom: jump (refresh) animation is now optional; nil = enabled
    --! (upstream plays it unconditionally, see SESSION_NOTES #20)
    if refreshing and frame.showJump ~= false then
        frame.ag:Play()
    end
end

local function Block_SetColors(frame, colors)
    if colors[1] == "duration" then
        frame.SetCooldown = Block_SetCooldown_Duration
    else
        frame.SetCooldown = Block_SetCooldown_Stack
    end
    frame:SetBackdropBorderColor(colors[5][1], colors[5][2], colors[5][3], colors[5][4])
    frame.state = nil
    frame.colors = colors
end

local function Block_UpdatePixelPerfect(frame)
    P.Resize(frame)
    P.Repoint(frame)
    P.Repoint(frame.stack)
    P.Repoint(frame.duration)
    P.Repoint(frame.cooldown)
    P.Reborder(frame)
    if frame.cooldown.spark then
        P.Resize(frame.cooldown.spark)
    end
end

function I.CreateAura_Block(name, parent)
    local frame = CreateFrame("Frame", name, parent, nil)
    frame:Hide()
    frame.indicatorType = "block"

    frame:SetBackdrop({bgFile = Cell.vars.whiteTexture, edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(CELL_BORDER_SIZE)})

    Shared_SetCooldownStyle(frame, CELL_COOLDOWN_STYLE, true)

    frame.stack = frame.cooldown:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    frame.duration = frame.cooldown:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")

    frame.SetFont = Shared_SetFont
    frame.SetColors = Block_SetColors
    frame.ShowStack = Shared_ShowStack
    frame.ShowDuration = Shared_ShowDuration
    frame.ShowJump = Shared_ShowJump
    frame.SetCooldown = Block_SetCooldown_Duration
    frame.SetupGlow = Shared_SetupGlow
    frame.UpdatePixelPerfect = Block_UpdatePixelPerfect

    local ag = frame:CreateAnimationGroup()
    frame.ag = ag
    local t1 = ag:CreateAnimation("Translation")
    t1:SetOffset(0, 5)
    t1:SetDuration(0.1)
    t1:SetOrder(1)
    t1:SetSmoothing("OUT")
    local t2 = ag:CreateAnimation("Translation")
    t2:SetOffset(0, -5)
    t2:SetDuration(0.1)
    t2:SetOrder(2)
    t2:SetSmoothing("IN")

    Shared_SyncJumpToChildren(frame) --! WotLK: children don't follow parent AG

    return frame
end

-------------------------------------------------
-- CreateAura_Blocks
-------------------------------------------------
local function Blocks_OnUpdate(frame, elapsed)
    --! WotLK perf: остаток в локале, как в Icon_OnUpdate наверху файла.
    local remain = frame._duration - (GetTime() - frame._start)
    if remain < 0 then remain = 0 end
    frame._remain = remain

    if remain > frame._threshold then
        --! WotLK fix: blank the duration only on the state transition.
        if not frame._durationTextBlank then
            frame.duration:SetText("")
            frame._durationTextBlank = true
            frame._durationKey = nil
        end
        return
    end
    frame._durationTextBlank = nil

    SetDurationText(frame, remain)
end

local function Blocks_SetCooldown(frame, start, duration, debuffType, texture, count, refreshing, color)
    if duration == 0 then
        frame.cooldown:Hide()
        frame.duration:Hide()
        frame:SetScript("OnUpdate", nil)
        frame._start = nil
        frame._duration = nil
        frame._remain = nil
        frame._threshold = nil
        frame._durationTextBlank = nil
    else
        frame.cooldown:ShowCooldown(start, duration)

        if not frame.showDuration then
            frame._threshold = -1
            frame.duration:Hide()
        else
            if frame.showDuration == true then
                frame._threshold = duration
            elseif frame.showDuration >= 1 then
                frame._threshold = frame.showDuration
            else -- < 1
                frame._threshold = frame.showDuration * duration
            end
            frame.duration:Show()
        end

        frame._start = start
        frame._duration = duration
        frame:SetScript("OnUpdate", Blocks_OnUpdate)
    end

    frame:SetBackdropColor(color[1], color[2], color[3], color[4])
    frame.stack:SetText((count == 0 or count == 1) and "" or count)
    frame:Show()

    --! custom: jump (refresh) animation is now optional; nil = enabled
    --! (upstream plays it unconditionally, see SESSION_NOTES #20)
    if refreshing and frame.showJump ~= false then
        frame.ag:Play()
    end
end

function I.CreateAura_Blocks(name, parent, num)
    local blocks = CreateFrame("Frame", name, parent)
    blocks:Hide()

    blocks.indicatorType = "blocks"
    blocks.maxNum = num
    blocks.numPerLine = num

    blocks._SetSize = blocks.SetSize
    blocks.SetSize = Icons_SetSize
    blocks._Hide = blocks.Hide
    blocks.Hide = Icons_Hide
    blocks.SetFont = Icons_SetFont
    blocks.UpdateSize = Icons_UpdateSize
    blocks.SetOrientation = Icons_SetOrientation
    blocks.SetSpacing = Icons_SetSpacing
    blocks.SetNumPerLine = Icons_SetNumPerLine
    blocks.ShowDuration = Icons_ShowDuration
    blocks.ShowStack = Icons_ShowStack
    blocks.ShowJump = Icons_ShowJump
    blocks.SetupGlow = I.Glow_SetupForChildren
    blocks.UpdatePixelPerfect = Icons_UpdatePixelPerfect

    for i = 1, num do
        local name = name and name.."Icons"..i
        local frame = I.CreateAura_Block(name, blocks)
        blocks[i] = frame
        frame.SetCooldown = Blocks_SetCooldown
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end

    return blocks
end

-------------------------------------------------
-- CreateAura_Border
-------------------------------------------------
local function Border_OnUpdate(border, elapsed)
    local e = border._elapsed + elapsed
    if e >= 0.1 then
        e = 0

        --! WotLK perf: остаток и длительность в локалях; `_elapsed` пишется один
        --! раз за кадр вместо двух. Было четыре чтения полей на проход.
        local duration = border._duration
        local remain = duration - (GetTime() - border._start)
        if remain < 0 then remain = 0 end
        border._remain = remain
        border:SetAlpha(remain / duration * 0.9 + 0.1)
    end
    border._elapsed = e
end

local function Border_SetFadeOut(border, fadeOut)
    border.fadeOut = fadeOut
end

local function Border_SetCooldown(border, start, duration, _, _, _, _, color)
    if duration ~= 0 and border.fadeOut then
        border._start = start
        border._duration = duration
        border._elapsed = 0.1 -- update immediately
        border:SetScript("OnUpdate", Border_OnUpdate)
    else
        border:SetScript("OnUpdate", nil)
        border._start = nil
        border._duration = nil
        border._remain = nil
        border._elapsed = nil
        border:SetAlpha(1)
    end
    border.tex:SetVertexColor(color[1], color[2], color[3], color[4])
    border:Show()
end

--! WotLK fix: Border_UpdatePixelPerfect и Border_SetThickness удалены вместе с
--! ретейл-телом I.CreateAura_Border - обе работали по border.mask/border.mask2,
--! которых на 3.3.5 нет, и других вызывающих у них не было. Их роль исполняют
--! WrathBorder_UpdatePixelPerfect и WrathBorder_SetThickness ниже.

--! WotLK fix: the retail border is a full-size colored texture whose CENTER
--! is cut away by two mask textures - on 3.3.5 masks are no-op polyfills,
--! so the "border" custom indicator flooded the whole unit button with a
--! solid color. Rebuild it from four edge textures (hollow frame), keeping
--! the same API surface (tex:SetVertexColor, SetThickness, SetCooldown,
--! UpdatePixelPerfect).
local function WrathBorder_SetVertexColor(proxy, r, g, b, a)
    local edges = proxy._edges
    for i = 1, 4 do
        edges[i]:SetVertexColor(r, g, b, a)
    end
end

local function WrathBorder_SetThickness(border, thickness)
    border._thickness = thickness
    local top, bottom, left, right = border._top, border._bottom, border._left, border._right
    P.ClearPoints(top)
    P.Point(top, "TOPLEFT")
    P.Point(top, "TOPRIGHT")
    P.Height(top, thickness)
    P.ClearPoints(bottom)
    P.Point(bottom, "BOTTOMLEFT")
    P.Point(bottom, "BOTTOMRIGHT")
    P.Height(bottom, thickness)
    P.ClearPoints(left)
    P.Point(left, "TOPLEFT", 0, -thickness)
    P.Point(left, "BOTTOMLEFT", 0, thickness)
    P.Width(left, thickness)
    P.ClearPoints(right)
    P.Point(right, "TOPRIGHT", 0, -thickness)
    P.Point(right, "BOTTOMRIGHT", 0, thickness)
    P.Width(right, thickness)
end

local function WrathBorder_UpdatePixelPerfect(border)
    P.Repoint(border)
    WrathBorder_SetThickness(border, border._thickness or 1)
end

function I.CreateAura_Border(name, parent)
    local border = CreateFrame("Frame", name, parent)
    border:Hide()
    border.indicatorType = "border"

    P.Point(border, "TOPLEFT", CELL_BORDER_SIZE, -CELL_BORDER_SIZE)
    P.Point(border, "BOTTOMRIGHT", -CELL_BORDER_SIZE, CELL_BORDER_SIZE)

    local edges = {}
    for i = 1, 4 do
        local tex = border:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(Cell.vars.whiteTexture)
        edges[i] = tex
    end
    border._top, border._bottom, border._left, border._right = edges[1], edges[2], edges[3], edges[4]

    -- proxy keeps Border_SetCooldown's `border.tex:SetVertexColor(...)` working
    border.tex = {_edges = edges, SetVertexColor = WrathBorder_SetVertexColor}

    WrathBorder_SetThickness(border, 1)

    border.SetCooldown = Border_SetCooldown
    border.SetFadeOut = Border_SetFadeOut
    border.SetThickness = WrathBorder_SetThickness
    border.UpdatePixelPerfect = WrathBorder_UpdatePixelPerfect

    return border
end
