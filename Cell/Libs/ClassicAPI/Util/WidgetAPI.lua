--! Cell: this is a private, trimmed fork of Tsoukie's ClassicAPI.
--! WotLK fix: the `if IsAddOnLoaded("!!!ClassicAPI") then return end` guard that used to
--! stand here is gone. Cell is a public addon, so both environments are real and the guard
--! only ever fired in one of them:
--!   * standalone !!!ClassicAPI absent  -> guard never fired, this file already installed its
--!     additive subset (audited runs 6/9/10/11: changed 0 / added 16, zero Lua errors;
--!     those runs predate the SetAtlas removal and the dormant-method purge — the manifest
--!     installs 8 methods today, and the count is pinned by global_hook_ownership_smoke.py);
--!   * standalone !!!ClassicAPI present -> guard fired, Cell installed nothing at all and
--!     silently depended on a foreign addon's version of every method it calls.
--! The second shape is what CLAUDE.md rule 3 forbids: an early exit hands the hot path to
--! someone else's copy and rolls back this backport's own fixes. Process() below is additive
--! only (`if Metatable[Method] == nil`), so with the foreign addon loaded first its methods
--! stay untouched and Cell fills only what is genuinely missing. These adapters live on
--! shared widget metatables, not on globals, so no global-ownership test belongs here.

local _, Private = ...

local _G = _G
local PCall = pcall
local Pairs = pairs
--! WotLK fix: локалы error/string.format ушли вместе с шимом SetColorTexture -
--! единственным местом в файле, которое печатало Usage-ошибку.
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

	WidgetAPI is a system to automatically add or modify the methods/functions on an object.
	You can define custom methods within the "UIObject" table.

	This code implements inheritance. All child objects receive the methods of the parent object.
	Therefore, you only need to add methods to root objects.

	Information:
		-- https://warcraft.wiki.gg/wiki/Widget_API
		-- https://warcraft.wiki.gg/wiki/Widget_API?oldid=348056 (3.3.5)
		-- https://warcraft.wiki.gg/wiki/Widget_API#/media/File:Widget_Hierarchy.png

	Example:
		The SetEnabled method is listed in the "Button" section, so we define it in
		the "Button" table and every metatable that answers the Button signature
		below receives it.

		--! WotLK fix: примером служил сначала ScriptRegion:SetShown, потом
		--! TextureBase:SetColorTexture - оба метода удалены (первый попадал во все
		--! метатаблицы клиента, второй - во все текстуры; оба заменены нативными
		--! вызовами на местах). Пример намеренно указывает на узкую конкретную
		--! секцию: чем выше в иерархии секция, тем шире налог на весь клиент.
		--! Абстрактная секция (вида TextureBase) сама себя не устанавливает -
		--! GetObject для неё падает на PCall(CreateFrame, Class); в метатаблицу она
		--! попадает только через конкретный класс из этого же манифеста, чья подпись
		--! совпала. Убрав конкретный класс, убираешь и абстрактную секцию.

		If method(s) already exist define a "Prehook" or "Posthook" table within the object class:
			FrameScriptObject = {
				Posthook = {
					GetName = function()end
					...
				}
				...
			}

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

	Button = {
		SetEnabled = function(Self, Enabled)
			if ( Enabled ) then Self:Enable() else Self:Disable() end
		end,
		--! WotLK fix: atlas-state and clear-texture helpers have no active Cell
		--! consumers. Retain only the proven button enable adapter.
	},

	--! WotLK fix: model transform approximations have no active Cell consumer;
	--! do not publish them on the shared Model metatable.

	--! WotLK fix: PlayerModel:SetPortraitZoom is native on 3.3.5. Do not
	--! publish a retail approximation on the shared PlayerModel metatable.

	EditBox = {
		Enable = function(Self)
			Self._Enabled = true
			Self:SetFontObject("GameFontWhite")
			Self:EnableMouse(true)
			Self:ClearFocus()
			local Script = Self:GetScript("OnEnable")
			if ( Script ) then
				Script(Self)
			end
		end,

		Disable = function(Self)
			Self._Enabled = nil
			Self:SetFontObject("GameFontDisable")
			Self:EnableMouse(false)
			Self:ClearFocus()
			local Script = Self:GetScript("OnDisable")
			if ( Script ) then
				Script(Self)
			end
		end,

		SetEnabled = function(Self, State)
			if ( State ) then
				Self:Enable()
			else
				Self:Disable()
			end
		end,

		IsEnabled = function(Self)
			return Self._Enabled or false
		end,
	},

	--! WotLK fix: SimpleHTML content-height and GameTooltip line/item helpers have
	--! no active Cell consumers. Do not publish them as foreign-facing contracts.

	--! WotLK fix: native 3.3.5 Cooldown exposes SetCooldown and SetReverse only.
	--! Do not publish a retail control surface or hook SetCooldown client-wide.
	--! Cell owns completion, duration, OmniCC, and swipe-visibility state on the
	--! cooldown instances created in Indicators/Base.lua.

	Slider = {
		SetEnabled = function(Self, State)
			if ( State ) then Self:Enable() else Self:Disable() end
		end,
	},

	--! WotLK fix: SetObeyStepOnDrag cannot change native 3.3.5 behavior.
	--! Cell call sites already guard the optional method, so leave it absent
	--! instead of advertising a successful shared no-op to foreign addons.

}

local function ObjectSignature(Class, Meta)
	-- Identify objects by checking their intrinsic API...

	if Class == "FrameScriptObject" then return Meta.GetName
	elseif Class == "Object" then return Meta.GetParent -- ScriptObject
	elseif Class == "ScriptRegion" then return Meta.SetAllPoints -- ScriptRegionResizing, AnimatableObject
	elseif Class == "Region" then return Meta.GetDrawLayer

	-- Frame
	elseif Class == "Frame" then return Meta.GetFrameLevel

	-- Button
	elseif Class == "Button" then return Meta.Click
	elseif Class == "CheckButton" then return Meta.SetChecked

	-- Model
	elseif Class == "Model" then return Meta.ClearModel
	elseif Class == "PlayerModel" then return Meta.RefreshUnit
	elseif Class == "DressUpModel" then return Meta.Dress
	elseif Class == "TabardModel" then return Meta.CanSaveTabardNow

	-- Blob
	elseif Class == "QuestPOIFrame" then return Meta.DrawQuestBlob

	-- Misc Frame
	elseif Class == "Cooldown" then return Meta.SetCooldown
	elseif Class == "GameTooltip" then return Meta.AddLine
	elseif Class == "ScrollFrame" then return Meta.GetScrollChild
	elseif Class == "StatusBar" then return Meta.SetStatusBarTexture
	elseif Class == "Slider" then return Meta.GetThumbTexture
	elseif Class == "ColorSelect" then return Meta.GetColorRGB

	elseif Class == "Minimap" then return Meta.PingLocation
	elseif Class == "MovieFrame" then return Meta.StartMovie
	--elseif Class == "WorldFrame" then return

	elseif Class == "EditBox" then return Meta.HighlightText
	elseif Class == "MessageFrame" then return Meta.GetInsertMode and not Meta.AtBottom
	elseif Class == "ScrollingMessageFrame" then return Meta.AtBottom
	elseif Class == "SimpleHTML" then return Meta.SetHyperlinkFormat

	-- Texture
	elseif Class == "TextureBase" then return Meta.SetTexture
	elseif Class == "Texture" then return Meta.SetGradient

	-- Font
	elseif Class == "Font" then return Meta.SetFontObject
	elseif Class == "FontInstance" then return Meta.GetFontObject and not Meta.SetHyperlinkFormat
	elseif Class == "FontString" then return Meta.GetStringWidth

	-- Animation
	elseif Class == "AnimationGroup" then return Meta.CreateAnimation
	elseif Class == "Animation" then return Meta.Play and Meta.GetRegionParent
	elseif Class == "Alpha" then return Meta.Play and Meta.SetChange
	elseif Class == "Scale" then return Meta.Play and Meta.SetScale
	elseif Class == "Rotation" then return Meta.Play and Meta.SetRadians
	elseif Class == "Translation" then return Meta.Play and Meta.SetOffset
	elseif Class == "Path" then return Meta.CreateControlPoint
	elseif Class == "ControlPoint" then return Meta.SetOrder and not Meta.Play
	end
end

local GetObjectCache = {}
local function GetObject(Class)
	local Object = GetObjectCache[Class]

	if ( not Object ) then
		if ( Class == "Font" ) then
			Object = CreateFont("__")
			_G["__"] = nil
		elseif ( Class == "Texture" ) then
			Object = GetObject("Frame"):CreateTexture()
		elseif ( Class == "FontString" ) then
			Object = GetObject("Frame"):CreateFontString()
		elseif ( Class == "ControlPoint" ) then
			Object = GetObject("Path"):CreateControlPoint()
		elseif ( Class == "AnimationGroup" ) then
			Object = GetObject("Frame"):CreateAnimationGroup()
		elseif ( Class == "Animation" ) then
			--! WotLK fix: the native base Animation is abstract for Lua creation on
			--! some 3.3.5 clients. Any concrete child exposes the same inherited
			--! Animation metatable, so probe it through a native Alpha object.
			Object = GetObject("AnimationGroup"):CreateAnimation("Alpha")
		elseif ( Class == "Translation" or Class == "Rotation" or Class == "Scale" or Class == "Alpha" or Class == "Path" ) then
			Object = GetObject("AnimationGroup"):CreateAnimation(Class)
		elseif ( Class == "WorldFrame" or Class == "Minimap" or Class == "MovieFrame" ) then
			Object = true
		else
			-- Exception handling for "Frame", "Button", etc.
			-- It will safely fail for abstract classes "ScriptRegion", "FrameScriptObject", etc.
			local Success
			Success, Object = PCall(CreateFrame, Class)
			if ( not Success ) then return end
		end

		if ( Object ~= true and Object.Hide ) then
			Object:Hide() -- REQUIRED! Otherwise, the keyboard input will cease to work if EditBox is created, as it captures input.
		end

		GetObjectCache[Class] = Object
	end

	return Object
end

-- Process classes and inject only absent compatibility methods.
local function Process(Metatable)
	for Class, Data in Pairs(UIObject) do
		if ( ObjectSignature(Class, Metatable) ) then
			for Method, Function in Pairs(Data) do
				--! WotLK fix: embedded compatibility methods are additive only.
				--! Never replace or hook a native 3.3.5 method, or a method already
				--! owned by another addon, on a shared widget metatable.
				if ( Metatable[Method] == nil ) then
					Metatable[Method] = Function
				end
			end
		end
	end
end

-- Manifest UIObjects, automatically determining if they're abstract, unique, or not.
for Class in Pairs(UIObject) do
	local Object = GetObject(Class)
	if ( Object ) then
		local Metatable = ( Object == true ) and _G[Class] or GetMetaTable(Object).__index
		if ( Metatable ) then
			Process(Metatable)
		end
	end
end