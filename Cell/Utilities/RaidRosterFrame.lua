local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs
local A = Cell.animations
local LibTranslit = LibStub("LibTranslit-1.0")
local LCG = LibStub("LibCustomGlow-1.0-Cell")

local GetRaidRosterInfo = GetRaidRosterInfo
local SwapRaidSubgroup = SwapRaidSubgroup
local SetRaidSubgroup = SetRaidSubgroup

local LoadRoster, UpdateRoster
local UpdateMode, CheckPermission, UpdateAssistantState
local PremadeSwap, PremadeSet, PremadeApply, ProcessNext

local groups = {} -- contains girds
local changes = {} -- store subgroup changed member indices
local queue
-- local premadeGroups = {} -- contains member nums of each sub group

local isInstantMode = true
local isProcessing = false
local modeBtn, assistantCB, processingFrame, progressBar, combatTips

local function Reset(reload)
    -- print("RESET", reload)
    queue = nil
    isInstantMode = true
    isProcessing = false
    wipe(changes)
    UpdateMode()

    if reload then
        LoadRoster()
    end
end

-------------------------------------------------
-- raid roster frame
-------------------------------------------------
local raidRosterFrame = Cell.CreateFrame("CellRaidRosterFrame", Cell.frames.mainFrame, 405, 230)
Cell.frames.raidRosterFrame = raidRosterFrame
raidRosterFrame:SetFrameStrata("DIALOG")
raidRosterFrame:SetFrameLevel(5)

local function CreateWidgets()
    -- mode
    modeBtn = Cell.CreateButton(raidRosterFrame, L["Instant Mode"], "accent", {127, 17})
    modeBtn:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\instant", {13, 13}, {"LEFT", 4, 0})
    modeBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    modeBtn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then -- switch mode / apply changes
            if isInstantMode then
                isInstantMode = false
                UpdateMode()
            else
                if not isProcessing then
                    isProcessing = true
                    PremadeApply()
                end
            end

        else -- discard changes
            if isProcessing then
                processingFrame:Hide()
            else
                Reset(true)
            end
        end
    end)

    Cell.SetTooltips(modeBtn, "ANCHOR_TOPRIGHT", 0, 2,
        "|cffff2727EXPERIMENTAL|r",
        L["No support for rearrangement of members within a same subgroup"],
        L["No guarantee of the order of members in each subgroup"],
        "|cffffb5c5"..L["Left-Click"]..":|r "..L["change mode / apply changes"],
        "|cffffb5c5"..L["Right-Click"]..":|r "..L["discard changes"]
    )

    -- SetEveryoneIsAssistant
    assistantCB = Cell.CreateCheckButton(raidRosterFrame, "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:16:16|t", function(checked)
        --! WotLK fix: keep assistant batching private to Cell.
        Cell.SetEveryoneIsAssistant(checked)
    end)
    assistantCB:SetPoint("BOTTOMRIGHT", -25, 5)

    local tips = Cell.CreateScrollTextFrame(raidRosterFrame, "|cffb7b7b7"..L["raidRosterTips"], 0.02, nil, 2)
    tips:SetPoint("BOTTOMLEFT", raidRosterFrame, 5, 2)
    tips:SetPoint("RIGHT", assistantCB, "LEFT", -5, 0)
end

local function UpdateModeBtnPosition()
    local anchor = Cell.vars.currentLayoutTable.main.anchor
    modeBtn:ClearAllPoints()
    if anchor == "TOPLEFT" then
        modeBtn:SetPoint("BOTTOMRIGHT", raidRosterFrame, "TOPRIGHT", 0, 4)
    elseif anchor == "TOPRIGHT" then
        modeBtn:SetPoint("BOTTOMLEFT", raidRosterFrame, "TOPLEFT", 0, 4)
    elseif anchor == "BOTTOMLEFT" then
        modeBtn:SetPoint("TOPRIGHT", raidRosterFrame, "BOTTOMRIGHT", 0, -4)
    elseif anchor == "BOTTOMRIGHT" then
        modeBtn:SetPoint("TOPLEFT", raidRosterFrame, "BOTTOMLEFT", 0, -4)
    end
end

local function UpdateInstantRoster()
    if raidRosterFrame:IsShown() and isInstantMode then
        LoadRoster()
        CheckPermission()
        UpdateAssistantState()
    end
end

local function ProcessRosterChange()
    if processingFrame and processingFrame:IsShown() then
        ProcessNext()
    end
end

UpdateMode = function()
    --! WotLK fix: the backport receives roster changes through Cell's private
    --! callback bus, which does not stop dispatching merely because this frame
    --! is hidden. Reset() runs from OnHide, so registration must be gated here
    --! or OnHide immediately re-adds the listener it just removed.
    if isInstantMode and raidRosterFrame:IsShown() then
        Cell.RegisterCallback(
            "GroupRosterUpdate",
            "RaidRosterFrame_InstantRosterUpdate",
            UpdateInstantRoster
        )
    else
        Cell.UnregisterCallback(
            "GroupRosterUpdate",
            "RaidRosterFrame_InstantRosterUpdate"
        )
    end

    -- update button
    if isInstantMode then
        modeBtn:SetText(L["Instant Mode"])
        modeBtn.tex:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\instant")
        LCG.PixelGlow_Stop(modeBtn)
    else
        modeBtn:SetText(L["Premade Mode"])
        modeBtn.tex:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\premade")
        LCG.PixelGlow_Start(modeBtn, Cell.GetAccentColorTable(1), 12, 0.25, 10, 1)
    end
end

local function CreateProcessingFrame()
    -- processing
    processingFrame = CreateFrame("Frame", nil, raidRosterFrame, nil)
    processingFrame:SetPoint("TOPLEFT", P.Scale(1), P.Scale(-1))
    processingFrame:SetPoint("BOTTOMRIGHT", P.Scale(-1), P.Scale(1))
    Cell.StylizeFrame(processingFrame, {0.15, 0.15, 0.15, 0.7}, {0, 0, 0, 0})
    processingFrame:SetFrameLevel(raidRosterFrame:GetFrameLevel()+30)
    processingFrame:EnableMouse(true)
    processingFrame:Hide()

    processingFrame:SetScript("OnShow", function()
        --! WotLK fix: processing advances from Cell's normalized roster
        --! callback instead of the non-native GROUP_ROSTER_UPDATE event.
        Cell.RegisterCallback(
            "GroupRosterUpdate",
            "RaidRosterFrame_ProcessRosterChange",
            ProcessRosterChange
        )
        ProcessNext()
    end)

    processingFrame:SetScript("OnHide", function()
        processingFrame:Hide()
        processingFrame:UnregisterAllEvents()
        Cell.UnregisterCallback(
            "GroupRosterUpdate",
            "RaidRosterFrame_ProcessRosterChange"
        )
        Reset(true)
    end)

    processingFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            processingFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            combatTips:Hide()
        end
        ProcessNext()
    end)

    A.CreateFadeOut(processingFrame, 1, 0, 0.5, 0.5)

    -- progress bar
    progressBar = Cell.CreateStatusBar(nil, processingFrame, 1, 1, 100, true, nil, true, "Interface\\AddOns\\Cell\\Media\\statusbar", Cell.GetAccentColorTable())
    progressBar:SetPoint("TOPLEFT", 10, -103)
    progressBar:SetPoint("BOTTOMRIGHT", -10, 102)

    -- combat tips
    combatTips = processingFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    combatTips:SetPoint("TOP", progressBar, "BOTTOM", 0, -5)
    combatTips:SetTextColor(1, 0.2, 0.2)
    combatTips:SetText(L["Waiting for combat to end..."])
    combatTips:Hide()
end

-------------------------------------------------
-- premade
-------------------------------------------------
PremadeSwap = function(grid1, grid2)
    if grid1.subgroup == grid2.subgroup and grid1._subgroup == grid2._subgroup then
        -- NOTE: in same group, don't swap
        return
    end

    local tempPoint1 = grid1._point1 or grid1.point1
    local tempPoint2 = grid1._point2 or grid1.point2

    grid1._point1 = grid2._point1 or grid2.point1
    grid1._point2 = grid2._point2 or grid2.point2
    grid2._point1 = tempPoint1
    grid2._point2 = tempPoint2

    local anchor1 = grid1._subgroup and groups[grid1._subgroup] or groups[grid1.subgroup]
    local anchor2 = grid2._subgroup and groups[grid2._subgroup] or groups[grid2.subgroup]

    grid1._anchor = anchor2
    grid2._anchor = anchor1

    grid1:ClearAllPoints()
    grid1:SetPoint(grid1._point1[1], anchor2, grid1._point1[2], grid1._point1[3])
    grid1:SetPoint(grid1._point2[1], anchor2, grid1._point2[2], grid1._point2[3])

    grid2:ClearAllPoints()
    grid2:SetPoint(grid2._point1[1], anchor1, grid2._point1[2], grid2._point1[3])
    grid2:SetPoint(grid2._point2[1], anchor1, grid2._point2[2], grid2._point2[3])

    local subgroup = grid1._subgroup or grid1.subgroup
    grid1._subgroup = grid2._subgroup or grid2.subgroup
    grid2._subgroup = subgroup

    local index = grid1._index or grid1.index
    grid1._index = grid2._index or grid2.index
    grid2._index = index

    if grid1.hasUnit then
        if grid1._subgroup ~= grid1.subgroup then
            changes[grid1.fullName] = {grid1._subgroup, grid1._index, grid2.fullName}
        else
            changes[grid1.fullName] = nil
        end
    end

    if grid2.hasUnit then
        if grid2._subgroup ~= grid2.subgroup then
            changes[grid2.fullName] = {grid2._subgroup, grid2._index, grid1.fullName}
        else
            changes[grid2.fullName] = nil
        end
    end
end

PremadeSet = function(grid, emptyGrid)
    -- premadeGroups[grid._subgroup or grid.subgroup] = premadeGroups[grid._subgroup or grid.subgroup] - 1
    -- premadeGroups[emptyGrid._subgroup or emptyGrid.subgroup] = premadeGroups[emptyGrid._subgroup or emptyGrid.subgroup] + 1

    PremadeSwap(grid, emptyGrid)
end

ProcessNext = function()
    -- print("ProcessNext", queue and queue[1] or nil)
    if queue and queue[1] then
        local noAction = true

        local next = queue[1]
        local fromIndex, fromSubgroup = F.GetRaidInfoByName(next)

        local targetSubgroup = changes[next][1]
        local targetIndex = changes[next][2] -- index in subgroup, not raidIndex
        local targetPlayer = changes[next][3]

        if fromIndex then -- "next" still in raid
            local targetPlayerTarget = changes[targetPlayer] and changes[targetPlayer][3] or nil
            local toIndex, toName = F.GetRaidInfoBySubgroupIndex(targetSubgroup, targetIndex)

            -- print(next, "raidIndex:", fromIndex, "subgroup:", fromSubgroup.."->"..targetSubgroup, "targetIndex:", targetIndex, "targetPlayer:", targetPlayer, targetPlayerTarget)

            if toIndex and targetPlayerTarget == next then -- NOTE: unit to be swapped with exists, and requires a swap with "next"
                if fromIndex ~= toIndex then
                    if not InCombatLockdown() then
                        noAction = false
                        SwapRaidSubgroup(fromIndex, toIndex)
                    else
                        processingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                        combatTips:Show()
                        return
                    end
                end
            else  -- NOTE: non-full subgroup, set
                if fromSubgroup ~= targetSubgroup and F.GetNumSubgroupMembers(targetSubgroup) < 5 then
                    if not InCombatLockdown() then
                        noAction = false
                        SetRaidSubgroup(fromIndex, targetSubgroup)
                    else
                        processingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                        combatTips:Show()
                        return
                    end
                end
            end
        end

        tremove(queue, 1)
        progressBar.value = progressBar.value + 1
        progressBar:SetSmoothedValue(progressBar.value)

        -- NOTE: run next immediately
        if noAction then
            ProcessNext()
        end
    else
        processingFrame:FadeOut()
    end
end

PremadeApply = function()
    queue = F.GetKeys(changes)
    local n = #queue
    if n ~= 0 then
        progressBar:SetMaxValue(n)
        progressBar:SetValue(0)
        progressBar.value = 0
        -- texplore(queue)
        processingFrame:Show()
    else
        Reset(true)
    end
end

-------------------------------------------------
-- roster
-------------------------------------------------
local movingGrid

--! WotLK fix: the drop target used to be resolved in an OnEvent handler driven by
--! GLOBAL_MOUSE_UP - an event that does not exist on 3.3.5 (added in 8.1.5, codex:
--! "НЕТ GLOBAL_MOUSE_UP"). Its two registrations were commented out during the
--! backport and nothing else ever fired the handler, so dragging a player in the
--! raid roster window did nothing whatsoever - the tile snapped back and no
--! subgroup changed. That is the only function this window has. The comment that
--! used to sit here claimed "drag-swap still ends via the buttons' own mouse
--! handlers"; there are no OnMouseUp/OnMouseDown/OnReceiveDrag handlers anywhere
--! in this file, so the claim was false.
--!
--! Blizzard's own raid UI on this very client does the same job with no event at
--! all: Blizzard_RaidUI.lua:626-651 resolves the target inside OnDragStop by
--! geometry, and :566-583 highlights it from an OnUpdate while the drag runs. Cell
--! already highlights the hovered tile from its own per-grid OnUpdate below, so
--! only the resolution needs a home; putting it in OnDragStop costs one 40-tile
--! walk per drop instead of 1600 IsMouseOver calls per frame. OnDragStop is a
--! native Button script on 3.3.5 (codex) and it does fire.
--!
--! IsMouseOver is a Region method and purely geometric - it does not care whether
--! the frame accepts mouse input. That matters here: an empty tile switches its
--! mouse off (grid:Reset -> EnableMouse(false) below) yet still has to accept a
--! drop, because dropping onto an empty slot is how a player is moved into an
--! unfilled group. GetMouseFocus would have refused those tiles.
local function FindDropTarget(source)
    for i = 1, 8 do
        local group = groups[i]
        if group then
            for j = 1, 5 do
                local grid = group[j]
                --! Tiles are 17 high on a 16 step, so neighbours overlap by 1px and
                --! two can match at once; the first hit wins, which is the upper one.
                if grid and grid ~= source and grid:IsVisible() and grid:IsMouseOver() then
                    return grid
                end
            end
        end
    end
end

--! WotLK fix: the body below is what used to live in the unreachable OnEvent
--! handler. Nothing about it is retail-only, it simply had no trigger.
local function PerformDrop(source, target)
    if isInstantMode then
        --! SwapRaidSubgroup/SetRaidSubgroup are protected on this client
        --! (codex: both are API functions, and FrameXML guards them the same way),
        --! so a drop that lands during combat is dropped rather than erroring.
        if InCombatLockdown() then return end
        if target.hasUnit then
            SwapRaidSubgroup(source.raidIndex, target.raidIndex)
        else
            SetRaidSubgroup(source.raidIndex, target.subgroup)
        end
    else
        if target.hasUnit then
            PremadeSwap(source, target)
        else
            PremadeSet(source, target)
        end
    end
end

local function CreateRaidRosterGrid(parent, index)
    local grid = CreateFrame("Button", parent:GetName().."Unit"..index, parent, nil)
    P.Size(grid, 100, 17)
    Cell.StylizeFrame(grid, {0.1, 0.1, 0.1, 0.5})
    grid.color = {0.5, 0.5, 0.5}

    grid:SetFrameLevel(7)

    local roleIconBg = grid:CreateTexture(nil, "BORDER")
    roleIconBg:SetPoint("TOPLEFT", 2, -2)
    roleIconBg:SetSize(13, 13)
    --! WotLK fix: SetColorTexture на 3.3.5 нет - это нативная числовая форма
    --! SetTexture(r, g, b[, a]); шим TextureBase в WidgetAPI удалён.
    roleIconBg:SetTexture(0, 0, 0, 1)

    local roleIcon = grid:CreateTexture(nil, "ARTWORK")
    roleIcon:SetPoint("TOPLEFT", roleIconBg, P.Scale(1), P.Scale(-1))
    roleIcon:SetPoint("BOTTOMRIGHT", roleIconBg, P.Scale(-1), P.Scale(1))
    roleIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    local nameText = grid:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    nameText:SetPoint("LEFT", roleIcon, "RIGHT", 2, 0)
    nameText:SetPoint("RIGHT", -2, 0)
    nameText:SetWordWrap(false)
    nameText:SetJustifyH("LEFT")

    -- click
    grid:RegisterForClicks("RightButtonDown")
    grid:SetScript("OnClick", function()
        if IsAltKeyDown() then
            UninviteUnit(grid.name)
        else
            if not Cell.UnitIsGroupLeader("player") then return end

            if Cell.UnitIsGroupLeader(grid.unit) then return end

            if Cell.UnitIsGroupAssistant(grid.unit) then
                DemoteAssistant(grid.unit)
            else
                PromoteToAssistant(grid.unit)
            end
        end
    end)

    -- drag
    grid:SetMovable(true)
    grid:RegisterForDrag("LeftButton")
    grid:SetScript("OnDragStart", function()
        grid:SetFrameLevel(9)
        grid:StartMoving()
        grid:SetUserPlaced(false)
        grid:SetBackdropBorderColor(unpack(grid.color))
        grid:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        grid.isMoving = true
        movingGrid = grid
    end)
    --! WotLK fix: the drop is resolved and performed here now, not in the OnEvent
    --! handler that used to sit below and never ran. Blizzard's own raid window does
    --! exactly this on this client: RaidGroupButton_OnDragStop calls
    --! SwapRaidSubgroup / SetRaidSubgroup itself (Blizzard_RaidUI.lua:626-651).
    --! The second argument is Cell's own invention - 3.3.5 passes only self to
    --! OnDragStop, so the slot is free, and LoadRoster uses it to cancel an
    --! in-flight drag without moving anybody (the roster it was dragging against
    --! has just been rebuilt, so a drop there would land on stale tiles).
    grid:SetScript("OnDragStop", function(self, noDrop)
        grid:SetFrameLevel(7)
        grid:StopMovingOrSizing()
        grid:ClearAllPoints()
        if grid._anchor then
            grid:SetPoint(grid._point1[1], grid._anchor, grid._point1[2], grid._point1[3])
            grid:SetPoint(grid._point2[1], grid._anchor, grid._point2[2], grid._point2[3])
        else
            grid:SetPoint(unpack(grid.point1))
            grid:SetPoint(unpack(grid.point2))
        end
        grid:SetBackdropBorderColor(0, 0, 0, 1)
        grid:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        grid.isMoving = nil
        --! cleared unconditionally: the old code only cleared it inside the swap
        --! branch, so a cancelled drag left movingGrid pointing at a live tile
        --! forever.
        movingGrid = nil

        if not noDrop and grid.hasUnit then
            local target = FindDropTarget(grid)
            if target then
                PerformDrop(grid, target)
            end
        end
    end)

    -- onupdate
    grid:SetScript("OnUpdate", function()
        if not grid.isMoving then
            if grid:IsMouseOver() then
                grid:SetBackdropColor(grid.color[1], grid.color[2], grid.color[3], 0.2)
            else
                grid:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
            end
        end
    end)

    function grid:Update()
        nameText:SetText(grid.name)
        nameText:SetTextColor(unpack(grid.color))

        roleIcon:Show()
        roleIconBg:Show()
        -- NOTE: fileID textures (134400) are not supported on 3.3.5a, use the path;
        -- also this checked an undefined local "role" instead of grid.role (upstream typo)
        if not grid.role or grid.role == "NONE" then
            roleIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        else
            roleIcon:SetTexture(F.GetDefaultRoleIcon(grid.role))
        end

        if grid.isLeader then
            roleIconBg:SetTexture(1, 0.84, 0, 1)
        elseif grid.isAssistant then
            roleIconBg:SetTexture(0.7, 0.7, 0.7, 1)
        else
            roleIconBg:SetTexture(0, 0, 0, 1)
        end
    end

    function grid:Reset()
        F.RemoveElementsByKeys(grid,
            "hasUnit", "raidIndex", "unit", "fullName", "name", "role", "isLeader", "isAssistant",
            "_subgroup", "_index", "_point1", "_point2", "_anchor" -- premade temps
        )
        grid.color[1], grid.color[2], grid.color[3] = 0.5, 0.5, 0.5

        nameText:SetText("")
        nameText:SetTextColor(1, 1, 1)
        roleIconBg:SetTexture(0, 0, 0, 1)
        roleIconBg:Hide()
        roleIcon:Hide()

        grid:ClearAllPoints()
        grid:SetPoint(unpack(grid.point1))
        grid:SetPoint(unpack(grid.point2))

        grid:EnableMouse(false)
    end

    function grid:Set(raidIndex)
        -- NOTE: on 3.3.5a GetRaidRosterInfo has only 11 returns (combatRole was added in 4.x),
        -- resolve the role via Cell's private UnitGroupRolesAssigned adapter instead
        local name, _, subgroup, _, _, classFileName = GetRaidRosterInfo(raidIndex)

        if not name then
            -- unknown target, retry
            C_Timer.After(0.5, function()
                grid:Set(raidIndex)
            end)
            return
        end



        -- save
        grid.fullName = name -- contains server name for cross-realm players

        if string.find(name, "-") then
            name = strsplit("-", name)
        end

        if CellDB["general"]["translit"] then
            name = LibTranslit:Transliterate(name)
        end

        grid.hasUnit = true
        grid.raidIndex = raidIndex
        grid.unit = "raid"..raidIndex
        grid.name = name
        grid.role = Cell.UnitGroupRolesAssigned("raid"..raidIndex) --! WotLK fix: Cell-private role adapter (global stays native).
        grid.color[1], grid.color[2], grid.color[3] = F.GetClassColor(classFileName)
        grid.isLeader = Cell.UnitIsGroupLeader(grid.unit)
        grid.isAssistant = Cell.UnitIsGroupAssistant(grid.unit)

        -- update
        grid:Update()
        grid:EnableMouse(true)
    end

    return grid
end

local function CreateRaidRosterGroup(parent, groupIndex)
    local group = CreateFrame("Frame", parent:GetName().."Subgroup"..groupIndex, parent, nil)
    P.Size(group, 95, 81)
    Cell.StylizeFrame(group, {0.1, 0.1, 0.1, 0.5})

    local headerText = group:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    headerText:SetPoint("BOTTOM", group, "TOP", 0, 1)
    headerText:SetText("|cFFEEC900"..GROUP.." "..groupIndex)

    for i = 1, 5 do
        group[i] = CreateRaidRosterGrid(group, i)
        group[i].point1 = {"TOPLEFT", 0, -(i-1)*16}
        group[i]:SetPoint(unpack(group[i].point1))
        group[i].point2 = {"TOPRIGHT", 0, -(i-1)*16}
        group[i]:SetPoint(unpack(group[i].point2))
        group[i].subgroup = groupIndex
        group[i].index = i
    end

    group.numMembers = 0

    function group:Reset()
        group.numMembers = 0
        for i = 1, 5 do
            group[i]:Reset()
        end
    end

    function group:Insert(raidIndex)
        group.numMembers = group.numMembers + 1
        group[group.numMembers]:Set(raidIndex)
    end

    return group
end

local function CreateRosterContainer()
    local rosterContainer = CreateFrame("Frame", "CellRaidRosterFrameContainer", raidRosterFrame)
    rosterContainer:SetPoint("TOPLEFT", 5, -5)
    rosterContainer:SetPoint("BOTTOMRIGHT", raidRosterFrame, "TOPRIGHT", -5, -207)

    for i = 1, 8 do
        groups[i] = CreateRaidRosterGroup(rosterContainer, i)

        if i % 4 == 1 then
            groups[i]:SetPoint("TOPLEFT", 0, -20-(math.modf(i/4)*(groups[i]:GetHeight()+20)))
        else
            groups[i]:SetPoint("TOPLEFT", groups[i-1], "TOPRIGHT", 5, 0)
        end
    end
end

-------------------------------------------------
-- functions
-------------------------------------------------
LoadRoster = function()
    if movingGrid then
        --! WotLK fix: pass self, and ask for a cancel rather than a drop - the
        --! roster is about to be rebuilt from scratch, so whatever tile the cursor
        --! happens to hover is stale. The old call passed no arguments at all;
        --! that was harmless only because the handler ignored its parameters, and
        --! it left movingGrid set, which is now cleared inside the handler.
        movingGrid:GetScript("OnDragStop")(movingGrid, true)
    end

    -- reset
    for i = 1, 8 do
        groups[i]:Reset()
        -- premadeGroups[i] = 0
    end

    -- insert
    for i = 1, Cell.GetNumGroupMembers() do
        local subgroup = select(3, GetRaidRosterInfo(i))
        groups[subgroup]:Insert(i)
        -- premadeGroups[subgroup] = premadeGroups[subgroup] + 1
    end
end

UpdateRoster = function()

end

-------------------------------------------------
-- scripts
-------------------------------------------------
CheckPermission = function()
    if Cell.UnitIsGroupLeader("player") or Cell.UnitIsGroupAssistant("player") then
        if raidRosterFrame.mask then raidRosterFrame.mask:Hide() end
    else
        Cell.CreateMask(raidRosterFrame, L["You don't have permission to do this"], {1, -1, -1, 1})
    end
end

UpdateAssistantState = function()
    if assistantCB then
        assistantCB:SetChecked(Cell.IsEveryoneAssistant())
    end
end

raidRosterFrame:SetScript("OnEvent", function()
    LoadRoster()
    CheckPermission()
    UpdateAssistantState()
end)

raidRosterFrame:SetScript("OnShow", function()
    --! WotLK fix: UpdateMode owns the private roster callback according to
    --! instant/premade mode; no synthetic frame event is registered here.
    UpdateMode()
    LoadRoster()
    CheckPermission()
    UpdateAssistantState()
end)

raidRosterFrame:SetScript("OnHide", function()
    --! WotLK fix: hiding a frame does not stop an in-progress StartMoving/
    --! StopMovingOrSizing drag on 3.3.5 - Blizzard's own raid window has the exact
    --! same guard for the exact same reason (Blizzard_RaidUI.lua:158-162,
    --! RaidGroupFrame_OnHide -> RaidGroupButton_OnDragStop). Without it, closing
    --! this window mid-drag (Escape, clicking elsewhere) left the tile silently
    --! tracking the cursor forever and movingGrid stuck non-nil.
    if movingGrid then
        movingGrid:GetScript("OnDragStop")(movingGrid, true)
    end
    Cell.UnregisterCallback(
        "GroupRosterUpdate",
        "RaidRosterFrame_InstantRosterUpdate"
    )
    Reset()
end)

-------------------------------------------------
-- callbacks
-------------------------------------------------
local function GroupTypeChanged(groupType)
    raidRosterFrame:Hide()
end
Cell.RegisterCallback("GroupTypeChanged", "RaidRosterFrame_GroupTypeChanged", GroupTypeChanged)

local function UpdateLayout(layout, which)
    if Cell.vars.isHidden then
        raidRosterFrame:Hide()
        return
    end

    layout = Cell.vars.currentLayoutTable
    if not which or which == "main-arrangement" then
        raidRosterFrame:ClearAllPoints()
        raidRosterFrame:SetPoint(layout["main"]["anchor"], Cell.frames.mainFrame)

        if modeBtn then UpdateModeBtnPosition() end
    end
end
Cell.RegisterCallback("UpdateLayout", "RaidRosterFrame_UpdateLayout", UpdateLayout)

-------------------------------------------------
-- show
-------------------------------------------------
local init
function F.ShowRaidRosterFrame()
    if not init then
        init = true
        raidRosterFrame:UpdatePixelPerfect()
        CreateWidgets()
        CreateProcessingFrame()
        UpdateModeBtnPosition()
        CreateRosterContainer()
    end

    if raidRosterFrame:IsShown() then
        raidRosterFrame:Hide()
    else
        raidRosterFrame:Show()
        -- texplore(changes)
    end
end

-------------------------------------------------
-- pixel perfect
-------------------------------------------------
--! WotLK fix: смену масштаба этому окну ловить было некому - колбэка
--! "UpdatePixelPerfect" тут не было ни одного, а единственный
--! raidRosterFrame:UpdatePixelPerfect() стоит в F.ShowRaidRosterFrame за флагом
--! `init`, то есть срабатывает один раз за сеанс. Толщина рамки - это P.Scale(1),
--! записанный при создании кадра (Cell.StylizeFrame, Widgets.lua:383), и после
--! смены масштаба он уже не тот: 0.7111 против 0.8466 при масштабе 0.84, то есть
--! линия рисуется в 0.84 физического пикселя вместо ровно одного - тусклая и
--! рваная. Полный разбор формы и всех трёх триггеров смены масштаба - в
--! Modules/OptionsFrame.lua, колбэк UpdatePixelPerfect. На экране: рамка окна
--! состава рейда и клетки внутри не совпадают по толщине с остальными рамками
--! аддона и остаются такими до /reload.
--! Обходим детей, а не только родителя (та же форма, что в
--! RaidFrames/Groups/SpotlightFrame.lua:1152): бэкдроп есть у 8 подгрупп и у всех
--! 40 клеток, а шов между ними виден лучше, чем рамка самого окна. Родителю годится
--! его собственный метод - своих цветов у окна нет, сброс в умолчания ничего не
--! меняет; детям P.Reborder, он снимает и возвращает оба цвета, а кнопке хватает
--! b:UpdatePixelPerfect (Widgets.lua:733). Полосе прогресса только рамка: размер ей
--! задают два якоря, а не width/height. До первого открытия окна детей не
--! существует - родившись позже, они возьмут уже верный P.Scale(1), поэтому обход
--! стоит за тем же флагом `init`.
local function UpdatePixelPerfect()
    raidRosterFrame:UpdatePixelPerfect()

    if not init then return end

    modeBtn:UpdatePixelPerfect()

    P.Resize(assistantCB)
    P.Reborder(assistantCB, true)

    P.Reborder(processingFrame, true)
    P.Reborder(progressBar, true)

    for i = 1, 8 do
        P.Resize(groups[i])
        P.Reborder(groups[i], true)
        for j = 1, 5 do
            P.Resize(groups[i][j])
            P.Reborder(groups[i][j], true)
        end
    end
end
Cell.RegisterCallback("UpdatePixelPerfect", "RaidRosterFrame_UpdatePixelPerfect", UpdatePixelPerfect)
