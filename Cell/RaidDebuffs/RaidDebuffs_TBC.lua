---------------------------------------------------------------------
-- File: Cell\RaidDebuffs\RaidDebuffs_TBC.lua
-- Author: enderneko (enderneko-dev@outlook.com)
-- Created : 2022-08-05 17:45:05 +08:00
-- Modified: 2025-02-20 16:08 +08:00
---------------------------------------------------------------------

local _, Cell = ...
local F = Cell.funcs

--! WotLK fix: отсюда удалены 35 записей с id вида 21xxxxx (Ascension: Watery Tomb,
--! Sludge Nova, Focused Fire, Inner Demon, ... Fel Rage). Это спеллы кастомного
--! сервера Project Ascension, которых нет в Spell.dbc клиента 3.3.5a: GetSpellInfo
--! на такой id возвращает nil, F.GetDebuffList отбрасывает запись по `if spellName`,
--! и в окне «Дебаффы рейда» строка не появлялась НИКОГДА - молча, без ошибки, так что
--! ни один игровой прогон её найти не мог. Нашёл `dbc_probe.py --sweep` (сверка с
--! Spell.dbc из patch-enUS-3.MPQ), удаление разрешил владелец 2026-08-24. Пустые
--! ключи боссов оставлены: они и раньше в этом файле есть (GAP-037), а их удаление -
--! это уже правка видимого списка, на которую разрешения не было.
local debuffs = {
    [745] = { -- Karazhan
        ["general"] = {
        },
        [1552] = { -- Servant's Quarters
        },
        [1553] = { -- Attumen the Huntsman
            29833, -- Intangible Presence
        },
        [1554] = { -- Moroes
            37066, -- Garrote
        },
        [1555] = { -- Maiden of Virtue
            29511, -- Repentance
        },
        [1556] = { -- Opera Event
            30753, -- Big Bad Wolf
        },
        [1557] = { -- The Curator
            30254, -- Evocation
        },
        [1559] = { -- Shade of Aran
            29946, -- Flame Wreath
        },
        [1560] = { -- Terestian Illhoof
            30053, -- Sacrifice
        },
        [1561] = { -- Netherspite
            38523, -- Nether Exhaust
        },
        [1764] = { -- Chess Event
        },
        [1563] = { -- Prince Malchezaar
            30843, -- Enfeeble
        },
    },

    [746] = { -- 格鲁尔的巢穴
        ["general"] = {
        },
        [1564] = { -- 莫加尔大王
        },
        [1565] = { -- 屠龙者格鲁尔
        },
    },

    [747] = { -- 玛瑟里顿的巢穴
        ["general"] = {
        },
        [1566] = { -- 玛瑟里顿
        },
    },

    [748] = { -- Serpentshrine Cavern
        ["general"] = {
        },
        [1567] = { -- Hydross
            38246, -- Mark of Hydross
        },
        [1568] = { -- Lurker Below
            37850, -- Watery Grave
        },
        [1569] = { -- Leotheras
            37640, -- Whirlwind
        },
        [1570] = { -- Karathress
        },
        [1571] = { -- Morogrim
            37850, -- Watery Grave
        },
        [1572] = { -- Lady Vashj
            38280, -- Static Charge
        },
    },

    [749] = { -- 风暴要塞
        ["general"] = {
        },
        [1573] = { -- 奥
        },
        [1574] = { -- 空灵机甲
        },
        [1575] = { -- 大星术师索兰莉安
        },
        [1576] = { -- 凯尔萨斯·逐日者
        },
    },

    [750] = { -- 海加尔山之战
        ["general"] = {
        },
        [1577] = { -- 雷基·冬寒
        },
        [1578] = { -- 安纳塞隆
        },
        [1579] = { -- 卡兹洛加
        },
        [1580] = { -- 阿兹加洛
        },
        [1581] = { -- 阿克蒙德
        },
    },

    [751] = { -- Black Temple
        ["general"] = {
        },
        [1582] = { -- High Warlord Naj'entus
            39837, -- Impaling Spine
        },
        [1583] = { -- Supremus
            40253, -- Molten Flame
        },
        [1584] = { -- Shade of Akama
        },
        [1585] = { -- Teron Gorefiend
            40251, -- Shadow of Death
        },
        [1586] = { -- Gurtogg Bloodboil
            40481, -- Acidic Wound
            42005, -- Bloodboil
        },
        [1587] = { -- Reliquary of Souls
        },
        [1588] = { -- Mother Shahraz
            40823, -- Saber Lash
        },
        [1589] = { -- Illidari Council
        },
        [1590] = { -- Illidan Stormrage
            41917, -- Parasitic Shadowfiend
        },
    },

    --! WotLK fix: Зул'Аман в дампе отсутствовал целиком - см. блок missingInstances
    --! в ExpansionData/ExpansionDataOverrides.lua, там же id инстанса и id боссов.
    --! Каждый id проверен по Spell.dbc клиента (`dbc_probe.py`), подпись рядом - имя
    --! из самой базы. Принадлежность босса доказана соседством id внутри кластера
    --! энкаунтера (43143+ Халаззи, 43093..43208 Зул'джин, 42389..42398 Налоракк):
    --! серверных привязок способностей к NPC ни один офлайновый источник не хранит.
    --! Мгновенный урон без ауры (43382 Spirit Bolts, 43267 Saber Lash, 42402 Surge,
    --! 42384 Brutal Swipe, 43121 Cyclone, 43140/43215/43294 Flame Breath) и общие
    --! имена (Frenzy, Enrage, Bomb, Fire Bomb) не берутся: список дебаффов ключуется
    --! по ИМЕНИ (F.GetDebuffList), и общее имя поймало бы чужую ауру.
    [77] = { -- Zul'Aman
        ["general"] = {
        },
        [186] = { -- Akil'zon
            43622, -- Static Disruption
            43648, -- Electrical Storm
            43621, -- Gust of Wind
        },
        [187] = { -- Nalorakk
            42389, -- Mangle
            42397, -- Rend Flesh
            42395, -- Lacerating Slash
            42398, -- Deafening Roar
        },
        [188] = { -- Jan'alai
            43299, -- Flame Buffet
        },
        [189] = { -- Halazzi
            43303, -- Flame Shock
        },
        [190] = { -- Hex Lord Malacrass
            43501, -- Siphon Soul
            44131, -- Drain Power
        },
        [191] = { -- Zul'jin
            43093, -- Grievous Throw
            43095, -- Creeping Paralysis
            43149, -- Claw Rage
            43153, -- Lynx Rush
            43208, -- Flame Whirl
        },
    },

    [752] = { -- Sunwell Plateau
        ["general"] = {
        },
        [1591] = { -- Kalecgos
            45032, -- Curse of Boundless Agony
        },
        [1592] = { -- Brutallus
            45150, -- Meteor Slash
            46394, -- Burn
        },
        [1593] = { -- Felmyst
            45855, -- Gas Nova
        },
        [1594] = { -- Eredar Twins
            45256, -- Conflagration
        },
        [1595] = { -- M'uru
        },
        [1596] = { -- Kil'jaeden
            45737, -- Flame Dart
        },
    },

    [248] = { -- 地狱火城墙
        ["general"] = {
        },
        [527] = { -- 巡视者加戈玛
            36814, -- Mortal Wound
        },
        [528] = { -- 无疤者奥摩尔
            37566, -- Bane of Treachery
            30695, -- Treacherous Aura
        },
        [529] = { -- 传令官瓦兹德
        },
    },

    [252] = { -- 塞泰克大厅
        ["general"] = {
            40303, -- Spell Bomb (Anzu heroic)
            40321, -- Cyclone (Anzu heroic)
        },
        [541] = { -- 黑暗编织者塞斯
        },
        [543] = { -- 利爪之王艾吉斯
            12826, -- Polymorph
        },
    },

    [247] = { -- 奥金尼地穴
        ["general"] = {
        },
        [523] = { -- 死亡观察者希尔拉克
        },
        [524] = { -- 大主教玛拉达尔
            32346, -- Soul Siphon
        },
    },

    [260] = { -- 奴隶围栏
        ["general"] = {
        },
        [570] = { -- 背叛者门努
        },
        [571] = { -- 巨钳鲁克玛尔
            38801, -- Grievous Wound
            31948, -- Ensnaring Moss
        },
        [572] = { -- 夸格米拉
        },
    },

    [262] = { -- 幽暗沼泽
        ["general"] = {
        },
        [576] = { -- 霍加尔芬
            34971, -- Frenzy (Claw)
            31615, -- Hunter's Mark
        },
        [577] = { -- 加兹安
        },
        [578] = { -- 沼地领主穆塞雷克
            34974, -- Multi-Shot
            31429, -- Echoing Roar
        },
        [579] = { -- 黑色阔步者
            31715, -- Static Charge
            31717, -- Chain Lightning
        },
    },

    [251] = { -- 旧希尔斯布莱德丘陵
        ["general"] = {
        },
        [538] = { -- 德拉克中尉
            33792, -- Mortal Shot
        },
        [539] = { -- 斯卡洛克上尉
            13005, -- Hammer of Justice
        },
        [540] = { -- 时空猎手
        },
    },

    [253] = { -- 暗影迷宫
        ["general"] = {
        },
        [544] = { -- 赫尔默大使
            33551, -- Acid Breath
            33547, -- Fear
        },
        [545] = { -- 煽动者布莱卡特
            33676, -- Incite Chaos
        },
        [546] = { -- 沃匹尔大师
            38791, -- Banish
        },
        [547] = { -- 摩摩尔
            38794, -- Touch of Murmur
        },
    },

    [250] = { -- 法力陵墓
        ["general"] = {
        },
        [534] = { -- 潘德莫努斯
            38759, -- Dark Shell
        },
        [535] = { -- 塔瓦洛克
            32361, -- Crystal Prison
        },
        [537] = { -- 节点亲王沙法尔
            32365, -- Frost Nova
        },
    },

    [257] = { -- 生态船
        ["general"] = {
        },
        [558] = { -- 指挥官萨拉妮丝
        },
        [559] = { -- 高级植物学家弗雷温
        },
        [560] = { -- 看管者索恩格林
            34661, -- Sacrifice
        },
        [561] = { -- 拉伊
            34697, -- Allergic Reaction
        },
        [562] = { -- 迁跃扭木
        },
    },

    [259] = { -- 破碎大厅
        ["general"] = {
        },
        [566] = { -- 高阶术士奈瑟库斯
            39661, -- Dark Spin (Fear)
            30500, -- Death Coil
            30502, -- Dark Spin
        },
        [568] = { -- 战争使者沃姆罗格
            30618, -- Beatdown
        },
        [569] = { -- 酋长卡加斯·刃拳
        },
    },

    [254] = { -- 禁魔监狱
        ["general"] = {
        },
        [548] = { -- 自由的瑟雷凯斯
            39367, -- Seed of Corruption
        },
        [549] = { -- 末日预言者达尔莉安
            39009, -- Gift of the Doomsayer
        },
        [550] = { -- 天怒预言者苏克拉底
        },
        [551] = { -- 预言者斯克瑞斯
            39017, -- Mind Rend
            39019, -- Domination
        },
    },

    [258] = { -- 能源舰
        ["general"] = {
        },
        [563] = { -- 机械领主卡帕西图斯
        },
        [564] = { -- 灵术师塞比瑟蕾
        },
        [565] = { -- 计算者帕萨雷恩
            35280, -- Domination
            35250, -- Dragon's Breath
            35314, -- Arcane Blast
            35268, -- Inferno
        },
    },

    [261] = { -- 蒸汽地窟
        ["general"] = {
        },
        [573] = { -- 水术师瑟丝比娅
            31481, -- Tidal Surge
            31718, -- Cyclone
        },
        [574] = { -- 机械师斯蒂里格
            35107, -- Net
        },
        [575] = { -- 督军卡利瑟里斯
            16172, -- Head Crack
            31534, -- Spell Reflection
            36453, -- Warlord's Rage
        },
    },

    [249] = { -- 魔导师平台
        ["general"] = {
        },
        [530] = { -- 塞林·火心
        },
        [531] = { -- 维萨鲁斯
            44335, -- Energy Feedback
        },
        [532] = { -- 女祭司德莉希亚
            44141, -- Seed of Corruption
            13323, -- Polymorph
        },
        [533] = { -- 凯尔萨斯·逐日者
            36819, -- Pyroblast
        },
    },

    [256] = { -- 鲜血熔炉
        ["general"] = {
        },
        [555] = { -- 制造者
            30923, -- Mind Control
        },
        [556] = { -- 布洛戈克
            30916, -- Poison Cloud
        },
        [557] = { -- 击碎者克里丹
            30940, -- Burning Nova
        },
    },

    [255] = { -- 黑色沼泽
        ["general"] = {
        },
        [552] = { -- 时空领主德亚
        },
        [553] = { -- 坦普卢斯
            31458, -- Hasten
            38592, -- Spell Reflection
        },
        [554] = { -- 埃欧努斯
            37605, -- Enrage
        },
    },
}

-- WotLK Fix: Defer loading until F.LoadBuiltInDebuffs is available
if F.LoadBuiltInDebuffs then
    F.LoadBuiltInDebuffs(debuffs)
else
    Cell.RegisterCallback("RaidDebuffsReady", "RaidDebuffs_TBC_LoadBuiltIn", function()
        if F.LoadBuiltInDebuffs then
            F.LoadBuiltInDebuffs(debuffs)
        end
    end)
end
