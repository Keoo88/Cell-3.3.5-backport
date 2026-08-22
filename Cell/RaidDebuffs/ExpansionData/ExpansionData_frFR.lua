---------------------------------------------------------------------
-- File: Cell\RaidDebuffs\ExpansionData\ExpansionData_frFR.lua
-- Author: enderneko (enderneko-dev@outlook.com)
-- Created : 2023-09-03 19:52:19 +08:00
-- Modified: 2024-06-01 19:56 +08:00
---------------------------------------------------------------------

--! WotLK fix: гейт переведён с FrameXML-глобала LOCALE_frFR на native GetLocale().
--! LOCALE_frFR объявляет не аддон, а сам клиент в Localization.lua своей локали
--! (в эталонном дампе enUS-клиента есть ровно одна такая строка, LOCALE_enUS), то есть
--! доказать существование LOCALE_frFR на frFR-клиенте 3.3.5a по эталону нельзя, а
--! ложный гейт молча оставил бы игрока без всего локализованного пейлоада. GetLocale
--! документирован кодексом, перечисляет ровно эти коды и уже вызывается ниже в
--! F.GetExpansionList - теперь гейт и та сверка читают один источник и разойтись не
--! могут. Собственные локали Cell (Cell/Locales) выбираются так же, по GetLocale.
if GetLocale() ~= "frFR" then return end

Cell_ExpansionData.locale = "frFR"

--! WotLK fix: пейлоад локали пришёл из ретейла, поэтому часть имён инстансов в нём
--! записана так, как их зовёт Encounter Journal, а клиент 3.3.5a возвращает другую
--! строку: иногда целиком другое имя (Hyjal Summit против ретейльного The Battle for
--! Mount Hyjal), иногда ту же фразу с другим регистром или артиклем. Поиск зоны идёт
--! точным ключом таблицы, поэтому любое расхождение означает, что дебаффы зоны просто
--! не включаются - молча. Ключи ниже - клиентские написания 3.3.5a по
--! LibBabble-Zone-3.0, значения - записи этого пейлоада. Верным окажется какой-то
--! один из двух, и оба ведут на одну запись, поэтому лишним псевдоним быть не может.
Cell_ExpansionData.instanceNameAliases = {
    ["Les salles des Reflets"] = "Salles des Reflets", -- Halls of Reflection
    ["La Forge des âmes"] = "La Forge des Âmes", -- The Forge of Souls
    ["Sommet d'Hyjal"] = "La bataille du mont Hyjal", -- The Battle for Mount Hyjal
    ["Temple noir"] = "Le Temple noir", -- Black Temple
    ["Labyrinthe des ombres"] = "Labyrinthe des Ombres", -- Shadow Labyrinth
    ["Le Noir Marécage"] = "Le Noir marécage", -- The Black Morass
    ["Les Salles brisées"] = "Les salles Brisées", -- The Shattered Halls
    ["Le Caveau de la vapeur"] = "Le caveau de la Vapeur", -- The Steamvault
    ["Le temple d'Ahn'Qiraj"] = "Temple d'Ahn'Qiraj", -- Temple of Ahn'Qiraj
    ["Hache-tripes"] = "Hache-Tripes", -- Dire Maul
    ["Pic de Rochenoire inférieur"] = "Bas du pic Rochenoire", -- Lower Blackrock Spire
    ["Monastère écarlate"] = "Monastère Écarlate", -- Scarlet Monastery
    ["Cavernes des lamentations"] = "Cavernes des Lamentations", -- Wailing Caverns
}

--! WotLK fix: семь пост-WotLK эпох вырезаны из литерала - причина и счёт в
--! ExpansionData.lua. Остаток - те же позиции 8-10: WotLK, TBC, Classic.
Cell_ExpansionData.expansions = {
    "Wrath of the Lich King",
    "Burning Crusade",
    "Donjons classiques",
}

Cell_ExpansionData.data = {
    ["Donjons classiques"] = {
        {
            ["id"] = 741,
            ["image"] = 1396586,
            ["name"] = "Cœur du Magma",
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
                    ["name"] = "Messager de Sulfuron",
                }, -- [7]
                {
                    ["id"] = 1526,
                    ["image"] = 1378978,
                    ["name"] = "Golemagg l'Incinérateur",
                }, -- [8]
                {
                    ["id"] = 1527,
                    ["image"] = 1378998,
                    ["name"] = "Chambellan Executus",
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
            ["name"] = "Repaire de l'Aile noire",
            ["bosses"] = {
                {
                    ["id"] = 1529,
                    ["image"] = 1379008,
                    ["name"] = "Tranchetripe l'Indompté",
                }, -- [1]
                {
                    ["id"] = 1530,
                    ["image"] = 1379022,
                    ["name"] = "Vaelastrasz le Corrompu",
                }, -- [2]
                {
                    ["id"] = 1531,
                    ["image"] = 1378968,
                    ["name"] = "Seigneur des couvées Lanistaire",
                }, -- [3]
                {
                    ["id"] = 1532,
                    ["image"] = 1378973,
                    ["name"] = "Gueule-de-feu",
                }, -- [4]
                {
                    ["id"] = 1533,
                    ["image"] = 1378971,
                    ["name"] = "Rochébène",
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
            ["name"] = "Ruines d'Ahn'Qiraj",
            ["bosses"] = {
                {
                    ["id"] = 1537,
                    ["image"] = 1385749,
                    ["name"] = "Kurinnaxx",
                }, -- [1]
                {
                    ["id"] = 1538,
                    ["image"] = 1385734,
                    ["name"] = "Général Rajaxx",
                }, -- [2]
                {
                    ["id"] = 1539,
                    ["image"] = 1385755,
                    ["name"] = "Moam",
                }, -- [3]
                {
                    ["id"] = 1540,
                    ["image"] = 1385723,
                    ["name"] = "Buru Grandgosier",
                }, -- [4]
                {
                    ["id"] = 1541,
                    ["image"] = 1385718,
                    ["name"] = "Ayamiss le Chasseur",
                }, -- [5]
                {
                    ["id"] = 1542,
                    ["image"] = 1385759,
                    ["name"] = "Ossirian l'Intouché",
                }, -- [6]
            },
        }, -- [3]
        {
            ["id"] = 744,
            ["image"] = 1396593,
            ["name"] = "Temple d'Ahn'Qiraj",
            ["bosses"] = {
                {
                    ["id"] = 1543,
                    ["image"] = 1385769,
                    ["name"] = "Le prophète Skeram",
                }, -- [1]
                {
                    ["id"] = 1547,
                    ["image"] = 1390436,
                    ["name"] = "Famille royale silithide",
                }, -- [2]
                {
                    ["id"] = 1544,
                    ["image"] = 1385720,
                    ["name"] = "Garde de guerre Sartura",
                }, -- [3]
                {
                    ["id"] = 1545,
                    ["image"] = 1385728,
                    ["name"] = "Fankriss l'Inflexible",
                }, -- [4]
                {
                    ["id"] = 1548,
                    ["image"] = 1385771,
                    ["name"] = "Viscidus",
                }, -- [5]
                {
                    ["id"] = 1546,
                    ["image"] = 1385761,
                    ["name"] = "Princesse Huhuran",
                }, -- [6]
                {
                    ["id"] = 1549,
                    ["image"] = 1390437,
                    ["name"] = "Les Empereurs jumeaux",
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
                    ["name"] = "Grande veuve Faerlina",
                }, -- [2]
                {
                    ["id"] = 901554,
                    ["image"] = 1378994,
                    ["name"] = "Maexxna",
                }, -- [3]
                {
                    ["id"] = 901555,
                    ["image"] = 1379004,
                    ["name"] = "Noth le Porte-Peste",
                }, -- [4]
                {
                    ["id"] = 901556,
                    ["image"] = 1378984,
                    ["name"] = "Heigan l'Impur",
                }, -- [5]
                {
                    ["id"] = 901557,
                    ["image"] = 1378991,
                    ["name"] = "Horreb",
                }, -- [6]
                {
                    ["id"] = 901558,
                    ["image"] = 1378988,
                    ["name"] = "Instructeur Razuvious",
                }, -- [7]
                {
                    ["id"] = 901559,
                    ["image"] = 1378979,
                    ["name"] = "Gothik le Moissonneur",
                }, -- [8]
                {
                    ["id"] = 901560,
                    ["image"] = 1385732,
                    ["name"] = "Les quatre cavaliers",
                }, -- [9]
                {
                    ["id"] = 901561,
                    ["image"] = 1379005,
                    ["name"] = "Le Recousu",
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
                    ["name"] = "Saphiron",
                }, -- [14]
                {
                    ["id"] = 901566,
                    ["image"] = 1378989,
                    ["name"] = "Kel'Thuzad",
                }, -- [15]
            },
        }, -- [5]
        {
            ["id"] = 229,
            ["image"] = 608197,
            ["name"] = "Bas du pic Rochenoire",
            ["bosses"] = {
                {
                    ["id"] = 388,
                    ["image"] = 607645,
                    ["name"] = "Généralissime Omokk",
                }, -- [1]
                {
                    ["id"] = 389,
                    ["image"] = 607769,
                    ["name"] = "Chasseresse des ombres Vosh'gajin",
                }, -- [2]
                {
                    ["id"] = 390,
                    ["image"] = 607810,
                    ["name"] = "Maître de guerre Voone",
                }, -- [3]
                {
                    ["id"] = 391,
                    ["image"] = 607719,
                    ["name"] = "Matriarche Couveuse",
                }, -- [4]
                {
                    ["id"] = 392,
                    ["image"] = 607801,
                    ["name"] = "Urok Hurleruine",
                }, -- [5]
                {
                    ["id"] = 393,
                    ["image"] = 607751,
                    ["name"] = "Intendant Zigris",
                }, -- [6]
                {
                    ["id"] = 394,
                    ["image"] = 607634,
                    ["name"] = "Halycon",
                }, -- [7]
                {
                    ["id"] = 395,
                    ["image"] = 607615,
                    ["name"] = "Gizrul l'esclavagiste",
                }, -- [8]
                {
                    ["id"] = 396,
                    ["image"] = 607737,
                    ["name"] = "Seigneur Wyrmthalak",
                }, -- [9]
            },
        }, -- [6]
        {
            ["id"] = 240,
            ["image"] = 608229,
            ["name"] = "Cavernes des Lamentations",
            ["bosses"] = {
                {
                    ["id"] = 474,
                    ["image"] = 607680,
                    ["name"] = "Dame Anacondra",
                }, -- [1]
                {
                    ["id"] = 476,
                    ["image"] = 607696,
                    ["name"] = "Seigneur Pythas",
                }, -- [2]
                {
                    ["id"] = 475,
                    ["image"] = 607693,
                    ["name"] = "Seigneur Cobrahn",
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
                    ["name"] = "Seigneur Serpentis",
                }, -- [6]
                {
                    ["id"] = 480,
                    ["image"] = 607805,
                    ["name"] = "Verdan l'Immortel",
                }, -- [7]
                {
                    ["id"] = 481,
                    ["image"] = 607721,
                    ["name"] = "Mutanus le Dévoreur",
                }, -- [8]
            },
        }, -- [7]
        {
            ["id"] = 64,
            ["image"] = 522358,
            ["name"] = "Donjon d'Ombrecroc",
            ["bosses"] = {
                {
                    ["id"] = 96,
                    ["image"] = 522205,
                    ["name"] = "Baron Ashbury",
                }, -- [1]
                {
                    ["id"] = 97,
                    ["image"] = 522206,
                    ["name"] = "Baron d'Argelaine",
                }, -- [2]
                {
                    ["id"] = 98,
                    ["image"] = 522213,
                    ["name"] = "Commandant Printeval",
                }, -- [3]
                {
                    ["id"] = 99,
                    ["image"] = 522249,
                    ["name"] = "Seigneur Walden",
                }, -- [4]
                {
                    ["id"] = 100,
                    ["image"] = 522247,
                    ["name"] = "Seigneur Godfrey",
                }, -- [5]
            },
        }, -- [8]
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
                    ["name"] = "Retombée visqueuse",
                }, -- [2]
                {
                    ["id"] = 421,
                    ["image"] = 607594,
                    ["name"] = "Electrocuteur 6000",
                }, -- [3]
                {
                    ["id"] = 418,
                    ["image"] = 607572,
                    ["name"] = "Disperseur de foule 9-60",
                }, -- [4]
                {
                    ["id"] = 422,
                    ["image"] = 607714,
                    ["name"] = "Mekgénieur Thermojoncteur",
                }, -- [5]
            },
        }, -- [9]
        {
            ["id"] = 226,
            ["image"] = 608211,
            ["name"] = "Gouffre de Ragefeu",
            ["bosses"] = {
                {
                    ["id"] = 694,
                    ["image"] = 608309,
                    ["name"] = "Adarogg",
                }, -- [1]
                {
                    ["id"] = 695,
                    ["image"] = 608310,
                    ["name"] = "Sombre chaman Koranthal",
                }, -- [2]
                {
                    ["id"] = 696,
                    ["image"] = 522251,
                    ["name"] = "Crassegueule",
                }, -- [3]
                {
                    ["id"] = 697,
                    ["image"] = 608315,
                    ["name"] = "Garde de lave Gordoth",
                }, -- [4]
            },
        }, -- [10]
        {
            ["id"] = 230,
            ["image"] = 608200,
            ["name"] = "Hache-Tripes",
            ["bosses"] = {
                {
                    ["id"] = 402,
                    ["image"] = 607824,
                    ["name"] = "Zevrim Sabot-de-Ronce",
                }, -- [1]
                {
                    ["id"] = 403,
                    ["image"] = 607653,
                    ["name"] = "Hydrogénos",
                }, -- [2]
                {
                    ["id"] = 404,
                    ["image"] = 607686,
                    ["name"] = "Lethtendris",
                }, -- [3]
                {
                    ["id"] = 405,
                    ["image"] = 607533,
                    ["name"] = "Alzzin le Modeleur",
                }, -- [4]
                {
                    ["id"] = 406,
                    ["image"] = 607785,
                    ["name"] = "Tendris Crochebois",
                }, -- [5]
                {
                    ["id"] = 407,
                    ["image"] = 607656,
                    ["name"] = "Illyanna Corvichêne",
                }, -- [6]
                {
                    ["id"] = 408,
                    ["image"] = 607703,
                    ["name"] = "Magistère Kalendris",
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
                    ["name"] = "Garde Mol'dar",
                }, -- [10]
                {
                    ["id"] = 412,
                    ["image"] = 607777,
                    ["name"] = "Kreeg le Marteleur",
                }, -- [11]
                {
                    ["id"] = 413,
                    ["image"] = 607629,
                    ["name"] = "Garde Fengus",
                }, -- [12]
                {
                    ["id"] = 414,
                    ["image"] = 607631,
                    ["name"] = "Garde Slip'kik",
                }, -- [13]
                {
                    ["id"] = 415,
                    ["image"] = 607560,
                    ["name"] = "Capitaine Kromcrabouille",
                }, -- [14]
                {
                    ["id"] = 416,
                    ["image"] = 607565,
                    ["name"] = "Cho'Rush l'Observateur",
                }, -- [15]
                {
                    ["id"] = 417,
                    ["image"] = 607673,
                    ["name"] = "Roi Gordok",
                }, -- [16]
            },
        }, -- [11]
        {
            ["id"] = 234,
            ["image"] = 608213,
            ["name"] = "Kraal de Tranchebauge",
            ["bosses"] = {
                {
                    ["id"] = 896,
                    ["image"] = 607531,
                    ["name"] = "Chasseur Ossathure",
                }, -- [1]
                {
                    ["id"] = 895,
                    ["image"] = 607760,
                    ["name"] = "Roogug",
                }, -- [2]
                {
                    ["id"] = 899,
                    ["image"] = 607736,
                    ["name"] = "Seigneur de guerre Brusquebroche",
                }, -- [3]
                {
                    ["id"] = 900,
                    ["image"] = 1064175,
                    ["name"] = "Groyat, le chasseur aveugle",
                }, -- [4]
                {
                    ["id"] = 901,
                    ["image"] = 607563,
                    ["name"] = "Charlga Trancheflanc",
                }, -- [5]
            },
        }, -- [12]
        {
            ["id"] = 238,
            ["image"] = 608223,
            ["name"] = "La Prison",
            ["bosses"] = {
                {
                    ["id"] = 464,
                    ["image"] = 4776138,
                    ["name"] = "Lardeur",
                }, -- [1]
                {
                    ["id"] = 465,
                    ["image"] = 607695,
                    ["name"] = "Seigneur Surchauffe",
                }, -- [2]
                {
                    ["id"] = 466,
                    ["image"] = 607753,
                    ["name"] = "Randolph Moloch",
                }, -- [3]
            },
        }, -- [13]
        {
            ["id"] = 237,
            ["image"] = 608217,
            ["name"] = "Le temple d'Atal'Hakkar",
            ["bosses"] = {
                {
                    ["id"] = 457,
                    ["image"] = 607548,
                    ["name"] = "Avatar d'Hakkar",
                }, -- [1]
                {
                    ["id"] = 458,
                    ["image"] = 607665,
                    ["name"] = "Jammal'an le Prophète",
                }, -- [2]
                {
                    ["id"] = 459,
                    ["image"] = 608311,
                    ["name"] = "Protecteurs du Rêve",
                }, -- [3]
                {
                    ["id"] = 463,
                    ["image"] = 607768,
                    ["name"] = "Ombre d'Eranikus",
                }, -- [4]
            },
        }, -- [14]
        {
            ["id"] = 63,
            ["image"] = 522352,
            ["name"] = "Les Mortemines",
            ["bosses"] = {
                {
                    ["id"] = 89,
                    ["image"] = 522228,
                    ["name"] = "Glubtok",
                }, -- [1]
                {
                    ["id"] = 90,
                    ["image"] = 522234,
                    ["name"] = "Hélix Engrecasse",
                }, -- [2]
                {
                    ["id"] = 91,
                    ["image"] = 522225,
                    ["name"] = "Faucheur 5000",
                }, -- [3]
                {
                    ["id"] = 92,
                    ["image"] = 522189,
                    ["name"] = "Amiral Grondéventre",
                }, -- [4]
                {
                    ["id"] = 93,
                    ["image"] = 522210,
                    ["name"] = "« Capitaine » Macaron",
                }, -- [5]
                {
                    ["id"] = 95,
                    ["image"] = 522278,
                    ["name"] = "Vanessa VanCleef",
                }, -- [6]
            },
        }, -- [15]
        {
            ["id"] = 232,
            ["image"] = 608209,
            ["name"] = "Maraudon",
            ["bosses"] = {
                {
                    ["id"] = 423,
                    ["image"] = 607728,
                    ["name"] = "Noxcion",
                }, -- [1]
                {
                    ["id"] = 424,
                    ["image"] = 607756,
                    ["name"] = "Tranchefouet",
                }, -- [2]
                {
                    ["id"] = 425,
                    ["image"] = 607796,
                    ["name"] = "Bricoleur Kadenaz",
                }, -- [3]
                {
                    ["id"] = 427,
                    ["image"] = 607699,
                    ["name"] = "Seigneur Vylelangue",
                }, -- [4]
                {
                    ["id"] = 428,
                    ["image"] = 607562,
                    ["name"] = "Celebras le Maudit",
                }, -- [5]
                {
                    ["id"] = 429,
                    ["image"] = 607684,
                    ["name"] = "Glissement de terrain",
                }, -- [6]
                {
                    ["id"] = 430,
                    ["image"] = 607761,
                    ["name"] = "Grippe-charogne",
                }, -- [7]
                {
                    ["id"] = 431,
                    ["image"] = 607747,
                    ["name"] = "Princesse Theradras",
                }, -- [8]
            },
        }, -- [16]
        {
            ["id"] = 316,
            ["image"] = 608214,
            ["name"] = "Monastère Écarlate",
            ["bosses"] = {
                {
                    ["id"] = 688,
                    ["image"] = 630853,
                    ["name"] = "Thalnos le Déchiqueteur d'âmes",
                }, -- [1]
                {
                    ["id"] = 671,
                    ["image"] = 630818,
                    ["name"] = "Frère Korloff",
                }, -- [2]
                {
                    ["id"] = 674,
                    ["image"] = 607643,
                    ["name"] = "Grande inquisitrice Blanchetête",
                }, -- [3]
            },
        }, -- [17]
        {
            ["id"] = 227,
            ["image"] = 608195,
            ["name"] = "Profondeurs de Brassenoire",
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
                    ["name"] = "Subjugateur Kor'ul",
                }, -- [3]
                {
                    ["id"] = 1145,
                    ["image"] = 1064181,
                    ["name"] = "Thruk",
                }, -- [4]
                {
                    ["id"] = 447,
                    ["image"] = 1064182,
                    ["name"] = "Gardien des profondeurs",
                }, -- [5]
                {
                    ["id"] = 1144,
                    ["image"] = 1064183,
                    ["name"] = "Exécuteur Carnage",
                }, -- [6]
                {
                    ["id"] = 437,
                    ["image"] = 1064184,
                    ["name"] = "Seigneur du Crépuscule Bathiel",
                }, -- [7]
                {
                    ["id"] = 444,
                    ["image"] = 607532,
                    ["name"] = "Aku'mai",
                }, -- [8]
            },
        }, -- [18]
        {
            ["id"] = 228,
            ["image"] = 608196,
            ["name"] = "Profondeurs de Rochenoire",
            ["bosses"] = {
                {
                    ["id"] = 369,
                    ["image"] = 607644,
                    ["name"] = "Grande Interrogatrice Gerstahn",
                }, -- [1]
                {
                    ["id"] = 370,
                    ["image"] = 607697,
                    ["name"] = "Seigneur Roccor",
                }, -- [2]
                {
                    ["id"] = 371,
                    ["image"] = 607647,
                    ["name"] = "Maître-chien Grebmar",
                }, -- [3]
                {
                    ["id"] = 372,
                    ["image"] = 608314,
                    ["name"] = "Cercle de la loi",
                }, -- [4]
                {
                    ["id"] = 373,
                    ["image"] = 607749,
                    ["name"] = "Pyromancien Blé-du-savoir",
                }, -- [5]
                {
                    ["id"] = 374,
                    ["image"] = 607694,
                    ["name"] = "Seigneur Incendius",
                }, -- [6]
                {
                    ["id"] = 375,
                    ["image"] = 607814,
                    ["name"] = "Gardien Stilgiss",
                }, -- [7]
                {
                    ["id"] = 376,
                    ["image"] = 607602,
                    ["name"] = "Fineous Sombrevire",
                }, -- [8]
                {
                    ["id"] = 377,
                    ["image"] = 607549,
                    ["name"] = "Bael'Gar",
                }, -- [9]
                {
                    ["id"] = 378,
                    ["image"] = 607610,
                    ["name"] = "Général Forgehargne",
                }, -- [10]
                {
                    ["id"] = 379,
                    ["image"] = 607618,
                    ["name"] = "Seigneur golem Argelmach",
                }, -- [11]
                {
                    ["id"] = 380,
                    ["image"] = 607650,
                    ["name"] = "Hurley Soufflenoir",
                }, -- [12]
                {
                    ["id"] = 381,
                    ["image"] = 607740,
                    ["name"] = "Phalange",
                }, -- [13]
                {
                    ["id"] = 383,
                    ["image"] = 607741,
                    ["name"] = "Lanfiche Brouillecircuit",
                }, -- [14]
                {
                    ["id"] = 384,
                    ["image"] = 607535,
                    ["name"] = "Ambassadeur Cinglefouet",
                }, -- [15]
                {
                    ["id"] = 385,
                    ["image"] = 607587,
                    ["name"] = "Les Sept",
                }, -- [16]
                {
                    ["id"] = 386,
                    ["image"] = 607705,
                    ["name"] = "Magmus",
                }, -- [17]
                {
                    ["id"] = 387,
                    ["image"] = 607595,
                    ["name"] = "Empereur Dagran Thaurissan",
                }, -- [18]
            },
        }, -- [19]
        {
            ["id"] = 311,
            ["image"] = 643262,
            ["name"] = "Salles Écarlates",
            ["bosses"] = {
                {
                    ["id"] = 660,
                    ["image"] = 630833,
                    ["name"] = "Maître-chien Braun",
                }, -- [1]
                {
                    ["id"] = 654,
                    ["image"] = 630816,
                    ["name"] = "Maître d'armes Harlan",
                }, -- [2]
                {
                    ["id"] = 656,
                    ["image"] = 630825,
                    ["name"] = "Tisseur de flammes Koegler",
                }, -- [3]
            },
        }, -- [20]
        {
            ["id"] = 246,
            ["image"] = 608215,
            ["name"] = "Scholomance",
            ["bosses"] = {
                {
                    ["id"] = 659,
                    ["image"] = 630835,
                    ["name"] = "Instructrice Froidecœur",
                }, -- [1]
                {
                    ["id"] = 663,
                    ["image"] = 607666,
                    ["name"] = "Jandice Barov",
                }, -- [2]
                {
                    ["id"] = 665,
                    ["image"] = 607755,
                    ["name"] = "Cliquettripes",
                }, -- [3]
                {
                    ["id"] = 666,
                    ["image"] = 630838,
                    ["name"] = "Lilian Voss",
                }, -- [4]
                {
                    ["id"] = 684,
                    ["image"] = 607582,
                    ["name"] = "Sombre Maître Gandling",
                }, -- [5]
            },
        }, -- [21]
        {
            ["id"] = 233,
            ["image"] = 608212,
            ["name"] = "Souilles de Tranchebauge",
            ["bosses"] = {
                {
                    ["id"] = 1142,
                    ["image"] = 607633,
                    ["name"] = "Aarux",
                }, -- [1]
                {
                    ["id"] = 433,
                    ["image"] = 607718,
                    ["name"] = "Mordresh Oeil-de-Feu",
                }, -- [2]
                {
                    ["id"] = 1143,
                    ["image"] = 1064178,
                    ["name"] = "Bouillegrume",
                }, -- [3]
                {
                    ["id"] = 1146,
                    ["image"] = 607584,
                    ["name"] = "Nécrorateur Noirépine",
                }, -- [4]
                {
                    ["id"] = 1141,
                    ["image"] = 607537,
                    ["name"] = "Amnennar le Porte-Froid",
                }, -- [5]
            },
        }, -- [22]
        {
            ["id"] = 236,
            ["image"] = 608216,
            ["name"] = "Stratholme",
            ["bosses"] = {
                {
                    ["id"] = 443,
                    ["image"] = 607637,
                    ["name"] = "Chanteloge Forrestin",
                }, -- [1]
                {
                    ["id"] = 445,
                    ["image"] = 607795,
                    ["name"] = "Timmy le Cruel",
                }, -- [2]
                {
                    ["id"] = 749,
                    ["image"] = 607569,
                    ["name"] = "Commandant Malor",
                }, -- [3]
                {
                    ["id"] = 446,
                    ["image"] = 607818,
                    ["name"] = "Willey Mutilespoir",
                }, -- [4]
                {
                    ["id"] = 448,
                    ["image"] = 607660,
                    ["name"] = "Instructeur Galford",
                }, -- [5]
                {
                    ["id"] = 449,
                    ["image"] = 607551,
                    ["name"] = "Balnazzar",
                }, -- [6]
                {
                    ["id"] = 450,
                    ["image"] = 607792,
                    ["name"] = "Le Condamné",
                }, -- [7]
                {
                    ["id"] = 451,
                    ["image"] = 607553,
                    ["name"] = "Baronne Anastari",
                }, -- [8]
                {
                    ["id"] = 452,
                    ["image"] = 607724,
                    ["name"] = "Nerub'enkan",
                }, -- [9]
                {
                    ["id"] = 453,
                    ["image"] = 607707,
                    ["name"] = "Maleki le Blafard",
                }, -- [10]
                {
                    ["id"] = 454,
                    ["image"] = 607791,
                    ["name"] = "Magistrat Barthilas",
                }, -- [11]
                {
                    ["id"] = 455,
                    ["image"] = 607752,
                    ["name"] = "Ramstein Grandgosier",
                }, -- [12]
                {
                    ["id"] = 456,
                    ["image"] = 607692,
                    ["name"] = "Seigneur Aurius Vaillefendre",
                }, -- [13]
            },
        }, -- [23]
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
                    ["name"] = "Les nains perdus",
                }, -- [2]
                {
                    ["id"] = 469,
                    ["image"] = 607664,
                    ["name"] = "Ironaya",
                }, -- [3]
                {
                    ["id"] = 748,
                    ["image"] = 607729,
                    ["name"] = "Sentinelle d'obsidienne",
                }, -- [4]
                {
                    ["id"] = 470,
                    ["image"] = 607538,
                    ["name"] = "Ancien gardien en pierre",
                }, -- [5]
                {
                    ["id"] = 471,
                    ["image"] = 607606,
                    ["name"] = "Galgann Martel-de-Feu",
                }, -- [6]
                {
                    ["id"] = 472,
                    ["image"] = 607626,
                    ["name"] = "Grimelok",
                }, -- [7]
                {
                    ["id"] = 473,
                    ["image"] = 607546,
                    ["name"] = "Archaedas",
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
                    ["name"] = "Theka le Martyr",
                }, -- [3]
                {
                    ["id"] = 486,
                    ["image"] = 607819,
                    ["name"] = "Féticheur Zum'rah",
                }, -- [4]
                {
                    ["id"] = 487,
                    ["image"] = 607723,
                    ["name"] = "Nekrum et Sezz'ziz",
                }, -- [5]
                {
                    ["id"] = 489,
                    ["image"] = 607564,
                    ["name"] = "Chef Ukorz Scalpessable",
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
                    ["name"] = "Quartiers des serviteurs",
                }, -- [1]
                {
                    ["id"] = 1553,
                    ["image"] = 1378965,
                    ["name"] = "Attumen le Veneur",
                }, -- [2]
                {
                    ["id"] = 1554,
                    ["image"] = 1378999,
                    ["name"] = "Moroes",
                }, -- [3]
                {
                    ["id"] = 1555,
                    ["image"] = 1378997,
                    ["name"] = "Damoiselle de vertu",
                }, -- [4]
                {
                    ["id"] = 1556,
                    ["image"] = 1385758,
                    ["name"] = "L'Opéra",
                }, -- [5]
                {
                    ["id"] = 1557,
                    ["image"] = 1379020,
                    ["name"] = "Le Conservateur",
                }, -- [6]
                {
                    ["id"] = 1559,
                    ["image"] = 1379012,
                    ["name"] = "Ombre d'Aran",
                }, -- [7]
                {
                    ["id"] = 1560,
                    ["image"] = 1379017,
                    ["name"] = "Terestian Malsabot",
                }, -- [8]
                {
                    ["id"] = 1561,
                    ["image"] = 1379002,
                    ["name"] = "Dédain-du-Néant",
                }, -- [9]
                {
                    ["id"] = 1764,
                    ["image"] = 1385724,
                    ["name"] = "Évènement de l'échiquier",
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
            ["name"] = "Repaire de Gruul",
            ["bosses"] = {
                {
                    ["id"] = 1564,
                    ["image"] = 1378985,
                    ["name"] = "Haut Roi Maulgar",
                }, -- [1]
                {
                    ["id"] = 1565,
                    ["image"] = 1378982,
                    ["name"] = "Gruul le Tue-Dragon",
                }, -- [2]
            },
        }, -- [2]
        {
            ["id"] = 747,
            ["image"] = 1396585,
            ["name"] = "Le repaire de Magtheridon",
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
            ["name"] = "Caverne du sanctuaire du Serpent",
            ["bosses"] = {
                {
                    ["id"] = 1567,
                    ["image"] = 1385741,
                    ["name"] = "Hydross l'Instable",
                }, -- [1]
                {
                    ["id"] = 1568,
                    ["image"] = 1385768,
                    ["name"] = "Le Rôdeur d'En bas",
                }, -- [2]
                {
                    ["id"] = 1569,
                    ["image"] = 1385751,
                    ["name"] = "Leotheras l'Aveugle",
                }, -- [3]
                {
                    ["id"] = 1570,
                    ["image"] = 1385729,
                    ["name"] = "Seigneur des fonds Karathress",
                }, -- [4]
                {
                    ["id"] = 1571,
                    ["image"] = 1385756,
                    ["name"] = "Morogrim Marcheur-des-flots",
                }, -- [5]
                {
                    ["id"] = 1572,
                    ["image"] = 1385750,
                    ["name"] = "Dame Vashj",
                }, -- [6]
            },
        }, -- [4]
        {
            ["id"] = 749,
            ["image"] = 608218,
            ["name"] = "L'Œil",
            ["bosses"] = {
                {
                    ["id"] = 1573,
                    ["image"] = 1385712,
                    ["name"] = "Al'ar",
                }, -- [1]
                {
                    ["id"] = 1574,
                    ["image"] = 1385772,
                    ["name"] = "Saccageur du Vide",
                }, -- [2]
                {
                    ["id"] = 1575,
                    ["image"] = 1385739,
                    ["name"] = "Grande astromancienne Solarian",
                }, -- [3]
                {
                    ["id"] = 1576,
                    ["image"] = 607669,
                    ["name"] = "Kael'thas Haut-Soleil",
                }, -- [4]
            },
        }, -- [5]
        {
            ["id"] = 750,
            ["image"] = 608198,
            ["name"] = "La bataille du mont Hyjal",
            ["bosses"] = {
                {
                    ["id"] = 1577,
                    ["image"] = 1385762,
                    ["name"] = "Rage Froidhiver",
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
            ["name"] = "Le Temple noir",
            ["bosses"] = {
                {
                    ["id"] = 1582,
                    ["image"] = 1378986,
                    ["name"] = "Grand seigneur de guerre Naj'entus",
                }, -- [1]
                {
                    ["id"] = 1583,
                    ["image"] = 1379016,
                    ["name"] = "Supremus",
                }, -- [2]
                {
                    ["id"] = 1584,
                    ["image"] = 1379011,
                    ["name"] = "Ombre d'Akama",
                }, -- [3]
                {
                    ["id"] = 1585,
                    ["image"] = 1379018,
                    ["name"] = "Teron Fielsang",
                }, -- [4]
                {
                    ["id"] = 1586,
                    ["image"] = 1378983,
                    ["name"] = "Gurtogg Fièvresang",
                }, -- [5]
                {
                    ["id"] = 1587,
                    ["image"] = 1385764,
                    ["name"] = "Reliquaire des âmes",
                }, -- [6]
                {
                    ["id"] = 1588,
                    ["image"] = 1379000,
                    ["name"] = "Mère Shahraz",
                }, -- [7]
                {
                    ["id"] = 1589,
                    ["image"] = 1385743,
                    ["name"] = "Le conseil illidari",
                }, -- [8]
                {
                    ["id"] = 1590,
                    ["image"] = 1378987,
                    ["name"] = "Illidan Hurlorage",
                }, -- [9]
            },
        }, -- [7]
        {
            ["id"] = 752,
            ["image"] = 1396592,
            ["name"] = "Plateau du Puits de soleil",
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
                    ["name"] = "Gangrebrume",
                }, -- [3]
                {
                    ["id"] = 1594,
                    ["image"] = 1390438,
                    ["name"] = "Les jumelles érédars",
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
            ["id"] = 251,
            ["image"] = 608198,
            ["name"] = "Contreforts de Hautebrande d'antan",
            ["bosses"] = {
                {
                    ["id"] = 538,
                    ["image"] = 607689,
                    ["name"] = "Lieutenant Drake",
                }, -- [1]
                {
                    ["id"] = 539,
                    ["image"] = 607561,
                    ["name"] = "Capitaine Skarloc",
                }, -- [2]
                {
                    ["id"] = 540,
                    ["image"] = 607596,
                    ["name"] = "Chasseur d'époques",
                }, -- [3]
            },
        }, -- [9]
        {
            ["id"] = 247,
            ["image"] = 608193,
            ["name"] = "Cryptes Auchenaï",
            ["bosses"] = {
                {
                    ["id"] = 523,
                    ["image"] = 607771,
                    ["name"] = "Shirrak le Veillemort",
                }, -- [1]
                {
                    ["id"] = 524,
                    ["image"] = 607600,
                    ["name"] = "Exarque Maladaar",
                }, -- [2]
            },
        }, -- [10]
        {
            ["id"] = 262,
            ["image"] = 608199,
            ["name"] = "La Basse-tourbière",
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
                    ["name"] = "Seigneur des marais Musel'ek",
                }, -- [3]
                {
                    ["id"] = 579,
                    ["image"] = 607788,
                    ["name"] = "La Traqueuse noire",
                }, -- [4]
            },
        }, -- [11]
        {
            ["id"] = 257,
            ["image"] = 608218,
            ["name"] = "La Botanica",
            ["bosses"] = {
                {
                    ["id"] = 558,
                    ["image"] = 607570,
                    ["name"] = "Commandant Sarannis",
                }, -- [1]
                {
                    ["id"] = 559,
                    ["image"] = 607641,
                    ["name"] = "Grand botaniste Freywinn",
                }, -- [2]
                {
                    ["id"] = 560,
                    ["image"] = 607794,
                    ["name"] = "Rirépine le Tendre",
                }, -- [3]
                {
                    ["id"] = 561,
                    ["image"] = 607683,
                    ["name"] = "Laj",
                }, -- [4]
                {
                    ["id"] = 562,
                    ["image"] = 607816,
                    ["name"] = "Brise-Dimension",
                }, -- [5]
            },
        }, -- [12]
        {
            ["id"] = 256,
            ["image"] = 608207,
            ["name"] = "La Fournaise du sang",
            ["bosses"] = {
                {
                    ["id"] = 555,
                    ["image"] = 607789,
                    ["name"] = "Le Faiseur",
                }, -- [1]
                {
                    ["id"] = 556,
                    ["image"] = 607558,
                    ["name"] = "Broggok",
                }, -- [2]
                {
                    ["id"] = 557,
                    ["image"] = 607670,
                    ["name"] = "Keli'dan le Briseur",
                }, -- [3]
            },
        }, -- [13]
        {
            ["id"] = 253,
            ["image"] = 608193,
            ["name"] = "Labyrinthe des Ombres",
            ["bosses"] = {
                {
                    ["id"] = 544,
                    ["image"] = 607536,
                    ["name"] = "Ambassadeur Gueule-d'Enfer",
                }, -- [1]
                {
                    ["id"] = 545,
                    ["image"] = 607555,
                    ["name"] = "Cœur-Noir le Séditieux",
                }, -- [2]
                {
                    ["id"] = 546,
                    ["image"] = 607625,
                    ["name"] = "Grand Maître Vorpil",
                }, -- [3]
                {
                    ["id"] = 547,
                    ["image"] = 607720,
                    ["name"] = "Marmon",
                }, -- [4]
            },
        }, -- [14]
        {
            ["id"] = 261,
            ["image"] = 608199,
            ["name"] = "Le caveau de la Vapeur",
            ["bosses"] = {
                {
                    ["id"] = 573,
                    ["image"] = 607651,
                    ["name"] = "Hydromancienne Thespia",
                }, -- [1]
                {
                    ["id"] = 574,
                    ["image"] = 607713,
                    ["name"] = "Mekgénieur Montevapeur",
                }, -- [2]
                {
                    ["id"] = 575,
                    ["image"] = 607815,
                    ["name"] = "Seigneur de guerre Kalithresh",
                }, -- [3]
            },
        }, -- [15]
        {
            ["id"] = 258,
            ["image"] = 608218,
            ["name"] = "Le Méchanar",
            ["bosses"] = {
                {
                    ["id"] = 563,
                    ["image"] = 607712,
                    ["name"] = "Mécanoseigneur Capacitus",
                }, -- [1]
                {
                    ["id"] = 564,
                    ["image"] = 607725,
                    ["name"] = "Néantomancienne Sepethrea",
                }, -- [2]
                {
                    ["id"] = 565,
                    ["image"] = 607739,
                    ["name"] = "Pathaleon le Calculateur",
                }, -- [3]
            },
        }, -- [16]
        {
            ["id"] = 255,
            ["image"] = 608198,
            ["name"] = "Le Noir marécage",
            ["bosses"] = {
                {
                    ["id"] = 552,
                    ["image"] = 607566,
                    ["name"] = "Chronoseigneur Déjà",
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
            ["id"] = 260,
            ["image"] = 608199,
            ["name"] = "Les enclos aux esclaves",
            ["bosses"] = {
                {
                    ["id"] = 570,
                    ["image"] = 607715,
                    ["name"] = "Mennu le Traître",
                }, -- [1]
                {
                    ["id"] = 571,
                    ["image"] = 607759,
                    ["name"] = "Rokmar le Crépitant",
                }, -- [2]
                {
                    ["id"] = 572,
                    ["image"] = 607750,
                    ["name"] = "Bourbierreux",
                }, -- [3]
            },
        }, -- [18]
        {
            ["id"] = 259,
            ["image"] = 608207,
            ["name"] = "Les salles Brisées",
            ["bosses"] = {
                {
                    ["id"] = 566,
                    ["image"] = 607624,
                    ["name"] = "Grand démoniste Néanathème",
                }, -- [1]
                {
                    ["id"] = 568,
                    ["image"] = 607811,
                    ["name"] = "Porteguerre O'mrogg",
                }, -- [2]
                {
                    ["id"] = 569,
                    ["image"] = 607812,
                    ["name"] = "Chef de guerre Kargath Lamepoing",
                }, -- [3]
            },
        }, -- [19]
        {
            ["id"] = 252,
            ["image"] = 608193,
            ["name"] = "Les salles des Sethekk",
            ["bosses"] = {
                {
                    ["id"] = 541,
                    ["image"] = 607583,
                    ["name"] = "Sombre tisseur Syth",
                }, -- [1]
                {
                    ["id"] = 543,
                    ["image"] = 607780,
                    ["name"] = "Roi-serre Ikiss",
                }, -- [2]
            },
        }, -- [20]
        {
            ["id"] = 254,
            ["image"] = 608218,
            ["name"] = "L'Arcatraz",
            ["bosses"] = {
                {
                    ["id"] = 548,
                    ["image"] = 607823,
                    ["name"] = "Zereketh le Délié",
                }, -- [1]
                {
                    ["id"] = 549,
                    ["image"] = 607574,
                    ["name"] = "Dalliah l'Auspice-Funeste",
                }, -- [2]
                {
                    ["id"] = 550,
                    ["image"] = 607820,
                    ["name"] = "Scrute-courroux Soccothrates",
                }, -- [3]
                {
                    ["id"] = 551,
                    ["image"] = 607635,
                    ["name"] = "Messager Cieuriss",
                }, -- [4]
            },
        }, -- [21]
        {
            ["id"] = 248,
            ["image"] = 608207,
            ["name"] = "Remparts des Flammes infernales",
            ["bosses"] = {
                {
                    ["id"] = 527,
                    ["image"] = 607817,
                    ["name"] = "Gardien des guetteurs Gargolmar",
                }, -- [1]
                {
                    ["id"] = 528,
                    ["image"] = 607734,
                    ["name"] = "Omor l'Intouché",
                }, -- [2]
                {
                    ["id"] = 529,
                    ["image"] = 607803,
                    ["name"] = "Vazruden le Héraut",
                }, -- [3]
            },
        }, -- [22]
        {
            ["id"] = 249,
            ["image"] = 608208,
            ["name"] = "Terrasse des Magistères",
            ["bosses"] = {
                {
                    ["id"] = 530,
                    ["image"] = 607767,
                    ["name"] = "Selin Cœur-de-Feu",
                }, -- [1]
                {
                    ["id"] = 531,
                    ["image"] = 607806,
                    ["name"] = "Vexallus",
                }, -- [2]
                {
                    ["id"] = 532,
                    ["image"] = 607742,
                    ["name"] = "Prêtresse Delrissa",
                }, -- [3]
                {
                    ["id"] = 533,
                    ["image"] = 607669,
                    ["name"] = "Kael'thas Haut-Soleil",
                }, -- [4]
            },
        }, -- [23]
        {
            ["id"] = 250,
            ["image"] = 608193,
            ["name"] = "Tombes-mana",
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
                    ["name"] = "Prince-nexus Shaffar",
                }, -- [3]
            },
        }, -- [24]
    },
    ["Wrath of the Lich King"] = {
        {
            ["id"] = 753,
            ["image"] = 1396596,
            ["name"] = "Caveau d'Archavon",
            ["bosses"] = {
                {
                    ["id"] = 1597,
                    ["image"] = 1385715,
                    ["name"] = "Archavon le Gardien des pierres",
                }, -- [1]
                {
                    ["id"] = 1598,
                    ["image"] = 1385727,
                    ["name"] = "Emalon le Guetteur d'orage",
                }, -- [2]
                {
                    ["id"] = 1599,
                    ["image"] = 1385748,
                    ["name"] = "Koralon le Veilleur des flammes",
                }, -- [3]
                {
                    ["id"] = 1600,
                    ["image"] = 1385767,
                    ["name"] = "Toravon la Sentinelle de glace",
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
                    ["name"] = "Grande veuve Faerlina",
                }, -- [2]
                {
                    ["id"] = 1603,
                    ["image"] = 1378994,
                    ["name"] = "Maexxna",
                }, -- [3]
                {
                    ["id"] = 1604,
                    ["image"] = 1379004,
                    ["name"] = "Noth le Porte-Peste",
                }, -- [4]
                {
                    ["id"] = 1605,
                    ["image"] = 1378984,
                    ["name"] = "Heigan l'Impur",
                }, -- [5]
                {
                    ["id"] = 1606,
                    ["image"] = 1378991,
                    ["name"] = "Horreb",
                }, -- [6]
                {
                    ["id"] = 1607,
                    ["image"] = 1378988,
                    ["name"] = "Instructeur Razuvious",
                }, -- [7]
                {
                    ["id"] = 1608,
                    ["image"] = 1378979,
                    ["name"] = "Gothik le Moissonneur",
                }, -- [8]
                {
                    ["id"] = 1609,
                    ["image"] = 1385732,
                    ["name"] = "Les quatre cavaliers",
                }, -- [9]
                {
                    ["id"] = 1610,
                    ["image"] = 1379005,
                    ["name"] = "Le Recousu",
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
                    ["name"] = "Saphiron",
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
            ["name"] = "Le sanctum Obsidien",
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
            ["name"] = "L'Œil de l'éternité",
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
                    ["name"] = "Léviathan des flammes",
                }, -- [1]
                {
                    ["id"] = 1638,
                    ["image"] = 1385742,
                    ["name"] = "Ignis le maître de la Fournaise",
                }, -- [2]
                {
                    ["id"] = 1639,
                    ["image"] = 1385763,
                    ["name"] = "Tranchécaille",
                }, -- [3]
                {
                    ["id"] = 1640,
                    ["image"] = 1385773,
                    ["name"] = "Déconstructeur XT-002",
                }, -- [4]
                {
                    ["id"] = 1641,
                    ["image"] = 1390439,
                    ["name"] = "L'assemblée du Fer",
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
                    ["name"] = "Général Vezax",
                }, -- [12]
                {
                    ["id"] = 1649,
                    ["image"] = 1385774,
                    ["name"] = "Yogg-Saron",
                }, -- [13]
                {
                    ["id"] = 1650,
                    ["image"] = 1385713,
                    ["name"] = "Algalon l'Observateur",
                }, -- [14]
            },
        }, -- [5]
        {
            ["id"] = 757,
            ["image"] = 1396594,
            ["name"] = "L'épreuve du croisé",
            ["bosses"] = {
                {
                    ["id"] = 1618,
                    ["image"] = 1390440,
                    ["name"] = "Les bêtes du Norfendre",
                }, -- [1]
                {
                    ["id"] = 1619,
                    ["image"] = 1385752,
                    ["name"] = "Seigneur Jaraxxus",
                }, -- [2]
                {
                    ["id"] = 1620,
                    ["image"] = 1390442,
                    ["name"] = "Champions de l'Alliance",
                }, -- [3]
                {
                    ["id"] = 1622,
                    ["image"] = 1390443,
                    ["name"] = "Jumelles val'kyrs",
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
            ["name"] = "Repaire d'Onyxia",
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
            ["name"] = "Citadelle de la Couronne de glace",
            ["bosses"] = {
                {
                    ["id"] = 1624,
                    ["image"] = 1378992,
                    ["name"] = "Seigneur Gargamoelle",
                }, -- [1]
                {
                    ["id"] = 1625,
                    ["image"] = 1378990,
                    ["name"] = "Dame Murmemort",
                }, -- [2]
                {
                    ["id"] = 1627,
                    ["image"] = 1385736,
                    ["name"] = "Bataille des canonnières de la Couronne de glace",
                }, -- [3]
                {
                    ["id"] = 1628,
                    ["image"] = 1378970,
                    ["name"] = "Porte-mort Saurcroc",
                }, -- [4]
                {
                    ["id"] = 1629,
                    ["image"] = 1378972,
                    ["name"] = "Pulentraille",
                }, -- [5]
                {
                    ["id"] = 1630,
                    ["image"] = 1379009,
                    ["name"] = "Trognepus",
                }, -- [6]
                {
                    ["id"] = 1631,
                    ["image"] = 1379007,
                    ["name"] = "Professeur Putricide",
                }, -- [7]
                {
                    ["id"] = 1632,
                    ["image"] = 1385721,
                    ["name"] = "Conseil des princes de sang",
                }, -- [8]
                {
                    ["id"] = 1633,
                    ["image"] = 1378967,
                    ["name"] = "Reine de sang Lana'thel",
                }, -- [9]
                {
                    ["id"] = 1634,
                    ["image"] = 1379023,
                    ["name"] = "Valithria Marcherêve",
                }, -- [10]
                {
                    ["id"] = 1635,
                    ["image"] = 1379014,
                    ["name"] = "Sindragosa",
                }, -- [11]
                {
                    ["id"] = 1636,
                    ["image"] = 607688,
                    ["name"] = "Le roi-liche",
                }, -- [12]
            },
        }, -- [8]
        {
            ["id"] = 761,
            ["image"] = 1396590,
            ["name"] = "Le sanctum Rubis",
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
            ["name"] = "Ahn'kahet : l'Ancien royaume",
            ["bosses"] = {
                {
                    ["id"] = 580,
                    ["image"] = 607593,
                    ["name"] = "Ancien Nadox",
                }, -- [1]
                {
                    ["id"] = 581,
                    ["image"] = 607744,
                    ["name"] = "Prince Taldaram",
                }, -- [2]
                {
                    ["id"] = 582,
                    ["image"] = 607667,
                    ["name"] = "Jedoga Cherchelombre",
                }, -- [3]
                {
                    ["id"] = 584,
                    ["image"] = 607639,
                    ["name"] = "Héraut Volazj",
                }, -- [4]
            },
        }, -- [10]
        {
            ["id"] = 272,
            ["image"] = 608194,
            ["name"] = "Azjol-Nérub",
            ["bosses"] = {
                {
                    ["id"] = 585,
                    ["image"] = 607678,
                    ["name"] = "Krik'thir le Gardien de porte",
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
            ["id"] = 286,
            ["image"] = 608227,
            ["name"] = "Cime d'Utgarde",
            ["bosses"] = {
                {
                    ["id"] = 641,
                    ["image"] = 607778,
                    ["name"] = "Svala Tristetombe",
                }, -- [1]
                {
                    ["id"] = 642,
                    ["image"] = 607620,
                    ["name"] = "Gortok Pâle-Sabot",
                }, -- [2]
                {
                    ["id"] = 643,
                    ["image"] = 607773,
                    ["name"] = "Skadi le Brutal",
                }, -- [3]
                {
                    ["id"] = 644,
                    ["image"] = 607674,
                    ["name"] = "Roi Ymiron",
                }, -- [4]
            },
        }, -- [12]
        {
            ["id"] = 273,
            ["image"] = 608201,
            ["name"] = "Donjon de Drak'Tharon",
            ["bosses"] = {
                {
                    ["id"] = 588,
                    ["image"] = 607798,
                    ["name"] = "Trollétripe",
                }, -- [1]
                {
                    ["id"] = 589,
                    ["image"] = 607727,
                    ["name"] = "Novos l'Invocateur",
                }, -- [2]
                {
                    ["id"] = 590,
                    ["image"] = 607672,
                    ["name"] = "Roi Dred",
                }, -- [3]
                {
                    ["id"] = 591,
                    ["image"] = 607790,
                    ["name"] = "Le prophète Tharon'ja",
                }, -- [4]
            },
        }, -- [13]
        {
            ["id"] = 285,
            ["image"] = 608226,
            ["name"] = "Donjon d'Utgarde",
            ["bosses"] = {
                {
                    ["id"] = 638,
                    ["image"] = 607743,
                    ["name"] = "Prince Keleseth",
                }, -- [1]
                {
                    ["id"] = 639,
                    ["image"] = 607774,
                    ["name"] = "Skarvald et Dalronn",
                }, -- [2]
                {
                    ["id"] = 640,
                    ["image"] = 607659,
                    ["name"] = "Ingvar le Pilleur",
                }, -- [3]
            },
        }, -- [14]
        {
            ["id"] = 278,
            ["image"] = 608210,
            ["name"] = "Fosse de Saron",
            ["bosses"] = {
                {
                    ["id"] = 608,
                    ["image"] = 607603,
                    ["name"] = "Maître-forge Gargivre",
                }, -- [1]
                {
                    ["id"] = 609,
                    ["image"] = 607677,
                    ["name"] = "Ick et Krick",
                }, -- [2]
                {
                    ["id"] = 610,
                    ["image"] = 607765,
                    ["name"] = "Seigneur du Fléau Tyrannus",
                }, -- [3]
            },
        }, -- [15]
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
                    ["name"] = "Colosse drakkari",
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
        }, -- [16]
        {
            ["id"] = 280,
            ["image"] = 608220,
            ["name"] = "La Forge des Âmes",
            ["bosses"] = {
                {
                    ["id"] = 615,
                    ["image"] = 607559,
                    ["name"] = "Bronjahm",
                }, -- [1]
                {
                    ["id"] = 616,
                    ["image"] = 607585,
                    ["name"] = "Dévoreur d'âmes",
                }, -- [2]
            },
        }, -- [17]
        {
            ["id"] = 283,
            ["image"] = 608228,
            ["name"] = "Le fort Pourpre",
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
                    ["name"] = "Zuramat l'Oblitérateur",
                }, -- [6]
                {
                    ["id"] = 632,
                    ["image"] = 607573,
                    ["name"] = "Cyanigosa",
                }, -- [7]
            },
        }, -- [18]
        {
            ["id"] = 281,
            ["image"] = 608221,
            ["name"] = "Le Nexus",
            ["bosses"] = {
                {
                    ["id"] = 618,
                    ["image"] = 607623,
                    ["name"] = "Grand magus Telestra",
                }, -- [1]
                {
                    ["id"] = 619,
                    ["image"] = 607540,
                    ["name"] = "Anomalus",
                }, -- [2]
                {
                    ["id"] = 620,
                    ["image"] = 607735,
                    ["name"] = "Ormorok le Sculpte-arbre",
                }, -- [3]
                {
                    ["id"] = 621,
                    ["image"] = 607671,
                    ["name"] = "Keristrasza",
                }, -- [4]
            },
        }, -- [19]
        {
            ["id"] = 275,
            ["image"] = 608204,
            ["name"] = "Les salles de Foudre",
            ["bosses"] = {
                {
                    ["id"] = 597,
                    ["image"] = 607611,
                    ["name"] = "Général Bjarngrim",
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
        }, -- [20]
        {
            ["id"] = 277,
            ["image"] = 608206,
            ["name"] = "Les salles de Pierre",
            ["bosses"] = {
                {
                    ["id"] = 604,
                    ["image"] = 607679,
                    ["name"] = "Krystallus",
                }, -- [1]
                {
                    ["id"] = 605,
                    ["image"] = 607706,
                    ["name"] = "Damoiselle de peine",
                }, -- [2]
                {
                    ["id"] = 606,
                    ["image"] = 607797,
                    ["name"] = "Tribunal des Âges",
                }, -- [3]
                {
                    ["id"] = 607,
                    ["image"] = 607772,
                    ["name"] = "Sjonnir le Sculptefer",
                }, -- [4]
            },
        }, -- [21]
        {
            ["id"] = 282,
            ["image"] = 608222,
            ["name"] = "L'Oculus",
            ["bosses"] = {
                {
                    ["id"] = 622,
                    ["image"] = 607590,
                    ["name"] = "Drakos l'Interrogateur",
                }, -- [1]
                {
                    ["id"] = 623,
                    ["image"] = 607802,
                    ["name"] = "Varos Arpentenuée",
                }, -- [2]
                {
                    ["id"] = 624,
                    ["image"] = 607702,
                    ["name"] = "Seigneur-mage Urom",
                }, -- [3]
                {
                    ["id"] = 625,
                    ["image"] = 607687,
                    ["name"] = "Gardien-tellurique Eregos",
                }, -- [4]
            },
        }, -- [22]
        {
            ["id"] = 284,
            ["image"] = 608224,
            ["name"] = "L'épreuve du champion",
            ["bosses"] = {
                {
                    ["id"] = 834,
                    ["image"] = 607621,
                    ["name"] = "Grands champions",
                }, -- [1]
                {
                    ["id"] = 635,
                    ["image"] = 607591,
                    ["name"] = "Eadric le Pur",
                }, -- [2]
                {
                    ["id"] = 636,
                    ["image"] = 607547,
                    ["name"] = "Confesseur d'argent Paletress",
                }, -- [3]
                {
                    ["id"] = 637,
                    ["image"] = 607787,
                    ["name"] = "Le Chevalier noir",
                }, -- [4]
            },
        }, -- [23]
        {
            ["id"] = 279,
            ["image"] = 608219,
            ["name"] = "L'Épuration de Stratholme",
            ["bosses"] = {
                {
                    ["id"] = 611,
                    ["image"] = 607711,
                    ["name"] = "Grancrochet",
                }, -- [1]
                {
                    ["id"] = 612,
                    ["image"] = 607763,
                    ["name"] = "Salramm le Façonneur de chair",
                }, -- [2]
                {
                    ["id"] = 613,
                    ["image"] = 607567,
                    ["name"] = "Chronoseigneur Epoque",
                }, -- [3]
                {
                    ["id"] = 614,
                    ["image"] = 607708,
                    ["name"] = "Mal'Ganis",
                }, -- [4]
            },
        }, -- [24]
        {
            ["id"] = 276,
            ["image"] = 608205,
            ["name"] = "Salles des Reflets",
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
                    ["name"] = "Échapper à Arthas",
                }, -- [3]
            },
        }, -- [25]
    },
}
