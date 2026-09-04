--! Cell: this is a private, trimmed fork of Tsoukie's ClassicAPI.
--! WotLK fix: the `if IsAddOnLoaded("!!!ClassicAPI") then return end` guard that used to
--! stand here is gone. Cell is a public addon, so both environments are real and the guard
--! only ever fired in one of them:
--!   * standalone !!!ClassicAPI absent  -> guard never fired, this file already installed its
--!     additive subset (audited runs 6/9/10/11: changed 0 / added 16, zero Lua errors;
--!     those runs predate the SetAtlas removal and the dormant-method purge — the manifest
--!     installs 2 methods today, and the count is pinned by global_hook_ownership_smoke.py);
--!   * standalone !!!ClassicAPI present -> guard fired, Cell installed nothing at all and
--!     silently depended on a foreign addon's version of every method it calls.
--! The second shape is what CLAUDE.md rule 3 forbids: an early exit hands the hot path to
--! someone else's copy and rolls back this backport's own fixes. Process() below is additive
--! only (`if Metatable[Method] == nil`), so with the foreign addon loaded first its methods
--! stay untouched and Cell fills only what is genuinely missing. These adapters live on
--! shared widget metatables, not on globals, so no global-ownership test belongs here.

local _, Private = ...

local Pairs = pairs
--! WotLK fix: локалы error/string.format ушли вместе с шимом SetColorTexture -
--! единственным местом в файле, которое печатало Usage-ошибку.
--! WotLK fix: _G and pcall went with the class-probing machinery — the FontString
--! metatable is reached through one frame, not through _G[Class] lookups.
local CreateFrame = CreateFrame
local GetMetaTable = getmetatable
local Ceil = math.ceil
local Floor = math.floor

--! WotLK fix: FontString:GetNumLines needs only integer rounding. Keep that
--! helper local instead of loading ClassicAPI MathUtil and publishing its broad
--! retail math family to the shared Lua global namespace.
local function Round(Value)
	if Value < 0 then
		return Ceil(Value - 0.5)
	end
	return Floor(Value + 0.5)
end

--! WotLK fix: адаптер TextureBase:SetAtlas удалён вместе с чтением
--! _G.C_Texture.AtlasData. Данные атласов Cell больше не публикует и не грузит,
--! поэтому в одиночку (без чужого !!!ClassicAPI) метод молча не делал ничего -
--! и именно на этом уже дважды ловились пустые кнопки (см. WotLK fix в
--! RaidDebuffs_Classic.lua:347 и Widgets_IndicatorSettings.lua:6733). Атласов на
--! 3.3.5 нет как системы, все живые точки переведены на реальные пути текстур.

local UIObject

--[[

	WidgetAPI adds missing 3.3.5 methods to a shared widget metatable.

	Information:
		-- https://warcraft.wiki.gg/wiki/Widget_API
		-- https://warcraft.wiki.gg/wiki/Widget_API?oldid=348056 (3.3.5)

	--! WotLK fix: only the FontString section is left, so the ClassicAPI class-probing
	--! machinery (ObjectSignature/GetObject/Process, ~150 lines) is gone with it — one
	--! hidden probe frame yields that metatable directly. Every other section was either
	--! dead or moved to a per-instance field on the widgets Cell builds itself; the
	--! examples that used to stand here (ScriptRegion:SetShown, TextureBase:SetColorTexture,
	--! Button:SetEnabled) all describe removed sections. The rule they illustrated still
	--! holds: the higher the section sits in the widget hierarchy, the wider the tax on
	--! the whole client.

	To avoid collision/errors with other addons (eg. self.duration), we prefix object stored data with "_".

]]

UIObject = {
	--! WotLK fix: parent-key/debug/forbidden compatibility has no active Cell
	--! consumer after the private FlipBook path was installed. Do not publish
	--! table-scanning or state-only methods on every shared UI object.

	--! WotLK fix: манифест Frame и вся секция ScriptRegion удалены вместе с
	--! единственным жившим в них методом - SetShown. Он прописывался в общие
	--! метатаблицы Frame, Texture, FontString, Button, CheckButton, EditBox,
	--! Slider, StatusBar и т.д., то есть всем фреймам клиента, а звали его ровно
	--! четыре точки в Cell (Indicators/Base.lua x2, Modules/General/General.lua,
	--! RaidFrames/UnitButton_Cata_Wrath.lua). Все четыре переведены на нативную
	--! пару Show/Hide. Остальные методы ScriptRegion (сдвиги геометрии, состояние
	--! alpha/scale родителя) потребителей не имели и на 3.3.5 нереализуемы.
	--! Локальный GetObject("Frame") ниже от этого не зависит: он вызывается
	--! рекурсивно из ветвей Texture/FontString/AnimationGroup, а не из манифеста.

	--! WotLK fix: no active Cell path needs a shared Region:GetEffectiveScale
	--! fallback; frames already expose the native method and texture sizing uses
	--! the owning frame explicitly.

	--! WotLK fix: секции Texture и TextureBase удалены целиком вместе с единственным
	--! жившим в них методом - SetColorTexture. На 3.3.5 такого метода нет, потому что
	--! цвет задаёт сама нативная числовая форма Texture:SetTexture(r, g, b[, a])
	--! (кодекс), а шим ровно её и звал - лишний Lua-кадр на каждый из 88 вызовов Cell.
	--! Все точки переведены на нативный SetTexture напрямую. Аргумент `A or 1` был
	--! мёртвым: живые вызовы передавали 3-4 числа из хелперов с фиксированной
	--! арностью (F.GetClassColor, I.GetDebuffTypeColor, Cell.GetAccentColorRGB - все
	--! по три значения), а трёхаргументная форма и так даёт alpha = 1 - см.
	--! FrameXML 3.3.5a WorldMapFrame.lua:379 и 18 таких вызовов в ElvUI 6.09 под этот
	--! клиент, включая заведомо непрозрачные чёрные рамки. Проверка "все три nil"
	--! тоже ничего не ловила: ни один вызов не приходил пустым.
	--! Пустых секций после удаления не осталось, поэтому WidgetAPI больше вообще не
	--! пишет в общую метатаблицу Texture: при живом !!!ClassicAPI, который ставит
	--! методы неаддитивно и грузится раньше, Cell теперь не зависит от чужой копии
	--! этого метода ни в одной точке (правило 3).
	--! Прежние заметки по этой секции: GetAtlas/GetTextureFilePath, атласные хелперы
	--! статус-бара и SetAtlas обслуживали только неактивные TextureUtil/NineSlice (см.
	--! комментарий выше о C_Texture.AtlasData); SetMask на 3.3.5 неисполним и не
	--! должен выдаваться за успешный no-op (Cell использует явный фолбэк);
	--! SetSnapToPixelGrid/SetTexelSnappingBias не влияют на нативный рендер, а
	--! нативный Texture:SetRotation нельзя хукать на весь клиент ради ретейльного
	--! геттера, которым Cell не пользуется.

	--! WotLK fix: do not publish fake mask methods on the shared Texture
	--! metatable. Cell's Wrath paths use explicit non-mask fallbacks, while
	--! LibCustomGlow tracks native masks privately on clients that support them.

	FontString = {
		GetNumLines = function(Self)
			local _, FontSize = Self:GetFont()
			if ( not FontSize or FontSize <= 0 ) then return 0 end
			local HeightMultiplier = 1.05445
			return Round((Self:GetStringHeight() * HeightMultiplier) / Round(FontSize))
		end,

		IsTruncated = function(Self)
			local OldWidth = Self:GetWidth()
			if ( not OldWidth or OldWidth == 0 ) then return false end
			Self:SetWidth(0)
			local NaturalWidth = Self:GetStringWidth()
			Self:SetWidth(OldWidth)
			return (NaturalWidth > (OldWidth + 0.1))
		end,

		--! WotLK fix: retain only the two proven Cell consumers. Text scaling,
		--! font-height aliases, unbounded-width and fit helpers were dormant shared
		--! behavior and no longer alter every FontString metatable.
	},

	--! WotLK fix: Cell restarts its own action animations explicitly with
	--! Stop/Play. Do not add retail Restart/SetPlaying helpers to every shared
	--! AnimationGroup and Animation object for dormant foreign consumers.

	--! WotLK fix: do not publish retail absolute Alpha/Scale endpoint methods
	--! on shared widget metatables. Native 3.3.5 animations are relative and
	--! Cell owns its absolute endpoint adapters privately in Widgets/Animation.lua.

	--! WotLK fix: Frame clipping, line emulation, hierarchy desaturation, resize
	--! aliases and parent-level state have no active Cell consumers. Remove the
	--! shared methods and their timer/closure machinery instead of maintaining a
	--! broad foreign-facing approximation layer.

	--! WotLK fix: the Button section is gone. SetEnabled moved to a per-instance
	--! field in Cell.CreateButton / Cell.CreateColorPicker (Widgets.lua,
	--! Widget_SetEnabled). Its body was the native Enable/Disable pair, so every
	--! button in the client carried a wrapper that only Cell called. Cell.SetEnabled
	--! falls back to the native pair for raw frames.

	--! WotLK fix: model transform approximations have no active Cell consumer;
	--! do not publish them on the shared Model metatable.

	--! WotLK fix: PlayerModel:SetPortraitZoom is native on 3.3.5. Do not
	--! publish a retail approximation on the shared PlayerModel metatable.

	--! WotLK fix: the EditBox section (Enable/Disable/SetEnabled/IsEnabled) is gone:
	--! Cell.CreateEditBox owns all four per instance since August (EditBox_* in
	--! Widgets.lua), so the shared copies had zero Cell consumers — and they swapped
	--! the font object, which is why the per-instance ones exist.

	--! WotLK fix: SimpleHTML content-height and GameTooltip line/item helpers have
	--! no active Cell consumers. Do not publish them as foreign-facing contracts.

	--! WotLK fix: native 3.3.5 Cooldown exposes SetCooldown and SetReverse only.
	--! Do not publish a retail control surface or hook SetCooldown client-wide.
	--! Cell owns completion, duration, OmniCC, and swipe-visibility state on the
	--! cooldown instances created in Indicators/Base.lua.

	--! WotLK fix: the Slider section is gone the same way — Cell.CreateSlider sets
	--! SetEnabled per instance.

	--! WotLK fix: SetObeyStepOnDrag cannot change native 3.3.5 behavior.
	--! Cell call sites already guard the optional method, so leave it absent
	--! instead of advertising a successful shared no-op to foreign addons.

}

-- Install the absent methods on the shared FontString metatable.
--! WotLK fix: the probe frame stays hidden and parents nothing; a FontString needs
--! no template, so this cannot capture keyboard input the way the old EditBox probe did.
local Probe = CreateFrame("Frame")
Probe:Hide()

local Metatable = GetMetaTable(Probe:CreateFontString()).__index
if ( Metatable ) then
	for Method, Function in Pairs(UIObject.FontString) do
		--! WotLK fix: embedded compatibility methods are additive only.
		--! Never replace or hook a native 3.3.5 method, or a method already
		--! owned by another addon, on a shared widget metatable.
		if ( Metatable[Method] == nil ) then
			Metatable[Method] = Function
		end
	end
end