---------------------------------------------------------------------
-- File: ExpansionDataOverrides.lua
-- Author: enderneko (enderneko-dev@outlook.com)
-- Created : 2025-03-31 16:35 +08:00
-- Modified: 2025-03-31 17:17 +08:00
---------------------------------------------------------------------

local _, Cell = ...
local F = Cell.funcs

--! WotLK fix: карта переведена на сокращённый список эпох. Это позиции в
--! Cell_ExpansionData.expansions, а он теперь несёт ровно три эпохи 3.3.5a
--! (см. ExpansionData.lua) - семь ретейльных строк указывали за конец списка,
--! то есть from/to стали бы nil, и перенос инстанса молча ничего не делал.
local expansions = {
    ["Wrath of the Lich King"] = 1,
    ["Burning Crusade"] = 2,
    ["Classic"] = 3,
}

-------------------------------------------------
-- overrides
-------------------------------------------------
Cell_ExpansionDataOverrides = {
    -- [instanceId] = {
    --     from = "expansion",
    --     to = "expansion",
    --     bosses = {
    --         "boss1", ...
    --     }
    -- }
}

--! Vanilla-only переносы UBRS/LBRS вырезаны: на 3.3.5 (isVanilla=false)
--! ветка была мёртвой, а инстансы и так лежат на своих местах в WotLK-данных.

-------------------------------------------------
-- do
-------------------------------------------------
for instanceId, data in pairs(Cell_ExpansionDataOverrides) do
    local from = Cell_ExpansionData.expansions[expansions[data.from]]
    local to = Cell_ExpansionData.expansions[expansions[data.to]]
    local bosses = data.bosses

    if Cell_ExpansionData["data"][from] then
        for i = 1, #Cell_ExpansionData["data"][from] do
            if Cell_ExpansionData["data"][from][i]["id"] == instanceId then
                local t = F.Copy(Cell_ExpansionData["data"][from][i])

                -- remove old
                tremove(Cell_ExpansionData["data"][from], i)

                -- replace bosses
                wipe(t.bosses)
                if bosses then
                    for j, name in ipairs(bosses) do
                        tinsert(t.bosses, {
                            id = j,
                            name = name,
                        })
                    end
                end

                -- insert
                tinsert(Cell_ExpansionData["data"][to], t)
                break
            end
        end
    end
end

-------------------------------------------------
-- missing encounters
-------------------------------------------------
--! WotLK fix: пять encounter'ов WotLK держат дебаффы в RaidDebuffs_WotLK.lua, но их
--! bossId нет ни в одном списке боссов ExpansionData - ни здесь, ни в дампе upstream
--! r274, то есть это дефект самого дампа, а не бэкпорта. F.GetDebuffList сливает все
--! ключи bossId инстанса, поэтому в бою эти дебаффы отслеживаются; невидим только
--! список опций, то есть выключить или подкрасить их было нечем (GAP-034).
--! Дозаполняем аддитивно и после всех локальных пейлоадов: у каждого locale-файла
--! свой полный Cell_ExpansionData.data, и правка, размазанная по семи дампам,
--! разъехалась бы при первой же регенерации любого из них.
--! Боссы опознаны по китайским комментариям в самих данных дебаффов, а не по памяти:
--!   [757] 1621 - зеркало 1620 по фракции, набор id совпадает id-в-id;
--!   [271] 583  и [274] 595 - герой-онли боссы Ан'кахета и Гундрака;
--!   [281] 617 и 833 - фракционная пара командиров героического Нексуса.
--! Поле image не задаётся сознательно: боссовая картинка на 3.3.5 отключена совсем
--! (ShowBossImage = function() end в RaidDebuffs_Classic.lua), ApplyTexture
--! нил-безопасен, а ретейловые fileID этому клиенту всё равно не отдать.
--! У каждой записи обязателен якорь after/before из уже существующего списка: он же
--! ставит запись на её место в порядке энкаунтеров и не даёт дозаполнить чужой
--! инстанс, если id инстанса когда-нибудь переиспользуют (как Classic делает с 745).
local missingBosses = {
    [757] = { -- Trial of the Crusader
        {id = 1621, name = "Champions of the Horde", after = 1620},
    },
    [271] = { -- Ahn'kahet: The Old Kingdom
        {id = 583, name = "Amanitar", after = 582},
    },
    [274] = { -- Gundrak
        {id = 595, name = "Eck the Ferocious", after = 594},
    },
    [281] = { -- The Nexus
        {id = 617, name = "Commander Stoutbeard", before = 618},
        {id = 833, name = "Commander Kolurg", after = 617},
    },
}
--! Локализованных строк для этих пяти боссов нет ни в одном пейлоаде upstream,
--! поэтому по умолчанию подписи английские: поле name - только вывод (список кнопок,
--! строка шаринга, запрос сброса), ключом везде служит id. zhCN восстановлен из
--! комментариев RaidDebuffs_WotLK.lua, то есть из данных репозитория.
local missingBossNames = {
    ["zhCN"] = {
        [1621] = "部落的冠军",
        [583] = "埃曼尼塔",
        [595] = "凶残的伊克",
        [617] = "指挥官斯托比德",
        [833] = "指挥官库鲁尔格",
    },
}

local function IndexOfBoss(bosses, bossId)
    for i = 1, #bosses do
        if bosses[i]["id"] == bossId then return i end
    end
end

do
    local names = missingBossNames[Cell_ExpansionData["locale"]]

    for instanceId, additions in pairs(missingBosses) do
        for _, instances in pairs(Cell_ExpansionData["data"]) do
            for _, instance in ipairs(instances) do
                if instance["id"] == instanceId and instance["bosses"] then
                    local bosses = instance["bosses"]

                    for _, add in ipairs(additions) do
                        -- idempotent: if upstream data ever gains the entry, leave it alone
                        if not IndexOfBoss(bosses, add.id) then
                            local anchor = IndexOfBoss(bosses, add.after or add.before)
                            if anchor then
                                tinsert(bosses, add.after and anchor + 1 or anchor, {
                                    ["id"] = add.id,
                                    ["name"] = names and names[add.id] or add.name,
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

-------------------------------------------------
-- missing instances
-------------------------------------------------
--! WotLK fix: Зул'Гуруба и Зул'Амана в данных нет вообще - ни инстанса в списке
--! рейдов, ни одного дебаффа. Причина та же, что у пяти боссов выше: дамп собран из
--! ретейлового Encounter Journal, а там оба рейда существуют только в виде своих
--! переделок Cataclysm (5 человек, другие боссы), поэтому оригинальные рейды 3.3.5a
--! выпали целиком. На этом клиенте они живы и являются именно рейдами: Map.dbc
--! отдаёт карту 309 "Zul'Gurub" (каталог "Zul'gurub") и карту 568 "Zul'Aman"
--! (каталог "ZulAman"), у обеих instanceType = 2. Псевдоним ни одному не нужен:
--! AreaTable.dbc (зоны 1977 и 3805) даёт ровно те же написания, что Map.dbc, а
--! сравнивает ResolveInstance именно их.
--!
--! id инстанса - journalInstanceID ретейла (76 и 77), как весь остальной дамп (см.
--! комментарий про приватные 900745 в ExpansionData.lua). id босса - тот же EJ id
--! там, где энкаунтер в ретейле тот же самый (175, 176, 186..191), и приватный из
--! окна 784..790 там, где ретейл его не знает: в дампе нет ни одного bossId в
--! диапазонах 170..200 и 780..800, так что не пересекается ни с чем.
--!
--! Подписи взяты из полных пейлоадов upstream (Cell-retail/RaidDebuffs/
--! ExpansionData/ExpansionData_*.lua), то есть из данных, а не по памяти. Где
--! ретейл энкаунтер переименовал (Jin'do the Hexxer -> the Godbreaker, Зул'джин ->
--! Даакара) или не знает вовсе (Джеклик, Мар'ли, Текал, Арлокк, Газ'ранка, Хаккар,
--! Край Безумия), подпись английская: name - это только вывод (кнопка списка, строка
--! шаринга, запрос сброса), ключом везде служит id. Поле image не задаётся по той же
--! причине, что у missingBosses: обе картинки на 3.3.5 отключены совсем.
--!
--! Ключ верхнего уровня - ПОЗИЦИЯ эпохи в Cell_ExpansionData.expansions, а не её
--! имя: имя локализовано (в ruRU-пейлоаде третья эпоха называется "Классические
--! подземелья"), и литерал "Classic" совпал бы только на английском клиенте.
local missingInstances = {
    [3] = { -- Classic
        {
            id = 76,
            name = "Zul'Gurub",
            after = 742, -- патч 1.7: между Логовом Крыла Тьмы (1.6) и Руинами Ан'Киража (1.9)
            bosses = {
                {id = 175, name = "High Priest Venoxis"},
                {id = 784, name = "High Priestess Jeklik"},
                {id = 785, name = "High Priest Mar'li"},
                {id = 176, name = "Bloodlord Mandokir"},
                {id = 786, name = "Edge of Madness"},
                {id = 787, name = "High Priest Thekal"},
                {id = 788, name = "Gahz'ranka"},
                {id = 789, name = "High Priestess Arlokk"},
                {id = 185, name = "Jin'do the Hexxer"},
                {id = 790, name = "Hakkar"},
            },
        },
    },
    [2] = { -- Burning Crusade
        {
            id = 77,
            name = "Zul'Aman",
            after = 751, -- патч 2.3: между Чёрным храмом (2.1) и Плато Солнечного Колодца (2.4)
            bosses = {
                {id = 186, name = "Akil'zon"},
                {id = 187, name = "Nalorakk"},
                {id = 188, name = "Jan'alai"},
                {id = 189, name = "Halazzi"},
                {id = 190, name = "Hex Lord Malacrass"},
                {id = 191, name = "Zul'jin"},
            },
        },
    },
}

local missingInstanceNames = {
    ["ruRU"] = {
        [76] = "Зул'Гуруб",
        [175] = "Верховный жрец Веноксис",
        [176] = "Мандокир Повелитель Крови",
        [77] = "Зул'Аман",
        [186] = "Акил'зон",
        [187] = "Налоракк",
        [188] = "Джан'алай",
        [189] = "Халаззи",
        [190] = "Повелитель проклятий Малакрасс",
    },
    ["deDE"] = {
        [76] = "Zul'Gurub",
        [175] = "Hohepriester Venoxis",
        [176] = "Blutfürst Mandokir",
        [77] = "Zul'Aman",
        [186] = "Akil'zon",
        [187] = "Nalorakk",
        [188] = "Jan'alai",
        [189] = "Halazzi",
        [190] = "Hexlord Malacrass",
    },
    ["frFR"] = {
        [76] = "Zul'Gurub",
        [175] = "Grand prêtre Venoxis",
        [176] = "Seigneur sanglant Mandokir",
        [77] = "Zul'Aman",
        [186] = "Akil'zon",
        [187] = "Nalorakk",
        [188] = "Jan'alai",
        [189] = "Halazzi",
        [190] = "Seigneur des maléfices Malacrass",
    },
    ["koKR"] = {
        [76] = "줄구룹",
        [175] = "대사제 베녹시스",
        [176] = "혈군주 만도키르",
        [77] = "줄아만",
        [186] = "아킬존",
        [187] = "날로라크",
        [188] = "잔알라이",
        [189] = "할라지",
        [190] = "사술 군주 말라크라스",
    },
    ["zhCN"] = {
        [76] = "祖尔格拉布",
        [175] = "高阶祭司温诺希斯",
        [176] = "血领主曼多基尔",
        [77] = "祖阿曼",
        [186] = "埃基尔松",
        [187] = "纳洛拉克",
        [188] = "加亚莱",
        [189] = "哈尔拉兹",
        [190] = "妖术领主玛拉卡斯",
    },
    ["zhTW"] = {
        [76] = "祖爾格拉布",
        [175] = "高階祭司溫諾希斯",
        [176] = "血領主曼多基爾",
        [77] = "祖阿曼",
        [186] = "阿奇爾森",
        [187] = "納羅拉克",
        [188] = "賈納雷",
        [189] = "哈拉齊",
        [190] = "妖術領主瑪拉克雷斯",
    },
}

local function IndexOfInstance(instances, instanceId)
    for i = 1, #instances do
        if instances[i]["id"] == instanceId then return i end
    end
end

do
    local names = missingInstanceNames[Cell_ExpansionData["locale"]]

    for pos, additions in pairs(missingInstances) do
        local eName = Cell_ExpansionData["expansions"][pos]
        local instances = eName and Cell_ExpansionData["data"][eName]

        if instances then
            for _, add in ipairs(additions) do
                -- idempotent: if the dump is ever regenerated with the entry, leave it alone
                local exists
                for _, list in pairs(Cell_ExpansionData["data"]) do
                    if IndexOfInstance(list, add.id) then
                        exists = true
                        break
                    end
                end

                if not exists then
                    local bosses = {}
                    for _, b in ipairs(add.bosses) do
                        tinsert(bosses, {
                            ["id"] = b.id,
                            ["name"] = names and names[b.id] or b.name,
                        })
                    end

                    --! Якорь ставит рейд на его место в хронологии патчей, но, в
                    --! отличие от missingBosses, пропавший якорь здесь НЕ повод
                    --! отменить запись: порядок - косметика, а без записи инстанс
                    --! недостижим целиком. Не нашли - дописываем в конец списка.
                    local anchor = IndexOfInstance(instances, add.after)
                    tinsert(instances, anchor and anchor + 1 or #instances + 1, {
                        ["id"] = add.id,
                        ["name"] = names and names[add.id] or add.name,
                        ["bosses"] = bosses,
                    })
                end
            end
        end
    end
end