local _, Cell = ...
local F = Cell.funcs
local B = Cell.bFuncs
local P = Cell.pixelPerfectFuncs

local soloFrame = CreateFrame("Frame", "CellSoloFrame", Cell.frames.mainFrame, "SecureFrameTemplate")
Cell.frames.soloFrame = soloFrame
soloFrame:SetAllPoints(Cell.frames.mainFrame)

local playerButton = CreateFrame("Button", soloFrame:GetName().."Player", soloFrame, "CellUnitButtonTemplate")
-- playerButton.type = "main" -- layout setup
playerButton:SetAttribute("unit", "player")
playerButton:SetPoint("TOPLEFT")
playerButton:Show()
Cell.unitButtons.solo["player"] = playerButton

local petButton = CreateFrame("Button", soloFrame:GetName().."Pet", soloFrame, "CellUnitButtonTemplate")
-- petButton.type = "pet" -- layout setup
petButton:SetAttribute("unit", "pet")
Cell.unitButtons.solo["pet"] = petButton

local function SoloFrame_UpdateLayout(layout, which)
    -- visibility
    if Cell.vars.groupType ~= "solo" or Cell.vars.isHidden then
        UnregisterAttributeDriver(soloFrame, "state-visibility")
        soloFrame:Hide()
        return
    else
        RegisterAttributeDriver(soloFrame, "state-visibility", "[@raid1,exists] hide;[@party1,exists] hide;[group] hide;show")
    end

    -- update
    layout = CellDB["layouts"][layout]

    if not which or strfind(which, "size$") then
        local width, height = unpack(layout["main"]["size"])
        P.Size(playerButton, width, height)
        if layout["pet"]["sameSizeAsMain"] then
            P.Size(petButton, width, height)
        else
            P.Size(petButton, layout["pet"]["size"][1], layout["pet"]["size"][2])
        end
    end

    -- NOTE: SetOrientation BEFORE SetPowerSize
    if not which or which == "barOrientation" then
        B.SetOrientation(playerButton, layout["barOrientation"][1], layout["barOrientation"][2])
        B.SetOrientation(petButton, layout["barOrientation"][1], layout["barOrientation"][2])
    end

    if not which or strfind(which, "power$") or which == "barOrientation" or which == "powerFilter" then
        B.SetPowerSize(playerButton, layout["main"]["powerSize"])
        if layout["pet"]["sameSizeAsMain"] then
            B.SetPowerSize(petButton, layout["main"]["powerSize"])
        else
            B.SetPowerSize(petButton, layout["pet"]["powerSize"])
        end
    end

    if not which or which == "main-arrangement" or which == "pet-arrangement" then
        petButton:ClearAllPoints()
        if layout["main"]["orientation"] == "vertical" then
            -- anchor
            local point, anchorPoint
            local petSpacing = layout["pet"]["sameArrangementAsMain"] and layout["main"]["spacingY"] or layout["pet"]["spacingY"]

            if layout["main"]["anchor"] == "BOTTOMLEFT" then
                point, anchorPoint = "BOTTOMLEFT", "TOPLEFT"
            elseif layout["main"]["anchor"] == "BOTTOMRIGHT" then
                point, anchorPoint = "BOTTOMRIGHT", "TOPRIGHT"
            elseif layout["main"]["anchor"] == "TOPLEFT" then
                point, anchorPoint = "TOPLEFT", "BOTTOMLEFT"
                petSpacing = -petSpacing
            elseif layout["main"]["anchor"] == "TOPRIGHT" then
                point, anchorPoint = "TOPRIGHT", "BOTTOMRIGHT"
                petSpacing = -petSpacing
            end

            petButton:SetPoint(point, playerButton, anchorPoint, 0, P.Scale(petSpacing))
        else
            -- anchor
            local point, anchorPoint
            local petSpacing = layout["pet"]["sameArrangementAsMain"] and layout["main"]["spacingX"] or layout["pet"]["spacingX"]

            if layout["main"]["anchor"] == "BOTTOMLEFT" then
                point, anchorPoint = "BOTTOMLEFT", "BOTTOMRIGHT"
            elseif layout["main"]["anchor"] == "BOTTOMRIGHT" then
                point, anchorPoint = "BOTTOMRIGHT", "BOTTOMLEFT"
                petSpacing = -petSpacing
            elseif layout["main"]["anchor"] == "TOPLEFT" then
                point, anchorPoint = "TOPLEFT", "TOPRIGHT"
            elseif layout["main"]["anchor"] == "TOPRIGHT" then
                point, anchorPoint = "TOPRIGHT", "TOPLEFT"
                petSpacing = -petSpacing
            end

            petButton:SetPoint(point, playerButton, anchorPoint, P.Scale(petSpacing), 0)
        end
    end

    if not which or which == "pet" then
        if layout["pet"]["soloEnabled"] then
            RegisterAttributeDriver(petButton, "state-visibility", "[nopet] hide; [vehicleui] hide; show")
        else
            UnregisterAttributeDriver(petButton, "state-visibility")
            petButton:Hide()
        end
    end
end
Cell.RegisterCallback("UpdateLayout", "SoloFrame_UpdateLayout", SoloFrame_UpdateLayout)

-- WotLK Fix: Force update solo buttons when returning to solo group type
-- The RegisterAttributeDriver visibility state doesn't always sync properly after leaving BG/raid
local function SoloFrame_GroupTypeChanged(groupType)
    if groupType == "solo" then
        -- Force update after a delay to ensure frame is visible
        C_Timer.After(0.5, function()
            if Cell.vars.groupType == "solo" then
                -- Force update player button
                if playerButton then
                    if playerButton:IsVisible() then
                        playerButton._updateRequired = 1
                        playerButton._powerUpdateRequired = 1
                        if playerButton._indicatorsReady and Cell.bFuncs and Cell.bFuncs.UpdateAll then
                            Cell.bFuncs.UpdateAll(playerButton)
                        end
                    else
                        -- Button not visible - the attribute driver may not have updated
                        -- Force show the frame and retry
                        soloFrame:Show()
                        C_Timer.After(0.2, function()
                            if playerButton:IsVisible() then
                                playerButton._updateRequired = 1
                                playerButton._powerUpdateRequired = 1
                                if playerButton._indicatorsReady and Cell.bFuncs and Cell.bFuncs.UpdateAll then
                                    Cell.bFuncs.UpdateAll(playerButton)
                                end
                            end
                        end)
                    end
                end
                -- Force update pet button
                if petButton and petButton:IsVisible() then
                    petButton._updateRequired = 1
                    petButton._powerUpdateRequired = 1
                    if petButton._indicatorsReady and Cell.bFuncs and Cell.bFuncs.UpdateAll then
                        Cell.bFuncs.UpdateAll(petButton)
                    end
                end
            end
        end)
    end
end
Cell.RegisterCallback("GroupTypeChanged", "SoloFrame_GroupTypeChanged", SoloFrame_GroupTypeChanged)

-- local function SoloFrame_UpdateVisibility(which)
--     F.Debug("|cffff7fffUpdateVisibility:|r "..(which or "all"))

--     if not which or which == "solo" then
--         if CellDB["general"]["showSolo"] then
--             RegisterAttributeDriver(soloFrame, "state-visibility", "[@raid1,exists] hide;[@party1,exists] hide;[group] hide;show")
--         else
--             UnregisterAttributeDriver(soloFrame, "state-visibility")
--             soloFrame:Hide()
--         end
--     end
-- end
-- Cell.RegisterCallback("UpdateVisibility", "SoloFrame_UpdateVisibility", SoloFrame_UpdateVisibility)