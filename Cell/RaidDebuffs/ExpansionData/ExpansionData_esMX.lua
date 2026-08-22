---------------------------------------------------------------------
-- File: Cell\RaidDebuffs\ExpansionData\ExpansionData_esMX.lua
-- Compact runtime aliases for native Spanish instance names (esMX + esES).
---------------------------------------------------------------------

--! WotLK fix: файл обслуживает оба испанских клиента. GetLocale на 3.3.5a
--! различает esES и esMX, но имена наших 74 инстансов у них совпадают в 71 случае
--! (сверка с LibBabble-Zone-3.0), а три расхождения - опечатки в esMX-колонке
--! библиотеки, здесь исправленные. Отдельный файл на esES дал бы копию этой же
--! таблицы, поэтому загружаемся на оба значения.
--! Гейт по native GetLocale(), а не по FrameXML-глобалам LOCALE_esMX/LOCALE_esES:
--! их объявляет клиент в Localization.lua своей локали, и по эталонному дампу
--! enUS-клиента (там только LOCALE_enUS) их существование на испанском 3.3.5a не
--! проверить. GetLocale документирован кодексом и перечисляет оба испанских кода.
local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then return end

--! WotLK fix: у Cell нет полного испанского пейлоада ExpansionData. Рантайму он и
--! не нужен: нужно, чтобы локализованное имя зоны из GetInstanceInfo/GetRealZoneText
--! свелось к канонической английской записи. Подписи в опциях остаются английскими.
--! Имена сверены с WotLK-эры Questie, LibBabble-Zone-3.0 и WeakAuras WotLK.
--! Таблица покрывает все инстансы, у которых на 3.3.5a есть зона: Naxxramas-40 и
--! Scarlet Halls в клиенте не существуют, псевдоним им не нужен.
Cell_ExpansionData.instanceLocale = locale
Cell_ExpansionData.instanceNameAliases = {
    -- Wrath of the Lich King
    ["La Cámara de Archavon"] = "Vault of Archavon",
    ["Naxxramas"] = "Naxxramas",
    ["El Sagrario Obsidiana"] = "The Obsidian Sanctum",
    ["El Ojo de la Eternidad"] = "The Eye of Eternity",
    ["Ulduar"] = "Ulduar",
    ["Prueba del Cruzado"] = "Trial of the Crusader",
    ["Guarida de Onyxia"] = "Onyxia's Lair",
    ["Ciudadela de la Corona de Hielo"] = "Icecrown Citadel",
    ["El Sagrario Rubí"] = "The Ruby Sanctum",
    ["Ahn'kahet: El Antiguo Reino"] = "Ahn'kahet: The Old Kingdom",
    ["Azjol-Nerub"] = "Azjol-Nerub",
    ["Fortaleza de Drak'Tharon"] = "Drak'Tharon Keep",
    ["Gundrak"] = "Gundrak",
    ["Cámaras de Relámpagos"] = "Halls of Lightning",
    ["Cámaras de Reflexión"] = "Halls of Reflection",
    ["Cámaras de Piedra"] = "Halls of Stone",
    ["Foso de Saron"] = "Pit of Saron",
    ["La Matanza de Stratholme"] = "The Culling of Stratholme",
    ["La Forja de Almas"] = "The Forge of Souls",
    ["El Nexo"] = "The Nexus",
    ["El Oculus"] = "The Oculus",
    ["El Bastión Violeta"] = "The Violet Hold",
    ["Prueba del Campeón"] = "Trial of the Champion",
    ["Fortaleza de Utgarde"] = "Utgarde Keep",
    ["Pináculo de Utgarde"] = "Utgarde Pinnacle",
    -- Burning Crusade
    ["Karazhan"] = "Karazhan",
    ["Guarida de Gruul"] = "Gruul's Lair",
    ["Guarida de Magtheridon"] = "Magtheridon's Lair",
    ["Caverna Santuario Serpiente"] = "Serpentshrine Cavern",
    ["El Ojo"] = "The Eye",
    ["Cima Hyjal"] = "The Battle for Mount Hyjal",
    ["El Templo Oscuro"] = "Black Temple",
    ["Meseta de la Fuente del Sol"] = "Sunwell Plateau",
    ["Criptas Auchenai"] = "Auchenai Crypts",
    ["Murallas del Fuego Infernal"] = "Hellfire Ramparts",
    ["Bancal Del Magister"] = "Magisters' Terrace",
    ["Tumbas de Maná"] = "Mana-Tombs",
    ["Antiguas Laderas de Trabalomas"] = "Old Hillsbrad Foothills",
    ["Salas Sethekk"] = "Sethekk Halls",
    ["Laberinto de las Sombras"] = "Shadow Labyrinth",
    ["El Alcatraz"] = "The Arcatraz",
    ["La Ciénaga Negra"] = "The Black Morass",
    ["El Horno de Sangre"] = "The Blood Furnace",
    ["El Invernáculo"] = "The Botanica",
    ["El Mechanar"] = "The Mechanar",
    ["Las Salas Arrasadas"] = "The Shattered Halls",
    ["Recinto de los Esclavos"] = "The Slave Pens",
    ["La Cámara de Vapor"] = "The Steamvault",
    ["La Sotiénaga"] = "The Underbog",
    -- Classic
    ["Núcleo de Magma"] = "Molten Core",
    ["Guarida Alanegra"] = "Blackwing Lair",
    ["Ruinas de Ahn'Qiraj"] = "Ruins of Ahn'Qiraj",
    ["El Templo de Ahn'Qiraj"] = "Temple of Ahn'Qiraj",
    ["Cavernas de Brazanegra"] = "Blackfathom Deeps",
    ["Profundidades de Roca Negra"] = "Blackrock Depths",
    ["Las Minas de la Muerte"] = "Deadmines",
    ["La Masacre"] = "Dire Maul",
    ["Gnomeregan"] = "Gnomeregan",
    ["Cumbre inferior de Roca Negra"] = "Lower Blackrock Spire",
    ["Maraudon"] = "Maraudon",
    ["Sima ígnea"] = "Ragefire Chasm",
    ["Zahúrda Rajacieno"] = "Razorfen Downs",
    ["Horado Rajacieno"] = "Razorfen Kraul",
    ["Monasterio Escarlata"] = "Scarlet Monastery",
    ["Scholomance"] = "Scholomance",
    ["Castillo de Colmillo Oscuro"] = "Shadowfang Keep",
    ["Stratholme"] = "Stratholme",
    ["Las Mazmorras"] = "The Stockade",
    ["El Templo de Atal'Hakkar"] = "The Temple of Atal'hakkar",
    ["Uldaman"] = "Uldaman",
    ["Cuevas de los Lamentos"] = "Wailing Caverns",
    ["Zul'Farrak"] = "Zul'Farrak",
    --! Написания esMX-колонки LibBabble-Zone-3.0 (с её опечатками) - если клиент
    --! отдаёт именно их, сработают они, а не выправленные варианты выше. Две записи
    --! на один инстанс карте не мешают: LoadList кладёт оба ключа на одну цель.
    ["Camáras de Reflexión"] = "Halls of Reflection",
    ["Pueba del Campeon"] = "Trial of the Champion",
}
