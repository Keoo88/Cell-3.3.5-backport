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
  назначение MAINTANK или talent-скан LibGroupInfo (inspect). ��сл��
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
зависели, но любая будущая проверка `== 0` ��о��������а��������������ась бы. Выровнено.

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
  bottom-up заливка (��атем��ял�� бы ОСТАВШ��ЕС�� время) погашена, тот же
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
  StatusBar: пр�� nil от н��тивн��го вызова region-scan брал ПЕРВУЮ
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

## Аудит: девятая волна (скопированные из апстрима файлы + эпоха API)
Проверены Modules/Indicators/Indicators.lua и
Widgets/Widgets_IndicatorSettings.lua (копии апстрима, фича №20) на
API, отсутствующие в 3.3.5:
- Чисто: C_Timer.After/NewTicker (наш полифил полный: хендлы с
  :Cancel(), бесконечные тикеры), GetSpellInfo и EditBox:SetMaxLetters
  нативны с ваниллы, RegisterUnitEvent (MoP) не используется нигде.

### 24. SetShown не существует в 3.3.5 (не был полифилен!)
`Polyfills.lua:312` (новый блок). Метод добавлен только в 5.0.4.
- Вызывался в 3 местах: Base.lua Shared_ShowStack (:82) и
  Shared_ShowDuration (:87), UnitButton ShowPowerBar gapTexture
  (:1778). На 3.3.5 = runtime-ошибка «attempt to call method
  'SetShown'»; при выключенном scriptErrors (дефолт) обработчик молча
  обрывался: ShowStack/ShowDuration не срабатывали до конца — мог быть
  источник «настройка стаков/длительности не применяется».
- Фикс: аддитивный полифил SetShown (Show/Hide) на метатаблицах Frame,
  Texture, FontString + отдельные виджет-типы (Button, StatusBar,
  Cooldown, EditBox, Slider, CheckButton, ScrollFrame) — у каждого
  типа своя метатаблица в 3.3.5. Ставится ТОЛЬКО при отсутствии
  метода (паттерн IsTruncated) — безопасно для чужих аддонов.
- Porядок загрузки подтверждён: Polyfills.lua (toc:17) до Base.lua
  (toc:35).

---

## Диагностика, НЕ являющаяся багами Cell

- **FPS при наведении:** профилирование через `scriptProfile` показало,
  что Cell стоит ~2 мс/сек (тикеры OnUpdate дешёвые). Реальный потребитель
  CPU — **WeakAuras** (в ~25 раз дороже Cell в каждом окне замера).
  Рекомендация тестерам: искать тяжёлую ауру через `/wa` -> Profiling.
- **«Ползунок размера шрифта не работает»:** размер применялся корректно
  (доказано замером 22->39->50). У индикатора Control Effects была
  ��ыключена опция Show Duration — видимая цифра принадлежал�� другому
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

---

## Волна 10 аудита (продолжение сессии, НЕ запушено)

### 25. Офлайн-статус не обновлялся в пати (UNIT_CONNECTION)
**Файл:** `RaidFrames/UnitButton_Cata_Wrath.lua`
- Кнопка регистрирует `UNIT_CONNECTION` — события НЕТ в 3.3.5 (добавлено
  в 4.0), регистрация молча не срабатывает. OFFLINE-состояние обновлялось
  только через синтетический `GROUP_ROSTER_UPDATE`: в рейде это надёжно
  (`RAID_ROSTER_UPDATE` шлётся на дисконнект), в ПАТИ — нет.
- Blizzard-паттерн 3.3.5: `PartyMemberFrame.lua:421` обновляет
  онлайн-статус на `UNIT_HEALTH` (сервер шлёт его юниту при
  коннекте/дисконнекте).
- Фикс: в ветке `UNIT_HEALTH` кэш `self.__isConnected` (нормализован
  в boolean — `UnitIsConnected` возвращает 1/nil); при изменении —
  `_updateRequired = 1`. Кэш синхронизируется в `UnitButton_UpdateAll`.

### 26. Двойное срабатывание secure-кнопок (Up+Down)
**Файлы:** `Utilities/ReadyAndPull.lua`, `Utilities/BuffTracker_Classic.lua`,
`Utilities/Marks.lua`
- Класс бага: в 3.3.5 `SecureActionButton_OnClick(self, button, down)`
  выполняет действие на КАЖДЫЙ вызов — гейтинг по CVar
  `ActionButtonUseKeyDown` появился позже. Регистрация
  `RegisterForClicks("...Up", "...Down")` = действие дважды за клик.
- pullBtn: `/dbm pull N` уходил дважды — DBM стартует и тут же отменяет
  пулл-таймер. Фикс: down-only (как readyBtn).
- Бафф-кнопки BuffTracker: двойной каст (GCD-ошибка). Фикс: down-only.
  ВАЖНО: хук OnClick проверял `and not down` (апстрим стрелял анонс на
  Up) — при down-only регистрации это убило бы shift-анонс, условие
  переделано (регрессия поймана до коммита).
- worldMarkButtons: тоже down-only (см. №27).

### 27. World Marks: мёртвый UI + спам ошибок IsRaidMarkerActive
**Файл:** `Utilities/Marks.lua`
- World markers не существуют в WotLK; secure-тип `"worldmarker"` не
  распознаётся SecureTemplates 3.3.5 (проверено по FrameXML). Опции в
  дропдауне уже задизейблены для wrath, НО: SavedVariables, перенесённый
  с новее клиента, может содержать `world_*`/`both_*` — тогда покажется
  нерабочий UI и `OnShow`-тикер начнёт дёргать `IsRaidMarkerActive`
  (нет в 3.3.5, нет полифила) => Lua-ошибка каждые 0.5с.
- Фикс: `NormalizeMarksMode()` (коэрсия world/both -> target с
  сохранением ориентации) в `ShowMover` и `CheckPermission` + guard
  `if not IsRaidMarkerActive then return end` перед тикером.

### Проверено и признано корректным в волне 10
- `RegisterForClicks("AnyDown")` на юнит-кнопках (4248) — одиночное
  срабатывание, ок для 3.3.5.
- `Marks.lua:130` markButtons, `readyBtn`, `RaidRosterFrame` grid —
  уже down-only, не затронуты.
- World/Both опции меток в `RaidTools.lua` — уже `disabled` для wrath.
- Синтаксис всех правок проверен luaparse (Lua 5.1).

## Волна 11: систематический дифф вызовов против API-базы milkyway

Методика: скриптом собраны все `:Method(`-вызовы, `C_Xxx.*` и глобальные
вызовы в коде Cell (без Libs/) и сверены с базой 3.3.5 (milkyway-codex:
`widgets.ts` 3896 методов, `api-functions.ts` 6109 функций, `events.ts`
558 событий) с учётом Polyfills.lua и ClassicAPI. Плюс сверка всех
`RegisterEvent` с базой событий.

### 28. UnitInPartyIsAI: nil-call на NPC-юнитах и в Spotlight
**Файлы:** `RaidFrames/UnitButton_Cata_Wrath.lua:1655`,
`RaidFrames/Groups/SpotlightFrame.lua:421`
- `UnitInPartyIsAI` — retail API (follower dungeons, 10.2), в 3.3.5 нет.
  В `Utils.lua:1141` есть фолбэк, но он `local` и на другие файлы не
  действует. Ветка `F.IsNPC(guid)` в GetClass/GetRole и `SetUnit` в
  спотлайте падали с "attempt to call global 'UnitInPartyIsAI'".
- Фикс: guard `UnitInPartyIsAI and UnitInPartyIsAI(...)` в обоих местах.

### 29. ClickCastings: вызов несуществующего глобального UpdateClickCastings
**Файл:** `Modules/ClickCastings/ClickCastings.lua:737`
- `UpdateQueuedClickCastings()` звал глобальный `UpdateClickCastings(true,
  true)`, которого не существует (функция живёт в `F`). Callback
  "UpdateQueuedClickCastings" стрелял nil-call ошибкой.
- Фикс: `F.UpdateClickCastings(true, true)`.

### 30. Supporter-индикатор: мёртвый бутстрап через FIRST_FRAME_RENDERED
**Файл:** `Indicators/Supporter.lua:265`
- `FIRST_FRAME_RENDERED` добавлен в 10.1, на 3.3.5 не приходит никогда.
  Обработчик регистрировал `GROUP_ROSTER_UPDATE` только из этого события
  => весь индикатор саппортеров молча не работал.
- Фикс: дополнительно регистрируется `PLAYER_ENTERING_WORLD` как
  бутстрап; обработчик принимает оба события. `GROUP_ROSTER_UPDATE`
  дальше маршрутизируется roster-прокси из Polyfills.

### 31. Raid Roster: drag&drop свап групп был мёртв (GLOBAL_MOUSE_UP)
**Файл:** `Utilities/RaidRosterFrame.lua`
- Приём дропа строился на `GLOBAL_MOUSE_UP` (добавлен в 8.1.5): грид под
  курсором ловил событие и делал `SwapRaidSubgroup`/`PremadeSwap`. На
  3.3.5 событие не приходит => перетаскивание игроков между группами не
  делало ничего, `movingGrid` оставался висеть до следующего дропа.
- Фикс: реестр `allGrids` (пополняется в `CreateRaidRosterGrid`, фабрика
  одна на оба режима — instant и premade); в `OnDragStop` источника
  вручную ищется видимый грид под курсором и вызывается его существующий
  OnEvent-обработчик свапа; после — `movingGrid = nil`.

### Проверено и признано корректным в волне 11
- `C_IncomingSummon.*` (StatusIcon.lua:248) — под guard `C_IncomingSummon
  and ...`, ветка на 3.3.5 не выполняется.
- `GetMouseFoci` (Utils.lua) — guard с фолбэком на `GetMouseFocus`.
- `InitiateRolePoll` (ReadyAndPull.lua) — `elseif InitiateRolePoll then`.
- `CompactRaidFrameManager_SetSetting`, `PartyMemberFramePool:
  EnumerateActive` (HideBlizzard.lua) — под guard'ами retail-фреймов.
- `tooltip:RefreshData` — под `Cell.isRetail`; `SetUnit(De)BuffByAura
  InstanceID` — ветка "aura" достижима только если иконка получила
  `auraInstanceID` (на wrath ставится `index` => ветка "spell").
- PrivateAuras — `C_UnitAuras.Add/RemovePrivateAuraAnchor` заглушены
  no-op в Polyfills.
- `GROUP_ROSTER_UPDATE` (13 регистраций по коду) — покрыт прокси-слоем
  Polyfills (hooksecurefunc на RegisterEvent/UnregisterEvent/
  UnregisterAllEvents метатаблицы фрейма + PARTY_MEMBERS_CHANGED/
  RAID_ROSTER_UPDATE).
- `UNIT_HEALTH_FREQUENT`, `UNIT_POWER`, `UNIT_MAXPOWER`, `UNIT_HEAL_
  PREDICTION`, `UNIT_CONNECTION` — рядом зарегистрированы wrath-
  эквиваленты (см. №7, №8, №25).
- `START_TIMER`, `INCOMING_SUMMON_CHANGED`, `TOOLTIP_DATA_UPDATE` — под
  `Cell.isRetail`.
- Секьюрные методы (`GetFrameRef`, `WrapScript`, `SetBindingClick`,
  `CallMethod`, `RunFor` и т.п.) — есть в SecureHandlers 3.3.5.

### Известные деградации (без фикса, фичи молча не работают на 3.3.5)
- **TargetCounter** (счётчик целей): `NAME_PLATE_UNIT_ADDED/REMOVED` не
  существуют, а полифил `C_NamePlate.GetNamePlates()` возвращает `{}` —
  счётчик всегда 0. На 3.3.5 нейм-плейты не маппятся на юнитов; честной
  реализации нет. Кандидат: задизейблить опцию для wrath.
- **ENCOUNTER_START/END** (DeathReport, TargetedSpells): события 4.x+,
  сброс по энкаунтерам не срабатывает. Возможная замена — эвристика по
  CLEU/боссовым юнитам, пока не делалось.
- `UNIT_PHASE` (StatusIcon) — фазовая иконка не обновляется по событию;
  на wrath фазинга в retail-смысле нет, некритично.
- `F.ShowSpellTooltips` (Widgets/Tooltip.lua:82) — мёртвый код (нет
  вызовов), внутри retail-only `CreateBaseTooltipInfo`/`ProcessInfo`.
- `DevTools_Dump` в `F.Debug` — на 3.3.5 доступен только при
  подгруженном Blizzard_DebugTools; затрагивает только debugMode.
- Синтаксис всех правок волны 11 проверен (баланс блоков, Lua 5.1;
  luaparse в песочнице недоступен без сети).

### 32. PowerFilters/roleIcon: роли группы всегда DAMAGER, свой спек «запоминается» с логина
**Файлы:** `Libs/LibGroupInfo.lua`, `RaidFrames/UnitButton_Cata_Wrath.lua`
**Симптом (от тестера):** кнопки TANK/HEALER в фильтрах ресурсов не
работают — реагирует только «мечик» (DD) у всех классов; но если зайти
на персонажа с активным хил-спеком, то у его класса работает «хил», а
«мечик» перестаёт. Иконка роли — так же («запоминает спек с логина»).
**Причина — цепочка ролей сломана в трёх местах:**
1. Свой спек: LibGroupInfo строил кэш игрока один раз на логине.
   `PLAYER_SPECIALIZATION_CHANGED` (5.0+) на 3.3.5 не существует, wrath-
   эквиваленты не были зарегистрированы => смена дуал-спека/талантов не
   обновляла specRole. Роль = спек, с которым зашёл.
2. Даже когда инспект соседа успевал отработать, **никто в Cell не был
   подписан на колбэк `GroupInfo_Update`** — обновлённая роль не
   доходила до кнопок: `states.role` оставался «DAMAGER», фильтры
   TANK/HEALER не находили ни одного юнита.
3. Члены группы вне зоны инспекта (28 ярдов) отбрасывались `AddToQueue`
   без повторной попытки до следующего roster-события — в статичной
   группе их никогда не переинспектировали.
**Фиксы:**
- LGI: на wrath регистрируются `ACTIVE_TALENT_GROUP_CHANGED` +
  `PLAYER_TALENT_UPDATE` => `Query("player")`; чужие свапы дуал-спека
  ловятся по `UNIT_SPELLCAST_SUCCEEDED` со спеллом из
  `TALENT_ACTIVATION_SPELLS` (63645/63644, приём LibGroupTalents) =>
  инвалидация кэша + переинспект юнита.
- LGI: тикер (15с) в группе перезапускает сканирование — доинспектирует
  тех, кто был вне зоны (уже инспектированные пропускаются).
- UnitButton: подписка на `GroupInfo_Update` => `UnitButton_UpdateRole`
  + пересчёт `_shouldShowPowerBar/_shouldShowPowerText` и показ/скрытие
  павер-бара; для скрытых кнопок ставится `_powerUpdateRequired = 1`
  (штатный путь OnShow).
**Ограничение:** роль друида-фераловода определяется как DAMAGER (бер/кот
по талантам неразличимы) — тановодов покрывает MAINTANK-назначение.
**Референс:** ElvUI Project Zidras (LibGroupTalents/LibTalentQuery) —
тот же событийный набор: PLAYER_TALENT_UPDATE, UNIT_SPELLCAST_SUCCEEDED
с TALENT_ACTIVATION_SPELLS.

### 33. Роли: «вар меняет роль вслед за моим спеком» + танк-иконка в соло
**Файлы:** `Libs/LibGroupInfo.lua`, `Polyfills.lua`
**Симптомы (от тестера, после #32):**
- Роль вара в пати следует за СПЕКОМ ИГРОКА: я элем (таб 1) => вар DD
  (WARRIOR[1]); спекаюсь в ресто (таб 3) => через ~8с вар СТАНОВИТСЯ
  ТАНКОМ (WARRIOR[3] = TANK). То есть вару записываются МОИ таланты.
- Новые члены пати получают роль только после релога.
- Иконка танка у ресто-шамана в СОЛО в Даларане.
**Причины:**
1. На 3.3.5 хранилище инспекта (`GetTalentTabInfo(i, true)`) может
   отдавать СТАРЫЕ/ЧУЖИЕ данные — в т.ч. собственные таланты игрока
   (свой респек, молча провалившийся NotifyInspect). LGI писал их в
   кэш инспектируемого без проверки. LibTalentQuery (референс от
   юзера + ElvUI Zidras) валидирует имя первого дерева по классу
   (validateTrees) и отбрасывает 0/0/0.
2. В wrath-ветке `BuildAndNotify_Wrath` НИКОГДА не ставился
   `cache[guid].inspected = true` (только retail-ветка) => каждый
   roster-ивент/рескан переинспектировал ВСЕХ бесконечно — очередь
   молотила постоянно, резко повышая шанс мисатрибуции
   INSPECT_TALENT_READY (без guid на 3.3.5).
3. На некоторых корах `GetPartyAssignment("MAINTANK", "player")` возвращает
   true в СОЛО => танк-иконка у любого персонажа вне группы.
**Фиксы:**
- LGI/BuildAndNotify_Wrath (inspect-ветка): валидация по
  CLASS_TALENT_FILE_PREFIX — 4-й возврат GetTalentTabInfo (background
  fileName, напр. "ShamanElementalCombat") классо-зависим и
  локале-НЕзависим => должен начинаться с префикса класса юнита;
  сумма очков > 0; чтение с активной группой талантов
  (GetActiveTalentGroup(true), дуал-спек). При мусоре — return false,
  кэш не трогаем.
- LGI/INSPECT_READY: при return false юнит возвращается в статус
  "waiting" (ретрай с капом MAX_ATTEMPTS), успех => декью.
- LGI: на успехе ставится `cache[guid].inspected = true` — черновая
  причина череды мисатрибуций устранена; рескан (15с тикер из #32)
  теперь трогает только непроинспектированных => новые члены пати
  подхватываются без релога.
- Polyfills/UnitGroupRolesAssigned: GetPartyAssignment-ветка выполняется
  только при GetNumRaidMembers()>0 или GetNumPartyMembers()>0 — в соло
  сразу переход к спек-детекции через LGI.
**Референс:** LibTalentQuery-1.0 (прислан юзером, идентичен версии в
  ElvUI Zidras): lastInspectTree запоминается при NotifyInspect,
  сверяется на READY + validateTrees по классу + отброс 0/0/0 +
  lastInspectPending-счётчик.

### 34. Соло-шаман 0/0/41 определяется как ДПС (спек игрока не читается при логине)
**Файл:** `Libs/LibGroupInfo.lua`
**Причина:** аргументы `isLogin/isReload` у PLAYER_ENTERING_WORLD появились
только в Legion (7.0). На 3.3.5 событие приходит БЕЗ аргументов =>
при логине в открытом мире Query("player") никогда не выполнялся =>
specRole игрока nil => дефолт DAMAGER.
**Фиксы:** на wrath PEW всегда обновляет; при чтении своих талантов 0/0/0
(ранний логин) — однократный ретрай через C_Timer.After(5).

### 35. Горячий путь UnitGroupRolesAssigned
**Файл:** `Polyfills.lua`
**Фикс:** референс LibGroupInfo кэшируется в апвалью `_cachedLGI`
вместо LibStub:GetLibrary на каждый вызов (вызывается на каждый апдейт
роли/павер-бара каждой кнопки).

### 36. Перф-аудит по референсу ElvUI 3.3.5: два пожирателя + дрейф тикеров
**Файлы:** `Indicators/TargetCounter.lua`, `Libs/AceTimer-3.0/AceTimer-3.0.lua`, `Polyfills.lua`
**Найдено при сравнении с ElvUI 3.3.5 (там таймеры = E:Delay WaitFrame +
AceTimer с OnUpdate-движком, C_Timer не полифилится вообще):**
1. **TargetCounter — мёртвый поллер.** Считает цели через C_NamePlate,
   который на 3.3.5 — заглушка (всегда {}), а NAME_PLATE_UNIT_* не
   стреляют никогда. При включённом индикаторе тикер 0.25с гонял
   F.HandleUnitButton по ВСЕЙ группе 4 раза/сек (в рейде 25 — ~100
   вызовов/сек) с вечным результатом 0. Фикс: в Polyfills заглушка
   помечена `C_NamePlate._cellPolyfill = true`; TargetCounter при этом
   маркере не стартует тикер и не регистрирует события.
2. **AceTimer30Frame крутил OnUpdate вечно** (бекпорт-движок, как в
   ElvUI — там тоже крутится всегда), даже с нулём таймеров — пустой
   next-проход каждый кадр. Фикс: frame:Show() в new(), self:Hide() в
   конце OnUpdate при пустом activeTimers, старт в спящем состоянии.
   (Пользователи AceTimer у нас: AbsorbsMonitor-1.0.)
3. **Дрейф тикеров CellTimerDriver**: после срабатывания _elapsed
   сбрасывался в 0 и хвост кадра терялся (тикер 0.25с при 30 FPS
   реально тикал ~0.26-0.28с). Фикс по образцу ElvUI: перенос овершута
   в следующий интервал + кламп после лаг-спайков.
**Не трогали:** WaitFrame-паттерн ElvUI — у нас уже есть эквивалент
(CellTimerDriver со сном и пулом); safecall-диспетчеры — наш pcall уже
изолирует ошибки.

### 37. Расширение дебаг-модуля: /cell debug dump
**Файл:** `Debug.lua`
**Зачем:** тестеры пересказывают симптомы словами, а для диагностики нужны
состояние LGI-кэша, роли и шина событий. Теперь всё снимается одной командой.
**Что добавлено:** подкоманда `dump` (`/cell debug dump` или `d`) — окно
`CellDebugDumpFrame` (draggable, ESC закрывает, текст в EditBox для
Ctrl+A/Ctrl+C) с отчётом:
- клиент/билд, версия Cell, память аддона (GetAddOnMemoryUsage);
- таланты игрока по вкладкам: имя(backgroundFileName)=очки — то самое,
  по чему валидируется класс в LGI (#33);
- состав группы (raid/party/solo) и по каждому юниту: имя, класс, уровень,
  роль из UnitGroupRolesAssigned + шаллоу-дамп скалярных полей LGI-кэша
  (specName, specRole, inspected и т.д. — структура кэша дампится
  универсально, что бы в ней ни было);
- статистика шины колбэков: регистрации, срабатывания, MISSED-события
  (fires считаются только при включённом /cell debug).
Дамп работает и при выключенном дебаг-режиме. Помощь (`/cell debug h`)
обновлена.

### 38. AoE Healing: белая полоска, цвет из настроек не применяется

**Симптом:** индикатор AoE Healing срабатывает (вспышка при своём аое-хиле), но полоска сплошная белая; смена цвета в настройках ничего не меняет. Дефолтный жёлтый {1,1,0} тоже не применялся.

**Причина:** `aoeHealing:SetColor` использовал ретейловский путь: `tex:SetGradient("VERTICAL", CreateColor(...), CreateColor(...))`. На 3.3.5 это работает только через нашу цепочку полифилов (глобальный `CreateColor` из ClassicAPI → обёртка `SetGradient` на общем метатейбле текстур → нативный `SetGradientAlpha`). В полевых условиях цепочка молча не срабатывает: сплошная (не градиентная) белая полоска означает, что до нативного вызова дело не доходит вовсе. Обёртка была хрупкой: принимала только Lua-таблицы (`type(c) == "table"`), не переживала userdata-цвета от чужих аддонов и nil из unpackColor уходил прямо в нативный вызов.

**Фикс (Indicators/AoEHealing.lua):**
- `SetColor` сохраняет r/g/b и вызывает новый `ApplyColor`.
- `ApplyColor` бьёт по нативному числовому API напрямую, без CreateColor и без метатейбл-обёртки: `SetVertexColor(r,g,b,0.77)` как базовый тинт (страховка: даже если градиенты на кастомном клиенте сломаны — полоска будет нужного цвета), затем `SetGradientAlpha("VERTICAL", r,g,b,0, r,g,b,0.77)` (нативная сигнатура 3.3.5: низ RGBA, верх RGBA).
- `ApplyColor` переприменяется в OnPlay анимации — на случай, если клиент сбрасывает градиент-стейт, пока текстура скрыта.

**Фикс (Polyfills.lua, обёртки SetGradient/SetGradientAlpha):**
- `unpackColor` принимает и таблицы, и userdata; чтение полей обёрнуто в pcall.
- Диспатч по цвет-объектам: `type(c) ~= "number"` вместо `== "table"`; фолбэк в нативный вызов только если unpackColor реально вернул числа; `a or 1` для nil-альфы.

**Урок:** для встроенных индикаторов бекпорта не гонять цвет через ретейловский ColorMixin-путь — звать нативные числовые API 3.3.5 напрямую; полифилы общего метатейбла оставлять только для неизменённого ретейл-кода.

### 39. AoE Healing всё ещё белый: настоящая причина — старый профиль без ключа ["color"]

**Симптом после № 38:** полоска по-прежнему белая, цвет из настроек не применяется, НО высота меняется. Это ключевая улика: оба сеттинга идут через один и тот же диспатч (Cell.Fire("UpdateIndicators", layout, name, setting, value) → UnitButton), значит путь жив, а ломается именно цвет.

**Причина:** в сохранённом CellDB тестера (профиль создан старой версией бекпорта) у записи индикатора aoeHealing нет ключа ["color"]. Следствия:
1. Инициализация кнопок: `if t["color"] then indicator:SetColor(...)` не проходит → текстура остаётся без тинта → белая (даже дефолтный жёлтый не ставится).
2. Окно настроек: CreateSetting_Color получает `SetDBValue(nil)` → `widget.colorTable = nil` → при выборе цвета колбэк падает на `widget.colorTable[1] = r` ДО записи в БД и ДО Cell.Fire → смена цвета молча ничего не делает (на Warmane ошибки скриптов обычно скрыты).
3. Высота работает, потому что ["height"] в старых профилях есть.

**Фикс:**
- Revise.lua: идемпотентный бекфилл перед `CellDB["revise"] = Cell.version`: для всех лейаутов, если у aoeHealing нет ["color"] — ставим {1,1,0}; у targetCounter — {1,0.1,0.1} (тот же риск, та же эпоха профилей).
- Widgets_IndicatorSettings.lua (CreateSetting_Color): guard — если colorTable не пришла, создаётся заглушка {1,1,1}, чтобы колбэк никогда не умирал молча.
- № 38 (нативный SetGradientAlpha + SetVertexColor в ApplyColor) остаётся — правильное укрепление, но корневая причина была в БД.

**Проверка диагноза на клиенте (до установки фикса):**
`/run for _,x in pairs(Cell.vars.currentLayoutTable.indicators) do if x.indicatorName=="aoeHealing" then print("color:", x.color and (x.color[1]..","..x.color[2]..","..x.color[3]) or "NIL <- баг", "height:", x.height) end end`

**Урок:** при бекпорте новых ключей в дефолты лейаутов ВСЕГДА добавлять бекфилл в Revise — дефолты применяются только к НОВЫМ профилям, старые SavedVariables живут годами. Симптом-маркер: «одна настройка индикатора работает, соседняя нет» = дыра в сохранённом профиле, а не в коде отрисовки.

### 40. AoE Healing белый ОКОНЧАТЕЛЬНО: нативная Alpha-анимация 3.3.5 сбрасывает vertex color / градиент текстуры во время проигрывания

**Доказательства (зонды тестера, установка файлов была корректной):**
- `i:SetColor(1,0,0)` (vertex color + градиент) + Display → вспышка БЕЛАЯ.
- `i.tex:SetTexture(1,0,0,0.77)` (цвет-ЗАЛИВКА) + Display → вспышка КРАСНАЯ.
- На статичном предпросмотре в настройках (без анимации) градиент рендерится правильно.

**Вывод:** пока нативная Alpha-анимация играет, клиент 3.3.5 рисует анимируемую текстуру БЕЗ её vertex-состояния (SetVertexColor/SetGradientAlpha игнорируются, белая плоская заливка), а цвет-заливка SetTexture(r,g,b,a) выживает. Индикатор виден ТОЛЬКО во время анимации → всегда белый, на любой версии SetColor. Цепочка попадания на нативную анимацию: Fix 4 (PatchAnimationSystem) транслирует SetFromAlpha/SetToAlpha в нативный SetChange(±1) — родственник бага SnowfallKeyPress, но зеркальный: там шим ломал нативных пользователей, здесь он уводит ретейл-пользователей на нативный путь с его рендер-квирком.

**Фикс (Indicators/AoEHealing.lua):** у индикатора больше нет AnimationGroup. Фейд (0.5s ease-out вверх + 0.5s ease-in вниз, как раньше у a1/a2 со SetSmoothing) ведётся вручную через OnUpdate + frame:SetAlpha. Без нативной анимации градиент и цвет рендерятся всегда. Display() перезапускает вспышку (как закомменченный Restart в оригинале) и переприменяет цвет. OnUpdate живёт только 1 секунду на вспышку — CPU-цена нулевая.

**Урок:** на 3.3.5 нельзя анимировать нативными Alpha-анимациями текстуры, которым нужен vertex color/градиент — только ручной OnUpdate-фейд или цвет-заливка SetTexture(r,g,b,a). Диагностическая пара зондов «vertex vs заливка» теперь штатный инструмент для таких багов.

### 41. EPGP LootMaster: окно разрола не появляется с включённым Cell — ретейловый AceComm 14 ломает аддон-сообщения на 3.3.5

**Механика конфликта (общие библиотеки через LibStub):**
- Cell грузится раньше EPGP (алфавит) и регистрирует AceComm-3.0 MINOR **14** (ретейл) против MINOR 7 у EPGP — весь комм-трафик EPGP идёт через код Cell. Аналогично ChatThrottleLib v25 (ClassicAPI) перекрывает v22.
- Окно разрола открывается по комму `EPGPLootMasterC` с командой ADDLOOT (итемлинк + текстура + GP + классы + кнопки — всегда длинное сообщение).

**Два бага ретейлового AceComm 14 на 3.3.5:**
1. **Лимит длины**: на клиентах до 4.1 лимит SendAddonMessage — **254 байта на префикс+текст вместе**; ретейловый код считает 255 текста ОТДЕЛЬНО. С префиксом `EPGPLootMasterC` (15) любое сообщение >239 символов падает с error в CTL v25 (тот проверяет правильно: `prefix + 1 + text > 255`) и НЕ ОТПРАВЛЯЕТСЯ. Ошибка глотается safecall'ом — внешне тишина. Короткие сообщения (биды, версия-чек) проходят.
2. **Формат мультичасти**: ретейл кладёт маркер \\001-\\003 первым байтом ТЕКСТА, старый формат (AceComm 7 у игроков без Cell) — в КОНЕЦ ПРЕФИКСА. Форматы взаимно нечитаемы.

**Важно**: capability-детекция (`if RegisterAddonMessagePrefix`) здесь НЕ работает — Polyfills.lua сам определяет RegisterAddonMessagePrefix/C_ChatInfo/Ambiguate, и проверки видят «ретейл». Детект только по билду: `select(4, GetBuildInfo()) < 40100`.

**Фикс (Libs/AceComm-3.0/AceComm-3.0.lua, MINOR остаётся 14):**
- `IS_PRE_PREFIX_CLIENT = (select(4, GetBuildInfo()) or 0) < 40100`.
- Отправка: `maxtextlen = 254 - #prefix`; маркеры мультичасти клеятся к префиксу (старый формат, совместимый с AceComm 7 у других игроков); \\004-экранирование только на 4.1+ (как в оригинальном AceComm 7).
- Приём: сначала разбор старого формата (маркер в конце префикса → OnReceiveMultipart*), затем ретейловый fallback (контрольный байт в начале текста) — понимаем оба формата.

**Бонус**: этот же баг ломал бы ЛЮБОЙ аддон с длинными коммами через AceComm при включённом Cell (DBM-синхронизация, Gearscore и пр.), а также собственный шеринг лейаутов Cell.

**Урок**: при бекпорте проверять все бандленные Ace-библиотеки: через LibStub они становятся ОБЩИМИ для всех аддонов, и ретейловые предположения (лимиты, wire-форматы) ломают чужие аддоны молча. Полифилы делают capability-детекцию ненадёжной — детектить по GetBuildInfo.
