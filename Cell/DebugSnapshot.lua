--! WotLK fix: снимок НАТИВНОГО API до загрузки слоя совместимости.
--!
--! Файл обязан грузиться ПЕРВЫМ в Cell.toc — раньше Libs\ClassicAPI\Load.xml и
--! Polyfills.lua. Он запоминает, какие методы виджетов и какие глобалы существуют
--! в клиенте 3.3.5a САМИ ПО СЕБЕ. Дальше `/cell debug shims` показывает разницу:
--! что слой совместимости добавил, а что ПЕРЕОПРЕДЕЛИЛ поверх нативного.
--!
--! Переопределение нативного метода — главный источник перф-налога в бэкпорте:
--! обёртка вызывается из всего аддона и из чужих аддонов (ElvUI/Plater/MRT),
--! поэтому её надо видеть глазами, а не искать grep'ом.
--!
--! Стоимость: ~600 строковых ключей, снимок делается один раз за сессию.

local addonName, ns = ...
_G.Cell = _G.Cell or ns or {}
local Cell = _G.Cell

local snapshot = {
    --! WotLK fix: сохраняем точные ссылки, а не только тип/флаг наличия.
    --! Иначе подмена function -> function или table -> table после снимка невидима.
    widgets = {},   -- тип виджета -> { имя метода = исходная функция }
    globals = {},   -- имя глобала -> исходное значение
    order = {},     -- порядок появления владельцев (кто грузился)
}
Cell.nativeSnapshot = snapshot

-------------------------------------------------
-- метатаблицы виджетов
-------------------------------------------------
-- Скрытый родитель для зондов: фреймы не должны попадать на экран и,
-- главное, EditBox не должен забирать фокус клавиатуры (autoFocus включён
-- по умолчанию на 3.3.5 и молча съедает все нажатия).
local probeParent = CreateFrame("Frame")
probeParent:Hide()

local function RecordMetatable(label, obj)
    if not obj then return end
    local mt = getmetatable(obj)
    local index = mt and mt.__index
    if type(index) ~= "table" then return end

    local t = {}
    for k, v in pairs(index) do
        if type(k) == "string" and type(v) == "function" then
            --! WotLK fix: ссылка нужна для обнаружения подмены метода функцией
            --! того же типа; boolean показывал только появление нового имени.
            t[k] = v
        end
    end
    snapshot.widgets[label] = t
end

local function Probe(frameType, template)
    local ok, obj = pcall(CreateFrame, frameType, nil, probeParent, template)
    if not ok or not obj then return nil end
    if obj.SetAutoFocus then obj:SetAutoFocus(false) end   -- EditBox: не воровать фокус
    if obj.ClearFocus then obj:ClearFocus() end
    if obj.Hide then obj:Hide() end
    return obj
end

do
    local frame = Probe("Frame")
    RecordMetatable("Frame", frame)
    RecordMetatable("Button", Probe("Button"))
    RecordMetatable("CheckButton", Probe("CheckButton"))
    RecordMetatable("EditBox", Probe("EditBox"))
    RecordMetatable("Slider", Probe("Slider"))
    RecordMetatable("StatusBar", Probe("StatusBar"))
    RecordMetatable("ScrollFrame", Probe("ScrollFrame"))
    RecordMetatable("Cooldown", Probe("Cooldown"))
    RecordMetatable("ColorSelect", Probe("ColorSelect"))
    RecordMetatable("MessageFrame", Probe("MessageFrame"))
    RecordMetatable("ScrollingMessageFrame", Probe("ScrollingMessageFrame"))
    RecordMetatable("SimpleHTML", Probe("SimpleHTML"))
    RecordMetatable("PlayerModel", Probe("PlayerModel"))
    --! Без шаблона: OnLoad из GameTooltipTemplate делает
    --! getglobal(self:GetName().."ShoppingTooltip1"), а у безымянного зонда
    --! GetName() возвращает nil -> ошибка конкатенации в FrameXML/GameTooltip.lua.
    --! Метатаблица у типа общая, шаблон для снимка не нужен.
    RecordMetatable("GameTooltip", Probe("GameTooltip"))

    if frame then
        RecordMetatable("Texture", frame:CreateTexture())
        RecordMetatable("FontString", frame:CreateFontString())
        if frame.CreateAnimationGroup then
            local ok, ag = pcall(frame.CreateAnimationGroup, frame)
            if ok and ag then
                RecordMetatable("AnimationGroup", ag)
                local ok2, anim = pcall(ag.CreateAnimation, ag, "Alpha")
                if ok2 and anim then RecordMetatable("Animation", anim) end
            end
        end
    end
end

probeParent:SetScript("OnShow", probeParent.Hide)

-------------------------------------------------
-- глобалы, которых касается слой совместимости
-------------------------------------------------
-- Снимаем не весь _G (это ~4000 имён в памяти на всю сессию), а точечный список
-- того, что Polyfills.lua и ClassicAPI трогают. Список пополнять по мере находок.
local WATCHED = {
    -- юниты и роли
    "UnitGroupRolesAssigned", "UnitIsGroupLeader", "UnitIsGroupAssistant",
    "UnitAura", "UnitBuff", "UnitDebuff", "UnitPower", "UnitPowerMax",
    "UnitPowerType", "UnitInRange", "UnitInRaid", "UnitInParty", "UnitGUID",
    "UnitHealth", "UnitHealthMax", "UnitClass", "UnitClassBase", "UnitName", "UnitExists",
    "UnitGetIncomingHeals", "UnitGetTotalAbsorbs", "UnitGetTotalHealAbsorbs",
    "UnitHasIncomingResurrection", "UnitIsPlayer", "UnitIsUnit",
    -- группа
    "GetNumGroupMembers", "GetNumRaidMembers", "GetNumPartyMembers",
    "GetRaidRosterInfo", "GetPartyAssignment", "IsInGroup", "IsInRaid",
    "IsEveryoneAssistant", "GetInstanceInfo", "IsInInstance",
    -- заклинания и предметы
    "GetSpellInfo", "GetSpellCooldown", "GetSpellCharges", "IsSpellInRange",
    "GetItemInfo", "GetItemCount", "IsItemInRange",
    -- интерфейс
    "CreateFrame", "CreateColor", "WrapTextInColorCode", "PlaySound",
    "SetRaidTargetIconTexture", "GetRaidTargetIndex",
    "RegisterUnitWatch", "UnregisterUnitWatch",
    "RegisterStateDriver", "UnregisterStateDriver",
    "SecureHandlerSetFrameRef", "SecureHandlerWrapScript", "SecureHandlerExecute",
    -- прочее
    "GetBattlegroundInfo", "GetTime", "GetCVar", "GetCVarBool", "SetCVar",
    "SendAddonMessage", "RegisterAddonMessagePrefix",
    "CombatLogGetCurrentEventInfo", "GetClassInfo", "securecallfunction",
    "hooksecurefunc", "GetPhysicalScreenSize", "GetScreenWidth", "GetScreenHeight",
    -- C_* неймспейсы: важно, существовали ли они ДО слоя совместимости
    "C_Timer", "C_Spell", "C_Item", "C_Map", "C_AddOns", "C_ChatInfo",
    "C_UnitAuras", "C_CreatureInfo", "C_PvP", "C_Texture", "C_SpellBook",
    "C_TooltipInfo", "C_IncomingSummon", "C_PlayerInfo", "C_Container",
    "C_ClassTalents", "C_Traits", "C_SpecializationInfo", "C_NamePlate",
    --! То, что занимает отдельный аддон !!!ClassicAPI, если он установлен.
    --! Он грузится раньше Cell, и всё занятое им Cell своим полифиллом уже не создаст.
    --! Первый пойманный случай — SOUNDKIT: у него 12 ключей без U_CHAT_SCROLL_BUTTON,
    --! из-за чего PlaySound(nil) рвал цепочку клика (см. Polyfills.lua, блок SOUNDKIT).
    "SOUNDKIT", "PixelUtil", "Mixin", "CreateFromMixins", "AuraUtil",
    "ColorMixin", "Enum", "CreateVector2D", "WrapTextInColorCode",
    "GetPhysicalScreenSize", "IsAddOnLoaded", "GetAddOnMetadata",
}

--! Что из WATCHED существует в 3.3.5a САМО ПО СЕБЕ — как C-функция (проверено по
--! milkyway-codex) либо как глобал FrameXML (проверено grep'ом по исходникам 3.3.5a).
--! Всё остальное, найденное в _G до загрузки Cell, создано ЧУЖИМ аддоном —
--! на этом клиенте отдельным !!!ClassicAPI, который грузится раньше нас.
--! Без этого разделения список «занято» бесполезен: в нём поровну нормы и конфликтов.
local NATIVE335 = {}
for _, n in ipairs({
    -- C-API (codex)
    "UnitAura", "UnitBuff", "UnitDebuff", "UnitPower", "UnitPowerMax", "UnitPowerType",
    "UnitInRange", "UnitInRaid", "UnitInParty", "UnitGUID", "UnitHealth", "UnitHealthMax",
    "UnitClass", "UnitClassBase", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsUnit",
    "GetNumRaidMembers", "GetNumPartyMembers", "GetRaidRosterInfo", "GetPartyAssignment",
    "GetInstanceInfo", "IsInInstance", "GetSpellInfo", "GetSpellCooldown", "IsSpellInRange",
    "GetItemInfo", "GetItemCount", "IsItemInRange", "CreateFrame", "GetRaidTargetIndex",
    "GetBattlegroundInfo", "GetTime", "GetCVar", "GetCVarBool", "SetCVar",
    "SendAddonMessage", "PlaySound", "GetScreenWidth", "GetScreenHeight",
    "IsAddOnLoaded", "GetAddOnMetadata", "UnitGroupRolesAssigned",
    -- FrameXML 3.3.5a (кодекс их не знает, но они есть)
    "RegisterUnitWatch", "UnregisterUnitWatch", "RegisterStateDriver", "UnregisterStateDriver",
    "SecureHandlerSetFrameRef", "SecureHandlerWrapScript", "SecureHandlerExecute",
    "SetRaidTargetIconTexture", "hooksecurefunc",
}) do NATIVE335[n] = true end

for i = 1, #WATCHED do
    local name = WATCHED[i]
    local v = _G[name]
    if v ~= nil then
        --! WotLK fix: точечный список удерживает только проверяемые значения и
        --! позволяет отличить изменение типа от подмены объекта того же типа.
        snapshot.globals[name] = v
    end
end

snapshot.native = NATIVE335
snapshot.watched = WATCHED
snapshot.ready = true
