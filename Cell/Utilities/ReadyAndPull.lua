local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
local PixelUtil = Cell.PixelUtil
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs
local A = Cell.animations
--! WotLK fix: consume Cell-private group adapters.
local IsInRaid = Cell.IsInRaid
local GetNumGroupMembers = Cell.GetNumGroupMembers

local readyBtn, pullBtn

local buttonsFrame = CreateFrame("Frame", "CellReadyAndPullFrame", Cell.frames.mainFrame, "SecureFrameTemplate")
Cell.frames.readyAndPullFrame = buttonsFrame
P.Size(buttonsFrame, 60, 55)
PixelUtil.SetPoint(buttonsFrame, "TOPRIGHT", CellParent, "CENTER", -1, -1)
buttonsFrame:SetClampedToScreen(true)
buttonsFrame:SetMovable(true)
buttonsFrame:RegisterForDrag("LeftButton")
buttonsFrame:SetScript("OnDragStart", function()
    buttonsFrame:StartMoving()
    buttonsFrame:SetUserPlaced(false)
end)
buttonsFrame:SetScript("OnDragStop", function()
    buttonsFrame:StopMovingOrSizing()
    P.SavePosition(buttonsFrame, CellDB["tools"]["readyAndPull"][4])
end)

-------------------------------------------------
-- mover
-------------------------------------------------
buttonsFrame.moverText = buttonsFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
buttonsFrame.moverText:SetPoint("TOP", 0, -3)
--! WotLK fix: the label is set in ShowMover, not here. Cell's L is an identity fallback
--! until ns.LoadUserLocale() runs on ADDON_LOADED, and every file has already executed
--! by then - a FontString filled in the main chunk kept the English key for the whole
--! session on a non-enUS client. ShowMover fires from the options toggle, long after.
buttonsFrame.moverText:Hide()

--! WotLK fix: хват за всю площадь в режиме мувера, см. F.CreateMoverOverlay.
--! Раньше тащить можно было только за полосу над кнопками (~13 экранных пикселей
--! при масштабе 0.7), а промах по ней запускал ready check или pull timer на рейд.
local moverOverlay = F.CreateMoverOverlay(buttonsFrame, function()
    return CellDB["tools"]["readyAndPull"][4]
end)

local function ShowMover(show)
    if show then
        if not CellDB["tools"]["readyAndPull"][1] then return end
        buttonsFrame:EnableMouse(true)
        buttonsFrame.moverText:SetText(L["Mover"]) --! WotLK fix: см. выше
        buttonsFrame.moverText:Show()
        Cell.StylizeFrame(buttonsFrame, {0, 1, 0, 0.4}, {0, 0, 0, 0})
        if not F.HasPermission() then -- button not shown
            readyBtn:Show()
            pullBtn:Show()
        end
        buttonsFrame:SetAlpha(1)
        moverOverlay:Show()
    else
        buttonsFrame:EnableMouse(false)
        buttonsFrame.moverText:Hide()
        Cell.StylizeFrame(buttonsFrame, {0, 0, 0, 0}, {0, 0, 0, 0})
        if not F.HasPermission() then -- button should not shown
            readyBtn:Hide()
            pullBtn:Hide()
        end
        buttonsFrame:SetAlpha(CellDB["tools"]["fadeOut"] and 0 or 1)
        moverOverlay:Hide()
    end
end
Cell.RegisterCallback("ShowMover", "RaidButtons_ShowMover", ShowMover)

-------------------------------------------------
-- pull
-------------------------------------------------
--! WotLK fix: the label is a placeholder, not a translation - UpdateStyle() sets the real
--! L["Pull"] on both of its branches and runs from UpdateTools, i.e. at PLAYER_LOGIN,
--! before the frame is ever shown. It must stay a NON-EMPTY string: Cell.CreateButton
--! captures b:GetFontString() right after b:SetText(text) and guards all label anchoring
--! with `if s then`, so nil/"" here would cost the button its FontString for good.
pullBtn = Cell.CreateStatusBarButton(buttonsFrame, "Pull", {60, 17}, 7, "SecureActionButtonTemplate")
--! WotLK fix: on 3.3.5 SecureActionButton_OnClick executes the action on BOTH
--! down and up (the ActionButtonUseKeyDown cvar gating is a later addition),
--! so registering Up+Down ran the pull macro (e.g. "/dbm pull N") twice per
--! click - with DBM that starts and instantly cancels the pull timer.
--! Register down-only, matching readyBtn below.
pullBtn:RegisterForClicks("LeftButtonDown", "RightButtonDown")
pullBtn:Hide()

-------------------------------------------------
-- pull bar
-------------------------------------------------
pullBtn:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)

local pullTicker, isPullTickerRunning
local function Start(sec, sendToChat)
    isPullTickerRunning = true
    pullBtn:SetMaxValue(sec)
    pullBtn:Start()

    -- update button text
    pullBtn:SetText(sec)
    if pullTicker then
        pullTicker:Cancel()
        pullTicker = nil
    end
    pullBtn.sec = sec
    pullTicker = C_Timer.NewTicker(1, function()
        pullBtn.sec = pullBtn.sec - 1
        if pullBtn.sec == 0 then
            isPullTickerRunning = false
            pullBtn:SetText(L["Go!"])
            if sendToChat then
                SendChatMessage(L["Go!"], IsInRaid() and "RAID_WARNING" or "PARTY")
            end
        elseif pullBtn.sec == -1 then
            pullBtn:SetText(L["Pull"])
        else
            pullBtn:SetText(pullBtn.sec)
            if sendToChat then
                if pullBtn.sec > 3 then
                    SendChatMessage(pullBtn.sec, IsInRaid() and "RAID" or "PARTY")
                else
                    SendChatMessage(pullBtn.sec, IsInRaid() and "RAID_WARNING" or "PARTY")
                end
            end
        end
    end, sec+1)
end

local function Stop()
    isPullTickerRunning = false
    pullBtn:Stop()

    -- update button text
    pullBtn:SetText(L["Pull"])
    if pullTicker then
        pullTicker:Cancel()
        pullTicker = nil
    end
end

--! WotLK fix: listen for DBMv4-PT as well - that is the prefix the DBM of this era
--! actually puts on the wire. Upstream knows only "D4", which arrived with DBM 5.x on
--! Mists; the build Warmane raiders run derives every prefix from `local DBMPrefix =
--! "DBMv4"` (DBM-Core.lua:43, sent at :669) and its Pull() emits
--! sendSync("DBMv4-PT", timer.."\t"..area) (modules/Commands.lua:34) - the string "D4"
--! does not occur anywhere in that addon. So the D4-only branch ignored every pull timer
--! on this client, including the ones Cell itself caused: the "dbm" tool mode clicks the
--! macro /dbm pull N, DBM broadcasts DBMv4-PT, and CHAT_MSG_ADDON delivers a copy to the
--! sender too ("The local client receives any messages it sends"), so the bar can follow
--! DBM's own countdown while DBM does the announcing. Payload: the first tab field is the
--! timer in seconds and 0 means cancel (DBM-Core.lua:3646 - "/dbm pull 0 will strictly be
--! used to cancel the pull timer").
--! strsplit must be assigned before tonumber, never nested: it returns every field, and
--! in a tail position those become tonumber's extra arguments, where field two is read as
--! the numeric base - tonumber("30", "Icecrown") is a hard error. Both branches also
--! require a number now, because tonumber of a junk field is nil and `nil > 0` throws.
function pullBtn:CHAT_MSG_ADDON(prefix, text)
    if prefix == "D4" then -- DBM 5.x and later ports
        local pre, sec = strsplit("\t", text)
        sec = tonumber(sec)
        if pre == "PT" and sec then
            if sec > 0 then -- start
                Start(sec)
            elseif sec == 0 then -- cancel
                Stop()
            end
        end

    elseif prefix == "DBMv4-PT" then -- DBM on 3.3.5a
        local sec = strsplit("\t", text)
        sec = tonumber(sec)
        if sec and sec > 0 then -- start
            Start(sec)
        elseif sec == 0 then -- cancel
            Stop()
        end

    -- elseif prefix == "BigWigs" then
    --     local _, pre, sec = strsplit("^", text)
    --     sec = tonumber(sec)
    --     if pre == "Pull" and sec > 0 then -- start
    --     elseif pre == "Pull" and sec  == 0 then -- cancel
    --     end
    end
end

-------------------------------------------------
-- ready
-------------------------------------------------
--! WotLK fix: placeholder label, see pullBtn above - UpdateStyle() writes L["Ready"] at
--! PLAYER_LOGIN, when the locale is finally loaded.
readyBtn = Cell.CreateStatusBarButton(buttonsFrame, "Ready", {60, 17}, 35)
-- P.Point(readyBtn, "BOTTOMLEFT", pullBtn, "TOPLEFT", 0, 3)
readyBtn:Hide()

--! WotLK fix: left click only. The right-click branch called InitiateRolePoll, which
--! exists neither in the codex nor anywhere in FrameXML 3.3.5a - role polls arrived in
--! 4.0.6, so on this client the branch was unreachable. Worse, it is a rule-3 hazard:
--! Cell does not own that name, and if some other addon publishes an InitiateRolePoll
--! of its own, a right-click on Cell's Ready button would call a stranger's function.
readyBtn:RegisterForClicks("LeftButtonDown")
readyBtn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        DoReadyCheck()
    end
end)

--! WotLK fix: count the confirmations by re-polling the roster, never from the event
--! payload. READY_CHECK_CONFIRM arg1 is a NUMBER on 3.3.5 (roster index with no
--! "raid"/"party" prefix), not a unitID like on retail, and what number the player's
--! OWN confirmation carries in a party is not derivable at all: the player has no
--! partyN token, so any prefix..arg1 key either collides with a real party member
--! (undercount) or invents a slot that is not in the denominator. Stock FrameXML
--! never reads this payload either: PlayerFrame.lua:377, PartyMemberFrame.lua:289
--! and Blizzard_RaidUI.lua:313/952 all re-poll GetReadyCheckStatus(unit) on EVERY
--! confirm event, in every frame, whoever answered - so the client guarantees the
--! status is already updated by the time the event fires. Same decision as
--! UnitButton_Cata_Wrath.lua:4071 for the per-unit ready-check icons.
--! GetReadyCheckStatus returns nil unless the player is leader or raid assistant,
--! and that is exactly who CheckPermission() shows this button to (F.HasPermission),
--! so the restriction never bites here.
local function GetReadyCount()
    local count = 0
    for unit in F.IterateGroupMembers() do
        if GetReadyCheckStatus(unit) == "ready" then
            count = count + 1
        end
    end
    return count
end

readyBtn:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "READY_CHECK" then
        --! WotLK fix: READY_CHECK carries only the initiator name on 3.3.5;
        --! readyCheckTimeLeft (arg2) was added in 4.0. SetMaxValue(nil) reaches
        --! bar:SetMinMaxValues(0, nil) -> Lua error on every ready check.
        --! 35s is the client's fixed ready-check timeout on this build.
        readyBtn:SetMaxValue(arg2 or 35)
        readyBtn:Start()
        readyBtn:SetText(GetReadyCount().." / "..GetNumGroupMembers())
    elseif event == "READY_CHECK_FINISHED" then
        readyBtn:Stop()
        readyBtn:SetText(L["Ready"])
    else
        --! WotLK fix: recount unconditionally - a "notready" answer simply leaves the
        --! number where it was, and the roster pass is the only authoritative source.
        readyBtn:SetText(GetReadyCount().." / "..GetNumGroupMembers())
    end
end)

-------------------------------------------------
-- style
-------------------------------------------------
local function CreateTexture(b, tex)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("CENTER")
    P.Size(b.tex, 16, 16)
    b.tex:SetTexture(tex)

    -- push effect
    b.onMouseDown = function()
        b.tex:ClearAllPoints()
        b.tex:SetPoint("CENTER", 0, -1)
    end
    b.onMouseUp = function()
        b.tex:ClearAllPoints()
        b.tex:SetPoint("CENTER")
    end
    b:SetScript("OnMouseDown", b.onMouseDown)
    b:SetScript("OnMouseUp", b.onMouseUp)

    -- enable / disable
    b:HookScript("OnEnable", function()
        b.tex:SetVertexColor(1, 1, 1)
        b:SetScript("OnMouseDown", b.onMouseDown)
        b:SetScript("OnMouseUp", b.onMouseUp)
    end)
    b:HookScript("OnDisable", function()
        b.tex:SetVertexColor(0.4, 0.4, 0.4)
        b:SetScript("OnMouseDown", nil)
        b:SetScript("OnMouseUp", nil)
    end)
end

local function UpdateStyle()
    P.ClearPoints(pullBtn)
    P.ClearPoints(readyBtn)

    if CellDB["tools"]["readyAndPull"][2] == "text_button" then
        readyBtn:RegisterEvent("READY_CHECK")
        readyBtn:RegisterEvent("READY_CHECK_FINISHED")
        readyBtn:RegisterEvent("READY_CHECK_CONFIRM")

        P.Size(buttonsFrame, 60, 55)
        P.Size(pullBtn, 60, 17)
        P.Size(readyBtn, 60, 17)

        P.Point(pullBtn, "BOTTOMLEFT")
        P.Point(readyBtn, "BOTTOMLEFT", pullBtn, "TOPLEFT", 0, 3)

        pullBtn.tex:Hide()
        pullBtn:SetText(L["Pull"])
        readyBtn.tex:Hide()
        readyBtn:SetText(L["Ready"])
    else
        Stop()
        readyBtn:Stop()

        pullBtn:UnregisterAllEvents()
        readyBtn:UnregisterAllEvents()

        if CellDB["tools"]["readyAndPull"][2] == "icon_button_h" then -- horizontal
            buttonsFrame:SetSize(P.Scale(40)+P.Scale(2), P.Scale(40))
            P.Size(pullBtn, 20, 20)
            P.Size(readyBtn, 20, 20)

            P.Point(readyBtn, "BOTTOMLEFT")
            P.Point(pullBtn, "BOTTOMLEFT", readyBtn, "BOTTOMRIGHT", 2, 0)
        else -- vertical
            P.Size(buttonsFrame, 20, 62)
            P.Size(pullBtn, 20, 20)
            P.Size(readyBtn, 20, 20)

            P.Point(pullBtn, "BOTTOMLEFT")
            P.Point(readyBtn, "BOTTOMLEFT", pullBtn, "TOPLEFT", 0, 2)
        end

        pullBtn.tex:Show()
        pullBtn:SetText("")
        readyBtn.tex:Show()
        readyBtn:SetText("")
    end
end

-------------------------------------------------
-- fade out
-------------------------------------------------
A.ApplyFadeInOutToParent(buttonsFrame, function()
    return CellDB["tools"]["fadeOut"] and not buttonsFrame.moverText:IsShown()
end, readyBtn, pullBtn)

-------------------------------------------------
-- functions
-------------------------------------------------
local function CheckPermission()
    if InCombatLockdown() then
        buttonsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        buttonsFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if F.HasPermission() and CellDB["tools"]["readyAndPull"][1] then
            readyBtn:Show()
            readyBtn:SetEnabled(true)
            pullBtn:Show()
            pullBtn:SetEnabled(true)
        else
            readyBtn:Hide()
            readyBtn:SetEnabled(false)
            pullBtn:Hide()
            pullBtn:SetEnabled(false)
        end
    end
end

buttonsFrame:SetScript("OnEvent", function()
    CheckPermission()
end)

Cell.RegisterCallback("PermissionChanged", "RaidButtons_PermissionChanged", CheckPermission)

local function UpdateTools(which)
    if not which or which == "buttons" then
        CheckPermission()
        ShowMover(Cell.vars.showMover and CellDB["tools"]["readyAndPull"][1])
    end

    if not which or which == "readyAndPull" then
        if not pullBtn.tex then CreateTexture(pullBtn, "Interface\\AddOns\\Cell\\Media\\Icons\\pull") end
        if not readyBtn.tex then CreateTexture(readyBtn, "Interface\\AddOns\\Cell\\Media\\Icons\\ready") end

        pullBtn:UnregisterAllEvents()
        pullBtn:SetScript("OnMouseUp", pullBtn.onMouseUp)
        pullBtn:SetAttribute("type1", "macro")
        pullBtn:SetAttribute("type2", "macro")

        if CellDB["tools"]["readyAndPull"][3][1] == "mrt" then
            pullBtn:RegisterEvent("CHAT_MSG_ADDON")
            pullBtn:SetAttribute("macrotext1", "/ert pull "..CellDB["tools"]["readyAndPull"][3][2])
            pullBtn:SetAttribute("macrotext2", "/ert pull 0")
        elseif CellDB["tools"]["readyAndPull"][3][1] == "dbm" then
            pullBtn:RegisterEvent("CHAT_MSG_ADDON")
            pullBtn:SetAttribute("macrotext1", "/dbm pull "..CellDB["tools"]["readyAndPull"][3][2])
            pullBtn:SetAttribute("macrotext2", "/dbm pull 0")
        elseif CellDB["tools"]["readyAndPull"][3][1] == "bw" then
            pullBtn:RegisterEvent("CHAT_MSG_ADDON")
            pullBtn:SetAttribute("macrotext1", "/pull "..CellDB["tools"]["readyAndPull"][3][2])
            pullBtn:SetAttribute("macrotext2", "/pull 0")
        else -- default
                pullBtn:SetAttribute("type1", nil)
                pullBtn:SetAttribute("type2", nil)
                pullBtn:SetScript("OnMouseUp", function(self, button)
                    if button == "LeftButton" then
                        SendChatMessage(L["Pull in %d sec"]:format(CellDB["tools"]["readyAndPull"][3][2]), IsInRaid() and "RAID_WARNING" or "PARTY")
                        Start(CellDB["tools"]["readyAndPull"][3][2], true)
                    else
                        if isPullTickerRunning then
                            SendChatMessage(L["Pull timer cancelled"], IsInRaid() and "RAID_WARNING" or "PARTY")
                            Stop()
                        end
                    end
                    pullBtn.onMouseUp()
                end)
        end

        UpdateStyle()
    end

    if not which or which == "fadeOut" then
        if CellDB["tools"]["fadeOut"] and not buttonsFrame.moverText:IsShown() then
            buttonsFrame:SetAlpha(0)
        else
            buttonsFrame:SetAlpha(1)
        end
    end

    if not which then -- position
        P.LoadPosition(buttonsFrame, CellDB["tools"]["readyAndPull"][4])
    end
end
Cell.RegisterCallback("UpdateTools", "RaidButtons_UpdateTools", UpdateTools)

local function UpdatePixelPerfect()
    -- P.Resize(buttonsFrame)
    readyBtn:UpdatePixelPerfect()
    pullBtn:UpdatePixelPerfect()
end
Cell.RegisterCallback("UpdatePixelPerfect", "RaidButtons_UpdatePixelPerfect", UpdatePixelPerfect)
