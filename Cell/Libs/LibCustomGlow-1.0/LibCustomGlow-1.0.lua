--[[
This library contains work of Hendrick "nevcairiel" Leppkes
https://www.wowace.com/projects/libbuttonglow-1-0
]]

--! WotLK fix: this Cell fork owns its texture/frame/mask pools below and does
--! not consume ClassicAPI's global pool mixins or constructors.

local MAJOR_VERSION = "LibCustomGlow-1.0-Cell"
local MINOR_VERSION = 99
if not LibStub then error(MAJOR_VERSION .. " requires LibStub.") end
local lib, oldversion = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end
local Masque = LibStub("Masque", true)

--! WotLK fix: defer native animation cancellation out of Frame/Animation
--! callbacks. Build 12340 can crash in AnimationGroup:Stop() when a stop
--! handler releases and hides the same animation owner reentrantly.
local C_Timer = _G.Cell and _G.Cell.C_Timer
assert(C_Timer, MAJOR_VERSION .. " requires Cell.C_Timer")

--! WotLK perf: floor и sin зовутся из драйверов на полном фреймрейте: pCalc1 и
--! pCalc2 - по два раза на текстуру за кадр из pUpdate (при N=8 это 32 вызова на
--! кадр на один глоу), SetTile - из FlipbookAnimation_OnUpdate, sin - из
--! PulseAnimation_OnUpdate. Файловый локал убирает из каждого вызова GETGLOBAL
--! math (хеш-лукап в _G) плюс хеш-лукап поля. Тот же приём и по той же причине
--! уже применён в Indicators/Base.lua и Built-in.lua. Два math.min ниже (ветки
--! перекраски в ButtonGlow_Start) оставлены как есть - это холодный путь
--! настройки, а не кадровый.
local floor = math.floor
local sin = math.sin

--! WotLK fix: this is the only active texture-sheet consumer. Keep the animator
--! private instead of depending on or publishing the retail AnimateTexCoords global.
local function AnimateTexCoords(texture, width, height, frameWidth, frameHeight, numFrames, elapsed, throttle)
    throttle = throttle or 0.1
    if not texture.frame then
        texture.frame = 0
        texture.throttleTimer = 0
        texture.maxFrames = numFrames
        texture.numColumns = floor(width / frameWidth)
        texture.columnWidth = frameWidth / width
        texture.rowHeight = frameHeight / height
    end

    texture.throttleTimer = texture.throttleTimer + elapsed
    if texture.throttleTimer >= throttle then
        local frame = (texture.frame + 1) % texture.maxFrames
        texture.frame = frame
        texture.throttleTimer = 0

        local column = frame % texture.numColumns
        local row = floor(frame / texture.numColumns)
        local left = column * texture.columnWidth
        local top = row * texture.rowHeight
        texture:SetTexCoord(left, left + texture.columnWidth, top, top + texture.rowHeight)
    end
end

local textureList = {
    empty = [[Interface\AdventureMap\BrokenIsles\AM_29]],
    white = [[Interface\BUTTONS\WHITE8X8]],
    shine = [[Interface\ItemSocketingFrame\UI-ItemSockets]]
}

local shineCoords = {0.3984375, 0.4453125, 0.40234375, 0.44921875}

--! WotLK fix: bundled textures for glows whose retail art does not exist on 3.3.5.
--! Interface\SpellActivationOverlay\IconAlert(+Ants) was added in 4.0 and the proc
--! flipbook sheet is a 10.x atlas, so both "Action Button Glow" and "Proc Glow"
--! rendered NOTHING on 3.3.5 (SetTexture on a missing file draws nothing at all).
--! The .blp files are bundled next to this lib, same way WeakAuras-WotLK ships them.
local texturePath = [[Interface\AddOns\Cell\Libs\LibCustomGlow-1.0\]]

function lib.RegisterTextures(texture,id)
    textureList[id] = texture
end

lib.glowList = {}
lib.startList = {}
lib.stopList = {}

local GlowParent = UIParent

--! WotLK fix: own mask capability and attachment bookkeeping inside this
--! library. Never rely on, probe, or add methods on the shared Texture
--! metatable; standalone !!!ClassicAPI may publish void stubs there.
local GlowMaskPool
local GlowTextureMasks = setmetatable({}, {__mode = "k"})
local NativeCreateMaskTexture = not (_G.Cell and _G.Cell.isWrath)
    and type(GlowParent.CreateMaskTexture) == "function"
    and GlowParent.CreateMaskTexture

local function GlowTextureAddMask(texture, mask)
    if not (NativeCreateMaskTexture and texture.AddMaskTexture and mask) then
        return false
    end

    local masks = GlowTextureMasks[texture]
    if not masks then
        masks = {}
        GlowTextureMasks[texture] = masks
    end

    if not masks[mask] then
        texture:AddMaskTexture(mask)
        masks[mask] = true
    end
    return true
end

local function GlowTextureRemoveAllMasks(texture)
    local masks = GlowTextureMasks[texture]
    if masks then
        if texture.RemoveMaskTexture then
            for mask in pairs(masks) do
                texture:RemoveMaskTexture(mask)
            end
        end
        GlowTextureMasks[texture] = nil
    end
end

if NativeCreateMaskTexture then
    GlowMaskPool = {
        createFunc = function(self)
            return NativeCreateMaskTexture(self.parent)
        end,
        resetFunc = function(self, mask)
            mask:Hide()
            mask:ClearAllPoints()
        end,
        AddObject = function(self, object)
            self.activeObjects[object] = true
            self.activeObjectCount = self.activeObjectCount + 1
        end,
        ReclaimObject = function(self, object)
            tinsert(self.inactiveObjects, object)
            self.activeObjects[object] = nil
            self.activeObjectCount = self.activeObjectCount - 1
        end,
        Release = function(self, object)
            local active = self.activeObjects[object] ~= nil
            if active then
                self:resetFunc(object)
                self:ReclaimObject(object)
            end
            return active
        end,
        Acquire = function(self)
            local object = tremove(self.inactiveObjects)
            local new = object == nil
            if new then
                object = self:createFunc()
                self:resetFunc(object)
            end
            self:AddObject(object)
            return object, new
        end,
        Init = function(self, parent)
            self.activeObjects = {}
            self.inactiveObjects = {}
            self.activeObjectCount = 0
            self.parent = parent
        end,
    }
    GlowMaskPool:Init(GlowParent)
end

local TexPoolResetter = function(pool,tex)
    GlowTextureRemoveAllMasks(tex)
    tex:Hide()
    tex:ClearAllPoints()
end

-- Custom texture pool for WotLK compatibility
local GlowTexPool = {
    parent = GlowParent,
    inactive = {},
    active = {},
    count = 0,
}
function GlowTexPool:Acquire()
    local tex = tremove(self.inactive)
    if not tex then
        self.count = self.count + 1
        tex = self.parent:CreateTexture(nil, "ARTWORK", nil, 7)
    end
    self.active[tex] = true
    return tex
end
function GlowTexPool:Release(tex)
    if self.active[tex] then
        self.active[tex] = nil
        TexPoolResetter(self, tex)
        tinsert(self.inactive, tex)
    end
end
lib.GlowTexPool = GlowTexPool

local FramePoolResetter = function(framePool,frame)
    frame:SetScript("OnUpdate",nil)
    local parent = frame:GetParent()
    if parent and frame.name and parent[frame.name] then
        parent[frame.name] = nil
    end
    if frame.textures then
        for _, texture in pairs(frame.textures) do
            GlowTexPool:Release(texture)
        end
    end
    if frame.bg then
        GlowTexPool:Release(frame.bg)
        frame.bg = nil
    end
    if frame.masks then
        --! WotLK fix: GlowMaskPool only exists when this client exposes real
        --! mask regions. Wrath renders PixelGlow without mask objects.
        if GlowMaskPool then
            for _,mask in pairs(frame.masks) do
                GlowMaskPool:Release(mask)
            end
        end
        frame.masks = nil
    end
    frame.textures = {}
    frame.info = {}
    frame.name = nil
    frame.timer = nil
    frame:Hide()
    frame:ClearAllPoints()
end

-- Custom frame pool for WotLK compatibility
local GlowFramePool = {
    parent = GlowParent,
    inactive = {},
    active = {},
    count = 0,
}
function GlowFramePool:Acquire()
    local frame = tremove(self.inactive)
    if not frame then
        self.count = self.count + 1
        frame = CreateFrame("Frame", nil, self.parent)
    end
    self.active[frame] = true
    return frame
end
function GlowFramePool:Release(frame)
    if self.active[frame] then
        self.active[frame] = nil
        FramePoolResetter(self, frame)
        tinsert(self.inactive, frame)
    end
end
lib.GlowFramePool = GlowFramePool

local function addFrameAndTex(r,color,name,key,N,xOffset,yOffset,texture,texCoord,desaturated,frameLevel)
    key = key or ""
	frameLevel = frameLevel or 8
    if not r[name..key] then
        r[name..key] = GlowFramePool:Acquire()
        r[name..key]:SetParent(r)
        r[name..key].name = name..key
    end
    local f = r[name..key]
	f:SetFrameLevel(r:GetFrameLevel()+frameLevel)
    f:SetPoint("TOPLEFT",r,"TOPLEFT",-xOffset+0.05,yOffset+0.05)
    f:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",xOffset,-yOffset+0.05)
    f:Show()

    if not f.textures then
        f.textures = {}
    end

    for i=1,N do
        if not f.textures[i] then
            f.textures[i] = GlowTexPool:Acquire()
            f.textures[i]:SetTexture(texture)
            f.textures[i]:SetTexCoord(texCoord[1],texCoord[2],texCoord[3],texCoord[4])
            f.textures[i]:SetDesaturated(desaturated)
            f.textures[i]:SetParent(f)
            f.textures[i]:SetDrawLayer("ARTWORK",7)
            if name == "_AutoCastGlow" then
                f.textures[i]:SetBlendMode("ADD")
            end
        end
        f.textures[i]:SetVertexColor(color[1],color[2],color[3],color[4])
        f.textures[i]:Show()
    end
    while #f.textures>N do
        GlowTexPool:Release(f.textures[#f.textures])
        table.remove(f.textures)
    end
end


--Pixel Glow Functions--
local pCalc1 = function(progress,s,th,p)
    local c
    if progress>p[3] or progress<p[0] then
        c = 0
    elseif progress>p[2] then
        c =s-th-(progress-p[2])/(p[3]-p[2])*(s-th)
    elseif progress>p[1] then
        c =s-th
    else
        c = (progress-p[0])/(p[1]-p[0])*(s-th)
    end
    return floor(c+0.5)
end

local pCalc2 = function(progress,s,th,p)
    local c
    if progress>p[3] then
        c = s-th-(progress-p[3])/(p[0]+1-p[3])*(s-th)
    elseif progress>p[2] then
        c = s-th
    elseif progress>p[1] then
        c = (progress-p[1])/(p[2]-p[1])*(s-th)
    elseif progress>p[0] then
        c = 0
    else
        c = s-th-(progress+1-p[3])/(p[0]+1-p[3])*(s-th)
    end
    return floor(c+0.5)
end

local  pUpdate = function(self,elapsed)
    self.timer = self.timer+elapsed/self.info.period
    if self.timer>1 or self.timer <-1 then
        self.timer = self.timer%1
    end
    local progress = self.timer
    local width,height = self:GetSize()
    if width ~= self.info.width or height ~= self.info.height then
        local perimeter = 2*(width+height)
        if not (perimeter>0) then
            return
        end
        self.info.width = width
        self.info.height = height
        self.info.pTLx = {
            [0] = (height+self.info.length/2)/perimeter,
            [1] = (height+width+self.info.length/2)/perimeter,
            [2] = (2*height+width-self.info.length/2)/perimeter,
            [3] = 1-self.info.length/2/perimeter
        }
        self.info.pTLy ={
            [0] = (height-self.info.length/2)/perimeter,
            [1] = (height+width+self.info.length/2)/perimeter,
            [2] = (height*2+width+self.info.length/2)/perimeter,
            [3] = 1-self.info.length/2/perimeter
        }
        self.info.pBRx ={
            [0] = self.info.length/2/perimeter,
            [1] = (height-self.info.length/2)/perimeter,
            [2] = (height+width-self.info.length/2)/perimeter,
            [3] = (height*2+width+self.info.length/2)/perimeter
        }
        self.info.pBRy ={
            [0] = self.info.length/2/perimeter,
            [1] = (height+self.info.length/2)/perimeter,
            [2] = (height+width-self.info.length/2)/perimeter,
            [3] = (height*2+width-self.info.length/2)/perimeter
        }
    end
    if self:IsShown() then
        if self.masks then
            if not (self.masks[1]:IsShown()) then
                self.masks[1]:Show()
                self.masks[1]:SetPoint("TOPLEFT",self,"TOPLEFT",self.info.th,-self.info.th)
                self.masks[1]:SetPoint("BOTTOMRIGHT",self,"BOTTOMRIGHT",-self.info.th,self.info.th)
            end
            if self.masks[2] and not(self.masks[2]:IsShown()) then
                self.masks[2]:Show()
                self.masks[2]:SetPoint("TOPLEFT",self,"TOPLEFT",self.info.th+1,-self.info.th-1)
                self.masks[2]:SetPoint("BOTTOMRIGHT",self,"BOTTOMRIGHT",-self.info.th-1,self.info.th+1)
            end
        end
        if self.bg and not(self.bg:IsShown()) then
            self.bg:Show()
        end
        --! WotLK perf: цикл идёт на полном фреймрейте по всем текстурам глоу (N
        --! задаёт вызывающий, по умолчанию 8), и глоу может висеть сразу на
        --! нескольких рейдовых кнопках. Выражение прогресса
        --! (progress+step*(k-1))%1 было выписано четыре раза подряд с одними и
        --! теми же операндами - считаем один раз в локал. Заодно подняты поля
        --! self.info: их читали 12 раз за итерацию, а каждое чтение - это два
        --! хеш-лукапа (self.info, потом само поле). Таблица self.info внутри
        --! pUpdate не переприсваивается, блок выше правит только её поля, так
        --! что ссылка остаётся той же.
        local info = self.info
        local step, th = info.step, info.th
        local pTLx, pTLy, pBRx, pBRy = info.pTLx, info.pTLy, info.pBRx, info.pBRy

        for k,line  in pairs(self.textures) do
            local p = (progress+step*(k-1))%1
            line:SetPoint("TOPLEFT",self,"TOPLEFT",pCalc1(p,width,th,pTLx),-pCalc2(p,height,th,pTLy))
            line:SetPoint("BOTTOMRIGHT",self,"TOPLEFT",th+pCalc2(p,width,th,pBRx),-height+pCalc1(p,height,th,pBRy))
        end
    end
end

function lib.PixelGlow_Start(r,color,N,frequency,length,th,xOffset,yOffset,border,key,frameLevel)
    if not r then
        return
    end
    if not color then
        color = {0.95,0.95,0.32,1}
    end

    if not(N and N>0) then
        N = 8
    end

    local period
    if frequency then
        if not(frequency>0 or frequency<0) then
            period = 4
        else
            period = 1/frequency
        end
    else
        period = 4
    end
    local width,height = r:GetSize()
    length = length or math.floor((width+height)*(2/N-0.1))
    length = min(length,min(width,height))
    th = th or 1
    xOffset = xOffset or 0
    yOffset = yOffset or 0
    key = key or ""

    addFrameAndTex(r,color,"_PixelGlow",key,N,xOffset,yOffset,textureList.white,{0,1,0,1},nil,frameLevel)
    local f = r["_PixelGlow"..key]
    if GlowMaskPool then
        if not f.masks then
            f.masks = {}
        end
        if not f.masks[1] then
            f.masks[1] = GlowMaskPool:Acquire()
            f.masks[1]:SetTexture(textureList.empty, "CLAMPTOWHITE","CLAMPTOWHITE")
            f.masks[1]:Show()
        end
        f.masks[1]:SetPoint("TOPLEFT",f,"TOPLEFT",th,-th)
        f.masks[1]:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-th,th)
    end

    if not(border==false) and GlowMaskPool then
        if not f.masks[2] then
            f.masks[2] = GlowMaskPool:Acquire()
            f.masks[2]:SetTexture(textureList.empty, "CLAMPTOWHITE","CLAMPTOWHITE")
        end
        f.masks[2]:SetPoint("TOPLEFT",f,"TOPLEFT",th+1,-th-1)
        f.masks[2]:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-th-1,th+1)

        if not f.bg then
            f.bg = GlowTexPool:Acquire()
            --! WotLK fix: SetColorTexture на 3.3.5 нет - это нативная числовая форма
            --! SetTexture(r, g, b[, a]); шим TextureBase в WidgetAPI удалён.
            f.bg:SetTexture(0.1,0.1,0.1,0.8)
            f.bg:SetParent(f)
            f.bg:SetAllPoints(f)
            f.bg:SetDrawLayer("ARTWORK",6)
            GlowTextureAddMask(f.bg, f.masks[2])
        end
    else
        if f.bg then
            GlowTexPool:Release(f.bg)
            f.bg = nil
        end
        if GlowMaskPool and f.masks and f.masks[2] then
            GlowMaskPool:Release(f.masks[2])
            f.masks[2] = nil
        end
    end
    if GlowMaskPool then
        for _,tex in pairs(f.textures) do
            GlowTextureAddMask(tex, f.masks[1])
        end
    end
    f.timer = f.timer or 0
    f.info = f.info or {}
    f.info.step = 1/N
    f.info.period = period
    f.info.th = th
    if f.info.length ~= length then
        f.info.width = nil
        f.info.length = length
    end
    pUpdate(f, 0)
    f:SetScript("OnUpdate",pUpdate)
end

function lib.PixelGlow_Stop(r,key)
    if not r then
        return
    end
    key = key or ""
    if not r["_PixelGlow"..key] then
        return false
    else
        GlowFramePool:Release(r["_PixelGlow"..key])
    end
end

table.insert(lib.glowList, "Pixel Glow")
lib.startList["Pixel Glow"] = lib.PixelGlow_Start
lib.stopList["Pixel Glow"] = lib.PixelGlow_Stop


--Autocast Glow Functions--
local function acUpdate(self,elapsed)
    local width,height = self:GetSize()
    if width ~= self.info.width or height ~= self.info.height or not self.info.space then
        if width*height == 0 then return end -- Avoid division by zero
        self.info.width = width
        self.info.height = height
        self.info.perimeter = 2*(width+height)
        self.info.bottomlim = height*2+width
        self.info.rightlim = height+width
        self.info.space = self.info.perimeter/self.info.N
    end

    --! WotLK perf: вложенный цикл - это 4*N итераций на кадр (N задаёт вызывающий,
    --! по умолчанию 4, то есть 16 проходов), и всё это на полном фреймрейте на
    --! каждом глоу. В теле было по 6-7 обращений вида self.info.X, а каждое - два
    --! хеш-лукапа. Поля подняты в локалы после блока пересчёта выше: до него
    --! читать нельзя, он их и записывает. Сама таблица self.info тут не
    --! переприсваивается, только её поля, так что ссылка остаётся той же.
    --! self.timer[k] читался четыре раза за внешнюю итерацию - стал локалом,
    --! запись в таблицу осталась одна и на том же месте.
    local info = self.info
    local timer = self.timer
    local textures = self.textures
    local N, period = info.N, info.period
    local space, perimeter = info.space, info.perimeter
    local bottomlim, rightlim, infoHeight = info.bottomlim, info.rightlim, info.height

    local texIndex = 0;
    for k=1,4 do
        local t = timer[k]+elapsed/(period*k)
        if t > 1 or t <-1 then
            t = t%1
        end
        timer[k] = t

        local offset = perimeter*t
        for i = 1,N do
            texIndex = texIndex+1
            local position = (space*i+offset)%perimeter
            if position>bottomlim then
                textures[texIndex]: SetPoint("CENTER",self,"BOTTOMRIGHT",-position+bottomlim,0)
            elseif position>rightlim then
                textures[texIndex]: SetPoint("CENTER",self,"TOPRIGHT",0,-position+rightlim)
            elseif position>infoHeight then
                textures[texIndex]: SetPoint("CENTER",self,"TOPLEFT",position-infoHeight,0)
            else
                textures[texIndex]: SetPoint("CENTER",self,"BOTTOMLEFT",0,position)
            end
        end
    end
end

function lib.AutoCastGlow_Start(r,color,N,frequency,scale,xOffset,yOffset,key,frameLevel)
    if not r then
        return
    end

    if not color then
        color = {0.95,0.95,0.32,1}
    end

    if not(N and N>0) then
        N = 4
    end

    local period
    if frequency then
        if not(frequency>0 or frequency<0) then
            period = 8
        else
            period = 1/frequency
        end
    else
        period = 8
    end
    scale = scale or 1
    xOffset = xOffset or 0
    yOffset = yOffset or 0
    key = key or ""

    addFrameAndTex(r,color,"_AutoCastGlow",key,N*4,xOffset,yOffset,textureList.shine,shineCoords, true, frameLevel)
    local f = r["_AutoCastGlow"..key]
    local sizes = {7,6,5,4}
    for k,size in pairs(sizes) do
        for i = 1,N do
            f.textures[i+N*(k-1)]:SetSize(size*scale,size*scale)
        end
    end
    f.timer = f.timer or {0,0,0,0}
    f.info = f.info or {}
    f.info.N = N
    f.info.period = period
    f:SetScript("OnUpdate",acUpdate)
    acUpdate(f, 0)
end

function lib.AutoCastGlow_Stop(r,key)
    if not r then
        return
    end

    key = key or ""
    if not r["_AutoCastGlow"..key] then
        return false
    else
        GlowFramePool:Release(r["_AutoCastGlow"..key])
    end
end

table.insert(lib.glowList, "Autocast Shine")
lib.startList["Autocast Shine"] = lib.AutoCastGlow_Start
lib.stopList["Autocast Shine"] = lib.AutoCastGlow_Stop

--Action Button Glow--
local ButtonGlowPool

--! WotLK fix: never call AnimationGroup:Stop() while OnHide, OnStop, or pool
--! release is already unwinding. Queue cancellation for the next timer pass
--! and reject stale work when the pooled frame has already been reused.
local function CancelButtonGlowAnimations(frame, generation)
    if frame._cellGlowGeneration ~= generation then return end

    frame._cancelAnimOutForRestart = true
    if frame.animIn and frame.animIn:IsPlaying() then frame.animIn:Stop() end
    if frame.animOut and frame.animOut:IsPlaying() then frame.animOut:Stop() end
    frame._cancelAnimOutForRestart = nil
end

local function QueueButtonGlowAnimationCancel(frame)
    if frame._cellGlowCancelQueued then return end

    frame._cellGlowCancelQueued = true
    local generation = frame._cellGlowGeneration
    C_Timer.After(0, function()
        frame._cellGlowCancelQueued = nil
        CancelButtonGlowAnimations(frame, generation)
    end)
end

local function ButtonGlowResetter(framePool,frame)
    frame:SetScript("OnUpdate",nil)
    local parent = frame:GetParent()
    if parent and parent._ButtonGlow == frame then
        parent._ButtonGlow = nil
    end
    frame:Hide()
    frame:ClearAllPoints()
    QueueButtonGlowAnimationCancel(frame)
end
-- Custom ButtonGlowPool for WotLK compatibility
ButtonGlowPool = {
    parent = GlowParent,
    inactive = {},
    active = {},
    count = 0,
}
function ButtonGlowPool:Acquire()
    local frame = tremove(self.inactive)
    local isNew = false
    if not frame then
        self.count = self.count + 1
        frame = CreateFrame("Frame", nil, self.parent)
        isNew = true
    end
    frame._cellGlowGeneration = (frame._cellGlowGeneration or 0) + 1
    frame._cellGlowCancelQueued = nil
    self.active[frame] = true
    return frame, isNew
end
function ButtonGlowPool:Release(frame)
    if self.active[frame] then
        --! WotLK fix: mark inactive before Hide() runs OnHide, preventing a
        --! finishing animOut from recursively returning the frame twice.
        self.active[frame] = nil
        frame._cellGlowRestartRequested = nil
        ButtonGlowResetter(self, frame)
        tinsert(self.inactive, frame)
    end
end
lib.ButtonGlowPool = ButtonGlowPool

--! WotLK fix: Action Button Glow animation helpers ported from the
--! WeakAuras-WotLK LibCustomGlow-1.0 fork. Native 3.3.5 Alpha/Scale animations
--! apply a relative transform on the texture's render scale, which compounds
--! with SetSize/SetAlpha overrides and produces visible triangle spikes
--! around the spark frame. We instead create plain Animation objects, keep
--! our own target/scale/alpha state, and drive the texture directly from
--! OnUpdate using a captured base size/alpha. This matches WeakAuras-WotLK,
--! which has shipped without the visual artefact on 3.3.5a for years.
local function InitAlphaAnimation(self)
    self.target = self.target or self:GetRegionParent()
    self.change = self.change or 0

    self.frameAlpha = self.target:GetAlpha()
    self.alphaFactor = self.frameAlpha + self.change - self.frameAlpha
end

local function TidyAlphaAnimation(self)
    self.alphaFactor = nil
    self.frameAlpha = nil
end

local function AlphaAnimation_OnUpdate(animation)
    local progress = animation:GetSmoothProgress() or 0
    if progress ~= 0 then
        if not animation.played then
            InitAlphaAnimation(animation)
            animation.played = true
        end
        if animation.frameAlpha then
            animation.target:SetAlpha(animation.frameAlpha + animation.alphaFactor * progress)
            if progress == 1 then
                TidyAlphaAnimation(animation)
            end
        end
    end
end

local function AlphaAnimation_OnStop(animation)
    if animation.frameAlpha then
        TidyAlphaAnimation(animation)
    end
    animation.played = nil
end

local function InitScaleAnimation(self)
    self.target = self.target or self:GetRegionParent()
    self.scaleX = self.scaleX or 0
    self.scaleY = self.scaleY or 0

    local _, _, width, height = self.target:GetRect()
    if not width then return end

    self.frameWidth = width
    self.frameHeight = height

    self.widthFactor = width * self.scaleX - width
    self.heightFactor = height * self.scaleY - height

    return 1
end

local function TidyScaleAnimation(self)
    self.widthFactor = nil
    self.heightFactor = nil
    self.frameWidth = nil
    self.frameHeight = nil
end

local function ScaleAnimation_OnUpdate(animation)
    local progress = animation:GetSmoothProgress() or 0
    if progress ~= 0 then
        if not animation.played then
            if InitScaleAnimation(animation) then
                animation.played = true
            end
        end
        if animation.frameWidth then
            animation.target:SetSize(
                animation.frameWidth + animation.widthFactor * progress,
                animation.frameHeight + animation.heightFactor * progress
            )
            if progress == 1 then
                TidyScaleAnimation(animation)
            end
        end
    end
end

local function ScaleAnimation_OnStop(animation)
    if animation.frameWidth then
        TidyScaleAnimation(animation)
    end
    animation.played = nil
end

local function CreateScaleAnim(group, target, order, duration, x, y, delay)
    local scale = group:CreateAnimation()
    scale.target = group:GetParent()[target]
    scale:SetOrder(order)
    scale:SetDuration(duration)
    scale.scaleX, scale.scaleY = x, y
    if delay then scale:SetStartDelay(delay) end
    scale:SetScript("OnUpdate", ScaleAnimation_OnUpdate)
    scale:SetScript("OnStop", ScaleAnimation_OnStop)
    scale:SetScript("OnFinished", ScaleAnimation_OnStop)
    return scale
end

local function CreateAlphaAnim(group, target, order, duration, change, delay, appear)
    local alpha = group:CreateAnimation()
    alpha.target = group:GetParent()[target]
    alpha:SetOrder(order)
    alpha:SetDuration(duration)
    alpha.change = change
    if delay then alpha:SetStartDelay(delay) end
    alpha:SetScript("OnUpdate", AlphaAnimation_OnUpdate)
    alpha:SetScript("OnStop", AlphaAnimation_OnStop)
    alpha:SetScript("OnFinished", AlphaAnimation_OnStop)
    table.insert(appear and group.appear or group.fade, alpha)
    return alpha
end

local function AnimIn_OnPlay(group)
    local frame = group:GetParent()
    local frameWidth, frameHeight = frame:GetSize()
    local alpha = not frame.color and 1 or frame.color[4]
    frame.spark:SetSize(frameWidth, frameHeight)
    frame.spark:SetAlpha(not frame.color and 1 or 0.3 * alpha)
    frame.innerGlow:SetSize(frameWidth / 2, frameHeight / 2)
    frame.innerGlow:SetAlpha(alpha)
    frame.innerGlowOver:SetAlpha(alpha)
    frame.outerGlow:SetSize(frameWidth * 2, frameHeight * 2)
    frame.outerGlow:SetAlpha(alpha)
    frame.outerGlowOver:SetAlpha(alpha)
    frame.ants:SetSize(frameWidth * 0.85, frameHeight * 0.85)
    frame.ants:SetAlpha(0)
    frame:Show()
end

local function AnimIn_OnFinished(group)
    local frame = group:GetParent()
    local frameWidth, frameHeight = frame:GetSize()
    frame.spark:SetAlpha(0)
    frame.innerGlow:SetAlpha(0)
    frame.innerGlow:SetSize(frameWidth, frameHeight)
    frame.innerGlowOver:SetAlpha(0)
    frame.outerGlow:SetSize(frameWidth, frameHeight)
    frame.outerGlowOver:SetAlpha(0)
    frame.outerGlowOver:SetSize(frameWidth, frameHeight)
    frame.ants:SetAlpha(not frame.color and 1 or frame.color[4])
end

local function AnimIn_OnStop(group)
    local frame = group:GetParent()
    frame.spark:SetAlpha(0)
    frame.innerGlow:SetAlpha(0)
    frame.innerGlowOver:SetAlpha(0.0)
    frame.outerGlowOver:SetAlpha(0.0)
end

local function bgHide(self)
    if (self.animIn and self.animIn:IsPlaying())
        or (self.animOut and self.animOut:IsPlaying()) then
        QueueButtonGlowAnimationCancel(self)
    end
end

local function bgUpdate(self, elapsed)
    AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, self.throttle);
    local cooldown = self:GetParent() and self:GetParent().cooldown;
    --! WotLK fix: GetCooldownDuration is not a native 3.3.5 widget method. Only
    --! consult the instance-owned Cell helper; foreign cooldowns keep their API.
    if(cooldown and cooldown:IsShown() and rawget(cooldown, "GetCooldownDuration") and cooldown:GetCooldownDuration() > 3000) then
        self:SetAlpha(0.5);
    else
        self:SetAlpha(1.0);
    end
end

local function configureButtonGlow(f,alpha)
    f.spark = f:CreateTexture(nil, "BACKGROUND")
    f.spark:SetPoint("CENTER")
    f.spark:SetAlpha(0)
    f.spark:SetTexture(texturePath .. [[IconAlert]]) --! WotLK fix: bundled (retail path absent on 3.3.5)
    f.spark:SetTexCoord(0.00781250, 0.61718750, 0.00390625, 0.26953125)

    -- inner glow
    f.innerGlow = f:CreateTexture(nil, "ARTWORK")
    f.innerGlow:SetPoint("CENTER")
    f.innerGlow:SetAlpha(0)
    f.innerGlow:SetTexture(texturePath .. [[IconAlert]]) --! WotLK fix: bundled (retail path absent on 3.3.5)
    f.innerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

    -- inner glow over
    f.innerGlowOver = f:CreateTexture(nil, "ARTWORK")
    f.innerGlowOver:SetPoint("TOPLEFT", f.innerGlow, "TOPLEFT")
    f.innerGlowOver:SetPoint("BOTTOMRIGHT", f.innerGlow, "BOTTOMRIGHT")
    f.innerGlowOver:SetAlpha(0)
    f.innerGlowOver:SetTexture(texturePath .. [[IconAlert]]) --! WotLK fix: bundled (retail path absent on 3.3.5)
    f.innerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

    -- outer glow
    f.outerGlow = f:CreateTexture(nil, "ARTWORK")
    f.outerGlow:SetPoint("CENTER")
    f.outerGlow:SetAlpha(0)
    f.outerGlow:SetTexture(texturePath .. [[IconAlert]]) --! WotLK fix: bundled (retail path absent on 3.3.5)
    f.outerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

    -- outer glow over
    f.outerGlowOver = f:CreateTexture(nil, "ARTWORK")
    f.outerGlowOver:SetPoint("TOPLEFT", f.outerGlow, "TOPLEFT")
    f.outerGlowOver:SetPoint("BOTTOMRIGHT", f.outerGlow, "BOTTOMRIGHT")
    f.outerGlowOver:SetAlpha(0)
    f.outerGlowOver:SetTexture(texturePath .. [[IconAlert]]) --! WotLK fix: bundled (retail path absent on 3.3.5)
    f.outerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

    -- ants
    f.ants = f:CreateTexture(nil, "OVERLAY")
    f.ants:SetPoint("CENTER")
    f.ants:SetAlpha(0)
    f.ants:SetTexture(texturePath .. [[IconAlertAnts]]) --! WotLK fix: bundled (retail path absent on 3.3.5)

    --! WotLK fix: port the WeakAuras-WotLK anim graph (plain Animation
    --! objects + Init/Tidy state pattern). See helpers above. Parameter
    --! list: (group, target, order, duration, scaleX, scaleY, delay).
    f.animIn = f:CreateAnimationGroup()
    f.animIn.appear = {}
    f.animIn.fade = {}
    CreateScaleAnim(f.animIn, "spark",          1, 0.2, 1.5, 1.5)
    CreateAlphaAnim(f.animIn, "spark",          1, 0.2, alpha, nil, nil, true)
    CreateScaleAnim(f.animIn, "innerGlow",      1, 0.3, 2, 2)
    CreateScaleAnim(f.animIn, "innerGlowOver",  1, 0.3, 2, 2)
    CreateAlphaAnim(f.animIn, "innerGlowOver",  1, 0.3, alpha, nil, nil, true)
    CreateScaleAnim(f.animIn, "outerGlow",      1, 0.3, 0.5, 0.5)
    CreateScaleAnim(f.animIn, "outerGlowOver",  1, 0.3, 0.5, 0.5)
    CreateAlphaAnim(f.animIn, "outerGlowOver",  1, 0.3, -alpha, nil, nil, false)
    CreateScaleAnim(f.animIn, "spark",          1, 0.2, 0.666666, 0.666666, 0.2)
    CreateAlphaAnim(f.animIn, "spark",          1, 0.2, -alpha, 0.2, nil, false)
    CreateAlphaAnim(f.animIn, "innerGlow",      1, 0.2, -alpha, 0.3, nil, false)
    CreateAlphaAnim(f.animIn, "ants",           1, 0.2, alpha, 0.3, nil, true)
    f.animIn:SetScript("OnPlay", AnimIn_OnPlay)
    f.animIn:SetScript("OnStop", AnimIn_OnStop)
    f.animIn:SetScript("OnFinished", AnimIn_OnFinished)

    f.animOut = f:CreateAnimationGroup()
    f.animOut.appear = {}
    f.animOut.fade = {}
    CreateAlphaAnim(f.animOut, "outerGlowOver", 1, 0.2, alpha, nil, nil, true)
    CreateAlphaAnim(f.animOut, "ants",          1, 0.2, -alpha, nil, nil, false)
    CreateAlphaAnim(f.animOut, "outerGlowOver", 2, 0.2, -alpha, nil, nil, false)
    CreateAlphaAnim(f.animOut, "outerGlow",     2, 0.2, -alpha, nil, nil, false)
    f.animOut:SetScript("OnFinished", function()
        ButtonGlowPool:Release(f)
    end)
    --! WotLK fix: OnStop is notification only. Releasing/hiding the owner from
    --! inside the native Stop() callback reentered build 12340's animation
    --! teardown and produced ERROR #132. Explicit callers own pool release.
    f.animOut:SetScript("OnStop", nil)

    f:SetScript("OnHide", bgHide)
end

local function updateAlphaAnim(f,alpha)
    for _,anim in pairs(f.animIn.appear) do
        anim.change = alpha
    end
    for _,anim in pairs(f.animIn.fade) do
        anim.change = -alpha
    end
    for _,anim in pairs(f.animOut.appear) do
        anim.change = alpha
    end
    for _,anim in pairs(f.animOut.fade) do
        anim.change = -alpha
    end
end

local ButtonGlowTextures = {["spark"] = true,["innerGlow"] = true,["innerGlowOver"] = true,["outerGlow"] = true,["outerGlowOver"] = true,["ants"] = true}

local function noZero(num)
    if num == 0 then
        return 0.001
    else
        return num
    end
end

function lib.ButtonGlow_Start(r,color,frequency,frameLevel)
    if not r then
        return
    end
	frameLevel = frameLevel or 8;
    local throttle
    if frequency and frequency > 0 then
        throttle = 0.25/frequency*0.01
    else
        throttle = 0.01
    end
    if r._ButtonGlow then
        local f = r._ButtonGlow
        local width,height = r:GetSize()
        f:SetFrameLevel(r:GetFrameLevel()+frameLevel)
        f:SetSize(width*1.4 , height*1.4)
        f:SetPoint("TOPLEFT", r, "TOPLEFT", -width * 0.2, height * 0.2)
        f:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", width * 0.2, -height * 0.2)
        f.ants:SetSize(width*1.4*0.85, height*1.4*0.85)
		AnimIn_OnFinished(f.animIn)
        if f.animOut:IsPlaying() then
            --! WotLK fix: defer Stop() outside the current callback and only
            --! restart if this parent still owns the same pooled generation.
            local generation = f._cellGlowGeneration
            f._cellGlowRestartRequested = true
            C_Timer.After(0, function()
                if ButtonGlowPool.active[f]
                    and f._cellGlowGeneration == generation
                    and r._ButtonGlow == f then
                    CancelButtonGlowAnimations(f, generation)
                    if f._cellGlowRestartRequested then
                        f._cellGlowRestartRequested = nil
                        f.animIn:Play()
                    end
                end
            end)
        end

        if not(color) then
            for texture in pairs(ButtonGlowTextures) do
                f[texture]:SetDesaturated(nil)
                f[texture]:SetVertexColor(1,1,1)
                local alpha = math.min(f[texture]:GetAlpha()/noZero(f.color and f.color[4] or 1), 1)
                f[texture]:SetAlpha(alpha)
                updateAlphaAnim(f, 1)
            end
            f.color = false
        else
            for texture in pairs(ButtonGlowTextures) do
                f[texture]:SetDesaturated(1)
                f[texture]:SetVertexColor(color[1],color[2],color[3])
                local alpha = math.min(f[texture]:GetAlpha()/noZero(f.color and f.color[4] or 1)*color[4], 1)
                f[texture]:SetAlpha(alpha)
                updateAlphaAnim(f,color and color[4] or 1)
            end
            f.color = color
        end
        f.throttle = throttle
    else
        local f, new = ButtonGlowPool:Acquire()
        if new then
            configureButtonGlow(f,color and color[4] or 1)
        else
            updateAlphaAnim(f,color and color[4] or 1)
        end
        r._ButtonGlow = f
        local width,height = r:GetSize()
        f:SetParent(r)
        f:SetFrameLevel(r:GetFrameLevel()+frameLevel)
        f:SetSize(width * 1.4, height * 1.4)
        f:SetPoint("TOPLEFT", r, "TOPLEFT", -width * 0.2, height * 0.2)
        f:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", width * 0.2, -height * 0.2)
        if not(color) then
            f.color = false
            for texture in pairs(ButtonGlowTextures) do
                f[texture]:SetDesaturated(nil)
                f[texture]:SetVertexColor(1,1,1)
            end
        else
            f.color = color
            for texture in pairs(ButtonGlowTextures) do
                f[texture]:SetDesaturated(1)
                f[texture]:SetVertexColor(color[1],color[2],color[3])
            end
        end
        f.throttle = throttle
        f:SetScript("OnUpdate", bgUpdate)

        f.animIn:Play()

        if Masque and Masque.UpdateSpellAlert and (not r.overlay or not issecurevariable(r, "overlay")) then
            local old_overlay = r.overlay
            r.overlay = f
            Masque:UpdateSpellAlert(r)
            r.overlay = old_overlay
        end
    end
end

function lib.ButtonGlow_Stop(r)
    if r._ButtonGlow then
        r._ButtonGlow._cellGlowRestartRequested = nil
        if r._ButtonGlow.animOut:IsPlaying() then
            -- Do nothing the animOut finishing will release
        elseif r._ButtonGlow.animIn:IsPlaying() then
            --! WotLK fix: detach/release first, then cancel the native animation
            --! on the next timer pass so Stop() cannot reenter pool teardown.
            ButtonGlowPool:Release(r._ButtonGlow)
        elseif r:IsVisible() then
            r._ButtonGlow.animOut:Play()
        else
            ButtonGlowPool:Release(r._ButtonGlow)
        end
    end
end

table.insert(lib.glowList, "Action Button Glow")
lib.startList["Action Button Glow"] = lib.ButtonGlow_Start
lib.stopList["Action Button Glow"] = lib.ButtonGlow_Stop


-- ProcGlow
--! WotLK fix: "Proc Glow" was completely invisible on 3.3.5 - the old adaptation
--! pointed at Interface\SpellActivationOverlay\IconAlert (a 4.0 texture missing on
--! 3.3.5) and stubbed the animations out entirely. Ported the WeakAuras-WotLK
--! approach instead: the retail proc flipbook sheet is bundled as UIActionBarFX.blp
--! and animated manually via OnUpdate + SetTexCoord stepping (FlipBook animations do
--! not exist on 3.3.5): a 0.7s start burst, then a 30-frame 6x5 loop. If the bundled
--! texture is absent (source checkout without binaries), falls back to the native
--! 3.3.5 UI-ActionButton-Border glow with an alpha pulse instead of rendering nothing.

local BaseTexCoord = {
    ["Loop"] = {0.412598, 0.575195, 0.000976562, 0.391602},
    ["Start"] = {0.000488281, 0.411621, 0.000976562, 0.987305},
}

local function SetTile(texture, frame, rows, columns, frameScaleW, frameScaleH, key)
    frame = frame - 1
    local row = floor(frame / columns)
    local column = frame % columns

    local leftStart, rightEnd, topStart, bottomEnd = BaseTexCoord[key][1], BaseTexCoord[key][2], BaseTexCoord[key][3], BaseTexCoord[key][4]

    local fullWidth = rightEnd - leftStart
    local fullHeight = bottomEnd - topStart

    local baseDeltaX = fullWidth / columns
    local baseDeltaY = fullHeight / rows

    local deltaX = baseDeltaX * frameScaleW
    local deltaY = baseDeltaY * frameScaleH

    local left = leftStart + baseDeltaX * column + (baseDeltaX - deltaX) / 2
    local right = left + deltaX

    local top = topStart + baseDeltaY * row + (baseDeltaY - deltaY) / 2
    local bottom = top + deltaY

    texture:SetTexCoord(left, right, top, bottom)
end

local StartFlipbook
local FlipbookAnimation_OnUpdate

FlipbookAnimation_OnUpdate = function(self, elapsed)
    local data = self.flipbookData
    if not data then return end

    if data.animElapsed then
        data.animElapsed = data.animElapsed + elapsed
        if data.animElapsed >= 0.7 then
            -- start burst finished -> switch to the loop flipbook
            if self:IsShown() then
                StartFlipbook(self, self.ProcLoop, 6, 5, 30, ((data.animOptions and (30 / data.animOptions)) or 30), nil, nil, "Loop")
            end
            data.animElapsed = nil
            data.animOptions = nil
            return
        end
    end

    data.elapsedTime = data.elapsedTime + elapsed
    local frameDuration = 1 / data.frameRate

    if data.elapsedTime >= frameDuration then
        data.elapsedTime = data.elapsedTime - frameDuration
        data.currentFrame = data.currentFrame + 1
        if data.currentFrame > data.totalFrames then
            data.currentFrame = 1
        end
        SetTile(data.texture, data.currentFrame, data.rows, data.columns, 1, 1, data.key)
    end
end

local function StopFlipbook(f)
    f:SetScript("OnUpdate", nil)
    if f.flipbookData and f.flipbookData.texture then
        f.flipbookData.texture:Hide()
    end
    f.flipbookData = nil
end

StartFlipbook = function(f, texture, rows, columns, totalFrames, frameRate, startAnim, startOptionsDur, key)
    StopFlipbook(f)
    f.flipbookData = {
        key = key,
        texture = texture,
        rows = rows,
        columns = columns,
        totalFrames = totalFrames,
        frameRate = frameRate,
        currentFrame = 1,
        elapsedTime = 0,
        animElapsed = startAnim,
        animOptions = startOptionsDur,
    }
    SetTile(texture, 1, rows, columns, 1, 1, key)
    texture:Show()
    f:SetScript("OnUpdate", FlipbookAnimation_OnUpdate)
end

--! fallback driver (no bundled texture): native 3.3.5 glow with an alpha pulse
local function PulseAnimation_OnUpdate(self, elapsed)
    local data = self.pulseData
    if not data then return end
    data.t = (data.t + elapsed * 1.5) % 1
    data.texture:SetAlpha(0.55 + 0.45 * sin(data.t * 6.2831853))
end

local function StopPulse(f)
    if f.pulseData then
        f:SetScript("OnUpdate", nil)
        if f.pulseData.texture then
            f.pulseData.texture:Hide()
        end
        f.pulseData = nil
    end
end

local function ProcGlowResetter(framePool, frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetScript("OnShow", nil)
    frame:SetScript("OnHide", nil)
    frame:SetScript("OnUpdate", nil) --! WotLK fix: don't leak the flipbook/pulse driver into the pool
    frame.flipbookData = nil
    frame.pulseData = nil
    local parent = frame:GetParent()
    if frame.key and parent[frame.key] then
        parent[frame.key] = nil
    end
end

-- Custom ProcGlowPool for WotLK compatibility
local ProcGlowPool = {
    parent = GlowParent,
    inactive = {},
    active = {},
    count = 0,
}
function ProcGlowPool:Acquire()
    local frame = tremove(self.inactive)
    local isNew = false
    if not frame then
        self.count = self.count + 1
        frame = CreateFrame("Frame", nil, self.parent)
        isNew = true
    end
    self.active[frame] = true
    return frame, isNew
end
function ProcGlowPool:Release(frame)
    if self.active[frame] then
        self.active[frame] = nil
        ProcGlowResetter(self, frame)
        tinsert(self.inactive, frame)
    end
end
lib.ProcGlowPool = ProcGlowPool

local hasProcTexture -- nil = not probed yet; on 3.3.5 SetTexture returns 1 when the file exists

local function InitProcGlow(f)
    f.ProcStart = f:CreateTexture(nil, "ARTWORK")
    f.ProcStart:SetBlendMode("ADD")
    f.ProcStart:SetTexture(texturePath .. [[UIActionBarFX]])
    f.ProcStart:SetTexCoord(0.0827148248, 0.1649413686, 0.000976562, 0.165364635) -- first Start frame
    f.ProcStart:SetAlpha(1)
    f.ProcStart:SetSize(150, 150)
    f.ProcStart:SetPoint("CENTER")
    f.ProcStart:Hide()

    f.ProcLoop = f:CreateTexture(nil, "ARTWORK")
    f.ProcLoop:SetTexture(texturePath .. [[UIActionBarFX]])
    f.ProcLoop:SetTexCoord(0.412598, 0.4451174, 0.000976562, 0.066080801666667) -- first Loop frame
    f.ProcLoop:SetAlpha(1)
    f.ProcLoop:SetAllPoints()
    f.ProcLoop:Hide()

    f.key = nil
end

local function SetupProcGlow(f, options)
    f.key = "_ProcGlow" .. options.key

    f:SetScript("OnHide", function(self)
        StopFlipbook(self)
        StopPulse(self)
    end)

    f:SetScript("OnShow", function(self)
        StopFlipbook(self)
        if self.startAnim then
            local width, height = self:GetSize()
            self.ProcStart:SetSize((width / 42 * 150) / 1.4, (height / 42 * 150) / 1.4)
            self.ProcLoop:Hide()
            StartFlipbook(self, self.ProcStart, 6, 5, 30, 30, 0, options.duration, "Start")
        else
            StartFlipbook(self, self.ProcLoop, 6, 5, 30, (30 / options.duration), nil, nil, "Loop")
        end
    end)

    local color = options.color or {1, 1, 1, 1}
    f.ProcStart:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    f.ProcLoop:SetVertexColor(color[1], color[2], color[3], color[4] or 1)

    f.startAnim = options.startAnim
end

local ProcGlowDefaults = {
    frameLevel = 8,
    color = nil,
    startAnim = true,
    xOffset = 0,
    yOffset = 0,
    duration = 1,
    key = ""
}

function lib.ProcGlow_Start(r, options)
    if not r then
        return
    end
    options = options or {}
    setmetatable(options, { __index = ProcGlowDefaults })
    local key = "_ProcGlow" .. options.key
    local f, new
    if r[key] then
        f = r[key]
    else
        f, new = ProcGlowPool:Acquire()
        if new then
            InitProcGlow(f)
        end
        r[key] = f
    end
    f:SetParent(r)
    f:SetFrameLevel(r:GetFrameLevel() + options.frameLevel)

    local width, height = r:GetSize()
    local xOffset = options.xOffset + width * 0.2
    local yOffset = options.yOffset + height * 0.2
    f:SetPoint("TOPLEFT", r, "TOPLEFT", -xOffset, yOffset)
    f:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", xOffset, -yOffset)

    SetupProcGlow(f, options)
    f:Show()
end

function lib.ProcGlow_Stop(r, key)
    key = key or ""
    local f = r["_ProcGlow" .. key]
    if f then
        ProcGlowPool:Release(f)
    end
end

table.insert(lib.glowList, "Proc Glow")
lib.startList["Proc Glow"] = lib.ProcGlow_Start
lib.stopList["Proc Glow"] = lib.ProcGlow_Stop
