---------------------------------------------------------------------
-- File: Cell\RaidDebuffs\ExpansionData\ExpansionData.lua
-- Author: enderneko (enderneko-dev@outlook.com)
-- Created : 2022-08-26 04:40:40 +08:00
-- Modified: 2025-02-20 16:12 +08:00
---------------------------------------------------------------------

local _, Cell = ...
local F = Cell.funcs

Cell_ExpansionData = {
    ["locale"] = "enUS",
    --! WotLK fix: a compact locale alias file can make native zone-name lookup
    --! functional without duplicating the full retail ExpansionData payload.
    ["instanceLocale"] = "enUS",
    --! WotLK fix: часть записей дампа названа так, как их переименовал ретейл уже
    --! ПОСЛЕ 3.3.5a, поэтому на английском клиенте зона не находилась вообще, а
    --! поиск идёт точным ключом. Ключи ниже - клиентские имена 3.3.5a, значения -
    --! записи дампа. Полные локали присваивают свою таблицу поверх, и это верно: на
    --! немецком клиенте английские ключи не встретятся.
    --!
    --! Имён у одного инстанса ДВА, и оба взяты из самого клиента, а не с чужих слов:
    --! GetInstanceInfo() отдаёт имя КАРТЫ (Map.dbc поле 5), GetRealZoneText() - имя
    --! ЗОНЫ (AreaTable.dbc поле 11). Первые три ключа - это написания ЗОНЫ, вторые
    --! пять - написания КАРТЫ, и для одного инстанса нужны оба, потому что внутри
    --! подземелья Cell спрашивает карту, а снаружи - зону (см. ResolveInstance в
    --! Modules/RaidDebuffs/RaidDebuffs_Classic.lua). Прежняя редакция этого
    --! комментария приписывала три нижних написания GetInstanceInfo - это неверно:
    --! карту клиент зовёт "The Battle for Mount Hyjal", "Deadmines" и
    --! "Sunken Temple", последнее и добавлено ниже.
    --!
    --! Остальные пять - записи, чьё имя клиент не знает ни одной из двух таблиц:
    --! рейд AQ40 на карте называется "Ahn'Qiraj Temple", The Eye - "Tempest Keep",
    --! Нижний Пик - "Blackrock Spire" (карта 229 общая с Верхним Пиком, отдельной
    --! записи для него в дампе нет). Без этих ключей дебаффы там не включались
    --! молча. Два инстанса дозаполнить нечем: карты 40-местного Наксрамаса на
    --! 3.3.5a нет вовсе, а "Scarlet Halls" - подземелье Cataclysm.
    ["instanceNameAliases"] = {
        ["Hyjal Summit"] = "The Battle for Mount Hyjal",
        ["The Deadmines"] = "Deadmines",
        ["The Temple of Atal'Hakkar"] = "The Temple of Atal'hakkar",
        ["Sunken Temple"] = "The Temple of Atal'hakkar",
        ["Ahn'Qiraj Temple"] = "Temple of Ahn'Qiraj",
        ["Ahn'Qiraj"] = "Temple of Ahn'Qiraj",
        ["Tempest Keep"] = "The Eye",
        ["Blackrock Spire"] = "Lower Blackrock Spire",
    },
    ["expansions"] = {},
    ["data"] = {},
}

-------------------------------------------------
-- functions
-------------------------------------------------
--! WotLK fix: колбэк AddonLoaded "UpdateExpansionData" удалён вместе с семью
--! пост-WotLK эпохами. Он срезал `#expansions - 3` первых элемента списка и
--! соответствующие ветки `data` уже после загрузки - то есть работу по разбору
--! ретейльных таблиц клиент всё равно выполнял. Теперь в литералах ровно те три
--! эпохи, которые нужны 3.3.5a, и срезать нечего.

function F.GetExpansionList()
    --! WotLK fix: localized instance-name aliases are sufficient for the runtime
    --! Raid Debuffs contract. Keep English UI labels when a full locale dataset
    --! is unavailable, but warn only if native zone-name lookup is also missing.
    local locale = GetLocale()
    --! WotLK fix: на 3.3.5a GetLocale отдаёт enGB отдельным значением (кодекс
    --! перечисляет его наравне с enUS), а зоны у обоих английских клиентов
    --! называются одинаково. Без нормализации EU-английский игрок получал при
    --! каждом входе строку "Missing localized instance data for enGB", хотя ничего
    --! не сломано. ElvUI 6.09 под этот же клиент сводит enGB к enUS так же
    --! (reference/ElvUI-master/ElvUI/Core/Core.lua:5).
    if locale == "enGB" then locale = "enUS" end
    if Cell_ExpansionData["locale"] ~= locale and Cell_ExpansionData["instanceLocale"] ~= locale then
        F.Print("Missing localized instance data for "..locale..", Raid Debuffs may not work properly, please report to author.")
    end
    return Cell_ExpansionData["expansions"]
end

function F.GetExpansionData()
    return Cell_ExpansionData["data"]
end

function F.GetExpansionInstanceNameAliases()
    return Cell_ExpansionData["instanceNameAliases"]
end

-------------------------------------------------
-- expansions
-------------------------------------------------
--! WotLK fix: список сокращён до трёх эпох, которые существуют на 3.3.5a.
--! Раньше литерал нёс все десять, а колбэк AddonLoaded на каждом входе в игру
--! выбрасывал семь первых: 109 инстансов и 614 боссов ретейла разбирались в
--! таблицы и тут же удалялись. На Lua 5.1 без JIT это ~150 КБ мёртвого разбора
--! здесь и ещё по ~145 КБ в каждой из шести полных локалей. Порядок остатка тот
--! же, что получался после среза, - позиции 8-10 исходного списка.
--! Данные Classic/TBC сохранены целиком: старые рейды на WotLK-сервере доступны.
Cell_ExpansionData.expansions = {
    "Wrath of the Lich King",
    "Burning Crusade",
    "Classic",
}

-------------------------------------------------
-- instances & bosses
-------------------------------------------------
Cell_ExpansionData.data = {
    ["Classic"] = {
        {
            ["id"] = 741,
            ["image"] = 1396586,
            ["name"] = "Molten Core",
            ["bosses"] = {
                {
                    ["id"] = 1519,
                    ["image"] = 1378993,
                    ["name"] = "Lucifron",
                }, -- [1]
                {
                    ["id"] = 1520,
                    ["image"] = 1378995,
                    ["name"] = "Magmadar",
                }, -- [2]
                {
                    ["id"] = 1521,
                    ["image"] = 1378976,
                    ["name"] = "Gehennas",
                }, -- [3]
                {
                    ["id"] = 1522,
                    ["image"] = 1378975,
                    ["name"] = "Garr",
                }, -- [4]
                {
                    ["id"] = 1523,
                    ["image"] = 1379013,
                    ["name"] = "Shazzrah",
                }, -- [5]
                {
                    ["id"] = 1524,
                    ["image"] = 1378966,
                    ["name"] = "Baron Geddon",
                }, -- [6]
                {
                    ["id"] = 1525,
                    ["image"] = 1379015,
                    ["name"] = "Sulfuron Harbinger",
                }, -- [7]
                {
                    ["id"] = 1526,
                    ["image"] = 1378978,
                    ["name"] = "Golemagg the Incinerator",
                }, -- [8]
                {
                    ["id"] = 1527,
                    ["image"] = 1378998,
                    ["name"] = "Majordomo Executus",
                }, -- [9]
                {
                    ["id"] = 1528,
                    ["image"] = 522261,
                    ["name"] = "Ragnaros",
                }, -- [10]
            },
        }, -- [1]
        {
            ["id"] = 742,
            ["image"] = 1396580,
            ["name"] = "Blackwing Lair",
            ["bosses"] = {
                {
                    ["id"] = 1529,
                    ["image"] = 1379008,
                    ["name"] = "Razorgore the Untamed",
                }, -- [1]
                {
                    ["id"] = 1530,
                    ["image"] = 1379022,
                    ["name"] = "Vaelastrasz the Corrupt",
                }, -- [2]
                {
                    ["id"] = 1531,
                    ["image"] = 1378968,
                    ["name"] = "Broodlord Lashlayer",
                }, -- [3]
                {
                    ["id"] = 1532,
                    ["image"] = 1378973,
                    ["name"] = "Firemaw",
                }, -- [4]
                {
                    ["id"] = 1533,
                    ["image"] = 1378971,
                    ["name"] = "Ebonroc",
                }, -- [5]
                {
                    ["id"] = 1534,
                    ["image"] = 1378974,
                    ["name"] = "Flamegor",
                }, -- [6]
                {
                    ["id"] = 1535,
                    ["image"] = 1378969,
                    ["name"] = "Chromaggus",
                }, -- [7]
                {
                    ["id"] = 1536,
                    ["image"] = 1379001,
                    ["name"] = "Nefarian",
                }, -- [8]
            },
        }, -- [2]
        {
            ["id"] = 743,
            ["image"] = 1396591,
            ["name"] = "Ruins of Ahn'Qiraj",
            ["bosses"] = {
                {
                    ["id"] = 1537,
                    ["image"] = 1385749,
                    ["name"] = "Kurinnaxx",
                }, -- [1]
                {
                    ["id"] = 1538,
                    ["image"] = 1385734,
                    ["name"] = "General Rajaxx",
                }, -- [2]
                {
                    ["id"] = 1539,
                    ["image"] = 1385755,
                    ["name"] = "Moam",
                }, -- [3]
                {
                    ["id"] = 1540,
                    ["image"] = 1385723,
                    ["name"] = "Buru the Gorger",
                }, -- [4]
                {
                    ["id"] = 1541,
                    ["image"] = 1385718,
                    ["name"] = "Ayamiss the Hunter",
                }, -- [5]
                {
                    ["id"] = 1542,
                    ["image"] = 1385759,
                    ["name"] = "Ossirian the Unscarred",
                }, -- [6]
            },
        }, -- [3]
        {
            ["id"] = 744,
            ["image"] = 1396593,
            ["name"] = "Temple of Ahn'Qiraj",
            ["bosses"] = {
                {
                    ["id"] = 1543,
                    ["image"] = 1385769,
                    ["name"] = "The Prophet Skeram",
                }, -- [1]
                {
                    ["id"] = 1547,
                    ["image"] = 1390436,
                    ["name"] = "Silithid Royalty",
                }, -- [2]
                {
                    ["id"] = 1544,
                    ["image"] = 1385720,
                    ["name"] = "Battleguard Sartura",
                }, -- [3]
                {
                    ["id"] = 1545,
                    ["image"] = 1385728,
                    ["name"] = "Fankriss the Unyielding",
                }, -- [4]
                {
                    ["id"] = 1548,
                    ["image"] = 1385771,
                    ["name"] = "Viscidus",
                }, -- [5]
                {
                    ["id"] = 1546,
                    ["image"] = 1385761,
                    ["name"] = "Princess Huhuran",
                }, -- [6]
                {
                    ["id"] = 1549,
                    ["image"] = 1390437,
                    ["name"] = "The Twin Emperors",
                }, -- [7]
                {
                    ["id"] = 1550,
                    ["image"] = 1385760,
                    ["name"] = "Ouro",
                }, -- [8]
                {
                    ["id"] = 1551,
                    ["image"] = 1385726,
                    ["name"] = "C'Thun",
                }, -- [9]
            },
        }, -- [4]
        --! WotLK fix: приватные id 900745 / 901552..901566 вместо 745 / 1552..1566.
        --! Cell нумерует рейды по journalInstanceID ретейлового Encounter Journal, но
        --! Наксрамаса-40 в ретейле нет (снят в 3.0.2), id ему никто не выдавал - в
        --! данные он попал простым продолжением классического ряда 741 MC, 742 BWL,
        --! 743 Ruins AQ, 744 Temple AQ -> 745, боссы так же продолжили C'Thun 1551.
        --! А 745 в EJ занят Каражаном (:1832), и 1552 там же - его "Servant's
        --! Quarters". Список дополнений обходится от новых к старым, поэтому
        --! выигрывал Каражан: классический Наксрамас был недостижим в UI и делил с
        --! ним одно ведро настроек CellDB["raidDebuffs"][745]. Диапазон 900000+ не
        --! пересекается ни с одним настоящим EJ id (максимум в данных - 1209).
        --! Те же id продублированы в RaidDebuffs_Classic.lua:137 и во всех
        --! ExpansionData_*.lua; TBC-шный Каражан не тронут.
        {
            ["id"] = 900745,
            ["image"] = 1396587,
            ["name"] = "Naxxramas (40)",
            ["bosses"] = {
                {
                    ["id"] = 901552,
                    ["image"] = 1378964,
                    ["name"] = "Anub'Rekhan",
                }, -- [1]
                {
                    ["id"] = 901553,
                    ["image"] = 1378980,
                    ["name"] = "Grand Widow Faerlina",
                }, -- [2]
                {
                    ["id"] = 901554,
                    ["image"] = 1378994,
                    ["name"] = "Maexxna",
                }, -- [3]
                {
                    ["id"] = 901555,
                    ["image"] = 1379004,
                    ["name"] = "Noth the Plaguebringer",
                }, -- [4]
                {
                    ["id"] = 901556,
                    ["image"] = 1378984,
                    ["name"] = "Heigan the Unclean",
                }, -- [5]
                {
                    ["id"] = 901557,
                    ["image"] = 1378991,
                    ["name"] = "Loatheb",
                }, -- [6]
                {
                    ["id"] = 901558,
                    ["image"] = 1378988,
                    ["name"] = "Instructor Razuvious",
                }, -- [7]
                {
                    ["id"] = 901559,
                    ["image"] = 1378979,
                    ["name"] = "Gothik the Harvester",
                }, -- [8]
                {
                    ["id"] = 901560,
                    ["image"] = 1385732,
                    ["name"] = "The Four Horsemen",
                }, -- [9]
                {
                    ["id"] = 901561,
                    ["image"] = 1379005,
                    ["name"] = "Patchwerk",
                }, -- [10]
                {
                    ["id"] = 901562,
                    ["image"] = 1378981,
                    ["name"] = "Grobbulus",
                }, -- [11]
                {
                    ["id"] = 901563,
                    ["image"] = 1378977,
                    ["name"] = "Gluth",
                }, -- [12]
                {
                    ["id"] = 901564,
                    ["image"] = 1379019,
                    ["name"] = "Thaddius",
                }, -- [13]
                {
                    ["id"] = 901565,
                    ["image"] = 1379010,
                    ["name"] = "Sapphiron",
                }, -- [14]
                {
                    ["id"] = 901566,
                    ["image"] = 1378989,
                    ["name"] = "Kel'Thuzad",
                }, -- [15]
            },
        }, -- [5]
        {
            ["id"] = 227,
            ["image"] = 608195,
            ["name"] = "Blackfathom Deeps",
            ["bosses"] = {
                {
                    ["id"] = 368,
                    ["image"] = 1064179,
                    ["name"] = "Ghamoo-Ra",
                }, -- [1]
                {
                    ["id"] = 436,
                    ["image"] = 1064180,
                    ["name"] = "Domina",
                }, -- [2]
                {
                    ["id"] = 426,
                    ["image"] = 522214,
                    ["name"] = "Subjugator Kor'ul",
                }, -- [3]
                {
                    ["id"] = 1145,
                    ["image"] = 1064181,
                    ["name"] = "Thruk",
                }, -- [4]
                {
                    ["id"] = 447,
                    ["image"] = 1064182,
                    ["name"] = "Guardian of the Deep",
                }, -- [5]
                {
                    ["id"] = 1144,
                    ["image"] = 1064183,
                    ["name"] = "Executioner Gore",
                }, -- [6]
                {
                    ["id"] = 437,
                    ["image"] = 1064184,
                    ["name"] = "Twilight Lord Bathiel",
                }, -- [7]
                {
                    ["id"] = 444,
                    ["image"] = 607532,
                    ["name"] = "Aku'mai",
                }, -- [8]
            },
        }, -- [6]
        {
            ["id"] = 228,
            ["image"] = 608196,
            ["name"] = "Blackrock Depths",
            ["bosses"] = {
                {
                    ["id"] = 369,
                    ["image"] = 607644,
                    ["name"] = "High Interrogator Gerstahn",
                }, -- [1]
                {
                    ["id"] = 370,
                    ["image"] = 607697,
                    ["name"] = "Lord Roccor",
                }, -- [2]
                {
                    ["id"] = 371,
                    ["image"] = 607647,
                    ["name"] = "Houndmaster Grebmar",
                }, -- [3]
                {
                    ["id"] = 372,
                    ["image"] = 608314,
                    ["name"] = "Ring of Law",
                }, -- [4]
                {
                    ["id"] = 373,
                    ["image"] = 607749,
                    ["name"] = "Pyromancer Loregrain",
                }, -- [5]
                {
                    ["id"] = 374,
                    ["image"] = 607694,
                    ["name"] = "Lord Incendius",
                }, -- [6]
                {
                    ["id"] = 375,
                    ["image"] = 607814,
                    ["name"] = "Warder Stilgiss",
                }, -- [7]
                {
                    ["id"] = 376,
                    ["image"] = 607602,
                    ["name"] = "Fineous Darkvire",
                }, -- [8]
                {
                    ["id"] = 377,
                    ["image"] = 607549,
                    ["name"] = "Bael'Gar",
                }, -- [9]
                {
                    ["id"] = 378,
                    ["image"] = 607610,
                    ["name"] = "General Angerforge",
                }, -- [10]
                {
                    ["id"] = 379,
                    ["image"] = 607618,
                    ["name"] = "Golem Lord Argelmach",
                }, -- [11]
                {
                    ["id"] = 380,
                    ["image"] = 607650,
                    ["name"] = "Hurley Blackbreath",
                }, -- [12]
                {
                    ["id"] = 381,
                    ["image"] = 607740,
                    ["name"] = "Phalanx",
                }, -- [13]
                {
                    ["id"] = 383,
                    ["image"] = 607741,
                    ["name"] = "Plugger Spazzring",
                }, -- [14]
                {
                    ["id"] = 384,
                    ["image"] = 607535,
                    ["name"] = "Ambassador Flamelash",
                }, -- [15]
                {
                    ["id"] = 385,
                    ["image"] = 607587,
                    ["name"] = "The Seven",
                }, -- [16]
                {
                    ["id"] = 386,
                    ["image"] = 607705,
                    ["name"] = "Magmus",
                }, -- [17]
                {
                    ["id"] = 387,
                    ["image"] = 607595,
                    ["name"] = "Emperor Dagran Thaurissan",
                }, -- [18]
            },
        }, -- [7]
        {
            ["id"] = 63,
            ["image"] = 522352,
            ["name"] = "Deadmines",
            ["bosses"] = {
                {
                    ["id"] = 89,
                    ["image"] = 522228,
                    ["name"] = "Glubtok",
                }, -- [1]
                {
                    ["id"] = 90,
                    ["image"] = 522234,
                    ["name"] = "Helix Gearbreaker",
                }, -- [2]
                {
                    ["id"] = 91,
                    ["image"] = 522225,
                    ["name"] = "Foe Reaper 5000",
                }, -- [3]
                {
                    ["id"] = 92,
                    ["image"] = 522189,
                    ["name"] = "Admiral Ripsnarl",
                }, -- [4]
                {
                    ["id"] = 93,
                    ["image"] = 522210,
                    ["name"] = "\"Captain\" Cookie",
                }, -- [5]
                {
                    ["id"] = 95,
                    ["image"] = 522278,
                    ["name"] = "Vanessa VanCleef",
                }, -- [6]
            },
        }, -- [8]
        {
            ["id"] = 230,
            ["image"] = 608200,
            ["name"] = "Dire Maul",
            ["bosses"] = {
                {
                    ["id"] = 402,
                    ["image"] = 607824,
                    ["name"] = "Zevrim Thornhoof",
                }, -- [1]
                {
                    ["id"] = 403,
                    ["image"] = 607653,
                    ["name"] = "Hydrospawn",
                }, -- [2]
                {
                    ["id"] = 404,
                    ["image"] = 607686,
                    ["name"] = "Lethtendris",
                }, -- [3]
                {
                    ["id"] = 405,
                    ["image"] = 607533,
                    ["name"] = "Alzzin the Wildshaper",
                }, -- [4]
                {
                    ["id"] = 406,
                    ["image"] = 607785,
                    ["name"] = "Tendris Warpwood",
                }, -- [5]
                {
                    ["id"] = 407,
                    ["image"] = 607656,
                    ["name"] = "Illyanna Ravenoak",
                }, -- [6]
                {
                    ["id"] = 408,
                    ["image"] = 607703,
                    ["name"] = "Magister Kalendris",
                }, -- [7]
                {
                    ["id"] = 409,
                    ["image"] = 607657,
                    ["name"] = "Immol'thar",
                }, -- [8]
                {
                    ["id"] = 410,
                    ["image"] = 607745,
                    ["name"] = "Prince Tortheldrin",
                }, -- [9]
                {
                    ["id"] = 411,
                    ["image"] = 607630,
                    ["name"] = "Guard Mol'dar",
                }, -- [10]
                {
                    ["id"] = 412,
                    ["image"] = 607777,
                    ["name"] = "Stomper Kreeg",
                }, -- [11]
                {
                    ["id"] = 413,
                    ["image"] = 607629,
                    ["name"] = "Guard Fengus",
                }, -- [12]
                {
                    ["id"] = 414,
                    ["image"] = 607631,
                    ["name"] = "Guard Slip'kik",
                }, -- [13]
                {
                    ["id"] = 415,
                    ["image"] = 607560,
                    ["name"] = "Captain Kromcrush",
                }, -- [14]
                {
                    ["id"] = 416,
                    ["image"] = 607565,
                    ["name"] = "Cho'Rush the Observer",
                }, -- [15]
                {
                    ["id"] = 417,
                    ["image"] = 607673,
                    ["name"] = "King Gordok",
                }, -- [16]
            },
        }, -- [9]
        {
            ["id"] = 231,
            ["image"] = 608202,
            ["name"] = "Gnomeregan",
            ["bosses"] = {
                {
                    ["id"] = 419,
                    ["image"] = 607628,
                    ["name"] = "Grubbis",
                }, -- [1]
                {
                    ["id"] = 420,
                    ["image"] = 607808,
                    ["name"] = "Viscous Fallout",
                }, -- [2]
                {
                    ["id"] = 421,
                    ["image"] = 607594,
                    ["name"] = "Electrocutioner 6000",
                }, -- [3]
                {
                    ["id"] = 418,
                    ["image"] = 607572,
                    ["name"] = "Crowd Pummeler 9-60",
                }, -- [4]
                {
                    ["id"] = 422,
                    ["image"] = 607714,
                    ["name"] = "Mekgineer Thermaplugg",
                }, -- [5]
            },
        }, -- [10]
        {
            ["id"] = 229,
            ["image"] = 608197,
            ["name"] = "Lower Blackrock Spire",
            ["bosses"] = {
                {
                    ["id"] = 388,
                    ["image"] = 607645,
                    ["name"] = "Highlord Omokk",
                }, -- [1]
                {
                    ["id"] = 389,
                    ["image"] = 607769,
                    ["name"] = "Shadow Hunter Vosh'gajin",
                }, -- [2]
                {
                    ["id"] = 390,
                    ["image"] = 607810,
                    ["name"] = "War Master Voone",
                }, -- [3]
                {
                    ["id"] = 391,
                    ["image"] = 607719,
                    ["name"] = "Mother Smolderweb",
                }, -- [4]
                {
                    ["id"] = 392,
                    ["image"] = 607801,
                    ["name"] = "Urok Doomhowl",
                }, -- [5]
                {
                    ["id"] = 393,
                    ["image"] = 607751,
                    ["name"] = "Quartermaster Zigris",
                }, -- [6]
                {
                    ["id"] = 394,
                    ["image"] = 607634,
                    ["name"] = "Halycon",
                }, -- [7]
                {
                    ["id"] = 395,
                    ["image"] = 607615,
                    ["name"] = "Gizrul the Slavener",
                }, -- [8]
                {
                    ["id"] = 396,
                    ["image"] = 607737,
                    ["name"] = "Overlord Wyrmthalak",
                }, -- [9]
            },
        }, -- [11]
        {
            ["id"] = 232,
            ["image"] = 608209,
            ["name"] = "Maraudon",
            ["bosses"] = {
                {
                    ["id"] = 423,
                    ["image"] = 607728,
                    ["name"] = "Noxxion",
                }, -- [1]
                {
                    ["id"] = 424,
                    ["image"] = 607756,
                    ["name"] = "Razorlash",
                }, -- [2]
                {
                    ["id"] = 425,
                    ["image"] = 607796,
                    ["name"] = "Tinkerer Gizlock",
                }, -- [3]
                {
                    ["id"] = 427,
                    ["image"] = 607699,
                    ["name"] = "Lord Vyletongue",
                }, -- [4]
                {
                    ["id"] = 428,
                    ["image"] = 607562,
                    ["name"] = "Celebras the Cursed",
                }, -- [5]
                {
                    ["id"] = 429,
                    ["image"] = 607684,
                    ["name"] = "Landslide",
                }, -- [6]
                {
                    ["id"] = 430,
                    ["image"] = 607761,
                    ["name"] = "Rotgrip",
                }, -- [7]
                {
                    ["id"] = 431,
                    ["image"] = 607747,
                    ["name"] = "Princess Theradras",
                }, -- [8]
            },
        }, -- [12]
        {
            ["id"] = 226,
            ["image"] = 608211,
            ["name"] = "Ragefire Chasm",
            ["bosses"] = {
                {
                    ["id"] = 694,
                    ["image"] = 608309,
                    ["name"] = "Adarogg",
                }, -- [1]
                {
                    ["id"] = 695,
                    ["image"] = 608310,
                    ["name"] = "Dark Shaman Koranthal",
                }, -- [2]
                {
                    ["id"] = 696,
                    ["image"] = 522251,
                    ["name"] = "Slagmaw",
                }, -- [3]
                {
                    ["id"] = 697,
                    ["image"] = 608315,
                    ["name"] = "Lava Guard Gordoth",
                }, -- [4]
            },
        }, -- [13]
        {
            ["id"] = 233,
            ["image"] = 608212,
            ["name"] = "Razorfen Downs",
            ["bosses"] = {
                {
                    ["id"] = 1142,
                    ["image"] = 607633,
                    ["name"] = "Aarux",
                }, -- [1]
                {
                    ["id"] = 433,
                    ["image"] = 607718,
                    ["name"] = "Mordresh Fire Eye",
                }, -- [2]
                {
                    ["id"] = 1143,
                    ["image"] = 1064178,
                    ["name"] = "Mushlump",
                }, -- [3]
                {
                    ["id"] = 1146,
                    ["image"] = 607584,
                    ["name"] = "Death Speaker Blackthorn",
                }, -- [4]
                {
                    ["id"] = 1141,
                    ["image"] = 607537,
                    ["name"] = "Amnennar the Coldbringer",
                }, -- [5]
            },
        }, -- [14]
        {
            ["id"] = 234,
            ["image"] = 608213,
            ["name"] = "Razorfen Kraul",
            ["bosses"] = {
                {
                    ["id"] = 896,
                    ["image"] = 607531,
                    ["name"] = "Hunter Bonetusk",
                }, -- [1]
                {
                    ["id"] = 895,
                    ["image"] = 607760,
                    ["name"] = "Roogug",
                }, -- [2]
                {
                    ["id"] = 899,
                    ["image"] = 607736,
                    ["name"] = "Warlord Ramtusk",
                }, -- [3]
                {
                    ["id"] = 900,
                    ["image"] = 1064175,
                    ["name"] = "Groyat, the Blind Hunter",
                }, -- [4]
                {
                    ["id"] = 901,
                    ["image"] = 607563,
                    ["name"] = "Charlga Razorflank",
                }, -- [5]
            },
        }, -- [15]
        {
            ["id"] = 311,
            ["image"] = 643262,
            ["name"] = "Scarlet Halls",
            ["bosses"] = {
                {
                    ["id"] = 660,
                    ["image"] = 630833,
                    ["name"] = "Houndmaster Braun",
                }, -- [1]
                {
                    ["id"] = 654,
                    ["image"] = 630816,
                    ["name"] = "Armsmaster Harlan",
                }, -- [2]
                {
                    ["id"] = 656,
                    ["image"] = 630825,
                    ["name"] = "Flameweaver Koegler",
                }, -- [3]
            },
        }, -- [16]
        {
            ["id"] = 316,
            ["image"] = 608214,
            ["name"] = "Scarlet Monastery",
            ["bosses"] = {
                {
                    ["id"] = 688,
                    ["image"] = 630853,
                    ["name"] = "Thalnos the Soulrender",
                }, -- [1]
                {
                    ["id"] = 671,
                    ["image"] = 630818,
                    ["name"] = "Brother Korloff",
                }, -- [2]
                {
                    ["id"] = 674,
                    ["image"] = 607643,
                    ["name"] = "High Inquisitor Whitemane",
                }, -- [3]
            },
        }, -- [17]
        {
            ["id"] = 246,
            ["image"] = 608215,
            ["name"] = "Scholomance",
            ["bosses"] = {
                {
                    ["id"] = 659,
                    ["image"] = 630835,
                    ["name"] = "Instructor Chillheart",
                }, -- [1]
                {
                    ["id"] = 663,
                    ["image"] = 607666,
                    ["name"] = "Jandice Barov",
                }, -- [2]
                {
                    ["id"] = 665,
                    ["image"] = 607755,
                    ["name"] = "Rattlegore",
                }, -- [3]
                {
                    ["id"] = 666,
                    ["image"] = 630838,
                    ["name"] = "Lilian Voss",
                }, -- [4]
                {
                    ["id"] = 684,
                    ["image"] = 607582,
                    ["name"] = "Darkmaster Gandling",
                }, -- [5]
            },
        }, -- [18]
        {
            ["id"] = 64,
            ["image"] = 522358,
            ["name"] = "Shadowfang Keep",
            ["bosses"] = {
                {
                    ["id"] = 96,
                    ["image"] = 522205,
                    ["name"] = "Baron Ashbury",
                }, -- [1]
                {
                    ["id"] = 97,
                    ["image"] = 522206,
                    ["name"] = "Baron Silverlaine",
                }, -- [2]
                {
                    ["id"] = 98,
                    ["image"] = 522213,
                    ["name"] = "Commander Springvale",
                }, -- [3]
                {
                    ["id"] = 99,
                    ["image"] = 522249,
                    ["name"] = "Lord Walden",
                }, -- [4]
                {
                    ["id"] = 100,
                    ["image"] = 522247,
                    ["name"] = "Lord Godfrey",
                }, -- [5]
            },
        }, -- [19]
        {
            ["id"] = 236,
            ["image"] = 608216,
            ["name"] = "Stratholme",
            ["bosses"] = {
                {
                    ["id"] = 443,
                    ["image"] = 607637,
                    ["name"] = "Hearthsinger Forresten",
                }, -- [1]
                {
                    ["id"] = 445,
                    ["image"] = 607795,
                    ["name"] = "Timmy the Cruel",
                }, -- [2]
                {
                    ["id"] = 749,
                    ["image"] = 607569,
                    ["name"] = "Commander Malor",
                }, -- [3]
                {
                    ["id"] = 446,
                    ["image"] = 607818,
                    ["name"] = "Willey Hopebreaker",
                }, -- [4]
                {
                    ["id"] = 448,
                    ["image"] = 607660,
                    ["name"] = "Instructor Galford",
                }, -- [5]
                {
                    ["id"] = 449,
                    ["image"] = 607551,
                    ["name"] = "Balnazzar",
                }, -- [6]
                {
                    ["id"] = 450,
                    ["image"] = 607792,
                    ["name"] = "The Unforgiven",
                }, -- [7]
                {
                    ["id"] = 451,
                    ["image"] = 607553,
                    ["name"] = "Baroness Anastari",
                }, -- [8]
                {
                    ["id"] = 452,
                    ["image"] = 607724,
                    ["name"] = "Nerub'enkan",
                }, -- [9]
                {
                    ["id"] = 453,
                    ["image"] = 607707,
                    ["name"] = "Maleki the Pallid",
                }, -- [10]
                {
                    ["id"] = 454,
                    ["image"] = 607791,
                    ["name"] = "Magistrate Barthilas",
                }, -- [11]
                {
                    ["id"] = 455,
                    ["image"] = 607752,
                    ["name"] = "Ramstein the Gorger",
                }, -- [12]
                {
                    ["id"] = 456,
                    ["image"] = 607692,
                    ["name"] = "Lord Aurius Rivendare",
                }, -- [13]
            },
        }, -- [20]
        {
            ["id"] = 238,
            ["image"] = 608223,
            ["name"] = "The Stockade",
            ["bosses"] = {
                {
                    ["id"] = 464,
                    ["image"] = 4776138,
                    ["name"] = "Hogger",
                }, -- [1]
                {
                    ["id"] = 465,
                    ["image"] = 607695,
                    ["name"] = "Lord Overheat",
                }, -- [2]
                {
                    ["id"] = 466,
                    ["image"] = 607753,
                    ["name"] = "Randolph Moloch",
                }, -- [3]
            },
        }, -- [21]
        {
            ["id"] = 237,
            ["image"] = 608217,
            ["name"] = "The Temple of Atal'hakkar",
            ["bosses"] = {
                {
                    ["id"] = 457,
                    ["image"] = 607548,
                    ["name"] = "Avatar of Hakkar",
                }, -- [1]
                {
                    ["id"] = 458,
                    ["image"] = 607665,
                    ["name"] = "Jammal'an the Prophet",
                }, -- [2]
                {
                    ["id"] = 459,
                    ["image"] = 608311,
                    ["name"] = "Wardens of the Dream",
                }, -- [3]
                {
                    ["id"] = 463,
                    ["image"] = 607768,
                    ["name"] = "Shade of Eranikus",
                }, -- [4]
            },
        }, -- [22]
        {
            ["id"] = 239,
            ["image"] = 608225,
            ["name"] = "Uldaman",
            ["bosses"] = {
                {
                    ["id"] = 467,
                    ["image"] = 607757,
                    ["name"] = "Revelosh",
                }, -- [1]
                {
                    ["id"] = 468,
                    ["image"] = 607550,
                    ["name"] = "The Lost Dwarves",
                }, -- [2]
                {
                    ["id"] = 469,
                    ["image"] = 607664,
                    ["name"] = "Ironaya",
                }, -- [3]
                {
                    ["id"] = 748,
                    ["image"] = 607729,
                    ["name"] = "Obsidian Sentinel",
                }, -- [4]
                {
                    ["id"] = 470,
                    ["image"] = 607538,
                    ["name"] = "Ancient Stone Keeper",
                }, -- [5]
                {
                    ["id"] = 471,
                    ["image"] = 607606,
                    ["name"] = "Galgann Firehammer",
                }, -- [6]
                {
                    ["id"] = 472,
                    ["image"] = 607626,
                    ["name"] = "Grimlok",
                }, -- [7]
                {
                    ["id"] = 473,
                    ["image"] = 607546,
                    ["name"] = "Archaedas",
                }, -- [8]
            },
        }, -- [23]
        {
            ["id"] = 240,
            ["image"] = 608229,
            ["name"] = "Wailing Caverns",
            ["bosses"] = {
                {
                    ["id"] = 474,
                    ["image"] = 607680,
                    ["name"] = "Lady Anacondra",
                }, -- [1]
                {
                    ["id"] = 476,
                    ["image"] = 607696,
                    ["name"] = "Lord Pythas",
                }, -- [2]
                {
                    ["id"] = 475,
                    ["image"] = 607693,
                    ["name"] = "Lord Cobrahn",
                }, -- [3]
                {
                    ["id"] = 477,
                    ["image"] = 607676,
                    ["name"] = "Kresh",
                }, -- [4]
                {
                    ["id"] = 478,
                    ["image"] = 607775,
                    ["name"] = "Skum",
                }, -- [5]
                {
                    ["id"] = 479,
                    ["image"] = 607698,
                    ["name"] = "Lord Serpentis",
                }, -- [6]
                {
                    ["id"] = 480,
                    ["image"] = 607805,
                    ["name"] = "Verdan the Everliving",
                }, -- [7]
                {
                    ["id"] = 481,
                    ["image"] = 607721,
                    ["name"] = "Mutanus the Devourer",
                }, -- [8]
            },
        }, -- [24]
        {
            ["id"] = 241,
            ["image"] = 608230,
            ["name"] = "Zul'Farrak",
            ["bosses"] = {
                {
                    ["id"] = 483,
                    ["image"] = 607614,
                    ["name"] = "Gahz'rilla",
                }, -- [1]
                {
                    ["id"] = 484,
                    ["image"] = 607541,
                    ["name"] = "Antu'sul",
                }, -- [2]
                {
                    ["id"] = 485,
                    ["image"] = 607793,
                    ["name"] = "Theka the Martyr",
                }, -- [3]
                {
                    ["id"] = 486,
                    ["image"] = 607819,
                    ["name"] = "Witch Doctor Zum'rah",
                }, -- [4]
                {
                    ["id"] = 487,
                    ["image"] = 607723,
                    ["name"] = "Nekrum & Sezz'ziz",
                }, -- [5]
                {
                    ["id"] = 489,
                    ["image"] = 607564,
                    ["name"] = "Chief Ukorz Sandscalp",
                }, -- [6]
            },
        }, -- [25]
    },
    ["Burning Crusade"] = {
        {
            ["id"] = 745,
            ["image"] = 1396584,
            ["name"] = "Karazhan",
            ["bosses"] = {
                {
                    ["id"] = 1552,
                    ["image"] = 1385766,
                    ["name"] = "Servant's Quarters",
                }, -- [1]
                {
                    ["id"] = 1553,
                    ["image"] = 1378965,
                    ["name"] = "Attumen the Huntsman",
                }, -- [2]
                {
                    ["id"] = 1554,
                    ["image"] = 1378999,
                    ["name"] = "Moroes",
                }, -- [3]
                {
                    ["id"] = 1555,
                    ["image"] = 1378997,
                    ["name"] = "Maiden of Virtue",
                }, -- [4]
                {
                    ["id"] = 1556,
                    ["image"] = 1385758,
                    ["name"] = "Opera Hall",
                }, -- [5]
                {
                    ["id"] = 1557,
                    ["image"] = 1379020,
                    ["name"] = "The Curator",
                }, -- [6]
                {
                    ["id"] = 1559,
                    ["image"] = 1379012,
                    ["name"] = "Shade of Aran",
                }, -- [7]
                {
                    ["id"] = 1560,
                    ["image"] = 1379017,
                    ["name"] = "Terestian Illhoof",
                }, -- [8]
                {
                    ["id"] = 1561,
                    ["image"] = 1379002,
                    ["name"] = "Netherspite",
                }, -- [9]
                {
                    ["id"] = 1764,
                    ["image"] = 1385724,
                    ["name"] = "Chess Event",
                }, -- [10]
                {
                    ["id"] = 1563,
                    ["image"] = 1379006,
                    ["name"] = "Prince Malchezaar",
                }, -- [11]
            },
        }, -- [1]
        {
            ["id"] = 746,
            ["image"] = 1396582,
            ["name"] = "Gruul's Lair",
            ["bosses"] = {
                {
                    ["id"] = 1564,
                    ["image"] = 1378985,
                    ["name"] = "High King Maulgar",
                }, -- [1]
                {
                    ["id"] = 1565,
                    ["image"] = 1378982,
                    ["name"] = "Gruul the Dragonkiller",
                }, -- [2]
            },
        }, -- [2]
        {
            ["id"] = 747,
            ["image"] = 1396585,
            ["name"] = "Magtheridon's Lair",
            ["bosses"] = {
                {
                    ["id"] = 1566,
                    ["image"] = 1378996,
                    ["name"] = "Magtheridon",
                }, -- [1]
            },
        }, -- [3]
        {
            ["id"] = 748,
            ["image"] = 608199,
            ["name"] = "Serpentshrine Cavern",
            ["bosses"] = {
                {
                    ["id"] = 1567,
                    ["image"] = 1385741,
                    ["name"] = "Hydross the Unstable",
                }, -- [1]
                {
                    ["id"] = 1568,
                    ["image"] = 1385768,
                    ["name"] = "The Lurker Below",
                }, -- [2]
                {
                    ["id"] = 1569,
                    ["image"] = 1385751,
                    ["name"] = "Leotheras the Blind",
                }, -- [3]
                {
                    ["id"] = 1570,
                    ["image"] = 1385729,
                    ["name"] = "Fathom-Lord Karathress",
                }, -- [4]
                {
                    ["id"] = 1571,
                    ["image"] = 1385756,
                    ["name"] = "Morogrim Tidewalker",
                }, -- [5]
                {
                    ["id"] = 1572,
                    ["image"] = 1385750,
                    ["name"] = "Lady Vashj",
                }, -- [6]
            },
        }, -- [4]
        {
            ["id"] = 749,
            ["image"] = 608218,
            ["name"] = "The Eye",
            ["bosses"] = {
                {
                    ["id"] = 1573,
                    ["image"] = 1385712,
                    ["name"] = "Al'ar",
                }, -- [1]
                {
                    ["id"] = 1574,
                    ["image"] = 1385772,
                    ["name"] = "Void Reaver",
                }, -- [2]
                {
                    ["id"] = 1575,
                    ["image"] = 1385739,
                    ["name"] = "High Astromancer Solarian",
                }, -- [3]
                {
                    ["id"] = 1576,
                    ["image"] = 607669,
                    ["name"] = "Kael'thas Sunstrider",
                }, -- [4]
            },
        }, -- [5]
        {
            ["id"] = 750,
            ["image"] = 608198,
            ["name"] = "The Battle for Mount Hyjal",
            ["bosses"] = {
                {
                    ["id"] = 1577,
                    ["image"] = 1385762,
                    ["name"] = "Rage Winterchill",
                }, -- [1]
                {
                    ["id"] = 1578,
                    ["image"] = 1385714,
                    ["name"] = "Anetheron",
                }, -- [2]
                {
                    ["id"] = 1579,
                    ["image"] = 1385745,
                    ["name"] = "Kaz'rogal",
                }, -- [3]
                {
                    ["id"] = 1580,
                    ["image"] = 1385719,
                    ["name"] = "Azgalor",
                }, -- [4]
                {
                    ["id"] = 1581,
                    ["image"] = 1385716,
                    ["name"] = "Archimonde",
                }, -- [5]
            },
        }, -- [6]
        {
            ["id"] = 751,
            ["image"] = 1396579,
            ["name"] = "Black Temple",
            ["bosses"] = {
                {
                    ["id"] = 1582,
                    ["image"] = 1378986,
                    ["name"] = "High Warlord Naj'entus",
                }, -- [1]
                {
                    ["id"] = 1583,
                    ["image"] = 1379016,
                    ["name"] = "Supremus",
                }, -- [2]
                {
                    ["id"] = 1584,
                    ["image"] = 1379011,
                    ["name"] = "Shade of Akama",
                }, -- [3]
                {
                    ["id"] = 1585,
                    ["image"] = 1379018,
                    ["name"] = "Teron Gorefiend",
                }, -- [4]
                {
                    ["id"] = 1586,
                    ["image"] = 1378983,
                    ["name"] = "Gurtogg Bloodboil",
                }, -- [5]
                {
                    ["id"] = 1587,
                    ["image"] = 1385764,
                    ["name"] = "Reliquary of Souls",
                }, -- [6]
                {
                    ["id"] = 1588,
                    ["image"] = 1379000,
                    ["name"] = "Mother Shahraz",
                }, -- [7]
                {
                    ["id"] = 1589,
                    ["image"] = 1385743,
                    ["name"] = "The Illidari Council",
                }, -- [8]
                {
                    ["id"] = 1590,
                    ["image"] = 1378987,
                    ["name"] = "Illidan Stormrage",
                }, -- [9]
            },
        }, -- [7]
        {
            ["id"] = 752,
            ["image"] = 1396592,
            ["name"] = "Sunwell Plateau",
            ["bosses"] = {
                {
                    ["id"] = 1591,
                    ["image"] = 1385744,
                    ["name"] = "Kalecgos",
                }, -- [1]
                {
                    ["id"] = 1592,
                    ["image"] = 1385722,
                    ["name"] = "Brutallus",
                }, -- [2]
                {
                    ["id"] = 1593,
                    ["image"] = 1385730,
                    ["name"] = "Felmyst",
                }, -- [3]
                {
                    ["id"] = 1594,
                    ["image"] = 1390438,
                    ["name"] = "The Eredar Twins",
                }, -- [4]
                {
                    ["id"] = 1595,
                    ["image"] = 1385757,
                    ["name"] = "M'uru",
                }, -- [5]
                {
                    ["id"] = 1596,
                    ["image"] = 1385746,
                    ["name"] = "Kil'jaeden",
                }, -- [6]
            },
        }, -- [8]
        {
            ["id"] = 247,
            ["image"] = 608193,
            ["name"] = "Auchenai Crypts",
            ["bosses"] = {
                {
                    ["id"] = 523,
                    ["image"] = 607771,
                    ["name"] = "Shirrak the Dead Watcher",
                }, -- [1]
                {
                    ["id"] = 524,
                    ["image"] = 607600,
                    ["name"] = "Exarch Maladaar",
                }, -- [2]
            },
        }, -- [9]
        {
            ["id"] = 248,
            ["image"] = 608207,
            ["name"] = "Hellfire Ramparts",
            ["bosses"] = {
                {
                    ["id"] = 527,
                    ["image"] = 607817,
                    ["name"] = "Watchkeeper Gargolmar",
                }, -- [1]
                {
                    ["id"] = 528,
                    ["image"] = 607734,
                    ["name"] = "Omor the Unscarred",
                }, -- [2]
                {
                    ["id"] = 529,
                    ["image"] = 607803,
                    ["name"] = "Vazruden the Herald",
                }, -- [3]
            },
        }, -- [10]
        {
            ["id"] = 249,
            ["image"] = 608208,
            ["name"] = "Magisters' Terrace",
            ["bosses"] = {
                {
                    ["id"] = 530,
                    ["image"] = 607767,
                    ["name"] = "Selin Fireheart",
                }, -- [1]
                {
                    ["id"] = 531,
                    ["image"] = 607806,
                    ["name"] = "Vexallus",
                }, -- [2]
                {
                    ["id"] = 532,
                    ["image"] = 607742,
                    ["name"] = "Priestess Delrissa",
                }, -- [3]
                {
                    ["id"] = 533,
                    ["image"] = 607669,
                    ["name"] = "Kael'thas Sunstrider",
                }, -- [4]
            },
        }, -- [11]
        {
            ["id"] = 250,
            ["image"] = 608193,
            ["name"] = "Mana-Tombs",
            ["bosses"] = {
                {
                    ["id"] = 534,
                    ["image"] = 607738,
                    ["name"] = "Pandemonius",
                }, -- [1]
                {
                    ["id"] = 535,
                    ["image"] = 607782,
                    ["name"] = "Tavarok",
                }, -- [2]
                {
                    ["id"] = 537,
                    ["image"] = 607726,
                    ["name"] = "Nexus-Prince Shaffar",
                }, -- [3]
            },
        }, -- [12]
        {
            ["id"] = 251,
            ["image"] = 608198,
            ["name"] = "Old Hillsbrad Foothills",
            ["bosses"] = {
                {
                    ["id"] = 538,
                    ["image"] = 607689,
                    ["name"] = "Lieutenant Drake",
                }, -- [1]
                {
                    ["id"] = 539,
                    ["image"] = 607561,
                    ["name"] = "Captain Skarloc",
                }, -- [2]
                {
                    ["id"] = 540,
                    ["image"] = 607596,
                    ["name"] = "Epoch Hunter",
                }, -- [3]
            },
        }, -- [13]
        {
            ["id"] = 252,
            ["image"] = 608193,
            ["name"] = "Sethekk Halls",
            ["bosses"] = {
                {
                    ["id"] = 541,
                    ["image"] = 607583,
                    ["name"] = "Darkweaver Syth",
                }, -- [1]
                {
                    ["id"] = 543,
                    ["image"] = 607780,
                    ["name"] = "Talon King Ikiss",
                }, -- [2]
            },
        }, -- [14]
        {
            ["id"] = 253,
            ["image"] = 608193,
            ["name"] = "Shadow Labyrinth",
            ["bosses"] = {
                {
                    ["id"] = 544,
                    ["image"] = 607536,
                    ["name"] = "Ambassador Hellmaw",
                }, -- [1]
                {
                    ["id"] = 545,
                    ["image"] = 607555,
                    ["name"] = "Blackheart the Inciter",
                }, -- [2]
                {
                    ["id"] = 546,
                    ["image"] = 607625,
                    ["name"] = "Grandmaster Vorpil",
                }, -- [3]
                {
                    ["id"] = 547,
                    ["image"] = 607720,
                    ["name"] = "Murmur",
                }, -- [4]
            },
        }, -- [15]
        {
            ["id"] = 254,
            ["image"] = 608218,
            ["name"] = "The Arcatraz",
            ["bosses"] = {
                {
                    ["id"] = 548,
                    ["image"] = 607823,
                    ["name"] = "Zereketh the Unbound",
                }, -- [1]
                {
                    ["id"] = 549,
                    ["image"] = 607574,
                    ["name"] = "Dalliah the Doomsayer",
                }, -- [2]
                {
                    ["id"] = 550,
                    ["image"] = 607820,
                    ["name"] = "Wrath-Scryer Soccothrates",
                }, -- [3]
                {
                    ["id"] = 551,
                    ["image"] = 607635,
                    ["name"] = "Harbinger Skyriss",
                }, -- [4]
            },
        }, -- [16]
        {
            ["id"] = 255,
            ["image"] = 608198,
            ["name"] = "The Black Morass",
            ["bosses"] = {
                {
                    ["id"] = 552,
                    ["image"] = 607566,
                    ["name"] = "Chrono Lord Deja",
                }, -- [1]
                {
                    ["id"] = 553,
                    ["image"] = 607784,
                    ["name"] = "Temporus",
                }, -- [2]
                {
                    ["id"] = 554,
                    ["image"] = 607529,
                    ["name"] = "Aeonus",
                }, -- [3]
            },
        }, -- [17]
        {
            ["id"] = 256,
            ["image"] = 608207,
            ["name"] = "The Blood Furnace",
            ["bosses"] = {
                {
                    ["id"] = 555,
                    ["image"] = 607789,
                    ["name"] = "The Maker",
                }, -- [1]
                {
                    ["id"] = 556,
                    ["image"] = 607558,
                    ["name"] = "Broggok",
                }, -- [2]
                {
                    ["id"] = 557,
                    ["image"] = 607670,
                    ["name"] = "Keli'dan the Breaker",
                }, -- [3]
            },
        }, -- [18]
        {
            ["id"] = 257,
            ["image"] = 608218,
            ["name"] = "The Botanica",
            ["bosses"] = {
                {
                    ["id"] = 558,
                    ["image"] = 607570,
                    ["name"] = "Commander Sarannis",
                }, -- [1]
                {
                    ["id"] = 559,
                    ["image"] = 607641,
                    ["name"] = "High Botanist Freywinn",
                }, -- [2]
                {
                    ["id"] = 560,
                    ["image"] = 607794,
                    ["name"] = "Thorngrin the Tender",
                }, -- [3]
                {
                    ["id"] = 561,
                    ["image"] = 607683,
                    ["name"] = "Laj",
                }, -- [4]
                {
                    ["id"] = 562,
                    ["image"] = 607816,
                    ["name"] = "Warp Splinter",
                }, -- [5]
            },
        }, -- [19]
        {
            ["id"] = 258,
            ["image"] = 608218,
            ["name"] = "The Mechanar",
            ["bosses"] = {
                {
                    ["id"] = 563,
                    ["image"] = 607712,
                    ["name"] = "Mechano-Lord Capacitus",
                }, -- [1]
                {
                    ["id"] = 564,
                    ["image"] = 607725,
                    ["name"] = "Nethermancer Sepethrea",
                }, -- [2]
                {
                    ["id"] = 565,
                    ["image"] = 607739,
                    ["name"] = "Pathaleon the Calculator",
                }, -- [3]
            },
        }, -- [20]
        {
            ["id"] = 259,
            ["image"] = 608207,
            ["name"] = "The Shattered Halls",
            ["bosses"] = {
                {
                    ["id"] = 566,
                    ["image"] = 607624,
                    ["name"] = "Grand Warlock Nethekurse",
                }, -- [1]
                {
                    ["id"] = 568,
                    ["image"] = 607811,
                    ["name"] = "Warbringer O'mrogg",
                }, -- [2]
                {
                    ["id"] = 569,
                    ["image"] = 607812,
                    ["name"] = "Warchief Kargath Bladefist",
                }, -- [3]
            },
        }, -- [21]
        {
            ["id"] = 260,
            ["image"] = 608199,
            ["name"] = "The Slave Pens",
            ["bosses"] = {
                {
                    ["id"] = 570,
                    ["image"] = 607715,
                    ["name"] = "Mennu the Betrayer",
                }, -- [1]
                {
                    ["id"] = 571,
                    ["image"] = 607759,
                    ["name"] = "Rokmar the Crackler",
                }, -- [2]
                {
                    ["id"] = 572,
                    ["image"] = 607750,
                    ["name"] = "Quagmirran",
                }, -- [3]
            },
        }, -- [22]
        {
            ["id"] = 261,
            ["image"] = 608199,
            ["name"] = "The Steamvault",
            ["bosses"] = {
                {
                    ["id"] = 573,
                    ["image"] = 607651,
                    ["name"] = "Hydromancer Thespia",
                }, -- [1]
                {
                    ["id"] = 574,
                    ["image"] = 607713,
                    ["name"] = "Mekgineer Steamrigger",
                }, -- [2]
                {
                    ["id"] = 575,
                    ["image"] = 607815,
                    ["name"] = "Warlord Kalithresh",
                }, -- [3]
            },
        }, -- [23]
        {
            ["id"] = 262,
            ["image"] = 608199,
            ["name"] = "The Underbog",
            ["bosses"] = {
                {
                    ["id"] = 576,
                    ["image"] = 607649,
                    ["name"] = "Hungarfen",
                }, -- [1]
                {
                    ["id"] = 577,
                    ["image"] = 607614,
                    ["name"] = "Ghaz'an",
                }, -- [2]
                {
                    ["id"] = 578,
                    ["image"] = 607779,
                    ["name"] = "Swamplord Musel'ek",
                }, -- [3]
                {
                    ["id"] = 579,
                    ["image"] = 607788,
                    ["name"] = "The Black Stalker",
                }, -- [4]
            },
        }, -- [24]
    },
    ["Wrath of the Lich King"] = {
        {
            ["id"] = 753,
            ["image"] = 1396596,
            ["name"] = "Vault of Archavon",
            ["bosses"] = {
                {
                    ["id"] = 1597,
                    ["image"] = 1385715,
                    ["name"] = "Archavon the Stone Watcher",
                }, -- [1]
                {
                    ["id"] = 1598,
                    ["image"] = 1385727,
                    ["name"] = "Emalon the Storm Watcher",
                }, -- [2]
                {
                    ["id"] = 1599,
                    ["image"] = 1385748,
                    ["name"] = "Koralon the Flame Watcher",
                }, -- [3]
                {
                    ["id"] = 1600,
                    ["image"] = 1385767,
                    ["name"] = "Toravon the Ice Watcher",
                }, -- [4]
            },
        }, -- [1]
        {
            ["id"] = 754,
            ["image"] = 1396587,
            ["name"] = "Naxxramas",
            ["bosses"] = {
                {
                    ["id"] = 1601,
                    ["image"] = 1378964,
                    ["name"] = "Anub'Rekhan",
                }, -- [1]
                {
                    ["id"] = 1602,
                    ["image"] = 1378980,
                    ["name"] = "Grand Widow Faerlina",
                }, -- [2]
                {
                    ["id"] = 1603,
                    ["image"] = 1378994,
                    ["name"] = "Maexxna",
                }, -- [3]
                {
                    ["id"] = 1604,
                    ["image"] = 1379004,
                    ["name"] = "Noth the Plaguebringer",
                }, -- [4]
                {
                    ["id"] = 1605,
                    ["image"] = 1378984,
                    ["name"] = "Heigan the Unclean",
                }, -- [5]
                {
                    ["id"] = 1606,
                    ["image"] = 1378991,
                    ["name"] = "Loatheb",
                }, -- [6]
                {
                    ["id"] = 1607,
                    ["image"] = 1378988,
                    ["name"] = "Instructor Razuvious",
                }, -- [7]
                {
                    ["id"] = 1608,
                    ["image"] = 1378979,
                    ["name"] = "Gothik the Harvester",
                }, -- [8]
                {
                    ["id"] = 1609,
                    ["image"] = 1385732,
                    ["name"] = "The Four Horsemen",
                }, -- [9]
                {
                    ["id"] = 1610,
                    ["image"] = 1379005,
                    ["name"] = "Patchwerk",
                }, -- [10]
                {
                    ["id"] = 1611,
                    ["image"] = 1378981,
                    ["name"] = "Grobbulus",
                }, -- [11]
                {
                    ["id"] = 1612,
                    ["image"] = 1378977,
                    ["name"] = "Gluth",
                }, -- [12]
                {
                    ["id"] = 1613,
                    ["image"] = 1379019,
                    ["name"] = "Thaddius",
                }, -- [13]
                {
                    ["id"] = 1614,
                    ["image"] = 1379010,
                    ["name"] = "Sapphiron",
                }, -- [14]
                {
                    ["id"] = 1615,
                    ["image"] = 1378989,
                    ["name"] = "Kel'Thuzad",
                }, -- [15]
            },
        }, -- [2]
        {
            ["id"] = 755,
            ["image"] = 1396588,
            ["name"] = "The Obsidian Sanctum",
            ["bosses"] = {
                {
                    ["id"] = 1616,
                    ["image"] = 1385765,
                    ["name"] = "Sartharion",
                }, -- [1]
            },
        }, -- [3]
        {
            ["id"] = 756,
            ["image"] = 1396581,
            ["name"] = "The Eye of Eternity",
            ["bosses"] = {
                {
                    ["id"] = 1617,
                    ["image"] = 1385753,
                    ["name"] = "Malygos",
                }, -- [1]
            },
        }, -- [4]
        {
            ["id"] = 759,
            ["image"] = 1396595,
            ["name"] = "Ulduar",
            ["bosses"] = {
                {
                    ["id"] = 1637,
                    ["image"] = 1385731,
                    ["name"] = "Flame Leviathan",
                }, -- [1]
                {
                    ["id"] = 1638,
                    ["image"] = 1385742,
                    ["name"] = "Ignis the Furnace Master",
                }, -- [2]
                {
                    ["id"] = 1639,
                    ["image"] = 1385763,
                    ["name"] = "Razorscale",
                }, -- [3]
                {
                    ["id"] = 1640,
                    ["image"] = 1385773,
                    ["name"] = "XT-002 Deconstructor",
                }, -- [4]
                {
                    ["id"] = 1641,
                    ["image"] = 1390439,
                    ["name"] = "The Assembly of Iron",
                }, -- [5]
                {
                    ["id"] = 1642,
                    ["image"] = 1385747,
                    ["name"] = "Kologarn",
                }, -- [6]
                {
                    ["id"] = 1643,
                    ["image"] = 1385717,
                    ["name"] = "Auriaya",
                }, -- [7]
                {
                    ["id"] = 1644,
                    ["image"] = 1385740,
                    ["name"] = "Hodir",
                }, -- [8]
                {
                    ["id"] = 1645,
                    ["image"] = 1385770,
                    ["name"] = "Thorim",
                }, -- [9]
                {
                    ["id"] = 1646,
                    ["image"] = 1385733,
                    ["name"] = "Freya",
                }, -- [10]
                {
                    ["id"] = 1647,
                    ["image"] = 1385754,
                    ["name"] = "Mimiron",
                }, -- [11]
                {
                    ["id"] = 1648,
                    ["image"] = 1385735,
                    ["name"] = "General Vezax",
                }, -- [12]
                {
                    ["id"] = 1649,
                    ["image"] = 1385774,
                    ["name"] = "Yogg-Saron",
                }, -- [13]
                {
                    ["id"] = 1650,
                    ["image"] = 1385713,
                    ["name"] = "Algalon the Observer",
                }, -- [14]
            },
        }, -- [5]
        {
            ["id"] = 757,
            ["image"] = 1396594,
            ["name"] = "Trial of the Crusader",
            ["bosses"] = {
                {
                    ["id"] = 1618,
                    ["image"] = 1390440,
                    ["name"] = "The Northrend Beasts",
                }, -- [1]
                {
                    ["id"] = 1619,
                    ["image"] = 1385752,
                    ["name"] = "Lord Jaraxxus",
                }, -- [2]
                {
                    ["id"] = 1620,
                    ["image"] = 1390442,
                    ["name"] = "Champions of the Alliance",
                }, -- [3]
                {
                    ["id"] = 1622,
                    ["image"] = 1390443,
                    ["name"] = "Twin Val'kyr",
                }, -- [4]
                {
                    ["id"] = 1623,
                    ["image"] = 607542,
                    ["name"] = "Anub'arak",
                }, -- [5]
            },
        }, -- [6]
        {
            ["id"] = 760,
            ["image"] = 1396589,
            ["name"] = "Onyxia's Lair",
            ["bosses"] = {
                {
                    ["id"] = 1651,
                    ["image"] = 1379025,
                    ["name"] = "Onyxia",
                }, -- [1]
            },
        }, -- [7]
        {
            ["id"] = 758,
            ["image"] = 1396583,
            ["name"] = "Icecrown Citadel",
            ["bosses"] = {
                {
                    ["id"] = 1624,
                    ["image"] = 1378992,
                    ["name"] = "Lord Marrowgar",
                }, -- [1]
                {
                    ["id"] = 1625,
                    ["image"] = 1378990,
                    ["name"] = "Lady Deathwhisper",
                }, -- [2]
                {
                    ["id"] = 1627,
                    ["image"] = 1385736,
                    ["name"] = "Icecrown Gunship Battle",
                }, -- [3]
                {
                    ["id"] = 1628,
                    ["image"] = 1378970,
                    ["name"] = "Deathbringer Saurfang",
                }, -- [4]
                {
                    ["id"] = 1629,
                    ["image"] = 1378972,
                    ["name"] = "Festergut",
                }, -- [5]
                {
                    ["id"] = 1630,
                    ["image"] = 1379009,
                    ["name"] = "Rotface",
                }, -- [6]
                {
                    ["id"] = 1631,
                    ["image"] = 1379007,
                    ["name"] = "Professor Putricide",
                }, -- [7]
                {
                    ["id"] = 1632,
                    ["image"] = 1385721,
                    ["name"] = "Blood Prince Council",
                }, -- [8]
                {
                    ["id"] = 1633,
                    ["image"] = 1378967,
                    ["name"] = "Blood-Queen Lana'thel",
                }, -- [9]
                {
                    ["id"] = 1634,
                    ["image"] = 1379023,
                    ["name"] = "Valithria Dreamwalker",
                }, -- [10]
                {
                    ["id"] = 1635,
                    ["image"] = 1379014,
                    ["name"] = "Sindragosa",
                }, -- [11]
                {
                    ["id"] = 1636,
                    ["image"] = 607688,
                    ["name"] = "The Lich King",
                }, -- [12]
            },
        }, -- [8]
        {
            ["id"] = 761,
            ["image"] = 1396590,
            ["name"] = "The Ruby Sanctum",
            ["bosses"] = {
                {
                    ["id"] = 1652,
                    ["image"] = 1385738,
                    ["name"] = "Halion",
                }, -- [1]
            },
        }, -- [9]
        {
            ["id"] = 271,
            ["image"] = 608192,
            ["name"] = "Ahn'kahet: The Old Kingdom",
            ["bosses"] = {
                {
                    ["id"] = 580,
                    ["image"] = 607593,
                    ["name"] = "Elder Nadox",
                }, -- [1]
                {
                    ["id"] = 581,
                    ["image"] = 607744,
                    ["name"] = "Prince Taldaram",
                }, -- [2]
                {
                    ["id"] = 582,
                    ["image"] = 607667,
                    ["name"] = "Jedoga Shadowseeker",
                }, -- [3]
                {
                    ["id"] = 584,
                    ["image"] = 607639,
                    ["name"] = "Herald Volazj",
                }, -- [4]
            },
        }, -- [10]
        {
            ["id"] = 272,
            ["image"] = 608194,
            ["name"] = "Azjol-Nerub",
            ["bosses"] = {
                {
                    ["id"] = 585,
                    ["image"] = 607678,
                    ["name"] = "Krik'thir the Gatewatcher",
                }, -- [1]
                {
                    ["id"] = 586,
                    ["image"] = 607633,
                    ["name"] = "Hadronox",
                }, -- [2]
                {
                    ["id"] = 587,
                    ["image"] = 607542,
                    ["name"] = "Anub'arak",
                }, -- [3]
            },
        }, -- [11]
        {
            ["id"] = 273,
            ["image"] = 608201,
            ["name"] = "Drak'Tharon Keep",
            ["bosses"] = {
                {
                    ["id"] = 588,
                    ["image"] = 607798,
                    ["name"] = "Trollgore",
                }, -- [1]
                {
                    ["id"] = 589,
                    ["image"] = 607727,
                    ["name"] = "Novos the Summoner",
                }, -- [2]
                {
                    ["id"] = 590,
                    ["image"] = 607672,
                    ["name"] = "King Dred",
                }, -- [3]
                {
                    ["id"] = 591,
                    ["image"] = 607790,
                    ["name"] = "The Prophet Tharon'ja",
                }, -- [4]
            },
        }, -- [12]
        {
            ["id"] = 274,
            ["image"] = 608203,
            ["name"] = "Gundrak",
            ["bosses"] = {
                {
                    ["id"] = 592,
                    ["image"] = 607776,
                    ["name"] = "Slad'ran",
                }, -- [1]
                {
                    ["id"] = 593,
                    ["image"] = 607589,
                    ["name"] = "Drakkari Colossus",
                }, -- [2]
                {
                    ["id"] = 594,
                    ["image"] = 607716,
                    ["name"] = "Moorabi",
                }, -- [3]
                {
                    ["id"] = 596,
                    ["image"] = 607605,
                    ["name"] = "Gal'darah",
                }, -- [4]
            },
        }, -- [13]
        {
            ["id"] = 275,
            ["image"] = 608204,
            ["name"] = "Halls of Lightning",
            ["bosses"] = {
                {
                    ["id"] = 597,
                    ["image"] = 607611,
                    ["name"] = "General Bjarngrim",
                }, -- [1]
                {
                    ["id"] = 598,
                    ["image"] = 607809,
                    ["name"] = "Volkhan",
                }, -- [2]
                {
                    ["id"] = 599,
                    ["image"] = 607663,
                    ["name"] = "Ionar",
                }, -- [3]
                {
                    ["id"] = 600,
                    ["image"] = 607690,
                    ["name"] = "Loken",
                }, -- [4]
            },
        }, -- [14]
        {
            ["id"] = 276,
            ["image"] = 608205,
            ["name"] = "Halls of Reflection",
            ["bosses"] = {
                {
                    ["id"] = 601,
                    ["image"] = 607601,
                    ["name"] = "Falric",
                }, -- [1]
                {
                    ["id"] = 602,
                    ["image"] = 607710,
                    ["name"] = "Marwyn",
                }, -- [2]
                {
                    ["id"] = 603,
                    ["image"] = 607688,
                    ["name"] = "Escape from Arthas",
                }, -- [3]
            },
        }, -- [15]
        {
            ["id"] = 277,
            ["image"] = 608206,
            ["name"] = "Halls of Stone",
            ["bosses"] = {
                {
                    ["id"] = 604,
                    ["image"] = 607679,
                    ["name"] = "Krystallus",
                }, -- [1]
                {
                    ["id"] = 605,
                    ["image"] = 607706,
                    ["name"] = "Maiden of Grief",
                }, -- [2]
                {
                    ["id"] = 606,
                    ["image"] = 607797,
                    ["name"] = "Tribunal of Ages",
                }, -- [3]
                {
                    ["id"] = 607,
                    ["image"] = 607772,
                    ["name"] = "Sjonnir the Ironshaper",
                }, -- [4]
            },
        }, -- [16]
        {
            ["id"] = 278,
            ["image"] = 608210,
            ["name"] = "Pit of Saron",
            ["bosses"] = {
                {
                    ["id"] = 608,
                    ["image"] = 607603,
                    ["name"] = "Forgemaster Garfrost",
                }, -- [1]
                {
                    ["id"] = 609,
                    ["image"] = 607677,
                    ["name"] = "Ick & Krick",
                }, -- [2]
                {
                    ["id"] = 610,
                    ["image"] = 607765,
                    ["name"] = "Scourgelord Tyrannus",
                }, -- [3]
            },
        }, -- [17]
        {
            ["id"] = 279,
            ["image"] = 608219,
            ["name"] = "The Culling of Stratholme",
            ["bosses"] = {
                {
                    ["id"] = 611,
                    ["image"] = 607711,
                    ["name"] = "Meathook",
                }, -- [1]
                {
                    ["id"] = 612,
                    ["image"] = 607763,
                    ["name"] = "Salramm the Fleshcrafter",
                }, -- [2]
                {
                    ["id"] = 613,
                    ["image"] = 607567,
                    ["name"] = "Chrono-Lord Epoch",
                }, -- [3]
                {
                    ["id"] = 614,
                    ["image"] = 607708,
                    ["name"] = "Mal'Ganis",
                }, -- [4]
            },
        }, -- [18]
        {
            ["id"] = 280,
            ["image"] = 608220,
            ["name"] = "The Forge of Souls",
            ["bosses"] = {
                {
                    ["id"] = 615,
                    ["image"] = 607559,
                    ["name"] = "Bronjahm",
                }, -- [1]
                {
                    ["id"] = 616,
                    ["image"] = 607585,
                    ["name"] = "Devourer of Souls",
                }, -- [2]
            },
        }, -- [19]
        {
            ["id"] = 281,
            ["image"] = 608221,
            ["name"] = "The Nexus",
            ["bosses"] = {
                {
                    ["id"] = 618,
                    ["image"] = 607623,
                    ["name"] = "Grand Magus Telestra",
                }, -- [1]
                {
                    ["id"] = 619,
                    ["image"] = 607540,
                    ["name"] = "Anomalus",
                }, -- [2]
                {
                    ["id"] = 620,
                    ["image"] = 607735,
                    ["name"] = "Ormorok the Tree-Shaper",
                }, -- [3]
                {
                    ["id"] = 621,
                    ["image"] = 607671,
                    ["name"] = "Keristrasza",
                }, -- [4]
            },
        }, -- [20]
        {
            ["id"] = 282,
            ["image"] = 608222,
            ["name"] = "The Oculus",
            ["bosses"] = {
                {
                    ["id"] = 622,
                    ["image"] = 607590,
                    ["name"] = "Drakos the Interrogator",
                }, -- [1]
                {
                    ["id"] = 623,
                    ["image"] = 607802,
                    ["name"] = "Varos Cloudstrider",
                }, -- [2]
                {
                    ["id"] = 624,
                    ["image"] = 607702,
                    ["name"] = "Mage-Lord Urom",
                }, -- [3]
                {
                    ["id"] = 625,
                    ["image"] = 607687,
                    ["name"] = "Ley-Guardian Eregos",
                }, -- [4]
            },
        }, -- [21]
        {
            ["id"] = 283,
            ["image"] = 608228,
            ["name"] = "The Violet Hold",
            ["bosses"] = {
                {
                    ["id"] = 626,
                    ["image"] = 607597,
                    ["name"] = "Erekem",
                }, -- [1]
                {
                    ["id"] = 627,
                    ["image"] = 607717,
                    ["name"] = "Moragg",
                }, -- [2]
                {
                    ["id"] = 628,
                    ["image"] = 607654,
                    ["name"] = "Ichoron",
                }, -- [3]
                {
                    ["id"] = 629,
                    ["image"] = 607821,
                    ["name"] = "Xevozz",
                }, -- [4]
                {
                    ["id"] = 630,
                    ["image"] = 607685,
                    ["name"] = "Lavanthor",
                }, -- [5]
                {
                    ["id"] = 631,
                    ["image"] = 607825,
                    ["name"] = "Zuramat the Obliterator",
                }, -- [6]
                {
                    ["id"] = 632,
                    ["image"] = 607573,
                    ["name"] = "Cyanigosa",
                }, -- [7]
            },
        }, -- [22]
        {
            ["id"] = 284,
            ["image"] = 608224,
            ["name"] = "Trial of the Champion",
            ["bosses"] = {
                {
                    ["id"] = 834,
                    ["image"] = 607621,
                    ["name"] = "Grand Champions",
                }, -- [1]
                {
                    ["id"] = 635,
                    ["image"] = 607591,
                    ["name"] = "Eadric the Pure",
                }, -- [2]
                {
                    ["id"] = 636,
                    ["image"] = 607547,
                    ["name"] = "Argent Confessor Paletress",
                }, -- [3]
                {
                    ["id"] = 637,
                    ["image"] = 607787,
                    ["name"] = "The Black Knight",
                }, -- [4]
            },
        }, -- [23]
        {
            ["id"] = 285,
            ["image"] = 608226,
            ["name"] = "Utgarde Keep",
            ["bosses"] = {
                {
                    ["id"] = 638,
                    ["image"] = 607743,
                    ["name"] = "Prince Keleseth",
                }, -- [1]
                {
                    ["id"] = 639,
                    ["image"] = 607774,
                    ["name"] = "Skarvald & Dalronn",
                }, -- [2]
                {
                    ["id"] = 640,
                    ["image"] = 607659,
                    ["name"] = "Ingvar the Plunderer",
                }, -- [3]
            },
        }, -- [24]
        {
            ["id"] = 286,
            ["image"] = 608227,
            ["name"] = "Utgarde Pinnacle",
            ["bosses"] = {
                {
                    ["id"] = 641,
                    ["image"] = 607778,
                    ["name"] = "Svala Sorrowgrave",
                }, -- [1]
                {
                    ["id"] = 642,
                    ["image"] = 607620,
                    ["name"] = "Gortok Palehoof",
                }, -- [2]
                {
                    ["id"] = 643,
                    ["image"] = 607773,
                    ["name"] = "Skadi the Ruthless",
                }, -- [3]
                {
                    ["id"] = 644,
                    ["image"] = 607674,
                    ["name"] = "King Ymiron",
                }, -- [4]
            },
        }, -- [25]
    },
}

-------------------------------------------------
-- vanilla
-------------------------------------------------
-- if Cell.isVanilla then
    -- IDs are Encounter Journal ID on Retail, no need to modify

    -- override specific instance, all bosses must be listed
    -- Cell_ExpansionData.data["Classic"][(number: instanceIndex)] = {
    --     ["id"] = (number: EJ instance id),
    --     ["image"] = (number: instance image),
    --     ["name"] = (string: instance name),
    --     ["bosses"] = {
    --         {
    --             ["id"] = (number: boss id),
    --             ["image"] = (number: boss image),
    --             ["name"] = (string: boss name),
    --         },
    --     },
    -- }

    -- override specific boss
    -- Cell_ExpansionData.data["Classic"][(number: instanceIndex)]["bosses"][(number: bossIndex)] = {
    --     ["id"] = (number: EJ boss id),
    --     ["image"] = (number: boss image),
    --     ["name"] = (string: boss name),
    -- }
-- end
