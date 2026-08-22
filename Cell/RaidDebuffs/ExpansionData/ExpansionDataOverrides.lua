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