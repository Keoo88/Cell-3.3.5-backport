local _, Cell = ...
--! WotLK feature: predictive AoE-cluster counter. Ported from RaidCluster
--! (https://github.com/NoM0Re/RaidCluster) with permission of its license terms
--! (CC BY-NC-SA 4.0 - attribution above, no code copied verbatim).
--!
--! Every other Cell indicator reacts to something that already happened: a heal
--! landed, an aura was applied, threat changed. This one answers a question that
--! only matters BEFORE the cast - "if I drop Wild Growth / Circle of Healing /
--! Chain Heal on this unit, how many allies does it reach?" - so it cannot use
--! the combat log at all. The answer comes from world-map coordinates, which on
--! 3.3.5a are readable for the whole raid at any time via
--! GetPlayerMapPosition(unit).

--! WotLK fix: bind Cell timers privately so a standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs

--! WotLK perf: everything below runs on a timer with the whole raid in scope, so
--! the API surface is bound to locals once instead of being resolved out of the
--! global table on every unit of every tick.
local UnitExists, UnitIsConnected, UnitIsVisible = UnitExists, UnitIsConnected, UnitIsVisible
local UnitIsDeadOrGhost, UnitHealth, UnitHealthMax = UnitIsDeadOrGhost, UnitHealth, UnitHealthMax
local GetPlayerMapPosition, GetMapInfo = GetPlayerMapPosition, GetMapInfo
local GetCurrentMapDungeonLevel = GetCurrentMapDungeonLevel
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local wipe = wipe

-------------------------------------------------
-- map sizes
-------------------------------------------------
--! GetPlayerMapPosition returns a fraction of the displayed map (0..1), so a
--! distance in yards needs the map's real size. Blizzard does not expose it -
--! addons carry a generated table instead (LibMapData-1.0 and friends). Only the
--! width/height of the WotLK dataset is kept here: 211 maps, ~9 KB of literals,
--! versus a 153 KB bundled library whose callbacks, floor discovery and Cata
--! dataset this indicator never touches.
--!
--! Key is the GetMapInfo() map FILE name - a texture folder name, identical in
--! every locale (the same reason Core_Wrath.lua keys BATTLEGROUND_SIZE by it).
--! Value is a flat per-floor list {w1, h1, w2, h2, ...}; floor N is at
--! [N*2-1], [N*2] and anything past the last floor falls back to floor 1, which
--! reproduces LibMapData's MapArea() exactly. Cell never calls
--! SetMapToCurrentZone: FrameXML already restores the current zone itself
--! (WorldMapFrame_OnHide, WatchFrame on PLAYER_ENTERING_WORLD), and mutating
--! global map state would break other addons reading it.
local MAP_YARDS = {
    AhnQiraj = {2777.5, 1851.7, 977.6, 651.7, 577.6, 385},
    Ahnkahet = {972.4, 648.3},
    Alterac = {2800, 1866.7},
    AlteracValley = {4237.5, 2825},
    AmaniCatacombs1_ = {300, 200},
    AmmenValeStart = {1818.8, 1212.5},
    Arathi = {3600, 2400},
    ArathiBasin = {1756.2, 1170.8},
    Ashenvale = {5766.7, 3843.7},
    Aszhara = {5070.8, 3381.2},
    AuchenaiCrypts = {742.5, 495, 817.5, 545},
    Azeroth = {40741.2, 27149.7},
    AzjolNerub = {753, 502, 293, 195.3, 367.5, 245},
    AzuremystIsle = {4070.8, 2714.6},
    Badlands = {2487.5, 1658.3},
    BanethilBarrowden4_ = {230, 153.3},
    BanethilBarrowden5_ = {380, 253.3},
    Barrens = {10133.3, 6756.2},
    BlackTemple = {783.3, 522.9, 1252.2, 834.8, 975, 650, 1005, 670, 440, 293.3, 670, 446.7, 705, 470, 355, 236.7},
    BlackfathomDeeps = {884.2, 589.5, 884.2, 589.5, 284.2, 189.5},
    BlackrockDepths = {1407.1, 938, 1507.1, 1004.7},
    BlackrockMountain14_ = {712.5, 475},
    BlackrockMountain15_ = {255, 170},
    BlackrockMountain16_ = {760, 506.7},
    BlackrockSpire = {886.8, 591.2, 886.8, 591.2, 886.8, 591.2, 886.8, 591.2, 886.8, 591.2, 886.8, 591.2, 886.8, 591.2},
    BlackwingLair = {499.4, 332.9, 649.4, 432.9, 649.4, 432.9, 649.4, 432.9},
    BladesEdgeMountains = {5425, 3616.7},
    BlastedLands = {3350, 2233.3},
    BloodmystIsle = {3262.5, 2175},
    BoreanTundra = {5764.6, 3843.7},
    BurningBladeCoven8_ = {266, 177.3},
    BurningSteppes = {2929.2, 1952.1},
    CampNaracheStart = {1766.7, 1177.1},
    CavernsofTime17_ = {1107.5, 738.3},
    CavernsofTime18_ = {1306, 870.7},
    CoTHillsbradFoothills = {2331.2, 1554.2},
    CoTMountHyjal = {2500, 1666.7},
    CoTStratholme = {1825, 1216.7, 1125.3, 750.2},
    CoTTheBlackMorass = {1087.5, 725},
    CoilfangReservoir = {1575, 1050},
    ColdridgePass6_ = {330, 220},
    ColdridgeValley = {964.6, 643.8},
    CrystalsongForest = {2722.9, 1814.6},
    Dalaran = {830, 553.3, 563.2, 375.5},
    Darkshore = {6550, 4366.7},
    Darnassis = {1058.3, 705.7},
    DeadminesWestfall17_ = {450, 300},
    DeadwindPass = {2500, 1666.7},
    DeathknellStart = {1089.6, 727.1},
    DeeprunTram = {312, 208, 309, 208},
    Desolace = {4495.8, 2997.9},
    DireMaul = {1275, 850, 525, 350, 487.5, 325, 750, 500, 800, 533.3, 975, 650},
    Dragonblight = {5608.3, 3739.6},
    DrakTharonKeep = {619.9, 413.3, 619.9, 413.3},
    DunMorogh = {4925, 3283.3},
    Durotar = {5287.5, 3525},
    Duskwood = {2700, 1800},
    Dustwallow = {5250, 3500},
    DustwindCave19_ = {258, 172},
    EasternPlaguelands = {4031.2, 2687.5},
    EchoRidgeMine3_ = {279, 186},
    Elwynn = {3470.8, 2314.6},
    EversongWoods = {4925, 3283.3},
    Expansion01 = {17464.1, 11642.7},
    Fargodeepmine1_ = {240, 160},
    Fargodeepmine2_ = {255, 170},
    FelRock3_ = {279.6, 186.4},
    Felwood = {5750, 3833.3},
    Feralas = {6950, 4633.3},
    FrostmaneHold8_ = {341.9, 234.4},
    FrostmaneHovel9_ = {266.5, 177.7},
    GMIsland = {828, 541},
    Ghostlands = {3300, 2200},
    Gnomeregan = {769.7, 513.1, 769.7, 513.1, 869.7, 579.8, 869.7, 579.8},
    GnomereganEntrance10_ = {730.5, 467.2},
    GolBolarQuarry11_ = {374, 249.3},
    GoldCoastQuarry4_ = {262.5, 175},
    GrizzlyHills = {5250, 3500},
    GruulsLair = {525, 350},
    Gundrak = {905, 603.4},
    HallsofLightning = {566.2, 377.5, 708.2, 472.2},
    HallsofReflection = {879, 586},
    Hellfire = {5164.6, 3443.7},
    HellfireRamparts = {694.6, 463},
    Hilsbrad = {3200, 2133.3},
    Hinterlands = {3850, 2566.7},
    HowlingFjord = {6045.8, 4031.2},
    HrothgarsLanding = {3677.1, 2452.1},
    Hyjal = {3195.9, 2129.1},
    IcecrownCitadel = {1355.5, 903.6, 1067, 711.3, 195.5, 130.3, 773.7, 515.8, 1148.7, 765.8, 373.7, 249.1, 293.3, 195.5, 247.9, 165.3},
    IcecrownGlacier = {6270.8, 4181.2},
    Ironforge = {790.6, 527.6},
    IsleofConquest = {2650, 1766.7},
    JangolodeMine5_ = {277, 184.7},
    JasperlodeMine19_ = {323.2, 215.5},
    Kalimdor = {36799.8, 24533.2},
    Karazhan = {550, 366.7, 257.9, 171.9, 345.1, 230.1, 520, 346.7, 234.1, 156.1, 581.5, 387.7, 191.5, 127.7, 139.4, 92.9, 760, 506.7, 450.2, 300.2, 271.1, 180.7, 595, 396.7, 529, 352.7, 245.2, 163.5, 211.1, 140.8, 101.2, 67.5, 341.2, 227.5},
    LakeWintergrasp = {2975, 1983.3},
    LochModan = {2758.3, 1839.6},
    MagistersTerrace = {530.3, 353.6, 530.3, 353.6},
    MagtheridonsLair = {556, 370.7},
    ManaTombs = {823.3, 548.9},
    Maraudon = {975, 650, 1637.5, 1091.7},
    MaraudonOutside21_ = {600, 400},
    MaraudonOutside22_ = {560, 373.3},
    MoltenCore = {1264.8, 843.2},
    Moonglade = {2308.3, 1539.6},
    Mulgore = {5137.5, 3425},
    Nagrand = {5525, 3683.3},
    Naxxramas = {1093.8, 729.2, 1093.8, 729.2, 1200, 800, 1200.3, 800.2, 2069.8, 1379.9, 655.9, 437.3},
    Netherstorm = {5575, 3716.7},
    NetherstormArena = {2270.8, 1514.6},
    Nexus80 = {514.7, 343.1, 664.7, 443.1, 514.7, 343.1, 294.7, 196.5},
    NightWebsHollow12_ = {220, 146.7},
    Northrend = {17751.4, 11834.3},
    Northshire = {968.8, 645.8},
    Ogrimmar = {1402.6, 935.4},
    Ogrimmar1_ = {362.1, 241.4},
    OnyxiasLair = {483.1, 322.1},
    PalemaneRock6_ = {350, 233.3},
    PitofSaron = {1533.3, 1022.9},
    Ragefire = {738.9, 492.6},
    RazorfenDowns = {709, 472.7},
    RazorfenKraul = {736.4, 491},
    Redridge = {2170.8, 1447.9},
    RuinsofAhnQiraj = {2512.5, 1675},
    ScarletEnclave = {3162.5, 2108.3},
    ScarletMonastery = {620, 413.3, 320.2, 213.5, 612.7, 408.5, 703.3, 468.9},
    ScarletMonasteryEntrance13_ = {205, 136.7},
    Scholomance = {320, 213.4, 440, 293.4, 410.1, 273.4, 531, 354},
    SearingGorge = {2231.2, 1487.5},
    SethekkHalls = {703.5, 469, 703.5, 469},
    ShadowLabyrinth = {841.5, 561},
    ShadowfangKeep = {352.4, 235, 212.4, 141.6, 152.4, 101.6, 152.4, 101.6, 152.4, 101.6, 198.4, 132.3, 272.4, 181.6},
    ShadowglenStart = {1450, 966.7},
    ShadowmoonValley = {5500, 3666.7},
    ShadowthreadCave2_ = {480, 320},
    ShattrathCity = {1306.2, 870.8},
    SholazarBasin = {4356.2, 2904.2},
    Silithus = {3483.3, 2322.9},
    SilvermoonCity = {1211.5, 806.8},
    Silverpine = {4200, 2800},
    SkullRock12_ = {270, 180},
    StillpineHold3_ = {475, 316.7},
    StonetalonMountains = {4883.3, 3256.2},
    Stormwind = {1737.5, 1158.3},
    StrandoftheAncients = {1743.7, 1162.5},
    Stranglethorn = {6381.2, 4254.2},
    Stratholme = {705.7, 470.5, 1005.7, 670.5},
    SunstriderIsleStart = {1600, 1066.7},
    Sunwell = {3327.1, 2218.7},
    SunwellPlateau = {906.2, 604.2, 465, 310},
    SwampOfSorrows = {2293.8, 1529.2},
    Tanaris = {6900, 4600},
    Teldrassil = {5091.7, 3393.8},
    TempestKeep = {1575, 1050},
    TerokkarForest = {5400, 3600},
    TheArcatraz = {689.7, 459.8, 546, 364, 636.7, 424.5},
    TheArgentColiseum = {370, 246.7, 740, 493.3},
    TheBloodFurnace = {1003.5, 669},
    TheBotanica = {757.4, 504.9},
    TheDeadmines = {559.3, 372.8, 499.3, 332.8},
    TheExodar = {1056.8, 704.7},
    TheEyeofEternity = {430.1, 286.7},
    TheForgeofSouls = {1448.1, 965.4},
    TheGapingChasm16_ = {885, 590},
    TheGrizzledDen7_ = {505.5, 337},
    TheMechanar = {676.2, 450.8, 676.2, 450.8},
    TheNexus = {1101.3, 734.2},
    TheNoxiousLair15_ = {750, 500},
    TheObsidianSanctum = {1162.5, 775},
    TheRubySanctum = {752.1, 502.1},
    TheShatteredHalls = {1063.7, 709.2},
    TheSlavePens = {890.1, 593.4},
    TheSlitheringScar14_ = {382.5, 255},
    TheSteamvault = {876.8, 584.5, 876.8, 584.5},
    TheStockade = {378.2, 252.1},
    TheStormPeaks = {7112.5, 4741.7},
    TheTempleOfAtalHakkar = {695, 463.4, 248.2, 166, 556.2, 370.4},
    TheUnderbog = {894.9, 596.6},
    TheVentureCoMine7_ = {741, 494},
    ThousandNeedles = {4400, 2933.3},
    ThunderBluff = {1043.7, 695.8},
    TidesHollow2_ = {375, 250},
    TiragardeKeep10_ = {125, 83.3},
    TiragardeKeep11_ = {125, 83.3},
    Tirisfal = {4518.7, 3012.5},
    TwilightsRun13_ = {252.5, 168.3},
    Uldaman = {893.7, 595.8, 492.6, 328.4},
    Uldaman18_ = {562.5, 375},
    Ulduar = {3287.5, 2191.7, 669.5, 446.3, 1328.5, 885.6, 910.5, 607, 1569.5, 1046.3, 619.5, 413},
    Ulduar77 = {920.2, 613.5},
    Undercity = {959.4, 640.1},
    UngoroCrater = {3700, 2466.7},
    UtgardeKeep = {734.6, 489.7, 481.1, 320.7, 736.6, 491.1},
    UtgardePinnacle = {548.9, 366, 756.2, 504.1},
    ValleyofTrialsStart = {1350, 900},
    VaultofArchavon = {1398.3, 932.2},
    VioletHold = {256.2, 170.8},
    WailingCaverns = {936.5, 624.3},
    WailingCavernsBarrens20_ = {570, 380},
    WarsongGulch = {1145.8, 764.6},
    WesternPlaguelands = {4300, 2866.7},
    Westfall = {3500, 2333.3},
    Wetlands = {4135.4, 2756.2},
    Winterspring = {7100, 4733.3},
    Zangarmarsh = {5027.1, 3352.1},
    ZulAman = {1268.7, 845.8},
    ZulDrak = {4993.8, 3329.2},
    ZulFarrak = {1383.3, 922.9},
    ZulGurub = {2120.8, 1414.6},
}

-------------------------------------------------
-- class presets
-------------------------------------------------
--! Radius and counting rule of the spell each healing class drops on a cluster.
--! "players" - every ally in range, the unit itself not counted (Wild Growth,
--!             Circle of Healing, Glyph of Holy Light).
--! "group"   - only allies in the unit's own party, the unit counted (Prayer of
--!             Healing always heals the target's own party, target included).
--! "chained" - allies reachable in up to two jumps (Chain Heal).
local CLASS_PRESET = {
    PALADIN = {9.5, "players"},
    SHAMAN = {12.5, "chained"},
    DRUID = {16.5, "players"},
}
local PRIEST_DISCIPLINE = {30, "group"}
local PRIEST_HOLY = {16.5, "players"}
--! A class with no group heal still gets a useful "how many are stacked here"
--! reading; 15 yd is the radius most raid mechanics are designed around.
local FALLBACK = {15, "players"}

local INTERVAL = 0.5

-------------------------------------------------
-- state
-------------------------------------------------
local dbRadius = 0 -- 0 = derive from class and spec
local lowHealthOnly = false
local mode = "players"
local radiusSq = 225
local presetPending = true
local mapX, mapY = 0, 0
local unitCount = 0

local units, subgroup, px, py = {}, {}, {}, {}
local weight = {}
local adj, adjN = {}, {}
local cnt, counts = {}, {}
local mark, stamp = {}, 0

--! WotLK perf: unit tokens built once. Concatenating "raid"..i for 40 units twice
--! a second is 80 string interns per second for no reason.
local RAID_UNIT, PARTY_UNIT = {}, {}
for i = 1, 40 do RAID_UNIT[i] = "raid"..i end
for i = 1, 4 do PARTY_UNIT[i] = "party"..i end

-------------------------------------------------
-- radius and mode
-------------------------------------------------
local function ResolvePreset()
    local class = Cell.vars.playerClass
    if class == "PRIEST" then
        --! Discipline casts Prayer of Healing (own party, 30 yd), Holy casts
        --! Circle of Healing (any ally, 16.5 yd) - the split needs the tree, not
        --! just the class. Right after login the talent trees are not readable
        --! yet and this returns nil; the caller keeps re-asking until it is not.
        local tab = F.GetDominantTalentTab()
        if not tab then return nil end
        return tab == 1 and PRIEST_DISCIPLINE or PRIEST_HOLY
    end
    return CLASS_PRESET[class] or FALLBACK
end

local function ApplyPreset()
    local preset = ResolvePreset()
    presetPending = not preset
    preset = preset or FALLBACK
    mode = preset[2]
    --! A hand-set radius overrides the distance but never the counting rule:
    --! Prayer of Healing still only reaches the target's own party, whatever
    --! number the player types in.
    local radius = (dbRadius > 0) and dbRadius or preset[1]
    radiusSq = radius * radius
end

-------------------------------------------------
-- map scale
-------------------------------------------------
--! Resolved on every tick instead of on zone events: it is two API calls and one
--! table lookup, while ZONE_CHANGED_NEW_AREA gives no guarantee that FrameXML has
--! already pointed the world map at the new zone by the time Cell sees the event.
local function RefreshMapScale()
    local map = GetMapInfo()
    local t = map and MAP_YARDS[map]
    if not t then
        mapX, mapY = 0, 0
        return false
    end

    local w, h
    local level = GetCurrentMapDungeonLevel()
    if level and level > 0 then
        w, h = t[level * 2 - 1], t[level * 2]
    end
    if not w or w <= 1 then
        w, h = t[1], t[2]
    end
    if not w or not h or w <= 1 or h <= 1 then
        mapX, mapY = 0, 0
        return false
    end

    mapX, mapY = w, h
    return true
end

-------------------------------------------------
-- roster
-------------------------------------------------
local function AddUnit(unit, group)
    if not UnitExists(unit) or not UnitIsConnected(unit) or not UnitIsVisible(unit)
        or UnitIsDeadOrGhost(unit) then
        return
    end
    local x, y = GetPlayerMapPosition(unit)
    --! 0,0 means "not on the displayed map": another instance, another zone, or
    --! the player is browsing the world map somewhere else. Such a unit is
    --! dropped instead of being placed at the map's top-left corner.
    if not x or not y or (x == 0 and y == 0) then return end

    local n = unitCount + 1
    unitCount = n
    units[n] = unit
    subgroup[n] = group
    --! WotLK feature: "count only wounded allies" filters WHO IS COUNTED, not who
    --! stands on the map. An ally at full health is dropped from the sum but kept in
    --! the roster, because the healer still aims at them: a tank at full health in
    --! the middle of a wounded melee pile must show the number of those wounded, and
    --! a healthy ally must still block nothing and pass a chain jump along. Weight is
    --! 1 or 0 so the pair loop stays branch-free.
    weight[n] = (not lowHealthOnly or UnitHealth(unit) < UnitHealthMax(unit)) and 1 or 0
    --! WotLK perf: converted to yards once here, so the pair loop below is pure
    --! arithmetic on plain numbers.
    px[n] = x * mapX
    py[n] = y * mapY
end

local function CollectRoster()
    unitCount = 0

    local num = GetNumRaidMembers()
    if num > 0 then
        if num > 40 then num = 40 end
        for i = 1, num do
            local _, _, group = GetRaidRosterInfo(i)
            AddUnit(RAID_UNIT[i], group or 1)
        end
    else
        --! Outside a raid everybody shares one party, so the subgroup filter is
        --! a constant and "group" mode degenerates into "everyone in range".
        AddUnit("player", 1)
        num = GetNumPartyMembers()
        if num > 4 then num = 4 end
        for i = 1, num do
            AddUnit(PARTY_UNIT[i], 1)
        end
    end
end

-------------------------------------------------
-- counting
-------------------------------------------------
--! Done whole in one tick rather than sliced across frames the way RaidCluster
--! does it. Forty units are 780 unordered pairs, and each pair here costs two
--! subtractions, two multiplications and one comparison - there is no square
--! root, because comparing squared distances answers the same question, and no
--! pair is visited twice, because a hit credits both of its units. A chunked
--! worker would cost more in bookkeeping than the work it defers.
local function ComputeCounts()
    local n = unitCount
    local isGroup = mode == "group"
    local isChained = mode == "chained"

    for i = 1, n do
        --! Prayer of Healing heals the target too, so its own frame starts at 1 -
        --! unless the target itself is at full health and the filter is on.
        cnt[i] = isGroup and weight[i] or 0
        if isChained then
            if not adj[i] then adj[i] = {} end
            adjN[i] = 0
        end
    end

    local rSq = radiusSq
    for i = 1, n - 1 do
        local xi, yi, gi = px[i], py[i], subgroup[i]
        for j = i + 1, n do
            local dx, dy = px[j] - xi, py[j] - yi
            if dx * dx + dy * dy <= rSq then
                if isChained then
                    local a = adj[i]
                    local k = adjN[i] + 1
                    a[k] = j
                    adjN[i] = k
                    a = adj[j]
                    k = adjN[j] + 1
                    a[k] = i
                    adjN[j] = k
                elseif not isGroup then
                    cnt[i] = cnt[i] + weight[j]
                    cnt[j] = cnt[j] + weight[i]
                elseif subgroup[j] == gi then
                    cnt[i] = cnt[i] + weight[j]
                    cnt[j] = cnt[j] + weight[i]
                end
            end
        end
    end

    if not isChained then return end

    --! Chain Heal jumps from the target to a neighbour and from there to a third
    --! unit, so what matters is the two-hop reach. Visited units are stamped with
    --! a per-source number instead of being wiped out of a scratch table, and the
    --! walk stops as soon as everyone else is already reachable - which is what
    --! keeps a fully stacked 40-man from turning this into 64000 iterations.
    --! Two counters, not one: "visited" bounds the walk (a healthy ally is still a
    --! stepping stone for the jump), while "c" is what the player sees.
    local limit = n - 1
    for i = 1, n do
        stamp = stamp + 1
        mark[i] = stamp
        local c, visited = 0, 0
        local ai, an = adj[i], adjN[i]
        for k = 1, an do
            local j = ai[k]
            if mark[j] ~= stamp then
                mark[j] = stamp
                visited = visited + 1
                c = c + weight[j]
            end
        end
        if visited < limit then
            for k = 1, an do
                local aj = adj[ai[k]]
                local ajn = adjN[ai[k]]
                for m = 1, ajn do
                    local u = aj[m]
                    if mark[u] ~= stamp then
                        mark[u] = stamp
                        visited = visited + 1
                        c = c + weight[u]
                        if visited >= limit then break end
                    end
                end
                if visited >= limit then break end
            end
        end
        cnt[i] = c
    end
end

-------------------------------------------------
-- display
-------------------------------------------------
local function Apply(b)
    local indicator = b.indicators.cluster
    if not indicator then return end

    local unit = b.states.unit
    local value = unit and counts[unit]
    if value and value > 0 then
        indicator:SetValue(value)
    else
        indicator:Hide()
    end
end

local function Refresh()
    if presetPending then ApplyPreset() end

    wipe(counts)

    if RefreshMapScale() then
        CollectRoster()
        if unitCount > 0 then
            ComputeCounts()
            for i = 1, unitCount do
                counts[units[i]] = cnt[i]
            end
        end
    end

    F.IterateAllUnitButtons(Apply, true)
end

-------------------------------------------------
-- indicator frame
-------------------------------------------------
local function Cluster_SetValue(self, value)
    self.text:SetText(value)
    self:SetWidth(self.text:GetStringWidth())
    self:Show()
end

local function Cluster_SetFont(self, font, size, outline, shadow)
    font = F.GetFont(font)

    local flags
    if outline == "None" then
        flags = ""
    elseif outline == "Outline" then
        flags = "OUTLINE"
    else
        flags = "OUTLINE,MONOCHROME"
    end

    self.text:SetFont(font, size, flags)

    if shadow then
        self.text:SetShadowOffset(1, -1)
        self.text:SetShadowColor(0, 0, 0, 1)
    else
        self.text:SetShadowOffset(0, 0)
        self.text:SetShadowColor(0, 0, 0, 0)
    end

    self:SetSize(self.text:GetStringWidth(), size)
end

local function Cluster_SetPoint(self, point, relativeTo, relativePoint, x, y)
    self.text:ClearAllPoints()
    if string.find(point, "LEFT$") then
        self.text:SetPoint("LEFT")
    elseif string.find(point, "RIGHT$") then
        self.text:SetPoint("RIGHT")
    else
        self.text:SetPoint("CENTER")
    end
    self:_SetPoint(point, relativeTo, relativePoint, x, y)
end

local function Cluster_SetColor(self, r, g, b)
    self.text:SetTextColor(r, g, b)
end

function I.CreateCluster(parent)
    local cluster = CreateFrame("Frame", parent:GetName().."Cluster", parent.widgets.indicatorFrame)
    parent.indicators.cluster = cluster
    cluster:Hide()

    local text = cluster:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
    cluster.text = text

    cluster.SetFont = Cluster_SetFont
    cluster._SetPoint = cluster.SetPoint
    cluster.SetPoint = Cluster_SetPoint
    cluster.SetColor = Cluster_SetColor
    cluster.SetValue = Cluster_SetValue
end

-------------------------------------------------
-- enable
-------------------------------------------------
local ticker

--! WotLK fix: a respec inside the same talent group only fires
--! PLAYER_TALENT_UPDATE - ACTIVE_TALENT_GROUP_CHANGED alone would leave a
--! Discipline radius on a priest who just went Holy. Both are registered only
--! while the indicator is on, and both fire rarely.
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", ApplyPreset)

function I.SetClusterRadius(radius)
    dbRadius = tonumber(radius) or 0
    ApplyPreset()
end

function I.SetClusterLowHealthOnly(onlyWounded)
    lowHealthOnly = onlyWounded and true or false
end

function I.SetClusterOptions(radius, onlyWounded)
    I.SetClusterLowHealthOnly(onlyWounded)
    I.SetClusterRadius(radius)
end

function I.EnableCluster(enabled)
    if enabled then
        ApplyPreset()
        eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
        eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        if not ticker then
            ticker = C_Timer.NewTicker(INTERVAL, Refresh)
        end
        Refresh()
    else
        eventFrame:UnregisterAllEvents()
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
        --! Wipe first, then push: otherwise the last computed numbers would stay
        --! frozen on the frames after the indicator was switched off.
        wipe(counts)
        F.IterateAllUnitButtons(Apply, true)
    end
end
