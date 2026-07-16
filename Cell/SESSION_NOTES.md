# Cell 3.3.5 Backport — заметки по сессии (передача проекта)

Репозиторий: `Keoo88/Cell-3.3.5-backport`, ветка `master`.
Все фиксы запушены коммитом `0634e35` ("fix: session fixes - power filters,
pet frame, custom indicators, heal prediction").

Референсы, использованные при отладке (исходники, не память):
- Апстрим Cell (retail): github.com/enderneko/Cell — `Indicators/Custom.lua`, `RaidFrames/UnitButton.lua`, `Utils/Utils.lua`
- Нативный FrameXML 3.3.5 (`SecureTemplates.lua/xml`)
- ElvUI (`Core/Cooldowns.lua`), VuhDo (хил-предикшн)

---

## Исправленные баги

### 1. Power Bar Filters не работали вообще
**Симптом:** все фильтры выключены, но полоски силы показываются.
**Причин было три, чинились последовательно:**

1. `Polyfills.lua` — `UnitClassBase` возвращал класс в смешанном регистре
   ("Hunter"), а таблица `powerFilters` использует ключи ВЕРХНИМ регистром
   ("HUNTER"). Лукап молча промахивался. Фикс: безусловное переопределение
   `UnitClassBase` с принудительным `string.upper` (как в retail API).

2. `RaidFrames/UnitButton_Cata_Wrath.lua` — в `ShouldShowPowerBar` бэкпорт
   добавил обход "в соло всегда показывать бар", которого нет в апстриме.
   Фильтры игнорировались вне группы. Обход удалён (сверено с retail).

3. `Utils.lua` — `F.IsPlayer/IsPet/IsNPC/IsVehicle` матчили ретейловые
   строковые GUID ("Player-1-..."), а на 3.3.5 GUID — hex-строка
   ("0x0000000000012345"). Все проверки возвращали nil, юнит не
   классифицировался, фильтры игнорировались для всех членов группы.
   Фикс: разбор типа юнита из hex-цифр GUID (маска старших цифр:
   0/1 = игрок, 3 = NPC, 4 = пет, 5 = машина) + ретейловый фолбэк.

### 2. Пет-фреймы не отображались
**Симптом:** опции Show Solo/Party/Raid Pets включены, фреймов нет.
`RaidFrames/Groups/PetFrame.lua` — на 3.3.5 дети secure-хедера доступны
только через атрибуты `child1..childN`; массивная индексация `header[i]`
(на которую рассчитан `ipairs(header)`) появилась в поздних клиентах.
Циклы задания размера не выполнялись — кнопки оставались 2x2 px
(невидимы, но кликабельны). Фикс: сбор детей в массивную часть `header`
сразу после создания.

### 3. Кастомные индикаторы «мёртвые» + Lua-ошибка
`Indicators/Custom_Classic.lua`:
- `Update()` падал на nil при ауре, совпавшей только через wildcard «0»
  (все ауры): `auras[spell]` = nil -> крэш на каждом UNIT_AURA, весь
  пайплайн аур умирал. Фикс: фолбэк на данные wildcard-записи
  (`auras[0]`), сравнение порядка через `<=` с дефолтом 999.
- Компаратор сортировки `a[1] < b[1]` сравнивал два nil. Бэкпортирован
  nil-safe компаратор из апстрима (фолбэк на время начала ауры).

`RaidFrames/UnitButton_Cata_Wrath.lua`:
- В debuff-цикле не передавался `castByMe` в `I.UpdateCustomIndicators`
  (только в buff-цикле) — фильтр "Cast By: Me" для дебаффов никогда не
  срабатывал. Фикс: `source == "player" or source == "pet"`.

### 4. Хил-предикшн (входящее лечение)
`Polyfills.lua` — `UnitGetIncomingHeals` переведён на
LibHealComm-4.0 `ALL_HEALS` с окном 3 сек и модификатором хила
(паритет с VuhDo): учитываются все хилеры, а не только прямые хилы.

### 5. Клик-касты / лейауты (ранее в сессии)
`Modules/ClickCastings/ClickCastings.lua`, `Modules/Layouts/Layouts.lua` —
правки в составе коммита (регистр классов, применение настроек).

### 6. Краш "attempt to index field '?'" в ShouldShowPowerBar (DEATH KNIGHT)
`Polyfills.lua` (UnitClassBase), `RaidFrames/UnitButton_Cata_Wrath.lua`
(ShouldShowPowerText / ShouldShowPowerBar).
- Симптом: Lua-ошибка при GROUP_ROSTER_UPDATE -> UpdateLayout; в locals
  `class = "DEATH KNIGHT"` — с пробелом. На некоторых серверах второй
  return `UnitClass` — отображаемое имя, а не токен; наш `string.upper`
  давал "DEATH KNIGHT", которого нет в `powerFilters`, и выражение
  `type(powerFilters[class][role])` падало на индексации nil.
- Фикс 1 (полифил): нормализация токена — upper + удаление пробелов,
  валидация по каноническому набору (WARRIOR..DRUID); при провале —
  обратный маппинг через LOCALIZED_CLASS_NAMES_MALE/FEMALE, включая
  первый return UnitClass (покрывает ruRU-клиенты).
- Фикс 2 (защита): в обеих функциях lookup вынесен в локальную
  `filter = table[class]`; вложенный `[role]` берётся только если
  `type(filter) == "table"`, неизвестный класс -> return true
  («показывать power»), как в апстримном фолбэке.

### 7. Power-фильтры TANK/HEALER не работают (DPS работает)
`Polyfills.lua` (UnitGroupRolesAssigned).
- Корень: в 3.3.5a `UnitGroupRolesAssigned` СУЩЕСТВУЕТ нативно (появилась
  с Dungeon Finder, 0x0060C810 — подтверждено по MilkyWay Codex), но со
  СТАРЫМ контрактом: возвращает ТРИ БУЛЕВЫХ (isTank, isHealer, isDamage).
  Наш полифил был обёрнут в `if not UnitGroupRolesAssigned` и на реальном
  клиенте никогда не устанавливался.
- Следствие: `states.role` получал булево — у ЛФД-танка `true` (не
  совпадает ни с одним строковым ключом), у остальных `false` ->
  GetRole фолбэкался в "DAMAGER". Симптом: DPS-фильтр применялся ко
  всем, TANK/HEALER — никогда. Ролевые иконки от этого тоже страдали.
- Фикс: обёртка определяется БЕЗУСЛОВНО. Нативный результат
  конвертируется в retail-контракт (одна строка); если нативный API
  роли не знает (не-ЛФД группа) — прежняя цепочка фолбэков:
  GetRaidRosterInfo -> MAINTANK/MAINASSIST -> LibGroupInfo(specRole) ->
  "DAMAGER". Строковый return нативной функции (кастомные ядра с уже
  бэкпорченным контрактом) пропускается как есть после валидации.
- Ограничение: вне ЛФД роль танка/хила определяется только через
  назначение MAINTANK или talent-скан LibGroupInfo (inspect). Есл��
  библиотека ещё не успела опросить юнита — он временно "DAMAGER".

### 7b. РЕГРЕССИЯ фикса №7: спам «pet/bossN is not in your party.»
`Polyfills.lua` (UnitGroupRolesAssigned). После установки обёртки
безусловно (фикс №7) фолбэк-цепочка стала выполняться для ВСЕХ юнитов,
включая петов и spotlight-боссов. `GetPartyAssignment("MAINTANK"/
"MAINASSIST", unit)` на этом ядре серверно валидируется: для юнита вне
группы сервер шлёт ERR_NOT_IN_YOUR_PARTY — «pet/raidpetN/bossN is not
in your party.» дважды на кнопку при каждом roster-апдейте/релоге.
Фикс: перед фолбэк-цепочкой guard — не-игрок или игрок вне нашей
группы -> сразу "NONE" (retail-контракт для петов такой же). Нативный
LFD-вызов (клиентский) остаётся для всех юнитов.
Урок (повторно, ср. регрессию №10): в полифилах НЕ вызывать серверно-
валидируемые party-функции (GetPartyAssignment, UnitIsPartyLeader,
Promote*) для юнитов, которые не подтверждены как члены группы.

### 8. UNIT_MAXPOWER никогда не приходит (аудит по паттерну бага №7)
`RaidFrames/UnitButton_Cata_Wrath.lua` (CheckPowerEventRegistration,
UnitButton_RegisterEvents, UnitButton_OnEvent).
- Корень: событие `UNIT_MAXPOWER` добавлено в 4.0 — в 3.3.5 его НЕТ
  (сверено с MilkyWay Codex). Клиент шлёт per-power-type события:
  UNIT_MAXMANA / UNIT_MAXRAGE / UNIT_MAXFOCUS / UNIT_MAXENERGY /
  UNIT_MAXRUNIC_POWER / UNIT_MAXHAPPINESS. Регистрация несуществующего
  события в 3.3.5 не ошибается — оно просто никогда не срабатывает.
- Симптом: максимум ресурса не обновлялся на лету (бафы интеллекта —
  ЧА/Кингс, левел-ап) — заполнение полоски power врало до следующего
  полного апдейта (DISPLAYPOWER / roster).
- Фикс: нативные UNIT_MAX* зарегистрированы в обоих местах регистрации
  и добавлены в ветку диспатчера рядом с UNIT_MAXPOWER (само
  UNIT_MAXPOWER оставлено для кастомных ядер с бэкпортом события).

---

## Полный аудит API/событий по паттерну «retail-контракт на 3.3.5»
(триггер — баги №6/№7; сверка каждого подозреваемого с MilkyWay Codex)

Проверено и ПРАВИЛЬНО в текущем коде (не трогать):
- `GROUP_ROSTER_UPDATE` — нет в 3.3.5, но в Polyfills есть proxy-слой:
  PARTY_MEMBERS_CHANGED / RAID_ROSTER_UPDATE / PARTY_MEMBER_ENABLE /
  PARTY_MEMBER_DISABLE -> синтетический GROUP_ROSTER_UPDATE всем
  зарегистрированным фреймам. Работает.
- `UNIT_HEAL_PREDICTION` — нет в 3.3.5; синтезируется в Polyfills через
  колбэки LibHealComm (EventHandler.Define/Fire). Работает.
- `INCOMING_RESURRECT_CHANGED` — синтетический диспатч в Polyfills
  (LibResComm/CLEU). В UnitButton регистрация закомментирована —
  как в исходном бэкпорте; иконка реза обновляется полным апдейтом.
- `UNIT_HEALTH_FREQUENT`, `UNIT_POWER`, `UNIT_CONNECTION` — мёртвые
  регистрации (событий нет в 3.3.5), но безвредны: рядом everywhere
  зарегистрированы нативные аналоги (UNIT_HEALTH, UNIT_MANA и т.п.),
  offline покрыт roster-proxy. Оставлены для кастомных ядер.
- Ауры: скан идёт через `Cell.UnitBuff/Cell.UnitDebuff` — обёртки
  корректно выбрасывают `rank` (2-й return 3.3.5) и отдают retail-формат.
  Единственный прямой вызов `UnitBuff` использует только 1-й return.
- `GetSpellInfo` — 3.3.5-контракт (castTime на 7-й позиции!), но addon
  берёт только name/icon/rank через `F.GetSpellInfo` — безопасно.
- CLEU — два обработчика, оба с ветками «есть/нет
  CombatLogGetCurrentEventInfo» и правильным порядком аргументов 3.3.5
  (без hideCaster/raidFlags).
- `UnitDetailedThreatSituation`, `GetThreatStatusColor`,
  `GetInstanceInfo` (берётся только name), `LoadAddOn`, `GetUnitName`,
  vehicle-функции — нативные, контракты совпадают.
- `C_Spell`/`C_UnitAuras`/`C_Item`-полифилы — маппинг проверен, верный.

Исправлено в этом аудите: №8 (UNIT_MAXPOWER).

### 9. RegisterAttributeDriver: двойной префикс "state-state-visibility"
`Polyfills.lua`. Контракты отличаются на префикс: в 4.0+
`RegisterAttributeDriver(frame, attribute, cond)` принимает ПОЛНОЕ имя
атрибута ("state-visibility"), а `RegisterStateDriver(frame, state, cond)`
в 3.3.5 сам добавляет "state-". Старый сквозной проброс превращал
"state-visibility" в атрибут "state-state-visibility", у которого нет
спец-обработки в SecureStateDriverManager — драйвер видимости пет-фрейма
(PetFrame.lua:270) молча не работал. Фикс: срез префикса "state-" перед
делегированием (и в Unregister-паре тоже).

### 10. UnitIsGroupLeader/Assistant: false для всех кроме себя в рейде
`Polyfills.lua`. Старая реализация «не можем проверить в WotLK» возвращала
false для любого рейдового юнита кроме игрока — иконки лидера/ассиста не
рисовались на чужих фреймах (UnitButton:1852). На деле 3.3.5 отдаёт это
через `GetRaidRosterInfo(index)`: rank 2 = лидер, 1 = ассистент; индекс =
`UnitInRaid(unit) + 1` (UnitInRaid в 3.3.5 0-based — сверено с Codex).
- РЕГРЕССИЯ (исправлена): для не-рейдовых юнитов первый вариант фикса
  звал `UnitIsPartyLeader(unit)`. На этом ядре она серверная: для юнита
  вне группы сервер шлёт ERR_NOT_IN_YOUR_PARTY — после появления
  пет-кнопок чат спамило «raidpetN is not in your party.» на каждый
  roster-апдейт (по 2 раза: вызов на кнопку из UnitButton:1852).
  Заменено на чисто клиентские проверки: `IsPartyLeader()` для игрока,
  `GetPartyLeaderIndex()` + `UnitIsUnit(unit, "partyN")` для остальных;
  всё прочее (petы, вне группы) -> false без обращения к серверу.
  Урок: в полифилах избегать функций с серверной валидацией юнита.

### 11. GetNumGroupMembers: соло возвращал 1 вместо 0
`Polyfills.lua`. Retail-контракт: 0 вне группы. Текущие сайты вызова не
зависели, но любая будущая проверка `== 0` ло��������а��������������ась бы. Выровнено.

Проверено дополнительно и ПРАВИЛЬНО (вторая волна аудита):
- Виджет-шимы метатаблиц (SetSmoothedValue, HookScript, Cooldown swipe,
  SetReverseFill, маски, FlipBook, SetIgnoreParentAlpha и т.д.) — все
  защищены `not mt.__index.X`, нативные методы не перезаписываются.
- `PlaySound`-обёртка — правильно отбрасывает retail-канал, pcall.
- `SOUNDKIT` — маппинг на строковые имена звуков 3.3.5, верный.
- `GetSpellBookItemName` -> GetSpellInfo(index, bookType) — валидно
  в 3.3.5; `Ambiguate` — нет нативной, полифил ок.
- `IsEncounterInProgress` — нативной нет (Codex), безусловный stub ок.
- `IsInRaid`/`IsInGroup` — семантика retail соблюдена.
- `BNSendGameData`, `RegisterAddonMessagePrefix`, `C_ChatInfo.*`,
  `BackdropTemplateMixin`, `IsEveryoneAssistant`, `Mixin`,
  `LocalizedClassList`, `GetClassColor`, `GetNumClasses` — нативных
  нет, полифилы корректны.
- `GetNormalizedRealmName` — намеренная безусловная перезапись
  (на Ascension н��тивная сломана), оставлено.

### 12. C_Spell.GetSpellCooldown: кортеж вместо таблицы (hard error)
`Polyfills.lua`. Retail-контракт возвращает ТАБЛИЦУ SpellCooldownInfo
(startTime, duration, isEnabled, modRate), полифил возвращал кортеж
чисел. Utils.lua:2028 идёт по C_Spell-ветке и делает `info.startTime` —
индексация числа -> Lua-ошибка, `F.IsSpellReady` был сломан целиком.
Фикс: полифил возвращает retail-таблицу (nil при неизвестном спелле).

### 13. C_Spell.IsSpellInRange / C_Item.IsItemInRange: 0 truthy
`Polyfills.lua`. Retail-контракт — BOOLEAN; нативные функции 3.3.5
возвращают 1/0/nil, а 0 (вне дальности) в Lua truthy. Utils.lua
берёт retail-ветку (`UnitInSpellRange` б��з `== 1`, hostile item-check) —
юниты ВНЕ дальности считались в дальности: range-fade фактически не
работал через эти ветки. Фикс: оба полифила конвертируют 1/0 -> true/
false (nil пропускается как nil — «нельзя проверить»).

Проверено дополнительно и ПРАВИЛЬНО (третья волна, весь файл до конца):
- Верх файла: flavor-шим, GetPhysicalScreenSize (gxResolution CVar),
  PixelUtil, SetGradient/CreateColor, colorStr-дериватор, обёртка
  CreateFontString/GetStatusBarTexture, SmoothStatusBarMixin — ок.
- UnitHasIncomingResurrection + синтетический INCOMING_RESURRECT_CHANGED
  (LibResComm, weak-table хук RegisterEvent) — контракт и GC ок.
- C_Map/C_PvP/C_TooltipInfo/GameTooltip:SetSpellByID (через
  SetHyperlink), C_AddOns-зеркало, C_ClassTalents/C_Traits/C_NamePlate
  стабы — ок.
- Слайдер (userChanged через флаг _isProgrammaticChange), Frame:Run()
  (loadstring+setfenv+pcall), пиксель-перфект/RotateTexture/SetPowerSize
  обёртки, AnimationGroup-совместимость, Click-Castings Fixes 1-5
  (ScrollFrame, frame level, spell list + Binding Heal, анимации,
  LibCustomGlow acUpdate) — логика верная, идемпотентные патчи.
- Известное «не баг»: C_AddOns.GetAddOnEnableState использует классический
  порядок аргументов (character, name); retail поменял на (name,
  character), но в 3.3.5 нативной функции нет и ветка мертва — не трогать,
  пока какой-нибудь аддон реально не позовёт с retail-порядком.

### 14. Анимация «прыжка» иконки двигает только фон (галочка Show Animation)
`Indicators/Base.lua` (НОВЫЙ файл в рабочем наборе — взят из репозитория).
- Симптом (тестер): при включённой «Показывать анимацию» при рефреше ауры
  подпрыгивает только задний план; при выключенной — иконка прыгает
  полноценно.
- Корень: в 3.3.5 AnimationGroup трансформирует только РЕГИОНЫ своего
  фрейма — дочерние фреймы за родителем НЕ следуют (retail это изменил
  позже). Jump-анимация (frame.ag, Translation вверх/вниз) создана на
  фрейме индикатора, а видимые части живут на детях:
  - BarIcon: vertical-cooldown StatusBar несёт ЯРКУЮ КОПИЮ иконки
    (cooldown.icon) поверх приглушённой frame.icon. Галочка ON ->
    cooldown показан -> его копия стоит на месте, прыгает лишь подложка.
    Галочка OFF -> cooldown скрыт -> видна frame.icon (регион) -> прыгает.
  - BorderIcon: icon/stack/duration лежат на child-фрейме iconFrame.
  - Block: stack/duration лежат на frame.cooldown.
- Фикс: хелперы CreateJumpAG + Shared_SyncJumpToChildren — на детях
  (cooldown, iconFrame) лениво создаются идентичные Translation-группы
  и проигрываются синхронно через OnPlay родительской группы. Ленивое
  создание в OnPlay покрывает пересоздание cooldown при смене стиля
  (CLOCK <-> VERTICAL). Подключено в CreateAura_BarIcon,
  CreateAura_BorderIcon, CreateAura_Block.
- Примечание по семантике: галочка «Показывать анимацию» в этой версии
  Cell управляет видимостью cooldown-свайпа (BarIcon_ShowAnimation
  показывает/скрывает frame.cooldown), а jump при рефреше играется
  всегда — это поведение апстрима, не менялось.

### 16. Галочка «Показывать анимацию» вообще ничего не делает (verticalcd)
`Indicators/Base.lua` (VerticalCooldown_*, Shared_CreateCooldown_Vertical
и _NoIcon). Репорт: кастомный индикатор (icons), спеллы добавлены,
галочка вкл/выкл — визуально ноль изменений.
- Корень: retail-визуал вертикального кулдауна собран на ДВУХ API,
  которых нет в 3.3.5: CreateMaskTexture (8.0+) и SetReverseFill (4.2+,
  наш полифил — no-op). Заливка StatusBar невидима by design (alpha 0 —
  она лишь якорь маски), маска на Wrath пропускалась (`if not
  Cell.isWrath`), и яркая копия иконки (cooldown.icon) перекрывала ВСЮ
  иконку статично. ON и OFF выглядели одинаково.
- Фикс: ручная эмуляция маски — чёрный overlay (OVERLAY-слой, alpha
  0.7) поверх иконки, высота = elapsed/duration * height, обновляется
  из VerticalCooldown_OnUpdate (тик 0.1s); затемнение растёт сверху
  вниз, spark едет по нижней кромке overlay. В NoIcon-варианте нативная
  bottom-up заливка (затем��ял�� бы ОСТАВШ��ЕС�� время) погашена, тот же
  overlay. Путь настройки (checkbutton -> ShowAnimation -> SetCooldown)
  проверен весь — он был исправен, сломан был только рендер.

### 15. Правый клик «Меню» (togglemenu) молча не работал
`Modules/ClickCastings/ClickCastings.lua`.
- Корень: secure-тип "togglemenu" появился в 4.x — SecureTemplates 3.3.5
  его не знает, а дефолтные клик-касты (Core_Wrath.lua) ставят именно
  {"type2", "togglemenu"}. Плюс никто не задавал Lua-поле `button.menu`,
  которое вызывает тип "menu" в 3.3.5.
- Фикс (3 части):
  1) ApplyClickCastings транслирует "togglemenu" -> "menu" (non-retail);
  2) в secure-снippetах restore-логики (wrapFrame _onstate-combatstate и
     non-retail _onenter) значение "togglemenu" заменено на "menu" —
     retail-ветка (строка ~268) не тронута;
  3) добавлен ShowUnitMenu: общий UIDropDownMenu + UnitPopup_ShowMenu
     (подход Clique/oUF на WotLK), меню SELF/VEHICLE/PET/RAID_PLAYER/
     PARTY/PLAYER/TARGET; `b.menu = ShowUnitMenu` ставится в
     ApplyClickCastings. RAID_PLAYER использует UnitInRaid(unit)+1
     (0-based, см. фикс №10).
- Инцидент при правке: Edit по неуникальному контексту склеил retail и
  non-retail ветки SetBindingClicks (снесло 32 строки) — замечено по
  diff, восстановлено полностью, финальный git diff чистый (+69/-2).
  Урок: для повторяющихся снippet-блоков брать больший контекст.

## Аудит: четвёртая волна (файлы вне Polyfills.lua)
- Порядок загрузки .toc: Polyfills.lua первый -> локальные кэши API в
  UnitButton (`local UnitClassBase = ...` и т.п.) получают наши обёртки.
- `select(2, UnitClass(unit))` в Utils.lua:1204 безо��асен: результат идёт
  только в F.GetClassColor -> NormalizeClassToken (обрабатывает
  display-имена и локализацию через CLASS_NAME_TO_TOKEN).
- `UnitPhaseReason` в Utils.lua — мёртвая ветка за Cell.isRetail.
- F.IterateGroupMembers/IterateGroupPets корректны с новым соло-нулём
  GetNumGroupMembers (ветка i==0 отдаёт "player" безусловно).
- Layouts.lua: подозрительных API нет (C_Timer покрыт полифилом).

### 17. Индикатор «граница» заливал всю кнопку сплошным цветом
`Indicators/Base.lua` (CreateAura_Border). Пятая волна аудита: Base.lua
целиком на retail-API.
- Корень: retail-граница — полноразмерная цветная текстура, у которой
  ЦЕНТР вырезают две mask-текстуры (CreateMaskTexture, 8.0+). Наши
  полифилы масок — no-op (AddMaskTexture ничего не делает), поэтому
  «граница» рисовалась сплошным цветным квадратом поверх всей кнопки.
- Фикс: Wrath-ветка CreateAura_Border_Wrath — рамка из четырёх краевых
  текстур (top/bottom/left/right) с сохранением API-поверхности:
  `border.tex` — прокси с SetVertexColor, раскрашивающий все 4 края
  (Border_SetCooldown не изменён), свои SetThickness/UpdatePixelPerfect.
  Retail-ветка нетронута.

## Аудит: пятая волна (Indicators/Base.lua целиком)
Проверено и ПРАВИЛЬНО:
- Vertical cooldown: маска создаётся только `if not Cell.isWrath` — на
  Wrath работает наш overlay (фикс №16).
- `SetShown` (5.0+) в Base.lua:82,87 и UnitButton:1750 — бэкпортирован
  бандл-библиотекой ClassicAPI (Libs/ClassicAPI/Util/WidgetAPI.lua),
  Libs грузятся первыми в .toc.
- `SetColorTexture` (7.0+), `SetGradient`+`CreateColor`,
  Cooldown-методы (SetSwipeTexture/Color, SetDrawEdge,
  SetHideCountdownNumbers), OnCooldownDone, FlipBook — все покрыты
  полифилами (проверены соответствия сайтов вызова и шимов).
- `SetSwipeColor` вызывается с явной альфой (4 арга) — совместимо с
  бэкпортом ClassicAPI, отмечено комментариями в коде.
- `SetDesaturated` — нативный в 3.3.5.
- BorderIcon `cooldown:_SetCooldown` — переименование из Clock-креатора
  (защита от OmniCC), корректно.

### 18. VEHICLE-иконка роли: retail GUID-паттерн (шестая волна)
`RaidFrames/UnitButton_Cata_Wrath.lua:1832` (UnitButton_UpdateRole).
- Корень: `strfind(guid, "^Vehicle")` — retail-формат GUID; в 3.3.5
  GUID hex-строка, проверка никогда не срабатывала, CheckVehicleRoot
  не вызывался — VEHICLE-иконка не показывалась на рутах машин.
  Тот же класс бага, что в фиксе №1 (Utils).
- Фикс: `F.IsVehicle(guid)` — парсит и hex 3.3.5, и retail-формат.

## Аудит: шестая волна (PetFrame, хвост UnitButton, остальное)
Проверено и ПРАВИЛЬНО:
- PetFrame.lua: RAID_ROSTER_UPDATE нативное; RegisterAttributeDriver
  теперь корректен (фикс №9); секьюр-атрибуты стандартные.
- C_Timer-полифил полный: After/NewTimer/NewTicker (+двоеточие-формы),
  :Cancel()/:IsCancelled(), пул не переиспользует хендлы NewTimer/
  NewTicker (защита от stale Cancel) — все 10+ сайтов Layouts.lua и
  UnitButton работают.
- Хвост UnitButton (2000-4200): GetThreatStatusColor, UnitIsAFK/DND/
  FeignDeath, UnitIsCharmed, UnitHasVehicleUI, UnitName/GetUnitName —
  нативные или покрыты; прочих retail GUID-паттернов нет (grep чист).
- GetTexCoordsForRole* нигде не используется (иконки ролей — свои
  текстуры Cell).
- Custom_Classic.lua: хвост файла — конец секьюр-снippet-строки, ок.
АУДИТ ЗАВЕРШЁН: все 8 файлов рабочего набора пройдены полностью
(Polyfills, Utils, UnitButton, PetFrame, Base, Custom_Classic,
ClickCastings, Layouts). Итог: 18 багов исправлено, 2 регрессии
поймано и устранено.

### 19. Cell ломал ЧУЖИЕ текстуры: белый прямоугольник (spark ElvUI)
`Polyfills.lua`. Репорт: при включённом Cell спарк на полосах ElvUI
(aurabar таргета) — сплошной белый прямоугольник. Сверено с исходниками
ElvUI-WotLK (github.com/ElvUI-WotLK/ElvUI): spark аурабара создаётся
как `statusBar:CreateTexture(nil, "OVERLAY")` и якорится к
`statusBar:GetStatusBarTexture()` (oUF_AuraBars.lua:102-107).
- НАСТОЯЩИЙ корень — враппер GetStatusBarTexture на ОБЩЕЙ метатаблице
  StatusBar: при nil от н��тивн��го вызова region-scan брал ПЕРВУЮ
  текстуру-регион бара — у аурабара ElvUI ею мог оказаться сам spark.
  Затем враппер SetStatusBarTexture «синхр����и��ировал» кэш — то есть
  ПЕРЕЗАПИСЫВАЛ текстуру спарка плоской текстурой полосы; с ADD-блендом
  это выглядит как белый прямоугольник.
- Фикс (обёртки стали безопасны для чужих баров):
  1) region-scan теперь принимает только ARTWORK-слой (внутренняя
     заливка статусбара) и, если известен кэшированный путь, только
     текстуру с совпадающим путём — spark (OVERLAY) не захватывается;
  2) SetStatusBarTexture синхронизирует ТОЛЬКО текстуру, созданную нами
     (_cellStatusBarTextureCreated), а сканированный кэш сбрасывает —
     следующий Get разрешит заново через натив.
  3) (попутно) фолбэк SetAtlas-враппера: SetTexture(nil) заменён на
     SetTexture(0,0,0,0) — в 3.3.5 SetTexture(nil) рисует непрозрачный
     БЕЛЫЙ квадрат, а не очищает.
- Урок: правки общих метатаблиц перехватывают ВСЕ аддоны; эвристики
  типа «первый регион — наверняка нужный» недопустимы, любые фолбэки
  обязаны быть строго верифицированными и безобидными.

## Аудит: седьмая волна (кросс-аддонное влияние, по мотивам №19)
Пройдены ВСЕ глобальные перехваты Polyfills.lua с точки зрения «что
видят другие аддоны». Новых багов НЕ найдено. Проверено и ПРАВИЛЬНО:
- Метатаблица-полифилы (SetColorTexture, SetMouseClickEnabled,
  IsTruncated, SetRotation, WrapTextInColorCode, Smoothed*,
  SetFromAlpha/SetToAlpha) — добавляются только при отсутствии метода,
  ничего не перезаписывают.
- Врапперы поверх существующих методов (SetGradient/SetGradientAlpha,
  SetAtlas, Set/GetStatusBarTexture, Slider SetValue/SetScript,
  CreateFontString) — прозрачны для чужих сигнатур; после фикса №19
  не трогают чужие текстуры. Slider-враппер меняет только nil ->
  вычисленный userChanged (3.3.5-аддоны третий арг игнорируют).
- Синтетическая доставка событий (INCOMING_RESURRECT_CHANGED,
  GROUP_ROSTER_UPDATE, UNIT_HEAL_PREDICTION через EventHandler) — все
  вызовы чужих OnEvent обёрнуты в pcall; hooksecurefunc-хуки
  RegisterEvent фильтруют по имени события (только registration-time,
  оверхед ничтожен); rezFrames/groupRosterFrames — weak-таблицы.
- SetTexture(nil) больше нигде не используется (grep чист).
- Глобальные имена: всё с префиксом Cell/_Cell, кроме намеренного
  API-полифила _G.IsEveryoneAssistant.
- SecureHandler_SetFrameRef: глобальная замена молча глотает невалидные
  refFrame вместо ошибки — поведение мягче оригинала, безопасно.

## Аудит: восьмая волна (секьюр-снippetы vs restricted env 3.3.5)
Сверено с НАСТОЯЩИМ FrameXML 3.3.5 (tekkub/wow-ui-source, тег 3.3.5:
RestrictedEnvironment/RestrictedExecution/RestrictedFrames/
SecureHandlers.lua). Новых багов НЕТ — весь снippet-код Cell легален:
- Функции env: strsplit/strfind/gsub/strupper/print/string.* — в
  RESTRICTED_FUNCTIONS_SCOPE; pairs/newtable — RestrictedTable_*
  (RestrictedExecution:672); `table.new` СУЩЕСТВУЕТ в 3.3.5
  (LOCAL_Table_Namespace, :544 — не пришлось менять на newtable);
  UnitHasVehicleUI — обёртка ENV (:213), PlayerInCombat (:204).
- Методы хендлов: ClearBindings (:525), SetBindingClick (:533),
  IsUnderMouse (:351), SetAttribute/GetName/GetParent/SetWidth — все в
  RestrictedFrames.lua; control:RunFor (:794) и control:CallMethod
  (:893) — в SecureHandlers.lua.
- `self:Run(...)` остаётся ТОЛЬКО в retail-ветке SetBindingClicks
  (ClickCastings:243); non-retail ветка использует control:RunFor
  (наш ранний фикс) — граница веток корректна.
- RegisterUnitWatch в снippetе PetFrame — закомментирован, не баг.
Справочник: /tmp/frameXML335 — полный FrameXML 3.3.5 для будущих
сверок ограниченного окружения.

### 20. ФИЧА (запрос тестера): отдельная галочка «прыжок» при обновлении
Не баг — осознанное отступление от апстрима (там jump-анимация играется
безусловно). Новая настройка showJump для кастомных индикаторов
icon/icons; nil в старых БД = включено (легаси-поведение).
- `Indicators/Base.lua`: Shared_ShowJump (frame.showJump), гейт всех
  5 сайтов `frame.ag:Play()` условием `showJump ~= false`; методы
  ShowJump навешаны на BarIcon/BorderIcon/Block + групповые
  Icons_ShowJump (icons/blocks).
- `Widgets/Widgets_IndicatorSettings.lua`: НОВЫЙ в воркспейсе (копия
  апстрима + правки): CreateSetting_CheckButton5 + ветка диспатча
  `^checkbutton5` (ДО `^checkbutton4` — порядок важен, find по префиксу).
- `Modules/Indicators/Indicators.lua`: НОВЫЙ в воркспейсе (копия
  апстрима + правки): "checkbutton5:showJump" в settingsTable
  icon/icons; ветки применения в 3 местах (превью-load, live-dispatch,
  create); в генерик-загрузчике чекбоксов nil showJump материализуется
  в true (синхронизация галочки с БД); локаль L["showJump"]
  (ru/zhCN/en) через rawget — ключа в апстрим-локалях нет.
- `RaidFrames/UnitButton_Cata_Wrath.lua`: применение на РЕАЛЬНЫХ
  кнопках — при загрузке (:342), live-переключение (:941, без
  UpdateAuras — прыжок не влияет на layout), при create (:1045).
- Все appliers защищены `indicator.ShowJump and` — text/bar-индикаторы
  без метода сохраняют легаси-поведение.
ВАЖНО для пользователя: файлы Widgets_IndicatorSettings.lua и
Modules/Indicators/Indicators.lua добавлены в воркспейс из апстрима с
правками — при переносе в аддон они ЗАМЕНЯЮТ соответствующие файлы.

### 21. ХП петов навсегда «фулл» в пет-фрейме
`RaidFrames/UnitButton_Cata_Wrath.lua` (UnitButton_OnTick).
- Репорт: у пета реально неполное ХП, но бар в Cell всегда полный.
- Корень: в 3.3.5 UNIT_HEALTH/UNIT_MAXHEALTH НЕ приходят надёжно для
  пет-юнитов (partypetN/raidpetN) — бар не обновлялся с момента
  создания. Подтверждено FrameXML 3.3.5: собственный PetFrame Blizzard
  не полагается на события, а опрашивает HP через frequentUpdates
  (UnitFrame.lua:48,199 ��� OnUpdate-полллинг с predictedHealth).
- Фикс: в UnitButton_OnTick (тик 0.5с) для displayedUnit с "pet" в
  имени сравниваем UnitHealth/UnitHealthMax с кэшем states; при
  изменении дергаем UpdateHealthMax/UpdateHealth. Только петы —
  на игроках события работают, лишнего опроса нет.

## Аудит полифилов: перф-ревизия (репорт «фризы»), сравнение с ElvUI
ElvUI-WotLK написан НАТИВНО под 3.3.5: ноль полифилов, прямые
UnitAura/UnitBuff, ноль pcall в аура-пути. Cell — порт с ретейла и
платил «налог на трансляцию» на самом горячем пути.

### 22. Перф: аура-сканы переведены с врапперов на нативный API
- Горячий путь (2×40 итераций на каждый UNIT_AURA на каждой кнопке):
  Cell.UnitBuff/Cell.UnitDebuff — лишний вызов + перекладка 16
  возвратов на каждую ауру. В 25-рейде в бою это тысячи лишних
  вызовов/сек — главный подозреваемый фризов.
- Конвертировано на нативную сигнатуру 3.3.5 (name, rank, icon, count,
  debuffType, duration, expirationTime, caster, isStealable,
  shouldConsolidate, spellId): UnitButton 4 сайта (основной скан
  дебаффов, raidDebuffs, big/normal дебаффы, скан баффов) + Utils 2
  сайта (FindDebuffByIds, FindAuraByDebuffTypes). Нативные UnitBuff/
  UnitDebuff уже были закэшированы локалями (:67-68). arg16 в скане
  баффов = позиция 12+ (нет в 3.3.5, остаётся nil — идентично старому
  врапперу).
- ПОПУТНЫЙ БАГ (есть и в апстриме!): FindAuraByDebuffTypes звал
  CheckDebuffType(s, spellId) с неопределённой глобальной `s` (всегда
  nil) вместо debuffType. Исправлено.
- Врапперы Cell.UnitBuff/UnitDebuff оставлены в Polyfills (консумеров
  в аддоне больше нет, но могут звать сторонние снippetы юзера).

### Инвентарь полифилов: что ещё можно перевести (не сделано)
Горячие (кандидаты при сохранении фризов):
- UnitClassBase-враппер (реверс-маппинг локализованных имён) — зовётся
  на каждый апдейт кнопки; можно fast-path для уже-валидных токенов.
- WrapPixelPerfectFunctions — слой замыканий на P.Point/Size/etc (bulk
  при перестройке лейаута); nil-баги давно исправлены, слой можно снять.
- Get/SetStatusBarTexture-враппер на общей метатаблице — после фикса
  №19 корректен, но вызывается любыми аддонами; редкий, не горячий.
Холодные (только load-time, фризов не дают): SetGradient, SetAtlas,
SetColorTexture, IsTruncated, SetRotation, WrapTextInColorCode,
CreateFontString, Smoothed* (прямой алиас SetValue — нулевая цена),
SetFrom/ToAlpha, HookScript, Cooldown-методы, SetReverseFill,
SetParentKey, FlipBook, SecureHandler_SetFrameRef, C_Spell,
C_UnitAuras (внутри аддона НЕ используется).
Постоянные фоновые (проверены, дёшевы): CellTimerDriver (OnUpdate,
скрыт без таймеров), roster-proxy (один кадр на батч), heal-pred clock
(0.25с, ранний выход без активных хилов).

### 23. Перф: fast-path в UnitClassBase (NormalizeClassToken)
`Polyfills.lua:905`. Второй горячий полифил (после аура-сканов №22):
зовётся на каждый апдейт каждой кнопки (states.class). На 3.3.5
UnitClass() практически всегда возвращает уже валидный uppercase-токен
("MAGE", "DEATHKNIGHT") — добавлена мгновенная проверка
`VALID_TOKENS[class]` ДО string.upper/gsub-аллокаций. Медленный путь
(локализованные имена, реверс-маппинг) сохранён как фолбэк.
Вывод по «перевести на API»: остальные полифилы переводить не нужно —
group-API (GetNumGroupMembers/IsInRaid/GetClassColor и т.п.) — тонкие
алиасы нулевой цены на холодных путях; C_-неймспейсы и texture-методы
нативного эквивалента в 3.3.5 не имеют (в этом их смысл).

---

## Диагностика, НЕ являющаяся багами Cell

- **FPS при наведении:** профилирование через `scriptProfile` показало,
  что Cell стоит ~2 мс/сек (тикеры OnUpdate дешёвые). Реальный потребитель
  CPU — **WeakAuras** (в ~25 раз дороже Cell в каждом окне замера).
  Рекомендация тестерам: искать тяжёлую ауру через `/wa` -> Profiling.
- **«Ползунок размера шрифта не работает»:** размер применялся корректно
  (доказано замером 22->39->50). У индикатора Control Effects была
  ��ыключена опция Show Duration — видимая цифра принадлежала другому
  источнику. ElvUI на и��онки Cell кулдаун-текст НЕ вешает (проверено по
  исходникам: только явный `E:RegisterCooldown` для своих модулей).

## Технические заметки для продолжения работы

- Временные отладочные команды (`/cellcpu`, `/cellpower`, `/cellpet`,
  `/cellccfont`) и флаги `CELL_FPS_DEBUG`/`CELL_IND_DEBUG` — УДАЛЕНЫ
  из релизного кода. При новой отладке смотреть историю чата/гита.
- Все «wotlk-фиксы» в коде помечены комментариями `--!` с объяснением
  причины — искать по `grep -rn '^\s*--!' Cell/`.
- Синтаксис Lua проверялся `luaparse` (Lua 5.1) перед каждым коммитом.
- GUID-маска 3.3.5: старшие hex-цифры 3–5 GUID, низший ниббл:
  0x0/0x1 = игрок, 0x3 = NPC, 0x4 = пет, 0x5 = машина.
- На 3.3.5 НЕТ: `header[i]`-индексации secure-хедеров, ��ативных цифр
  на кулдаунах, retail-строковых GUID, синхронного `UnitClassBase`.
