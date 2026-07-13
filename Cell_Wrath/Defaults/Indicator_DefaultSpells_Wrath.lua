local _, Cell = ...
local L = Cell.L
local I = Cell.iFuncs
local F = Cell.funcs

-------------------------------------------------
-- dispelBlacklist
-------------------------------------------------
-- supress dispel highlight
local dispelBlacklist = {}

function I.GetDefaultDispelBlacklist()
    return dispelBlacklist
end

-------------------------------------------------
-- debuffBlacklist
-------------------------------------------------
local debuffBlacklist = {
    8326, -- 鬼魂
    57723, -- 筋疲力尽
    57724, -- 心满意足
}

function I.GetDefaultDebuffBlacklist()
    return debuffBlacklist
end

-------------------------------------------------
-- bigDebuffs
-------------------------------------------------
local bigDebuffs = {
    -- Original Cell
    46392, -- Focused Assault
    
    -- CC Debuffs from ElvUI (Crowd Control)
    -- Death Knight
    47476, -- Strangulate
    51209, -- Hungering Cold
    
    -- Druid
    99, -- Demoralizing Roar
    339, -- Entangling Roots
    2637, -- Hibernate
    5211, -- Bash
    9005, -- Pounce
    22570, -- Maim
    33786, -- Cyclone
    45334, -- Feral Charge Effect
    
    -- Hunter
    1513, -- Scare Beast
    3355, -- Freezing Trap Effect
    19386, -- Wyvern Sting
    19503, -- Scatter Shot
    24394, -- Intimidation
    34490, -- Silencing Shot
    50245, -- Pin
    50519, -- Sonic Blast
    50541, -- Snatch
    54706, -- Venom Web Spray
    56626, -- Sting
    60210, -- Freezing Arrow Effect
    64803, -- Entrapment
    
    -- Mage
    118, -- Polymorph (Sheep)
    122, -- Frost Nova
    18469, -- Silenced - Improved Counterspell (Rank 1)
    31589, -- Slow
    31661, -- Dragon's Breath
    33395, -- Freeze
    44572, -- Deep Freeze
    55080, -- Shattered Barrier
    61305, -- Polymorph (Black Cat)
    55021, -- Silenced - Improved Counterspell (Rank 2)
    
    -- Paladin
    853, -- Hammer of Justice
    10326, -- Turn Evil
    20066, -- Repentance
    31935, -- Avenger's Shield
    
    -- Priest
    605, -- Mind Control
    8122, -- Psychic Scream
    9484, -- Shackle Undead
    15487, -- Silence
    64044, -- Psychic Horror
    
    -- Rogue
    408, -- Kidney Shot
    1330, -- Garrote - Silence
    1776, -- Gouge
    1833, -- Cheap Shot
    2094, -- Blind
    6770, -- Sap
    18425, -- Silenced - Improved Kick
    51722, -- Dismantle
    
    -- Shaman
    3600, -- Earthbind
    8056, -- Frost Shock
    39796, -- Stoneclaw Stun
    51514, -- Hex
    63685, -- Freeze
    64695, -- Earthgrab
    
    -- Warlock
    710, -- Banish
    5782, -- Fear
    6358, -- Seduction
    6789, -- Death Coil
    17928, -- Howl of Terror
    24259, -- Spell Lock
    30283, -- Shadowfury
    
    -- Warrior
    676, -- Disarm
    7922, -- Charge Stun
    18498, -- Silenced - Gag Order
    20511, -- Intimidating Shout
    
    -- Racial
    25046, -- Arcane Torrent
    20549, -- War Stomp
    
    -- The Lich King (Boss)
    73787, -- Necrotic Plague
}

function I.GetDefaultBigDebuffs()
    return bigDebuffs
end

-------------------------------------------------
-- aoeHealings
-------------------------------------------------
local aoeHealings = {
    ["DRUID"] = {
        [740] = true, -- 宁静
    },
    ["PRIEST"] = {
        [596]  = true, -- 治疗祷言
        [64843] = true, -- 神圣赞美诗
        [34866] = true, -- 治疗之环
    },
    ["SHAMAN"] = {
        [1064] = true, -- 治疗链
    },
}

function I.GetAoEHealings()
    return aoeHealings
end

local builtInAoEHealings = {}
local customAoEHealings = {}

function I.UpdateAoEHealings(t)
    -- user disabled
    wipe(builtInAoEHealings)
    for class, spells in pairs(aoeHealings) do
        for id, trackByName in pairs(spells) do
            if not t["disabled"][id] then -- not disabled
                if trackByName then
                    local name = F.GetSpellInfo(id)
                    if name then
                        builtInAoEHealings[name] = true
                    end
                else
                    builtInAoEHealings[id] = true
                end
            end
        end
    end

    -- user created
    wipe(customAoEHealings)
    for _, id in pairs(t["custom"]) do
        customAoEHealings[id] = true
    end
end

function I.IsAoEHealing(name, id)
    return builtInAoEHealings[name] or builtInAoEHealings[id] or customAoEHealings[id]
end

local summonDuration = {}

do
    local temp = {}
    for id, duration in pairs(summonDuration) do
        temp[F.GetSpellInfo(id)] = duration
    end
    summonDuration = temp
end

function I.GetSummonDuration(spellName)
    return summonDuration[spellName]
end

-------------------------------------------------
-- externalCooldowns
-------------------------------------------------
local externals = { -- true: track by name, false: track by id
    ["DEATHKNIGHT"] = {
        [51052] = true, -- 反魔法领域
    },

    ["PALADIN"] = {
        [1022] = true, -- 保护祝福
        [6940] = true, -- 牺牲祝福
        [64205] = true, -- 神圣牺牲
        [70940] = true, -- 神圣护卫者
        [19752] = true, -- 神圣干涉
        [31821] = true, -- 光环掌握
        [20236] = true, -- 强化圣疗术（天赋）
    },

    ["PRIEST"] = {
        [33206] = true, -- 痛苦压制
        [47788] = true, -- 守护之魂
    },

    ["WARRIOR"] = {
        [3411] = true, -- 援护
    },
}

function I.GetExternals()
    return externals
end

local builtInExternals = {}
local customExternals = {}

function I.UpdateExternals(t)
       -- user disabled
    wipe(builtInExternals)
    for class, spells in pairs(externals) do
        for id, trackByName in pairs(spells) do
            if not t["disabled"][id] then -- not disabled
                if trackByName then
                    local name = F.GetSpellInfo(id)
                    if name then
                        builtInExternals[name] = true
                    end
                else
                    builtInExternals[id] = true
                end
            end
        end
    end

    -- user created
    wipe(customExternals)
    for _, id in pairs(t["custom"]) do
        -- local name = F.GetSpellInfo(id)
        -- if name then
        --     customExternals[name] = true
        -- end
        customExternals[id] = true
    end
end

function I.IsExternalCooldown(name, id, source, target)
    return builtInExternals[name] or builtInExternals[id] or customExternals[id]
end

-------------------------------------------------
-- defensiveCooldowns
-------------------------------------------------
local defensives = { -- true: track by name, false: track by id
    ["DEATHKNIGHT"] = {
        [48707] = true, -- 反魔法护罩
        [48792] = true, -- 冰封之韧
        [55233] = true, -- 吸血鬼之血
    },

    ["DRUID"] = {
        [22812] = true, -- 树皮术
        [22842] = true, -- 狂暴回复
        [61336] = true, -- 生存本能
    },

    ["HUNTER"] = {
        [19263] = true, -- 威慑
    },

    ["MAGE"] = {
        [45438] = true, -- 寒冰屏障
    },

    ["PALADIN"] = {
        [498] = true, -- 圣佑术
        [642] = true, -- 圣盾术
    },

    ["PRIEST"] = {
        [47585] = true, -- 消散
        [27827] = true, -- 救赎之魂
    },

    ["ROGUE"] = {
        [1966] = true, -- 佯攻
        [5277] = true, -- 闪避
        [31224] = true, -- 暗影斗篷
    },

    ["SHAMAN"] = {
        [30823] = true, -- 萨满之怒
    },

    ["WARRIOR"] = {
        [871] = true, -- 盾墙
        [12975] = true, -- 破釜沉舟
        [23920] = true, -- 法术反射
        [55694] = true, -- 狂怒回复
    },
}

function I.GetDefensives()
    return defensives
end

local builtInDefensives = {}
local customDefensives = {}

function I.UpdateDefensives(t)
    -- user disabled
    wipe(builtInDefensives)
    for class, spells in pairs(defensives) do
        for id, trackByName in pairs(spells) do
            if not t["disabled"][id] then -- not disabled
                if trackByName then
                    local name = F.GetSpellInfo(id)
                    if name then
                        builtInDefensives[name] = true
                    end
                else
                    builtInDefensives[id] = true
                end
            end
        end
    end

    -- user created
    wipe(customDefensives)
    for _, id in pairs(t["custom"]) do
        -- local name = F.GetSpellInfo(id)
        -- if name then
        --     customDefensives[name] = true
        -- end
        customDefensives[id] = true
    end
end

local defensiveBlacklist = {
    [67378] = true,
    [67354] = true,
    [67380] = true,
}

function I.IsDefensiveCooldown(name, id)
    if defensiveBlacklist[id] then return end
    return builtInDefensives[name] or builtInDefensives[id] or customDefensives[id]
end

-------------------------------------------------
-- dispels
-------------------------------------------------
local dispellable = {
    -- DRUID ----------------
    [11] = {["Curse"] = true, ["Poison"] = true},

    -- MAGE -----------------
    [8] = {["Curse"] = true},

    -- PALADIN --------------
    [2] = {["Disease"] = true, ["Magic"] = true, ["Poison"] = true},

    -- PRIEST ---------------
    -- NOTE: 全心全意天赋可以解自己的毒
    [5] = {["Disease"] = true, ["Magic"] = true},

    -- SHAMAN ---------------
    [7] = {["Disease"] = true, ["Poison"] = true},
}

function I.CanDispel(dispelType)
    if not dispelType then return end

    local classID = Cell.vars.playerClassID
    if not classID then
        local _, _, cid = UnitClass("player")
        classID = cid
        Cell.vars.playerClassID = cid
    end

    if dispellable[classID] then
        if classID == 7 then -- 萨满
            -- NOTE: 净化灵魂天赋可以解除诅咒
            dispellable[classID]["Curse"] = IsSpellKnown(51886)
        end
        return dispellable[classID][dispelType]
    else
        return
    end
end

-------------------------------------------------
-- drinking
-------------------------------------------------
local drinks = {
    430, -- 喝水
    43182, -- 饮水
}

do
    local temp = {}
    for _, id in pairs(drinks) do
        temp[F.GetSpellInfo(id)] = true
    end
    drinks = temp
end

function I.IsDrinking(name)
    return drinks[name]
end

-------------------------------------------------
-- healer
-------------------------------------------------
local spells =  {
    -- druid
    774, -- 回春术
    8936, -- 愈合
    33763, -- 生命绽放
    48438, -- 野性成长
    50464, -- 滋养
    -- paladin
    53563, -- 圣光道标
    53601, -- 圣洁护盾
    -- priest
    139, -- 恢复
    41635, -- 愈合祷言
    17, -- 真言术：盾
    28276, -- 光明之泉恢复
    -- shaman
    974, -- 大地之盾
    61295, -- 激流
}

function F.FirstRun()
    local icons = "\n\n"
    for i, id in pairs(spells) do
        local icon = select(2, F.GetSpellInfo(id))
        icons = icons .. "|T"..icon..":0|t"
        if i % 11 == 0 then
            icons = icons .. "\n"
        end
    end

    local popup = Cell.CreateConfirmPopup(Cell.frames.anchorFrame, 200, L["Would you like Cell to create a \"Healers\" indicator (icons)?"]..icons, function(self)
        local currentLayoutTable = Cell.vars.currentLayoutTable

        local last = #currentLayoutTable["indicators"]
        if currentLayoutTable["indicators"][last]["type"] == "built-in" then
            indicatorName = "indicator1"
        else
            indicatorName = "indicator"..(tonumber(strmatch(currentLayoutTable["indicators"][last]["indicatorName"], "%d+"))+1)
        end

        tinsert(currentLayoutTable["indicators"], {
            ["name"] = "Healers",
            ["indicatorName"] = indicatorName,
            ["type"] = "icons",
            ["enabled"] = true,
            ["position"] = {"TOPRIGHT", "button", "TOPRIGHT", 0, 3},
            ["frameLevel"] = 5,
            ["size"] = {13, 13},
            ["num"] = 5,
            ["numPerLine"] = 5,
            ["orientation"] = "right-to-left",
            ["spacing"] = {0, 0},
            ["font"] = {
                {"Cell ".._G.DEFAULT, 11, "Outline", false, "TOPRIGHT", 2, 1, {1, 1, 1}},
                {"Cell ".._G.DEFAULT, 11, "Outline", false, "BOTTOMRIGHT", 2, -1, {1, 1, 1}},
            },
            ["showStack"] = true,
            ["showDuration"] = false,
            ["showAnimation"] = true,
            ["glowOptions"] = {"None", {0.95, 0.95, 0.32, 1}},
            ["auraType"] = "buff",
            ["castBy"] = "me",
            ["trackByName"] = true,
            ["auras"] = spells,
        })
        Cell.Fire("UpdateIndicators", Cell.vars.currentLayout, indicatorName, "create", currentLayoutTable["indicators"][last+1])
        CellDB["firstRun"] = false
        F.ReloadIndicatorList()
    end, function()
        CellDB["firstRun"] = false
    end)
    popup:SetPoint("TOPLEFT")
    popup:Show()
end

-------------------------------------------------
-- targetedSpells
-------------------------------------------------
local targetedSpells = {

}

function I.GetDefaultTargetedSpellsList()
    return targetedSpells
end

function I.GetDefaultTargetedSpellsGlow()
    return {"Pixel", {0.95,0.95,0.32,1}, 9, 0.25, 8, 2}
end

-------------------------------------------------
-- Actions: Healing Potion & Healthstone
-------------------------------------------------
local actions = {

}


function I.GetDefaultActions()
    return actions
end

function I.ConvertActions(db)
    local temp = {}
    for _, t in pairs(db) do
        temp[t[1]] = t[2]
    end
    return temp
end

-------------------------------------------------
-- crowdControls
-------------------------------------------------
local crowdControls = { -- true: track by name, false: track by id
    ["DEATHKNIGHT"] = {
        [47476] = true, -- Strangulate
        [51209] = true, -- Hungering Cold
    },

    ["DRUID"] = {
        [99] = true, -- Demoralizing Roar
        [339] = true, -- Entangling Roots
        [2637] = true, -- Hibernate
        [5211] = true, -- Bash
        [9005] = true, -- Pounce
        [22570] = true, -- Maim
        [33786] = true, -- Cyclone
        [45334] = true, -- Feral Charge Effect
    },

    ["HUNTER"] = {
        [1513] = true, -- Scare Beast
        [3355] = true, -- Freezing Trap Effect
        [19386] = true, -- Wyvern Sting
        [19503] = true, -- Scatter Shot
        [24394] = true, -- Intimidation
        [34490] = true, -- Silencing Shot
    },

    ["MAGE"] = {
        [118] = true, -- Polymorph
        [122] = true, -- Frost Nova
        [18469] = true, -- Silenced - Improved Counterspell
        [31589] = true, -- Slow
        [31661] = true, -- Dragon's Breath
        [33395] = true, -- Freeze
        [44572] = true, -- Deep Freeze
    },

    ["PALADIN"] = {
        [853] = true, -- Hammer of Justice
        [10326] = true, -- Turn Evil
        [20066] = true, -- Repentance
        [31935] = true, -- Avenger's Shield
    },

    ["PRIEST"] = {
        [605] = true, -- Mind Control
        [8122] = true, -- Psychic Scream
        [9484] = true, -- Shackle Undead
        [15487] = true, -- Silence
        [64044] = true, -- Psychic Horror
    },

    ["ROGUE"] = {
        [408] = true, -- Kidney Shot
        [1330] = true, -- Garrote - Silence
        [1776] = true, -- Gouge
        [1833] = true, -- Cheap Shot
        [2094] = true, -- Blind
        [6770] = true, -- Sap
        [18425] = true, -- Silenced - Improved Kick
        [51722] = true, -- Dismantle
    },

    ["SHAMAN"] = {
        [3600] = true, -- Earthbind
        [8056] = true, -- Frost Shock
        [51514] = true, -- Hex
        [63685] = true, -- Freeze
        [64695] = true, -- Earthgrab
    },

    ["WARLOCK"] = {
        [710] = true, -- Banish
        [5782] = true, -- Fear
        [6358] = true, -- Seduction
        [6789] = true, -- Death Coil
        [17928] = true, -- Howl of Terror
        [24259] = true, -- Spell Lock
        [30283] = true, -- Shadowfury
    },

    ["WARRIOR"] = {
        [676] = true, -- Disarm
        [7922] = true, -- Charge Stun
        [18498] = true, -- Silenced - Gag Order
        [20511] = true, -- Intimidating Shout
    },

    ["UNCATEGORIZED"] = {
        [25046] = true, -- Arcane Torrent
        [20549] = true, -- War Stomp
    },
}

function I.GetCrowdControls()
    return crowdControls
end

local builtInCrowdControls = {}
local customCrowdControls = {}

function I.UpdateCrowdControls(t)
    -- user disabled
    wipe(builtInCrowdControls)
    for class, spells in pairs(crowdControls) do
        for id, trackByName in pairs(spells) do
            if not t["disabled"][id] then -- not disabled
                if trackByName then
                    local name = F.GetSpellInfo(id)
                    if name then
                        builtInCrowdControls[name] = true
                    end
                else
                    builtInCrowdControls[id] = true
                end
            end
        end
    end

    -- user created
    wipe(customCrowdControls)
    for _, id in pairs(t["custom"]) do
        local name = F.GetSpellInfo(id)
        if name then
            customCrowdControls[name] = true
        end
    end
end

function I.IsCrowdControls(name, id)
    return builtInCrowdControls[name] or builtInCrowdControls[id] or customCrowdControls[name]
end
