local _, Cell = ...
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs

-------------------------------------------------
-- minimap button (3.3.5, self-contained)
-------------------------------------------------
--! WotLK feature: LDB-style minimap button without LibDataBroker/LibDBIcon deps
--! (Cell ships neither). Visuals follow the classic LibDBIcon look (31px button,
--! 53px tracking border overlay, icon centered), positioning is the classic
--! angle-around-the-minimap math with the angle persisted in CellDB.
--!   Left-Click       - hide/show all Cell frames (out of combat only)
--!   Right-Click      - unlock/lock the tool movers (same as /cell unlock, /cell lock)
--!   Shift+Right-Click- open the Cell options frame
--!   Middle-Click     - hide this button (restore with /cell minimap)
--!   Left-Drag        - move the button around the minimap

local button = CreateFrame("Button", "CellMinimapButton", Minimap)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetWidth(31)
button:SetHeight(31)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:Hide() -- state is applied once CellDB is loaded

local overlay = button:CreateTexture(nil, "OVERLAY")
overlay:SetWidth(53)
overlay:SetHeight(53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetTexture("Interface\\AddOns\\Cell\\Media\\icon")
icon:SetPoint("TOPLEFT", 7, -6)

local function GetDB()
    -- self-initializing: keeps this module independent from the Core defaults block
    if type(CellDB) ~= "table" then return end
    if type(CellDB["minimapButton"]) ~= "table" then
        CellDB["minimapButton"] = {["shown"] = true, ["degree"] = 195}
    end
    return CellDB["minimapButton"]
end

local function UpdatePosition()
    local db = GetDB()
    local rad = math.rad((db and db["degree"]) or 195)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 80, math.sin(rad) * 80)
end

-- drag around the minimap
button:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local db = GetDB()
        if not db then return end
        local mx, my = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local px, py = GetCursorPosition()
        px, py = px / scale, py / scale
        db["degree"] = math.floor(math.deg(math.atan2(py - my, px - mx)) + 0.5)
        UpdatePosition()
    end)
end)

button:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

--! WotLK fix: MainFrame.lua no longer installs a permanent constant state
--! driver. Toggle the protected Cell root directly, outside combat, through its
--! private owner instead of leaving SecureStateDriver polling forever.
local framesHidden = false
local function ToggleCellFrames()
    if InCombatLockdown() then --! protected frames cannot be shown/hidden in combat
        F.Print(L["Cannot toggle Cell frames in combat."])
        return
    end
    framesHidden = not framesHidden
    if Cell.SetMainFrameVisibility then
        Cell.SetMainFrameVisibility(not framesHidden)
    elseif framesHidden then
        Cell.frames.mainFrame:Hide()
    else
        Cell.frames.mainFrame:Show()
    end
end

--! WotLK feature: правый клик - тумблер режима мувера, то же самое, что
--! /cell unlock и /cell lock. Единственный вход - U.SetMoverShown (см. RaidTools),
--! без аргумента он сам переключает Cell.vars.showMover и печатает в чат, что
--! включилось. Работает и в бою: protected-состояние тут не трогается, показываются
--! только зелёные рамки Marks Bar / ReadyCheck-PullTimer / Buff Tracker.
--! Открытие опций не потеряно - переехало на Shift+правый клик и подписано в тултипе.
local function ToggleMover()
    if Cell.uFuncs and Cell.uFuncs.SetMoverShown then
        Cell.uFuncs.SetMoverShown() --! nil -> toggle
    else
        F.Print("Raid Tools module not loaded.")
    end
end

button:SetScript("OnClick", function(self, b)
    if b == "LeftButton" then
        -- hide/show all Cell frames (raid/party/solo/pets/npc/spotlight share mainFrame)
        ToggleCellFrames()
    elseif b == "RightButton" then
        if IsShiftKeyDown() then
            F.ShowOptionsFrame()
        else
            ToggleMover()
            --! WotLK feature: тултип открыт под курсором и подпись в нём только что
            --! устарела - перерисовываем его тем же обработчиком, иначе игрок видит
            --! "Разблокировать" на уже разблокированном мувере до ухода курсора.
            if GameTooltip:IsOwned(self) then
                self:GetScript("OnEnter")(self)
            end
        end
    elseif b == "MiddleButton" then
        local db = GetDB()
        if db then db["shown"] = false end
        button:Hide()
        GameTooltip:Hide()
        F.Print(L["Minimap button hidden. Use /cell minimap to show it again."])
    end
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFFFF3030Cell|r")
    GameTooltip:AddLine(L["Left-Click"]..": "..L["hide/show all Cell frames"], 1, 1, 1)
    --! WotLK feature: подпись правого клика показывает, что произойдёт по нажатию,
    --! а не название режима: мувер выключен - "Разблокировать", включён - "Заблокировать".
    --! Ключи L["Unlock"]/L["Lock"] уже переведены (кнопка в Raid Tools), новых нет.
    GameTooltip:AddLine(L["Right-Click"]..": "..((Cell.vars and Cell.vars.showMover) and L["Lock"] or L["Unlock"]), 1, 1, 1)
    GameTooltip:AddLine("Shift+"..L["Right-Click"]..": "..L["show Cell options frame"], 1, 1, 1)
    GameTooltip:AddLine(L["Middle-Click"]..": "..L["hide this button"], 1, 1, 1)
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function UpdateMinimapButton()
    local db = GetDB()
    if not db then return end
    UpdatePosition()
    if db["shown"] then
        button:Show()
    else
        button:Hide()
    end
end

Cell.RegisterCallback("AddonLoaded", "MinimapButton_AddonLoaded", UpdateMinimapButton)
Cell.RegisterCallback("UpdateMinimapButton", "MinimapButton_Update", UpdateMinimapButton)
