local _, Cell = ...
--! WotLK fix: bind Cell timers privately so standalone !!!ClassicAPI cannot change semantics.
local C_Timer = Cell.C_Timer
---@type CellFuncs
local F = Cell.funcs
---@class CellUnitButtonFuncs
local B = Cell.bFuncs
---@type CellIndicatorFuncs
local I = Cell.iFuncs
---@type CellUtilityFuncs
local U = Cell.uFuncs
---@type PixelPerfectFuncs
local P = Cell.pixelPerfectFuncs
---@type CellAnimations
local A = Cell.animations


CELL_FADE_OUT_HEALTH_PERCENT = nil

-- GetStatusBarTexture can return nil on some 3.3.5 clients (e.g. with
-- Ascension's Classic API disabled), so guard the SetDrawLayer call
local function SetBarTextureDrawLayer(bar, layer, subLayer)
    local tex = bar:GetStatusBarTexture()
    if tex then
        tex:SetDrawLayer(layer, subLayer)
    end
end

local UnitGUID = UnitGUID
--! WotLK fix: min IS a real global on 3.3.5 (codex: API function, alias of
--! math.min; FrameXML calls it bare in 71 places), so the bare min() on the
--! health path was not a crash. But rule 3 forbids trusting a global Cell does
--! not own, and the alias used to sit at :2704 - below the health code that
--! reads it, which compiles to a global lookup on every health update for every
--! unit. One file-scope alias at the top covers both call sites.
local min = math.min
--! WotLK perf: same reasoning as `min` above. `abs` is also a real global on 3.3.5
--! (codex: API function, alias of math.abs), and UnitButton_UpdateHealth already
--! called it bare on the flash path - one file-scope alias covers both that call and
--! the smoothing driver's per-bar-per-frame use, without trusting a foreign global.
local abs = math.abs
--! WotLK perf: floor нужен в UnitButton_UpdateHealPrediction, который зовётся из
--! шести колбэков LibHealComm; math.floor там был единственным местом с чтением
--! глобала math на горячем пути.
local floor = math.floor
local UnitName = UnitName
local GetUnitName = GetUnitName
--! WotLK fix: use Cell's private class-token normalizer; keep native UnitClassBase untouched.
local UnitClassBase = Cell.GetUnitClassToken
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitIsConnected = UnitIsConnected
local UnitIsAFK = UnitIsAFK
local UnitIsFeignDeath = UnitIsFeignDeath
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitPowerMax = UnitPowerMax
--! WotLK perf: UnitPower звался голым глобалом в UnitButton_UpdatePowerStates,
--! рядом со своим уже локализованным близнецом UnitPowerMax. Функция идёт на
--! каждое UNIT_POWER/UNIT_MANA, а на 3.3.5 нет RegisterUnitEvent - событие
--! доходит до каждой кнопки. Регистр под алиас взят с освободившегося
--! дубликата UnitIsPlayer (был объявлен дважды, :55 и :73).
local UnitPower = UnitPower
-- local UnitInRange = UnitInRange
-- local UnitIsVisible = UnitIsVisible
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local GetTime = GetTime
local GetRaidTargetIndex = GetRaidTargetIndex
local GetReadyCheckStatus = GetReadyCheckStatus
local UnitHasVehicleUI = UnitHasVehicleUI
-- local UnitInVehicle = UnitInVehicle
-- local UnitUsingVehicle = UnitUsingVehicle
local UnitIsCharmed = UnitIsCharmed
--! WotLK perf: здесь стоял второй `local UnitIsPlayer = UnitIsPlayer` - точный
--! дубликат объявления выше. Он занимал ещё один регистр главного чанка, а
--! чанк стоит вплотную к пределу Lua 5.1 в 200 живых локалов.
local UnitGroupRolesAssigned = Cell.UnitGroupRolesAssigned --! WotLK fix: Cell-private retail-contract adapter; the global stays native.
local UnitThreatSituation = UnitThreatSituation
local GetThreatStatusColor = GetThreatStatusColor
local UnitExists = UnitExists
local UnitIsGroupLeader = Cell.UnitIsGroupLeader
local UnitIsGroupAssistant = Cell.UnitIsGroupAssistant
local InCombatLockdown = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
--! WotLK fix: локал UnitInPhase убран. Имени на 3.3.5 нет (кодекс: НЕТ), так
--! что захватывался nil, и ни одного вызова в файле не было - греп по
--! UnitInPhase давал ровно эту строку. Фазовый статус читается через приватный
--! Cell.UnitInPhase (см. Indicators/StatusIcon.lua).
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local IsInRaid = Cell.IsInRaid
local IsInGroup = Cell.IsInGroup
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local GetSpellInfo = GetSpellInfo


local barAnimationType, highlightEnabled, predictionEnabled
local absorbEnabled, absorbInvertColor
local shieldEnabled, overshieldEnabled, overshieldReverseFillEnabled

--! WotLK fix: Cell's health/power smoothing must not depend on the global
--! SmoothStatusBarMixin. Standalone !!!ClassicAPI may load first and own that
--! global, while without it Polyfills.lua previously supplied only snap-to-value
--! stubs. Keep a private two-phase driver and attach its methods directly to
--! Cell bars so both load modes have identical behavior.
local smoothBars = {}
local smoothDriver = CreateFrame("Frame")
local ProcessCellSmoothBars
--! WotLK perf: the snapshot buffer is a file-local reused every frame instead of a
--! fresh `{}` inside the OnUpdate. This handler runs at full framerate while any bar
--! is animating, and at 40 units it grew an 80-slot table 60 times a second - pure
--! garbage for a Lua 5.1 collector with no generational step. Reuse is safe because
--! the handler is only ever installed as an OnUpdate script: OnUpdate cannot fire
--! re-entrantly, and the OnValueChanged work that bar:SetValue triggers can only
--! write to `smoothBars`, never call back into here.
local smoothPending = {}
local function ClampBarValue(bar, value)
    local minValue, maxValue = bar:GetMinMaxValues()
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

ProcessCellSmoothBars = function(self, elapsed)
    local pending = smoothPending
    local n = 0
    for bar, target in pairs(smoothBars) do
        pending[n + 1] = bar
        pending[n + 2] = target
        n = n + 2
    end

    local active
    --! WotLK perf: доля интерполяции зависит только от elapsed, а он один на кадр -
    --! считать её внутри цикла значило звать min по разу на каждую полосу.
    local amount = min(elapsed * 15, 1)
    for i = 1, n, 2 do
        local bar = pending[i]
        local queuedTarget = pending[i + 1]
        --! WotLK fix: callbacks triggered by SetValue may retarget a bar while
        --! this snapshot is being processed. Only consume the entry when it is
        --! still the same target; a newer target is left for the next frame.
        if smoothBars[bar] == queuedTarget then
            --! WotLK perf: GetMinMaxValues спрашивался у клиента дважды на каждую
            --! полосу в кадре - внутри ClampBarValue и ещё раз ниже, под range.
            --! Это C-вызов, между двумя чтениями нет ни одного SetValue, ответ
            --! гарантированно тот же. При 40 юнитах и двух полосах на кнопку это
            --! 80 лишних переходов Lua->C в кадре, ~4800 в секунду на анимации.
            --! Тело ClampBarValue вставлено сюда как есть; сама функция остаётся,
            --! её зовёт ResetSmoothedValue (холодный путь).
            local minValue, maxValue = bar:GetMinMaxValues()
            local target = queuedTarget
            if target < minValue then
                target = minValue
            elseif target > maxValue then
                target = maxValue
            end
            local current = bar:GetValue() or target
            local value = current + (target - current) * amount
            local range = maxValue - minValue
            if range <= 0 or abs(value - target) <= range * 0.00001 then
                smoothBars[bar] = nil
                bar:SetValue(target)
            else
                active = true
                bar:SetValue(value)
            end
        elseif smoothBars[bar] ~= nil then
            active = true
        end
    end

    --! Drop the borrowed references so a bar that stopped animating is not pinned
    --! by the scratch buffer until the next frame overwrites its slot.
    for i = 1, n do
        pending[i] = nil
    end

    if not active and not next(smoothBars) then
        self:SetScript("OnUpdate", nil)
    end
end

local function AttachCellSmoothing(bar)
    function bar:SetSmoothedValue(value)
        smoothBars[self] = value
        smoothDriver:SetScript("OnUpdate", ProcessCellSmoothBars)
    end

    function bar:SetMinMaxSmoothedValue(minValue, maxValue)
        local oldMin, oldMax = self:GetMinMaxValues()
        local target = smoothBars[self]
        self:SetMinMaxValues(minValue, maxValue)
        if target and oldMax ~= oldMin then
            local ratio = (target - oldMin) / (oldMax - oldMin)
            smoothBars[self] = minValue + ratio * (maxValue - minValue)
        end
    end

    function bar:ResetSmoothedValue(value)
        local target = smoothBars[self]
        smoothBars[self] = nil
        if value ~= nil then
            self:SetValue(value)
        elseif target ~= nil then
            self:SetValue(ClampBarValue(self, target))
        end
    end
end

local POWER_WORD_SHIELD_NAME = GetSpellInfo(17) or "Power Word: Shield"
local WEAKENED_SOUL_NAME = GetSpellInfo(6788) or "Weakened Soul"

--! WotLK fix: главный чанк этого файла стоит вплотную к пределу Lua 5.1 -
--! 200 одновременно живых локалов на функцию. Кэш и его хелпер объявлены
--! внутри do...end: на выходе из блока их регистры освобождаются, поэтому
--! в главном чанке по-прежнему занято ровно два имени, как и до правки.
local IsPowerWordShield, IsWeakenedSoul
do
    --! WotLK perf: мемо spellId -> имя. Обе проверки зовутся из aura-цикла, то
    --! есть до 40 юнитов * N аур на обновление, и на каждой ауре, чьё имя не
    --! совпало, платился C-вызов GetSpellInfo. Для конкретного spellId ответ
    --! клиента за сессию не меняется, поэтому кэш сохраняет семантику ровно и
    --! снимает повторный вызов. false - отрицательный ответ (nil означало бы
    --! "ещё не спрашивали"), чтобы промах не спрашивал клиент снова.
    local spellNameById = {}

    local function GetCachedSpellName(spellId)
        local name = spellNameById[spellId]
        if name == nil then
            name = GetSpellInfo(spellId) or false
            spellNameById[spellId] = name
        end
        return name
    end

    function IsPowerWordShield(spellId, spellName)
        if spellName and spellName == POWER_WORD_SHIELD_NAME then
            return true
        end

        if spellId then
            return GetCachedSpellName(spellId) == POWER_WORD_SHIELD_NAME
        end

        return false
    end

    function IsWeakenedSoul(spellId, spellName)
        if spellName and spellName == WEAKENED_SOUL_NAME then
            return true
        end

        if spellId then
            return GetCachedSpellName(spellId) == WEAKENED_SOUL_NAME
        end

        return false
    end
end

--! WotLK fix: restore upstream's Weakened Soul filter, lost in the backport.
--! 6788 is not in the default debuff blacklist, so with a disc priest around a
--! 15s debuff sat on every shielded player and pushed real debuffs out of the
--! three Debuffs slots. Upstream hides it from everyone but priests.
local function FilterWeakenedSoul(spellId)
    return spellId ~= 6788 or Cell.vars.playerClass == "PRIEST"
end

-------------------------------------------------
-- unit button func declarations
-------------------------------------------------
--! WotLK NOTE: в главном чанке этого файла сейчас 199 локалов из 200,
--! разрешённых Lua 5.1 (LUAI_MAXVARS). Свободен ровно один слот: 201-й
--! `local` на верхнем уровне - это не рантайм-ошибка, а отказ компиляции всего
--! файла при загрузке ("main function has more than 200 local variables"), то
--! есть Cell просто не поднимется. Новые помощники держать анонимными,
--! складывать в существующие таблицы или заводить в do...end блоке (локалы
--! блока освобождают регистры на выходе). Проверка - audit/raw/tmp/luacheck.py.
local UnitButton_UpdateAll
local UnitButton_UpdateAuras, UnitButton_UpdateRole, UnitButton_UpdateLeader, UnitButton_UpdateStatusText
local UnitButton_UpdateHealthColor, UnitButton_UpdateNameTextColor, UnitButton_UpdateHealthTextColor
local UnitButton_UpdatePowerMax, UnitButton_UpdatePower, UnitButton_UpdatePowerType, UnitButton_UpdatePowerText, UnitButton_UpdatePowerTextColor
local UnitButton_UpdateShieldAbsorbs, UnitButton_UpdateHealAbsorbs
local CheckPowerEventRegistration, ShouldShowPowerText, ShouldShowPowerBar

-------------------------------------------------
-- unit button init indicators
-------------------------------------------------
local enabledIndicators = {}
local indicatorNums, indicatorBooleans, indicatorColors, indicatorCustoms = {}, {}, {}, {}

local function UpdateIndicatorParentVisibility(b, indicatorName, enabled)
    if not (indicatorName == "debuffs" or
            --! WotLK fix: "privateAuras" из списка убран — такого индикатора в
            --! бэкпорте нет (приватные ауры появились только в ретейле).
            indicatorName == "defensiveCooldowns" or
            indicatorName == "externalCooldowns" or
            indicatorName == "allCooldowns" or
            indicatorName == "crowdControls" or
            indicatorName == "dispels" or
            indicatorName == "missingBuffs") then
        return
    end

    if enabled then
        b.indicators[indicatorName]:Show()
    else
        b.indicators[indicatorName]:Hide()
    end
end

local function ResetIndicators()
    wipe(enabledIndicators)
    wipe(indicatorNums)

    for _, t in pairs(Cell.vars.currentLayoutTable["indicators"]) do
        -- update enabled
        if t["enabled"] then
            enabledIndicators[t["indicatorName"]] = true
        end
        -- update num
        if t["num"] then
            indicatorNums[t["indicatorName"]] = t["num"]
        end

        -- update statusIcon
        if t["indicatorName"] == "statusIcon" then
            I.EnableStatusIcon(t["enabled"])

        -- update aoehealing
        elseif t["indicatorName"] == "aoeHealing" then
            I.EnableAoEHealing(t["enabled"])

        --! WotLK fix: the targetCounter branch is gone with the indicator (GAP-081).

        -- update targetedSpells
        elseif t["indicatorName"] == "targetedSpells" then
            I.UpdateTargetedSpellsNum(t["num"])
            I.ShowAllTargetedSpells(t["showAllSpells"])
            I.EnableTargetedSpells(t["enabled"])

        -- update actions
        elseif t["indicatorName"] == "actions" then
            I.EnableActions(t["enabled"])

        -- update missingBuffs
        elseif t["indicatorName"] == "missingBuffs" then
            --! WotLK fix: showGlow до Enable - иначе первый же проход баффов
            --! (EnableMissingBuffs дёргает GroupRosterUpdate) нарисует иконки
            --! по старому флагу и подсветка мигнёт вопреки настройке.
            I.SetMissingBuffsGlow(t["showGlow"] ~= false)
            I.EnableMissingBuffs(t["enabled"])

        -- update healthThresholds
        elseif t["indicatorName"] == "healthThresholds" then
            I.UpdateHealthThresholds()
        end

        -- update extra
        if t["indicatorName"] == "nameText" or t["indicatorName"] == "powerText" then
            indicatorColors[t["indicatorName"]] = t["color"]
        end
        if t["indicatorName"] == "powerText" then
            indicatorCustoms[t["indicatorName"]] = t["filters"]
        end
        if t["indicatorName"] == "dispels" then
            indicatorBooleans["dispels"] = t["filters"]
        end
        if t["dispellableByMe"] ~= nil then
            indicatorBooleans[t["indicatorName"]] = t["dispellableByMe"]
        end
        if t["onlyShowTopGlow"] ~= nil then
            indicatorBooleans[t["indicatorName"]] = t["onlyShowTopGlow"]
        end
        if t["hideInCombat"] ~= nil then
            indicatorBooleans[t["indicatorName"]] = t["hideInCombat"]
        end
        if t["onlyEnableNotInCombat"] ~= nil then
            indicatorBooleans[t["indicatorName"]] = t["onlyEnableNotInCombat"]
        end
        if t["shieldByMe"] ~= nil then
            indicatorBooleans[t["indicatorName"]] = t["shieldByMe"]
        end
        if t["onlyShowOvershields"] ~= nil then
            indicatorBooleans[t["indicatorName"]] = t["onlyShowOvershields"]
        end
        --! WotLK fix: настройки аггро (порог и "не показывать танков") кладём в уже
        --! существующие indicatorNums/indicatorBooleans, а не в новые локалы файла:
        --! в главном чанке занято 199 слотов из 200, разрешённых Lua 5.1 (см. заметку
        --! у объявлений выше). Коллизии нет - у aggroBlink и aggroBorder своего "num"
        --! не бывает, и других булевых настроек у них тоже нет.
        if t["threatThreshold"] then
            indicatorNums[t["indicatorName"]] = t["threatThreshold"]
        end
        if t["hideForTanks"] ~= nil then
            indicatorBooleans[t["indicatorName"]] = t["hideForTanks"]
        end
    end
end

local function HandleIndicators(b)
    b._indicatorsReady = nil
    b._loggedPendingUpdate = nil

    if b._waitingForIndicatorCreation then
        b._waitingForIndicatorCreation = nil
        I.CreateDefensiveCooldowns(b)
        I.CreateExternalCooldowns(b)
        I.CreateAllCooldowns(b)
        I.CreateDebuffs(b)
        I.CreateCrowdControls(b)
    end

    -- NOTE: Remove old
    --! WotLK perf: hand the incoming layout table over so custom indicators whose
    --! name and type both survive the switch are kept instead of orphaned and
    --! rebuilt. Frames cannot be freed on 3.3.5a, so each rebuild leaked one frame
    --! per custom indicator per button, and this path runs on every layout change
    --! and every group-type change (solo/party/raid, 10/25). The type check reads
    --! indicator.configs, which still holds the PREVIOUS layout entry here -- the
    --! loop below overwrites it at `indicator.configs = t`.
    I.RemoveAllCustomIndicators(b, b._config)

    for _, t in next, b._config do
        local indicator = b.indicators[t["indicatorName"]] or I.CreateIndicator(b, t)
        indicator.configs = t

        -- update position
        if t["position"] then
            if t["indicatorName"] == "statusText" then
                indicator:SetPosition(t["position"][1], t["position"][2], t["position"][3])
            else
                P.ClearPoints(indicator)
                local relativeTo = t["position"][2] == "healthBar" and b.widgets.healthBar or b
                P.Point(indicator, t["position"][1], relativeTo, t["position"][3], t["position"][4], t["position"][5])
            end
        end
        -- update anchor
        if t["anchor"] then
            indicator:SetAnchor(t["anchor"])
        end
        -- update frameLevel
        if t["frameLevel"] then
            indicator:SetFrameLevel(indicator:GetParent():GetFrameLevel()+t["frameLevel"])
        end
        -- update size
        local size = t["size-width"] or t["size"]
        if size then
            -- NOTE: debuffs: ["size"] = {{normalSize}, {bigSize}}
            if t["indicatorName"] == "debuffs" or t["indicatorName"] == "powerWordShield" then
                indicator:SetSize(size[1], size[2])
            else
                P.Size(indicator, size[1], size[2])
            end
        end
        -- update thickness
        if t["thickness"] then
            indicator:SetThickness(t["thickness"])
        end
        -- update border
        if t["border"] then
            indicator:SetBorder(t["border"])
        end
        -- update height
        if t["height"] then
            P.Height(indicator, t["height"])
        end
        -- update height
        if t["textWidth"] then
            indicator:UpdateTextWidth(t["textWidth"])
        end
        -- update alpha
        if t["alpha"] then
            indicator:SetAlpha(t["alpha"])
        end
        -- update numPerLine
        if t["numPerLine"] then
            indicator:SetNumPerLine(t["numPerLine"])
        end
        -- update spacing
        if t["spacing"] then
            indicator:SetSpacing(t["spacing"])
        end
        -- update orientation
        if t["orientation"] then
            indicator:SetOrientation(t["orientation"])
        end
        -- update font
        if t["font"] then
            indicator:SetFont(unpack(t["font"]))
        end
        -- update format
        if t["format"] then
            indicator:SetFormat(t["format"])
            if t["indicatorName"] == "healthText" then
                B.UpdateHealthText(b)
            elseif t["indicatorName"] == "powerText" then
                B.UpdatePowerText(b)
            end
        end
        -- update color
        if t["color"] and t["indicatorName"] ~= "nameText" and t["indicatorName"] ~="powerText" then
            indicator:SetColor(unpack(t["color"]))
        end
        -- update colors
        if t["colors"] then
            indicator:SetColors(t["colors"])
        end
        -- update texture
        if t["texture"] then
            indicator:SetTexture(t["texture"])
        end
        -- update dispel highlight
        if t["highlightType"] then
            indicator:UpdateHighlight(t["highlightType"])
        end
        -- update icon style
        if t["iconStyle"] then
            indicator:SetIconStyle(t["iconStyle"])
        end
        -- update animation
        if type(t["showAnimation"]) == "boolean" then
            indicator:ShowAnimation(t["showAnimation"])
        end
        --! custom: update jump animation (see SESSION_NOTES #20)
        if type(t["showJump"]) == "boolean" and indicator.ShowJump then
            indicator:ShowJump(t["showJump"])
        end
        -- update duration
        if type(t["showDuration"]) == "boolean" or type(t["showDuration"]) == "number" then
            indicator:ShowDuration(t["showDuration"])
        end
        -- update stack
        if type(t["showStack"]) == "boolean" then
            indicator:ShowStack(t["showStack"])
        end
        -- update duration
        if t["duration"] then
            indicator:SetDuration(t["duration"])
        end
        -- update stack
        if t["stack"] then
            indicator:SetStack(t["stack"])
        end
        -- update groupNumber
        if type(t["showGroupNumber"]) == "boolean" then
            indicator:ShowGroupNumber(t["showGroupNumber"])
        end
        -- update vehicleNamePosition
        if t["vehicleNamePosition"] then
            indicator:UpdateVehicleNamePosition(t["vehicleNamePosition"])
        end
        -- update timer
        if type(t["showTimer"]) == "boolean" then
            indicator:SetShowTimer(t["showTimer"])
        end
        -- update background
        if type(t["showBackground"]) == "boolean" then
            indicator:ShowBackground(t["showBackground"])
        end
        -- update role texture
        if t["roleTexture"] then
            indicator:SetRoleTexture(t["roleTexture"])
            indicator:HideDamager(t["hideDamager"])
            UnitButton_UpdateRole(b)
        end
        -- tooltip
        if type(t["showTooltip"]) == "boolean" then
            indicator:ShowTooltip(t["showTooltip"])
        end
        -- blacklist shortcut
        if type(t["enableBlacklistShortcut"]) == "boolean" then
            indicator:EnableBlacklistShortcut(t["enableBlacklistShortcut"])
        end
        -- speed
        if t["speed"] then
            indicator:SetSpeed(t["speed"])
        end
        --! WotLK fix: every call below is driven by an optional config key, but the
        --! matching method only exists on some indicators (e.g. SetHideIfEmptyOrFull is
        --! defined for powerText only). A profile imported from an older Cell build can
        --! leave a stale top-level key on an indicator that never supported it -
        --! healthText used to carry "hideIfEmptyOrFull" before it moved inside "format" -
        --! and calling the missing method errors on every button refresh. Check the
        --! method exists before invoking it.
        -- update fadeOut
        if type(t["fadeOut"]) == "boolean" and indicator.SetFadeOut then
            indicator:SetFadeOut(t["fadeOut"])
        end
        --! WotLK fix: чтения t["shape"] здесь больше нет: настройка мертва в этом
        --! бэкпорте (Power Word: Shield стал полосой, виджет формы вырезан).
        -- update glow
        if t["glowOptions"] and indicator.SetupGlow then
            indicator:SetupGlow(t["glowOptions"])
        end
        -- update smooth
        if type(t["smooth"]) == "boolean" and indicator.EnableSmooth then
            indicator:EnableSmooth(t["smooth"])
        end
        -- max value
        if t["maxValue"] and indicator.SetMaxValue then
            indicator:SetMaxValue(t["maxValue"])
        end
        -- update hideIfEmptyOrFull
        if type(t["hideIfEmptyOrFull"]) == "boolean" and indicator.SetHideIfEmptyOrFull then
            indicator:SetHideIfEmptyOrFull(t["hideIfEmptyOrFull"])
        end

        -- init
        -- update name visibility
        if t["indicatorName"] == "nameText" or t["indicatorName"] == "healthText" then
            if t["enabled"] then
                indicator:Show()
            else
                indicator:Hide()
            end
        elseif t["indicatorName"] == "playerRaidIcon" then
            B.UpdatePlayerRaidIcon(b, t["enabled"])
        elseif t["indicatorName"] == "targetRaidIcon" then
            B.UpdateTargetRaidIcon(b, t["enabled"])
        elseif t["indicatorName"] == "readyCheckIcon" then
            B.UpdateReadyCheckIcon(b, t["enabled"])
        else
            UpdateIndicatorParentVisibility(b, t["indicatorName"], t["enabled"])
        end

        -- update pixel perfect for built-in widgets
        -- if t["type"] == "built-in" then
        --     if indicator.UpdatePixelPerfect then
        --         indicator:UpdatePixelPerfect()
        --     end
        -- end
    end

    --! update pixel perfect for widgets
    B.UpdatePixelPerfect(b, true)

    b._indicatorsReady = true
    F.Debug("Indicators ready for", b:GetName(), "guid", b.states.guid or "nil")
end

-------------------------------------------------
-- indicator update queue
-------------------------------------------------
local updater = CreateFrame("Frame")
updater:Hide()
local queue = {}

local WAITING_FOR_INIT = "WAITING_FOR_INIT"
local WAITING_FOR_UPDATE = "WAITING_FOR_UPDATE"

local function Process(b)
    if b then
        -- print("Process", GetTime(), b:GetName(), b._status)
        if b._status == WAITING_FOR_INIT then
            -- print("processing_init", GetTime(), b:GetName())
            b._status = "processing"
            HandleIndicators(b)
            UnitButton_UpdateAuras(b)
        elseif b._status == WAITING_FOR_UPDATE then
            -- print("processing_update", GetTime(), b:GetName())
            b._indicatorsReady = true
            b._status = "processing"
            UnitButton_UpdateAuras(b)
        end

        CellLoadingBar.current = (CellLoadingBar.current or 0) + 1
        CellLoadingBar:SetValue(CellLoadingBar.current)
        b._status = nil
        b._config = nil
        queue[b] = nil
    else
        CellLoadingBar:Hide()
        CellLoadingBar.current = 0
        updater:Hide()
    end
end

updater:SetScript("OnUpdate", function()
    Process(next(queue))
    Process(next(queue))
end)

hooksecurefunc(updater, "Show", function()
    CellLoadingBar.total = F.Getn(queue)
    CellLoadingBar.current = 0
    CellLoadingBar:SetMinMaxValues(0, CellLoadingBar.total)
    CellLoadingBar:SetValue(0)
    CellLoadingBar:Show()
end)

local function FlushQueue()
    updater:Hide()
    wipe(queue)
end

local function AddToInitQueue(b)
    b._indicatorsReady = nil
    b._status = WAITING_FOR_INIT
    b._config = Cell.vars.currentLayoutTable["indicators"]
    queue[b] = true
    F.Debug("InitQueue +", b:GetName(), "unit", b.states.unit or "nil")
end

local function AddToUpdateQueue(b)
    if queue[b] then return end
    --! WotLK fix: a button that never went through the init path still has
    --! _waitingForIndicatorCreation set and NO indicator frames created (e.g. the
    --! combined-header buttons the first time Combine Groups is toggled on: the layout
    --! name does not change, so UpdateIndicators routes ALL buttons into the update
    --! queue). The WAITING_FOR_UPDATE branch of Process() force-sets _indicatorsReady
    --! and runs UnitButton_UpdateAuras, which crashed on self.indicators.debuffs (nil),
    --! and the OnTick path (_updateRequired) then kept crashing every 0.25s. Route such
    --! buttons to the INIT queue instead - it creates indicators from the current layout.
    if b._waitingForIndicatorCreation then
        AddToInitQueue(b)
        return
    end
    b._indicatorsReady = nil
    b._status = WAITING_FOR_UPDATE
    queue[b] = true
    F.Debug("UpdateQueue +", b:GetName(), "unit", b.states.unit or "nil")
end

-------------------------------------------------
-- UpdateIndicators
-------------------------------------------------
local activeLayouts = {
    solo = nil,
    party = nil,
    raid = nil,
}

local function UpdateIndicators(layout, indicatorName, setting, value, value2)
    F.Debug("|cffff7777UpdateIndicators:|r ", layout, indicatorName, setting, value, value2)

    --! WotLK fix: Cell.Fire dispatches listeners with pairs(), so the Lua 5.1
    --! callback order cannot guarantee that custom-indicator cache mutation
    --! finishes before this redraw handler. Update that private cache directly
    --! before any layout/visibility early return or indicator refresh.
    I.UpdateCustomIndicatorSettings(layout, indicatorName, setting, value, value2)

    -- FlushQueue()

    local currentLayout = Cell.vars.currentLayout
    local INDEX = Cell.vars.groupType

    --! WotLK fix: PLAYER_ENTERING_WORLD can request a layout before the deferred
    --! 3.3.5 roster route has initialized groupType. Lua table keys cannot be nil;
    --! derive the live group type here and persist it so the first UpdateIndicators
    --! fired by F.UpdateLayout cannot crash during login/reload.
    if INDEX ~= "solo" and INDEX ~= "party" and INDEX ~= "raid" then
        if IsInRaid() then
            INDEX = "raid"
        elseif IsInGroup() then
            INDEX = "party"
        else
            INDEX = "solo"
        end
        Cell.vars.groupType = INDEX
    end

    if layout then
        -- Cell.Fire("UpdateIndicators", layout): indicators copy/import
        -- Cell.Fire("UpdateIndicators", xxx, ...): indicator updated
        for groupType, groupLayout in next, activeLayouts do
            if groupLayout == layout then
                activeLayouts[groupType] = nil -- update required
                F.Debug("  -> UPDATE REQUIRED:", groupType)
            end
        end

        --! indicator changed, but not current layout
        if layout ~= currentLayout then
            F.Debug("  -> NO UPDATE: not active layout")
            return
        end

    else -- Cell.Fire("UpdateIndicators")
        --! layout/groupType switched, check if update is required
        if activeLayouts[INDEX] == currentLayout then
            I.ResetCustomIndicatorTables()
            ResetIndicators()
                F.Debug("  -> NO FULL UPDATE: only reset custom indicator tables")
                F.IterateAllUnitButtons(AddToUpdateQueue, true, nil, true)
                F.IterateSharedUnitButtons(AddToInitQueue)
            updater:Show()
            return
        end
    end

    if Cell.vars.isHidden then
        F.Debug("  -> NO UPDATE: Cell is hidden")
        I.ResetCustomIndicatorTables()
        ResetIndicators()
        return
    end

    activeLayouts[INDEX] = currentLayout

    if not indicatorName then -- init
        F.Debug("  -> FULL UPDATE", INDEX, currentLayout)
        I.ResetCustomIndicatorTables()
        ResetIndicators()
        F.IterateAllUnitButtons(AddToInitQueue, true)
        updater:Show()

    else
        -- changed in IndicatorsTab
        if setting == "enabled" then
            enabledIndicators[indicatorName] = value

            if indicatorName == "statusIcon" then
                --! WotLK fix: incremental statusIcon changes must mirror the
                --! full-layout lifecycle, including event registration and an
                --! immediate redraw of already-created buttons.
                I.EnableStatusIcon(value)
                if value then
                    F.IterateAllUnitButtons(function(b)
                        I.UpdateStatusIcon(b)
                    end, true)
                end
            elseif indicatorName == "combatIcon" then
                F.IterateAllUnitButtons(function(b)
                    if not value then
                        b.indicators[indicatorName]:Hide()
                    end
                end, true)
            elseif indicatorName == "aoeHealing" then
                I.EnableAoEHealing(value)
            elseif indicatorName == "targetedSpells" then
                I.EnableTargetedSpells(value)
            elseif indicatorName == "actions" then
                I.EnableActions(value)
            elseif indicatorName == "roleIcon" then
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateRole(b)
                end, true)
            elseif indicatorName == "leaderIcon" then
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateLeader(b)
                end, true)
            elseif indicatorName == "playerRaidIcon" then
                F.IterateAllUnitButtons(function(b)
                    B.UpdatePlayerRaidIcon(b, value)
                end, true)
            elseif indicatorName == "targetRaidIcon" then
                F.IterateAllUnitButtons(function(b)
                    B.UpdateTargetRaidIcon(b, value)
                end, true)
            elseif indicatorName == "readyCheckIcon" then
                F.IterateAllUnitButtons(function(b)
                    B.UpdateReadyCheckIcon(b, value)
                end, true)
            elseif indicatorName == "nameText" then
                F.IterateAllUnitButtons(function(b)
                    if value then
                        b.indicators[indicatorName]:Show()
                    else
                        b.indicators[indicatorName]:Hide()
                    end
                end, true)
            elseif indicatorName == "statusText" then
                F.IterateAllUnitButtons(function(b)
                    B.UpdateStatusText(b)
                end, true)
            elseif indicatorName == "healthText" then
                F.IterateAllUnitButtons(function(b)
                    if value then
                        b.indicators[indicatorName]:Show()
                        B.UpdateHealthText(b)
                    else
                        b.indicators[indicatorName]:Hide()
                    end
                end, true)
            elseif indicatorName == "powerText" then
                F.IterateAllUnitButtons(function(b)
                    b._shouldShowPowerText = ShouldShowPowerText(b)
                    CheckPowerEventRegistration(b)
                    if b._shouldShowPowerText then
                        B.UpdatePowerText(b)
                    else
                        b.indicators[indicatorName]:Hide()
                    end
                end, true)
            elseif indicatorName == "shieldBar" then
                F.IterateAllUnitButtons(function(b)
                    B.UpdateShield(b)
                end, true)
            elseif indicatorName == "healthThresholds" then
                if value then
                    I.UpdateHealthThresholds()
                end
                F.IterateAllUnitButtons(function(b)
                    B.UpdateHealth(b)
                end, true)
            elseif indicatorName == "missingBuffs" then
                I.EnableMissingBuffs(value)
                F.IterateAllUnitButtons(function(b)
                    UpdateIndicatorParentVisibility(b, indicatorName, value)
                end, true)
            else
                -- refresh
                F.IterateAllUnitButtons(function(b)
                    UpdateIndicatorParentVisibility(b, indicatorName, value)
                    if not value then
                        b.indicators[indicatorName]:Hide() -- hide indicators which is shown right now
                    end
                    UnitButton_UpdateAuras(b)
                end, true)
            end
        elseif setting == "position" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                if indicatorName == "statusText" then
                    indicator:SetPosition(value[1], value[2], value[3])
                else
                    P.ClearPoints(indicator)
                    local relativeTo = value[2] == "healthBar" and b.widgets.healthBar or b
                    P.Point(indicator, value[1], relativeTo, value[3], value[4], value[5])
                end
                -- update arrangement
                if indicator.indicatorType == "icons" then
                    indicator:SetOrientation(indicator.orientation)
                end
            end, true)
        elseif setting == "anchor" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetAnchor(value)
            end, true)
        elseif setting == "frameLevel" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetFrameLevel(indicator:GetParent():GetFrameLevel()+value)
            end, true)
        elseif setting == "size" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                if indicatorName == "debuffs" then
                    indicator:SetSize(value[1], value[2])
                    -- update debuffs' normal/big icon sizes
                    UnitButton_UpdateAuras(b)
                else
                    P.Size(indicator, value[1], value[2])
                end
            end, true)
        elseif setting == "size-width" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                local height = (indicator.configs and indicator.configs["size"] and indicator.configs["size"][2]) or value[2] or indicator:GetHeight() or 0
                if indicator.SetSize then
                    indicator:SetSize(value[1], height)
                else
                    P.Size(indicator, value[1], height)
                end
            end, true)
        elseif setting == "size-border" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                P.Size(indicator, value[1], value[2])
                indicator:SetBorder(value[3])
            end, true)
        elseif setting == "thickness" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetThickness(value)
            end, true)
        elseif setting == "height" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                P.Height(indicator, value)
            end, true)
        elseif setting == "textWidth" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:UpdateTextWidth(value)
            end, true)
        elseif setting == "alpha" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetAlpha(value)
            end, true)
        elseif setting == "spacing" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetSpacing(value)
            end, true)
        elseif setting == "orientation" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetOrientation(value)
            end, true)
        elseif setting == "font" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetFont(unpack(value))
            end, true)
        elseif setting == "format" then
            if indicatorName == "healthText" then
                F.IterateAllUnitButtons(function(b)
                    local indicator = b.indicators[indicatorName]
                    indicator:SetFormat(value)
                    B.UpdateHealthText(b)
                end, true)
            elseif indicatorName == "powerText" then
                F.IterateAllUnitButtons(function(b)
                    local indicator = b.indicators[indicatorName]
                    indicator:SetFormat(value)
                    B.UpdatePowerText(b)
                end, true)
            end
        elseif setting == "color" then
            if indicatorName == "nameText" then
                indicatorColors[indicatorName] = value
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateNameTextColor(b)
                end, true)
            elseif indicatorName == "powerText" then
                indicatorColors[indicatorName] = value
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdatePowerTextColor(b)
                end, true)
            else
                F.IterateAllUnitButtons(function(b)
                    local indicator = b.indicators[indicatorName]
                    indicator:SetColor(unpack(value))
                end, true)
            end
        elseif setting == "colors" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetColors(value) -- update color on next SetCooldown
                UnitButton_UpdateAuras(b) -- call SetCooldown now
            end, true)
        elseif setting == "vehicleNamePosition" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:UpdateVehicleNamePosition(value)
            end, true)
        elseif setting == "statusColors" then
            F.IterateAllUnitButtons(function(b)
                UnitButton_UpdateStatusText(b)
            end, true)
        elseif setting == "num" then
            indicatorNums[indicatorName] = value
            if indicatorName == "targetedSpells" then
                I.UpdateTargetedSpellsNum(value)
            else
                -- refresh
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateAuras(b)
                end, true)
            end
        elseif setting == "threatThreshold" then
            --! WotLK fix: порог аггро хранится в indicatorNums - в главном чанке файла
            --! свободен один local из 200 (см. заметку у объявлений), а своего "num" у
            --! aggroBlink/aggroBorder не бывает. Перерисовываем сразу: threat-события
            --! в мирное время не приходят, иначе ползунок выглядел бы мёртвым.
            indicatorNums[indicatorName] = value
            F.IterateAllUnitButtons(B.UpdateThreat, true)
        elseif setting == "numPerLine" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetNumPerLine(value)
            end, true)
        elseif setting == "roleTexture" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetRoleTexture(value)
                UnitButton_UpdateRole(b)
            end, true)
        elseif setting == "texture" then
            F.IterateAllUnitButtons(function(b)
                local indicator = b.indicators[indicatorName]
                indicator:SetTexture(value)
            end, true)
        elseif setting == "duration" or setting == "dispelFilters" then
            F.IterateAllUnitButtons(function(b)
                UnitButton_UpdateAuras(b)
            end, true)
        elseif setting == "stack" then
            F.IterateAllUnitButtons(function(b)
                b.indicators[indicatorName]:SetStack(value)
                UnitButton_UpdateAuras(b)
            end, true)
        elseif setting == "highlightType" then
            F.IterateAllUnitButtons(function(b)
                b.indicators[indicatorName]:UpdateHighlight(value)
                UnitButton_UpdateAuras(b)
            end, true)
        elseif setting == "thresholds" then
            I.UpdateHealthThresholds()
            F.IterateAllUnitButtons(function(b)
                B.UpdateHealth(b)
            end, true)
        elseif setting == "showDuration" then
            F.IterateAllUnitButtons(function(b)
                b.indicators[indicatorName]:ShowDuration(value)
                UnitButton_UpdateAuras(b)
            end, true)
        elseif setting == "powerTextFilters" then
            F.IterateAllUnitButtons(function(b)
                b._shouldShowPowerText = ShouldShowPowerText(b)
                CheckPowerEventRegistration(b)
                if b._shouldShowPowerText then
                    B.UpdatePowerText(b)
                else
                    b.indicators[indicatorName]:Hide()
                end
            end, true)
        elseif setting == "maxValue" then
            F.IterateAllUnitButtons(function(b)
                b.indicators[indicatorName]:SetMaxValue(value)
                UnitButton_UpdateAuras(b)
            end, true)
        elseif setting == "glowOptions" then
            F.IterateAllUnitButtons(function(b)
                b.indicators[indicatorName]:SetupGlow(value)
                UnitButton_UpdateAuras(b)
            end, true)
        elseif setting == "iconStyle" then
            F.IterateAllUnitButtons(function(b)
                b.indicators[indicatorName]:SetIconStyle(value)
                UnitButton_UpdateAuras(b)
            end, true)
        elseif setting == "checkbutton" then
            if value == "showGroupNumber" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:ShowGroupNumber(value2)
                end, true)
            elseif value == "showTimer" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:SetShowTimer(value2)
                    UnitButton_UpdateStatusText(b)
                end, true)
            elseif value == "showBackground" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:ShowBackground(value2)
                end, true)
            elseif value == "hideIfEmptyOrFull" then
                if indicatorName == "powerText" then
                    F.IterateAllUnitButtons(function(b)
                        b.indicators[indicatorName]:SetHideIfEmptyOrFull(value2)
                        B.UpdatePowerText(b)
                    end, true)
                end
            elseif value == "hideInCombat" then
                indicatorBooleans[indicatorName] = value2
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateLeader(b)
                end, true)
            elseif value == "onlyEnableNotInCombat" then
                indicatorBooleans[indicatorName] = value2
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:Hide()
                end, true)
            elseif value == "shieldByMe" then
                --! WotLK fix: писался только булев. Флаг читается в проходе
                --! баффов как pwsMineOnly (indicatorBooleans["powerWordShield"],
                --! UnitButton_UpdateBuffs), поэтому уже нарисованный PW:S висел
                --! по старому правилу до следующего события аур. Сосед
                --! onlyShowOvershields ниже перерисовывает сразу - здесь то же,
                --! но через аура-проход, а не через щиты: булев гейтит икону
                --! баффа, CLEU-ветка (:3245) отработает сама на следующем щите.
                indicatorBooleans[indicatorName] = value2
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateAuras(b)
                end, true)
            elseif value == "onlyShowOvershields" then
                indicatorBooleans[indicatorName] = value2
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateShieldAbsorbs(b)
                end, true)
            elseif value == "showGlow" then
                --! WotLK fix: тумблер мигающей подсветки индикатора Missing Buffs.
                --! Гасит/запускает уже нарисованные иконки сам, обходить кнопки
                --! здесь не нужно - см. I.SetMissingBuffsGlow.
                if indicatorName == "missingBuffs" then
                    I.SetMissingBuffsGlow(value2)
                end
            elseif value == "hideForTanks" then
                --! WotLK fix: "не показывать танков" для аггро-индикаторов. Танк
                --! держит моба по должности, его status/процент всегда наверху - на
                --! 25ппл это половина мигающих рамок, которые ни о чём не сообщают.
                --! Флаг ложится в indicatorBooleans (других булевых настроек у этих
                --! двух индикаторов нет), перерисовка - сразу, см. B.UpdateThreat.
                indicatorBooleans[indicatorName] = value2
                F.IterateAllUnitButtons(B.UpdateThreat, true)
            elseif value == "showStack" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:ShowStack(value2)
                    UnitButton_UpdateAuras(b)
                end, true)
            elseif value == "showAnimation" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:ShowAnimation(value2)
                    UnitButton_UpdateAuras(b)
                end, true)
            --! custom: jump animation toggle (see SESSION_NOTES #20)
            elseif value == "showJump" then
                F.IterateAllUnitButtons(function(b)
                    local indicator = b.indicators[indicatorName]
                    if indicator and indicator.ShowJump then
                        indicator:ShowJump(value2)
                    end
                end, true)
            elseif value == "trackByName" then
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateAuras(b)
                end, true)
            elseif value == "dispellableByMe" then
                indicatorBooleans[indicatorName] = value2
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateAuras(b)
                end, true)
            elseif value == "showTooltip" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:ShowTooltip(value2)
                end, true)
            elseif value == "enableBlacklistShortcut" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:EnableBlacklistShortcut(value2)
                end, true)
            elseif value == "hideDamager" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:HideDamager(value2)
                    UnitButton_UpdateRole(b)
                end, true)
            elseif value == "fadeOut" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:SetFadeOut(value2)
                    UnitButton_UpdateAuras(b)
                end, true)
            elseif value == "smooth" then
                F.IterateAllUnitButtons(function(b)
                    b.indicators[indicatorName]:EnableSmooth(value2)
                end, true)
            elseif value == "onlyShowTopGlow" then
                --! WotLK fix: попадало в общий else, то есть менялся только
                --! булев. Флаг читается в аура-проходе как raidDebuffsFirstOnly
                --! (indicatorBooleans["raidDebuffs"]), поэтому свечение на уже
                --! висящих рейд-дебаффах не пересчитывалось до нового UNIT_AURA:
                --! галка стояла в новом положении, экран - в старом.
                indicatorBooleans[indicatorName] = value2
                F.IterateAllUnitButtons(function(b)
                    UnitButton_UpdateAuras(b)
                end, true)
            elseif value == "showAllSpells" then
                I.ShowAllTargetedSpells(value2)
            else
                indicatorBooleans[indicatorName] = value2
            end
        elseif setting == "create" then
            I.UpdateIndicatorTable(value)
            F.IterateAllUnitButtons(function(b)
                local indicator = I.CreateIndicator(b, value)
                indicator.configs = value

                -- update position
                if value["position"] then
                    P.ClearPoints(indicator)
                    local relativeTo = value["position"][2] == "healthBar" and b.widgets.healthBar or b
                    P.Point(indicator, value["position"][1], relativeTo, value["position"][3], value["position"][4], value["position"][5])
                end
                -- update anchor
                if value["anchor"] then
                    indicator:SetAnchor(value["anchor"])
                end
                -- update size
                if value["size"] then
                    P.Size(indicator, value["size"][1], value["size"][2])
                end
                -- update thickness
                if value["thickness"] then
                    indicator:SetThickness(value["thickness"])
                end
                -- update frameLevel
                if value["frameLevel"] then
                    indicator:SetFrameLevel(indicator:GetParent():GetFrameLevel()+value["frameLevel"])
                end
                -- update numPerLine
                if value["numPerLine"] then
                    indicator:SetNumPerLine(value["numPerLine"])
                end
                -- update spacing
                if value["spacing"] then
                    indicator:SetSpacing(value["spacing"])
                end
                -- update orientation
                if value["orientation"] then
                    indicator:SetOrientation(value["orientation"])
                end
                -- update font
                if value["font"] then
                    indicator:SetFont(unpack(value["font"]))
                end
                -- update color
                if value["color"] then
                    indicator:SetColor(unpack(value["color"]))
                end
                -- update colors
                if value["colors"] then
                    indicator:SetColors(value["colors"])
                end
                -- update texture
                if value["texture"] then
                    indicator:SetTexture(value["texture"])
                end
                -- update showAnimation
                if type(value["showAnimation"]) == "boolean" then
                    indicator:ShowAnimation(value["showAnimation"])
                end
                --! custom: update jump animation (see SESSION_NOTES #20)
                if type(value["showJump"]) == "boolean" and indicator.ShowJump then
                    indicator:ShowJump(value["showJump"])
                end
                -- update showDuration
                if type(value["showDuration"]) ~= "nil" then
                    indicator:ShowDuration(value["showDuration"])
                end
                -- update showStack
                if type(value["showStack"]) ~= "nil" then
                    indicator:ShowStack(value["showStack"])
                end
                -- update duration
                if value["duration"] then
                    indicator:SetDuration(value["duration"])
                end
                -- update stack
                if value["stack"] then
                    indicator:SetStack(value["stack"])
                end
                -- update fadeOut
                if type(value["fadeOut"]) == "boolean" then
                    indicator:SetFadeOut(value["fadeOut"])
                end
                -- update glow
                if value["glowOptions"] then
                    indicator:SetupGlow(value["glowOptions"])
                end
                -- FirstRun: Healers
                if value["auras"] and #value["auras"] ~= 0 then
                    UnitButton_UpdateAuras(b)
                end
            end, true)
        elseif setting == "remove" then
            F.IterateAllUnitButtons(function(b)
                I.RemoveIndicator(b, indicatorName, value)
            end, true)
        elseif setting == "castBy" then
            --! WotLK fix: the custom cache is updated above, but castBy has no
            --! generic redraw path. Re-scan current buttons so old matches do
            --! not remain visible after the caster filter changes.
            F.IterateAllUnitButtons(function(b)
                UnitButton_UpdateAuras(b)
            end, true)
        elseif setting == "auras" then
            -- indicator auras changed, hide them all, then recheck whether to show
            F.IterateAllUnitButtons(function(b)
                b.indicators[indicatorName]:Hide()
                UnitButton_UpdateAuras(b)
            end, true)
        --! WotLK fix: "crowdControls" в списке не было. I.UpdateCrowdControls
        --! (Indicator_DefaultSpells_Wrath.lua:653) только перестраивает две
        --! таблицы-словаря и ничего не рисует - ровно как I.UpdateExternals,
        --! который здесь уже перечислен. Без этого включение/выключение CC
        --! в списке не убирало и не добавляло уже висящие иконки.
        elseif setting == "debuffBlacklist" or setting == "dispelBlacklist" or setting == "defensives" or setting == "externals" or setting == "crowdControls" or setting == "bigDebuffs" or setting == "debuffTypeColor" then
            F.IterateAllUnitButtons(function(b)
                UnitButton_UpdateAuras(b)
            end, true)
        elseif setting == "speed" then
            -- only Actions indicator has this option for now
            F.IterateAllUnitButtons(function(b)
                b.indicators[indicatorName]:SetSpeed(value)
            end, true)
        end
    end
end
Cell.RegisterCallback("UpdateIndicators", "UnitButton_UpdateIndicators", UpdateIndicators)

-------------------------------------------------
-- aura instance key (3.3.5 auraInstanceID emulation)
-------------------------------------------------
--! WotLK fix/perf: the emulated auraInstanceID was '(source or "")..spellId' -
--! ambiguous ("raid1"..56789 == "raid15"..6789), so different auras could collide
--! in the _buffs/_debuffs caches, and it built a fresh throwaway string for EVERY
--! aura of EVERY button on EVERY UNIT_AURA (thousands per minute of GC churn in a
--! raid). Keys now carry a ":" separator (collisions gone: unit tokens contain no
--! colons) and are memoized: sources are unit tokens (bounded set) and spellIds are
--! bounded by auras actually seen, so the cache stays small and steady-state scans
--! allocate no strings at all. The key is a pure cache key on 3.3.5 - the only
--! other consumer (SetUnit*ByAuraInstanceID tooltip branch in Indicators/Built-in)
--! is dead retail code, tooltips here go through the .index path.
local auraKeyCache = {}
local function GetAuraInstanceID(source, spellId)
    source = source or ""
    local bySource = auraKeyCache[source]
    if not bySource then
        bySource = {}
        auraKeyCache[source] = bySource
    end
    local key = bySource[spellId]
    if not key then
        key = source..":"..spellId
        bySource[spellId] = key
    end
    return key
end

-------------------------------------------------
-- debuffs
-------------------------------------------------
--! WotLK fix: table.sort calls this only synchronously, so one short-lived
--! owner reference avoids allocating a new closure for every UNIT_AURA while
--! preserving each button's private order table.
--! WotLK perf: держим саму таблицу порядков, а не кнопку - компаратор зовётся
--! O(n log n) раз за сортировку, и каждый вызов делал два лишних хеш-лукапа
--! ._debuffs_raid_orders. Таблица создаётся один раз в InitAuraTables и дальше
--! только wipe'ается, так что ссылка на неё живёт столько же, сколько кнопка.
local raidDebuffSortOrders
local function SortRaidDebuffsByOrder(a, b)
    return raidDebuffSortOrders[a] < raidDebuffSortOrders[b]
end

local function UnitButton_UpdateDebuffs(self)
    local unit = self.states.displayedUnit

    -- self.states.BGOrb = nil

    -- user created indicators
    I.ResetCustomIndicators(self, "debuff")

    local startIndex, raidDebuffsFound, wsFound = 1
    local ccFound = 1
    local glowType, glowOptions
    local refreshing = false

    --! WotLK perf: всё, что не меняется за время цикла, поднято перед ним.
    --! Цикл крутится сорок раз на каждое UNIT_AURA каждой кнопки - это самое
    --! горячее место аддона, и внутри него на каждой итерации шли: чтение глобала
    --! Cell плюс хеш-лукап .vars (до шести раз), повторные лукапы enabledIndicators
    --! и indicatorBooleans, повторные чтения self._debuffs_* и self.indicators.
    --! Ни одна из этих величин не может измениться внутри цикла: таблицы
    --! Cell.vars.* переписываются только колбэками настроек (Core_Wrath.lua:569-582,
    --! Indicators.lua), enabledIndicators - только из UpdateIndicators (:292, :761),
    --! а сами таблицы self._debuffs_* создаются один раз в InitAuraTables и дальше
    --! только wipe'аются, не подменяются.
    local vars = Cell.vars
    local iconAnimation = vars.iconAnimation
    local debuffBlacklist = vars.debuffBlacklist
    local bigDebuffs = vars.bigDebuffs
    local bigDebuffNames = vars.bigDebuffNames
    local dispelBlacklist = vars.dispelBlacklist

    local indicators = self.indicators
    local debuffsCache = self._debuffs_cache
    local debuffsCountCache = self._debuffs_count_cache
    local debuffsCurrent = self._debuffs_current
    local debuffsBig = self._debuffs_big
    local debuffsNormal = self._debuffs_normal
    local debuffsRaid = self._debuffs_raid
    local debuffsRaidRefreshing = self._debuffs_raid_refreshing
    local debuffsRaidOrders = self._debuffs_raid_orders
    local debuffsGlowCurrent = self._debuffs_glow_current
    local debuffsGlowCache = self._debuffs_glow_cache
    local debuffsDispel = self._debuffs_dispel

    local debuffsOn = enabledIndicators["debuffs"]
    local debuffsOnlyDispellable = indicatorBooleans["debuffs"]
    local raidDebuffsOn = enabledIndicators["raidDebuffs"]
    local raidDebuffsFirstOnly = indicatorBooleans["raidDebuffs"]
    local dispelsOn = enabledIndicators["dispels"]
    --! WotLK perf: таблица фильтров тоже неизменна за вызов - её переписывает только
    --! колбэк настроек (:339). Читалась на каждый дебафф с типом.
    local dispelFilters = indicatorBooleans["dispels"]
    local pwsOn = enabledIndicators["powerWordShield"]
    local ccOn = enabledIndicators["crowdControls"]
    local ccNum = indicatorNums["crowdControls"]

    for i = 1, 40 do
        --! WotLK perf: direct native UnitDebuff (3.3.5 signature: name,
        --! rank, icon, count, debuffType, duration, expirationTime, caster,
        --! isStealable, shouldConsolidate, spellId) instead of the
        --! Cell.UnitDebuff translation wrapper - this is the hottest loop
        --! in the addon (40 iterations per UNIT_AURA per button).
        local name, _, icon, count, debuffType, duration, expirationTime, source, _, _, spellId = UnitDebuff(unit, i)
        if not name then
            break
        end

        local auraInstanceID = GetAuraInstanceID(source, spellId) --! WotLK fix/perf: was '(source or "")..spellId' - collision-prone + string churn

        -- check Bleed
        debuffType = I.CheckDebuffType(debuffType, spellId)

        if duration then
            --! WotLK perf: start считается один раз - ниже он нужен до трёх раз.
            local start = expirationTime - duration
            --! WotLK perf: кэши читались по два-три раза на итерацию.
            local cachedExpiration = debuffsCache[auraInstanceID]
            local cachedCount = debuffsCountCache[auraInstanceID]

            if iconAnimation == "duration" then
                local timeIncreased = cachedExpiration and (expirationTime - cachedExpiration >= 0.5) or false
                local countIncreased = cachedCount and (count > cachedCount) or false
                refreshing = timeIncreased or countIncreased
            elseif iconAnimation == "stack" then
                refreshing = cachedCount and (count > cachedCount) or false
            else
                refreshing = false
            end

            if debuffsOn and not debuffBlacklist[spellId] and FilterWeakenedSoul(spellId) then
                local isBigDebuff = bigDebuffs[spellId]
                if not isBigDebuff and name then
                    isBigDebuff = bigDebuffNames[name]
                end

                if isBigDebuff or (not debuffsOnlyDispellable or I.CanDispel(debuffType)) then
                    if isBigDebuff then  -- isBigDebuff
                        debuffsBig[i] = refreshing
                    else
                        debuffsNormal[i] = refreshing
                    end
                end
            end

            -- user created indicators
            --! WotLK fix: castByMe was not passed for debuffs (only for
            --! buffs), so custom debuff indicators with "Cast By: Me" never
            --! showed and "Cast By: Others" matched everything. The debuff
            --! loop already has `source` - derive castByMe the same way the
            --! buff path does (upstream computes it for both aura types).
            I.UpdateCustomIndicators(self, "debuff", spellId, name, start, duration, debuffType or "", icon, count, refreshing, source == "player" or source == "pet")

            -- prepare raidDebuffs
            --! WotLK perf: I.GetDebuffOrder was called twice per matching debuff -
            --! once as the condition, once for the stored order - and it is not a
            --! plain lookup: it re-evaluates the aura's stack condition every call.
            --! One call, one local.
            local debuffOrder
            if raidDebuffsOn then
                debuffOrder = I.GetDebuffOrder(name, spellId, count)
            end
            if debuffOrder then
                raidDebuffsFound = true
                tinsert(debuffsRaid, i)
                debuffsRaidRefreshing[i] = refreshing -- store all raidDebuffs
                debuffsRaidOrders[i] = debuffOrder

                if not raidDebuffsFirstOnly then -- glow all matching debuffs
                    glowType, glowOptions = I.GetDebuffGlow(name, spellId, count)
                    if glowType and glowType ~= "None" then
                        debuffsGlowCurrent[glowType] = glowOptions
                        debuffsGlowCache[glowType] = true
                    end
                end
            end

            debuffsCache[auraInstanceID] = expirationTime
            debuffsCountCache[auraInstanceID] = count
            debuffsCurrent[auraInstanceID] = i

            if dispelsOn and debuffType and debuffType ~= "" then
                if dispelFilters and dispelFilters[debuffType] then
                    local canDispel = I.CanDispel(debuffType)
                    -- when "only show dispellable by me" is checked, require a positive match
                    -- NOTE: Bleeds are never dispellable by any class, so I.CanDispel("Bleed")
                    -- is always nil. Without this exception, the default "dispellableByMe"
                    -- filter would permanently hide Bleed highlights even though the Bleed
                    -- filter is enabled. Bleeds bypass the dispellable-by-me gate.
                    if not dispelFilters["dispellableByMe"] or canDispel or debuffType == "Bleed" then
                        if dispelBlacklist[spellId] then
                            debuffsDispel[debuffType] = false
                        else
                            debuffsDispel[debuffType] = true
                        end
                    end
                end
            end

            if pwsOn and IsWeakenedSoul(spellId, name) then
                wsFound = true
                indicators.powerWordShield:SetWeakenedSoulCooldown(start, duration, source == "player")
            end

            -- crowdControls
            if ccOn and I.IsCrowdControls(name, spellId) and ccFound <= ccNum then
                -- start, duration, debuffType, texture, count, refreshing
                indicators.crowdControls[ccFound]:SetCooldown(start, duration, debuffType, icon, count, refreshing)
                ccFound = ccFound + 1
            end

            -- BG orbs
            -- if spellId == 121164 then
            --     self.states.BGOrb = "blue"
            -- end
            -- if spellId == 121175 then
            --     self.states.BGOrb = "purple"
            -- end
            -- if spellId == 121176 then
            --     self.states.BGOrb = "green"
            -- end
            -- if spellId == 121177 then
            --     self.states.BGOrb = "orange"
            -- end
        end
    end

    -- update crowdControls
    indicators.crowdControls:UpdateSize(ccFound - 1)

    -- update raid debuffs
    if raidDebuffsFound then
        startIndex = 1
        --! WotLK perf: indicators.raidDebuffs читался в этом блоке одиннадцать раз.
        local raidDebuffs = indicators.raidDebuffs
        raidDebuffs:Show()

        -- sort indices
        -- NOTE: self._debuffs_raid_orders = { [index] = debuffOrder } used for sorting
        raidDebuffSortOrders = debuffsRaidOrders
        table.sort(debuffsRaid, SortRaidDebuffsByOrder)
        raidDebuffSortOrders = nil

        -- show
        local topGlowType, topGlowOptions
        for i = 1, indicatorNums["raidDebuffs"] do
            local index = debuffsRaid[i]
            if index then
                --! WotLK perf: native UnitDebuff signature (see main scan loop)
                --! WotLK perf: было UnitDebuff(unit, self._debuffs_raid[i]) - тот же
                --! элемент читался повторно, хотя уже лежит в index.
                local name, _, icon, count, debuffType, duration, expirationTime, source, isStealable, _, spellId = UnitDebuff(unit, index)
                if name then
                    local ind = raidDebuffs[i]
                    ind:SetCooldown(
                        expirationTime - duration,
                        duration,
                        debuffType or "",
                        icon,
                        count,
                        debuffsRaidRefreshing[index],
                        I.IsDebuffUseElapsedTime(name, spellId)
                    )
                    ind.index = index -- NOTE: for tooltip
                    startIndex = startIndex + 1
                    -- store debuffs indices shown by raidDebuffs indicator
                    -- self._debuffs_raid_shown[index] = true
                    -- remove from debuffs
                    debuffsBig[index] = nil
                    debuffsNormal[index] = nil

                    if i == 1 then -- top
                        topGlowType, topGlowOptions = I.GetDebuffGlow(name, spellId, count)
                    end
                end
            end
        end

        -- update raidDebuffs
        raidDebuffs:UpdateSize(startIndex - 1)
        for i = startIndex, 3 do
            raidDebuffs[i].index = nil
        end

        -- update glow
        if not raidDebuffsFirstOnly then
            if topGlowType and topGlowType ~= "None" then
                -- to make sure top glow has highest priority
                debuffsGlowCurrent[topGlowType] = topGlowOptions
            end
            for t, o in pairs(debuffsGlowCurrent) do
                raidDebuffs:ShowGlow(t, o, true)
            end
            for t, _ in pairs(debuffsGlowCache) do
                if not debuffsGlowCurrent[t] then
                    raidDebuffs:HideGlow(t)
                    debuffsGlowCache[t] = nil
                end
            end
            wipe(debuffsGlowCurrent)
        else
            raidDebuffs:ShowGlow(topGlowType, topGlowOptions)
        end
    else
        indicators.raidDebuffs:Hide()
    end

    -- update debuffs
    startIndex = 1
    if debuffsOn then
        --! WotLK perf: indicators.debuffs и indicatorNums["debuffs"] читались по
        --! четыре-пять раз на КАЖДЫЙ показанный дебафф в двух циклах ниже.
        local debuffsInd = indicators.debuffs
        local debuffsNum = indicatorNums["debuffs"]
        -- bigDebuffs first
        for debuffIndex, refreshing in pairs(debuffsBig) do
            --! WotLK perf: native UnitDebuff signature (see main scan loop)
            local name, _, icon, count, debuffType, duration, expirationTime, _, _, _, spellId = UnitDebuff(unit, debuffIndex)
            if name and startIndex <= debuffsNum then
                local ind = debuffsInd[startIndex]
                -- start, duration, debuffType, texture, count, refreshing
                ind:SetCooldown(expirationTime - duration, duration, debuffType or "", icon, count, refreshing, true)
                ind.index = debuffIndex -- NOTE: for tooltip
                ind.spellId = spellId -- NOTE: for blacklist
                startIndex = startIndex + 1
            end
        end
        -- then normal debuffs
        for debuffIndex, refreshing in pairs(debuffsNormal) do
            --! WotLK perf: native UnitDebuff signature (see main scan loop)
            local name, _, icon, count, debuffType, duration, expirationTime, _, _, _, spellId = UnitDebuff(unit, debuffIndex)
            if name and startIndex <= debuffsNum then
                local ind = debuffsInd[startIndex]
                -- start, duration, debuffType, texture, count, refreshing
                ind:SetCooldown(expirationTime - duration, duration, debuffType or "", icon, count, refreshing)
                ind.index = debuffIndex -- NOTE: for tooltip
                ind.spellId = spellId -- NOTE: for blacklist
                startIndex = startIndex + 1
            end
        end
    end

    -- update debuffs
    --! WotLK perf: indicators.debuffs читался в этом хвосте одиннадцать раз (десять
    --! итераций очистки плюс UpdateSize).
    local debuffsIndicator = indicators.debuffs
    debuffsIndicator:UpdateSize(startIndex - 1)
    for i = startIndex, 10 do
        local ind = debuffsIndicator[i]
        ind.index = nil
        ind.spellId = nil
    end

    -- update dispels
    if F.UnitInGroup(unit) or UnitIsFriend("player", unit) then
        indicators.dispels:SetDispels(debuffsDispel)
    end

    -- user created indicators
    I.ShowCustomIndicators(self, "debuff")

    -- hide ws
    if pwsOn then
        if not wsFound then
            indicators.powerWordShield:SetWeakenedSoulCooldown()
        end
    end

    -- update debuffs_cache
    --! WotLK perf: GetTime() is constant for the whole frame, so calling it once per
    --! cached aura was one C call per entry per UNIT_AURA per unit for no new answer.
    local now = GetTime()
    for auraInstanceID, expirationTime in pairs(debuffsCache) do
        -- lost or expired
        if not debuffsCurrent[auraInstanceID] or (expirationTime ~= 0 and now >= expirationTime) then -- expirationTime == 0: no duration
            debuffsCache[auraInstanceID] = nil
            debuffsCountCache[auraInstanceID] = nil
        end
    end

    wipe(debuffsCurrent)
    wipe(debuffsNormal)
    wipe(debuffsBig)
    wipe(debuffsDispel)
    wipe(debuffsRaid)
    wipe(debuffsRaidRefreshing)
    wipe(debuffsRaidOrders)
    -- wipe(self._debuffs_raid_shown)
end

-------------------------------------------------
-- buffs
-------------------------------------------------
local function UnitButton_UpdateBuffs(self)
    local states = self.states
    local unit = states.displayedUnit

    states.BGFlag = nil

    -- user created indicators
    I.ResetCustomIndicators(self, "buff")

    local refreshing = false
    local defensiveFound, externalFound, allFound, drinkingFound, pwsFound = 1, 1, 1, false, false

    --! WotLK perf: то же, что в UnitButton_UpdateDebuffs - всё неизменное поднято
    --! перед циклом на сорок итераций. Обоснование неизменности там же: таблицы
    --! Cell.vars.* переписываются только колбэками настроек, enabledIndicators и
    --! indicatorNums - только из UpdateIndicators, self._buffs_* создаются один раз
    --! в InitAuraTables и дальше только wipe'аются.
    local vars = Cell.vars
    local iconAnimation = vars.iconAnimation

    local indicators = self.indicators
    local buffsCache = self._buffs_cache
    local buffsCountCache = self._buffs_count_cache
    local buffsCurrent = self._buffs_current

    local defensiveOn = enabledIndicators["defensiveCooldowns"]
    local externalOn = enabledIndicators["externalCooldowns"]
    local allOn = enabledIndicators["allCooldowns"]
    local statusTextOn = enabledIndicators["statusText"]
    local pwsOn = enabledIndicators["powerWordShield"]
    local pwsMineOnly = indicatorBooleans["powerWordShield"]
    local defensiveNum = indicatorNums["defensiveCooldowns"]
    local externalNum = indicatorNums["externalCooldowns"]
    local allNum = indicatorNums["allCooldowns"]

    for i = 1, 40 do
        --! WotLK perf: direct native UnitBuff (3.3.5 signature: name, rank,
        --! icon, count, debuffType, duration, expirationTime, caster,
        --! isStealable, shouldConsolidate, spellId) instead of the
        --! Cell.UnitBuff translation wrapper.
        --! WotLK fix: a 12th value was taken here and handed to
        --! I.UpdateCustomIndicators. It was retail's UnitAura return #16 (the
        --! aura's first effect value); 3.3.5 stops at spellId (кодекс: 11
        --! returns), so it was always nil, and Custom_Classic.lua declares only
        --! the 11 parameters up to castByMe with no vararg - the callee could
        --! not read it even on retail. Dropped: one dead register plus one dead
        --! stack push per buff per unit per aura update.
        local name, _, icon, count, debuffType, duration, expirationTime, source, _, _, spellId = UnitBuff(unit, i)
        if not name then
            break
        end

        local auraInstanceID = GetAuraInstanceID(source, spellId) --! WotLK fix/perf: was '(source or "")..spellId' - collision-prone + string churn

        if duration then
            --! WotLK perf: start считался до четырёх раз за итерацию; кэши читались
            --! по два-три раза.
            local start = expirationTime - duration
            local cachedExpiration = buffsCache[auraInstanceID]
            local cachedCount = buffsCountCache[auraInstanceID]

            if iconAnimation == "duration" then
                local timeIncreased = cachedExpiration and (expirationTime - cachedExpiration >= 0.5) or false
                local countIncreased = cachedCount and (count > cachedCount) or false
                refreshing = timeIncreased or countIncreased
            elseif iconAnimation == "stack" then
                refreshing = cachedCount and (count > cachedCount) or false
            else
                refreshing = false
            end

            --! WotLK perf: the three cooldown indicators used to ask the same two
            --! questions up to four times per buff per unit - allCooldowns repeated
            --! both lookups that defensiveCooldowns and externalCooldowns had just
            --! made. Ask once. The order below reproduces the original call pattern
            --! exactly when only allCooldowns is on (external first, defensive only
            --! if external missed), so no configuration pays more than it used to.
            local isDefensive, isExternal
            if defensiveOn then
                isDefensive = I.IsDefensiveCooldown(name, spellId)
            end
            if externalOn or allOn then
                isExternal = I.IsExternalCooldown(name, spellId, source, unit)
            end
            if allOn and not isExternal and not defensiveOn then
                isDefensive = I.IsDefensiveCooldown(name, spellId)
            end

            -- defensiveCooldowns
            if defensiveOn and isDefensive and defensiveFound <= defensiveNum then
                -- start, duration, debuffType, texture, count, refreshing
                indicators.defensiveCooldowns[defensiveFound]:SetCooldown(start, duration, nil, icon, count, refreshing)
                defensiveFound = defensiveFound + 1
            end

            -- externalCooldowns
            if externalOn and isExternal and externalFound <= externalNum then
                -- start, duration, debuffType, texture, count, refreshing
                indicators.externalCooldowns[externalFound]:SetCooldown(start, duration, nil, icon, count, refreshing)
                externalFound = externalFound + 1
            end

            -- allCooldowns
            if allOn and (isExternal or isDefensive) and allFound <= allNum then
                -- start, duration, debuffType, texture, count, refreshing
                indicators.allCooldowns[allFound]:SetCooldown(start, duration, nil, icon, count, refreshing)
                allFound = allFound + 1
            end

            -- drinking
            if statusTextOn and I.IsDrinking(name) then
                local statusText = indicators.statusText
                if not statusText:GetStatus() then
                    statusText:SetStatus("DRINKING")
                    statusText:Show()
                end
                drinkingFound = true
            end

            -- user created indicators
            I.UpdateCustomIndicators(self, "buff", spellId, name, start, duration, nil, icon, count, refreshing, source == "player" or source == "pet")

            -- check BG flags for statusIcon
            if spellId == 301091 then
                states.BGFlag = "alliance"
            end
            if spellId == 301089 then
                states.BGFlag = "horde"
            end

            --! WotLK perf: дешёвый гейт вперёд. Оба операнда без побочных эффектов,
            --! так что порядок эквивалентен, но табличный лукап и сравнение строки
            --! отсеивают чужие щиты до вызова функции, а не после.
            if pwsOn and (not pwsMineOnly or source == "player") and IsPowerWordShield(spellId, name) then
                pwsFound = true
                indicators.powerWordShield:SetShieldCooldown(start, duration)
            end

            buffsCurrent[auraInstanceID] = i
            buffsCache[auraInstanceID] = expirationTime
            buffsCountCache[auraInstanceID] = count
        end
    end

    -- update defensiveCooldowns
    indicators.defensiveCooldowns:UpdateSize(defensiveFound - 1)

    -- update externalCooldowns
    indicators.externalCooldowns:UpdateSize(externalFound - 1)

    -- update allCooldowns
    indicators.allCooldowns:UpdateSize(allFound - 1)

    -- hide drinking
    if not drinkingFound and indicators.statusText:GetStatus() == "DRINKING" then
        -- self.indicators.statusText:Hide()
        indicators.statusText:SetStatus()
    end

    -- hide pws
    if pwsOn then
        if not pwsFound then
            indicators.powerWordShield:SetShieldCooldown()
        end
    end

    -- update buffs_cache
    --! WotLK perf: one GetTime() for the sweep instead of one per cached aura (see
    --! the matching debuff sweep).
    local now = GetTime()
    for auraInstanceID, expirationTime in pairs(buffsCache) do
        -- lost or expired
        if not buffsCurrent[auraInstanceID] or (expirationTime ~= 0 and now >= expirationTime) then
            buffsCache[auraInstanceID] = nil
            buffsCountCache[auraInstanceID] = nil
        end
    end
    wipe(buffsCurrent)

    I.ShowCustomIndicators(self, "buff")
end

-------------------------------------------------
-- aura tables
-------------------------------------------------
local function InitAuraTables(self)
    -- for icon animation only
    self._buffs_current = {}
    self._buffs_cache = {}
    self._buffs_count_cache = {}
    self._debuffs_current = {}
    self._debuffs_cache = {}
    self._debuffs_count_cache = {}

    -- debuffs
    self._debuffs_normal = {} -- [auraInstanceID] = refreshing
    self._debuffs_big = {} -- [auraInstanceID] = refreshing
    self._debuffs_dispel = {} -- [debuffType] = true/false
    self._debuffs_raid = {} -- {index1, index2, ...}
    self._debuffs_raid_refreshing = {} -- [auraInstanceID] = refreshing
    self._debuffs_raid_orders = {} -- [auraInstanceID] = order
    -- self._debuffs_raid_shown = {} -- [auraInstanceID] = true, currently shown by raidDebuffs indicator
    self._debuffs_glow_current = {}
    self._debuffs_glow_cache = {}
end

local function ResetAuraTables(self)
    wipe(self._buffs_current)
    wipe(self._buffs_cache)
    wipe(self._buffs_count_cache)
    wipe(self._debuffs_current)
    wipe(self._debuffs_cache)
    wipe(self._debuffs_count_cache)

    -- debuffs
    wipe(self._debuffs_normal)
    wipe(self._debuffs_big)
    wipe(self._debuffs_dispel)
    wipe(self._debuffs_raid)
    wipe(self._debuffs_raid_refreshing)
    wipe(self._debuffs_raid_orders)
    -- wipe(self._debuffs_raid_shown)

    -- raid debuffs glow
    wipe(self._debuffs_glow_current)
    wipe(self._debuffs_glow_cache)
    if self.indicators.raidDebuffs then
        self.indicators.raidDebuffs:HideGlow()
    end
end

-------------------------------------------------
-- functions
-------------------------------------------------
-- 64413: Protection of Ancient Kings
-- 64411: Blessing of Ancient Kings
local absorbInfos = {}

local function UnitButton_UpdateHealthStates(self, diff)
    --! WotLK perf: `self.states` is resolved once. This function runs on every
    --! UNIT_HEALTH and UNIT_MAXHEALTH - broadcast to every button, since 3.3.5 has
    --! no RegisterUnitEvent - plus the 0.25s poll, and it used to re-resolve the
    --! same two-level path twenty times per call. The table itself is only ever
    --! created once, in CellUnitButton_OnLoad, so the reference cannot go stale
    --! across the status-text and status-icon calls below.
    local states = self.states
    local unit = states.displayedUnit
    local guid = states.guid

    local health = UnitHealth(unit) + (diff or 0)
    local healthMax = UnitHealthMax(unit)
    health = min(health, healthMax) --! diff

    states.health = health
    states.healthMax = healthMax
    if guid then
        local total = 0
        local absorbs = absorbInfos[guid] --! WotLK perf: one lookup, not two
        if absorbs then
             for spellName, amount in pairs(absorbs) do
                 total = total + amount
             end
        end
        states.totalAbsorbs = total
    else
        states.totalAbsorbs = 0
    end
    --! WotLK fix: the comment that used to stand here claimed heal absorbs "don't
    --! exist in WotLK (added in Cataclysm+)". That is false, and the client says so:
    --! Spell.dbc carries aura 301 (SCHOOL_HEAL_ABSORB) on exactly ten spells of two
    --! mechanics - Incinerate Flesh (66236/66237/67049/67050/67051, Trial of the
    --! Crusader) and Necrotic Strike (70659/71951/72490/72491/72492, Icecrown), the
    --! latter described as "negates the next $s2 healing received". The combat log
    --! can even be made to follow them: SPELL_HEAL and SPELL_PERIODIC_HEAL both carry
    --! an `absorbed` field on 3.3.5. So the zero below is a DECISION, not a fact about
    --! the client: the owner declined the feature on 2026-08-26 (see GAP-079), so
    --! absorbsBar, overAbsorbGlow, the healAbsorb colour option and the `effective`
    --! health text stay dormant by design. Do not re-derive this - measure once.
    --! WotLK perf: обе ветви писали в states.healAbsorbs один и тот же ноль -
    --! запись вынесена за if. Значение и порядок относительно остальных записей
    --! сохранены, между ветвями и этой строкой ничего не читает healAbsorbs.
    states.healAbsorbs = 0

    if healthMax == 0 then
        states.healthPercent = 0
    else
        states.healthPercent = health / healthMax
    end

    states.wasDead = states.isDead
    states.isDead = health == 0
    if states.wasDead ~= states.isDead then
        UnitButton_UpdateStatusText(self)
        I.UpdateStatusIcon_Resurrection(self)
        if not states.isDead then
            states.hasSoulstone = nil
            I.UpdateStatusIcon(self)
        end
    end

    states.wasDeadOrGhost = states.isDeadOrGhost
    states.isDeadOrGhost = UnitIsDeadOrGhost(unit)
    if states.wasDeadOrGhost ~= states.isDeadOrGhost then
        I.UpdateStatusIcon_Resurrection(self)
        UnitButton_UpdateHealthColor(self)
    end

    --! WotLK perf: indicators.healthText - три чтения двухуровневого пути в трёх
    --! ветвях; states.totalAbsorbs только что записан выше, берём локал.
    local healthText = self.indicators.healthText
    if enabledIndicators["healthText"] then -- and not self.states.isDeadOrGhost then
        healthText:SetValue(health, healthMax, states.totalAbsorbs, 0)
        healthText:Show()
    else
        healthText:Hide()
    end
end

local function UnitButton_UpdatePowerStates(self)
    local states = self.states --! WotLK perf: see UnitButton_UpdateHealthStates
    local unit = states.displayedUnit
    if not unit then return end

    states.power = UnitPower(unit)
    states.powerMax = UnitPowerMax(unit)
    if states.powerMax <= 0 then states.powerMax = 1 end
end

-------------------------------------------------
-- power filter funcs
-------------------------------------------------
local function GetRole(b)
    if b.states.role and b.states.role ~= "NONE" then
        return b.states.role
    end

    -- FIXME:
    return "DAMAGER"
end

ShouldShowPowerText = function(b)
    if not enabledIndicators["powerText"] then return end
    if not (b:IsVisible() or b.isPreview) then return end

    if not b.states.guid then
        return true
    end

    local class, role
    if b.states.inVehicle then
        class = "VEHICLE"
    elseif F.IsPlayer(b.states.guid) then
        class = b.states.class
        role = GetRole(b)
    elseif F.IsPet(b.states.guid) then
        class = "PET"
    elseif F.IsNPC(b.states.guid) then
        --! WotLK fix: UnitInPartyIsAI does not exist on 3.3.5 (retail follower
        --! dungeons API) - guard the global to avoid a nil call on NPC units.
        if UnitInPartyIsAI and UnitInPartyIsAI(b.states.unit) then
            class = b.states.class
            role = GetRole(b)
        else
            class = "NPC"
        end
    elseif F.IsVehicle(b.states.guid) then
        class = "VEHICLE"
    end

    if class then
        --! WotLK fix: guard the [class] lookup - a non-canonical token (e.g.
        --! "DEATH KNIGHT" from a server returning display names) yields nil
        --! and the nested [role] index would hard-error. Default to "show".
        local filter = indicatorCustoms["powerText"][class]
        if type(filter) == "boolean" then
            return filter
        elseif type(filter) == "table" then
            if role and type(filter[role]) == "boolean" then
                return filter[role]
            else
                return true -- show power if role not found
            end
        else
            return true -- unknown class: show power
        end
    end

    return true
end

ShouldShowPowerBar = function(b)
    if not (b:IsVisible() or b.isPreview) then return end
    if not b.powerSize or b.powerSize == 0 then return end

    --! WotLK fix: the backport added a solo bypass here ("no role while
    --! solo, always show power bar"), which made power filters do nothing
    --! outside of a group. Upstream Cell has no such bypass: class-level
    --! boolean filters (HUNTER/MAGE/WARLOCK/...) don't need a role at all,
    --! and role-based ones already fall back to "show" below when the role
    --! is unknown. Matches upstream UnitButton.lua ShouldShowPowerBar.
    if not b.states.guid then
        return true
    end

    local class, role
    if b.states.inVehicle then
        class = "VEHICLE"
    elseif F.IsPlayer(b.states.guid) then
        class = b.states.class
        role = GetRole(b)
    elseif F.IsPet(b.states.guid) then
        class = "PET"
    elseif F.IsNPC(b.states.guid) then
        class = "NPC"
    elseif F.IsVehicle(b.states.guid) then
        class = "VEHICLE"
    end

    if class then
        --! WotLK fix: guard the [class] lookup - a non-canonical token (e.g.
        --! "DEATH KNIGHT" from a server returning display names) yields nil,
        --! and the old code indexed powerFilters[class][role] inside type()
        --! which hard-errored ("attempt to index field '?' (a nil value)").
        local filter = Cell.vars.currentLayoutTable["powerFilters"][class]
        if type(filter) == "boolean" then
            return filter
        elseif type(filter) == "table" then
            if role and type(filter[role]) == "boolean" then
                return filter[role]
            else
                return true -- show power if role not found
            end
        else
            return true -- unknown class: show power
        end
    end

    return true
end

CheckPowerEventRegistration = function(b)
    --! WotLK perf: the power events now live on the central unitEventFrame, so this
    --! no longer registers anything - it flips the gate the dispatcher reads before
    --! it touches a power branch. Same decision, same return value, but instead of
    --! fourteen C calls per button per toggle it is one field, and a button with a
    --! hidden power bar stops paying for power events exactly as it did before.
    if b:IsVisible() and not b.isPreview and (b._shouldShowPowerText or b._shouldShowPowerBar) then
        b.__powerEvents = true
        return true
    else
        b.__powerEvents = nil
        return false
    end
end

local function ShowPowerBar(b)
    b.widgets.powerBar:Show()
    b.widgets.powerBarLoss:Show()
    --! WotLK fix: SetShown нет на 3.3.5, шим WidgetAPI удалён — нативная пара.
    if CELL_BORDER_SIZE ~= 0 then
        b.widgets.gapTexture:Show()
    else
        b.widgets.gapTexture:Hide()
    end

    P.ClearPoints(b.widgets.healthBar)
    P.ClearPoints(b.widgets.powerBar)
    if b.orientation == "horizontal" or b.orientation == "vertical_health" then
        P.Point(b.widgets.healthBar, "TOPLEFT", b, "TOPLEFT", CELL_BORDER_SIZE, -CELL_BORDER_SIZE)
        P.Point(b.widgets.healthBar, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -CELL_BORDER_SIZE, b.powerSize + CELL_BORDER_SIZE * 2)
        P.Point(b.widgets.powerBar, "TOPLEFT", b.widgets.healthBar, "BOTTOMLEFT", 0, -CELL_BORDER_SIZE)
        P.Point(b.widgets.powerBar, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -CELL_BORDER_SIZE, CELL_BORDER_SIZE)
    else
        P.Point(b.widgets.healthBar, "TOPLEFT", b, "TOPLEFT", CELL_BORDER_SIZE, -CELL_BORDER_SIZE)
        P.Point(b.widgets.healthBar, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -(b.powerSize + CELL_BORDER_SIZE * 2), CELL_BORDER_SIZE)
        P.Point(b.widgets.powerBar, "TOPLEFT", b.widgets.healthBar, "TOPRIGHT", CELL_BORDER_SIZE, 0)
        P.Point(b.widgets.powerBar, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -CELL_BORDER_SIZE, CELL_BORDER_SIZE)
    end

    if b:IsVisible() then
        -- update now
        CheckPowerEventRegistration(b)
        UnitButton_UpdatePowerStates(b)
        UnitButton_UpdatePowerType(b)
        UnitButton_UpdatePowerMax(b)
        UnitButton_UpdatePower(b)
    end
end

local function HidePowerBar(b)
    CheckPowerEventRegistration(b)
    b.widgets.powerBar:Hide()
    b.widgets.powerBarLoss:Hide()
    b.widgets.gapTexture:Hide()

    P.ClearPoints(b.widgets.healthBar)
    P.Point(b.widgets.healthBar, "TOPLEFT", b, "TOPLEFT", CELL_BORDER_SIZE, -CELL_BORDER_SIZE)
    P.Point(b.widgets.healthBar, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -CELL_BORDER_SIZE, CELL_BORDER_SIZE)
end

-------------------------------------------------
-- unit button functions
-------------------------------------------------
local function UnitButton_UpdateTarget(self)
    local unit = self.states.displayedUnit
    if not unit then return end

    if UnitIsUnit(unit, "target") then
        if highlightEnabled then self.widgets.targetHighlight:Show() end
    else
        self.widgets.targetHighlight:Hide()
    end
end

local function CheckVehicleRoot(self, petUnit)
    if not petUnit then return end

    local playerUnit = F.GetPlayerUnit(petUnit)

    local isRoot
    for i = 1, UnitVehicleSeatCount(playerUnit) do
        local controlType, occupantName, serverName, ejectable, canSwitchSeats = UnitVehicleSeatInfo(playerUnit, i)
        if UnitName(playerUnit) == occupantName then
            isRoot = controlType == "Root"
            break
        end
    end

    self.indicators.roleIcon:SetRole(isRoot and "VEHICLE" or "NONE")
end

UnitButton_UpdateRole = function(self)
    local unit = self.states.unit
    if not unit then return end

    -- UnitGroupRolesAssigned polyfill follows the RETAIL contract:
    -- returns a single string ("TANK"/"HEALER"/"DAMAGER"/"NONE")
    local role = UnitGroupRolesAssigned(unit)
    self.states.role = role

    local roleIcon = self.indicators.roleIcon
    if enabledIndicators["roleIcon"] then
        roleIcon:SetRole(role)

        --! check vehicle root
        --! WotLK fix: was `strfind(guid, "^Vehicle")` - a retail GUID
        --! pattern; 3.3.5 GUIDs are hex strings, so the check never
        --! matched and the VEHICLE role icon never showed on vehicle
        --! roots. F.IsVehicle parses both hex and retail formats.
        if self.states.guid and F.IsVehicle(self.states.guid) then
            CheckVehicleRoot(self, unit)
        end
    else
        roleIcon:Hide()
    end
end

--! WotLK fix: общее тело "роль юнита изменилась". Источников теперь два:
--! асинхронный LibGroupInfo (конец файла - инспект дошёл, сменился дуал-спек) и
--! новое PLAYER_ROLES_ASSIGNED из Core_Wrath.lua (роль выдал интерфейс
--! подземелий). Тело было только в LGI-колбэке, поэтому второй путь пришлось бы
--! копировать - вместо этого один локал на двоих. Невидимые кнопки не считаем:
--! OnShow сам ставит _updateRequired/_powerUpdateRequired.
local function UnitButton_RoleChanged(b)
    UnitButton_UpdateRole(b)

    if not (b:IsVisible() or b.isPreview) then
        -- recompute power filters on next OnShow (same flag the
        -- normal update path uses)
        b._powerUpdateRequired = 1
        return
    end

    b._shouldShowPowerText = ShouldShowPowerText(b)
    b._shouldShowPowerBar = ShouldShowPowerBar(b)
    CheckPowerEventRegistration(b)

    if b._shouldShowPowerText then
        UnitButton_UpdatePowerTextColor(b)
        UnitButton_UpdatePowerText(b)
    else
        b.indicators.powerText:Hide()
    end

    if b._shouldShowPowerBar then
        ShowPowerBar(b)
    else
        HidePowerBar(b)
    end
end

UnitButton_UpdateLeader = function(self, event)
    local unit = self.states.unit
    if not unit then return end

    local leaderIcon = self.indicators.leaderIcon

    if enabledIndicators["leaderIcon"] then
        if indicatorBooleans["leaderIcon"] and (InCombatLockdown() or event == "PLAYER_REGEN_DISABLED") then
            leaderIcon:Hide()
            return
        end

        local isLeader = Cell.UnitIsGroupLeader(unit)
        self.states.isLeader = isLeader
        local isAssistant = Cell.UnitIsGroupAssistant(unit) and IsInRaid()
        self.states.isAssistant = isAssistant

        leaderIcon:SetIcon(isLeader, isAssistant)
    else
        leaderIcon:Hide()
    end
end

local function UnitButton_UpdatePlayerRaidIcon(self)
    local unit = self.states.displayedUnit
    if not unit then return end

    local playerRaidIcon = self.indicators.playerRaidIcon

    --! WotLK perf: то же, что в UnitButton_UpdateTargetRaidIcon следом - C-вызов
    --! делался и при выключенном индикаторе, результат отбрасывался ветвью else.
    --! Здесь нет конкатенации, поэтому экономия меньше, но событие то же самое.
    if not enabledIndicators["playerRaidIcon"] then
        playerRaidIcon:Hide()
        return
    end

    local index = GetRaidTargetIndex(unit)

    if index then
        SetRaidTargetIconTexture(playerRaidIcon.tex, index)
        playerRaidIcon:Show()
    else
        playerRaidIcon:Hide()
    end
end

local function UnitButton_UpdateTargetRaidIcon(self)
    local unit = self.states.displayedUnit
    if not unit then return end

    local targetRaidIcon = self.indicators.targetRaidIcon

    --! WotLK perf: проверка индикатора поднята выше конкатенации и C-вызова.
    --! `unit.."target"` в Lua 5.1 - это не склейка буферов, а хеширование строки и
    --! поиск в глобальной таблице интернированных строк; следом шёл GetRaidTargetIndex.
    --! Обе операции делались и тогда, когда индикатор выключен, а весь результат
    --! отбрасывался ветвью else. Функция идёт на каждое UNIT_TARGET (любой в группе
    --! сменил цель) и на RAID_TARGET_UPDATE - на 3.3.5 нет RegisterUnitEvent, событие
    --! доходит до каждой зарегистрированной кнопки. Ветвь Hide() сохранена: при
    --! выключенном индикаторе поведение прежнее.
    if not enabledIndicators["targetRaidIcon"] then
        targetRaidIcon:Hide()
        return
    end

    local index = GetRaidTargetIndex(unit.."target")

    if index then
        SetRaidTargetIconTexture(targetRaidIcon.tex, index)
        targetRaidIcon:Show()
    else
        targetRaidIcon:Hide()
    end
end

local function UnitButton_UpdateReadyCheck(self)
    local unit = self.states.unit
    if not unit then return end

    local status = GetReadyCheckStatus(unit)
    self.states.readyCheckStatus = status

    if enabledIndicators["readyCheckIcon"] and status then
        -- self.widgets.readyCheckHighlight:SetVertexColor(unpack(READYCHECK_STATUS[status].c))
        -- self.widgets.readyCheckHighlight:Show()
        self.indicators.readyCheckIcon:SetStatus(status)
    else
        -- self.widgets.readyCheckHighlight:Hide()
        self.indicators.readyCheckIcon:Hide()
    end
end

local function UnitButton_FinishReadyCheck(self)
    if not enabledIndicators["readyCheckIcon"] then return end

    if self.states.readyCheckStatus == "waiting" then
        -- self.widgets.readyCheckHighlight:SetVertexColor(unpack(READYCHECK_STATUS.notready.c))
        self.indicators.readyCheckIcon:SetStatus("notready")
    end
    C_Timer.After(6, function()
        -- self.widgets.readyCheckHighlight:Hide()
        self.indicators.readyCheckIcon:Hide()
    end)
end

UnitButton_UpdatePowerText = function(self)
    if not self._shouldShowPowerText then return end

    --! WotLK perf: self.states индексировался четыре раза за проход, стало один.
    --! Функция идёт на каждое UNIT_POWER/UNIT_MANA каждой кнопки: на 3.3.5 нет
    --! RegisterUnitEvent, событие доходит до всех зарегистрированных фреймов.
    local states = self.states
    local power, powerMax = states.power, states.powerMax
    if powerMax and power and not states.isDeadOrGhost then
        self.indicators.powerText:SetValue(power, powerMax)
    else
        self.indicators.powerText:Hide()
    end
end

UnitButton_UpdatePowerTextColor = function(self)
    if not self._shouldShowPowerText then return end

    local unit = self.states.displayedUnit
    if not unit then return end

    --! WotLK perf: indicatorColors["powerText"] - два лукапа в цепочке ветвей плюс
    --! третий в else, стало один; self.indicators.powerText поднят заодно.
    local colors = indicatorColors["powerText"]
    local powerText = self.indicators.powerText
    if colors[1] == "power_color" then
        powerText:SetColor(F.GetPowerColor(unit))
    elseif colors[1] == "class_color" then
        powerText:SetColor(F.GetUnitClassColor(unit))
    else
        powerText:SetColor(unpack(colors[2]))
    end
end

UnitButton_UpdatePowerMax = function(self)
    --! WotLK perf: powerMax читался дважды (в guard'е и в теле). Проверка
    --! _shouldShowPowerBar оставлена первой отдельным if'ом: при скрытой полосе
    --! мощи это ноль индексаций таблиц, как и было со сцепкой через and.
    if not self._shouldShowPowerBar then return end
    local powerMax = self.states.powerMax
    if not powerMax then return end

    if barAnimationType == "Smooth" then
        self.widgets.powerBar:SetMinMaxSmoothedValue(0, powerMax)
    else
        self.widgets.powerBar:SetMinMaxValues(0, powerMax)
    end
end

UnitButton_UpdatePower = function(self)
    --! WotLK perf: states.power читался дважды - это самый частый из power-путей.
    --! Порядок проверок сохранён, см. UnitButton_UpdatePowerMax выше.
    if not self._shouldShowPowerBar then return end
    local power = self.states.power
    if not power then return end

    --! WotLK fix: same zero-value rect as on the health bar, see
    --! UnitButton_UpdateHealth. Here it is powerBarLoss that hangs off
    --! powerBar:GetStatusBarTexture(), so a warrior at 0 rage or a rogue at 0 energy
    --! kept the "missing power" part starting at the previous fill edge.
    if power == 0 and barAnimationType ~= "Smooth" then power = 0.0001 end

    self.widgets.powerBar:SetBarValue(power)
end

UnitButton_UpdatePowerType = function(self)
    if not self._shouldShowPowerBar then return end

    local unit = self.states.displayedUnit
    if not unit then return end

    local r, g, b, lossR, lossG, lossB
    local a = Cell.loaded and CellDB["appearance"]["lossAlpha"] or 1

    if not UnitIsConnected(unit) then
        r, g, b = 0.4, 0.4, 0.4
        lossR, lossG, lossB = 0.4, 0.4, 0.4
    else
        r, g, b, lossR, lossG, lossB, self.states.powerType = F.GetPowerBarColor(unit, self.states.class)
    end

    self.widgets.powerBar:SetStatusBarColor(r, g, b)
    self.widgets.powerBarLoss:SetVertexColor(lossR, lossG, lossB)
end

local function UnitButton_UpdateHealthMax(self, statesReady)
    local unit = self.states.displayedUnit
    if not unit then return end

    --! WotLK fix/perf: UNIT_MAXHEALTH/full-update callers immediately repaint
    --! health too. Let them reuse one authoritative UnitHealth/UnitHealthMax/
    --! absorb snapshot instead of rebuilding the same state twice in sequence.
    if not statesReady then
        UnitButton_UpdateHealthStates(self)
    end

    if barAnimationType == "Smooth" then
        self.widgets.healthBar:SetMinMaxSmoothedValue(0, self.states.healthMax)
    else
        self.widgets.healthBar:SetMinMaxValues(0, self.states.healthMax)
    end

end

local function UnitButton_UpdateHealth(self, diff, statesReady)
    --! WotLK perf: one resolve each for the states table and the health bar; both
    --! were walked three to seven times per call, and this runs on every UNIT_HEALTH
    --! for every button (no RegisterUnitEvent on 3.3.5) plus the 0.25s poll.
    local states = self.states
    local unit = states.displayedUnit
    if not unit then return end

    if not statesReady then
        UnitButton_UpdateHealthStates(self, diff)
    end
    local healthPercent = states.healthPercent
    local healthBar = self.widgets.healthBar

    --! WotLK fix: at exactly the bar's minimum 3.3.5 leaves the fill texture's rect
    --! where it was instead of collapsing it onto the left edge. The bar itself reads
    --! as empty, but every region anchored to :GetStatusBarTexture() keeps the stale
    --! position - healthBarLoss, incomingHeal, shieldBar, shieldBarR, absorbsBar,
    --! overAbsorbGlow, damageFlashTex - so a unit at 0 health drew its incoming-heal,
    --! shield and damage-flash segments starting in mid-bar. A hair above the minimum
    --! paints a zero-width rect at the left edge, which is what the other two 3.3.5
    --! code bases do for the same reason (reference/ElvUI-master oUF
    --! elements/health.lua:166; NoM0Re fork commit 2657a35d).
    --! "Smooth" is excluded on purpose: SmoothStatusBar.lua walks the value towards
    --! the target and only its closing frame is exactly zero, by which point the
    --! painted rect is already under 0.001% of the bar - invisible either way.
    local barValue = states.health
    if barValue == 0 and barAnimationType ~= "Smooth" then barValue = 0.0001 end

    if barAnimationType == "Flash" then
        healthBar:SetValue(barValue)
        local diff = healthPercent - (states.healthPercentOld or healthPercent)
        if diff >= 0 or states.healthMax == 0 then
            B.HideFlash(self)
        elseif diff <= -0.05 and diff >= -1 then --! player (just joined) UnitHealthMax(unit) may be 1 ====> diff == -maxHealth
            B.ShowFlash(self, abs(diff))
        end
    else
        healthBar:SetBarValue(barValue)
    end

    --! WotLK perf: Cell.vars читался дважды подряд (чтение глобала Cell плюс
    --! хеш-лукап .vars каждый раз), а indicators.healthThresholds - в обеих ветвях
    --! следующего if. Обе величины за время вызова не меняются: Cell.vars создаётся
    --! один раз (Core_Wrath.lua:25), таблица indicators - при создании кнопки.
    local vars = Cell.vars
    if vars.useThresholdColor or vars.useFullColor then
        UnitButton_UpdateHealthColor(self)
    end

    states.healthPercentOld = healthPercent

    local healthThresholds = self.indicators.healthThresholds
    if enabledIndicators["healthThresholds"] then
        healthThresholds:CheckThreshold(healthPercent)
    else
        healthThresholds:Hide()
    end

    if CELL_FADE_OUT_HEALTH_PERCENT then
        if states.inRange and healthPercent < CELL_FADE_OUT_HEALTH_PERCENT then
            A.FrameFadeIn(self, 0.25, self:GetAlpha(), 1)
        else
            A.FrameFadeOut(self, 0.25, self:GetAlpha(), CellDB["appearance"]["outOfRangeAlpha"])
        end
    end
end

--! WotLK fix: heal prediction is a Cell-private LibHealComm consumer. Stock
--! 3.3.5 has neither UnitGetIncomingHeals nor UNIT_HEAL_PREDICTION, and routing
--! through either the embedded or standalone !!!ClassicAPI made Cell inherit
--! foreign callback and filtering semantics. Direct casts/channels are counted
--! to completion; only HoT/bomb healing is limited to the next three seconds.
local HealComm = LibStub and LibStub:GetLibrary("LibHealComm-4.0", true)
local HEALCOMM_OVERTIME_AND_BOMBS = HealComm and bit.bor(HealComm.HOT_HEALS, HealComm.BOMB_HEALS)

local function UnitButton_UpdateHealPrediction(self, statesReady, useCached)
    --! WotLK perf: widgets.incomingHeal читался пять раз (четыре ранних выхода плюс
    --! запись), states - трижды. Функция вызывается из шести колбэков LibHealComm,
    --! то есть на каждом старте, обновлении, задержке и остановке лечения в рейде.
    local incomingHeal = self.widgets.incomingHeal

    if not predictionEnabled or not HealComm then
        incomingHeal:Hide()
        return
    end

    local states = self.states

    --! WotLK perf: the three LibHealComm queries below are Lua, not C - each one
    --! walks the library's pending-heal tables - and health repaints call this
    --! function far more often than the incoming amount can actually change: every
    --! UNIT_HEALTH, every UNIT_MAXHEALTH and the 0.25s change-detected poll ask for
    --! a value that only a LibHealComm callback can move. So those callers pass
    --! useCached and reuse the last amount, rescaled by the current healthMax; the
    --! six callbacks, UpdateAll and B.UpdateShields pass nothing and recompute.
    --! The cache is still time-bounded, and that is not belt-and-braces: the
    --! HoT/bomb query uses a sliding GetTime()+3 window, so the amount shrinks as
    --! time passes even when no callback fires. One button tick is the bound,
    --! because that is already the staleness of everything else on the frame.
    local value
    if useCached and states.incomingHeal and (GetTime() - (states.incomingHealAt or 0)) < 0.25 then
        value = states.incomingHeal
    else
        local unit = states.displayedUnit
        local guid = unit and UnitGUID(unit)
        if not guid then
            states.incomingHeal = nil
            incomingHeal:Hide()
            return
        end

        local now = GetTime()
        local casted = HealComm:GetHealAmount(guid, HealComm.CASTED_HEALS) or 0
        local overtime = HealComm:GetHealAmount(
            guid,
            HEALCOMM_OVERTIME_AND_BOMBS,
            now + 3
        ) or 0
        value = floor((casted + overtime) * (HealComm:GetHealModifier(guid) or 1))
        states.incomingHeal = value
        states.incomingHealAt = now
    end

    if value <= 0 then
        incomingHeal:Hide()
        return
    end

    if not statesReady then
        UnitButton_UpdateHealthStates(self)
    end

    local healthMax = states.healthMax
    if healthMax <= 0 then
        incomingHeal:Hide()
        return
    end

    incomingHeal:SetValue(value / healthMax, states.healthPercent)
end

--! WotLK fix: LibHealComm callback payloads already carry every affected target
--! GUID. Update normal and spotlight Cell buttons directly instead of synthesizing
--! a retail Frame event or walking all possible unit tokens on every callback.
if HealComm then
    local callbackOwner = {}

    local function HealComm_TargetsChanged(_, casterGUID, spellID, healType, endTime, ...)
        for i = 1, select("#", ...) do
            local guid = select(i, ...)
            F.HandleUnitButton("guid", guid, UnitButton_UpdateHealPrediction)
        end
    end

    local function HealComm_TargetChanged(_, guid)
        F.HandleUnitButton("guid", guid, UnitButton_UpdateHealPrediction)
    end

    HealComm.RegisterCallback(callbackOwner, "HealComm_HealStarted", HealComm_TargetsChanged)
    HealComm.RegisterCallback(callbackOwner, "HealComm_HealUpdated", HealComm_TargetsChanged)
    HealComm.RegisterCallback(callbackOwner, "HealComm_HealDelayed", HealComm_TargetsChanged)
    HealComm.RegisterCallback(callbackOwner, "HealComm_HealStopped", HealComm_TargetsChanged)
    HealComm.RegisterCallback(callbackOwner, "HealComm_ModifierChanged", HealComm_TargetChanged)
    HealComm.RegisterCallback(callbackOwner, "HealComm_GUIDDisappeared", HealComm_TargetChanged)
end

UnitButton_UpdateAuras = function(self)
    if not self._indicatorsReady then return end

    local unit = self.states.displayedUnit
    if not unit then return end

    UnitButton_UpdateDebuffs(self)
    UnitButton_UpdateBuffs(self)
    I.UpdateStatusIcon(self)
end

--! WotLK fix: у рейдовой рамки нет "своего" моба, а UnitThreatSituation(unit) без
--! второго аргумента возвращает МАКСИМУМ по всем NPC, на которых у юнита есть
--! угроза (это прямо написано в описании функции на 3.3.5). На любом бою с адами
--! каждый, кто держит хоть одного ада, получает status 3 - отсюда жалоба "мигает
--! просто весь рейд". Поэтому ищем конкретного моба: цель игрока, если она враждебна
--! и жива; иначе цель цели - хилер целится в рейд, значит targettarget это тот, по
--! кому рейд работает. Если моба нет вообще (город, никого не выбрано), возвращаем
--! nil, и UpdateThreat честно откатывается на старое глобальное правило.
--! Функция живёт в B (Cell.bFuncs), а не в локале файла: свободен ровно один слот
--! из 200 (см. заметку у объявлений), а решение нужно ещё и снаружи - /cell debug
--! threat печатает вердикт по тем же данным, что и рамки.
function B.GetThreatMobUnit()
    if UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target") then
        return "target"
    end
    if UnitExists("targettarget") and not UnitIsDead("targettarget") and UnitCanAttack("player", "targettarget") then
        return "targettarget"
    end
end

local function UnitButton_UpdateThreat(self)
    local unit = self.states.displayedUnit
    if not unit or not UnitExists(unit) then return end

    local blink = enabledIndicators["aggroBlink"]
    local border = enabledIndicators["aggroBorder"]
    if not blink and not border then
        --! WotLK perf: оба индикатора выключены - ни одного C-вызова угрозы.
        self.indicators.aggroBlink:Hide()
        self.indicators.aggroBorder:Hide()
        return
    end

    local mob = B.GetThreatMobUnit()
    local status, percent, isTanking

    if mob then
        -- isTanking, status, scaledPercentage, rawPercentage = UnitDetailedThreatSituation(unit, mobUnit)
        --! rawPercentage - процент от угрозы того, кто моба держит: 100 = вровень с ним.
        --! WotLK fix: isTanking is no longer discarded - the codex defines it as "1 if
        --! unit is mobUnit's primary target", i.e. the mob is swinging at this unit.
        local tanking, st, _, rawPercentage = UnitDetailedThreatSituation(unit, mob)
        isTanking, status, percent = tanking, st, rawPercentage or 0
        --! nil здесь означает "у этого юнита на этом мобе угрозы нет" - и это НЕ повод
        --! падать в глобальную ветку: именно она и подсвечивала весь рейд.
    else
        status = UnitThreatSituation(unit)
        --! В этой ветке процентов не существует, есть только категория. status >= 1 -
        --! это ровно "набрал 100% угрозы того, кто моба держит", поэтому нормализуем
        --! к 100 и дальше сравниваем одинаково. Порог в глобальной ветке не работает -
        --! показываем как раньше, чтобы без цели индикатор не потерять совсем.
        percent = (status and status >= 1) and 100 or 0
        --! WotLK fix: status 2 and 3 both mean "this unit IS the mob's primary target"
        --! (codex, UnitThreatSituation), so the top-of-slider rule below still works
        --! without a hostile target selected.
        isTanking = status and status >= 2
    end

    --! Порог и "не показывать танков" - свои у каждого из двух индикаторов;
    --! данные угрозы при этом добываются один раз на кнопку.
    local isTank = self.states.role == "TANK"

    --! WotLK fix: the top of the slider (130, see CreateSetting_ThreatThreshold in
    --! Widgets_IndicatorSettings.lua) means "the mob is already hitting this unit",
    --! not "130% of somebody else's threat". Such a percentage practically never
    --! exists: rawPercentage is measured against the threat of whoever holds the mob,
    --! and the moment the unit rips it the unit becomes that holder itself, so the
    --! ratio reads 100 again. The old comparison therefore made the highest setting
    --! fire never at all instead of firing exactly on a real pull.
    local blinkThreshold = indicatorNums["aggroBlink"] or 100
    local borderThreshold = indicatorNums["aggroBorder"] or 100
    local blinkOn, borderOn

    if blinkThreshold >= 130 then
        blinkOn = isTanking and true or false
    else
        blinkOn = percent > 0 and percent >= blinkThreshold
    end

    if borderThreshold >= 130 then
        borderOn = isTanking and true or false
    else
        borderOn = percent > 0 and percent >= borderThreshold
    end

    if blink and blinkOn
        and not (isTank and indicatorBooleans["aggroBlink"]) then
        self.indicators.aggroBlink:ShowAggro(GetThreatStatusColor(status or 0))
    else
        self.indicators.aggroBlink:Hide()
    end

    if border and borderOn
        and not (isTank and indicatorBooleans["aggroBorder"]) then
        self.indicators.aggroBorder:ShowAggro(GetThreatStatusColor(status or 0))
    else
        self.indicators.aggroBorder:Hide()
    end
end

local function UnitButton_UpdateThreatBar(self)
    if not enabledIndicators["aggroBar"] then
        self.indicators.aggroBar:Hide()
        return
    end

    local unit = self.states.displayedUnit
    if not unit or not UnitExists(unit) then return end

    --! WotLK fix: моба берём тем же правилом, что и мигание с рамкой (см.
    --! B.GetThreatMobUnit). Жёсткий "target" означал, что у хилера - который
    --! целится в рейд, а не в босса - полоска угрозы не показывала вообще ничего.
    local mob = B.GetThreatMobUnit()
    if not mob then
        self.indicators.aggroBar:Hide()
        return
    end

    -- isTanking, status, scaledPercentage, rawPercentage, threatValue = UnitDetailedThreatSituation(unit, mobUnit)
    local _, status, scaledPercentage, rawPercentage = UnitDetailedThreatSituation(unit, mob)
    if status then
        self.indicators.aggroBar:Show()
        self.indicators.aggroBar:SetSmoothedValue(scaledPercentage)
        self.indicators.aggroBar:SetStatusBarColor(GetThreatStatusColor(status))
    else
        self.indicators.aggroBar:Hide()
    end
end

--! WotLK fix: панель опций живёт выше этих функций и по правилам Lua 5.1 их локалы
--! не видит (upvalue связывается по месту компиляции). Публикуем в B, чтобы смена
--! порога или галки "не показывать танков" перерисовывала уже нарисованные рамки
--! сразу, а не ждала следующего threat-события.
B.UpdateThreat = UnitButton_UpdateThreat
B.UpdateThreatBar = UnitButton_UpdateThreatBar

--! WotLK perf: раньше UNIT_THREAT_LIST_UPDATE был зарегистрирован на КАЖДОЙ кнопке.
--! Но arg1 у этого события - NPC, чей список угрозы изменился, а не юнит рейда
--! (кодекс: "The unit whose threat list changed" + threatDelta), поэтому фильтр по
--! states.displayedUnit его никогда не пропускал, и событие уходило в ветку else -
--! то есть все 25-40 кнопок пересчитывали полоску угрозы на каждое событие любого
--! моба: UnitDetailedThreatSituation + SetSmoothedValue на кнопку. На боях с адами
--! это десятки полных проходов в секунду впустую.
--! Держим одну центральную рамку: событие слушается один раз, проход по кнопкам -
--! не чаще 5 раз в секунду. Первое событие после тишины обрабатывается сразу (мигание
--! аггро опаздывать не должно), дальше окно 0.2 с, и если внутри окна события
--! приходили - в конце делается один догоняющий проход.
--! Это же единственное место, откуда мигание обновляется по ПРОЦЕНТУ: событие
--! UNIT_THREAT_SITUATION_UPDATE приходит только на смену категории (0-3), а порог из
--! настроек меряется в процентах и меняется внутри категории.
--! Всё завёрнуто в do...end: локалы блока освобождают регистры на выходе и не съедают
--! последний свободный слот из 200 в главном чанке файла (см. заметку у объявлений).
do
    local ticker = CreateFrame("Frame")
    local nextAllowed, pending = 0, false

    local function UpdateButtonThreat(b)
        UnitButton_UpdateThreat(b)
        UnitButton_UpdateThreatBar(b)
    end

    local function Refresh()
        if not Cell.loaded then return end
        --! Все три индикатора выключены - ни одного C-вызова и ни одного прохода.
        if not (enabledIndicators["aggroBlink"] or enabledIndicators["aggroBorder"]
            or enabledIndicators["aggroBar"]) then return end
        F.IterateAllUnitButtons(UpdateButtonThreat, true)
    end

    ticker:Hide()
    ticker:SetScript("OnUpdate", function(self)
        if GetTime() < nextAllowed then return end
        self:Hide()
        pending = false
        nextAllowed = GetTime() + 0.2
        Refresh()
    end)

    function B.RequestThreatUpdate()
        local now = GetTime()
        if now >= nextAllowed then
            nextAllowed = now + 0.2
            Refresh()
        elseif not pending then
            --! События внутри окна не теряем: досиживаем окно на OnUpdate и делаем
            --! ровно один проход. OnEvent на скрытой рамке работает, OnUpdate - нет,
            --! поэтому Show/Hide это и есть выключатель таймера.
            pending = true
            ticker:Show()
        end
    end

    ticker:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    ticker:RegisterEvent("PLAYER_TARGET_CHANGED")
    ticker:RegisterEvent("UNIT_TARGET")
    --! Выход из боя: угрозы больше нет ни у кого, и один общий проход гарантированно
    --! гасит мигание и полоски. Без этого можно застрять с подсвеченной рамкой, если
    --! моб умер и threat-события на его смерть уже не пришли.
    ticker:RegisterEvent("PLAYER_REGEN_ENABLED")
    ticker:SetScript("OnEvent", function(_, event, unit)
        --! UNIT_TARGET важен только когда цель сменил тот, в кого целимся мы сами:
        --! его targettarget и становится мобом (см. B.GetThreatMobUnit). Остальные
        --! UNIT_TARGET рейда на выбор моба не влияют.
        if event == "UNIT_TARGET" and not UnitIsUnit(unit, "target") then return end
        B.RequestThreatUpdate()
    end)
end

local function UnitButton_UpdateCombatIcon(self)
    if not enabledIndicators["combatIcon"] then return end

    local unit = self.states.displayedUnit
    if not unit then return end

    if not (indicatorBooleans["combatIcon"] and InCombatLockdown()) and UnitAffectingCombat(unit) then
        self.indicators.combatIcon:Show()
    else
        self.indicators.combatIcon:Hide()
    end
end

local IsInRange = F.IsInRange
local function UnitButton_UpdateInRange(self)
    --! WotLK perf: one resolve of the states table, and the value just stored is
    --! compared directly instead of being read back out of it. This is called from
    --! the 0.25s tick on every button, so it is one of the few functions in the file
    --! that runs whether or not anything actually happened.
    local states = self.states
    local unit = states.displayedUnit
    if not unit then return end

    local inRange = IsInRange(unit)

    states.inRange = inRange
    if Cell.loaded then
        if inRange ~= states.wasInRange then
            if inRange then
                if CELL_FADE_OUT_HEALTH_PERCENT then
                    if not states.healthPercent or states.healthPercent < CELL_FADE_OUT_HEALTH_PERCENT then
                        A.FrameFadeIn(self, 0.25, self:GetAlpha(), 1)
                    else
                        A.FrameFadeOut(self, 0.25, self:GetAlpha(), CellDB["appearance"]["outOfRangeAlpha"])
                    end
                else
                    A.FrameFadeIn(self, 0.25, self:GetAlpha(), 1)
                end
            else
                A.FrameFadeOut(self, 0.25, self:GetAlpha(), CellDB["appearance"]["outOfRangeAlpha"])
            end
        end
        states.wasInRange = inRange
        -- self:SetAlpha(inRange and 1 or CellDB["appearance"]["outOfRangeAlpha"])
    end
end

-------------------------------------------------
-- central unit event dispatcher
-------------------------------------------------
--! WotLK perf: 3.3.5a has no RegisterUnitEvent - it arrived in 5.0 - so a frame
--! that registers UNIT_HEALTH receives UNIT_HEALTH for every unit in the game.
--! Cell registered about thirty unit events on EVERY shown button, so one health
--! tick on one raid member woke 25-40 button handlers, and all but one of them
--! existed only to fail the same token comparison and then walk the whole
--! broadcast-event chain below it. One frame receives those events instead and
--! looks the token up in an index, so an event costs a single hash lookup and
--! reaches only the button(s) that actually display that unit.
--!
--! Two tokens per button are indexed - states.unit and states.displayedUnit -
--! because a unit in a vehicle is drawn from its vehicle/pet alias while events
--! still arrive for the owner token; that is exactly the pair the old per-button
--! filter compared against, so the set of delivered events is unchanged. Several
--! buttons can show one unit (spotlight frames, party plus raid), hence a list.
--!
--! The failure modes are deliberately asymmetric. A stale entry only causes a
--! redundant update, because every handler reads states.displayedUnit itself; a
--! MISSING entry would silently stop a button updating. So UnitButton_OnTick
--! re-checks its own entry four times a second and repairs it, which turns a
--! forgotten index update into a quarter-second hiccup instead of a dead frame.
--!
--! The broadcast events stay on the buttons: PLAYER_TARGET_CHANGED, READY_CHECK*,
--! RAID_TARGET_UPDATE, PLAYER_REGEN_* and ZONE_CHANGED_NEW_AREA are rare and
--! every button has to react to each of them anyway, so routing them centrally
--! would only add an iteration over the set the client already walks.
--! Only three names reach the file scope from this section - the frame, the index
--! and the updater. Everything else lives in a do-block on purpose: the main chunk
--! of this file is a few slots short of Lua 5.1's hard limit of 200 active locals
--! per function, and a block's locals give their slots back at `end` while the
--! closures that captured them keep working.
local unitEventFrame = CreateFrame("Frame")
local unitEventButtons = {} -- [unitToken] = { button, ... }
local UpdateUnitEventIndex

do
    local function AddToUnitEventIndex(token, button)
        local list = unitEventButtons[token]
        if not list then
            list = {}
            unitEventButtons[token] = list
        end
        for i = 1, #list do
            if list[i] == button then return end
        end
        list[#list+1] = button
    end

    local function RemoveFromUnitEventIndex(token, button)
        local list = unitEventButtons[token]
        if not list then return end
        local n = #list
        for i = 1, n do
            if list[i] == button then
                for j = i, n - 1 do
                    list[j] = list[j+1]
                end
                list[n] = nil
                n = n - 1
                break
            end
        end
        if n == 0 then unitEventButtons[token] = nil end
    end

    --! Recomputes this button's place in the index from its own states, so it is safe
    --! to call from anywhere that touches states.unit / states.displayedUnit. It
    --! returns immediately when nothing moved, which is the common case by far.
    UpdateUnitEventIndex = function(self)
        local unit, displayed
        if self.__unitEventsOn then
            local states = self.states
            unit = states.unit
            displayed = states.displayedUnit
            if displayed == unit then displayed = nil end
        end

        local oldUnit, oldDisplayed = self.__indexedUnit, self.__indexedDisplayedUnit
        if oldUnit == unit and oldDisplayed == displayed then return end

        --! Past this line the button draws a different unit than it did before, so the
        --! incoming-heal cache (keyed by time only) has to die with the old token -
        --! otherwise a vehicle, or a button taking over another raid member, would
        --! show the previous unit's prediction for up to one tick.
        self.states.incomingHeal = nil

        if oldUnit and oldUnit ~= unit and oldUnit ~= displayed then
            RemoveFromUnitEventIndex(oldUnit, self)
        end
        if oldDisplayed and oldDisplayed ~= unit and oldDisplayed ~= displayed then
            RemoveFromUnitEventIndex(oldDisplayed, self)
        end
        if unit then AddToUnitEventIndex(unit, self) end
        if displayed then AddToUnitEventIndex(displayed, self) end

        self.__indexedUnit = unit
        self.__indexedDisplayedUnit = displayed
    end
end

local function UnitButton_UpdateVehicleStatus(self)
    local unit = self.states.unit
    if not unit then return end

    if UnitHasVehicleUI(unit) then -- or UnitInVehicle(unit) or UnitUsingVehicle(unit) then
        self.states.inVehicle = true
        if unit == "player" then
            self.states.displayedUnit = "vehicle"
        else
            -- local prefix, id, suffix = strmatch(unit, "([^%d]+)([%d]*)(.*)")
            local prefix, id = strmatch(unit, "([^%d]+)([%d]*)")
            self.states.displayedUnit = prefix .. "pet" .. (id or "")
        end
        self.indicators.nameText:UpdateVehicleName()
    else
        self.states.inVehicle = nil
        self.states.displayedUnit = self.states.unit
        self.indicators.nameText.vehicle:SetText("")
    end

    --! WotLK perf: displayedUnit just moved, so the central dispatcher's index has
    --! to move with it - otherwise the button would keep receiving events for the
    --! alias it no longer draws and miss the ones for the token it does.
    UpdateUnitEventIndex(self)
end

UnitButton_UpdateStatusText = function(self)
    local statusText = self.indicators.statusText
    if not enabledIndicators["statusText"] then
        -- statusText:Hide()
        statusText:SetStatus()
        return
    end

    local unit = self.states.unit
    if not unit then return end

    self.states.guid = UnitGUID(unit) -- update!
    if not self.states.guid then return end

    if not UnitIsConnected(unit) and UnitIsPlayer(unit) then
        statusText:Show()
        statusText:SetStatus("OFFLINE")
        statusText:ShowTimer()
    elseif UnitIsAFK(unit) then
        statusText:Show()
        statusText:SetStatus("AFK")
        statusText:ShowTimer()
    elseif UnitIsFeignDeath(unit) then
        statusText:Show()
        statusText:SetStatus("FEIGN")
        statusText:HideTimer(true)
    elseif UnitIsDeadOrGhost(unit) then
        statusText:Show()
        statusText:HideTimer(true)
        if UnitIsGhost(unit) then
            statusText:SetStatus("GHOST")
        else
            statusText:SetStatus("DEAD")
        end
    elseif statusText:GetStatus() == "DRINKING" then
        -- update colors
        statusText:Show()
        statusText:SetStatus("DRINKING")
    else
        -- statusText:Hide()
        statusText:HideTimer(true)
        statusText:SetStatus()
    end
end

local function UnitButton_UpdateName(self)
    local unit = self.states.unit
    if not unit then return end

    self.states.name = UnitName(unit)
    self.states.fullName = F.UnitFullName(unit)
    self.states.class = UnitClassBase(unit)
    self.states.guid = UnitGUID(unit)
    self.states.isPlayer = UnitIsPlayer(unit)

    self.indicators.nameText:UpdateName()
end

UnitButton_UpdateNameTextColor = function(self)
    local unit = self.states.unit
    if not unit then return end

    if enabledIndicators["nameText"] then
        if indicatorColors["nameText"][1] == "class_color" or not UnitIsConnected(unit) or (UnitIsPlayer(unit) and UnitIsCharmed(unit)) or self.states.inVehicle then
            self.indicators.nameText:SetColor(F.GetUnitClassColor(unit))
        else
            self.indicators.nameText:SetColor(unpack(indicatorColors["nameText"][2]))
        end
    end
end

UnitButton_UpdateHealthTextColor = function(self)
    local unit = self.states.unit
    if not unit then return end

    if enabledIndicators["healthText"] then
        self.indicators.healthText:SetColor(F.GetUnitClassColor(unit))
    end
end

UnitButton_UpdateHealthColor = function(self)
    local unit = self.states.unit
    if not unit then return end

    self.states.class = UnitClassBase(unit) --! update class

    local barR, barG, barB
    local lossR, lossG, lossB
    local barA, lossA = 1, 1

    if Cell.loaded then
        barA =  CellDB["appearance"]["barAlpha"]
        lossA =  CellDB["appearance"]["lossAlpha"]
    end

    if UnitIsPlayer(unit) then -- player
        if not UnitIsConnected(unit) then
            barR, barG, barB = 0.4, 0.4, 0.4
            lossR, lossG, lossB = 0.4, 0.4, 0.4
        elseif UnitIsCharmed(unit) then
            barR, barG, barB, barA = 0.5, 0, 1, 1
            lossR, lossG, lossB, lossA = barR*0.2, barG*0.2, barB*0.2, 1
        elseif self.states.inVehicle then
            barR, barG, barB, lossR, lossG, lossB = F.GetHealthBarColor(self.states.healthPercent, self.states.isDeadOrGhost or self.states.isDead, 0, 1, 0.2)
        else
            barR, barG, barB, lossR, lossG, lossB = F.GetHealthBarColor(self.states.healthPercent, self.states.isDeadOrGhost or self.states.isDead, F.GetClassColor(self.states.class))
        end
    elseif F.IsPet(self.states.guid) then -- pet
        barR, barG, barB, lossR, lossG, lossB = F.GetHealthBarColor(self.states.healthPercent, self.states.isDeadOrGhost or self.states.isDead, 0.5, 0.5, 1)
    else -- npc
        barR, barG, barB, lossR, lossG, lossB = F.GetHealthBarColor(self.states.healthPercent, self.states.isDeadOrGhost or self.states.isDead, 0, 1, 0.2)
    end

    self.widgets.healthBar:SetStatusBarColor(barR, barG, barB, barA)
    self.widgets.healthBarLoss:SetVertexColor(lossR, lossG, lossB, lossA)

    if Cell.loaded and CellDB["appearance"]["healPrediction"][2] then
        self.widgets.incomingHeal:SetVertexColor(CellDB["appearance"]["healPrediction"][3][1], CellDB["appearance"]["healPrediction"][3][2], CellDB["appearance"]["healPrediction"][3][3], CellDB["appearance"]["healPrediction"][3][4])
    else
        self.widgets.incomingHeal:SetVertexColor(barR, barG, barB, 0.4)
    end

    if absorbInvertColor and self.widgets.absorbsBar then
        local r, g, b, a = self.widgets.healthBar:GetStatusBarColor()
        self.widgets.absorbsBar:SetVertexColor(F.InvertColor(r, g, b, a))
        self.widgets.overAbsorbGlow:SetVertexColor(F.InvertColor(r, g, b, a))
    end
end

-------------------------------------------------
-- shields
-------------------------------------------------
UnitButton_UpdateShieldAbsorbs = function(self, statesReady)
    --! WotLK perf: self.states / self.indicators / self.widgets поднимаются один раз.
    --! Функция зовётся из _UpdateShield на каждом CLEU-событии щита (SPELL_AURA_*,
    --! SPELL_ABSORBED и диффы здоровья), то есть в рейде десятки раз в секунду, а
    --! self.states читался здесь девять раз, self.widgets - пять, self.indicators - пять.
    --! Каждое чтение - индексация таблицы; поля кнопки за время вызова не меняются.
    local states = self.states
    local unit = states.displayedUnit
    if not unit then return end

    if not statesReady then
        UnitButton_UpdateHealthStates(self)
    end

    local indicators = self.indicators
    local widgets = self.widgets

    local totalAbsorbs = states.totalAbsorbs
    if totalAbsorbs > 0 then
        local healthMax = states.healthMax
        local shieldPercent = totalAbsorbs / healthMax

        if enabledIndicators["shieldBar"] then
            if indicatorBooleans["shieldBar"] then
                -- onlyShowOvershields
                local overshieldPercent = (totalAbsorbs + states.health - healthMax) / healthMax
                if overshieldPercent > 0 then
                    indicators.shieldBar:Show()
                    indicators.shieldBar:SetValue(overshieldPercent)
                else
                    indicators.shieldBar:Hide()
                end
            else
                indicators.shieldBar:Show()
                indicators.shieldBar:SetValue(shieldPercent)
            end
        else
            indicators.shieldBar:Hide()
        end

        widgets.shieldBar:SetValue(shieldPercent, states.healthPercent)
        UnitButton_UpdateHealAbsorbs(self, true)
    else
        indicators.shieldBar:Hide()
        widgets.shieldBar:Hide()
        widgets.overShieldGlow:Hide()
        widgets.shieldBarR:Hide()
        widgets.overShieldGlowR:Hide()
        UnitButton_UpdateHealAbsorbs(self, true)
    end
end

UnitButton_UpdateHealAbsorbs = function(self, skipStateUpdates)
    --! WotLK perf: тот же приём, что выше. Функция вызывается из обеих ветвей
    --! UnitButton_UpdateShieldAbsorbs, то есть ровно так же часто.
    local widgets = self.widgets

    if not absorbEnabled then
        if widgets.absorbsBar then
            widgets.absorbsBar:Hide()
            widgets.overAbsorbGlow:Hide()
        end
        return
    end

    local states = self.states
    local unit = states.displayedUnit
    if not unit then return end

    if not skipStateUpdates then
        UnitButton_UpdateHealthStates(self)
    end

    local healAbsorbs = states.healAbsorbs
    if healAbsorbs > 0 then
        local absorbsPercent = healAbsorbs / states.healthMax
        widgets.absorbsBar:SetValue(absorbsPercent, states.healthPercent)
    else
        widgets.absorbsBar:Hide()
        widgets.overAbsorbGlow:Hide()
    end
end

local function UnitButton_UpdatePowerWordShield(self, current, max, resetMax)
    if not enabledIndicators["powerWordShield"] then return end

    self.indicators.powerWordShield:UpdateShield(current, max, resetMax)
end

local function _UpdateShield(b, current, max, resetMax)
    UnitButton_UpdateShieldAbsorbs(b)
    UnitButton_UpdatePowerWordShield(b, current, max, resetMax)
end

-- Localized Spell Names (Priest)
--! WotLK fix: hoisted these three up from below. In Lua 5.1 a local is only in
--! scope AFTER its declaration, so PWS_NAME read inside UpdateShield - which sat
--! above the old declaration site - compiled as a nil global: absorbInfos[guid][nil]
--! is nil, so pws was always 0 and the Power Word: Shield indicator never moved.
--! (An earlier literal duplicate of two of them was removed here as well.)
local PWS_NAME = GetSpellInfo(17) or "Power Word: Shield"
local DA_NAME = GetSpellInfo(47753) or "Divine Aegis"
local PAK_NAME = GetSpellInfo(64413) or "Protection of Ancient Kings"

local function UpdateShield(guid, max, resetMax)
    --! WotLK perf: absorbInfos[guid] спрашивался дважды подряд. Это самая
    --! вызываемая функция пути абсорбов: её зовёт ConsumeAbsorb на каждое
    --! событие урона по цели со щитом (в рейде - сотни в секунду), плюс все
    --! ветви применения и снятия щита в обработчике CLEU.
    local t = absorbInfos[guid]
    local pws = t and t[PWS_NAME] or 0
    F.HandleUnitButton("guid", guid, _UpdateShield, pws, max, resetMax)
end

local cleu = CreateFrame("Frame")
cleu:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local UnitLevel = UnitLevel
-- local totalAbsorbed = 0
local lastHealAmount, lastHealGUID
local lastGlyphHeal = {}
local blessing
local lastHealTimeStamp = {}

-- Localized Spell Names
-- Shaman
local STONECLAW_NAME = GetSpellInfo(55277) or "Stoneclaw Totem"
-- Mage
local ICE_BARRIER_NAME = GetSpellInfo(11426) or "Ice Barrier"
local MANA_SHIELD_NAME = GetSpellInfo(1463) or "Mana Shield"
-- Paladin
local SACRED_SHIELD_NAME = GetSpellInfo(58597) or "Sacred Shield"
-- Warlock
local SACRIFICE_NAME = GetSpellInfo(7812) or "Sacrifice"

local ABSORB_SPELLS = {
    [PWS_NAME] = true,
    [DA_NAME] = true,
    [PAK_NAME] = true,
    [STONECLAW_NAME] = true,
    [ICE_BARRIER_NAME] = true,
    [SACRED_SHIELD_NAME] = true,
    [MANA_SHIELD_NAME] = true,
    [SACRIFICE_NAME] = true,
}

--! WotLK fix: pairs() order is undefined in Lua, so one and the same hit could eat
--! Divine Aegis on one client and Power Word: Shield on another. That is visible to
--! the player: the powerWordShield indicator reads absorbInfos[guid][PWS_NAME] by
--! name (UpdateShield above), not the sum of the subtable, so the shield bar jumped
--! around depending on hash order. Deduct in a fixed order DA -> PW:S -> the rest,
--! the way the WotLK reference implementation that used to be embedded in Cell did
--! it (AbsorbsMonitor-1.0.lua:1681, activeEffectsByPriority - folder deleted
--! 2026-08-09 as never loaded; see git history for the original).
--! This one function replaces five byte-identical copies of the same loop below
--! (SWING_DAMAGE, SPELL_DAMAGE & friends, SWING_MISSED, SPELL_MISSED, ENVIRONMENTAL).
--! min is aliased once at the top of the file (see the note there).
local absorbConsumeOrder = {DA_NAME, PWS_NAME, PAK_NAME}

local function ConsumeAbsorb(guid, absorbed)
    local t = absorbInfos[guid]
    if not t or type(absorbed) ~= "number" or absorbed <= 0 then return end

    for i = 1, #absorbConsumeOrder do
        local spellName = absorbConsumeOrder[i]
        local amount = t[spellName]
        if amount then
            local deduct = min(amount, absorbed)
            amount = amount - deduct
            t[spellName] = amount > 0 and amount or nil
            absorbed = absorbed - deduct
            if absorbed <= 0 then break end
        end
    end

    if absorbed > 0 then
        for spellName, amount in pairs(t) do
            local deduct = min(amount, absorbed)
            amount = amount - deduct
            t[spellName] = amount > 0 and amount or nil
            absorbed = absorbed - deduct
            if absorbed <= 0 then break end
        end
    end

    --! WotLK fix: drop the subtable once it is empty. Otherwise absorbInfos holds an
    --! empty table for every GUID that was ever shielded during the session - the only
    --! cleanup sites are tied to Cell's own buttons (UnitButton_OnAttributeChanged and
    --! UnitButton_OnHide), so a player Cell never shows is never collected.
    if next(t) == nil then absorbInfos[guid] = nil end

    UpdateShield(guid)
end

-------------------------------------------------
-- WotLK Absorb Scanner
-------------------------------------------------
local scanner = CreateFrame("GameTooltip", "CellAbsorbScanner", nil, "GameTooltipTemplate")
scanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local function GetShieldAmount(unit, spellName)
    local index = 1
    while true do
        local name = UnitBuff(unit, index)
        if not name then break end
        if name == spellName then
            scanner:ClearLines()
            scanner:SetUnitBuff(unit, index)
            local text = CellAbsorbScannerTextLeft2:GetText() 
            if text then
                local value = tonumber(string.match(text, "(%d+)"))
                return value
            end
        end
        index = index + 1
    end
    return 0
end

--! WotLK fix/perf: the absorb scan used to be declared as a closure (plus a nested
--! retry closure) INSIDE the CLEU handler below - a fresh allocation on every shield
--! SPELL_AURA_APPLIED/REFRESH (dozens per second with a disc priest in a raid).
--! File-scope functions with parameters instead: the immediate-success path (the
--! common case) allocates nothing; a single retry closure is only built when the
--! first tooltip scan races the aura update and fails. Retry schedule is unchanged:
--! attempts at +0s, +0.1s, +0.3s.
local function TryAbsorbScan(unit, spellName, destGUID)
    local amount = GetShieldAmount(unit, spellName)
    if amount and amount > 0 then
        if not absorbInfos[destGUID] then absorbInfos[destGUID] = {} end
        absorbInfos[destGUID][spellName] = amount
        UpdateShield(destGUID, amount)
        return true
    end
    return false
end

local function AbsorbScanWithRetry(unit, spellName, destGUID)
    if TryAbsorbScan(unit, spellName, destGUID) then return end
    local tries = 0
    local function retry()
        tries = tries + 1
        if not TryAbsorbScan(unit, spellName, destGUID) and tries < 2 then
            C_Timer.After(0.2, retry)
        end
    end
    C_Timer.After(0.1, retry)
end

--! WotLK fix: отложенная проверка Divine Aegis - см. ветку SPELL_AURA_REMOVED ниже.
--! Одна общая очередь и один таймер в полёте, а не C_Timer.After на каждое событие:
--! DA переприменяется на каждом крите лечения, у дисциплин-жреца в 25-ке это несколько
--! событий в секунду, и замыкание на каждое из них - тот самый GC-мусор, от которого
--! в этом файле уже избавились выше. Пока таймер не сработал, новые GUID просто
--! копятся в pendingDA.
local pendingDA = {}
local daCheckScheduled

local function CheckPendingDA()
    daCheckScheduled = nil
    for guid in pairs(pendingDA) do
        local unit = Cell.vars.guids[guid]
        --! Юнита нет в группе - записи о нём всё равно быть не должно, чистим.
        --! Есть и бафф на месте - значит это было переприменение, а не снятие.
        if not (unit and UnitBuff(unit, DA_NAME)) then
            local t = absorbInfos[guid]
            if t then
                t[DA_NAME] = nil
                if next(t) == nil then absorbInfos[guid] = nil end
                UpdateShield(guid)
            end
        end
    end
    wipe(pendingDA)
end

local function ScheduleDACheck()
    if daCheckScheduled then return end
    daCheckScheduled = true
    C_Timer.After(0.1, CheckPendingDA)
end

--! WotLK fix/perf: the old GetCLEU wrapper called the ClassicAPI
--! CombatLogGetCurrentEventInfo shim with NO arguments - but that shim is a
--! pure argument TRANSLATOR (native varargs in, retail order out) and returns
--! nothing when fed nothing. The retail branch could never be taken, yet it
--! allocated a throwaway table on EVERY combat-log event (hundreds/sec in a
--! raid = pure GC churn). Parse the native 3.3.5 payload directly instead:
--! timestamp(1), subEvent(2), srcGUID(3), srcName(4), srcFlags(5), dstGUID(6),
--! dstName(7), dstFlags(8), then the per-event payload from slot 9 (no
--! hideCaster / raid-flag slots on 3.3.5).
--! WotLK perf: the set of sub-events this handler actually acts on. In a 25-man
--! raid COMBAT_LOG_EVENT_UNFILTERED is the most frequent event in the game -
--! hundreds a second - and the majority of what arrives (SPELL_CAST_SUCCESS,
--! SPELL_ENERGIZE, SPELL_AURA_APPLIED_DOSE, UNIT_DIED, SPELL_SUMMON ...) is not
--! handled below at all, yet it used to walk all twenty-five string comparisons of
--! the chain before falling out of the bottom. One hash lookup answers that now.
--! Keep this list in step with the branches below.
local CLEU_ABSORB_EVENTS = {
    ["SPELL_HEAL"] = true,
    ["SPELL_PERIODIC_HEAL"] = true,
    ["SPELL_AURA_APPLIED"] = true,
    ["SPELL_AURA_REFRESH"] = true,
    ["SPELL_AURA_REMOVED"] = true,
    ["SWING_DAMAGE"] = true,
    ["SPELL_DAMAGE"] = true,
    ["RANGE_DAMAGE"] = true,
    ["SPELL_PERIODIC_DAMAGE"] = true,
    ["SPELL_BUILDING_DAMAGE"] = true,
    ["DAMAGE_SHIELD"] = true,
    ["DAMAGE_SPLIT"] = true,
    ["SWING_MISSED"] = true,
    ["SPELL_MISSED"] = true,
    ["RANGE_MISSED"] = true,
    ["SPELL_PERIODIC_MISSED"] = true,
    ["DAMAGE_SHIELD_MISSED"] = true,
    ["ENVIRONMENTAL_DAMAGE"] = true,
}

--! WotLK perf: the payload arrives as named parameters instead of `...` plus a
--! twenty-slot vararg unpack. A Lua 5.1 function that declares `...` is a vararg
--! function: every call goes through adjust_varargs, which relocates the fixed
--! arguments and sets up a separate vararg area, and the VARARG opcode then copies
--! the values back into registers. Named parameters are already sitting on the
--! stack where the C caller left them, so both costs vanish - on the single most
--! frequent event in the game. Extra arguments past arg20 are discarded exactly as
--! the old unpack discarded them. The unused names are kept because they document
--! the native 3.3.5 slot layout the branches below depend on, and an unfilled
--! parameter slot costs nothing at runtime.
cleu:SetScript("OnEvent", function(_, _,
    timestamp, subEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags,
    arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20)

    if not CLEU_ABSORB_EVENTS[subEvent] then return end

    local spellId, spellName, spellSchool = arg9, arg10, arg11

    if subEvent == "SPELL_HEAL" then
        --! WotLK perf: Cell.vars читался в этой ветви восемь раз - каждый раз это
        --! чтение глобала Cell плюс хеш-лукап .vars, - а playerGUID из него четыре
        --! раза. Подъём стоит внутри ветви, а не сразу после гейта: ветви урона
        --! (SWING_DAMAGE, SPELL_DAMAGE и родня) - самые частые из проходящих гейт,
        --! и Cell.vars им не нужен вовсе, так что общий подъём был бы для них
        --! чистым налогом. Ни один вызов внутри ветви таблицу vars не подменяет:
        --! она создаётся один раз в Core_Wrath.lua:25, guids - один раз ниже в файле
        --! (`Cell.vars.guids = {}`, единственное присвоение на весь аддон).
        local vars = Cell.vars
        local playerGUID = vars.playerGUID
        local guids = vars.guids

        --! WotLK fix: the glyph branch wrote to three tables (lastHealTimeStamp,
        --! lastGlyphHeal, absorbInfos) keyed on ANY destGUID - no roster filter, no
        --! source filter - and cleanup is tied to Cell's own buttons, so for an
        --! outsider it never happens. Harness run 12: 3 of 4 glyph header samples carry
        --! destFlags 1304 = OUTSIDER. Only process what Cell actually shows, or what
        --! the player himself applied.
        if spellId == 56160 and (guids[destGUID] or sourceGUID == playerGUID) then -- Glyph of Power Word: Shield
            lastHealTimeStamp[destGUID] = timestamp

            local amount
            --! WotLK fix: on native 3.3.5 SPELL_HEAL the crit flag is slot 15
            --! (amount=12, overheal=13, absorbed=14, critical=15). arg17 does
            --! not exist here, so crit glyph heals overestimated the shield.
            if arg15 then
                amount = arg12 / 1.5 / 0.2
            else
                amount = arg12 / 0.2
            end
            lastGlyphHeal[destGUID] = arg12

            local t = absorbInfos[destGUID]
            if not t then t = {}; absorbInfos[destGUID] = t end
            t[PWS_NAME] = amount

            if not indicatorBooleans["powerWordShield"] or sourceGUID == playerGUID then
                UpdateShield(destGUID, amount)
            else
                UpdateShield(destGUID, nil, true)
            end
        end

        -- Divine Aegis (mine)
        --! WotLK fix: DA procs on CRITS - on native 3.3.5 the crit flag is
        --! slot 15 and the heal amount is slot 12. The old arg18/arg15 pair
        --! (retail-ordered payload) is nil/crit-flag here, so my Divine Aegis
        --! was never accumulated from this path.
        if sourceGUID == playerGUID and vars.divineAegisMultiplier and arg15 then
            --! WotLK perf: guids[destGUID] спрашивался дважды в одной строке.
            local daUnit = guids[destGUID]
            local maxDA = daUnit and 125 * UnitLevel(daUnit) or 10000
            local t = absorbInfos[destGUID]
            if not t then t = {}; absorbInfos[destGUID] = t end

            local currentDA = t[DA_NAME] or 0
            t[DA_NAME] = min(currentDA + arg12 * vars.divineAegisMultiplier, maxDA)

            UpdateShield(destGUID)
        end

        -- Val'anyr
        if sourceGUID == playerGUID then
            lastHealAmount = arg12 --! WotLK fix: heal amount is slot 12 on native 3.3.5 (slot 15 is the 1/nil crit flag - a non-crit heal during an active Val'anyr proc crashed on nil arithmetic)
            lastHealGUID = destGUID
            if blessing then
                local t = absorbInfos[destGUID]
                if not t then t = {}; absorbInfos[destGUID] = t end
                local currentPAK = t[PAK_NAME] or 0
                t[PAK_NAME] = min(currentPAK + arg12 * 0.15, 20000) --! WotLK fix: amount is slot 12 (slot 15 = 1/nil crit flag -> nil arithmetic crash on non-crit heals)

                UpdateShield(destGUID)
            end
        end

    elseif subEvent == "SPELL_PERIODIC_HEAL" then
        -- Val'anyr
        --! Cell.vars здесь читается один раз - поднимать нечего.
        if sourceGUID == Cell.vars.playerGUID then
            lastHealAmount = arg12 --! WotLK fix: heal amount is slot 12 on native 3.3.5 (slot 15 is the 1/nil crit flag - a non-crit heal during an active Val'anyr proc crashed on nil arithmetic)
            lastHealGUID = destGUID
            if blessing then
                --! WotLK perf: absorbInfos[destGUID] спрашивался трижды.
                local t = absorbInfos[destGUID]
                if not t then t = {}; absorbInfos[destGUID] = t end
                local currentPAK = t[PAK_NAME] or 0
                t[PAK_NAME] = min(currentPAK + arg12 * 0.15, 20000) --! WotLK fix: amount is slot 12 (slot 15 = 1/nil crit flag -> nil arithmetic crash on non-crit heals)
                
                UpdateShield(destGUID)
            end
        end

    -- WotLK Absorb Application / Removal
    elseif subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
        if spellName and ABSORB_SPELLS[spellName] then
             -- Specific logic for PW:S glyph check prioritization
             if spellName == PWS_NAME and lastGlyphHeal[destGUID] and lastHealTimeStamp[destGUID] and (timestamp - lastHealTimeStamp[destGUID] < 0.5) then
                  if not absorbInfos[destGUID] then absorbInfos[destGUID] = {} end
                  absorbInfos[destGUID][PWS_NAME] = lastGlyphHeal[destGUID] / 0.2
                  lastGlyphHeal[destGUID] = nil
                  UpdateShield(destGUID)
             else
                  local unit = Cell.vars.guids[destGUID]
                  if unit then
                      --! WotLK perf: was a per-event closure declared right here -
                      --! see TryAbsorbScan/AbsorbScanWithRetry at file scope
                      AbsorbScanWithRetry(unit, spellName, destGUID)
                  end
             end
             -- UpdateShield called inside TryAbsorbScan if successful
        elseif spellId == 64411 and sourceGUID == Cell.vars.playerGUID then
             -- Blessing of Ancient Kings (start)
             blessing = true
             if lastHealAmount then
                 if not absorbInfos[lastHealGUID] then absorbInfos[lastHealGUID] = {} end
                 absorbInfos[lastHealGUID][PAK_NAME] = min(lastHealAmount * 0.15, 20000)
                 UpdateShield(lastHealGUID)
             end
        end

    elseif subEvent == "SPELL_AURA_REMOVED" then
        --! WotLK fix: Divine Aegis обнуляется с задержкой и с перепроверкой аурой.
        --! DA складывается: каждый крит лечения добавляет щит к уже существующему, и
        --! сервер при этом переприменяет ауру - в лог уходит SPELL_AURA_REMOVED, сразу
        --! за ним SPELL_AURA_APPLIED. Обнуляя запись по первому же REMOVED, Cell сбивал
        --! накопленный щит в ноль на каждом крите, хотя аура на цели никуда не
        --! девалась. Так же это сделано в WeakAuras-аурах на DA под этот клиент:
        --! отложить на 0.1 с и обнулять только если баффа действительно больше нет.
        --! Остальные щиты (PW:S, Val'anyr, чужие абсорбы) не складываются и снимаются
        --! однократно, поэтому для них зачистка остаётся немедленной - там задержка
        --! только оставила бы на экране уже съеденный щит.
        if spellName == DA_NAME then
            pendingDA[destGUID] = true
            ScheduleDACheck()
        elseif spellName and ABSORB_SPELLS[spellName] then
            if absorbInfos[destGUID] then
                 absorbInfos[destGUID][spellName] = nil
            end
            if spellName == PWS_NAME and lastGlyphHeal[destGUID] then
                lastGlyphHeal[destGUID] = nil
                 -- Only clear PW:S
            end

            UpdateShield(destGUID)

            if spellName == PWS_NAME then
                -- drop absorb bar immediately ? No update handles it.
                -- However legacy code forced hide if HealAbsorbs 0.
                -- UpdateShield calls UpdateShieldAbsorbs which hides if 0.
            end
        elseif sourceGUID == Cell.vars.playerGUID then 
            if spellId == 64411 then
                blessing = false
                UpdateShield(destGUID)
            end
        end

    -- WotLK Consumption
    -- SWING_DAMAGE: amount(9), ..., absorbed(14)
    elseif subEvent == "SWING_DAMAGE" then
        ConsumeAbsorb(destGUID, arg14)
    -- SPELL_DAMAGE / RANGE_DAMAGE: amount(12), ..., absorbed(17)
    --! WotLK fix: SPELL_PERIODIC_DAMAGE, SPELL_BUILDING_DAMAGE, DAMAGE_SHIELD and
    --! DAMAGE_SPLIT carry the same SPELL prefix (spellId, spellName, spellSchool),
    --! so absorbed stays at arg17. Without the periodic variant every DoT tick ate
    --! the shield without decrementing absorbInfos, and shieldBar kept showing
    --! absorb the target no longer had.
    elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE"
        or subEvent == "SPELL_PERIODIC_DAMAGE" or subEvent == "SPELL_BUILDING_DAMAGE"
        or subEvent == "DAMAGE_SHIELD" or subEvent == "DAMAGE_SPLIT" then
         ConsumeAbsorb(destGUID, arg17)
    -- SWING_MISSED / SPELL_MISSED
    elseif subEvent == "SWING_MISSED" then
        --! WotLK fix: SWING_MISSED payload is missType(9), amountMissed(10).
        if arg9 == "ABSORB" then
            ConsumeAbsorb(destGUID, arg10)
        end
    --! WotLK fix: a tick absorbed in full arrives as SPELL_PERIODIC_MISSED with the
    --! same layout - missType(12), amountMissed(13). DAMAGE_SHIELD_MISSED too.
    elseif subEvent == "SPELL_MISSED" or subEvent == "RANGE_MISSED"
        or subEvent == "SPELL_PERIODIC_MISSED" or subEvent == "DAMAGE_SHIELD_MISSED" then
         --! WotLK fix: SPELL/RANGE_MISSED payload is spellId(9), spellName(10),
         --! school(11), missType(12), amountMissed(13).
         if arg12 == "ABSORB" then
             ConsumeAbsorb(destGUID, arg13)
         end

    --! WotLK fix: ENVIRONMENTAL_DAMAGE has a single prefix arg (environmentalType),
    --! so the damage suffix starts one slot earlier and absorbed sits at arg15,
    --! not arg17. Fire, lava, falling and drowning eat the shield too.
    elseif subEvent == "ENVIRONMENTAL_DAMAGE" then
         ConsumeAbsorb(destGUID, arg15)
    end
end)

--! WotLK fix: сброс поглощения при смене зоны. Записи в absorbInfos чистятся только
--! там, где кнопка Cell меняет отображаемого юнита (:3420) - то есть лишь для тех, кто
--! есть в группе. Но ветки DA, Val'anyr и глифа PW:S фильтруют только источник
--! (sourceGUID == Cell.vars.playerGUID), а не цель: полечив в открытом мире случайного
--! прохожего, жрец получает запись, которую уже ничто не удалит, и она висит до
--! перезахода. За долгую сессию с рейдами, БГ и городом это утечка, а при совпадении
--! GUID - ещё и чужой щит на новом юните. Отдельный фрейм, а не подписка на том же
--! cleu: его обработчик игнорирует имя события (второй параметр - `_`) и разбирает
--! аргументы как боевой лог, а добавлять туда сравнение события - это сотни лишних
--! проверок в секунду в рейде. Смена зоны выбрана точкой сброса потому, что все данные
--! здесь производные от боя, который к этому моменту уже кончился.
local absorbReset = CreateFrame("Frame")
absorbReset:RegisterEvent("PLAYER_ENTERING_WORLD")
absorbReset:SetScript("OnEvent", function()
    wipe(absorbInfos)
    wipe(lastGlyphHeal)
    wipe(lastHealTimeStamp)
    wipe(pendingDA)
    lastHealAmount = nil
    lastHealGUID = nil
    blessing = nil
end)

-------------------------------------------------
-- cleu health updater
-------------------------------------------------
local cleuHealthUpdater = CreateFrame("Frame", "CellCleuHealthUpdater")
--! WotLK perf: named parameters instead of `...` + a nineteen-slot vararg unpack,
--! and the friend test now comes before anything else. See the note on the main
--! cleu handler above for why the vararg form costs more in Lua 5.1; this frame
--! sees exactly the same event stream, so the saving is the same. destFlags is the
--! cheapest possible rejection - one bit mask - and it throws away every line of
--! the log that concerns a mob hitting another mob, which in a raid is most of it.
cleuHealthUpdater:SetScript("OnEvent", function(self, event,
    _, subEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags,
    arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19)

    if not F.IsFriend(destFlags) then return end

    --! WotLK fix/perf: CombatLogGetCurrentEventInfo does not exist on 3.3.5 - the
    --! ClassicAPI version is a pure argument TRANSLATOR (20 params in, 23 returns
    --! out) whose Lua frame was paid on EVERY combat-log event, before subEvent or
    --! destFlags were even looked at; in a raid that is hundreds of calls a second.
    --! Parse the native payload directly, like the cleu handler above does: there
    --! is no hideCaster and there are no raid-flag slots here, so retail slot N is
    --! native slot N-3 (amount: 15 -> 12 for spell/range, 12 -> 9 for swing).
    local diff
    if subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
        -- spellId, spellName, spellSchool, amount, overhealing, absorbed, critical
        diff = arg12
    --! WotLK fix: DAMAGE_SHIELD (Thorns, Retribution Aura) and DAMAGE_SPLIT carry
    --! the same SPELL prefix, so amount is arg12 here too (codex describes both as
    --! "SPELL prefix args + DAMAGE suffix args"). The absorb branch of the main
    --! cleu handler already lists them (:2904), this one did not - damage from
    --! those two sources never moved the health bar between UNIT_HEALTH events.
    --! Not a theoretical path: harness run 11 recorded DAMAGE_SPLIT 12 times.
    elseif subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE"
        or subEvent == "DAMAGE_SHIELD" or subEvent == "DAMAGE_SPLIT" then
        -- spellId, spellName, spellSchool, amount, overhealing, absorbed, critical
        diff = -arg12
    elseif subEvent == "SWING_DAMAGE" then
        -- amount
        diff = -arg9
    elseif subEvent == "RANGE_DAMAGE" then
        -- spellId, spellName, spellSchool, amount
        diff = -arg12
    elseif subEvent == "ENVIRONMENTAL_DAMAGE" then
        -- environmentalType, amount
        diff = -arg10
    end

    if diff and diff ~= 0 then
        F.HandleUnitButton("guid", destGUID, UnitButton_UpdateHealth, diff)
    end
end)

local function UpdateCLEU()
    if CellDB["general"]["useCleuHealthUpdater"] then
        cleuHealthUpdater:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        cleuHealthUpdater:UnregisterAllEvents()
    end
end
Cell.RegisterCallback("UpdateCLEU", "UnitButton_UpdateCLEU", UpdateCLEU)

-------------------------------------------------
-- translit names
-------------------------------------------------
Cell.RegisterCallback("TranslitNames", "UnitButton_TranslitNames", function()
    F.IterateAllUnitButtons(function(b)
        UnitButton_UpdateName(b)
    end, true)
end)

-------------------------------------------------
-- update all
-------------------------------------------------
UnitButton_UpdateAll = function(self)
    if not self:IsVisible() then return end

    --! WotLK fix (offline detect, see UNIT_HEALTH branch): sync the
    --! connection-state cache on every full update, normalized to boolean
    --! (UnitIsConnected returns 1/nil on 3.3.5).
    self.__isConnected = (self.states.unit and UnitIsConnected(self.states.unit)) and true or false

    UnitButton_UpdateVehicleStatus(self)
    UnitButton_UpdateName(self)
    UnitButton_UpdateNameTextColor(self)
    UnitButton_UpdateHealthTextColor(self)
    UnitButton_UpdateHealthStates(self)
    UnitButton_UpdateHealthMax(self, true)
    UnitButton_UpdateHealth(self, nil, true)
    UnitButton_UpdateHealPrediction(self, true)
    UnitButton_UpdateStatusText(self)
    UnitButton_UpdateHealthColor(self)
    UnitButton_UpdateTarget(self)
    UnitButton_UpdatePlayerRaidIcon(self)
    UnitButton_UpdateTargetRaidIcon(self)
    --! WotLK fix/perf: shield repaint already performs the paired heal-absorb
    --! repaint; do not invoke the disabled WotLK path a second time.
    UnitButton_UpdateShieldAbsorbs(self, true)
    UnitButton_UpdateInRange(self)
    UnitButton_UpdateRole(self)
    UnitButton_UpdateLeader(self)
    UnitButton_UpdateReadyCheck(self)
    UnitButton_UpdateThreat(self)
    UnitButton_UpdateThreatBar(self)
    I.UpdateStatusIcon_Resurrection(self)

    UnitButton_UpdatePowerStates(self)
    if Cell.loaded then
        if self._powerUpdateRequired then
            self._powerUpdateRequired = nil

            self._shouldShowPowerText = ShouldShowPowerText(self)
            self._shouldShowPowerBar = ShouldShowPowerBar(self)
            CheckPowerEventRegistration(self)

            if self._shouldShowPowerText then
                UnitButton_UpdatePowerTextColor(self)
                UnitButton_UpdatePowerText(self)
            else
                self.indicators.powerText:Hide()
            end

            if self._shouldShowPowerBar then
                ShowPowerBar(self)
            else
                HidePowerBar(self)
            end

        end
    end

    UnitButton_UpdateAuras(self)
end

--! WotLK fix: one private roster broadcast invalidates all current unit
--! buttons. Native PARTY_MEMBERS_CHANGED / RAID_ROSTER_UPDATE are owned by
--! Core_Wrath.lua, so every button no longer registers a non-native event.
local function UnitButton_GroupRosterUpdate()
    F.IterateAllUnitButtons(function(button)
        if button:IsVisible() then
            button._updateRequired = 1
            button._powerUpdateRequired = 1
        end
    end, true)
end
Cell.RegisterCallback(
    "GroupRosterUpdate",
    "UnitButton_GroupRosterUpdate",
    UnitButton_GroupRosterUpdate
)

--! WotLK fix: два узких широковещания того же вида. Апстрим держал
--! PARTY_LEADER_CHANGED и PLAYER_ROLES_ASSIGNED закомментированными в
--! UnitButton_RegisterEvents ниже с пометкой "GROUP_ROSTER_UPDATE" - на ретейле
--! их покрывает роста. На 3.3.5 не покрывает (см. Core_Wrath.lua, где они
--! теперь зарегистрированы один раз): повышение и выдача роли через LFD состав
--! не меняют, поэтому корона, states.role, иконка роли и фильтры силы
--! TANK/HEALER оставались в старом виде до постороннего полного обновления.
--! Регистрация в Core, а не на кнопках, потому что 40 кнопок × 2 события - это
--! 80 регистраций, и каждая рассылка будила бы все 40 обработчиков поштучно.
--! Обработчики анонимные намеренно: главный чанк этого файла почти упёрся в
--! лимит Lua 5.1 (200 локалов на функцию), а имена тут нужны только шине.
Cell.RegisterCallback("LeaderChanged", "UnitButton_LeaderChanged", function()
    F.IterateAllUnitButtons(function(button)
        if button:IsVisible() then
            UnitButton_UpdateLeader(button)
        end
    end, true)
end)

Cell.RegisterCallback("RolesAssigned", "UnitButton_RolesAssigned", function()
    F.IterateAllUnitButtons(UnitButton_RoleChanged, true)
end)

-------------------------------------------------
-- unit button events
-------------------------------------------------
local function UnitButton_RegisterEvents(self)
    -- self:RegisterEvent("PLAYER_ENTERING_WORLD")
    --! WotLK fix: roster invalidation is delivered once through Cell's private
    --! GroupRosterUpdate callback, not the non-native frame event.

    --! WotLK perf: every UNIT_* event this function used to register now sits on the
    --! central unitEventFrame, registered once for the whole session - joining the
    --! token index IS the registration for this button. __powerEvents carries what
    --! CheckPowerEventRegistration used to express by (un)registering the fourteen
    --! power events here: they are always on centrally, so the gate moved onto the
    --! button. Both fields are set before UpdateUnitEventIndex so the very first
    --! event after this line finds the button in the index.
    self.__unitEventsOn = true
    self.__powerEvents = true
    UpdateUnitEventIndex(self)

    self:RegisterEvent("ZONE_CHANGED_NEW_AREA") --? update status text

    --! WotLK fix: PARTY_LEADER_CHANGED / PLAYER_ROLES_ASSIGNED зарегистрированы
    --! один раз в Core_Wrath.lua и приходят сюда шиной ("LeaderChanged",
    --! "RolesAssigned" выше) - на кнопках их держать незачем.
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")

    self:RegisterEvent("PLAYER_TARGET_CHANGED")

    if Cell.loaded then
        if enabledIndicators["playerRaidIcon"] then
            self:RegisterEvent("RAID_TARGET_UPDATE")
        end
        if enabledIndicators["targetRaidIcon"] then
            --! UNIT_TARGET is a unit event, so it is toggled on the central frame.
            --! The indicator flag is global, so there is nothing to refcount: the
            --! second button to show only repeats what the first one decided, and
            --! RegisterEvent is idempotent.
            unitEventFrame:RegisterEvent("UNIT_TARGET")
        end
        if enabledIndicators["readyCheckIcon"] then
            self:RegisterEvent("READY_CHECK")
            self:RegisterEvent("READY_CHECK_FINISHED")
            self:RegisterEvent("READY_CHECK_CONFIRM")
        end
    else
        self:RegisterEvent("RAID_TARGET_UPDATE")
        unitEventFrame:RegisterEvent("UNIT_TARGET")
        self:RegisterEvent("READY_CHECK")
        self:RegisterEvent("READY_CHECK_FINISHED")
        self:RegisterEvent("READY_CHECK_CONFIRM")
    end

    -- self:RegisterEvent("PARTY_MEMBER_DISABLE")
    -- self:RegisterEvent("PARTY_MEMBER_ENABLE")
    --! WotLK fix: incoming resurrection updates are owned privately by
    --! Indicators/StatusIcon.lua through LibResComm callbacks.

    -- self:RegisterEvent("VOICE_CHAT_CHANNEL_ACTIVATED")
    -- self:RegisterEvent("VOICE_CHAT_CHANNEL_DEACTIVATED")

    local success, result = pcall(UnitButton_UpdateAll, self)
    if not success then
        F.Debug("UnitButton_UpdateAll |cffff0000FAILED:|r", self:GetName(), result)
    end
end

local function UnitButton_UnregisterEvents(self)
    --! WotLK perf: leaving the token index is what unregisters the unit events now;
    --! the broadcast ones are still real registrations on this frame.
    self.__unitEventsOn = nil
    UpdateUnitEventIndex(self)
    self:UnregisterAllEvents()
end

--! WotLK perf: the per-button half of the central dispatcher above. Reaching this
--! function already means the index says this button displays `unit`, so the token
--! filter that used to open it is gone. That filter was the most-executed line in
--! the addon and it answered "no" for 25-40 buttons out of 25-40 on every unit
--! event; the index answers the same question once, with one hash lookup. What the
--! old note here explained about that filter now describes UpdateUnitEventIndex.
--! What still holds is why `states` is hoisted (P-1/P-28: the body walks it
--! repeatedly) and why the branch order is what it is - kept below.
local function UnitButton_UnitEvent(self, event, unit)
    -- print(event, self:GetName(), unit, self.states.displayedUnit, self.states.unit)
    local states = self.states
    --! WotLK perf: the branches below are ordered by how often 3.3.5 actually
    --! fires them, not by topic. UNIT_AURA used to sit behind twenty-two string
    --! comparisons, after both power groups. Health, auras and power now come
    --! first; the conditions are mutually exclusive equality tests on one upvalue,
    --! so the order carries no meaning beyond cost.
    if event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" then
        --! WotLK fix/perf: one snapshot feeds health, prediction and shield outputs.
        UnitButton_UpdateHealthStates(self)
        UnitButton_UpdateHealth(self, nil, true)
        UnitButton_UpdateHealPrediction(self, true, true)
        UnitButton_UpdateShieldAbsorbs(self, true)
        -- UnitButton_UpdateStatusText(self)
        --! WotLK fix: UNIT_CONNECTION does not exist in 3.3.5 (added 4.0),
        --! so its registration never fires and OFFLINE state was only
        --! refreshed by (synthetic) GROUP_ROSTER_UPDATE - reliable in raid
        --! (RAID_ROSTER_UPDATE) but NOT in party. Blizzard's own 3.3.5
        --! PartyMemberFrame refreshes online status on UNIT_HEALTH
        --! (PartyMemberFrame.lua:421) - the server fires UNIT_HEALTH for a
        --! unit on connect/disconnect. Mirror that: on connection-state
        --! change, request a full update (grey bar, OFFLINE status text).
        local connected = UnitIsConnected(unit) and true or false
        if connected ~= self.__isConnected then
            self.__isConnected = connected
            self._updateRequired = 1
            self._powerUpdateRequired = 1
        end

    elseif event == "UNIT_AURA" then
        UnitButton_UpdateAuras(self)

    elseif event == "UNIT_POWER" or event == "UNIT_MANA" or event == "UNIT_RAGE" or event == "UNIT_FOCUS" or event == "UNIT_ENERGY" or event == "UNIT_RUNIC_POWER" then
        --! WotLK perf: this is what CheckPowerEventRegistration used to say by
        --! (un)registering the power events on this very button.
        if not self.__powerEvents then return end
        UnitButton_UpdatePowerStates(self)
        UnitButton_UpdatePower(self)
        UnitButton_UpdatePowerText(self)

    elseif event == "UNIT_MAXHEALTH" then
        --! WotLK fix/perf: this branch used to rebuild identical health and
        --! absorb state four times before repainting the same button.
        UnitButton_UpdateHealthStates(self)
        UnitButton_UpdateHealthMax(self, true)
        UnitButton_UpdateHealth(self, nil, true)
        UnitButton_UpdateHealPrediction(self, true, true)
        UnitButton_UpdateShieldAbsorbs(self, true)

    --! WotLK fix: heal prediction is updated by direct LibHealComm
    --! callbacks, plus the health/max-health branches above.

    --! WotLK fix: 3.3.5 fires per-power-type max events, not UNIT_MAXPOWER
    elseif event == "UNIT_MAXPOWER" or event == "UNIT_MAXMANA" or event == "UNIT_MAXRAGE" or event == "UNIT_MAXFOCUS" or event == "UNIT_MAXENERGY" or event == "UNIT_MAXRUNIC_POWER" or event == "UNIT_MAXHAPPINESS" then
        if not self.__powerEvents then return end
        UnitButton_UpdatePowerStates(self)
        UnitButton_UpdatePowerMax(self)
        UnitButton_UpdatePower(self)
        UnitButton_UpdatePowerText(self)

    elseif event == "UNIT_DISPLAYPOWER" then
        if not self.__powerEvents then return end
        UnitButton_UpdatePowerStates(self)
        UnitButton_UpdatePowerMax(self)
        UnitButton_UpdatePower(self)
        UnitButton_UpdatePowerType(self)
        UnitButton_UpdatePowerTextColor(self)
        UnitButton_UpdatePowerText(self)

    elseif  event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" or event == "UNIT_CONNECTION" then
        self._updateRequired = 1
        self._powerUpdateRequired = 1

    elseif event == "UNIT_NAME_UPDATE" then
        UnitButton_UpdateName(self)
        UnitButton_UpdateNameTextColor(self)
        UnitButton_UpdateHealthColor(self)
        UnitButton_UpdateHealthTextColor(self)
        UnitButton_UpdatePowerTextColor(self)

    elseif event == "UNIT_TARGET" then
        UnitButton_UpdateTargetRaidIcon(self)

    elseif event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FLAGS" then
        --! WotLK: PLAYER_FLAGS_CHANGED is a unit event on 3.3.5a - arg1 is a unit
        --! token, see FrameXML TargetFrame.lua:189 (`arg1 == self.unit`), which is
        --! why it belongs on the central frame and not in the broadcast handler.
        UnitButton_UpdateStatusText(self)

    elseif event == "UNIT_FACTION" then -- mind control
        UnitButton_UpdateNameTextColor(self)
        UnitButton_UpdateHealthColor(self)

    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        --! Полоска аггро здесь НЕ перерисовывается, и это не забытая строка:
        --! она видна только когда есть моб-юнит ("target"/"targettarget", см.
        --! B.GetThreatMobUnit), а для такого юнита смена категории всегда идёт
        --! вместе с UNIT_THREAT_LIST_UPDATE - его ловит общий тикер и красит
        --! полоску всему рейду одним проходом. Добавить сюда UpdateThreatBar
        --! значит удвоить работу на горячем пути ради уже сделанного. В upstream
        --! ровно так же: полоску там ведут PLAYER_TARGET_CHANGED и
        --! UNIT_THREAT_LIST_UPDATE на кнопках, а мы их свернули в тикер.
        UnitButton_UpdateThreat(self)

    -- elseif event == "UNIT_PHASE" or event == "PARTY_MEMBER_DISABLE" or event == "PARTY_MEMBER_ENABLE" then
    --     UnitButton_UpdateStatusIcon(self)

    elseif event == "UNIT_PORTRAIT_UPDATE" then -- pet summoned far away
        if states.healthMax == 0 then
            self._updateRequired = 1
            self._powerUpdateRequired = 1
        end
    end
end

--! WotLK perf: one lookup, then only the owners. Reading unitEventButtons[nil] is
--! legal in Lua 5.1 - only WRITING a nil key raises - so a custom core that fires
--! a unit event without arg1 (the very defect behind the guard in
--! BuffTracker_Classic.lua) lands on a nil list and returns, exactly as the old
--! per-button `if unit and ...` filter did.
local function UnitEventFrame_OnEvent(_, event, unit)
    local list = unitEventButtons[unit]
    if not list then return end
    --! Backwards on purpose: the vehicle branches below reach UpdateUnitEventIndex,
    --! which may remove an entry from the very list being walked. Counting down means
    --! a removal at or above the current index cannot shift a button that has not been
    --! visited yet. Order between buttons carries no meaning - they are separate
    --! frames drawing the same unit.
    for i = #list, 1, -1 do
        local button = list[i]
        if button then
            UnitButton_UnitEvent(button, event, unit)
        end
    end
end
unitEventFrame:SetScript("OnEvent", UnitEventFrame_OnEvent)

do
    --! WotLK: registered once for the whole session instead of ~30 times per shown
    --! button. An event that no button owns costs one failed hash lookup, so there
    --! is nothing to gain from unregistering when the raid frames are hidden.
    local events = {
        "UNIT_HEALTH",
        --! WotLK: UNIT_HEALTH_FREQUENT does not exist on stock 3.3.5 - kept for
        --! custom cores that backported it (harmless if it never fires; UNIT_HEALTH
        --! plus the 0.25s change-detected poll in OnTick cover health updates).
        "UNIT_HEALTH_FREQUENT",
        "UNIT_MAXHEALTH",
        --! WotLK: UNIT_POWER does not exist on stock 3.3.5 (added in 4.0) - kept for
        --! custom cores that backported it; the per-power-type events do the work.
        "UNIT_POWER",
        "UNIT_MANA",
        "UNIT_RAGE",
        "UNIT_FOCUS",
        "UNIT_ENERGY",
        "UNIT_RUNIC_POWER",
        --! WotLK fix: UNIT_MAXPOWER does not exist in 3.3.5 (added in 4.0);
        --! the client fires per-power-type max events instead. Keep UNIT_MAXPOWER
        --! for custom cores that backported the new event.
        "UNIT_MAXPOWER",
        "UNIT_MAXMANA",
        "UNIT_MAXRAGE",
        "UNIT_MAXFOCUS",
        "UNIT_MAXENERGY",
        "UNIT_MAXRUNIC_POWER",
        "UNIT_MAXHAPPINESS",
        "UNIT_DISPLAYPOWER",
        "UNIT_AURA",
        --! WotLK fix: incoming-heal repainting is driven directly by the six
        --! LibHealComm callbacks. Do not register the non-native retail
        --! UNIT_HEAL_PREDICTION event or redundant player spellcast events.
        "UNIT_THREAT_SITUATION_UPDATE",
        --! WotLK perf: UNIT_THREAT_LIST_UPDATE не регистрируется - arg1 у него NPC,
        --! а не юнит рейда, фильтр он не проходил и заставлял все кнопки
        --! пересчитывать угрозу на каждое событие. Теперь его слушает одна
        --! центральная рамка с окном 0.2 с (см. B.RequestThreatUpdate).
        "UNIT_ENTERED_VEHICLE",
        "UNIT_EXITED_VEHICLE",
        "UNIT_FLAGS", -- afk
        "UNIT_FACTION", -- mind control
        --! WotLK: UNIT_CONNECTION does not exist in 3.3.5 either - see the
        --! UNIT_HEALTH branch, which is what actually catches offline state.
        "UNIT_CONNECTION", -- offline
        "PLAYER_FLAGS_CHANGED", -- afk; unit event on 3.3.5a, see the branch above
        "UNIT_NAME_UPDATE", -- unknown target
        "UNIT_PORTRAIT_UPDATE", -- pet summoned far away
        -- "UNIT_PHASE" -- warmode, traditional sources of phasing
        -- "UNIT_PET"
    }
    for i = 1, #events do
        unitEventFrame:RegisterEvent(events[i])
    end
end

--! WotLK perf: what is left on the buttons themselves - the broadcast events. None
--! of them carries a unit token this addon can filter on, and every shown button
--! has to react to each of them, so the client's own dispatch is already the
--! cheapest fan-out available. Because the unit events left this handler, the chain
--! below now runs only when one of these seven actually fires - a few times per
--! fight instead of once per button per health tick.
local function UnitButton_OnEvent(self, event)
    if event == "READY_CHECK_CONFIRM" then
        --! WotLK fix: arg1 is a numeric party/raid index on 3.3.5, not a
        --! unit token, so it never belonged with the unit events. Each visible
        --! button already receives the event and can query its own authoritative
        --! status through GetReadyCheckStatus(states.unit).
        UnitButton_UpdateReadyCheck(self)

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        UnitButton_UpdateLeader(self, event)

    elseif event == "PLAYER_TARGET_CHANGED" then
        UnitButton_UpdateTarget(self)
        --! WotLK perf: угрозу здесь больше не считаем - смена цели меняет моба для
        --! ВСЕХ кнопок сразу, и центральная рамка делает один общий проход вместо
        --! 25-40 отдельных вызовов из 25-40 копий этого обработчика.

    elseif event == "RAID_TARGET_UPDATE" then
        UnitButton_UpdatePlayerRaidIcon(self)
        UnitButton_UpdateTargetRaidIcon(self)

    elseif event == "READY_CHECK" then
        UnitButton_UpdateReadyCheck(self)

    elseif event == "READY_CHECK_FINISHED" then
        UnitButton_FinishReadyCheck(self)

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        UnitButton_UpdateStatusText(self)

    -- elseif event == "VOICE_CHAT_CHANNEL_ACTIVATED" or event == "VOICE_CHAT_CHANNEL_DEACTIVATED" then
    -- 	VOICE_CHAT_CHANNEL_MEMBER_SPEAKING_STATE_CHANGED
    end
end

local timer
local function EnterLeaveInstance()
    if timer then timer:Cancel() timer=nil end
    timer = C_Timer.NewTimer(1, function()
        F.Debug("|cffff1111*** EnterLeaveInstance:|r UnitButton_UpdateAll")
        F.IterateAllUnitButtons(UnitButton_UpdateAll, true)
        timer = nil
    end)
end
Cell.RegisterCallback("EnterInstance", "UnitButton_EnterInstance", EnterLeaveInstance)
Cell.RegisterCallback("LeaveInstance", "UnitButton_LeaveInstance", EnterLeaveInstance)

local function UnitButton_OnAttributeChanged(self, name, value)
    if name == "unit" and not self:GetAttribute("oldUnit") then
        Cell.funcs.Debug("|cffaaaa00[OnAttributeChanged] name:|r", name, "|cffaaaa00value:|r", value, "|cffaaaa00self.states.unit:|r", self.states.unit, "|cffaaaa00Button:|r", self:GetName())
        if not value or value ~= self.states.unit then
            -- NOTE: when unitId for this button changes
            if self.__unitGuid then -- self.__unitGuid is deleted when hide
                -- print("deleteUnitGuid:", self:GetName(), self.states.unit, self.__unitGuid)
                if not self.isSpotlight then Cell.vars.guids[self.__unitGuid] = nil end
                self.__unitGuid = nil
            end
            if self.__unitName then
                if not self.isSpotlight then Cell.vars.names[self.__unitName] = nil end
                self.__unitName = nil
            end
            wipe(self.states)
        else
            Cell.funcs.Debug("|cffaaaa00[OnAttributeChanged] SKIPPED - value equals self.states.unit:|r", value)
        end

        if type(value) == "string" then
            self.states.unit = value
            self.states.displayedUnit = value
            if string.find(value, "raid") then Cell.unitButtons.raid.units[value] = self end
            -- WotLK 3.3.5a: Also populate party units (player, party1-4, pet, partypet1-4)
            -- Only add to units table if the unit actually exists to prevent duplicates when leaving party
            if string.find(value, "party") or value == "player" or value == "pet" or string.find(value, "partypet") then
                if UnitExists(value) then
                    Cell.unitButtons.party.units[value] = self
                    Cell.funcs.Debug("|cff00ffff[OnAttributeChanged] Populated party unit:|r", value, "Button:", self:GetName())
                else
                    -- Unit no longer exists, ensure it's cleared from the table
                    Cell.unitButtons.party.units[value] = nil
                    Cell.funcs.Debug("|cffff0000[OnAttributeChanged] Cleared invalid party unit:|r", value, "Button:", self:GetName())
                end
            end
            -- for omnicd
            if string.match(value, "raid%d") then
                local i = string.match(value, "%d")
                _G["CellRaidFrameMember"..i] = self
                self.unit = value
            end

            ResetAuraTables(self)

            -- reset shields
            local guid = UnitGUID(value)
            if guid then
                absorbInfos[guid] = nil
                --! WotLK fix: the two glyph-of-PW:S bookkeeping tables were never
                --! cleaned up anywhere, so every GUID ever shielded stayed keyed
                --! for the whole session. They are written next to absorbInfos
                --! (:2818, :2829), so they get cleared next to it too - the entry
                --! is worthless the moment the button stops showing that unit.
                lastGlyphHeal[guid] = nil
                lastHealTimeStamp[guid] = nil
            end
        end

        --! WotLK perf: this is where a button changes which unit it owns - either to
        --! a new token above, or to nothing at all when value is not a string and
        --! wipe(self.states) has just cleared both tokens. Either way the central
        --! dispatcher's index has to follow, and it has to happen after the wipe.
        UpdateUnitEventIndex(self)
    end
end

-------------------------------------------------
-- unit button show/hide/enter/leave
-------------------------------------------------
Cell.vars.guids = {} -- guid to unitid
Cell.vars.names = {} -- name to unitid

local function UnitButton_OnShow(self)
    --! WotLK fix: seed the GUID map before an immediate LibHealComm callback
    --! can target this newly shown button. The regular tick keeps the mapping
    --! synchronized afterward and clears it in UnitButton_OnHide.
    if self.states.unit and not self.isSpotlight then
        local guid = UnitGUID(self.states.unit)
        if guid then
            Cell.vars.guids[guid] = self.states.unit
            self.__unitGuid = guid
        end
    end

    --! WotLK 3.3.5a: some header update paths can leave raid buttons
    --! non-interactive (dead mouseover/clicks) until /reload. Force it on show.
    if not self:IsMouseEnabled() then
        self:EnableMouse(true)
    end

    self._updateRequired = 1 -- prevent duplicate full updates during party <-> raid conversion.
    self._powerUpdateRequired = 1
    UnitButton_RegisterEvents(self)

    --[[
    if self.states.unit then
        -- NOTE: update Cell.vars.guids
        local guid = UnitGUID(self.states.unit)
        if guid then
            Cell.vars.guids[guid] = self.states.unit
        end
        --! NOTE: can't get valid name immediately after an unseen player joining into group
        self.__timer = C_Timer.NewTicker(0.5, function()
            local name = GetUnitName(self.states.unit, true)
            if name and name ~= _G.UNKNOWN then
                Cell.vars.names[name] = self.states.unit
                self.__timer:Cancel()
                self.__timer = nil
            end
        end)
        -- print("show", self.states.unit, guid, name)
    end
    ]]
end

local function UnitButton_OnHide(self)
    UnitButton_UnregisterEvents(self)

    --! WotLK fix: private smoothing keeps bars as table keys; remove hidden
    --! buttons immediately so the driver cannot retain recycled secure frames.
    smoothBars[self.widgets.healthBar] = nil
    smoothBars[self.widgets.powerBar] = nil

    ResetAuraTables(self)

    -- reset shields
    if self.__displayedGuid then
        absorbInfos[self.__displayedGuid] = nil
        --! WotLK fix: clear the glyph bookkeeping with the shield, see :3415.
        lastGlyphHeal[self.__displayedGuid] = nil
        lastHealTimeStamp[self.__displayedGuid] = nil
    end

    -- NOTE: update Cell.vars.guids
    -- print("hide", self.states.unit, self.__unitGuid, self.__unitName)
    if self.__unitGuid then
        if not self.isSpotlight then Cell.vars.guids[self.__unitGuid] = nil end
        self.__unitGuid = nil
    end
    if self.__unitName then
        if not self.isSpotlight then Cell.vars.names[self.__unitName] = nil end
        self.__unitName = nil
    end
    self.__displayedGuid = nil
    self._updateRequired = nil
    F.RemoveElementsExceptKeys(self.states, "unit", "displayedUnit")
end

local function UnitButton_OnEnter(self)
    if not Cell.IsEncounterInProgress() then UnitButton_UpdateStatusText(self) end

    if highlightEnabled then self.widgets.mouseoverHighlight:Show() end

    local unit = self.states.displayedUnit
    if not unit then return end

    F.ShowTooltips(self, "unit", unit)
end

local function UnitButton_OnLeave(self)
    self.widgets.mouseoverHighlight:Hide()
    GameTooltip:Hide()
end

local UNKNOWN = _G.UNKNOWN
local UNKNOWNOBJECT = _G.UNKNOWNOBJECT
local function UnitButton_OnTick(self)
    --! WotLK perf: one resolve of the states table for the whole tick. OnTick runs
    --! four times a second on every button - 160 calls a second in a full raid -
    --! and it walked self.states more than a dozen times per call. The table is
    --! created once in CellUnitButton_OnLoad and is only ever cleared in place
    --! (wipe / F.RemoveElementsExceptKeys), so the reference cannot go stale here.
    local states = self.states

    --! WotLK perf: safety net for the central dispatcher's index. A missing entry is
    --! the one failure mode that would be silent - the button would simply stop
    --! updating - so its own tick verifies the entry it believes it holds and
    --! repairs it. Four comparisons four times a second per button; in exchange, a
    --! token change that some future edit forgets to report costs a quarter second
    --! of staleness instead of a dead frame for the rest of the session.
    if self.__unitEventsOn then
        local indexedDisplayed = states.displayedUnit
        if indexedDisplayed == states.unit then indexedDisplayed = nil end
        if self.__indexedUnit ~= states.unit or self.__indexedDisplayedUnit ~= indexedDisplayed then
            UpdateUnitEventIndex(self)
        end
    end

    local e = (self.__tickCount or 0) + 1
    if e >= 2 then -- every 0.5 second
        e = 0

        if states.unit and states.displayedUnit then
            local du = states.displayedUnit

            --! WotLK fix: 3.3.5 does NOT reliably fire UNIT_HEALTH /
            --! UNIT_MAXHEALTH for pet units (partypetN/raidpetN), so pet
            --! frames stayed at full HP forever. Blizzard's own 3.3.5
            --! PetFrame polls via frequentUpdates (UnitFrame.lua:48,199) -
            --! do the same here on the 0.5s tick, pets only.
            --! WotLK perf: the strfind answer is cached against the unit id that
            --! produced it. Unit ids are interned strings, so the guard is a pointer
            --! compare and the C call now happens only when the button starts showing
            --! a different unit, instead of twice a second for the whole session.
            if du ~= self.__tickUnit then
                self.__tickUnit = du
                self.__tickUnitIsPet = strfind(du, "pet") and true or false
            end
            if self.__tickUnitIsPet then
                local health = UnitHealth(du)
                local healthMax = UnitHealthMax(du)
                if healthMax ~= states.healthMax then
                    UnitButton_UpdateHealthMax(self)
                    UnitButton_UpdateHealth(self)
                elseif health ~= states.health then
                    UnitButton_UpdateHealth(self)
                end
            end

            --! WotLK fix: 3.3.5a does not fire a reliable event on a corpse<->ghost
            --! transition. UNIT_HEALTH often arrives BEFORE UnitIsGhost /
            --! UnitIsDeadOrGhost flip, and no follow-up event is sent, so the
            --! "GHOST"/"DEAD" status text only refreshed on the next full update
            --! (e.g. mouseover). Poll the dead/ghost state on the 0.5s tick and
            --! refresh the status text whenever it changes.
            local u = states.unit
            local deadGhostState = (UnitIsGhost(u) and 2) or (UnitIsDeadOrGhost(u) and 1) or 0
            if deadGhostState ~= self.__deadGhostState then
                self.__deadGhostState = deadGhostState
                UnitButton_UpdateStatusText(self)
            end

            local displayedGuid = UnitGUID(du)
            if displayedGuid ~= self.__displayedGuid then
                -- NOTE: displayed unit entity changed
                F.RemoveElementsExceptKeys(states, "unit", "displayedUnit")
                self.__displayedGuid = displayedGuid
                if displayedGuid then --? clearing unit may come before hiding
                    self._updateRequired = 1
                    self._powerUpdateRequired = 1
                end
            end

            local guid = UnitGUID(u)
            if guid and guid ~= self.__unitGuid then
                -- print("guidChanged:", self:GetName(), self.states.unit, guid)
                -- NOTE: unit entity changed
                -- update Cell.vars.guids
                self.__unitGuid = guid
                if not self.isSpotlight then Cell.vars.guids[guid] = u end

                -- NOTE: only save players' names
                if UnitIsPlayer(u) then
                    -- update Cell.vars.names
                    local name = GetUnitName(u, true)
                    if (name and self.__nameRetries and self.__nameRetries >= 4) or (name and name ~= UNKNOWN and name ~= UNKNOWNOBJECT) then
                        self.__unitName = name
                        if not self.isSpotlight then Cell.vars.names[name] = u end
                        self.__nameRetries = nil
                    else
                        -- NOTE: update on next tick
                        -- 国服可以���名为“未知目标”，干！就只多重试4次好了
                        self.__nameRetries = (self.__nameRetries or 0) + 1
                        self.__unitGuid = nil
                    end
                end
            end
        end
    end

    self.__tickCount = e

    UnitButton_UpdateInRange(self)

    --! WotLK 3.3.5a: UNIT_HEALTH_FREQUENT does not exist and UNIT_HEALTH is
    --! server-throttled (worse in big raids), so health bars can lag. Poll for
    --! changes here as a fallback. Change-detected, so an unchanged unit costs
    --! only a couple of API reads and triggers no redraw.
    if self._indicatorsReady and not self._updateRequired and states.displayedUnit then
        local u = states.displayedUnit
        if UnitHealthMax(u) ~= states.healthMax then
            UnitButton_UpdateHealthStates(self)
            UnitButton_UpdateHealthMax(self, true)
            UnitButton_UpdateHealth(self, nil, true)
            UnitButton_UpdateHealPrediction(self, true, true)
        elseif UnitHealth(u) ~= states.health then
            UnitButton_UpdateHealthStates(self)
            UnitButton_UpdateHealth(self, nil, true)
            UnitButton_UpdateHealPrediction(self, true, true)
        end
    end

    if self._updateRequired and self._indicatorsReady then
        self._updateRequired = nil
        UnitButton_UpdateAll(self)
        self._loggedPendingUpdate = nil
    elseif self._updateRequired then
        if not self._loggedPendingUpdate then
            self._loggedPendingUpdate = true
            F.Debug("Pending update but indicators not ready:", self:GetName(), "unit", states.unit or "nil", "guid", states.guid or "nil")
        end
        --! WotLK fix: this branch is the addon's own detector of a dead button - shown,
        --! carrying a pending full update (OnShow sets _updateRequired), and still
        --! without indicators - and until now it only wrote a debug line. Repair it.
        --! The state is reachable because indicator creation lives exclusively in the
        --! init queue, and the queue is fed from exactly one place: the UpdateIndicators
        --! layout pass. A button the secure header materializes outside that pass is
        --! never enqueued (3.3.5 runs configureChildren on its own schedule, and the
        --! pass itself returns early while Cell.vars.isHidden), so _indicatorsReady
        --! stays nil - and that one flag gates EVERY update path there is
        --! (UnitButton_UpdateAuras, the health poll above, UpdateAll here,
        --! Custom_Classic's UpdateCustomIndicators). The player sees a frame that draws
        --! a name and an empty bar and then never changes again: no health, no auras, no
        --! range fade. Three guards, each load-bearing:
        --!   * `queue[self]` - during a normal layout apply the queue legitimately
        --!     drains two buttons per frame, so a tail button of a 40-man raid is "not
        --!     ready" for dozens of ticks. Those must not be re-enqueued;
        --!   * `_forcedIndicatorInit` - once per button per session. HandleIndicators
        --!     sets _indicatorsReady only at its very end, so an error thrown inside it
        --!     would otherwise re-arm this enqueue every 0.25s forever;
        --!   * `currentLayoutTable` - AddToInitQueue reads its ["indicators"] subtable.
        if not self._forcedIndicatorInit and not queue[self]
        and Cell.vars.currentLayoutTable and Cell.vars.currentLayoutTable["indicators"] then
            self._forcedIndicatorInit = true
            AddToInitQueue(self)
            --! Show() fires the hooksecurefunc that recomputes CellLoadingBar's total,
            --! so calling it on an already-visible updater would jerk the bar backwards
            --! mid-drain. An updater that is already running picks this button up on its
            --! next OnUpdate anyway.
            if not updater:IsShown() then updater:Show() end
        end
    end

    --! for Xtarget
    --! WotLK perf: SpotlightFrame.lua is the only writer of "refreshOnUpdate" and
    --! it only ever writes it to spotlight buttons, so on a party/raid button the
    --! attribute is nil for the whole session and this C call could never answer
    --! anything else. `isSpotlight` is a plain field set once at creation
    --! (SpotlightFrame.lua:272), so the raid buttons now skip the call entirely
    --! and only the spotlight buttons still pay for it.
    if self.isSpotlight and self:GetAttribute("refreshOnUpdate") then
        UnitButton_UpdateAll(self)
    end
end

local function UnitButton_OnUpdate(self, elapsed)
    local e = (self.__updateElapsed or 0) + elapsed
    if e > 0.25 then
        e = 0
        UnitButton_OnTick(self)
        UnitButton_UpdateCombatIcon(self)
    end
    self.__updateElapsed = e
end

-------------------------------------------------
-- button functions
-------------------------------------------------
function B.SetPowerSize(button, size)
    button.powerSize = size

    if size == 0 then
        HidePowerBar(button)
        button._shouldShowPowerBar = false
    else
        button._shouldShowPowerBar = ShouldShowPowerBar(button)
        if button._shouldShowPowerBar then
            ShowPowerBar(button)
        else
            HidePowerBar(button)
        end
    end
    CheckPowerEventRegistration(button)
end

function B.UpdateShields(button)
    predictionEnabled = CellDB["appearance"]["healPrediction"][1]
    -- WotLK 3.3.5a: Heal absorbs don't exist in WotLK (added in Cataclysm+)
    -- Force disable the heal absorb feature for WotLK
    if CellDB["appearance"]["healAbsorb"][1] == nil then
        CellDB["appearance"]["healAbsorb"][1] = false  -- Default to false for WotLK
    end
    absorbEnabled = false  -- Always disabled for WotLK
    absorbInvertColor = CellDB["appearance"]["healAbsorbInvertColor"]
    shieldEnabled = CellDB["appearance"]["shield"][1]
    overshieldEnabled = CellDB["appearance"]["overshield"][1]
    overshieldReverseFillEnabled = shieldEnabled and CellDB["appearance"]["overshieldReverseFill"]

    button.widgets.shieldBar:SetVertexColor(unpack(CellDB["appearance"]["shield"][2]))
    button.widgets.shieldBarR:SetVertexColor(unpack(CellDB["appearance"]["shield"][2]))
    button.widgets.overShieldGlow:SetVertexColor(unpack(CellDB["appearance"]["overshield"][2]))
    button.widgets.overShieldGlowR:SetVertexColor(unpack(CellDB["appearance"]["overshield"][2]))
    -- WotLK 3.3.5a: Skip if absorbsBar doesn't exist (heal absorbs disabled)
    if button.widgets.absorbsBar and button.widgets.overAbsorbGlow then
        if absorbInvertColor then
            button.widgets.absorbsBar:SetVertexColor(F.InvertColor(button.widgets.healthBar:GetStatusBarColor()))
            button.widgets.overAbsorbGlow:SetVertexColor(F.InvertColor(button.widgets.healthBar:GetStatusBarColor()))
        else
            button.widgets.absorbsBar:SetVertexColor(unpack(CellDB["appearance"]["healAbsorb"][2]))
            button.widgets.overAbsorbGlow:SetVertexColor(unpack(CellDB["appearance"]["healAbsorb"][2]))
        end
    end

    UnitButton_UpdateHealPrediction(button)
    --! WotLK fix/perf: UpdateShieldAbsorbs includes the paired heal-absorb
    --! cleanup; a second explicit call only repeated the disabled WotLK branch.
    UnitButton_UpdateShieldAbsorbs(button)
end

function B.SetTexture(button, tex)
    button.widgets.healthBar:SetStatusBarTexture(tex)
    SetBarTextureDrawLayer(button.widgets.healthBar, "ARTWORK", -7)
    button.widgets.healthBarLoss:SetTexture(tex)
    button.widgets.powerBar:SetStatusBarTexture(tex)
    SetBarTextureDrawLayer(button.widgets.powerBar, "ARTWORK", -7)
    button.widgets.powerBarLoss:SetTexture(tex)
    button.widgets.incomingHeal:SetTexture(tex)
    button.widgets.damageFlashTex:SetTexture(tex)
end

function B.UpdateColor(button)
    UnitButton_UpdateHealthColor(button)
    UnitButton_UpdatePowerType(button)
    UnitButton_UpdatePowerTextColor(button)
    button:SetBackdropColor(0, 0, 0, CellDB["appearance"]["bgAlpha"])
end

local function IncomingHeal_SetValue_Horizontal(self, incomingPercent, healthPercent)
    local barWidth = self:GetParent():GetWidth()
    local incomingHealWidth = incomingPercent * barWidth
    local lostHealthWidth = barWidth * (1 - healthPercent)

    -- print(incomingPercent, barWidth, incomingHealWidth, lostHealthWidth)
    -- FIXME: if incomingPercent is a very tiny number, like 0.005
    -- P.Scale(incomingHealWidth) ==> 0
    --! if width is set to 0, then the ACTUAL width may be 256!!!

    if lostHealthWidth == 0 then
        self:Hide()
    else
        if lostHealthWidth > incomingHealWidth then
            self:SetWidth(incomingHealWidth)
        else
            self:SetWidth(lostHealthWidth)
        end
        self:Show()
    end
end

local function ShieldBar_SetValue_Horizontal(self, shieldPercent, healthPercent)
    local barWidth = self:GetParent():GetWidth()
    -- WotLK 3.3.5a: Calculate max available width to prevent overflow beyond health bar
    local maxAvailableWidth = barWidth * (1 - healthPercent)

    if shieldPercent + healthPercent > 1 then -- overshield
        local p = 1 - healthPercent
        if p ~= 0 then
            if shieldEnabled then
                -- Constrain shield width to available space
                --! WotLK perf: math.min -> файловый локал min (шапка, :37). Полоса
                --! щита перерисовывается из CLEU-потока абсорбов, а math.min - это
                --! чтение глобала плюс хеш-лукап поля на каждый вызов.
                local shieldWidth = min(p * barWidth, maxAvailableWidth)
                self:SetWidth(shieldWidth)
                self:Show()
            else
                self:Hide()
            end
        else
            self:Hide()
        end

        if overshieldReverseFillEnabled then
            p = shieldPercent + healthPercent - 1
            if p > healthPercent then p = healthPercent end
            self.shieldBarR:SetWidth(p * barWidth)
            self.shieldBarR:Show()
            if overshieldEnabled then
                self.overShieldGlowR:Show()
            else
                self.overShieldGlowR:Hide()
            end
            self.overShieldGlow:Hide()
        else
            if overshieldEnabled then
                self.overShieldGlow:Show()
            else
                self.overShieldGlow:Hide()
            end
            self.shieldBarR:Hide()
            self.overShieldGlowR:Hide()
        end
    else
        if shieldEnabled then
            -- Constrain shield width to available space
            local shieldWidth = min(shieldPercent * barWidth, maxAvailableWidth)
            self:SetWidth(shieldWidth)
            self:Show()
        else
            self:Hide()
        end
        self.shieldBarR:Hide()
        self.overShieldGlow:Hide()
        self.overShieldGlowR:Hide()
    end
end

local function AbsorbsBar_SetValue_Horizontal(self, absorbsPercent, healthPercent)
    --! WotLK perf: self.healthBar поднят - читался трижды.
    local healthBar = self.healthBar
    local barWidth = healthBar:GetWidth()
    -- WotLK 3.3.5a: Calculate max available width to prevent overflow beyond health bar
    local maxAvailableWidth = barWidth * (1 - healthPercent)

    if absorbInvertColor then
        --! WotLK perf: цвет полосы спрашивался у клиента дважды и дважды же
        --! инвертировался. Теперь один C-вызов и одна инверсия на обе текстуры.
        --! F.InvertColor объявляет три параметра, поэтому четвёртое возвращаемое
        --! значение GetStatusBarColor (alpha) отбрасывалось и раньше - поведение то же.
        local r, g, b = healthBar:GetStatusBarColor()
        local ir, ig, ib = F.InvertColor(r, g, b)
        self:SetVertexColor(ir, ig, ib)
        self.overAbsorbGlow:SetVertexColor(ir, ig, ib)
    end

    --! WotLK perf: обе ветви считали и ставили одну и ту же ширину - вынесено
    --! наверх, различается только показ overAbsorbGlow. math.min заменён файловым
    --! локалом min (объявлен в шапке файла, см. :37): функция зовётся на каждом
    --! перерисовывании абсорбов, то есть из CLEU-потока щитов.
    local absorbWidth = min(absorbsPercent * barWidth, maxAvailableWidth)
    self:SetWidth(absorbWidth)
    self:Show()

    if absorbsPercent > healthPercent then
        self.overAbsorbGlow:Show()
    else
        self.overAbsorbGlow:Hide()
    end
end

local function DamageFlashTex_SetValue_Horizontal(self, lostPercent)
    local barWidth = self:GetParent():GetWidth()
    self:SetWidth(barWidth * lostPercent)
end

local function IncomingHeal_SetValue_Vertical(self, incomingPercent, healthPercent)
    local barHeight = self:GetParent():GetHeight()
    local incomingHealHeight = incomingPercent * barHeight
    local lostHealthHeight = barHeight * (1 - healthPercent)

    if lostHealthHeight == 0 then
        self:Hide()
    else
        if lostHealthHeight > incomingHealHeight then
            self:SetHeight(incomingHealHeight)
        else
            self:SetHeight(lostHealthHeight)
        end
        self:Show()
    end
end

local function ShieldBar_SetValue_Vertical(self, shieldPercent, healthPercent)
    local barHeight = self:GetParent():GetHeight()
    -- WotLK 3.3.5a: Calculate max available height to prevent overflow beyond health bar
    local maxAvailableHeight = barHeight * (1 - healthPercent)

    if shieldPercent + healthPercent > 1 then -- overshield
        local p = 1 - healthPercent
        if p ~= 0 then
            if shieldEnabled then
                -- Constrain shield height to available space
                local shieldHeight = min(p * barHeight, maxAvailableHeight)
                self:SetHeight(shieldHeight)
                self:Show()
            else
                self:Hide()
            end
        else
            self:Hide()
        end

        if overshieldReverseFillEnabled then
            p = shieldPercent + healthPercent - 1
            if p > healthPercent then p = healthPercent end
            self.shieldBarR:SetHeight(p * barHeight)
            self.shieldBarR:Show()
            if overshieldEnabled then
                self.overShieldGlowR:Show()
            else
                self.overShieldGlowR:Hide()
            end
            self.overShieldGlow:Hide()
        else
            if overshieldEnabled then
                self.overShieldGlow:Show()
            else
                self.overShieldGlow:Hide()
            end
            self.shieldBarR:Hide()
            self.overShieldGlowR:Hide()
        end
    else
        if shieldEnabled then
            -- Constrain shield height to available space
            local shieldHeight = min(shieldPercent * barHeight, maxAvailableHeight)
            self:SetHeight(shieldHeight)
            self:Show()
        else
            self:Hide()
        end
        self.shieldBarR:Hide()
        self.overShieldGlow:Hide()
        self.overShieldGlowR:Hide()
    end
end

local function AbsorbsBar_SetValue_Vertical(self, absorbsPercent, healthPercent)
    --! WotLK perf: тот же набор приёмов, что в горизонтальной версии.
    local healthBar = self.healthBar
    local barHeight = healthBar:GetHeight()
    -- WotLK 3.3.5a: Calculate max available height to prevent overflow beyond health bar
    local maxAvailableHeight = barHeight * (1 - healthPercent)

    if absorbInvertColor then
        local r, g, b = healthBar:GetStatusBarColor()
        local ir, ig, ib = F.InvertColor(r, g, b)
        self:SetVertexColor(ir, ig, ib)
        self.overAbsorbGlow:SetVertexColor(ir, ig, ib)
    end

    local absorbHeight = min(absorbsPercent * barHeight, maxAvailableHeight)
    self:SetHeight(absorbHeight)
    self:Show()

    if absorbsPercent > healthPercent then
        self.overAbsorbGlow:Show()
    else
        self.overAbsorbGlow:Hide()
    end
end

local function DamageFlashTex_SetValue_Vertical(self, lostPercent)
    local barHeight = self:GetParent():GetHeight()
    self:SetHeight(barHeight * lostPercent)
end

function B.SetOrientation(button, orientation, rotateTexture)
    local healthBar = button.widgets.healthBar
    local healthBarLoss = button.widgets.healthBarLoss
    local powerBar = button.widgets.powerBar
    local powerBarLoss = button.widgets.powerBarLoss
    local incomingHeal = button.widgets.incomingHeal
    local damageFlashTex = button.widgets.damageFlashTex
    local gapTexture = button.widgets.gapTexture
    local shieldBar = button.widgets.shieldBar
    local shieldBarR = button.widgets.shieldBarR
    local overShieldGlow = button.widgets.overShieldGlow
    local overShieldGlowR = button.widgets.overShieldGlowR
    local absorbsBar = button.widgets.absorbsBar
    local overAbsorbGlow = button.widgets.overAbsorbGlow

    --! WotLK fix: SetColorTexture на 3.3.5 нет - это нативная числовая форма
    --! SetTexture(r, g, b[, a]); шим TextureBase в WidgetAPI удалён.
    gapTexture:SetTexture(unpack(CELL_BORDER_COLOR))

    button.orientation = orientation
    if orientation == "vertical_health" then
        healthBar:SetOrientation("vertical")
        powerBar:SetOrientation("horizontal")
    else
        healthBar:SetOrientation(orientation)
        powerBar:SetOrientation(orientation)
    end
    healthBar:SetRotatesTexture(rotateTexture)
    powerBar:SetRotatesTexture(rotateTexture)

    if button.indicators.healthThresholds then
        button.indicators.healthThresholds:SetOrientation(orientation)
    end

    if rotateTexture then
        F.RotateTexture(healthBarLoss, 90)
        F.RotateTexture(powerBarLoss, 90)
        F.RotateTexture(incomingHeal, 90)
        F.RotateTexture(damageFlashTex, 90)
    else
        F.RotateTexture(healthBarLoss, 0)
        F.RotateTexture(powerBarLoss, 0)
        F.RotateTexture(incomingHeal, 0)
        F.RotateTexture(damageFlashTex, 0)
    end

    if orientation == "horizontal" then
        -- update healthBarLoss
        P.ClearPoints(healthBarLoss)
        P.Point(healthBarLoss, "TOPRIGHT", healthBar)
        P.Point(healthBarLoss, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")

        -- update powerBarLoss
        P.ClearPoints(powerBarLoss)
        P.Point(powerBarLoss, "TOPRIGHT", powerBar)
        P.Point(powerBarLoss, "BOTTOMLEFT", powerBar:GetStatusBarTexture(), "BOTTOMRIGHT")

        -- update gapTexture
        P.ClearPoints(gapTexture)
        P.Point(gapTexture, "BOTTOMLEFT", powerBar, "TOPLEFT")
        P.Point(gapTexture, "BOTTOMRIGHT", powerBar, "TOPRIGHT")
        P.Height(gapTexture, CELL_BORDER_SIZE)

        -- update incomingHeal
        incomingHeal.SetValue = IncomingHeal_SetValue_Horizontal
        P.ClearPoints(incomingHeal)
        P.Point(incomingHeal, "TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
        P.Point(incomingHeal, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")

        -- update shieldBar
        shieldBar.SetValue = ShieldBar_SetValue_Horizontal
        P.ClearPoints(shieldBar)
        P.Point(shieldBar, "TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
        P.Point(shieldBar, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")

        -- update shieldBarR
        P.ClearPoints(shieldBarR)
        P.Point(shieldBarR, "TOPRIGHT", healthBar:GetStatusBarTexture())
        P.Point(shieldBarR, "BOTTOMRIGHT", healthBar:GetStatusBarTexture())

        -- update overShieldGlow
        P.ClearPoints(overShieldGlow)
        P.Point(overShieldGlow, "TOPRIGHT")
        P.Point(overShieldGlow, "BOTTOMRIGHT")
        P.Width(overShieldGlow, 4)
        F.RotateTexture(overShieldGlow, 0)

        -- update overShieldGlowR
        P.ClearPoints(overShieldGlowR)
        P.Point(overShieldGlowR, "TOP", shieldBarR, "TOPLEFT", 0, 0)
        P.Point(overShieldGlowR, "BOTTOM", shieldBarR, "BOTTOMLEFT", 0, 0)
        P.Width(overShieldGlowR, 8)
        F.RotateTexture(overShieldGlowR, 0)

        -- update absorbsBar
        -- WotLK 3.3.5a: Skip if absorbsBar doesn't exist (heal absorbs disabled)
        if absorbsBar then
            absorbsBar.SetValue = AbsorbsBar_SetValue_Horizontal
            P.ClearPoints(absorbsBar)
            P.Point(absorbsBar, "TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
            P.Point(absorbsBar, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
        end

        -- update overAbsorbGlow
        if overAbsorbGlow then
            P.ClearPoints(overAbsorbGlow)
            P.Point(overAbsorbGlow, "TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
            P.Point(overAbsorbGlow, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
            P.Width(overAbsorbGlow, 8)
            F.RotateTexture(overAbsorbGlow, 0)
        end

        -- update damageFlashTex
        damageFlashTex.SetValue = DamageFlashTex_SetValue_Horizontal
        P.ClearPoints(damageFlashTex)
        P.Point(damageFlashTex, "TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
        P.Point(damageFlashTex, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")

    else -- vertical / vertical_health
        P.ClearPoints(healthBarLoss)
        P.Point(healthBarLoss, "TOPRIGHT", healthBar)
        P.Point(healthBarLoss, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "TOPLEFT")

        if orientation == "vertical" then
            -- update powerBarLoss
            P.ClearPoints(powerBarLoss)
            P.Point(powerBarLoss, "TOPRIGHT", powerBar)
            P.Point(powerBarLoss, "BOTTOMLEFT", powerBar:GetStatusBarTexture(), "TOPLEFT")

            -- update gapTexture
            P.ClearPoints(gapTexture)
            P.Point(gapTexture, "TOPRIGHT", powerBar, "TOPLEFT")
            P.Point(gapTexture, "BOTTOMRIGHT", powerBar, "BOTTOMLEFT")
            P.Width(gapTexture, CELL_BORDER_SIZE)
        else -- vertical_health
            -- update powerBarLoss
            P.ClearPoints(powerBarLoss)
            P.Point(powerBarLoss, "TOPRIGHT", powerBar)
            P.Point(powerBarLoss, "BOTTOMLEFT", powerBar:GetStatusBarTexture(), "BOTTOMRIGHT")

            -- update gapTexture
            P.ClearPoints(gapTexture)
            P.Point(gapTexture, "BOTTOMLEFT", powerBar, "TOPLEFT")
            P.Point(gapTexture, "BOTTOMRIGHT", powerBar, "TOPRIGHT")
            P.Height(gapTexture, CELL_BORDER_SIZE)
        end

        -- update incomingHeal
        incomingHeal.SetValue = IncomingHeal_SetValue_Vertical
        P.ClearPoints(incomingHeal)
        P.Point(incomingHeal, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "TOPLEFT")
        P.Point(incomingHeal, "BOTTOMRIGHT", healthBar:GetStatusBarTexture(), "TOPRIGHT")

        -- update shieldBar
        shieldBar.SetValue = ShieldBar_SetValue_Vertical
        P.ClearPoints(shieldBar)
        P.Point(shieldBar, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "TOPLEFT")
        P.Point(shieldBar, "BOTTOMRIGHT", healthBar:GetStatusBarTexture(), "TOPRIGHT")

        -- update shieldBarR
        P.ClearPoints(shieldBarR)
        P.Point(shieldBarR, "TOPLEFT", healthBar:GetStatusBarTexture())
        P.Point(shieldBarR, "TOPRIGHT", healthBar:GetStatusBarTexture())

        -- update overShieldGlow
        P.ClearPoints(overShieldGlow)
        P.Point(overShieldGlow, "TOPLEFT")
        P.Point(overShieldGlow, "TOPRIGHT")
        P.Height(overShieldGlow, 4)
        F.RotateTexture(overShieldGlow, 90)

        -- update overShieldGlowR
        P.ClearPoints(overShieldGlowR)
        P.Point(overShieldGlowR, "LEFT", shieldBarR, "BOTTOMLEFT", 0, 0)
        P.Point(overShieldGlowR, "RIGHT", shieldBarR, "BOTTOMRIGHT", 0, 0)
        P.Height(overShieldGlowR, 8)
        F.RotateTexture(overShieldGlowR, 90)

        -- update absorbsBar
        -- WotLK 3.3.5a: Skip if absorbsBar doesn't exist (heal absorbs disabled)
        if absorbsBar then
            absorbsBar.SetValue = AbsorbsBar_SetValue_Vertical
            P.ClearPoints(absorbsBar)
            P.Point(absorbsBar, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "TOPLEFT")
            P.Point(absorbsBar, "BOTTOMRIGHT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
        end

        -- update overAbsorbGlow
        if overAbsorbGlow then
            P.ClearPoints(overAbsorbGlow)
            P.Point(overAbsorbGlow, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "TOPLEFT")
            P.Point(overAbsorbGlow, "BOTTOMRIGHT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
            P.Height(overAbsorbGlow, 8)
            F.RotateTexture(overAbsorbGlow, 90)
        end

        -- update damageFlashTex
        damageFlashTex.SetValue = DamageFlashTex_SetValue_Vertical
        P.ClearPoints(damageFlashTex)
        P.Point(damageFlashTex, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "TOPLEFT")
        P.Point(damageFlashTex, "BOTTOMRIGHT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
    end

    -- update actions
    I.UpdateActionsOrientation(button, orientation)
end

function B.UpdateHighlightColor(button)
    button.widgets.targetHighlight:SetBackdropBorderColor(unpack(CellDB["appearance"]["targetColor"]))
    button.widgets.mouseoverHighlight:SetBackdropBorderColor(unpack(CellDB["appearance"]["mouseoverColor"]))
end

function B.UpdateHighlightSize(button)
    local targetHighlight = button.widgets.targetHighlight
    local mouseoverHighlight = button.widgets.mouseoverHighlight

    -- WotLK Fix: Some button types don't have highlight widgets
    if not targetHighlight or not mouseoverHighlight then return end

    local size = CellDB["appearance"]["highlightSize"]

    if size ~= 0 then
        highlightEnabled = true

        P.ClearPoints(targetHighlight)
        P.ClearPoints(mouseoverHighlight)

        -- update point
        if size < 0 then
            size = abs(size)
            P.Point(targetHighlight, "TOPLEFT", button, "TOPLEFT")
            P.Point(targetHighlight, "BOTTOMRIGHT", button, "BOTTOMRIGHT")
            P.Point(mouseoverHighlight, "TOPLEFT", button, "TOPLEFT")
            P.Point(mouseoverHighlight, "BOTTOMRIGHT", button, "BOTTOMRIGHT")
        else
            P.Point(targetHighlight, "TOPLEFT", button, "TOPLEFT", -size, size)
            P.Point(targetHighlight, "BOTTOMRIGHT", button, "BOTTOMRIGHT", size, -size)
            P.Point(mouseoverHighlight, "TOPLEFT", button, "TOPLEFT", -size, size)
            P.Point(mouseoverHighlight, "BOTTOMRIGHT", button, "BOTTOMRIGHT", size, -size)
        end

        -- update thickness
        targetHighlight:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(size)})
        mouseoverHighlight:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(size)})

        -- update color
        targetHighlight:SetBackdropBorderColor(unpack(CellDB["appearance"]["targetColor"]))
        mouseoverHighlight:SetBackdropBorderColor(unpack(CellDB["appearance"]["mouseoverColor"]))

        UnitButton_UpdateTarget(button) -- 0->!0 show highlight again
    else
        highlightEnabled = false
        targetHighlight:Hide()
        mouseoverHighlight:Hide()
    end
end

-- raidIcons
function B.UpdatePlayerRaidIcon(button, enabled)
    if not button:IsShown() then return end
    UnitButton_UpdatePlayerRaidIcon(button)
    if enabled then
        button:RegisterEvent("RAID_TARGET_UPDATE")
    else
        button:UnregisterEvent("RAID_TARGET_UPDATE")
    end
end

function B.UpdateTargetRaidIcon(button, enabled)
    if not button:IsShown() then return end
    UnitButton_UpdateTargetRaidIcon(button)
    --! WotLK perf: UNIT_TARGET is a unit event, so it is toggled on the central
    --! dispatcher. `enabled` is one global option, so every button passes the same
    --! value and the repeated calls are idempotent - no refcount needed.
    if enabled then
        unitEventFrame:RegisterEvent("UNIT_TARGET")
    else
        unitEventFrame:UnregisterEvent("UNIT_TARGET")
    end
end

-- readyCheckIcon
function B.UpdateReadyCheckIcon(button, enabled)
    if not button:IsShown() then return end
    UnitButton_UpdateReadyCheck(button)
    if enabled then
        button:RegisterEvent("READY_CHECK")
        button:RegisterEvent("READY_CHECK_FINISHED")
        button:RegisterEvent("READY_CHECK_CONFIRM")
    else
        button:UnregisterEvent("READY_CHECK")
        button:UnregisterEvent("READY_CHECK_FINISHED")
        button:UnregisterEvent("READY_CHECK_CONFIRM")
    end
end

-- healthText
function B.UpdateHealthText(button)
    if button.states.displayedUnit then
        UnitButton_UpdateHealthStates(button)
    end
end

-- powerText
function B.UpdatePowerText(button)
    if button.states.displayedUnit then
        UnitButton_UpdatePowerStates(button)
        UnitButton_UpdatePowerText(button)
        UnitButton_UpdatePowerTextColor(button)
    end
end

-- statusText
function B.UpdateStatusText(button)
    UnitButton_UpdateStatusText(button)
end

-- shields
function B.UpdateShield(button)
    UnitButton_UpdateShieldAbsorbs(button)
end

-- animation
function B.UpdateAnimation(button)
    barAnimationType = CellDB["appearance"]["barAnimation"]

    if barAnimationType == "Smooth" then
        button.widgets.healthBar.SetBarValue = button.widgets.healthBar.SetSmoothedValue
        button.widgets.powerBar.SetBarValue = button.widgets.powerBar.SetSmoothedValue
    else
        button.widgets.healthBar:ResetSmoothedValue()
        button.widgets.healthBar.SetBarValue = button.widgets.healthBar.SetValue
        button.widgets.powerBar:ResetSmoothedValue()
        button.widgets.powerBar.SetBarValue = button.widgets.powerBar.SetValue

        --! WotLK fix: ResetSmoothedValue re-applies the pending target, and that target
        --! can be exactly zero - a bar parked on its minimum keeps the stale fill rect
        --! (see UnitButton_UpdateHealth). Nudge it off the minimum here, otherwise
        --! switching the bar animation away from "Smooth" leaves a unit that is at
        --! 0 health or 0 power with mid-bar anchors until its next update.
        if button.states.health == 0 then button.widgets.healthBar:SetValue(0.0001) end
        if button.states.power == 0 then button.widgets.powerBar:SetValue(0.0001) end
    end

    if barAnimationType ~= "Flash" then
        button.widgets.damageFlashAG:Finish()
    end
end

-- damageFlash
function B.ShowFlash(button, lostPercent)
    button.widgets.damageFlashTex:SetValue(lostPercent)
    button.widgets.damageFlashAG:Play()
end

function B.HideFlash(button)
    button.widgets.damageFlashAG:Finish()
end

-- backdrop
function B.UpdateBackdrop(button)
    if CELL_BORDER_SIZE == 0 then
        button:SetBackdrop({bgFile = Cell.vars.whiteTexture})
        button:SetBackdropColor(0, 0, 0, CellDB["appearance"]["bgAlpha"])
    else
        button:SetBackdrop({bgFile = Cell.vars.whiteTexture, edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(CELL_BORDER_SIZE)})
        button:SetBackdropColor(0, 0, 0, CellDB["appearance"]["bgAlpha"])
        button:SetBackdropBorderColor(unpack(CELL_BORDER_COLOR))
    end
end

-- pixel perfect
function B.UpdatePixelPerfect(button, updateIndicators)
    if not InCombatLockdown() then P.Resize(button) end
    P.Reborder(button)

    P.Repoint(button.widgets.healthBar)
    P.Repoint(button.widgets.healthBarLoss)
    P.Repoint(button.widgets.powerBar)
    P.Repoint(button.widgets.powerBarLoss)
    P.Repoint(button.widgets.gapTexture)
    P.Resize(button.widgets.gapTexture)

    P.Repoint(button.widgets.incomingHeal)
    P.Repoint(button.widgets.shieldBar)
    if button.widgets.absorbsBar then
        P.Repoint(button.widgets.absorbsBar)
        P.Repoint(button.widgets.overAbsorbGlow)
        P.Resize(button.widgets.overAbsorbGlow)
    end
    P.Repoint(button.widgets.damageFlashTex)

    P.Resize(button.widgets.overShieldGlow)
    P.Repoint(button.widgets.overShieldGlow)

    B.UpdateHighlightSize(button)
    B.UpdateBackdrop(button)

    if updateIndicators then
        -- indicators
        for _, i in pairs(button.indicators) do
            if i.UpdatePixelPerfect then
                i:UpdatePixelPerfect()
            end
        end
    end

    -- WotLK Fix: Some button types don't have srIcon widget
    if button.widgets.srIcon then
        button.widgets.srIcon:UpdatePixelPerfect()
    end
end

B.UpdateAll = UnitButton_UpdateAll
B.UpdateHealth = UnitButton_UpdateHealth
B.UpdateHealthMax = UnitButton_UpdateHealthMax
B.UpdateAuras = UnitButton_UpdateAuras
B.UpdateName = UnitButton_UpdateName

-------------------------------------------------
-- unit button init
-------------------------------------------------
-- local startTimeCache, statusCache = {}, {}

-- Layers ---------------------------------------
-- OVERLAY
-- ARTWORK
--  -2 overAbsorbGlow
--  -3 absorbsBar
--  -4 overShieldGlow, overShieldGlowR
--  -5 shieldBar, shieldBarR
--	-6 incomingHeal, damageFlashTex
--	-7 healthBar, healthBarLoss
-- BORDER
--  0 gapTexture
-- BACKGROUND
-------------------------------------------------

-- NOTE: prevent a nil method error
local DumbFunc = function() end

function CellUnitButton_OnLoad(button)
    local name = button:GetName()

    --! Keep mouse interaction enabled on header-generated secure buttons; some
    --! WotLK header update paths can leave raid buttons non-interactive.
    button:EnableMouse(true)

    --! WotLK 3.3.5a: Auto-register raid buttons created by SecureGroupHeader
    if name and name:find("CellRaidFrame") then
        local parent = button:GetParent()
        if parent and parent:GetName() and parent:GetName():find("CellRaidFrameHeader") then
            local id = name:match("UnitButton(%d+)")
            if id then
                id = tonumber(id)
                if not parent[id] then
                    parent[id] = button
                    RegisterUnitWatch(button)
                    
                    -- OmniCD support
                    _G[name] = button
                end
            end
        end
    end

    button.widgets = {}
    button.states = {}
    button.indicators = {}

    InitAuraTables(button)

    -- background
    -- local background = button:CreateTexture(name.."Background", "BORDER")
    -- button.widgets.background = background
    -- background:SetAllPoints(button)
    -- background:SetTexture(Cell.vars.whiteTexture)
    -- background:SetVertexColor(0, 0, 0, 1)

    -- backdrop
    -- button:SetBackdrop({bgFile = Cell.vars.whiteTexture, edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(CELL_BORDER_SIZE)})
    -- button:SetBackdropColor(0, 0, 0, 1)
    -- button:SetBackdropBorderColor(unpack(CELL_BORDER_COLOR))

    -- healthbar
    local healthBar = CreateFrame("StatusBar", name.."HealthBar", button)
    button.widgets.healthBar = healthBar
    healthBar.SetBarValue = healthBar.SetValue
    healthBar:SetStatusBarTexture(Cell.vars.texture)
    SetBarTextureDrawLayer(healthBar, "ARTWORK", -7)
    healthBar:SetFrameLevel(button:GetFrameLevel()+1)

    -- hp loss
    local healthBarLoss = button:CreateTexture(name.."HealthBarLoss", "ARTWORK", nil , -7)
    button.widgets.healthBarLoss = healthBarLoss
    -- P.Point(healthBarLoss, "TOPRIGHT", healthBar)
    -- P.Point(healthBarLoss, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    healthBarLoss:SetTexture(Cell.vars.texture)

    -- powerbar
    local powerBar = CreateFrame("StatusBar", name.."PowerBar", button)
    button.widgets.powerBar = powerBar
    powerBar.SetBarValue = powerBar.SetValue
    powerBar:SetStatusBarTexture(Cell.vars.texture)
    SetBarTextureDrawLayer(powerBar, "ARTWORK", -7)
    powerBar:SetFrameLevel(button:GetFrameLevel()+2)

    --! WotLK fix: install Cell-owned smoothing methods directly on these bars;
    --! do not consume or replace a global SmoothStatusBarMixin.
    AttachCellSmoothing(healthBar)
    AttachCellSmoothing(powerBar)

    local gapTexture = button:CreateTexture(nil, "BORDER")
    button.widgets.gapTexture = gapTexture
    -- P.Point(gapTexture, "BOTTOMLEFT", powerBar, "TOPLEFT")
    -- P.Point(gapTexture, "BOTTOMRIGHT", powerBar, "TOPRIGHT")
    -- P.Height(gapTexture, 1)
    gapTexture:SetTexture(unpack(CELL_BORDER_COLOR))

    -- power loss
    local powerBarLoss = button:CreateTexture(name.."PowerBarLoss", "ARTWORK", nil , -7)
    button.widgets.powerBarLoss = powerBarLoss
    -- P.Point(powerBarLoss, "TOPRIGHT", powerBar)
    -- P.Point(powerBarLoss, "BOTTOMLEFT", powerBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    powerBarLoss:SetTexture(Cell.vars.texture)

    -- incoming heal
    local incomingHeal = healthBar:CreateTexture(name.."IncomingHealBar", "ARTWORK", nil, -6)
    button.widgets.incomingHeal = incomingHeal
    incomingHeal:SetTexture(Cell.vars.texture)
    incomingHeal:Hide()
    incomingHeal.SetValue = DumbFunc

    --* indicatorFrame
    local indicatorFrame = CreateFrame("Frame", name.."IndicatorFrame", button)
    button.widgets.indicatorFrame = indicatorFrame
    -- 3.3.5: frame level cap is 128 (retail offsets +120..+220 overflow and
    -- collapse into one level, breaking draw order). Compressed scheme keeps
    -- the same relative order: mid(+20) < high(+30) < glows(+40) < indicators(+50).
    indicatorFrame:SetFrameLevel(button:GetFrameLevel()+50)
    indicatorFrame:SetAllPoints(button)

    --* tsGlowFrame (Targeted Spells)
    local tsGlowFrame = CreateFrame("Frame", name.."TSGlowFrame", button)
    button.widgets.tsGlowFrame = tsGlowFrame
    tsGlowFrame:SetFrameLevel(button:GetFrameLevel()+40) -- 3.3.5: was +200, level cap is 128
    tsGlowFrame:SetAllPoints(button)

    --* srGlowFrame (Spell Request)
    local srGlowFrame = CreateFrame("Frame", name.."SRGlowFrame", button)
    button.widgets.srGlowFrame = srGlowFrame
    srGlowFrame:SetFrameLevel(button:GetFrameLevel()+40) -- 3.3.5: was +200, level cap is 128
    srGlowFrame:SetAllPoints(button)

    --* drGlowFrame (Dispel Request)
    local drGlowFrame = CreateFrame("Frame", name.."DRGlowFrame", button)
    button.widgets.drGlowFrame = drGlowFrame
    drGlowFrame:SetFrameLevel(button:GetFrameLevel()+40) -- 3.3.5: was +200, level cap is 128
    drGlowFrame:SetAllPoints(button)

    --* highLevelFrame
    local highLevelFrame = CreateFrame("Frame", name.."HighLevelFrame", button)
    button.widgets.highLevelFrame = highLevelFrame
    highLevelFrame:SetFrameLevel(button:GetFrameLevel()+30) -- 3.3.5: was +140, level cap is 128
    highLevelFrame:SetAllPoints(button)

    --* midLevelFrame
    local midLevelFrame = CreateFrame("Frame", name.."MidLevelFrame", button)
    button.widgets.midLevelFrame = midLevelFrame
    midLevelFrame:SetFrameLevel(button:GetFrameLevel()+20) -- 3.3.5: was +120, level cap is 128
    midLevelFrame:SetAllPoints(healthBar)

    -- shield bar
    local shieldBar = midLevelFrame:CreateTexture(name.."ShieldBar", "ARTWORK", nil, -5)
    button.widgets.shieldBar = shieldBar
    shieldBar:SetTexture("Interface\\AddOns\\Cell\\Media\\shield.tga", "REPEAT", "REPEAT")
    shieldBar:SetHorizTile(true)
    shieldBar:SetVertTile(true)
    shieldBar:SetVertexColor(1, 1, 1, 0.4)
    shieldBar:Hide()
    shieldBar.SetValue = DumbFunc

    local shieldBarR = midLevelFrame:CreateTexture(name.."ShieldBarR", "ARTWORK", nil, -5)
    button.widgets.shieldBarR = shieldBarR
    shieldBarR:SetTexture("Interface\\AddOns\\Cell\\Media\\shield", "REPEAT", "REPEAT")
    shieldBarR:SetHorizTile(true)
    shieldBarR:SetVertTile(true)
    shieldBarR:Hide()
    shieldBar.shieldBarR = shieldBarR

    -- over-shield glow
    local overShieldGlow = midLevelFrame:CreateTexture(name.."OverShieldGlow", "ARTWORK", nil, -4)
    button.widgets.overShieldGlow = overShieldGlow
    overShieldGlow:SetTexture("Interface\\AddOns\\Cell\\Media\\overshield")
    overShieldGlow:Hide()
    shieldBar.overShieldGlow = overShieldGlow

    -- over-shield glow reversed
    local overShieldGlowR = midLevelFrame:CreateTexture(name.."OverShieldGlowR", "ARTWORK", nil, -4)
    button.widgets.overShieldGlowR = overShieldGlowR
    overShieldGlowR:SetTexture("Interface\\AddOns\\Cell\\Media\\overshield_reversed")
    -- overShieldGlowR:SetBlendMode("ADD")
    overShieldGlowR:Hide()
    shieldBar.overShieldGlowR = overShieldGlowR

    -- WotLK 3.3.5a: Heal absorbs don't exist in WotLK, so don't create these widgets
    -- This saves resources and prevents the heal absorb bar from ever showing
    -- (Kept as comments for compatibility if porting to other expansions)
    --[[
    -- over-absorb glow
    local overAbsorbGlow = midLevelFrame:CreateTexture(name.."OverAbsorbGlow", "ARTWORK", nil, -2)
    button.widgets.overAbsorbGlow = overAbsorbGlow
    overAbsorbGlow:SetTexture("Interface\\AddOns\\Cell\\Media\\overabsorb")
    -- overAbsorbGlow:SetBlendMode("ADD")
    overAbsorbGlow:Hide()

    -- absorbs bar
    local absorbsBar = midLevelFrame:CreateTexture(name.."AbsorbsBar", "ARTWORK", nil, 1)
    button.widgets.absorbsBar = absorbsBar
    absorbsBar.healthBar = healthBar
    absorbsBar:SetTexture("Interface\\AddOns\\Cell\\Media\\shield.tga", "REPEAT", "REPEAT")
    absorbsBar:SetHorizTile(true)
    absorbsBar:SetVertTile(true)
    absorbsBar:SetVertexColor(1, 0.1, 0.1, 1)
    -- absorbsBar:SetBlendMode("ADD")
    absorbsBar:Hide()
    absorbsBar.SetValue = DumbFunc
    absorbsBar.overAbsorbGlow = overAbsorbGlow
    --]]

    -- bar animation
    -- flash
    local damageFlashTex = healthBar:CreateTexture(name.."DamageFlash", "ARTWORK", nil, -6)
    button.widgets.damageFlashTex = damageFlashTex
    damageFlashTex:SetTexture(Cell.vars.whiteTexture)
    damageFlashTex:SetVertexColor(1, 1, 1, 0.7)
    -- P.Point(damageFlashTex, "TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
    -- P.Point(damageFlashTex, "BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    damageFlashTex:Hide()
    damageFlashTex.SetValue = DumbFunc

    -- damage flash animation group
    local damageFlashAG = damageFlashTex:CreateAnimationGroup()
    button.widgets.damageFlashAG = damageFlashAG

    local alpha = damageFlashAG:CreateAnimation("Alpha")
    alpha:SetChange(-0.7)
    alpha:SetDuration(0.2)

    damageFlashAG:SetScript("OnPlay", function(self)
        damageFlashTex:Show()
    end)
    damageFlashAG:SetScript("OnFinished", function(self)
        damageFlashTex:Hide()
    end)
    -- target highlight
    local targetHighlight = CreateFrame("Frame", name.."TargetHighlight", button)
    button.widgets.targetHighlight = targetHighlight
    targetHighlight:EnableMouse(false)
    targetHighlight:SetFrameLevel(button:GetFrameLevel()+3)
    -- targetHighlight:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
    -- P.Point(targetHighlight, "TOPLEFT", button, "TOPLEFT", -1, 1)
    -- P.Point(targetHighlight, "BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    targetHighlight:Hide()

    -- mouseover highlight
    local mouseoverHighlight = CreateFrame("Frame", name.."MouseoverHighlight", button)
    button.widgets.mouseoverHighlight = mouseoverHighlight
    mouseoverHighlight:EnableMouse(false)
    mouseoverHighlight:SetFrameLevel(button:GetFrameLevel()+4)
    -- mouseoverHighlight:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
    -- P.Point(mouseoverHighlight, "TOPLEFT", button, "TOPLEFT", -1, 1)
    -- P.Point(mouseoverHighlight, "BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    mouseoverHighlight:Hide()

    -- readyCheck highlight
    -- local readyCheckHighlight = button:CreateTexture(name.."ReadyCheckHighlight", "BACKGROUND")
    -- button.widgets.readyCheckHighlight = readyCheckHighlight
    -- readyCheckHighlight:SetPoint("TOPLEFT", -1, 1)
    -- readyCheckHighlight:SetPoint("BOTTOMRIGHT", 1, -1)
    -- readyCheckHighlight:SetTexture(Cell.vars.whiteTexture)
    -- readyCheckHighlight:Hide()

    -- aggro bar
    local aggroBar = Cell.CreateStatusBar(name.."AggroBar", indicatorFrame, 20, 4, 100, true)
    button.indicators.aggroBar = aggroBar
    aggroBar:Hide()

    -- indicators
    I.CreateNameText(button)
    I.CreateStatusText(button)
    I.CreateHealthText(button)
    I.CreatePowerText(button)
    I.CreateStatusIcon(button)
    I.CreateRoleIcon(button)
    I.CreateLeaderIcon(button)
    I.CreateCombatIcon(button)
    I.CreateReadyCheckIcon(button)
    I.CreateAggroBlink(button)
    I.CreateAggroBorder(button)
    I.CreatePlayerRaidIcon(button)
    I.CreateTargetRaidIcon(button)
    I.CreateShieldBar(button)
    I.CreateAoEHealing(button)
    -- I.CreateDefensiveCooldowns(button)
    -- I.CreateExternalCooldowns(button)
    -- I.CreateAllCooldowns(button)
    -- I.CreateDebuffs(button)
    I.CreateDispels(button)
    I.CreateRaidDebuffs(button)
    I.CreateTargetedSpells(button)
    I.CreateActions(button)
    I.CreateMissingBuffs(button)
    I.CreateHealthThresholds(button)
    I.CreatePowerWordShield(button)
    U.CreateSpellRequestIcon(button)
    I.CreateCrowdControls(button)
    U.CreateDispelRequestText(button)

    button._waitingForIndicatorCreation = true

    -- events
    button:SetScript("OnAttributeChanged", UnitButton_OnAttributeChanged) -- init
    button:HookScript("OnShow", UnitButton_OnShow)
    button:HookScript("OnHide", UnitButton_OnHide) -- use _onhide for click-castings
    button:HookScript("OnEnter", UnitButton_OnEnter) -- SecureHandlerEnterLeaveTemplate
    button:HookScript("OnLeave", UnitButton_OnLeave) -- SecureHandlerEnterLeaveTemplate
    button:SetScript("OnUpdate", UnitButton_OnUpdate)
    button:SetScript("OnEvent", UnitButton_OnEvent)
    button:RegisterForClicks("AnyDown")
end

-------------------------------------------------
-- LibGroupInfo -> live role updates (WotLK)
-------------------------------------------------
--! WotLK fix: nothing in Cell consumed LibGroupInfo's "GroupInfo_Update"
--! callback, so roles resolved asynchronously (inspect queue finishing, or
--! the player swapping dual spec) never reached the unit buttons:
--! states.role kept its stale value until some unrelated full update, and
--! TANK/HEALER power filters + the role icon looked dead. Refresh the
--! affected button(s) as soon as fresh spec info arrives.
do
    local LGI = LibStub and LibStub:GetLibrary("LibGroupInfo", true)
    --! WotLK fix: `not Cell.isRetail` вырезано - флаг задан литералом false
    --! в Utils.lua, ветка решалась статически.
    if LGI then
        LGI.RegisterCallback("CellUnitButton_RoleUpdate", "GroupInfo_Update", function(_, guid)
            if not Cell.loaded then return end
            F.HandleUnitButton("guid", guid, UnitButton_RoleChanged)
        end)
    end
end
