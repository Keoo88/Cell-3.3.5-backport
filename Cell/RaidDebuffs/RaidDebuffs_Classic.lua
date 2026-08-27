---------------------------------------------------------------------
-- File: Cell\RaidDebuffs\RaidDebuffs_Classic.lua
-- Author: enderneko (enderneko-dev@outlook.com)
-- Created : 2022-08-05 17:46:11 +08:00
-- Modified: 2025-12-01 04:11 +08:00
---------------------------------------------------------------------

local _, Cell = ...
local F = Cell.funcs

local debuffs = {
    --! WotLK fix: the last three Molten Core encounters shipped empty, and several
    --! of the others were missing most of what actually lands on the raid. Filled in
    --! from the fan fork (reference/cell_NoM0Re) after checking every id against the
    --! client's own Spell.dbc (`dbc_probe.py`) - the label next to each id is the name
    --! the client returns, not a retelling.
    --! Two rules decided what is NOT here, both of them consequences of how the list
    --! is consumed: F.GetDebuffList matches a bare id BY NAME, so a second id sharing
    --! a name already in the list is dead weight (20294 Immolate next to 15732), and a
    --! boss self-buff can never appear on a player at all. The fork's 47836 Seed of
    --! Corruption and 55360 Living Bomb are dropped for a third reason: those are the
    --! WotLK warlock and mage player spells, not anything Majordomo casts.
    --! A leading minus means "listed in the options, unchecked by default" (upstream's
    --! own convention, see RaidDebuffs_WotLK.lua). Used for the melee filler that sits
    --! on the tank permanently - having Sunder Armor light up the raid-debuff icon for
    --! the whole instance is worse than not having it.
    [741] = { -- Molten Core
        ["general"] = {
            19366, -- Cauterizing Flames
            15732, -- Immolate
        },
        [1519] = { -- Lucifron
            19702, -- Impending Doom
            19703, -- Lucifron's Curse
            20604, -- Dominate Mind
        },
        [1520] = { -- Magmadar
            19408, -- Panic
            19451, -- Enrage
            19428, -- Conflagration
            19450, -- Magma Spit
        },
        [1521] = { -- Gehennas
            19716, -- Gehennas' Curse
            20277, -- Fist of Ragnaros
            19717, -- Rain of Fire
            -15502, -- Sunder Armor
            -19730, -- Strike
        },
        [1522] = { -- Garr
            19496, -- Magma Shackles
        },
        [1523] = { -- Shazzrah
            19713, -- Shazzrah's Curse
            19714, -- Deaden Magic
            19715, -- Counterspell
        },
        [1524] = { -- Baron Geddon
            20475, -- Living Bomb
            19659, -- Ignite Mana
            19695, -- Inferno
        },
        [1525] = { -- Sulfuron Harbinger
            19779, -- Inspire
            19780, -- Hand of Ragnaros
            -19777, -- Dark Strike
        },
        [1526] = { -- Golemagg the Incinerator
            13880, -- Magma Splash
            19820, -- Mangle
            20228, -- Pyroblast
        },
        [1527] = { -- 管理者埃克索图斯
            20229, -- Blast Wave
            19369, -- Ancient Despair
            19365, -- Ancient Dread
            19372, -- Ancient Hysteria
            19367, -- Withering Heat
            19635, -- Incite Flames
            19776, -- Shadow Word: Pain
            19393, -- Soul Burn
        },
        [1528] = { -- 拉格纳罗斯
        },
    },

    [742] = { -- Blackwing Lair
        ["general"] = {
        },
        [1529] = { -- Razorgore the Untamed
        },
        [1530] = { -- Vaelastrasz the Corrupt
            18173, -- Burning Adrenaline
        },
        [1531] = { -- Broodlord Lashlayer
            23331, -- Blast Wave
            24573, -- Mortal Strike
        },
        [1532] = { -- Firemaw
            23341, -- Flame Buffet
        },
        [1533] = { -- Ebonroc
            23340, -- Shadow of Ebonroc
        },
        [1534] = { -- Flamegor
            23342, -- Frenzy
        },
        [1535] = { -- Chromaggus
            23128, -- Frost Burn
            23153, -- Brood Affliction: Black
            23154, -- Brood Affliction: Red
            23155, -- Brood Affliction: Blue
            23169, -- Brood Affliction: Green
            23170, -- Brood Affliction: Bronze
        },
        [1536] = { -- Nefarian
            22667, -- Shadow Flame
            22686, -- Bellowing Roar
        },
    },

    --! WotLK fix: Зул'Гуруб в дампе отсутствовал целиком - см. блок missingInstances
    --! в ExpansionData/ExpansionDataOverrides.lua, там же id инстанса и id боссов.
    --! Каждый id ниже проверен по Spell.dbc клиента (`dbc_probe.py`), подпись рядом -
    --! имя из самой базы, а не пересказ. Принадлежность босса доказана соседством id
    --! с его собственным *Transform-заклинанием (23849 Веноксис, 23966 Джеклик,
    --! 24084 Мар'ли, 24169 Текал, 24190 Арлокк): серверные привязки способностей к
    --! NPC на 3.3.5a не лежат ни в одном офлайновом источнике, а нумерация внутри
    --! патча идёт кластерами по энкаунтеру. Мгновенный урон без ауры (24326 Slam
    --! Газ'ранки, 24189 Force Punch, 24649 Thousand Blades) и общие имена (Frenzy,
    --! Enrage, Whirlwind) не берутся: отслеживать нечего, а общее имя поймало бы
    --! чужую ауру - список дебаффов ключуется по ИМЕНИ (F.GetDebuffList).
    --! WotLK fix: filled out from the fan fork (reference/cell_NoM0Re) on 2026-08-27,
    --! same two filters as Molten Core above - one entry per NAME, and nothing that
    --! only ever sits on the boss. That is why the fork's *Transform and Aspect of *
    --! ids are not here (Hakkar's Aspects are his own buffs, not raid debuffs), why
    --! Frenzy / Avatar / Enlarge / Vanish / Renew are gone, and why the second id of
    --! every doubled name was dropped: 24003 next to 24002 Tranquilizing Poison,
    --! 24011 next to 23862 Venom Spit, 24840 next to 23861 Poison Cloud, 24321 and
    --! 24327 already present under Hakkar, 24322/24324 next to 24323 Blood Siphon,
    --! 16856 next to 24573 Mortal Strike, 17172 next to 24053 Hex, 24333 next to
    --! 24213 Ravage, 23952 next to 24212 Shadow Word: Pain, 24300 next to 24618
    --! Drain Life, 24664/24004 next to 24778 Sleep, 12540 next to 24698 Gouge.
    --! The fork keys this instance [309] (the map id) with its bosses renumbered
    --! 784-793; ours keeps the Encounter Journal ids the file is documented to use,
    --! so each of the fork's lists was matched to our boss key by boss identity.
    [76] = { -- Zul'Gurub
        ["general"] = {
            23931, -- Thunderclap
            24002, -- Tranquilizing Poison
            24063, -- Disease Cloud
            24778, -- Sleep
            24818, -- Noxious Breath
            24839, -- Acid Breath
        },
        [175] = { -- High Priest Venoxis
            23862, -- Venom Spit
            23861, -- Poison Cloud
            23860, -- Holy Fire
            23865, -- Parasitic Serpent
        },
        [784] = { -- High Priestess Jeklik
            23918, -- Sonic Burst
            23919, -- Swoop
            24437, -- Blood Leech
            22884, -- Psychic Scream
            23953, -- Mind Flay
        },
        [785] = { -- High Priest Mar'li
            24110, -- Enveloping Webs
            24111, -- Corrosive Poison
            24099, -- Poison Bolt Volley
            24097, -- Poison
        },
        [176] = { -- Bloodlord Mandokir
            24314, -- Threatening Gaze
            24573, -- Mortal Strike
            -24317, -- Sunder Armor
        },
        [786] = { -- Edge of Madness
            24157, -- Hoodoo Hex
            24388, -- Brain Damage
            24415, -- Slow
            24674, -- Veil of Shadow
            24683, -- Lightning Cloud
        },
        [787] = { -- High Priest Thekal
            24192, -- Speed Slash
            24193, -- Charge
            24698, -- Gouge
            21060, -- Blind
        },
        [788] = { -- Gahz'ranka
            16099, -- Frost Breath
        },
        [789] = { -- High Priestess Arlokk
            24210, -- Mark of Arlokk
            24213, -- Ravage
            24212, -- Shadow Word: Pain
            24339, -- Infected Bite
            -24331, -- Rake
        },
        [185] = { -- Jin'do the Hexxer
            24053, -- Hex
            24306, -- Delusions of Jin'do
            24261, -- Brain Wash
            24600, -- Web Spin
            24618, -- Drain Life
        },
        [790] = { -- Hakkar
            24323, -- Blood Siphon
            24321, -- Poisonous Blood
            24327, -- Cause Insanity
            24328, -- Corrupted Blood
            24178, -- Will of Hakkar
            24673, -- Curse of Blood
        },
    },

    [743] = { -- 安其拉废墟
        ["general"] = {
        },
        [1537] = { -- 库林纳克斯
        },
        [1538] = { -- 拉贾克斯将军
        },
        [1539] = { -- 莫阿姆
        },
        [1540] = { -- 吞咽者布鲁
        },
        [1541] = { -- 狩猎者阿亚米斯
        },
        [1542] = { -- 无疤者奥斯里安
        },
    },

    [744] = { -- Temple of Ahn'Qiraj
        ["general"] = {
        },
        [1543] = { -- The Prophet Skeram
            785, -- True Fulfillment (Mind Control)
        },
        [1544] = { -- Battleguard Sartura
        },
        [1545] = { -- Fankriss the Unyielding
            25646, -- Mortal Wound
        },
        [1546] = { -- Princess Huhuran
            26052, -- Poison Bolt Volley
            26053, -- Noxious Poison
        },
        [1547] = { -- Silithid Royalty
        },
        [1548] = { -- Viscidus
        },
        [1549] = { -- Twin Emperors
            26613, -- Unbalancing Strike
        },
        [1550] = { -- Ouro
            26615, -- Sweep
            26616, -- Sand Blast
        },
        [1551] = { -- C'Thun
            26476, -- Digestive Acid
            26476, -- Mind Flay
        },
    },

    --! WotLK fix: приватные id 900745 / 901552..901566 вместо 745 / 1552..1566 -
    --! настоящий 745 в Encounter Journal принадлежит Каражану (RaidDebuffs_TBC.lua:12),
    --! у Наксрамаса-40 своего id никогда не было. Развёрнуто - в
    --! ExpansionData/ExpansionData.lua:897.
    [900745] = { -- Naxxramas (40)
        ["general"] = {
        },
        [901552] = { -- Anub'Rekhan
            28785, -- Locust Swarm
        },
        [901553] = { -- Grand Widow Faerlina
            28798, -- Poison Bolt Volley
        },
        [901554] = { -- Maexxna
            28622, -- Web Wrap
            28776, -- Necrotic Poison
        },
        [901555] = { -- Noth the Plaguebringer
            29212, -- Cripple
            29213, -- Curse of the Plaguebringer
        },
        [901556] = { -- Heigan the Unclean
            29998, -- Decrepit Fever
        },
        [901557] = { -- Loatheb
            29185, -- Corrupted Mind
            29234, -- Inevitable Doom
        },
        [901558] = { -- Instructor Razuvious
            28732, -- Unbalancing Strike
        },
        [901559] = { -- Gothik the Harvester
            27825, -- Shadow Mark
            28679, -- Harvest Soul
        },
        [901560] = { -- Four Horsemen
            28832, -- Mark of Korth'azz
            28833, -- Mark of Blaumeux
            28834, -- Mark of Rivendare
            28835, -- Mark of Zeliek
        },
        [901561] = { -- Patchwerk
            28801, -- Slime
        },
        --! WotLK fix: typo, the boss id is 1562 (Grobbulus) -- ExpansionData.lua:953
        --! carries 1562 and no button with id 15562 exists anywhere in the UI, so
        --! this whole block was unreachable and the Grobbulus button was empty.
        [901562] = { -- Grobbulus
            28158, -- Mutating Injection
            28169, -- Mutating Injection (Fallout)
        },
        [901563] = { -- Gluth
            29306, -- Infected Wound
            54378, -- Mortal Wound
        },
        [901564] = { -- Thaddius
            28059, -- Positive Charge
            28084, -- Negative Charge
        },
        [901565] = { -- Sapphiron
            28522, -- Icebolt
            28547, -- Chill
        },
        [901566] = { -- Kel'Thuzad
            27808, -- Frost Blast
            27819, -- Detonate Mana
            28410, -- Chains of Kel'Thuzad
        },
    },

    [63] = { -- 死亡矿井
        ["general"] = {
        },
        [89] = { -- 格拉布托克
            87859, -- Fists of Flame
            87861, -- Fists of Frost
        },
        [90] = { -- 赫利克斯·破甲
            88352, -- Chest Bomb
        },
        [91] = { -- 死神5000
            88495, -- Harvest
        },
        [92] = { -- 撕心狼将军
            88836, -- Go For the Throat
        },
        [93] = { -- “船长”曲奇
            6306, -- Acid Splash
        },
    },

    [64] = { -- 影牙城堡
        ["general"] = {
        },
        [96] = { -- 灰葬男爵
        },
        [97] = { -- 席瓦莱恩男爵
        },
        [98] = { -- 指挥官斯普林瓦尔
        },
        [99] = { -- 沃登勋爵
        },
        [100] = { -- 高弗雷勋爵
        },
    },

    [226] = { -- 怒焰裂谷
        ["general"] = {
        },
        [694] = { -- 阿达罗格
        },
        [695] = { -- 黑暗萨满柯兰萨
        },
        [696] = { -- 焰喉
        },
        [697] = { -- 熔岩守卫戈多斯
        },
    },

    [227] = { -- 黑暗深渊
        ["general"] = {
        },
        [368] = { -- 加摩拉
        },
        [426] = { -- 征服者克鲁尔
        },
        [436] = { -- 多米尼娜
        },
        [437] = { -- 暮光领主巴赛尔
        },
        [444] = { -- 阿库麦尔
        },
        [447] = { -- 深渊守护者
        },
        [1144] = { -- 刽子手戈尔
        },
        [1145] = { -- 苏克
        },
    },

    [228] = { -- 黑石深渊
        ["general"] = {
        },
        [369] = { -- 审讯官格斯塔恩
        },
        [370] = { -- 洛考尔
        },
        [371] = { -- 驯犬者格雷布玛尔
        },
        [372] = { -- 秩序竞技场
        },
        [373] = { -- 控火师罗格雷恩
        },
        [374] = { -- 伊森迪奥斯
        },
        [375] = { -- 典狱官斯迪尔基斯
        },
        [376] = { -- 弗诺斯·达克维尔
        },
        [377] = { -- 贝尔加
        },
        [378] = { -- 怒炉将军
        },
        [379] = { -- 傀儡统帅阿格曼奇
        },
        [380] = { -- 霍尔雷·黑须
        },
        [381] = { -- 法拉克斯
        },
        [383] = { -- 普拉格
        },
        [384] = { -- 弗莱拉斯总大使
        },
        [385] = { -- 黑铁七贤
        },
        [386] = { -- 玛格姆斯
        },
        [387] = { -- 达格兰·索瑞森大帝
        },
    },

    [229] = { -- 黑石塔下层
        ["general"] = {
        },
        [388] = { -- 欧莫克大王
        },
        [389] = { -- 暗影猎手沃什加斯
        },
        [390] = { -- 指挥官沃恩
        },
        [391] = { -- 烟网蛛后
        },
        [392] = { -- 尤洛克·暗嚎
        },
        [393] = { -- 军需官兹格雷斯
            15284, -- Cleave
        },
        [394] = { -- 哈雷肯
        },
        [395] = { -- 奴役者基兹鲁尔
        },
        [396] = { -- 维姆萨拉克
        },
    },

    [230] = { -- 厄运之槌
        ["general"] = {
        },
        [402] = { -- 瑟雷姆·刺蹄
            22651, -- Sacrifice
            22478, -- Intense Pain
            17228, -- Shadow Bolt Volley
        },
        [403] = { -- 海多斯博恩
            17207, -- Whirlwind
        },
        [404] = { -- 蕾瑟塔蒂丝
            13338, -- Curse of Thorns
            16247, -- Curse of Tongues
            17228, -- Shadow Bolt Volley
        },
        [405] = { -- 荒野变形者奥兹恩
            22661, -- Enervate
            22662, -- Wither
            22415, -- Entangling Roots
            10101, -- Knock Away
            22689, -- Mangle
        },
        [406] = { -- 特迪斯·扭木
            5568, -- Trample
            22924, -- Grasping Vines
            22994, -- Entangle
        },
        [407] = { -- 伊琳娜·暗木
            22910, -- Immolation Trap
            22914, -- Concussive Shot
            22911, -- Charge
        },
        [408] = { -- 卡雷迪斯镇长
            7645, -- Dominate Mind
            22917, -- Shadowform
        },
        [409] = { -- 伊莫塔尔
            5568, -- Trample
            22899, -- Eye of Immol'thar
        },
        [410] = { -- 托塞德林王子
        },
        [411] = { -- 卫兵摩尔达
            11972, -- Shield Bash
            15749, -- Shield Charge
            14516, -- Strike
        },
        [412] = { -- 践踏者克雷格
            15578, -- Whirlwind
            16740, -- War Stomp
            22833, -- Booze Spit
        },
        [413] = { -- 卫兵芬古斯
        },
        [414] = { -- 卫兵斯里基克
        },
        [415] = { -- 克罗卡斯
            13704, -- Psychic Scream
        },
        [416] = { -- 观察者克鲁什
        },
        [417] = { -- 戈多克大王
            16856, -- Mortal Strike
            15572, -- Sunder Armor
            16727, -- War Stomp
        },
    },

    [231] = { -- 诺莫瑞根
        ["general"] = {
        },
        [418] = { -- 群体打击者9-60
        },
        [419] = { -- 格鲁比斯
        },
        [420] = { -- 粘性辐射尘
        },
        [421] = { -- 电刑器6000型
        },
        [422] = { -- 机械师瑟玛普拉格
        },
    },

    [232] = { -- 玛拉顿
        ["general"] = {
        },
        [423] = { -- 诺克赛恩
        },
        [424] = { -- 锐刺鞭笞者
        },
        [425] = { -- 工匠吉兹洛克
        },
        [427] = { -- 维利塔恩
        },
        [428] = { -- 被诅咒的塞雷布拉斯
        },
        [429] = { -- 兰斯利德
        },
        [430] = { -- 洛特格里普
        },
        [431] = { -- 瑟莱德丝公主
        },
    },

    [233] = { -- 剃刀高地
        ["general"] = {
        },
        [433] = { -- 火眼莫德雷斯
        },
        [1141] = { -- 寒冰之王亚门纳尔
        },
        [1142] = { -- 阿鲁克斯
        },
        [1143] = { -- 麦什伦
        },
        [1146] = { -- 亡语者布莱克松
        },
    },

    [234] = { -- 剃刀沼泽
        ["general"] = {
        },
        [895] = { -- 鲁古格
        },
        [896] = { -- 猎手布塔斯克
        },
        [899] = { -- 督军拉姆塔斯
        },
        [900] = { -- 盲眼猎手格罗亚特
            32065, -- Grievous Wound
        },
        [901] = { -- 卡尔加·刺肋
        },
    },

    [236] = { -- 斯坦索姆
        ["general"] = {
        },
        [443] = { -- 弗雷斯特恩
            16798, -- Enchanting Lullaby
            16244, -- Demoralizing Shout
        },
        [445] = { -- 悲惨的提米
            17470, -- Ravenous Claw
            8599, -- Enrage
        },
        [446] = { -- 希望破坏者威利
            10887, -- Crowd Pummel
            14099, -- Mighty Blow
            16791, -- Furious Anger
        },
        [448] = { -- 档案管理员加尔福特
        },
        [449] = { -- 巴纳扎尔
            17405, -- Domination
            13704, -- Psychic Scream
        },
        [450] = { -- 不可宽恕者
        },
        [451] = { -- 安娜丝塔丽男爵夫人
            17244, -- Possess
            18327, -- Silence
            16867, -- Banshee Curse
        },
        [452] = { -- 奈鲁布恩坎
            4962, -- Encasing Webs
            6016, -- Pierce Armor
        },
        [453] = { -- 苍白的玛勒基
            16869, -- Ice Tomb
            17620, -- Drain Life
        },
        [454] = { -- 巴瑟拉斯镇长
            10887, -- Crowd Pummel
            14099, -- Mighty Blow
            16791, -- Furious Anger
        },
        [455] = { -- 吞咽者拉姆斯登
        },
        [456] = { -- 奥里克斯·瑞文戴尔领主
        },
        [749] = { -- 指挥官玛洛尔
        },
    },

    [237] = { -- 阿塔哈卡神庙
        ["general"] = {
        },
        [457] = { -- 哈卡的化身
        },
        [458] = { -- 预言者迦玛兰
        },
        [459] = { -- 梦境守望者
        },
        [463] = { -- 伊兰尼库斯的阴影
        },
    },

    [238] = { -- 监狱
        ["general"] = {
        },
        [464] = { -- 霍格
        },
        [465] = { -- 灼热勋爵
        },
        [466] = { -- 兰多菲·摩洛克
        },
    },

    [239] = { -- 奥达曼
        ["general"] = {
        },
        [467] = { -- 鲁维罗什
        },
        [468] = { -- 失踪的矮人
        },
        [469] = { -- 艾隆纳亚
        },
        [470] = { -- 远古巨石卫士
        },
        [471] = { -- 加加恩·火锤
        },
        [472] = { -- 格瑞姆洛克
        },
        [473] = { -- 阿扎达斯
        },
        [748] = { -- 黑曜石哨兵
        },
    },

    [240] = { -- 哀嚎洞穴
        ["general"] = {
        },
        [474] = { -- 安娜科德拉
        },
        [475] = { -- 考布莱恩
        },
        [476] = { -- 皮萨斯
        },
        [477] = { -- 克雷什
        },
        [478] = { -- 斯卡姆
        },
        [479] = { -- 瑟芬迪斯
        },
        [480] = { -- 永生者沃尔丹
        },
        [481] = { -- 吞噬者穆坦努斯
        },
    },

    [241] = { -- 祖尔法拉克
        ["general"] = {
        },
        [483] = { -- 加兹瑞拉
            11836, -- Freeze Solid
        },
        [484] = { -- 安图苏尔
            11020, -- Petrify
        },
        [485] = { -- 殉教者塞卡
            8600, -- Fevered Plague
        },
        [486] = { -- 巫医祖穆拉恩
        },
        [487] = { -- 耐克鲁姆和塞瑟斯
        },
        [489] = { -- 乌克兹·沙顶
        },
    },

    [246] = { -- 通灵学院
        ["general"] = {
        },
        [659] = { -- 指导者寒心
        },
        [663] = { -- 詹迪斯·巴罗夫
        },
        [665] = { -- 血骨傀儡
        },
        [666] = { -- 莉莉安·沃斯
        },
        [684] = { -- 黑暗院长加丁
        },
    },

    [311] = { -- 血色大厅
        ["general"] = {
        },
        [654] = { -- 武器大师哈兰
        },
        [656] = { -- 织焰者孔格勒
        },
        [660] = { -- 驯犬者布兰恩
        },
    },

    [316] = { -- 血色修道院
        ["general"] = {
        },
        [671] = { -- 科洛夫修士
        },
        [674] = { -- 大检察官怀特迈恩
        },
        [688] = { -- 裂魂者萨尔诺斯
        },
    },

}

-- WotLK Fix: Defer loading until F.LoadBuiltInDebuffs is available (defined in Modules/RaidDebuffs/RaidDebuffs_Classic.lua)
if F.LoadBuiltInDebuffs then
    F.LoadBuiltInDebuffs(debuffs)
else
    -- Register a callback to load debuffs once the function is available
    Cell.RegisterCallback("RaidDebuffsReady", "RaidDebuffs_Classic_LoadBuiltIn", function()
        if F.LoadBuiltInDebuffs then
            F.LoadBuiltInDebuffs(debuffs)
        end
    end)
end
